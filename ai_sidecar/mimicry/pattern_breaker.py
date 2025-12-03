"""
Pattern detection and breaking for anti-detection.

Analyzes recent actions for detectable patterns and injects variations
to prevent bot detection through behavioral pattern analysis.
"""

import math
import statistics
from collections import Counter, deque
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class PatternType(str, Enum):
    """Types of detectable patterns."""
    TIMING = "timing"               # Regular intervals
    MOVEMENT = "movement"           # Same paths
    TARGETING = "targeting"         # Always same priority
    SKILL_ORDER = "skill_order"     # Same skill sequence
    CHAT = "chat"                   # Scripted responses
    FARMING = "farming"             # Same farming route


class DetectedPattern(BaseModel):
    """A detected repetitive pattern."""
    
    model_config = ConfigDict(frozen=False)
    
    pattern_type: PatternType = Field(description="Type of pattern detected")
    description: str = Field(description="Human-readable description")
    occurrences: int = Field(ge=1, description="Number of times observed")
    similarity_score: float = Field(ge=0.0, le=1.0, description="0.0-1.0, 1.0 = identical")
    risk_level: str = Field(description="low, medium, high, critical")
    detected_at: datetime = Field(default_factory=datetime.now)
    
    @property
    def is_critical(self) -> bool:
        """Check if pattern is critical risk."""
        return self.risk_level == "critical"


