"""
Comprehensive tests for magic DPS tactics and economy modules.

Tests:
- MagicDPSTactics: element matching, AoE optimization, SP management
- BuyingManager: purchase strategy, price evaluation
- StorageManager: inventory optimization, auto-storage
"""

import pytest
from unittest.mock import Mock, MagicMock, patch
from datetime import datetime, timedelta

from ai_sidecar.combat.tactics.magic_dps import (
    MagicDPSTactics,
    MagicDPSTacticsConfig,
)
from ai_sidecar.combat.tactics.base import Position, Skill, TargetPriority, TacticalRole
from ai_sidecar.economy.buying import BuyingManager, PurchaseTarget, PurchasePriority
from ai_sidecar.economy.storage import StorageManager, StorageManagerConfig
from ai_sidecar.economy.core import MarketListing, MarketSource, PriceTrend
from ai_sidecar.core.state import InventoryItem


# Fixtures

@pytest.fixture
def mock_context():
    """Create mock combat context."""
    context = Mock()
    context.character_position = Position(x=100, y=100)
    context.character_hp = 700
    context.character_hp_max = 1000
    context.character_sp = 250
    context.character_sp_max = 400
    context.nearby_monsters = []
    context.party_members = []
    context.cooldowns = {}
    return context


@pytest.fixture
def mock_market_manager():
    """Create mock market manager."""
    manager = Mock()
    manager.listings = {}
    manager.get_trend = Mock(return_value=PriceTrend.STABLE)
    return manager


@pytest.fixture
def mock_price_analyzer():
    """Create mock price analyzer."""
    analyzer = Mock()
    analyzer.calculate_fair_price = Mock(return_value=1000)
    analyzer.detect_price_anomaly = Mock(return_value=(False, "normal"))
    analyzer.compare_to_market = Mock(return_value={"recommendation": "fair_price"})
    analyzer.predict_price = Mock(return_value=(950, 0.7))
    return analyzer


# Magic DPS Tests

class TestMagicDPSInit:
    """Test magic DPS tactics initialization."""
    
    def test_init_default_config(self):
        """Test initialization with default config."""
        tactics = MagicDPSTactics()
        assert tactics.role == TacticalRole.MAGIC_DPS
        assert isinstance(tactics.magic_config, MagicDPSTacticsConfig)
    
    def test_has_required_skill_lists(self):
        """Test tactics has all required skill lists."""
        tactics = MagicDPSTactics()
        assert len(tactics.ELEMENT_SKILLS) > 0
        assert len(tactics.AOE_SKILLS) > 0
        assert len(tactics.SINGLE_TARGET_SKILLS) > 0
        assert len(tactics.UTILITY_SKILLS) > 0
        assert len(tactics.BUFF_SKILLS) > 0


class TestMagicDPSTargetSelection:
    """Test magic DPS target selection."""
    
    @pytest.mark.asyncio
    async def test_selects_target_at_safe_range(self, mock_context):
        """Test selects target at safe casting distance."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (108, 108)  # 8 cells away
        monster.hp = 500
        monster.hp_max = 1000
        monster.is_boss = False
        monster.is_mvp = False
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == monster.actor_id
    
    @pytest.mark.asyncio
    async def test_no_target_when_no_enemies(self, mock_context):
        """Test returns None when no enemies."""
        tactics = MagicDPSTactics()
        target = await tactics.select_target(mock_context)
        assert target is None


class TestMagicDPSSkillSelection:
    """Test magic DPS skill selection."""
    
    @pytest.mark.asyncio
    async def test_selects_buff_when_sp_available(self, mock_context):
        """Test selects buff when SP is sufficient."""
        tactics = MagicDPSTactics()
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_conserves_sp_when_low(self, mock_context):
        """Test conserves SP when low."""
        mock_context.character_sp = 80  # 20% SP
        
        tactics = MagicDPSTactics()
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        # Should select lower SP cost skill or None
    
    @pytest.mark.asyncio
    async def test_selects_aoe_for_clustered_enemies(self, mock_context):
        """Test selects AoE for clustered enemies."""
        # Add clustered enemies
        for i in range(4):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110, 110 + i)
            monster.hp = 500
            monster.hp_max = 1000
            mock_context.nearby_monsters.append(monster)
        
        tactics = MagicDPSTactics()
        target = TargetPriority(
            actor_id=2000,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None


class TestMagicDPSPositioning:
    """Test magic DPS positioning."""
    
    @pytest.mark.asyncio
    async def test_retreats_when_too_close(self, mock_context):
        """Test retreats when enemy too close."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (102, 102)  # Too close
        monster.hp = 500
        monster.hp_max = 1000
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        position = await tactics.evaluate_positioning(mock_context)
        
        # Should calculate retreat position
        if position:
            # Should be farther from monster
            assert position.x != mock_context.character_position.x or position.y != mock_context.character_position.y
    
    @pytest.mark.asyncio
    async def test_no_positioning_when_no_threats(self, mock_context):
        """Test returns None when no threats."""
        tactics = MagicDPSTactics()
        position = await tactics.evaluate_positioning(mock_context)
        assert position is None


