"""
Session management for anti-detection.

Manages realistic play session lifecycle including warmup, fatigue,
breaks, and natural session end patterns to simulate human player behavior.
"""

import json
import random
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Optional
from uuid import uuid4

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class SessionState(str, Enum):
    """States of a play session."""
    STARTING = "starting"          # Just logged in
    WARMING_UP = "warming_up"      # First 15 minutes
    ACTIVE = "active"              # Normal play
    FOCUSED = "focused"            # High intensity (grinding, boss)
    RELAXED = "relaxed"            # Low intensity (chatting, organizing)
    FATIGUED = "fatigued"          # Long session
    WINDING_DOWN = "winding_down"  # Preparing to log off
    AFK = "afk"                    # Away from keyboard


class SessionBehavior(BaseModel):
    """Behavior profile for session state."""
    
    model_config = ConfigDict(frozen=True)
    
    state: SessionState = Field(description="Session state")
    action_speed_multiplier: float = Field(default=1.0, description="Speed modifier")
    error_rate_multiplier: float = Field(default=1.0, description="Error rate modifier")
    social_interaction_chance: float = Field(default=0.1, description="Chat likelihood")
    afk_chance_per_minute: float = Field(default=0.01, description="AFK probability")


class PlaySession(BaseModel):
    """Current play session data."""
    
    model_config = ConfigDict(frozen=False)
    
    session_id: str = Field(default_factory=lambda: str(uuid4()), description="Unique session ID")
    started_at: datetime = Field(default_factory=datetime.now, description="Session start time")
    current_state: SessionState = Field(default=SessionState.STARTING, description="Current state")
    
    # Duration tracking
    total_duration_minutes: float = Field(default=0.0, ge=0.0)
    active_play_minutes: float = Field(default=0.0, ge=0.0)
    afk_minutes: float = Field(default=0.0, ge=0.0)
    
    # Activity tracking
    actions_performed: int = Field(default=0, ge=0)
    monsters_killed: int = Field(default=0, ge=0)
    items_looted: int = Field(default=0, ge=0)
    messages_sent: int = Field(default=0, ge=0)
    
    # Break tracking
    last_break_at: Optional[datetime] = Field(default=None)
    total_breaks: int = Field(default=0, ge=0)
    
    @property
    def duration_seconds(self) -> float:
        """Get session duration in seconds."""
        return (datetime.now() - self.started_at).total_seconds()
    
    @property
    def duration_hours(self) -> float:
        """Get session duration in hours."""
        return self.duration_seconds / 3600.0


