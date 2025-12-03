"""
Comprehensive tests for recovery item management - Batch 4.

Tests HP/SP recovery, emergency handling, and item selection.
"""

from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

import pytest

from ai_sidecar.consumables.recovery import (
    RecoveryConfig,
    RecoveryDecision,
    RecoveryItem,
    RecoveryManager,
    RecoveryType,
    RestockRecommendation,
)


@pytest.fixture
def recovery_manager():
    """Create RecoveryManager with default items."""
    return RecoveryManager()


@pytest.fixture
def custom_config():
    """Create custom recovery config."""
    return RecoveryConfig(
        hp_critical_threshold=0.15,
        hp_urgent_threshold=0.35,
        hp_normal_threshold=0.65,
        sp_critical_threshold=0.08,
        sp_normal_threshold=0.35,
    )


class TestRecoveryManagerInit:
    """Test RecoveryManager initialization."""
    
    def test_init_default(self):
        """Test initialization with defaults."""
        manager = RecoveryManager()
        
        assert len(manager.items_database) > 0
        assert 501 in manager.items_database  # Red Potion
    
    def test_init_with_config(self, custom_config):
        """Test initialization with custom config."""
        manager = RecoveryManager(config=custom_config)
        
        assert manager.config.hp_critical_threshold == 0.15


class TestRecoveryItemModel:
    """Test RecoveryItem model."""
    
    def test_recovery_item_creation(self):
        """Test creating recovery item."""
        item = RecoveryItem(
            item_id=501,
            item_name="Red Potion",
            recovery_type=RecoveryType.HP_INSTANT,
            base_recovery=45,
            weight=7,
            price=50,
        )
        
        assert item.item_id == 501
        assert item.base_recovery == 45


