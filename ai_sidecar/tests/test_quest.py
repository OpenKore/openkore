"""
Tests for quest tracking and management.
"""

import pytest
from datetime import datetime

from ai_sidecar.npc.quest_models import (
    Quest,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
    QuestLog,
    QuestDatabase,
)


class TestQuestObjective:
    """Test quest objective functionality."""

    def test_objective_creation(self):
        """Test creating a quest objective."""
        obj = QuestObjective(
            objective_id="kill_porings",
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_id=1002,
            target_name="Poring",
            required_count=10,
        )

        assert obj.objective_id == "kill_porings"
        assert obj.required_count == 10
        assert obj.current_count == 0
        assert obj.completed is False

    def test_objective_progress(self):
        """Test objective progress tracking."""
        obj = QuestObjective(
            objective_id="kill_porings",
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_id=1002,
            target_name="Poring",
            required_count=10,
        )

        # Update progress
        obj.update_progress(5)
        assert obj.current_count == 5
        assert obj.progress_percent == 50.0
        assert obj.completed is False

        # Complete objective
        obj.update_progress(5)
        assert obj.current_count == 10
        assert obj.progress_percent == 100.0
        assert obj.completed is True

    def test_objective_over_completion(self):
        """Test objective with more than required count."""
        obj = QuestObjective(
            objective_id="collect_items",
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_id=501,
            target_name="Red Potion",
            required_count=5,
        )

        obj.update_progress(10)
        assert obj.current_count == 10
        assert obj.completed is True


class TestQuest:
    """Test quest functionality."""

    def test_quest_creation(self):
        """Test creating a quest."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        assert quest.quest_id == 1001
        assert quest.status == "not_started"

    def test_quest_with_objectives(self):
        """Test quest with objectives."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
            objectives=[
                QuestObjective(
                    objective_id="obj1",
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=1002,
                    target_name="Poring",
                    required_count=10,
                ),
                QuestObjective(
                    objective_id="obj2",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=501,
                    target_name="Red Potion",
                    required_count=5,
                ),
            ],
        )

        assert len(quest.objectives) == 2
        assert quest.all_objectives_complete is False

        # Complete first objective
        quest.objectives[0].update_progress(10)
        assert quest.all_objectives_complete is False

        # Complete second objective
        quest.objectives[1].update_progress(5)
        assert quest.all_objectives_complete is True

    def test_quest_eligibility(self):
        """Test quest eligibility checks."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
            min_level=10,
            max_level=50,
            required_job="Swordman",
        )

        # Too low level
        assert quest.is_eligible(5, "Swordman") is False

        # Too high level
        assert quest.is_eligible(60, "Swordman") is False

        # Wrong job
        assert quest.is_eligible(30, "Mage") is False

        # Eligible
        assert quest.is_eligible(30, "Swordman") is True


class TestQuestLog:
    """Test quest log functionality."""

    def test_add_quest(self):
        """Test adding quest to log."""
        log = QuestLog()
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        success = log.add_quest(quest)
        assert success is True
        assert quest.status == "in_progress"
        assert len(log.active_quests) == 1

    def test_duplicate_quest(self):
        """Test preventing duplicate quests."""
        log = QuestLog()
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        log.add_quest(quest)
        success = log.add_quest(quest)
        assert success is False
        assert len(log.active_quests) == 1

    def test_complete_quest(self):
        """Test completing a quest."""
        log = QuestLog()
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        log.add_quest(quest)
        success = log.complete_quest(1001)

        assert success is True
        assert len(log.active_quests) == 0
        assert 1001 in log.completed_quests

    def test_get_completable_quests(self):
        """Test getting quests ready to turn in."""
        log = QuestLog()

        quest1 = Quest(
            quest_id=1001,
            name="Quest 1",
            description="Quest 1",
            npc_id=10001,
            npc_name="NPC 1",
            status="in_progress",
        )
        quest2 = Quest(
            quest_id=1002,
            name="Quest 2",
            description="Quest 2",
            npc_id=10002,
            npc_name="NPC 2",
            status="ready_to_turn_in",
        )

        log.add_quest(quest1)
        log.add_quest(quest2)

        completable = log.get_completable_quests()
        assert len(completable) == 1
        assert completable[0].quest_id == 1002

    def test_daily_quest_tracking(self):
        """Test daily quest completion tracking."""
        log = QuestLog()
        quest = Quest(
            quest_id=1001,
            name="Daily Quest",
            description="A daily quest",
            npc_id=10001,
            npc_name="NPC",
            is_daily=True,
        )

        # First completion
        log.add_quest(quest)
        log.complete_quest(1001)

        # Can't accept again today
        assert log.can_accept_daily_quest(1001) is False

        # Simulate next day (manual test would require mocking datetime)
        # For now just test the tracking mechanism
        assert 1001 in log.daily_quests_completed


class TestQuestDatabase:
    """Test quest database operations."""

    def test_add_and_get_quest(self):
        """Test adding and retrieving quests."""
        db = QuestDatabase()

        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        db.add_quest(quest)

        retrieved = db.get_quest(1001)
        assert retrieved is not None
        assert retrieved.name == "Test Quest"

    def test_get_quests_by_npc(self):
        """Test retrieving quests by NPC."""
        db = QuestDatabase()

        quest1 = Quest(
            quest_id=1001,
            name="Quest 1",
            description="Quest 1",
            npc_id=10001,
            npc_name="NPC 1",
        )
        quest2 = Quest(
            quest_id=1002,
            name="Quest 2",
            description="Quest 2",
            npc_id=10001,
            npc_name="NPC 1",
        )

        db.add_quest(quest1)
        db.add_quest(quest2)

        npc_quests = db.get_quests_by_npc(10001)
        assert len(npc_quests) == 2

    def test_get_quests_for_level(self):
        """Test retrieving quests by level range."""
        db = QuestDatabase()

        quest1 = Quest(
            quest_id=1001,
            name="Low Level Quest",
            description="Quest 1",
            npc_id=10001,
            npc_name="NPC 1",
            min_level=1,
            max_level=10,
        )
        quest2 = Quest(
            quest_id=1002,
            name="Mid Level Quest",
            description="Quest 2",
            npc_id=10002,
            npc_name="NPC 2",
            min_level=20,
            max_level=40,
        )

        db.add_quest(quest1)
        db.add_quest(quest2)

        # Level 5 should get quest1
        available = db.get_quests_for_level(5)
        assert len(available) == 1
        assert available[0].quest_id == 1001

        # Level 30 should get quest2
        available = db.get_quests_for_level(30)
        assert len(available) == 1
        assert available[0].quest_id == 1002