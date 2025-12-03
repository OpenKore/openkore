"""
Comprehensive tests for price_analysis.py - covering all uncovered lines.
Target: 100% coverage of price analysis, prediction, and anomaly detection.
"""

import pytest
import statistics
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.core import MarketManager, PriceTrend


@pytest.fixture
def mock_market_manager():
    """Create mock market manager."""
    market = Mock(spec=MarketManager)
    market.get_current_price = Mock(return_value=None)
    market.get_price_history = Mock(return_value=None)
    market.get_trend = Mock(return_value=PriceTrend.STABLE)
    return market


@pytest.fixture
def price_analyzer(mock_market_manager):
    """Create price analyzer instance."""
    return PriceAnalyzer(mock_market_manager)


@pytest.fixture
def mock_price_history():
    """Create mock price history."""
    history = Mock()
    history.price_points = [
        (datetime.now() - timedelta(days=i), 1000 + (i * 10), 1)
        for i in range(30)
    ]
    history.avg_price = 1150
    history.std_deviation = 100
    history.volatility = 0.1
    history.trend = PriceTrend.STABLE
    return history


class TestPriceAnalyzerInit:
    """Test PriceAnalyzer initialization."""

    def test_init_without_config(self, mock_market_manager):
        """Test init without config file."""
        analyzer = PriceAnalyzer(mock_market_manager)
        assert analyzer.market == mock_market_manager
        assert analyzer.config is not None

    def test_init_with_config(self, mock_market_manager, tmp_path):
        """Test init with config file."""
        config_file = tmp_path / "config.json"
        config_file.write_text('{"price_thresholds": {"max_price_multiplier": 5.0}}')
        
        analyzer = PriceAnalyzer(mock_market_manager, config_file)
        assert analyzer.config["max_price_multiplier"] == 5.0

    def test_init_with_invalid_config(self, mock_market_manager, tmp_path):
        """Test init with invalid config file."""
        config_file = tmp_path / "config.json"
        config_file.write_text('invalid json')
        
        analyzer = PriceAnalyzer(mock_market_manager, config_file)
        assert analyzer.config == {}

    def test_init_with_missing_config(self, mock_market_manager, tmp_path):
        """Test init with missing config file."""
        config_file = tmp_path / "missing.json"
        analyzer = PriceAnalyzer(mock_market_manager, config_file)
        assert "max_price_multiplier" in analyzer.config


class TestFairPriceCalculation:
    """Test fair price calculation."""

    def test_calculate_fair_price_no_data(self, price_analyzer):
        """Test fair price with no market data."""
        price_analyzer.market.get_current_price.return_value = None
        
        price = price_analyzer.calculate_fair_price(1001)
        assert price == 0

    def test_calculate_fair_price_base(self, price_analyzer):
        """Test basic fair price calculation."""
        price_analyzer.market.get_current_price.return_value = {
            "median_price": 1000
        }
        
        price = price_analyzer.calculate_fair_price(1001)
        assert price > 0

    def test_calculate_fair_price_with_refine(self, price_analyzer):
        """Test fair price with refine level."""
        price_analyzer.market.get_current_price.return_value = {
            "median_price": 1000
        }
        
        base_price = price_analyzer.calculate_fair_price(1001, refine_level=0)
        refined_price = price_analyzer.calculate_fair_price(1001, refine_level=7)
        
        assert refined_price > base_price

    def test_calculate_fair_price_with_cards(self, price_analyzer):
        """Test fair price with cards."""
        price_analyzer.market.get_current_price.return_value = {
            "median_price": 1000
        }
        
        base_price = price_analyzer.calculate_fair_price(1001, cards=[])
        with_cards = price_analyzer.calculate_fair_price(1001, cards=[4001, 4002])
        
        assert with_cards > base_price

    def test_calculate_refine_value(self, price_analyzer):
        """Test refine value calculation."""
        # Test various refine levels
        assert price_analyzer._calculate_refine_value(1000, 0) == 0
        assert price_analyzer._calculate_refine_value(1000, 1) > 0
        assert price_analyzer._calculate_refine_value(1000, 7) > 0
        assert price_analyzer._calculate_refine_value(1000, 10) > 0
        
        # Higher refines should add more value
        val_7 = price_analyzer._calculate_refine_value(1000, 7)
        val_10 = price_analyzer._calculate_refine_value(1000, 10)
        assert val_10 > val_7

    def test_calculate_card_value_empty(self, price_analyzer):
        """Test card value with no cards."""
        value = price_analyzer._calculate_card_value([])
        assert value == 0

    def test_calculate_card_value_with_cards(self, price_analyzer):
        """Test card value calculation."""
        price_analyzer.market.get_current_price.side_effect = [
            {"median_price": 500},
            {"median_price": 1000},
        ]
        
        value = price_analyzer._calculate_card_value([4001, 4002])
        assert value > 0

    def test_calculate_card_value_missing_prices(self, price_analyzer):
        """Test card value with missing prices."""
        price_analyzer.market.get_current_price.return_value = None
        
        value = price_analyzer._calculate_card_value([4001, 4002])
        assert value == 0

    def test_get_trend_multiplier(self, price_analyzer):
        """Test trend multiplier calculation."""
        price_analyzer.market.get_trend.return_value = PriceTrend.RISING_FAST
        mult = price_analyzer._get_trend_multiplier(1001)
        assert mult > 1.0
        
        price_analyzer.market.get_trend.return_value = PriceTrend.FALLING_FAST
        mult = price_analyzer._get_trend_multiplier(1001)
        assert mult < 1.0
        
        price_analyzer.market.get_trend.return_value = PriceTrend.STABLE
        mult = price_analyzer._get_trend_multiplier(1001)
        assert mult == 1.0