class TestRecoveryEvaluation:
    """Test recovery need evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_no_recovery_needed(self, recovery_manager):
        """Test no recovery needed at full health."""
        decision = await recovery_manager.evaluate_recovery_need(
            hp_percent=1.0,
            sp_percent=1.0,
        )
        
        assert decision is None
    
    @pytest.mark.asyncio
    async def test_evaluate_hp_recovery_needed(self, recovery_manager):
        """Test HP recovery evaluation."""
        decision = await recovery_manager.evaluate_recovery_need(
            hp_percent=0.35,
            sp_percent=1.0,
        )
        
        assert decision is not None
        assert decision.item.recovery_type in [
            RecoveryType.HP_INSTANT,
            RecoveryType.HP_PERCENT,
        ]
    
    @pytest.mark.asyncio
    async def test_evaluate_sp_recovery_needed(self, recovery_manager):
        """Test SP recovery evaluation."""
        decision = await recovery_manager.evaluate_recovery_need(
            hp_percent=1.0,
            sp_percent=0.30,
        )
        
        assert decision is not None
        # May be SP_INSTANT or HP_SP_COMBO
        assert decision.item.recovery_type in [
            RecoveryType.SP_INSTANT,
            RecoveryType.HP_SP_COMBO,
        ]
    
    @pytest.mark.asyncio
    async def test_evaluate_emergency_hp(self, recovery_manager):
        """Test emergency HP recovery."""
        decision = await recovery_manager.evaluate_recovery_need(
            hp_percent=0.15,
            sp_percent=1.0,
        )
        
        assert decision is not None
        assert decision.priority == 10


class TestEmergencyRecovery:
    """Test emergency recovery."""
    
    @pytest.mark.asyncio
    async def test_emergency_recovery(self, recovery_manager):
        """Test emergency recovery selects best item."""
        decision = await recovery_manager.emergency_recovery()
        
        assert decision is not None
        assert decision.priority == 10
        assert decision.item.recovery_type in [
            RecoveryType.EMERGENCY,
            RecoveryType.HP_SP_COMBO,
            RecoveryType.HP_INSTANT,
        ]


class TestOptimalItemSelection:
    """Test optimal item selection."""
    
    @pytest.mark.asyncio
    async def test_select_optimal_item_hp(self, recovery_manager):
        """Test selecting optimal HP item."""
        # Set inventory to have items
        recovery_manager.inventory = {501: 10, 502: 5, 503: 3, 504: 2}
        
        item = await recovery_manager.select_optimal_item(
            RecoveryType.HP_INSTANT,
            current_percent=0.50,
        )
        
        assert item is not None
        assert item.recovery_type == RecoveryType.HP_INSTANT
    
    @pytest.mark.asyncio
    async def test_select_optimal_item_no_inventory(self, recovery_manager):
        """Test selection with no inventory tracking."""
        # Empty inventory means assume items available
        recovery_manager.inventory = {}
        
        item = await recovery_manager.select_optimal_item(
            RecoveryType.HP_INSTANT,
            current_percent=0.50,
        )
        
        assert item is not None
    
    @pytest.mark.asyncio
    async def test_select_optimal_item_on_cooldown(self, recovery_manager):
        """Test selection when items on cooldown."""
        # Set cooldown
        recovery_manager.cooldowns["potion"] = datetime.now() + timedelta(seconds=5)
        
        item = await recovery_manager.select_optimal_item(
            RecoveryType.HP_INSTANT,
            current_percent=0.50,
        )
        
        # Should return None or item from different cooldown group
        if item:
            assert item.cooldown_group != "potion"


class TestItemEfficiency:
    """Test item efficiency calculation."""
    
    def test_calculate_efficiency(self, recovery_manager):
        """Test efficiency calculation."""
        item = recovery_manager.items_database[501]  # Red Potion
        
        efficiency = recovery_manager._calculate_efficiency(
            item,
            current_percent=0.50,
            situation="normal",
        )
        
        assert efficiency > 0
    
    def test_calculate_efficiency_overheal_penalty(self, recovery_manager):
        """Test overheal penalty."""
        # Use White Potion (high recovery) at high HP
        item = recovery_manager.items_database[504]
        
        efficiency_high_hp = recovery_manager._calculate_efficiency(
            item,
            current_percent=0.95,  # Almost full HP
            situation="normal",
        )
        
        efficiency_low_hp = recovery_manager._calculate_efficiency(
            item,
            current_percent=0.30,  # Low HP
            situation="normal",
        )
        
        # Should be less efficient at high HP
        assert efficiency_low_hp > efficiency_high_hp


class TestCooldownTracking:
    """Test cooldown tracking."""
    
    @pytest.mark.asyncio
    async def test_track_cooldowns(self, recovery_manager):
        """Test tracking active cooldowns."""
        # Set some cooldowns
        recovery_manager.cooldowns["potion"] = datetime.now() + timedelta(seconds=2)
        recovery_manager.cooldowns["yggdrasil"] = datetime.now() + timedelta(seconds=10)
        
        remaining = await recovery_manager.track_cooldowns()
        
        assert "potion" in remaining
        assert remaining["potion"] <= 2.0
        assert remaining["yggdrasil"] <= 10.0
    
    def test_is_on_cooldown(self, recovery_manager):
        """Test cooldown check."""
        recovery_manager.cooldowns["potion"] = datetime.now() + timedelta(seconds=5)
        
        assert recovery_manager._is_on_cooldown("potion")
        assert not recovery_manager._is_on_cooldown("yggdrasil")


class TestInventoryManagement:
    """Test inventory and restock management."""
    
    @pytest.mark.asyncio
    async def test_manage_inventory_levels(self, recovery_manager):
        """Test inventory level monitoring."""
        # Set low inventory
        recovery_manager.inventory = {501: 5, 505: 2}
        
        recommendations = await recovery_manager.manage_inventory_levels()
        
        # Should recommend restocking
        assert len(recommendations) > 0
    
    def test_update_inventory(self, recovery_manager):
        """Test updating inventory."""
        new_inventory = {501: 100, 505: 50}
        
        recovery_manager.update_inventory(new_inventory)
        
        assert recovery_manager.inventory[501] == 100


class TestItemUsage:
    """Test item usage tracking."""
    
    def test_use_item(self, recovery_manager):
        """Test using an item."""
        recovery_manager.inventory = {501: 10}
        
        recovery_manager.use_item(501, 45)
        
        # Inventory should decrease
        assert recovery_manager.inventory[501] == 9
        # History should be recorded
        assert len(recovery_manager.usage_history) == 1
    
    def test_use_item_sets_cooldown(self, recovery_manager):
        """Test item usage sets cooldown."""
        recovery_manager.use_item(501, 45)
        
        assert "potion" in recovery_manager.cooldowns


class TestBurnRateCalculation:
    """Test usage burn rate calculation."""
    
    def test_calculate_burn_rates(self, recovery_manager):
        """Test burn rate calculation."""
        # Add usage history
        now = datetime.now()
        recovery_manager.usage_history = [
            (501, now - timedelta(minutes=30), 45),
            (501, now - timedelta(minutes=20), 45),
            (501, now - timedelta(minutes=10), 45),
            (505, now - timedelta(minutes=25), 60),
        ]
        
        burn_rates = recovery_manager._calculate_burn_rates()
        
        assert 501 in burn_rates
        assert burn_rates[501] > 0


class TestThresholdAdjustment:
    """Test situational threshold adjustment."""
    
    def test_get_hp_threshold_normal(self, recovery_manager):
        """Test normal HP threshold."""
        threshold = recovery_manager._get_hp_threshold("normal")
        
        assert threshold == recovery_manager.config.hp_normal_threshold
    
    def test_get_hp_threshold_mvp(self, recovery_manager):
        """Test MVP HP threshold."""
        threshold = recovery_manager._get_hp_threshold("mvp")
        
        assert threshold == recovery_manager.config.mvp_hp_threshold
    
    def test_get_hp_threshold_woe(self, recovery_manager):
        """Test WoE HP threshold."""
        threshold = recovery_manager._get_hp_threshold("woe")
        
        assert threshold == recovery_manager.config.woe_hp_threshold


class TestPriorityCalculation:
    """Test recovery priority calculation."""
    
    def test_calculate_priority_hp_critical(self, recovery_manager):
        """Test critical HP priority."""
        priority = recovery_manager._calculate_priority(0.15, "hp")
        
        assert priority == 10
    
    def test_calculate_priority_hp_urgent(self, recovery_manager):
        """Test urgent HP priority."""
        priority = recovery_manager._calculate_priority(0.35, "hp")
        
        assert priority == 8
    
    def test_calculate_priority_hp_normal(self, recovery_manager):
        """Test normal HP priority."""
        priority = recovery_manager._calculate_priority(0.65, "hp")
        
        assert priority == 5
    
    def test_calculate_priority_sp(self, recovery_manager):
        """Test SP priority."""
        priority = recovery_manager._calculate_priority(0.08, "sp")
        
        assert priority == 7


class TestRecoveryCalculation:
    """Test recovery amount calculation."""
    
    def test_calculate_recovery_instant(self, recovery_manager):
        """Test instant recovery calculation."""
        item = recovery_manager.items_database[501]  # Red Potion
        
        recovery = recovery_manager._calculate_recovery(item, 1000.0)
        
        assert recovery == 45
    
    def test_calculate_recovery_percent(self, recovery_manager):
        """Test percentage recovery calculation."""
        item = recovery_manager.items_database[607]  # Yggdrasil Berry
        
        recovery = recovery_manager._calculate_recovery(item, 1000.0)
        
        assert recovery == 1000


class TestTypeCompatibility:
    """Test recovery type compatibility."""
    
    def test_is_type_compatible_exact(self, recovery_manager):
        """Test exact type match."""
        assert recovery_manager._is_type_compatible(
            RecoveryType.HP_INSTANT,
            RecoveryType.HP_INSTANT,
        )
    
    def test_is_type_compatible_combo_hp(self, recovery_manager):
        """Test HP/SP combo for HP."""
        assert recovery_manager._is_type_compatible(
            RecoveryType.HP_SP_COMBO,
            RecoveryType.HP_INSTANT,
        )
    
    def test_is_type_compatible_combo_sp(self, recovery_manager):
        """Test HP/SP combo for SP."""
        assert recovery_manager._is_type_compatible(
            RecoveryType.HP_SP_COMBO,
            RecoveryType.SP_INSTANT,
        )
    
    def test_is_type_compatible_emergency(self, recovery_manager):
        """Test emergency for HP."""
        assert recovery_manager._is_type_compatible(
            RecoveryType.EMERGENCY,
            RecoveryType.HP_INSTANT,
        )


class TestItemAvailability:
    """Test item availability checking."""
    
    def test_is_available_no_tracking(self, recovery_manager):
        """Test availability when not tracking inventory."""
        recovery_manager.inventory = {}
        
        # Should assume available
        assert recovery_manager._is_available(501)
    
    def test_is_available_with_inventory(self, recovery_manager):
        """Test availability with inventory."""
        recovery_manager.inventory = {501: 10, 505: 0}
        
        assert recovery_manager._is_available(501)
        assert not recovery_manager._is_available(505)