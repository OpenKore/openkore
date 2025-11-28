"""
Tests for dialogue parsing and analysis.
"""

import pytest

from ai_sidecar.npc.dialogue_parser import DialogueParser, DialogueAnalysis
from ai_sidecar.npc.models import DialogueState, DialogueChoice


class TestDialogueParser:
    """Test dialogue parser functionality."""

    def setup_method(self):
        """Set up test fixtures."""
        self.parser = DialogueParser()

    def test_quest_keyword_detection(self):
        """Test detection of quest keywords."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Quest NPC",
            current_text="I have a quest for you. Would you help me?",
        )

        analysis = self.parser.parse_dialogue(dialogue)
        assert analysis.dialogue_type == "quest_offer"

    def test_shop_detection(self):
        """Test detection of shop dialogue."""
        dialogue = DialogueState(
            npc_id=1002,
            npc_name="Shop NPC",
            current_text="Welcome to my shop! What would you like to buy?",
        )

        analysis = self.parser.parse_dialogue(dialogue)
        assert analysis.dialogue_type == "shop"

    def test_service_detection(self):
        """Test detection of service dialogue."""
        dialogue = DialogueState(
            npc_id=2001,
            npc_name="Kafra Employee",
            current_text="Welcome to Kafra Corp. I can help you with storage.",
        )

        analysis = self.parser.parse_dialogue(dialogue)
        assert analysis.dialogue_type == "service"

    def test_quest_offer_response_suggestion(self):
        """Test suggesting response to quest offer."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Quest NPC",
            current_text="I have a quest for you. Will you help?",
            choices=[
                DialogueChoice(index=0, text="Yes, I'll help!"),
                DialogueChoice(index=1, text="No thanks", is_exit=True),
            ],
            waiting_for_input=True,
            input_type="choice",
        )

        analysis = self.parser.parse_dialogue(dialogue)
        # Should suggest accepting the quest
        assert analysis.suggested_choice == 0

    def test_confidence_calculation(self):
        """Test confidence scoring."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Quest NPC",
            current_text="I need help with a quest.",
            choices=[
                DialogueChoice(index=0, text="Accept"),
                DialogueChoice(index=1, text="Decline"),
            ],
            waiting_for_input=True,
            input_type="choice",
        )

        analysis = self.parser.parse_dialogue(dialogue)
        assert analysis.confidence > 0.5

    def test_npc_type_identification(self):
        """Test NPC type identification from dialogue."""
        # Kafra detection
        npc_type = self.parser.identify_npc_type(
            "Kafra Employee",
            "I can help you with storage and teleportation."
        )
        assert npc_type.value == "service"

        # Shop detection
        npc_type = self.parser.identify_npc_type(
            "Weapon Dealer",
            "Buy or sell weapons here!"
        )
        assert npc_type.value == "shop"

        # Quest detection
        npc_type = self.parser.identify_npc_type(
            "Quest Giver",
            "I have a quest for brave adventurers."
        )
        assert npc_type.value == "quest"


class TestDialogueExtraction:
    """Test extracting information from dialogue."""

    def setup_method(self):
        """Set up test fixtures."""
        self.parser = DialogueParser()

    def test_extract_item_requirements(self):
        """Test extracting item requirements."""
        text = "Bring me 5 Red Potions and 3 Blue Herbs."
        # This is a placeholder test since actual extraction needs item DB
        requirements = self.parser.extract_item_requirements(text)
        # Should find patterns even if IDs are placeholders
        assert isinstance(requirements, list)

    def test_extract_monster_requirements(self):
        """Test extracting monster kill requirements."""
        text = "Kill 10 Porings and defeat 5 Lunatics."
        # This is a placeholder test since actual extraction needs monster DB
        requirements = self.parser.extract_monster_requirements(text)
        assert isinstance(requirements, list)