"""
Extended test coverage for dialogue_parser.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 413, 426-428, 457, 479-490, 517-519, 535-625, 638, 663, 701-801
- Reward extraction, evaluation, response patterns
- NPC type identification
"""

import pytest
from unittest.mock import Mock

from ai_sidecar.npc.dialogue_parser import DialogueParser, DialogueAnalysis
from ai_sidecar.npc.models import DialogueState, DialogueChoice, NPCType
from ai_sidecar.npc.quest_models import Quest, QuestObjective, QuestObjectiveType


class TestDialogueParserExtendedCoverage:
    """Extended coverage for dialogue parser."""
    
    def test_extract_rewards_zeny(self):
        """Test extracting zeny rewards."""
        parser = DialogueParser()
        
        text = "I will reward you with 1000 zeny for completing this task."
        
        rewards = parser._extract_rewards(text)
        
        assert len(rewards) > 0
        assert any(r.reward_type == "zeny" for r in rewards)
    
    def test_extract_rewards_base_exp(self):
        """Test extracting base experience rewards."""
        parser = DialogueParser()
        
        text = "You will receive 5000 base experience as a reward."
        
        rewards = parser._extract_rewards(text)
        
        assert len(rewards) > 0
        assert any(r.reward_type == "exp_base" for r in rewards)
    
    def test_extract_rewards_job_exp(self):
        """Test extracting job experience rewards."""
        parser = DialogueParser()
        
        text = "Complete this and get 2500 job experience points."
        
        rewards = parser._extract_rewards(text)
        
        assert len(rewards) > 0
        assert any(r.reward_type == "exp_job" for r in rewards)
    
    def test_lookup_item_id_plural_form(self):
        """Test looking up item by plural name."""
        parser = DialogueParser()
        
        item_id = parser._lookup_item_id("jellop ies")  # Plural
        
        assert item_id == 909  # Should find "jellopy"
    
    def test_lookup_item_id_fuzzy_match(self):
        """Test fuzzy matching for item names."""
        parser = DialogueParser()
        
        item_id = parser._lookup_item_id("red healing potion")
        
        # Should fuzzy match to "red potion"
        assert item_id > 0
    
    def test_lookup_item_id_unknown(self):
        """Test looking up unknown item."""
        parser = DialogueParser()
        
        item_id = parser._lookup_item_id("completely_unknown_item_xyz")
        
        assert item_id == 0
    
    def test_lookup_monster_id_plural_form(self):
        """Test looking up monster by plural name."""
        parser = DialogueParser()
        
        monster_id = parser._lookup_monster_id("porings")  # Plural
        
        assert monster_id == 1002
    
    def test_lookup_monster_id_fuzzy_match(self):
        """Test fuzzy matching for monster names."""
        parser = DialogueParser()
        
        monster_id = parser._lookup_monster_id("green poring")
        
        # Should fuzzy match to "poring"
        assert monster_id > 0
    
    def test_lookup_monster_id_unknown(self):
        """Test looking up unknown monster."""
        parser = DialogueParser()
        
        monster_id = parser._lookup_monster_id("unknown_monster_xyz")
        
        assert monster_id == 0
    
    def test_extract_npc_mentions(self):
        """Test extracting NPC name mentions."""
        parser = DialogueParser()
        
        text = "Please go talk to Captain Smith in Prontera."
        
        mentions = parser._extract_npc_mentions(text)
        
        assert "Captain Smith" in mentions or "Captain" in mentions
    
    def test_extract_location_mentions(self):
        """Test extracting location mentions."""
        parser = DialogueParser()
        
        text = "Travel to Geffen and speak with the wizard in Prontera."
        
        locations = parser._extract_location_mentions(text)
        
        assert "geffen" in locations or "prontera" in locations
    
    def test_suggest_response_quest_offer(self):
        """Test suggesting response for quest offer."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Yes, I'll help you!", is_exit=False)
        choice2 = DialogueChoice(index=1, text="No thanks", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Quest Giver",
            current_text="I have a quest for you. Will you accept?",
            choices=[choice1, choice2]
        )
        
        suggestion = parser.suggest_response(dialogue, "quest_offer")
        
        assert suggestion == 0  # Should suggest accepting
    
    def test_suggest_response_quest_complete(self):
        """Test suggesting response for quest completion."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Turn in quest", is_exit=False)
        choice2 = DialogueChoice(index=1, text="Cancel", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Quest Giver",
            current_text="Great! You've finished the quest!",
            choices=[choice1, choice2]
        )
        
        suggestion = parser.suggest_response(dialogue, "quest_complete")
        
        assert suggestion == 0
    
    def test_suggest_response_shop(self):
        """Test suggesting response for shop dialogue."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Buy items", is_exit=False)
        choice2 = DialogueChoice(index=1, text="Sell items", is_exit=False)
        choice3 = DialogueChoice(index=2, text="Leave", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Shop",
            current_text="Welcome to my shop!",
            choices=[choice1, choice2, choice3]
        )
        
        suggestion = parser.suggest_response(dialogue, "shop")
        
        assert suggestion == 0  # Prefer buy
    
    def test_suggest_response_service(self):
        """Test suggesting response for service dialogue."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Use storage", is_exit=False)
        choice2 = DialogueChoice(index=1, text="Teleport", is_exit=False)
        choice3 = DialogueChoice(index=2, text="Leave", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Kafra",
            current_text="How can I help you?",
            choices=[choice1, choice2, choice3]
        )
        
        suggestion = parser.suggest_response(dialogue, "service")
        
        assert suggestion in [0, 1]  # Storage or teleport
    
    def test_suggest_response_no_choices(self):
        """Test suggesting response when no choices."""
        parser = DialogueParser()
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            current_text="Hello!",
            choices=[]
        )
        
        suggestion = parser.suggest_response(dialogue, "information")
        
        assert suggestion is None
    
    def test_suggest_response_default_non_exit(self):
        """Test default suggestion prefers non-exit choice."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Continue", is_exit=False)
        choice2 = DialogueChoice(index=1, text="Exit", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            current_text="Some text",
            choices=[choice1, choice2]
        )
        
        suggestion = parser.suggest_response(dialogue, "unknown")
        
        assert suggestion == 0
    
    def test_evaluate_selection_options_empty(self):
        """Test evaluating empty selection options."""
        parser = DialogueParser()
        
        result = parser._evaluate_selection_options([])
        
        assert result is None
    
    def test_evaluate_selection_options_with_rewards(self):
        """Test evaluating options prefers rewards."""
        parser = DialogueParser()
        
        choice1 = Mock()
        choice1.text = "Extra reward option"
        choice1.is_exit = False
        
        choice2 = Mock()
        choice2.text = "Normal option"
        choice2.is_exit = False
        
        result = parser._evaluate_selection_options([choice1, choice2])
        
        assert result == 0  # Should prefer reward option
    
    def test_evaluate_selection_options_avoids_exit(self):
        """Test evaluating options avoids exit."""
        parser = DialogueParser()
        
        choice1 = Mock()
        choice1.text = "Continue"
        choice1.is_exit = False
        
        choice2 = Mock()
        choice2.text = "Exit"
        choice2.is_exit = True
        
        result = parser._evaluate_selection_options([choice1, choice2])
        
        assert result == 0  # Should avoid exit
    
    def test_calculate_confidence_quest_offer(self):
        """Test confidence calculation for quest offer."""
        parser = DialogueParser()
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            current_text="I have a quest",
            choices=[Mock()]
        )
        
        confidence = parser._calculate_confidence(dialogue, "quest_offer")
        
        assert confidence >= 0.5
    
    def test_calculate_confidence_unknown_type(self):
        """Test confidence calculation for unknown type."""
        parser = DialogueParser()
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="NPC",
            current_text="Some text",
            choices=[]
        )
        
        confidence = parser._calculate_confidence(dialogue, "unknown")
        
        assert confidence < 0.5
    
    def test_identify_quest_offer(self):
        """Test identifying quest offer."""
        parser = DialogueParser()
        
        text = "I have a quest for you. Will you help me?"
        
        result = parser.identify_quest_offer(text)
        
        assert result["is_quest_offer"] is True
        assert result["confidence"] > 0.5
        assert len(result["keywords_found"]) > 0
    
    def test_identify_quest_progress(self):
        """Test identifying quest progress check."""
        parser = DialogueParser()
        
        text = "How is the quest going? Have you collected the items?"
        
        result = parser.identify_quest_progress(text)
        
        assert result["is_quest_progress"] is True
    
    def test_identify_quest_complete(self):
        """Test identifying quest completion."""
        parser = DialogueParser()
        
        text = "Congratulations! You've completed the quest!"
        
        result = parser.identify_quest_complete(text)
        
        assert result["is_quest_complete"] is True
    
    def test_identify_shop(self):
        """Test identifying shop dialogue."""
        parser = DialogueParser()
        
        text = "Welcome to my shop! Would you like to buy or sell?"
        
        result = parser.identify_shop(text)
        
        assert result["is_shop"] is True
    
    def test_identify_service(self):
        """Test identifying service dialogue."""
        parser = DialogueParser()
        
        text = "I'm a Kafra employee. I can help with storage and teleportation."
        
        result = parser.identify_service(text)
        
        assert result["is_service"] is True
    
    def test_identify_information(self):
        """Test identifying information dialogue."""
        parser = DialogueParser()
        
        text = "The weather is nice today."
        
        result = parser.identify_information(text)
        
        assert result["is_information"] is True
    
    def test_calculate_confidence_with_indicators(self):
        """Test calculating confidence with multiple indicators."""
        parser = DialogueParser()
        
        indicators = ["quest", "help", "reward"]
        
        confidence = parser.calculate_confidence("quest_offer", indicators)
        
        assert confidence > 0.5
    
    def test_calculate_confidence_no_indicators(self):
        """Test calculating confidence with no indicators."""
        parser = DialogueParser()
        
        confidence = parser.calculate_confidence("unknown", [])
        
        assert confidence == 0.1
    
    def test_identify_npc_type_kafra(self):
        """Test identifying Kafra NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Kafra Employee", "I can help with storage.")
        
        assert npc_type == NPCType.SERVICE
    
    def test_identify_npc_type_shop(self):
        """Test identifying shop NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Shopkeeper", "Would you like to buy something?")
        
        assert npc_type == NPCType.SHOP
    
    def test_identify_npc_type_warp(self):
        """Test identifying warp NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Portal", "Where would you like to warp?")
        
        assert npc_type == NPCType.WARP
    
    def test_identify_npc_type_quest(self):
        """Test identifying quest NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Quest Giver", "I have a quest for you.")
        
        assert npc_type == NPCType.QUEST
    
    def test_identify_npc_type_guild(self):
        """Test identifying guild NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Guild Master", "Welcome to our guild.")
        
        assert npc_type == NPCType.GUILD
    
    def test_identify_npc_type_generic(self):
        """Test identifying generic NPC."""
        parser = DialogueParser()
        
        npc_type = parser.identify_npc_type("Citizen", "Hello there!")
        
        assert npc_type == NPCType.GENERIC
    
    def test_extract_quest_info_no_requirements(self):
        """Test extracting quest info with no requirements."""
        parser = DialogueParser()
        
        dialogue_history = ["Just some regular dialogue without any quest."]
        
        quest = parser.extract_quest_info(dialogue_history)
        
        assert quest is None
    
    def test_extract_quest_info_with_items_and_monsters(self):
        """Test extracting quest info with mixed requirements."""
        parser = DialogueParser()
        
        dialogue_history = [
            "I need you to collect 10 Jellopy",
            "and kill 5 Porings",
            "I'll reward you with 1000 zeny"
        ]
        
        quest = parser.extract_quest_info(dialogue_history)
        
        assert quest is not None
        assert len(quest.objectives) > 0
    
    def test_parse_dialogue_comprehensive(self):
        """Test comprehensive dialogue parsing."""
        parser = DialogueParser()
        
        choice1 = DialogueChoice(index=0, text="Accept quest", is_exit=False)
        choice2 = DialogueChoice(index=1, text="Decline", is_exit=True)
        
        dialogue = DialogueState(
            npc_id=1,
            npc_name="Quest Giver",
            current_text="I need you to bring me 5 Red Potions. Will you help?",
            choices=[choice1, choice2],
            history=["Hello adventurer!"]
        )
        
        analysis = parser.parse_dialogue(dialogue)
        
        assert analysis.dialogue_type == "quest_offer"
        assert len(analysis.item_requirements) > 0
        assert analysis.suggested_choice is not None
        assert analysis.confidence > 0
    
    def test_item_extraction_with_bracket_format(self):
        """Test item extraction with bracket format."""
        parser = DialogueParser()
        
        text = "Please bring me [Red Potion] x5 and [Blue Potion] x3"
        
        items = parser.extract_item_requirements(text)
        
        assert len(items) > 0
    
    def test_monster_extraction_various_patterns(self):
        """Test monster extraction with different patterns."""
        parser = DialogueParser()
        
        text = "Hunt 20 Porings and defeat 10 Lunatics. 5 Willows must be slain!"
        
        monsters = parser.extract_monster_requirements(text)
        
        # Should extract all three patterns
        assert len(monsters) >= 2