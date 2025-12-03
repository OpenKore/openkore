"""
Comprehensive tests for economy/trading.py module.

Tests trading system, shopping lists, sell rules, and vending optimization.
"""

import pytest
from unittest.mock import Mock, AsyncMock

from ai_sidecar.economy.trading import (
    ShoppingItem,
    SellRule,
    ShopItem,
    VendingItem,
    TradingSystemConfig,
    TradingSystem
)
from ai_sidecar.core.state import InventoryItem, GameState, InventoryState
from ai_sidecar.core.decision import Action, ActionType


# ShoppingItem Model Tests

class TestShoppingItemModel:
    """Test ShoppingItem pydantic model."""
    
    def test_shopping_item_creation(self):
        """Test creating shopping item."""
        item = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=50,
            desired_quantity=100,
            priority=8
        )
        assert item.item_id == 501
        assert item.max_price == 50
        assert item.priority == 8
    
    def test_shopping_item_auto_replenish(self):
        """Test auto-replenish settings."""
        item = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=50,
            desired_quantity=100,
            min_quantity=10,
            auto_replenish=True
        )
        assert item.auto_replenish is True
        assert item.min_quantity == 10


# SellRule Model Tests

class TestSellRuleModel:
    """Test SellRule pydantic model."""
    
    def test_sell_rule_creation(self):
        """Test creating sell rule."""
        rule = SellRule(
            item_pattern="Jelopy",
            sell_to="npc",
            keep_quantity=0
        )
        assert rule.item_pattern == "Jelopy"
        assert rule.sell_to == "npc"
    
    def test_sell_rule_matches_by_id(self):
        """Test matching item by ID."""
        rule = SellRule(
            item_pattern="",
            item_id=909,
            sell_to="npc"
        )
        
        item = InventoryItem(
            item_id=909,
            name="Jelopy",
            index=0,
            amount=10,
            equipped=False
        )
        
        assert rule.matches_item(item) is True
    
    def test_sell_rule_matches_by_pattern(self):
        """Test matching item by name pattern."""
        rule = SellRule(
            item_pattern=".*Potion.*",
            sell_to="npc"
        )
        
        item = InventoryItem(
            item_id=501,
            name="Red Potion",
            index=0,
            amount=5,
            equipped=False
        )
        
        assert rule.matches_item(item) is True
    
    def test_sell_rule_no_match(self):
        """Test item doesn't match rule."""
        rule = SellRule(
            item_pattern="Sword",
            sell_to="npc"
        )
        
        item = InventoryItem(
            item_id=501,
            name="Red Potion",
            index=0,
            amount=5,
            equipped=False
        )
        
        assert rule.matches_item(item) is False
    
    def test_sell_rule_invalid_regex(self):
        """Test handling invalid regex pattern."""
        rule = SellRule(
            item_pattern="[invalid(",
            sell_to="npc"
        )
        
        item = InventoryItem(
            item_id=501,
            name="Red Potion",
            index=0,
            amount=5,
            equipped=False
        )
        
        # Should handle gracefully
        assert rule.matches_item(item) is False


# TradingSystemConfig Tests

class TestTradingSystemConfig:
    """Test TradingSystemConfig model."""
    
    def test_config_defaults(self):
        """Test default configuration."""
        config = TradingSystemConfig()
        assert config.auto_buy is False
        assert config.auto_sell is True
        assert config.auto_vend is False
        assert config.max_purchase_value == 100000
        assert config.min_zeny_reserve == 50000


# TradingSystem Initialization Tests

class TestTradingSystemInit:
    """Test TradingSystem initialization."""
    
    def test_init_defaults(self):
        """Test initialization with defaults."""
        system = TradingSystem()
        assert len(system.shopping_list) == 0
        assert len(system.sell_rules) == 0
        assert system.config.auto_sell is True
    
    def test_init_with_config(self):
        """Test initialization with custom config."""
        config = TradingSystemConfig(
            auto_buy=True,
            auto_sell=False,
            max_purchase_value=200000
        )
        system = TradingSystem(config=config)
        assert system.config.auto_buy is True
        assert system.config.max_purchase_value == 200000
    
    def test_init_with_lists(self):
        """Test initialization with shopping list and rules."""
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=50, desired_quantity=100)
        ]
        sell_rules = [
            SellRule(item_pattern="Jelopy", sell_to="npc")
        ]
        
        system = TradingSystem(shopping_list=shopping_list, sell_rules=sell_rules)
        assert len(system.shopping_list) == 1
        assert len(system.sell_rules) == 1


