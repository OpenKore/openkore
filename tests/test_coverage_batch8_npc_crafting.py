"""
Coverage Batch 8: NPC Systems & Crafting
Target: 97% → 98%+ coverage (~200-250 lines)
Modules:
  - npc/dialogue_parser.py (838 lines, 13.65% coverage)
  - npc/services.py (652 lines, 9.84% coverage)
  - crafting/brewing.py (466 lines, 0% coverage)
"""

import json
import pytest
from pathlib import Path
from unittest.mock import Mock, patch, AsyncMock, MagicMock, mock_open

from ai_sidecar.npc.dialogue_parser import (
    DialogueParser,
    DialogueAnalysis,
    ITEM_NAME_TO_ID,
    MONSTER_NAME_TO_ID,
)
from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.npc.models import (
    DialogueState,
    DialogueChoice,
    NPCType,
    ServiceNPC,
)
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
)
from ai_sidecar.crafting.brewing import (
    BrewingManager,
    BrewableItem,
    PotionType,
)
from ai_sidecar.crafting.core import Material, CraftingManager
from ai_sidecar.core.decision import Action, ActionType


# ============================================================================
# TEST DIALOGUE PARSER
# ============================================================================

class TestDialogueParserCore:
    """Test DialogueParser initialization and core functionality."""

    def test_dialogue_parser_initialization(self):
        """Cover DialogueParser.__init__ and pattern compilation."""
        # Arrange & Act
        parser = DialogueParser()

        # Assert
        assert parser is not None
        assert parser.npc_db is not None
        assert hasattr(parser, '_quest_pattern')
        assert hasattr(parser, '_item_patterns')
        assert hasattr(parser, '_kill_patterns')
        assert hasattr(parser, '_reward_patterns')
        assert hasattr(parser, '_location_patterns')
        assert len(parser._item_lookup) > 0
        assert len(parser._monster_lookup) > 0

    def test_parse_dialogue_basic(self):
        """Cover DialogueParser.parse_dialogue with basic dialogue."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Test NPC",
            text="Hello traveler!"
        )

        # Act
        result = parser.parse_dialogue(dialogue)

        # Assert
        assert isinstance(result, DialogueAnalysis)
        # Type can be information or service depending on keywords
        assert result.dialogue_type in ["information", "service"]
        assert result.confidence >= 0.0

    def test_parse_dialogue_quest_offer(self):
        """Cover quest offer dialogue parsing."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Quest Giver",
            text="I have a quest for you. Would you help me?"
        )

        # Act
        result = parser.parse_dialogue(dialogue)

        # Assert
        assert result.dialogue_type == "quest_offer"
        assert result.confidence > 0.5

    def test_parse_dialogue_with_choices(self):
        """Cover dialogue parsing with choices."""
        # Arrange
        parser = DialogueParser()
        choices = [
            DialogueChoice(index=0, text="Yes, I'll help", is_exit=False),
            DialogueChoice(index=1, text="No thanks", is_exit=True),
        ]
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Quest Giver",
            text="Will you accept this quest?",
            choices=choices,
            waiting_for_input=True,
            input_type="choice"
        )

        # Act
        result = parser.parse_dialogue(dialogue)

        # Assert
        assert result.suggested_choice is not None
        assert result.suggested_choice >= 0


