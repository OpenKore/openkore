"""
Anti-detection coordinator for OpenKore AI.

Coordinates all anti-detection subsystems to provide unified
human-like behavior simulation and bot detection prevention.
"""

from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

from .timing import HumanTimingEngine, TimingProfile, ReactionType
from .movement import MovementHumanizer, HumanPath
from .randomizer import BehaviorRandomizer, RandomBehavior
from .session import HumanSessionManager, PlaySession, SessionState
from .chat import HumanChatSimulator, ChatStyle, ChatResponse
from .pattern_breaker import PatternBreaker, DetectedPattern

logger = structlog.get_logger(__name__)


class DetectionRisk(str, Enum):
    """Risk levels for detection."""
    MINIMAL = "minimal"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class AntiDetectionReport(BaseModel):
    """Report on current detection risk."""
    
    model_config = ConfigDict(frozen=False)
    
    overall_risk: DetectionRisk = Field(description="Overall detection risk level")
    risk_factors: dict[str, float] = Field(default_factory=dict, description="Individual risk factors")
    recommendations: list[str] = Field(default_factory=list, description="Risk mitigation recommendations")
    recent_violations: list[str] = Field(default_factory=list, description="Recent suspicious behaviors")
    generated_at: datetime = Field(default_factory=datetime.now, description="Report generation time")
    
    # Component states
    session_duration_minutes: float = Field(default=0.0)
    behavior_entropy: float = Field(default=0.5)
    patterns_detected: int = Field(default=0)


