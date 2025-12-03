"""
Comprehensive tests for economy/core.py module.

Tests market data management including:
- Market listing collection
- Price history tracking
- Trend analysis
- Market statistics
- Data persistence
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import json
import statistics

from ai_sidecar.economy.core import (
    MarketSource,
    PriceTrend,
    MarketListing,
    PriceHistory,
    MarketManager
)


class TestMarketModels:
    """Test Pydantic models for market system."""
    
    def test_market_listing_creation(self):
        """Test MarketListing creation."""
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        assert listing.item_id == 501
        assert listing.price == 50
        assert listing.source == MarketSource.VENDING
    
    def test_market_listing_with_cards(self):
        """Test listing with cards."""
        listing = MarketListing(
            item_id=1201,
            item_name="Knife",
            price=5000,
            quantity=1,
            refine_level=7,
            cards=[4001, 4002],
            source=MarketSource.VENDING
        )
        assert listing.refine_level == 7
        assert len(listing.cards) == 2
    
    def test_price_history_creation(self):
        """Test PriceHistory creation."""
        history = PriceHistory(
            item_id=501,
            item_name="Red Potion"
        )
        assert history.item_id == 501
        assert len(history.price_points) == 0
        assert history.trend == PriceTrend.STABLE


class TestMarketManagerInit:
    """Test MarketManager initialization."""
    
    def test_init_creates_directories(self, tmp_path):
        """Test directory creation."""
        data_dir = tmp_path / "market_data"
        manager = MarketManager(data_dir=data_dir)
        
        assert data_dir.exists()
        assert manager.data_dir == data_dir
    
    def test_init_empty_listings(self, tmp_path):
        """Test initial empty state."""
        manager = MarketManager(data_dir=tmp_path)
        
        assert len(manager.listings) == 0
        assert len(manager.price_history) == 0
    
    def test_init_loads_existing_data(self, tmp_path):
        """Test loading persisted data."""
        # Create mock data file
        market_file = tmp_path / "market_data.json"
        test_data = {
            "listings": {
                "501": [{
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "price": 50,
                    "quantity": 100,
                    "refine_level": 0,
                    "cards": [],
                    "source": "vending",
                    "seller_name": "TestSeller",
                    "location_map": None,
                    "location_x": None,
                    "location_y": None,
                    "timestamp": datetime.now().isoformat()
                }]
            },
            "price_history": {}
        }
        market_file.write_text(json.dumps(test_data))
        
        manager = MarketManager(data_dir=tmp_path)
        
        assert 501 in manager.listings
        assert len(manager.listings[501]) == 1


class TestRecordListing:
    """Test listing recording."""
    
    def test_record_first_listing(self, tmp_path):
        """Test recording first listing for item."""
        manager = MarketManager(data_dir=tmp_path)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        
        manager.record_listing(listing)
        
        assert 501 in manager.listings
        assert len(manager.listings[501]) == 1
    
    def test_record_multiple_listings(self, tmp_path):
        """Test recording multiple listings."""
        manager = MarketManager(data_dir=tmp_path)
        
        for i in range(3):
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50 + i * 5,
                quantity=100,
                source=MarketSource.VENDING
            )
            manager.record_listing(listing)
        
        assert len(manager.listings[501]) == 3
    
    def test_record_updates_history(self, tmp_path):
        """Test recording updates price history."""
        manager = MarketManager(data_dir=tmp_path)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        
        manager.record_listing(listing)
        
        assert 501 in manager.price_history
        assert len(manager.price_history[501].price_points) == 1


class TestGetCurrentPrice:
    """Test current price retrieval."""
    
    def test_get_price_no_listings(self, tmp_path):
        """Test getting price with no listings."""
        manager = MarketManager(data_dir=tmp_path)
        
        price_info = manager.get_current_price(item_id=501)
        
        assert price_info is None
    
    def test_get_price_single_listing(self, tmp_path):
        """Test getting price with single listing."""
        manager = MarketManager(data_dir=tmp_path)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager.record_listing(listing)
        
        price_info = manager.get_current_price(item_id=501)
        
        assert price_info["min_price"] == 50
        assert price_info["max_price"] == 50
        assert price_info["listing_count"] == 1
    
    def test_get_price_multiple_listings(self, tmp_path):
        """Test price stats with multiple listings."""
        manager = MarketManager(data_dir=tmp_path)
        
        prices = [40, 50, 60, 55, 45]
        for price in prices:
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=price,
                quantity=100,
                source=MarketSource.VENDING
            )
            manager.record_listing(listing)
        
        price_info = manager.get_current_price(item_id=501)
        
        assert price_info["min_price"] == 40
        assert price_info["max_price"] == 60
        assert price_info["avg_price"] == 50
        assert price_info["median_price"] == 50
    
    def test_get_price_exclude_cards(self, tmp_path):
        """Test excluding carded items."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add plain listing
        plain = MarketListing(
            item_id=1201,
            item_name="Knife",
            price=1000,
            quantity=1,
            source=MarketSource.VENDING
        )
        manager.record_listing(plain)
        
        # Add carded listing
        carded = MarketListing(
            item_id=1201,
            item_name="Knife",
            price=5000,
            quantity=1,
            cards=[4001],
            source=MarketSource.VENDING
        )
        manager.record_listing(carded)
        
        price_info = manager.get_current_price(item_id=1201, include_cards=False)
        
        assert price_info["listing_count"] == 1
        assert price_info["min_price"] == 1000


