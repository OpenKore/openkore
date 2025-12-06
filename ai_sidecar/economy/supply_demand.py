"""
Supply/Demand Modeling - Market supply and demand analysis.

Features:
- Rarity assessment
- Market liquidity analysis
- Volume estimation
- Demand prediction
- Item category integration
- Crafting recipe analysis (via CraftingAnalyzer)
"""

import statistics
from datetime import timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketManager
from ai_sidecar.economy.item_categories import ItemCategoryDatabase, CategoryType
from ai_sidecar.economy.crafting_recipes import (
    CraftingRecipeDatabase,
    CraftingType,
)
from ai_sidecar.economy.crafting_analyzer import CraftingAnalyzer
from ai_sidecar.economy.supply_demand_helpers import (
    calculate_supply_score,
    calculate_demand_score,
    calculate_liquidity,
    estimate_sale_time,
    load_drop_rates,
)

logger = structlog.get_logger(__name__)


class ItemRarity(str, Enum):
    """Item rarity levels"""
    COMMON = "common"
    UNCOMMON = "uncommon"
    RARE = "rare"
    VERY_RARE = "very_rare"
    LEGENDARY = "legendary"
    UNIQUE = "unique"


class SupplyDemandMetrics(BaseModel):
    """Supply/demand metrics for item"""
    item_id: int
    item_name: str
    supply_score: float = Field(ge=0, le=100)  # Higher = more supply
    demand_score: float = Field(ge=0, le=100)  # Higher = more demand
    scarcity_index: float  # demand/supply ratio
    market_liquidity: float = Field(ge=0, le=1)  # How quickly item sells
    listing_count: int
    avg_sale_time: timedelta
    estimated_daily_volume: int


