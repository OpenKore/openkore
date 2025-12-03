"""
Comprehensive tests for companions/mount.py module.

Tests mount system intelligence including:
- Mount/dismount decisions
- Speed calculations
- Mado Gear fuel management
- Cart weight optimization
- Skill-based dismounting
"""

import pytest
from datetime import datetime
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.companions.mount import (
    MountType,
    MountState,
    MountConfig,
    MountDecision,
    RefuelAction,
    CartOptimization,
    MountManager
)


class TestMountModels:
    """Test Pydantic models for mount system."""
    
    def test_mount_state_creation(self):
        """Test MountState model creation."""
        state = MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO
        )
        assert state.is_mounted is True
        assert state.mount_type == MountType.PECO_PECO
        assert state.has_cart is False
    
    def test_mount_state_with_mado_fuel(self):
        """Test MountState with Mado Gear fuel."""
        state = MountState(
            is_mounted=True,
            mount_type=MountType.MADO_GEAR,
            fuel=50,
            fuel_max=100
        )
        assert state.fuel == 50
        assert state.fuel_max == 100
    
    def test_mount_state_with_cart(self):
        """Test MountState with cart."""
        state = MountState(
            has_cart=True,
            cart_weight=4000,
            cart_max_weight=8000
        )
        assert state.has_cart is True
        assert state.cart_weight == 4000
        assert state.cart_max_weight == 8000
    
    def test_mount_config_defaults(self):
        """Test MountConfig default values."""
        config = MountConfig()
        assert config.auto_mount is True
        assert config.auto_dismount_for_skills is True
        assert config.min_travel_distance == 10
        assert config.refuel_threshold == 20
        assert config.cart_weight_target == 0.8
    
    def test_mount_config_custom(self):
        """Test MountConfig with custom values."""
        config = MountConfig(
            auto_mount=False,
            min_travel_distance=20,
            refuel_threshold=30
        )
        assert config.auto_mount is False
        assert config.min_travel_distance == 20
        assert config.refuel_threshold == 30


class TestMountManagerInit:
    """Test MountManager initialization."""
    
    def test_init_default_config(self):
        """Test initialization with default config."""
        manager = MountManager()
        assert manager.config is not None
        assert manager.current_state is None
        assert manager._player_class == "generic"
    
    def test_init_custom_config(self):
        """Test initialization with custom config."""
        config = MountConfig(auto_mount=False)
        manager = MountManager(config=config)
        assert manager.config.auto_mount is False
    
    def test_set_player_class_rune_knight(self):
        """Test setting Rune Knight class."""
        manager = MountManager()
        manager.set_player_class("Rune_Knight")
        assert manager._available_mount == MountType.DRAGON
    
    def test_set_player_class_royal_guard(self):
        """Test setting Royal Guard class."""
        manager = MountManager()
        manager.set_player_class("Royal_Guard")
        assert manager._available_mount == MountType.GRYPHON
    
    def test_set_player_class_ranger(self):
        """Test setting Ranger class."""
        manager = MountManager()
        manager.set_player_class("Ranger")
        assert manager._available_mount == MountType.WARG
    
    def test_set_player_class_mechanic(self):
        """Test setting Mechanic class."""
        manager = MountManager()
        manager.set_player_class("Mechanic")
        assert manager._available_mount == MountType.MADO_GEAR
    
    def test_set_player_class_knight(self):
        """Test setting Knight class."""
        manager = MountManager()
        manager.set_player_class("Knight")
        assert manager._available_mount == MountType.PECO_PECO
    
    def test_set_player_class_no_mount(self):
        """Test setting class without mount."""
        manager = MountManager()
        manager.set_player_class("Priest")
        assert manager._available_mount is None


class TestUpdateState:
    """Test state updates."""
    
    @pytest.mark.asyncio
    async def test_update_state_basic(self):
        """Test basic state update."""
        manager = MountManager()
        state = MountState(is_mounted=True, mount_type=MountType.PECO_PECO)
        
        await manager.update_state(state)
        assert manager.current_state == state
    
    @pytest.mark.asyncio
    async def test_update_state_mado_low_fuel_warning(self):
        """Test warning on low Mado Gear fuel."""
        manager = MountManager(config=MountConfig(refuel_threshold=30))
        state = MountState(
            is_mounted=True,
            mount_type=MountType.MADO_GEAR,
            fuel=20,
            fuel_max=100
        )
        
        await manager.update_state(state)
        
        # Verify state was updated (warning is logged via structlog)
        assert manager.current_state == state
        assert manager.current_state.fuel == 20


