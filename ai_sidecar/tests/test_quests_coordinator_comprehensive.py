"""
Comprehensive tests for quests/coordinator.py - Batch 7.

Target: Push coverage from 88.55% to 95%+
Focus on uncovered lines: 72, 184-186, 221, 328, 352, 364, 389, 406, 408
"""

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import tempfile
import pytest

from ai_sidecar.quests.coordinator import QuestCoordinator
from ai_sidecar.quests.core import Quest, QuestObjective, QuestReward, QuestObjectiveType, QuestStatus, QuestType
from ai_sidecar.quests.daily import DailyQuestCategory


@pytest.fixture
def temp_data_dir():
    """Create temporary data directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def coordinator(temp_data_dir):
    """Create quest coordinator."""
    return QuestCoordinator(temp_data_dir)


@pytest.fixture
def sample_quest():
    """Create sample quest."""
    return Quest(
        quest_id=1001,
        quest_name="Test Quest",
        quest_type=QuestType.MAIN_STORY,
        description="Test quest description",
        start_npc="TestNPC",
        start_map="prontera",
        end_npc="TestNPC",
        end_map="prontera",
        min_level=50,
        max_level=99,
        objectives=[
            QuestObjective(
                objective_id=1,
                objective_type=QuestObjectiveType.KILL_MONSTER,
                target_id=1002,
                target_name="Poring",
                required_count=10,
                current_count=5,
                map_name="prt_fild08"
            )
        ],
        rewards=[
            QuestReward(
                reward_type="exp",
                reward_name="Base EXP",
                quantity=100000
            )
        ],
        status=QuestStatus.IN_PROGRESS,
        base_exp_reward=100000,
        job_exp_reward=50000,
        zeny_reward=10000
    )


@pytest.fixture
def character_state():
    """Create character state."""
    return {
        "name": "TestChar",
        "level": 75,
        "job": "High Priest"
    }


class TestUpdate:
    """Test update method - lines 54-79."""

    @pytest.mark.asyncio
    async def test_update_with_available_quests(self, coordinator, character_state):
        """Test update when quests available."""
        coordinator.daily._check_daily_reset = MagicMock()
        coordinator.quests.get_available_quests = MagicMock(
            return_value=["Quest1", "Quest2"]
        )
        
        await coordinator.update(character_state)
        
        coordinator.daily._check_daily_reset.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_error_handling(self, coordinator, character_state):
        """Test update error handling."""
        coordinator.daily._check_daily_reset = MagicMock(
            side_effect=Exception("Test error")
        )
        
        # Should not raise exception
        await coordinator.update(character_state)


class TestGetQuestPriorities:
    """Test get_quest_priorities method - lines 90-145."""

    def test_quest_priorities_with_completable(self, coordinator, sample_quest):
        """Test priority for completable quests."""
        # Make quest complete by completing objectives
        for obj in sample_quest.objectives:
            obj.current_count = obj.required_count
        
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        coordinator.daily.get_priority_dailies = MagicMock(return_value=[])
        coordinator.achievements.get_near_completion = MagicMock(return_value=[])
        
        priorities = coordinator.get_quest_priorities({})
        
        # Completable quests should be priority 1
        assert len(priorities) > 0
        assert priorities[0]["priority"] == 1
        assert priorities[0]["action"] == "turn_in"


class TestGetOptimalActivity:
    """Test get_optimal_activity method - lines 147-225."""

    def test_optimal_activity_short_session(self, coordinator, character_state):
        """Test optimal activity for short session."""
        coordinator.daily.calculate_daily_exp_potential = MagicMock(
            return_value={"total_exp": 500000}
        )
        coordinator.hunting.get_active_hunts = MagicMock(return_value=[])
        
        # Mock priority daily
        daily_quest = MagicMock()
        daily_quest.quest_id = 2001
        coordinator.daily.get_priority_dailies = MagicMock(
            return_value=[{
                "quest": daily_quest,
                "estimated_time_minutes": 20,
                "exp_total": 300000
            }]
        )
        
        activity = coordinator.get_optimal_activity(character_state, 25)
        
        assert activity["activity_type"] == "daily_quest"

    def test_optimal_activity_medium_session_gramps(self, coordinator, character_state):
        """Test optimal activity for medium session with Gramps."""
        coordinator.daily.calculate_daily_exp_potential = MagicMock(
            return_value={"total_exp": 500000}
        )
        coordinator.hunting.get_active_hunts = MagicMock(return_value=[])
        coordinator.daily.is_daily_completed = MagicMock(return_value=False)
        
        # Mock Gramps quest
        gramps_quest = MagicMock()
        gramps_quest.exp_reward = 500000
        gramps_quest.job_exp_reward = 300000
        coordinator.daily.get_gramps_quest = MagicMock(return_value=gramps_quest)
        
        activity = coordinator.get_optimal_activity(character_state, 45)
        
        assert activity["activity_type"] == "gramps_quest"

    def test_optimal_activity_long_session_hunting(self, coordinator, character_state):
        """Test optimal activity for long session with hunting."""
        coordinator.daily.calculate_daily_exp_potential = MagicMock(
            return_value={"total_exp": 500000}
        )
        
        # Mock active hunting quest
        hunt_quest = MagicMock()
        hunt_quest.quest_id = 3001
        coordinator.hunting.get_active_hunts = MagicMock(return_value=[hunt_quest])
        coordinator.hunting.calculate_exp_per_kill = MagicMock(
            return_value={"total_exp": 1000000}
        )
        coordinator.hunting.get_best_farming_map = MagicMock(
            return_value=("prt_fild08", 0.9)
        )
        
        activity = coordinator.get_optimal_activity(character_state, 120)
        
        assert activity["activity_type"] == "hunting_quest"

    def test_optimal_activity_default_grinding(self, coordinator, character_state):
        """Test default grinding fallback."""
        coordinator.daily.calculate_daily_exp_potential = MagicMock(
            return_value={"total_exp": 0}
        )
        coordinator.hunting.get_active_hunts = MagicMock(return_value=[])
        coordinator.daily.get_priority_dailies = MagicMock(return_value=[])
        
        activity = coordinator.get_optimal_activity(character_state, 30)
        
        assert activity["activity_type"] == "grinding"


class TestRecordMonsterKill:
    """Test record_monster_kill method - lines 227-264."""

    def test_record_monster_kill(self, coordinator):
        """Test recording monster kill."""
        coordinator.hunting.record_kill = MagicMock(return_value=[3001])
        coordinator.hunting.get_hunting_progress = MagicMock(
            return_value={"killed": 5, "required": 10}
        )
        
        updates = coordinator.record_monster_kill(1002, "Poring")
        
        assert len(updates) > 0
        assert updates[0]["type"] == "hunting_quest"


class TestRecordItemCollected:
    """Test record_item_collected method - lines 266-309."""

    def test_record_item_collected(self, coordinator, sample_quest):
        """Test recording item collection."""
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        coordinator.quests.update_objective = MagicMock()
        
        updates = coordinator.record_item_collected(1002, "Poring Card", 1)
        
        # May or may not have updates depending on quest objectives
        assert isinstance(updates, list)


class TestGetNextQuestAction:
    """Test get_next_quest_action method - lines 311-367."""

    @pytest.mark.asyncio
    async def test_next_action_turn_in_complete_quest(self, coordinator, sample_quest):
        """Test action to turn in complete quest."""
        # Complete all objectives
        for obj in sample_quest.objectives:
            obj.current_count = obj.required_count
        
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        
        action = await coordinator.get_next_quest_action({}, "prontera")
        
        assert action["action"] == "turn_in_quest"
        assert action["quest_id"] == sample_quest.quest_id

    @pytest.mark.asyncio
    async def test_next_action_no_quests(self, coordinator):
        """Test action when no quests."""
        coordinator.quests.get_active_quests = MagicMock(return_value=[])
        coordinator.get_quest_priorities = MagicMock(return_value=[])
        
        action = await coordinator.get_next_quest_action({}, "prontera")
        
        assert action["action"] == "no_quests"

    @pytest.mark.asyncio
    async def test_next_action_progress_objective(self, coordinator, sample_quest):
        """Test action to progress quest objective."""
        # Ensure quest is NOT complete (objectives still need progress)
        for obj in sample_quest.objectives:
            obj.current_count = min(obj.current_count, obj.required_count - 1)
        
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        coordinator.get_quest_priorities = MagicMock(
            return_value=[{"quest": sample_quest, "priority": 3}]
        )
        
        action = await coordinator.get_next_quest_action({}, "prontera")
        
        assert action["action"] == "progress_objective"
        assert "objective" in action


class TestCalculateDailyCompletionRate:
    """Test calculate_daily_completion_rate method - lines 369-376."""

    def test_calculate_daily_completion_rate(self, coordinator):
        """Test daily completion rate calculation."""
        coordinator.daily.get_completion_summary = MagicMock(
            return_value={"completion_rate": 75.0}
        )
        
        rate = coordinator.calculate_daily_completion_rate()
        
        assert rate == 75.0


class TestGetPendingRewards:
    """Test get_pending_rewards method - lines 378-416."""

    def test_get_pending_rewards_with_complete_quest(self, coordinator, sample_quest):
        """Test getting pending rewards from complete quest."""
        # Complete all objectives
        for obj in sample_quest.objectives:
            obj.current_count = obj.required_count
        
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        coordinator.achievements.achievements = {}
        
        rewards = coordinator.get_pending_rewards()
        
        assert len(rewards) > 0
        assert rewards[0]["type"] == "quest"

    def test_get_pending_rewards_with_achievement(self, coordinator):
        """Test getting pending rewards from achievement."""
        coordinator.quests.get_active_quests = MagicMock(return_value=[])
        
        # Mock complete achievement
        achievement = MagicMock()
        achievement.achievement_id = 5001
        achievement.achievement_name = "Monster Hunter"
        achievement.is_complete = True
        coordinator.achievements.achievements = {5001: achievement}
        coordinator.achievements.claim_rewards = MagicMock(
            return_value=[{"type": "item", "name": "Reward Box"}]
        )
        
        rewards = coordinator.get_pending_rewards()
        
        achievement_reward = next(
            (r for r in rewards if r["type"] == "achievement"),
            None
        )
        assert achievement_reward is not None


class TestGetStatistics:
    """Test get_statistics method - lines 418-431."""

    def test_get_statistics(self, coordinator):
        """Test statistics generation."""
        coordinator.quests.get_active_quests = MagicMock(return_value=[])
        coordinator.quests.completed_quests = {}
        coordinator.daily.get_completion_summary = MagicMock(
            return_value={"completion_rate": 80.0}
        )
        coordinator.achievements.get_statistics = MagicMock(
            return_value={"total": 100}
        )
        coordinator.hunting.get_active_hunts = MagicMock(return_value=[])
        
        stats = coordinator.get_statistics()
        
        assert "active_quests" in stats
        assert "completed_quests" in stats
        assert "daily_completion" in stats
        assert "achievement_stats" in stats


class TestIntegrationScenarios:
    """Integration tests for complete workflows."""

    @pytest.mark.asyncio
    async def test_complete_quest_workflow(self, coordinator, sample_quest, character_state):
        """Test complete quest workflow."""
        # Start with incomplete quest - reset objectives
        for obj in sample_quest.objectives:
            obj.current_count = obj.required_count - 1
        
        coordinator.quests.get_active_quests = MagicMock(return_value=[sample_quest])
        coordinator.get_quest_priorities = MagicMock(
            return_value=[{"quest": sample_quest, "priority": 3}]
        )
        
        # Get next action (should be progress)
        action = await coordinator.get_next_quest_action(character_state, "prontera")
        assert action["action"] == "progress_objective"
        
        # Record monster kills
        coordinator.hunting.record_kill = MagicMock(return_value=[1001])
        coordinator.hunting.get_hunting_progress = MagicMock(
            return_value={"killed": 10, "required": 10}
        )
        
        updates = coordinator.record_monster_kill(1002, "Poring")
        assert len(updates) > 0
        
        # Complete all quest objectives
        for obj in sample_quest.objectives:
            obj.current_count = obj.required_count
        
        # Get next action (should be turn in)
        action = await coordinator.get_next_quest_action(character_state, "prontera")
        assert action["action"] == "turn_in_quest"