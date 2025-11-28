"""
Comprehensive tests for Economy Deep Dive systems (Phase 9K).

Tests:
- Market Manager
- Price Analyzer
- Supply/Demand Analyzer
- Vending Optimizer
- Buying Manager
- Trading Manager
- Economic Intelligence
- Economy Coordinator
"""

import json
from datetime import datetime, timedelta
from pathlib import Path
from typing import List

import pytest

from ai_sidecar.economy.buying import BuyingManager, PurchasePriority, PurchaseTarget
from ai_sidecar.economy.coordinator import EconomyCoordinator
from ai_sidecar.economy.core import (
    MarketListing,
    MarketManager,
    MarketSource,
    PriceTrend,
)
from ai_sidecar.economy.intelligence import EconomicIntelligence
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.supply_demand import ItemRarity, SupplyDemandAnalyzer
from ai_sidecar.economy.trading_strategy import TradingManager
from ai_sidecar.economy.vending import VendingOptimizer


@pytest.fixture
def temp_data_dir(tmp_path):
    """Create temporary data directory."""
    data_dir = tmp_path / "economy_data"
    data_dir.mkdir()
    
    # Create drop_rates.json
    drop_rates = {
        "drop_rates": {
            "501": {"rate": 0.50, "sources": ["Poring"]},
            "4001": {"rate": 0.0001, "sources": ["Poring"]},
            "7001": {"rate": 0.50, "sources": ["Poring"]}
        },
        "mvp_drops": {
            "4121": {"boss": "Baphomet", "rate": 0.01}
        }
    }
    
    with open(data_dir / "drop_rates.json", 'w') as f:
        json.dump(drop_rates, f)
    
    return data_dir


@pytest.fixture
def market_manager(temp_data_dir):
    """Create market manager instance."""
    return MarketManager(temp_data_dir)


@pytest.fixture
def price_analyzer(market_manager):
    """Create price analyzer instance."""
    return PriceAnalyzer(market_manager)


@pytest.fixture
def supply_demand(market_manager, temp_data_dir):
    """Create supply/demand analyzer instance."""
    return SupplyDemandAnalyzer(market_manager, temp_data_dir)


@pytest.fixture
def trading_manager(market_manager, price_analyzer):
    """Create trading manager instance."""
    return TradingManager(market_manager, price_analyzer)


class TestMarketManager:
    """Test market data management"""
    
    def test_listing_recording(self, market_manager):
        """Test recording listings"""
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=100,
            source=MarketSource.VENDING,
            seller_name="TestSeller"
        )
        
        market_manager.record_listing(listing)
        
        assert 501 in market_manager.listings
        assert len(market_manager.listings[501]) == 1
        assert market_manager.listings[501][0].price == 50
    
    def test_price_history(self, market_manager):
        """Test price history tracking"""
        # Add multiple listings
        for i in range(5):
            listing = MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50 + i * 5,
                quantity=100,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Check history
        history = market_manager.get_price_history(501, days=7)
        
        assert history is not None
        assert history.item_id == 501
        assert len(history.price_points) == 5
        assert history.min_price == 50
        assert history.max_price == 70
    
    def test_trend_detection(self, market_manager):
        """Test trend detection"""
        # Create rising price pattern
        base_price = 100
        
        for i in range(10):
            listing = MarketListing(
                item_id=502,
                item_name="Orange Potion",
                price=base_price + i * 10,
                quantity=50,
                source=MarketSource.VENDING,
                timestamp=datetime.utcnow() - timedelta(days=9-i)
            )
            market_manager.record_listing(listing)
        
        trend = market_manager.get_trend(502)
        
        assert trend in [PriceTrend.RISING, PriceTrend.RISING_FAST]
    
    def test_current_price(self, market_manager):
        """Test current price retrieval"""
        # Add listings
        for price in [100, 110, 120, 90, 105]:
            listing = MarketListing(
                item_id=503,
                item_name="Yellow Potion",
                price=price,
                quantity=50,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        current = market_manager.get_current_price(503)
        
        assert current is not None
        assert current["min_price"] == 90
        assert current["max_price"] == 120
        assert current["median_price"] == 105
        assert current["listing_count"] == 5


class TestPriceAnalyzer:
    """Test price analysis"""
    
    def test_fair_price_calculation(self, market_manager, price_analyzer):
        """Test fair price calculation"""
        # Add market data
        for price in [1000, 1100, 1200, 1050, 1150]:
            listing = MarketListing(
                item_id=1101,
                item_name="Sword",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        fair_price = price_analyzer.calculate_fair_price(1101)
        
        assert fair_price > 0
        assert 1000 <= fair_price <= 1300  # Should be near median
    
    def test_anomaly_detection(self, market_manager, price_analyzer):
        """Test anomaly detection"""
        # Add normal listings
        for price in [1000, 1100, 1200, 1050, 1150]:
            listing = MarketListing(
                item_id=1102,
                item_name="Dagger",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Test high anomaly
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1102, 5000)
        assert is_anomaly
        assert reason in ["price_too_high", "exceeds_maximum_threshold"]
        
        # Test low anomaly
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1102, 100)
        assert is_anomaly
        assert reason in ["price_too_low", "below_minimum_threshold"]
        
        # Test normal price
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1102, 1100)
        assert not is_anomaly
    
    def test_price_prediction(self, market_manager, price_analyzer):
        """Test price prediction"""
        # Add trending data
        base_time = datetime.utcnow() - timedelta(days=14)
        
        for i in range(14):
            listing = MarketListing(
                item_id=1103,
                item_name="Axe",
                price=1000 + i * 50,
                quantity=1,
                source=MarketSource.VENDING,
                timestamp=base_time + timedelta(days=i)
            )
            market_manager.record_listing(listing)
        
        predicted, confidence = price_analyzer.predict_price(1103, days_ahead=7)
        
        assert predicted > 0
        assert 0 <= confidence <= 1
        # Should predict higher price due to trend
        assert predicted > 1000


