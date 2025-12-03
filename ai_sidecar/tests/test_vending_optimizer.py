"""
Comprehensive tests for economy/vending.py module
Target: Boost coverage from 44.88% to 90%+
"""

import json
import pytest
import tempfile
from datetime import timedelta
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.economy.vending import (
    VendingOptimizer,
    VendingLocation,
    VendingItem,
)
from ai_sidecar.economy.core import MarketManager
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.supply_demand import SupplyDemandAnalyzer, SupplyDemandMetrics


@pytest.fixture
def mock_market_manager():
    """Mock market manager"""
    market = Mock(spec=MarketManager)
    market.listings = {}
    market.get_current_price.return_value = {"median_price": 1000}
    return market


@pytest.fixture
def mock_price_analyzer():
    """Mock price analyzer"""
    analyzer = Mock(spec=PriceAnalyzer)
    analyzer.calculate_fair_price.return_value = 1000
    analyzer.compare_to_market.return_value = {"position": "median"}
    return analyzer


@pytest.fixture
def mock_supply_demand():
    """Mock supply/demand analyzer"""
    analyzer = Mock(spec=SupplyDemandAnalyzer)
    analyzer.calculate_supply_demand.return_value = SupplyDemandMetrics(
        item_id=501,
        item_name="Red Potion",
        demand_score=1.0,
        supply_score=1.0,
        scarcity_index=1.0,
        market_liquidity=0.5,
        listing_count=10,
        avg_sale_time=timedelta(hours=4),
        estimated_daily_volume=100
    )
    return analyzer


class TestVendingModels:
    """Test vending data models"""
    
    def test_vending_location_creation(self):
        """Test creating vending location"""
        location = VendingLocation(
            map="prontera",
            x=150,
            y=200,
            traffic_score=85.5,
            competition_count=5
        )
        
        assert location.map_name == "prontera"
        assert location.traffic_score == 85.5
    
    def test_vending_item_creation(self):
        """Test creating vending item"""
        item = VendingItem(
            item_id=501,
            item_name="Red Potion",
            quantity=100,
            price=50,
            profit_margin=0.2
        )
        
        assert item.item_id == 501
        assert item.quantity == 100
        assert item.price == 50


