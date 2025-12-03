"""
Comprehensive tests for mimicry/anti_detection.py module.

Tests anti-detection coordinator, risk assessment, humanization,
and mitigation strategies.
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.mimicry.anti_detection import (
    DetectionRisk,
    AntiDetectionReport,
    AntiDetectionCoordinator
)
from ai_sidecar.mimicry.timing import HumanTimingEngine, TimingProfile, ActionTiming
from ai_sidecar.mimicry.movement import HumanPath, PathPoint
from ai_sidecar.mimicry.randomizer import RandomBehavior, BehaviorCategory
from ai_sidecar.mimicry.session import PlaySession, SessionState
from ai_sidecar.mimicry.chat import ChatResponse
from ai_sidecar.mimicry.pattern_breaker import DetectedPattern, PatternType


# DetectionRisk Enum Tests

class TestDetectionRiskEnum:
    """Test DetectionRisk enum."""
    
    def test_detection_risk_values(self):
        """Test detection risk enum values."""
        assert DetectionRisk.MINIMAL == "minimal"
        assert DetectionRisk.LOW == "low"
        assert DetectionRisk.MEDIUM == "medium"
        assert DetectionRisk.HIGH == "high"
        assert DetectionRisk.CRITICAL == "critical"


# AntiDetectionReport Model Tests

class TestAntiDetectionReportModel:
    """Test AntiDetectionReport pydantic model."""
    
    def test_report_creation_minimal(self):
        """Test creating report with minimal fields."""
        report = AntiDetectionReport(overall_risk=DetectionRisk.LOW)
        assert report.overall_risk == DetectionRisk.LOW
        assert len(report.risk_factors) == 0
        assert len(report.recommendations) == 0
    
    def test_report_creation_full(self):
        """Test creating complete report."""
        report = AntiDetectionReport(
            overall_risk=DetectionRisk.HIGH,
            risk_factors={"patterns": 0.8, "entropy": 0.6},
            recommendations=["Take a break", "Vary behavior"],
            recent_violations=["Regular timing detected"],
            session_duration_minutes=180.0,
            behavior_entropy=0.45,
            patterns_detected=5
        )
        assert report.overall_risk == DetectionRisk.HIGH
        assert report.risk_factors["patterns"] == 0.8
        assert len(report.recommendations) == 2


# AntiDetectionCoordinator Initialization Tests

class TestAntiDetectionCoordinatorInit:
    """Test AntiDetectionCoordinator initialization."""
    
    def test_init_default(self, tmp_path):
        """Test initialization with defaults."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        assert coordinator.data_dir == tmp_path
        assert coordinator.timing is not None
        assert coordinator.movement is not None
        assert coordinator.randomizer is not None
        assert coordinator.session is not None
        assert coordinator.chat is not None
        assert coordinator.pattern_breaker is not None
        assert len(coordinator.risk_history) == 0
    
    def test_init_with_timing_profile(self, tmp_path):
        """Test initialization with custom timing profile."""
        profile = TimingProfile(
            base_reaction_ms=300,
            fatigue_multiplier=1.1
        )
        coordinator = AntiDetectionCoordinator(tmp_path, timing_profile=profile)
        
        assert coordinator.timing.profile.base_reaction_ms == 300


# Humanize Action Tests

