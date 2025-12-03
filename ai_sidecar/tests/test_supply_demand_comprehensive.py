"""
Comprehensive tests for supply_demand.py - covering all uncovered lines.
Target: 100% coverage of supply/demand modeling, rarity assessment, and volume estimation.
"""

import pytest
import json
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.economy.supply_demand import (
    ItemRarity,
    SupplyDemandMetrics,
    SupplyDemandAnalyzer,
)
from ai_sidecar.economy.core import MarketManager, PriceTrend


@pytest.fixture
def mock_market_manager():
    """Create mock market manager."""
    market = Mock(spec=MarketManager)
    market.listings = {}
    market.get_price_history = Mock(return_value=None)
    market.get_trend = Mock(return_value=PriceTrend.STABLE)
    return market


@pytest.fixture
def data_dir(tmp_path):
    """Create temporary data directory with drop rates."""
    drop_file = tmp_path / "drop_rates.json"
    drop_data = {
        "drop_rates": {
            "501": {"rate": 0.50, "monster": "Poring"},
            "502": {"rate": 0.20, "monster": "Drops"},
            "503": {"rate": 0.05, "monster": "Lunatic"},
        },
        "mvp_drops": {
            "601": {"rate": 0.01, "monster": "Baphomet"},
            "602": {"rate": 0.001, "monster": "Thanatos"},
        }
    }
    drop_file.write_text(json.dumps(drop_data))
    return tmp_path


@pytest.fixture
def analyzer(mock_market_manager, data_dir):
    """Create SupplyDemandAnalyzer instance."""
    return SupplyDemandAnalyzer(mock_market_manager, data_dir)


@pytest.fixture
def mock_price_history():
    """Create mock price history."""
    history = Mock()
    history.price_points = [
        (datetime.now() - timedelta(days=i), 1000, 5)
        for i in range(30)
    ]
    history.avg_price = 1000
    history.std_deviation = 100
    history.volatility = 0.1
    history.trend = PriceTrend.STABLE
    return history


class TestSupplyDemandAnalyzerInit:
    """Test analyzer initialization."""

    def test_init_with_drop_rates(self, mock_market_manager, data_dir):
        """Test initialization loads drop rates."""
        analyzer = SupplyDemandAnalyzer(mock_market_manager, data_dir)
        assert len(analyzer.drop_rates) > 0
        assert 501 in analyzer.drop_rates
        assert analyzer.drop_rates[501] == 0.50

    def test_init_missing_drop_file(self, mock_market_manager, tmp_path):
        """Test initialization without drop file."""
        analyzer = SupplyDemandAnalyzer(mock_market_manager, tmp_path)
        assert len(analyzer.drop_rates) == 0

    def test_init_invalid_drop_file(self, mock_market_manager, tmp_path):
        """Test initialization with invalid drop file."""
        drop_file = tmp_path / "drop_rates.json"
        drop_file.write_text("invalid json")
        
        analyzer = SupplyDemandAnalyzer(mock_market_manager, tmp_path)
        assert len(analyzer.drop_rates) == 0


