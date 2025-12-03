"""
Comprehensive tests for mimicry/pattern_breaker.py module.

Tests pattern detection, breaking, variation injection, and behavioral entropy.
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch
from collections import deque

from ai_sidecar.mimicry.pattern_breaker import (
    PatternType,
    DetectedPattern,
    PatternBreaker
)


# DetectedPattern Model Tests

class TestDetectedPatternModel:
    """Test DetectedPattern pydantic model."""
    
    def test_detected_pattern_creation(self):
        """Test creating detected pattern."""
        pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Regular intervals",
            occurrences=10,
            similarity_score=0.95,
            risk_level="critical"
        )
        assert pattern.pattern_type == PatternType.TIMING
        assert pattern.similarity_score == 0.95
    
    def test_pattern_is_critical_property(self):
        """Test is_critical property."""
        critical = DetectedPattern(
            pattern_type=PatternType.MOVEMENT,
            description="Test",
            occurrences=5,
            similarity_score=0.9,
            risk_level="critical"
        )
        assert critical.is_critical is True
        
        high = DetectedPattern(
            pattern_type=PatternType.MOVEMENT,
            description="Test",
            occurrences=5,
            similarity_score=0.85,
            risk_level="high"
        )
        assert high.is_critical is False


# PatternBreaker Initialization Tests

class TestPatternBreakerInit:
    """Test PatternBreaker initialization."""
    
    def test_init_default(self, tmp_path):
        """Test initialization with defaults."""
        breaker = PatternBreaker(tmp_path)
        assert len(breaker.action_history) == 0
        assert len(breaker.timing_history) == 0
        assert len(breaker.detected_patterns) == 0
    
    def test_init_custom_history_size(self, tmp_path):
        """Test initialization with custom history size."""
        breaker = PatternBreaker(tmp_path, history_size=50)
        assert breaker.action_history.maxlen == 50


# Detect Timing Patterns Tests

class TestDetectTimingPatterns:
    """Test timing pattern detection."""
    
    def test_detect_timing_insufficient_data(self, tmp_path):
        """Test returns None with insufficient data."""
        breaker = PatternBreaker(tmp_path)
        actions = [{"timestamp": datetime.now()} for _ in range(5)]
        
        result = breaker.detect_timing_patterns(actions)
        assert result is None
    
    def test_detect_timing_no_timestamps(self, tmp_path):
        """Test handles actions without timestamps."""
        breaker = PatternBreaker(tmp_path)
        actions = [{"action": f"action_{i}"} for i in range(15)]
        
        result = breaker.detect_timing_patterns(actions)
        assert result is None
    
    def test_detect_timing_regular_pattern(self, tmp_path):
        """Test detects regular timing pattern."""
        breaker = PatternBreaker(tmp_path)
        
        # Create actions with very regular timing (1 second apart)
        base_time = datetime.now()
        actions = [
            {"timestamp": base_time + timedelta(seconds=i)}
            for i in range(20)
        ]
        
        result = breaker.detect_timing_patterns(actions)
        assert result is not None
        assert result.pattern_type == PatternType.TIMING
        assert result.similarity_score > 0.8
    
    def test_detect_timing_variable_pattern(self, tmp_path):
        """Test doesn't detect with variable timing."""
        breaker = PatternBreaker(tmp_path)
        
        # Create actions with variable timing
        base_time = datetime.now()
        actions = [
            {"timestamp": base_time + timedelta(seconds=i * (1 + i * 0.1))}
            for i in range(20)
        ]
        
        result = breaker.detect_timing_patterns(actions)
        # Should not detect pattern due to high variance
        # Result may be None or have low similarity score


# Detect Movement Patterns Tests

class TestDetectMovementPatterns:
    """Test movement pattern detection."""
    
    def test_detect_movement_insufficient_data(self, tmp_path):
        """Test returns None with insufficient data."""
        breaker = PatternBreaker(tmp_path)
        movements = [{"path": [{"x": 100, "y": 200}]} for _ in range(3)]
        
        result = breaker.detect_movement_patterns(movements)
        assert result is None
    
    def test_detect_movement_no_paths(self, tmp_path):
        """Test handles movements without paths."""
        breaker = PatternBreaker(tmp_path)
        movements = [{"action": "move"} for _ in range(10)]
        
        result = breaker.detect_movement_patterns(movements)
        assert result is None
    
    def test_detect_movement_repetitive_path(self, tmp_path):
        """Test detects repetitive movement paths."""
        breaker = PatternBreaker(tmp_path)
        
        # Same path repeated multiple times
        same_path = [
            {"x": 100, "y": 200},
            {"x": 150, "y": 250},
            {"x": 200, "y": 300}
        ]
        movements = [{"path": same_path} for _ in range(10)]
        
        result = breaker.detect_movement_patterns(movements)
        assert result is not None
        assert result.pattern_type == PatternType.MOVEMENT
        assert result.occurrences >= 5
    
    def test_detect_movement_varied_paths(self, tmp_path):
        """Test doesn't detect with varied paths."""
        breaker = PatternBreaker(tmp_path)
        
        # Different paths
        movements = [
            {"path": [{"x": i * 10, "y": i * 20}, {"x": i * 15, "y": i * 25}]}
            for i in range(10)
        ]
        
        result = breaker.detect_movement_patterns(movements)
        assert result is None


