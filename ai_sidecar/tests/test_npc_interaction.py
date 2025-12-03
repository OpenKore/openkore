"""
Comprehensive test suite for NPC Interaction Engine.

Tests NPC interaction logic including dialogue handling, choice selection,
and interaction context management.
"""

from datetime import datetime
from unittest.mock import AsyncMock, Mock, patch

import pytest

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.dialogue_parser import DialogueAnalysis, DialogueParser
from ai_sidecar.npc.interaction import InteractionContext, NPCInteractionEngine
from ai_sidecar.npc.models import DialogueChoice, DialogueState, NPC, NPCType


@pytest.fixture
def interaction_engine():
    """Create NPCInteractionEngine instance."""
    return NPCInteractionEngine()


@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    state = Mock()
    state.in_dialogue = False
    state.current_dialogue = None
    return state


@pytest.fixture
def mock_npc():
    """Create mock NPC."""
    return NPC(
        npc_id=1001,
        name="Test NPC",
        npc_type=NPCType.QUEST,
        map_name="prontera",
        x=100,
        y=100,
        quests=[1, 2]
    )


@pytest.fixture
def mock_dialogue_state():
    """Create mock dialogue state."""
    return DialogueState(
        npc_id=1001,
        npc_name="Test NPC",
        current_text="Welcome! What can I do for you?",
        input_type="choice",
        choices=[
            DialogueChoice(index=0, text="I accept the quest", is_exit=False),
            DialogueChoice(index=1, text="Not interested", is_exit=True)
        ]
    )


@pytest.fixture
def mock_dialogue_analysis():
    """Create mock dialogue analysis."""
    return DialogueAnalysis(
        dialogue_type="quest_offer",
        keywords=["quest", "accept"],
        suggested_choice=0,
        quest_id=1,
        confidence=0.9
    )


# ==================== Initialization Tests ====================


class TestNPCInteractionEngineInit:
    """Test NPCInteractionEngine initialization."""
    
    def test_initialization(self, interaction_engine):
        """Test engine initialization."""
        assert interaction_engine.dialogue_parser is not None
        assert interaction_engine.npc_db is not None
        assert interaction_engine.current_interaction is None
    
    def test_dialogue_parser_creation(self, interaction_engine):
        """Test dialogue parser is created."""
        assert isinstance(interaction_engine.dialogue_parser, DialogueParser)


# ==================== Tick Method Tests ====================


class TestTickMethod:
    """Test main tick method."""
    
    @pytest.mark.asyncio
    async def test_tick_not_in_dialogue(self, interaction_engine, mock_game_state):
        """Test tick when not in dialogue."""
        actions = await interaction_engine.tick(mock_game_state)
        
        # Should check for NPC interactions but return empty
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_in_dialogue(self, interaction_engine, mock_game_state, mock_dialogue_state):
        """Test tick when in dialogue."""
        mock_game_state.in_dialogue = True
        mock_game_state.current_dialogue = mock_dialogue_state
        
        with patch.object(interaction_engine, '_handle_dialogue', new_callable=AsyncMock) as mock_handle:
            mock_handle.return_value = Mock(spec=Action)
            
            actions = await interaction_engine.tick(mock_game_state)
            
            assert len(actions) > 0
            mock_handle.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_tick_error_handling(self, interaction_engine, mock_game_state):
        """Test tick error handling."""
        mock_game_state.in_dialogue = True
        mock_game_state.current_dialogue = None  # Invalid state
        
        with patch.object(interaction_engine, '_handle_dialogue', side_effect=Exception("Test error")):
            actions = await interaction_engine.tick(mock_game_state)
            
            # Should handle error gracefully and return empty list
            assert actions == []


# ==================== Dialogue Handling Tests ====================