class TestVendingOptimizerInit:
    """Test VendingOptimizer initialization"""
    
    def test_init_default(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test initialization with defaults"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        assert optimizer.market == mock_market_manager
        assert optimizer.analyzer == mock_price_analyzer
        assert optimizer.supply_demand == mock_supply_demand
        assert len(optimizer.locations) == 0
    
    def test_init_with_config(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test initialization with config file"""
        config_data = {
            "vending": {
                "undercut_amount": 200,
                "peak_hours": [19, 20, 21]
            }
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(config_data, f)
            config_path = Path(f.name)
        
        try:
            optimizer = VendingOptimizer(
                mock_market_manager,
                mock_price_analyzer,
                mock_supply_demand,
                config_path=config_path
            )
            
            assert optimizer.config["undercut_amount"] == 200
            assert optimizer.config["peak_hours"] == [19, 20, 21]
        finally:
            config_path.unlink()
    
    def test_init_missing_config(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test initialization with missing config"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand,
            config_path=Path("/nonexistent/config.json")
        )
        
        # Should use defaults
        assert "undercut_amount" in optimizer.config
        assert "peak_hours" in optimizer.config


class TestOptimizePrice:
    """Test price optimization"""
    
    def test_optimize_price_normal_urgency(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization with normal urgency"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price = optimizer.optimize_price(item_id=501, urgency=0.5)
        
        # Normal urgency = 1.05 multiplier
        # 1000 * 1.05 = 1050
        assert price > 0
        assert price >= 1000  # Should have some markup
    
    def test_optimize_price_high_urgency(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization with high urgency (quick sale)"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price_normal = optimizer.optimize_price(item_id=501, urgency=0.5)
        price_urgent = optimizer.optimize_price(item_id=501, urgency=0.9)
        
        # High urgency = lower price
        assert price_urgent < price_normal
    
    def test_optimize_price_low_urgency(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization with low urgency (patient)"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price_normal = optimizer.optimize_price(item_id=501, urgency=0.5)
        price_patient = optimizer.optimize_price(item_id=501, urgency=0.1)
        
        # Low urgency = higher price
        assert price_patient > price_normal
    
    def test_optimize_price_high_scarcity(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization with high scarcity"""
        mock_supply_demand.calculate_supply_demand.return_value = SupplyDemandMetrics(
            item_id=501,
            item_name="Red Potion",
            demand_score=2.0,
            supply_score=0.5,
            scarcity_index=3.0,  # High scarcity
            market_liquidity=0.7,
            listing_count=5,
            avg_sale_time=timedelta(hours=2),
            estimated_daily_volume=200
        )
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price = optimizer.optimize_price(item_id=501, urgency=0.5)
        
        # High scarcity = higher price (1.10 multiplier)
        assert price > 1000
    
    def test_optimize_price_oversupply(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization with oversupply"""
        mock_supply_demand.calculate_supply_demand.return_value = SupplyDemandMetrics(
            item_id=501,
            item_name="Red Potion",
            demand_score=0.5,
            supply_score=2.0,
            scarcity_index=0.3,  # Oversupply
            market_liquidity=0.9,
            listing_count=50,
            avg_sale_time=timedelta(hours=12),
            estimated_daily_volume=20
        )
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price = optimizer.optimize_price(item_id=501, urgency=0.5)
        
        # Oversupply = lower price (0.90 multiplier)
        assert price > 0
    
    def test_optimize_price_no_price_data(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test price optimization when no price data available"""
        mock_price_analyzer.calculate_fair_price.return_value = 0
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        price = optimizer.optimize_price(item_id=999)
        
        assert price == 0


class TestGetBestLocations:
    """Test location selection"""
    
    def test_get_best_locations(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test getting best vending locations"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        # Add test locations
        optimizer.locations = [
            VendingLocation(map="prontera", x=150, y=200, traffic_score=90),
            VendingLocation(map="geffen", x=100, y=100, traffic_score=70),
            VendingLocation(map="payon", x=50, y=50, traffic_score=85),
        ]
        
        best = optimizer.get_best_locations(item_ids=[501, 502], count=2)
        
        assert len(best) == 2
        # Should be sorted by score
        assert best[0].traffic_score >= best[1].traffic_score
    
    def test_get_best_locations_no_data(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test getting locations with no location data"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        best = optimizer.get_best_locations(item_ids=[501], count=5)
        
        assert len(best) == 0


class TestSelectVendingItems:
    """Test vending item selection"""
    
    def test_select_vending_items(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test selecting items from inventory"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inventory = {
            "items": [
                {"item_id": 501, "name": "Red Potion", "amount": 100, "equipped": False},
                {"item_id": 502, "name": "Orange Potion", "amount": 50, "equipped": False},
            ]
        }
        
        items = optimizer.select_vending_items(inventory, max_items=2)
        
        assert len(items) > 0
        assert all(isinstance(item, VendingItem) for item in items)
    
    def test_select_vending_items_skips_equipped(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test that equipped items are skipped"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inventory = {
            "items": [
                {"item_id": 501, "name": "Weapon", "amount": 1, "equipped": True},
                {"item_id": 502, "name": "Potion", "amount": 100, "equipped": False},
            ]
        }
        
        items = optimizer.select_vending_items(inventory, max_items=10)
        
        # Should not include equipped weapon
        assert all(item.item_id != 501 for item in items)
    
    def test_select_vending_items_respects_max(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test that max_items limit is respected"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inventory = {
            "items": [
                {"item_id": 500 + i, "name": f"Item{i}", "amount": 10, "equipped": False}
                for i in range(20)
            ]
        }
        
        items = optimizer.select_vending_items(inventory, max_items=5)
        
        assert len(items) <= 5


class TestCalculateExpectedRevenue:
    """Test revenue calculations"""
    
    def test_calculate_expected_revenue(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test basic revenue calculation"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        items = [
            VendingItem(
                item_id=501,
                item_name="Red Potion",
                quantity=100,
                price=50,
                expected_sale_time=timedelta(hours=4)
            ),
            VendingItem(
                item_id=502,
                item_name="Blue Potion",
                quantity=50,
                price=100,
                expected_sale_time=timedelta(hours=8)
            )
        ]
        
        revenue = optimizer.calculate_expected_revenue(items, hours=8.0)
        
        assert "total_inventory_value" in revenue
        assert "expected_sold_value" in revenue
        assert "expected_profit" in revenue
        assert revenue["vending_hours"] == 8.0
    
    def test_calculate_expected_revenue_fast_selling(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test revenue with fast-selling items"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        items = [
            VendingItem(
                item_id=501,
                item_name="Fast Seller",
                quantity=100,
                price=100,
                expected_sale_time=timedelta(hours=2)  # Sells fast
            )
        ]
        
        revenue = optimizer.calculate_expected_revenue(items, hours=8.0)
        
        # Should sell all (prob = 1.0)
        assert revenue["expected_sold_value"] == 10000  # 100 * 100


class TestGetOptimalVendingTime:
    """Test vending time optimization"""
    
    @patch('ai_sidecar.economy.vending.datetime')
    def test_optimal_time_during_peak(self, mock_datetime, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test recommendation during peak hours"""
        mock_datetime.now.return_value.hour = 20  # Peak hour
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        timing = optimizer.get_optimal_vending_time(item_ids=[501])
        
        assert timing["is_peak_time"] is True
        assert timing["recommendation"] == "start_now"
    
    @patch('ai_sidecar.economy.vending.datetime')
    def test_optimal_time_before_peak(self, mock_datetime, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test recommendation before peak hours"""
        mock_datetime.now.return_value.hour = 15  # Before peak
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        timing = optimizer.get_optimal_vending_time(item_ids=[501])
        
        assert timing["is_peak_time"] is False
        assert timing["recommendation"] == "wait_for_peak"
        assert timing["next_peak_hour"] is not None


class TestAnalyzeCompetition:
    """Test competition analysis"""
    
    def test_analyze_competition_none(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test competition analysis with no competitors"""
        mock_market_manager.listings = {501: []}
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        analysis = optimizer.analyze_competition(item_id=501, location="prontera")
        
        assert analysis["competition_level"] == "none"
        assert analysis["competitor_count"] == 0
    
    def test_analyze_competition_low(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test competition analysis with low competition"""
        from ai_sidecar.economy.core import MarketListing, MarketSource
        from datetime import datetime
        
        listings = [
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50 + i,
                quantity=10,
                seller_name=f"Seller{i}",
                source=MarketSource.VENDING,
                location_map="prontera",
                timestamp=datetime.utcnow()
            ) for i in range(3)
        ]
        
        mock_market_manager.listings = {501: listings}
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        analysis = optimizer.analyze_competition(item_id=501, location="prontera")
        
        assert analysis["competition_level"] == "low"
        assert analysis["competitor_count"] == 3
    
    def test_analyze_competition_high(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test competition analysis with high competition"""
        from ai_sidecar.economy.core import MarketListing, MarketSource
        from datetime import datetime
        
        listings = [
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50,
                quantity=10,
                seller_name=f"Seller{i}",
                source=MarketSource.VENDING,
                location_map="prontera",
                timestamp=datetime.utcnow()
            ) for i in range(15)
        ]
        
        mock_market_manager.listings = {501: listings}
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        analysis = optimizer.analyze_competition(item_id=501, location="prontera")
        
        assert analysis["competition_level"] == "high"
        assert analysis["competitor_count"] == 15


class TestShouldUndercut:
    """Test undercutting logic"""
    
    def test_should_undercut_profitable(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test undercutting when it's profitable"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        should_undercut, price = optimizer.should_undercut(
            item_id=501,
            current_lowest=1000,
            my_cost=500
        )
        
        # Undercut: 1000 - 100 = 900
        # Min price: 500 * 1.05 = 525
        # 900 > 525, so yes undercut
        assert should_undercut is True
        assert price == 900
    
    def test_should_undercut_unprofitable(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test undercutting when it would be unprofitable"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        should_undercut, price = optimizer.should_undercut(
            item_id=501,
            current_lowest=600,
            my_cost=550  # High cost
        )
        
        # Undercut: 600 - 100 = 500
        # Min price: 550 * 1.05 = 577.5
        # 500 < 577.5, so no undercut
        assert should_undercut is False
        assert price >= 577  # Min profitable price


class TestScoreLocation:
    """Test location scoring"""
    
    def test_score_location_high_traffic(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test scoring high traffic location"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        location = VendingLocation(
            map="prontera",
            x=150,
            y=200,
            traffic_score=100,
            competition_count=5,
            avg_sales_per_hour=5.0
        )
        
        score = optimizer._score_location(location, item_ids=[501])
        
        # High traffic + good sales history
        assert score > 100
    
    def test_score_location_high_competition(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test scoring location with high competition"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        location_low_comp = VendingLocation(
            map="prontera",
            x=150,
            y=200,
            traffic_score=80,
            competition_count=5
        )
        
        location_high_comp = VendingLocation(
            map="geffen",
            x=100,
            y=100,
            traffic_score=80,
            competition_count=25
        )
        
        score_low = optimizer._score_location(location_low_comp, item_ids=[501])
        score_high = optimizer._score_location(location_high_comp, item_ids=[501])
        
        # High competition should reduce score
        assert score_low > score_high


class TestCalculateItemScore:
    """Test item profitability scoring"""
    
    def test_calculate_item_score(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test calculating item profitability score"""
        mock_market_manager.get_current_price.return_value = {
            "median_price": 5000
        }
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inv_item = {"item_id": 501}
        score = optimizer._calculate_item_score(inv_item)
        
        assert score > 0
    
    def test_calculate_item_score_no_price_data(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test item score when no market data"""
        mock_market_manager.get_current_price.return_value = None
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inv_item = {"item_id": 999}
        score = optimizer._calculate_item_score(inv_item)
        
        assert score == 0.0
    
    def test_calculate_item_score_high_demand(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test item score boost for high demand"""
        mock_market_manager.get_current_price.return_value = {"median_price": 1000}
        
        mock_supply_demand.calculate_supply_demand.return_value = SupplyDemandMetrics(
            item_id=501,
            item_name="Red Potion",
            demand_score=2.0,
            supply_score=0.5,
            listing_count=50,
            estimated_daily_volume=1000,
            scarcity_index=2.0,  # High scarcity
            market_liquidity=0.9,  # High liquidity
            avg_sale_time=timedelta(hours=1)
        )
        
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        inv_item = {"item_id": 501}
        score = optimizer._calculate_item_score(inv_item)
        
        # Should have high score due to scarcity and liquidity boosts
        assert score > 1.0


class TestLoadConfig:
    """Test configuration loading"""
    
    def test_load_config_valid(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test loading valid config file"""
        config_data = {
            "vending": {
                "undercut_amount": 150,
                "peak_hours": [20, 21, 22]
            }
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(config_data, f)
            config_path = Path(f.name)
        
        try:
            optimizer = VendingOptimizer(
                mock_market_manager,
                mock_price_analyzer,
                mock_supply_demand,
                config_path=config_path
            )
            
            config = optimizer._load_config(config_path)
            
            assert config["undercut_amount"] == 150
        finally:
            config_path.unlink()
    
    def test_load_config_invalid_json(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test loading invalid JSON config"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write("{ invalid json")
            config_path = Path(f.name)
        
        try:
            optimizer = VendingOptimizer(
                mock_market_manager,
                mock_price_analyzer,
                mock_supply_demand,
                config_path=config_path
            )
            
            config = optimizer._load_config(config_path)
            
            # Should return empty dict on error
            assert config == {}
        finally:
            config_path.unlink()


class TestLoadLocations:
    """Test location data loading"""
    
    def test_load_locations_success(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test loading locations from file"""
        # Create config file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump({"vending": {}}, f)
            config_path = Path(f.name)
        
        # Create locations file in same directory
        locations_data = {
            "locations": [
                {
                    "map": "prontera",
                    "x": 150,
                    "y": 200,
                    "traffic_score": 90
                }
            ]
        }
        
        loc_path = config_path.parent / "vending_locations.json"
        with open(loc_path, 'w') as f:
            json.dump(locations_data, f)
        
        try:
            optimizer = VendingOptimizer(
                mock_market_manager,
                mock_price_analyzer,
                mock_supply_demand,
                config_path=config_path
            )
            
            assert len(optimizer.locations) == 1
            assert optimizer.locations[0].map_name == "prontera"
        finally:
            config_path.unlink()
            loc_path.unlink()
    
    def test_load_locations_missing_file(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test loading when locations file missing"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand,
            config_path=None
        )
        
        optimizer._load_locations(None)
        
        assert len(optimizer.locations) == 0


class TestIntegrationScenarios:
    """Test complete vending workflows"""
    
    def test_complete_vending_setup(self, mock_market_manager, mock_price_analyzer, mock_supply_demand):
        """Test complete vending shop setup workflow"""
        optimizer = VendingOptimizer(
            mock_market_manager,
            mock_price_analyzer,
            mock_supply_demand
        )
        
        # Add location
        optimizer.locations = [
            VendingLocation(map="prontera", x=150, y=200, traffic_score=90)
        ]
        
        # Select items from inventory
        inventory = {
            "items": [
                {"item_id": 501, "name": "Red Potion", "amount": 100, "equipped": False},
            ]
        }
        
        items = optimizer.select_vending_items(inventory, max_items=12)
        
        # Get best location
        best_locations = optimizer.get_best_locations(item_ids=[501], count=1)
        
        # Calculate revenue
        revenue = optimizer.calculate_expected_revenue(items, hours=8.0)
        
        # Check timing
        timing = optimizer.get_optimal_vending_time(item_ids=[501])
        
        assert len(items) > 0
        assert len(best_locations) > 0
        assert revenue["expected_sold_value"] > 0
        assert "recommendation" in timing