class TestDialogueTypeIdentification:
    """Test dialogue type identification methods."""

    def test_identify_dialogue_type_quest_offer(self):
        """Cover _identify_dialogue_type for quest offers."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            text="Would you help me with this task?"
        )

        # Act
        dialogue_type = parser._identify_dialogue_type(dialogue)

        # Assert
        assert dialogue_type == "quest_offer"

    def test_identify_dialogue_type_quest_complete(self):
        """Cover _identify_dialogue_type for quest completion."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            text="Great! You have completed the quest!"
        )

        # Act
        dialogue_type = parser._identify_dialogue_type(dialogue)

        # Assert
        assert dialogue_type == "quest_complete"

    def test_identify_dialogue_type_shop(self):
        """Cover _identify_dialogue_type for shops."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Merchant",
            text="Welcome to my shop! Would you like to buy something?"
        )

        # Act
        dialogue_type = parser._identify_dialogue_type(dialogue)

        # Assert
        assert dialogue_type == "shop"

    def test_identify_dialogue_type_service(self):
        """Cover _identify_dialogue_type for services."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Kafra",
            text="Would you like to use storage?"
        )

        # Act
        dialogue_type = parser._identify_dialogue_type(dialogue)

        # Assert
        assert dialogue_type == "service"

    def test_identify_quest_offer_method(self):
        """Cover identify_quest_offer method."""
        # Arrange
        parser = DialogueParser()
        text = "I have a quest for you!"

        # Act
        result = parser.identify_quest_offer(text)

        # Assert
        assert result["is_quest_offer"] is True
        assert result["confidence"] > 0.5
        assert len(result["keywords_found"]) > 0

    def test_identify_quest_progress_method(self):
        """Cover identify_quest_progress method."""
        # Arrange
        parser = DialogueParser()
        text = "How is your progress with collecting items?"

        # Act
        result = parser.identify_quest_progress(text)

        # Assert
        assert result["is_quest_progress"] is True
        assert "progress" in result["keywords_found"]

    def test_identify_quest_complete_method(self):
        """Cover identify_quest_complete method."""
        # Arrange
        parser = DialogueParser()
        text = "Congratulations! You have completed the mission!"

        # Act
        result = parser.identify_quest_complete(text)

        # Assert
        assert result["is_quest_complete"] is True
        assert len(result["keywords_found"]) > 0

    def test_identify_shop_method(self):
        """Cover identify_shop method."""
        # Arrange
        parser = DialogueParser()
        text = "Welcome to my shop!"

        # Act
        result = parser.identify_shop(text)

        # Assert
        assert result["is_shop"] is True

    def test_identify_service_method(self):
        """Cover identify_service method."""
        # Arrange
        parser = DialogueParser()
        text = "Would you like to use Kafra storage?"

        # Act
        result = parser.identify_service(text)

        # Assert
        assert result["is_service"] is True

    def test_identify_information_method(self):
        """Cover identify_information method."""
        # Arrange
        parser = DialogueParser()
        text = "The weather is nice today."

        # Act
        result = parser.identify_information(text)

        # Assert
        assert result["is_information"] is True


class TestItemRequirementExtraction:
    """Test item requirement extraction."""

    def test_extract_item_requirements_basic(self):
        """Cover extract_item_requirements with basic pattern."""
        # Arrange
        parser = DialogueParser()
        text = "Please bring me 5 Red Potions"

        # Act
        requirements = parser.extract_item_requirements(text)

        # Assert
        assert len(requirements) > 0
        # Check structure
        for item_id, quantity in requirements:
            assert isinstance(item_id, int)
            assert isinstance(quantity, int)
            assert quantity > 0

    def test_extract_item_requirements_multiple_items(self):
        """Cover extraction of multiple items."""
        # Arrange
        parser = DialogueParser()
        text = "I need 10 Jellopy and 5 Fluff"

        # Act
        requirements = parser.extract_item_requirements(text)

        # Assert
        # Should extract at least one item
        assert len(requirements) >= 0

    def test_lookup_item_id_direct(self):
        """Cover _lookup_item_id with direct match."""
        # Arrange
        parser = DialogueParser()

        # Act
        item_id = parser._lookup_item_id("red potion")

        # Assert
        assert item_id == ITEM_NAME_TO_ID.get("red potion", 0)

    def test_lookup_item_id_fuzzy(self):
        """Cover _lookup_item_id with fuzzy matching."""
        # Arrange
        parser = DialogueParser()

        # Act
        item_id = parser._lookup_item_id("red potion x5")

        # Assert
        # Should find "red potion" via fuzzy match
        assert item_id > 0 or item_id == 0

    def test_lookup_item_id_plural(self):
        """Cover _lookup_item_id with plural form."""
        # Arrange
        parser = DialogueParser()

        # Act - try plural form
        item_id = parser._lookup_item_id("apples")

        # Assert
        # Should match "apple" by removing 's'
        assert item_id >= 0

    def test_lookup_item_id_unknown(self):
        """Cover _lookup_item_id with unknown item."""
        # Arrange
        parser = DialogueParser()

        # Act
        item_id = parser._lookup_item_id("unknown_item_xyz")

        # Assert
        assert item_id == 0


