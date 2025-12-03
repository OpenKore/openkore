"""
Comprehensive tests for economy/intelligence.py module
Target: Boost coverage from 30.31% to 90%+
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, MagicMock

from ai_sidecar.economy.intelligence import EconomicIntelligence, MarketAlert
from ai_sidecar.economy.core import MarketListing, MarketSource, PriceHistory, PriceTrend


class TestEconomicIntelligenceInit:
    """Test initialization"""
    
    def test_init_creates_instance(self):
        """Test basic initialization"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        
        assert intelligence.market == market
        assert intelligence.analyzer == analyzer
        assert intelligence.trading == trading
        assert intelligence._alert_counter == 0
        assert intelligence.alerts == []


class TestDetectManipulation:
    """Test market manipulation detection"""
    
    def test_detect_manipulation_sudden_spike(self):
        """Test detection of sudden price spike (2x increase)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Setup price history with sudden spike (2x increase)
        # older_prices = [100, 105] => avg = 102.5
        # recent_prices = [110, 115, 120, 500, 520] => avg = 273 (> 205 = 102.5*2)
        history = PriceHistory(
            item_id=501,
            item_name="Red Potion",
            price_points=[
                (datetime.utcnow() - timedelta(days=6), 100, 10),
                (datetime.utcnow() - timedelta(days=5), 105, 12),
                (datetime.utcnow() - timedelta(days=4), 110, 8),
                (datetime.utcnow() - timedelta(days=3), 115, 15),
                (datetime.utcnow() - timedelta(days=2), 120, 20),
                (datetime.utcnow() - timedelta(days=1), 500, 25),  # Spike!
                (datetime.utcnow(), 520, 30),  # Continued spike
            ],
            avg_price=210,
            min_price=100,
            max_price=520,
            volatility=0.9
        )
        
        market.get_price_history.return_value = history
        market.listings = {}  # Initialize as empty dict so len() works
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_manipulation(501)
        
        assert alert is not None
        assert alert.alert_type == "manipulation"
        assert alert.severity == "high"
        assert alert.item_id == 501
        assert "spike" in alert.description.lower()
        assert len(intelligence.alerts) == 1
    
    def test_detect_manipulation_coordinated_pricing(self):
        """Test detection of coordinated pricing (50%+ at same price)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Enough history but no spike (stable prices)
        history = PriceHistory(
            item_id=502,
            item_name="Blue Potion",
            price_points=[
                (datetime.utcnow() - timedelta(days=6), 500, 10),
                (datetime.utcnow() - timedelta(days=5), 505, 12),
                (datetime.utcnow() - timedelta(days=4), 510, 8),
                (datetime.utcnow() - timedelta(days=3), 500, 15),
                (datetime.utcnow() - timedelta(days=2), 495, 20),
                (datetime.utcnow() - timedelta(days=1), 500, 25),
                (datetime.utcnow(), 505, 30),
            ],
            avg_price=502,
            min_price=495,
            max_price=510,
            volatility=0.01
        )
        
        # But many listings at same price (coordinated)
        listings = [
            MarketListing(
                listing_id=i,
                item_id=502,
                item_name="Blue Potion",
                quantity=10,
                price=500,  # 12 at price 500
                seller_name=f"Seller{i}",
                source=MarketSource.VENDING,
                timestamp=datetime.utcnow()
            ) for i in range(12)
        ]
        # Add a few at different price
        listings.extend([
            MarketListing(
                listing_id=i + 100,
                item_id=502,
                item_name="Blue Potion",
                quantity=10,
                price=480 + i * 10,
                seller_name=f"DifferentSeller{i}",
                source=MarketSource.VENDING,
                timestamp=datetime.utcnow()
            ) for i in range(3)
        ])
        
        market.get_price_history.return_value = history
        market.listings = {502: listings}
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_manipulation(502)
        
        assert alert is not None
        assert alert.alert_type == "manipulation"
        assert alert.severity == "medium"
        assert "coordinated" in alert.description.lower()
        assert alert.data["coordination_pct"] > 50
    
    def test_detect_manipulation_insufficient_data(self):
        """Test no detection with insufficient price history"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Too few data points
        history = PriceHistory(
            item_id=503,
            item_name="White Potion",
            price_points=[
                (datetime.utcnow(), 100, 10),
            ],
            avg_price=100,
            min_price=100,
            max_price=100,
            volatility=0.0
        )
        
        market.get_price_history.return_value = history
        market.listings = {503: []}
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_manipulation(503)
        
        assert alert is None
    
    def test_detect_manipulation_no_history(self):
        """Test no detection when no history available"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.get_price_history.return_value = None
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_manipulation(504)
        
        assert alert is None


