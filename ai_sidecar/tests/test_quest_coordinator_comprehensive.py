"""
Comprehensive tests for quests/coordinator.py to achieve 90%+ coverage.

Tests all coordinator methods, quest priority logic, activity recommendations,
and integrated quest system operations.
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.quests.coordinator import QuestCoordinator
from ai_sidecar.quests.core import Quest, QuestObjective, QuestObjectiveType, QuestReward, QuestType
from ai_sidecar.quests.hunting import HuntingQuest, HuntingTarget


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test data."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    (data_dir / "quests.json").write_text('{"quests": []}')
    (data_dir / "daily_quests.json").write_text(
        '{"gramps_quests": [], "eden_quests": {}, "board_quests": {}}'
    )
    (data_dir / "achievements.json").write_text('{"achievements": []}')
    (data_dir / "hunting_quests.json").write_text('{"hunting_quests": []}')
    
    return data_dir


@pytest.fixture
def character_state() -> dict:
    """Sample character state."""
    return {
        "level": 50,
        "job_level": 40,
        "job": "Knight",
        "map": "prontera",
        "hp": 5000,
        "max_hp": 6000,
        "sp": 300,
        "max_sp": 500
    }


class TestQuestCoordinatorInit:
    """Test QuestCoordinator initialization."""
    
    def test_init_creates_subsystems(self, data_dir):
        """Test coordinator initializes all quest subsystems."""
        coord = QuestCoordinator(data_dir)
        
        assert coord.quests is not None
        assert coord.daily is not None
        assert coord.achievements is not None
        assert coord.hunting is not None
        
    def test_init_logs_creation(self, data_dir):
        """Test coordinator logs initialization."""
        coord = QuestCoordinator(data_dir)
        
        assert coord.log is not None


class TestUpdate:
    """Test update method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    @pytest.mark.asyncio
    async def test_update_checks_daily_reset(self, coordinator, character_state):
        """Test update checks for daily reset."""
        with patch.object(coordinator.daily, '_check_daily_reset') as mock_reset:
            await coordinator.update(character_state)
            mock_reset.assert_called_once()
            
    @pytest.mark.asyncio
    async def test_update_checks_available_quests(self, coordinator, character_state):
        """Test update checks for available quests."""
        with patch.object(coordinator.quests, 'get_available_quests', return_value=[]) as mock_get:
            await coordinator.update(character_state)
            mock_get.assert_called_once_with(character_state)
            
    @pytest.mark.asyncio
    async def test_update_handles_exception(self, coordinator, character_state):
        """Test update handles exceptions gracefully."""
        with patch.object(coordinator.quests, 'get_available_quests', side_effect=Exception("Test error")):
            # Should not raise
            await coordinator.update(character_state)


