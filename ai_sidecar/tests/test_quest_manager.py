"""
Tests for quest manager and tracking.
"""

import pytest

from ai_sidecar.core.state import GameState, CharacterState, Position, ActorState, ActorType
from ai_sidecar.npc.quest_manager import QuestManager
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
)


class TestQuestManager:
    """Test quest manager functionality."""

    def setup_method(self):
        """Set up test fixtures."""
        self.manager = QuestManager()

    def test_accept_quest(self):
        """Test accepting a quest."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        success = self.manager.accept_quest(quest)
        assert success is True
        assert len(self.manager.quest_log.active_quests) == 1

    def test_complete_quest(self):
        """Test completing a quest."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
        )

        self.manager.accept_quest(quest)
        success = self.manager.complete_quest(1001)

        assert success is True
        assert len(self.manager.quest_log.active_quests) == 0
        assert 1001 in self.manager.quest_log.completed_quests

    def test_on_monster_kill(self):
        """Test quest progress on monster kill."""
        quest = Quest(
            quest_id=1001,
            name="Hunt Quest",
            description="Kill monsters",
            npc_id=10001,
            npc_name="Test NPC",
            objectives=[
                QuestObjective(
                    objective_id="kill_poring",
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=1002,
                    target_name="Poring",
                    required_count=10,
                )
            ],
        )

        self.manager.accept_quest(quest)

        # Kill 5 Porings
        for _ in range(5):
            self.manager.on_monster_kill(1002, "Poring")

        active_quest = self.manager.quest_log.get_quest(1001)
        assert active_quest is not None
        assert active_quest.objectives[0].current_count == 5
        assert active_quest.status == "in_progress"

        # Kill 5 more (complete objective)
        for _ in range(5):
            self.manager.on_monster_kill(1002, "Poring")

        active_quest = self.manager.quest_log.get_quest(1001)
        assert active_quest.objectives[0].current_count == 10
        assert active_quest.status == "ready_to_turn_in"

    def test_on_item_obtained(self):
        """Test quest progress on item collection."""
        quest = Quest(
            quest_id=1001,
            name="Collection Quest",
            description="Collect items",
            npc_id=10001,
            npc_name="Test NPC",
            objectives=[
                QuestObjective(
                    objective_id="collect_potion",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=501,
                    target_name="Red Potion",
                    required_count=5,
                )
            ],
        )

        self.manager.accept_quest(quest)

        # Collect 3 potions
        self.manager.on_item_obtained(501, 3)

        active_quest = self.manager.quest_log.get_quest(1001)
        assert active_quest is not None
        assert active_quest.objectives[0].current_count == 3

        # Collect 2 more (complete)
        self.manager.on_item_obtained(501, 2)

        active_quest = self.manager.quest_log.get_quest(1001)
        assert active_quest.objectives[0].current_count == 5
        assert active_quest.status == "ready_to_turn_in"

    def test_quest_priority_calculation(self):
        """Test quest priority scoring."""
        quest1 = Quest(
            quest_id=1001,
            name="Low Priority",
            description="Quest 1",
            npc_id=10001,
            npc_name="NPC 1",
            status="in_progress",
            rewards=[QuestReward(reward_type="zeny", amount=100)],
        )

        quest2 = Quest(
            quest_id=1002,
            name="High Priority",
            description="Quest 2",
            npc_id=10002,
            npc_name="NPC 2",
            status="ready_to_turn_in",
            rewards=[QuestReward(reward_type="exp_base", amount=10000)],
        )

        priority1 = self.manager._calculate_quest_priority(quest1)
        priority2 = self.manager._calculate_quest_priority(quest2)

        # Quest ready to turn in should have higher priority
        assert priority2 > priority1

    def test_get_priority_quest(self):
        """Test getting highest priority quest."""
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

        self.manager.accept_quest(quest1)
        self.manager.accept_quest(quest2)

        priority_quest = self.manager.get_priority_quest()
        assert priority_quest is not None
        assert priority_quest.quest_id == 1002  # Ready to turn in

    @pytest.mark.asyncio
    async def test_tick_with_completable_quest(self):
        """Test quest manager tick with completable quest."""
        quest = Quest(
            quest_id=1001,
            name="Test Quest",
            description="A test quest",
            npc_id=10001,
            npc_name="Test NPC",
            status="ready_to_turn_in",
        )

        self.manager.accept_quest(quest)

        game_state = GameState(
            character=CharacterState(
                name="Test",
                job_id=0,
                position=Position(x=150, y=180),
            ),
        )

        actions = await self.manager.tick(game_state)
        # Should generate turn-in actions
        assert isinstance(actions, list)

    def test_get_available_quests(self):
        """Test getting available quests for level."""
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
            name="High Level Quest",
            description="Quest 2",
            npc_id=10002,
            npc_name="NPC 2",
            min_level=50,
            max_level=99,
        )

        self.manager.quest_db.add_quest(quest1)
        self.manager.quest_db.add_quest(quest2)

        # Level 5 character
        available = self.manager.get_available_quests(5, "Novice", "prontera")
        assert len(available) == 1
        assert available[0].quest_id == 1001

        # Level 60 character
        available = self.manager.get_available_quests(60, "Knight", "prontera")
        assert len(available) == 1
        assert available[0].quest_id == 1002