# Tick Tests

class TestTradingSystemTick:
    """Test main trading tick."""
    
    @pytest.mark.asyncio
    async def test_tick_auto_sell_disabled(self):
        """Test tick when auto-sell is disabled."""
        config = TradingSystemConfig(auto_sell=False)
        system = TradingSystem(config=config)
        
        game_state = Mock(spec=GameState)
        
        actions = await system.tick(game_state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_tick_auto_sell_enabled(self):
        """Test tick with auto-sell enabled."""
        config = TradingSystemConfig(auto_sell=True)
        rule = SellRule(item_pattern="Jelopy", sell_to="npc")
        system = TradingSystem(config=config, sell_rules=[rule])
        
        # Create game state with inventory
        item = InventoryItem(item_id=909, name="Jelopy", index=0, amount=100, equipped=False)
        index=0,
        inventory = InventoryState(items=[item], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        actions = await system.tick(game_state)
        assert len(actions) > 0


# Evaluate Shop Tests

class TestEvaluateShop:
    """Test NPC shop evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_shop_auto_buy_disabled(self):
        """Test shop evaluation when auto-buy disabled."""
        config = TradingSystemConfig(auto_buy=False)
        system = TradingSystem(config=config)
        
        shop_items = [
            ShopItem(item_id=501, name="Red Potion", price=50, quantity=100, shop_type="npc")
        ]
        
        actions = await system.evaluate_shop(shop_items, 100000)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_evaluate_shop_insufficient_zeny(self):
        """Test shop evaluation with insufficient zeny."""
        config = TradingSystemConfig(auto_buy=True, min_zeny_reserve=50000)
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=50, desired_quantity=100)
        ]
        system = TradingSystem(config=config, shopping_list=shopping_list)
        
        # Current zeny below reserve
        actions = await system.evaluate_shop([], 40000)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_evaluate_shop_successful_purchase(self):
        """Test successful purchase from shop."""
        config = TradingSystemConfig(auto_buy=True, min_zeny_reserve=10000)
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=100, desired_quantity=50, priority=8)
        ]
        system = TradingSystem(config=config, shopping_list=shopping_list)
        
        shop_items = [
            ShopItem(item_id=501, name="Red Potion", price=50, quantity=100, shop_type="npc")
        ]
        
        actions = await system.evaluate_shop(shop_items, 50000)
        
        assert len(actions) == 1
        assert actions[0].item_id == 501
        assert actions[0].extra["quantity"] == 50
    
    @pytest.mark.asyncio
    async def test_evaluate_shop_multiple_items(self):
        """Test buying multiple items."""
        config = TradingSystemConfig(auto_buy=True, min_zeny_reserve=10000)
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=100, desired_quantity=50),
            ShoppingItem(item_id=502, name="Orange Potion", max_price=200, desired_quantity=30)
        ]
        system = TradingSystem(config=config, shopping_list=shopping_list)
        
        shop_items = [
            ShopItem(item_id=501, name="Red Potion", price=50, quantity=100, shop_type="npc"),
            ShopItem(item_id=502, name="Orange Potion", price=150, quantity=50, shop_type="npc")
        ]
        
        actions = await system.evaluate_shop(shop_items, 100000)
        
        assert len(actions) == 2


# Evaluate Vending Tests

class TestEvaluateVending:
    """Test player vending evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_vending_auto_buy_disabled(self):
        """Test vending evaluation when auto-buy disabled."""
        config = TradingSystemConfig(auto_buy=False)
        system = TradingSystem(config=config)
        
        vending_items = [
            VendingItem(item_id=501, name="Red Potion", price=50, quantity=100, seller_name="Seller1")
        ]
        
        actions = await system.evaluate_vending(vending_items, 100000)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_evaluate_vending_price_too_high(self):
        """Test skipping items above max price."""
        config = TradingSystemConfig(auto_buy=True, min_zeny_reserve=10000)
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=50, desired_quantity=100)
        ]
        system = TradingSystem(config=config, shopping_list=shopping_list)
        
        vending_items = [
            VendingItem(item_id=501, name="Red Potion", price=100, quantity=50, seller_name="Greedy")
        ]
        
        actions = await system.evaluate_vending(vending_items, 100000)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_evaluate_vending_successful_purchase(self):
        """Test successful purchase from vending."""
        config = TradingSystemConfig(auto_buy=True, min_zeny_reserve=10000)
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=100, desired_quantity=50, priority=9)
        ]
        system = TradingSystem(config=config, shopping_list=shopping_list)
        
        vending_items = [
            VendingItem(item_id=501, name="Red Potion", price=60, quantity=50, seller_name="GoodSeller")
        ]
        
        actions = await system.evaluate_vending(vending_items, 50000)
        
        assert len(actions) == 1
        assert actions[0].extra["seller"] == "GoodSeller"


