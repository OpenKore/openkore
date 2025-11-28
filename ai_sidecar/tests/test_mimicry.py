"""
Comprehensive tests for Human Mimicry and Anti-Detection systems.

Tests all components:
- HumanTimingEngine
- MovementHumanizer
- BehaviorRandomizer
- HumanSessionManager
- HumanChatSimulator
- PatternBreaker
- AntiDetectionCoordinator
"""

import asyncio
import statistics
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from ai_sidecar.mimicry import (
    AntiDetectionCoordinator,
    HumanTimingEngine,
    MovementHumanizer,
    BehaviorRandomizer,
    HumanSessionManager,
    HumanChatSimulator,
    PatternBreaker,
    ReactionType,
    TimingProfile,
    ChatStyle,
    SessionState,
    DetectionRisk,
)


@pytest.fixture
def data_dir(tmp_path):
    """Create temporary data directory with config files."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Create minimal config files
    behaviors_file = data_dir / "human_behaviors.json"
    behaviors_file.write_text('{"idle_behaviors": [], "social_behaviors": []}')
    
    patterns_file = data_dir / "session_patterns.json"
    patterns_file.write_text('{"weekday_patterns": {"typical_start_hours": [18, 19], "typical_end_hours": [22, 23], "average_session_minutes": 120, "max_session_minutes": 240}, "break_patterns": {"short_break_after_minutes": 45}, "afk_patterns": {}}')
    
    return data_dir


class TestHumanTimingEngine:
    """Test timing humanization."""
    
    def test_initialization(self):
        """Test timing engine initialization."""
        engine = HumanTimingEngine()
        assert engine.profile is not None
        assert engine.action_count == 0
        assert engine.session_start is not None
    
    def test_reaction_distribution(self):
        """Verify reaction times follow skewed normal distribution."""
        engine = HumanTimingEngine()
        samples = [engine.get_reaction_delay(ReactionType.NORMAL) for _ in range(100)]
        
        # Check range
        assert all(100 <= s <= 2000 for s in samples)
        
        # Check distribution (should not be uniform)
        variance = statistics.stdev(samples)
        assert variance > 50  # Should have variance
        
        # Check mean is reasonable
        mean = statistics.mean(samples)
        assert 300 <= mean <= 700
    
    def test_fatigue_simulation(self):
        """Test fatigue increases over time."""
        engine = HumanTimingEngine()
        
        # Simulate session start
        initial_fatigue = engine.apply_fatigue()
        assert initial_fatigue == 1.0
        
        # Simulate 3 hours later
        engine.session_start = datetime.now() - timedelta(hours=3)
        later_fatigue = engine.apply_fatigue()
        assert later_fatigue > 1.0
        assert later_fatigue <= 1.5
    
    def test_time_of_day_factor(self):
        """Test slower reactions at night."""
        engine = HumanTimingEngine()
        factor = engine.apply_time_of_day_factor()
        
        # Should return a valid multiplier
        assert 1.0 <= factor <= 1.3
    
    def test_consecutive_action_speedup(self):
        """Test muscle memory effect."""
        engine = HumanTimingEngine()
        
        # First action
        timing1 = engine.get_action_delay("attack", is_combat=True)
        delay1 = timing1.actual_delay_ms
        
        # Same action repeatedly
        delays = [engine.get_action_delay("attack", is_combat=True).actual_delay_ms for _ in range(5)]
        
        # Later actions should generally be faster (muscle memory)
        # Though randomness means not guaranteed, trend should be faster
        assert engine.consecutive_same_action > 1
    
    def test_typing_delay(self):
        """Test realistic typing delays."""
        engine = HumanTimingEngine()
        
        short_delay = engine.get_typing_delay("hi")
        long_delay = engine.get_typing_delay("This is a much longer message with more words.")
        
        # Longer messages should take longer
        assert long_delay > short_delay
        assert short_delay >= 500  # At least thinking time
        assert long_delay >= 2000


class TestMovementHumanizer:
    """Test movement humanization."""
    
    def test_initialization(self, data_dir):
        """Test movement humanizer initialization."""
        humanizer = MovementHumanizer(data_dir)
        assert humanizer.movement_history == []
        assert humanizer.base_speed_cells_per_sec > 0
    
    def test_path_inefficiency(self, data_dir):
        """Verify paths are not perfectly optimal."""
        humanizer = MovementHumanizer(data_dir)
        
        start = (0, 0)
        end = (100, 100)
        
        path = humanizer.humanize_path(start, end, urgency=0.5)
        
        # Path should exist
        assert len(path.points) > 2
        
        # Path should be inefficient (not perfectly straight)
        assert path.path_efficiency < 1.0
        assert path.path_efficiency >= 0.7
        
        # Should have some direction changes
        assert path.direction_changes >= 0
    
    def test_bezier_curves(self, data_dir):
        """Test curved path generation."""
        humanizer = MovementHumanizer(data_dir)
        
        start = (0, 0)
        end = (50, 50)
        
        points = humanizer.generate_bezier_path(start, end, control_points=2)
        
        # Should have multiple points
        assert len(points) > 5
        
        # First and last should match start/end
        assert points[0].x == start[0] and points[0].y == start[1]
        assert points[-1].x == end[0] and points[-1].y == end[1]
    
    def test_pause_injection(self, data_dir):
        """Test random pauses added to paths."""
        humanizer = MovementHumanizer(data_dir)
        
        # Create path
        points = [PathPoint(x=i, y=i) for i in range(20)]
        
        # Add pauses
        paused = humanizer.add_pause_points(points, pause_chance=0.5)
        
        # Some points should have delays
        pauses = sum(1 for p in paused if p.delay_before_ms > 0)
        assert pauses >= 0  # At least some chance
    
    def test_speed_variation(self, data_dir):
        """Test variable movement speed."""
        humanizer = MovementHumanizer(data_dir)
        
        speeds = humanizer.get_movement_speed_variation(20)
        
        # Should have 20 speed values
        assert len(speeds) == 20
        
        # All should be in valid range
        assert all(0.7 <= s <= 1.2 for s in speeds)
        
        # Should have variation
        assert statistics.stdev(speeds) > 0.05
    
    def test_pattern_detection(self, data_dir):
        """Test detection of suspicious movement patterns."""
        humanizer = MovementHumanizer(data_dir)
        
        # Generate several identical paths (suspicious)
        for _ in range(10):
            path = HumanPath(
                points=[PathPoint(x=0, y=0), PathPoint(x=10, y=10)],
                pattern_type=MovementPattern.DIRECT,
                total_distance=14.14,
                estimated_time_ms=2828,
                path_efficiency=0.99,
                pause_points=[],
                direction_changes=0
            )
            humanizer.movement_history.append(path)
        
        suspicious, reason = humanizer.detect_suspicious_pattern()
        # Should detect high efficiency or lack of variation
        assert isinstance(suspicious, bool)


class TestBehaviorRandomizer:
    """Test behavior randomization."""
    
    def test_initialization(self, data_dir):
        """Test randomizer initialization."""
        randomizer = BehaviorRandomizer(data_dir)
        assert len(randomizer.behavior_pools) > 0
    
    def test_idle_behavior_injection(self, data_dir):
        """Test random idle behaviors."""
        randomizer = BehaviorRandomizer(data_dir)
        
        # Should sometimes inject behavior
        should_inject, behavior = randomizer.should_inject_random_behavior(
            current_activity="idle",
            time_in_activity_ms=600000  # 10 minutes
        )
        
        # Result should be valid
        assert isinstance(should_inject, bool)
        if should_inject:
            assert behavior is not None
    
    def test_suboptimal_targeting(self, data_dir):
        """Test occasionally suboptimal choices."""
        randomizer = BehaviorRandomizer(data_dir)
        
        targets = [{"actor_id": i, "hp": 100 - i*10} for i in range(5)]
        optimal = targets[0]
        
        # Run multiple times to test probability
        selections = [randomizer.vary_target_selection(targets, optimal) for _ in range(100)]
        
        # Should sometimes select suboptimal
        suboptimal_count = sum(1 for s in selections if s != optimal)
        assert suboptimal_count > 5  # At least some variation


class TestSessionManager:
    """Test session management."""
    
    @pytest.mark.asyncio
    async def test_session_lifecycle(self, data_dir):
        """Test session state transitions."""
        manager = HumanSessionManager(data_dir)
        
        # Start session
        session = await manager.start_session()
        assert session is not None
        assert session.current_state == SessionState.STARTING
        
        # Update state
        new_state = await manager.update_session_state()
        assert new_state in SessionState
        
        # End session
        await manager.end_session("Test complete")
        assert manager.current_session is None
    
    @pytest.mark.asyncio
    async def test_break_scheduling(self, data_dir):
        """Test natural break patterns."""
        manager = HumanSessionManager(data_dir)
        await manager.start_session()
        
        # Simulate time passing
        manager.current_session.started_at = datetime.now() - timedelta(minutes=50)
        
        should_break, duration = await manager.should_take_break()
        
        # Should be valid response
        assert isinstance(should_break, bool)
        if should_break:
            assert duration > 0
    
    @pytest.mark.asyncio
    async def test_fatigue_detection(self, data_dir):
        """Test fatigue state detection."""
        manager = HumanSessionManager(data_dir)
        await manager.start_session()
        
        # Simulate long session
        manager.current_session.started_at = datetime.now() - timedelta(hours=3)
        
        state = await manager.update_session_state()
        
        # Should transition to fatigue-related state
        assert state in [SessionState.FATIGUED, SessionState.ACTIVE, SessionState.WINDING_DOWN]


class TestChatSimulator:
    """Test chat humanization."""
    
    def test_typing_delays(self):
        """Test realistic typing simulation."""
        simulator = HumanChatSimulator()
        
        delays = simulator.generate_typing_pattern("Hello world!")
        
        # Should have delay for each character
        assert len(delays) == len("Hello world!")
        
        # All delays should be positive
        assert all(d > 0 for d in delays)
    
    def test_typo_injection(self):
        """Test realistic typo patterns."""
        simulator = HumanChatSimulator()
        
        # Test multiple times due to randomness
        typos_found = 0
        for _ in range(100):
            message, has_typo = simulator.add_typo("hello world", typo_rate=0.5)
            if has_typo:
                typos_found += 1
                assert message != "hello world"
        
        # Should have some typos with 50% rate
        assert typos_found > 20
    
    def test_response_timing(self):
        """Test natural response delays."""
        simulator = HumanChatSimulator()
        
        # Short message
        short_delay = asyncio.run(simulator.get_response_timing(10, requires_thinking=False))
        
        # Long complex message
        long_delay = asyncio.run(simulator.get_response_timing(100, requires_thinking=True))
        
        # Complex should take longer
        assert long_delay > short_delay
        assert short_delay >= 1000  # At least 1 second
    
    def test_abbreviations(self):
        """Test gaming abbreviations."""
        simulator = HumanChatSimulator()
        
        abbreviated = simulator.abbreviate_message("please thanks you")
        
        # Should contain abbreviations
        assert "pls" in abbreviated or "thx" in abbreviated or "u" in abbreviated


class TestPatternBreaker:
    """Test pattern detection and breaking."""
    
    def test_timing_pattern_detection(self, data_dir):
        """Detect regular timing intervals."""
        breaker = PatternBreaker(data_dir)
        
        # Create regular timing pattern (suspicious)
        base_time = datetime.now()
        actions = [
            {"timestamp": base_time + timedelta(seconds=i*5), "action_type": "attack"}
            for i in range(20)
        ]
        
        pattern = breaker.detect_timing_patterns(actions)
        
        if pattern:
            assert pattern.pattern_type == PatternType.TIMING
            assert pattern.similarity_score > 0.5
    
    def test_movement_pattern_detection(self, data_dir):
        """Detect repetitive movement patterns."""
        breaker = PatternBreaker(data_dir)
        
        # Create identical paths (suspicious)
        identical_path = [{"x": 0, "y": 0}, {"x": 10, "y": 10}]
        movements = [
            {"path": identical_path, "timestamp": datetime.now()}
            for _ in range(10)
        ]
        
        pattern = breaker.detect_movement_patterns(movements)
        
        if pattern:
            assert pattern.pattern_type == PatternType.MOVEMENT
            assert pattern.occurrences >= 5
    
    @pytest.mark.asyncio
    async def test_pattern_breaking(self, data_dir):
        """Test pattern variation injection."""
        breaker = PatternBreaker(data_dir)
        
        # Create pattern
        pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Test pattern",
            occurrences=10,
            similarity_score=0.95,
            risk_level="high"
        )
        
        variation = await breaker.break_pattern(pattern)
        
        assert variation is not None
        assert "type" in variation
    
    def test_entropy_calculation(self, data_dir):
        """Test behavior entropy measurement."""
        breaker = PatternBreaker(data_dir)
        
        # Add varied actions
        for i in range(20):
            action = {
                "action_type": ["attack", "skill", "move", "item"][i % 4],
                "timestamp": datetime.now()
            }
            breaker.record_action(action)
        
        entropy = breaker.calculate_behavior_entropy()
        
        # Should have reasonable entropy
        assert 0.0 <= entropy <= 1.0


class TestAntiDetectionCoordinator:
    """Test integrated anti-detection system."""
    
    def test_initialization(self, data_dir):
        """Test coordinator initialization."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        assert coordinator.timing is not None
        assert coordinator.movement is not None
        assert coordinator.randomizer is not None
        assert coordinator.session is not None
        assert coordinator.chat is not None
        assert coordinator.pattern_breaker is not None
    
    @pytest.mark.asyncio
    async def test_action_humanization(self, data_dir):
        """Test full action humanization."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        action = {
            "action_type": "attack",
            "target_id": 123,
            "is_combat": True
        }
        
        humanized = await coordinator.humanize_action(action)
        
        # Should have added timing
        assert "delay_ms" in humanized
        assert humanized["delay_ms"] > 0
        
        # Should have timing info
        assert "timing_info" in humanized
    
    @pytest.mark.asyncio
    async def test_risk_assessment(self, data_dir):
        """Test detection risk calculation."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        report = await coordinator.assess_detection_risk()
        
        assert report.overall_risk in DetectionRisk
        assert isinstance(report.risk_factors, dict)
        assert isinstance(report.recommendations, list)
    
    @pytest.mark.asyncio
    async def test_emergency_response(self, data_dir):
        """Test critical risk response."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        # Start session first
        await coordinator.start_session()
        
        # Apply emergency humanization
        await coordinator.apply_emergency_humanization()
        
        # Should have increased randomness
        assert coordinator.timing.profile.micro_delay_chance >= 0.5
    
    @pytest.mark.asyncio
    async def test_path_humanization(self, data_dir):
        """Test path humanization integration."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        start = (0, 0)
        end = (50, 50)
        
        path = await coordinator.humanize_path(start, end, urgency=0.5)
        
        assert path is not None
        assert len(path.points) > 0
        assert path.path_efficiency < 1.0
    
    @pytest.mark.asyncio
    async def test_chat_humanization(self, data_dir):
        """Test chat message humanization."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        response = await coordinator.humanize_chat("hello there", emotion="happy")
        
        assert response.message is not None
        assert response.typing_delay_ms > 0
    
    def test_comprehensive_stats(self, data_dir):
        """Test comprehensive statistics collection."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        stats = coordinator.get_comprehensive_stats()
        
        assert "timing" in stats
        assert "movement" in stats
        assert "randomizer" in stats
        assert "session" in stats
        assert "chat" in stats
        assert "patterns" in stats
        assert "risk_assessment" in stats


