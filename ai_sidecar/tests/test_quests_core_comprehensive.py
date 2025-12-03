"""
Comprehensive tests for quest core system - Batch 3.

Tests quest tracking, objective progress, rewards,
and quest recommendations.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from ai_sidecar.quests.core import (
    Quest,
    QuestManager,
    QuestObjective,
    QuestObjectiveType,
    QuestRequirement,
    QuestReward,
    QuestStatus,
    QuestType,
)


@pytest.fixture
def temp_quest_data_dir(tmp_path):
    """Create temporary data directory with quest data."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    quests_data = {
        "quests": [
            {
                "quest_id": 1,
                "quest_name": "Collect Jellopy",
                "quest_type": "hunting",
                "description": "Collect 10 Jellopy",
                "objectives": [
                    {
                        "objective_id": 1,
                        "objective_type": "collect_item",
                        "target_id": 909,
                        "target_name": "Jellopy",
                        "required_count": 10
                    }
                ],
                "requirements": [],
                "rewards": [
                    {
                        "reward_type": "exp_base",
                        "reward_id": None,
                        "reward_name": "Base Experience",
                        "quantity": 1000
                    }
                ],
                "base_exp_reward": 1000,
                "job_exp_reward": 500,
                "zeny_reward": 100,
                "min_level": 1,
                "max_level": 99,
                "is_daily": False,
                "is_repeatable": False,
                "start_npc": "Training Grounds NPC",
                "start_map": "new_1-2"
            },
            {
                "quest_id": 2,
                "quest_name": "Kill Porings",
                "quest_type": "hunting",
                "description": "Kill 20 Porings",
                "objectives": [
                    {
                        "objective_id": 1,
                        "objective_type": "kill_monster",
                        "target_id": 1002,
                        "target_name": "Poring",
                        "required_count": 20
                    }
                ],
                "requirements": [
                    {
                        "requirement_type": "level",
                        "requirement_id": None,
                        "requirement_name": "Level 10",
                        "required_value": 10
                    }
                ],
                "rewards": [],
                "base_exp_reward": 2000,
                "job_exp_reward": 1000,
                "min_level": 10,
                "max_level": 99
            },
            {
                "quest_id": 3,
                "quest_name": "Daily Hunting",
                "quest_type": "daily",
                "description": "Daily hunting quest",
                "objectives": [
                    {
                        "objective_id": 1,
                        "objective_type": "kill_monster",
                        "target_id": 1063,
                        "target_name": "Lunatic",
                        "required_count": 50
                    }
                ],
                "requirements": [],
                "rewards": [],
                "base_exp_reward": 5000,
                "job_exp_reward": 2500,
                "is_daily": True,
                "cooldown_hours": 24,
                "min_level": 20,
                "max_level": 99
            },
            {
                "quest_id": 4,
                "quest_name": "Job Change Quest",
                "quest_type": "job_change",
                "description": "Complete job change",
                "objectives": [
                    {
                        "objective_id": 1,
                        "objective_type": "talk_npc",
                        "target_id": 1,
                        "target_name": "Job Master",
                        "required_count": 1
                    }
                ],
                "requirements": [
                    {
                        "requirement_type": "job_level",
                        "requirement_id": None,
                        "requirement_name": "Job Level 40",
                        "required_value": 40
                    }
                ],
                "rewards": [],
                "min_level": 1,
                "max_level": 99,
                "job_requirements": ["Novice", "First Class"]
            }
        ]
    }
    
    quest_file = data_dir / "quests.json"
    quest_file.write_text(json.dumps(quests_data))
    
    return data_dir


class TestQuestManagerInit:
    """Test QuestManager initialization."""
    
    def test_init_loads_quests(self, temp_quest_data_dir):
        """Test quests are loaded on init."""
        manager = QuestManager(temp_quest_data_dir)
        
        assert len(manager.quests) == 4
        assert 1 in manager.quests
        assert manager.quests[1].quest_name == "Collect Jellopy"
    
    def test_init_missing_file(self, tmp_path):
        """Test init with missing file."""
        manager = QuestManager(tmp_path / "nonexistent")
        
        # Should not crash
        assert len(manager.quests) == 0


