"""
Crafting and enchanting systems for OpenKore AI.

This package provides comprehensive crafting management including:
- Core crafting system (recipes, materials, success rates)
- Blacksmith forging (weapon creation, elements, fame)
- Alchemist brewing (potions, slim potions, genetics items)
- Equipment refinement (normal refine, HD ores, enriched ores)
- Enchanting systems (Mora, Malangdo, Temporal, Instance)
- Card system (slotting, combos, removal)
- Integrated crafting coordination

Example:
    from ai_sidecar.crafting import CraftingCoordinator
    
    coordinator = CraftingCoordinator(data_dir)
    opportunities = await coordinator.get_crafting_opportunities(
        character_state, inventory, market_prices
    )
"""

from ai_sidecar.crafting.core import (
    CraftingManager,
    CraftingRecipe,
    CraftingResult,
    CraftingType,
    Material,
)
from ai_sidecar.crafting.forging import (
    ForgeableWeapon,
    ForgeElement,
    ForgeResult,
    ForgingManager,
)
from ai_sidecar.crafting.brewing import (
    BrewableItem,
    BrewingManager,
    PotionType,
)
from ai_sidecar.crafting.refining import (
    RefineLevel,
    RefineOre,
    RefiningManager,
)
from ai_sidecar.crafting.enchanting import (
    EnchantingManager,
    EnchantOption,
    EnchantPool,
    EnchantSlot,
    EnchantType,
)
from ai_sidecar.crafting.cards import (
    Card,
    CardCombo,
    CardManager,
    CardSlotType,
)
from ai_sidecar.crafting.coordinator import CraftingCoordinator

__all__ = [
    # Core crafting system
    "CraftingManager",
    "CraftingRecipe",
    "CraftingResult",
    "CraftingType",
    "Material",
    # Forging
    "ForgeableWeapon",
    "ForgeElement",
    "ForgeResult",
    "ForgingManager",
    # Brewing
    "BrewableItem",
    "BrewingManager",
    "PotionType",
    # Refining
    "RefineLevel",
    "RefineOre",
    "RefiningManager",
    # Enchanting
    "EnchantingManager",
    "EnchantOption",
    "EnchantPool",
    "EnchantSlot",
    "EnchantType",
    # Cards
    "Card",
    "CardCombo",
    "CardManager",
    "CardSlotType",
    # Coordinator
    "CraftingCoordinator",
]