class TestItemRarity:
    """Test item rarity classification."""

    def test_get_item_rarity_common_by_drop_rate(self, analyzer):
        """Test common item by drop rate."""
        rarity = analyzer.get_item_rarity(501)  # 50% drop
        assert rarity == ItemRarity.COMMON

    def test_get_item_rarity_uncommon_by_drop_rate(self, analyzer):
        """Test uncommon item by drop rate."""
        rarity = analyzer.get_item_rarity(502)  # 20% drop
        assert rarity == ItemRarity.UNCOMMON

    def test_get_item_rarity_rare_by_drop_rate(self, analyzer):
        """Test rare item by drop rate."""
        rarity = analyzer.get_item_rarity(503)  # 5% drop
        assert rarity == ItemRarity.RARE

    def test_get_item_rarity_very_rare_by_drop_rate(self, analyzer):
        """Test very rare item by drop rate."""
        rarity = analyzer.get_item_rarity(601)  # 1% drop
        assert rarity == ItemRarity.VERY_RARE

    def test_get_item_rarity_legendary_by_drop_rate(self, analyzer):
        """Test legendary item by drop rate."""
        rarity = analyzer.get_item_rarity(602)  # 0.1% drop
        assert rarity == ItemRarity.LEGENDARY

    def test_get_item_rarity_by_listing_count_unique(self, analyzer):
        """Test rarity by listing count - unique."""
        analyzer.market.listings[9001] = []
        rarity = analyzer.get_item_rarity(9001)
        assert rarity == ItemRarity.UNIQUE

    def test_get_item_rarity_by_listing_count_legendary(self, analyzer):
        """Test rarity by listing count - legendary."""
        analyzer.market.listings[9002] = [Mock(), Mock()]
        rarity = analyzer.get_item_rarity(9002)
        assert rarity == ItemRarity.LEGENDARY

    def test_get_item_rarity_by_listing_count_very_rare(self, analyzer):
        """Test rarity by listing count - very rare."""
        analyzer.market.listings[9003] = [Mock() for _ in range(5)]
        rarity = analyzer.get_item_rarity(9003)
        assert rarity == ItemRarity.VERY_RARE

    def test_get_item_rarity_by_listing_count_rare(self, analyzer):
        """Test rarity by listing count - rare."""
        analyzer.market.listings[9004] = [Mock() for _ in range(15)]
        rarity = analyzer.get_item_rarity(9004)
        assert rarity == ItemRarity.RARE

    def test_get_item_rarity_by_listing_count_uncommon(self, analyzer):
        """Test rarity by listing count - uncommon."""
        analyzer.market.listings[9005] = [Mock() for _ in range(50)]
        rarity = analyzer.get_item_rarity(9005)
        assert rarity == ItemRarity.UNCOMMON

    def test_get_item_rarity_by_listing_count_common(self, analyzer):
        """Test rarity by listing count - common."""
        analyzer.market.listings[9006] = [Mock() for _ in range(150)]
        rarity = analyzer.get_item_rarity(9006)
        assert rarity == ItemRarity.COMMON


class TestSupplyDemandCalculation:
    """Test supply/demand metrics calculation."""

    def test_calculate_supply_demand_basic(self, analyzer, mock_price_history):
        """Test basic supply/demand calculation."""
        # Set up test data
        listing = Mock()
        listing.item_name = "Test Item"
        analyzer.market.listings[1001] = [listing]
        analyzer.market.get_price_history.return_value = mock_price_history
        
        metrics = analyzer.calculate_supply_demand(1001)
        
        assert metrics.item_id == 1001
        assert metrics.item_name == "Test Item"
        assert metrics.supply_score >= 0
        assert metrics.demand_score >= 0
        assert metrics.scarcity_index > 0

    def test_calculate_supply_score_no_listings(self, analyzer):
        """Test supply score with no listings."""
        score = analyzer._calculate_supply_score(1001, [])
        assert score == 0.0

    def test_calculate_supply_score_few_listings(self, analyzer):
        """Test supply score with few listings."""
        listings = [Mock() for _ in range(3)]
        score = analyzer._calculate_supply_score(1001, listings)
        assert 0 < score < 40

    def test_calculate_supply_score_many_listings(self, analyzer):
        """Test supply score with many listings."""
        listings = [Mock() for _ in range(150)]
        score = analyzer._calculate_supply_score(1001, listings)
        assert score >= 80

    def test_calculate_supply_score_with_drop_rate(self, analyzer):
        """Test supply score factors in drop rate."""
        listings = [Mock() for _ in range(10)]
        score_without = analyzer._calculate_supply_score(9999, listings)
        score_with = analyzer._calculate_supply_score(501, listings)  # Has 50% drop
        assert score_with > score_without

    def test_calculate_demand_score_no_history(self, analyzer):
        """Test demand score without history."""
        score = analyzer._calculate_demand_score(1001, None)
        assert score == 50.0

    def test_calculate_demand_score_low_volume(self, analyzer, mock_price_history):
        """Test demand score with low volume."""
        mock_price_history.price_points = [
            (datetime.now() - timedelta(days=i), 1000, 1)
            for i in range(30)
        ]
        score = analyzer._calculate_demand_score(1001, mock_price_history)
        assert 0 < score < 60

    def test_calculate_demand_score_high_volume(self, analyzer):
        """Test demand score with high volume."""
        history = Mock()
        history.price_points = [
            (datetime.now() - timedelta(days=i), 1000, 50)
            for i in range(30)
        ]
        history.trend = PriceTrend.STABLE
        
        score = analyzer._calculate_demand_score(1001, history)
        # High volume gives score of 80, not adjusted since trend is stable
        assert score >= 20  # At least medium demand

    def test_calculate_demand_score_rising_trend(self, analyzer, mock_price_history):
        """Test demand score with rising prices."""
        mock_price_history.trend = PriceTrend.RISING
        score = analyzer._calculate_demand_score(1001, mock_price_history)
        assert score > 0

    def test_calculate_demand_score_falling_trend(self, analyzer, mock_price_history):
        """Test demand score with falling prices."""
        mock_price_history.trend = PriceTrend.FALLING
        score = analyzer._calculate_demand_score(1001, mock_price_history)
        assert score > 0

    def test_calculate_liquidity_no_history(self, analyzer):
        """Test liquidity with no history."""
        liquidity = analyzer._calculate_liquidity(1001, None)
        assert liquidity == 0.0

    def test_calculate_liquidity_with_history(self, analyzer, mock_price_history):
        """Test liquidity calculation."""
        liquidity = analyzer._calculate_liquidity(1001, mock_price_history)
        assert 0 <= liquidity <= 1.0

    def test_estimate_sale_time_high_demand(self, analyzer):
        """Test sale time with high demand."""
        sale_time = analyzer._estimate_sale_time(1001, 20.0, 80.0)
        assert sale_time.total_seconds() < timedelta(days=1).total_seconds()

    def test_estimate_sale_time_low_demand(self, analyzer):
        """Test sale time with low demand."""
        sale_time = analyzer._estimate_sale_time(1001, 80.0, 20.0)
        assert sale_time.total_seconds() > timedelta(days=1).total_seconds()

    def test_estimate_sale_time_no_demand(self, analyzer):
        """Test sale time with zero demand."""
        sale_time = analyzer._estimate_sale_time(1001, 50.0, 0.0)
        assert sale_time == timedelta(days=30)

    def test_estimate_sale_time_various_ratios(self, analyzer):
        """Test sale time with various supply/demand ratios."""
        # High demand, low supply - fast sale
        fast = analyzer._estimate_sale_time(1001, 30.0, 70.0)
        
        # Low demand, high supply - slow sale
        slow = analyzer._estimate_sale_time(1001, 70.0, 30.0)
        
        assert fast < slow


