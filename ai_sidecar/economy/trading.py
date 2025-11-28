"""
Trading system for AI Sidecar.

Implements automated buying and selling decisions based on:
- Shopping lists with price limits
- Sell rules for inventory management
- Vending shop optimization
"""

import logging
import re
from typing import TYPE_CHECKING, Literal

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.core.state import InventoryItem
from ai_sidecar.protocol.messages import Action, ActionType

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = logging.getLogger(__name__)


class ShoppingItem(BaseModel):
    """Item on shopping list with purchase constraints."""
    
    model_config = ConfigDict(frozen=False)
    
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    max_price: int = Field(ge=0, description="Maximum price willing to pay")
    desired_quantity: int = Field(ge=1, description="Target quantity to have")
    priority: int = Field(default=5, ge=1, le=10, description="Purchase priority")
    for_build: str | None = Field(
        default=None,
        description="Build-specific need (optional)"
    )
    
    # Auto-replenish settings
    min_quantity: int = Field(
        default=0,
        ge=0,
        description="Minimum quantity before auto-buy"
    )
    auto_replenish: bool = Field(
        default=False,
        description="Automatically replenish when below min"
    )


class SellRule(BaseModel):
    """Rule for automatically selling items."""
    
    model_config = ConfigDict(frozen=False)
    
    # Item matching
    item_pattern: str = Field(description="Regex pattern or item ID")
    item_id: int | None = Field(default=None, description="Specific item ID")
    
    # Sell constraints
    sell_below_price: int | None = Field(
        default=None,
        description="Only sell if price is below this"
    )
    keep_quantity: int = Field(
        default=0,
        ge=0,
        description="Always keep this many"
    )
    
    # Destination
    sell_to: Literal["npc", "vend", "storage"] = Field(
        default="npc",
        description="Where to sell the item"
    )
    
    # Priority
    priority: int = Field(
        default=5,
        ge=1,
        le=10,
        description="Rule priority (higher = more important)"
    )
    
    def matches_item(self, item: InventoryItem) -> bool:
        """
        Check if this rule matches an inventory item.
        
        Args:
            item: Inventory item to check
            
        Returns:
            True if rule applies to this item
        """
        # Exact item ID match
        if self.item_id is not None:
            return item.item_id == self.item_id
        
        # Pattern match on item name
        try:
            return bool(re.search(self.item_pattern, item.name, re.IGNORECASE))
        except re.error:
            logger.warning(f"Invalid regex pattern: {self.item_pattern}")
            return False


class ShopItem(BaseModel):
    """Item available in an NPC or player shop."""
    
    model_config = ConfigDict(frozen=True)
    
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    price: int = Field(ge=0, description="Item price")
    quantity: int = Field(default=1, ge=1, description="Available quantity")
    shop_type: Literal["npc", "vending", "buying_store"] = Field(
        description="Type of shop"
    )


class VendingItem(BaseModel):
    """Item in a player vending shop."""
    
    model_config = ConfigDict(frozen=True)
    
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    price: int = Field(ge=0, description="Listed price")
    quantity: int = Field(ge=1, description="Available quantity")
    seller_name: str = Field(default="", description="Vendor character name")


class TradingSystemConfig(BaseModel):
    """Configuration for trading system."""
    
    model_config = ConfigDict(frozen=True)
    
    # Features
    auto_buy: bool = Field(default=False, description="Enable auto-buying")
    auto_sell: bool = Field(default=True, description="Enable auto-selling")
    auto_vend: bool = Field(default=False, description="Enable auto-vending")
    
    # Limits
    max_purchase_value: int = Field(
        default=100000,
        description="Maximum single purchase value"
    )
    min_zeny_reserve: int = Field(
        default=50000,
        description="Always keep this much zeny"
    )
    
    # Vending
    vend_markup_percent: float = Field(
        default=10.0,
        ge=0.0,
        description="Markup percentage for vending"
    )
    vend_location: str | None = Field(
        default=None,
        description="Preferred vending location map"
    )


