"""
Equipment data models for AI Sidecar.

Defines Pydantic v2 models for equipment management including:
- Equipment items with full attributes (refine, cards, enchants)
- Equipment slots and constraints
- Inventory and storage items
- Equipment set bonuses
"""

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field, ConfigDict


class EquipSlot(str, Enum):
    """Equipment slot types in Ragnarok Online."""
    
    HEAD_TOP = "head_top"
    HEAD_MID = "head_mid"
    HEAD_LOW = "head_low"
    ARMOR = "armor"
    WEAPON = "weapon"
    SHIELD = "shield"
    GARMENT = "garment"
    FOOTGEAR = "footgear"
    ACCESSORY1 = "accessory1"
    ACCESSORY2 = "accessory2"
    AMMO = "ammo"


# Alias for backward compatibility
EquipmentSlot = EquipSlot


class EquipmentType(str, Enum):
    """Equipment type classifications."""
    
    WEAPON = "weapon"
    ARMOR = "armor"
    SHIELD = "shield"
    HEADGEAR = "headgear"
    ACCESSORY = "accessory"
    GARMENT = "garment"
    FOOTGEAR = "footgear"
    ONE_HAND_SWORD = "one_hand_sword"
    TWO_HAND_SWORD = "two_hand_sword"


class RefineLevel(str, Enum):
    """Refine level classifications."""
    PLUS_0 = "+0"
    PLUS_1 = "+1"
    PLUS_2 = "+2"
    PLUS_3 = "+3"
    PLUS_4 = "+4"
    PLUS_5 = "+5"
    PLUS_6 = "+6"
    PLUS_7 = "+7"
    PLUS_8 = "+8"
    PLUS_9 = "+9"
    PLUS_10 = "+10"
    PLUS_11 = "+11"
    PLUS_12 = "+12"
    PLUS_13 = "+13"
    PLUS_14 = "+14"
    PLUS_15 = "+15"


class WeaponType(str, Enum):
    """Weapon type classifications."""
    
    DAGGER = "dagger"
    ONE_HAND_SWORD = "one_hand_sword"
    TWO_HAND_SWORD = "two_hand_sword"
    ONE_HAND_SPEAR = "one_hand_spear"
    TWO_HAND_SPEAR = "two_hand_spear"
    ONE_HAND_AXE = "one_hand_axe"
    TWO_HAND_AXE = "two_hand_axe"
    MACE = "mace"
    STAFF = "staff"
    BOW = "bow"
    KNUCKLE = "knuckle"
    INSTRUMENT = "instrument"
    WHIP = "whip"
    BOOK = "book"
    KATAR = "katar"
    REVOLVER = "revolver"
    RIFLE = "rifle"
    GATLING = "gatling"
    SHOTGUN = "shotgun"
    GRENADE_LAUNCHER = "grenade_launcher"
    FUUMA_SHURIKEN = "fuuma_shuriken"


class CardSlot(BaseModel):
    """
    Card slot in equipment.
    
    Equipment can have 0-4 card slots depending on the item.
    Each slot can hold one card that provides additional effects.
    """
    
    model_config = ConfigDict(frozen=False)
    
    slot_index: int = Field(ge=0, le=3, description="Slot index (0-3)")
    card_id: int | None = Field(default=None, description="Inserted card ID")
    card_name: str | None = Field(default=None, description="Card name")