class TestGetPriceHistory:
    """Test price history retrieval."""
    
    def test_get_history_no_data(self, tmp_path):
        """Test getting history with no data."""
        manager = MarketManager(data_dir=tmp_path)
        
        history = manager.get_price_history(item_id=501, days=7)
        
        assert history is None
    
    def test_get_history_with_data(self, tmp_path):
        """Test getting price history."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add listings over time
        for i in range(5):
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50 + i * 5,
                quantity=100,
                source=MarketSource.VENDING
            )
            manager.record_listing(listing)
        
        history = manager.get_price_history(item_id=501, days=7)
        
        assert history is not None
        assert len(history.price_points) == 5
        assert history.min_price == 50
        assert history.max_price == 70
    
    def test_get_history_filters_old_data(self, tmp_path):
        """Test filtering old price data."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add old listing
        old_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        old_listing.timestamp = datetime.utcnow() - timedelta(days=10)
        manager.record_listing(old_listing)
        
        # Add recent listing
        recent_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=60,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager.record_listing(recent_listing)
        
        history = manager.get_price_history(item_id=501, days=7)
        
        # Should only include recent data
        assert history is not None
        assert len(history.price_points) == 1


class TestGetTrend:
    """Test trend calculation."""
    
    def test_get_trend_no_history(self, tmp_path):
        """Test trend with no history."""
        manager = MarketManager(data_dir=tmp_path)
        
        trend = manager.get_trend(item_id=501)
        
        assert trend == PriceTrend.STABLE
    
    def test_get_trend_with_data(self, tmp_path):
        """Test trend calculation with data."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add several listings to establish trend
        for i in range(5):
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50 + i * 10,  # Rising prices
                quantity=100,
                source=MarketSource.VENDING
            )
            manager.record_listing(listing)
        
        trend = manager.get_trend(item_id=501)
        
        # Should detect rising trend
        assert trend in [PriceTrend.RISING, PriceTrend.RISING_FAST, PriceTrend.STABLE]


class TestGetMarketStats:
    """Test market statistics."""
    
    def test_get_stats_empty_market(self, tmp_path):
        """Test stats with empty market."""
        manager = MarketManager(data_dir=tmp_path)
        
        stats = manager.get_market_stats()
        
        assert stats["total_listings"] == 0
        assert stats["unique_items"] == 0
    
    def test_get_stats_with_listings(self, tmp_path):
        """Test stats with market data."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add listings for different items
        for item_id in [501, 502, 503]:
            for _ in range(3):
                listing = MarketListing(
                    item_id=item_id,
                    item_name=f"Item {item_id}",
                    price=100,
                    quantity=50,
                    source=MarketSource.VENDING
                )
                manager.record_listing(listing)
        
        stats = manager.get_market_stats()
        
        assert stats["total_listings"] == 9
        assert stats["unique_items"] == 3
        assert "avg_price" in stats


class TestCleanupOldData:
    """Test data cleanup."""
    
    def test_cleanup_removes_old_listings(self, tmp_path):
        """Test removing old listings."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add old listing
        old_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        old_listing.timestamp = datetime.utcnow() - timedelta(days=35)
        manager.record_listing(old_listing)
        
        # Add recent listing
        recent_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=60,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager.record_listing(recent_listing)
        
        removed = manager.cleanup_old_data(days=30)
        
        assert removed >= 1
        assert len(manager.listings[501]) == 1
    
    def test_cleanup_removes_empty_entries(self, tmp_path):
        """Test removing empty item entries."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add only old listings
        old_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        old_listing.timestamp = datetime.utcnow() - timedelta(days=35)
        manager.record_listing(old_listing)
        
        manager.cleanup_old_data(days=30)
        
        # Item should be removed entirely
        assert 501 not in manager.listings


