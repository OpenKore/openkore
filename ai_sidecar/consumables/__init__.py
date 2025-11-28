"""
Consumable Management System for OpenKore AI.

This package provides intelligent management of consumables, buffs, status effects,
recovery items, and food buffs for the Ragnarok Online bot.

Features:
- Real-time buff duration tracking and automatic rebuffing
- Priority-based status effect curing
- Intelligent recovery item usage based on HP/SP thresholds
- Food buff optimization for character builds
- Unified consumable coordination with emergency handling
"""

__all__ = [
    "BuffManager",
    "StatusEffectManager",
    "RecoveryManager",
    "FoodManager",
    "ConsumableCoordinator",
]