class TestHumanizeAction:
    """Test action humanization."""
    
    @pytest.mark.asyncio
    async def test_humanize_action_basic(self, tmp_path):
        """Test humanizing basic action."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        action = {
            "action_type": "move",
            "position": (100, 200),
            "is_combat": False
        }
        
        humanized = await coordinator.humanize_action(action)
        
        assert "delay_ms" in humanized
        assert "timing_info" in humanized
        assert humanized["action_type"] == "move"
    
    @pytest.mark.asyncio
    async def test_humanize_action_with_critical_pattern(self, tmp_path):
        """Test humanization with critical pattern detected."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Add critical pattern
        critical_pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Critical",
            occurrences=10,
            similarity_score=0.98,
            risk_level="critical"
        )
        coordinator.pattern_breaker.detected_patterns.append(critical_pattern)
        
        action = {"action_type": "attack", "is_combat": True}
        
        humanized = await coordinator.humanize_action(action)
        
        assert "delay_ms" in humanized
        # May or may not have pattern_variation depending on analysis
    
    @pytest.mark.asyncio
    async def test_humanize_action_records_for_analysis(self, tmp_path):
        """Test that action is recorded for pattern analysis."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        action = {"action_type": "skill", "skill_name": "fire_bolt"}
        
        await coordinator.humanize_action(action)
        
        assert len(coordinator.pattern_breaker.action_history) == 1


# Get Action Delay Tests

class TestGetActionDelay:
    """Test getting humanized action delay."""
    
    @pytest.mark.asyncio
    async def test_get_action_delay_no_session(self, tmp_path):
        """Test delay without active session."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        delay = await coordinator.get_action_delay("move", {"is_combat": False})
        
        assert delay > 0
        assert isinstance(delay, int)
    
    @pytest.mark.asyncio
    async def test_get_action_delay_with_session(self, tmp_path):
        """Test delay with active session."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Create mock session
        session = Mock(spec=PlaySession)
        session.duration_seconds = 600
        coordinator.session.current_session = session
        
        # Mock behavior
        coordinator.session.get_session_behavior = Mock(
            return_value=Mock(action_speed_multiplier=1.2)
        )
        
        delay = await coordinator.get_action_delay("attack", {"is_combat": True})
        
        assert delay > 0


# Humanize Path Tests

class TestHumanizePath:
    """Test path humanization."""
    
    @pytest.mark.asyncio
    async def test_humanize_path_basic(self, tmp_path):
        """Test basic path humanization."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        start = (100, 100)
        end = (200, 200)
        
        path = await coordinator.humanize_path(start, end, urgency=0.5)
        
        assert isinstance(path, HumanPath)
    
    @pytest.mark.asyncio
    async def test_humanize_path_with_urgency(self, tmp_path):
        """Test path with different urgency levels."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Low urgency
        casual_path = await coordinator.humanize_path((0, 0), (100, 100), urgency=0.2)
        assert casual_path is not None
        
        # High urgency
        urgent_path = await coordinator.humanize_path((0, 0), (100, 100), urgency=0.9)
        assert urgent_path is not None


# Should Inject Behavior Tests

class TestShouldInjectBehavior:
    """Test random behavior injection check."""
    
    @pytest.mark.asyncio
    async def test_should_inject_no_session(self, tmp_path):
        """Test injection check without active session."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        coordinator.session.current_session = None
        
        should, behavior = await coordinator.should_inject_behavior()
        
        assert should is False
        assert behavior is None
    
    @pytest.mark.asyncio
    async def test_should_inject_with_session(self, tmp_path):
        """Test injection check with active session."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Create mock session
        session = Mock(spec=PlaySession)
        session.duration_seconds = 1200
        coordinator.session.current_session = session
        
        # Mock randomizer decision
        coordinator.randomizer.should_inject_random_behavior = Mock(
            return_value=(True, Mock(spec=RandomBehavior))
        )
        
        should, behavior = await coordinator.should_inject_behavior()
        
        coordinator.randomizer.should_inject_random_behavior.assert_called_once()


# Humanize Chat Tests

class TestHumanizeChat:
    """Test chat humanization."""
    
    @pytest.mark.asyncio
    async def test_humanize_chat_basic(self, tmp_path):
        """Test basic chat humanization."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        response = await coordinator.humanize_chat("Hello there!", "neutral", 0.02)
        
        assert isinstance(response, ChatResponse)
    
    @pytest.mark.asyncio
    async def test_humanize_chat_with_emotion(self, tmp_path):
        """Test chat with different emotions."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        happy = await coordinator.humanize_chat("Great!", "happy", 0.0)
        assert happy is not None
        
        angry = await coordinator.humanize_chat("No way!", "angry", 0.0)
        assert angry is not None


# Assess Detection Risk Tests

class TestAssessDetectionRisk:
    """Test detection risk assessment."""
    
    @pytest.mark.asyncio
    async def test_assess_risk_minimal(self, tmp_path):
        """Test assessment with minimal risk."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # No patterns, good entropy
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.75)
        coordinator.session.current_session = None
        
        report = await coordinator.assess_detection_risk()
        
        assert report.overall_risk == DetectionRisk.MINIMAL
    
    @pytest.mark.asyncio
    async def test_assess_risk_with_critical_patterns(self, tmp_path):
        """Test assessment with critical patterns."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        critical_pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Critical timing",
            occurrences=20,
            similarity_score=0.98,
            risk_level="critical"
        )
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(
            return_value=[critical_pattern]
        )
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.6)
        coordinator.session.current_session = None
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        
        report = await coordinator.assess_detection_risk()
        
        assert len(report.recent_violations) > 0
        assert any("critical" in v for v in report.recent_violations)
        assert len(report.recommendations) > 0
    
    @pytest.mark.asyncio
    async def test_assess_risk_low_entropy(self, tmp_path):
        """Test assessment with low behavior entropy."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.35)
        coordinator.session.current_session = None
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        
        report = await coordinator.assess_detection_risk()
        
        assert "entropy" in report.risk_factors
        assert any("entropy" in v for v in report.recent_violations)
    
    @pytest.mark.asyncio
    async def test_assess_risk_long_session(self, tmp_path):
        """Test assessment with long session duration."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Create long session (5 hours)
        session = Mock(spec=PlaySession)
        session.duration_hours = 5.0
        session.duration_seconds = 18000.0
        session.afk_minutes = 30.0
        coordinator.session.current_session = session
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.6)
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        
        report = await coordinator.assess_detection_risk()
        
        assert "session_duration" in report.risk_factors
        assert any("break" in r.lower() for r in report.recommendations)
    
    @pytest.mark.asyncio
    async def test_assess_risk_insufficient_afk(self, tmp_path):
        """Test assessment with insufficient AFK time."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        session = Mock(spec=PlaySession)
        session.duration_hours = 4.0
        session.duration_seconds = 14400.0
        session.afk_minutes = 5.0  # Should be ~8+ minutes for 4 hours
        coordinator.session.current_session = session
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.6)
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        
        report = await coordinator.assess_detection_risk()
        
        assert any("AFK" in v for v in report.recent_violations)
    
    @pytest.mark.asyncio
    async def test_assess_risk_high_fatigue(self, tmp_path):
        """Test assessment with high fatigue."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.6)
        coordinator.session.current_session = None
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.5})
        
        report = await coordinator.assess_detection_risk()
        
        assert "fatigue" in report.risk_factors
    
    @pytest.mark.asyncio
    async def test_assess_risk_overall_calculation(self, tmp_path):
        """Test overall risk calculation from factors."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Create high risk scenario
        critical_pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Critical",
            occurrences=15,
            similarity_score=0.98,
            risk_level="critical"
        )
        high_pattern = DetectedPattern(
            pattern_type=PatternType.MOVEMENT,
            description="High risk",
            occurrences=10,
            similarity_score=0.92,
            risk_level="high"
        )
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(
            return_value=[critical_pattern, high_pattern]
        )
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.3)
        coordinator.session.current_session = None
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.6})
        
        report = await coordinator.assess_detection_risk()
        
        # Should have high/critical risk
        assert report.overall_risk in [DetectionRisk.HIGH, DetectionRisk.CRITICAL]
    
    @pytest.mark.asyncio
    async def test_assess_risk_history_limited(self, tmp_path):
        """Test risk history is limited to 100 entries."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.7)
        coordinator.session.current_session = None
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        
        # Generate 110 reports
        for _ in range(110):
            await coordinator.assess_detection_risk()
        
        assert len(coordinator.risk_history) == 100


# Get Mitigation Actions Tests

class TestGetMitigationActions:
    """Test mitigation action generation."""
    
    @pytest.mark.asyncio
    async def test_mitigation_critical_risk(self, tmp_path):
        """Test mitigation for critical risk."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        coordinator.pattern_breaker.get_pattern_breaking_suggestions = AsyncMock(return_value=[])
        
        actions = await coordinator.get_mitigation_actions(DetectionRisk.CRITICAL)
        
        assert len(actions) > 0
        assert any(a["action"] == "take_long_break" for a in actions)
        assert any(a["action"] == "change_activity" for a in actions)
    
    @pytest.mark.asyncio
    async def test_mitigation_high_risk(self, tmp_path):
        """Test mitigation for high risk."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        coordinator.pattern_breaker.get_pattern_breaking_suggestions = AsyncMock(return_value=[])
        
        actions = await coordinator.get_mitigation_actions(DetectionRisk.HIGH)
        
        assert len(actions) > 0
        assert any(a["action"] == "take_short_break" for a in actions)
        assert any(a["action"] == "increase_randomness" for a in actions)
    
    @pytest.mark.asyncio
    async def test_mitigation_medium_risk(self, tmp_path):
        """Test mitigation for medium risk."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        coordinator.pattern_breaker.get_pattern_breaking_suggestions = AsyncMock(return_value=[])
        
        actions = await coordinator.get_mitigation_actions(DetectionRisk.MEDIUM)
        
        assert len(actions) > 0
        assert any(a["action"] == "inject_random_behaviors" for a in actions)
    
    @pytest.mark.asyncio
    async def test_mitigation_includes_pattern_suggestions(self, tmp_path):
        """Test mitigation includes pattern-specific suggestions."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        pattern_suggestions = [
            {"type": "timing_variation", "add_delay_ms": 2000}
        ]
        coordinator.pattern_breaker.get_pattern_breaking_suggestions = AsyncMock(
            return_value=pattern_suggestions
        )
        
        actions = await coordinator.get_mitigation_actions(DetectionRisk.LOW)
        
        assert len(actions) > 0
        # Should include pattern suggestions
        assert any("timing_variation" in str(a) for a in actions)


# Apply Emergency Humanization Tests

class TestApplyEmergencyHumanization:
    """Test emergency humanization application."""
    
    @pytest.mark.asyncio
    async def test_apply_emergency_humanization(self, tmp_path):
        """Test applying emergency humanization."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Add some history
        for _ in range(10):
            coordinator.pattern_breaker.action_history.append({"action": "test"})
        coordinator.timing.consecutive_same_action = 5
        
        # Mock simulate_afk
        coordinator.session.simulate_afk = AsyncMock()
        
        await coordinator.apply_emergency_humanization()
        
        # Should clear history
        assert len(coordinator.pattern_breaker.action_history) == 0
        assert coordinator.timing.consecutive_same_action == 0
        
        # Should increase variance
        assert coordinator.timing.profile.fatigue_multiplier == 1.2
        assert coordinator.timing.profile.micro_delay_chance == 0.5
        
        # Should simulate AFK
        coordinator.session.simulate_afk.assert_called_once()