class TestQuestObjective:
    """Test QuestObjective model."""
    
    def test_objective_is_complete(self):
        """Test objective completion check."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_id=909,
            target_name="Jellopy",
            required_count=10,
            current_count=10
        )
        
        assert obj.is_complete
    
    def test_objective_progress_percent(self):
        """Test progress percentage calculation."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_id=1002,
            target_name="Poring",
            required_count=20,
            current_count=10
        )
        
        assert obj.progress_percent == 50.0
    
    def test_objective_update_progress(self):
        """Test updating progress."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_id=909,
            target_name="Jellopy",
            required_count=10,
            current_count=5
        )
        
        completed = obj.update_progress(5)
        
        assert obj.current_count == 10
        assert completed
    
    def test_objective_update_progress_overflow(self):
        """Test progress doesn't overflow."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_id=909,
            target_name="Jellopy",
            required_count=10,
            current_count=8
        )
        
        obj.update_progress(5)
        
        # Should cap at required_count
        assert obj.current_count == 10


class TestQuest:
    """Test Quest model."""
    
    def test_quest_is_complete(self):
        """Test quest completion check."""
        quest = Quest(
            quest_id=1,
            quest_name="Test Quest",
            quest_type=QuestType.HUNTING,
            description="Test",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=1002,
                    target_name="Poring",
                    required_count=10,
                    current_count=10
                )
            ]
        )
        
        assert quest.is_complete
    
    def test_quest_overall_progress(self):
        """Test overall progress calculation."""
        quest = Quest(
            quest_id=1,
            quest_name="Test Quest",
            quest_type=QuestType.HUNTING,
            description="Test",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=1002,
                    target_name="Poring",
                    required_count=10,
                    current_count=5
                ),
                QuestObjective(
                    objective_id=2,
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=909,
                    target_name="Jellopy",
                    required_count=10,
                    current_count=10
                )
            ]
        )
        
        # Average of 50% and 100%
        assert quest.overall_progress == 75.0
    
    def test_quest_can_start(self):
        """Test can start check."""
        quest = Quest(
            quest_id=1,
            quest_name="Test Quest",
            quest_type=QuestType.HUNTING,
            description="Test",
            status=QuestStatus.NOT_STARTED
        )
        
        assert quest.can_start
    
    def test_quest_cannot_start_active(self):
        """Test cannot start active quest."""
        quest = Quest(
            quest_id=1,
            quest_name="Test Quest",
            quest_type=QuestType.HUNTING,
            description="Test",
            status=QuestStatus.IN_PROGRESS
        )
        
        assert not quest.can_start
    
    def test_quest_cooldown_remaining(self):
        """Test cooldown calculation."""
        quest = Quest(
            quest_id=1,
            quest_name="Daily Quest",
            quest_type=QuestType.DAILY,
            description="Test",
            is_daily=True,
            cooldown_hours=24,
            last_completed=datetime.now() - timedelta(hours=12)
        )
        
        remaining = quest.get_cooldown_remaining()
        
        assert remaining is not None
        assert remaining.total_seconds() > 0


class TestQuestStarting:
    """Test quest starting."""
    
    def test_start_quest(self, temp_quest_data_dir):
        """Test starting a quest."""
        manager = QuestManager(temp_quest_data_dir)
        
        result = manager.start_quest(1)
        
        assert result
        assert 1 in manager.active_quests
        assert manager.active_quests[1].status == QuestStatus.IN_PROGRESS
    
    def test_start_nonexistent_quest(self, temp_quest_data_dir):
        """Test starting nonexistent quest fails."""
        manager = QuestManager(temp_quest_data_dir)
        
        result = manager.start_quest(999)
        
        assert not result
    
    def test_start_quest_cannot_start(self, temp_quest_data_dir):
        """Test starting quest that can't be started."""
        manager = QuestManager(temp_quest_data_dir)
        
        # Start once
        manager.start_quest(1)
        
        # Try to start again
        result = manager.start_quest(1)
        
        assert not result


class TestObjectiveUpdating:
    """Test objective progress updates."""
    
    def test_update_objective(self, temp_quest_data_dir):
        """Test updating objective progress."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        
        result = manager.update_objective(1, 1, 5)
        
        assert result
        quest = manager.active_quests[1]
        assert quest.objectives[0].current_count == 5
    
    def test_update_objective_completes_quest(self, temp_quest_data_dir):
        """Test quest completes when all objectives done."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        
        manager.update_objective(1, 1, 10)
        
        quest = manager.active_quests[1]
        assert quest.is_complete
        assert quest.status == QuestStatus.COMPLETED
    
    def test_update_objective_not_active(self, temp_quest_data_dir):
        """Test updating inactive quest fails."""
        manager = QuestManager(temp_quest_data_dir)
        
        result = manager.update_objective(1, 1, 5)
        
        assert not result