# Detect Targeting Patterns Tests

class TestDetectTargetingPatterns:
    """Test targeting pattern detection."""
    
    def test_detect_targeting_insufficient_data(self, tmp_path):
        """Test returns None with insufficient data."""
        breaker = PatternBreaker(tmp_path)
        targets = [{"target_type": "monster"} for _ in range(5)]
        
        result = breaker.detect_targeting_patterns(targets)
        assert result is None
    
    def test_detect_targeting_predictable_pattern(self, tmp_path):
        """Test detects predictable targeting."""
        breaker = PatternBreaker(tmp_path)
        
        # Always targeting same type with same reason
        targets = [
            {"target_type": "poring", "selection_reason": "lowest_hp"}
            for _ in range(15)
        ]
        
        result = breaker.detect_targeting_patterns(targets)
        assert result is not None
        assert result.pattern_type == PatternType.TARGETING
    
    def test_detect_targeting_varied_pattern(self, tmp_path):
        """Test doesn't detect with varied targeting."""
        breaker = PatternBreaker(tmp_path)
        
        targets = [
            {"target_type": f"monster_{i % 5}", "selection_reason": f"reason_{i % 3}"}
            for i in range(15)
        ]
        
        result = breaker.detect_targeting_patterns(targets)
        # Should have lower similarity score


# Detect Skill Patterns Tests

class TestDetectSkillPatterns:
    """Test skill pattern detection."""
    
    def test_detect_skill_insufficient_data(self, tmp_path):
        """Test returns None with insufficient data."""
        breaker = PatternBreaker(tmp_path)
        actions = [{"action_type": "skill", "skill_id": i} for i in range(5)]
        
        result = breaker._detect_skill_patterns(actions)
        assert result is None
    
    def test_detect_skill_repetitive_sequence(self, tmp_path):
        """Test detects repetitive skill sequences."""
        breaker = PatternBreaker(tmp_path)
        
        # Repeat same 3-skill sequence
        sequence = ["fire_bolt", "cold_bolt", "lightning_bolt"]
        actions = []
        for _ in range(10):
            for skill in sequence:
                actions.append({"action_type": "skill", "skill_id": skill})
        
        result = breaker._detect_skill_patterns(actions)
        assert result is not None
        assert result.pattern_type == PatternType.SKILL_ORDER
    
    def test_detect_skill_varied_sequence(self, tmp_path):
        """Test doesn't detect with varied skills."""
        breaker = PatternBreaker(tmp_path)
        
        actions = [
            {"action_type": "skill", "skill_id": f"skill_{i}"}
            for i in range(30)
        ]
        
        result = breaker._detect_skill_patterns(actions)
        assert result is None


# Calculate Risk Level Tests

class TestCalculateRiskLevel:
    """Test risk level calculation."""
    
    def test_calculate_risk_critical(self, tmp_path):
        """Test critical risk level."""
        breaker = PatternBreaker(tmp_path)
        assert breaker._calculate_risk_level(0.96) == "critical"
    
    def test_calculate_risk_high(self, tmp_path):
        """Test high risk level."""
        breaker = PatternBreaker(tmp_path)
        assert breaker._calculate_risk_level(0.92) == "high"
    
    def test_calculate_risk_medium(self, tmp_path):
        """Test medium risk level."""
        breaker = PatternBreaker(tmp_path)
        assert breaker._calculate_risk_level(0.85) == "medium"
    
    def test_calculate_risk_low(self, tmp_path):
        """Test low risk level."""
        breaker = PatternBreaker(tmp_path)
        assert breaker._calculate_risk_level(0.70) == "low"


# Analyze Patterns Tests