# Record Action Tests

class TestRecordAction:
    """Test action recording."""
    
    @pytest.mark.asyncio
    async def test_record_action(self, tmp_path):
        """Test recording action updates state."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        action = {"action_type": "move", "position": (100, 200)}
        
        initial_count = coordinator.timing.action_count
        
        await coordinator.record_action(action)
        
        assert len(coordinator.pattern_breaker.action_history) == 1
        assert coordinator.timing.action_count == initial_count + 1
        assert coordinator.timing.last_action_time is not None


# Session Management Tests

class TestSessionManagement:
    """Test session management through coordinator."""
    
    def test_get_session_status(self, tmp_path):
        """Test getting session status."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        coordinator.session.get_session_stats = Mock(
            return_value={"state": "active", "duration": 3600}
        )
        
        status = coordinator.get_session_status()
        
        assert "state" in status
        coordinator.session.get_session_stats.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_start_session(self, tmp_path):
        """Test starting session through coordinator."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        mock_session = Mock(spec=PlaySession)
        mock_session.session_id = "test_session"
        coordinator.session.start_session = AsyncMock(return_value=mock_session)
        
        session = await coordinator.start_session()
        
        assert session.session_id == "test_session"
        coordinator.session.start_session.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_end_session(self, tmp_path):
        """Test ending session through coordinator."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        coordinator.session.end_session = AsyncMock()
        
        await coordinator.end_session("Test reason")
        
        coordinator.session.end_session.assert_called_once_with("Test reason")