class TestDialogueHandling:
    """Test dialogue handling logic."""
    
    @pytest.mark.asyncio
    async def test_handle_dialogue_choice(self, interaction_engine, mock_game_state, mock_dialogue_state):
        """Test handling choice dialogue."""
        mock_dialogue_state.input_type = "choice"
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_analysis = Mock()
            mock_analysis.suggested_choice = 0
            mock_parse.return_value = mock_analysis
            
            action = await interaction_engine._handle_dialogue(mock_game_state, mock_dialogue_state)
            
            assert action is not None
            assert action.type == ActionType.TALK_NPC
            assert "dialogue_choice" in action.extra
    
    @pytest.mark.asyncio
    async def test_handle_dialogue_number(self, interaction_engine, mock_game_state, mock_dialogue_state):
        """Test handling number input dialogue."""
        mock_dialogue_state.input_type = "number"
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock()
            
            action = await interaction_engine._handle_dialogue(mock_game_state, mock_dialogue_state)
            
            assert action is not None
            assert "dialogue_number" in action.extra
    
    @pytest.mark.asyncio
    async def test_handle_dialogue_text(self, interaction_engine, mock_game_state, mock_dialogue_state):
        """Test handling text input dialogue."""
        mock_dialogue_state.input_type = "text"
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock()
            
            action = await interaction_engine._handle_dialogue(mock_game_state, mock_dialogue_state)
            
            assert action is not None
            assert "dialogue_text" in action.extra
    
    @pytest.mark.asyncio
    async def test_handle_dialogue_continue(self, interaction_engine, mock_game_state, mock_dialogue_state):
        """Test handling continue dialogue."""
        mock_dialogue_state.input_type = "continue"
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock()
            
            action = await interaction_engine._handle_dialogue(mock_game_state, mock_dialogue_state)
            
            assert action is not None
            assert action.extra.get("dialogue_continue") is True
    
    @pytest.mark.asyncio
    async def test_handle_dialogue_stores_history(self, interaction_engine, mock_game_state, mock_dialogue_state, mock_npc):
        """Test dialogue is stored in interaction history."""
        interaction_engine.current_interaction = InteractionContext(
            npc=mock_npc,
            purpose="quest"
        )
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock(suggested_choice=0)
            
            await interaction_engine._handle_dialogue(mock_game_state, mock_dialogue_state)
            
            assert len(interaction_engine.current_interaction.dialogue_history) == 1


# ==================== Choice Selection Tests ====================


class TestChoiceSelection:
    """Test dialogue choice selection logic."""
    
    def test_select_choice_with_suggestion(self, interaction_engine, mock_dialogue_state):
        """Test choice selection with parser suggestion."""
        mock_analysis = Mock()
        mock_analysis.suggested_choice = 1
        
        choice = interaction_engine._select_dialogue_choice(mock_dialogue_state, mock_analysis)
        
        assert choice == 1
    
    def test_select_choice_quest_accept(self, interaction_engine, mock_dialogue_state, mock_npc):
        """Test choice selection for quest acceptance."""
        interaction_engine.current_interaction = InteractionContext(
            npc=mock_npc,
            purpose="quest"
        )
        
        mock_analysis = Mock()
        mock_analysis.suggested_choice = None
        
        choice = interaction_engine._select_dialogue_choice(mock_dialogue_state, mock_analysis)
        
        # Should select "I accept" choice
        assert choice == 0
    
    def test_select_choice_service(self, interaction_engine, mock_dialogue_state, mock_npc):
        """Test choice selection for service."""
        interaction_engine.current_interaction = InteractionContext(
            npc=mock_npc,
            purpose="service"
        )
        
        mock_dialogue_state.choices = [
            DialogueChoice(index=0, text="Use storage", is_exit=False),
            DialogueChoice(index=1, text="Cancel", is_exit=True)
        ]
        
        mock_analysis = Mock()
        mock_analysis.suggested_choice = None
        
        choice = interaction_engine._select_dialogue_choice(mock_dialogue_state, mock_analysis)
        
        # Should select service option
        assert choice == 0
    
    def test_select_choice_default_non_exit(self, interaction_engine, mock_dialogue_state):
        """Test default choice selection (non-exit)."""
        mock_analysis = Mock()
        mock_analysis.suggested_choice = None
        
        choice = interaction_engine._select_dialogue_choice(mock_dialogue_state, mock_analysis)
        
        # Should select first non-exit choice
        assert choice == 0
    
    def test_select_choice_all_exit(self, interaction_engine, mock_dialogue_state):
        """Test choice selection when all choices are exit."""
        mock_dialogue_state.choices = [
            DialogueChoice(index=0, text="Exit", is_exit=True)
        ]
        
        mock_analysis = Mock()
        mock_analysis.suggested_choice = None
        
        choice = interaction_engine._select_dialogue_choice(mock_dialogue_state, mock_analysis)
        
        # Should fallback to first choice
        assert choice == 0


# ==================== Number Input Tests ====================


class TestNumberInput:
    """Test number input determination."""
    
    def test_determine_number_buying(self, interaction_engine, mock_dialogue_state, mock_npc):
        """Test number input for buying items."""
        interaction_engine.current_interaction = InteractionContext(
            npc=mock_npc,
            purpose="shop",
            items_to_buy=[(501, 10)]  # Buy 10 red potions
        )
        
        mock_analysis = Mock()
        
        number = interaction_engine._determine_number_input(mock_dialogue_state, mock_analysis)
        
        assert number == 10
    
    def test_determine_number_default(self, interaction_engine, mock_dialogue_state):
        """Test default number input."""
        mock_analysis = Mock()
        
        number = interaction_engine._determine_number_input(mock_dialogue_state, mock_analysis)
        
        assert number == 1


