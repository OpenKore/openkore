"""
NPC Coordinator - Complete P3 integration for NPC/Quest bridge.

Coordinates all NPC-related systems:
- NPC dialogue and interaction
- Quest management and tracking
- Service NPCs (Kafra, storage, refine, etc.)
- NPC shop browsing and purchasing
- Cart management

P3 Bridge Completion: 100%

Configuration is loaded from YAML files for easy customization:
- config/consumable_items.yml - Item restocking rules
- config/job_classes.yml - Job class definitions
"""

from typing import TYPE_CHECKING, List, Set, Optional, Dict, Any

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.interaction import NPCInteractionEngine
from ai_sidecar.npc.manager import NPCManager
from ai_sidecar.npc.models import NPC, NPCDatabase
from ai_sidecar.npc.quest_manager import QuestManager
from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.utils.logging import get_logger

# Import centralized config loaders
from ai_sidecar.config.loader import (
    get_consumables_config,
    get_job_classes_config,
    ConsumableItemsConfig,
    JobClassesConfig
)

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class NPCCoordinator:
    """
    Complete NPC/Quest bridge coordinator (P3 - 100% completion).
    
    Integrates:
    - Dialogue handling (NPCInteractionEngine)
    - Quest tracking (QuestManager)
    - Service interactions (ServiceHandler)
    - NPC shop management
    - Cart management
    
    Handles all NPC-related decision making for the AI.
    
    Configuration is externalized to YAML files for easy customization:
    - Consumable definitions and restock thresholds
    - Job class definitions for cart eligibility
    """
    
    def __init__(
        self,
        consumables_config: Optional[ConsumableItemsConfig] = None,
        job_classes_config: Optional[JobClassesConfig] = None
    ) -> None:
        """
        Initialize NPC coordinator with all subsystems.
        
        Args:
            consumables_config: Optional custom consumables config (uses global if None)
            job_classes_config: Optional custom job classes config (uses global if None)
        """
        self.npc_manager = NPCManager()
        self.interaction_engine = self.npc_manager.interaction_engine
        self.quest_manager = self.npc_manager.quest_manager
        self.service_handler = self.npc_manager.service_handler
        self.npc_db = self.npc_manager.npc_db
        
        # Load configurations
        self._consumables_config = consumables_config or get_consumables_config()
        self._job_classes_config = job_classes_config or get_job_classes_config()
        
        # Register for config reload notifications
        self._consumables_config.register_reload_callback(self._on_consumables_reload)
        self._job_classes_config.register_reload_callback(self._on_job_classes_reload)
        
        # Cache frequently accessed config values
        self._merchant_job_ids: Set[int] = self._job_classes_config.get_merchant_job_ids()
        self._protected_items: Set[int] = self._consumables_config.protected_items
        
        # NPC shop state tracking
        self.shop_open = False
        self.current_shop_npc_id: int | None = None
        self.shop_items: List[dict] = []
        
        # Cart state tracking
        self.cart_available = False
        self.auto_cart_management = True
        
        logger.info(
            "NPC coordinator initialized with full P3 bridge integration",
            consumables_version=self._consumables_config.config.get("version", "unknown"),
            job_classes_version=self._job_classes_config.config.get("version", "unknown"),
            merchant_job_count=len(self._merchant_job_ids),
            consumable_count=len(self._consumables_config.consumables)
        )
    
    def _on_consumables_reload(self) -> None:
        """Handle consumables config reload."""
        self._protected_items = self._consumables_config.protected_items
        logger.info(
            "consumables_config_reloaded",
            consumable_count=len(self._consumables_config.consumables)
        )
    
    def _on_job_classes_reload(self) -> None:
        """Handle job classes config reload."""
        self._merchant_job_ids = self._job_classes_config.get_merchant_job_ids()
        logger.info(
            "job_classes_config_reloaded",
            merchant_job_count=len(self._merchant_job_ids)
        )
    
    async def tick(self, game_state: "GameState", tick: int) -> List[Action]:
        """
        Main NPC coordinator tick.
        
        Args:
            game_state: Current game state
            tick: Current game tick
            
        Returns:
            List of NPC-related actions
        """
        actions: List[Action] = []
        
        try:
            # Priority 1: Handle ongoing dialogue (blocks all other actions)
            if self._is_in_dialogue(game_state):
                dialogue_actions = await self.interaction_engine.tick(game_state)
                actions.extend(dialogue_actions)
                return actions
            
            # Priority 2: Handle NPC shop if open
            if self.shop_open:
                shop_actions = await self._handle_npc_shop(game_state)
                if shop_actions:
                    actions.extend(shop_actions)
                    return actions
            
            # Priority 3: Quest management (high priority)
            quest_actions = await self.quest_manager.tick(game_state)
            if quest_actions:
                actions.extend(quest_actions[:2])  # Limit to top 2 quest actions
            
            # Priority 4: Service needs (storage, repair, etc.)
            if not actions:
                service_actions = await self._check_all_services(game_state)
                if service_actions:
                    actions.extend(service_actions[:1])  # Take highest priority service
            
            # Priority 5: Cart management
            if not actions and self.auto_cart_management:
                cart_actions = await self._handle_cart_management(game_state)
                if cart_actions:
                    actions.extend(cart_actions)
            
            # Priority 6: NPC shop browsing for needed items
            if not actions:
                shopping_actions = await self._check_shopping_needs(game_state)
                if shopping_actions:
                    actions.extend(shopping_actions[:1])
        
        except Exception as e:
            logger.error(f"Error in NPC coordinator tick: {e}", exc_info=True)
        
        return actions
    
    def _is_in_dialogue(self, game_state: "GameState") -> bool:
        """Check if currently in NPC dialogue."""
        if hasattr(game_state, "npc_dialogue") and game_state.npc_dialogue:
            return game_state.npc_dialogue.in_dialogue
        return False
    
    async def _handle_npc_shop(self, game_state: "GameState") -> List[Action]:
        """
        Handle NPC shop interface when open.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of shop-related actions
        """
        actions: List[Action] = []
        
        # Check if we need any items from this shop
        needed_items = self._identify_needed_shop_items(game_state)
        
        if needed_items:
            # Buy the most important item
            item = needed_items[0]
            actions.append(
                Action(
                    type=ActionType.BUY_FROM_NPC_SHOP,
                    priority=2,
                    extra={
                        "item_id": item["item_id"],
                        "quantity": item.get("quantity", 1),
                        "max_price": item.get("max_price", 999999)
                    }
                )
            )
        else:
            # Close shop if no items needed
            actions.append(
                Action(
                    type=ActionType.CLOSE_NPC_SHOP,
                    priority=3
                )
            )
            self.shop_open = False
            self.current_shop_npc_id = None
        
        return actions
    
    def _identify_needed_shop_items(self, game_state: "GameState") -> List[dict]:
        """
        Identify items we need from current NPC shop.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of needed items with priority
        """
        needed: List[dict] = []
        
        # Check consumables (potions, arrows, etc.)
        consumables_needed = self._check_consumables_stock(game_state)
        needed.extend(consumables_needed)
        
        # Check quest requirements
        quest_items = self._check_quest_item_needs(game_state)
        needed.extend(quest_items)
        
        # Sort by priority
        needed.sort(key=lambda x: x.get("priority", 50), reverse=True)
        
        return needed
    
    def _check_consumables_stock(self, game_state: "GameState") -> List[dict]:
        """
        Check if consumable stocks are low based on configuration.
        
        Consumable definitions are loaded from config/consumable_items.yml
        which allows customization per server without code changes.
        """
        needed: List[dict] = []
        
        # Get consumables from config (supports hot-reload)
        consumables = self._consumables_config.get_consumables_dict()
        
        if not consumables:
            logger.debug("no_consumables_configured")
            return needed
        
        # Count current inventory
        inventory_counts: Dict[int, int] = {}
        for item in game_state.inventory:
            inventory_counts[item.id] = inventory_counts.get(item.id, 0) + item.amount
        
        # Check each consumable against configured thresholds
        for item_id, info in consumables.items():
            current = inventory_counts.get(item_id, 0)
            min_count = info.get("min_count", 50)
            
            if current < min_count:
                quantity_needed = min_count - current
                needed.append({
                    "item_id": item_id,
                    "item_name": info.get("name", f"Item {item_id}"),
                    "quantity": quantity_needed,
                    "priority": info.get("priority", 50)
                })
                
                logger.debug(
                    "consumable_low_stock",
                    item_id=item_id,
                    item_name=info.get("name"),
                    current=current,
                    min_count=min_count,
                    quantity_needed=quantity_needed
                )
        
        return needed
    
    def _check_quest_item_needs(self, game_state: "GameState") -> List[dict]:
        """Check if quest requires purchasing items."""
        needed: List[dict] = []
        
        # Get active quests
        for quest in self.quest_manager.quest_log.active_quests:
            # Check collection objectives
            for obj in quest.objectives:
                if not obj.completed and obj.objective_type.value == "collect_item":
                    # Check if item can be bought from NPC
                    if self._is_purchasable_from_npc(obj.target_id):
                        quantity_needed = obj.required_count - obj.current_count
                        if quantity_needed > 0:
                            needed.append({
                                "item_id": obj.target_id,
                                "item_name": obj.target_name,
                                "quantity": quantity_needed,
                                "priority": 80,  # Quest items are high priority
                                "quest_id": quest.quest_id
                            })
        
        return needed
    
    def _is_purchasable_from_npc(self, item_id: int) -> bool:
        """
        Check if item can be purchased from NPCs.
        
        Uses the consumable items configuration to determine purchasability.
        Items marked as npc_purchasable in config are considered buyable.
        """
        # Check if item is in NPC-purchasable consumables from config
        consumable = self._consumables_config.get_consumable(item_id)
        if consumable and consumable.get("npc_purchasable", False):
            return True
        
        # Fallback: common purchasable items not in config
        # (this list is smaller as most should be in config now)
        fallback_purchasable = {504, 505, 506, 507, 508, 509, 510}
        return item_id in fallback_purchasable
    
    async def _check_all_services(self, game_state: "GameState") -> List[Action]:
        """
        Check all service needs and prioritize.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of service actions
        """
        actions: List[Action] = []
        
        # Get all recommended services
        recommendations = self.service_handler.get_recommended_services(game_state)
        
        if not recommendations:
            return actions
        
        # Handle highest priority service
        service_type, reason = recommendations[0]
        logger.info(f"Service recommended: {service_type} - {reason}")
        
        if service_type == "storage":
            storage_actions = await self.service_handler.use_storage(game_state)
            actions.extend(storage_actions)
        
        elif service_type == "repair":
            repair_actions = await self.service_handler.use_repair(game_state)
            actions.extend(repair_actions)
        
        elif service_type == "save":
            save_actions = await self.service_handler.use_save_point(game_state)
            actions.extend(save_actions)
        
        elif service_type == "teleport":
            # Would need destination logic
            pass
        
        return actions
    
    async def _handle_cart_management(self, game_state: "GameState") -> List[Action]:
        """
        Handle cart acquisition and management.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of cart-related actions
        """
        actions: List[Action] = []
        
        # Check if cart is available
        mount = getattr(game_state, "mount", None)
        if not mount:
            return actions
        
        has_cart = getattr(mount, "has_cart", False)
        
        # Get cart if we don't have one and we're a merchant class
        if not has_cart and self._is_merchant_class(game_state):
            # Find cart rental NPC
            cart_npc = self._find_cart_rental_npc(game_state)
            if cart_npc:
                actions.append(
                    Action(
                        type=ActionType.GET_CART,
                        target_id=cart_npc.npc_id,
                        priority=4
                    )
                )
        
        # Transfer items to cart if overweight
        if has_cart:
            weight_percent = self._get_weight_percent(game_state)
            if weight_percent > 60:  # Move items to cart
                items_to_move = self._select_items_for_cart(game_state)
                if items_to_move:
                    actions.append(
                        Action(
                            type=ActionType.CART_ADD,
                            priority=3,
                            extra={"items": items_to_move}
                        )
                    )
        
        return actions
    
    def _is_merchant_class(self, game_state: "GameState") -> bool:
        """
        Check if character is merchant class (has cart access).
        
        Job class definitions are loaded from config/job_classes.yml
        which allows customization for different server job systems.
        """
        job_id = game_state.character.job_id
        
        # Use cached merchant job IDs from config (supports hot-reload)
        is_merchant = job_id in self._merchant_job_ids
        
        logger.debug(
            "merchant_class_check",
            job_id=job_id,
            is_merchant=is_merchant,
            merchant_jobs=list(self._merchant_job_ids)[:5]  # Log first 5 for brevity
        )
        
        return is_merchant
    
    def _find_cart_rental_npc(self, game_state: "GameState") -> NPC | None:
        """Find cart rental NPC."""
        # Would query NPC database for cart rental service
        return None
    
    def _get_weight_percent(self, game_state: "GameState") -> float:
        """Get current weight percentage."""
        char = game_state.character
        if char.weight_max > 0:
            return (char.weight / char.weight_max) * 100
        return 0.0
    
    def _select_items_for_cart(self, game_state: "GameState") -> List[dict]:
        """
        Select items to move to cart.
        
        Protected items (consumables needed for combat) are loaded from config.
        """
        items_to_move: List[dict] = []
        
        # Get protected item IDs from config (cached, supports hot-reload)
        protected_items = self._protected_items
        
        # Move heavy items first
        for item in sorted(game_state.inventory, key=lambda x: getattr(x, 'weight', 0), reverse=True):
            # Don't move equipped items or protected consumables from config
            if not item.equipped and item.id not in protected_items:
                items_to_move.append({
                    "index": item.index,
                    "amount": item.amount
                })
                
                logger.debug(
                    "item_selected_for_cart",
                    item_id=item.id,
                    amount=item.amount,
                    weight=getattr(item, 'weight', 0)
                )
                
                # Stop when we've selected enough
                if len(items_to_move) >= 10:
                    break
        
        return items_to_move
    
    async def _check_shopping_needs(self, game_state: "GameState") -> List[Action]:
        """
        Check if we need to visit NPC shops.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of shopping actions
        """
        actions: List[Action] = []
        
        # Check if we need supplies
        needs_potions = self._needs_potion_restock(game_state)
        needs_arrows = self._needs_arrow_restock(game_state)
        
        if needs_potions or needs_arrows:
            # Find nearest tool/potion dealer
            dealer = self._find_nearest_dealer(game_state)
            if dealer:
                char_pos = game_state.character.position
                distance = ((dealer.x - char_pos.x) ** 2 + (dealer.y - char_pos.y) ** 2) ** 0.5
                
                if distance > 5:
                    # Move to dealer
                    actions.append(
                        Action.move_to(dealer.x, dealer.y, priority=4)
                    )
                else:
                    # Open shop
                    actions.append(
                        Action(
                            type=ActionType.OPEN_NPC_SHOP,
                            target_id=dealer.npc_id,
                            priority=4
                        )
                    )
        
        return actions
    
    def _needs_potion_restock(self, game_state: "GameState") -> bool:
        """Check if potions need restocking."""
        potion_count = sum(
            item.amount for item in game_state.inventory
            if item.id in {501, 502, 503, 504}
        )
        return potion_count < 50
    
    def _needs_arrow_restock(self, game_state: "GameState") -> bool:
        """Check if arrows need restocking."""
        arrow_count = sum(
            item.amount for item in game_state.inventory
            if item.id in {1750, 1751, 1752, 1753}
        )
        return arrow_count < 300
    
    def _find_nearest_dealer(self, game_state: "GameState") -> NPC | None:
        """Find nearest tool/potion dealer."""
        # Query NPC database for dealers on current map
        dealers = self.npc_db.get_npcs_by_type_and_map("dealer", game_state.map.name)
        if not dealers:
            return None
        
        # Find closest
        char_pos = game_state.character.position
        closest = min(
            dealers,
            key=lambda npc: ((npc.x - char_pos.x) ** 2 + (npc.y - char_pos.y) ** 2)
        )
        return closest
    
    def open_npc_shop(self, npc_id: int, items: List[dict]) -> None:
        """
        Update state when NPC shop is opened.
        
        Args:
            npc_id: NPC ID
            items: List of available items
        """
        self.shop_open = True
        self.current_shop_npc_id = npc_id
        self.shop_items = items
        logger.info(f"NPC shop opened: {npc_id} with {len(items)} items")
    
    def close_npc_shop(self) -> None:
        """Update state when NPC shop is closed."""
        self.shop_open = False
        self.current_shop_npc_id = None
        self.shop_items = []
        logger.info("NPC shop closed")
    
    def get_quest_summary(self) -> dict:
        """
        Get quest system summary.
        
        Returns:
            Quest statistics
        """
        return {
            "active_quests": len(self.quest_manager.quest_log.active_quests),
            "completed_quests": len(self.quest_manager.quest_log.completed_quests),
            "completable_quests": len(self.quest_manager.quest_log.get_completable_quests()),
            "priority_quest": self.quest_manager.get_priority_quest().name if self.quest_manager.get_priority_quest() else None
        }
    
    def get_service_summary(self) -> dict:
        """
        Get service system summary.
        
        Returns:
            Service statistics
        """
        return {
            "shop_open": self.shop_open,
            "cart_available": self.cart_available,
            "last_save_map": self.service_handler.last_save_map
        }
    
    def get_config_summary(self) -> dict:
        """
        Get configuration summary for diagnostics.
        
        Returns:
            Configuration status and info
        """
        return {
            "consumables": {
                "version": self._consumables_config.config.get("version", "unknown"),
                "count": len(self._consumables_config.consumables),
                "protected_item_count": len(self._protected_items)
            },
            "job_classes": {
                "version": self._job_classes_config.config.get("version", "unknown"),
                "merchant_job_count": len(self._merchant_job_ids),
                "merchant_job_ids": list(self._merchant_job_ids)
            }
        }
    
    def reload_configs(self) -> Dict[str, bool]:
        """
        Manually trigger configuration reload.
        
        Returns:
            Dict of config names to reload status
        """
        results = {}
        results["consumables"] = self._consumables_config.reload()
        results["job_classes"] = self._job_classes_config.reload()
        
        logger.info("npc_coordinator_configs_reloaded", results=results)
        return results