# Should Buy Tests

class TestShouldBuy:
    """Test buy decision logic."""
    
    def test_should_buy_price_acceptable(self):
        """Test buying when price is acceptable."""
        system = TradingSystem()
        
        shop_item = ShopItem(
            item_id=501,
            name="Red Potion",
            price=50,
            quantity=100,
            shop_type="npc"
        )
        wanted = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=50
        )
        
        should_buy, quantity = system.should_buy(shop_item, wanted)
        assert should_buy is True
        assert quantity == 50
    
    def test_should_buy_price_too_high(self):
        """Test not buying when price too high."""
        system = TradingSystem()
        
        shop_item = ShopItem(
            item_id=501,
            name="Red Potion",
            price=150,
            quantity=100,
            shop_type="npc"
        )
        wanted = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=50
        )
        
        should_buy, quantity = system.should_buy(shop_item, wanted)
        assert should_buy is False
        assert quantity == 0
    
    def test_should_buy_limited_quantity(self):
        """Test buying limited by shop quantity."""
        system = TradingSystem()
        
        shop_item = ShopItem(
            item_id=501,
            name="Red Potion",
            price=50,
            quantity=30,
            shop_type="npc"
        )
        wanted = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=100
        )
        
        should_buy, quantity = system.should_buy(shop_item, wanted)
        assert should_buy is True
        assert quantity == 30  # Limited by shop quantity


# Should Sell Tests

class TestShouldSell:
    """Test sell decision logic."""
    
    def test_should_sell_no_matching_rule(self):
        """Test not selling when no rule matches."""
        system = TradingSystem()
        
        item = InventoryItem(
            item_id=501,
            name="Red Potion",
            index=0,
            amount=10,
            equipped=False
        )
        
        should_sell, quantity = system.should_sell(item, 10)
        assert should_sell is False
        assert quantity == 0
    
    def test_should_sell_matching_rule(self):
        """Test selling with matching rule."""
        rule = SellRule(item_pattern="Jelopy", sell_to="npc", keep_quantity=0)
        system = TradingSystem(sell_rules=[rule])
        
        item = InventoryItem(
            item_id=909,
            name="Jelopy",
            index=0,
            amount=100,
            equipped=False
        )
        
        should_sell, quantity = system.should_sell(item, 100)
        assert should_sell is True
        assert quantity == 100
    
    def test_should_sell_keep_quantity(self):
        """Test keeping minimum quantity."""
        rule = SellRule(item_pattern="Arrow", sell_to="npc", keep_quantity=50)
        system = TradingSystem(sell_rules=[rule])
        
        item = InventoryItem(
            item_id=1750,
            name="Arrow",
            index=0,
            amount=100,
            equipped=False
        )
        
        should_sell, quantity = system.should_sell(item, 100)
        assert should_sell is True
        assert quantity == 50  # Sell 50, keep 50
    
    def test_should_sell_below_keep_quantity(self):
        """Test not selling when below keep quantity."""
        rule = SellRule(item_pattern="Arrow", sell_to="npc", keep_quantity=100)
        system = TradingSystem(sell_rules=[rule])
        
        item = InventoryItem(
            item_id=1750,
            name="Arrow",
            index=0,
            amount=50,
            equipped=False
        )
        
        should_sell, quantity = system.should_sell(item, 50)
        assert should_sell is False
        assert quantity == 0
    
    def test_should_sell_highest_priority_rule(self):
        """Test using highest priority rule when multiple match."""
        rule1 = SellRule(item_pattern=".*", sell_to="npc", priority=3, keep_quantity=10)
        rule2 = SellRule(item_pattern="Jelopy", sell_to="vend", priority=7, keep_quantity=5)
        system = TradingSystem(sell_rules=[rule1, rule2])
        
        item = InventoryItem(
            item_id=909,
            name="Jelopy",
            index=0,
            amount=100,
            equipped=False
        )
        
        should_sell, quantity = system.should_sell(item, 100)
        assert should_sell is True
        assert quantity == 95  # Uses rule2 (keep 5)


