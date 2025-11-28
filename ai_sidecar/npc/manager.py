"""
NPC Manager - Orchestrates all NPC interaction systems.

Coordinates NPC interactions, quests, and services to provide
cohesive NPC-related decision making for the AI.
"""

from typing import TYPE_CHECKING

from ai_sidecar.core.decision import Action
from ai_sidecar.npc.interaction import NPCInteractionEngine
from ai_sidecar.npc.models import NPC, NPCDatabase
from ai_sidecar.npc.quest_manager import QuestManager
from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class NPCManager:
    """
    Orchestrates NPC interactions, quests, and services.

    Manages:
    - Dialogue handling through NPCInteractionEngine
    - Quest tracking through QuestManager
    - Service access through ServiceHandler
    - NPC discovery and cataloging

    Priority hierarchy:
    1. Handle ongoing dialogue (highest priority)
    2. Quest-related activities
    3. Service needs (storage, refine, etc.)
    """

    def __init__(self) -> None:
        """Initialize NPC manager and subsystems."""
        self.interaction_engine = NPCInteractionEngine()
        self.quest_manager = QuestManager()
        self.service_handler = ServiceHandler()
        self.npc_db = NPCDatabase()

        logger.info("NPC manager initialized")

    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main NPC management tick.

        Args:
            game_state: Current game state

        Returns:
            List of NPC-related actions
        """
        actions: list[Action] = []

        try:
            # Priority 1: Handle ongoing dialogue
            # Dialogue must be processed first and exclusively
            if self._is_in_dialogue(game_state):
                dialogue_actions = await self.interaction_engine.tick(game_state)
                actions.extend(dialogue_actions)
                return actions  # Return early - don't do anything else during dialogue

            # Priority 2: Quest management
            # Quest actions include talking to NPCs, killing monsters, etc.
            quest_actions = await self.quest_manager.tick(game_state)
            actions.extend(quest_actions)

            # Priority 3: Service needs
            # Check if services are needed (storage, repair, etc.)
            if not actions:  # Only check services if no quest actions
                service_actions = await self._check_service_needs(game_state)
                actions.extend(service_actions)

        except Exception as e:
            logger.error(f"Error in NPC manager tick: {e}", exc_info=True)

        return actions

    def _is_in_dialogue(self, game_state: "GameState") -> bool:
        """
        Check if character is currently in dialogue.

        Args:
            game_state: Current game state

        Returns:
            True if in dialogue
        """
        return hasattr(game_state, "in_dialogue") and game_state.in_dialogue

    async def _check_service_needs(self, game_state: "GameState") -> list[Action]:
        """
        Check if any services are needed.

        Args:
            game_state: Current game state

        Returns:
            List of service-related actions
        """
        actions: list[Action] = []

        # Check if inventory is full or nearly full
        if self._needs_storage(game_state):
            storage_actions = await self.service_handler.use_storage(game_state)
            actions.extend(storage_actions)

        return actions

    def _needs_storage(self, game_state: "GameState") -> bool:
        """
        Check if character needs to use storage.

        Args:
            game_state: Current game state

        Returns:
            True if storage is needed
        """
        # Check weight
        weight_percent = game_state.character.weight_percent
        if weight_percent > 80:
            return True

        # Check inventory slot count (if available)
        if hasattr(game_state.inventory, "items"):
            item_count = len(game_state.inventory.items)
            # Assume max 100 slots
            if item_count > 80:
                return True

        return False

    def on_npc_spotted(self, npc: NPC) -> None:
        """
        Handle NPC discovery.

        Args:
            npc: Newly discovered NPC
        """
        # Add to database if not already present
        if not self.npc_db.get_npc(npc.npc_id):
            self.npc_db.add_npc(npc)
            logger.info(f"Discovered new NPC: {npc.name} ({npc.npc_type})")

    def register_event_handlers(self, event_bus: object) -> None:
        """
        Register event handlers for NPC and quest events.

        Args:
            event_bus: Event bus to register handlers on
        """
        # Quest-related events
        if hasattr(event_bus, "on"):
            event_bus.on("monster_killed", self.quest_manager.on_monster_kill)
            event_bus.on("item_obtained", self.quest_manager.on_item_obtained)
            event_bus.on("npc_talked", self.quest_manager.on_npc_talk)
            event_bus.on("npc_spotted", self.on_npc_spotted)

            logger.info("Event handlers registered")

    def get_active_quest_count(self) -> int:
        """
        Get number of active quests.

        Returns:
            Count of active quests
        """
        return len(self.quest_manager.quest_log.active_quests)

    def get_completed_quest_count(self) -> int:
        """
        Get number of completed quests.

        Returns:
            Count of completed quests
        """
        return len(self.quest_manager.quest_log.completed_quests)

    def get_npc_count(self) -> int:
        """
        Get number of discovered NPCs.

        Returns:
            Count of NPCs in database
        """
        return self.npc_db.count()

    def load_npc_data(self, npc_data: dict) -> None:
        """
        Load NPC data from configuration.

        Args:
            npc_data: Dictionary of NPC definitions
        """
        try:
            # Load NPCs
            if "npcs" in npc_data:
                for npc_dict in npc_data["npcs"]:
                    npc = NPC(**npc_dict)
                    self.npc_db.add_npc(npc)

            logger.info(f"Loaded {self.npc_db.count()} NPCs from data")

        except Exception as e:
            logger.error(f"Error loading NPC data: {e}", exc_info=True)

    def load_quest_data(self, quest_data: dict) -> None:
        """
        Load quest data from configuration.

        Args:
            quest_data: Dictionary of quest definitions
        """
        try:
            self.quest_manager.load_quest_database(quest_data)
            logger.info("Loaded quest data")

        except Exception as e:
            logger.error(f"Error loading quest data: {e}", exc_info=True)

    def load_service_data(self, service_data: dict) -> None:
        """
        Load service NPC data from configuration.

        Args:
            service_data: Dictionary of service NPC definitions
        """
        try:
            from ai_sidecar.npc.models import ServiceNPC

            # Load service NPCs by type
            for service_type, locations in service_data.items():
                if isinstance(locations, dict):
                    for map_name, npcs in locations.items():
                        for npc_dict in npcs:
                            service_npc = ServiceNPC(
                                service_type=service_type,
                                map_name=map_name,
                                **npc_dict,
                            )
                            self.service_handler.service_db.add_service_npc(
                                service_npc
                            )

            logger.info("Loaded service NPC data")

        except Exception as e:
            logger.error(f"Error loading service data: {e}", exc_info=True)