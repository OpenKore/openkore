"""
Supply/Demand Modeling - Market supply and demand analysis.

Features:
- Rarity assessment
- Market liquidity analysis
- Volume estimation
- Demand prediction
"""

import json
import statistics
from datetime import timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketManager

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
        
        # Load drop rates
        self.drop_rates: Dict[int, float] = {}
        self._load_drop_rates(data_dir)
        
        self.log.info("supply_demand_initialized", drop_rates=len(self.drop_rates))
    
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
        
        # Calculate supply score
        supply_score = self._calculate_supply_score(item_id, listings)
        
        # Calculate demand score
        demand_score = self._calculate_demand_score(item_id, history)
        
        # Calculate scarcity index
        scarcity_index = demand_score / supply_score if supply_score > 0 else 10.0
        
        # Calculate market liquidity
        liquidity = self._calculate_liquidity(item_id, history)
        
        # Estimate sale time
        avg_sale_time = self._estimate_sale_time(item_id, supply_score, demand_score)
        
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
        
        Args:
            item_id: Item ID
            
        Returns:
            List of related item IDs
        """
        # This would ideally use item categories and crafting recipes
        # For now, return empty list
        # TODO: Integrate with item categories and recipe data
        
        return []
    
    def analyze_crafting_demand(self, product_id: int) -> dict:
        """
        Analyze material demand for crafted items.
        
        Args:
            product_id: Crafted product ID
            
        Returns:
            Dict with material demand analysis
        """
        # This would require recipe data integration
        # For now, return basic structure
        
        return {
            "product_id": product_id,
            "materials": [],
            "profitability": 0.0,
            "material_availability": {}
        }
    
    def _calculate_supply_score(
        self,
        item_id: int,
        listings: List
    ) -> float:
        """
        Calculate supply score.
        
        Args:
            item_id: Item ID
            listings: Current market listings
            
        Returns:
            Supply score (0-100)
        """
        # Base score on number of listings
        listing_count = len(listings)
        
        # More listings = higher supply
        if listing_count == 0:
            base_score = 0.0
        elif listing_count < 5:
            base_score = 20.0
        elif listing_count < 20:
            base_score = 40.0
        elif listing_count < 50:
            base_score = 60.0
        elif listing_count < 100:
            base_score = 80.0
        else:
            base_score = 100.0
        
        # Factor in drop rate
        drop_rate = self.drop_rates.get(item_id, 0.0)
        
        if drop_rate > 0:
            # Higher drop rate = more supply
            drop_multiplier = min(1.5, 1.0 + drop_rate)
            base_score *= drop_multiplier
        
        return min(100.0, base_score)
    
    def _calculate_demand_score(
        self,
        item_id: int,
        history
    ) -> float:
        """
        Calculate demand score.
        
        Args:
            item_id: Item ID
            history: Price history
            
        Returns:
            Demand score (0-100)
        """
        if not history or not history.price_points:
            return 50.0  # Default medium demand
        
        # Base score on transaction volume
        daily_volume = self.estimate_market_volume(item_id)
        
        if daily_volume == 0:
            base_score = 20.0
        elif daily_volume < 10:
            base_score = 40.0
        elif daily_volume < 50:
            base_score = 60.0
        elif daily_volume < 200:
            base_score = 80.0
        else:
            base_score = 100.0
        
        # Factor in price trend
        if history.trend.value in ["rising", "rising_fast"]:
            base_score *= 1.2  # Rising prices indicate demand
        elif history.trend.value in ["falling", "falling_fast"]:
            base_score *= 0.8  # Falling prices indicate low demand
        
        return min(100.0, base_score)
    
    def _calculate_liquidity(
        self,
        item_id: int,
        history
    ) -> float:
        """
        Calculate market liquidity.
        
        Args:
            item_id: Item ID
            history: Price history
            
        Returns:
            Liquidity score (0-1)
        """
        if not history or not history.price_points:
            return 0.0
        
        # High liquidity = many transactions, stable prices
        
        # Factor 1: Transaction volume
        daily_volume = self.estimate_market_volume(item_id)
        volume_score = min(1.0, daily_volume / 100.0)
        
        # Factor 2: Price stability (inverse of volatility)
        stability_score = max(0.0, 1.0 - history.volatility)
        
        # Combined liquidity
        liquidity = (volume_score * 0.6) + (stability_score * 0.4)
        
        return liquidity
    
    def _estimate_sale_time(
        self,
        item_id: int,
        supply_score: float,
        demand_score: float
    ) -> timedelta:
        """
        Estimate average time to sell item.
        
        Args:
            item_id: Item ID
            supply_score: Supply score
            demand_score: Demand score
            
        Returns:
            Estimated time to sell
        """
        # High demand + low supply = fast sale
        # Low demand + high supply = slow sale
        
        if demand_score == 0:
            # No demand, assume long sale time
            return timedelta(days=30)
        
        ratio = supply_score / demand_score
        
        if ratio < 0.5:
            # High demand, low supply
            hours = 2
        elif ratio < 1.0:
            # Good demand
            hours = 12
        elif ratio < 2.0:
            # Moderate
            hours = 48
        elif ratio < 5.0:
            # Slow
            hours = 168  # 7 days
        else:
            # Very slow
            hours = 720  # 30 days
        
        return timedelta(hours=hours)
    
    def _load_drop_rates(self, data_dir: Path) -> None:
        """Load drop rate data from file."""
        drop_file = data_dir / "drop_rates.json"
        
        if not drop_file.exists():
            self.log.warning("no_drop_rates_file", path=str(drop_file))
            return
        
        try:
            with open(drop_file, 'r') as f:
                data = json.load(f)
            
            # Load normal drop rates
            for item_id_str, drop_info in data.get("drop_rates", {}).items():
                self.drop_rates[int(item_id_str)] = drop_info.get("rate", 0.0)
            
            # Load MVP drop rates
            for item_id_str, drop_info in data.get("mvp_drops", {}).items():
                self.drop_rates[int(item_id_str)] = drop_info.get("rate", 0.0)
            
            self.log.info("drop_rates_loaded", count=len(self.drop_rates))
        
        except Exception as e:
            self.log.error("drop_rates_load_failed", error=str(e))