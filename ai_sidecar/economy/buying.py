"""
Buying Strategy - Strategic buying management system.

Features:
- Price thresholds
- Purchase prioritization
- Bulk buying strategy
- Budget allocation
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.economy.core import MarketListing, MarketManager
from ai_sidecar.economy.price_analysis import PriceAnalyzer

logger = structlog.get_logger(__name__)


class PurchasePriority(str, Enum):
    """Purchase priority levels"""
    CRITICAL = "critical"       # Need immediately
    HIGH = "high"               # Need soon
    NORMAL = "normal"           # Can wait
    LOW = "low"                 # Nice to have
    SPECULATIVE = "speculative" # Investment


class PurchaseTarget(BaseModel):
    """Target item for purchase"""
    item_id: int
    item_name: str
    max_price: int
    priority: PurchasePriority
    quantity_needed: int
    quantity_owned: int = 0
    deadline: Optional[datetime] = None
    reason: str = ""


class BuyingManager:
    """
    Strategic buying management system.
    
    Features:
    - Price thresholds
    - Purchase prioritization
    - Bulk buying strategy
    - Budget allocation
    """
    
    def __init__(
        self,
        market_manager: MarketManager,
        price_analyzer: PriceAnalyzer
    ):
        """
        Initialize buying manager.
        
        Args:
            market_manager: Market data manager
            price_analyzer: Price analyzer
        """
        self.log = logger.bind(system="buying_manager")
        self.market = market_manager
        self.analyzer = price_analyzer
        
        # Purchase targets
        self.purchase_targets: Dict[int, PurchaseTarget] = {}
        
        self.log.info("buying_manager_initialized")
    
    def add_purchase_target(self, target: PurchaseTarget) -> None:
        """
        Add item to purchase list.
        
        Args:
            target: Purchase target to add
        """
        self.purchase_targets[target.item_id] = target
        
        self.log.info(
            "purchase_target_added",
            item_id=target.item_id,
            item_name=target.item_name,
            priority=target.priority.value,
            max_price=target.max_price
        )
    
    def remove_purchase_target(self, item_id: int) -> None:
        """
        Remove item from purchase list.
        
        Args:
            item_id: Item ID to remove
        """
        if item_id in self.purchase_targets:
            del self.purchase_targets[item_id]
            self.log.info("purchase_target_removed", item_id=item_id)
    
    def calculate_buy_price(
        self,
        item_id: int,
        urgency: float = 0.5
    ) -> int:
        """
        Calculate maximum buy price.
        
        Args:
            item_id: Item ID
            urgency: Urgency factor (0=patient, 1=urgent)
            
        Returns:
            Maximum price to pay
        """
        # Get fair market price
        fair_price = self.analyzer.calculate_fair_price(item_id)
        
        if fair_price == 0:
            self.log.warning("no_price_data", item_id=item_id)
            return 0
        
        # Adjust based on urgency
        if urgency > 0.7:
            # Urgent - willing to pay more
            multiplier = 1.0 + (urgency - 0.7) * 0.5
        elif urgency < 0.3:
            # Patient - wait for good deal
            multiplier = 0.80 - (0.3 - urgency) * 0.2
        else:
            # Normal - slight below fair
            multiplier = 0.95
        
        max_price = int(fair_price * multiplier)
        
        self.log.debug(
            "buy_price_calculated",
            item_id=item_id,
            fair_price=fair_price,
            max_price=max_price,
            urgency=urgency
        )
        
        return max_price
    
    def evaluate_listing(
        self,
        listing: MarketListing
    ) -> Tuple[bool, str]:
        """
        Evaluate if should buy from listing.
        
        Args:
            listing: Market listing to evaluate
            
        Returns:
            Tuple of (should_buy, reason)
        """
        item_id = listing.item_id
        
        # Check if we want this item
        target = self.purchase_targets.get(item_id)
        
        if not target:
            return (False, "not_on_purchase_list")
        
        # Check if already have enough
        if target.quantity_owned >= target.quantity_needed:
            return (False, "already_have_enough")
        
        # Check price
        if listing.price > target.max_price:
            return (False, "price_too_high")
        
        # Check for anomalies
        is_anomaly, anomaly_reason = self.analyzer.detect_price_anomaly(
            item_id,
            listing.price
        )
        
        if is_anomaly and anomaly_reason == "price_too_low":
            # Suspiciously cheap - might be scam
            return (False, "suspicious_price")
        
        # Good deal!
        comparison = self.analyzer.compare_to_market(item_id, listing.price)
        
        return (True, f"good_deal_{comparison['recommendation']}")
    
    def get_purchase_recommendations(
        self,
        budget: int
    ) -> List[dict]:
        """
        Get prioritized purchase recommendations.
        
        Args:
            budget: Available budget
            
        Returns:
            List of purchase recommendations
        """
        recommendations: List[dict] = []
        remaining_budget = budget
        
        # Sort targets by priority
        sorted_targets = sorted(
            self.purchase_targets.values(),
            key=lambda t: self._priority_score(t),
            reverse=True
        )
        
        for target in sorted_targets:
            if remaining_budget <= 0:
                break
            
            # Find best sellers for this item
            sellers = self.find_best_sellers(
                target.item_id,
                target.max_price
            )
            
            if not sellers:
                continue
            
            # Get cheapest option
            best_listing = min(sellers, key=lambda l: l.price)
            
            # Calculate quantity to buy
            quantity_needed = target.quantity_needed - target.quantity_owned
            quantity_to_buy = min(
                quantity_needed,
                best_listing.quantity,
                remaining_budget // best_listing.price
            )
            
            if quantity_to_buy > 0:
                total_cost = best_listing.price * quantity_to_buy
                
                recommendations.append({
                    "item_id": target.item_id,
                    "item_name": target.item_name,
                    "priority": target.priority.value,
                    "quantity": quantity_to_buy,
                    "price_per_unit": best_listing.price,
                    "total_cost": total_cost,
                    "seller": best_listing.seller_name,
                    "source": best_listing.source.value,
                    "reason": target.reason
                })
                
                remaining_budget -= total_cost
        
        self.log.info(
            "purchase_recommendations_generated",
            count=len(recommendations),
            budget_used=budget - remaining_budget
        )
        
        return recommendations
    
    def find_best_sellers(
        self,
        item_id: int,
        max_price: int
    ) -> List[MarketListing]:
        """
        Find best sellers for item.
        
        Args:
            item_id: Item ID
            max_price: Maximum acceptable price
            
        Returns:
            List of suitable listings
        """
        all_listings = self.market.listings.get(item_id, [])
        
        # Filter by price
        suitable = [
            listing for listing in all_listings
            if listing.price <= max_price
        ]
        
        # Sort by price
        suitable.sort(key=lambda l: l.price)
        
        return suitable
    
    def bulk_buy_strategy(
        self,
        item_id: int,
        quantity: int,
        max_total: int
    ) -> dict:
        """
        Strategy for bulk purchasing.
        
        Args:
            item_id: Item ID
            quantity: Total quantity needed
            max_total: Maximum total cost
            
        Returns:
            Dict with bulk buy strategy
        """
        # Get all available listings
        listings = self.market.listings.get(item_id, [])
        
        if not listings:
            return {
                "feasible": False,
                "reason": "no_sellers",
                "plan": []
            }
        
        # Sort by price
        sorted_listings = sorted(listings, key=lambda l: l.price)
        
        # Try to fulfill order with cheapest listings
        plan: List[dict] = []
        total_quantity = 0
        total_cost = 0
        
        for listing in sorted_listings:
            if total_quantity >= quantity:
                break
            
            # How much to buy from this seller
            needed = quantity - total_quantity
            available = listing.quantity
            buy_qty = min(needed, available)
            
            cost = buy_qty * listing.price
            
            if total_cost + cost > max_total:
                # Can't afford more
                remaining_budget = max_total - total_cost
                buy_qty = remaining_budget // listing.price
                cost = buy_qty * listing.price
                
                if buy_qty > 0:
                    plan.append({
                        "seller": listing.seller_name,
                        "price": listing.price,
                        "quantity": buy_qty,
                        "cost": cost,
                        "source": listing.source.value
                    })
                    total_quantity += buy_qty
                    total_cost += cost
                
                break
            
            plan.append({
                "seller": listing.seller_name,
                "price": listing.price,
                "quantity": buy_qty,
                "cost": cost,
                "source": listing.source.value
            })
            
            total_quantity += buy_qty
            total_cost += cost
        
        feasible = total_quantity >= quantity and total_cost <= max_total
        
        return {
            "feasible": feasible,
            "total_quantity": total_quantity,
            "total_cost": total_cost,
            "avg_price": total_cost // total_quantity if total_quantity > 0 else 0,
            "sellers_count": len(plan),
            "plan": plan
        }
    
    def should_wait(
        self,
        item_id: int,
        current_price: int,
        days_to_wait: int = 3
    ) -> Tuple[bool, str]:
        """
        Determine if should wait for better price.
        
        Args:
            item_id: Item ID
            current_price: Current market price
            days_to_wait: Days willing to wait
            
        Returns:
            Tuple of (should_wait, reason)
        """
        # Check price trend
        trend = self.market.get_trend(item_id)
        
        if trend.value in ["falling", "falling_fast"]:
            return (True, "price_falling_trend")
        
        # Predict future price
        predicted, confidence = self.analyzer.predict_price(
            item_id,
            days_ahead=days_to_wait
        )
        
        if confidence > 0.6 and predicted < current_price * 0.95:
            return (True, "predicted_price_drop")
        
        # Compare to historical average
        comparison = self.analyzer.compare_to_market(item_id, current_price)
        
        if comparison["recommendation"] in ["above_market", "overpriced"]:
            return (True, "price_above_market")
        
        # Don't wait - good price or stable market
        return (False, "buy_now")
    
    def _priority_score(self, target: PurchaseTarget) -> float:
        """
        Calculate priority score for sorting.
        
        Args:
            target: Purchase target
            
        Returns:
            Priority score (higher = more urgent)
        """
        base_scores = {
            PurchasePriority.CRITICAL: 100.0,
            PurchasePriority.HIGH: 75.0,
            PurchasePriority.NORMAL: 50.0,
            PurchasePriority.LOW: 25.0,
            PurchasePriority.SPECULATIVE: 10.0
        }
        
        score = base_scores.get(target.priority, 50.0)
        
        # Boost if deadline approaching
        if target.deadline:
            time_left = target.deadline - datetime.utcnow()
            days_left = time_left.total_seconds() / 86400
            
            if days_left < 1:
                score *= 2.0
            elif days_left < 3:
                score *= 1.5
            elif days_left < 7:
                score *= 1.2
        
        return score