class Equipment(BaseModel):
    """
    Equipment item with full attributes.
    
    Represents a complete equipment piece including refine level,
    card slots, enchants, and all stat bonuses.
    """
    
    model_config = ConfigDict(frozen=False)
    
    # Identity
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    slot: EquipSlot = Field(description="Equipment slot")
    type: EquipmentType | None = Field(default=None, description="Equipment type classification")
    current_stats: dict[str, Any] = Field(default_factory=dict, description="Current stats")
    
    # Weapon-specific
    weapon_type: WeaponType | None = Field(default=None, description="Weapon type")
    
    # Enhancement
    refine: int = Field(default=0, ge=0, le=20, description="Refine level (+0 to +20)")
    cards: list[CardSlot] = Field(default_factory=list, description="Card slots")
    enchants: list[int] = Field(default_factory=list, description="Enchant IDs")
    
    # Condition
    broken: bool = Field(default=False, description="Is equipment broken")
    bound: bool = Field(default=False, description="Is account-bound")
    
    # Base stats
    atk: int = Field(default=0, ge=0, description="Base ATK")
    matk: int = Field(default=0, ge=0, description="Base MATK")
    defense: int = Field(default=0, ge=0, description="Base DEF")
    mdef: int = Field(default=0, ge=0, description="Base MDEF")
    
    # Bonus stats
    str_bonus: int = Field(default=0, description="STR bonus")
    agi_bonus: int = Field(default=0, description="AGI bonus")
    vit_bonus: int = Field(default=0, description="VIT bonus")
    int_bonus: int = Field(default=0, description="INT bonus")
    dex_bonus: int = Field(default=0, description="DEX bonus")
    luk_bonus: int = Field(default=0, description="LUK bonus")
    
    # Additional bonuses
    hp_bonus: int = Field(default=0, description="Max HP bonus")
    sp_bonus: int = Field(default=0, description="Max SP bonus")
    aspd_bonus: int = Field(default=0, description="ASPD bonus")
    crit_bonus: int = Field(default=0, description="Critical rate bonus")
    
    # Special effects
    effects: list[str] = Field(
        default_factory=list,
        description="Special effect descriptions"
    )
    set_id: int | None = Field(default=None, description="Equipment set ID")
    
    # Item properties
    weight: int = Field(default=0, ge=0, description="Item weight")
    slots: int = Field(default=0, ge=0, le=4, description="Total card slots")
    required_level: int = Field(default=1, ge=1, description="Required level to equip")
    job_restriction: list[str] = Field(
        default_factory=list,
        description="Job classes that can equip"
    )
    
    @property
    def total_atk(self) -> int:
        """Calculate total ATK including refine bonus."""
        # Weapon refine: +refine level to ATK
        if self.slot == EquipSlot.WEAPON:
            return self.atk + self.refine
        return self.atk
    
    @property
    def total_defense(self) -> int:
        """Calculate total DEF including refine bonus."""
        # Armor refine: +refine level to DEF
        if self.slot == EquipSlot.ARMOR:
            return self.defense + self.refine
        return self.defense
    
    @property
    def card_count(self) -> int:
        """Count how many cards are inserted."""
        return sum(1 for card in self.cards if card.card_id is not None)
    
    @property
    def is_fully_carded(self) -> bool:
        """Check if all card slots are filled."""
        return self.card_count >= self.slots
    
    @property
    def has_empty_slots(self) -> bool:
        """Check if there are empty card slots."""
        return self.card_count < self.slots
    
    def is_weapon(self) -> bool:
        """Check if this is a weapon."""
        return self.slot == EquipSlot.WEAPON
    
    def is_armor(self) -> bool:
        """Check if this is an armor piece."""
        return self.slot in [EquipSlot.ARMOR, EquipSlot.SHIELD, EquipSlot.GARMENT, EquipSlot.FOOTGEAR]


class EquipmentSet(BaseModel):
    """
    Equipment set bonuses.
    
    RO equipment sets provide additional bonuses when multiple
    pieces from the same set are equipped.
    """
    
    model_config = ConfigDict(frozen=True)
    
    set_id: int = Field(description="Unique set ID")
    name: str = Field(default="", description="Set name")
    pieces: list[int] = Field(default_factory=list, description="Item IDs in the set")
    
    # Bonuses based on number of pieces equipped
    # Format: {pieces_equipped: [list of bonus descriptions]}
    bonuses: dict[int, list[str]] = Field(
        default_factory=dict,
        description="Bonuses by piece count"
    )
    
    def get_active_bonuses(self, equipped_count: int) -> list[str]:
        """
        Get active bonuses for the number of pieces equipped.
        
        Args:
            equipped_count: Number of set pieces currently equipped
            
        Returns:
            List of active bonus descriptions
        """
        active = []
        for count, bonus_list in sorted(self.bonuses.items()):
            if equipped_count >= count:
                active.extend(bonus_list)
        return active