class TestTradingManager:
    """Test trading strategies"""
    
    def test_arbitrage_detection(self, market_manager, price_analyzer, trading_manager):
        """Test arbitrage opportunity detection"""
        # Add NPC listing (cheap)
        npc_listing = MarketListing(
            item_id=1104,
            item_name="Lance",
            price=5000,
            quantity=10,
            source=MarketSource.NPC_SELL
        )
        market_manager.record_listing(npc_listing)
        
        # Add vending listing (expensive)
        vend_listing = MarketListing(
            item_id=1104,
            item_name="Lance",
            price=7000,
            quantity=5,
            source=MarketSource.VENDING,
            seller_name="HighPricer"
        )
        market_manager.record_listing(vend_listing)
        
        opportunities = trading_manager.find_arbitrage_opportunities(
            min_profit=1000,
            min_margin=0.05
        )
        
        assert len(opportunities) > 0
        opp = opportunities[0]
        assert opp.item_id == 1104
        assert opp.profit >= 1000
        assert opp.buy_source == MarketSource.NPC_SELL
        assert opp.sell_source == MarketSource.VENDING
    
    def test_flip_opportunities(self, market_manager, price_analyzer, trading_manager):
        """Test flip opportunity detection"""
        # Add multiple listings with one cheap outlier
        for price in [10000, 11000, 12000, 11500, 10500]:
            listing = MarketListing(
                item_id=1105,
                item_name="Bow",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Add cheap listing
        cheap_listing = MarketListing(
            item_id=1105,
            item_name="Bow",
            price=7000,  # Below median
            quantity=1,
            source=MarketSource.VENDING,
            seller_name="QuickSeller"
        )
        market_manager.record_listing(cheap_listing)
        
        opportunities = trading_manager.find_flip_opportunities(
            min_profit=3000,
            max_risk=0.5
        )
        
        assert len(opportunities) > 0
        assert any(opp.buy_price == 7000 for opp in opportunities)
    
    def test_trade_evaluation(self, market_manager, price_analyzer, trading_manager):
        """Test trade evaluation"""
        # Add market data
        for price in [5000, 5500, 6000, 5200, 5800]:
            listing = MarketListing(
                item_id=1106,
                item_name="Mace",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Evaluate good trade
        evaluation = trading_manager.evaluate_trade(1106, buy_price=4000)
        
        assert evaluation["viable"]
        assert evaluation["profit"] > 0
        assert evaluation["profit_margin"] > 0


class TestVendingOptimizer:
    """Test vending optimization"""
    
    def test_price_optimization(self, market_manager, price_analyzer, supply_demand):
        """Test price optimization"""
        vending = VendingOptimizer(market_manager, price_analyzer, supply_demand)
        
        # Add market data
        for price in [1000, 1100, 1200, 1050, 1150]:
            listing = MarketListing(
                item_id=2101,
                item_name="Guard",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Test normal urgency
        optimal = vending.optimize_price(2101, urgency=0.5)
        assert optimal > 0
        
        # Test high urgency (should be lower)
        urgent = vending.optimize_price(2101, urgency=0.9)
        assert urgent < optimal
        
        # Test low urgency (should be higher)
        patient = vending.optimize_price(2101, urgency=0.1)
        assert patient > optimal
    
    def test_location_selection(self, market_manager, price_analyzer, supply_demand, temp_data_dir):
        """Test location selection"""
        # Create locations file
        locations = {
            "locations": [
                {
                    "map": "prontera",
                    "x": 155,
                    "y": 180,
                    "traffic_score": 95,
                    "competition_count": 10,
                    "avg_sales_per_hour": 5.0,
                    "category_preference": ["weapons"]
                }
            ]
        }
        
        with open(temp_data_dir / "vending_locations.json", 'w') as f:
            json.dump(locations, f)
        
        vending = VendingOptimizer(
            market_manager,
            price_analyzer,
            supply_demand,
            temp_data_dir / "market_config.json"
        )
        
        best = vending.get_best_locations([1101, 1102])
        
        assert len(best) > 0


class TestBuyingManager:
    """Test buying strategy"""
    
    def test_purchase_target_management(self, market_manager, price_analyzer):
        """Test adding and managing purchase targets"""
        buying = BuyingManager(market_manager, price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.HIGH,
            quantity_needed=50
        )
        
        buying.add_purchase_target(target)
        
        assert 501 in buying.purchase_targets
        assert buying.purchase_targets[501].max_price == 100
    
    def test_listing_evaluation(self, market_manager, price_analyzer):
        """Test listing evaluation"""
        buying = BuyingManager(market_manager, price_analyzer)
        
        # Add purchase target
        target = PurchaseTarget(
            item_id=502,
            item_name="Orange Potion",
            max_price=150,
            priority=PurchasePriority.NORMAL,
            quantity_needed=30
        )
        buying.add_purchase_target(target)
        
        # Add market data
        for price in [100, 120, 140, 110, 130]:
            listing = MarketListing(
                item_id=502,
                item_name="Orange Potion",
                price=price,
                quantity=10,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Test good listing
        good_listing = MarketListing(
            item_id=502,
            item_name="Orange Potion",
            price=100,
            quantity=10,
            source=MarketSource.VENDING
        )
        
        should_buy, reason = buying.evaluate_listing(good_listing)
        assert should_buy
        
        # Test overpriced listing
        bad_listing = MarketListing(
            item_id=502,
            item_name="Orange Potion",
            price=200,
            quantity=10,
            source=MarketSource.VENDING
        )
        
        should_buy, reason = buying.evaluate_listing(bad_listing)
        assert not should_buy
        assert reason == "price_too_high"
    
    def test_purchase_recommendations(self, market_manager, price_analyzer):
        """Test purchase recommendations"""
        buying = BuyingManager(market_manager, price_analyzer)
        
        # Add targets
        buying.add_purchase_target(PurchaseTarget(
            item_id=503,
            item_name="Yellow Potion",
            max_price=200,
            priority=PurchasePriority.CRITICAL,
            quantity_needed=50
        ))
        
        # Add market listings
        listing = MarketListing(
            item_id=503,
            item_name="Yellow Potion",
            price=150,
            quantity=50,
            source=MarketSource.VENDING,
            seller_name="Seller1"
        )
        market_manager.record_listing(listing)
        
        recommendations = buying.get_purchase_recommendations(budget=10000)
        
        assert len(recommendations) > 0
        assert recommendations[0]["item_id"] == 503


class TestSupplyDemandAnalyzer:
    """Test supply/demand modeling"""
    
    def test_rarity_assessment(self, market_manager, temp_data_dir):
        """Test item rarity assessment"""
        analyzer = SupplyDemandAnalyzer(market_manager, temp_data_dir)
        
        # Test common item (high drop rate)
        rarity = analyzer.get_item_rarity(501)
        assert rarity == ItemRarity.COMMON
        
        # Test rare card (low drop rate)
        rarity = analyzer.get_item_rarity(4001)
        assert rarity in [ItemRarity.LEGENDARY, ItemRarity.UNIQUE]
    
    def test_supply_demand_calculation(self, market_manager, supply_demand):
        """Test supply/demand metrics calculation"""
        # Add listings
        for i in range(10):
            listing = MarketListing(
                item_id=504,
                item_name="White Potion",
                price=200 + i * 10,
                quantity=20,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        metrics = supply_demand.calculate_supply_demand(504)
        
        assert metrics.item_id == 504
        assert metrics.supply_score > 0
        assert metrics.demand_score > 0
        assert metrics.listing_count == 10


class TestEconomicIntelligence:
    """Test economic intelligence"""
    
    def test_manipulation_detection(self, market_manager, price_analyzer, trading_manager):
        """Test market manipulation detection"""
        intelligence = EconomicIntelligence(market_manager, price_analyzer, trading_manager)
        
        # Create manipulation pattern - sudden price spike
        base_time = datetime.utcnow() - timedelta(days=10)
        
        # Normal prices for 5 days
        for i in range(5):
            listing = MarketListing(
                item_id=1201,
                item_name="Knife",
                price=1000,
                quantity=5,
                source=MarketSource.VENDING,
                timestamp=base_time + timedelta(days=i)
            )
            market_manager.record_listing(listing)
        
        # Sudden spike
        for i in range(5, 10):
            listing = MarketListing(
                item_id=1201,
                item_name="Knife",
                price=3000,
                quantity=5,
                source=MarketSource.VENDING,
                timestamp=base_time + timedelta(days=i)
            )
            market_manager.record_listing(listing)
        
        alert = intelligence.detect_manipulation(1201)
        
        assert alert is not None
        assert alert.alert_type == "manipulation"
        assert alert.severity in ["high", "medium"]
    
    def test_scam_detection(self, market_manager, price_analyzer, trading_manager):
        """Test scam detection"""
        intelligence = EconomicIntelligence(market_manager, price_analyzer, trading_manager)
        
        # Add normal market data
        for price in [5000, 5500, 6000, 5200]:
            listing = MarketListing(
                item_id=1202,
                item_name="Stiletto",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            market_manager.record_listing(listing)
        
        # Create suspicious listing (too cheap)
        scam_listing = MarketListing(
            item_id=1202,
            item_name="Stiletto",
            price=500,  # 10x too cheap
            quantity=1,
            source=MarketSource.VENDING,
            seller_name="Scammer"
        )
        
        alert = intelligence.detect_scam(scam_listing)
        
        assert alert is not None
        assert alert.alert_type == "scam"


class TestEconomyCoordinator:
    """Test integrated economy system"""
    
    def test_coordinator_initialization(self, temp_data_dir):
        """Test coordinator initialization"""
        coordinator = EconomyCoordinator(temp_data_dir)
        
        assert coordinator.market is not None
        assert coordinator.analyzer is not None
        assert coordinator.trading is not None
        assert coordinator.supply_demand is not None
        assert coordinator.vending is not None
        assert coordinator.buying is not None
        assert coordinator.intelligence is not None
    
    async def test_market_data_update(self, temp_data_dir):
        """Test market data update"""
        coordinator = EconomyCoordinator(temp_data_dir)
        
        listings = [
            {
                "item_id": 601,
                "item_name": "Fly Wing",
                "price": 50,
                "quantity": 100,
                "source": "vending",
                "seller_name": "Seller1"
            },
            {
                "item_id": 602,
                "item_name": "Butterfly Wing",
                "price": 200,
                "quantity": 50,
                "source": "vending",
                "seller_name": "Seller2"
            }
        ]
        
        result = await coordinator.update_market_data(listings)
        
        assert result["added"] == 2
        assert result["total_listings"] >= 2
    
    def test_net_worth_calculation(self, temp_data_dir):
        """Test net worth calculation"""
        coordinator = EconomyCoordinator(temp_data_dir)
        
        # Add market data
        for item_id, price in [(701, 1000), (702, 2000), (703, 500)]:
            listing = MarketListing(
                item_id=item_id,
                item_name=f"Item_{item_id}",
                price=price,
                quantity=1,
                source=MarketSource.VENDING
            )
            coordinator.market.record_listing(listing)
        
        inventory = {
            "items": [
                {"item_id": 701, "name": "Item_701", "amount": 10},
                {"item_id": 702, "name": "Item_702", "amount": 5},
                {"item_id": 703, "name": "Item_703", "amount": 20}
            ]
        }
        
        net_worth = coordinator.evaluate_net_worth(inventory, zeny=50000)
        
        assert net_worth["total_worth"] > 50000
        assert net_worth["liquid_zeny"] == 50000
        assert net_worth["inventory_value"] > 0
    
    def test_statistics(self, temp_data_dir):
        """Test statistics retrieval"""
        coordinator = EconomyCoordinator(temp_data_dir)
        
        stats = coordinator.get_statistics()
        
        assert "market" in stats
        assert "health" in stats
        assert "purchase_targets" in stats
        assert "active_alerts" in stats