class TradingSystem:
    """
    Automated buying and selling decision system.
    
    Manages:
    - Shopping list automation
    - Item selling based on rules
    - Vending shop optimization
    """
    
    def __init__(
        self,
        config: TradingSystemConfig | None = None,
        shopping_list: list[ShoppingItem] | None = None,
        sell_rules: list[SellRule] | None = None,
    ):
        """
        Initialize trading system.
        
        Args:
            config: Trading configuration
            shopping_list: Items to auto-purchase
            sell_rules: Rules for auto-selling
        """
        self.config = config or TradingSystemConfig()
        self.shopping_list = shopping_list or []
        self.sell_rules = sell_rules or []
        
        # State tracking
        self._last_shop_check: int = 0
        self._vending_active: bool = False
        
        logger.info("TradingSystem initialized")
    
    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main trading tick.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of trading actions
        """
        actions: list[Action] = []
        
        # Check if we should sell items
        if self.config.auto_sell:
            sell_actions = await self._evaluate_selling(game_state)
            actions.extend(sell_actions)
        
        # Note: Shop evaluation would be triggered when near NPC/vending
        # Not implemented in this tick-based approach
        
        return actions
    
    async def evaluate_shop(
        self,
        shop_items: list[ShopItem],
        current_zeny: int,
    ) -> list[Action]:
        """
        Evaluate NPC shop and decide purchases.
        
        Args:
            shop_items: Items available in shop
            current_zeny: Character's current zeny
            
        Returns:
            List of buy actions
        """
        if not self.config.auto_buy:
            return []
        
        actions: list[Action] = []
        available_budget = current_zeny - self.config.min_zeny_reserve
        
        if available_budget <= 0:
            return []
        
        # Match shop items against shopping list
        for shop_item in shop_items:
            for wanted in self.shopping_list:
                if shop_item.item_id != wanted.item_id:
                    continue
                
                should_buy, quantity = self.should_buy(shop_item, wanted)
                
                if should_buy and quantity > 0:
                    total_cost = shop_item.price * quantity
                    
                    # Check budget
                    if total_cost <= available_budget:
                        actions.append(
                            Action(
                                action_type=ActionType.NOOP,  # Placeholder
                                priority=wanted.priority,
                                item_id=shop_item.item_id,
                                extra={
                                    "action": "buy",
                                    "quantity": quantity,
                                    "price": shop_item.price,
                                },
                            )
                        )
                        available_budget -= total_cost
                        logger.info(
                            f"Buy: {shop_item.name} x{quantity} "
                            f"@ {shop_item.price} zeny each"
                        )
        
        return actions
    
    async def evaluate_vending(
        self,
        vending_items: list[VendingItem],
        current_zeny: int,
    ) -> list[Action]:
        """
        Evaluate player vending shop and decide purchases.
        
        Similar to evaluate_shop but for player vendors.
        
        Args:
            vending_items: Items in vending shop
            current_zeny: Character's current zeny
            
        Returns:
            List of buy actions
        """
        if not self.config.auto_buy:
            return []
        
        actions: list[Action] = []
        available_budget = current_zeny - self.config.min_zeny_reserve
        
        if available_budget <= 0:
            return []
        
        # Similar logic to evaluate_shop
        for vend_item in vending_items:
            for wanted in self.shopping_list:
                if vend_item.item_id != wanted.item_id:
                    continue
                
                # Check price
                if vend_item.price > wanted.max_price:
                    continue
                
                # Determine quantity to buy
                quantity = min(vend_item.quantity, wanted.desired_quantity)
                total_cost = vend_item.price * quantity
                
                if total_cost <= available_budget:
                    logger.info(
                        f"Vending buy: {vend_item.name} x{quantity} "
                        f"@ {vend_item.price} from {vend_item.seller_name}"
                    )
                    # Would create buy action here
        
        return actions
    
    async def setup_vend(
        self,
        game_state: "GameState",
    ) -> Action | None:
        """
        Set up vending shop with optimal prices.
        
        Args:
            game_state: Current game state
            
        Returns:
            Vending setup action or None
        """
        if not self.config.auto_vend:
            return None
        
        # Get items to vend from inventory
        vend_items = self._get_vendable_items(game_state)
        
        if not vend_items:
            return None
        
        logger.info(f"Setting up vend with {len(vend_items)} items")
        
        # Would create vending setup action here
        return None
    
    def should_buy(
        self,
        shop_item: ShopItem,
        wanted: ShoppingItem,
    ) -> tuple[bool, int]:
        """
        Determine if item should be bought and quantity.
        
        Args:
            shop_item: Item in shop
            wanted: Shopping list item
            
        Returns:
            Tuple of (should_buy, quantity)
        """
        # Check price constraint
        if shop_item.price > wanted.max_price:
            return (False, 0)
        
        # Calculate needed quantity
        # Note: Would need to check current inventory quantity
        quantity = min(shop_item.quantity, wanted.desired_quantity)
        
        return (True, quantity)
    
    def should_sell(
        self,
        item: InventoryItem,
        current_quantity: int,
    ) -> tuple[bool, int]:
        """
        Determine if item should be sold and quantity.
        
        Args:
            item: Inventory item
            current_quantity: Current quantity of this item
            
        Returns:
            Tuple of (should_sell, quantity)
        """
        # Find matching sell rule
        matching_rule: SellRule | None = None
        highest_priority = -1
        
        for rule in self.sell_rules:
            if rule.matches_item(item) and rule.priority > highest_priority:
                matching_rule = rule
                highest_priority = rule.priority
        
        if matching_rule is None:
            return (False, 0)
        
        # Calculate quantity to sell (keeping minimum)
        quantity_to_sell = max(0, current_quantity - matching_rule.keep_quantity)
        
        if quantity_to_sell <= 0:
            return (False, 0)
        
        return (True, quantity_to_sell)
    
    async def _evaluate_selling(
        self,
        game_state: "GameState",
    ) -> list[Action]:
        """
        Evaluate inventory for items to sell.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of sell actions
        """
        actions: list[Action] = []
        
        for inv_item in game_state.inventory.items:
            should_sell, quantity = self.should_sell(
                inv_item,
                inv_item.amount,
            )
            
            if should_sell and quantity > 0:
                logger.info(f"Sell: {inv_item.name} x{quantity}")
                # Would create sell action here
        
        return actions
    
    def _get_vendable_items(
        self,
        game_state: "GameState",
    ) -> list[tuple[InventoryItem, int]]:
        """
        Get items suitable for vending.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of (item, price) tuples
        """
        vendable: list[tuple[InventoryItem, int]] = []
        
        for inv_item in game_state.inventory.items:
            # Check sell rules for vending
            for rule in self.sell_rules:
                if (
                    rule.matches_item(inv_item)
                    and rule.sell_to == "vend"
                ):
                    # Calculate vending price
                    base_price = rule.sell_below_price or 1000
                    vend_price = int(base_price * (1 + self.config.vend_markup_percent / 100))
                    vendable.append((inv_item, vend_price))
                    break
        
        return vendable
    
    def add_shopping_item(
        self,
        item_id: int,
        name: str,
        max_price: int,
        desired_quantity: int,
        priority: int = 5,
    ) -> None:
        """
        Add item to shopping list.
        
        Args:
            item_id: Item database ID
            name: Item name
            max_price: Maximum price to pay
            desired_quantity: Target quantity
            priority: Purchase priority
        """
        self.shopping_list.append(
            ShoppingItem(
                item_id=item_id,
                name=name,
                max_price=max_price,
                desired_quantity=desired_quantity,
                priority=priority,
            )
        )
        logger.info(f"Added to shopping list: {name} (max {max_price}z)")
    
    def add_sell_rule(
        self,
        pattern: str,
        sell_to: Literal["npc", "vend", "storage"] = "npc",
        keep_quantity: int = 0,
        sell_below_price: int | None = None,
    ) -> None:
        """
        Add sell rule.
        
        Args:
            pattern: Item name pattern or item ID
            sell_to: Where to sell
            keep_quantity: Minimum to keep
            sell_below_price: Price constraint
        """
        self.sell_rules.append(
            SellRule(
                item_pattern=pattern,
                sell_to=sell_to,
                keep_quantity=keep_quantity,
                sell_below_price=sell_below_price,
            )
        )
        logger.info(f"Added sell rule: {pattern} -> {sell_to}")
    
    def clear_shopping_list(self) -> None:
        """Clear the shopping list."""
        self.shopping_list.clear()
        logger.info("Shopping list cleared")
    
    def clear_sell_rules(self) -> None:
        """Clear all sell rules."""
        self.sell_rules.clear()
        logger.info("Sell rules cleared")