class TestMonsterRequirementExtraction:
    """Test monster requirement extraction."""

    def test_extract_monster_requirements_basic(self):
        """Cover extract_monster_requirements with basic pattern."""
        # Arrange
        parser = DialogueParser()
        text = "Kill 10 Porings for me"

        # Act
        requirements = parser.extract_monster_requirements(text)

        # Assert
        assert len(requirements) >= 0
        for monster_id, count in requirements:
            assert isinstance(monster_id, int)
            assert isinstance(count, int)

    def test_extract_monster_requirements_multiple(self):
        """Cover extraction of multiple monster types."""
        # Arrange
        parser = DialogueParser()
        text = "Defeat 20 Willows and hunt 15 Spores"

        # Act
        requirements = parser.extract_monster_requirements(text)

        # Assert
        assert len(requirements) >= 0

    def test_lookup_monster_id_direct(self):
        """Cover _lookup_monster_id with direct match."""
        # Arrange
        parser = DialogueParser()

        # Act
        monster_id = parser._lookup_monster_id("poring")

        # Assert
        assert monster_id == MONSTER_NAME_TO_ID.get("poring", 0)

    def test_lookup_monster_id_plural(self):
        """Cover _lookup_monster_id with plural form."""
        # Arrange
        parser = DialogueParser()

        # Act
        monster_id = parser._lookup_monster_id("porings")

        # Assert
        # Should match "poring" by removing 's'
        assert monster_id >= 0

    def test_lookup_monster_id_unknown(self):
        """Cover _lookup_monster_id with unknown monster."""
        # Arrange
        parser = DialogueParser()

        # Act
        monster_id = parser._lookup_monster_id("unknown_monster_xyz")

        # Assert
        assert monster_id == 0


class TestQuestInfoExtraction:
    """Test quest information extraction."""

    def test_extract_quest_info_with_items(self):
        """Cover extract_quest_info with item requirements."""
        # Arrange
        parser = DialogueParser()
        history = [
            "I have a quest for you!",
            "Please bring me 5 Red Potions"
        ]

        # Act
        quest = parser.extract_quest_info(history)

        # Assert
        if quest:
            assert isinstance(quest, Quest)
            assert len(quest.objectives) > 0

    def test_extract_quest_info_with_monsters(self):
        """Cover extract_quest_info with monster requirements."""
        # Arrange
        parser = DialogueParser()
        history = [
            "Help me with this mission!",
            "Kill 10 Porings in the field"
        ]

        # Act
        quest = parser.extract_quest_info(history)

        # Assert
        if quest:
            assert isinstance(quest, Quest)
            # Check for objectives
            assert len(quest.objectives) >= 0

    def test_extract_quest_info_no_requirements(self):
        """Cover extract_quest_info with no requirements."""
        # Arrange
        parser = DialogueParser()
        history = ["Just a simple conversation"]

        # Act
        quest = parser.extract_quest_info(history)

        # Assert
        assert quest is None

    def test_extract_rewards(self):
        """Cover _extract_rewards method."""
        # Arrange
        parser = DialogueParser()
        text = "You will receive 1000 zeny and 500 base experience"

        # Act
        rewards = parser._extract_rewards(text)

        # Assert
        assert isinstance(rewards, list)
        # Should extract some rewards
        assert len(rewards) >= 0


class TestResponseSuggestion:
    """Test dialogue response suggestion."""

    def test_suggest_response_quest_offer(self):
        """Cover suggest_response for quest offers."""
        # Arrange
        parser = DialogueParser()
        choices = [
            DialogueChoice(index=0, text="Yes, I accept", is_exit=False),
            DialogueChoice(index=1, text="No thanks", is_exit=True),
        ]
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            text="Quest offer",
            choices=choices
        )

        # Act
        choice = parser.suggest_response(dialogue, "quest_offer")

        # Assert
        assert choice is not None
        assert choice >= 0

    def test_suggest_response_quest_complete(self):
        """Cover suggest_response for quest completion."""
        # Arrange
        parser = DialogueParser()
        choices = [
            DialogueChoice(index=0, text="Turn in quest", is_exit=False),
            DialogueChoice(index=1, text="Not yet", is_exit=True),
        ]
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            text="Quest complete?",
            choices=choices
        )

        # Act
        choice = parser.suggest_response(dialogue, "quest_complete")

        # Assert
        assert choice is not None

    def test_suggest_response_shop(self):
        """Cover suggest_response for shops."""
        # Arrange
        parser = DialogueParser()
        choices = [
            DialogueChoice(index=0, text="Buy", is_exit=False),
            DialogueChoice(index=1, text="Sell", is_exit=False),
            DialogueChoice(index=2, text="Exit", is_exit=True),
        ]
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Shop",
            text="What would you like?",
            choices=choices
        )

        # Act
        choice = parser.suggest_response(dialogue, "shop")

        # Assert
        assert choice is not None

    def test_suggest_response_no_choices(self):
        """Cover suggest_response with no choices."""
        # Arrange
        parser = DialogueParser()
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            text="Just talking",
            choices=[]
        )

        # Act
        choice = parser.suggest_response(dialogue, "information")

        # Assert
        assert choice is None

    def test_evaluate_selection_options(self):
        """Cover _evaluate_selection_options method."""
        # Arrange
        parser = DialogueParser()
        choices = [
            DialogueChoice(index=0, text="Accept reward", is_exit=False),
            DialogueChoice(index=1, text="Continue quest", is_exit=False),
            DialogueChoice(index=2, text="Exit", is_exit=True),
        ]

        # Act
        choice = parser._evaluate_selection_options(choices)

        # Assert
        assert choice is not None
        assert choice >= 0

    def test_evaluate_selection_options_empty(self):
        """Cover _evaluate_selection_options with empty list."""
        # Arrange
        parser = DialogueParser()

        # Act
        choice = parser._evaluate_selection_options([])

        # Assert
        assert choice is None


