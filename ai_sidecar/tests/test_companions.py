"""
Comprehensive test suite for companion systems.

Tests all companion managers:
- Pet management (feeding, intimacy, evolution)
- Homunculus AI (stats, skills, evolution)
- Mercenary control (contracts, skills, positioning)
- Mount system (mounting, fuel, cart)
- Coordinator (action prioritization)
"""

import pytest

from ai_sidecar.companions.coordinator import CompanionCoordinator, GameState
from ai_sidecar.companions.homunculus import (
    HomunculusManager,
    HomunculusState,
    HomunculusType,
)
from ai_sidecar.companions.mercenary import (
    MercenaryConfig,
    MercenaryManager,
    MercenaryState,
    MercenaryType,
)
from ai_sidecar.companions.mount import MountConfig, MountManager, MountState, MountType
from ai_sidecar.companions.pet import PetConfig, PetManager, PetState, PetType


class TestPetManager:
    """Test pet management logic."""
    
    @pytest.fixture
    def pet_manager(self):
        """Create pet manager for testing."""
        return PetManager()
    
    @pytest.fixture
    def pet_state(self):
        """Create sample pet state."""
        return PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            name="TestPoring",
            intimacy=500,
            hunger=80,
            is_summoned=True
        )
    
    @pytest.mark.asyncio
    async def test_feed_timing_emergency(self, pet_manager, pet_state):
        """Test emergency feeding at critically low hunger."""
        pet_state.hunger = 5
        await pet_manager.update_state(pet_state)
        
        decision = await pet_manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is True
        assert "emergency" in decision.reason
    
    @pytest.mark.asyncio
    async def test_feed_timing_optimal(self, pet_manager, pet_state):
        """Test optimal feeding at hunger 25-35."""
        pet_state.hunger = 30
        pet_state.intimacy = 800
        await pet_manager.update_state(pet_state)
        
        decision = await pet_manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is True
        assert "optimal" in decision.reason
        assert decision.expected_intimacy_gain > 0
    
    @pytest.mark.asyncio
    async def test_feed_timing_high_hunger(self, pet_manager, pet_state):
        """Test no feeding when hunger is high."""
        pet_state.hunger = 95
        await pet_manager.update_state(pet_state)
        
        decision = await pet_manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is False
    
    @pytest.mark.asyncio
    async def test_evolution_eligibility(self, pet_manager, pet_state):
        """Test evolution eligibility detection."""
        pet_state.intimacy = 920  # Above threshold
        await pet_manager.update_state(pet_state)
        
        decision = await pet_manager.evaluate_evolution()
        
        assert decision is not None
        assert decision.should_evolve is True
        assert decision.target == PetType.DROPS
    
    @pytest.mark.asyncio
    async def test_evolution_low_intimacy(self, pet_manager, pet_state):
        """Test evolution rejection with low intimacy."""
        pet_state.intimacy = 500  # Below threshold
        await pet_manager.update_state(pet_state)
        
        decision = await pet_manager.evaluate_evolution()
        
        assert decision is not None
        assert decision.should_evolve is False
    
    @pytest.mark.asyncio
    async def test_pet_selection_farming(self, pet_manager):
        """Test pet selection for farming situation."""
        pet_type = await pet_manager.select_optimal_pet("farming")
        
        assert pet_type in [PetType.DROPS, PetType.YOYO]
    
    @pytest.mark.asyncio
    async def test_skill_coordination(self, pet_manager, pet_state):
        """Test pet skill coordination."""
        await pet_manager.update_state(pet_state)
        
        skill = await pet_manager.coordinate_pet_skills(
            combat_active=True,
            player_hp_percent=0.4,
            enemies_nearby=2
        )
        
        # May or may not use skill depending on pet type
        assert skill is None or skill.skill_name in ["Heal"]