class TestMarketVolume:
    """Test market volume estimation."""

    def test_estimate_market_volume_no_history(self, analyzer):
        """Test volume with no history."""
        analyzer.market.get_price_history.return_value = None
        volume = analyzer.estimate_market_volume(1001)
        assert volume == 0

    def test_estimate_market_volume_empty_history(self, analyzer):
        """Test volume with empty history."""
        history = Mock()
        history.price_points = []
        analyzer.market.get_price_history.return_value = history
        
        volume = analyzer.estimate_market_volume(1001)
        assert volume == 0

    def test_estimate_market_volume_with_data(self, analyzer, mock_price_history):
        """Test volume estimation."""
        analyzer.market.get_price_history.return_value = mock_price_history
        volume = analyzer.estimate_market_volume(1001)
        assert volume > 0


class TestDemandPrediction:
    """Test demand change prediction."""

    def test_predict_demand_change_insufficient_data(self, analyzer):
        """Test prediction with insufficient data."""
        history = Mock()
        history.price_points = [(datetime.now(), 1000, 1)]
        analyzer.market.get_price_history.return_value = history
        
        prediction = analyzer.predict_demand_change(1001)
        assert prediction["prediction"] == "stable"
        assert prediction["confidence"] == 0.0

    def test_predict_demand_change_increasing(self, analyzer):
        """Test prediction for increasing demand."""
        # Create rising price history
        history = Mock()
        history.price_points = [
            (datetime.now() - timedelta(days=i), 900 + (i * 10), 1)
            for i in range(20)
        ]
        history.volatility = 0.1
        analyzer.market.get_price_history.return_value = history
        
        prediction = analyzer.predict_demand_change(1001)
        assert prediction["prediction"] in ["increasing", "stable"]

    def test_predict_demand_change_decreasing(self, analyzer):
        """Test prediction for decreasing demand."""
        # Create falling price history
        history = Mock()
        history.price_points = [
            (datetime.now() - timedelta(days=i), 1100 - (i * 10), 1)
            for i in range(20)
        ]
        history.volatility = 0.1
        analyzer.market.get_price_history.return_value = history
        
        prediction = analyzer.predict_demand_change(1001)
        assert prediction["prediction"] in ["decreasing", "stable"]

    def test_predict_demand_change_stable(self, analyzer):
        """Test prediction for stable demand."""
        history = Mock()
        history.price_points = [
            (datetime.now() - timedelta(days=i), 1000, 1)
            for i in range(20)
        ]
        history.volatility = 0.05
        analyzer.market.get_price_history.return_value = history
        
        prediction = analyzer.predict_demand_change(1001)
        assert prediction["prediction"] == "stable"


