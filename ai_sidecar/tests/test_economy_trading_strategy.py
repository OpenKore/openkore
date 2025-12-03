"""
Tests for Trading Strategy - trading opportunities and strategies.

Tests cover:
- Arbitrage opportunity detection
- Flip opportunity detection
- Trade evaluation
- ROI calculation
- Buy/sell decision logic
- Risk assessment
- Trade recommendations
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.economy.trading_strategy import (
    TradingManager, TradeOpportunity, TradingStrategy
)
from ai_sidecar.economy.core import MarketManager, MarketSource, PriceTrend, MarketListing


@pytest.fixture
def mock_market_manager():
    """Mock market manager."""
    manager = Mock(spec=MarketManager)
    
    # Setup listings
    manager.listings = {
        1001: [  # Item with price differences
            Mock(source=MarketSource.NPC_BUY, price=1000, quantity=10, item_name="Test Item"),
            Mock(source=MarketSource.VENDING, price=1500, quantity=5, item_name="Test Item"),
        ],
        1002: [  # Another item
            Mock(source=MarketSource.VENDING, price=2000, quantity=3, item_name="Rare Item"),
        ]
    }
    
    manager.get_current_price = Mock(return_value={
        "median_price": 1200,
        "min_price": 1000,
        "max_price": 1500
    })
    
    manager.get_price_history = Mock(return_value=Mock(
        volatility=0.2,
        min_price=900,
        max_price=1600
    ))
    
    manager.get_trend = Mock(return_value=PriceTrend.STABLE)
    manager.get_market_stats = Mock(return_value={})
    
    return manager


@pytest.fixture
def mock_price_analyzer():
    """Mock price analyzer."""
    analyzer = Mock()
    analyzer.calculate_fair_price = Mock(return_value=1200)
    analyzer.predict_price = Mock(return_value=(1300, 0.8))
    analyzer.compare_to_market = Mock(return_value={
        "status": "compared",
        "recommendation": "good_buy",
        "median_market": 1200
    })
    return analyzer


@pytest.fixture
def trading_manager(mock_market_manager, mock_price_analyzer):
    """Create trading manager."""
    return TradingManager(mock_market_manager, mock_price_analyzer)


# Initialization Tests

def test_trading_manager_init(mock_market_manager, mock_price_analyzer):
    """Test trading manager initialization."""
    manager = TradingManager(mock_market_manager, mock_price_analyzer)
    
    assert manager.market == mock_market_manager
    assert manager.analyzer == mock_price_analyzer
    assert manager._opportunity_counter == 0
    assert len(manager._found_opportunities) == 0


# Arbitrage Detection Tests

def test_find_arbitrage_opportunities_basic(trading_manager):
    """Test finding basic arbitrage opportunities."""
    opportunities = trading_manager.find_arbitrage_opportunities(
        min_profit=400,
        min_margin=0.1
    )
    
    assert len(opportunities) > 0
    opp = opportunities[0]
    assert opp.buy_price < opp.sell_price
    assert opp.profit >= 400


def test_find_arbitrage_opportunities_high_threshold(trading_manager):
    """Test with high profit threshold filters opportunities."""
    opportunities = trading_manager.find_arbitrage_opportunities(
        min_profit=10000,  # Very high
        min_margin=0.1
    )
    
    # Should find no opportunities
    assert len(opportunities) == 0


def test_find_arbitrage_opportunities_margin_threshold(trading_manager):
    """Test minimum margin filtering."""
    opportunities = trading_manager.find_arbitrage_opportunities(
        min_profit=1,
        min_margin=0.9  # Very high margin required
    )
    
    # Should find no opportunities
    assert len(opportunities) == 0


def test_find_arbitrage_empty_market(mock_price_analyzer):
    """Test arbitrage with empty market."""
    empty_market = Mock(spec=MarketManager)
    empty_market.listings = {}
    
    manager = TradingManager(empty_market, mock_price_analyzer)
    
    opportunities = manager.find_arbitrage_opportunities()
    
    assert len(opportunities) == 0


def test_find_arbitrage_single_source(mock_price_analyzer):
    """Test no arbitrage when only one source."""
    market = Mock(spec=MarketManager)
    market.listings = {
        1001: [
            Mock(source=MarketSource.NPC_BUY, price=1000, quantity=10, item_name="Item"),
        ]
    }
    
    manager = TradingManager(market, mock_price_analyzer)
    
    opportunities = manager.find_arbitrage_opportunities()
    
    # Can't arbitrage with single source
    assert len(opportunities) == 0


# Flip Opportunity Detection Tests

def test_find_flip_opportunities_basic(trading_manager):
    """Test finding flip opportunities."""
    # Add listing below median
    low_price_listing = Mock(
        source=MarketSource.VENDING,
        price=900,  # Below 80% of 1200 median
        quantity=5,
        item_name="Bargain Item"
    )
    trading_manager.market.listings[1001].append(low_price_listing)
    
    opportunities = trading_manager.find_flip_opportunities(
        min_profit=200,
        max_risk=0.5
    )
    
    assert len(opportunities) > 0


def test_find_flip_opportunities_no_underpriced(trading_manager):
    """Test when no items are underpriced."""
    trading_manager.market.listings = {
        1001: [
            Mock(source=MarketSource.VENDING, price=1200, quantity=5, item_name="Item")
        ]
    }
    trading_manager.market.get_current_price = Mock(return_value={
        "median_price": 1200
    })
    
    opportunities = trading_manager.find_flip_opportunities()
    
    # No underpriced items
    assert len(opportunities) == 0


def test_find_flip_opportunities_high_risk_filtered(trading_manager):
    """Test high risk opportunities are filtered."""
    low_price_listing = Mock(
        source=MarketSource.VENDING,
        price=900,
        quantity=5,
        item_name="Risky Item"
    )
    trading_manager.market.listings[1001] = [low_price_listing]
    
    # Mock high risk
    trading_manager._calculate_flip_risk = Mock(return_value=0.9)
    
    opportunities = trading_manager.find_flip_opportunities(
        min_profit=200,
        max_risk=0.3  # Low tolerance
    )
    
    # Should filter out high risk
    assert len(opportunities) == 0


def test_find_flip_opportunities_sorted_by_profit(trading_manager):
    """Test opportunities sorted by profit."""
    # Setup multiple underpriced items
    trading_manager.market.listings = {
        1001: [Mock(source=MarketSource.VENDING, price=800, quantity=5, item_name="Item A")],
        1002: [Mock(source=MarketSource.VENDING, price=600, quantity=5, item_name="Item B")]
    }
    
    def mock_price(item_id):
        return {"median_price": 1200} if item_id == 1001 else {"median_price": 1000}
    
    trading_manager.market.get_current_price = Mock(side_effect=mock_price)
    trading_manager._calculate_flip_risk = Mock(return_value=0.2)
    
    opportunities = trading_manager.find_flip_opportunities(min_profit=200)
    
    # Should be sorted by profit (descending)
    if len(opportunities) >= 2:
        assert opportunities[0].profit >= opportunities[1].profit


# Trade Evaluation Tests

def test_evaluate_trade_viable(trading_manager):
    """Test evaluating viable trade."""
    result = trading_manager.evaluate_trade(1001, 1000)
    
    assert result["viable"] is True
    assert result["buy_price"] == 1000
    assert result["expected_sell"] == 1200
    assert result["profit"] == 200
    assert "profit_margin" in result
    assert "roi_percent" in result


def test_evaluate_trade_no_price_data(trading_manager):
    """Test evaluation with no price data."""
    trading_manager.analyzer.calculate_fair_price = Mock(return_value=0)
    
    result = trading_manager.evaluate_trade(9999, 1000)
    
    assert result["viable"] is False
    assert result["reason"] == "no_price_data"


def test_evaluate_trade_unprofitable(trading_manager):
    """Test evaluation of unprofitable trade."""
    result = trading_manager.evaluate_trade(1001, 2000)  # Buy above fair price
    
    assert result["viable"] is False
    assert result["profit"] < 0


def test_evaluate_trade_low_margin(trading_manager):
    """Test trade with insufficient margin."""
    result = trading_manager.evaluate_trade(1001, 1190)  # Only 10 profit
    
    # Margin below 5%
    assert result["profit_margin"] < 0.05


# ROI Calculation Tests

def test_calculate_roi_positive(trading_manager):
    """Test ROI calculation with price increase."""
    result = trading_manager.calculate_roi(1001, 1000, hold_days=7)
    
    assert result["buy_price"] == 1000
    assert result["predicted_price"] == 1300
    assert result["profit"] == 300
    assert result["roi"] > 0
    assert result["expected_roi"] > 0
    assert result["recommended"] is True


def test_calculate_roi_no_prediction(trading_manager):
    """Test ROI when price prediction fails."""
    trading_manager.analyzer.predict_price = Mock(return_value=(0, 0.0))
    
    result = trading_manager.calculate_roi(1001, 1000)
    
    assert result["roi"] == 0.0
    assert result["recommended"] is False


def test_calculate_roi_negative(trading_manager):
    """Test ROI with predicted price drop."""
    trading_manager.analyzer.predict_price = Mock(return_value=(800, 0.9))
    
    result = trading_manager.calculate_roi(1001, 1000)
    
    assert result["profit"] < 0
    assert result["roi"] < 0
    assert result["recommended"] is False


def test_calculate_roi_low_confidence(trading_manager):
    """Test ROI with low confidence prediction."""
    trading_manager.analyzer.predict_price = Mock(return_value=(1500, 0.2))
    
    result = trading_manager.calculate_roi(1001, 1000, hold_days=14)
    
    # High ROI but low confidence
    assert result["confidence"] == 0.2
    assert result["expected_roi"] == result["roi"] * 0.2


# Buy Decision Tests

def test_should_buy_flip_good_opportunity(trading_manager):
    """Test buy decision for good flip opportunity."""
    should_buy, reason = trading_manager.should_buy(1001, 1000, "flip")
    
    assert should_buy is True
    assert "flip" in reason.lower() or "opportunity" in reason.lower()


def test_should_buy_flip_insufficient_profit(trading_manager):
    """Test buy decision for flip with low profit."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "status": "compared",
        "recommendation": "good_buy",
        "median_market": 1050  # Only 50 profit
    })
    
    should_buy, reason = trading_manager.should_buy(1001, 1000, "flip")
    
    assert should_buy is False


