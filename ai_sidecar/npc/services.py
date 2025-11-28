"""
Service NPC handler for Kafra, refiners, and other service NPCs.

Manages interactions with service NPCs like storage, teleportation,
refining, item identification, and repair.
"""

from typing import TYPE_CHECKING

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.models import ServiceNPC, ServiceNPCDatabase
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class ServiceHandler:
    """
    Handles service NPC interactions.

    Manages:
    - Storage (Kafra storage, deposit/withdraw)
    - Teleportation (Kafra warps)
    - Save points (respawn location)
    - Equipment refining
    - Item identification
    - Equipment repair
    """

    # Service costs (base estimates)
    SERVICE_COSTS = {
        "storage": 60,
        "teleport": 600,
        "save": 0,
        "refine": 2000,
        "identify": 40,
        "repair": 500,
    }

    def __init__(self) -> None:
        """Initialize service handler."""
        self.service_db = ServiceNPCDatabase()
        logger.info("Service handler initialized")

    async def use_storage(self, game_state: "GameState") -> list[Action]:
        """
        Interact with Kafra for storage.

        Args:
            game_state: Current game state

        Returns:
            List of actions to access storage
        """
        actions: list[Action] = []

        # Find nearest Kafra
        kafra = self._find_nearest_service_npc("kafra", game_state)
        if not kafra:
            logger.warning("No Kafra NPC found nearby")
            return actions

        # Check if can afford
        if game_state.character.zeny < self.SERVICE_COSTS["storage"]:
            logger.warning("Insufficient zeny for storage service")
            return actions

        # Navigate if not near
        if not self._is_near_npc(kafra, game_state):
            actions.append(
                Action.move_to(kafra.x, kafra.y, priority=2)
            )
            return actions

        # Initiate storage interaction
        actions.append(
            Action(type=ActionType.TALK_NPC, target_id=kafra.npc_id, priority=2)
        )

        return actions

    async def use_refine(
        self, game_state: "GameState", item_index: int
    ) -> list[Action]:
        """
        Interact with refiner NPC.

        Args:
            game_state: Current game state
            item_index: Inventory index of item to refine

        Returns:
            List of actions to refine item
        """
        actions: list[Action] = []

        # Find nearest refiner
        refiner = self._find_nearest_service_npc("refiner", game_state)
        if not refiner:
            logger.warning("No refiner NPC found nearby")
            return actions

        # Check if can afford
        if game_state.character.zeny < self.SERVICE_COSTS["refine"]:
            logger.warning("Insufficient zeny for refining")
            return actions

        # Navigate if not near
        if not self._is_near_npc(refiner, game_state):
            actions.append(
                Action.move_to(refiner.x, refiner.y, priority=2)
            )
            return actions

        # Initiate refine interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=refiner.npc_id,
                priority=2,
                extra={"item_index": item_index},
            )
        )

        return actions

    async def use_teleport(
        self, game_state: "GameState", destination: str
    ) -> list[Action]:
        """
        Use Kafra teleport service.

        Args:
            game_state: Current game state
            destination: Destination map name

        Returns:
            List of actions to teleport
        """
        actions: list[Action] = []

        # Find nearest Kafra
        kafra = self._find_nearest_service_npc("kafra", game_state)
        if not kafra:
            logger.warning("No Kafra NPC found nearby")
            return actions

        # Check if can afford
        if game_state.character.zeny < self.SERVICE_COSTS["teleport"]:
            logger.warning("Insufficient zeny for teleport")
            return actions

        # Navigate if not near
        if not self._is_near_npc(kafra, game_state):
            actions.append(
                Action.move_to(kafra.x, kafra.y, priority=2)
            )
            return actions

        # Initiate teleport interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=kafra.npc_id,
                priority=2,
                extra={"teleport_destination": destination},
            )
        )

        return actions

    async def use_save_point(self, game_state: "GameState") -> list[Action]:
        """
        Save respawn point at Kafra.

        Args:
            game_state: Current game state

        Returns:
            List of actions to save
        """
        actions: list[Action] = []

        # Find nearest Kafra
        kafra = self._find_nearest_service_npc("kafra", game_state)
        if not kafra:
            logger.warning("No Kafra NPC found nearby")
            return actions

        # Navigate if not near
        if not self._is_near_npc(kafra, game_state):
            actions.append(
                Action.move_to(kafra.x, kafra.y, priority=2)
            )
            return actions

        # Initiate save interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=kafra.npc_id,
                priority=2,
                extra={"service": "save"},
            )
        )

        return actions

    def find_nearest_service(
        self, service_type: str, game_state: "GameState"
    ) -> ServiceNPC | None:
        """
        Find nearest service NPC of given type.

        Args:
            service_type: Type of service (kafra, refiner, etc.)
            game_state: Current game state

        Returns:
            Nearest service NPC or None
        """
        char_pos = game_state.character.position
        return self.service_db.find_nearest(
            service_type, game_state.map.name, char_pos.x, char_pos.y
        )

    def estimate_service_cost(self, service_type: str, **kwargs) -> int:
        """
        Estimate cost of service.

        Args:
            service_type: Type of service
            **kwargs: Additional parameters (e.g., refine level)

        Returns:
            Estimated cost in zeny
        """
        base_cost = self.SERVICE_COSTS.get(service_type, 0)

        # Special handling for refining
        if service_type == "refine":
            refine_level = kwargs.get("current_refine", 0)
            # Cost increases exponentially
            base_cost = base_cost * (2 ** (refine_level // 5))

        return base_cost

    def _find_nearest_service_npc(
        self, service_type: str, game_state: "GameState"
    ) -> ServiceNPC | None:
        """Find nearest service NPC by type and map."""
        char_pos = game_state.character.position
        return self.service_db.find_nearest(
            service_type, game_state.map.name, char_pos.x, char_pos.y
        )

    def _is_near_npc(
        self, npc: ServiceNPC, game_state: "GameState", threshold: int = 5
    ) -> bool:
        """Check if character is near NPC."""
        char_pos = game_state.character.position
        distance = ((npc.x - char_pos.x) ** 2 + (npc.y - char_pos.y) ** 2) ** 0.5
        return distance <= threshold