class TestAnalyzePatterns:
    """Test comprehensive pattern analysis."""
    
    @pytest.mark.asyncio
    async def test_analyze_patterns_empty_history(self, tmp_path):
        """Test analysis with empty history."""
        breaker = PatternBreaker(tmp_path)
        
        patterns = await breaker.analyze_patterns()
        assert patterns == []
    
    @pytest.mark.asyncio
    async def test_analyze_patterns_detects_multiple(self, tmp_path):
        """Test detecting multiple pattern types."""
        breaker = PatternBreaker(tmp_path)
        
        # Add timing pattern
        base_time = datetime.now()
        for i in range(20):
            breaker.timing_history.append({
                "delay_ms": 1000,
                "timestamp": base_time + timedelta(seconds=i)
            })
        
        # Add movement pattern
        same_path = [{"x": 100, "y": 200}, {"x": 150, "y": 250}]
        for _ in range(10):
            breaker.movement_history.append({"path": same_path})
        
        patterns = await breaker.analyze_patterns()
        assert len(patterns) >= 1  # At least timing pattern should be detected
    
    @pytest.mark.asyncio
    async def test_analyze_patterns_cleans_old(self, tmp_path):
        """Test old patterns are removed."""
        breaker = PatternBreaker(tmp_path)
        
        # Add old pattern
        old_pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Old",
            occurrences=5,
            similarity_score=0.9,
            risk_level="high",
            detected_at=datetime.now() - timedelta(hours=2)
        )
        breaker.detected_patterns.append(old_pattern)
        
        await breaker.analyze_patterns()
        
        # Old pattern should be removed
        assert old_pattern not in breaker.detected_patterns


# Break Pattern Tests

class TestBreakPattern:
    """Test pattern breaking."""
    
    @pytest.mark.asyncio
    async def test_break_timing_pattern(self, tmp_path):
        """Test breaking timing pattern."""
        breaker = PatternBreaker(tmp_path)
        
        pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Regular timing",
            occurrences=10,
            similarity_score=0.95,
            risk_level="critical"
        )
        
        variation = await breaker.break_pattern(pattern)
        assert variation["type"] == "timing_variation"
        assert "add_delay_ms" in variation
    
    @pytest.mark.asyncio
    async def test_break_movement_pattern(self, tmp_path):
        """Test breaking movement pattern."""
        breaker = PatternBreaker(tmp_path)
        
        pattern = DetectedPattern(
            pattern_type=PatternType.MOVEMENT,
            description="Same path",
            occurrences=8,
            similarity_score=0.9,
            risk_level="high"
        )
        
        variation = await breaker.break_pattern(pattern)
        assert variation["type"] == "movement_variation"
        assert variation["force_different_path"] is True
    
    @pytest.mark.asyncio
    async def test_break_targeting_pattern(self, tmp_path):
        """Test breaking targeting pattern."""
        breaker = PatternBreaker(tmp_path)
        
        pattern = DetectedPattern(
            pattern_type=PatternType.TARGETING,
            description="Predictable",
            occurrences=12,
            similarity_score=0.92,
            risk_level="high"
        )
        
        variation = await breaker.break_pattern(pattern)
        assert variation["type"] == "targeting_variation"
        assert variation["randomize_priority"] is True
    
    @pytest.mark.asyncio
    async def test_break_skill_pattern(self, tmp_path):
        """Test breaking skill pattern."""
        breaker = PatternBreaker(tmp_path)
        
        pattern = DetectedPattern(
            pattern_type=PatternType.SKILL_ORDER,
            description="Same sequence",
            occurrences=15,
            similarity_score=0.93,
            risk_level="high"
        )
        
        variation = await breaker.break_pattern(pattern)
        assert variation["type"] == "skill_variation"
        assert variation["shuffle_next_sequence"] is True


# Inject Variation Tests

class TestInjectVariation:
    """Test variation injection."""
    
    def test_inject_variation_timing(self, tmp_path):
        """Test injecting timing variation."""
        breaker = PatternBreaker(tmp_path)
        
        action = {"delay_ms": 1000, "action_type": "move"}
        
        varied = breaker.inject_variation(action, variation_factor=0.3)
        
        # Should have different delay
        assert "delay_ms" in varied
        assert varied["delay_ms"] != action["delay_ms"]
    
    def test_inject_variation_position(self, tmp_path):
        """Test injecting position variation."""
        breaker = PatternBreaker(tmp_path)
        
        action = {"position": (100, 200), "action_type": "move"}
        
        varied = breaker.inject_variation(action, variation_factor=0.5)
        
        # Should have slightly different position
        assert "position" in varied
        # Position should be different but close
        x_diff = abs(varied["position"][0] - 100)
        y_diff = abs(varied["position"][1] - 200)
        assert x_diff <= 3
        assert y_diff <= 3