# ==================== Text Response Tests ====================


class TestTextResponse:
    """Test text response generation."""
    
    def test_generate_text_default(self, interaction_engine, mock_dialogue_state):
        """Test default text response."""
        mock_analysis = Mock()
        
        text = interaction_engine._generate_text_response(mock_dialogue_state, mock_analysis)
        
        # Should return empty string as default
        assert text == ""


# ==================== Action Creation Tests ====================


class TestActionCreation:
    """Test action creation methods."""
    
    def test_create_dialogue_choice_action(self, interaction_engine):
        """Test dialogue choice action creation."""
        action = interaction_engine._create_dialogue_choice_action(2)
        
        assert action.type == ActionType.TALK_NPC
        assert action.priority == 1
        assert action.extra["dialogue_choice"] == 2
    
    def test_create_number_input_action(self, interaction_engine):
        """Test number input action creation."""
        action = interaction_engine._create_number_input_action(5)
        
        assert action.type == ActionType.TALK_NPC
        assert action.priority == 1
        assert action.extra["dialogue_number"] == 5
    
    def test_create_text_input_action(self, interaction_engine):
        """Test text input action creation."""
        action = interaction_engine._create_text_input_action("test input")
        
        assert action.type == ActionType.TALK_NPC
        assert action.priority == 1
        assert action.extra["dialogue_text"] == "test input"
    
    def test_create_continue_dialogue_action(self, interaction_engine):
        """Test continue dialogue action creation."""
        action = interaction_engine._create_continue_dialogue_action()
        
        assert action.type == ActionType.TALK_NPC
        assert action.priority == 1
        assert action.extra["dialogue_continue"] is True


# ==================== NPC Interaction Evaluation Tests ====================


class TestNPCInteractionEvaluation:
    """Test NPC interaction evaluation."""
    
    def test_evaluate_npc_interactions_default(self, interaction_engine, mock_game_state):
        """Test default NPC interaction evaluation."""
        action = interaction_engine._evaluate_npc_interactions(mock_game_state)
        
        # Should return None by default
        assert action is None
    
    def test_should_talk_to_quest_npc(self, interaction_engine, mock_npc, mock_game_state):
        """Test should talk to quest NPC."""
        mock_npc.npc_type = NPCType.QUEST
        mock_npc.quests = [1, 2]
        
        should_talk = interaction_engine.should_talk_to_npc(mock_npc, mock_game_state)
        
        assert should_talk is True
    
    def test_should_not_talk_to_service_npc(self, interaction_engine, mock_npc, mock_game_state):
        """Test should not talk to service NPC (handled by service handler)."""
        mock_npc.npc_type = NPCType.SERVICE
        
        should_talk = interaction_engine.should_talk_to_npc(mock_npc, mock_game_state)
        
        assert should_talk is False
    
    def test_should_not_talk_to_generic_npc(self, interaction_engine, mock_npc, mock_game_state):
        """Test should not talk to generic NPC."""
        mock_npc.npc_type = NPCType.GENERIC
        mock_npc.quests = []
        
        should_talk = interaction_engine.should_talk_to_npc(mock_npc, mock_game_state)
        
        assert should_talk is False


# ==================== Interaction Lifecycle Tests ====================


class TestInteractionLifecycle:
    """Test interaction start and end."""
    
    def test_start_interaction(self, interaction_engine, mock_npc):
        """Test starting interaction."""
        interaction_engine.start_interaction(mock_npc, "quest")
        
        assert interaction_engine.current_interaction is not None
        assert interaction_engine.current_interaction.npc == mock_npc
        assert interaction_engine.current_interaction.purpose == "quest"
        assert isinstance(interaction_engine.current_interaction.started_at, datetime)
    
    def test_end_interaction(self, interaction_engine, mock_npc):
        """Test ending interaction."""
        interaction_engine.start_interaction(mock_npc, "quest")
        assert interaction_engine.current_interaction is not None
        
        interaction_engine.end_interaction()
        
        assert interaction_engine.current_interaction is None
    
    def test_end_interaction_none(self, interaction_engine):
        """Test ending interaction when none active."""
        # Should not raise error
        interaction_engine.end_interaction()
        assert interaction_engine.current_interaction is None
    
    def test_interaction_purpose_shop(self, interaction_engine, mock_npc):
        """Test interaction with shop purpose."""
        interaction_engine.start_interaction(mock_npc, "shop")
        
        assert interaction_engine.current_interaction.purpose == "shop"
        assert interaction_engine.current_interaction.items_to_buy == []
        assert interaction_engine.current_interaction.items_to_sell == []
    
    def test_interaction_purpose_service(self, interaction_engine, mock_npc):
        """Test interaction with service purpose."""
        interaction_engine.start_interaction(mock_npc, "service")
        
        assert interaction_engine.current_interaction.purpose == "service"
    
    def test_interaction_purpose_exploration(self, interaction_engine, mock_npc):
        """Test interaction with exploration purpose."""
        interaction_engine.start_interaction(mock_npc, "exploration")
        
        assert interaction_engine.current_interaction.purpose == "exploration"


