"""
Trading Strategy - Trading opportunity detection and strategy.

Features:
- Arbitrage detection
- Flip opportunities
- Profit calculation
- Risk assessment
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketManager, MarketSource
from ai_sidecar.economy.price_analysis import PriceAnalyzer

logger = structlog.get_logger(__name__)


class TradeOpportunity(BaseModel):
    """Single trading opportunity"""
    opportunity_id: int
    item_id: int
    item_name: str
    buy_price: int
    sell_price: int
    profit: int
    profit_margin: float
    risk_level: float = Field(ge=0, le=1)
    confidence: float = Field(ge=0, le=1)
    buy_source: MarketSource
    sell_source: MarketSource
    expires_at: Optional[datetime] = None
    quantity_available: int = 1


class TradingStrategy(str, Enum):
    """Trading strategy types"""
    FLIP = "flip"                # Buy and resell immediately
    HOLD = "hold"                # Buy and hold for appreciation
    ARBITRAGE = "arbitrage"      # Cross-market price difference
    SPECULATION = "speculation"  # Bet on future price changes
    MATERIAL = "material"        # Buy materials, sell products


class TradingManager:
    """
    Trading strategy and opportunity detection.
    
    Features:
    - Arbitrage detection
    - Flip opportunities
    - Profit calculation
    - Risk assessment
    """
    
    def __init__(
        self,
        market_manager: MarketManager,
        price_analyzer: PriceAnalyzer
    ):
        """
        Initialize trading manager.
        
        Args:
            market_manager: Market data manager
            price_analyzer: Price analyzer
        """
        self.log = logger.bind(system="trading_manager")
        self.market = market_manager
        self.analyzer = price_analyzer
        
        # Opportunity tracking
        self._opportunity_counter = 0
        self._found_opportunities: List[TradeOpportunity] = []
        
        self.log.info("trading_manager_initialized")
    
    def find_arbitrage_opportunities(
        self,
        min_profit: int = 1000,
        min_margin: float = 0.05
    ) -> List[TradeOpportunity]:
        """
        Find cross-market arbitrage opportunities.
        
        Args:
            min_profit: Minimum profit per item
            min_margin: Minimum profit margin
            
        Returns:
            List of arbitrage opportunities
        """
        opportunities: List[TradeOpportunity] = []
        
        # Check each item in market
        for item_id, listings in self.market.listings.items():
            if not listings:
                continue
            
            # Group by source
            by_source: Dict[MarketSource, List] = {}
            
            for listing in listings:
                source = listing.source
                if source not in by_source:
                    by_source[source] = []
                by_source[source].append(listing)
            
            # Look for price differences between sources
            sources = list(by_source.keys())
            
            for i, buy_source in enumerate(sources):
                for sell_source in sources[i+1:]:
                    # Find cheapest buy price
                    buy_listings = by_source[buy_source]
                    sell_listings = by_source[sell_source]
                    
                    min_buy = min(l.price for l in buy_listings)
                    max_sell = max(l.price for l in sell_listings)
                    
                    # Calculate arbitrage
                    profit = max_sell - min_buy
                    margin = profit / min_buy if min_buy > 0 else 0
                    
                    if profit >= min_profit and margin >= min_margin:
                        # Found arbitrage opportunity
                        self._opportunity_counter += 1
                        
                        opportunity = TradeOpportunity(
                            opportunity_id=self._opportunity_counter,
                            item_id=item_id,
                            item_name=listings[0].item_name,
                            buy_price=min_buy,
                            sell_price=max_sell,
                            profit=profit,
                            profit_margin=margin,
                            risk_level=0.2,  # Arbitrage is low risk
                            confidence=0.9,
                            buy_source=buy_source,
                            sell_source=sell_source,
                            expires_at=datetime.utcnow() + timedelta(hours=1),
                            quantity_available=min(
                                sum(l.quantity for l in buy_listings),
                                sum(l.quantity for l in sell_listings)
                            )
                        )
                        
                        opportunities.append(opportunity)
        
        self.log.info(
            "arbitrage_opportunities_found",
            count=len(opportunities),
            min_profit=min_profit
        )
        
        return opportunities
    
    def find_flip_opportunities(
        self,
        min_profit: int = 5000,
        max_risk: float = 0.3
    ) -> List[TradeOpportunity]:
        """
        Find buy-low-sell-high opportunities.
        
        Args:
            min_profit: Minimum profit per item
            max_risk: Maximum acceptable risk
            
        Returns:
            List of flip opportunities
        """
        opportunities: List[TradeOpportunity] = []
        
        for item_id, listings in self.market.listings.items():
            if not listings:
                continue
            
            # Get current price data
            current_price = self.market.get_current_price(item_id)
            
            if not current_price:
                continue
            
            median = current_price["median_price"]
            
            # Find items priced significantly below median
            for listing in listings:
                if listing.price < median * 0.8:  # 20% below median
                    # Calculate potential profit
                    expected_sell = median
                    profit = expected_sell - listing.price
                    margin = profit / listing.price if listing.price > 0 else 0
                    
                    if profit >= min_profit:
                        # Assess risk
                        risk = self._calculate_flip_risk(item_id, listing.price)
                        
                        if risk <= max_risk:
                            self._opportunity_counter += 1
                            
                            opportunity = TradeOpportunity(
                                opportunity_id=self._opportunity_counter,
                                item_id=item_id,
                                item_name=listing.item_name,
                                buy_price=listing.price,
                                sell_price=expected_sell,
                                profit=profit,
                                profit_margin=margin,
                                risk_level=risk,
                                confidence=0.7,
                                buy_source=listing.source,
                                sell_source=MarketSource.VENDING,
                                expires_at=datetime.utcnow() + timedelta(hours=2),
                                quantity_available=listing.quantity
                            )
                            
                            opportunities.append(opportunity)
        
        # Sort by profit
        opportunities.sort(key=lambda o: o.profit, reverse=True)
        
        self.log.info(
            "flip_opportunities_found",
            count=len(opportunities),
            min_profit=min_profit
        )
        
        return opportunities
    
    def evaluate_trade(self, item_id: int, buy_price: int) -> dict:
        """
        Evaluate potential profit from trade.
        
        Args:
            item_id: Item ID
            buy_price: Purchase price
            
        Returns:
            Dict with trade evaluation
        """
        # Get fair market price
        fair_price = self.analyzer.calculate_fair_price(item_id)
        
        if fair_price == 0:
            return {
                "viable": False,
                "reason": "no_price_data"
            }
        
        # Calculate potential profit
        expected_sell = fair_price
        profit = expected_sell - buy_price
        margin = profit / buy_price if buy_price > 0 else 0
        
        # Check if viable
        viable = profit > 0 and margin > 0.05
        
        # Calculate ROI
        roi = margin * 100
        
        # Assess risk
        risk = self._calculate_flip_risk(item_id, buy_price)
        
        return {
            "viable": viable,
            "buy_price": buy_price,
            "expected_sell": expected_sell,
            "profit": profit,
            "profit_margin": margin,
            "roi_percent": roi,
            "risk_level": risk,
            "recommendation": self._get_trade_recommendation(margin, risk)
        }
    
    def get_recommended_trades(
        self,
        budget: int,
        risk_tolerance: float
    ) -> List[TradeOpportunity]:
        """
        Get recommended trades based on budget and risk.
        
        Args:
            budget: Available budget
            risk_tolerance: Risk tolerance (0-1)
            
        Returns:
            List of recommended trades
        """
        # Find all opportunities
        arbitrage = self.find_arbitrage_opportunities()
        flips = self.find_flip_opportunities()
        
        # Combine and filter by risk
        all_opps = arbitrage + flips
        suitable = [
            opp for opp in all_opps
            if opp.risk_level <= risk_tolerance
        ]
        
        # Sort by profit/risk ratio
        suitable.sort(
            key=lambda o: o.profit * (1 - o.risk_level),
            reverse=True
        )
        
        # Select trades within budget
        recommended: List[TradeOpportunity] = []
        remaining_budget = budget
        
        for opp in suitable:
            cost = opp.buy_price * opp.quantity_available
            
            if cost <= remaining_budget:
                recommended.append(opp)
                remaining_budget -= cost
        
        self.log.info(
            "recommended_trades_generated",
            count=len(recommended),
            budget_used=budget - remaining_budget
        )
        
        return recommended
    
    def calculate_roi(
        self,
        item_id: int,
        buy_price: int,
        hold_days: int = 7
    ) -> dict:
        """
        Calculate expected ROI.
        
        Args:
            item_id: Item ID
            buy_price: Purchase price
            hold_days: Days to hold before selling
            
        Returns:
            Dict with ROI calculation
        """
        # Predict future price
        predicted, confidence = self.analyzer.predict_price(
            item_id,
            days_ahead=hold_days
        )
        
        if predicted == 0:
            return {
                "roi": 0.0,
                "confidence": 0.0,
                "recommended": False
            }
        
        # Calculate ROI
        profit = predicted - buy_price
        roi = profit / buy_price if buy_price > 0 else 0
        
        # Adjust for confidence
        expected_roi = roi * confidence
        
        recommended = expected_roi > 0.10  # At least 10% ROI
        
        return {
            "buy_price": buy_price,
            "predicted_price": predicted,
            "profit": profit,
            "roi": roi,
            "expected_roi": expected_roi,
            "confidence": confidence,
            "hold_days": hold_days,
            "recommended": recommended
        }
    
    def should_buy(
        self,
        item_id: int,
        price: int,
        purpose: str
    ) -> Tuple[bool, str]:
        """
        Determine if should buy at price.
        
        Args:
            item_id: Item ID
            price: Offered price
            purpose: Purchase purpose (flip, hold, use)
            
        Returns:
            Tuple of (should_buy, reason)
        """
        # Get price comparison
        comparison = self.analyzer.compare_to_market(item_id, price)
        
        if comparison["status"] != "compared":
            return (False, "no_price_data")
        
        if purpose == "flip":
            # For flipping, need good margin
            if comparison["recommendation"] in ["excellent_buy", "good_buy"]:
                profit_potential = comparison["median_market"] - price
                if profit_potential > 1000:
                    return (True, "good_flip_opportunity")
            return (False, "insufficient_profit_margin")
        
        elif purpose == "hold":
            # For holding, check trend
            trend = self.market.get_trend(item_id)
            if trend.value in ["rising", "rising_fast"]:
                if comparison["recommendation"] != "overpriced":
                    return (True, "good_investment")
            return (False, "unfavorable_trend")
        
        elif purpose == "use":
            # For use, just need fair price
            if comparison["recommendation"] in ["excellent_buy", "good_buy", "fair_price"]:
                return (True, "fair_price_for_use")
            return (False, "price_too_high")
        
        return (False, "unknown_purpose")
    
    def should_sell(
        self,
        item_id: int,
        price: int,
        holding_price: int
    ) -> Tuple[bool, str]:
        """
        Determine if should sell at price.
        
        Args:
            item_id: Item ID
            price: Offered price
            holding_price: Original purchase price
            
        Returns:
            Tuple of (should_sell, reason)
        """
        # Calculate current profit
        profit = price - holding_price
        margin = profit / holding_price if holding_price > 0 else 0
        
        # Check if profitable
        if margin < 0.05:
            return (False, "insufficient_profit")
        
        # Compare to market
        comparison = self.analyzer.compare_to_market(item_id, price)
        
        if comparison["recommendation"] == "overpriced":
            # Market price is even higher - can wait
            return (False, "can_get_better_price")
        
        # Check trend
        trend = self.market.get_trend(item_id)
        
        if trend.value in ["rising", "rising_fast"]:
            # Price rising - might want to wait
            if margin < 0.20:  # Less than 20% profit
                return (False, "price_rising_wait")
        
        elif trend.value in ["falling", "falling_fast"]:
            # Price falling - sell now!
            return (True, "sell_before_drop")
        
        # Good profit and stable/falling market
        if margin >= 0.15:
            return (True, "good_profit_achieved")
        
        return (False, "wait_for_better_opportunity")
    
    def _calculate_flip_risk(self, item_id: int, buy_price: int) -> float:
        """
        Calculate risk level for flip trade.
        
        Args:
            item_id: Item ID
            buy_price: Purchase price
            
        Returns:
            Risk level (0-1)
        """
        history = self.market.get_price_history(item_id, days=30)
        
        if not history:
            return 0.8  # High risk without data
        
        # Base risk on volatility
        risk = history.volatility
        
        # Increase risk if price is very low
        if buy_price < history.min_price * 1.1:
            risk += 0.2
        
        # Decrease risk for liquid markets
        metrics = self.market.get_market_stats()
        if item_id in self.market.listings:
            listing_count = len(self.market.listings[item_id])
            if listing_count > 20:
                risk *= 0.8
        
        return min(1.0, risk)
    
    def _get_trade_recommendation(
        self,
        margin: float,
        risk: float
    ) -> str:
        """
        Get trade recommendation based on margin and risk.
        
        Args:
            margin: Profit margin
            risk: Risk level
            
        Returns:
            Recommendation string
        """
        if margin > 0.30 and risk < 0.3:
            return "excellent_trade"
        elif margin > 0.20 and risk < 0.5:
            return "good_trade"
        elif margin > 0.10 and risk < 0.5:
            return "acceptable_trade"
        elif margin > 0.05:
            return "marginal_trade"
        else:
            return "avoid"