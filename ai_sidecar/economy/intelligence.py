"""
Economic Intelligence - Market intelligence and alerting system.

Features:
- Market manipulation detection
- Scam prevention
- Opportunity alerts
- Investment recommendations
"""

from datetime import datetime
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketListing, MarketManager
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.trading_strategy import TradingManager

logger = structlog.get_logger(__name__)


class MarketAlert(BaseModel):
    """Market alert notification"""
    alert_id: int
    alert_type: str  # price_drop, price_spike, opportunity, manipulation
    item_id: int
    item_name: str
    description: str
    severity: str  # low, medium, high, critical
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    data: dict = Field(default_factory=dict)


class EconomicIntelligence:
    """
    Economic intelligence and alerting system.
    
    Features:
    - Market manipulation detection
    - Scam prevention
    - Opportunity alerts
    - Investment recommendations
    """
    
    def __init__(
        self,
        market_manager: MarketManager,
        price_analyzer: PriceAnalyzer,
        trading_manager: TradingManager
    ):
        """
        Initialize economic intelligence.
        
        Args:
            market_manager: Market data manager
            price_analyzer: Price analyzer
            trading_manager: Trading manager
        """
        self.log = logger.bind(system="economic_intelligence")
        self.market = market_manager
        self.analyzer = price_analyzer
        self.trading = trading_manager
        
        # Alert tracking
        self._alert_counter = 0
        self.alerts: List[MarketAlert] = []
        
        self.log.info("economic_intelligence_initialized")
    
    def detect_manipulation(self, item_id: int) -> Optional[MarketAlert]:
        """
        Detect potential market manipulation.
        
        Args:
            item_id: Item ID to check
            
        Returns:
            Market alert if manipulation detected
        """
        history = self.market.get_price_history(item_id, days=7)
        
        if not history or len(history.price_points) < 10:
            return None
        
        # Check for sudden price spikes
        prices = [p for _, p, _ in history.price_points]
        recent_prices = prices[-5:]
        older_prices = prices[:-5]
        
        if not older_prices or not recent_prices:
            return None
        
        import statistics
        avg_old = statistics.mean(older_prices)
        avg_recent = statistics.mean(recent_prices)
        
        # Detect manipulation patterns
        if avg_recent > avg_old * 2.0:
            # Sudden 2x price increase
            self._alert_counter += 1
            
            alert = MarketAlert(
                alert_id=self._alert_counter,
                alert_type="manipulation",
                item_id=item_id,
                item_name=history.item_name,
                description="Sudden price spike detected - possible manipulation",
                severity="high",
                data={
                    "old_avg": int(avg_old),
                    "new_avg": int(avg_recent),
                    "increase_pct": ((avg_recent - avg_old) / avg_old * 100)
                }
            )
            
            self.alerts.append(alert)
            
            self.log.warning(
                "manipulation_detected",
                item_id=item_id,
                old_avg=int(avg_old),
                new_avg=int(avg_recent)
            )
            
            return alert
        
        # Check for coordinated buying (many listings at same price)
        listings = self.market.listings.get(item_id, [])
        
        if len(listings) > 10:
            prices_count: Dict[int, int] = {}
            for listing in listings:
                prices_count[listing.price] = prices_count.get(listing.price, 0) + 1
            
            # If more than 50% at same price, suspicious
            max_count = max(prices_count.values())
            if max_count / len(listings) > 0.5:
                self._alert_counter += 1
                
                alert = MarketAlert(
                    alert_id=self._alert_counter,
                    alert_type="manipulation",
                    item_id=item_id,
                    item_name=listings[0].item_name,
                    description="Coordinated pricing detected",
                    severity="medium",
                    data={
                        "listing_count": len(listings),
                        "same_price_count": max_count,
                        "coordination_pct": (max_count / len(listings) * 100)
                    }
                )
                
                self.alerts.append(alert)
                
                return alert
        
        return None
    
    def detect_scam(self, listing: MarketListing) -> Optional[MarketAlert]:
        """
        Detect potential scam listing.
        
        Args:
            listing: Market listing to check
            
        Returns:
            Market alert if scam detected
        """
        item_id = listing.item_id
        price = listing.price
        
        # Check for price anomalies
        is_anomaly, reason = self.analyzer.detect_price_anomaly(item_id, price)
        
        if is_anomaly:
            severity = "critical" if reason == "price_too_low" else "high"
            
            self._alert_counter += 1
            
            alert = MarketAlert(
                alert_id=self._alert_counter,
                alert_type="scam",
                item_id=item_id,
                item_name=listing.item_name,
                description=f"Suspicious pricing: {reason}",
                severity=severity,
                data={
                    "price": price,
                    "seller": listing.seller_name,
                    "reason": reason,
                    "source": listing.source.value
                }
            )
            
            self.alerts.append(alert)
            
            self.log.warning(
                "scam_detected",
                item_id=item_id,
                price=price,
                reason=reason
            )
            
            return alert
        
        return None
    
    def identify_investment_opportunities(
        self,
        budget: int,
        risk_tolerance: float
    ) -> List[dict]:
        """
        Identify investment opportunities.
        
        Args:
            budget: Available budget
            risk_tolerance: Risk tolerance (0-1)
            
        Returns:
            List of investment recommendations
        """
        opportunities: List[dict] = []
        
        # Look for undervalued items with rising trends
        for item_id, listings in self.market.listings.items():
            if not listings:
                continue
            
            # Get trend
            trend = self.market.get_trend(item_id)
            
            if trend.value not in ["rising", "rising_fast"]:
                continue
            
            # Get current price
            current_price = self.market.get_current_price(item_id)
            
            if not current_price:
                continue
            
            median = current_price["median_price"]
            
            # Find underpriced listings
            underpriced = [l for l in listings if l.price < median * 0.85]
            
            if not underpriced:
                continue
            
            # Calculate ROI
            cheapest = min(underpriced, key=lambda l: l.price)
            roi_data = self.trading.calculate_roi(
                item_id,
                cheapest.price,
                hold_days=7
            )
            
            if roi_data["recommended"]:
                opportunities.append({
                    "item_id": item_id,
                    "item_name": cheapest.item_name,
                    "buy_price": cheapest.price,
                    "current_market": median,
                    "predicted_price": roi_data["predicted_price"],
                    "expected_roi": roi_data["expected_roi"],
                    "confidence": roi_data["confidence"],
                    "trend": trend.value,
                    "seller": cheapest.seller_name,
                    "quantity_available": cheapest.quantity
                })
        
        # Sort by expected ROI
        opportunities.sort(key=lambda o: o["expected_roi"], reverse=True)
        
        # Filter by budget
        affordable = [
            opp for opp in opportunities
            if opp["buy_price"] <= budget
        ]
        
        self.log.info(
            "investment_opportunities_identified",
            count=len(affordable),
            budget=budget
        )
        
        return affordable[:10]  # Top 10
    
    def analyze_market_health(self) -> dict:
        """
        Analyze overall market health.
        
        Returns:
            Dict with market health metrics
        """
        stats = self.market.get_market_stats()
        
        # Calculate trend distribution
        trend_counts = {"rising": 0, "falling": 0, "stable": 0, "volatile": 0}
        
        for item_id in self.market.listings.keys():
            trend = self.market.get_trend(item_id)
            
            if trend.value in ["rising", "rising_fast"]:
                trend_counts["rising"] += 1
            elif trend.value in ["falling", "falling_fast"]:
                trend_counts["falling"] += 1
            elif trend.value == "volatile":
                trend_counts["volatile"] += 1
            else:
                trend_counts["stable"] += 1
        
        total_items = sum(trend_counts.values())
        
        # Determine overall health
        if total_items == 0:
            health_status = "unknown"
        else:
            rising_pct = trend_counts["rising"] / total_items
            volatile_pct = trend_counts["volatile"] / total_items
            
            if volatile_pct > 0.4:
                health_status = "unstable"
            elif rising_pct > 0.6:
                health_status = "bullish"
            elif rising_pct < 0.3:
                health_status = "bearish"
            else:
                health_status = "stable"
        
        return {
            "health_status": health_status,
            "total_listings": stats["total_listings"],
            "unique_items": stats["unique_items"],
            "avg_price": int(stats["avg_price"]),
            "trend_distribution": trend_counts,
            "rising_percentage": (trend_counts["rising"] / total_items * 100) if total_items > 0 else 0,
            "volatile_percentage": (trend_counts["volatile"] / total_items * 100) if total_items > 0 else 0
        }
    
    def predict_market_events(self, days_ahead: int = 7) -> List[dict]:
        """
        Predict upcoming market events.
        
        Args:
            days_ahead: Days to predict ahead
            
        Returns:
            List of predicted events
        """
        events: List[dict] = []
        
        # Check for items with strong trends
        for item_id in self.market.listings.keys():
            trend = self.market.get_trend(item_id)
            
            if trend.value in ["rising_fast", "falling_fast"]:
                # Predict continuation or reversal
                predicted, confidence = self.analyzer.predict_price(
                    item_id,
                    days_ahead=days_ahead
                )
                
                if confidence > 0.6:
                    current = self.market.get_current_price(item_id)
                    
                    if current:
                        change_pct = ((predicted - current["median_price"]) / 
                                     current["median_price"] * 100)
                        
                        if abs(change_pct) > 20:
                            events.append({
                                "item_id": item_id,
                                "event_type": "price_change",
                                "current_price": current["median_price"],
                                "predicted_price": predicted,
                                "change_percent": change_pct,
                                "confidence": confidence,
                                "days_ahead": days_ahead
                            })
        
        # Sort by magnitude of change
        events.sort(key=lambda e: abs(e["change_percent"]), reverse=True)
        
        return events[:10]  # Top 10 events
    
    def get_hot_items(self, limit: int = 10) -> List[dict]:
        """
        Get currently trending items.
        
        Args:
            limit: Maximum items to return
            
        Returns:
            List of hot items
        """
        hot_items: List[dict] = []
        
        for item_id, listings in self.market.listings.items():
            if not listings:
                continue
            
            # Check volume
            history = self.market.get_price_history(item_id, days=7)
            
            if not history or len(history.price_points) < 5:
                continue
            
            # Calculate trading volume
            volume = sum(qty for _, _, qty in history.price_points)
            
            # Check trend
            trend = self.market.get_trend(item_id)
            
            # Hot if high volume and rising price
            if volume > 100 and trend.value in ["rising", "rising_fast"]:
                current = self.market.get_current_price(item_id)
                
                if current:
                    hot_items.append({
                        "item_id": item_id,
                        "item_name": listings[0].item_name,
                        "volume": volume,
                        "trend": trend.value,
                        "current_price": current["median_price"],
                        "listing_count": len(listings),
                        "volatility": history.volatility
                    })
        
        # Sort by volume
        hot_items.sort(key=lambda i: i["volume"], reverse=True)
        
        return hot_items[:limit]
    
    def get_undervalued_items(self, limit: int = 10) -> List[dict]:
        """
        Get potentially undervalued items.
        
        Args:
            limit: Maximum items to return
            
        Returns:
            List of undervalued items
        """
        undervalued: List[dict] = []
        
        for item_id, listings in self.market.listings.items():
            if not listings:
                continue
            
            current_price = self.market.get_current_price(item_id)
            
            if not current_price:
                continue
            
            history = self.market.get_price_history(item_id, days=30)
            
            if not history:
                continue
            
            # Compare current price to historical average
            current = current_price["median_price"]
            historical_avg = history.avg_price
            
            # Undervalued if current price is significantly below average
            if current < historical_avg * 0.7:
                discount = (historical_avg - current) / historical_avg * 100
                
                # Check if trend is recovering
                trend = self.market.get_trend(item_id)
                
                undervalued.append({
                    "item_id": item_id,
                    "item_name": listings[0].item_name,
                    "current_price": current,
                    "historical_avg": int(historical_avg),
                    "discount_percent": discount,
                    "trend": trend.value,
                    "potential_profit": int(historical_avg - current),
                    "listing_count": len(listings)
                })
        
        # Sort by discount percentage
        undervalued.sort(key=lambda i: i["discount_percent"], reverse=True)
        
        return undervalued[:limit]
    
    def get_recent_alerts(self, severity: Optional[str] = None) -> List[MarketAlert]:
        """
        Get recent market alerts.
        
        Args:
            severity: Filter by severity (optional)
            
        Returns:
            List of recent alerts
        """
        if severity:
            return [a for a in self.alerts if a.severity == severity]
        
        return self.alerts[-20:]  # Last 20 alerts
    
    def clear_old_alerts(self, hours: int = 24) -> int:
        """
        Clear alerts older than specified hours.
        
        Args:
            hours: Age threshold in hours
            
        Returns:
            Number of alerts cleared
        """
        from datetime import timedelta
        
        cutoff = datetime.utcnow() - timedelta(hours=hours)
        
        old_count = len(self.alerts)
        self.alerts = [a for a in self.alerts if a.timestamp >= cutoff]
        cleared = old_count - len(self.alerts)
        
        if cleared > 0:
            self.log.info("old_alerts_cleared", count=cleared, hours=hours)
        
        return cleared