# ==================== Interaction Context Tests ====================


class TestInteractionContext:
    """Test InteractionContext model."""
    
    def test_context_creation(self, mock_npc):
        """Test context creation."""
        context = InteractionContext(
            npc=mock_npc,
            purpose="quest"
        )
        
        assert context.npc == mock_npc
        assert context.purpose == "quest"
        assert context.dialogue_history == []
        assert context.items_to_buy == []
        assert context.items_to_sell == []
        assert context.quest_to_accept is None
        assert context.quest_to_complete is None
    
    def test_context_with_quest(self, mock_npc):
        """Test context with quest data."""
        context = InteractionContext(
            npc=mock_npc,
            purpose="quest",
            quest_to_accept=1
        )
        
        assert context.quest_to_accept == 1
    
    def test_context_with_shopping(self, mock_npc):
        """Test context with shopping data."""
        context = InteractionContext(
            npc=mock_npc,
            purpose="shop",
            items_to_buy=[(501, 10), (502, 5)]
        )
        
        assert len(context.items_to_buy) == 2
        assert context.items_to_buy[0] == (501, 10)


# ==================== Integration Tests ====================


class TestNPCInteractionIntegration:
    """Test integration scenarios."""
    
    @pytest.mark.asyncio
    async def test_full_quest_dialogue_flow(self, interaction_engine, mock_game_state, mock_npc):
        """Test complete quest dialogue flow."""
        # Start interaction
        interaction_engine.start_interaction(mock_npc, "quest")
        
        # Simulate dialogue state
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Test NPC",
            text="I need your help with a task. Will you accept?",
            input_type="choice",
            choices=[
                DialogueChoice(index=0, text="Yes, I will help", is_exit=False),
                DialogueChoice(index=1, text="No thanks", is_exit=True)
            ]
        )
        
        mock_game_state.in_dialogue = True
        mock_game_state.current_dialogue = dialogue
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock(suggested_choice=0)
            
            actions = await interaction_engine.tick(mock_game_state)
            
            assert len(actions) > 0
            assert actions[0].extra["dialogue_choice"] == 0
    
    @pytest.mark.asyncio
    async def test_shop_interaction_flow(self, interaction_engine, mock_game_state, mock_npc):
        """Test shop interaction flow."""
        # Start shop interaction
        interaction_engine.start_interaction(mock_npc, "shop")
        interaction_engine.current_interaction.items_to_buy = [(501, 20)]
        
        # Simulate number input for quantity
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Shop NPC",
            text="How many do you want to buy?",
            input_type="number",
            choices=[]
        )
        
        mock_game_state.in_dialogue = True
        mock_game_state.current_dialogue = dialogue
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock()
            
            actions = await interaction_engine.tick(mock_game_state)
            
            assert len(actions) > 0
            assert actions[0].extra["dialogue_number"] == 20
    
    @pytest.mark.asyncio
    async def test_service_interaction_flow(self, interaction_engine, mock_game_state, mock_npc):
        """Test service interaction flow."""
        # Start service interaction
        interaction_engine.start_interaction(mock_npc, "service")
        
        # Simulate service selection
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Kafra",
            current_text="What service would you like?",
            input_type="choice",
            choices=[
                DialogueChoice(index=0, text="Use storage", is_exit=False),
                DialogueChoice(index=1, text="Save point", is_exit=False),
                DialogueChoice(index=2, text="Cancel", is_exit=True)
            ]
        )
        
        mock_game_state.in_dialogue = True
        mock_game_state.current_dialogue = dialogue
        
        with patch.object(interaction_engine.dialogue_parser, 'parse_dialogue') as mock_parse:
            mock_parse.return_value = Mock(suggested_choice=None)
            
            actions = await interaction_engine.tick(mock_game_state)
            
            assert len(actions) > 0
            # Should select storage option
            assert actions[0].extra["dialogue_choice"] == 0