"""
Comprehensive tests for quest_manager.py - covering all uncovered lines.
Target: 100% coverage of quest tracking, objectives, and completion logic.
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, MagicMock, patch, AsyncMock

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.quest_manager import QuestManager
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
)


@pytest.fixture
def quest_manager():
    """Create QuestManager instance."""
    return QuestManager()


@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    state = Mock()
    state.character = Mock()
    state.character.position = Mock(x=100, y=100)
    state.map_name = "prontera"
    state.inventory = []
    state.actors = []
    return state


@pytest.fixture
def sample_quest():
    """Create a sample quest."""
    quest = Quest(
        quest_id=1001,
        name="Hunt Poring",
        description="Kill 10 Porings",
        npc_id=5000,
        npc_name="Quest Giver",
        min_level=1,
        objectives=[
            QuestObjective(
                objective_id="1",
                objective_type=QuestObjectiveType.KILL_MONSTER,
                target_id=1002,
                target_name="Poring",
                required_count=10,
                current_count=0,
            )
        ],
        rewards=[
            QuestReward(reward_type="exp_base", amount=1000),
            QuestReward(reward_type="zeny", amount=500),
        ],
    )
    return quest


class TestQuestManagerInit:
    """Test QuestManager initialization."""

    def test_init(self, quest_manager):
        """Test initialization."""
        assert quest_manager.quest_db is not None
        assert quest_manager.quest_log is not None
        assert quest_manager.dialogue_parser is not None


class TestQuestTick:
    """Test quest tick and main loop."""

    @pytest.mark.asyncio
    async def test_tick_no_active_quests(self, quest_manager, mock_game_state):
        """Test tick with no active quests."""
        actions = await quest_manager.tick(mock_game_state)
        assert actions == []

    @pytest.mark.asyncio
    async def test_tick_with_completable_quest(
        self, quest_manager, mock_game_state, sample_quest
    ):
        """Test tick with quest ready to turn in."""
        # Set up completable quest
        sample_quest.status = "ready_to_turn_in"
        for obj in sample_quest.objectives:
            obj.completed = True
        
        # Must add quest AFTER setting status
        quest_manager.quest_log.active_quests.append(sample_quest)

        # Add NPC to actors
        npc = Mock()
        npc.id = sample_quest.npc_id
        npc.position = Mock(x=105, y=105)
        mock_game_state.actors = [npc]
        mock_game_state.character.position.distance_to = Mock(return_value=3.0)

        actions = await quest_manager.tick(mock_game_state)
        assert len(actions) > 0

    @pytest.mark.asyncio
    async def test_tick_error_handling(self, quest_manager, mock_game_state):
        """Test tick with error."""
        # Mock error in update
        with patch.object(
            quest_manager, "_update_quest_progress", side_effect=Exception("Test error")
        ):
            actions = await quest_manager.tick(mock_game_state)
            assert actions == []

    @pytest.mark.asyncio
    async def test_tick_with_objective_actions(
        self, quest_manager, mock_game_state, sample_quest
    ):
        """Test tick generates objective actions."""
        quest_manager.quest_log.add_quest(sample_quest)

        # Add monster to actors
        monster = Mock()
        monster.mob_id = 1002
        monster.id = 2000
        monster.hp = 100
        mock_game_state.actors = [monster]

        actions = await quest_manager.tick(mock_game_state)
        assert len(actions) > 0


class TestQuestProgress:
    """Test quest progress updates."""

    def test_update_quest_progress_no_quests(self, quest_manager, mock_game_state):
        """Test update with no active quests."""
        quest_manager._update_quest_progress(mock_game_state)
        # Should not raise error

    def test_update_collection_objective(self, quest_manager, mock_game_state):
        """Test updating collection objective."""
        quest = Quest(
            quest_id=2001,
            name="Collect Items",
            description="Collect 5 apples",
            npc_id=5000,
            npc_name="Item Collector",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=501,
                    target_name="Apple",
                    required_count=5,
                    current_count=0,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        # Add items to inventory
        item = Mock()
        item.id = 501
        item.amount = 3
        mock_game_state.inventory = [item]

        quest_manager._update_quest_progress(mock_game_state)

        obj = quest.objectives[0]
        assert obj.current_count == 3

    def test_update_collection_objective_completion(
        self, quest_manager, mock_game_state
    ):
        """Test collection objective completion."""
        quest = Quest(
            quest_id=2001,
            name="Collect Items",
            description="Collect 5 apples",
            npc_id=5000,
            npc_name="Item Collector",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=501,
                    target_name="Apple",
                    required_count=5,
                    current_count=0,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        # Add enough items
        item = Mock()
        item.id = 501
        item.amount = 10
        mock_game_state.inventory = [item]

        quest_manager._update_quest_progress(mock_game_state)

        obj = quest.objectives[0]
        assert obj.completed
        assert obj.current_count == 5

    def test_update_visit_location_objective(self, quest_manager, mock_game_state):
        """Test visit location objective."""
        quest = Quest(
            quest_id=3001,
            name="Visit Location",
            description="Go to coordinates",
            npc_id=5000,
            npc_name="Explorer",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.VISIT_LOCATION,
                    target_id=0,
                    target_name="Secret Spot",
                    map_name="prontera",
                    x=100,
                    y=100,
                    required_count=1,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        mock_game_state.character.position = Mock(x=102, y=102)
        mock_game_state.map_name = "prontera"

        quest_manager._update_quest_progress(mock_game_state)

        obj = quest.objectives[0]
        assert obj.completed

    def test_update_talk_to_npc_objective(self, quest_manager, mock_game_state):
        """Test talk to NPC objective tracking."""
        quest = Quest(
            quest_id=4001,
            name="Talk Quest",
            description="Talk to NPC",
            npc_id=5000,
            npc_name="Quest Giver",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.TALK_TO_NPC,
                    target_id=5001,
                    target_name="Quest NPC",
                    required_count=1,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        # Add NPC nearby
        npc = Mock()
        npc.id = 5001
        npc.position = Mock(x=101, y=101)
        npc.distance_to = Mock(return_value=1.0)
        mock_game_state.actors = [npc]
        mock_game_state.character.position.distance_to = Mock(return_value=1.0)

        quest_manager._update_quest_progress(mock_game_state)
        # Note: actual talk tracking would need event system


class TestQuestEvents:
    """Test quest event handlers."""

    def test_on_monster_kill(self, quest_manager, sample_quest):
        """Test monster kill event."""
        quest_manager.quest_log.add_quest(sample_quest)

        quest_manager.on_monster_kill(1002, "Poring")

        obj = sample_quest.objectives[0]
        assert obj.current_count == 1

    def test_on_monster_kill_completion(self, quest_manager, sample_quest):
        """Test monster kill quest completion."""
        obj = sample_quest.objectives[0]
        obj.current_count = 9
        quest_manager.quest_log.add_quest(sample_quest)

        quest_manager.on_monster_kill(1002, "Poring")

        assert obj.completed
        assert sample_quest.status == "ready_to_turn_in"

    def test_on_item_obtained(self, quest_manager):
        """Test item obtained event."""
        quest = Quest(
            quest_id=2001,
            name="Collect Items",
            description="Collect items",
            npc_id=5000,
            npc_name="Collector",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=501,
                    target_name="Apple",
                    required_count=5,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        quest_manager.on_item_obtained(501, 3)

        obj = quest.objectives[0]
        assert obj.current_count == 3

    def test_on_npc_talk(self, quest_manager):
        """Test NPC talk event."""
        quest = Quest(
            quest_id=4001,
            name="Talk Quest",
            description="Talk to NPC",
            npc_id=5000,
            npc_name="Questgiver",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.TALK_TO_NPC,
                    target_id=5001,
                    target_name="NPC",
                    required_count=1,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        quest_manager.on_npc_talk(5001)

        obj = quest.objectives[0]
        assert obj.completed


class TestQuestManagement:
    """Test quest acceptance and completion."""

    def test_accept_quest(self, quest_manager, sample_quest):
        """Test accepting a quest."""
        success = quest_manager.accept_quest(sample_quest)
        assert success
        assert sample_quest in quest_manager.quest_log.active_quests

    def test_complete_quest(self, quest_manager, sample_quest):
        """Test completing a quest."""
        quest_manager.quest_log.add_quest(sample_quest)
        success = quest_manager.complete_quest(sample_quest.quest_id)
        assert success

    def test_complete_nonexistent_quest(self, quest_manager):
        """Test completing quest that doesn't exist."""
        success = quest_manager.complete_quest(9999)
        assert not success