class TestPricePrediction:
    """Test price prediction."""

    def test_predict_price_no_data(self, price_analyzer):
        """Test prediction with no data."""
        price_analyzer.market.get_price_history.return_value = None
        price_analyzer.market.get_current_price.return_value = {"median_price": 1000}
        
        predicted, confidence = price_analyzer.predict_price(1001)
        assert predicted == 1000
        assert confidence == 0.0

    def test_predict_price_insufficient_data(self, price_analyzer):
        """Test prediction with insufficient data."""
        history = Mock()
        history.price_points = [(datetime.now(), 1000, 1) for _ in range(5)]
        price_analyzer.market.get_price_history.return_value = history
        price_analyzer.market.get_current_price.return_value = {"median_price": 1000}
        
        predicted, confidence = price_analyzer.predict_price(1001)
        assert predicted == 1000
        assert confidence == 0.0

    def test_predict_price_with_data(self, price_analyzer, mock_price_history):
        """Test prediction with sufficient data."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        predicted, confidence = price_analyzer.predict_price(1001, days_ahead=7)
        assert predicted > 0
        assert 0 <= confidence <= 1.0

    def test_calculate_price_slope(self, price_analyzer):
        """Test price slope calculation."""
        # Upward trend
        prices = [100, 110, 120, 130, 140]
        slope = price_analyzer._calculate_price_slope(prices)
        assert slope > 0
        
        # Downward trend
        prices = [140, 130, 120, 110, 100]
        slope = price_analyzer._calculate_price_slope(prices)
        assert slope < 0
        
        # Flat
        prices = [100, 100, 100, 100]
        slope = price_analyzer._calculate_price_slope(prices)
        assert abs(slope) < 1

    def test_calculate_price_slope_insufficient_data(self, price_analyzer):
        """Test slope with insufficient data."""
        slope = price_analyzer._calculate_price_slope([100])
        assert slope == 0.0

    def test_calculate_price_slope_zero_denominator(self, price_analyzer):
        """Test slope with zero denominator."""
        prices = [100, 100]
        slope = price_analyzer._calculate_price_slope(prices)
        assert slope == 0.0


class TestAnomalyDetection:
    """Test anomaly detection."""

    def test_detect_anomaly_insufficient_data(self, price_analyzer):
        """Test anomaly with insufficient data."""
        history = Mock()
        history.price_points = [(datetime.now(), 1000, 1)]
        price_analyzer.market.get_price_history.return_value = history
        
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1001, 2000)
        assert not is_anomaly
        assert reason == "insufficient_data"

    def test_detect_anomaly_price_too_high(self, price_analyzer, mock_price_history):
        """Test detecting price too high."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1001, 5000)
        assert is_anomaly
        assert "too_high" in reason or "threshold" in reason

    def test_detect_anomaly_price_too_low(self, price_analyzer, mock_price_history):
        """Test detecting price too low."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1001, 50)
        assert is_anomaly
        assert "too_low" in reason or "threshold" in reason

    def test_detect_anomaly_normal_price(self, price_analyzer, mock_price_history):
        """Test normal price detection."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        is_anomaly, reason = price_analyzer.detect_price_anomaly(1001, 1150)
        assert not is_anomaly
        assert reason == "normal"


class TestPricePercentile:
    """Test price percentile calculation."""

    def test_get_price_percentile_no_data(self, price_analyzer):
        """Test percentile with no data."""
        price_analyzer.market.get_price_history.return_value = None
        
        percentile = price_analyzer.get_price_percentile(1001, 1000)
        assert percentile == 0.5

    def test_get_price_percentile_with_data(self, price_analyzer, mock_price_history):
        """Test percentile calculation."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        percentile = price_analyzer.get_price_percentile(1001, 1000)
        assert 0 <= percentile <= 1.0

    def test_get_price_percentile_lowest(self, price_analyzer, mock_price_history):
        """Test percentile for lowest price."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        percentile = price_analyzer.get_price_percentile(1001, 0)
        assert percentile == 0.0

    def test_get_price_percentile_highest(self, price_analyzer, mock_price_history):
        """Test percentile for highest price."""
        price_analyzer.market.get_price_history.return_value = mock_price_history
        
        percentile = price_analyzer.get_price_percentile(1001, 10000)
        assert percentile == 1.0