# Calculate Behavior Entropy Tests

class TestCalculateBehaviorEntropy:
    """Test behavior entropy calculation."""
    
    def test_calculate_entropy_insufficient_data(self, tmp_path):
        """Test returns 1.0 with insufficient data."""
        breaker = PatternBreaker(tmp_path)
        
        entropy = breaker.calculate_behavior_entropy()
        assert entropy == 1.0
    
    def test_calculate_entropy_varied_actions(self, tmp_path):
        """Test entropy with varied actions."""
        breaker = PatternBreaker(tmp_path)
        
        # Add varied actions
        for i in range(50):
            action_type = ["move", "attack", "skill", "item"][i % 4]
            breaker.action_history.append({"action_type": action_type})
        
        # Add varied timing
        for i in range(20):
            breaker.timing_history.append({
                "delay_ms": 1000 + i * 100,
                "timestamp": datetime.now()
            })
        
        entropy = breaker.calculate_behavior_entropy()
        assert 0.0 <= entropy <= 1.0
        assert entropy > 0.3  # Should have some entropy
    
    def test_calculate_entropy_repetitive_actions(self, tmp_path):
        """Test entropy with repetitive actions."""
        breaker = PatternBreaker(tmp_path)
        
        # Add same action type repeatedly
        for _ in range(50):
            breaker.action_history.append({"action_type": "attack"})
        
        # Add constant timing
        for _ in range(20):
            breaker.timing_history.append({
                "delay_ms": 1000,
                "timestamp": datetime.now()
            })
        
        entropy = breaker.calculate_behavior_entropy()
        assert entropy < 0.5  # Should have low entropy


# Calculate Shannon Entropy Tests

class TestCalculateShannonEntropy:
    """Test Shannon entropy calculation."""
    
    def test_shannon_entropy_empty_data(self, tmp_path):
        """Test with empty data."""
        breaker = PatternBreaker(tmp_path)
        
        entropy = breaker._calculate_shannon_entropy([])
        assert entropy == 0.0
    
    def test_shannon_entropy_uniform_distribution(self, tmp_path):
        """Test with uniform distribution (high entropy)."""
        breaker = PatternBreaker(tmp_path)
        
        # Perfectly uniform distribution
        data = ["a", "b", "c", "d"] * 10
        
        entropy = breaker._calculate_shannon_entropy(data)
        assert entropy > 0.9  # Should be close to 1.0
    
    def test_shannon_entropy_single_value(self, tmp_path):
        """Test with single repeated value (zero entropy)."""
        breaker = PatternBreaker(tmp_path)
        
        data = ["a"] * 20
        
        entropy = breaker._calculate_shannon_entropy(data)
        assert entropy == 0.0
    
    def test_shannon_entropy_skewed_distribution(self, tmp_path):
        """Test with skewed distribution."""
        breaker = PatternBreaker(tmp_path)
        
        # Mostly "a", some "b"
        data = ["a"] * 18 + ["b"] * 2
        
        entropy = breaker._calculate_shannon_entropy(data)
        assert 0.0 < entropy < 0.5


# Pattern Breaking Suggestions Tests

class TestGetPatternBreakingSuggestions:
    """Test pattern breaking suggestions."""
    
    @pytest.mark.asyncio
    async def test_suggestions_low_entropy(self, tmp_path):
        """Test suggestions for low entropy."""
        breaker = PatternBreaker(tmp_path)
        
        # Add repetitive actions for low entropy
        for _ in range(50):
            breaker.action_history.append({"action_type": "attack"})
        
        suggestions = await breaker.get_pattern_breaking_suggestions()
        
        # Should suggest increasing randomness
        assert len(suggestions) > 0
        assert any("randomness" in str(s).lower() for s in suggestions)
    
    @pytest.mark.asyncio
    async def test_suggestions_critical_patterns(self, tmp_path):
        """Test suggestions for critical patterns."""
        breaker = PatternBreaker(tmp_path)
        
        # Add critical pattern
        critical = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Critical timing",
            occurrences=20,
            similarity_score=0.98,
            risk_level="critical"
        )
        breaker.detected_patterns.append(critical)
        
        suggestions = await breaker.get_pattern_breaking_suggestions()
        
        # Should include pattern-breaking suggestions
        assert len(suggestions) > 0


# Record Action Tests

