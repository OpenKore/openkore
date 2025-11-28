"""
Comprehensive tests for quest, achievement, and daily quest systems.
"""

from datetime import datetime, timedelta
from pathlib import Path

import pytest

from ai_sidecar.quests import (
    Achievement,
    AchievementCategory,
    AchievementManager,
    AchievementTier,
    DailyQuestCategory,
    DailyQuestManager,
    HuntingQuestManager,
    Quest,
    QuestCoordinator,
    QuestManager,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
    QuestStatus,
    QuestType,
)


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test data"""
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
    """Sample character state"""
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


class TestQuestManager:
    """Test core quest management"""
    
    def test_quest_loading(self, data_dir: Path):
        """Test quest data loading"""
        manager = QuestManager(data_dir)
        assert manager is not None
        assert isinstance(manager.quests, dict)
    
    def test_quest_lifecycle(self, data_dir: Path):
        """Test quest start, progress, and completion"""
        manager = QuestManager(data_dir)
        
        quest = Quest(
            quest_id=1001,
            quest_name="Test Quest",
            quest_type=QuestType.TUTORIAL,
            description="Test",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=1002,
                    target_name="Poring",
                    required_count=10
                )
            ],
            rewards=[QuestReward(reward_type="exp", reward_name="EXP", quantity=1000)]
        )
        manager.quests[1001] = quest
        
        # Start
        assert manager.start_quest(1001)
        assert 1001 in manager.active_quests
        
        # Progress
        manager.update_objective(1001, 1, 10)
        assert quest.is_complete
        
        # Complete
        rewards = manager.complete_quest(1001)
        assert len(rewards) == 1
        assert 1001 in manager.completed_quests


class TestDailyQuestManager:
    """Test daily quest system"""
    
    def test_daily_reset(self, data_dir: Path):
        """Test daily reset mechanism"""
        quest_manager = QuestManager(data_dir)
        manager = DailyQuestManager(data_dir, quest_manager)
        
        manager.mark_daily_complete(DailyQuestCategory.GRAMPS)
        assert manager.is_daily_completed(DailyQuestCategory.GRAMPS)
        
        manager.last_reset = datetime.now() - timedelta(days=2)
        manager._check_daily_reset()
        assert not manager.is_daily_completed(DailyQuestCategory.GRAMPS)
    
    def test_time_until_reset(self, data_dir: Path):
        """Test reset timer"""
        quest_manager = QuestManager(data_dir)
        manager = DailyQuestManager(data_dir, quest_manager)
        
        time_remaining = manager.get_time_until_reset()
        assert isinstance(time_remaining, timedelta)
        assert 0 < time_remaining.total_seconds() <= 86400


class TestAchievementManager:
    """Test achievement system"""
    
    def test_achievement_progress(self, data_dir: Path):
        """Test progress tracking and completion"""
        manager = AchievementManager(data_dir)
        
        achievement = Achievement(
            achievement_id=101,
            achievement_name="Test",
            category=AchievementCategory.BATTLE,
            tier=AchievementTier.BRONZE,
            description="Test",
            target_value=100,
            achievement_points=10
        )
        manager.achievements[101] = achievement
        
        assert not manager.update_progress(101, 50)
        assert achievement.progress_percent == 50.0
        
        assert manager.update_progress(101, 100)
        assert achievement.is_complete
        assert 101 in manager.completed_achievements


class TestHuntingQuestManager:
    """Test hunting quest system"""
    
    def test_kill_tracking(self, data_dir: Path):
        """Test kill recording and tracking"""
        quest_manager = QuestManager(data_dir)
        manager = HuntingQuestManager(data_dir, quest_manager)
        
        for _ in range(10):
            manager.record_kill(1002)
        
        assert manager.kill_counts.get(1002, 0) == 10


class TestQuestCoordinator:
    """Test integrated quest system"""
    
    @pytest.fixture
    def coordinator(self, data_dir: Path) -> QuestCoordinator:
        """Create quest coordinator"""
        return QuestCoordinator(data_dir)
    
    async def test_coordinator_operations(
        self,
        coordinator: QuestCoordinator,
        character_state: dict
    ):
        """Test coordinator operations"""
        await coordinator.update(character_state)
        
        priorities = coordinator.get_quest_priorities(character_state)
        assert isinstance(priorities, list)
        
        activity = coordinator.get_optimal_activity(character_state, 60)
        assert "activity_type" in activity
        
        stats = coordinator.get_statistics()
        assert "active_quests" in stats


class TestModels:
    """Test data models"""
    
    def test_quest_objective_progress(self):
        """Test objective progress calculations"""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_id=1002,
            target_name="Poring",
            required_count=10
        )
        
        assert not obj.is_complete
        obj.update_progress(5)
        assert obj.progress_percent == 50.0
        obj.update_progress(5)
        assert obj.is_complete
    
    def test_quest_cooldown(self):
        """Test quest cooldown mechanics"""
        quest = Quest(
            quest_id=1,
            quest_name="Daily",
            quest_type=QuestType.DAILY,
            description="Test",
            is_daily=True,
            cooldown_hours=24,
            last_completed=datetime.now() - timedelta(hours=12)
        )
        
        remaining = quest.get_cooldown_remaining()
        assert remaining is not None and remaining.total_seconds() > 0
        
        quest.last_completed = datetime.now() - timedelta(hours=25)
        assert quest.get_cooldown_remaining() is None