class TestMarketComparison:
    """Test market comparison."""

    def test_compare_to_market_no_data(self, price_analyzer):
        """Test comparison with no market data."""
        price_analyzer.market.get_current_price.return_value = None
        
        result = price_analyzer.compare_to_market(1001, 1000)
        assert result["status"] == "no_data"
        assert result["recommendation"] == "unknown"

    def test_compare_to_market_excellent_buy(self, price_analyzer):
        """Test excellent buy recommendation."""
        price_analyzer.market.get_current_price.return_value = {
            "min_price": 900,
            "max_price": 1500,
            "avg_price": 1200,
            "median_price": 1200,
        }
        
        with patch.object(price_analyzer, 'get_price_percentile', return_value=0.3):
            result = price_analyzer.compare_to_market(1001, 1000)
        
        assert result["status"] == "compared"
        assert result["recommendation"] == "excellent_buy"

    def test_compare_to_market_overpriced(self, price_analyzer):
        """Test overpriced recommendation."""
        price_analyzer.market.get_current_price.return_value = {
            "min_price": 900,
            "max_price": 1500,
            "avg_price": 1000,
            "median_price": 1000,
        }
        
        with patch.object(price_analyzer, 'get_price_percentile', return_value=0.9):
            result = price_analyzer.compare_to_market(1001, 1500)
        
        assert result["recommendation"] == "overpriced"

    def test_compare_to_market_fair_price(self, price_analyzer):
        """Test fair price recommendation."""
        price_analyzer.market.get_current_price.return_value = {
            "min_price": 900,
            "max_price": 1100,
            "avg_price": 1000,
            "median_price": 1000,
        }
        
        with patch.object(price_analyzer, 'get_price_percentile', return_value=0.5):
            result = price_analyzer.compare_to_market(1001, 1020)
        
        assert result["recommendation"] == "fair_price"


class TestSeasonalPattern:
    """Test seasonal pattern detection."""

    def test_get_seasonal_pattern_insufficient_data(self, price_analyzer):
        """Test pattern with insufficient data."""
        history = Mock()
        history.price_points = [(datetime.now(), 1000, 1) for _ in range(5)]
        price_analyzer.market.get_price_history.return_value = history
        
        result = price_analyzer.get_seasonal_pattern(1001)
        assert result["has_pattern"] is False

    def test_get_seasonal_pattern_with_data(self, price_analyzer):
        """Test pattern detection with data."""
        # Create price data spanning days of week
        price_points = []
        base_date = datetime(2024, 1, 1)  # Monday
        for i in range(90):
            date = base_date + timedelta(days=i)
            price = 1000 + (i % 7) * 10  # Weekly pattern
            price_points.append((date, price, 1))
        
        history = Mock()
        history.price_points = price_points
        history.std_deviation = 50
        price_analyzer.market.get_price_history.return_value = history
        
        result = price_analyzer.get_seasonal_pattern(1001)
        assert "has_pattern" in result
        assert "daily_pattern" in result
        assert "time_pattern" in result

    def test_get_seasonal_pattern_time_of_day(self, price_analyzer):
        """Test pattern detection by time of day."""
        price_points = []
        base_date = datetime(2024, 1, 1, 8, 0)  # Morning
        for i in range(90):
            date = base_date + timedelta(hours=i)
            price = 1000
            price_points.append((date, price, 1))
        
        history = Mock()
        history.price_points = price_points
        history.std_deviation = 10
        price_analyzer.market.get_price_history.return_value = history
        
        result = price_analyzer.get_seasonal_pattern(1001)
        assert "time_pattern" in result


class TestConfigLoading:
    """Test configuration loading."""

    def test_load_config_missing_file(self, price_analyzer):
        """Test loading missing config."""
        config = price_analyzer._load_config(Path("missing.json"))
        assert "max_price_multiplier" in config
        assert "min_price_multiplier" in config

    def test_load_config_valid_file(self, mock_market_manager, tmp_path):
        """Test loading valid config."""
        config_file = tmp_path / "config.json"
        config_data = {
            "price_thresholds": {
                "max_price_multiplier": 4.0,
                "min_price_multiplier": 0.2,
            }
        }
        import json
        config_file.write_text(json.dumps(config_data))
        
        analyzer = PriceAnalyzer(mock_market_manager, config_file)
        assert analyzer.config["max_price_multiplier"] == 4.0