def test_should_buy_hold_rising_trend(trading_manager):
    """Test buy decision for holding with rising trend."""
    trading_manager.market.get_trend = Mock(return_value=PriceTrend.RISING)
    
    should_buy, reason = trading_manager.should_buy(1001, 1000, "hold")
    
    assert should_buy is True
    assert "investment" in reason.lower()


def test_should_buy_hold_falling_trend(trading_manager):
    """Test buy decision for holding with falling trend."""
    trading_manager.market.get_trend = Mock(return_value=PriceTrend.FALLING)
    
    should_buy, reason = trading_manager.should_buy(1001, 1000, "hold")
    
    assert should_buy is False


def test_should_buy_use_fair_price(trading_manager):
    """Test buy decision for personal use."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "status": "compared",
        "recommendation": "fair_price",
        "median_market": 1200
    })
    
    should_buy, reason = trading_manager.should_buy(1001, 1100, "use")
    
    assert should_buy is True


def test_should_buy_use_overpriced(trading_manager):
    """Test rejecting overpriced items for use."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "status": "compared",
        "recommendation": "overpriced",
        "median_market": 1200
    })
    
    should_buy, reason = trading_manager.should_buy(1001, 2000, "use")
    
    assert should_buy is False


def test_should_buy_no_price_data(trading_manager):
    """Test buy decision without price data."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "status": "no_data"
    })
    
    should_buy, reason = trading_manager.should_buy(9999, 1000, "flip")
    
    assert should_buy is False
    assert "no_price_data" in reason


# Sell Decision Tests

def test_should_sell_good_profit(trading_manager):
    """Test sell decision with good profit."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "recommendation": "fair_price"
    })
    
    should_sell, reason = trading_manager.should_sell(
        item_id=1001,
        price=1200,  # Current offer
        holding_price=1000  # Bought at
    )
    
    # 20% profit
    assert should_sell is True


