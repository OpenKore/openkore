"""
Market management system for OpenKore AI.

Manages market analysis, price tracking, buy/sell recommendations,
and trading bot functionality for Ragnarok Online economy.
"""

import json
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class MarketSource(str, Enum):
    """Market data sources"""
    VENDING = "vending"
    AUCTION = "auction"
    NPC_SHOP = "npc_shop"
    PLAYER_SHOP = "player_shop"


class PricePoint(BaseModel):
    """Single price observation"""
    
    model_config = ConfigDict(frozen=False)
    
    item_id: int
    price: int
    quantity: int
    timestamp: datetime = Field(default_factory=datetime.now)
    source: MarketSource
    location: str = ""


class MarketListing(BaseModel):
    """Market listing entry"""
    
    model_config = ConfigDict(frozen=False)
    
    item_id: int
    item_name: str
    quantity: int
    price_per_unit: int
    seller_name: str
    source: MarketSource
    location: str
    listed_at: datetime = Field(default_factory=datetime.now)
    
    def total_price(self) -> int:
        """Calculate total listing price"""
        return self.quantity * self.price_per_unit


class MarketManager:
    """
    Market management and trading system.
    
    Features:
    - Price tracking and analysis
    - Buy/sell recommendations
    - Profit margin calculation
    - Market trend analysis
    """
    
    def __init__(self, data_dir: Path | None = None, data_path: Path | None = None):
        """
        Initialize market manager.
        
        Args:
            data_dir: Directory containing market data
            data_path: Alias for data_dir (backwards compatibility)
        """
        self.log = logger.bind(component="market_manager")
        # Support both parameters for backwards compatibility
        final_data_dir = data_dir or data_path or Path("data/market")
        self.data_dir = Path(final_data_dir)
        
        self.price_history: Dict[int, List[PricePoint]] = {}
        self.active_listings: List[MarketListing] = []
        self._load_market_data()
    
    def _load_market_data(self) -> None:
        """Load market data from files"""
        market_file = self.data_dir / "market_data.json"
        if not market_file.exists():
            self.log.warning("market_data_missing", file=str(market_file))
            return
        
        try:
            with open(market_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load price history
            for item_id_str, history in data.get("price_history", {}).items():
                item_id = int(item_id_str)
                self.price_history[item_id] = [
                    PricePoint(**point) for point in history
                ]
            
            self.log.info("market_data_loaded", items=len(self.price_history))
        except Exception as e:
            self.log.error("market_data_load_error", error=str(e))
    
    def add_price_observation(self, item_id: int, price: int, quantity: int, source: MarketSource, location: str = "") -> None:
        """
        Add new price observation.
        
        Args:
            item_id: Item identifier
            price: Price per unit
            quantity: Quantity available
            source: Market source
            location: Location of listing
        """
        point = PricePoint(
            item_id=item_id,
            price=price,
            quantity=quantity,
            source=source,
            location=location
        )
        
        if item_id not in self.price_history:
            self.price_history[item_id] = []
        
        self.price_history[item_id].append(point)
        
        # Keep only recent history (last 100 entries)
        if len(self.price_history[item_id]) > 100:
            self.price_history[item_id].pop(0)
    
    def get_average_price(self, item_id: int, hours: int = 24) -> Optional[int]:
        """
        Get average price for item over time period.
        
        Args:
            item_id: Item identifier
            hours: Time period in hours
            
        Returns:
            Average price or None
        """
        if item_id not in self.price_history:
            return None
        
        cutoff = datetime.now().timestamp() - (hours * 3600)
        recent_prices = [
            p.price for p in self.price_history[item_id]
            if p.timestamp.timestamp() > cutoff
        ]
        
        if not recent_prices:
            return None
        
        return int(sum(recent_prices) / len(recent_prices))
    
    def get_price_trend(self, item_id: int) -> str:
        """
        Get price trend direction.
        
        Args:
            item_id: Item identifier
            
        Returns:
            Trend: "rising", "falling", or "stable"
        """
        if item_id not in self.price_history or len(self.price_history[item_id]) < 2:
            return "stable"
        
        recent = self.price_history[item_id][-10:]  # Last 10 prices
        if len(recent) < 2:
            return "stable"
        
        avg_first_half = sum(p.price for p in recent[:len(recent)//2]) / (len(recent)//2)
        avg_second_half = sum(p.price for p in recent[len(recent)//2:]) / (len(recent) - len(recent)//2)
        
        change_pct = ((avg_second_half - avg_first_half) / avg_first_half) * 100
        
        if change_pct > 5:
            return "rising"
        elif change_pct < -5:
            return "falling"
        else:
            return "stable"
    
    def calculate_profit_margin(self, item_id: int, buy_price: int, sell_price: int) -> float:
        """
        Calculate profit margin percentage.
        
        Args:
            item_id: Item identifier
            buy_price: Purchase price
            sell_price: Selling price
            
        Returns:
            Profit margin percentage
        """
        if buy_price <= 0:
            return 0.0
        
        profit = sell_price - buy_price
        margin = (profit / buy_price) * 100
        
        return margin
    
    def should_buy(self, item_id: int, current_price: int) -> Tuple[bool, str]:
        """
        Determine if item should be purchased.
        
        Args:
            item_id: Item identifier
            current_price: Current asking price
            
        Returns:
            (should_buy, reason)
        """
        avg_price = self.get_average_price(item_id)
        if avg_price is None:
            return False, "No price history"
        
        # Buy if price is significantly below average
        if current_price <= avg_price * 0.8:  # 20% below average
            return True, f"Price {current_price} is below average {avg_price}"
        
        # Check trend
        trend = self.get_price_trend(item_id)
        if trend == "falling" and current_price <= avg_price:
            return True, "Price falling, good buy opportunity"
        
        return False, "Price not favorable"
    
    def should_sell(self, item_id: int, current_price: int, buy_price: int) -> Tuple[bool, str]:
        """
        Determine if item should be sold.
        
        Args:
            item_id: Item identifier
            current_price: Current market price
            buy_price: Original purchase price
            
        Returns:
            (should_sell, reason)
        """
        margin = self.calculate_profit_margin(item_id, buy_price, current_price)
        
        # Sell if profit margin is good
        if margin >= 20:  # 20% profit
            return True, f"Good profit margin: {margin:.1f}%"
        
        # Check trend
        trend = self.get_price_trend(item_id)
        if trend == "falling" and margin > 0:
            return True, "Price falling, sell before loss"
        
        if margin < -10:  # 10% loss
            return True, "Cut losses, price declining"
        
        return False, f"Hold, current margin: {margin:.1f}%"
    
    def get_market_statistics(self) -> dict:
        """
        Get market statistics.
        
        Returns:
            Statistics dictionary
        """
        total_items = len(self.price_history)
        total_observations = sum(len(h) for h in self.price_history.values())
        
        trends = {}
        for item_id in self.price_history.keys():
            trend = self.get_price_trend(item_id)
            trends[trend] = trends.get(trend, 0) + 1
        
        return {
            "total_tracked_items": total_items,
            "total_price_observations": total_observations,
            "active_listings": len(self.active_listings),
            "trend_distribution": trends
        }