"""
Economy Coordinator - Main integration facade for all economic systems.

Coordinates:
- Market Manager
- Price Analyzer
- Trading Manager
- Supply/Demand Analyzer
- Vending Optimizer
- Buying Manager
- Economic Intelligence
"""

from pathlib import Path
from typing import Dict, List, Optional

import structlog

from ai_sidecar.economy.buying import BuyingManager, PurchaseTarget
from ai_sidecar.economy.core import MarketListing, MarketManager
from ai_sidecar.economy.intelligence import EconomicIntelligence
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.economy.supply_demand import SupplyDemandAnalyzer
from ai_sidecar.economy.trading_strategy import TradingManager
from ai_sidecar.economy.vending import VendingOptimizer

logger = structlog.get_logger(__name__)


class EconomyCoordinator:
    """
    Main economy coordinator integrating all economic systems.
    
    Acts as facade for:
    - Market Manager
    - Price Analyzer
    - Trading Manager
    - Supply/Demand Analyzer
    - Vending Optimizer
    - Buying Manager
    - Economic Intelligence
    """
    
    def __init__(self, data_dir: Path, config_path: Optional[Path] = None):
        """
        Initialize economy coordinator.
        
        Args:
            data_dir: Directory for data storage
            config_path: Path to configuration file
        """
        self.log = logger.bind(system="economy_coordinator")
        self.data_dir = data_dir
        self.config_path = config_path or (data_dir / "market_config.json")
        
        # Initialize core systems
        self.market = MarketManager(data_dir)
        self.analyzer = PriceAnalyzer(self.market, self.config_path)
        self.trading = TradingManager(self.market, self.analyzer)
        self.supply_demand = SupplyDemandAnalyzer(self.market, data_dir)
        self.vending = VendingOptimizer(
            self.market,
            self.analyzer,
            self.supply_demand,
            self.config_path
        )
        self.buying = BuyingManager(self.market, self.analyzer)
        self.intelligence = EconomicIntelligence(
            self.market,
            self.analyzer,
            self.trading
        )
        
        self.log.info("economy_coordinator_initialized", data_dir=str(data_dir))
    
    async def tick(self, game_state) -> List[dict]:
        """
        Process tick and return economic actions.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of action dicts
        """
        actions = []
        
        # Check for economic actions
        character = game_state.character
        inventory = game_state.inventory
        
        action = await self.get_next_economic_action(
            character_state={"level": character.base_level},
            inventory={"items": []},
            zeny=character.zeny
        )
        
        if action["action"] != "wait":
            actions.append(action)
        
        return actions
    
    async def update_market_data(self, listings: List[dict]) -> dict:
        """
        Update market with new listings.
        
        Args:
            listings: List of listing dicts from game
            
        Returns:
            Dict with update results
        """
        added_count = 0
        scam_detected = 0
        manipulation_detected = 0
        
        for listing_data in listings:
            try:
                # Normalize listing data for MarketListing compatibility
                normalized = self._normalize_listing_data(listing_data)
                
                # Create listing object
                listing = MarketListing(**normalized)
                
                # Record in market
                self.market.record_listing(listing)
                added_count += 1
                
                # Check for scams
                scam_alert = self.intelligence.detect_scam(listing)
                if scam_alert:
                    scam_detected += 1
                
                # Check for manipulation
                manip_alert = self.intelligence.detect_manipulation(listing.item_id)
                if manip_alert:
                    manipulation_detected += 1
            
            except Exception as e:
                self.log.error(
                    "listing_update_failed",
                    error=str(e),
                    listing=listing_data
                )
        
        result = {
            "added": added_count,
            "scams_detected": scam_detected,
            "manipulation_detected": manipulation_detected,
            "total_listings": self.market.get_market_stats()["total_listings"]
        }
        
        self.log.info("market_data_updated", **result)
        
        return result
    
    def _normalize_listing_data(self, data: dict) -> dict:
        """
        Normalize listing data to match MarketListing model.
        
        Handles field name variations and source conversions.
        
        Args:
            data: Raw listing data
            
        Returns:
            Normalized data dict
        """
        from ai_sidecar.economy.core import MarketSource
        
        normalized = data.copy()
        
        # Map alternate field names
        if "seller" in normalized and "seller_name" not in normalized:
            normalized["seller_name"] = normalized.pop("seller")
        
        if "map_name" in normalized and "location_map" not in normalized:
            normalized["location_map"] = normalized.pop("map_name")
        
        # Normalize source to MarketSource enum
        if "source" in normalized:
            source_str = normalized["source"].lower()
            # Map common variations to valid MarketSource values
            source_mapping = {
                "player_shop": MarketSource.VENDING,
                "vending": MarketSource.VENDING,
                "buying": MarketSource.BUYING,
                "npc": MarketSource.NPC,
                "npc_buy": MarketSource.NPC_BUY,
                "npc_sell": MarketSource.NPC_SELL,
                "auction": MarketSource.AUCTION,
                "trade": MarketSource.TRADE,
            }
            
            if source_str in source_mapping:
                normalized["source"] = source_mapping[source_str]
            elif not isinstance(normalized["source"], MarketSource):
                # Default to VENDING if unknown
                normalized["source"] = MarketSource.VENDING
        
        return normalized
    
    async def get_next_economic_action(
        self,
        character_state: dict,
        inventory: dict,
        zeny: int
    ) -> dict:
        """
        Get next recommended economic action.
        
        Args:
            character_state: Current character state
            inventory: Character inventory
            zeny: Current zeny
            
        Returns:
            Dict with recommended action
        """
        # Check purchase targets
        recommendations = self.buying.get_purchase_recommendations(zeny)
        
        if recommendations:
            return {
                "action": "buy",
                "recommendations": recommendations[:3],  # Top 3
                "reason": "fulfilling_purchase_targets"
            }
        
        # Check for trading opportunities
        trades = self.trading.get_recommended_trades(
            budget=zeny,
            risk_tolerance=0.5
        )
        
        if trades:
            return {
                "action": "trade",
                "opportunities": [
                    {
                        "item_id": t.item_id,
                        "item_name": t.item_name,
                        "buy_price": t.buy_price,
                        "sell_price": t.sell_price,
                        "profit": t.profit,
                        "profit_margin": t.profit_margin
                    }
                    for t in trades[:3]
                ],
                "reason": "profitable_trading_opportunities"
            }
        
        # Check if should vend
        vending_items = self.vending.select_vending_items(inventory, max_items=12)
        
        if vending_items:
            revenue = self.vending.calculate_expected_revenue(vending_items, hours=8)
            
            if revenue["expected_profit"] > 10000:
                return {
                    "action": "vend",
                    "items": [
                        {
                            "item_id": vi.item_id,
                            "item_name": vi.item_name,
                            "quantity": vi.quantity,
                            "price": vi.price
                        }
                        for vi in vending_items
                    ],
                    "expected_revenue": revenue,
                    "reason": "profitable_vending_opportunity"
                }
        
        # No immediate actions
        return {
            "action": "wait",
            "reason": "no_profitable_opportunities"
        }
    
    def evaluate_net_worth(self, inventory: dict, zeny: int) -> dict:
        """
        Calculate total net worth.
        
        Args:
            inventory: Character inventory
            zeny: Current zeny
            
        Returns:
            Dict with net worth breakdown
        """
        inventory_value = 0
        item_breakdown: List[dict] = []
        
        for item in inventory.get("items", []):
            item_id = item.get("item_id")
            quantity = item.get("amount", 1)
            
            if not item_id:
                continue
            
            # Get market price
            current_price = self.market.get_current_price(item_id)
            
            if current_price:
                unit_price = current_price["median_price"]
                total_value = unit_price * quantity
                inventory_value += total_value
                
                item_breakdown.append({
                    "item_id": item_id,
                    "item_name": item.get("name", f"Item_{item_id}"),
                    "quantity": quantity,
                    "unit_price": unit_price,
                    "total_value": total_value
                })
        
        # Sort by value
        item_breakdown.sort(key=lambda i: i["total_value"], reverse=True)
        
        total_worth = zeny + inventory_value
        
        return {
            "total_worth": total_worth,
            "liquid_zeny": zeny,
            "inventory_value": inventory_value,
            "zeny_percentage": (zeny / total_worth * 100) if total_worth > 0 else 0,
            "top_assets": item_breakdown[:10]
        }
    
    def get_daily_report(self) -> dict:
        """
        Generate daily economic report.
        
        Returns:
            Dict with daily economic report
        """
        market_health = self.intelligence.analyze_market_health()
        hot_items = self.intelligence.get_hot_items(limit=5)
        undervalued = self.intelligence.get_undervalued_items(limit=5)
        predictions = self.intelligence.predict_market_events(days_ahead=1)
        
        return {
            "date": str(self.log._context.get("timestamp", "")),
            "market_health": market_health,
            "hot_items": hot_items,
            "undervalued_items": undervalued,
            "predicted_events": predictions,
            "recent_alerts": [
                {
                    "type": a.alert_type,
                    "item": a.item_name,
                    "severity": a.severity,
                    "description": a.description
                }
                for a in self.intelligence.get_recent_alerts()[-5:]
            ]
        }
    
    def get_trading_summary(self, days: int = 7) -> dict:
        """
        Get trading activity summary.
        
        Args:
            days: Days to summarize
            
        Returns:
            Dict with trading summary
        """
        # Get arbitrage opportunities
        arbitrage = self.trading.find_arbitrage_opportunities(
            min_profit=1000,
            min_margin=0.05
        )
        
        # Get flip opportunities
        flips = self.trading.find_flip_opportunities(
            min_profit=5000,
            max_risk=0.5
        )
        
        total_potential = sum(
            opp.profit * opp.quantity_available
            for opp in arbitrage + flips
        )
        
        return {
            "period_days": days,
            "arbitrage_opportunities": len(arbitrage),
            "flip_opportunities": len(flips),
            "total_opportunities": len(arbitrage) + len(flips),
            "total_potential_profit": total_potential,
            "top_opportunities": [
                {
                    "item_id": opp.item_id,
                    "item_name": opp.item_name,
                    "profit": opp.profit,
                    "margin": opp.profit_margin,
                    "strategy": "arbitrage" if opp in arbitrage else "flip"
                }
                for opp in sorted(
                    arbitrage + flips,
                    key=lambda o: o.profit,
                    reverse=True
                )[:10]
            ]
        }
    
    def get_profit_analysis(self, days: int = 7) -> dict:
        """
        Analyze profit/loss over period.
        
        Args:
            days: Days to analyze
            
        Returns:
            Dict with profit analysis
        """
        # This would require transaction history tracking
        # For now, return structure
        
        return {
            "period_days": days,
            "total_income": 0,
            "total_expenses": 0,
            "net_profit": 0,
            "profit_margin": 0.0,
            "best_trades": [],
            "worst_trades": []
        }
    
    def get_statistics(self) -> dict:
        """
        Get comprehensive economic statistics.
        
        Returns:
            Dict with all economic statistics
        """
        market_stats = self.market.get_market_stats()
        market_health = self.intelligence.analyze_market_health()
        
        return {
            "market": market_stats,
            "health": market_health,
            "purchase_targets": len(self.buying.purchase_targets),
            "active_alerts": len(self.intelligence.alerts),
            "tracked_items": len(self.market.price_history),
            "vending_locations": len(self.vending.locations)
        }
    
    def add_purchase_target(
        self,
        item_id: int,
        item_name: str,
        max_price: int,
        quantity: int,
        priority: str = "normal"
    ) -> None:
        """
        Add item to purchase list.
        
        Args:
            item_id: Item ID
            item_name: Item name
            max_price: Maximum price to pay
            quantity: Quantity needed
            priority: Purchase priority
        """
        from ai_sidecar.economy.buying import PurchasePriority
        
        target = PurchaseTarget(
            item_id=item_id,
            item_name=item_name,
            max_price=max_price,
            priority=PurchasePriority(priority),
            quantity_needed=quantity,
            quantity_owned=0
        )
        
        self.buying.add_purchase_target(target)
        
        self.log.info(
            "purchase_target_added",
            item_id=item_id,
            item_name=item_name,
            max_price=max_price
        )
    
    def cleanup_old_data(self, days: int = 30) -> dict:
        """
        Clean up old data from all systems.
        
        Args:
            days: Age threshold in days
            
        Returns:
            Dict with cleanup results
        """
        market_cleaned = self.market.cleanup_old_data(days)
        alerts_cleaned = self.intelligence.clear_old_alerts(days * 24)
        
        result = {
            "market_entries_removed": market_cleaned,
            "alerts_cleared": alerts_cleaned,
            "total_cleaned": market_cleaned + alerts_cleaned
        }
        
        self.log.info("cleanup_completed", **result)
        
        return result