# Add Shopping Item Tests

class TestAddShoppingItem:
    """Test adding items to shopping list."""
    
    def test_add_shopping_item(self):
        """Test adding item to shopping list."""
        system = TradingSystem()
        
        system.add_shopping_item(
            item_id=501,
            name="Red Potion",
            max_price=50,
            desired_quantity=100,
            priority=8
        )
        
        assert len(system.shopping_list) == 1
        assert system.shopping_list[0].item_id == 501
        assert system.shopping_list[0].priority == 8


# Add Sell Rule Tests

class TestAddSellRule:
    """Test adding sell rules."""
    
    def test_add_sell_rule(self):
        """Test adding sell rule."""
        system = TradingSystem()
        
        system.add_sell_rule(
            pattern="Jelopy",
            sell_to="npc",
            keep_quantity=0,
            sell_below_price=100
        )
        
        assert len(system.sell_rules) == 1
        assert system.sell_rules[0].item_pattern == "Jelopy"
        assert system.sell_rules[0].sell_to == "npc"


# Clear Lists Tests

class TestClearLists:
    """Test clearing shopping list and sell rules."""
    
    def test_clear_shopping_list(self):
        """Test clearing shopping list."""
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=50, desired_quantity=100)
        ]
        system = TradingSystem(shopping_list=shopping_list)
        
        assert len(system.shopping_list) == 1
        system.clear_shopping_list()
        assert len(system.shopping_list) == 0
    
    def test_clear_sell_rules(self):
        """Test clearing sell rules."""
        sell_rules = [
            SellRule(item_pattern="Jelopy", sell_to="npc")
        ]
        system = TradingSystem(sell_rules=sell_rules)
        
        assert len(system.sell_rules) == 1
        system.clear_sell_rules()
        assert len(system.sell_rules) == 0


# Setup Vend Tests