class TestHomunculusManager:
    """Test homunculus AI."""
    
    @pytest.fixture
    def homun_manager(self):
        """Create homunculus manager for testing."""
        return HomunculusManager()
    
    @pytest.fixture
    def homun_state(self):
        """Create sample homunculus state."""
        return HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=500,
            max_hp=1000,
            sp=100,
            max_sp=200,
            stat_str=15,
            agi=20,
            vit=25,
            int_stat=40,
            dex=30,
            luk=15,
            skills={"Healing Hands": 3},
            skill_points=10
        )
    
    @pytest.mark.asyncio
    async def test_stat_distribution_eira(self, homun_manager, homun_state):
        """Test INT/DEX distribution for Eira build."""
        await homun_manager.set_target_build(HomunculusType.EIRA)
        await homun_manager.update_state(homun_state)
        
        allocation = await homun_manager.calculate_stat_distribution()
        
        assert allocation is not None
        assert allocation.stat_name in ["int", "dex", "vit"]
    
    @pytest.mark.asyncio
    async def test_skill_allocation(self, homun_manager, homun_state):
        """Test skill point allocation."""
        await homun_manager.update_state(homun_state)
        
        allocation = await homun_manager.allocate_skill_points()
        
        assert allocation is not None
        assert allocation.skill_name in ["Healing Hands", "Urgent Escape", "Brain Surgery"]
        assert allocation.target_level > allocation.current_level
    
    @pytest.mark.asyncio
    async def test_evolution_requirements(self, homun_manager, homun_state):
        """Test evolution requirements check."""
        homun_state.level = 99
        homun_state.intimacy = 920
        await homun_manager.update_state(homun_state)
        
        decision = await homun_manager.decide_evolution_path()
        
        assert decision.should_evolve is True
        assert decision.requirements_met["level_99"] is True
        assert decision.requirements_met["intimacy_910"] is True
    
    @pytest.mark.asyncio
    async def test_tactical_healing(self, homun_manager, homun_state):
        """Test healing skill usage when player HP is low."""
        await homun_manager.update_state(homun_state)
        
        skill = await homun_manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.5,
            player_sp_percent=0.8,
            enemies_nearby=2,
            ally_count=1
        )
        
        assert skill is not None
        assert skill.skill_name == "Healing Hands"


class TestMercenaryManager:
    """Test mercenary control."""
    
    @pytest.fixture
    def merc_manager(self):
        """Create mercenary manager for testing."""
        return MercenaryManager(MercenaryConfig())
    
    @pytest.fixture
    def merc_state(self):
        """Create sample mercenary state."""
        return MercenaryState(
            merc_id=1,
            type=MercenaryType.ARCHER_LV5,
            level=70,
            contract_remaining=1200,
            hp=2000,
            max_hp=3000,
            sp=100,
            max_sp=200,
            faith=60,
            skills={"Double Strafe": 5, "Arrow Shower": 3}
        )
    
    @pytest.mark.asyncio
    async def test_type_selection_mvp(self, merc_manager):
        """Test mercenary type selection for MVP."""
        merc_type = await merc_manager.select_mercenary_type(
            situation="mvp",
            player_class="priest",
            enemies_expected=1
        )
        
        assert "lancer" in merc_type.value
    
    @pytest.mark.asyncio
    async def test_type_selection_squishy_class(self, merc_manager):
        """Test tank mercenary for squishy classes."""
        merc_type = await merc_manager.select_mercenary_type(
            situation="farming",
            player_class="mage",
            enemies_expected=3
        )
        
        assert "sword" in merc_type.value or "archer" in merc_type.value
    
    @pytest.mark.asyncio
    async def test_contract_renewal(self, merc_manager, merc_state):
        """Test auto-renewal when contract expires soon."""
        merc_state.contract_remaining = 200  # Below threshold
        await merc_manager.update_state(merc_state)
        
        action = await merc_manager.manage_contract()
        
        assert action is not None
        assert action.action == "renew"
    
    @pytest.mark.asyncio
    async def test_contract_low_faith(self, merc_manager, merc_state):
        """Test dismissal on low faith."""
        merc_state.contract_remaining = 200
        merc_state.faith = 30  # Below threshold
        await merc_manager.update_state(merc_state)
        
        action = await merc_manager.manage_contract()
        
        assert action is not None
        assert action.action == "dismiss"
    
    @pytest.mark.asyncio
    async def test_skill_coordination_aoe(self, merc_manager, merc_state):
        """Test AoE skill when multiple enemies."""
        await merc_manager.update_state(merc_state)
        
        skill = await merc_manager.coordinate_skills(
            combat_active=True,
            player_hp_percent=0.8,
            enemies_nearby=4,
            is_boss_fight=False
        )
        
        assert skill is not None
        assert skill.skill_name == "Arrow Shower"
    
    def test_faith_multiplier(self, merc_manager, merc_state):
        """Test faith stat multiplier calculation."""
        merc_state.faith = 20
        merc_manager.current_state = merc_state
        assert merc_manager.get_faith_multiplier() == 0.8
        
        merc_state.faith = 80
        assert merc_manager.get_faith_multiplier() == 1.1


