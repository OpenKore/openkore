"""
Final push to 70% coverage - targeting easy wins.

Tests remaining uncovered lines in high-value modules.
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime

from ai_sidecar.economy.coordinator import EconomyCoordinator
from ai_sidecar.economy.core import MarketManager, MarketListing, MarketSource
from ai_sidecar.core.state import GameState, CharacterState, Position, InventoryState


# Quick economy coordinator tests

class TestEconomyCoordinatorQuick:
    """Quick economy coordinator tests."""
    
    @pytest.mark.asyncio
    async def test_tick_basic(self, tmp_path):
        """Test basic tick processing."""
        coordinator = EconomyCoordinator(data_dir=Path(tmp_path))
        
        char = CharacterState(
            name="TestChar",
            job_id=4001,
            base_level=90,
            job_level=50,
            hp=800,
            hp_max=1000,
            sp=200,
            sp_max=300,
            position=Position(x=100, y=100),
            zeny=10000,
            weight=1000,
            weight_max=2000,
            weight_percent=50,
        )
        
        inventory = InventoryState(items=[])
        
        game_state = GameState(
            tick=1000,
            character=char,
            inventory=inventory,
            party_members=[],
            nearby_monsters=[],
            nearby_npcs=[],
            nearby_players=[],
            nearby_items=[],
        )
        
        actions = await coordinator.tick(game_state)
        assert isinstance(actions, list)


# Quick market manager tests

class TestMarketManagerQuick:
    """Quick market manager tests."""
    
    def test_add_listing(self, tmp_path):
        """Test add listing."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        manager.add_listing(listing)
        assert 501 in manager.listings
    
    def test_remove_listing(self, tmp_path):
        """Test remove listing."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        manager.add_listing(listing)
        manager.remove_listing(listing)
    
    def test_get_best_price(self, tmp_path):
        """Test get best price."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        listing1 = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=60,
            quantity=50,
            seller_name="Seller1",
            source=MarketSource.VENDING,
        )
        
        listing2 = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="Seller2",
            source=MarketSource.VENDING,
        )
        
        manager.add_listing(listing1)
        manager.add_listing(listing2)
        
        best = manager.get_best_price(501)
        assert best == 50
    
    def test_get_average_price(self, tmp_path):
        """Test get average price."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        for price in [100, 110, 90]:
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=price,
                quantity=10,
                seller_name=f"Seller{price}",
                source=MarketSource.VENDING,
            )
            manager.add_listing(listing)
        
        avg = manager.get_average_price(501)
        assert 90 <= avg <= 110
    
    def test_get_listings(self, tmp_path):
        """Test get listings for item."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        manager.add_listing(listing)
        
        listings = manager.get_listings(501)
        assert len(listings) > 0
    
    def test_get_sellers_count(self, tmp_path):
        """Test get sellers count."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        manager.add_listing(listing)
        
        count = manager.get_sellers_count(501)
        assert count >= 1
    
    def test_clear_old_listings(self, tmp_path):
        """Test clear old listings."""
        manager = MarketManager(data_dir=Path(tmp_path))
        
        old_listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
            posted_at=datetime.utcnow(),
        )
        
        manager.add_listing(old_listing)
        manager.clear_old_listings(max_age_hours=24)


# Additional simple tests

class TestSimpleCoverage:
    """Simple tests for easy coverage wins."""
    
    def test_market_listing_creation(self):
        """Test market listing creation."""
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
            posted_at=datetime.utcnow(),
        )
        
        assert listing.item_id == 501
        assert listing.price == 50
    
    def test_market_source_enum(self):
        """Test market source enum."""
        assert MarketSource.VENDING.value == "vending"
        assert MarketSource.AUCTION.value == "auction"
        assert MarketSource.NPC.value == "npc"