class TestGetAllActiveQuests:
    """Test get_all_active_quests method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_get_all_active_quests_empty(self, coordinator):
        """Test returns empty list when no active quests."""
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
            result = coordinator.get_all_active_quests()
            assert result == []
            
    def test_get_all_active_quests_with_quests(self, coordinator):
        """Test returns active quests."""
        mock_quests = [
            Mock(quest_id=1, quest_name="Quest1"),
            Mock(quest_id=2, quest_name="Quest2")
        ]
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=mock_quests):
            result = coordinator.get_all_active_quests()
            assert len(result) == 2


class TestGetQuestPriorities:
    """Test get_quest_priorities method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_priorities_completable_quests_first(self, coordinator, character_state):
        """Test completable quests have priority 1."""
        complete_quest = Mock()
        complete_quest.is_complete = True
        complete_quest.quest_id = 1
        complete_quest.quest_name = "Complete Quest"
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[complete_quest]):
            priorities = coordinator.get_quest_priorities(character_state)
            
            assert len(priorities) > 0
            assert priorities[0]["priority"] == 1
            assert priorities[0]["action"] == "turn_in"
            
    def test_priorities_daily_quests_second(self, coordinator, character_state):
        """Test daily quests have priority 2."""
        daily_quest = Mock()
        daily_quest.quest_id = 2
        
        mock_daily_info = {
            "quest": daily_quest,
            "category": Mock(value="gramps"),
            "priority_score": 100
        }
        
        with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[mock_daily_info]):
            with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
                priorities = coordinator.get_quest_priorities(character_state)
                
                daily_priorities = [p for p in priorities if p["priority"] == 2]
                assert len(daily_priorities) > 0
                
    def test_priorities_in_progress_quests_third(self, coordinator, character_state):
        """Test in-progress quests have priority 3."""
        progress_quest = Mock()
        progress_quest.is_complete = False
        progress_quest.overall_progress = 50.0
        progress_quest.quest_id = 3
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[progress_quest]):
            with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[]):
                priorities = coordinator.get_quest_priorities(character_state)
                
                progress_priorities = [p for p in priorities if p.get("priority") == 3]
                assert len(progress_priorities) > 0
                
    def test_priorities_near_achievements_fourth(self, coordinator, character_state):
        """Test near-complete achievements have priority 4."""
        achievement = Mock()
        achievement.achievement_id = 101
        achievement.progress_percent = 80.0
        
        with patch.object(coordinator.achievements, 'get_near_completion', return_value=[achievement]):
            with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
                with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[]):
                    priorities = coordinator.get_quest_priorities(character_state)
                    
                    achievement_priorities = [p for p in priorities if "achievement" in p]
                    assert len(achievement_priorities) > 0
                    
    def test_priorities_sorted_by_priority(self, coordinator, character_state):
        """Test priorities are sorted correctly."""
        complete_quest = Mock(is_complete=True, quest_id=1, overall_progress=100)
        progress_quest = Mock(is_complete=False, quest_id=2, overall_progress=50)
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[progress_quest, complete_quest]):
            with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[]):
                priorities = coordinator.get_quest_priorities(character_state)
                
                # First should be complete quest (priority 1)
                if len(priorities) >= 2:
                    assert priorities[0]["priority"] <= priorities[1]["priority"]


class TestGetOptimalActivity:
    """Test get_optimal_activity method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_short_session_recommends_daily(self, coordinator, character_state):
        """Test short session (< 30 min) recommends quick dailies."""
        mock_daily = {
            "quest": Mock(quest_name="Quick Daily"),
            "estimated_time_minutes": 15,
            "exp_total": 10000
        }
        
        with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[mock_daily]):
            activity = coordinator.get_optimal_activity(character_state, 25)
            
            assert activity["activity_type"] == "daily_quest"
            assert activity["estimated_time"] == 15
            
    def test_medium_session_recommends_gramps(self, coordinator, character_state):
        """Test medium session (30-60 min) recommends gramps."""
        mock_gramps = Mock(
            quest_name="Gramps Quest",
            exp_reward=50000,
            job_exp_reward=30000
        )
        
        with patch.object(coordinator.daily, 'is_daily_completed', return_value=False):
            with patch.object(coordinator.daily, 'get_gramps_quest', return_value=mock_gramps):
                activity = coordinator.get_optimal_activity(character_state, 45)
                
                assert activity["activity_type"] == "gramps_quest"
                assert activity["estimated_time"] == 45
                
    def test_long_session_with_hunting_quest(self, coordinator, character_state):
        """Test long session with active hunting quest."""
        mock_hunt = Mock(quest_id=1001)
        
        with patch.object(coordinator.hunting, 'get_active_hunts', return_value=[mock_hunt]):
            with patch.object(coordinator.hunting, 'calculate_exp_per_kill', return_value={"total_exp": 100000}):
                with patch.object(coordinator.hunting, 'get_best_farming_map', return_value=("map1", ["map1"])):
                    activity = coordinator.get_optimal_activity(character_state, 90)
                    
                    assert activity["activity_type"] == "hunting_quest"
                    
    def test_long_session_no_hunting_daily_routine(self, coordinator, character_state):
        """Test long session without hunting recommends daily routine."""
        with patch.object(coordinator.hunting, 'get_active_hunts', return_value=[]):
            with patch.object(coordinator.daily, 'calculate_daily_exp_potential', return_value={"total_exp": 50000}):
                activity = coordinator.get_optimal_activity(character_state, 90)
                
                assert activity["activity_type"] == "daily_routine"
                
    def test_default_grinding_fallback(self, coordinator, character_state):
        """Test fallback to grinding when no quests available."""
        with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[]):
            with patch.object(coordinator.hunting, 'get_active_hunts', return_value=[]):
                with patch.object(coordinator.daily, 'is_daily_completed', return_value=True):
                    activity = coordinator.get_optimal_activity(character_state, 30)
                    
                    assert activity["activity_type"] in ["grinding", "daily_quest"]


class TestRecordMonsterKill:
    """Test record_monster_kill method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_records_hunting_quest_kills(self, coordinator):
        """Test records kills for hunting quests."""
        with patch.object(coordinator.hunting, 'record_kill', return_value=[1001, 1002]) as mock_record:
            with patch.object(coordinator.hunting, 'get_hunting_progress', return_value={"progress": 50}):
                updates = coordinator.record_monster_kill(1234, "Poring")
                
                mock_record.assert_called_once_with(1234)
                assert len(updates) == 2
                
    def test_returns_update_info(self, coordinator):
        """Test returns quest update information."""
        with patch.object(coordinator.hunting, 'record_kill', return_value=[1001]):
            with patch.object(coordinator.hunting, 'get_hunting_progress', return_value={"quest_id": 1001, "progress": 50}):
                updates = coordinator.record_monster_kill(1234, "Poring")
                
                assert updates[0]["type"] == "hunting_quest"
                assert updates[0]["quest_id"] == 1001


