"""
Equipment Manager - Orchestrates equipment decisions.

Coordinates equipment evaluation, upgrades, card slotting,
and optimization decisions.
"""

import logging
from typing import TYPE_CHECKING, Any

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.equipment.models import Equipment, EquipSlot, InventoryItem, CardSlot
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
        
        Parses the equipment data from game_state.equipment dict which contains
        EquippedItem objects keyed by slot name (e.g., "weapon", "armor").
        Converts each to full Equipment model for valuation.
        
        Args:
            game_state: Current game state containing equipment dict
            
        Returns:
            Dict of Equipment by EquipSlot, None for empty slots
        """
        # Initialize all slots as empty
        equipped: dict[EquipSlot, Equipment | None] = {
            slot: None for slot in EquipSlot
        }
        
        # Mapping from string slot names (bridge protocol) to EquipSlot enum
        slot_name_to_enum: dict[str, EquipSlot] = {
            "head_top": EquipSlot.HEAD_TOP,
            "head_mid": EquipSlot.HEAD_MID,
            "head_low": EquipSlot.HEAD_LOW,
            "armor": EquipSlot.ARMOR,
            "weapon": EquipSlot.WEAPON,
            "shield": EquipSlot.SHIELD,
            "garment": EquipSlot.GARMENT,
            "footgear": EquipSlot.FOOTGEAR,
            "accessory1": EquipSlot.ACCESSORY1,
            "accessory2": EquipSlot.ACCESSORY2,
            "accessory_l": EquipSlot.ACCESSORY1,  # Alias
            "accessory_r": EquipSlot.ACCESSORY2,  # Alias
            "ammo": EquipSlot.AMMO,
        }
        
        # Parse equipment from game_state.equipment dict
        # game_state.equipment is dict[str, EquippedItem] from bridge protocol
        if not hasattr(game_state, 'equipment') or not game_state.equipment:
            logger.debug("_get_current_equipment: No equipment data in game state")
            return equipped
        
        logger.debug(f"_get_current_equipment: Parsing {len(game_state.equipment)} equipped slots")
        
        for slot_name, equipped_item in game_state.equipment.items():
            try:
                # Normalize slot name to lowercase for mapping
                normalized_slot = slot_name.lower().strip()
                
                # Map to EquipSlot enum
                equip_slot = slot_name_to_enum.get(normalized_slot)
                if equip_slot is None:
                    logger.warning(
                        f"_get_current_equipment: Unknown slot name '{slot_name}', skipping"
                    )
                    continue
                
                # Convert EquippedItem to Equipment model
                # EquippedItem has: item_id, name, refine_level, broken, identified
                equipment = self._convert_equipped_item_to_equipment(
                    equipped_item, equip_slot
                )
                
                if equipment:
                    equipped[equip_slot] = equipment
                    logger.debug(
                        f"_get_current_equipment: Slot {equip_slot.value} -> "
                        f"{equipment.name} (ID:{equipment.item_id}, +{equipment.refine})"
                    )
                else:
                    logger.debug(
                        f"_get_current_equipment: Slot {equip_slot.value} has empty/invalid item"
                    )
                    
            except Exception as e:
                logger.error(
                    f"_get_current_equipment: Error parsing slot '{slot_name}': {e}"
                )
                continue
        
        # Log summary of parsed equipment
        equipped_count = sum(1 for eq in equipped.values() if eq is not None)
        logger.info(
            f"_get_current_equipment: Parsed {equipped_count}/{len(EquipSlot)} equipped slots"
        )
        
        return equipped
    
    def _convert_equipped_item_to_equipment(
        self,
        equipped_item: Any,
        slot: EquipSlot,
    ) -> Equipment | None:
        """
        Convert EquippedItem (from bridge protocol) to Equipment model.
        
        EquippedItem is a simplified structure from the game state bridge
        that contains basic item info. This method creates a full Equipment
        model with default stats that can be enhanced with item database lookup.
        
        Args:
            equipped_item: EquippedItem from game_state.equipment
            slot: The equipment slot this item belongs to
            
        Returns:
            Equipment model or None if conversion fails
        """
        try:
            # Handle dict or object access
            if isinstance(equipped_item, dict):
                item_id = equipped_item.get('item_id', 0)
                name = equipped_item.get('name', '')
                refine_level = equipped_item.get('refine_level', 0)
                broken = equipped_item.get('broken', False)
                identified = equipped_item.get('identified', True)
            else:
                # Pydantic model or object with attributes
                item_id = getattr(equipped_item, 'item_id', 0)
                name = getattr(equipped_item, 'name', '')
                refine_level = getattr(equipped_item, 'refine_level', 0)
                broken = getattr(equipped_item, 'broken', False)
                identified = getattr(equipped_item, 'identified', True)
            
            # Skip invalid items (item_id 0 means empty slot)
            if not item_id or item_id <= 0:
                return None
            
            # Create Equipment model with available data
            # Note: Full stats would come from item database lookup in production
            equipment = Equipment(
                item_id=item_id,
                name=name or f"Item_{item_id}",
                slot=slot,
                refine=refine_level,
                broken=broken,
                # Default stats - would be populated from item database
                atk=self._estimate_base_atk(item_id, slot),
                defense=self._estimate_base_def(item_id, slot),
            )
            
            logger.debug(
                f"_convert_equipped_item_to_equipment: Converted {name} "
                f"(ID:{item_id}) to Equipment for slot {slot.value}"
            )
            
            return equipment
            
        except Exception as e:
            logger.error(
                f"_convert_equipped_item_to_equipment: Failed to convert item: {e}"
            )
            return None
    
    def _estimate_base_atk(self, item_id: int, slot: EquipSlot) -> int:
        """
        Estimate base ATK for an item based on ID and slot.
        
        In production, this would query an item database. For now, we use
        a simple estimation based on typical RO item ID ranges.
        
        Args:
            item_id: Item database ID
            slot: Equipment slot
            
        Returns:
            Estimated base ATK value
        """
        # Only weapons have meaningful ATK
        if slot != EquipSlot.WEAPON:
            return 0
        
        # Simple estimation based on typical RO item ID patterns
        # Weapons are typically in ID range 1100-1999 (daggers), 13000+ (newer)
        # Higher IDs generally correlate with higher level items
        if item_id < 2000:
            return 50 + (item_id % 100)  # Low-level weapons
        elif item_id < 5000:
            return 100 + (item_id % 200)  # Mid-level
        else:
            return 150 + (item_id % 300)  # High-level
    
    def _estimate_base_def(self, item_id: int, slot: EquipSlot) -> int:
        """
        Estimate base DEF for an item based on ID and slot.
        
        In production, this would query an item database.
        
        Args:
            item_id: Item database ID
            slot: Equipment slot
            
        Returns:
            Estimated base DEF value
        """
        # Non-defensive slots have no DEF
        if slot in [EquipSlot.WEAPON, EquipSlot.AMMO]:
            return 0
        
        # Armor provides most DEF
        if slot == EquipSlot.ARMOR:
            return 30 + (item_id % 50)
        # Shield second highest
        elif slot == EquipSlot.SHIELD:
            return 20 + (item_id % 30)
        # Garment and footgear moderate
        elif slot in [EquipSlot.GARMENT, EquipSlot.FOOTGEAR]:
            return 10 + (item_id % 20)
        # Headgear and accessories low DEF
        else:
            return 5 + (item_id % 10)
    
    def _get_available_equipment(
        self,
        game_state: "GameState",
    ) -> list[Equipment]:
        """
        Get equipment items available in inventory.
        
        Parses inventory for unequipped equipment items and converts them
        to Equipment models for comparison with currently equipped gear.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of unequipped equipment items
        """
        available: list[Equipment] = []
        
        # Check if inventory exists and has items
        if not hasattr(game_state, 'inventory') or not game_state.inventory:
            logger.debug("_get_available_equipment: No inventory in game state")
            return available
        
        # Handle both list and object with .items attribute
        inventory_items = []
        if hasattr(game_state.inventory, 'items'):
            inventory_items = game_state.inventory.items
        elif isinstance(game_state.inventory, list):
            inventory_items = game_state.inventory
        elif isinstance(game_state.inventory, dict):
            inventory_items = game_state.inventory.values()
        
        logger.debug(f"_get_available_equipment: Scanning {len(inventory_items)} inventory items")
        
        # Parse inventory for equipment items
        for inv_item in inventory_items:
            try:
                # Extract item properties - handle both dict and object
                if isinstance(inv_item, dict):
                    item_id = inv_item.get('item_id', 0)
                    name = inv_item.get('name', '')
                    equipped = inv_item.get('equipped', False)
                    item_type = inv_item.get('type', 0)
                    refine = inv_item.get('refine', 0)
                    index = inv_item.get('index', 0)
                else:
                    item_id = getattr(inv_item, 'item_id', 0)
                    name = getattr(inv_item, 'name', '')
                    equipped = getattr(inv_item, 'equipped', False)
                    item_type = getattr(inv_item, 'type', 0)
                    refine = getattr(inv_item, 'refine', 0)
                    index = getattr(inv_item, 'index', 0)
                
                # Skip if already equipped or not an equipment type
                # Type 3 = equipment, Type 4 = usable with equip option, Type 5 = armor
                # We include types 3, 4, 5 as potential equipment
                if equipped:
                    logger.debug(f"_get_available_equipment: Skipping {name} - already equipped")
                    continue
                
                if item_type not in [3, 4, 5]:
                    continue
                
                # Skip invalid item IDs
                if not item_id or item_id <= 0:
                    continue
                
                # Determine equipment slot from item ID ranges
                # This is based on typical Ragnarok Online item ID conventions
                equip_slot = self._determine_equip_slot_from_item_id(item_id)
                if not equip_slot:
                    logger.debug(
                        f"_get_available_equipment: Could not determine slot for item {name} (ID:{item_id})"
                    )
                    continue
                
                # Create Equipment model from inventory item
                equipment = Equipment(
                    item_id=item_id,
                    name=name or f"Item_{item_id}",
                    slot=equip_slot,
                    refine=refine,
                    # Estimate stats based on slot
                    atk=self._estimate_base_atk(item_id, equip_slot),
                    defense=self._estimate_base_def(item_id, equip_slot),
                )
                
                available.append(equipment)
                logger.debug(
                    f"_get_available_equipment: Found available equipment: "
                    f"{name} (ID:{item_id}, slot:{equip_slot.value}, +{refine})"
                )
                
            except Exception as e:
                logger.error(f"_get_available_equipment: Error processing inventory item: {e}")
                continue
        
        logger.info(f"_get_available_equipment: Found {len(available)} available equipment items")
        return available
    
    def _determine_equip_slot_from_item_id(self, item_id: int) -> EquipSlot | None:
        """
        Determine equipment slot from item ID based on RO item ID conventions.
        
        Ragnarok Online uses specific ID ranges for different equipment types:
        - 1100-1999: Daggers, Swords, etc. (Weapons)
        - 2100-2199: Shields
        - 2200-2299: Headgear (Top)
        - 2300-2399: Armor
        - 2400-2499: Footgear
        - 2500-2599: Garment
        - 2600-2699: Accessory
        - And newer high-ID ranges for expanded content
        
        Args:
            item_id: Item database ID
            
        Returns:
            EquipSlot enum value or None if cannot determine
        """
        # Weapon ranges (multiple weapon types)
        if 1100 <= item_id < 2100:
            return EquipSlot.WEAPON
        
        # Shield range
        if 2100 <= item_id < 2200:
            return EquipSlot.SHIELD
        
        # Headgear ranges (2200-2299 typically top, varies)
        if 2200 <= item_id < 2300:
            # Determine specific headgear slot by sub-range
            if item_id % 100 < 33:
                return EquipSlot.HEAD_TOP
            elif item_id % 100 < 66:
                return EquipSlot.HEAD_MID
            else:
                return EquipSlot.HEAD_LOW
        
        # Armor range
        if 2300 <= item_id < 2400:
            return EquipSlot.ARMOR
        
        # Footgear range
        if 2400 <= item_id < 2500:
            return EquipSlot.FOOTGEAR
        
        # Garment range
        if 2500 <= item_id < 2600:
            return EquipSlot.GARMENT
        
        # Accessory ranges
        if 2600 <= item_id < 2800:
            # Alternate between accessory slots
            if item_id % 2 == 0:
                return EquipSlot.ACCESSORY1
            else:
                return EquipSlot.ACCESSORY2
        
        # Ammo range
        if 13200 <= item_id < 13300:
            return EquipSlot.AMMO
        
        # High-ID weapons (renewal content)
        if 13000 <= item_id < 13200:
            return EquipSlot.WEAPON
        
        # High-ID equipment (newer servers)
        if 15000 <= item_id < 16000:
            return EquipSlot.ARMOR
        if 16000 <= item_id < 17000:
            return EquipSlot.WEAPON
        if 20000 <= item_id < 21000:
            return EquipSlot.HEAD_TOP
        
        # Cannot determine slot
        logger.debug(f"_determine_equip_slot_from_item_id: Unknown item ID range: {item_id}")
        return None
    
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
        
        This is a synchronous method that compares current equipment against
        inventory items and returns the best upgrade candidate with score details.
        
        Args:
            slot: Equipment slot name (e.g., "weapon", "armor")
            inventory: Current inventory dict containing items
            
        Returns:
            Dict with comparison results:
            - slot: Equipment slot name
            - current: Current equipment info or None
            - candidate: Best candidate equipment or None
            - score_improvement: Score difference (positive = better)
            - current_score: Score of current equipment
            - candidate_score: Score of candidate equipment
        """
        try:
            # Map slot string to EquipSlot enum
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
                logger.warning(f"find_better_equipment: Unknown slot '{slot}'")
                return None
            
            logger.debug(f"find_better_equipment: Searching for better {slot} equipment")
            
            # Extract current equipment for this slot from inventory
            current_equipment: Equipment | None = None
            candidates: list[Equipment] = []
            
            # Parse inventory items
            inventory_items = []
            if isinstance(inventory, dict):
                if 'items' in inventory:
                    inventory_items = inventory['items']
                elif 'equipped' in inventory:
                    # Has both equipped and unequipped sections
                    if inventory.get('equipped', {}).get(slot):
                        current_data = inventory['equipped'][slot]
                        current_equipment = self._dict_to_equipment(current_data, equipment_slot)
                    inventory_items = inventory.get('items', [])
                else:
                    inventory_items = list(inventory.values())
            elif isinstance(inventory, list):
                inventory_items = inventory
            
            # Find current equipment and candidates from inventory
            for item_data in inventory_items:
                try:
                    if isinstance(item_data, dict):
                        item_id = item_data.get('item_id', 0)
                        is_equipped = item_data.get('equipped', False)
                        item_slot = item_data.get('slot', '')
                    else:
                        item_id = getattr(item_data, 'item_id', 0)
                        is_equipped = getattr(item_data, 'equipped', False)
                        item_slot = getattr(item_data, 'slot', '')
                    
                    if not item_id:
                        continue
                    
                    # Check if this item is for the slot we're looking at
                    item_equip_slot = self._determine_equip_slot_from_item_id(item_id)
                    if item_equip_slot != equipment_slot:
                        continue
                    
                    # Convert to Equipment model
                    equipment = self._dict_to_equipment(item_data, equipment_slot)
                    if not equipment:
                        continue
                    
                    if is_equipped or item_slot == slot:
                        current_equipment = equipment
                        logger.debug(
                            f"find_better_equipment: Current {slot}: {equipment.name} "
                            f"(ID:{equipment.item_id})"
                        )
                    else:
                        candidates.append(equipment)
                        
                except Exception as e:
                    logger.debug(f"find_better_equipment: Error processing item: {e}")
                    continue
            
            logger.debug(f"find_better_equipment: Found {len(candidates)} candidates for {slot}")
            
            # Calculate current equipment score
            current_score = 0.0
            if current_equipment:
                current_score = self.valuation.calculate_equipment_score(
                    current_equipment,
                    self._current_build,
                )
            
            # Find best candidate
            best_candidate: Equipment | None = None
            best_score = current_score
            best_improvement = 0.0
            
            for candidate in candidates:
                candidate_score = self.valuation.calculate_equipment_score(
                    candidate,
                    self._current_build,
                )
                
                improvement = candidate_score - current_score
                
                logger.debug(
                    f"find_better_equipment: Candidate {candidate.name} "
                    f"score={candidate_score:.1f}, improvement={improvement:.1f}"
                )
                
                if candidate_score > best_score:
                    best_score = candidate_score
                    best_candidate = candidate
                    best_improvement = improvement
            
            # Build result
            result = {
                "slot": slot,
                "current": self._equipment_to_dict(current_equipment) if current_equipment else None,
                "candidate": self._equipment_to_dict(best_candidate) if best_candidate else None,
                "score_improvement": best_improvement,
                "current_score": current_score,
                "candidate_score": best_score if best_candidate else 0.0,
            }
            
            if best_candidate and best_improvement > 0:
                logger.info(
                    f"find_better_equipment: Found better {slot}: {best_candidate.name} "
                    f"(+{best_improvement:.1f} score improvement)"
                )
            else:
                logger.debug(f"find_better_equipment: No better {slot} found")
            
            return result
            
        except Exception as e:
            logger.error(f"find_better_equipment: Failed for slot '{slot}': {e}")
            return {
                "slot": slot,
                "current": None,
                "candidate": None,
                "score_improvement": 0.0,
                "error": str(e),
            }
    
    def _dict_to_equipment(self, data: dict | Any, slot: EquipSlot) -> Equipment | None:
        """
        Convert a dict or object to Equipment model.
        
        Args:
            data: Item data as dict or object
            slot: Equipment slot
            
        Returns:
            Equipment model or None
        """
        try:
            if isinstance(data, dict):
                item_id = data.get('item_id', 0)
                name = data.get('name', '')
                refine = data.get('refine', data.get('refine_level', 0))
                cards = data.get('cards', [])
                atk = data.get('atk', 0)
                defense = data.get('defense', data.get('def', 0))
            else:
                item_id = getattr(data, 'item_id', 0)
                name = getattr(data, 'name', '')
                refine = getattr(data, 'refine', getattr(data, 'refine_level', 0))
                cards = getattr(data, 'cards', [])
                atk = getattr(data, 'atk', 0)
                defense = getattr(data, 'defense', getattr(data, 'def', 0))
            
            if not item_id:
                return None
            
            # Use estimated stats if not provided
            if not atk:
                atk = self._estimate_base_atk(item_id, slot)
            if not defense:
                defense = self._estimate_base_def(item_id, slot)
            
            # Convert cards to CardSlot objects
            card_slots = self._convert_cards_to_card_slots(cards)
            
            return Equipment(
                item_id=item_id,
                name=name or f"Item_{item_id}",
                slot=slot,
                refine=refine,
                cards=card_slots,
                atk=atk,
                defense=defense,
            )
        except Exception as e:
            logger.debug(f"_dict_to_equipment: Conversion failed: {e}")
            return None
    
    def _convert_cards_to_card_slots(self, cards_data: list | None) -> list[CardSlot]:
        """
        Convert card data (IDs or dicts) to CardSlot objects.
        
        Args:
            cards_data: Raw card data from bridge or inventory
            
        Returns:
            List of CardSlot objects
        """
        if not cards_data:
            return []
        
        card_slots: list[CardSlot] = []
        for i, card in enumerate(cards_data):
            try:
                if isinstance(card, CardSlot):
                    card_slots.append(card)
                elif isinstance(card, dict):
                    card_slots.append(CardSlot(
                        slot_index=i,
                        card_id=card.get('card_id') or card.get('id'),
                        card_name=card.get('card_name') or card.get('name'),
                    ))
                elif isinstance(card, int) and card > 0:
                    card_slots.append(CardSlot(
                        slot_index=i,
                        card_id=card,
                    ))
            except Exception as e:
                logger.debug(f"_convert_cards_to_card_slots: Failed to convert card {card}: {e}")
                continue
        
        return card_slots
    
    def _equipment_to_dict(self, equipment: Equipment) -> dict:
        """
        Convert Equipment model to dict for API responses.
        
        Args:
            equipment: Equipment model
            
        Returns:
            Dict representation
        """
        return {
            "item_id": equipment.item_id,
            "name": equipment.name,
            "slot": equipment.slot.value,
            "refine": equipment.refine,
            "cards": equipment.cards,
            "atk": equipment.atk,
            "defense": equipment.defense,
        }
    
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