"""
NPC interaction engine for handling dialogue and responses.

Manages NPC conversations, dialogue choice selection, and interaction flow.
"""

from datetime import datetime
from typing import TYPE_CHECKING, Literal

from pydantic import BaseModel, Field

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.dialogue_parser import DialogueAnalysis, DialogueParser
from ai_sidecar.npc.models import NPC, NPCDatabase, DialogueState
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class InteractionContext(BaseModel):
    """Context for ongoing NPC interaction."""

    npc: NPC = Field(description="NPC being interacted with")
    purpose: Literal["quest", "shop", "service", "exploration"] = Field(
        description="Purpose of interaction"
    )
    started_at: datetime = Field(
        default_factory=datetime.now, description="When interaction started"
    )
    dialogue_history: list[DialogueState] = Field(
        default_factory=list, description="Dialogue history"
    )

    # Shopping context
    items_to_buy: list[tuple[int, int]] = Field(
        default_factory=list, description="(item_id, quantity) to purchase"
    )
    items_to_sell: list[tuple[int, int]] = Field(
        default_factory=list, description="(item_id, quantity) to sell"
    )

    # Quest context
    quest_to_accept: int | None = Field(
        default=None, description="Quest ID to accept"
    )
    quest_to_complete: int | None = Field(
        default=None, description="Quest ID to complete"
    )