class TestSetupVend:
    """Test vending setup."""
    
    @pytest.mark.asyncio
    async def test_setup_vend_disabled(self):
        """Test vending when auto-vend disabled."""
        config = TradingSystemConfig(auto_vend=False)
        system = TradingSystem(config=config)
        
        game_state = Mock(spec=GameState)
        
        action = await system.setup_vend(game_state)
        assert action is None
    
    @pytest.mark.asyncio
    async def test_setup_vend_no_items(self):
        """Test vending with no vendable items."""
        config = TradingSystemConfig(auto_vend=True)
        system = TradingSystem(config=config)
        
        inventory = InventoryState(items=[], max_weight=2000, current_weight=0)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        action = await system.setup_vend(game_state)
        assert action is None
    
    @pytest.mark.asyncio
    async def test_setup_vend_with_items(self):
        """Test vending setup with vendable items."""
        config = TradingSystemConfig(
            auto_vend=True,
            vend_markup_percent=20.0,
            vend_location="prontera"
        )
        rule = SellRule(
            item_pattern="Jelopy",
            sell_to="vend",
            sell_below_price=100
        )
        system = TradingSystem(config=config, sell_rules=[rule])
        
        item = InventoryItem(item_id=909, name="Jelopy", index=0, amount=500, equipped=False)
        index=0,
        inventory = InventoryState(items=[item], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        action = await system.setup_vend(game_state)
        
        assert action is not None
        assert action.extra["action"] == "setup_vending"
        assert action.extra["location"] == "prontera"
        assert len(action.extra["items"]) == 1


# Get Vendable Items Tests

class TestGetVendableItems:
    """Test finding vendable items."""
    
    def test_get_vendable_items_none(self):
        """Test when no items are vendable."""
        system = TradingSystem()
        
        inventory = InventoryState(items=[], max_weight=2000, current_weight=0)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        vendable = system._get_vendable_items(game_state)
        assert vendable == []
    
    def test_get_vendable_items_with_vend_rules(self):
        """Test finding items marked for vending."""
        rule = SellRule(
            item_pattern="Jelopy",
            sell_to="vend",
            sell_below_price=100
        )
        config = TradingSystemConfig(vend_markup_percent=25.0)
        system = TradingSystem(config=config, sell_rules=[rule])
        
        item = InventoryItem(item_id=909, name="Jelopy", index=0, amount=300, equipped=False)
        index=0,
        inventory = InventoryState(items=[item], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        vendable = system._get_vendable_items(game_state)
        
        assert len(vendable) == 1
        assert vendable[0][0].item_id == 909
        assert vendable[0][1] == 125  # 100 * 1.25
    
    def test_get_vendable_items_npc_rule_ignored(self):
        """Test NPC sell rules are not included in vending."""
        rule = SellRule(
            item_pattern="Jelopy",
            sell_to="npc",
            sell_below_price=100
        )
        system = TradingSystem(sell_rules=[rule])
        
        item = InventoryItem(item_id=909, name="Jelopy", index=0, amount=300, equipped=False)
        index=0,
        inventory = InventoryState(items=[item], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        vendable = system._get_vendable_items(game_state)
        assert vendable == []


# Evaluate Selling Tests

class TestEvaluateSelling:
    """Test selling evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_selling_with_rules(self):
        """Test evaluating items to sell."""
        rule = SellRule(item_pattern="Jelopy", sell_to="npc", keep_quantity=0)
        system = TradingSystem(sell_rules=[rule])
        
        item = InventoryItem(item_id=909, name="Jelopy", index=0, amount=100, equipped=False)
        index=0,
        inventory = InventoryState(items=[item], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        actions = await system._evaluate_selling(game_state)
        
        assert len(actions) == 1
        assert actions[0].extra["action"] == "sell_to_npc"
        assert actions[0].extra["quantity"] == 100


# Integration Tests

class TestTradingSystemIntegration:
    """Test trading system integration scenarios."""
    
    @pytest.mark.asyncio
    async def test_complete_trading_scenario(self):
        """Test complete buy and sell scenario."""
        config = TradingSystemConfig(
            auto_buy=True,
            auto_sell=True,
            min_zeny_reserve=10000
        )
        shopping_list = [
            ShoppingItem(item_id=501, name="Red Potion", max_price=100, desired_quantity=100)
        ]
        sell_rules = [
            SellRule(item_pattern="Jelopy", sell_to="npc", keep_quantity=0)
        ]
        
        system = TradingSystem(
            config=config,
            shopping_list=shopping_list,
            sell_rules=sell_rules
        )
        
        # Evaluate shop
        shop_items = [
            ShopItem(item_id=501, name="Red Potion", price=50, quantity=100, shop_type="npc")
        ]
        buy_actions = await system.evaluate_shop(shop_items, 50000)
        assert len(buy_actions) == 1
        
        # Evaluate selling
        jelopy = InventoryItem(item_id=909, name="Jelopy", index=0, amount=500, equipped=False)
        index=0,
        inventory = InventoryState(items=[jelopy], max_weight=2000, current_weight=100)
        game_state = Mock(spec=GameState)
        game_state.inventory = inventory
        
        sell_actions = await system._evaluate_selling(game_state)
        assert len(sell_actions) == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])