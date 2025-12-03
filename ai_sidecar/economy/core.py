"""
Market Core System - Core market data management.

Handles:
- Market listing collection and storage
- Price history tracking
- Market statistics
- Data persistence
"""

import json
import statistics
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

logger = structlog.get_logger(__name__)


class MarketSource(str, Enum):
    """Sources of market data"""
    VENDING = "vending"           # Player vending shops
    BUYING = "buying"             # Buying stores
    NPC = "npc"                   # Generic NPC
    NPC_BUY = "npc_buy"           # NPC buy prices
    NPC_SELL = "npc_sell"         # NPC sell prices
    AUCTION = "auction"           # Auction house
    TRADE = "trade"               # Direct trades


class PriceTrend(str, Enum):
    """Price trend indicators"""
    RISING_FAST = "rising_fast"
    RISING = "rising"
    STABLE = "stable"
    FALLING = "falling"
    FALLING_FAST = "falling_fast"
    VOLATILE = "volatile"


class PricePoint(BaseModel):
    """Single price data point for historical tracking."""
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    price: int = Field(ge=0)
    quantity: int = Field(default=1, ge=1)
    source: MarketSource
    
    
class MarketListing(BaseModel):
    """Single market listing"""
    item_id: int
    item_name: str
    price: Optional[int] = None
    price_per_unit: Optional[int] = None
    quantity: int
    refine_level: int = 0
    cards: List[int] = Field(default_factory=list)
    source: MarketSource
    seller_name: Optional[str] = None
    location: Optional[str] = None
    location_map: Optional[str] = None
    location_x: Optional[int] = None
    location_y: Optional[int] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    
    def __init__(self, **data):
        """Initialize market listing with flexible pricing."""
        # If price_per_unit is provided but not price, calculate it
        if 'price_per_unit' in data and 'price' not in data:
            data['price'] = data['price_per_unit'] * data.get('quantity', 1)
        # If price is provided but not price_per_unit, calculate it
        elif 'price' in data and 'price_per_unit' not in data:
            data['price_per_unit'] = data['price'] // data.get('quantity', 1) if data.get('quantity', 1) > 0 else data['price']
        super().__init__(**data)
    
    def total_price(self) -> int:
        """Calculate total price for this listing."""
        if self.price:
            return self.price
        if self.price_per_unit:
            return self.price_per_unit * self.quantity
        return 0


class PriceHistory(BaseModel):
    """Price history for an item"""
    item_id: int
    item_name: str
    price_points: List[Tuple[datetime, int, int]] = Field(
        default_factory=list
    )  # (time, price, quantity)
    min_price: int = 0
    max_price: int = 0
    avg_price: float = 0.0
    median_price: int = 0
    std_deviation: float = 0.0
    trend: PriceTrend = PriceTrend.STABLE
    volatility: float = 0.0  # 0-1 scale