class TestQuestCompletion:
    """Test quest completion."""
    
    def test_complete_quest(self, temp_quest_data_dir):
        """Test completing a quest."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        manager.update_objective(1, 1, 10)
        
        rewards = manager.complete_quest(1)
        
        assert len(rewards) > 0
        assert 1 in manager.completed_quests
        assert 1 not in manager.active_quests
    
    def test_complete_quest_not_ready(self, temp_quest_data_dir):
        """Test completing incomplete quest."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        manager.update_objective(1, 1, 5)  # Only 5/10
        
        rewards = manager.complete_quest(1)
        
        assert len(rewards) == 0
    
    def test_complete_quest_not_active(self, temp_quest_data_dir):
        """Test completing non-active quest."""
        manager = QuestManager(temp_quest_data_dir)
        
        rewards = manager.complete_quest(1)
        
        assert len(rewards) == 0


class TestQuestAbandoning:
    """Test abandoning quests."""
    
    def test_abandon_quest(self, temp_quest_data_dir):
        """Test abandoning active quest."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        
        result = manager.abandon_quest(1)
        
        assert result
        assert 1 not in manager.active_quests
    
    def test_abandon_nonactive_quest(self, temp_quest_data_dir):
        """Test abandoning non-active quest."""
        manager = QuestManager(temp_quest_data_dir)
        
        result = manager.abandon_quest(1)
        
        assert not result


class TestQuestRetrieval:
    """Test quest retrieval methods."""
    
    def test_get_quest(self, temp_quest_data_dir):
        """Test getting quest by ID."""
        manager = QuestManager(temp_quest_data_dir)
        
        quest = manager.get_quest(1)
        
        assert quest is not None
        assert quest.quest_id == 1
    
    def test_get_active_quests(self, temp_quest_data_dir):
        """Test getting all active quests."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        manager.start_quest(2)
        
        active = manager.get_active_quests()
        
        assert len(active) == 2