class InventoryItem(BaseModel):
    """
    Item in character inventory.
    
    Can be equipment, consumable, card, or etc item.
    """
    
    model_config = ConfigDict(frozen=False)
    
    # Identity
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    quantity: int = Field(default=1, ge=1, description="Stack quantity")
    
    # Type classification
    item_type: Literal["equipment", "consumable", "etc", "card"] = Field(
        default="etc",
        description="Item type category"
    )
    
    # Equipment data (if item_type == "equipment")
    equipment: Equipment | None = Field(
        default=None,
        description="Equipment details if this is equipment"
    )
    
    # Inventory tracking
    inventory_index: int | None = Field(
        default=None,
        description="Inventory slot index"
    )
    identified: bool = Field(default=True, description="Is item identified")
    
    @property
    def is_equipment(self) -> bool:
        """Check if this is an equipment item."""
        return self.item_type == "equipment" and self.equipment is not None
    
    @property
    def total_weight(self) -> int:
        """Calculate total weight of this stack."""
        if self.equipment:
            return self.equipment.weight * self.quantity
        return 0  # Would need item database for non-equipment


class StorageItem(BaseModel):
    """
    Item in storage (Kafra, guild, cart).
    
    Simplified version of inventory item for storage tracking.
    """
    
    model_config = ConfigDict(frozen=False)
    
    # Identity
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    quantity: int = Field(default=1, ge=1, description="Stack quantity")
    
    # Storage location
    storage_type: Literal["kafra", "guild", "cart"] = Field(
        description="Type of storage"
    )
    
    # Item type
    item_type: Literal["equipment", "consumable", "etc", "card"] = Field(
        default="etc",
        description="Item type category"
    )
    
    # Equipment reference (if applicable)
    equipment: Equipment | None = Field(
        default=None,
        description="Equipment details if this is equipment"
    )


class MarketPrice(BaseModel):
    """
    Market price information for an item.
    
    Tracks price history and statistics for market analysis.
    """
    
    model_config = ConfigDict(frozen=True)
    
    item_id: int = Field(description="Item database ID")
    
    # Price statistics
    min_price: int = Field(default=0, ge=0, description="Minimum observed price")
    avg_price: int = Field(default=0, ge=0, description="Average price")
    max_price: int = Field(default=0, ge=0, description="Maximum observed price")
    
    # NPC prices
    npc_sell_price: int = Field(default=0, ge=0, description="NPC sell price")
    npc_buy_price: int = Field(default=0, ge=0, description="NPC buy price")
    
    # Market metadata
    sample_count: int = Field(default=0, ge=0, description="Number of price samples")
    last_updated: int = Field(default=0, description="Unix timestamp of last update")
    volatility: float = Field(default=0.0, ge=0.0, description="Price volatility score")