class MarketManager:
    """
    Core market data management system.
    
    Features:
    - Price data collection
    - Historical tracking
    - Market statistics
    - Data persistence
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize market manager.
        
        Args:
            data_dir: Directory for market data storage
        """
        self.log = logger.bind(system="market_manager")
        self.data_dir = data_dir
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
        # Active listings by item_id
        self.listings: Dict[int, List[MarketListing]] = {}
        
        # Price history by item_id
        self.price_history: Dict[int, PriceHistory] = {}
        
        # Load persisted data
        self._load_market_data()
        
        self.log.info("market_manager_initialized", data_dir=str(data_dir))
    
    def record_listing(self, listing: MarketListing) -> None:
        """
        Record a new market listing.
        
        Args:
            listing: Market listing to record
        """
        item_id = listing.item_id
        
        # Add to active listings
        if item_id not in self.listings:
            self.listings[item_id] = []
        
        self.listings[item_id].append(listing)
        
        # Update price history
        self._update_price_history(listing)
        
        self.log.debug(
            "listing_recorded",
            item_id=item_id,
            item_name=listing.item_name,
            price=listing.price,
            source=listing.source.value
        )
    
    def add_listing(self, listing: MarketListing) -> None:
        """Convenience alias for record_listing()."""
        self.record_listing(listing)
    
    def remove_listing(self, listing: MarketListing) -> None:
        """Remove a listing from the market."""
        item_id = listing.item_id
        if item_id in self.listings:
            self.listings[item_id] = [
                l for l in self.listings[item_id]
                if not (l.price == listing.price and l.seller_name == listing.seller_name)
            ]
            if not self.listings[item_id]:
                del self.listings[item_id]
    
    def get_best_price(self, item_id: int) -> Optional[int]:
        """Get lowest price for item."""
        if item_id not in self.listings or not self.listings[item_id]:
            return None
        return min(l.price for l in self.listings[item_id])
    
    def get_average_price(self, item_id: int) -> Optional[float]:
        """Get average price for item."""
        if item_id not in self.listings or not self.listings[item_id]:
            return None
        prices = [l.price for l in self.listings[item_id]]
        return statistics.mean(prices)
    
    def get_listings(self, item_id: int) -> List[MarketListing]:
        """Get all listings for item."""
        return self.listings.get(item_id, [])
    
    def get_sellers_count(self, item_id: int) -> int:
        """Get number of unique sellers for item."""
        if item_id not in self.listings:
            return 0
        sellers = set(l.seller_name for l in self.listings[item_id] if l.seller_name)
        return len(sellers)
    
    def clear_old_listings(self, max_age_hours: int = 24) -> int:
        """Clear listings older than max_age_hours."""
        cutoff = datetime.utcnow() - timedelta(hours=max_age_hours)
        removed = 0
        
        for item_id in list(self.listings.keys()):
            old_count = len(self.listings[item_id])
            self.listings[item_id] = [
                l for l in self.listings[item_id]
                if l.timestamp >= cutoff
            ]
            removed += old_count - len(self.listings[item_id])
            
            if not self.listings[item_id]:
                del self.listings[item_id]
        
        return removed
    
    def get_current_price(
        self,
        item_id: int,
        include_cards: bool = False
    ) -> Optional[dict]:
        """
        Get current market price for item.
        
        Args:
            item_id: Item ID to query
            include_cards: Include carded items in analysis
            
        Returns:
            Dict with price statistics or None
        """
        if item_id not in self.listings:
            return None
        
        listings = self.listings[item_id]
        
        # Filter out carded items if requested
        if not include_cards:
            listings = [l for l in listings if not l.cards]
        
        if not listings:
            return None
        
        prices = [l.price for l in listings]
        
        return {
            "min_price": min(prices),
            "max_price": max(prices),
            "avg_price": statistics.mean(prices),
            "median_price": int(statistics.median(prices)),
            "listing_count": len(listings),
            "total_quantity": sum(l.quantity for l in listings)
        }
    
    def get_price_history(
        self,
        item_id: int,
        days: int = 7
    ) -> Optional[PriceHistory]:
        """
        Get price history for item.
        
        Args:
            item_id: Item ID to query
            days: Days of history to include
            
        Returns:
            PriceHistory object or None
        """
        if item_id not in self.price_history:
            return None
        
        history = self.price_history[item_id]
        
        # Filter to requested time period
        cutoff = datetime.utcnow() - timedelta(days=days)
        filtered_points = [
            (ts, price, qty)
            for ts, price, qty in history.price_points
            if ts >= cutoff
        ]
        
        if not filtered_points:
            return None
        
        # Recalculate statistics for filtered period
        prices = [price for _, price, _ in filtered_points]
        
        history_copy = history.model_copy(deep=True)
        history_copy.price_points = filtered_points
        history_copy.min_price = min(prices)
        history_copy.max_price = max(prices)
        history_copy.avg_price = statistics.mean(prices)
        history_copy.median_price = int(statistics.median(prices))
        
        if len(prices) > 1:
            history_copy.std_deviation = statistics.stdev(prices)
        
        return history_copy
    
    def get_trend(self, item_id: int) -> PriceTrend:
        """
        Get price trend for item.
        
        Args:
            item_id: Item ID to query
            
        Returns:
            Price trend indicator
        """
        history = self.get_price_history(item_id, days=7)
        
        if not history or len(history.price_points) < 3:
            return PriceTrend.STABLE
        
        return history.trend
    
    def get_market_stats(self) -> dict:
        """
        Get overall market statistics.
        
        Returns:
            Dict with market statistics
        """
        total_listings = sum(len(lst) for lst in self.listings.values())
        unique_items = len(self.listings)
        
        # Calculate average prices across all items
        all_prices = [
            listing.price
            for listings in self.listings.values()
            for listing in listings
        ]
        
        return {
            "total_listings": total_listings,
            "unique_items": unique_items,
            "avg_price": statistics.mean(all_prices) if all_prices else 0,
            "tracked_items": len(self.price_history),
            "sources": self._get_source_stats()
        }
    
    def cleanup_old_data(self, days: int = 30) -> int:
        """
        Remove data older than specified days.
        
        Args:
            days: Age threshold in days
            
        Returns:
            Number of entries removed
        """
        cutoff = datetime.utcnow() - timedelta(days=days)
        removed_count = 0
        
        # Clean old listings
        for item_id in list(self.listings.keys()):
            old_listings = [
                l for l in self.listings[item_id]
                if l.timestamp < cutoff
            ]
            removed_count += len(old_listings)
            
            self.listings[item_id] = [
                l for l in self.listings[item_id]
                if l.timestamp >= cutoff
            ]
            
            # Remove empty entries
            if not self.listings[item_id]:
                del self.listings[item_id]
        
        # Clean old price history
        for item_id in list(self.price_history.keys()):
            history = self.price_history[item_id]
            old_points = [
                (ts, price, qty)
                for ts, price, qty in history.price_points
                if ts < cutoff
            ]
            removed_count += len(old_points)
            
            history.price_points = [
                (ts, price, qty)
                for ts, price, qty in history.price_points
                if ts >= cutoff
            ]
            
            # Remove if no data left
            if not history.price_points:
                del self.price_history[item_id]
        
        self.log.info("old_data_cleaned", removed_count=removed_count, days=days)
        
        # Persist cleaned data
        self._save_market_data()
        
        return removed_count
    
    def _update_price_history(self, listing: MarketListing) -> None:
        """
        Update price history with new listing.
        
        Args:
            listing: New market listing
        """
        item_id = listing.item_id
        
        if item_id not in self.price_history:
            self.price_history[item_id] = PriceHistory(
                item_id=item_id,
                item_name=listing.item_name
            )
        
        history = self.price_history[item_id]
        
        # Add price point
        history.price_points.append((
            listing.timestamp,
            listing.price,
            listing.quantity
        ))
        
        # Recalculate statistics
        prices = [price for _, price, _ in history.price_points]
        
        history.min_price = min(prices)
        history.max_price = max(prices)
        history.avg_price = statistics.mean(prices)
        history.median_price = int(statistics.median(prices))
        
        if len(prices) > 1:
            history.std_deviation = statistics.stdev(prices)
            history.volatility = history.std_deviation / history.avg_price if history.avg_price > 0 else 0
        
        # Update trend
        history.trend = self._calculate_trend(history.price_points)
    
    def _calculate_trend(
        self,
        price_points: List[Tuple[datetime, int, int]]
    ) -> PriceTrend:
        """
        Calculate price trend from historical data.
        
        Args:
            price_points: List of (timestamp, price, quantity) tuples
            
        Returns:
            Calculated price trend
        """
        if len(price_points) < 3:
            return PriceTrend.STABLE
        
        # Take recent points (last 7 days)
        recent_cutoff = datetime.utcnow() - timedelta(days=7)
        recent_points = [
            (ts, price, qty)
            for ts, price, qty in price_points
            if ts >= recent_cutoff
        ]
        
        if len(recent_points) < 3:
            return PriceTrend.STABLE
        
        prices = [price for _, price, _ in recent_points]
        
        # Calculate simple linear trend
        first_third = prices[:len(prices)//3]
        last_third = prices[-len(prices)//3:]
        
        if not first_third or not last_third:
            return PriceTrend.STABLE
        
        avg_first = statistics.mean(first_third)
        avg_last = statistics.mean(last_third)
        
        change_pct = (avg_last - avg_first) / avg_first if avg_first > 0 else 0
        
        # Determine trend FIRST - prioritize directional trends
        if change_pct > 0.15:
            return PriceTrend.RISING_FAST
        elif change_pct > 0.05:
            return PriceTrend.RISING
        elif change_pct < -0.15:
            return PriceTrend.FALLING_FAST
        elif change_pct < -0.05:
            return PriceTrend.FALLING
        
        # Only check volatility if trend is STABLE
        if len(prices) > 1:
            std_dev = statistics.stdev(prices)
            avg_price = statistics.mean(prices)
            volatility = std_dev / avg_price if avg_price > 0 else 0
            
            if volatility > 0.3:
                return PriceTrend.VOLATILE
        
        return PriceTrend.STABLE
    
    def _get_source_stats(self) -> Dict[str, int]:
        """Get statistics by market source."""
        stats: Dict[str, int] = {}
        
        for listings in self.listings.values():
            for listing in listings:
                source = listing.source.value
                stats[source] = stats.get(source, 0) + 1
        
        return stats
    
    def _load_market_data(self) -> None:
        """Load persisted market data from disk."""
        market_file = self.data_dir / "market_data.json"
        
        if not market_file.exists():
            self.log.info("no_market_data_found", creating_new=True)
            return
        
        try:
            with open(market_file, 'r') as f:
                data = json.load(f)
            
            # Load listings (skip old ones)
            cutoff = datetime.utcnow() - timedelta(days=7)
            
            for item_id_str, listings_data in data.get("listings", {}).items():
                item_id = int(item_id_str)
                self.listings[item_id] = []
                
                for listing_data in listings_data:
                    listing_data["timestamp"] = datetime.fromisoformat(
                        listing_data["timestamp"]
                    )
                    listing = MarketListing(**listing_data)
                    
                    if listing.timestamp >= cutoff:
                        self.listings[item_id].append(listing)
            
            # Load price history
            for item_id_str, history_data in data.get("price_history", {}).items():
                item_id = int(item_id_str)
                
                # Convert timestamps
                history_data["price_points"] = [
                    (datetime.fromisoformat(ts), price, qty)
                    for ts, price, qty in history_data["price_points"]
                ]
                
                self.price_history[item_id] = PriceHistory(**history_data)
            
            self.log.info(
                "market_data_loaded",
                items=len(self.listings),
                history_items=len(self.price_history)
            )
        
        except Exception as e:
            self.log.error("market_data_load_failed", error=str(e))
    
    def _save_market_data(self) -> None:
        """Persist market data to disk."""
        market_file = self.data_dir / "market_data.json"
        
        try:
            # Prepare data for JSON serialization
            data = {
                "listings": {},
                "price_history": {}
            }
            
            # Serialize listings
            for item_id, listings in self.listings.items():
                data["listings"][str(item_id)] = [
                    {
                        **listing.model_dump(),
                        "timestamp": listing.timestamp.isoformat()
                    }
                    for listing in listings
                ]
            
            # Serialize price history
            for item_id, history in self.price_history.items():
                history_dict = history.model_dump()
                history_dict["price_points"] = [
                    (ts.isoformat(), price, qty)
                    for ts, price, qty in history.price_points
                ]
                data["price_history"][str(item_id)] = history_dict
            
            with open(market_file, 'w') as f:
                json.dump(data, f, indent=2)
            
            self.log.debug("market_data_saved", file=str(market_file))
        
        except Exception as e:
            self.log.error("market_data_save_failed", error=str(e))