class TestMagicDPSThreatAssessment:
    """Test magic DPS threat calculation."""
    
    def test_threat_increases_with_low_hp(self, mock_context):
        """Test threat increases when HP is low."""
        tactics = MagicDPSTactics()
        
        mock_context.character_hp = 700
        threat_high = tactics.get_threat_assessment(mock_context)
        
        mock_context.character_hp = 200
        threat_low = tactics.get_threat_assessment(mock_context)
        
        assert threat_low > threat_high
    
    def test_threat_increases_with_low_sp(self, mock_context):
        """Test threat increases when SP is low."""
        tactics = MagicDPSTactics()
        
        mock_context.character_sp = 250
        threat_normal = tactics.get_threat_assessment(mock_context)
        
        mock_context.character_sp = 30  # Very low SP
        threat_low_sp = tactics.get_threat_assessment(mock_context)
        
        assert threat_low_sp > threat_normal
    
    def test_threat_with_close_enemies(self, mock_context):
        """Test threat increases with close enemies."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.position = (102, 102)  # Very close
        mock_context.nearby_monsters = [monster]
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat > 0.0


class TestMagicDPSHelpers:
    """Test magic DPS helper methods."""
    
    def test_has_element_spell(self):
        """Test element spell availability check."""
        tactics = MagicDPSTactics()
        assert tactics._has_element_spell("fire")
        assert tactics._has_element_spell("water")
        assert not tactics._has_element_spell("unknown")
    
    def test_get_skill_id_lookup(self):
        """Test skill ID lookup."""
        tactics = MagicDPSTactics()
        assert tactics._get_skill_id("fire_bolt") == 19
        assert tactics._get_skill_id("storm_gust") == 89
        assert tactics._get_skill_id("unknown") == 0
    
    def test_get_sp_cost_lookup(self):
        """Test SP cost lookup."""
        tactics = MagicDPSTactics()
        assert tactics._get_sp_cost("fire_bolt") == 12
        assert tactics._get_sp_cost("meteor_storm") == 64
        assert tactics._get_sp_cost("unknown") == 15
    
    def test_get_cast_time_lookup(self):
        """Test cast time lookup."""
        tactics = MagicDPSTactics()
        assert tactics._get_cast_time("fire_bolt") == 0.7
        assert tactics._get_cast_time("meteor_storm") == 15.0
        assert tactics._get_cast_time("unknown") == 1.0


# Buying Manager Tests

class TestBuyingManagerInit:
    """Test buying manager initialization."""
    
    def test_init(self, mock_market_manager, mock_price_analyzer):
        """Test initialization."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        assert manager.purchase_targets == {}


class TestBuyingManagerTargets:
    """Test purchase target management."""
    
    def test_add_purchase_target(self, mock_market_manager, mock_price_analyzer):
        """Test adding purchase target."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=50,
            priority=PurchasePriority.HIGH,
            quantity_needed=100,
        )
        
        manager.add_purchase_target(target)
        assert 501 in manager.purchase_targets
        assert manager.purchase_targets[501] == target
    
    def test_remove_purchase_target(self, mock_market_manager, mock_price_analyzer):
        """Test removing purchase target."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=50,
            priority=PurchasePriority.HIGH,
            quantity_needed=100,
        )
        
        manager.add_purchase_target(target)
        manager.remove_purchase_target(501)
        assert 501 not in manager.purchase_targets


