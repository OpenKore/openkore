"""
Comprehensive tests for economy/coordinator.py - Batch 7.

Target: Push coverage from 60.66% to 85%+
Focus on uncovered lines: 102-110, 145-200, 224, 229, 262-267, 295-311, 346, 393-406, 423-434
"""

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import tempfile
import pytest

from ai_sidecar.economy.coordinator import EconomyCoordinator
from ai_sidecar.economy.core import MarketListing, MarketSource
from ai_sidecar.economy.trading_strategy import TradeOpportunity


@pytest.fixture
def temp_data_dir():
    """Create temporary data directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def coordinator(temp_data_dir):
    """Create economy coordinator."""
    return EconomyCoordinator(temp_data_dir)


@pytest.fixture
def sample_listings():
    """Create sample market listings."""
    return [
        {
            "item_id": 501,
            "item_name": "Red Potion",
            "seller": "Merchant1",
            "price": 50,
            "quantity": 100,
            "source": "player_shop",
            "map_name": "prontera"
        },
        {
            "item_id": 502,
            "item_name": "Orange Potion",
            "seller": "Merchant2",
            "price": 200,
            "quantity": 50,
            "source": "player_shop",
            "map_name": "prontera"
        },
    ]


class TestUpdateMarketData:
    """Test update_market_data method - lines 76-125."""

    @pytest.mark.asyncio
    async def test_update_market_data_success(self, coordinator, sample_listings):
        """Test successful market data update."""
        # Mock market manager
        coordinator.market.record_listing = MagicMock()
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 2}
        )
        
        # Mock intelligence (no scams/manipulation)
        coordinator.intelligence.detect_scam = MagicMock(return_value=None)
        coordinator.intelligence.detect_manipulation = MagicMock(return_value=None)
        
        result = await coordinator.update_market_data(sample_listings)
        
        assert result["added"] == 2
        assert result["scams_detected"] == 0
        assert result["manipulation_detected"] == 0

    @pytest.mark.asyncio
    async def test_update_market_data_with_scam_detection(self, coordinator, sample_listings):
        """Test scam detection during update."""
        coordinator.market.record_listing = MagicMock()
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 2}
        )
        
        # Mock scam detection
        coordinator.intelligence.detect_scam = MagicMock(
            return_value={"alert": "price too high"}
        )
        coordinator.intelligence.detect_manipulation = MagicMock(return_value=None)
        
        result = await coordinator.update_market_data(sample_listings)
        
        assert result["scams_detected"] == 2  # All listings flagged

    @pytest.mark.asyncio
    async def test_update_market_data_with_manipulation(self, coordinator, sample_listings):
        """Test manipulation detection during update."""
        coordinator.market.record_listing = MagicMock()
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 2}
        )
        
        # Mock manipulation detection
        coordinator.intelligence.detect_scam = MagicMock(return_value=None)
        coordinator.intelligence.detect_manipulation = MagicMock(
            return_value={"alert": "price manipulation"}
        )
        
        result = await coordinator.update_market_data(sample_listings)
        
        assert result["manipulation_detected"] == 2

    @pytest.mark.asyncio
    async def test_update_market_data_with_errors(self, coordinator):
        """Test error handling during update."""
        bad_listings = [
            {"invalid": "data"}  # Missing required fields
        ]
        
        coordinator.market.record_listing = MagicMock()
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 0}
        )
        
        result = await coordinator.update_market_data(bad_listings)
        
        # Should handle error gracefully
        assert result["added"] == 0


class TestGetNextEconomicAction:
    """Test get_next_economic_action method - lines 127-203."""

    @pytest.mark.asyncio
    async def test_action_with_purchase_recommendations(self, coordinator):
        """Test buy action recommendation."""
        character_state = {"level": 50}
        inventory = {"items": []}
        zeny = 100000
        
        # Mock purchase recommendations
        coordinator.buying.get_purchase_recommendations = MagicMock(
            return_value=[
                {"item_id": 501, "item_name": "Red Potion"}
            ]
        )
        
        result = await coordinator.get_next_economic_action(
            character_state, inventory, zeny
        )
        
        assert result["action"] == "buy"
        assert len(result["recommendations"]) > 0

    @pytest.mark.asyncio
    async def test_action_with_trade_opportunities(self, coordinator):
        """Test trade action recommendation."""
        character_state = {"level": 50}
        inventory = {"items": []}
        zeny = 100000
        
        # No purchase recommendations, but trades available
        coordinator.buying.get_purchase_recommendations = MagicMock(
            return_value=[]
        )
        
        trade_opp = TradeOpportunity(
            item_id=501,
            item_name="Red Potion",
            buy_price=40,
            sell_price=60,
            profit=20,
            profit_margin=0.5,
            quantity_available=100,
            source="arbitrage"
        )
        coordinator.trading.get_recommended_trades = MagicMock(
            return_value=[trade_opp]
        )
        
        result = await coordinator.get_next_economic_action(
            character_state, inventory, zeny
        )
        
        assert result["action"] == "trade"
        assert len(result["opportunities"]) > 0

    @pytest.mark.asyncio
    async def test_action_with_vending_opportunity(self, coordinator):
        """Test vending action recommendation."""
        character_state = {"level": 50}
        inventory = {
            "items": [
                {"item_id": 501, "name": "Red Potion", "amount": 100}
            ]
        }
        zeny = 100000
        
        # No purchases or trades, but vending profitable
        coordinator.buying.get_purchase_recommendations = MagicMock(
            return_value=[]
        )
        coordinator.trading.get_recommended_trades = MagicMock(
            return_value=[]
        )
        
        # Mock vending items and revenue
        vending_item = MagicMock(
            item_id=501,
            item_name="Red Potion",
            quantity=100,
            price=60
        )
        coordinator.vending.select_vending_items = MagicMock(
            return_value=[vending_item]
        )
        coordinator.vending.calculate_expected_revenue = MagicMock(
            return_value={"expected_profit": 15000}
        )
        
        result = await coordinator.get_next_economic_action(
            character_state, inventory, zeny
        )
        
        assert result["action"] == "vend"
        assert result["expected_revenue"]["expected_profit"] > 10000

    @pytest.mark.asyncio
    async def test_action_no_opportunities(self, coordinator):
        """Test wait action when no opportunities."""
        character_state = {"level": 50}
        inventory = {"items": []}
        zeny = 100000
        
        # No opportunities available
        coordinator.buying.get_purchase_recommendations = MagicMock(
            return_value=[]
        )
        coordinator.trading.get_recommended_trades = MagicMock(
            return_value=[]
        )
        coordinator.vending.select_vending_items = MagicMock(
            return_value=[]
        )
        
        result = await coordinator.get_next_economic_action(
            character_state, inventory, zeny
        )
        
        assert result["action"] == "wait"


class TestEvaluateNetWorth:
    """Test evaluate_net_worth method - lines 205-253."""

    def test_net_worth_calculation(self, coordinator):
        """Test net worth calculation."""
        inventory = {
            "items": [
                {"item_id": 501, "name": "Red Potion", "amount": 100},
                {"item_id": 502, "name": "Orange Potion", "amount": 50},
            ]
        }
        zeny = 100000
        
        # Mock market prices
        coordinator.market.get_current_price = MagicMock(
            side_effect=lambda item_id: {
                501: {"median_price": 50},
                502: {"median_price": 200}
            }.get(item_id)
        )
        
        result = coordinator.evaluate_net_worth(inventory, zeny)
        
        # 100*50 + 50*200 = 5000 + 10000 = 15000 inventory value
        # Total: 100000 + 15000 = 115000
        assert result["total_worth"] == 115000
        assert result["liquid_zeny"] == 100000
        assert result["inventory_value"] == 15000
        assert len(result["top_assets"]) == 2


class TestGetDailyReport:
    """Test get_daily_report method - lines 255-282."""

    def test_daily_report_generation(self, coordinator):
        """Test daily report generation."""
        # Mock intelligence methods
        coordinator.intelligence.analyze_market_health = MagicMock(
            return_value={"health_score": 85}
        )
        coordinator.intelligence.get_hot_items = MagicMock(
            return_value=[{"item_id": 501}]
        )
        coordinator.intelligence.get_undervalued_items = MagicMock(
            return_value=[{"item_id": 502}]
        )
        coordinator.intelligence.predict_market_events = MagicMock(
            return_value=[]
        )
        coordinator.intelligence.get_recent_alerts = MagicMock(
            return_value=[
                MagicMock(
                    alert_type="scam",
                    item_name="Fake Card",
                    severity="high",
                    description="Price too good to be true"
                )
            ]
        )
        
        report = coordinator.get_daily_report()
        
        assert "market_health" in report
        assert "hot_items" in report
        assert "undervalued_items" in report
        assert len(report["recent_alerts"]) > 0


class TestGetTradingSummary:
    """Test get_trading_summary method - lines 284-331."""

    def test_trading_summary(self, coordinator):
        """Test trading summary generation."""
        # Mock arbitrage opportunities
        arb_opp = MagicMock(
            item_id=501,
            item_name="Red Potion",
            profit=100,
            profit_margin=0.2,
            quantity_available=50
        )
        coordinator.trading.find_arbitrage_opportunities = MagicMock(
            return_value=[arb_opp]
        )
        
        # Mock flip opportunities
        flip_opp = MagicMock(
            item_id=502,
            item_name="Orange Potion",
            profit=200,
            profit_margin=0.3,
            quantity_available=30
        )
        coordinator.trading.find_flip_opportunities = MagicMock(
            return_value=[flip_opp]
        )
        
        summary = coordinator.get_trading_summary(days=7)
        
        assert summary["arbitrage_opportunities"] == 1
        assert summary["flip_opportunities"] == 1
        assert summary["total_opportunities"] == 2
        assert summary["total_potential_profit"] > 0


class TestGetProfitAnalysis:
    """Test get_profit_analysis method - lines 333-354."""

    def test_profit_analysis_structure(self, coordinator):
        """Test profit analysis returns correct structure."""
        result = coordinator.get_profit_analysis(days=7)
        
        assert "period_days" in result
        assert "total_income" in result
        assert "total_expenses" in result
        assert "net_profit" in result
        assert result["period_days"] == 7


class TestGetStatistics:
    """Test get_statistics method - lines 356-373."""

    def test_statistics_summary(self, coordinator):
        """Test statistics summary."""
        # Mock dependencies
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 100}
        )
        coordinator.intelligence.analyze_market_health = MagicMock(
            return_value={"health_score": 80}
        )
        coordinator.buying.purchase_targets = []
        coordinator.intelligence.alerts = []
        coordinator.market.price_history = {}
        coordinator.vending.locations = {}
        
        stats = coordinator.get_statistics()
        
        assert "market" in stats
        assert "health" in stats
        assert "purchase_targets" in stats


class TestAddPurchaseTarget:
    """Test add_purchase_target method - lines 375-411."""

    def test_add_purchase_target(self, coordinator):
        """Test adding purchase target."""
        coordinator.buying.add_purchase_target = MagicMock()
        
        coordinator.add_purchase_target(
            item_id=501,
            item_name="Red Potion",
            max_price=50,
            quantity=100,
            priority="high"
        )
        
        coordinator.buying.add_purchase_target.assert_called_once()


class TestCleanupOldData:
    """Test cleanup_old_data method - lines 413-434."""

    def test_cleanup_old_data(self, coordinator):
        """Test cleanup operation."""
        # Mock cleanup methods
        coordinator.market.cleanup_old_data = MagicMock(return_value=50)
        coordinator.intelligence.clear_old_alerts = MagicMock(return_value=10)
        
        result = coordinator.cleanup_old_data(days=30)
        
        assert result["market_entries_removed"] == 50
        assert result["alerts_cleared"] == 10
        assert result["total_cleaned"] == 60


class TestIntegrationScenarios:
    """Integration tests for complete workflows."""

    @pytest.mark.asyncio
    async def test_complete_trading_workflow(self, coordinator):
        """Test complete trading workflow."""
        # Setup market data
        listings = [
            {
                "item_id": 501,
                "item_name": "Red Potion",
                "seller": "Merchant1",
                "price": 40,
                "quantity": 100,
                "source": "player_shop",
                "map_name": "prontera"
            }
        ]
        
        coordinator.market.record_listing = MagicMock()
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 1}
        )
        coordinator.intelligence.detect_scam = MagicMock(return_value=None)
        coordinator.intelligence.detect_manipulation = MagicMock(return_value=None)
        
        # Update market
        update_result = await coordinator.update_market_data(listings)
        assert update_result["added"] > 0
        
        # Get statistics
        coordinator.market.get_market_stats = MagicMock(
            return_value={"total_listings": 1}
        )
        coordinator.intelligence.analyze_market_health = MagicMock(
            return_value={"health_score": 85}
        )
        coordinator.buying.purchase_targets = []
        coordinator.intelligence.alerts = []
        coordinator.market.price_history = {}
        coordinator.vending.locations = {}
        
        stats = coordinator.get_statistics()
        assert stats is not None

    @pytest.mark.asyncio
    async def test_profit_optimization_scenario(self, coordinator):
        """Test profit optimization scenario."""
        character_state = {"level": 75, "job": "Merchant"}
        inventory = {
            "items": [
                {"item_id": 501, "name": "Red Potion", "amount": 200}
            ]
        }
        zeny = 500000
        
        # Setup profitable vending
        coordinator.buying.get_purchase_recommendations = MagicMock(
            return_value=[]
        )
        coordinator.trading.get_recommended_trades = MagicMock(
            return_value=[]
        )
        
        vending_item = MagicMock(
            item_id=501,
            item_name="Red Potion",
            quantity=200,
            price=60
        )
        coordinator.vending.select_vending_items = MagicMock(
            return_value=[vending_item]
        )
        coordinator.vending.calculate_expected_revenue = MagicMock(
            return_value={"expected_profit": 20000}
        )
        
        # Get action
        action = await coordinator.get_next_economic_action(
            character_state, inventory, zeny
        )
        
        assert action["action"] == "vend"
        assert action["expected_revenue"]["expected_profit"] >= 10000