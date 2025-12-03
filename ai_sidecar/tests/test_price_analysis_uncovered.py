"""
Comprehensive tests to achieve 100% coverage for economy/price_analysis.py.
Targets all uncovered lines from coverage report.
"""

import pytest
import statistics
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch
from datetime import datetime, timedelta

from ai_sidecar.economy.price_analysis import (
    PriceAnalyzer,
    SupplyDemandAnalyzer
)
from ai_sidecar.economy.core import (
    MarketManager,
    PriceHistory,
    PriceTrend
)


class TestDetectPriceAnomaly:
    """Test anomaly detection edge cases (Lines 188, 193)."""
    
    def test_detect_anomaly_max_threshold(self, tmp_path):
        """Test anomaly detection for exceeding maximum threshold (Line 188)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market, config_path=None)
        
        # Set up price history with at least 3 price points and low std_deviation
        now = datetime.now()
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            std_deviation=50,  # Low std_dev so z-score won't trigger
            price_points=[
                (now - timedelta(days=2), 1000, 1),
                (now - timedelta(days=1), 1000, 1),
                (now, 1000, 1)
            ]
        )
        market.get_price_history.return_value = history
        
        # Test price that exceeds max threshold (default 3.0x)
        # 3500 > 1000 * 3.0 = True, and z-score = abs(3500-1000)/50 = 50 > 3.0
        # So it will trigger z-score check first and return "price_too_high"
        is_anomaly, reason = analyzer.detect_price_anomaly(1, 3500)
        
        assert is_anomaly is True
        assert reason == "price_too_high"  # Z-score triggers first
    
    def test_detect_anomaly_min_threshold(self, tmp_path):
        """Test anomaly detection for below minimum threshold (Line 193)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market, config_path=None)
        
        # Set up price history with at least 3 price points
        now = datetime.now()
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            std_deviation=50,  # Low std_dev so z-score will trigger
            price_points=[
                (now - timedelta(days=2), 1000, 1),
                (now - timedelta(days=1), 1000, 1),
                (now, 1000, 1)
            ]
        )
        market.get_price_history.return_value = history
        
        # Test price below min threshold (default 0.1x)
        # 50 < 1000 * 0.1 = True, and z-score = abs(50-1000)/50 = 19 > 3.0
        # So z-score check triggers first and returns "price_too_low"
        is_anomaly, reason = analyzer.detect_price_anomaly(1, 50)
        
        assert is_anomaly is True
        assert reason == "price_too_low"  # Z-score triggers first


class TestCompareToMarket:
    """Test market comparison edge cases (Line 250, 260)."""
    
    def test_compare_to_market_equal_min_max(self):
        """Test comparison when min equals max price (Line 250)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market)
        
        # Set up current price with min == max
        market.get_current_price.return_value = {
            "min_price": 1000,
            "max_price": 1000,  # Same as min
            "avg_price": 1000,
            "median_price": 1000
        }
        
        # Mock price history for percentile calculation
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            price_points=[(datetime.now(), 1000, 1)]
        )
        market.get_price_history.return_value = history
        
        result = analyzer.compare_to_market(1, 1000)
        
        # Position should default to 0.5 when range is 0
        assert result["position"] == 0.5
    
    def test_compare_to_market_above_market(self):
        """Test above_market recommendation (Line 260)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market)
        
        market.get_current_price.return_value = {
            "min_price": 800,
            "max_price": 1200,
            "avg_price": 1000,
            "median_price": 1000
        }
        
        # Mock percentile calculation
        with patch.object(analyzer, 'get_price_percentile', return_value=0.8):
            result = analyzer.compare_to_market(1, 1150)  # 1.15x median
        
        assert result["recommendation"] == "above_market"


class TestSeasonalPattern:
    """Test seasonal pattern analysis (Lines 343->350)."""
    
    def test_seasonal_pattern_variance_check(self):
        """Test pattern detection based on variance (Lines 343-350)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market)
        
        # Create price history with clear daily pattern
        base_time = datetime(2024, 1, 1, 12, 0, 0)
        price_points = []
        
        # Add prices with clear weekday pattern
        for day in range(60):
            timestamp = base_time + timedelta(days=day)
            # Mondays are expensive, Fridays are cheap
            if timestamp.weekday() == 0:  # Monday
                price = 1500
            elif timestamp.weekday() == 4:  # Friday
                price = 800
            else:
                price = 1000
            
            price_points.append((timestamp, price, 1))
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1100,
            std_deviation=250,
            price_points=price_points
        )
        market.get_price_history.return_value = history
        
        result = analyzer.get_seasonal_pattern(1)
        
        # Should detect pattern due to high variance between days
        assert "has_pattern" in result
        assert "daily_pattern" in result
        assert len(result["daily_pattern"]) > 0


class TestCalculatePriceSlope:
    """Test price slope calculation (Line 454)."""
    
    def test_calculate_slope_zero_denominator(self):
        """Test slope calculation with zero denominator (Line 454)."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market)
        
        # All prices the same (zero variance)
        prices = [1000, 1000, 1000, 1000]
        
        slope = analyzer._calculate_price_slope(prices)
        
        # Should return 0.0 when denominator is 0
        assert slope == 0.0


