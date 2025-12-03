"""
Human timing humanization for anti-detection.

Generates human-like timing delays using statistical distributions,
fatigue simulation, and time-of-day awareness to prevent bot detection.
"""

import math
import random
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class ReactionType(str, Enum):
    """Types of human reaction scenarios."""
    INSTANT = "instant"          # Emergency reaction (100-200ms)
    QUICK = "quick"              # Practiced action (200-400ms)
    NORMAL = "normal"            # Average response (400-800ms)
    CONSIDERED = "considered"    # Thinking required (800-1500ms)
    DISTRACTED = "distracted"    # Multi-tasking (1500-3000ms)
    AFK_RETURN = "afk_return"    # Coming back from AFK (3000-10000ms)


class TimingProfile(BaseModel):
    """Human timing profile based on player skill level."""
    
    model_config = ConfigDict(frozen=False)
    
    profile_name: str = Field(default="default", description="Profile identifier")
    
    # Base reaction times (milliseconds)
    base_reaction_ms: Optional[int] = Field(default=None, ge=50, description="Base reaction time (overrides min/max if set)")
    min_reaction_ms: int = Field(default=150, ge=50, description="Minimum reaction time")
    max_reaction_ms: int = Field(default=500, ge=100, description="Maximum reaction time")
    
    # Variance factors
    fatigue_multiplier: float = Field(default=1.0, ge=0.5, le=2.0, description="Current fatigue factor")
    time_of_day_factor: float = Field(default=1.0, ge=0.8, le=1.5, description="Time-based slowdown")
    consecutive_action_speedup: float = Field(default=0.9, ge=0.7, le=1.0, description="Muscle memory effect")
    
    # Randomization
    micro_delay_chance: float = Field(default=0.3, ge=0.0, le=1.0, description="Chance of micro-pause")
    typo_chance: float = Field(default=0.02, ge=0.0, le=0.1, description="Typing error rate")
    misclick_chance: float = Field(default=0.01, ge=0.0, le=0.1, description="Targeting error rate")
    
    def model_post_init(self, __context):
        """Initialize min/max from base_reaction_ms if provided."""
        if self.base_reaction_ms is not None:
            # Set min/max based on base
            object.__setattr__(self, 'min_reaction_ms', int(self.base_reaction_ms * 0.8))
            object.__setattr__(self, 'max_reaction_ms', int(self.base_reaction_ms * 1.5))


class ActionTiming(BaseModel):
    """Timing for a specific action."""
    
    model_config = ConfigDict(frozen=False)
    
    action_type: str = Field(description="Type of action being timed")
    base_delay_ms: int = Field(ge=0, description="Base delay before variance")
    variance_ms: int = Field(ge=0, description="Applied variance amount")
    actual_delay_ms: int = Field(ge=0, description="Final computed delay")
    
    # Context
    triggered_at: datetime = Field(default_factory=datetime.now, description="When action was triggered")
    executed_at: Optional[datetime] = Field(default=None, description="When action executed")
    was_delayed_by_distraction: bool = Field(default=False, description="Was randomly delayed")
    
    @property
    def delay_seconds(self) -> float:
        """Get delay in seconds."""
        return self.actual_delay_ms / 1000.0