class TestMountManager:
    """Test mount system."""
    
    @pytest.fixture
    def mount_manager(self):
        """Create mount manager for testing."""
        manager = MountManager(MountConfig())
        manager.set_player_class("knight")
        return manager
    
    @pytest.fixture
    def mount_state(self):
        """Create sample mount state."""
        return MountState(
            is_mounted=False,
            mount_type=MountType.PECO_PECO,
            has_cart=False
        )
    
    @pytest.mark.asyncio
    async def test_mount_long_distance(self, mount_manager, mount_state):
        """Test mounting for long distance travel."""
        await mount_manager.update_state(mount_state)
        
        decision = await mount_manager.should_mount(
            distance_to_destination=15,
            in_combat=False
        )
        
        assert decision.should_mount is True
        assert "long_distance" in decision.reason
    
    @pytest.mark.asyncio
    async def test_dismount_for_skill(self, mount_manager, mount_state):
        """Test dismounting for restricted skills."""
        mount_state.is_mounted = True
        await mount_manager.update_state(mount_state)
        
        decision = await mount_manager.should_mount(
            distance_to_destination=5,
            in_combat=True,
            skill_to_use="Bowling Bash"
        )
        
        assert decision.should_mount is False
        assert "dismount_for_skill" in decision.reason
    
    @pytest.mark.asyncio
    async def test_mado_fuel_management(self, mount_manager, mount_state):
        """Test Mado Gear fuel management."""
        mount_manager.set_player_class("mechanic")
        mount_state.mount_type = MountType.MADO_GEAR
        mount_state.is_mounted = True
        mount_state.fuel = 15
        mount_state.fuel_max = 100
        await mount_manager.update_state(mount_state)
        
        refuel = await mount_manager.manage_mado_fuel()
        
        assert refuel is not None
        assert refuel.should_refuel is True
        assert refuel.fuel_needed == 85
    
    @pytest.mark.asyncio
    async def test_cart_optimization_full(self, mount_manager, mount_state):
        """Test cart weight optimization when overloaded."""
        mount_state.has_cart = True
        mount_state.cart_weight = 7500
        mount_state.cart_max_weight = 8000
        await mount_manager.update_state(mount_state)
        
        optimization = await mount_manager.optimize_cart_weight(
            items_to_pickup=10
        )
        
        assert optimization.action == "lighten"
        assert optimization.current_ratio > 0.9
    
    def test_speed_bonus(self, mount_manager, mount_state):
        """Test movement speed bonus calculation."""
        mount_state.is_mounted = False
        mount_manager.current_state = mount_state
        assert mount_manager.get_speed_bonus() == 1.0
        
        mount_state.is_mounted = True
        assert mount_manager.get_speed_bonus() == 1.25


class TestCompanionCoordinator:
    """Test unified coordinator."""
    
    @pytest.fixture
    def coordinator(self):
        """Create companion coordinator."""
        return CompanionCoordinator()
    
    @pytest.fixture
    def game_state(self):
        """Create sample game state."""
        return GameState(
            player_hp_percent=0.7,
            player_sp_percent=0.8,
            player_position=(100, 100),
            player_class="knight",
            in_combat=True,
            enemies_nearby=2,
            pet_state=PetState(
                pet_id=1,
                pet_type=PetType.PORING,
                name="TestPet",
                intimacy=900,
                hunger=30,
                is_summoned=True
            ),
            homun_state=HomunculusState(
                homun_id=1,
                type=HomunculusType.LIF,
                level=50,
                intimacy=800,
                hp=500,
                max_hp=1000,
                sp=100,
                max_sp=200,
                stat_str=15,
                agi=20,
                vit=25,
                int_stat=40,
                dex=30,
                luk=15,
                skills={"Healing Hands": 5}
            )
        )
    
    @pytest.mark.asyncio
    async def test_update_all_companions(self, coordinator, game_state):
        """Test updating all companion systems."""
        actions = await coordinator.update_all(game_state)
        
        assert isinstance(actions, list)
        # Should have actions from pet (feed) and possibly others
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_action_prioritization(self, coordinator, game_state):
        """Test action priority sorting."""
        actions = await coordinator.update_all(game_state)
        
        if len(actions) > 1:
            # Check that actions are sorted by priority
            for i in range(len(actions) - 1):
                assert actions[i].priority >= actions[i + 1].priority
    
    @pytest.mark.asyncio
    async def test_prioritize_emergency_healing(self, coordinator, game_state):
        """Test emergency healing gets highest priority."""
        game_state.player_hp_percent = 0.4  # Low HP
        
        actions = await coordinator.update_all(game_state)
        top_action = await coordinator.prioritize_actions(actions)
        
        # Should prioritize healing if available
        if top_action and "homunculus" in top_action.companion_type:
            assert top_action.priority >= 7
    
    @pytest.mark.asyncio
    async def test_status_summary(self, coordinator, game_state):
        """Test status summary generation."""
        await coordinator.update_all(game_state)
        
        summary = await coordinator.get_status_summary()
        
        assert "pet" in summary
        assert "homunculus" in summary
        assert "mercenary" in summary
        assert "mount" in summary
        
        assert summary["pet"] is not None
        assert summary["homunculus"] is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])