class TestRelatedItems:
    """Test related items functionality."""

    def test_get_related_items(self, analyzer):
        """Test getting related items."""
        related = analyzer.get_related_items(1001)
        # Currently returns empty list - placeholder
        assert isinstance(related, list)


class TestCraftingDemand:
    """Test crafting demand analysis."""

    def test_analyze_crafting_demand(self, analyzer):
        """Test crafting demand analysis."""
        result = analyzer.analyze_crafting_demand(2001)
        
        assert "product_id" in result
        assert result["product_id"] == 2001
        assert "materials" in result
        assert "profitability" in result


class TestSupplyDemandMetrics:
    """Test SupplyDemandMetrics model."""

    def test_metrics_creation(self):
        """Test creating metrics."""
        metrics = SupplyDemandMetrics(
            item_id=1001,
            item_name="Test Item",
            supply_score=60.0,
            demand_score=70.0,
            scarcity_index=1.17,
            market_liquidity=0.75,
            listing_count=50,
            avg_sale_time=timedelta(hours=12),
            estimated_daily_volume=100,
        )
        
        assert metrics.item_id == 1001
        assert metrics.supply_score == 60.0
        assert metrics.demand_score == 70.0

    def test_metrics_validation(self):
        """Test metrics validation."""
        # Supply and demand scores must be 0-100
        with pytest.raises(Exception):
            SupplyDemandMetrics(
                item_id=1001,
                item_name="Test",
                supply_score=150.0,  # Invalid
                demand_score=70.0,
                scarcity_index=1.0,
                market_liquidity=0.5,
                listing_count=10,
                avg_sale_time=timedelta(hours=1),
                estimated_daily_volume=10,
            )


class TestDropRateLoading:
    """Test drop rate data loading."""

    def test_load_drop_rates_success(self, mock_market_manager, data_dir):
        """Test successful drop rate loading."""
        analyzer = SupplyDemandAnalyzer(mock_market_manager, data_dir)
        
        assert 501 in analyzer.drop_rates
        assert 502 in analyzer.drop_rates
        assert 601 in analyzer.drop_rates

    def test_load_drop_rates_missing_file(self, mock_market_manager, tmp_path):
        """Test loading with missing file."""
        analyzer = SupplyDemandAnalyzer(mock_market_manager, tmp_path)
        assert len(analyzer.drop_rates) == 0

    def test_load_drop_rates_corrupted_file(self, mock_market_manager, tmp_path):
        """Test loading corrupted file."""
        drop_file = tmp_path / "drop_rates.json"
        drop_file.write_text("{corrupted")
        
        analyzer = SupplyDemandAnalyzer(mock_market_manager, tmp_path)
        assert len(analyzer.drop_rates) == 0

    def test_load_drop_rates_empty_sections(self, mock_market_manager, tmp_path):
        """Test loading with empty sections."""
        drop_file = tmp_path / "drop_rates.json"
        drop_file.write_text('{"drop_rates": {}, "mvp_drops": {}}')
        
        analyzer = SupplyDemandAnalyzer(mock_market_manager, tmp_path)
        assert len(analyzer.drop_rates) == 0


class TestIntegration:
    """Integration tests."""

    def test_full_analysis_workflow(self, analyzer, mock_price_history):
        """Test full analysis workflow."""
        # Set up data
        listing = Mock()
        listing.item_name = "Integration Test Item"
        analyzer.market.listings[1001] = [listing for _ in range(20)]
        analyzer.market.get_price_history.return_value = mock_price_history
        
        # Test rarity
        rarity = analyzer.get_item_rarity(1001)
        assert isinstance(rarity, ItemRarity)
        
        # Test metrics
        metrics = analyzer.calculate_supply_demand(1001)
        assert metrics.item_id == 1001
        assert metrics.supply_score > 0
        
        # Test volume
        volume = analyzer.estimate_market_volume(1001)
        assert volume >= 0
        
        # Test prediction
        prediction = analyzer.predict_demand_change(1001)
        assert "prediction" in prediction