"""
Vending Optimization - Vending shop optimization system.

Features:
- Price optimization
- Location selection
- Item selection
- Timing optimization
"""

import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketManager
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.supply_demand import SupplyDemandAnalyzer

logger = structlog.get_logger(__name__)


class VendingLocation(BaseModel):
    """Vending location data"""
    map_name: str = Field(alias="map")
    x: int
    y: int
    traffic_score: float = Field(ge=0, le=100)
    competition_count: int = 0
    avg_sales_per_hour: float = 0.0
    category_preference: List[str] = Field(default_factory=list)
    
    class Config:
        populate_by_name = True  # Allow both map and map_name


class VendingItem(BaseModel):
    """Item in vending shop"""
    item_id: int
    item_name: str
    quantity: int
    price: int
    refine_level: int = 0
    cards: List[int] = Field(default_factory=list)
    expected_sale_time: timedelta = Field(default_factory=lambda: timedelta(hours=8))
    profit_margin: float = 0.0


class VendingOptimizer:
    """
    Vending shop optimization system.
    
    Features:
    - Price optimization
    - Location selection
    - Item selection
    - Timing optimization
    """
    
    def __init__(
        self,
        market_manager: MarketManager,
        price_analyzer: PriceAnalyzer,
        supply_demand: SupplyDemandAnalyzer,
        config_path: Optional[Path] = None
    ):
        """
        Initialize vending optimizer.
        
        Args:
            market_manager: Market data manager
            price_analyzer: Price analyzer
            supply_demand: Supply/demand analyzer
            config_path: Path to configuration file
        """
        self.log = logger.bind(system="vending_optimizer")
        self.market = market_manager
        self.analyzer = price_analyzer
        self.supply_demand = supply_demand
        
        # Load configuration
        self.config = self._load_config(config_path)
        
        # Load vending locations
        self.locations: List[VendingLocation] = []
        self._load_locations(config_path)
        
        self.log.info(
            "vending_optimizer_initialized",
            locations=len(self.locations)
        )
    
    def optimize_price(
        self,
        item_id: int,
        refine_level: int = 0,
        cards: List[int] = None,
        urgency: float = 0.5
    ) -> int:
        """
        Calculate optimal selling price.
        
        Args:
            item_id: Item ID
            refine_level: Refine level
            cards: Card list
            urgency: Urgency factor (0=patient, 1=quick sale)
            
        Returns:
            Optimal selling price
        """
        cards = cards or []
        
        # Get fair market price
        fair_price = self.analyzer.calculate_fair_price(
            item_id,
            refine_level,
            cards
        )
        
        if fair_price == 0:
            self.log.warning("no_price_data", item_id=item_id)
            return 0
        
        # Get market comparison
        comparison = self.analyzer.compare_to_market(item_id, fair_price)
        
        # Adjust based on urgency
        if urgency > 0.7:
            # Quick sale - price below median
            multiplier = 0.90 - (urgency - 0.7) * 0.3
        elif urgency < 0.3:
            # Patient - price above median
            multiplier = 1.10 + (0.3 - urgency) * 0.3
        else:
            # Normal - slight markup
            multiplier = 1.05
        
        # Consider supply/demand
        metrics = self.supply_demand.calculate_supply_demand(item_id)
        
        if metrics.scarcity_index > 2.0:
            # High demand, low supply - can charge more
            multiplier *= 1.10
        elif metrics.scarcity_index < 0.5:
            # Low demand, high supply - must be competitive
            multiplier *= 0.90
        
        optimal_price = int(fair_price * multiplier)
        
        self.log.debug(
            "price_optimized",
            item_id=item_id,
            fair_price=fair_price,
            optimal_price=optimal_price,
            urgency=urgency,
            multiplier=multiplier
        )
        
        return optimal_price
    
    def get_best_locations(
        self,
        item_ids: List[int],
        count: int = 5
    ) -> List[VendingLocation]:
        """
        Get best vending locations for items.
        
        Args:
            item_ids: Items to vend
            count: Number of locations to return
            
        Returns:
            List of best locations
        """
        if not self.locations:
            self.log.warning("no_locations_data")
            return []
        
        # Score each location
        location_scores: List[Tuple[VendingLocation, float]] = []
        
        for location in self.locations:
            score = self._score_location(location, item_ids)
            location_scores.append((location, score))
        
        # Sort by score
        location_scores.sort(key=lambda x: x[1], reverse=True)
        
        # Return top locations
        best = [loc for loc, score in location_scores[:count]]
        
        self.log.debug(
            "best_locations_found",
            count=len(best),
            top_score=location_scores[0][1] if location_scores else 0
        )
        
        return best
    
    def select_vending_items(
        self,
        inventory: dict,
        max_items: int = 12
    ) -> List[VendingItem]:
        """
        Select best items to vend.
        
        Args:
            inventory: Character inventory
            max_items: Maximum vending slots
            
        Returns:
            List of items to vend
        """
        candidates: List[Tuple[dict, float]] = []
        
        # Score each inventory item
        for inv_item in inventory.get("items", []):
            item_id = inv_item.get("item_id")
            
            if not item_id:
                continue
            
            # Skip equipped items
            if inv_item.get("equipped", False):
                continue
            
            # Calculate profitability score
            score = self._calculate_item_score(inv_item)
            
            if score > 0:
                candidates.append((inv_item, score))
        
        # Sort by score
        candidates.sort(key=lambda x: x[1], reverse=True)
        
        # Select top items
        vending_items: List[VendingItem] = []
        
        for inv_item, score in candidates[:max_items]:
            item_id = inv_item.get("item_id")
            quantity = inv_item.get("amount", 1)
            refine = inv_item.get("refine", 0)
            cards = inv_item.get("cards", [])
            
            # Calculate optimal price
            price = self.optimize_price(item_id, refine, cards, urgency=0.5)
            
            if price > 0:
                # Calculate profit margin
                # (Would need acquisition cost data)
                profit_margin = 0.15  # Assume 15% margin
                
                # Estimate sale time
                metrics = self.supply_demand.calculate_supply_demand(item_id)
                sale_time = metrics.avg_sale_time
                
                vending_items.append(VendingItem(
                    item_id=item_id,
                    item_name=inv_item.get("name", f"Item_{item_id}"),
                    quantity=quantity,
                    price=price,
                    refine_level=refine,
                    cards=cards,
                    expected_sale_time=sale_time,
                    profit_margin=profit_margin
                ))
        
        self.log.info(
            "vending_items_selected",
            count=len(vending_items),
            max_items=max_items
        )
        
        return vending_items
    
    def calculate_expected_revenue(
        self,
        items: List[VendingItem],
        hours: float = 8.0
    ) -> dict:
        """
        Calculate expected revenue.
        
        Args:
            items: Items in vending shop
            hours: Vending duration in hours
            
        Returns:
            Dict with revenue projections
        """
        total_value = sum(item.price * item.quantity for item in items)
        
        # Estimate sell rate based on sale times
        expected_sold_value = 0
        
        for item in items:
            # Calculate probability of selling within time period
            sale_hours = item.expected_sale_time.total_seconds() / 3600
            
            if sale_hours > 0:
                sell_probability = min(1.0, hours / sale_hours)
            else:
                sell_probability = 1.0
            
            expected_value = item.price * item.quantity * sell_probability
            expected_sold_value += expected_value
        
        # Calculate profit
        total_profit = expected_sold_value * 0.15  # Assume 15% margin
        
        return {
            "total_inventory_value": total_value,
            "expected_sold_value": int(expected_sold_value),
            "expected_profit": int(total_profit),
            "expected_sell_rate": expected_sold_value / total_value if total_value > 0 else 0,
            "vending_hours": hours,
            "zeny_per_hour": int(total_profit / hours) if hours > 0 else 0
        }
    
    def get_optimal_vending_time(self, item_ids: List[int]) -> dict:
        """
        Get optimal time to start vending.
        
        Args:
            item_ids: Items to vend
            
        Returns:
            Dict with timing recommendations
        """
        # Get peak hours from config
        peak_hours = self.config.get("peak_hours", [18, 19, 20, 21, 22])
        
        current_hour = datetime.now().hour
        
        # Determine if currently in peak hours
        is_peak = current_hour in peak_hours
        
        # Find next peak hour
        next_peak = None
        for hour in peak_hours:
            if hour > current_hour:
                next_peak = hour
                break
        
        if next_peak is None and peak_hours:
            # Next peak is tomorrow
            next_peak = peak_hours[0]
        
        return {
            "is_peak_time": is_peak,
            "current_hour": current_hour,
            "peak_hours": peak_hours,
            "next_peak_hour": next_peak,
            "recommendation": "start_now" if is_peak else "wait_for_peak"
        }
    
    def analyze_competition(self, item_id: int, location: str) -> dict:
        """
        Analyze vending competition.
        
        Args:
            item_id: Item ID
            location: Map location
            
        Returns:
            Dict with competition analysis
        """
        # Get current listings
        listings = self.market.listings.get(item_id, [])
        
        # Filter to location
        local_listings = [
            l for l in listings
            if l.location_map == location
        ]
        
        if not local_listings:
            return {
                "competition_level": "none",
                "competitor_count": 0,
                "lowest_price": 0,
                "avg_price": 0
            }
        
        prices = [l.price for l in local_listings]
        
        competition_level = "low"
        if len(local_listings) > 10:
            competition_level = "high"
        elif len(local_listings) > 5:
            competition_level = "medium"
        
        return {
            "competition_level": competition_level,
            "competitor_count": len(local_listings),
            "lowest_price": min(prices),
            "highest_price": max(prices),
            "avg_price": int(sum(prices) / len(prices))
        }
    
    def should_undercut(
        self,
        item_id: int,
        current_lowest: int,
        my_cost: int
    ) -> Tuple[bool, int]:
        """
        Determine if should undercut competition.
        
        Args:
            item_id: Item ID
            current_lowest: Current lowest market price
            my_cost: My acquisition cost
            
        Returns:
            Tuple of (should_undercut, recommended_price)
        """
        # Calculate minimum acceptable price
        undercut_amount = self.config.get("undercut_amount", 100)
        min_margin = 0.05  # Minimum 5% profit
        
        min_price = int(my_cost * (1 + min_margin))
        
        # Calculate undercut price
        undercut_price = current_lowest - undercut_amount
        
        # Only undercut if still profitable
        if undercut_price >= min_price:
            self.log.debug(
                "undercut_recommended",
                item_id=item_id,
                current_lowest=current_lowest,
                undercut_price=undercut_price,
                profit_margin=(undercut_price - my_cost) / my_cost
            )
            return (True, undercut_price)
        
        # Can't undercut profitably
        self.log.debug(
            "undercut_unprofitable",
            item_id=item_id,
            current_lowest=current_lowest,
            min_price=min_price
        )
        return (False, min_price)
    
    def _score_location(
        self,
        location: VendingLocation,
        item_ids: List[int]
    ) -> float:
        """
        Score a vending location for items.
        
        Args:
            location: Vending location
            item_ids: Items to vend
            
        Returns:
            Location score
        """
        score = location.traffic_score
        
        # Reduce score for high competition
        if location.competition_count > 20:
            score *= 0.7
        elif location.competition_count > 10:
            score *= 0.85
        
        # Boost for sales history
        if location.avg_sales_per_hour > 0:
            score *= (1 + min(0.5, location.avg_sales_per_hour / 10))
        
        return score
    
    def _calculate_item_score(self, inv_item: dict) -> float:
        """
        Calculate profitability score for item.
        
        Args:
            inv_item: Inventory item
            
        Returns:
            Profitability score
        """
        item_id = inv_item.get("item_id")
        
        if not item_id:
            return 0.0
        
        # Get market data
        current_price = self.market.get_current_price(item_id)
        
        if not current_price:
            return 0.0
        
        # Base score on price
        score = current_price["median_price"] / 1000.0
        
        # Boost for high demand items
        metrics = self.supply_demand.calculate_supply_demand(item_id)
        
        if metrics.scarcity_index > 1.5:
            score *= 1.3
        
        # Boost for high liquidity
        score *= (1 + metrics.market_liquidity)
        
        return score
    
    def _load_config(self, config_path: Optional[Path]) -> dict:
        """Load configuration from file."""
        if not config_path or not config_path.exists():
            return {
                "undercut_amount": 100,
                "price_decay_per_hour": 0.02,
                "peak_hours": [18, 19, 20, 21, 22]
            }
        
        try:
            with open(config_path, 'r') as f:
                data = json.load(f)
                return data.get("vending", {})
        except Exception as e:
            self.log.error("config_load_failed", error=str(e))
            return {}
    
    def _load_locations(self, config_path: Optional[Path]) -> None:
        """Load vending locations from file."""
        if not config_path:
            return
        
        loc_file = config_path.parent / "vending_locations.json"
        
        if not loc_file.exists():
            self.log.warning("no_locations_file", path=str(loc_file))
            return
        
        try:
            with open(loc_file, 'r') as f:
                data = json.load(f)
            
            for loc_data in data.get("locations", []):
                self.locations.append(VendingLocation(**loc_data))
            
            self.log.info("locations_loaded", count=len(self.locations))
        
        except Exception as e:
            self.log.error("locations_load_failed", error=str(e))