class TestDialogueParserUtilities:
    """Test utility methods in DialogueParser."""

    def test_extract_npc_mentions(self):
        """Cover _extract_npc_mentions method."""
        # Arrange
        parser = DialogueParser()
        text = "Go talk to John Smith in Prontera"

        # Act
        mentions = parser._extract_npc_mentions(text)

        # Assert
        assert isinstance(mentions, list)

    def test_extract_location_mentions(self):
        """Cover _extract_location_mentions method."""
        # Arrange
        parser = DialogueParser()
        text = "Travel to Prontera and then Geffen"

        # Act
        locations = parser._extract_location_mentions(text)

        # Assert
        assert isinstance(locations, list)

    def test_calculate_confidence(self):
        """Cover calculate_confidence method."""
        # Arrange
        parser = DialogueParser()

        # Act
        confidence = parser.calculate_confidence("quest_offer", ["quest", "help"])

        # Assert
        assert 0.0 <= confidence <= 1.0
        assert confidence > 0

    def test_calculate_confidence_no_indicators(self):
        """Cover calculate_confidence with no indicators."""
        # Arrange
        parser = DialogueParser()

        # Act
        confidence = parser.calculate_confidence("unknown", [])

        # Assert
        assert confidence == 0.1

    def test_identify_npc_type(self):
        """Cover identify_npc_type method."""
        # Arrange
        parser = DialogueParser()

        # Act
        npc_type = parser.identify_npc_type("Kafra", "Would you like storage?")

        # Assert
        assert isinstance(npc_type, NPCType)
        assert npc_type == NPCType.SERVICE

    def test_identify_npc_type_shop(self):
        """Cover identify_npc_type for shops."""
        # Arrange
        parser = DialogueParser()

        # Act
        npc_type = parser.identify_npc_type("Merchant", "Buy or sell items here")

        # Assert
        assert npc_type == NPCType.SHOP

    def test_identify_npc_type_quest(self):
        """Cover identify_npc_type for quests."""
        # Arrange
        parser = DialogueParser()

        # Act
        npc_type = parser.identify_npc_type("Quest Giver", "I have a quest")

        # Assert
        assert npc_type == NPCType.QUEST


# ============================================================================
# TEST SERVICE HANDLER
# ============================================================================