class TestAvailableQuests:
    """Test available quest filtering."""
    
    def test_get_available_quests_level_filter(self, temp_quest_data_dir):
        """Test filtering by level."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 5, "job": "Novice"}
        available = manager.get_available_quests(character_state)
        
        # Should only include quest 1 (min level 1)
        assert any(q.quest_id == 1 for q in available)
        assert not any(q.quest_id == 2 for q in available)  # Needs level 10
    
    def test_get_available_quests_job_filter(self, temp_quest_data_dir):
        """Test filtering by job."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Swordman", "job_level": 50}
        available = manager.get_available_quests(character_state)
        
        # Should not include job change quest (wrong job)
        assert not any(q.quest_id == 4 for q in available)
    
    def test_get_available_quests_active_filter(self, temp_quest_data_dir):
        """Test filtering out active quests."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        
        character_state = {"level": 50, "job": "Novice"}
        available = manager.get_available_quests(character_state)
        
        # Should not include active quest
        assert not any(q.quest_id == 1 for q in available)
    
    def test_get_available_quests_completed_filter(self, temp_quest_data_dir):
        """Test filtering out completed quests."""
        manager = QuestManager(temp_quest_data_dir)
        manager.start_quest(1)
        manager.update_objective(1, 1, 10)
        manager.complete_quest(1)
        
        character_state = {"level": 50, "job": "Novice"}
        available = manager.get_available_quests(character_state)
        
        # Should not include completed quest (non-repeatable)
        assert not any(q.quest_id == 1 for q in available)
    
    def test_get_available_quests_cooldown_filter(self, temp_quest_data_dir):
        """Test filtering cooldown quests."""
        manager = QuestManager(temp_quest_data_dir)
        
        # Mark quest as recently completed
        manager.quests[3].last_completed = datetime.now() - timedelta(hours=1)
        
        character_state = {"level": 50, "job": "Novice"}
        available = manager.get_available_quests(character_state)
        
        # Should not include quest on cooldown
        assert not any(q.quest_id == 3 for q in available)


class TestRequirementChecking:
    """Test quest requirement validation."""
    
    def test_check_requirements_level(self, temp_quest_data_dir):
        """Test level requirement check."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 5, "job": "Novice", "job_level": 10}
        can_start, missing = manager.check_quest_requirements(2, character_state)
        
        assert not can_start
        assert any("Level 10" in msg for msg in missing)
    
    def test_check_requirements_job_level(self, temp_quest_data_dir):
        """Test job level requirement check."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Novice", "job_level": 20}
        can_start, missing = manager.check_quest_requirements(4, character_state)
        
        assert not can_start
        assert any("Job level 40" in msg for msg in missing)
    
    def test_check_requirements_job(self, temp_quest_data_dir):
        """Test job requirement check."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Swordman", "job_level": 50}
        can_start, missing = manager.check_quest_requirements(4, character_state)
        
        assert not can_start
        assert any("Job requirement" in msg for msg in missing)
    
    def test_check_requirements_met(self, temp_quest_data_dir):
        """Test all requirements met."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Novice", "job_level": 50}
        can_start, missing = manager.check_quest_requirements(1, character_state)
        
        assert can_start
        assert len(missing) == 0


class TestQuestRecommendations:
    """Test quest recommendation system."""
    
    def test_get_recommended_quests(self, temp_quest_data_dir):
        """Test getting recommended quests."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Novice"}
        recommended = manager.get_recommended_quests(character_state, limit=3)
        
        assert len(recommended) <= 3
    
    def test_get_recommended_quests_daily_priority(self, temp_quest_data_dir):
        """Test daily quests are prioritized."""
        manager = QuestManager(temp_quest_data_dir)
        
        character_state = {"level": 50, "job": "Novice"}
        recommended = manager.get_recommended_quests(character_state, limit=3)
        
        # Daily quest should be first if available
        if any(q.quest_id == 3 for q in recommended):
            daily = next(q for q in recommended if q.quest_id == 3)
            assert recommended.index(daily) == 0
    
    def test_get_recommended_quests_no_available(self, temp_quest_data_dir):
        """Test recommendations with no available quests."""
        manager = QuestManager(temp_quest_data_dir)
        
        # Level too high for all quests
        character_state = {"level": 200, "job": "Novice"}
        recommended = manager.get_recommended_quests(character_state)
        
        assert len(recommended) == 0


class TestQuestRequirementModels:
    """Test quest requirement models."""
    
    def test_quest_requirement_creation(self):
        """Test creating quest requirement."""
        req = QuestRequirement(
            requirement_type="quest",
            requirement_id=1,
            requirement_name="Previous Quest",
            required_value=None
        )
        
        assert req.requirement_type == "quest"
        assert req.requirement_id == 1


class TestQuestRewardModels:
    """Test quest reward models."""
    
    def test_quest_reward_creation(self):
        """Test creating quest reward."""
        reward = QuestReward(
            reward_type="exp_base",
            reward_id=None,
            reward_name="Base Experience",
            quantity=1000
        )
        
        assert reward.reward_type == "exp_base"
        assert reward.quantity == 1000
    
    def test_quest_reward_optional(self):
        """Test optional reward."""
        reward = QuestReward(
            reward_type="item",
            reward_id=501,
            reward_name="Red Potion",
            quantity=5,
            is_optional=True
        )
        
        assert reward.is_optional


class TestQuestParsing:
    """Test quest data parsing."""
    
    def test_parse_quest_with_objectives(self, temp_quest_data_dir):
        """Test parsing quest with objectives."""
        manager = QuestManager(temp_quest_data_dir)
        quest = manager.quests[1]
        
        assert len(quest.objectives) == 1
        assert quest.objectives[0].objective_type == QuestObjectiveType.COLLECT_ITEM
    
    def test_parse_quest_with_requirements(self, temp_quest_data_dir):
        """Test parsing quest with requirements."""
        manager = QuestManager(temp_quest_data_dir)
        quest = manager.quests[2]
        
        assert len(quest.requirements) == 1
        assert quest.requirements[0].requirement_type == "level"
    
    def test_parse_quest_with_rewards(self, temp_quest_data_dir):
        """Test parsing quest with rewards."""
        manager = QuestManager(temp_quest_data_dir)
        quest = manager.quests[1]
        
        assert len(quest.rewards) == 1
        assert quest.base_exp_reward == 1000