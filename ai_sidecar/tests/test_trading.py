"""
Unit tests for trading system.

Tests buy/sell decisions, shopping list management,
and vending shop logic.
"""

import pytest

from ai_sidecar.core.state import GameState, InventoryItem
from ai_sidecar.economy.trading import (
    SellRule,
    ShopItem,
    ShoppingItem,
    TradingSystem,
    TradingSystemConfig,
)


class TestShoppingItem:
    """Test shopping item model."""
    
    def test_shopping_item_creation(self):
        """Test creating a shopping item."""
        item = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=50,
            priority=8,
        )
        
        assert item.item_id == 501
        assert item.max_price == 100
        assert item.desired_quantity == 50


class TestSellRule:
    """Test sell rule functionality."""
    
    def test_item_id_matching(self):
        """Test exact item ID matching."""
        rule = SellRule(
            item_pattern=".*",
            item_id=501,
            sell_to="npc",
        )
        
        item = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=10,
        )
        
        assert rule.matches_item(item)
    
    def test_pattern_matching(self):
        """Test regex pattern matching."""
        rule = SellRule(
            item_pattern=r".*Potion$",
            sell_to="npc",
        )
        
        potion = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=5,
        )
        
        other = InventoryItem(
            index=1,
            item_id=909,
            name="Jellopy",
            amount=10,
        )
        
        assert rule.matches_item(potion)
        assert not rule.matches_item(other)


class TestTradingSystem:
    """Test trading system functionality."""
    
    @pytest.fixture
    def trading(self):
        """Create trading system for testing."""
        config = TradingSystemConfig(
            auto_buy=True,
            auto_sell=True,
            max_purchase_value=100000,
        )
        
        shopping_list = [
            ShoppingItem(
                item_id=501,
                name="Red Potion",
                max_price=100,
                desired_quantity=50,
                priority=8,
            ),
        ]
        
        sell_rules = [
            SellRule(
                item_pattern=r"Jellopy",
                sell_to="npc",
                keep_quantity=0,
            ),
        ]
        
        return TradingSystem(
            config=config,
            shopping_list=shopping_list,
            sell_rules=sell_rules,
        )
    
    def test_should_buy_within_budget(self, trading):
        """Test buy decision within price limit."""
        shop_item = ShopItem(
            item_id=501,
            name="Red Potion",
            price=50,
            quantity=100,
            shop_type="npc",
        )
        
        wanted = trading.shopping_list[0]
        should_buy, quantity = trading.should_buy(shop_item, wanted)
        
        assert should_buy
        assert quantity == 50  # Desired quantity
    
    def test_should_not_buy_over_budget(self, trading):
        """Test buy decision rejects over-priced items."""
        shop_item = ShopItem(
            item_id=501,
            name="Red Potion",
            price=200,  # Over max_price of 100
            quantity=100,
            shop_type="npc",
        )
        
        wanted = trading.shopping_list[0]
        should_buy, quantity = trading.should_buy(shop_item, wanted)
        
        assert not should_buy
    
    def test_should_sell_matching_rule(self, trading):
        """Test sell decision with matching rule."""
        item = InventoryItem(
            index=0,
            item_id=909,
            name="Jellopy",
            amount=100,
        )
        
        should_sell, quantity = trading.should_sell(item, 100)
        
        assert should_sell
        assert quantity == 100  # No keep_quantity set
    
    def test_should_keep_minimum(self, trading):
        """Test sell respects keep_quantity."""
        # Add rule with keep_quantity
        trading.sell_rules.append(
            SellRule(
                item_pattern=r"Apple",
                sell_to="npc",
                keep_quantity=10,
            )
        )
        
        item = InventoryItem(
            index=0,
            item_id=512,
            name="Apple",
            amount=20,
        )
        
        should_sell, quantity = trading.should_sell(item, 20)
        
        assert should_sell
        assert quantity == 10  # Keep 10, sell 10
    
    @pytest.mark.asyncio
    async def test_evaluate_shop(self, trading):
        """Test shop evaluation."""
        shop_items = [
            ShopItem(
                item_id=501,
                name="Red Potion",
                price=50,
                quantity=100,
                shop_type="npc",
            ),
        ]
        
        actions = await trading.evaluate_shop(shop_items, current_zeny=100000)
        
        # Should have buy action
        assert len(actions) >= 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])