class TestQuestPriority:
    """Test quest priority calculation."""

    def test_get_priority_quest_none(self, quest_manager):
        """Test getting priority quest with no active quests."""
        quest = quest_manager.get_priority_quest()
        assert quest is None

    def test_get_priority_quest(self, quest_manager, sample_quest):
        """Test getting priority quest."""
        quest_manager.quest_log.add_quest(sample_quest)
        quest = quest_manager.get_priority_quest()
        assert quest == sample_quest

    def test_calculate_quest_priority_ready_to_turn_in(
        self, quest_manager, sample_quest
    ):
        """Test priority for quest ready to turn in."""
        sample_quest.status = "ready_to_turn_in"
        priority = quest_manager._calculate_quest_priority(sample_quest)
        assert priority >= 100.0

    def test_calculate_quest_priority_with_rewards(self, quest_manager, sample_quest):
        """Test priority calculation with rewards."""
        priority = quest_manager._calculate_quest_priority(sample_quest)
        assert priority > 0

    def test_calculate_quest_priority_time_limited(self, quest_manager, sample_quest):
        """Test priority for time-limited quest."""
        sample_quest.time_limit_seconds = 3600
        priority = quest_manager._calculate_quest_priority(sample_quest)
        assert priority > quest_manager._calculate_quest_priority(
            Quest(
                quest_id=9999,
                name="Normal",
                description="Normal quest",
                npc_id=5000,
                npc_name="Normal NPC",
                min_level=1,
            )
        )

    def test_calculate_quest_priority_daily(self, quest_manager, sample_quest):
        """Test priority for daily quest."""
        sample_quest.is_daily = True
        priority = quest_manager._calculate_quest_priority(sample_quest)
        assert priority > 50

    def test_determine_quest_type_daily(self, quest_manager, sample_quest):
        """Test determining daily quest type."""
        sample_quest.is_daily = True
        quest_type = quest_manager._determine_quest_type(sample_quest)
        assert quest_type == "daily"

    def test_determine_quest_type_repeatable(self, quest_manager, sample_quest):
        """Test determining repeatable quest type."""
        sample_quest.is_repeatable = True
        quest_type = quest_manager._determine_quest_type(sample_quest)
        assert quest_type == "repeatable"

    def test_determine_quest_type_main_story(self, quest_manager):
        """Test determining main story quest."""
        quest = Quest(
            quest_id=1,
            name="Main Chapter 1",
            description="Story quest",
            npc_id=5000,
            npc_name="Story NPC",
            min_level=1,
        )
        quest_type = quest_manager._determine_quest_type(quest)
        assert quest_type == "main_story"

    def test_determine_quest_type_collection(self, quest_manager):
        """Test determining collection quest."""
        quest = Quest(
            quest_id=1,
            name="Gather Quest",
            description="Collect herbs from the field",
            npc_id=5000,
            npc_name="Herbalist",
            min_level=1,
        )
        quest_type = quest_manager._determine_quest_type(quest)
        assert quest_type == "collection"


