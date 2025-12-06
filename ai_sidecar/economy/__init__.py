"""
Economic management package for AI Sidecar.

This package handles trading, storage, and economic decision-making.
Includes advanced market analysis, trading strategies, and economic intelligence.
"""

# Legacy systems
from ai_sidecar.economy.manager import EconomicManager, EconomicManagerConfig
from ai_sidecar.economy.storage import StorageManager, StorageManagerConfig
from ai_sidecar.economy.trading import (
    SellRule,
    ShoppingItem,
    TradingSystem,
    TradingSystemConfig,
)
from ai_sidecar.economy.zeny import ZenyManager, ZenyManagerConfig

# Market analysis systems (Phase 9K)
from ai_sidecar.economy.core import (
    MarketListing,
    MarketManager,
    MarketSource,
    PriceHistory,
    PriceTrend,
)
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.supply_demand import (
    ItemRarity,
    SupplyDemandAnalyzer,
    SupplyDemandMetrics,
)

# Item categories and crafting (Phase 3.2)
from ai_sidecar.economy.item_categories import (
    CategoryType,
    ItemCategory,
    ItemCategoryDatabase,
)
from ai_sidecar.economy.crafting_recipes import (
    CraftingRecipe,
    CraftingRecipeDatabase,
    CraftingType,
    JobClass,
    RecipeMaterial,
)
from ai_sidecar.economy.crafting_analyzer import CraftingAnalyzer
from ai_sidecar.economy.vending import (
    VendingItem,
    VendingLocation,
    VendingOptimizer,
)
from ai_sidecar.economy.buying import (
    BuyingManager,
    PurchasePriority,
    PurchaseTarget,
)
from ai_sidecar.economy.trading_strategy import (
    TradeOpportunity,
    TradingManager,
    TradingStrategy,
)
from ai_sidecar.economy.intelligence import (
    EconomicIntelligence,
    MarketAlert,
)
from ai_sidecar.economy.coordinator import EconomyCoordinator

__all__ = [
    # Legacy systems
    "EconomicManager",
    "EconomicManagerConfig",
    "SellRule",
    "ShoppingItem",
    "StorageManager",
    "StorageManagerConfig",
    "TradingSystem",
    "TradingSystemConfig",
    "ZenyManager",
    "ZenyManagerConfig",
    # Market core
    "MarketListing",
    "MarketManager",
    "MarketSource",
    "PriceHistory",
    "PriceTrend",
    # Analysis
    "PriceAnalyzer",
    # Supply/Demand
    "ItemRarity",
    "SupplyDemandAnalyzer",
    "SupplyDemandMetrics",
    # Item Categories (Phase 3.2)
    "CategoryType",
    "ItemCategory",
    "ItemCategoryDatabase",
    # Crafting Recipes (Phase 3.2)
    "CraftingRecipe",
    "CraftingRecipeDatabase",
    "CraftingType",
    "JobClass",
    "RecipeMaterial",
    # Crafting Analyzer (Phase 3.2)
    "CraftingAnalyzer",
    # Vending
    "VendingItem",
    "VendingLocation",
    "VendingOptimizer",
    # Buying
    "BuyingManager",
    "PurchasePriority",
    "PurchaseTarget",
    # Trading
    "TradeOpportunity",
    "TradingManager",
    "TradingStrategy",
    # Intelligence
    "EconomicIntelligence",
    "MarketAlert",
    # Coordinator
    "EconomyCoordinator",
]