class AntiDetectionCoordinator:
    """
    Coordinate all anti-detection systems.
    
    Integrates:
    - Timing humanizer
    - Movement humanizer
    - Behavior randomizer
    - Session manager
    - Chat simulator
    - Pattern breaker
    
    Provides unified API for human-like behavior.
    """
    
    def __init__(self, data_dir: Path, timing_profile: Optional[TimingProfile] = None):
        self.log = structlog.get_logger()
        self.data_dir = data_dir
        
        # Initialize all subsystems
        self.timing = HumanTimingEngine(profile=timing_profile)
        self.movement = MovementHumanizer(data_dir)
        self.randomizer = BehaviorRandomizer(data_dir)
        self.session = HumanSessionManager(data_dir)
        self.chat = HumanChatSimulator(style=ChatStyle.CASUAL, data_dir=data_dir)
        self.pattern_breaker = PatternBreaker(data_dir)
        
        # Risk tracking
        self.risk_history: list[AntiDetectionReport] = []
        
        self.log.info("anti_detection_coordinator_initialized", data_dir=str(data_dir))
        
    async def humanize_action(self, action: dict) -> dict:
        """
        Main entry point - humanize any action.
        Applies all relevant humanization.
        
        Args:
            action: Action dictionary with type and parameters
            
        Returns:
            Humanized action with delays and variations
        """
        humanized = action.copy()
        
        # Add timing delay
        timing = self.timing.get_action_delay(
            action.get("action_type", "unknown"),
            is_combat=action.get("is_combat", False)
        )
        humanized["delay_ms"] = timing.actual_delay_ms
        humanized["timing_info"] = {
            "base_delay": timing.base_delay_ms,
            "variance": timing.variance_ms,
            "was_delayed": timing.was_delayed_by_distraction
        }
        
        # Inject pattern-breaking variation
        if patterns := await self.pattern_breaker.analyze_patterns():
            critical_patterns = [p for p in patterns if p.is_critical]
            if critical_patterns:
                variation = await self.pattern_breaker.break_pattern(critical_patterns[0])
                humanized["pattern_variation"] = variation
        
        # Record action for pattern analysis
        self.pattern_breaker.record_action(humanized)
        
        # Update session stats
        if action.get("action_type"):
            self.session.record_action(action["action_type"])
        
        self.log.debug("action_humanized", action_type=action.get("action_type"), delay_ms=humanized["delay_ms"])
        
        return humanized
    
    async def get_action_delay(self, action_type: str, context: dict) -> int:
        """
        Get humanized delay before action.
        
        Args:
            action_type: Type of action
            context: Additional context
            
        Returns:
            Delay in milliseconds
        """
        is_combat = context.get("is_combat", False)
        timing = self.timing.get_action_delay(action_type, is_combat)
        
        # Apply session state modifiers
        if self.session.current_session:
            behavior = self.session.get_session_behavior()
            delay = int(timing.actual_delay_ms * behavior.action_speed_multiplier)
            return delay
        
        return timing.actual_delay_ms
    
    async def humanize_path(
        self,
        start: Tuple[int, int],
        end: Tuple[int, int],
        urgency: float = 0.5
    ) -> HumanPath:
        """
        Get humanized movement path.
        
        Args:
            start: Starting position
            end: Ending position
            urgency: 0.0 (casual) to 1.0 (emergency)
            
        Returns:
            HumanPath with natural characteristics
        """
        return self.movement.humanize_path(start, end, urgency)
    
    async def should_inject_behavior(self) -> Tuple[bool, Optional[RandomBehavior]]:
        """
        Check if random behavior should be injected.
        
        Returns:
            (should_inject, behavior)
        """
        if not self.session.current_session:
            return False, None
        
        current_activity = "idle"  # Default
        time_in_activity = self.session.current_session.duration_seconds * 1000
        
        return self.randomizer.should_inject_random_behavior(current_activity, time_in_activity)
    
    async def humanize_chat(
        self,
        message: str,
        emotion: str = "neutral",
        typo_chance: float = 0.02
    ) -> ChatResponse:
        """
        Humanize a chat message.
        
        Args:
            message: Original message
            emotion: Emotional context
            typo_chance: Probability of typo
            
        Returns:
            Humanized ChatResponse
        """
        return self.chat.humanize_response(message, emotion, typo_chance)
    
    async def assess_detection_risk(self) -> AntiDetectionReport:
        """
        Assess current detection risk.
        Analyze all factors.
        
        Returns:
            Comprehensive risk assessment
        """
        risk_factors = {}
        recommendations = []
        violations = []
        
        # Check pattern detection
        patterns = await self.pattern_breaker.analyze_patterns()
        if patterns:
            critical_count = len([p for p in patterns if p.is_critical])
            high_count = len([p for p in patterns if p.risk_level == "high"])
            
            risk_factors["patterns"] = min(1.0, (critical_count * 0.5 + high_count * 0.3))
            
            if critical_count > 0:
                violations.append(f"{critical_count} critical patterns detected")
                recommendations.append("Break repetitive patterns immediately")
        
        # Check behavior entropy
        entropy = self.pattern_breaker.calculate_behavior_entropy()
        if entropy < 0.5:
            risk_factors["entropy"] = 1.0 - entropy
            violations.append(f"Low behavior entropy ({entropy:.2f})")
            recommendations.append("Increase action randomness")
        
        # Check session duration
        if self.session.current_session:
            duration_hours = self.session.current_session.duration_hours
            
            if duration_hours > 4:
                risk_factors["session_duration"] = min(1.0, (duration_hours - 4) / 4)
                recommendations.append("Consider taking a break or ending session")
            
            # Check for AFK behavior
            if self.session.current_session.afk_minutes < duration_hours * 2:
                violations.append("Insufficient AFK time for session length")
                recommendations.append("Take occasional breaks")
        
        # Check timing patterns
        timing_stats = self.timing.get_session_stats()
        if timing_stats["current_fatigue"] > 1.3:
            risk_factors["fatigue"] = (timing_stats["current_fatigue"] - 1.0) / 0.5
            recommendations.append("Excessive fatigue - consider ending session")
        
        # Calculate overall risk
        if risk_factors:
            avg_risk = sum(risk_factors.values()) / len(risk_factors)
            
            if avg_risk >= 0.8:
                overall_risk = DetectionRisk.CRITICAL
            elif avg_risk >= 0.6:
                overall_risk = DetectionRisk.HIGH
            elif avg_risk >= 0.4:
                overall_risk = DetectionRisk.MEDIUM
            elif avg_risk >= 0.2:
                overall_risk = DetectionRisk.LOW
            else:
                overall_risk = DetectionRisk.MINIMAL
        else:
            overall_risk = DetectionRisk.MINIMAL
        
        report = AntiDetectionReport(
            overall_risk=overall_risk,
            risk_factors=risk_factors,
            recommendations=recommendations,
            recent_violations=violations,
            session_duration_minutes=self.session.current_session.duration_seconds / 60.0 if self.session.current_session else 0.0,
            behavior_entropy=entropy,
            patterns_detected=len(patterns)
        )
        
        self.risk_history.append(report)
        if len(self.risk_history) > 100:
            self.risk_history.pop(0)
        
        if overall_risk in [DetectionRisk.HIGH, DetectionRisk.CRITICAL]:
            self.log.warning(
                "high_detection_risk",
                risk=overall_risk.value,
                factors=risk_factors,
                violations=violations
            )
        
        return report
    
    async def get_mitigation_actions(self, risk_level: DetectionRisk) -> list[dict]:
        """
        Get actions to reduce detection risk.
        Varies based on risk level.
        
        Args:
            risk_level: Current risk level
            
        Returns:
            List of mitigation actions
        """
        actions = []
        
        if risk_level == DetectionRisk.CRITICAL:
            actions.extend([
                {"action": "take_long_break", "duration_minutes": 15},
                {"action": "change_activity", "new_activity": "random"},
                {"action": "inject_afk_period", "duration_minutes": 5}
            ])
        
        elif risk_level == DetectionRisk.HIGH:
            actions.extend([
                {"action": "take_short_break", "duration_minutes": 5},
                {"action": "increase_randomness", "factor": 0.5},
                {"action": "vary_next_n_actions", "count": 10}
            ])
        
        elif risk_level == DetectionRisk.MEDIUM:
            actions.extend([
                {"action": "inject_random_behaviors", "count": 3},
                {"action": "vary_timing", "variance_increase": 0.2}
            ])
        
        # Add pattern-specific mitigations
        suggestions = await self.pattern_breaker.get_pattern_breaking_suggestions()
        actions.extend(suggestions)
        
        return actions
    
    async def apply_emergency_humanization(self) -> None:
        """
        Emergency behavior change when risk is critical.
        Take break, change activity, etc.
        """
        self.log.warning("applying_emergency_humanization")
        
        # Force a break
        await self.session.simulate_afk(duration_seconds=600)  # 10 minute break
        
        # Reset timing profile to increase variance
        self.timing.profile.fatigue_multiplier = 1.2
        self.timing.profile.micro_delay_chance = 0.5
        
        # Clear recent history to start fresh
        self.pattern_breaker.action_history.clear()
        self.timing.consecutive_same_action = 0
        
        self.log.info("emergency_humanization_applied")
    
    async def record_action(self, action: dict) -> None:
        """
        Record action for pattern analysis.
        
        Args:
            action: Action dictionary
        """
        self.pattern_breaker.record_action(action)
        
        # Update timing engine state
        self.timing.action_count += 1
        self.timing.last_action_time = datetime.now()
    
    def get_session_status(self) -> dict:
        """Get current session status."""
        return self.session.get_session_stats()
    
    async def start_session(self) -> PlaySession:
        """Start a new play session."""
        session = await self.session.start_session()
        self.log.info("session_started_through_coordinator", session_id=session.session_id)
        return session
    
    async def end_session(self, reason: str = "User initiated") -> None:
        """End the current session."""
        await self.session.end_session(reason)
        self.log.info("session_ended_through_coordinator", reason=reason)
    
    def get_comprehensive_stats(self) -> dict:
        """Get comprehensive statistics from all subsystems."""
        return {
            "timing": self.timing.get_session_stats(),
            "movement": self.movement.get_movement_stats(),
            "randomizer": self.randomizer.get_behavior_stats(),
            "session": self.session.get_session_stats(),
            "chat": self.chat.get_chat_stats(),
            "patterns": self.pattern_breaker.get_pattern_stats(),
            "risk_assessment": {
                "current_risk": self.risk_history[-1].overall_risk.value if self.risk_history else "minimal",
                "risk_history_count": len(self.risk_history)
            }
        }