# Get Comprehensive Stats Tests

class TestGetComprehensiveStats:
    """Test comprehensive statistics."""
    
    def test_get_stats_all_subsystems(self, tmp_path):
        """Test getting stats from all subsystems."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Mock all subsystem stats
        coordinator.timing.get_session_stats = Mock(return_value={"timing": "data"})
        coordinator.movement.get_movement_stats = Mock(return_value={"movement": "data"})
        coordinator.randomizer.get_behavior_stats = Mock(return_value={"behavior": "data"})
        coordinator.session.get_session_stats = Mock(return_value={"session": "data"})
        coordinator.chat.get_chat_stats = Mock(return_value={"chat": "data"})
        coordinator.pattern_breaker.get_pattern_stats = Mock(return_value={"patterns": "data"})
        
        stats = coordinator.get_comprehensive_stats()
        
        assert "timing" in stats
        assert "movement" in stats
        assert "randomizer" in stats
        assert "session" in stats
        assert "chat" in stats
        assert "patterns" in stats
        assert "risk_assessment" in stats
    
    def test_get_stats_with_risk_history(self, tmp_path):
        """Test stats includes risk history."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Add risk history
        report = AntiDetectionReport(overall_risk=DetectionRisk.HIGH)
        coordinator.risk_history.append(report)
        
        # Mock other stats
        coordinator.timing.get_session_stats = Mock(return_value={})
        coordinator.movement.get_movement_stats = Mock(return_value={})
        coordinator.randomizer.get_behavior_stats = Mock(return_value={})
        coordinator.session.get_session_stats = Mock(return_value={})
        coordinator.chat.get_chat_stats = Mock(return_value={})
        coordinator.pattern_breaker.get_pattern_stats = Mock(return_value={})
        
        stats = coordinator.get_comprehensive_stats()
        
        assert stats["risk_assessment"]["current_risk"] == "high"
        assert stats["risk_assessment"]["risk_history_count"] == 1