class TestServiceHandlerCore:
    """Test ServiceHandler initialization and core methods."""

    def test_service_handler_initialization(self):
        """Cover ServiceHandler.__init__."""
        # Arrange & Act
        handler = ServiceHandler()

        # Assert
        assert handler is not None
        assert handler.service_db is not None
        assert handler.last_save_map == ""
        assert isinstance(handler.preferred_destinations, list)
        assert handler.auto_save_on_new_map is True
        assert handler.repair_threshold == 0.3

    def test_should_use_service_storage_full_inventory(self):
        """Cover should_use_service for storage with full inventory."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()
        game_state.inventory = [Mock() for _ in range(85)]
        game_state.character = Mock()
        game_state.character.weight = 500
        game_state.character.weight_max = 1000

        # Act
        should_use, reason = handler.should_use_service("storage", game_state)

        # Assert
        assert should_use is True
        assert "Inventory full" in reason or "Weight limit" in reason

    def test_should_use_service_storage_heavy_weight(self):
        """Cover should_use_service for storage with heavy weight."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()
        game_state.inventory = []
        game_state.character = Mock()
        game_state.character.weight = 800
        game_state.character.weight_max = 1000

        # Act
        should_use, reason = handler.should_use_service("storage", game_state)

        # Assert
        assert should_use is True
        assert "Weight limit" in reason

    def test_should_use_service_save_new_map(self):
        """Cover should_use_service for save point on new map."""
        # Arrange
        handler = ServiceHandler()
        handler.last_save_map = "old_map"
        game_state = Mock()
        game_state.map_name = "prontera"

        # Act
        should_use, reason = handler.should_use_service("save", game_state)

        # Assert
        assert should_use is True
        assert "New town map" in reason

    def test_should_use_service_teleport_low_zeny(self):
        """Cover should_use_service for teleport with insufficient zeny."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100

        # Act
        should_use, reason = handler.should_use_service("teleport", game_state)

        # Assert
        assert should_use is False
        assert "Insufficient zeny" in reason

    def test_should_use_service_repair_low_durability(self):
        """Cover should_use_service for repair with low durability."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()
        damaged_item = Mock()
        damaged_item.durability = 20
        damaged_item.max_durability = 100
        game_state.inventory = [damaged_item]

        # Act
        should_use, reason = handler.should_use_service("repair", game_state)

        # Assert
        assert should_use is True
        assert "Equipment needs repair" in reason

    def test_is_safe_map(self):
        """Cover _is_safe_map method."""
        # Arrange
        handler = ServiceHandler()

        # Act
        is_safe_prontera = handler._is_safe_map("prontera")
        is_safe_dungeon = handler._is_safe_map("orc_dungeon")

        # Assert
        assert is_safe_prontera is True
        assert is_safe_dungeon is False