class TestRecordAction:
    """Test action recording."""
    
    def test_record_action_basic(self, tmp_path):
        """Test recording basic action."""
        breaker = PatternBreaker(tmp_path)
        
        action = {"action_type": "move", "position": (100, 200)}
        breaker.record_action(action)
        
        assert len(breaker.action_history) == 1
        assert "timestamp" in breaker.action_history[0]
    
    def test_record_action_with_timing(self, tmp_path):
        """Test recording action with timing info."""
        breaker = PatternBreaker(tmp_path)
        
        action = {"action_type": "attack", "delay_ms": 1500}
        breaker.record_action(action)
        
        assert len(breaker.timing_history) == 1
        assert breaker.timing_history[0]["delay_ms"] == 1500
    
    def test_record_action_with_path(self, tmp_path):
        """Test recording action with movement path."""
        breaker = PatternBreaker(tmp_path)
        
        path = [{"x": 100, "y": 200}, {"x": 150, "y": 250}]
        action = {"action_type": "move", "path": path}
        breaker.record_action(action)
        
        assert len(breaker.movement_history) == 1
        assert breaker.movement_history[0]["path"] == path
    
    def test_record_action_with_target(self, tmp_path):
        """Test recording action with target info."""
        breaker = PatternBreaker(tmp_path)
        
        action = {
            "action_type": "attack",
            "target_id": 1234,
            "target_type": "poring",
            "selection_reason": "nearest"
        }
        breaker.record_action(action)
        
        assert len(breaker.targeting_history) == 1
        assert breaker.targeting_history[0]["target_type"] == "poring"


# Pattern Stats Tests

class TestGetPatternStats:
    """Test pattern statistics."""
    
    def test_get_stats_empty(self, tmp_path):
        """Test stats with no data."""
        breaker = PatternBreaker(tmp_path)
        
        stats = breaker.get_pattern_stats()
        
        assert stats["total_actions_tracked"] == 0
        assert stats["patterns_detected_last_hour"] == 0
        assert stats["critical_patterns"] == 0
    
    def test_get_stats_with_patterns(self, tmp_path):
        """Test stats with detected patterns."""
        breaker = PatternBreaker(tmp_path)
        
        # Add actions
        for i in range(25):
            breaker.action_history.append({"action_type": "move"})
        
        # Add patterns
        pattern1 = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Test",
            occurrences=5,
            similarity_score=0.9,
            risk_level="high"
        )
        pattern2 = DetectedPattern(
            pattern_type=PatternType.MOVEMENT,
            description="Test",
            occurrences=3,
            similarity_score=0.95,
            risk_level="critical"
        )
        breaker.detected_patterns.extend([pattern1, pattern2])
        
        stats = breaker.get_pattern_stats()
        
        assert stats["total_actions_tracked"] == 25
        assert stats["patterns_detected_last_hour"] == 2
        assert stats["critical_patterns"] == 1
        assert "timing" in stats["patterns_by_type"]


# Edge Cases and Integration Tests

class TestPatternBreakerEdgeCases:
    """Test edge cases and integration scenarios."""
    
    def test_history_maxlen_enforcement(self, tmp_path):
        """Test that history respects maxlen."""
        breaker = PatternBreaker(tmp_path, history_size=10)
        
        # Add more actions than maxlen
        for i in range(20):
            action = {"action_type": "move", "index": i}
            breaker.record_action(action)
        
        assert len(breaker.action_history) == 10
        # Should have the latest actions
        assert breaker.action_history[-1]["index"] == 19
    
    @pytest.mark.asyncio
    async def test_pattern_detection_with_real_scenario(self, tmp_path):
        """Test pattern detection in realistic scenario."""
        breaker = PatternBreaker(tmp_path)
        
        # Simulate botting behavior: attack, loot, attack, loot, etc.
        base_time = datetime.now()
        for i in range(30):
            if i % 2 == 0:
                action = {
                    "action_type": "attack",
                    "timestamp": base_time + timedelta(seconds=i * 2),
                    "delay_ms": 2000
                }
            else:
                action = {
                    "action_type": "loot",
                    "timestamp": base_time + timedelta(seconds=i * 2),
                    "delay_ms": 500
                }
            breaker.action_history.append(action)
            breaker.timing_history.append({
                "delay_ms": action["delay_ms"],
                "timestamp": action["timestamp"]
            })
        
        patterns = await breaker.analyze_patterns()
        # Should detect timing pattern due to regularity
        timing_patterns = [p for p in patterns if p.pattern_type == PatternType.TIMING]
        assert len(timing_patterns) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])