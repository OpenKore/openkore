"""
Price Analysis System - Advanced price analysis and prediction.

Features:
- Statistical analysis
- Trend detection
- Price prediction
- Anomaly detection
"""

import statistics
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketManager, PriceTrend

logger = structlog.get_logger(__name__)


class PriceAnalyzer:
    """
    Advanced price analysis system.
    
    Features:
    - Statistical analysis
    - Trend detection
    - Price prediction
    - Anomaly detection
    """
    
    def __init__(self, market_manager: MarketManager, config_path: Optional[Path] = None):
        """
        Initialize price analyzer.
        
        Args:
            market_manager: Market data manager
            config_path: Path to configuration file
        """
        self.log = logger.bind(system="price_analyzer")
        self.market = market_manager
        
        # Load configuration
        self.config = self._load_config(config_path)
        
        self.log.info("price_analyzer_initialized")
    
    def calculate_fair_price(
        self,
        item_id: int,
        refine_level: int = 0,
        cards: List[int] = None
    ) -> int:
        """
        Calculate fair market price for item.
        
        Args:
            item_id: Item ID
            refine_level: Refine level for equipment
            cards: List of card IDs inserted
            
        Returns:
            Calculated fair price
        """
        cards = cards or []
        
        # Get base item price
        current_price = self.market.get_current_price(item_id, include_cards=False)
        
        if not current_price:
            self.log.warning("no_price_data", item_id=item_id)
            return 0
        
        base_price = current_price["median_price"]
        
        # Add refine value
        refine_value = self._calculate_refine_value(base_price, refine_level)
        
        # Add card values
        card_value = self._calculate_card_value(cards)
        
        # Consider market trends
        trend_multiplier = self._get_trend_multiplier(item_id)
        
        fair_price = int((base_price + refine_value + card_value) * trend_multiplier)
        
        self.log.debug(
            "fair_price_calculated",
            item_id=item_id,
            base=base_price,
            refine=refine_value,
            cards=card_value,
            trend=trend_multiplier,
            final=fair_price
        )
        
        return fair_price
    
    def predict_price(
        self,
        item_id: int,
        days_ahead: int = 7
    ) -> Tuple[int, float]:
        """
        Predict future price with confidence.
        
        Args:
            item_id: Item ID
            days_ahead: Days to predict ahead
            
        Returns:
            Tuple of (predicted_price, confidence)
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history or len(history.price_points) < 7:
            # Not enough data
            current = self.market.get_current_price(item_id)
            if current:
                return (current["median_price"], 0.0)
            return (0, 0.0)
        
        # Simple moving average prediction
        prices = [price for _, price, _ in history.price_points]
        
        # Calculate trend slope
        recent_prices = prices[-14:]  # Last 2 weeks
        trend = self._calculate_price_slope(recent_prices)
        
        # Predict based on trend
        current_avg = statistics.mean(recent_prices)
        predicted = int(current_avg + (trend * days_ahead))
        
        # Calculate confidence based on volatility
        volatility = history.volatility
        confidence = max(0.0, 1.0 - (volatility * 2))  # Lower volatility = higher confidence
        
        self.log.debug(
            "price_predicted",
            item_id=item_id,
            current=int(current_avg),
            predicted=predicted,
            confidence=confidence,
            trend=trend
        )
        
        return (predicted, confidence)
    
    def detect_price_anomaly(
        self,
        item_id: int,
        price: int
    ) -> Tuple[bool, str]:
        """
        Detect if price is anomalous.
        
        Args:
            item_id: Item ID
            price: Price to check
            
        Returns:
            Tuple of (is_anomaly, reason)
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history or len(history.price_points) < 3:
            # Not enough data to determine
            return (False, "insufficient_data")
        
        avg_price = history.avg_price
        std_dev = history.std_deviation
        
        # Check if price is too far from average
        z_score = abs(price - avg_price) / std_dev if std_dev > 0 else 0
        
        if z_score > 3.0:
            if price > avg_price:
                return (True, "price_too_high")
            else:
                return (True, "price_too_low")
        
        # Check against max price threshold
        max_threshold = self.config.get("max_price_multiplier", 3.0)
        if price > avg_price * max_threshold:
            return (True, "exceeds_maximum_threshold")
        
        # Check against min price threshold
        min_threshold = self.config.get("min_price_multiplier", 0.1)
        if price < avg_price * min_threshold:
            return (True, "below_minimum_threshold")
        
        return (False, "normal")
    
    def get_price_percentile(self, item_id: int, price: int) -> float:
        """
        Get percentile of price in distribution.
        
        Args:
            item_id: Item ID
            price: Price to evaluate
            
        Returns:
            Percentile (0.0-1.0)
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history or not history.price_points:
            return 0.5  # Default to median
        
        prices = sorted([p for _, p, _ in history.price_points])
        
        # Count how many prices are below target
        below_count = sum(1 for p in prices if p < price)
        
        percentile = below_count / len(prices) if prices else 0.5
        
        return percentile
    
    def compare_to_market(self, item_id: int, price: int) -> dict:
        """
        Compare price to market.
        
        Args:
            item_id: Item ID
            price: Price to compare
            
        Returns:
            Dict with comparison data
        """
        current = self.market.get_current_price(item_id)
        
        if not current:
            return {
                "status": "no_data",
                "recommendation": "unknown"
            }
        
        min_price = current["min_price"]
        max_price = current["max_price"]
        avg_price = current["avg_price"]
        median_price = current["median_price"]
        
        # Calculate position in range
        if max_price > min_price:
            position = (price - min_price) / (max_price - min_price)
        else:
            position = 0.5
        
        # Determine recommendation
        if price < median_price * 0.9:
            recommendation = "excellent_buy"
        elif price < median_price:
            recommendation = "good_buy"
        elif price < median_price * 1.1:
            recommendation = "fair_price"
        elif price < median_price * 1.2:
            recommendation = "above_market"
        else:
            recommendation = "overpriced"
        
        return {
            "status": "compared",
            "price": price,
            "min_market": min_price,
            "max_market": max_price,
            "avg_market": int(avg_price),
            "median_market": median_price,
            "position": position,
            "percentile": self.get_price_percentile(item_id, price),
            "recommendation": recommendation,
            "difference_from_median": price - median_price,
            "difference_percent": ((price - median_price) / median_price * 100) if median_price > 0 else 0
        }
    
    def get_seasonal_pattern(self, item_id: int) -> dict:
        """
        Get seasonal price patterns.
        
        Args:
            item_id: Item ID
            
        Returns:
            Dict with seasonal pattern data
        """
        history = self.market.get_price_history(item_id, days=90)
        
        if not history or len(history.price_points) < 30:
            return {
                "has_pattern": False,
                "daily_pattern": {},
                "weekly_pattern": {}
            }
        
        # Analyze by day of week
        daily_prices: Dict[int, List[int]] = {i: [] for i in range(7)}
        
        for timestamp, price, _ in history.price_points:
            day_of_week = timestamp.weekday()
            daily_prices[day_of_week].append(price)
        
        daily_pattern = {}
        for day, prices in daily_prices.items():
            if prices:
                daily_pattern[day] = {
                    "avg": statistics.mean(prices),
                    "count": len(prices)
                }
        
        # Analyze by time of day (rough)
        hourly_prices: Dict[str, List[int]] = {
            "morning": [],    # 6-12
            "afternoon": [],  # 12-18
            "evening": [],    # 18-24
            "night": []       # 0-6
        }
        
        for timestamp, price, _ in history.price_points:
            hour = timestamp.hour
            if 6 <= hour < 12:
                hourly_prices["morning"].append(price)
            elif 12 <= hour < 18:
                hourly_prices["afternoon"].append(price)
            elif 18 <= hour < 24:
                hourly_prices["evening"].append(price)
            else:
                hourly_prices["night"].append(price)
        
        time_pattern = {}
        for period, prices in hourly_prices.items():
            if prices:
                time_pattern[period] = {
                    "avg": statistics.mean(prices),
                    "count": len(prices)
                }
        
        # Detect if there's a significant pattern
        daily_avgs = [p["avg"] for p in daily_pattern.values()]
        has_pattern = False
        
        if len(daily_avgs) > 1:
            pattern_variance = statistics.variance(daily_avgs)
            overall_variance = history.std_deviation ** 2
            
            # Pattern exists if daily variance is significant
            has_pattern = pattern_variance > overall_variance * 0.5
        
        return {
            "has_pattern": has_pattern,
            "daily_pattern": daily_pattern,
            "time_pattern": time_pattern
        }
    
    def _calculate_refine_value(self, base_price: int, refine_level: int) -> int:
        """
        Calculate value added by refine level.
        
        Args:
            base_price: Base item price
            refine_level: Refine level
            
        Returns:
            Additional value from refining
        """
        if refine_level <= 0:
            return 0
        
        # Exponential increase for higher refines
        # +7 to +10 add significant value
        multipliers = {
            1: 0.05, 2: 0.07, 3: 0.10, 4: 0.13,
            5: 0.17, 6: 0.22, 7: 0.35, 8: 0.55,
            9: 0.85, 10: 1.50
        }
        
        multiplier = multipliers.get(refine_level, 0.05)
        
        return int(base_price * multiplier)
    
    def _calculate_card_value(self, cards: List[int]) -> int:
        """
        Calculate value added by cards.
        
        Args:
            cards: List of card IDs
            
        Returns:
            Total value from cards
        """
        if not cards:
            return 0
        
        total_value = 0
        
        for card_id in cards:
            card_price = self.market.get_current_price(card_id)
            if card_price and "median_price" in card_price:
                # Cards add 80% of their market value
                # (accounting for risk/effort of slotting)
                total_value += int(card_price["median_price"] * 0.8)
        
        return total_value
    
    def _get_trend_multiplier(self, item_id: int) -> float:
        """
        Get price multiplier based on trend.
        
        Args:
            item_id: Item ID
            
        Returns:
            Trend multiplier (0.8-1.2)
        """
        trend = self.market.get_trend(item_id)
        
        multipliers = {
            PriceTrend.RISING_FAST: 1.15,
            PriceTrend.RISING: 1.08,
            PriceTrend.STABLE: 1.0,
            PriceTrend.FALLING: 0.92,
            PriceTrend.FALLING_FAST: 0.85,
            PriceTrend.VOLATILE: 1.0
        }
        
        return multipliers.get(trend, 1.0)
    
    def _calculate_price_slope(self, prices: List[int]) -> float:
        """
        Calculate price slope (trend direction).
        
        Args:
            prices: List of prices
            
        Returns:
            Slope value (zeny per day)
        """
        if len(prices) < 2:
            return 0.0
        
        # Simple linear regression
        n = len(prices)
        x = list(range(n))
        y = prices
        
        x_mean = statistics.mean(x)
        y_mean = statistics.mean(y)
        
        numerator = sum((x[i] - x_mean) * (y[i] - y_mean) for i in range(n))
        denominator = sum((x[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            return 0.0
        
        slope = numerator / denominator
        
        return slope
    
    def _load_config(self, config_path: Optional[Path]) -> dict:
        """Load configuration from file."""
        if not config_path or not config_path.exists():
            # Return default config
            return {
                "max_price_multiplier": 3.0,
                "min_price_multiplier": 0.1,
                "scam_threshold": 0.05
            }
        
        try:
            import json
            with open(config_path, 'r') as f:
                data = json.load(f)
                return data.get("price_thresholds", {})
        except Exception as e:
            self.log.error("config_load_failed", error=str(e))
            return {}
    
    def estimate_fair_price(
        self,
        item_id: int,
        refine_level: int = 0,
        cards: List[int] = None
    ) -> int:
        """
        Estimate fair market price for item (alias for calculate_fair_price).
        
        Args:
            item_id: Item ID
            refine_level: Refine level for equipment
            cards: List of card IDs inserted
            
        Returns:
            Estimated fair price
        """
        return self.calculate_fair_price(item_id, refine_level, cards)


class SupplyDemandAnalyzer:
    """
    Analyzes supply and demand dynamics in the market.
    
    Features:
    - Demand estimation based on listing turnover
    - Supply tracking
    - Buy/sell pressure analysis
    """
    
    def __init__(self, market_manager: MarketManager):
        """
        Initialize supply/demand analyzer.
        
        Args:
            market_manager: Market data manager
        """
        self.log = logger.bind(system="supply_demand")
        self.market = market_manager
    
    def estimate_demand(self, item_id: int) -> float:
        """
        Estimate demand level for an item.
        
        Args:
            item_id: Item ID
            
        Returns:
            Demand score (0.0-1.0, higher = more demand)
        """
        current_price = self.market.get_current_price(item_id)
        history = self.market.get_price_history(item_id, days=7)
        
        if not current_price or not history:
            return 0.5  # Unknown demand
        
        # Factors indicating demand:
        # 1. Rising prices
        # 2. Multiple listings (sellers know there are buyers)
        # 3. Low volatility (stable demand)
        
        demand_score = 0.0
        
        # Trend-based demand
        if history.trend == PriceTrend.RISING_FAST:
            demand_score += 0.4
        elif history.trend == PriceTrend.RISING:
            demand_score += 0.3
        elif history.trend == PriceTrend.STABLE:
            demand_score += 0.2
        
        # Listing count
        listing_count = current_price.get("listing_count", 0)
        if listing_count > 10:
            demand_score += 0.3
        elif listing_count > 5:
            demand_score += 0.2
        elif listing_count > 0:
            demand_score += 0.1
        
        # Volatility (lower = more stable demand)
        volatility = history.volatility
        if volatility < 0.1:
            demand_score += 0.3
        elif volatility < 0.2:
            demand_score += 0.2
        elif volatility < 0.3:
            demand_score += 0.1
        
        demand_score = min(1.0, demand_score)
        
        self.log.debug(
            "demand_estimated",
            item_id=item_id,
            demand=demand_score,
            trend=history.trend.value,
            listings=listing_count
        )
        
        return demand_score