class TestRecordItemCollected:
    """Test record_item_collected method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_updates_quest_objectives(self, coordinator):
        """Test updates quest objectives for item collection."""
        mock_objective = Mock()
        mock_objective.target_id = 501
        mock_objective.objective_id = 1
        mock_objective.is_complete = False
        mock_objective.current_count = 5
        mock_objective.required_count = 10
        
        mock_quest = Mock()
        mock_quest.quest_id = 100
        mock_quest.objectives = [mock_objective]
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[mock_quest]):
            with patch.object(coordinator.quests, 'update_objective') as mock_update:
                updates = coordinator.record_item_collected(501, "Red Potion", 3)
                
                mock_update.assert_called_once_with(100, 1, 3)
                assert len(updates) == 1
                
    def test_skips_complete_objectives(self, coordinator):
        """Test skips objectives that are already complete."""
        mock_objective = Mock()
        mock_objective.target_id = 501
        mock_objective.is_complete = True
        
        mock_quest = Mock()
        mock_quest.quest_id = 100
        mock_quest.objectives = [mock_objective]
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[mock_quest]):
            with patch.object(coordinator.quests, 'update_objective') as mock_update:
                updates = coordinator.record_item_collected(501, "Item", 1)
                
                mock_update.assert_not_called()


class TestGetNextQuestAction:
    """Test get_next_quest_action method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    @pytest.mark.asyncio
    async def test_turn_in_complete_quest_first(self, coordinator, character_state):
        """Test prioritizes turning in complete quests."""
        complete_quest = Mock()
        complete_quest.is_complete = True
        complete_quest.quest_id = 100
        complete_quest.quest_name = "Complete Quest"
        complete_quest.end_npc = "NPC"
        complete_quest.end_map = "prontera"
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[complete_quest]):
            action = await coordinator.get_next_quest_action(character_state, "prontera")
            
            assert action["action"] == "turn_in_quest"
            assert action["quest_id"] == 100
            
    @pytest.mark.asyncio
    async def test_no_quests_recommendation(self, coordinator, character_state):
        """Test returns no_quests when no priorities."""
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
            with patch.object(coordinator, 'get_quest_priorities', return_value=[]):
                action = await coordinator.get_next_quest_action(character_state, "prontera")
                
                assert action["action"] == "no_quests"
                
    @pytest.mark.asyncio
    async def test_progress_objective_action(self, coordinator, character_state):
        """Test returns progress objective action."""
        mock_objective = Mock()
        mock_objective.is_complete = False
        mock_objective.objective_type = Mock(value="kill_monster")
        mock_objective.target_name = "Poring"
        mock_objective.current_count = 5
        mock_objective.required_count = 10
        mock_objective.map_name = "prontera"
        
        mock_quest = Mock()
        mock_quest.is_complete = False
        mock_quest.quest_id = 100
        mock_quest.objectives = [mock_objective]
        
        priority = {"quest": mock_quest, "priority": 2}
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
            with patch.object(coordinator, 'get_quest_priorities', return_value=[priority]):
                action = await coordinator.get_next_quest_action(character_state, "prontera")
                
                assert action["action"] == "progress_objective"
                assert action["quest_id"] == 100