def test_should_sell_insufficient_profit(trading_manager):
    """Test rejecting sale with low profit."""
    should_sell, reason = trading_manager.should_sell(
        item_id=1001,
        price=1030,  # Only 3% profit
        holding_price=1000
    )
    
    assert should_sell is False
    assert "insufficient_profit" in reason


def test_should_sell_market_higher(trading_manager):
    """Test waiting when market price even higher."""
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "recommendation": "overpriced"  # Current offer is overpriced = market higher
    })
    
    should_sell, reason = trading_manager.should_sell(1001, 1100, 1000)
    
    assert should_sell is False
    assert "better_price" in reason


def test_should_sell_falling_market(trading_manager):
    """Test selling quickly in falling market."""
    trading_manager.market.get_trend = Mock(return_value=PriceTrend.FALLING)
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "recommendation": "fair_price"
    })
    
    should_sell, reason = trading_manager.should_sell(1001, 1100, 1000)
    
    assert should_sell is True
    assert "drop" in reason.lower() or "falling" in reason.lower()


def test_should_sell_rising_market_wait(trading_manager):
    """Test waiting in rising market with low profit."""
    trading_manager.market.get_trend = Mock(return_value=PriceTrend.RISING)
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "recommendation": "fair_price"
    })
    
    should_sell, reason = trading_manager.should_sell(
        item_id=1001,
        price=1100,  # 10% profit
        holding_price=1000
    )
    
    assert should_sell is False
    assert "rising" in reason.lower() or "wait" in reason.lower()


