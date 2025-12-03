"""
Service NPC handler for Kafra, refiners, and other service NPCs.

Manages interactions with service NPCs like storage, teleportation,
refining, item identification, and repair.
"""

from typing import TYPE_CHECKING, Tuple

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.models import ServiceNPC, ServiceNPCDatabase
from ai_sidecar.social import config
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
        self.last_save_map: str = ""
        self.preferred_destinations: list[str] = []
        self.auto_save_on_new_map: bool = True
        self.repair_threshold: float = 0.3  # Repair when durability < 30%
        logger.info("Service handler initialized")
    
    def should_use_service(
        self,
        service_type: str,
        game_state: "GameState"
    ) -> Tuple[bool, str]:
        """
        Determine if a service should be used based on config and state.
        
        Args:
            service_type: Type of service to evaluate
            game_state: Current game state
            
        Returns:
            Tuple of (should_use, reason)
        """
        prefs = config.SERVICE_PREFERENCES
        
        # Check if service is enabled
        if not prefs.get(f"{service_type}_enabled", True):
            return False, f"{service_type} service is disabled"
        
        # Service-specific checks
        if service_type == "storage":
            return self._should_use_storage(game_state, prefs)
        elif service_type == "save":
            return self._should_save_point(game_state)
        elif service_type == "teleport":
            return self._should_teleport(game_state, prefs)
        elif service_type == "repair":
            return self._should_repair(game_state, prefs)
        elif service_type == "refine":
            return self._should_refine(game_state, prefs)
        
        return True, "Service available"
    
    def _should_use_storage(
        self,
        game_state: "GameState",
        prefs: dict
    ) -> Tuple[bool, str]:
        """Check if storage should be used."""
        # Check inventory fullness
        inventory_count = len(game_state.inventory)
        max_inventory = prefs.get("max_inventory_before_storage", 80)
        
        if inventory_count >= max_inventory:
            return True, f"Inventory full ({inventory_count} items)"
        
        # Check weight
        weight_percent = (
            game_state.character.weight / game_state.character.weight_max * 100
            if game_state.character.weight_max > 0 else 0
        )
        max_weight = prefs.get("max_weight_percent_before_storage", 70)
        
        if weight_percent >= max_weight:
            return True, f"Weight limit ({weight_percent:.0f}%)"
        
        return False, "Storage not needed"
    
    def _should_save_point(self, game_state: "GameState") -> Tuple[bool, str]:
        """Check if save point should be set."""
        current_map = game_state.map_name
        
        # Save on new map if enabled
        if self.auto_save_on_new_map and current_map != self.last_save_map:
            # Only save on town/safe maps
            if self._is_safe_map(current_map):
                return True, f"New town map: {current_map}"
        
        return False, "Save not needed"
    
    def _should_teleport(
        self,
        game_state: "GameState",
        prefs: dict
    ) -> Tuple[bool, str]:
        """Check if teleport should be used."""
        # Could check for various conditions:
        # - Need to return to town for supplies
        # - Quest objective in different map
        # - Party member requesting assistance
        
        min_zeny = prefs.get("min_zeny_for_teleport", 5000)
        if game_state.character.zeny < min_zeny:
            return False, "Insufficient zeny for teleport"
        
        return True, "Teleport available"
    
    def _should_repair(
        self,
        game_state: "GameState",
        prefs: dict
    ) -> Tuple[bool, str]:
        """Check if equipment should be repaired."""
        repair_threshold = prefs.get("repair_threshold", self.repair_threshold)
        
        # Check equipped items for durability (if available)
        for item in game_state.inventory:
            if hasattr(item, 'durability') and hasattr(item, 'max_durability'):
                if item.max_durability is not None and item.max_durability > 0:
                    durability_percent = item.durability / item.max_durability
                    if durability_percent < repair_threshold:
                        return True, f"Equipment needs repair ({durability_percent*100:.0f}%)"
        
        return False, "No repair needed"
    
    def _should_refine(
        self,
        game_state: "GameState",
        prefs: dict
    ) -> Tuple[bool, str]:
        """Check if equipment should be refined."""
        # Check if we have refinement materials and zeny
        min_zeny = prefs.get("min_zeny_for_refine", 50000)
        
        if game_state.character.zeny < min_zeny:
            return False, "Insufficient zeny for refining"
        
        # Check for refinement materials (Phracon, Emveretarcon, Oridecon, Elunium)
        material_ids = [1010, 1011, 984, 985]
        has_materials = any(
            item.id in material_ids
            for item in game_state.inventory
        )
        
        if not has_materials:
            return False, "No refinement materials"
        
        return True, "Refinement available"
    
    def _is_safe_map(self, map_name: str) -> bool:
        """Check if map is safe for saving."""
        safe_maps = config.SERVICE_PREFERENCES.get("safe_maps", [
            "prontera", "geffen", "payon", "morocc", "alberta",
            "izlude", "aldebaran", "juno", "comodo", "umbala",
            "niflheim", "louyang", "ayothaya", "einbroch",
            "lighthalzen", "rachel", "veins"
        ])
        
        return any(safe in map_name.lower() for safe in safe_maps)

    async def use_storage(self, game_state: "GameState | None" = None) -> list[Action]:
        """
        Interact with Kafra for storage.

        Args:
            game_state: Current game state (optional for tests)

        Returns:
            List of actions to access storage
        """
        actions: list[Action] = []
        
        # Test mode without game_state
        if game_state is None:
            logger.info("use_storage called without game_state (test mode)")
            return actions

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
        self, game_state: "GameState | None" = None, item_index: int = 0
    ) -> list[Action]:
        """
        Interact with refiner NPC.

        Args:
            game_state: Current game state (optional for tests)
            item_index: Inventory index of item to refine

        Returns:
            List of actions to refine item
        """
        actions: list[Action] = []
        
        # Test mode without game_state
        if game_state is None:
            logger.info("use_refine called without game_state (test mode)")
            return actions

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
        
        # Update last saved map
        self.last_save_map = game_state.map_name
        logger.info(f"Saving respawn point at {game_state.map_name}")

        return actions
    
    async def use_repair(
        self, game_state: "GameState | None" = None, item_indices: list[int] | None = None
    ) -> list[Action]:
        """
        Use repair NPC to fix equipment.
        
        Args:
            game_state: Current game state (optional for tests)
            item_indices: Specific items to repair (None for all)
            
        Returns:
            List of actions to repair
        """
        actions: list[Action] = []
        
        # Test mode without game_state
        if game_state is None:
            logger.info("use_repair called without game_state (test mode)")
            return actions
        
        # Find nearest repair NPC
        repair_npc = self._find_nearest_service_npc("repairman", game_state)
        if not repair_npc:
            logger.warning("No repair NPC found nearby")
            return actions
        
        # Check if can afford
        if game_state.character.zeny < self.SERVICE_COSTS["repair"]:
            logger.warning("Insufficient zeny for repair")
            return actions
        
        # Navigate if not near
        if not self._is_near_npc(repair_npc, game_state):
            actions.append(
                Action.move_to(repair_npc.x, repair_npc.y, priority=2)
            )
            return actions
        
        # Initiate repair interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=repair_npc.npc_id,
                priority=2,
                extra={
                    "service": "repair",
                    "item_indices": item_indices or "all"
                },
            )
        )
        
        logger.info("Initiating equipment repair")
        return actions
    
    async def use_identify(
        self, game_state: "GameState | None" = None, item_index: int = 0
    ) -> list[Action]:
        """
        Use identify service for unidentified items.
        
        Args:
            game_state: Current game state (optional for tests)
            item_index: Index of item to identify
            
        Returns:
            List of actions to identify
        """
        actions: list[Action] = []
        
        # Test mode without game_state
        if game_state is None:
            logger.info("use_identify called without game_state (test mode)")
            return actions
        
        # Find nearest identify NPC
        identify_npc = self._find_nearest_service_npc("identifier", game_state)
        if not identify_npc:
            logger.warning("No identify NPC found nearby")
            return actions
        
        # Check if can afford
        if game_state.character.zeny < self.SERVICE_COSTS["identify"]:
            logger.warning("Insufficient zeny for identification")
            return actions
        
        # Navigate if not near
        if not self._is_near_npc(identify_npc, game_state):
            actions.append(
                Action.move_to(identify_npc.x, identify_npc.y, priority=2)
            )
            return actions
        
        # Initiate identify interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=identify_npc.npc_id,
                priority=2,
                extra={
                    "service": "identify",
                    "item_index": item_index
                },
            )
        )
        
        logger.info(f"Identifying item at index {item_index}")
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
    
    def get_recommended_services(
        self, game_state: "GameState"
    ) -> list[Tuple[str, str]]:
        """
        Get list of recommended services based on current state.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of (service_type, reason) tuples
        """
        recommendations: list[Tuple[str, str]] = []
        
        service_types = ["storage", "save", "repair", "teleport"]
        
        for service in service_types:
            should_use, reason = self.should_use_service(service, game_state)
            if should_use:
                recommendations.append((service, reason))
        
        # Sort by priority (storage and repair are usually more urgent)
        priority_order = {"storage": 0, "repair": 1, "save": 2, "teleport": 3}
        recommendations.sort(key=lambda x: priority_order.get(x[0], 99))
        
        return recommendations
    
    async def use_card_remove(
        self, game_state: "GameState | None" = None, item_index: int = 0
    ) -> list[Action]:
        """
        Use card removal service.
        
        Args:
            game_state: Current game state (optional for tests)
            item_index: Index of item to remove cards from
            
        Returns:
            List of actions to remove cards
        """
        actions: list[Action] = []
        
        # Test mode without game_state
        if game_state is None:
            logger.info("use_card_remove called without game_state (test mode)")
            return actions
        
        # Find nearest card removal NPC
        card_npc = self._find_nearest_service_npc("card_remover", game_state)
        if not card_npc:
            logger.warning("No card removal NPC found nearby")
            return actions
        
        # Check if can afford (card removal is expensive)
        cost = 250000  # Base cost for card removal
        if game_state.character.zeny < cost:
            logger.warning("Insufficient zeny for card removal")
            return actions
        
        # Navigate if not near
        if not self._is_near_npc(card_npc, game_state):
            actions.append(
                Action.move_to(card_npc.x, card_npc.y, priority=2)
            )
            return actions
        
        # Initiate card removal interaction
        actions.append(
            Action(
                type=ActionType.TALK_NPC,
                target_id=card_npc.npc_id,
                priority=2,
                extra={
                    "service": "card_remove",
                    "item_index": item_index
                },
            )
        )
        
        logger.info(f"Removing cards from item at index {item_index}")
        return actions
    
    def set_preferred_destinations(self, destinations: list[str]) -> None:
        """Set preferred teleport destinations."""
        self.preferred_destinations = destinations
        logger.debug(f"Preferred destinations set: {destinations}")
    
    def get_teleport_destinations(
        self, game_state: "GameState"
    ) -> list[str]:
        """
        Get available teleport destinations from current location.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of available destination names
        """
        # Would query the Kafra for available destinations
        # For now, return common destinations
        common_destinations = [
            "Prontera", "Geffen", "Payon", "Morocc", "Alberta",
            "Izlude", "Aldebaran", "Juno", "Comodo"
        ]
        
        # Filter to preferred if set
        if self.preferred_destinations:
            return [d for d in common_destinations
                    if d.lower() in [p.lower() for p in self.preferred_destinations]]
        
        return common_destinations


# Alias for backward compatibility
NPCServiceHandler = ServiceHandler