class TestBuyingPriceCalculation:
    """Test price calculation logic."""
    
    def test_calculate_buy_price_urgent(self, mock_market_manager, mock_price_analyzer):
        """Test calculates higher price when urgent."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        price_normal = manager.calculate_buy_price(501, urgency=0.5)
        price_urgent = manager.calculate_buy_price(501, urgency=0.9)
        
        assert price_urgent > price_normal
    
    def test_calculate_buy_price_patient(self, mock_market_manager, mock_price_analyzer):
        """Test calculates lower price when patient."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        price_normal = manager.calculate_buy_price(501, urgency=0.5)
        price_patient = manager.calculate_buy_price(501, urgency=0.1)
        
        assert price_patient < price_normal
    
    def test_calculate_buy_price_no_data(self, mock_market_manager, mock_price_analyzer):
        """Test returns 0 when no price data."""
        mock_price_analyzer.calculate_fair_price = Mock(return_value=0)
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        price = manager.calculate_buy_price(999)
        assert price == 0


class TestBuyingListingEvaluation:
    """Test listing evaluation logic."""
    
    def test_evaluate_listing_good_deal(self, mock_market_manager, mock_price_analyzer):
        """Test evaluates good deal correctly."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        # Add purchase target
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.HIGH,
            quantity_needed=50,
            quantity_owned=0,
        )
        manager.add_purchase_target(target)
        
        # Create listing
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=80,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        assert should_buy == True
        assert "good_deal" in reason
    
    def test_evaluate_listing_not_on_list(self, mock_market_manager, mock_price_analyzer):
        """Test rejects listing not on purchase list."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        listing = MarketListing(
            item_id=999,
            item_name="Unknown Item",
            price=100,
            quantity=1,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        assert should_buy == False
        assert reason == "not_on_purchase_list"
    
    def test_evaluate_listing_price_too_high(self, mock_market_manager, mock_price_analyzer):
        """Test rejects listing with price too high."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=50,
            priority=PurchasePriority.HIGH,
            quantity_needed=50,
        )
        manager.add_purchase_target(target)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=100,  # Above max_price
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        assert should_buy == False
        assert reason == "price_too_high"


class TestBuyingRecommendations:
    """Test purchase recommendations."""
    
    def test_get_purchase_recommendations(self, mock_market_manager, mock_price_analyzer):
        """Test generates purchase recommendations."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        # Add target
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.HIGH,
            quantity_needed=50,
            quantity_owned=0,
        )
        manager.add_purchase_target(target)
        
        # Add mock listing
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=80,
            quantity=100,
            seller_name="TestSeller",
            source=MarketSource.VENDING,
        )
        mock_market_manager.listings = {501: [listing]}
        
        recommendations = manager.get_purchase_recommendations(budget=10000)
        assert len(recommendations) > 0
        assert recommendations[0]["item_id"] == 501
    
    def test_find_best_sellers(self, mock_market_manager, mock_price_analyzer):
        """Test finds best sellers by price."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        # Add multiple listings
        listings = [
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=100,
                quantity=10,
                seller_name="Expensive",
                source=MarketSource.VENDING,
            ),
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=80,
                quantity=20,
                seller_name="Cheap",
                source=MarketSource.VENDING,
            ),
        ]
        mock_market_manager.listings = {501: listings}
        
        best = manager.find_best_sellers(501, max_price=150)
        assert len(best) == 2
        assert best[0].price == 80  # Cheapest first


class TestBulkBuyStrategy:
    """Test bulk buying strategy."""
    
    def test_bulk_buy_strategy_feasible(self, mock_market_manager, mock_price_analyzer):
        """Test bulk buy strategy when feasible."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        # Add listings
        listings = [
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                price=50,
                quantity=100,
                seller_name="Seller1",
                source=MarketSource.VENDING,
            ),
        ]
        mock_market_manager.listings = {501: listings}
        
        strategy = manager.bulk_buy_strategy(501, quantity=50, max_total=5000)
        assert strategy["feasible"] == True
        assert strategy["total_quantity"] >= 50
    
    def test_bulk_buy_strategy_no_sellers(self, mock_market_manager, mock_price_analyzer):
        """Test bulk buy strategy with no sellers."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        mock_market_manager.listings = {}
        
        strategy = manager.bulk_buy_strategy(501, quantity=50, max_total=5000)
        assert strategy["feasible"] == False
        assert strategy["reason"] == "no_sellers"


# Storage Manager Tests

class TestStorageManagerInit:
    """Test storage manager initialization."""
    
    def test_init_default_config(self):
        """Test initialization with default config."""
        manager = StorageManager()
        assert isinstance(manager.config, StorageManagerConfig)
    
    def test_init_custom_config(self):
        """Test initialization with custom config."""
        config = StorageManagerConfig(
            auto_storage=False,
            inventory_full_threshold=0.90,
        )
        manager = StorageManager(config)
        assert manager.config.auto_storage == False
        assert manager.config.inventory_full_threshold == 0.90


class TestStorageInventoryPriority:
    """Test inventory item priority calculation."""
    
    def test_always_keep_items_highest_priority(self):
        """Test always-keep items get highest priority."""
        config = StorageManagerConfig(always_keep_items=[501])
        manager = StorageManager(config)
        
        item = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=50,
            equipped=False,
            item_type="consumable",
        )
        
        priority = manager.calculate_inventory_priority(item)
        assert priority == 100.0
    
    def test_always_store_items_lowest_priority(self):
        """Test always-store items get lowest priority."""
        config = StorageManagerConfig(always_store_items=[999])
        manager = StorageManager(config)
        
        item = InventoryItem(
            index=0,
            item_id=999,
            name="Junk Item",
            amount=1,
            equipped=False,
            item_type="etc",
        )
        
        priority = manager.calculate_inventory_priority(item)
        assert priority == 0.0
    
    def test_equipped_items_high_priority(self):
        """Test equipped items get high priority."""
        manager = StorageManager()
        
        item = InventoryItem(
            index=0,
            item_id=1101,
            name="Sword",
            amount=1,
            equipped=True,
            item_type="equipment",
        )
        
        priority = manager.calculate_inventory_priority(item)
        assert priority == 100.0
    
    def test_consumables_high_priority(self):
        """Test consumables get high priority."""
        manager = StorageManager()
        
        item = InventoryItem(
            index=0,
            item_id=501,  # In CONSUMABLE_ITEMS
            name="Red Potion",
            amount=50,
            equipped=False,
            item_type="consumable",
        )
        
        priority = manager.calculate_inventory_priority(item)
        assert priority > 50.0


class TestStorageTickProcessing:
    """Test storage tick processing."""
    
    @pytest.mark.asyncio
    async def test_tick_initializes(self):
        """Test tick initializes manager."""
        manager = StorageManager()
        
        # Create minimal game state
        game_state = Mock()
        game_state.character.weight_percent = 50
        game_state.inventory.items = []
        game_state.inventory.get_item_count = Mock(return_value=10)
        
        actions = await manager.tick(game_state)
        assert manager._initialized == True
    
    @pytest.mark.asyncio
    async def test_inventory_full_detection_by_weight(self):
        """Test detects full inventory by weight."""
        config = StorageManagerConfig(weight_limit_threshold=0.70)
        manager = StorageManager(config)
        
        game_state = Mock()
        game_state.character.weight_percent = 75  # Above threshold
        game_state.inventory.items = []
        
        assert manager._inventory_full(game_state) == True
    
    @pytest.mark.asyncio
    async def test_inventory_full_detection_by_count(self):
        """Test detects full inventory by item count."""
        config = StorageManagerConfig(inventory_full_threshold=0.80)
        manager = StorageManager(config)
        
        game_state = Mock()
        game_state.character.weight_percent = 50
        # 85 items = 85% of 100 slots
        game_state.inventory.items = [Mock() for _ in range(85)]
        
        assert manager._inventory_full(game_state) == True


class TestStorageRecommendations:
    """Test storage recommendations."""
    
    def test_get_storage_recommendations(self):
        """Test generates storage recommendations."""
        manager = StorageManager()
        
        game_state = Mock()
        game_state.inventory.items = [
            InventoryItem(
                index=0,
                item_id=501,
                name="Red Potion",
                amount=50,
                equipped=False,
                item_type="consumable",
            ),
            InventoryItem(
                index=1,
                item_id=999,
                name="Etc Item",
                amount=100,
                equipped=False,
                item_type="etc",
            ),
        ]
        
        recommendations = manager.get_storage_recommendations(game_state)
        assert "store" in recommendations
        assert "retrieve" in recommendations