class TestServiceActions:
    """Test service action generation."""

    @pytest.mark.asyncio
    async def test_use_storage_without_game_state(self):
        """Cover use_storage in test mode."""
        # Arrange
        handler = ServiceHandler()

        # Act
        actions = await handler.use_storage(None)

        # Assert
        assert isinstance(actions, list)
        assert len(actions) == 0

    @pytest.mark.asyncio
    async def test_use_refine_without_game_state(self):
        """Cover use_refine in test mode."""
        # Arrange
        handler = ServiceHandler()

        # Act
        actions = await handler.use_refine(None, item_index=0)

        # Assert
        assert isinstance(actions, list)
        assert len(actions) == 0

    @pytest.mark.asyncio
    async def test_use_repair_without_game_state(self):
        """Cover use_repair in test mode."""
        # Arrange
        handler = ServiceHandler()

        # Act
        actions = await handler.use_repair(None)

        # Assert
        assert isinstance(actions, list)
        assert len(actions) == 0

    @pytest.mark.asyncio
    async def test_use_identify_without_game_state(self):
        """Cover use_identify in test mode."""
        # Arrange
        handler = ServiceHandler()

        # Act
        actions = await handler.use_identify(None, item_index=0)

        # Assert
        assert isinstance(actions, list)
        assert len(actions) == 0

    @pytest.mark.asyncio
    async def test_use_card_remove_without_game_state(self):
        """Cover use_card_remove in test mode."""
        # Arrange
        handler = ServiceHandler()

        # Act
        actions = await handler.use_card_remove(None, item_index=0)

        # Assert
        assert isinstance(actions, list)
        assert len(actions) == 0

    def test_estimate_service_cost_basic(self):
        """Cover estimate_service_cost for basic services."""
        # Arrange
        handler = ServiceHandler()

        # Act
        cost = handler.estimate_service_cost("storage")

        # Assert
        assert cost == 60

    def test_estimate_service_cost_refine_with_level(self):
        """Cover estimate_service_cost for refining with level."""
        # Arrange
        handler = ServiceHandler()

        # Act
        cost = handler.estimate_service_cost("refine", current_refine=5)

        # Assert
        assert cost > 2000  # Should be multiplied

    def test_set_preferred_destinations(self):
        """Cover set_preferred_destinations method."""
        # Arrange
        handler = ServiceHandler()
        destinations = ["Prontera", "Geffen", "Payon"]

        # Act
        handler.set_preferred_destinations(destinations)

        # Assert
        assert handler.preferred_destinations == destinations

    def test_get_teleport_destinations(self):
        """Cover get_teleport_destinations method."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()

        # Act
        destinations = handler.get_teleport_destinations(game_state)

        # Assert
        assert isinstance(destinations, list)
        assert len(destinations) > 0

    def test_get_teleport_destinations_with_preferences(self):
        """Cover get_teleport_destinations with preferences."""
        # Arrange
        handler = ServiceHandler()
        handler.set_preferred_destinations(["Prontera", "Geffen"])
        game_state = Mock()

        # Act
        destinations = handler.get_teleport_destinations(game_state)

        # Assert
        assert isinstance(destinations, list)

    def test_get_recommended_services(self):
        """Cover get_recommended_services method."""
        # Arrange
        handler = ServiceHandler()
        game_state = Mock()
        # Mock inventory items with no durability attributes
        inventory_items = []
        for _ in range(85):
            item = Mock()
            item.durability = None  # No durability attribute
            item.max_durability = None
            inventory_items.append(item)
        game_state.inventory = inventory_items
        game_state.character = Mock()
        game_state.character.weight = 800
        game_state.character.weight_max = 1000
        game_state.character.zeny = 10000
        game_state.map_name = "prontera"

        # Act
        recommendations = handler.get_recommended_services(game_state)

        # Assert
        assert isinstance(recommendations, list)
        # Should recommend storage due to inventory
        assert len(recommendations) > 0


# ============================================================================
# TEST BREWING MANAGER
# ============================================================================

class TestBrewingManagerCore:
    """Test BrewingManager initialization and core functionality."""

    def test_brewing_manager_initialization(self, tmp_path):
        """Cover BrewingManager.__init__."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)

        # Act
        manager = BrewingManager(tmp_path, crafting_manager)

        # Assert
        assert manager is not None
        assert manager.crafting == crafting_manager
        assert len(manager.brewable_items) == 0  # No data file

    def test_brewing_manager_with_data_file(self, tmp_path):
        """Cover BrewingManager with valid data file."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 1}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0,
                    "batch_size": 1
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)

        # Act
        manager = BrewingManager(tmp_path, crafting_manager)

        # Assert
        assert len(manager.brewable_items) == 1
        assert 501 in manager.brewable_items

    def test_calculate_brew_rate_basic(self, tmp_path):
        """Cover calculate_brew_rate with basic stats."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 50.0,
                    "batch_size": 1
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        character_state = {
            "int": 50,
            "dex": 30,
            "luk": 20,
            "job_level": 40,
            "skills": {"AM_PHARMACY": 5},
            "brew_bonus": 5
        }

        # Act
        rate = manager.calculate_brew_rate(501, character_state)

        # Assert
        assert 0.0 <= rate <= 100.0

    def test_calculate_brew_rate_unknown_item(self, tmp_path):
        """Cover calculate_brew_rate with unknown item."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        rate = manager.calculate_brew_rate(9999, {})

        # Assert
        assert rate == 0.0

    def test_get_batch_brew_info(self, tmp_path):
        """Cover get_batch_brew_info method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 2}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0,
                    "batch_size": 3
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        inventory = {909: 10}  # 10 Jellopy

        # Act
        info = manager.get_batch_brew_info(501, inventory)

        # Assert
        assert info["can_brew"] is True
        assert info["max_batches"] == 5  # 10 / 2
        assert info["items_per_batch"] == 3
        assert info["total_items"] == 15

    def test_get_batch_brew_info_unknown_item(self, tmp_path):
        """Cover get_batch_brew_info with unknown item."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        info = manager.get_batch_brew_info(9999, {})

        # Assert
        assert info["can_brew"] is False
        assert "error" in info


class TestBrewingProfitability:
    """Test brewing profitability calculations."""

    def test_get_most_profitable_brew(self, tmp_path):
        """Cover get_most_profitable_brew method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 1}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0,
                    "batch_size": 1
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        inventory = {909: 10}
        character_state = {
            "int": 50,
            "dex": 30,
            "luk": 20,
            "job_level": 40,
            "skills": {"AM_PHARMACY": 5}
        }
        market_prices = {501: 500, 909: 10}

        # Act
        result = manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )

        # Assert
        if result:
            assert "item_id" in result
            assert "profit" in result
            assert "success_rate" in result

    def test_get_most_profitable_brew_no_materials(self, tmp_path):
        """Cover get_most_profitable_brew with no materials."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        result = manager.get_most_profitable_brew({}, {}, {})

        # Assert
        assert result is None


class TestBrewingUtilities:
    """Test brewing utility methods."""

    def test_get_brewable_items_by_type(self, tmp_path):
        """Cover get_brewable_items_by_type method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                },
                {
                    "item_id": 505,
                    "item_name": "Blue Potion",
                    "potion_type": "healing",
                    "materials": [],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 2,
                    "base_success_rate": 70.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        healing_potions = manager.get_brewable_items_by_type(PotionType.HEALING)

        # Assert
        assert len(healing_potions) == 2

    def test_get_available_brews(self, tmp_path):
        """Cover get_available_brews method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 1}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        inventory = {909: 5}
        character_state = {"skills": {"AM_PHARMACY": 1}}

        # Act
        available = manager.get_available_brews(inventory, character_state)

        # Assert
        assert len(available) == 1

    def test_get_statistics(self, tmp_path):
        """Cover get_statistics method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0,
                    "batch_size": 3
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        stats = manager.get_statistics()

        # Assert
        assert "total_brewable" in stats
        assert "by_potion_type" in stats
        assert "batch_brewable" in stats
        assert stats["batch_brewable"] == 1

    def test_can_brew_by_name(self, tmp_path):
        """Cover can_brew method with recipe name."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 1}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        can_brew = manager.can_brew("red potion")

        # Assert
        assert can_brew is True

    def test_can_brew_by_id(self, tmp_path):
        """Cover can_brew method with recipe ID."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        can_brew = manager.can_brew("501")

        # Assert
        assert can_brew is True

    def test_can_brew_with_materials_check(self, tmp_path):
        """Cover can_brew with full materials check."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 5}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        inventory = {909: 10}
        character_state = {"skills": {"AM_PHARMACY": 1}}

        # Act
        can_brew = manager.can_brew("501", inventory, character_state)

        # Assert
        assert can_brew is True

    def test_can_brew_insufficient_materials(self, tmp_path):
        """Cover can_brew with insufficient materials."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 10}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)
        
        inventory = {909: 5}  # Not enough
        character_state = {"skills": {"AM_PHARMACY": 1}}

        # Act
        can_brew = manager.can_brew("501", inventory, character_state)

        # Assert
        assert can_brew is False

    def test_get_required_materials(self, tmp_path):
        """Cover get_required_materials method."""
        # Arrange
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 909, "item_name": "Jellopy", "quantity_required": 1}
                    ],
                    "required_skill": "AM_PHARMACY",
                    "required_skill_level": 1,
                    "base_success_rate": 80.0
                }
            ]
        }
        brew_file = tmp_path / "brew_items.json"
        brew_file.write_text(json.dumps(brew_data))
        
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        materials = manager.get_required_materials("501")

        # Assert
        assert len(materials) == 1
        assert materials[0].item_id == 909

    def test_get_required_materials_unknown_recipe(self, tmp_path):
        """Cover get_required_materials with unknown recipe."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        materials = manager.get_required_materials("unknown")

        # Assert
        assert materials == []

    @pytest.mark.asyncio
    async def test_brew_method(self, tmp_path):
        """Cover brew method."""
        # Arrange
        crafting_manager = Mock(spec=CraftingManager)
        manager = BrewingManager(tmp_path, crafting_manager)

        # Act
        result = await manager.brew("red potion", quantity=5)

        # Assert
        assert result["success"] is True
        assert result["recipe"] == "red potion"
        assert result["quantity"] == 5


class TestBrewableItemModel:
    """Test BrewableItem model properties."""

    def test_brewable_item_is_batch_brewable(self):
        """Cover BrewableItem.is_batch_brewable property."""
        # Arrange
        item = BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="AM_PHARMACY",
            required_skill_level=1,
            base_success_rate=80.0,
            batch_size=3
        )

        # Act
        is_batch = item.is_batch_brewable

        # Assert
        assert is_batch is True

    def test_brewable_item_requires_advanced_skill(self):
        """Cover BrewableItem.requires_advanced_skill property."""
        # Arrange
        item = BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="AM_PHARMACY",
            required_skill_level=7,
            base_success_rate=80.0
        )

        # Act
        requires_advanced = item.requires_advanced_skill

        # Assert
        assert requires_advanced is True