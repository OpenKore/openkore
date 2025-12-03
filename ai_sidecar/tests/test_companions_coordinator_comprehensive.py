"""
Comprehensive tests for companions/coordinator.py - Batch 7.

Target: Push coverage from 65.88% to 85%+
Focus on uncovered lines: 117-128, 133-161, 170-193, 228-245, 281, 291-350, 358-359
"""

import time
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from ai_sidecar.companions.coordinator import (
    CompanionAction,
    CompanionContext,
    CompanionCoordinator,
)
from ai_sidecar.companions.homunculus import HomunculusState
from ai_sidecar.companions.mercenary import MercenaryState
from ai_sidecar.companions.mount import MountState
from ai_sidecar.companions.pet import PetState


@pytest.fixture
def coordinator():
    """Create companion coordinator."""
    return CompanionCoordinator()


@pytest.fixture
def pet_state():
    """Create pet state."""
    from ai_sidecar.companions.pet import PetType
    return PetState(
        pet_id=1,
        pet_type=PetType.PORING,
        is_summoned=True,
        intimacy=900,
        hunger=80
    )


@pytest.fixture
def homun_state():
    """Create homunculus state."""
    from ai_sidecar.companions.homunculus import HomunculusType
    return HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,
        hp=800,
        max_hp=1000,
        sp=200,
        max_sp=300,
        intimacy=900,
        skill_points=5
    )


@pytest.fixture
def merc_state():
    """Create mercenary state."""
    from ai_sidecar.companions.mercenary import MercenaryType
    return MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV5,
        level=40,
        hp=600,
        max_hp=800,
        sp=150,
        max_sp=200,
        contract_remaining=3600,
        faith=80
    )


@pytest.fixture
def mount_state():
    """Create mount state."""
    from ai_sidecar.companions.mount import MountType
    return MountState(
        is_mounted=False,
        mount_type=MountType.PECO_PECO,
        has_cart=False,
        fuel=100,
        fuel_max=100
    )


@pytest.fixture
def game_context(pet_state, homun_state, merc_state, mount_state):
    """Create full game context."""
    return CompanionContext(
        player_hp_percent=0.8,
        player_sp_percent=0.7,
        player_position=(100, 100),
        player_class="Genetic",
        in_combat=True,
        enemies_nearby=3,
        is_boss_fight=False,
        pet_state=pet_state,
        homun_state=homun_state,
        merc_state=merc_state,
        mount_state=mount_state,
        distance_to_destination=50,
        skill_to_use=None
    )


