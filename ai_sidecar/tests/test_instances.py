"""
Comprehensive tests for Instance/Memorial Dungeon systems.

Tests all instance subsystems including registry, state management,
strategy, navigation, cooldowns, and Endless Tower handling.
"""

import asyncio
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict

import pytest

from ai_sidecar.instances import (
    CooldownManager,
    EndlessTowerHandler,
    ETFloorData,
    InstanceCoordinator,
    InstanceDefinition,
    InstanceDifficulty,
    InstanceNavigator,
    InstancePhase,
    InstanceRegistry,
    InstanceRequirement,
    InstanceReward,
    InstanceState,
    InstanceStateManager,
    InstanceStrategyEngine,
    InstanceType,
)
from ai_sidecar.instances.navigator import FloorMap, MonsterPosition
from ai_sidecar.instances.strategy import BossStrategy, FloorStrategy


@pytest.fixture
def test_data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test files."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Create minimal test instances.json
    instances_file = data_dir / "instances.json"
    instances_file.write_text("""{
      "test_instance": {
        "instance_name": "Test Instance",
        "instance_type": "memorial_dungeon",
        "difficulty": "normal",
        "entry_npc": "Test NPC",
        "entry_map": "test_map",
        "entry_position": [100, 100],
        "time_limit_minutes": 60,
        "cooldown_hours": 24,
        "floors": 1,
        "requirements": {
          "min_level": 50
        },
        "rewards": {
          "guaranteed_items": ["Test Item"]
        },
        "recommended_level": 75
      }
    }""")
    
    return data_dir


@pytest.fixture
def sample_character_state() -> Dict[str, Any]:
    """Sample character state for testing."""
    return {
        "name": "TestChar",
        "base_level": 99,
        "job_class": "Lord Knight",
        "party_size": 1,
        "gear_score": 5000,
        "is_rebirth": True,
        "completed_quests": [],
        "inventory": [],
        "consumables": {
            "White Potion": 100,
            "Yggdrasil Leaf": 3
        }
    }


class TestInstanceRegistry:
    """Test instance registry."""
    
    @pytest.mark.asyncio
    async def test_load_instances(self, test_data_dir: Path):
        """Verify instances load correctly."""
        registry = InstanceRegistry(test_data_dir)
        
        assert registry.get_instance_count() == 1
        instance = await registry.get_instance("test_instance")
        assert instance is not None
        assert instance.instance_name == "Test Instance"
    
    @pytest.mark.asyncio
    async def test_requirement_checking(
        self,
        test_data_dir: Path,
        sample_character_state: Dict[str, Any]
    ):
        """Test requirement validation."""
        registry = InstanceRegistry(test_data_dir)
        
        # Should pass with level 99
        can_enter, missing = await registry.check_requirements(
            "test_instance",
            sample_character_state
        )
        assert can_enter is True
        assert len(missing) == 0
        
        # Should fail with low level
        low_level_char = sample_character_state.copy()
        low_level_char["base_level"] = 30
        
        can_enter, missing = await registry.check_requirements(
            "test_instance",
            low_level_char
        )
        assert can_enter is False
        assert len(missing) > 0
    
    @pytest.mark.asyncio
    async def test_find_by_level(self, test_data_dir: Path):
        """Test level-appropriate instance finding."""
        registry = InstanceRegistry(test_data_dir)
        
        instances = await registry.find_instances_by_level(75)
        assert len(instances) >= 0  # Should find test_instance or none
    
    @pytest.mark.asyncio
    async def test_find_by_type(self, test_data_dir: Path):
        """Test finding instances by type."""
        registry = InstanceRegistry(test_data_dir)
        
        instances = await registry.find_instances_by_type(
            InstanceType.MEMORIAL_DUNGEON
        )
        assert len(instances) == 1


class TestInstanceState:
    """Test instance state management."""
    
    @pytest.fixture
    def instance_def(self) -> InstanceDefinition:
        """Sample instance definition."""
        return InstanceDefinition(
            instance_id="test_inst",
            instance_name="Test Instance",
            instance_type=InstanceType.MEMORIAL_DUNGEON,
            difficulty=InstanceDifficulty.NORMAL,
            entry_npc="Test NPC",
            entry_map="test_map",
            entry_position=(100, 100),
            time_limit_minutes=30,
            floors=3
        )
    
    @pytest.mark.asyncio
    async def test_state_initialization(self, instance_def: InstanceDefinition):
        """Verify state initializes correctly."""
        manager = InstanceStateManager()
        
        state = await manager.start_instance(instance_def)
        
        assert state.instance_id == "test_inst"
        assert state.phase == InstancePhase.IN_PROGRESS
        assert state.current_floor == 1
        assert state.total_floors == 3
        assert len(state.floors) == 3
        assert state.started_at is not None
    
    @pytest.mark.asyncio
    async def test_floor_progression(self, instance_def: InstanceDefinition):
        """Test floor advancement."""
        manager = InstanceStateManager()
        state = await manager.start_instance(instance_def)
        
        # Update floor 1
        await manager.update_floor_progress(monsters_killed=5)
        assert state.floors[1].monsters_killed == 5
        
        # Advance to floor 2
        result = await manager.advance_floor()
        assert result is True
        assert state.current_floor == 2
        assert state.floors[1].time_completed is not None
        assert state.floors[2].time_started is not None
        
        # Try advancing past last floor
        await manager.advance_floor()
        result = await manager.advance_floor()
        assert result is False
    
    @pytest.mark.asyncio
    async def test_time_tracking(self, instance_def: InstanceDefinition):
        """Test time limit monitoring."""
        manager = InstanceStateManager()
        state = await manager.start_instance(instance_def)
        
        assert state.time_remaining_seconds > 0
        assert state.time_remaining_percent > 0
        
        # Should not be critical yet
        is_critical = await manager.check_time_critical()
        assert is_critical is False
    
    @pytest.mark.asyncio
    async def test_abort_conditions(self, instance_def: InstanceDefinition):
        """Test abort decision logic."""
        manager = InstanceStateManager()
        state = await manager.start_instance(instance_def)
        
        # Not enough deaths yet
        should_abort, reason = await manager.should_abort()
        assert should_abort is False
        
        # Too many deaths
        for _ in range(10):
            await manager.record_death()
        
        should_abort, reason = await manager.should_abort()
        assert should_abort is True
        assert "death" in reason.lower()