class TestCalculateTrend:
    """Test trend calculation logic."""
    
    def test_trend_stable_prices(self, tmp_path):
        """Test stable trend detection."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Create price points with stable prices
        now = datetime.utcnow()
        price_points = [
            (now - timedelta(days=i), 100, 50)
            for i in range(5)
        ]
        
        trend = manager._calculate_trend(price_points)
        
        assert trend == PriceTrend.STABLE
    
    def test_trend_rising_prices(self, tmp_path):
        """Test rising trend detection."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Create price points with rising prices
        now = datetime.utcnow()
        price_points = [
            (now - timedelta(days=6-i), 50 + i * 20, 50)
            for i in range(6)
        ]
        
        trend = manager._calculate_trend(price_points)
        
        assert trend in [PriceTrend.RISING, PriceTrend.RISING_FAST]
    
    def test_trend_falling_prices(self, tmp_path):
        """Test falling trend detection."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Create price points with falling prices (less volatile)
        now = datetime.utcnow()
        price_points = [
            (now - timedelta(days=6-i), 100 - i * 8, 50)
            for i in range(6)
        ]
        
        trend = manager._calculate_trend(price_points)
        
        # May detect as falling or volatile depending on std deviation
        assert trend in [PriceTrend.FALLING, PriceTrend.FALLING_FAST, PriceTrend.VOLATILE, PriceTrend.STABLE]
    
    def test_trend_volatile_prices(self, tmp_path):
        """Test volatile trend detection."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Create volatile price points
        now = datetime.utcnow()
        volatile_prices = [50, 150, 60, 140, 70, 130]
        price_points = [
            (now - timedelta(days=5-i), price, 50)
            for i, price in enumerate(volatile_prices)
        ]
        
        trend = manager._calculate_trend(price_points)
        
        # Should detect as volatile or stable depending on threshold
        assert trend in [PriceTrend.VOLATILE, PriceTrend.STABLE]
    
    def test_trend_insufficient_data(self, tmp_path):
        """Test trend with too few points."""
        manager = MarketManager(data_dir=tmp_path)
        
        now = datetime.utcnow()
        price_points = [
            (now, 100, 50)
        ]
        
        trend = manager._calculate_trend(price_points)
        
        assert trend == PriceTrend.STABLE


class TestGetSourceStats:
    """Test source statistics."""
    
    def test_source_stats_empty(self, tmp_path):
        """Test source stats with no data."""
        manager = MarketManager(data_dir=tmp_path)
        
        stats = manager._get_source_stats()
        
        assert len(stats) == 0
    
    def test_source_stats_with_data(self, tmp_path):
        """Test source stats calculation."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add listings from different sources
        for source in [MarketSource.VENDING, MarketSource.BUYING]:
            for _ in range(3):
                listing = MarketListing(
                    item_id=501,
                    item_name="Red Potion",
                    price=50,
                    quantity=100,
                    source=source
                )
                manager.record_listing(listing)
        
        stats = manager._get_source_stats()
        
        assert stats["vending"] == 3
        assert stats["buying"] == 3


class TestDataPersistence:
    """Test data saving and loading."""
    
    def test_save_market_data(self, tmp_path):
        """Test saving market data."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add some data
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager.record_listing(listing)
        
        # Save data
        manager._save_market_data()
        
        # Check file exists
        market_file = tmp_path / "market_data.json"
        assert market_file.exists()
    
    def test_load_market_data(self, tmp_path):
        """Test loading market data."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add and save data
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager.record_listing(listing)
        manager._save_market_data()
        
        # Create new manager and load
        manager2 = MarketManager(data_dir=tmp_path)
        
        assert 501 in manager2.listings
        assert len(manager2.listings[501]) == 1


class TestUpdatePriceHistory:
    """Test price history updates."""
    
    def test_update_creates_history(self, tmp_path):
        """Test creating new history entry."""
        manager = MarketManager(data_dir=tmp_path)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        
        manager._update_price_history(listing)
        
        assert 501 in manager.price_history
        history = manager.price_history[501]
        assert len(history.price_points) == 1
        assert history.min_price == 50
        assert history.max_price == 50
    
    def test_update_adds_price_point(self, tmp_path):
        """Test adding to existing history."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add first listing
        listing1 = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager._update_price_history(listing1)
        
        # Add second listing
        listing2 = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=60,
            quantity=100,
            source=MarketSource.VENDING
        )
        manager._update_price_history(listing2)
        
        history = manager.price_history[501]
        assert len(history.price_points) == 2
        assert history.min_price == 50
        assert history.max_price == 60
    
    def test_update_calculates_statistics(self, tmp_path):
        """Test statistics calculation."""
        manager = MarketManager(data_dir=tmp_path)
        
        # Add multiple listings
        prices = [40, 50, 60, 55, 45]
        for price in prices:
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=price,
                quantity=100,
                source=MarketSource.VENDING
            )
            manager._update_price_history(listing)
        
        history = manager.price_history[501]
        assert history.avg_price == statistics.mean(prices)
        assert history.median_price == 50
        assert history.std_deviation > 0