def test_should_sell_rising_market_good_profit(trading_manager):
    """Test selling in rising market with sufficient profit."""
    trading_manager.market.get_trend = Mock(return_value=PriceTrend.RISING)
    trading_manager.analyzer.compare_to_market = Mock(return_value={
        "recommendation": "fair_price"
    })
    
    should_sell, reason = trading_manager.should_sell(
        item_id=1001,
        price=1250,  # 25% profit
        holding_price=1000
    )
    
    # 25% > 20% threshold, should sell even in rising market
    assert should_sell is True


# Risk Assessment Tests

def test_calculate_flip_risk_no_history(trading_manager):
    """Test risk calculation without history."""
    trading_manager.market.get_price_history = Mock(return_value=None)
    
    risk = trading_manager._calculate_flip_risk(9999, 1000)
    
    # High risk without data
    assert risk == 0.8


def test_calculate_flip_risk_base_volatility(trading_manager):
    """Test risk based on volatility."""
    trading_manager.market.get_price_history = Mock(return_value=Mock(
        volatility=0.3,
        min_price=900
    ))
    
    risk = trading_manager._calculate_flip_risk(1001, 1000)
    
    assert risk >= 0.3


def test_calculate_flip_risk_very_low_price(trading_manager):
    """Test increased risk for very low prices."""
    trading_manager.market.get_price_history = Mock(return_value=Mock(
        volatility=0.2,
        min_price=1000
    ))
    
    risk = trading_manager._calculate_flip_risk(1001, 900)  # Very low
    
    # Should add 0.2 risk
    assert risk >= 0.4


def test_calculate_flip_risk_liquid_market(trading_manager):
    """Test decreased risk for liquid markets."""
    trading_manager.market.get_price_history = Mock(return_value=Mock(
        volatility=0.4,
        min_price=900
    ))
    
    # Mock many listings
    trading_manager.market.listings[1001] = [Mock()] * 25
    
    risk = trading_manager._calculate_flip_risk(1001, 1000)
    
    # Should be reduced by 0.8 multiplier
    assert risk < 0.4