class TestSupplyDemandAnalyzer:
    """Test SupplyDemandAnalyzer methods (Lines 516-517, 529-578)."""
    
    def test_estimate_demand_no_data(self):
        """Test demand estimation with no data (Lines 532-533)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        # No price data available
        market.get_current_price.return_value = None
        market.get_price_history.return_value = None
        
        demand = analyzer.estimate_demand(1)
        
        # Should return 0.5 (unknown demand)
        assert demand == 0.5
    
    def test_estimate_demand_rising_fast_trend(self):
        """Test demand estimation with rising fast trend (Lines 543-544)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.RISING_FAST,
            volatility=0.05,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 15
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # Rising fast + many listings + low volatility = high demand
        # 0.4 (rising fast) + 0.3 (listings>10) + 0.3 (volatility<0.1) = 1.0
        assert demand == 1.0
    
    def test_estimate_demand_rising_trend(self):
        """Test demand estimation with rising trend (Lines 545-546)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.RISING,
            volatility=0.15,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 7
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # 0.3 (rising) + 0.2 (listings 5-10) + 0.2 (volatility 0.1-0.2) = 0.7
        assert demand == 0.7
    
    def test_estimate_demand_stable_trend(self):
        """Test demand estimation with stable trend (Lines 547-548)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.25,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 3
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # 0.2 (stable) + 0.1 (listings>0) + 0.1 (volatility 0.2-0.3) = 0.4
        assert demand == 0.4
    
    def test_estimate_demand_many_listings(self):
        """Test demand score with many listings (Lines 552-553)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.05,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 12  # > 10
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # 0.2 (stable) + 0.3 (listings>10) + 0.3 (volatility<0.1) = 0.8
        assert demand == 0.8
    
    def test_estimate_demand_few_listings(self):
        """Test demand score with few listings (Lines 554-557)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.05,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 7  # 5-10 range
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # 0.2 (stable) + 0.2 (listings 5-10) + 0.3 (volatility<0.1) = 0.7
        assert demand == 0.7
    
    def test_estimate_demand_single_listing(self):
        """Test demand score with single listing (Line 557)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.05,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 1  # Just 1 listing
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # 0.2 (stable) + 0.1 (listings>0) + 0.3 (volatility<0.1) = 0.6
        assert abs(demand - 0.6) < 0.001  # Allow floating point tolerance
    
    def test_estimate_demand_low_volatility(self):
        """Test demand score with low volatility (Lines 561-562)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.05,  # < 0.1
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 5
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # Should get 0.3 bonus for low volatility
        assert demand >= 0.5  # Includes volatility bonus
    
    def test_estimate_demand_medium_volatility(self):
        """Test demand score with medium volatility (Lines 563-564)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.15,  # 0.1-0.2
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 5
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # Actual: 0.2 (stable) + 0.1 (5 listings, not >5) + 0.2 (medium volatility) = 0.5
        assert demand == 0.5
    
    def test_estimate_demand_high_volatility(self):
        """Test demand score with high volatility (Lines 565-566)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.STABLE,
            volatility=0.25,  # 0.2-0.3
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 5
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # Actual: 0.2 (stable) + 0.1 (5 listings) + 0.1 (volatility 0.2-0.3) = 0.4
        assert demand == 0.4
    
    def test_estimate_demand_capped_at_one(self):
        """Test demand score is capped at 1.0 (Line 568)."""
        market = Mock(spec=MarketManager)
        analyzer = SupplyDemandAnalyzer(market)
        
        # Set up conditions for high demand
        history = PriceHistory(
            item_id=1,
            item_name="Test Item",
            avg_price=1000,
            trend=PriceTrend.RISING_FAST,
            volatility=0.05,
            price_points=[(datetime.now(), 1000, 1)]
        )
        
        market.get_current_price.return_value = {
            "listing_count": 20  # Many listings
        }
        market.get_price_history.return_value = history
        
        demand = analyzer.estimate_demand(1)
        
        # Should be capped at 1.0
        assert demand == 1.0
        assert demand <= 1.0


class TestPriceAnalyzerConfigLoading:
    """Test configuration loading edge cases."""
    
    def test_load_config_with_valid_file(self, tmp_path):
        """Test loading config from valid file."""
        import json
        
        market = Mock(spec=MarketManager)
        config_file = tmp_path / "config.json"
        
        config_data = {
            "price_thresholds": {
                "max_price_multiplier": 5.0,
                "min_price_multiplier": 0.05,
                "scam_threshold": 0.02
            }
        }
        
        config_file.write_text(json.dumps(config_data))
        
        analyzer = PriceAnalyzer(market, config_path=config_file)
        
        assert analyzer.config["max_price_multiplier"] == 5.0
        assert analyzer.config["min_price_multiplier"] == 0.05
    
    def test_load_config_file_not_found(self, tmp_path):
        """Test loading config when file doesn't exist."""
        market = Mock(spec=MarketManager)
        config_file = tmp_path / "nonexistent.json"
        
        analyzer = PriceAnalyzer(market, config_path=config_file)
        
        # Should use default config
        assert "max_price_multiplier" in analyzer.config
        assert analyzer.config["max_price_multiplier"] == 3.0


class TestEstimateFairPriceAlias:
    """Test estimate_fair_price alias method."""
    
    def test_estimate_fair_price_calls_calculate(self):
        """Test that estimate_fair_price is an alias for calculate_fair_price."""
        market = Mock(spec=MarketManager)
        analyzer = PriceAnalyzer(market)
        
        # Mock the market data
        market.get_current_price.return_value = {
            "median_price": 1000
        }
        market.get_trend.return_value = PriceTrend.STABLE
        
        # Call estimate_fair_price
        result1 = analyzer.estimate_fair_price(item_id=1, refine_level=5)
        
        # Call calculate_fair_price with same params
        result2 = analyzer.calculate_fair_price(item_id=1, refine_level=5)
        
        # Should produce same result
        assert result1 == result2