class TestShouldMount:
    """Test mount/dismount decisions."""
    
    @pytest.mark.asyncio
    async def test_should_mount_no_state(self):
        """Test decision when no state available."""
        manager = MountManager()
        decision = await manager.should_mount()
        
        assert decision.should_mount is False
        assert "no_state_available" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_no_available_mount(self):
        """Test decision when class has no mount."""
        manager = MountManager()
        manager.set_player_class("Priest")
        await manager.update_state(MountState())
        
        decision = await manager.should_mount(distance_to_destination=50)
        
        assert decision.should_mount is False
        assert "no_mount_available" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_skill_requires_dismount(self):
        """Test dismount for restricted skill."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO
        ))
        
        decision = await manager.should_mount(skill_to_use="Bowling Bash")
        
        assert decision.should_mount is False
        assert "dismount_for_skill" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_mado_no_fuel(self):
        """Test Mado Gear with no fuel."""
        manager = MountManager()
        manager.set_player_class("Mechanic")
        await manager.update_state(MountState(
            mount_type=MountType.MADO_GEAR,
            fuel=0,
            fuel_max=100
        ))
        
        decision = await manager.should_mount()
        
        assert decision.should_mount is False
        assert "no_fuel" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_already_mounted_stay(self):
        """Test staying mounted when already mounted."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO
        ))
        
        decision = await manager.should_mount()
        
        assert decision.should_mount is True
        assert "already_mounted" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_long_distance(self):
        """Test mounting for long distance travel."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState())
        
        decision = await manager.should_mount(distance_to_destination=50)
        
        assert decision.should_mount is True
        assert "long_distance" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_short_distance_no_mount(self):
        """Test not mounting for short distance."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState())
        
        decision = await manager.should_mount(distance_to_destination=5)
        
        assert decision.should_mount is False
    
    @pytest.mark.asyncio
    async def test_should_mount_in_combat_no_mount(self):
        """Test not mounting during combat."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState())
        
        decision = await manager.should_mount(in_combat=True, distance_to_destination=20)
        
        assert decision.should_mount is False
        assert "combat" in decision.reason
    
    @pytest.mark.asyncio
    async def test_should_mount_auto_disabled(self):
        """Test with auto-mount disabled."""
        manager = MountManager(config=MountConfig(auto_mount=False))
        manager.set_player_class("Knight")
        await manager.update_state(MountState())
        
        decision = await manager.should_mount(distance_to_destination=50)
        
        assert decision.should_mount is False
        assert "auto_mount_disabled" in decision.reason


class TestMadoFuelManagement:
    """Test Mado Gear fuel management."""
    
    @pytest.mark.asyncio
    async def test_manage_fuel_no_state(self):
        """Test fuel management with no state."""
        manager = MountManager()
        action = await manager.manage_mado_fuel()
        
        assert action is None
    
    @pytest.mark.asyncio
    async def test_manage_fuel_not_mado_gear(self):
        """Test fuel management for non-Mado mount."""
        manager = MountManager()
        await manager.update_state(MountState(
            mount_type=MountType.PECO_PECO
        ))
        
        action = await manager.manage_mado_fuel()
        
        assert action is None
    
    @pytest.mark.asyncio
    async def test_manage_fuel_low_fuel_refuel_needed(self):
        """Test refuel recommendation when fuel low."""
        manager = MountManager(config=MountConfig(refuel_threshold=25))
        await manager.update_state(MountState(
            mount_type=MountType.MADO_GEAR,
            fuel=20,
            fuel_max=100
        ))
        
        action = await manager.manage_mado_fuel()
        
        assert action is not None
        assert action.should_refuel is True
        assert action.fuel_needed == 80
    
    @pytest.mark.asyncio
    async def test_manage_fuel_sufficient_no_refuel(self):
        """Test no refuel when fuel sufficient."""
        manager = MountManager(config=MountConfig(refuel_threshold=20))
        await manager.update_state(MountState(
            mount_type=MountType.MADO_GEAR,
            fuel=50,
            fuel_max=100
        ))
        
        action = await manager.manage_mado_fuel()
        
        assert action is not None
        assert action.should_refuel is False
        assert action.fuel_needed == 0


class TestCartOptimization:
    """Test cart weight optimization."""
    
    @pytest.mark.asyncio
    async def test_optimize_cart_no_cart(self):
        """Test optimization when no cart."""
        manager = MountManager()
        await manager.update_state(MountState())
        
        result = await manager.optimize_cart_weight()
        
        assert result.action == "maintain"
        assert "no_cart" in result.reason
    
    @pytest.mark.asyncio
    async def test_optimize_cart_vending_mode_fill(self):
        """Test cart filling for vending mode."""
        manager = MountManager()
        await manager.update_state(MountState(
            has_cart=True,
            cart_weight=4000,
            cart_max_weight=8000
        ))
        
        result = await manager.optimize_cart_weight(vending_mode=True)
        
        assert result.action == "fill"
        assert result.current_ratio == 0.5
        assert result.target_ratio == 0.9
    
    @pytest.mark.asyncio
    async def test_optimize_cart_full_cant_loot(self):
        """Test lightening cart when too full to loot."""
        manager = MountManager()
        await manager.update_state(MountState(
            has_cart=True,
            cart_weight=7500,
            cart_max_weight=8000
        ))
        
        result = await manager.optimize_cart_weight(items_to_pickup=10)
        
        assert result.action == "lighten"
        assert "cant_loot" in result.reason
    
    @pytest.mark.asyncio
    async def test_optimize_cart_over_target(self):
        """Test lightening when over target weight."""
        manager = MountManager(config=MountConfig(cart_weight_target=0.6))
        await manager.update_state(MountState(
            has_cart=True,
            cart_weight=6000,
            cart_max_weight=8000
        ))
        
        result = await manager.optimize_cart_weight()
        
        assert result.action == "lighten"
        assert result.current_ratio == 0.75
    
    @pytest.mark.asyncio
    async def test_optimize_cart_under_target(self):
        """Test filling when under target weight."""
        manager = MountManager(config=MountConfig(cart_weight_target=0.8))
        await manager.update_state(MountState(
            has_cart=True,
            cart_weight=3000,
            cart_max_weight=8000
        ))
        
        result = await manager.optimize_cart_weight()
        
        assert result.action == "fill"
        assert "underutilized" in result.reason
    
    @pytest.mark.asyncio
    async def test_optimize_cart_optimal_weight(self):
        """Test maintaining optimal weight."""
        manager = MountManager(config=MountConfig(cart_weight_target=0.8))
        await manager.update_state(MountState(
            has_cart=True,
            cart_weight=6400,
            cart_max_weight=8000
        ))
        
        result = await manager.optimize_cart_weight()
        
        assert result.action == "maintain"
        assert "optimal" in result.reason


class TestSpeedBonus:
    """Test movement speed calculations."""
    
    def test_speed_bonus_not_mounted(self):
        """Test speed bonus when not mounted."""
        manager = MountManager()
        manager.current_state = MountState()
        
        bonus = manager.get_speed_bonus()
        
        assert bonus == 1.0
    
    def test_speed_bonus_mounted_peco(self):
        """Test speed bonus with Peco mount."""
        manager = MountManager()
        manager.current_state = MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO
        )
        
        bonus = manager.get_speed_bonus()
        
        assert bonus == 1.25
    
    def test_speed_bonus_with_cart_empty(self):
        """Test speed with empty cart."""
        manager = MountManager()
        manager.current_state = MountState(
            has_cart=True,
            cart_weight=0,
            cart_max_weight=8000
        )
        
        bonus = manager.get_speed_bonus()
        
        assert bonus == 1.0
    
    def test_speed_bonus_with_cart_half_full(self):
        """Test speed with half-full cart."""
        manager = MountManager()
        manager.current_state = MountState(
            has_cart=True,
            cart_weight=4000,
            cart_max_weight=8000
        )
        
        bonus = manager.get_speed_bonus()
        
        assert bonus < 1.0
        assert bonus >= 0.95
    
    def test_speed_bonus_with_cart_full(self):
        """Test speed with full cart while mounted."""
        manager = MountManager()
        manager.current_state = MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO,
            has_cart=True,
            cart_weight=8000,
            cart_max_weight=8000
        )
        
        bonus = manager.get_speed_bonus()
        
        # Mount bonus (1.25) with cart penalty (cart_ratio = 1.0, penalty = 0.1 * 1.0 = 0.1)
        # Formula: mount_bonus * (1.0 - cart_penalty) = 1.25 * 0.9 = 1.125
        assert bonus == 1.125


class TestDismountSkills:
    """Test dismount-required skills."""
    
    def test_dismount_skills_list(self):
        """Test that dismount skills list is defined."""
        assert "Bowling Bash" in MountManager.DISMOUNT_REQUIRED_SKILLS
        assert "Charge Attack" in MountManager.DISMOUNT_REQUIRED_SKILLS
        assert "Grand Cross" in MountManager.DISMOUNT_REQUIRED_SKILLS
    
    @pytest.mark.asyncio
    async def test_combat_dismount_for_skill(self):
        """Test dismounting in combat for restricted skill."""
        manager = MountManager()
        manager.set_player_class("Knight")
        await manager.update_state(MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO
        ))
        
        decision = await manager.should_mount(
            in_combat=True,
            skill_to_use="Magnum Break"
        )
        
        assert decision.should_mount is False
        assert "dismount_for_skill" in decision.reason or "combat_requires_dismount" in decision.reason