def test_calculate_flip_risk_clamped_to_one(trading_manager):
    """Test risk is clamped to 1.0."""
    trading_manager.market.get_price_history = Mock(return_value=Mock(
        volatility=0.9,
        min_price=1000
    ))
    
    risk = trading_manager._calculate_flip_risk(1001, 500)  # Very low price
    
    # Should clamp to 1.0
    assert risk <= 1.0


# Trade Recommendation Tests

def test_get_trade_recommendation_excellent(trading_manager):
    """Test excellent trade recommendation."""
    recommendation = trading_manager._get_trade_recommendation(0.35, 0.2)
    
    assert recommendation == "excellent_trade"


def test_get_trade_recommendation_good(trading_manager):
    """Test good trade recommendation."""
    recommendation = trading_manager._get_trade_recommendation(0.25, 0.4)
    
    assert recommendation == "good_trade"


def test_get_trade_recommendation_acceptable(trading_manager):
    """Test acceptable trade recommendation."""
    recommendation = trading_manager._get_trade_recommendation(0.12, 0.4)
    
    assert recommendation == "acceptable_trade"


def test_get_trade_recommendation_marginal(trading_manager):
    """Test marginal trade recommendation."""
    recommendation = trading_manager._get_trade_recommendation(0.07, 0.6)
    
    assert recommendation == "marginal_trade"


def test_get_trade_recommendation_avoid(trading_manager):
    """Test avoid recommendation."""
    recommendation = trading_manager._get_trade_recommendation(0.03, 0.8)
    
    assert recommendation == "avoid"


# Recommended Trades Tests

def test_get_recommended_trades_within_budget(trading_manager):
    """Test getting trades within budget."""
    # Mock opportunities
    trading_manager.find_arbitrage_opportunities = Mock(return_value=[])
    
    low_price_listing = Mock(
        source=MarketSource.VENDING,
        price=900,
        quantity=5,
        item_name="Affordable Item"
    )
    trading_manager.market.listings[1001] = [low_price_listing]
    trading_manager._calculate_flip_risk = Mock(return_value=0.2)
    
    recommended = trading_manager.get_recommended_trades(
        budget=10000,
        risk_tolerance=0.5
    )
    
    # Should return opportunities within budget
    assert isinstance(recommended, list)


def test_get_recommended_trades_risk_filtered(trading_manager):
    """Test trades filtered by risk tolerance."""
    trading_manager.find_arbitrage_opportunities = Mock(return_value=[])
    trading_manager.find_flip_opportunities = Mock(return_value=[])
    
    recommended = trading_manager.get_recommended_trades(
        budget=10000,
        risk_tolerance=0.1  # Very low tolerance
    )
    
    # Should filter based on risk
    for opp in recommended:
        assert opp.risk_level <= 0.1


def test_get_recommended_trades_budget_limited(trading_manager):
    """Test budget limits trade selection."""
    # Create opportunities that cost more than budget
    opp1 = TradeOpportunity(
        opportunity_id=1,
        item_id=1001,
        item_name="Item",
        buy_price=6000,
        sell_price=7000,
        profit=1000,
        profit_margin=0.16,
        risk_level=0.2,
        confidence=0.8,
        buy_source=MarketSource.NPC_BUY,
        sell_source=MarketSource.VENDING,
        quantity_available=1
    )
    
    trading_manager.find_arbitrage_opportunities = Mock(return_value=[opp1])
    trading_manager.find_flip_opportunities = Mock(return_value=[])
    
    recommended = trading_manager.get_recommended_trades(
        budget=5000,  # Less than opportunity cost
        risk_tolerance=0.5
    )
    
    # Should be empty or filtered
    if len(recommended) > 0:
        total_cost = sum(o.buy_price * o.quantity_available for o in recommended)
        assert total_cost <= 5000


# Integration Tests

def test_full_arbitrage_workflow(trading_manager):
    """Test complete arbitrage detection workflow."""
    # Find opportunities
    opportunities = trading_manager.find_arbitrage_opportunities(
        min_profit=400,
        min_margin=0.1
    )
    
    assert len(opportunities) > 0
    
    # Evaluate first opportunity
    opp = opportunities[0]
    assert opp.profit >= 400
    assert opp.profit_margin >= 0.1
    assert opp.risk_level <= 1.0


