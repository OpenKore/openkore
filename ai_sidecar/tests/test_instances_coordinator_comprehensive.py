"""
Comprehensive tests for instances/coordinator.py - Batch 7.

Target: Push coverage from 59.50% to 85%+
Focus on uncovered lines: 115-116, 130-131, 135, 141, 145, 171, 180, 217-269,
285, 292-311, 328, 338, 404, 417, 439, 443
"""

from datetime import datetime
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import tempfile
import pytest

from ai_sidecar.instances.coordinator import (
    InstanceCoordinator,
    InstanceRunReport,
    PlannedInstance,
)
from ai_sidecar.instances.registry import InstanceDefinition, InstanceRequirement, InstanceType, InstanceDifficulty, InstanceReward
from ai_sidecar.instances.state import InstancePhase, InstanceState
from ai_sidecar.instances.strategy import InstanceAction


@pytest.fixture
def temp_data_dir():
    """Create temporary data directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def coordinator(temp_data_dir):
    """Create instance coordinator."""
    return InstanceCoordinator(temp_data_dir)


@pytest.fixture
def sample_instance_def():
    """Create sample instance definition."""
    return InstanceDefinition(
        instance_id="endless_tower",
        instance_name="Endless Tower",
        instance_type=InstanceType.ENDLESS_TOWER,
        difficulty=InstanceDifficulty.NORMAL,
        entry_npc="Tower Guardian",
        entry_map="alberta",
        entry_position=(100, 100),
        time_limit_minutes=240,
        cooldown_hours=168,
        floors=100,
        requirements=InstanceRequirement(
            min_level=50,
            max_level=150,
            min_party_size=1,
            max_party_size=12
        ),
        rewards=InstanceReward(),
        estimated_clear_time_minutes=120
    )


@pytest.fixture
def character_state():
    """Create character state."""
    return {
        "name": "TestChar",
        "level": 99,
        "job": "High Priest",
        "party_members": ["TestChar", "PartyMember1"]
    }


class TestSelectInstance:
    """Test select_instance method - lines 83-152."""

    @pytest.mark.asyncio
    async def test_select_instance_no_available(self, coordinator, character_state):
        """Test when all instances on cooldown."""
        coordinator.cooldown_manager.get_available_instances = AsyncMock(
            return_value=[]
        )
        
        result = await coordinator.select_instance(character_state)
        
        assert result is None

    @pytest.mark.asyncio
    async def test_select_instance_no_recommendations(self, coordinator, character_state):
        """Test when no recommended instances."""
        coordinator.cooldown_manager.get_available_instances = AsyncMock(
            return_value=["endless_tower"]
        )
        coordinator.registry.get_recommended_instances = AsyncMock(
            return_value=[]
        )
        
        result = await coordinator.select_instance(character_state)
        
        assert result is None

    @pytest.mark.asyncio
    async def test_select_instance_with_preferences(self, coordinator, character_state, sample_instance_def):
        """Test instance selection with preferences."""
        # Setup solo preference
        preferences = {"prefer_solo": True}
        
        solo_instance = MagicMock()
        solo_instance.instance_id = "solo_quest"
        solo_instance.requirements.max_party_size = 1
        
        coordinator.cooldown_manager.get_available_instances = AsyncMock(
            return_value=["solo_quest", "endless_tower"]
        )
        coordinator.registry.get_recommended_instances = AsyncMock(
            return_value=[solo_instance, sample_instance_def]
        )
        
        result = await coordinator.select_instance(character_state, preferences)
        
        assert result == "solo_quest"

    @pytest.mark.asyncio
    async def test_select_instance_prefer_short(self, coordinator, character_state):
        """Test selection prefers short instances."""
        preferences = {"prefer_short": True}
        
        short_instance = MagicMock()
        short_instance.instance_id = "short_quest"
        short_instance.estimated_clear_time_minutes = 15
        short_instance.requirements.max_party_size = 5
        
        long_instance = MagicMock()
        long_instance.instance_id = "long_quest"
        long_instance.estimated_clear_time_minutes = 120
        long_instance.requirements.max_party_size = 5
        
        coordinator.cooldown_manager.get_available_instances = AsyncMock(
            return_value=["short_quest", "long_quest"]
        )
        coordinator.registry.get_recommended_instances = AsyncMock(
            return_value=[long_instance, short_instance]
        )
        
        result = await coordinator.select_instance(character_state, preferences)
        
        assert result == "short_quest"


class TestStartInstanceRun:
    """Test start_instance_run method - lines 154-200."""

    @pytest.mark.asyncio
    async def test_start_instance_run_unknown_instance(self, coordinator, character_state):
        """Test starting unknown instance raises error."""
        coordinator.registry.get_instance = AsyncMock(return_value=None)
        
        with pytest.raises(ValueError, match="Unknown instance"):
            await coordinator.start_instance_run("unknown_id", character_state)

    @pytest.mark.asyncio
    async def test_start_instance_run_requirements_not_met(
        self, coordinator, character_state, sample_instance_def
    ):
        """Test requirements check failure."""
        coordinator.registry.get_instance = AsyncMock(return_value=sample_instance_def)
        coordinator.registry.check_requirements = AsyncMock(
            return_value=(False, ["Missing required quest"])
        )
        
        with pytest.raises(ValueError, match="Cannot enter instance"):
            await coordinator.start_instance_run("endless_tower", character_state)

    @pytest.mark.asyncio
    async def test_start_instance_run_success(
        self, coordinator, character_state, sample_instance_def
    ):
        """Test successful instance start."""
        coordinator.registry.get_instance = AsyncMock(return_value=sample_instance_def)
        coordinator.registry.check_requirements = AsyncMock(
            return_value=(True, [])
        )
        
        mock_state = MagicMock(spec=InstanceState)
        coordinator.state_manager.start_instance = AsyncMock(return_value=mock_state)
        
        result = await coordinator.start_instance_run("endless_tower", character_state)
        
        assert result == mock_state


class TestGetNextAction:
    """Test get_next_action method - lines 202-269."""

    @pytest.mark.asyncio
    async def test_get_next_action_no_state(self, coordinator):
        """Test when no active instance."""
        coordinator.state_manager.get_current_state = MagicMock(return_value=None)
        
        result = await coordinator.get_next_action({})
        
        assert result is None

    @pytest.mark.asyncio
    async def test_get_next_action_should_abort(self, coordinator):
        """Test abort scenario."""
        mock_state = MagicMock()
        mock_state.instance_id = "endless_tower"
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.should_abort = AsyncMock(
            return_value=(True, "Party member died")
        )
        
        result = await coordinator.get_next_action({})
        
        assert result is not None
        assert result.action_type == "exit"
        assert result.priority == 10

    @pytest.mark.asyncio
    async def test_get_next_action_in_progress(self, coordinator, sample_instance_def):
        """Test action during normal progress."""
        mock_state = MagicMock()
        mock_state.instance_id = "endless_tower"
        mock_state.phase = InstancePhase.IN_PROGRESS
        mock_state.current_floor = 5
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.should_abort = AsyncMock(return_value=(False, ""))
        coordinator.registry.get_instance = AsyncMock(return_value=sample_instance_def)
        
        mock_strategy = MagicMock()
        coordinator.strategy_engine.get_strategy = AsyncMock(return_value=mock_strategy)
        
        floor_action = InstanceAction(
            action_type="clear_floor",
            priority=8,
            reason="Clear current floor"
        )
        coordinator.strategy_engine.get_floor_actions = AsyncMock(
            return_value=[floor_action]
        )
        
        result = await coordinator.get_next_action({})
        
        assert result == floor_action

    @pytest.mark.asyncio
    async def test_get_next_action_boss_fight(self, coordinator, sample_instance_def):
        """Test action during boss fight."""
        mock_state = MagicMock()
        mock_state.instance_id = "endless_tower"
        mock_state.phase = InstancePhase.BOSS_FIGHT
        mock_state.current_floor = 10
        
        game_state = {
            "boss_hp_percent": 50.0,
            "boss_name": "Tower Boss"
        }
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.should_abort = AsyncMock(return_value=(False, ""))
        coordinator.registry.get_instance = AsyncMock(return_value=sample_instance_def)
        
        mock_strategy = MagicMock()
        coordinator.strategy_engine.get_strategy = AsyncMock(return_value=mock_strategy)
        
        boss_action = InstanceAction(
            action_type="attack_boss",
            priority=9,
            reason="Attack boss"
        )
        coordinator.strategy_engine.get_boss_actions = AsyncMock(
            return_value=[boss_action]
        )
        
        result = await coordinator.get_next_action(game_state)
        
        assert result == boss_action

    @pytest.mark.asyncio
    async def test_get_next_action_looting(self, coordinator):
        """Test action during looting phase."""
        mock_state = MagicMock()
        mock_state.instance_id = "endless_tower"
        mock_state.phase = InstancePhase.LOOTING
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.should_abort = AsyncMock(return_value=(False, ""))
        
        result = await coordinator.get_next_action({})
        
        assert result is not None
        assert result.action_type == "loot"


class TestHandleEvent:
    """Test handle_event method - lines 271-317."""

    @pytest.mark.asyncio
    async def test_handle_monster_killed(self, coordinator):
        """Test monster killed event."""
        mock_state = MagicMock()
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.update_floor_progress = AsyncMock()
        
        await coordinator.handle_event("monster_killed", {"count": 5})
        
        coordinator.state_manager.update_floor_progress.assert_called_once()

    @pytest.mark.asyncio
    async def test_handle_boss_killed(self, coordinator):
        """Test boss killed event."""
        mock_state = MagicMock()
        mock_state.current_floor = 10
        mock_state.total_floors = 100
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.update_floor_progress = AsyncMock()
        coordinator.state_manager.advance_floor = AsyncMock()
        
        await coordinator.handle_event("boss_killed", {})
        
        coordinator.state_manager.advance_floor.assert_called_once()

    @pytest.mark.asyncio
    async def test_handle_death_event(self, coordinator):
        """Test death event."""
        mock_state = MagicMock()
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.record_death = AsyncMock()
        coordinator.strategy_engine.adapt_strategy = AsyncMock()
        
        await coordinator.handle_event("death", {"member_name": "TestChar"})
        
        coordinator.state_manager.record_death.assert_called_once()
        coordinator.strategy_engine.adapt_strategy.assert_called_once()

    @pytest.mark.asyncio
    async def test_handle_time_warning(self, coordinator):
        """Test time warning event."""
        mock_state = MagicMock()
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.strategy_engine.adapt_strategy = AsyncMock()
        
        await coordinator.handle_event("time_warning", {})
        
        coordinator.strategy_engine.adapt_strategy.assert_called_with(
            "time_running_low", mock_state
        )


class TestCompleteRun:
    """Test complete_run method - lines 319-372."""

    @pytest.mark.asyncio
    async def test_complete_run_no_state(self, coordinator):
        """Test completing without active instance."""
        coordinator.state_manager.get_current_state = MagicMock(return_value=None)
        
        with pytest.raises(ValueError, match="No active instance"):
            await coordinator.complete_run()

    @pytest.mark.asyncio
    async def test_complete_run_success(self, coordinator, sample_instance_def):
        """Test successful completion."""
        mock_state = MagicMock()
        mock_state.instance_id = "endless_tower"
        mock_state.instance_name = "Endless Tower"
        mock_state.phase = InstancePhase.COMPLETED
        mock_state.elapsed_seconds = 3600.0
        mock_state.total_floors = 100
        mock_state.deaths = 2
        mock_state.total_loot = ["Card1", "Card2"]
        mock_state.loot_value_estimate = 1000000
        mock_state.overall_progress = 100.0
        mock_state.party_members = ["TestChar"]
        mock_state.floors = {
            1: MagicMock(is_cleared=True),
            2: MagicMock(is_cleared=True)
        }
        
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        coordinator.state_manager.complete_instance = AsyncMock(return_value=mock_state)
        coordinator.registry.get_instance = AsyncMock(return_value=sample_instance_def)
        coordinator.cooldown_manager.record_completion = AsyncMock()
        coordinator.strategy_engine.learn_from_run = AsyncMock()
        
        report = await coordinator.complete_run()
        
        assert isinstance(report, InstanceRunReport)
        assert report.success is True
        assert report.instance_id == "endless_tower"


class TestGetDailyPlan:
    """Test get_daily_plan method - lines 374-435."""

    @pytest.mark.asyncio
    async def test_get_daily_plan(self, coordinator, character_state, sample_instance_def):
        """Test daily plan generation."""
        all_instances = [sample_instance_def]
        
        coordinator.registry.get_all_instances = MagicMock(return_value=all_instances)
        coordinator.registry.check_requirements = AsyncMock(return_value=(True, []))
        coordinator.cooldown_manager.get_optimal_schedule = AsyncMock(
            return_value={"endless_tower": datetime.now()}
        )
        
        plan = await coordinator.get_daily_plan(character_state)
        
        assert len(plan) > 0
        assert isinstance(plan[0], PlannedInstance)


class TestGetCurrentState:
    """Test get_current_state method - line 437-439."""

    def test_get_current_state(self, coordinator):
        """Test getting current state."""
        mock_state = MagicMock()
        coordinator.state_manager.get_current_state = MagicMock(return_value=mock_state)
        
        result = coordinator.get_current_state()
        
        assert result == mock_state


class TestGetCooldownSummary:
    """Test get_cooldown_summary method - lines 441-443."""

    def test_get_cooldown_summary(self, coordinator):
        """Test getting cooldown summary."""
        coordinator.cooldown_manager.get_cooldown_summary = MagicMock(
            return_value={"cooldowns": []}
        )
        
        result = coordinator.get_cooldown_summary("TestChar")
        
        assert "cooldowns" in result