class EquipmentLoadout(BaseModel):
    """
    Complete equipment loadout for a specific situation.
    
    Allows quick switching between different equipment sets
    (e.g., farming, PvP, MVP hunting, tanking).
    """
    
    model_config = ConfigDict(frozen=False)
    
    name: str = Field(description="Loadout name")
    description: str = Field(default="", description="Loadout description")
    
    # Equipment by slot
    head_top: Equipment | None = None
    head_mid: Equipment | None = None
    head_low: Equipment | None = None
    armor: Equipment | None = None
    weapon: Equipment | None = None
    shield: Equipment | None = None
    garment: Equipment | None = None
    footgear: Equipment | None = None
    accessory1: Equipment | None = None
    accessory2: Equipment | None = None
    ammo: Equipment | None = None
    
    # Metadata
    optimized_for: str = Field(
        default="general",
        description="What this loadout is optimized for"
    )
    priority: int = Field(default=5, ge=1, le=10, description="Loadout priority")
    
    def get_equipment_by_slot(self, slot: EquipSlot) -> Equipment | None:
        """Get equipment for a specific slot."""
        slot_map = {
            EquipSlot.HEAD_TOP: self.head_top,
            EquipSlot.HEAD_MID: self.head_mid,
            EquipSlot.HEAD_LOW: self.head_low,
            EquipSlot.ARMOR: self.armor,
            EquipSlot.WEAPON: self.weapon,
            EquipSlot.SHIELD: self.shield,
            EquipSlot.GARMENT: self.garment,
            EquipSlot.FOOTGEAR: self.footgear,
            EquipSlot.ACCESSORY1: self.accessory1,
            EquipSlot.ACCESSORY2: self.accessory2,
            EquipSlot.AMMO: self.ammo,
        }
        return slot_map.get(slot)
    
    def set_equipment(self, slot: EquipSlot, equipment: Equipment | None) -> None:
        """Set equipment for a specific slot."""
        slot_attr = {
            EquipSlot.HEAD_TOP: "head_top",
            EquipSlot.HEAD_MID: "head_mid",
            EquipSlot.HEAD_LOW: "head_low",
            EquipSlot.ARMOR: "armor",
            EquipSlot.WEAPON: "weapon",
            EquipSlot.SHIELD: "shield",
            EquipSlot.GARMENT: "garment",
            EquipSlot.FOOTGEAR: "footgear",
            EquipSlot.ACCESSORY1: "accessory1",
            EquipSlot.ACCESSORY2: "accessory2",
            EquipSlot.AMMO: "ammo",
        }
        if slot in slot_attr:
            setattr(self, slot_attr[slot], equipment)
    
    @property
    def total_atk(self) -> int:
        """Calculate total ATK from all equipment."""
        total = 0
        for slot in EquipSlot:
            equip = self.get_equipment_by_slot(slot)
            if equip:
                total += equip.total_atk
        return total
    
    @property
    def total_defense(self) -> int:
        """Calculate total DEF from all equipment."""
        total = 0
        for slot in EquipSlot:
            equip = self.get_equipment_by_slot(slot)
            if equip:
                total += equip.total_defense
        return total
    
    @property
    def equipped_set_pieces(self) -> dict[int, int]:
        """
        Count equipped pieces per equipment set.
        
        Returns:
            Dict of set_id -> count of equipped pieces
        """
        set_counts: dict[int, int] = {}
        
        for slot in EquipSlot:
            equip = self.get_equipment_by_slot(slot)
            if equip and equip.set_id is not None:
                set_counts[equip.set_id] = set_counts.get(equip.set_id, 0) + 1
        
        return set_counts


# RO refine success rates by refine level and item type
REFINE_SUCCESS_RATES = {
    "weapon": {
        1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0,  # Safe refines
        5: 0.75, 6: 0.75, 7: 0.75,
        8: 0.50, 9: 0.30, 10: 0.20,
        11: 0.15, 12: 0.10, 13: 0.08, 14: 0.06, 15: 0.04,
        16: 0.03, 17: 0.02, 18: 0.015, 19: 0.01, 20: 0.005,
    },
    "armor": {
        1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0,  # Safe refines
        5: 1.0, 6: 1.0, 7: 1.0,
        8: 0.75, 9: 0.50, 10: 0.30,
        11: 0.20, 12: 0.15, 13: 0.10, 14: 0.08, 15: 0.06,
        16: 0.04, 17: 0.03, 18: 0.02, 19: 0.015, 20: 0.01,
    },
}


def get_refine_success_rate(
    item_slot: EquipSlot,
    current_refine: int,
    target_refine: int,
) -> float:
    """
    Calculate refine success rate.
    
    Args:
        item_slot: Equipment slot (determines weapon vs armor rates)
        current_refine: Current refine level
        target_refine: Target refine level
        
    Returns:
        Success probability (0.0-1.0)
    """
    if target_refine <= current_refine:
        return 1.0
    
    # Determine if weapon or armor
    is_weapon = item_slot == EquipSlot.WEAPON
    rates = REFINE_SUCCESS_RATES["weapon" if is_weapon else "armor"]
    
    # Calculate cumulative probability for multi-level refine
    cumulative_prob = 1.0
    for level in range(current_refine + 1, target_refine + 1):
        cumulative_prob *= rates.get(level, 0.0)
    
    return cumulative_prob


def calculate_refine_cost(
    current_refine: int,
    target_refine: int,
    base_cost: int = 2000,
) -> int:
    """
    Calculate zeny cost for refining.
    
    Args:
        current_refine: Current refine level
        target_refine: Target refine level
        base_cost: Base cost per refine attempt
        
    Returns:
        Total estimated cost in zeny
    """
    if target_refine <= current_refine:
        return 0
    
    total_cost = 0
    for level in range(current_refine + 1, target_refine + 1):
        # Cost increases exponentially
        level_cost = base_cost * (2 ** (level // 5))
        total_cost += level_cost
    
    return total_cost