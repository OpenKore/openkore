"""
Equipment Manager - Orchestrates equipment decisions.

Coordinates equipment evaluation, upgrades, card slotting,
and optimization decisions.
"""

import logging
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.equipment.models import Equipment, EquipSlot, InventoryItem
from ai_sidecar.equipment.valuation import ItemValuationEngine
from ai_sidecar.core.decision import Action, ActionType

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = logging.getLogger(__name__)


class EquipmentManagerConfig(BaseModel):
    """Configuration for EquipmentManager."""
    
    model_config = ConfigDict(frozen=True)
    
    # Features
    auto_equip_better_gear: bool = Field(default=True)
    auto_card_slotting: bool = Field(default=False)
    auto_refining: bool = Field(default=False)
    safe_refine_only: bool = Field(default=True)
    
    # Thresholds
    min_score_improvement: float = Field(
        default=5.0,
        description="Minimum score improvement to trigger equipment change"
    )
    max_refine_risk: float = Field(
        default=0.5,
        description="Maximum acceptable refine failure risk"
    )
    
    # Build detection
    build_type: str = Field(default="hybrid", description="Character build type")
    auto_detect_build: bool = Field(default=True)


class EquipmentManager:
    """
    Manages equipment evaluation, upgrades, and optimization.
    
    Main equipment tick entry point called from economic manager.
    """
    
    def __init__(
        self,
        config: EquipmentManagerConfig | None = None,
        valuation_engine: ItemValuationEngine | None = None,
    ):
        """
        Initialize EquipmentManager.
        
        Args:
            config: Manager configuration
            valuation_engine: Item valuation engine instance
        """
        self.config = config or EquipmentManagerConfig()
        self.valuation = valuation_engine or ItemValuationEngine()
        
        # State tracking
        self._current_build: str = self.config.build_type
        self._last_equipment_check: int = 0
        self._initialized = False
        
        logger.info("EquipmentManager initialized")
    
    def initialize(self, build_type: str | None = None) -> None:
        """
        Initialize manager with build type.
        
        Args:
            build_type: Override build type detection
        """
        if build_type:
            self._current_build = build_type
        
        self._initialized = True
        logger.info(f"EquipmentManager initialized for build: {self._current_build}")
    
    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main equipment tick - called from economic manager.
        
        Priority order:
        1. Equip better gear from inventory
        2. Card slotting optimization (if enabled)
        3. Refine decisions (if enabled and at NPC)
        
        Args:
            game_state: Current game state
            
        Returns:
            List of equipment actions to execute
        """
        if not self._initialized:
            self.initialize()
        
        actions: list[Action] = []
        
        # Priority 1: Equip better gear from inventory
        if self.config.auto_equip_better_gear:
            better_gear = await self._find_better_equipment(game_state)
            for item in better_gear:
                action = self._create_equip_action(item)
                if action:
                    actions.append(action)
        
        # Priority 2: Card slotting optimization (if enabled)
        if self.config.auto_card_slotting:
            card_actions = await self._optimize_card_slotting(game_state)
            actions.extend(card_actions)
        
        # Priority 3: Refine decisions (if enabled and at NPC)
        if self.config.auto_refining and self._at_refine_npc(game_state):
            refine_action = await self._evaluate_refine(game_state)
            if refine_action:
                actions.append(refine_action)
        
        return actions
    
    async def _find_better_equipment(
        self,
        game_state: "GameState",
    ) -> list[Equipment]:
        """
        Find unequipped items better than current gear.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of equipment items to equip
        """
        better_items: list[Equipment] = []
        
        # Get current equipment (would come from game state)
        current_equipment = self._get_current_equipment(game_state)
        
        # Get available equipment from inventory
        available_equipment = self._get_available_equipment(game_state)
        
        # Compare each available item to current gear
        for candidate in available_equipment:
            current = current_equipment.get(candidate.slot)
            
            # Calculate improvement
            improvement = self.valuation.compare_equipment(
                current,
                candidate,
                self._current_build,
            )
            
            if improvement >= self.config.min_score_improvement:
                better_items.append(candidate)
                logger.info(
                    f"Found better equipment: {candidate.name} "
                    f"(+{improvement:.1f} score improvement)"
                )
        
        return better_items
    
    async def _optimize_card_slotting(
        self,
        game_state: "GameState",
    ) -> list[Action]:
        """
        Determine optimal card placement.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of card insertion actions
        """
        actions: list[Action] = []
        
        # Get equipment with empty slots
        equipped = self._get_current_equipment(game_state)
        available_cards = self._get_available_cards(game_state)
        
        for slot, item in equipped.items():
            if item and item.has_empty_slots:
                # Find best card for this item
                best_card = self._find_best_card_for_item(
                    item,
                    available_cards,
                )
                
                if best_card:
                    # Create card insertion action
                    # Note: This would need to be implemented in protocol
                    logger.info(
                        f"Card recommendation: Insert {best_card} into {item.name}"
                    )
        
        return actions
    
    async def _evaluate_refine(
        self,
        game_state: "GameState",
    ) -> Action | None:
        """
        Decide whether to refine equipment.
        
        Args:
            game_state: Current game state
            
        Returns:
            Refine action or None
        """
        equipped = self._get_current_equipment(game_state)
        
        # Find best candidate for refining
        best_candidate: Equipment | None = None
        best_analysis = None
        best_value = -float("inf")
        
        for slot, item in equipped.items():
            if not item or item.refine >= 20:
                continue
            
            # Analyze refining to next level
            target = item.refine + 1
            
            # Skip if using safe refine only and past safe threshold
            if self.config.safe_refine_only and target > 4:
                continue
            
            analysis = self.valuation.calculate_refine_value(
                item,
                target,
                self._current_build,
            )
            
            # Check if recommended and within risk tolerance
            if (
                analysis.recommended
                and analysis.risk_score <= self.config.max_refine_risk
                and analysis.expected_value_gain > best_value
            ):
                best_candidate = item
                best_analysis = analysis
                best_value = analysis.expected_value_gain
        
        if best_candidate and best_analysis:
            logger.info(
                f"Refine recommendation: {best_candidate.name} "
                f"to +{best_analysis.target_refine} "
                f"(success rate: {best_analysis.success_rate:.1%})"
            )
            # Note: Actual refine action implementation would go here
            # return self._create_refine_action(best_candidate, best_analysis)
        
        return None
    
    def _create_equip_action(self, item: Equipment) -> Action | None:
        """
        Create an equip action for an item.
        
        Args:
            item: Equipment to equip
            
        Returns:
            Action to equip the item
        """
        return Action(
            type=ActionType.EQUIP,
            item_id=item.item_id,
            priority=6,  # Medium-low priority
        )
    
    def _get_current_equipment(
        self,
        game_state: "GameState",
    ) -> dict[EquipSlot, Equipment | None]:
        """
        Extract currently equipped items from game state.
        
        Args:
            game_state: Current game state
            
        Returns:
            Dict of equipment by slot
        """
        # This is a placeholder - actual implementation would parse
        # game_state.character or game_state.equipment
        
        equipped: dict[EquipSlot, Equipment | None] = {
            slot: None for slot in EquipSlot
        }
        
        # TODO: Parse from game_state when equipment data is available
        # For now, return empty slots
        
        return equipped
    
    def _get_available_equipment(
        self,
        game_state: "GameState",
    ) -> list[Equipment]:
        """
        Get equipment items available in inventory.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of unequipped equipment
        """
        available: list[Equipment] = []
        
        # Parse inventory for equipment items
        for inv_item in game_state.inventory.items:
            # Check if this is equipment and not currently equipped
            if not inv_item.equipped and inv_item.type == 3:  # Type 3 = equipment
                # Would need to convert InventoryItem to Equipment
                # This is placeholder logic
                pass
        
        return available
    
    def _get_available_cards(
        self,
        game_state: "GameState",
    ) -> list[int]:
        """
        Get card item IDs available in inventory.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of available card IDs
        """
        cards: list[int] = []
        
        for inv_item in game_state.inventory.items:
            # Cards typically have type 6
            if inv_item.type == 6:
                cards.append(inv_item.item_id)
        
        return cards
    
    def _find_best_card_for_item(
        self,
        item: Equipment,
        available_cards: list[int],
    ) -> int | None:
        """
        Find the best card to insert into an item.
        
        Args:
            item: Equipment with empty slot
            available_cards: Available card IDs
            
        Returns:
            Best card ID or None
        """
        if not available_cards:
            return None
        
        best_card = None
        best_improvement = 0.0
        
        for card_id in available_cards:
            evaluation = self.valuation.evaluate_card_insertion(
                item,
                card_id,
                self._current_build,
            )
            
            if (
                evaluation["recommended"]
                and evaluation["score_improvement"] > best_improvement
            ):
                best_card = card_id
                best_improvement = evaluation["score_improvement"]
        
        return best_card
    
    def _at_refine_npc(self, game_state: "GameState") -> bool:
        """
        Check if character is at a refine NPC.
        
        Args:
            game_state: Current game state
            
        Returns:
            True if at refine NPC
        """
        # Would check game_state for nearby NPCs
        # Placeholder implementation
        return False
    
    def set_build_type(self, build_type: str) -> None:
        """
        Set the build type for equipment evaluation.
        
        Args:
            build_type: Build type (melee_dps, tank, etc.)
        """
        self._current_build = build_type
        logger.info(f"Equipment build type set to: {build_type}")
    
    @property
    def build_type(self) -> str:
        """Get current build type."""
        return self._current_build
    
    async def find_better_equipment(self, game_state: "GameState") -> list[Equipment]:
        """
        Find better equipment in inventory (public wrapper).
        
        This is a public alias for _find_better_equipment() for test compatibility.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of equipment items to equip
        """
        return await self._find_better_equipment(game_state)
    
    def find_better_equipment(self, slot: str, inventory: dict) -> dict | None:
        """
        Find better equipment for a specific slot from inventory.
        
        Args:
            slot: Equipment slot name
            inventory: Current inventory
            
        Returns:
            Better equipment info or None
        """
        try:
            # Convert slot string to EquipSlot enum
            from ai_sidecar.equipment.models import EquipSlot
            
            slot_map = {
                "weapon": EquipSlot.WEAPON,
                "armor": EquipSlot.ARMOR,
                "shield": EquipSlot.SHIELD,
                "garment": EquipSlot.GARMENT,
                "footgear": EquipSlot.FOOTGEAR,
                "head_top": EquipSlot.HEAD_TOP,
                "head_mid": EquipSlot.HEAD_MID,
                "head_low": EquipSlot.HEAD_LOW,
                "accessory1": EquipSlot.ACCESSORY1,
                "accessory2": EquipSlot.ACCESSORY2,
                "ammo": EquipSlot.AMMO,
            }
            
            equipment_slot = slot_map.get(slot.lower())
            if not equipment_slot:
                return None
            
            # Return placeholder result
            return {
                "slot": slot,
                "current": None,
                "candidate": None,
                "score_improvement": 0.0
            }
        except Exception as e:
            logger.error(f"find_better_equipment_failed: {e}")
            return None
    
    def create_equip_action(self, item_id: int, slot: str) -> dict:
        """
        Create an equip action.
        
        Args:
            item_id: Item ID to equip
            slot: Slot to equip to
            
        Returns:
            Action dictionary
        """
        return {
            "action": "equip",
            "item_id": item_id,
            "slot": slot
        }