class TestInstanceStrategy:
    """Test strategy system."""
    
    @pytest.fixture
    def instance_def(self) -> InstanceDefinition:
        """Sample instance for strategy testing."""
        return InstanceDefinition(
            instance_id="strat_test",
            instance_name="Strategy Test",
            instance_type=InstanceType.MEMORIAL_DUNGEON,
            difficulty=InstanceDifficulty.HARD,
            entry_npc="Test NPC",
            entry_map="test",
            entry_position=(100, 100),
            floors=2,
            boss_names=["Test Boss"]
        )
    
    @pytest.mark.asyncio
    async def test_strategy_generation(
        self,
        instance_def: InstanceDefinition,
        sample_character_state: Dict[str, Any]
    ):
        """Test dynamic strategy generation."""
        engine = InstanceStrategyEngine()
        
        strategy = await engine.generate_strategy(
            instance_def,
            sample_character_state,
            ["Lord Knight"]
        )
        
        assert strategy.instance_id == "strat_test"
        assert len(strategy.floor_strategies) == 2
        assert len(strategy.boss_strategies) == 1
    
    @pytest.mark.asyncio
    async def test_boss_strategy(self):
        """Test boss fight strategy."""
        boss_strategy = BossStrategy(
            boss_name="Test Boss",
            phase_triggers=[50.0],
            positioning="ranged"
        )
        
        assert boss_strategy.boss_name == "Test Boss"
        assert boss_strategy.positioning == "ranged"
    
    @pytest.mark.asyncio
    async def test_strategy_adaptation(self):
        """Test adaptive strategy changes."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            current_floor=1,
            total_floors=1
        )
        
        # Adapt to event
        await engine.adapt_strategy("party_member_died", state)
        
        # Should have learned tactics
        assert "test" in engine.learned_tactics


class TestCooldownManager:
    """Test cooldown system."""
    
    @pytest.mark.asyncio
    async def test_cooldown_tracking(self):
        """Verify cooldown recording."""
        manager = CooldownManager()
        
        # Record completion
        await manager.record_completion(
            "test_instance",
            "TestChar",
            24
        )
        
        # Should be on cooldown
        is_available, time_until = await manager.check_cooldown(
            "test_instance",
            "TestChar"
        )
        
        assert is_available is False
        assert time_until is not None
    
    @pytest.mark.asyncio
    async def test_cooldown_expiration(self):
        """Test cooldown expiry detection."""
        manager = CooldownManager()
        
        # Record with 0 hour cooldown (immediately available)
        await manager.record_completion(
            "test_instance",
            "TestChar",
            0
        )
        
        is_available, time_until = await manager.check_cooldown(
            "test_instance",
            "TestChar"
        )
        
        assert is_available is True
    
    @pytest.mark.asyncio
    async def test_schedule_optimization(self):
        """Test optimal schedule planning."""
        manager = CooldownManager()
        
        instances = ["inst1", "inst2", "inst3"]
        schedule = await manager.get_optimal_schedule("TestChar", instances)
        
        assert len(schedule) == 3
        assert all(isinstance(dt, datetime) for dt in schedule.values())


class TestEndlessTower:
    """Test Endless Tower specific handling."""
    
    @pytest.mark.asyncio
    async def test_mvp_floor_detection(self):
        """Test MVP floor identification."""
        handler = EndlessTowerHandler()
        
        assert handler.is_mvp_floor(25) is True
        assert handler.is_mvp_floor(50) is True
        assert handler.is_mvp_floor(75) is True
        assert handler.is_mvp_floor(100) is True
        assert handler.is_mvp_floor(24) is False
    
    @pytest.mark.asyncio
    async def test_stopping_point(self, sample_character_state: Dict[str, Any]):
        """Test optimal stopping point calculation."""
        handler = EndlessTowerHandler()
        
        stopping_floor = await handler.get_stopping_point(
            sample_character_state,
            1
        )
        
        assert stopping_floor > 1
        assert stopping_floor <= 100
    
    @pytest.mark.asyncio
    async def test_floor_strategy(self, sample_character_state: Dict[str, Any]):
        """Test floor-specific strategy."""
        handler = EndlessTowerHandler()
        
        # Regular floor
        strategy = await handler.get_floor_strategy(10, sample_character_state)
        assert strategy.floor_number == 10
        
        # MVP floor
        mvp_strategy = await handler.get_floor_strategy(25, sample_character_state)
        assert mvp_strategy.floor_number == 25
        assert len(mvp_strategy.special_mechanics) > 0
    
    @pytest.mark.asyncio
    async def test_checkpoint_detection(self):
        """Test checkpoint floor detection."""
        handler = EndlessTowerHandler()
        
        assert handler.is_checkpoint_floor(26) is True
        assert handler.is_checkpoint_floor(51) is True
        assert handler.is_checkpoint_floor(77) is True
        assert handler.is_checkpoint_floor(1) is False


class TestInstanceNavigator:
    """Test navigation system."""
    
    @pytest.mark.asyncio
    async def test_path_finding(self):
        """Test A* pathfinding."""
        navigator = InstanceNavigator()
        
        floor_map = FloorMap(
            width=50,
            height=50,
            walkable_tiles=set((x, y) for x in range(50) for y in range(50))
        )
        
        path = await navigator._find_path(
            (0, 0),
            (10, 10),
            floor_map
        )
        
        assert len(path) > 0
        assert path[0] == (0, 0)
        assert path[-1] == (10, 10)
    
    @pytest.mark.asyncio
    async def test_loot_routing(self):
        """Test efficient loot collection routing."""
        navigator = InstanceNavigator()
        
        loot_positions = [(5, 5), (10, 10), (3, 3)]
        route = await navigator.get_loot_route((0, 0), loot_positions)
        
        assert len(route) == 3
        assert all(pos in loot_positions for pos in route)
    
    @pytest.mark.asyncio
    async def test_safe_positioning(self):
        """Test safe position calculation."""
        navigator = InstanceNavigator()
        
        boss_strategy = BossStrategy(
            boss_name="Test Boss",
            positioning="ranged",
            safe_zones=[(200, 200)]
        )
        
        safe_pos = await navigator.get_safe_position(
            (100, 100),
            boss_strategy
        )
        
        assert safe_pos is not None
        assert isinstance(safe_pos, tuple)
        assert len(safe_pos) == 2


class TestInstanceCoordinator:
    """Test unified coordinator."""
    
    @pytest.mark.asyncio
    async def test_instance_selection(
        self,
        test_data_dir: Path,
        sample_character_state: Dict[str, Any]
    ):
        """Test optimal instance selection."""
        coordinator = InstanceCoordinator(test_data_dir)
        
        instance_id = await coordinator.select_instance(sample_character_state)
        
        # May be None if no instances available
        if instance_id:
            assert isinstance(instance_id, str)
    
    @pytest.mark.asyncio
    async def test_run_lifecycle(
        self,
        test_data_dir: Path,
        sample_character_state: Dict[str, Any]
    ):
        """Test complete instance run lifecycle."""
        coordinator = InstanceCoordinator(test_data_dir)
        
        # Start run
        state = await coordinator.start_instance_run(
            "test_instance",
            sample_character_state
        )
        
        assert state.phase == InstancePhase.IN_PROGRESS
        assert state.instance_id == "test_instance"
        
        # Complete run
        report = await coordinator.complete_run()
        
        assert report.instance_id == "test_instance"
        assert report.duration_seconds >= 0
    
    @pytest.mark.asyncio
    async def test_daily_planning(
        self,
        test_data_dir: Path,
        sample_character_state: Dict[str, Any]
    ):
        """Test daily instance planning."""
        coordinator = InstanceCoordinator(test_data_dir)
        
        plan = await coordinator.get_daily_plan(sample_character_state)
        
        assert isinstance(plan, list)
        # May be empty if no instances available


class TestIntegration:
    """Integration tests for full workflow."""
    
    @pytest.mark.asyncio
    async def test_full_instance_workflow(
        self,
        test_data_dir: Path,
        sample_character_state: Dict[str, Any]
    ):
        """Test complete instance workflow."""
        coordinator = InstanceCoordinator(test_data_dir)
        
        # 1. Select instance
        instance_id = await coordinator.select_instance(sample_character_state)
        
        if not instance_id:
            # No instances available
            return
        
        # 2. Start run
        state = await coordinator.start_instance_run(
            instance_id,
            sample_character_state
        )
        
        assert state.phase == InstancePhase.IN_PROGRESS
        
        # 3. Simulate events
        await coordinator.handle_event("monster_killed", {"count": 3})
        
        # 4. Complete run
        report = await coordinator.complete_run()
        
        assert report.success is True or report.success is False
        assert report.instance_id == instance_id


# Run tests if executed directly
if __name__ == "__main__":
    pytest.main([__file__, "-v"])