class PatternBreaker:
    """
    Detect and break repetitive patterns.
    
    Features:
    - Pattern detection algorithms
    - Automatic pattern breaking
    - Variation injection
    - Historical analysis
    - Self-monitoring for bot-like behavior
    """
    
    def __init__(self, data_dir: Path | None = None, history_size: int = 100):
        self.log = structlog.get_logger()
        self.data_dir = data_dir or Path("data")
        
        # Action history with limited size
        self.action_history: deque = deque(maxlen=history_size)
        self.timing_history: deque = deque(maxlen=history_size)
        self.movement_history: deque = deque(maxlen=50)
        self.targeting_history: deque = deque(maxlen=50)
        
        # Detected patterns
        self.detected_patterns: list[DetectedPattern] = []
        
        # Pattern thresholds
        self.timing_variance_threshold = 0.15  # 15% variance acceptable
        self.similarity_threshold = 0.85        # 85% similarity is suspicious
        self.repetition_threshold = 5           # 5+ identical = pattern
        
        self.log.info("pattern_breaker_initialized", history_size=history_size)
        
    def should_break_pattern(self, activity_type: str, duration_minutes: int) -> bool:
        """
        Determine if pattern should be broken.
        
        Args:
            activity_type: Type of activity (combat, farming, etc.)
            duration_minutes: How long in this activity
        
        Returns:
            True if pattern should be broken
        """
        # Break pattern if activity too long
        if duration_minutes > 30:
            return True
        
        # Check entropy
        entropy = self.calculate_behavior_entropy()
        if entropy < 0.5:
            return True
        
        # Check for critical patterns
        return any(p.is_critical for p in self.detected_patterns)
    
    async def analyze_patterns(self) -> list[DetectedPattern]:
        """
        Analyze recent actions for patterns.
        Uses multiple algorithms.
        """
        patterns = []
        
        # Analyze different pattern types
        if timing_pattern := self.detect_timing_patterns(list(self.timing_history)):
            patterns.append(timing_pattern)
        
        if movement_pattern := self.detect_movement_patterns(list(self.movement_history)):
            patterns.append(movement_pattern)
        
        if targeting_pattern := self.detect_targeting_patterns(list(self.targeting_history)):
            patterns.append(targeting_pattern)
        
        if skill_pattern := self._detect_skill_patterns(list(self.action_history)):
            patterns.append(skill_pattern)
        
        # Store detected patterns
        self.detected_patterns.extend(patterns)
        
        # Keep only recent patterns (last hour)
        cutoff = datetime.now() - timedelta(hours=1)
        self.detected_patterns = [p for p in self.detected_patterns if p.detected_at > cutoff]
        
        if patterns:
            self.log.warning("patterns_detected", count=len(patterns), types=[p.pattern_type.value for p in patterns])
        
        return patterns
    
    def detect_timing_patterns(self, actions: list[dict]) -> Optional[DetectedPattern]:
        """
        Detect regular timing intervals.
        Exact same delays = bot behavior.
        """
        if len(actions) < 10:
            return None
        
        # Extract time differences between actions
        delays = []
        for i in range(1, len(actions)):
            if "timestamp" in actions[i] and "timestamp" in actions[i-1]:
                delay = (actions[i]["timestamp"] - actions[i-1]["timestamp"]).total_seconds()
                delays.append(delay)
        
        if len(delays) < 5:
            return None
        
        # Calculate variance
        mean_delay = statistics.mean(delays)
        if mean_delay == 0:
            return None
        
        variance = statistics.stdev(delays) / mean_delay if len(delays) > 1 else 0
        
        # Low variance indicates regular timing
        if variance < self.timing_variance_threshold:
            similarity_score = 1.0 - variance
            risk_level = self._calculate_risk_level(similarity_score)
            
            return DetectedPattern(
                pattern_type=PatternType.TIMING,
                description=f"Regular timing interval detected (mean: {mean_delay:.2f}s, variance: {variance:.3f})",
                occurrences=len(delays),
                similarity_score=similarity_score,
                risk_level=risk_level
            )
        
        return None
    
    def detect_movement_patterns(self, movements: list[dict]) -> Optional[DetectedPattern]:
        """
        Detect repetitive movement paths.
        Same farming route = suspicious.
        """
        if len(movements) < 5:
            return None
        
        # Compare recent paths for similarity
        path_strings = []
        for move in movements:
            if "path" in move:
                # Convert path to string for comparison
                path_str = "->".join([f"{p['x']},{p['y']}" for p in move["path"][:5]])  # First 5 points
                path_strings.append(path_str)
        
        if len(path_strings) < 5:
            return None
        
        # Count identical paths
        path_counts = Counter(path_strings)
        max_count = max(path_counts.values())
        
        if max_count >= self.repetition_threshold:
            similarity_score = max_count / len(path_strings)
            risk_level = self._calculate_risk_level(similarity_score)
            
            return DetectedPattern(
                pattern_type=PatternType.MOVEMENT,
                description=f"Repetitive movement path detected ({max_count} identical paths)",
                occurrences=max_count,
                similarity_score=similarity_score,
                risk_level=risk_level
            )
        
        return None
    
    def detect_targeting_patterns(self, targets: list[dict]) -> Optional[DetectedPattern]:
        """
        Detect predictable targeting.
        Always targeting same mob type first = bot.
        """
        if len(targets) < 10:
            return None
        
        # Extract target selection criteria
        target_criteria = []
        for target in targets:
            if "target_type" in target:
                criteria = target["target_type"]
                if "selection_reason" in target:
                    criteria += f"_{target['selection_reason']}"
                target_criteria.append(criteria)
        
        if len(target_criteria) < 5:
            return None
        
        # Count most common targeting pattern
        criteria_counts = Counter(target_criteria)
        max_count = max(criteria_counts.values())
        
        # If same criteria used too often
        if max_count / len(target_criteria) > self.similarity_threshold:
            similarity_score = max_count / len(target_criteria)
            risk_level = self._calculate_risk_level(similarity_score)
            
            return DetectedPattern(
                pattern_type=PatternType.TARGETING,
                description=f"Predictable targeting pattern detected",
                occurrences=max_count,
                similarity_score=similarity_score,
                risk_level=risk_level
            )
        
        return None
    
    def _detect_skill_patterns(self, actions: list[dict]) -> Optional[DetectedPattern]:
        """Detect repetitive skill usage sequences."""
        if len(actions) < 10:
            return None
        
        # Extract skill sequences
        skill_sequences = []
        current_sequence = []
        
        for action in actions:
            if action.get("action_type") == "skill":
                current_sequence.append(action.get("skill_id", "unknown"))
                if len(current_sequence) >= 3:
                    skill_sequences.append(tuple(current_sequence[-3:]))
        
        if len(skill_sequences) < 5:
            return None
        
        # Find repeated sequences
        sequence_counts = Counter(skill_sequences)
        max_count = max(sequence_counts.values())
        
        if max_count >= self.repetition_threshold:
            similarity_score = max_count / len(skill_sequences)
            risk_level = self._calculate_risk_level(similarity_score)
            
            return DetectedPattern(
                pattern_type=PatternType.SKILL_ORDER,
                description=f"Repetitive skill sequence detected",
                occurrences=max_count,
                similarity_score=similarity_score,
                risk_level=risk_level
            )
        
        return None
    
    def _calculate_risk_level(self, similarity_score: float) -> str:
        """Calculate risk level from similarity score."""
        if similarity_score >= 0.95:
            return "critical"
        elif similarity_score >= 0.90:
            return "high"
        elif similarity_score >= 0.80:
            return "medium"
        else:
            return "low"
    
    async def break_pattern(self, pattern: DetectedPattern) -> dict:
        """
        Generate action to break detected pattern.
        Returns variation to inject.
        """
        variations = {
            PatternType.TIMING: self._vary_timing,
            PatternType.MOVEMENT: self._vary_movement,
            PatternType.TARGETING: self._vary_targeting,
            PatternType.SKILL_ORDER: self._vary_skill_order
        }
        
        vary_func = variations.get(pattern.pattern_type)
        if vary_func:
            variation = vary_func(pattern)
            self.log.info("pattern_broken", type=pattern.pattern_type.value, variation=variation)
            return variation
        
        return {}
    
    def _vary_timing(self, pattern: DetectedPattern) -> dict:
        """Add timing variation to break timing pattern."""
        return {
            "type": "timing_variation",
            "add_delay_ms": int(1000 + (pattern.similarity_score * 2000)),
            "randomize_next_n": 5
        }
    
    def _vary_movement(self, pattern: DetectedPattern) -> dict:
        """Add movement variation to break movement pattern."""
        return {
            "type": "movement_variation",
            "force_different_path": True,
            "add_waypoint_count": 2,
            "increase_inefficiency": 0.2
        }
    
    def _vary_targeting(self, pattern: DetectedPattern) -> dict:
        """Add targeting variation to break targeting pattern."""
        return {
            "type": "targeting_variation",
            "prefer_suboptimal_next_n": 3,
            "randomize_priority": True
        }
    
    def _vary_skill_order(self, pattern: DetectedPattern) -> dict:
        """Add skill order variation to break skill pattern."""
        return {
            "type": "skill_variation",
            "shuffle_next_sequence": True,
            "skip_optimal_next_n": 2
        }
    
    def inject_variation(self, action: dict, variation_factor: float = 0.3) -> dict:
        """
        Inject variation into an action.
        Make it different from previous similar actions.
        """
        varied_action = action.copy()
        
        # Add timing variation
        if "delay_ms" in varied_action:
            variance = int(varied_action["delay_ms"] * variation_factor)
            varied_action["delay_ms"] += int((hash(str(datetime.now())) % (2 * variance)) - variance)
        
        # Add position variation for movement
        if "position" in varied_action:
            x, y = varied_action["position"]
            offset = int(3 * variation_factor)
            varied_action["position"] = (
                x + int((hash(str(datetime.now())) % (2 * offset)) - offset),
                y + int((hash(str(datetime.now().microsecond)) % (2 * offset)) - offset)
            )
        
        return varied_action
    
    def calculate_behavior_entropy(self) -> float:
        """
        Calculate randomness/entropy of recent behavior.
        Low entropy = bot-like, high entropy = human-like.
        Target: 0.6-0.8 for human-like behavior.
        """
        if len(self.action_history) < 10:
            return 1.0  # Not enough data
        
        # Calculate entropy across different dimensions
        entropies = []
        
        # Action type entropy
        action_types = [a.get("action_type", "unknown") for a in self.action_history]
        if action_types:
            entropies.append(self._calculate_shannon_entropy(action_types))
        
        # Timing entropy
        if len(self.timing_history) >= 5:
            timing_values = [t.get("delay_ms", 0) for t in self.timing_history]
            timing_variance = statistics.stdev(timing_values) / max(statistics.mean(timing_values), 1)
            entropies.append(min(timing_variance, 1.0))
        
        # Average entropy
        overall_entropy = statistics.mean(entropies) if entropies else 0.5
        
        return overall_entropy
    
    def _calculate_shannon_entropy(self, data: list) -> float:
        """Calculate Shannon entropy of a dataset."""
        if not data:
            return 0.0
        
        counts = Counter(data)
        total = len(data)
        
        entropy = 0.0
        for count in counts.values():
            if count > 0:
                probability = count / total
                entropy -= probability * math.log2(probability)
        
        # Normalize to 0-1 range
        max_entropy = math.log2(len(counts)) if len(counts) > 1 else 1.0
        normalized = entropy / max_entropy if max_entropy > 0 else 0.0
        
        return normalized
    
    async def get_pattern_breaking_suggestions(self) -> list[dict]:
        """
        Get suggestions to vary behavior.
        Proactive pattern prevention.
        """
        suggestions = []
        
        # Check if entropy is too low
        entropy = self.calculate_behavior_entropy()
        if entropy < 0.5:
            suggestions.append({
                "type": "increase_randomness",
                "reason": f"Low behavior entropy ({entropy:.2f})",
                "actions": ["inject_random_delays", "vary_action_order", "add_idle_behaviors"]
            })
        
        # Check for critical patterns
        critical_patterns = [p for p in self.detected_patterns if p.is_critical]
        for pattern in critical_patterns:
            suggestion = await self.break_pattern(pattern)
            suggestions.append(suggestion)
        
        return suggestions
    
    def record_action(self, action: dict) -> None:
        """Record an action for pattern analysis."""
        action["timestamp"] = datetime.now()
        self.action_history.append(action)
        
        # Record in specific histories
        if "delay_ms" in action:
            self.timing_history.append({"delay_ms": action["delay_ms"], "timestamp": action["timestamp"]})
        
        if "path" in action:
            self.movement_history.append({"path": action["path"], "timestamp": action["timestamp"]})
        
        if "target_id" in action:
            self.targeting_history.append({
                "target_type": action.get("target_type"),
                "selection_reason": action.get("selection_reason"),
                "timestamp": action["timestamp"]
            })
    
    def get_pattern_stats(self) -> dict:
        """Get pattern detection statistics."""
        recent_patterns = [p for p in self.detected_patterns if (datetime.now() - p.detected_at).total_seconds() < 3600]
        
        pattern_by_type = {}
        for pattern in recent_patterns:
            pattern_by_type[pattern.pattern_type.value] = pattern_by_type.get(pattern.pattern_type.value, 0) + 1
        
        return {
            "total_actions_tracked": len(self.action_history),
            "behavior_entropy": round(self.calculate_behavior_entropy(), 3),
            "patterns_detected_last_hour": len(recent_patterns),
            "patterns_by_type": pattern_by_type,
            "critical_patterns": len([p for p in recent_patterns if p.is_critical])
        }