class HumanSessionManager:
    """
    Manage realistic play sessions.
    
    Features:
    - Session lifecycle management
    - Fatigue simulation
    - Natural break patterns
    - Play time limits (humans have responsibilities)
    - Session personality (some days more active)
    - Weekend vs weekday patterns
    """
    
    def __init__(self, data_dir: Path):
        self.log = structlog.get_logger()
        self.data_dir = data_dir
        self.current_session: Optional[PlaySession] = None
        self.session_history: list[PlaySession] = []
        self.patterns = self._load_session_patterns()
        
        self.log.info("session_manager_initialized")
        
    def _load_session_patterns(self) -> dict:
        """Load session patterns from configuration."""
        patterns_file = self.data_dir / "session_patterns.json"
        
        if not patterns_file.exists():
            self.log.warning("session_patterns.json not found, using defaults")
            return self._get_default_patterns()
        
        try:
            with open(patterns_file, "r") as f:
                return json.load(f)
        except Exception as e:
            self.log.error("failed_to_load_session_patterns", error=str(e))
            return self._get_default_patterns()
    
    def _get_default_patterns(self) -> dict:
        """Get default session patterns."""
        return {
            "weekday_patterns": {
                "typical_start_hours": [18, 19, 20, 21, 22],
                "typical_end_hours": [22, 23, 0, 1],
                "average_session_minutes": 120,
                "max_session_minutes": 240
            },
            "weekend_patterns": {
                "typical_start_hours": [10, 11, 12, 14, 15, 16],
                "typical_end_hours": [23, 0, 1, 2],
                "average_session_minutes": 180,
                "max_session_minutes": 360
            },
            "break_patterns": {
                "short_break_after_minutes": 45,
                "short_break_duration_seconds": [30, 120],
                "long_break_after_minutes": 120,
                "long_break_duration_seconds": [300, 900],
                "bathroom_break_interval_minutes": [60, 180],
                "bathroom_break_duration_seconds": [60, 300]
            },
            "afk_patterns": {
                "random_afk_chance_per_hour": 0.3,
                "afk_duration_seconds": [30, 300],
                "afk_triggers": ["doorbell", "phone_call", "food_delivery", "bathroom", "drink_refill", "pet_attention"]
            }
        }
    
    async def start_session(self) -> PlaySession:
        """Start a new play session."""
        self.current_session = PlaySession()
        
        self.log.info(
            "session_started",
            session_id=self.current_session.session_id,
            time=datetime.now().strftime("%H:%M")
        )
        
        return self.current_session
    
    async def update_session_state(self) -> SessionState:
        """Update session state based on duration and activity."""
        if not self.current_session:
            return SessionState.STARTING
        
        duration_minutes = self.current_session.duration_seconds / 60.0
        
        # Determine new state based on duration
        if duration_minutes < 5:
            new_state = SessionState.STARTING
        elif duration_minutes < 15:
            new_state = SessionState.WARMING_UP
        elif duration_minutes < 60:
            new_state = SessionState.ACTIVE
        elif duration_minutes < 120:
            # Can be active or focused based on activity
            activity_rate = self.current_session.actions_performed / max(duration_minutes, 1)
            new_state = SessionState.FOCUSED if activity_rate > 10 else SessionState.ACTIVE
        elif duration_minutes < 180:
            new_state = SessionState.FATIGUED
        else:
            new_state = SessionState.WINDING_DOWN
        
        # Update state if changed
        if new_state != self.current_session.current_state:
            old_state = self.current_session.current_state
            self.current_session.current_state = new_state
            
            self.log.info(
                "session_state_changed",
                old=old_state.value,
                new=new_state.value,
                duration_minutes=round(duration_minutes, 1)
            )
        
        return new_state
    
    async def should_take_break(self) -> tuple[bool, int]:
        """
        Determine if it's time for a break.
        Returns (should_break, duration_seconds)
        """
        if not self.current_session:
            return False, 0
        
        duration_minutes = self.current_session.duration_seconds / 60.0
        patterns = self.patterns["break_patterns"]
        
        # Check if enough time since last break
        if self.current_session.last_break_at:
            time_since_break = (datetime.now() - self.current_session.last_break_at).total_seconds() / 60.0
        else:
            time_since_break = duration_minutes
        
        # Short break check (after 45 minutes)
        if time_since_break > patterns["short_break_after_minutes"]:
            if random.random() < 0.3:  # 30% chance
                duration = random.randint(*patterns["short_break_duration_seconds"])
                self.log.info("taking_short_break", duration_seconds=duration)
                return True, duration
        
        # Long break check (after 2 hours)
        if time_since_break > patterns["long_break_after_minutes"]:
            if random.random() < 0.6:  # 60% chance
                duration = random.randint(*patterns["long_break_duration_seconds"])
                self.log.info("taking_long_break", duration_seconds=duration)
                return True, duration
        
        # Bathroom break (random interval)
        bathroom_interval = random.randint(*patterns["bathroom_break_interval_minutes"])
        if time_since_break > bathroom_interval:
            if random.random() < 0.2:  # 20% chance
                duration = random.randint(*patterns["bathroom_break_duration_seconds"])
                self.log.info("taking_bathroom_break", duration_seconds=duration)
                return True, duration
        
        return False, 0
    
    async def simulate_afk(self, duration_seconds: int) -> None:
        """
        Simulate AFK behavior.
        Not just standing still - realistic AFK patterns.
        """
        if not self.current_session:
            return
        
        old_state = self.current_session.current_state
        self.current_session.current_state = SessionState.AFK
        self.current_session.last_break_at = datetime.now()
        self.current_session.total_breaks += 1
        
        self.log.info(
            "going_afk",
            duration_seconds=duration_seconds,
            reason=random.choice(self.patterns["afk_patterns"]["afk_triggers"])
        )
        
        # Update AFK time
        self.current_session.afk_minutes += duration_seconds / 60.0
        
        # Restore previous state after AFK
        self.current_session.current_state = old_state
    
    async def should_end_session(self) -> tuple[bool, str]:
        """
        Determine if session should end naturally.
        Returns (should_end, reason)
        """
        if not self.current_session:
            return False, ""
        
        duration_hours = self.current_session.duration_hours
        hour = datetime.now().hour
        is_weekend = datetime.now().weekday() >= 5
        
        patterns = self.patterns["weekend_patterns" if is_weekend else "weekday_patterns"]
        max_hours = patterns["max_session_minutes"] / 60.0
        
        # Maximum session time reached
        if duration_hours >= max_hours:
            return True, "Maximum session time reached"
        
        # Fatigue-based ending (more likely after 3 hours)
        if duration_hours > 3:
            fatigue_chance = (duration_hours - 3) * 0.1  # 10% per hour after 3
            if random.random() < fatigue_chance:
                return True, "Player fatigued"
        
        # Time-based ending (late at night)
        if hour in patterns["typical_end_hours"]:
            if random.random() < 0.2:  # 20% chance per check
                return True, "Typical end time"
        
        # Very late night (2am-6am)
        if 2 <= hour < 6:
            if random.random() < 0.4:  # 40% chance
                return True, "Very late, going to sleep"
        
        # Work/school time on weekdays (6am-8am)
        if not is_weekend and 6 <= hour < 8:
            if random.random() < 0.5:
                return True, "Morning responsibilities"
        
        return False, ""
    
    def get_session_behavior(self) -> SessionBehavior:
        """Get behavior profile for current session state."""
        if not self.current_session:
            return SessionBehavior(state=SessionState.STARTING)
        
        state = self.current_session.current_state
        
        # Define behavior profiles for each state
        profiles = {
            SessionState.STARTING: SessionBehavior(
                state=state,
                action_speed_multiplier=0.8,
                error_rate_multiplier=1.2,
                social_interaction_chance=0.15,
                afk_chance_per_minute=0.02
            ),
            SessionState.WARMING_UP: SessionBehavior(
                state=state,
                action_speed_multiplier=0.9,
                error_rate_multiplier=1.1,
                social_interaction_chance=0.12,
                afk_chance_per_minute=0.01
            ),
            SessionState.ACTIVE: SessionBehavior(
                state=state,
                action_speed_multiplier=1.0,
                error_rate_multiplier=1.0,
                social_interaction_chance=0.10,
                afk_chance_per_minute=0.005
            ),
            SessionState.FOCUSED: SessionBehavior(
                state=state,
                action_speed_multiplier=1.1,
                error_rate_multiplier=0.9,
                social_interaction_chance=0.05,
                afk_chance_per_minute=0.002
            ),
            SessionState.RELAXED: SessionBehavior(
                state=state,
                action_speed_multiplier=0.85,
                error_rate_multiplier=1.0,
                social_interaction_chance=0.25,
                afk_chance_per_minute=0.02
            ),
            SessionState.FATIGUED: SessionBehavior(
                state=state,
                action_speed_multiplier=0.75,
                error_rate_multiplier=1.3,
                social_interaction_chance=0.08,
                afk_chance_per_minute=0.03
            ),
            SessionState.WINDING_DOWN: SessionBehavior(
                state=state,
                action_speed_multiplier=0.7,
                error_rate_multiplier=1.2,
                social_interaction_chance=0.20,
                afk_chance_per_minute=0.04
            ),
            SessionState.AFK: SessionBehavior(
                state=state,
                action_speed_multiplier=0.0,
                error_rate_multiplier=0.0,
                social_interaction_chance=0.0,
                afk_chance_per_minute=1.0
            )
        }
        
        return profiles.get(state, SessionBehavior(state=state))
    
    def calculate_play_window(self) -> tuple[datetime, datetime]:
        """
        Calculate realistic play time window for today.
        Consider: weekday/weekend, typical patterns
        """
        now = datetime.now()
        is_weekend = now.weekday() >= 5
        
        patterns = self.patterns["weekend_patterns" if is_weekend else "weekday_patterns"]
        
        # Random start time from typical start hours
        start_hour = random.choice(patterns["typical_start_hours"])
        start_time = now.replace(hour=start_hour, minute=random.randint(0, 59), second=0)
        
        # If start time has passed, use tomorrow
        if start_time < now:
            start_time += timedelta(days=1)
        
        # Calculate end time
        session_duration = random.randint(
            patterns["average_session_minutes"] - 30,
            patterns["average_session_minutes"] + 30
        )
        end_time = start_time + timedelta(minutes=session_duration)
        
        return start_time, end_time
    
    def record_action(self, action_type: str) -> None:
        """Record an action in the current session."""
        if not self.current_session:
            return
        
        self.current_session.actions_performed += 1
        
        if action_type == "kill":
            self.current_session.monsters_killed += 1
        elif action_type == "loot":
            self.current_session.items_looted += 1
        elif action_type == "chat":
            self.current_session.messages_sent += 1
    
    async def end_session(self, reason: str = "User initiated") -> None:
        """End the current session."""
        if not self.current_session:
            return
        
        # Update final duration
        self.current_session.total_duration_minutes = self.current_session.duration_seconds / 60.0
        self.current_session.active_play_minutes = (
            self.current_session.total_duration_minutes - self.current_session.afk_minutes
        )
        
        # Archive session
        self.session_history.append(self.current_session)
        if len(self.session_history) > 50:
            self.session_history.pop(0)
        
        self.log.info(
            "session_ended",
            session_id=self.current_session.session_id,
            duration_minutes=round(self.current_session.total_duration_minutes, 1),
            actions=self.current_session.actions_performed,
            reason=reason
        )
        
        self.current_session = None
    
    def get_session_stats(self) -> dict:
        """Get current session statistics."""
        if not self.current_session:
            return {"active": False}
        
        return {
            "active": True,
            "session_id": self.current_session.session_id,
            "state": self.current_session.current_state.value,
            "duration_minutes": round(self.current_session.duration_seconds / 60.0, 1),
            "actions_performed": self.current_session.actions_performed,
            "monsters_killed": self.current_session.monsters_killed,
            "messages_sent": self.current_session.messages_sent,
            "total_breaks": self.current_session.total_breaks,
            "afk_minutes": round(self.current_session.afk_minutes, 1)
        }