class SupplyDemandAnalyzer:
    """
    Supply and demand modeling system.
    
    Features:
    - Rarity assessment
    - Market liquidity analysis
    - Volume estimation
    - Demand prediction
    """
    
    def __init__(self, market_manager: MarketManager, data_dir: Path):
        """
        Initialize supply/demand analyzer.
        
        Args:
            market_manager: Market data manager
            data_dir: Directory with drop rate data
        """
        self.log = logger.bind(system="supply_demand")
        self.market = market_manager
        self.data_dir = data_dir
        
        # Load drop rates using helper function
        self.drop_rates: Dict[int, float] = load_drop_rates(data_dir, self.log)
        
        # Initialize item category database
        self.category_db = ItemCategoryDatabase(data_dir)
        self.log.debug(
            "category_db_loaded",
            categories=len(self.category_db.categories)
        )
        
        # Initialize crafting recipe database
        self.recipe_db = CraftingRecipeDatabase(data_dir)
        self.log.debug(
            "recipe_db_loaded",
            recipes=len(self.recipe_db.recipes)
        )
        
        # Initialize crafting analyzer with composition
        self.crafting_analyzer = CraftingAnalyzer(
            recipe_db=self.recipe_db,
            category_db=self.category_db,
            market=self.market,
            supply_demand_calculator=self.calculate_supply_demand
        )
        
        self.log.info(
            "supply_demand_initialized",
            drop_rates=len(self.drop_rates),
            categories=len(self.category_db.categories),
            recipes=len(self.recipe_db.recipes)
        )
    
    def get_item_rarity(self, item_id: int) -> ItemRarity:
        """
        Determine item rarity.
        
        Args:
            item_id: Item ID
            
        Returns:
            Item rarity classification
        """
        # Check drop rate
        drop_rate = self.drop_rates.get(item_id, 0.0)
        
        # Check market listings
        listings = self.market.listings.get(item_id, [])
        listing_count = len(listings)
        
        # Classify by drop rate
        if drop_rate == 0.0:
            # No drop data, use market availability
            if listing_count == 0:
                return ItemRarity.UNIQUE
            elif listing_count < 3:
                return ItemRarity.LEGENDARY
            elif listing_count < 10:
                return ItemRarity.VERY_RARE
            elif listing_count < 30:
                return ItemRarity.RARE
            elif listing_count < 100:
                return ItemRarity.UNCOMMON
            else:
                return ItemRarity.COMMON
        
        # Classify by drop rate
        if drop_rate >= 0.50:
            return ItemRarity.COMMON
        elif drop_rate >= 0.20:
            return ItemRarity.UNCOMMON
        elif drop_rate >= 0.05:
            return ItemRarity.RARE
        elif drop_rate >= 0.01:
            return ItemRarity.VERY_RARE
        elif drop_rate > 0.0:
            return ItemRarity.LEGENDARY
        else:
            return ItemRarity.UNIQUE
    
    def calculate_supply_demand(self, item_id: int) -> SupplyDemandMetrics:
        """
        Calculate supply/demand metrics.
        
        Args:
            item_id: Item ID
            
        Returns:
            Supply/demand metrics
        """
        # Get market data
        listings = self.market.listings.get(item_id, [])
        history = self.market.get_price_history(item_id, days=30)
        
        # Calculate supply score using helper
        supply_score = calculate_supply_score(item_id, listings, self.drop_rates)
        
        # Calculate demand score using helper
        daily_volume = self.estimate_market_volume(item_id)
        demand_score = calculate_demand_score(daily_volume, history)
        
        # Calculate scarcity index
        scarcity_index = demand_score / supply_score if supply_score > 0 else 10.0
        
        # Calculate market liquidity using helper
        liquidity = calculate_liquidity(daily_volume, history)
        
        # Estimate sale time using helper
        avg_sale_time = estimate_sale_time(supply_score, demand_score)
        
        # Estimate daily volume
        daily_volume = self.estimate_market_volume(item_id)
        
        item_name = listings[0].item_name if listings else f"Item_{item_id}"
        
        return SupplyDemandMetrics(
            item_id=item_id,
            item_name=item_name,
            supply_score=supply_score,
            demand_score=demand_score,
            scarcity_index=scarcity_index,
            market_liquidity=liquidity,
            listing_count=len(listings),
            avg_sale_time=avg_sale_time,
            estimated_daily_volume=daily_volume
        )
    
    def estimate_market_volume(self, item_id: int) -> int:
        """
        Estimate daily market volume.
        
        Args:
            item_id: Item ID
            
        Returns:
            Estimated daily transaction volume
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history or not history.price_points:
            return 0
        
        # Sum quantities from last 30 days
        total_quantity = sum(qty for _, _, qty in history.price_points)
        days = min(30, len(history.price_points))
        
        # Average daily volume
        daily_volume = total_quantity // days if days > 0 else 0
        
        return daily_volume
    
    def predict_demand_change(
        self,
        item_id: int,
        days_ahead: int = 7
    ) -> dict:
        """
        Predict demand changes.
        
        Args:
            item_id: Item ID
            days_ahead: Days to predict ahead
            
        Returns:
            Dict with demand prediction
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history or len(history.price_points) < 7:
            return {
                "prediction": "stable",
                "confidence": 0.0,
                "factors": []
            }
        
        # Analyze recent trends
        recent_prices = [p for _, p, _ in history.price_points[-14:]]
        
        if len(recent_prices) < 2:
            return {
                "prediction": "stable",
                "confidence": 0.0,
                "factors": []
            }
        
        # Calculate trend
        first_half = recent_prices[:len(recent_prices)//2]
        second_half = recent_prices[len(recent_prices)//2:]
        
        avg_first = statistics.mean(first_half)
        avg_second = statistics.mean(second_half)
        
        change_pct = (avg_second - avg_first) / avg_first if avg_first > 0 else 0
        
        # Determine prediction
        factors = []
        
        if change_pct > 0.10:
            prediction = "increasing"
            factors.append("rising_prices")
        elif change_pct < -0.10:
            prediction = "decreasing"
            factors.append("falling_prices")
        else:
            prediction = "stable"
        
        # Check for seasonal patterns
        # (Would need event calendar integration)
        
        # Calculate confidence
        volatility = history.volatility
        confidence = max(0.0, 1.0 - volatility)
        
        return {
            "prediction": prediction,
            "confidence": confidence,
            "factors": factors,
            "change_percent": change_pct * 100
        }
    
    def get_related_items(self, item_id: int) -> List[int]:
        """
        Get items with correlated demand.
        
        Uses item categories and crafting recipes to find related items:
        1. Items in the same category (siblings)
        2. Materials needed to craft this item (if craftable)
        3. Products that can be made from this item (if it's a material)
        4. Items in upgrade paths (via category tree)
        
        Args:
            item_id: Item ID
            
        Returns:
            List of related item IDs
        """
        related: Set[int] = set()
        
        self.log.debug(
            "finding_related_items",
            item_id=item_id
        )
        
        # 1. Get items in same category (siblings)
        try:
            siblings = self.category_db.get_sibling_items(item_id)
            related.update(siblings)
            self.log.debug(
                "category_siblings_found",
                item_id=item_id,
                sibling_count=len(siblings)
            )
        except Exception as e:
            self.log.warning(
                "sibling_lookup_failed",
                item_id=item_id,
                error=str(e)
            )
        
        # 2. If this item is craftable, get the materials it needs
        if self.recipe_db.is_craftable(item_id):
            recipes = self.recipe_db.get_recipes_for_product(item_id)
            for recipe in recipes:
                material_ids = recipe.get_material_ids()
                related.update(material_ids)
                self.log.debug(
                    "crafting_materials_found",
                    item_id=item_id,
                    recipe_id=recipe.recipe_id,
                    material_count=len(material_ids)
                )
        
        # 3. If this item is a material, get products it can make
        if self.recipe_db.is_crafting_material(item_id):
            products = self.recipe_db.get_products_from_material(item_id)
            related.update(products)
            self.log.debug(
                "craftable_products_found",
                item_id=item_id,
                product_count=len(products)
            )
        
        # 4. Get items from parent category (broader related items)
        category = self.category_db.get_category(item_id)
        if category and category.parent_category:
            parent_cat = self.category_db.categories.get(category.parent_category)
            if parent_cat:
                # Get limited sample from parent to avoid too many items
                parent_items = parent_cat.get_all_item_ids()
                # Limit to first 50 items from parent
                limited_parent = set(list(parent_items)[:50])
                related.update(limited_parent)
                self.log.debug(
                    "parent_category_items_found",
                    item_id=item_id,
                    parent_category=category.parent_category,
                    item_count=len(limited_parent)
                )
        
        # Remove the input item itself
        related.discard(item_id)
        
        # Remove items with ID 0 (placeholder for refining recipes)
        related.discard(0)
        
        self.log.info(
            "related_items_found",
            item_id=item_id,
            total_related=len(related)
        )
        
        return list(related)
    
    def analyze_crafting_demand(self, product_id: int) -> Dict[str, Any]:
        """
        Analyze material demand for crafted items.
        Delegates to CraftingAnalyzer.
        
        Args:
            product_id: Crafted product ID
            
        Returns:
            Dict with material demand analysis
        """
        return self.crafting_analyzer.analyze_crafting_demand(product_id)
    
    def is_craftable(self, item_id: int) -> bool:
        """
        Check if an item can be crafted.
        Delegates to CraftingAnalyzer.
        
        Args:
            item_id: Item ID to check
            
        Returns:
            True if item has crafting recipes
        """
        return self.crafting_analyzer.is_craftable(item_id)
    
    def get_crafting_requirements(self, item_id: int) -> Optional[Dict[str, Any]]:
        """
        Get crafting requirements for an item.
        Delegates to CraftingAnalyzer.
        
        Args:
            item_id: Item ID to check
            
        Returns:
            Dict with requirements or None if not craftable
        """
        return self.crafting_analyzer.get_crafting_requirements(item_id)
    
    def estimate_crafting_value(self, item_id: int) -> Dict[str, float]:
        """
        Estimate the crafting value and potential profit for an item.
        Delegates to CraftingAnalyzer.
        
        Args:
            item_id: Item ID to analyze
            
        Returns:
            Dict with value estimates
        """
        return self.crafting_analyzer.estimate_crafting_value(item_id)
    
    def get_material_demand_impact(self, material_id: int) -> Dict[str, Any]:
        """
        Analyze how demand for products affects demand for this material.
        Delegates to CraftingAnalyzer.
        
        Args:
            material_id: Material item ID
            
        Returns:
            Dict with demand impact analysis
        """
        return self.crafting_analyzer.get_material_demand_impact(material_id)
    
    def get_item_category_info(self, item_id: int) -> Dict[str, Any]:
        """
        Get category information for an item.
        
        Args:
            item_id: Item ID
            
        Returns:
            Dict with category information
        """
        category = self.category_db.get_category(item_id)
        
        if not category:
            return {
                "item_id": item_id,
                "has_category": False,
                "category_id": None,
                "category_name": None,
                "category_type": None,
                "parent_category": None,
                "tags": []
            }
        
        return {
            "item_id": item_id,
            "has_category": True,
            "category_id": category.category_id,
            "category_name": category.name,
            "category_type": category.category_type.value,
            "parent_category": category.parent_category,
            "description": category.description,
            "tags": list(category.tags)
        }
    
    def find_profitable_crafting(
        self,
        min_profit_margin: float = 10.0,
        crafting_type: Optional[CraftingType] = None
    ) -> List[Dict[str, Any]]:
        """
        Find items that are profitable to craft.
        Delegates to CraftingAnalyzer.
        
        Args:
            min_profit_margin: Minimum profit margin percentage
            crafting_type: Optional filter by crafting type
            
        Returns:
            List of profitable crafting opportunities sorted by profit
        """
        return self.crafting_analyzer.find_profitable_crafting(
            min_profit_margin=min_profit_margin,
            crafting_type=crafting_type
        )