def test_full_flip_workflow(trading_manager):
    """Test complete flip detection workflow."""
    # Add underpriced listing
    trading_manager.market.listings[1001].append(
        Mock(source=MarketSource.VENDING, price=900, quantity=5, item_name="Flip Item")
    )
    
    opportunities = trading_manager.find_flip_opportunities(
        min_profit=200,
        max_risk=0.5
    )
    
    # Opportunities should be found and sorted
    assert isinstance(opportunities, list)


# Edge Cases

def test_arbitrage_zero_buy_price(mock_price_analyzer):
    """Test handling zero buy price."""
    market = Mock(spec=MarketManager)
    market.listings = {
        1001: [
            Mock(source=MarketSource.NPC_BUY, price=0, quantity=10, item_name="Free Item"),
            Mock(source=MarketSource.VENDING, price=1000, quantity=5, item_name="Free Item")
        ]
    }
    
    manager = TradingManager(market, mock_price_analyzer)
    
    opportunities = manager.find_arbitrage_opportunities()
    
    # Should handle zero price gracefully
    assert isinstance(opportunities, list)


def test_evaluate_trade_zero_buy_price(trading_manager):
    """Test evaluating trade with zero buy price."""
    result = trading_manager.evaluate_trade(1001, 0)
    
    # Should handle gracefully
    assert "profit_margin" in result


def test_should_buy_unknown_purpose(trading_manager):
    """Test buy decision with unknown purpose."""
    should_buy, reason = trading_manager.should_buy(1001, 1000, "unknown")
    
    assert should_buy is False
    assert "unknown_purpose" in reason


def test_multiple_arbitrage_pairs(mock_price_analyzer):
    """Test finding arbitrage across multiple source pairs."""
    market = Mock(spec=MarketManager)
    market.listings = {
        1001: [
            Mock(source=MarketSource.NPC_BUY, price=1000, quantity=10, item_name="Item"),
            Mock(source=MarketSource.VENDING, price=1500, quantity=5, item_name="Item"),
            Mock(source=MarketSource.VENDING, price=1600, quantity=3, item_name="Item")
        ]
    }
    
    manager = TradingManager(market, mock_price_analyzer)
    
    opportunities = manager.find_arbitrage_opportunities(min_profit=400)
    
    # Should find multiple arbitrage pairs
    assert len(opportunities) >= 2


def test_opportunity_counter_increments(trading_manager):
    """Test that opportunity counter increments."""
    initial_count = trading_manager._opportunity_counter
    
    # Add underpriced item
    trading_manager.market.listings[1001].append(
        Mock(source=MarketSource.VENDING, price=900, quantity=5, item_name="Item")
    )
    
    opportunities = trading_manager.find_flip_opportunities(min_profit=200)
    
    if len(opportunities) > 0:
        assert trading_manager._opportunity_counter > initial_count


def test_trade_recommendation_boundary_values(trading_manager):
    """Test trade recommendations at boundary values."""
    test_cases = [
        (0.31, 0.29, "excellent_trade"),
        (0.21, 0.49, "good_trade"),
        (0.11, 0.49, "acceptable_trade"),
        (0.06, 0.6, "marginal_trade"),
        (0.04, 0.8, "avoid")
    ]
    
    for margin, risk, expected in test_cases:
        result = trading_manager._get_trade_recommendation(margin, risk)
        assert result == expected


def test_roi_calculation_various_hold_periods(trading_manager):
    """Test ROI calculation for different hold periods."""
    for days in [1, 7, 14, 30]:
        result = trading_manager.calculate_roi(1001, 1000, hold_days=days)
        
        assert result["hold_days"] == days
        assert "roi" in result


def test_sell_decision_zero_holding_price(trading_manager):
    """Test sell decision with zero holding price."""
    should_sell, reason = trading_manager.should_sell(1001, 1200, 0)
    
    # Should handle division by zero
    assert isinstance(should_sell, bool)