class TestCalculateDailyCompletionRate:
    """Test calculate_daily_completion_rate method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_returns_completion_rate(self, coordinator):
        """Test returns daily completion rate."""
        with patch.object(coordinator.daily, 'get_completion_summary', return_value={"completion_rate": 75.0}):
            rate = coordinator.calculate_daily_completion_rate()
            
            assert rate == 75.0


class TestGetPendingRewards:
    """Test get_pending_rewards method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_includes_complete_quests(self, coordinator):
        """Test includes rewards from complete quests."""
        mock_reward = Mock()
        mock_reward.reward_type = "exp"
        mock_reward.reward_name = "EXP"
        mock_reward.quantity = 1000
        
        complete_quest = Mock()
        complete_quest.is_complete = True
        complete_quest.quest_id = 100
        complete_quest.quest_name = "Quest"
        complete_quest.rewards = [mock_reward]
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[complete_quest]):
            with patch.object(coordinator.achievements, 'achievements', {}):
                pending = coordinator.get_pending_rewards()
                
                assert len(pending) == 1
                assert pending[0]["type"] == "quest"
                
    def test_includes_complete_achievements(self, coordinator):
        """Test includes rewards from complete achievements."""
        achievement = Mock()
        achievement.is_complete = True
        achievement.achievement_id = 101
        achievement.achievement_name = "Achievement"
        
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
            with patch.object(coordinator.achievements, 'achievements', {101: achievement}):
                with patch.object(coordinator.achievements, 'claim_rewards', return_value=[{"reward": "exp"}]):
                    pending = coordinator.get_pending_rewards()
                    
                    achievement_rewards = [p for p in pending if p["type"] == "achievement"]
                    assert len(achievement_rewards) == 1


class TestGetStatistics:
    """Test get_statistics method."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_returns_comprehensive_stats(self, coordinator):
        """Test returns all quest statistics."""
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[Mock(), Mock()]):
            with patch.object(coordinator.quests, 'completed_quests', {1: True, 2: True}):
                with patch.object(coordinator.daily, 'get_completion_summary', return_value={"rate": 50}):
                    with patch.object(coordinator.achievements, 'get_statistics', return_value={"total": 10}):
                        with patch.object(coordinator.hunting, 'get_active_hunts', return_value=[Mock()]):
                            stats = coordinator.get_statistics()
                            
                            assert "active_quests" in stats
                            assert stats["active_quests"] == 2
                            assert "completed_quests" in stats
                            assert stats["completed_quests"] == 2
                            assert "daily_completion" in stats
                            assert "achievement_stats" in stats
                            assert "active_hunts" in stats
                            assert stats["active_hunts"] == 1


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        return QuestCoordinator(data_dir)
    
    def test_empty_priorities_list(self, coordinator, character_state):
        """Test handles empty priorities gracefully."""
        with patch.object(coordinator.quests, 'get_active_quests', return_value=[]):
            with patch.object(coordinator.daily, 'get_priority_dailies', return_value=[]):
                with patch.object(coordinator.achievements, 'get_near_completion', return_value=[]):
                    priorities = coordinator.get_quest_priorities(character_state)
                    
                    assert priorities == []
                    
    def test_none_character_state_fields(self, coordinator):
        """Test handles missing character state fields."""
        incomplete_state = {"level": 50}  # Missing other fields
        
        # Should not crash
        with patch.object(coordinator.quests, 'get_available_quests', return_value=[]):
            with patch.object(coordinator.daily, '_check_daily_reset'):
                import asyncio
                asyncio.run(coordinator.update(incomplete_state))
                
    def test_record_kill_no_affected_quests(self, coordinator):
        """Test record kill when no quests are affected."""
        with patch.object(coordinator.hunting, 'record_kill', return_value=[]):
            updates = coordinator.record_monster_kill(9999, "Unknown Monster")
            
            assert updates == []