class TestUpdateAll:
    """Test update_all method - lines 117-256."""

    @pytest.mark.asyncio
    async def test_update_all_with_pet_feeding(self, coordinator, game_context):
        """Test pet feeding action generation."""
        # Mock pet manager to return feed decision
        feed_decision = MagicMock(
            should_feed=True,
            food_item="Apple",
            reason="optimal feeding time"
        )
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=feed_decision)
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        
        # Mock other managers
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        assert len(actions) > 0
        feed_action = next((a for a in actions if a.action_type == "feed"), None)
        assert feed_action is not None
        assert feed_action.companion_type == "pet"
        assert feed_action.data["food"] == "Apple"

    @pytest.mark.asyncio
    async def test_update_all_with_pet_skill(self, coordinator, game_context):
        """Test pet skill action generation."""
        # Mock pet skill usage
        pet_skill = MagicMock(
            skill_name="Loot",
            reason="pick up items"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=pet_skill)
        
        # Mock other managers
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        skill_action = next((a for a in actions if a.action_type == "skill"), None)
        assert skill_action is not None
        assert skill_action.data["skill"] == "Loot"

    @pytest.mark.asyncio
    async def test_update_all_with_homun_heal(self, coordinator, game_context):
        """Test homunculus healing skill - high priority."""
        # Mock homunculus heal skill
        heal_skill = MagicMock(
            skill_name="Heal Master",
            reason="master low hp"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=heal_skill)
        
        # Mock other managers
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        # Heal skill should have priority 10
        heal_action = next(
            (a for a in actions if "heal" in a.data.get("skill", "").lower()),
            None
        )
        assert heal_action is not None
        assert heal_action.priority == 10

    @pytest.mark.asyncio
    async def test_update_all_with_homun_stat_allocation(self, coordinator, game_context):
        """Test homunculus stat allocation."""
        # Mock stat allocation
        stat_alloc = MagicMock(
            stat_name="STR",
            reason="increase damage"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.homun_manager.calculate_stat_distribution = AsyncMock(
            return_value=stat_alloc
        )
        
        # Mock other managers
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        stat_action = next(
            (a for a in actions if a.action_type == "allocate_stat"),
            None
        )
        assert stat_action is not None
        assert stat_action.priority == 2  # Low priority
        assert stat_action.data["stat"] == "STR"

    @pytest.mark.asyncio
    async def test_update_all_with_merc_contract_renewal(self, coordinator, game_context):
        """Test mercenary contract renewal."""
        # Mock contract renewal
        contract_action = MagicMock(
            action="renew",
            merc_type="Mercenary Archer",
            reason="contract expiring soon"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=contract_action)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        
        # Mock other managers
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        contract = next(
            (a for a in actions if a.action_type == "contract"),
            None
        )
        assert contract is not None
        assert contract.priority == 8  # High priority for renewal
        assert contract.data["action"] == "renew"

    @pytest.mark.asyncio
    async def test_update_all_with_mount_toggle(self, coordinator, game_context):
        """Test mount toggle action."""
        # Mock mount decision - should mount
        mount_decision = MagicMock(
            should_mount=True,
            reason="long distance travel"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(return_value=mount_decision)
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(game_context)
        
        mount_action = next(
            (a for a in actions if a.action_type == "toggle"),
            None
        )
        assert mount_action is not None
        assert mount_action.companion_type == "mount"
        assert mount_action.data["mount"] is True

    @pytest.mark.asyncio
    async def test_update_all_with_mado_refuel(self, coordinator, game_context):
        """Test Mado Gear refuel action."""
        # Mock refuel action
        refuel_action = MagicMock(
            should_refuel=True,
            fuel_needed=50,
            reason="fuel low"
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=refuel_action)
        
        actions = await coordinator.update_all(game_context)
        
        refuel = next(
            (a for a in actions if a.action_type == "refuel"),
            None
        )
        assert refuel is not None
        assert refuel.data["fuel_needed"] == 50


class TestPrioritizeActions:
    """Test prioritize_actions method - lines 258-306."""

    @pytest.mark.asyncio
    async def test_prioritize_no_actions(self, coordinator):
        """Test with empty action list."""
        result = await coordinator.prioritize_actions([])
        assert result is None

    @pytest.mark.asyncio
    async def test_prioritize_returns_highest_priority(self, coordinator):
        """Test returns highest priority action not on cooldown."""
        actions = [
            CompanionAction(
                companion_type="pet",
                action_type="feed",
                priority=5,
                reason="normal feed",
                data={}
            ),
            CompanionAction(
                companion_type="homunculus",
                action_type="skill",
                priority=10,
                reason="emergency heal",
                data={"skill": "Healing Hands"}
            ),
            CompanionAction(
                companion_type="mount",
                action_type="toggle",
                priority=3,
                reason="mount up",
                data={}
            ),
        ]
        
        # Sort by priority (highest first) as update_all() does
        actions.sort(key=lambda a: a.priority, reverse=True)
        
        result = await coordinator.prioritize_actions(actions)
        
        assert result is not None
        assert result.priority == 10  # Highest priority
        assert result.companion_type == "homunculus"

    @pytest.mark.asyncio
    async def test_prioritize_respects_cooldowns(self, coordinator):
        """Test cooldown enforcement."""
        actions = [
            CompanionAction(
                companion_type="pet",
                action_type="feed",
                priority=10,
                reason="emergency"
            ),
        ]
        
        # First call should succeed
        result1 = await coordinator.prioritize_actions(actions)
        assert result1 is not None
        
        # Immediate second call should fail due to cooldown
        result2 = await coordinator.prioritize_actions(actions)
        assert result2 is None  # All on cooldown

    @pytest.mark.asyncio
    async def test_prioritize_after_cooldown_expires(self, coordinator):
        """Test action available after cooldown."""
        # Set very short cooldown for testing
        coordinator._action_cooldowns["pet_feed"] = 0.1
        
        actions = [
            CompanionAction(
                companion_type="pet",
                action_type="feed",
                priority=5,
                reason="test"
            ),
        ]
        
        # First call
        result1 = await coordinator.prioritize_actions(actions)
        assert result1 is not None
        
        # Wait for cooldown
        time.sleep(0.15)
        
        # Second call after cooldown
        result2 = await coordinator.prioritize_actions(actions)
        assert result2 is not None


class TestGetFeedPriority:
    """Test _get_feed_priority helper - lines 308-314."""

    def test_emergency_feed_priority(self, coordinator):
        """Test emergency feed gets highest priority."""
        priority = coordinator._get_feed_priority("emergency feeding required")
        assert priority == 9

    def test_optimal_feed_priority(self, coordinator):
        """Test optimal feed gets medium priority."""
        priority = coordinator._get_feed_priority("optimal feeding time")
        assert priority == 4

    def test_default_feed_priority(self, coordinator):
        """Test default feed gets low priority."""
        priority = coordinator._get_feed_priority("regular feeding")
        assert priority == 2


class TestGetStatusSummary:
    """Test get_status_summary method - lines 316-365."""

    @pytest.mark.asyncio
    async def test_status_summary_with_all_companions(self, coordinator):
        """Test status summary with all companions active."""
        from ai_sidecar.companions.pet import PetType
        from ai_sidecar.companions.homunculus import HomunculusType
        from ai_sidecar.companions.mercenary import MercenaryType
        from ai_sidecar.companions.mount import MountType
        # Setup all companion states
        coordinator.pet_manager.current_state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            is_summoned=True,
            intimacy=900,
            hunger=80
        )
        
        coordinator.homun_manager.current_state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            hp=800,
            max_hp=1000,
            sp=200,
            max_sp=300,
            intimacy=900,
            skill_points=0
        )
        
        coordinator.merc_manager.current_state = MercenaryState(
            merc_id=1,
            type=MercenaryType.ARCHER_LV5,
            level=40,
            hp=600,
            max_hp=800,
            sp=150,
            max_sp=200,
            contract_remaining=3600,
            faith=80
        )
        
        coordinator.mount_manager.current_state = MountState(
            is_mounted=True,
            mount_type=MountType.PECO_PECO,
            has_cart=False,
            fuel=100,
            fuel_max=100
        )
        
        summary = await coordinator.get_status_summary()
        
        # Check all companions present
        assert summary["pet"] is not None
        assert summary["pet"]["type"] == PetType.PORING
        assert summary["pet"]["summoned"] is True
        
        assert summary["homunculus"] is not None
        assert summary["homunculus"]["type"] == HomunculusType.LIF
        assert summary["homunculus"]["level"] == 50
        assert summary["homunculus"]["hp_percent"] == 0.8
        
        assert summary["mercenary"] is not None
        assert summary["mercenary"]["type"] == MercenaryType.ARCHER_LV5
        assert summary["mercenary"]["contract_remaining"] == 3600
        
        assert summary["mount"] is not None
        assert summary["mount"]["mounted"] is True
        assert summary["mount"]["type"] == MountType.PECO_PECO

    @pytest.mark.asyncio
    async def test_status_summary_with_no_companions(self, coordinator):
        """Test status summary with no companions active."""
        # All managers have None state by default
        summary = await coordinator.get_status_summary()
        
        assert summary["pet"] is None
        assert summary["homunculus"] is None
        assert summary["mercenary"] is None
        assert summary["mount"] is None