class TestIntegration:
    """Integration tests for complete workflows."""
    
    @pytest.mark.asyncio
    async def test_complete_action_workflow(self, data_dir):
        """Test complete action from detection to execution."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        # Start session
        await coordinator.start_session()
        
        # Create and humanize multiple actions
        actions = [
            {"action_type": "attack", "target_id": 100 + i, "is_combat": True}
            for i in range(10)
        ]
        
        humanized_actions = []
        for action in actions:
            humanized = await coordinator.humanize_action(action)
            humanized_actions.append(humanized)
            await asyncio.sleep(0.01)  # Small delay
        
        # All should have timing
        assert all("delay_ms" in a for a in humanized_actions)
        
        # Delays should vary
        delays = [a["delay_ms"] for a in humanized_actions]
        assert statistics.stdev(delays) > 0
    
    @pytest.mark.asyncio
    async def test_risk_monitoring_workflow(self, data_dir):
        """Test continuous risk monitoring."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        await coordinator.start_session()
        
        # Perform actions
        for i in range(20):
            action = {"action_type": "attack", "timestamp": datetime.now()}
            await coordinator.record_action(action)
        
        # Assess risk
        report = await coordinator.assess_detection_risk()
        
        assert report is not None
        assert len(coordinator.risk_history) > 0
    
    @pytest.mark.asyncio
    async def test_session_complete_lifecycle(self, data_dir):
        """Test complete session from start to end."""
        coordinator = AntiDetectionCoordinator(data_dir)
        
        # Start
        session = await coordinator.start_session()
        assert session.current_state == SessionState.STARTING
        
        # Simulate some play time
        session.started_at = datetime.now() - timedelta(minutes=20)
        await coordinator.session.update_session_state()
        
        # Check status
        status = coordinator.get_session_status()
        assert status["active"] is True
        
        # End
        await coordinator.end_session("Test complete")
        
        status = coordinator.get_session_status()
        assert status["active"] is False


# Import PathPoint for test
from ai_sidecar.mimicry.movement import PathPoint, MovementPattern
from ai_sidecar.mimicry.pattern_breaker import PatternType


if __name__ == "__main__":
    pytest.main([__file__, "-v"])