class TestDetectScam:
    """Test scam detection"""
    
    def test_detect_scam_price_too_low(self):
        """Test scam detection for suspiciously low price"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=1,
            item_id=601,
            item_name="Rare Card",
            quantity=1,
            price=10,  # Way too cheap!
            seller_name="SuspiciousSeller",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        analyzer.detect_price_anomaly.return_value = (True, "price_too_low")
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_scam(listing)
        
        assert alert is not None
        assert alert.alert_type == "scam"
        assert alert.severity == "critical"
        assert alert.data["reason"] == "price_too_low"
    
    def test_detect_scam_price_too_high(self):
        """Test scam detection for suspiciously high price"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=2,
            item_id=602,
            item_name="Common Item",
            quantity=1,
            price=1000000,  # Way too expensive!
            seller_name="Scammer",
            source=MarketSource.AUCTION,
            timestamp=datetime.utcnow()
        )
        
        analyzer.detect_price_anomaly.return_value = (True, "price_too_high")
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_scam(listing)
        
        assert alert is not None
        assert alert.alert_type == "scam"
        assert alert.severity == "high"
        assert alert.data["reason"] == "price_too_high"
    
    def test_detect_scam_legitimate_price(self):
        """Test no scam alert for legitimate pricing"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=3,
            item_id=603,
            item_name="Normal Item",
            quantity=1,
            price=500,
            seller_name="HonestSeller",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        analyzer.detect_price_anomaly.return_value = (False, None)
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        alert = intelligence.detect_scam(listing)
        
        assert alert is None


class TestInvestmentOpportunities:
    """Test investment opportunity identification"""
    
    def test_identify_opportunities_rising_trend(self):
        """Test finding underpriced items with rising trend"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Setup rising trend item
        listing = MarketListing(
            listing_id=1,
            item_id=701,
            item_name="Investment Item",
            quantity=50,
            price=800,  # Below median of 1000
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        market.listings = {701: [listing]}
        market.get_trend.return_value = PriceTrend.RISING
        market.get_current_price.return_value = {
            "min_price": 800,
            "max_price": 1200,
            "median_price": 1000,
            "avg_price": 1050
        }
        
        trading.calculate_roi.return_value = {
            "recommended": True,
            "predicted_price": 1300,
            "expected_roi": 62.5,  # (1300-800)/800
            "confidence": 0.85
        }
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        opportunities = intelligence.identify_investment_opportunities(
            budget=10000,
            risk_tolerance=0.5
        )
        
        assert len(opportunities) > 0
        opp = opportunities[0]
        assert opp["item_id"] == 701
        assert opp["buy_price"] == 800
        assert opp["expected_roi"] == 62.5
        assert opp["trend"] == "rising"
    
    def test_identify_opportunities_filters_budget(self):
        """Test that opportunities respect budget constraint"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Two items, one too expensive
        cheap_listing = MarketListing(
            listing_id=1,
            item_id=702,
            item_name="Affordable",
            quantity=10,
            price=500,
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        expensive_listing = MarketListing(
            listing_id=2,
            item_id=703,
            item_name="Expensive",
            quantity=5,
            price=5000,  # Over budget!
            seller_name="Seller2",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        market.listings = {
            702: [cheap_listing],
            703: [expensive_listing]
        }
        
        def get_trend_side_effect(item_id):
            return PriceTrend.RISING_FAST
        
        def get_current_price_side_effect(item_id):
            if item_id == 702:
                return {"median_price": 600}
            return {"median_price": 6000}
        
        market.get_trend.side_effect = get_trend_side_effect
        market.get_current_price.side_effect = get_current_price_side_effect
        trading.calculate_roi.return_value = {
            "recommended": True,
            "predicted_price": 1000,
            "expected_roi": 50,
            "confidence": 0.7
        }
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        opportunities = intelligence.identify_investment_opportunities(
            budget=1000,
            risk_tolerance=0.5
        )
        
        # Should only get affordable item
        assert all(opp["buy_price"] <= 1000 for opp in opportunities)
    
    def test_identify_opportunities_empty_market(self):
        """Test with no viable opportunities"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {}
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        opportunities = intelligence.identify_investment_opportunities(
            budget=10000,
            risk_tolerance=0.5
        )
        
        assert opportunities == []


class TestMarketHealth:
    """Test market health analysis"""
    
    def test_analyze_market_health_bullish(self):
        """Test bullish market detection (60%+ rising)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Setup market with mostly rising items
        market.listings = {
            i: [Mock()] for i in range(1, 11)  # 10 items
        }
        
        market.get_market_stats.return_value = {
            "total_listings": 50,
            "unique_items": 10,
            "avg_price": 1000
        }
        
        def get_trend_side_effect(item_id):
            # 7 rising, 2 falling, 1 stable
            if item_id <= 7:
                return PriceTrend.RISING
            elif item_id <= 9:
                return PriceTrend.FALLING
            else:
                return PriceTrend.STABLE
        
        market.get_trend.side_effect = get_trend_side_effect
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        health = intelligence.analyze_market_health()
        
        assert health["health_status"] == "bullish"
        assert health["trend_distribution"]["rising"] == 7
        assert health["rising_percentage"] == 70.0
    
    def test_analyze_market_health_bearish(self):
        """Test bearish market detection (<30% rising)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {
            i: [Mock()] for i in range(1, 11)  # 10 items
        }
        
        market.get_market_stats.return_value = {
            "total_listings": 50,
            "unique_items": 10,
            "avg_price": 1000
        }
        
        def get_trend_side_effect(item_id):
            # 2 rising, 7 falling, 1 stable
            if item_id <= 2:
                return PriceTrend.RISING
            elif item_id <= 9:
                return PriceTrend.FALLING
            else:
                return PriceTrend.STABLE
        
        market.get_trend.side_effect = get_trend_side_effect
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        health = intelligence.analyze_market_health()
        
        assert health["health_status"] == "bearish"
        assert health["trend_distribution"]["falling"] == 7
    
    def test_analyze_market_health_unstable(self):
        """Test unstable market detection (40%+ volatile)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {
            i: [Mock()] for i in range(1, 11)  # 10 items
        }
        
        market.get_market_stats.return_value = {
            "total_listings": 50,
            "unique_items": 10,
            "avg_price": 1000
        }
        
        def get_trend_side_effect(item_id):
            # 5 volatile, 5 stable
            if item_id <= 5:
                return PriceTrend.VOLATILE
            else:
                return PriceTrend.STABLE
        
        market.get_trend.side_effect = get_trend_side_effect
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        health = intelligence.analyze_market_health()
        
        assert health["health_status"] == "unstable"
        assert health["volatile_percentage"] == 50.0
    
    def test_analyze_market_health_unknown(self):
        """Test unknown status with no data"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {}
        market.get_market_stats.return_value = {
            "total_listings": 0,
            "unique_items": 0,
            "avg_price": 0
        }
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        health = intelligence.analyze_market_health()
        
        assert health["health_status"] == "unknown"


class TestPredictMarketEvents:
    """Test market event prediction"""
    
    def test_predict_significant_price_changes(self):
        """Test prediction of significant price changes (>20%)"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {801: [Mock()], 802: [Mock()]}
        
        def get_trend_side_effect(item_id):
            return PriceTrend.RISING_FAST
        
        def get_current_price_side_effect(item_id):
            return {"median_price": 1000}
        
        market.get_trend.side_effect = get_trend_side_effect
        market.get_current_price.side_effect = get_current_price_side_effect
        
        # Predict significant increase
        analyzer.predict_price.return_value = (1300, 0.8)  # 30% increase
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        events = intelligence.predict_market_events(days_ahead=7)
        
        assert len(events) > 0
        event = events[0]
        assert event["event_type"] == "price_change"
        assert abs(event["change_percent"]) > 20
        assert event["confidence"] == 0.8
    
    def test_predict_filters_low_confidence(self):
        """Test that low confidence predictions are filtered out"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        market.listings = {803: [Mock()]}
        market.get_trend.return_value = PriceTrend.RISING_FAST
        market.get_current_price.return_value = {"median_price": 1000}
        
        # Low confidence prediction
        analyzer.predict_price.return_value = (1300, 0.4)
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        events = intelligence.predict_market_events(days_ahead=7)
        
        assert len(events) == 0


class TestHotItems:
    """Test hot items detection"""
    
    def test_get_hot_items_high_volume_rising(self):
        """Test detection of high volume + rising trend items"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=1,
            item_id=901,
            item_name="Hot Item",
            quantity=10,
            price=1000,
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        history = PriceHistory(
            item_id=901,
            item_name="Hot Item",
            price_points=[
                (datetime.utcnow() - timedelta(days=i), 1000, 50)
                for i in range(6, -1, -1)  # High volume
            ],
            avg_price=1000,
            min_price=900,
            max_price=1100,
            volatility=0.15
        )
        
        market.listings = {901: [listing]}
        market.get_price_history.return_value = history
        market.get_trend.return_value = PriceTrend.RISING_FAST
        market.get_current_price.return_value = {"median_price": 1000}
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        hot_items = intelligence.get_hot_items(limit=10)
        
        assert len(hot_items) > 0
        item = hot_items[0]
        assert item["item_id"] == 901
        assert item["volume"] > 100  # 50 * 7 = 350
        assert item["trend"] == "rising_fast"
    
    def test_get_hot_items_insufficient_history(self):
        """Test filtering of items with insufficient history"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=1,
            item_id=902,
            item_name="New Item",
            quantity=10,
            price=1000,
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        # Not enough data points
        history = PriceHistory(
            item_id=902,
            item_name="New Item",
            price_points=[
                (datetime.utcnow(), 1000, 50)
            ],
            avg_price=1000,
            min_price=1000,
            max_price=1000,
            volatility=0.0
        )
        
        market.listings = {902: [listing]}
        market.get_price_history.return_value = history
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        hot_items = intelligence.get_hot_items(limit=10)
        
        assert len(hot_items) == 0


class TestUndervaluedItems:
    """Test undervalued items detection"""
    
    def test_get_undervalued_items_significant_discount(self):
        """Test detection of items 30%+ below historical average"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=1,
            item_id=1001,
            item_name="Undervalued Item",
            quantity=5,
            price=600,  # Current
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        history = PriceHistory(
            item_id=1001,
            item_name="Undervalued Item",
            price_points=[
                (datetime.utcnow() - timedelta(days=i), 1000, 10)
                for i in range(29, -1, -1)
            ],
            avg_price=1000,  # Historical average
            min_price=900,
            max_price=1100,
            volatility=0.1
        )
        
        market.listings = {1001: [listing]}
        market.get_current_price.return_value = {"median_price": 600}
        market.get_price_history.return_value = history
        market.get_trend.return_value = PriceTrend.STABLE
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        undervalued = intelligence.get_undervalued_items(limit=10)
        
        assert len(undervalued) > 0
        item = undervalued[0]
        assert item["item_id"] == 1001
        assert item["current_price"] == 600
        assert item["historical_avg"] == 1000
        assert item["discount_percent"] == 40.0  # (1000-600)/1000
        assert item["potential_profit"] == 400
    
    def test_get_undervalued_items_no_history(self):
        """Test filtering when no price history available"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        listing = MarketListing(
            listing_id=1,
            item_id=1002,
            item_name="New Item",
            quantity=5,
            price=600,
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        market.listings = {1002: [listing]}
        market.get_current_price.return_value = {"median_price": 600}
        market.get_price_history.return_value = None  # No history
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        undervalued = intelligence.get_undervalued_items(limit=10)
        
        assert len(undervalued) == 0


class TestAlertManagement:
    """Test alert management functions"""
    
    def test_get_recent_alerts_all(self):
        """Test getting all recent alerts"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        
        # Add some alerts
        for i in range(5):
            alert = MarketAlert(
                alert_id=i,
                alert_type="test",
                item_id=i,
                item_name=f"Item{i}",
                description="Test alert",
                severity="low"
            )
            intelligence.alerts.append(alert)
        
        recent = intelligence.get_recent_alerts()
        
        assert len(recent) == 5
    
    def test_get_recent_alerts_filtered_by_severity(self):
        """Test filtering alerts by severity"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        
        # Add alerts with different severities
        severities = ["low", "medium", "high", "critical", "low"]
        for i, severity in enumerate(severities):
            alert = MarketAlert(
                alert_id=i,
                alert_type="test",
                item_id=i,
                item_name=f"Item{i}",
                description="Test alert",
                severity=severity
            )
            intelligence.alerts.append(alert)
        
        high_alerts = intelligence.get_recent_alerts(severity="high")
        
        assert len(high_alerts) == 1
        assert high_alerts[0].severity == "high"
    
    def test_clear_old_alerts(self):
        """Test clearing alerts older than threshold"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        
        # Add old and new alerts
        old_alert = MarketAlert(
            alert_id=1,
            alert_type="test",
            item_id=1,
            item_name="Item1",
            description="Old alert",
            severity="low",
            timestamp=datetime.utcnow() - timedelta(hours=48)
        )
        
        new_alert = MarketAlert(
            alert_id=2,
            alert_type="test",
            item_id=2,
            item_name="Item2",
            description="New alert",
            severity="low",
            timestamp=datetime.utcnow()
        )
        
        intelligence.alerts = [old_alert, new_alert]
        
        cleared = intelligence.clear_old_alerts(hours=24)
        
        assert cleared == 1
        assert len(intelligence.alerts) == 1
        assert intelligence.alerts[0].alert_id == 2


class TestMarketAlertModel:
    """Test MarketAlert model"""
    
    def test_market_alert_creation(self):
        """Test creating market alert"""
        alert = MarketAlert(
            alert_id=1,
            alert_type="price_spike",
            item_id=100,
            item_name="Test Item",
            description="Price increased 50%",
            severity="high",
            data={"increase": 50}
        )
        
        assert alert.alert_id == 1
        assert alert.alert_type == "price_spike"
        assert alert.item_id == 100
        assert alert.severity == "high"
        assert isinstance(alert.timestamp, datetime)
        assert alert.data["increase"] == 50


class TestIntegrationScenarios:
    """Test complete integration scenarios"""
    
    def test_complete_market_analysis_workflow(self):
        """Test complete workflow: health check, opportunities, alerts"""
        market = Mock()
        analyzer = Mock()
        trading = Mock()
        
        # Setup market data
        listing = MarketListing(
            listing_id=1,
            item_id=1101,
            item_name="Test Item",
            quantity=10,
            price=800,
            seller_name="Seller1",
            source=MarketSource.VENDING,
            timestamp=datetime.utcnow()
        )
        
        market.listings = {1101: [listing]}
        market.get_market_stats.return_value = {
            "total_listings": 10,
            "unique_items": 1,
            "avg_price": 800
        }
        market.get_trend.return_value = PriceTrend.RISING
        market.get_current_price.return_value = {"median_price": 1000}
        
        trading.calculate_roi.return_value = {
            "recommended": True,
            "predicted_price": 1200,
            "expected_roi": 50,
            "confidence": 0.8
        }
        
        intelligence = EconomicIntelligence(market, analyzer, trading)
        
        # Check market health
        health = intelligence.analyze_market_health()
        assert health["health_status"] in ["bullish", "bearish", "stable", "unstable"]
        
        # Find opportunities
        opportunities = intelligence.identify_investment_opportunities(
            budget=10000,
            risk_tolerance=0.5
        )
        assert isinstance(opportunities, list)
        
        # Get alerts
        alerts = intelligence.get_recent_alerts()
        assert isinstance(alerts, list)