class TestQuestActions:
    """Test quest action generation."""

    def test_create_turn_in_actions_nearby_npc(
        self, quest_manager, sample_quest, mock_game_state
    ):
        """Test turn-in action with nearby NPC."""
        sample_quest.status = "ready_to_turn_in"

        npc = Mock()
        npc.id = sample_quest.npc_id
        npc.position = Mock(x=102, y=102)
        mock_game_state.actors = [npc]
        mock_game_state.character.position.distance_to = Mock(return_value=3.0)

        actions = quest_manager._create_turn_in_actions([sample_quest], mock_game_state)
        assert len(actions) > 0
        assert actions[0].type == ActionType.TALK_NPC

    def test_create_turn_in_actions_far_npc(
        self, quest_manager, sample_quest, mock_game_state
    ):
        """Test turn-in action with far NPC."""
        sample_quest.status = "ready_to_turn_in"

        npc = Mock()
        npc.id = sample_quest.npc_id
        npc.position = Mock(x=150, y=150)
        mock_game_state.actors = [npc]
        mock_game_state.character.position.distance_to = Mock(return_value=70.0)

        actions = quest_manager._create_turn_in_actions([sample_quest], mock_game_state)
        assert len(actions) > 0
        assert actions[0].type == ActionType.MOVE

    def test_get_objective_actions_kill_monster(
        self, quest_manager, sample_quest, mock_game_state
    ):
        """Test getting actions for kill objective."""
        quest_manager.quest_log.add_quest(sample_quest)

        monster = Mock()
        monster.mob_id = 1002
        monster.id = 2000
        monster.hp = 100
        mock_game_state.actors = [monster]

        actions = quest_manager._get_objective_actions(mock_game_state)
        assert len(actions) > 0

    def test_get_objective_actions_talk_to_npc(self, quest_manager, mock_game_state):
        """Test getting actions for talk objective."""
        quest = Quest(
            quest_id=4001,
            name="Talk Quest",
            description="Talk to NPC",
            npc_id=5000,
            npc_name="Questgiver",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.TALK_TO_NPC,
                    target_id=5001,
                    target_name="NPC",
                    required_count=1,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        npc = Mock()
        npc.id = 5001
        npc.position = Mock(x=102, y=102)
        mock_game_state.actors = [npc]
        mock_game_state.character.position.distance_to = Mock(return_value=3.0)

        actions = quest_manager._get_objective_actions(mock_game_state)
        assert len(actions) > 0

    def test_get_objective_actions_visit_location(self, quest_manager, mock_game_state):
        """Test getting actions for visit location objective."""
        quest = Quest(
            quest_id=3001,
            name="Visit",
            description="Visit location",
            npc_id=5000,
            npc_name="Explorer",
            min_level=1,
            objectives=[
                QuestObjective(
                    objective_id="1",
                    objective_type=QuestObjectiveType.VISIT_LOCATION,
                    target_id=0,
                    target_name="Location",
                    map_name="prontera",
                    x=150,
                    y=150,
                    required_count=1,
                )
            ],
        )
        quest_manager.quest_log.add_quest(quest)

        actions = quest_manager._get_objective_actions(mock_game_state)
        assert len(actions) > 0


class TestQuestDatabase:
    """Test quest database operations."""

    def test_get_quest_by_id_from_log(self, quest_manager, sample_quest):
        """Test getting quest from log."""
        quest_manager.quest_log.add_quest(sample_quest)
        quest = quest_manager.get_quest_by_id(sample_quest.quest_id)
        assert quest == sample_quest

    def test_get_quest_by_id_from_database(self, quest_manager, sample_quest):
        """Test getting quest from database."""
        quest_manager.quest_db.add_quest(sample_quest)
        quest = quest_manager.get_quest_by_id(sample_quest.quest_id)
        assert quest is not None

    def test_load_quest_database(self, quest_manager):
        """Test loading quest database."""
        quest_data = {
            "1001": {"name": "Test Quest", "description": "Test"},
            "invalid": {"name": "Invalid"},
        }
        quest_manager.load_quest_database(quest_data)
        # Should not raise error

    def test_get_available_quests(self, quest_manager, sample_quest):
        """Test getting available quests."""
        quest_manager.quest_db.add_quest(sample_quest)

        available = quest_manager.get_available_quests(10, "Swordman", "prontera")
        assert len(available) > 0

    def test_get_available_quests_already_completed(self, quest_manager, sample_quest):
        """Test filtering completed non-repeatable quests."""
        quest_manager.quest_log.completed_quests.append(sample_quest.quest_id)
        quest_manager.quest_db.add_quest(sample_quest)

        available = quest_manager.get_available_quests(10, "Swordman", "prontera")
        assert len(available) == 0

    def test_get_available_quests_prerequisites_not_met(
        self, quest_manager, sample_quest
    ):
        """Test filtering quests with unmet prerequisites."""
        sample_quest.prerequisite_quests = [9999]
        quest_manager.quest_db.add_quest(sample_quest)

        available = quest_manager.get_available_quests(10, "Swordman", "prontera")
        assert len(available) == 0

    def test_get_available_quests_daily_not_available(
        self, quest_manager, sample_quest
    ):
        """Test filtering daily quests not available."""
        sample_quest.is_daily = True
        quest_manager.quest_db.add_quest(sample_quest)

        # Complete the quest today
        quest_manager.quest_log.daily_quests_completed[sample_quest.quest_id] = datetime.now()

        available = quest_manager.get_available_quests(10, "Swordman", "prontera")
        assert len(available) == 0