# Integration Tests

class TestAntiDetectionIntegration:
    """Test integrated anti-detection scenarios."""
    
    @pytest.mark.asyncio
    async def test_full_humanization_workflow(self, tmp_path):
        """Test complete humanization workflow."""
        coordinator = AntiDetectionCoordinator(tmp_path)
        
        # Start session
        mock_session = Mock(spec=PlaySession)
        mock_session.session_id = "test"
        mock_session.duration_seconds = 600
        coordinator.session.start_session = AsyncMock(return_value=mock_session)
        coordinator.session.current_session = mock_session
        
        session = await coordinator.start_session()
        assert session is not None
        
        # Humanize some actions
        for i in range(5):
            action = {"action_type": "attack", "target_id": 1000 + i}
            humanized = await coordinator.humanize_action(action)
            assert "delay_ms" in humanized
        
        # Assess risk
        coordinator.pattern_breaker.analyze_patterns = AsyncMock(return_value=[])
        coordinator.pattern_breaker.calculate_behavior_entropy = Mock(return_value=0.65)
        coordinator.timing.get_session_stats = Mock(return_value={"current_fatigue": 1.0})
        coordinator.session.get_session_behavior = Mock(
            return_value=Mock(action_speed_multiplier=1.0)
        )
        
        report = await coordinator.assess_detection_risk()
        assert report.overall_risk is not None
        
        # Get stats
        coordinator.timing.get_session_stats = Mock(return_value={"actions": 5})
        coordinator.movement.get_movement_stats = Mock(return_value={})
        coordinator.randomizer.get_behavior_stats = Mock(return_value={})
        coordinator.session.get_session_stats = Mock(return_value={})
        coordinator.chat.get_chat_stats = Mock(return_value={})
        coordinator.pattern_breaker.get_pattern_stats = Mock(return_value={})
        
        stats = coordinator.get_comprehensive_stats()
        assert "timing" in stats


if __name__ == "__main__":
    pytest.main([__file__, "-v"])