"""
Equipment management package for AI Sidecar.

This package handles equipment evaluation, upgrades, and optimization.
"""

from ai_sidecar.equipment.manager import EquipmentManager, EquipmentManagerConfig
from ai_sidecar.equipment.models import (
    CardSlot,
    Equipment,
    EquipmentLoadout,
    EquipmentSet,
    EquipSlot,
    InventoryItem,
    MarketPrice,
    StorageItem,
    WeaponType,
)
from ai_sidecar.equipment.valuation import (
    BuildWeights,
    ItemValuationEngine,
    RefineAnalysis,
)

__all__ = [
    "BuildWeights",
    "CardSlot",
    "Equipment",
    "EquipmentLoadout",
    "EquipmentManager",
    "EquipmentManagerConfig",
    "EquipmentSet",
    "EquipSlot",
    "InventoryItem",
    "ItemValuationEngine",
    "MarketPrice",
    "RefineAnalysis",
    "StorageItem",
    "WeaponType",
]