class HumanTimingEngine:
    """
    Generate human-like timing for all actions.
    
    Features:
    - Reaction time distribution (skewed normal, not uniform)
    - Fatigue simulation over play sessions
    - Time-of-day awareness (slower at night)
    - Consecutive action speedup (muscle memory)
    - Random micro-pauses (checking phone, etc.)
    - Session warmup (slower at start)
    """
    
    def __init__(self, profile: Optional[TimingProfile] = None):
        self.log = structlog.get_logger()
        self.profile = profile or self._create_default_profile()
        self.session_start = datetime.now()
        self.action_count = 0
        self.last_action_time: Optional[datetime] = None
        self.consecutive_same_action = 0
        self.last_action_type: Optional[str] = None
        
        self.log.info(
            "timing_engine_initialized",
            profile=self.profile.profile_name,
            min_reaction=self.profile.min_reaction_ms,
            max_reaction=self.profile.max_reaction_ms
        )
        
    def _create_default_profile(self) -> TimingProfile:
        """Create default average human profile."""
        return TimingProfile(
            profile_name="average_player",
            min_reaction_ms=200,
            max_reaction_ms=500,
            fatigue_multiplier=1.0,
            time_of_day_factor=1.0,
            consecutive_action_speedup=0.9,
            micro_delay_chance=0.3,
            typo_chance=0.02,
            misclick_chance=0.01
        )
    
    def _skewed_normal_sample(self, min_val: float, max_val: float, skew: float = 0.5) -> float:
        """
        Generate skewed normal distribution sample.
        
        Human reaction times follow a right-skewed distribution,
        not uniform random. Most reactions are faster, with a tail
        of slower reactions.
        
        Args:
            min_val: Minimum value
            max_val: Maximum value
            skew: Skew factor (0.5 = right skew, typical for human reactions)
            
        Returns:
            Sample from skewed distribution
        """
        # Generate beta distribution sample (naturally skewed)
        alpha = 2.0
        beta_param = 5.0 if skew > 0 else 2.0
        sample = random.betavariate(alpha, beta_param)
        
        # Scale to desired range
        return min_val + (sample * (max_val - min_val))
    
    def get_reaction_delay(self, reaction_type: ReactionType) -> int:
        """
        Get human-like reaction delay in milliseconds.
        Uses skewed normal distribution, not uniform random!
        
        Args:
            reaction_type: Type of reaction scenario
            
        Returns:
            Delay in milliseconds
        """
        # Base ranges for each reaction type
        ranges = {
            ReactionType.INSTANT: (100, 200),
            ReactionType.QUICK: (200, 400),
            ReactionType.NORMAL: (400, 800),
            ReactionType.CONSIDERED: (800, 1500),
            ReactionType.DISTRACTED: (1500, 3000),
            ReactionType.AFK_RETURN: (3000, 10000)
        }
        
        min_ms, max_ms = ranges.get(reaction_type, (400, 800))
        
        # Apply profile modifiers
        min_ms = int(min_ms * self.profile.time_of_day_factor * self.profile.fatigue_multiplier)
        max_ms = int(max_ms * self.profile.time_of_day_factor * self.profile.fatigue_multiplier)
        
        # Use skewed distribution
        delay = int(self._skewed_normal_sample(min_ms, max_ms, skew=0.5))
        
        return delay
    
    def get_action_delay(self, action_type: str, is_combat: bool = False) -> ActionTiming:
        """
        Get delay before executing an action.
        
        Args:
            action_type: Type of action (attack, skill, move, etc.)
            is_combat: Whether action is combat-related
            
        Returns:
            ActionTiming with calculated delay
        """
        # Determine base reaction type
        if is_combat and action_type in ["attack", "skill_offensive"]:
            reaction = ReactionType.QUICK
        elif action_type in ["flee", "emergency_heal"]:
            reaction = ReactionType.INSTANT
        elif action_type in ["chat", "inventory"]:
            reaction = ReactionType.CONSIDERED
        else:
            reaction = ReactionType.NORMAL
        
        # Get base delay
        base_delay = self.get_reaction_delay(reaction)
        
        # Apply consecutive action speedup (muscle memory)
        if self.last_action_type == action_type:
            # Apply speedup up to 5 consecutive actions
            if self.consecutive_same_action < 5:
                speedup = math.pow(self.profile.consecutive_action_speedup, self.consecutive_same_action)
                base_delay = int(base_delay * speedup)
            self.consecutive_same_action += 1
        else:
            self.consecutive_same_action = 1
        
        # Apply warmup factor
        warmup = self.get_warmup_factor()
        base_delay = int(base_delay * warmup)
        
        # Check for micro-pause
        should_pause, pause_duration = self.should_micro_pause()
        variance = pause_duration if should_pause else 0
        
        # Final delay
        actual_delay = base_delay + variance
        
        # Update state
        self.action_count += 1
        self.last_action_time = datetime.now()
        self.last_action_type = action_type
        
        timing = ActionTiming(
            action_type=action_type,
            base_delay_ms=base_delay,
            variance_ms=variance,
            actual_delay_ms=actual_delay,
            was_delayed_by_distraction=should_pause
        )
        
        self.log.debug(
            "action_timing_calculated",
            action_type=action_type,
            delay_ms=actual_delay,
            was_paused=should_pause
        )
        
        return timing
    
    def apply_fatigue(self) -> float:
        """
        Calculate fatigue multiplier based on session duration.
        Humans get slower after playing for hours.
        
        Returns:
            Fatigue multiplier (1.0 = no fatigue, >1.0 = slower)
        """
        session_hours = (datetime.now() - self.session_start).total_seconds() / 3600.0
        
        # Fatigue curve: slight increase after 2 hours, more after 4 hours
        if session_hours < 1.0:
            fatigue = 1.0
        elif session_hours < 2.0:
            fatigue = 1.0 + (session_hours - 1.0) * 0.05
        elif session_hours < 4.0:
            fatigue = 1.05 + (session_hours - 2.0) * 0.1
        else:
            fatigue = 1.25 + (session_hours - 4.0) * 0.05
            fatigue = min(fatigue, 1.5)  # Cap at 1.5x
        
        return fatigue
    
    def apply_time_of_day_factor(self) -> float:
        """
        Humans are slower during late night hours.
        Peak performance: 10am-2pm, 4pm-8pm
        Slowest: 2am-6am
        
        Returns:
            Time-of-day factor (1.0 = peak, >1.0 = slower)
        """
        hour = datetime.now().hour
        
        # Time-based performance factors
        if 10 <= hour < 14 or 16 <= hour < 20:
            # Peak hours
            factor = 1.0
        elif 20 <= hour < 23 or 7 <= hour < 10:
            # Slightly slower
            factor = 1.1
        elif 23 <= hour or hour < 2:
            # Late night
            factor = 1.2
        else:
            # Very late night (2am-6am)
            factor = 1.3
        
        return factor
    
    def should_micro_pause(self) -> tuple[bool, int]:
        """
        Random chance of short distraction pause.
        Simulates checking phone, taking sip of drink, etc.
        
        Returns:
            (should_pause, duration_ms)
        """
        if random.random() < self.profile.micro_delay_chance:
            # Micro-pause: 500ms to 3000ms
            duration = random.randint(500, 3000)
            return True, duration
        
        return False, 0
    
    def get_typing_delay(self, message: str) -> int:
        """
        Calculate realistic typing time.
        Average human: 40-80 WPM (words per minute)
        Include thinking time for response.
        
        Args:
            message: Message to type
            
        Returns:
            Total typing delay in milliseconds
        """
        # Words per minute to characters per second
        wpm = random.randint(40, 80)
        chars_per_second = (wpm * 5) / 60.0  # Assume avg 5 chars per word
        
        # Base typing time
        char_count = len(message)
        typing_time_s = char_count / chars_per_second
        
        # Add thinking time (before typing)
        thinking_time_s = random.uniform(0.5, 2.0)
        
        # Add pauses at punctuation
        pause_count = message.count('.') + message.count(',') + message.count('?')
        pause_time_s = pause_count * random.uniform(0.1, 0.3)
        
        total_ms = int((typing_time_s + thinking_time_s + pause_time_s) * 1000)
        
        return total_ms
    
    def simulate_hesitation(self, decision_complexity: int) -> int:
        """
        Add hesitation for complex decisions.
        
        Args:
            decision_complexity: Complexity on 1-10 scale
            
        Returns:
            Hesitation delay in milliseconds
        """
        if decision_complexity <= 3:
            # Simple decision
            return random.randint(100, 500)
        elif decision_complexity <= 7:
            # Moderate complexity
            return random.randint(500, 1500)
        else:
            # Complex decision
            return random.randint(1500, 3000)
    
    def get_warmup_factor(self) -> float:
        """
        Session warmup - slower at start, faster after warmup.
        First 10 minutes: 1.2x slower
        10-30 minutes: normal
        30+ minutes: slightly faster (in the zone)
        60+ minutes: fatigue kicks in
        
        Returns:
            Warmup factor multiplier
        """
        session_minutes = (datetime.now() - self.session_start).total_seconds() / 60.0
        
        if session_minutes < 10:
            # Warming up
            factor = 1.2 - (session_minutes / 10.0) * 0.2
        elif session_minutes < 30:
            # Normal
            factor = 1.0
        elif session_minutes < 60:
            # In the zone
            factor = 0.95
        else:
            # Fatigue starting
            factor = self.apply_fatigue()
        
        return factor
    
    def update_profile_state(self) -> None:
        """Update profile factors based on current session state."""
        self.profile.fatigue_multiplier = self.apply_fatigue()
        self.profile.time_of_day_factor = self.apply_time_of_day_factor()
        
        self.log.debug(
            "profile_updated",
            fatigue=self.profile.fatigue_multiplier,
            time_factor=self.profile.time_of_day_factor,
            session_minutes=(datetime.now() - self.session_start).total_seconds() / 60.0
        )
    
    def should_make_typo(self) -> bool:
        """
        Determine if a typo should occur.
        
        Returns:
            True if typo should happen
        """
        return random.random() < self.profile.typo_chance
    
    def should_misclick(self) -> bool:
        """
        Determine if a misclick should occur.
        
        Returns:
            True if misclick should happen
        """
        return random.random() < self.profile.misclick_chance
    
    def calculate_action_delay(self, action_type: str) -> int:
        """
        Calculate action delay (alias for get_action_delay).
        
        Args:
            action_type: Type of action
        
        Returns:
            Delay in milliseconds
        """
        timing = self.get_action_delay(action_type)
        return timing.actual_delay_ms
    
    def get_session_stats(self) -> dict:
        """Get current session statistics."""
        return {
            "session_duration_minutes": (datetime.now() - self.session_start).total_seconds() / 60.0,
            "total_actions": self.action_count,
            "current_fatigue": self.profile.fatigue_multiplier,
            "time_of_day_factor": self.profile.time_of_day_factor,
            "warmup_factor": self.get_warmup_factor()
        }


# Alias for backward compatibility
HumanTiming = HumanTimingEngine