class TestIntegrationScenarios:
    """Integration tests for full workflows."""

    @pytest.mark.asyncio
    async def test_full_combat_scenario(self, coordinator, game_context):
        """Test complete combat scenario with multiple actions."""
        # Setup all managers with appropriate returns
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(
            return_value=MagicMock(skill_name="Attack", reason="combat")
        )
        
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(
            return_value=MagicMock(skill_name="Offensive Heal", reason="damage enemy")
        )
        
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(
            return_value=MagicMock(skill_name="Arrow Shower", reason="aoe damage")
        )
        
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="in combat")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        # Get all actions
        actions = await coordinator.update_all(game_context)
        
        # Should have multiple combat actions
        assert len(actions) >= 3
        
        # Get highest priority action
        selected = await coordinator.prioritize_actions(actions)
        assert selected is not None
        assert selected.priority >= 7  # Combat actions have high priority

    @pytest.mark.asyncio
    async def test_emergency_scenario(self, coordinator):
        """Test emergency scenario with low HP."""
        from ai_sidecar.companions.homunculus import HomunculusType
        # Low HP context
        emergency_context = CompanionContext(
            player_hp_percent=0.2,  # Very low HP
            player_sp_percent=0.5,
            player_position=(100, 100),
            player_class="Genetic",
            in_combat=True,
            enemies_nearby=5,
            is_boss_fight=True,
            homun_state=HomunculusState(
                homun_id=1,
                type=HomunculusType.LIF,
                level=50,
                hp=800,
                max_hp=1000,
                sp=200,
                max_sp=300,
                intimacy=900,
                skill_points=0
            )
        )
        
        # Mock emergency heal
        coordinator.homun_manager.update_state = AsyncMock()
        coordinator.homun_manager.tactical_skill_usage = AsyncMock(
            return_value=MagicMock(skill_name="Emergency Heal", reason="master critical")
        )
        coordinator.pet_manager.update_state = AsyncMock()
        coordinator.pet_manager.decide_feed_timing = AsyncMock(return_value=None)
        coordinator.pet_manager.coordinate_pet_skills = AsyncMock(return_value=None)
        coordinator.merc_manager.update_state = AsyncMock()
        coordinator.merc_manager.manage_contract = AsyncMock(return_value=None)
        coordinator.merc_manager.coordinate_skills = AsyncMock(return_value=None)
        coordinator.mount_manager.update_state = AsyncMock()
        coordinator.mount_manager.set_player_class = MagicMock()
        coordinator.mount_manager.should_mount = AsyncMock(
            return_value=MagicMock(should_mount=False, reason="")
        )
        coordinator.mount_manager.manage_mado_fuel = AsyncMock(return_value=None)
        
        actions = await coordinator.update_all(emergency_context)
        
        # Emergency heal should be highest priority
        selected = await coordinator.prioritize_actions(actions)
        assert selected is not None
        assert selected.priority == 10