class NPCInteractionEngine:
    """
    Handles all NPC interaction logic including dialogue and responses.

    Manages:
    - Dialogue parsing and analysis
    - Response selection
    - Interaction state tracking
    - Smart dialogue navigation
    """

    def __init__(self) -> None:
        """Initialize NPC interaction engine."""
        self.dialogue_parser = DialogueParser()
        self.npc_db = NPCDatabase()
        self.current_interaction: InteractionContext | None = None

        logger.info("NPC interaction engine initialized")

    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main NPC interaction tick.

        Args:
            game_state: Current game state

        Returns:
            List of interaction actions
        """
        actions: list[Action] = []

        try:
            # Check if in dialogue
            if hasattr(game_state, "in_dialogue") and game_state.in_dialogue:
                # Handle ongoing dialogue
                dialogue_state = getattr(game_state, "current_dialogue", None)
                if dialogue_state:
                    action = await self._handle_dialogue(game_state, dialogue_state)
                    if action:
                        actions.append(action)
            else:
                # Check if should initiate NPC interaction
                npc_action = self._evaluate_npc_interactions(game_state)
                if npc_action:
                    actions.append(npc_action)

        except Exception as e:
            logger.error(f"Error in NPC interaction tick: {e}", exc_info=True)

        return actions

    async def _handle_dialogue(
        self, game_state: "GameState", dialogue: DialogueState
    ) -> Action | None:
        """
        Process current dialogue and respond appropriately.

        Args:
            game_state: Current game state
            dialogue: Current dialogue state

        Returns:
            Action to perform or None
        """
        # Analyze dialogue
        analysis = self.dialogue_parser.parse_dialogue(dialogue)

        # Store dialogue in history
        if self.current_interaction:
            self.current_interaction.dialogue_history.append(dialogue)

        # Determine response based on input type
        if dialogue.input_type == "choice":
            choice_index = self._select_dialogue_choice(dialogue, analysis)
            return self._create_dialogue_choice_action(choice_index)

        elif dialogue.input_type == "number":
            number = self._determine_number_input(dialogue, analysis)
            return self._create_number_input_action(number)

        elif dialogue.input_type == "text":
            text = self._generate_text_response(dialogue, analysis)
            return self._create_text_input_action(text)

        # Default: continue dialogue
        return self._create_continue_dialogue_action()

    def _select_dialogue_choice(
        self, dialogue: DialogueState, analysis: DialogueAnalysis
    ) -> int:
        """
        Select best dialogue choice based on context and analysis.

        Args:
            dialogue: Current dialogue state
            analysis: Dialogue analysis result

        Returns:
            Choice index to select
        """
        # Use parser suggestion if available
        if analysis.suggested_choice is not None:
            logger.debug(
                f"Using parser suggested choice: {analysis.suggested_choice}"
            )
            return analysis.suggested_choice

        # Check interaction context
        if self.current_interaction:
            if self.current_interaction.purpose == "quest":
                # Accept quest
                for i, choice in enumerate(dialogue.choices):
                    if any(
                        word in choice.text.lower()
                        for word in ["yes", "accept", "take"]
                    ):
                        return i

            elif self.current_interaction.purpose == "service":
                # Select service option
                for i, choice in enumerate(dialogue.choices):
                    if any(
                        word in choice.text.lower()
                        for word in ["storage", "save", "teleport"]
                    ):
                        return i

        # Default: first non-exit choice
        for i, choice in enumerate(dialogue.choices):
            if not choice.is_exit:
                return i

        return 0  # Fallback

    def _determine_number_input(
        self, dialogue: DialogueState, analysis: DialogueAnalysis
    ) -> int:
        """
        Determine number to input based on dialogue context.

        Args:
            dialogue: Current dialogue state
            analysis: Dialogue analysis result

        Returns:
            Number to input
        """
        # Check if buying/selling
        if self.current_interaction:
            if self.current_interaction.items_to_buy:
                # Return quantity to buy
                return self.current_interaction.items_to_buy[0][1]

        # Default to 1
        return 1

    def _generate_text_response(
        self, dialogue: DialogueState, analysis: DialogueAnalysis
    ) -> str:
        """
        Generate text response for text input.

        Args:
            dialogue: Current dialogue state
            analysis: Dialogue analysis result

        Returns:
            Text to input
        """
        # For now, return empty (most text inputs are optional)
        return ""

    def _create_dialogue_choice_action(self, choice_index: int) -> Action:
        """Create action to select a dialogue choice."""
        return Action(
            type=ActionType.TALK_NPC,
            priority=1,
            extra={"dialogue_choice": choice_index},
        )

    def _create_number_input_action(self, number: int) -> Action:
        """Create action to input a number."""
        return Action(
            type=ActionType.TALK_NPC,
            priority=1,
            extra={"dialogue_number": number},
        )

    def _create_text_input_action(self, text: str) -> Action:
        """Create action to input text."""
        return Action(
            type=ActionType.TALK_NPC,
            priority=1,
            extra={"dialogue_text": text},
        )

    def _create_continue_dialogue_action(self) -> Action:
        """Create action to continue dialogue."""
        return Action(
            type=ActionType.TALK_NPC,
            priority=1,
            extra={"dialogue_continue": True},
        )

    def _evaluate_npc_interactions(self, game_state: "GameState") -> Action | None:
        """
        Evaluate whether to initiate NPC interaction.

        Args:
            game_state: Current game state

        Returns:
            Action to interact with NPC or None
        """
        # For now, don't proactively initiate interactions
        # This will be handled by quest manager and service handler
        return None

    def should_talk_to_npc(
        self, npc: NPC, game_state: "GameState"
    ) -> bool:
        """
        Determine if should initiate conversation with NPC.

        Args:
            npc: NPC to evaluate
            game_state: Current game state

        Returns:
            True if should talk to NPC
        """
        # Check if NPC is quest-related
        if npc.npc_type.value == "quest" and npc.quests:
            return True

        # Check if NPC provides needed service
        if npc.npc_type.value == "service":
            return False  # Service handler decides

        return False

    def start_interaction(
        self,
        npc: NPC,
        purpose: Literal["quest", "shop", "service", "exploration"],
    ) -> None:
        """
        Start new NPC interaction.

        Args:
            npc: NPC to interact with
            purpose: Purpose of interaction
        """
        self.current_interaction = InteractionContext(npc=npc, purpose=purpose)
        logger.info(f"Started interaction with {npc.name} for {purpose}")

    def end_interaction(self) -> None:
        """End current NPC interaction."""
        if self.current_interaction:
            duration = (
                datetime.now() - self.current_interaction.started_at
            ).total_seconds()
            logger.info(
                f"Ended interaction with {self.current_interaction.npc.name} "
                f"after {duration:.1f}s"
            )
            self.current_interaction = None