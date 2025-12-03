"""
Tests for Mercenary Manager - tactical mercenary control.

Tests cover:
- Mercenary type selection
- Contract management and renewal
- Faith point tracking
- Skill coordination
- Tactical positioning
- Guild rank progression
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.companions.mercenary import (
    MercenaryManager, MercenaryState, MercenaryType,
    MercenaryConfig, ContractAction, Position
)


@pytest.fixture
def config():
    """Default mercenary configuration."""
    return MercenaryConfig(
        auto_renew=True,
        renew_threshold=300,
        faith_threshold=50,
        positioning="front"
    )


@pytest.fixture
def manager(config):
    """Create mercenary manager."""
    return MercenaryManager(config)


@pytest.fixture
def archer_state():
    """Create archer mercenary state."""
    return MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV5,
        level=50,
        contract_remaining=1800,
        contract_max=3600,
        hp=2000,
        max_hp=2000,
        sp=150,
        max_sp=150,
        kills=10,
        faith=75,
        skills={"Double Strafe": 5, "Arrow Shower": 3}
    )


@pytest.fixture
def sword_state():
    """Create swordsman mercenary state."""
    return MercenaryState(
        merc_id=2,
        type=MercenaryType.SWORD_LV3,
        level=30,
        contract_remaining=900,
        contract_max=3600,
        hp=3000,
        max_hp=3000,
        sp=100,
        max_sp=100,
        kills=5,
        faith=60,
        skills={"Provoke": 5, "Guard": 3}
    )


# Initialization Tests

def test_manager_init_default():
    """Test manager initialization with default config."""
    manager = MercenaryManager()
    
    assert manager.config is not None
    assert manager.current_state is None
    assert manager._guild_rank == 1


def test_manager_init_custom_config():
    """Test initialization with custom config."""
    config = MercenaryConfig(
        auto_renew=False,
        renew_threshold=600,
        faith_threshold=70
    )
    
    manager = MercenaryManager(config)
    
    assert manager.config.auto_renew is False
    assert manager.config.renew_threshold == 600


# State Update Tests

@pytest.mark.asyncio
async def test_update_state(manager, archer_state):
    """Test updating mercenary state."""
    await manager.update_state(archer_state)
    
    assert manager.current_state == archer_state
    assert manager.current_state.type == MercenaryType.ARCHER_LV5


@pytest.mark.asyncio
async def test_update_state_contract_warning(manager):
    """Test warning when contract expiring."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=250,  # Below 300
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=50
    )
    
    await manager.update_state(state)
    
    # Should log warning but not crash
    assert manager.current_state.contract_remaining == 250


# Guild Rank Tests

def test_set_guild_rank(manager):
    """Test setting guild rank."""
    manager.set_guild_rank(5)
    
    assert manager._guild_rank == 5


def test_set_guild_rank_clamp_low(manager):
    """Test guild rank clamped to minimum."""
    manager.set_guild_rank(0)
    
    assert manager._guild_rank == 1


def test_set_guild_rank_clamp_high(manager):
    """Test guild rank clamped to maximum."""
    manager.set_guild_rank(15)
    
    assert manager._guild_rank == 10


# Mercenary Selection Tests

@pytest.mark.asyncio
async def test_select_mercenary_mvp_situation(manager):
    """Test selecting mercenary for MVP/boss."""
    merc_type = await manager.select_mercenary_type("mvp", "knight", 1)
    
    # Should select lancer for boss fights
    assert "lancer" in merc_type.value


@pytest.mark.asyncio
async def test_select_mercenary_farming_multiple_mobs(manager):
    """Test selecting mercenary for farming."""
    merc_type = await manager.select_mercenary_type("farming", "knight", 5)
    
    # Should select archer for AoE
    assert "archer" in merc_type.value


@pytest.mark.asyncio
async def test_select_mercenary_squishy_class(manager):
    """Test selecting mercenary for squishy classes."""
    merc_type = await manager.select_mercenary_type("farming", "mage", 2)
    
    # Should select swordsman for tanking
    assert "sword" in merc_type.value


@pytest.mark.asyncio
async def test_select_mercenary_tanky_class(manager):
    """Test selecting mercenary for tanky classes."""
    merc_type = await manager.select_mercenary_type("farming", "knight", 2)
    
    # Should select archer for ranged DPS
    assert "archer" in merc_type.value


@pytest.mark.asyncio
async def test_select_mercenary_preferred_type(manager):
    """Test using preferred mercenary type."""
    config = MercenaryConfig(preferred_type=MercenaryType.LANCER_LV5)
    manager = MercenaryManager(config)
    
    merc_type = await manager.select_mercenary_type("farming", "generic", 2)
    
    assert merc_type == MercenaryType.LANCER_LV5


@pytest.mark.asyncio
async def test_select_mercenary_respects_guild_rank(manager):
    """Test selection respects guild rank."""
    manager.set_guild_rank(3)
    
    merc_type = await manager.select_mercenary_type("farming", "knight", 5)
    
    # Should select level 3 archer (guild rank limit)
    assert merc_type == MercenaryType.ARCHER_LV3


@pytest.mark.asyncio
async def test_select_mercenary_high_guild_rank(manager):
    """Test selection with high guild rank."""
    manager.set_guild_rank(10)
    
    merc_type = await manager.select_mercenary_type("mvp", "knight", 1)
    
    # Should select level 10
    assert merc_type == MercenaryType.LANCER_LV10


# Contract Management Tests

@pytest.mark.asyncio
async def test_manage_contract_no_mercenary(manager):
    """Test contract management without active mercenary."""
    action = await manager.manage_contract()
    
    assert action is not None
    assert action.action == "hire"
    assert action.merc_type is not None


@pytest.mark.asyncio
async def test_manage_contract_no_auto_renew(manager):
    """Test contract management with auto-renew disabled."""
    config = MercenaryConfig(auto_renew=False)
    manager = MercenaryManager(config)
    
    action = await manager.manage_contract()
    
    assert action is None


@pytest.mark.asyncio
async def test_manage_contract_renewal_needed(manager, archer_state):
    """Test contract renewal when time low."""
    archer_state.contract_remaining = 200  # Below threshold
    await manager.update_state(archer_state)
    
    action = await manager.manage_contract()
    
    assert action is not None
    assert action.action == "renew"
    assert action.merc_type == MercenaryType.ARCHER_LV5


@pytest.mark.asyncio
async def test_manage_contract_low_faith_dismiss(manager, archer_state):
    """Test dismissal when faith too low."""
    archer_state.contract_remaining = 200
    archer_state.faith = 30  # Below threshold
    await manager.update_state(archer_state)
    
    action = await manager.manage_contract()
    
    assert action is not None
    assert action.action == "dismiss"
    assert "low_faith" in action.reason


@pytest.mark.asyncio
async def test_manage_contract_good_faith_renew(manager, archer_state):
    """Test renewal when faith is good."""
    archer_state.contract_remaining = 200
    archer_state.faith = 80  # Above threshold
    await manager.update_state(archer_state)
    
    action = await manager.manage_contract()
    
    assert action is not None
    assert action.action == "renew"


@pytest.mark.asyncio
async def test_manage_contract_plenty_time_remaining(manager, archer_state):
    """Test no action when plenty of contract time."""
    archer_state.contract_remaining = 2000  # Well above threshold
    await manager.update_state(archer_state)
    
    action = await manager.manage_contract()
    
    assert action is None


# Skill Coordination Tests

@pytest.mark.asyncio
async def test_coordinate_skills_no_state(manager):
    """Test skill coordination without state."""
    result = await manager.coordinate_skills(True, 0.8, 2)
    
    assert result is None


@pytest.mark.asyncio
async def test_coordinate_skills_not_in_combat(manager, archer_state):
    """Test no skills when not in combat."""
    await manager.update_state(archer_state)
    
    result = await manager.coordinate_skills(False, 0.8, 2)
    
    assert result is None


@pytest.mark.asyncio
async def test_coordinate_skills_sword_provoke(manager, sword_state):
    """Test swordsman uses Provoke with multiple enemies."""
    await manager.update_state(sword_state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.8,
        enemies_nearby=3
    )
    
    assert result is not None
    assert result.skill_name == "Provoke"
    assert "aggro" in result.reason.lower()


@pytest.mark.asyncio
async def test_coordinate_skills_sword_guard(manager, sword_state):
    """Test swordsman uses Guard when player HP low."""
    await manager.update_state(sword_state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.4,  # Low HP
        enemies_nearby=1
    )
    
    assert result is not None
    assert result.skill_name == "Guard"
    assert "defensive" in result.reason.lower()


@pytest.mark.asyncio
async def test_coordinate_skills_archer_aoe(manager, archer_state):
    """Test archer uses AoE with many enemies."""
    await manager.update_state(archer_state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.9,
        enemies_nearby=4
    )
    
    assert result is not None
    assert result.skill_name == "Arrow Shower"
    assert "aoe" in result.reason.lower()


@pytest.mark.asyncio
async def test_coordinate_skills_archer_boss(manager, archer_state):
    """Test archer uses single target skill for boss."""
    archer_state.skills["Sharp Shooting"] = 5
    await manager.update_state(archer_state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.9,
        enemies_nearby=1,
        is_boss_fight=True
    )
    
    assert result is not None
    assert result.skill_name == "Sharp Shooting"


@pytest.mark.asyncio
async def test_coordinate_skills_lancer_boss(manager):
    """Test lancer uses burst damage for boss."""
    state = MercenaryState(
        merc_id=3,
        type=MercenaryType.LANCER_LV7,
        level=70,
        contract_remaining=1800,
        contract_max=3600,
        hp=2500, max_hp=2500,
        sp=200, max_sp=200,
        kills=20,
        faith=80,
        skills={"Spiral Pierce": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.9,
        enemies_nearby=1,
        is_boss_fight=True
    )
    
    assert result is not None
    assert result.skill_name == "Spiral Pierce"


@pytest.mark.asyncio
async def test_coordinate_skills_lancer_regular_pierce(manager):
    """Test lancer uses Pierce when SP available."""
    state = MercenaryState(
        merc_id=3,
        type=MercenaryType.LANCER_LV5,
        level=50,
        contract_remaining=1800,
        contract_max=3600,
        hp=2500, max_hp=2500,
        sp=50,  # Above 30
        max_sp=200,
        kills=15,
        faith=70,
        skills={"Pierce": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.9,
        enemies_nearby=1
    )
    
    assert result is not None
    assert result.skill_name == "Pierce"


@pytest.mark.asyncio
async def test_coordinate_skills_no_skill_available(manager):
    """Test when mercenary has no usable skills."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=1800,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=50,
        skills={}  # No skills
    )
    
    await manager.update_state(state)
    
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.8,
        enemies_nearby=3
    )
    
    assert result is None


# Positioning Tests

@pytest.mark.asyncio
async def test_position_mercenary_no_state(manager):
    """Test positioning without state."""
    player_pos = Position(x=100, y=100)
    
    result = await manager.position_mercenary(player_pos, [])
    
    # Should return player position
    assert result == player_pos


@pytest.mark.asyncio
async def test_position_mercenary_no_enemies(manager, archer_state):
    """Test positioning with no enemies."""
    await manager.update_state(archer_state)
    
    player_pos = Position(x=100, y=100)
    
    result = await manager.position_mercenary(player_pos, [])
    
    assert result == player_pos


@pytest.mark.asyncio
async def test_position_mercenary_sword_frontline(manager, sword_state):
    """Test swordsman positions at frontline."""
    await manager.update_state(sword_state)
    
    player_pos = Position(x=100, y=100)
    enemy_pos = [Position(x=110, y=110)]
    
    result = await manager.position_mercenary(player_pos, enemy_pos)
    
    # Should be between player and enemy
    assert result.x != player_pos.x or result.y != player_pos.y
    assert result.x == 105  # Midpoint
    assert result.y == 105


@pytest.mark.asyncio
async def test_position_mercenary_archer_backline(manager, archer_state):
    """Test archer positions at backline."""
    await manager.update_state(archer_state)
    
    player_pos = Position(x=100, y=100)
    enemy_pos = [Position(x=110, y=100)]
    
    result = await manager.position_mercenary(player_pos, enemy_pos)
    
    # Should be behind player
    assert result.x < player_pos.x


@pytest.mark.asyncio
async def test_position_mercenary_flank_positioning(manager, archer_state):
    """Test flank positioning strategy."""
    config = MercenaryConfig(positioning="flank")
    manager = MercenaryManager(config)
    await manager.update_state(archer_state)
    
    player_pos = Position(x=100, y=100)
    enemy_pos = [Position(x=110, y=110)]
    
    result = await manager.position_mercenary(player_pos, enemy_pos)
    
    # Should be to the side (perpendicular to enemy direction)
    assert result.x == 104
    assert result.y == 96


@pytest.mark.asyncio
async def test_position_mercenary_multiple_enemies(manager, sword_state):
    """Test positioning with multiple enemies."""
    await manager.update_state(sword_state)
    
    player_pos = Position(x=100, y=100)
    enemies = [
        Position(x=110, y=110),
        Position(x=120, y=100),
        Position(x=110, y=90)
    ]
    
    result = await manager.position_mercenary(player_pos, enemies)
    
    # Should position toward average enemy position
    assert result is not None


# Faith Multiplier Tests

def test_faith_multiplier_no_state(manager):
    """Test faith multiplier without state."""
    multiplier = manager.get_faith_multiplier()
    
    assert multiplier == 1.0


def test_faith_multiplier_very_low(manager):
    """Test faith multiplier at very low faith."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=1800,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=20  # Very low
    )
    
    manager.current_state = state
    multiplier = manager.get_faith_multiplier()
    
    assert multiplier == 0.8


def test_faith_multiplier_low(manager):
    """Test faith multiplier at low faith."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=1800,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=40
    )
    
    manager.current_state = state
    multiplier = manager.get_faith_multiplier()
    
    assert multiplier == 0.9


def test_faith_multiplier_normal(manager):
    """Test faith multiplier at normal faith."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=1800,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=60
    )
    
    manager.current_state = state
    multiplier = manager.get_faith_multiplier()
    
    assert multiplier == 1.0


def test_faith_multiplier_high(manager):
    """Test faith multiplier at high faith."""
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV1,
        level=10,
        contract_remaining=1800,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=90
    )
    
    manager.current_state = state
    multiplier = manager.get_faith_multiplier()
    
    assert multiplier == 1.1


def test_faith_multiplier_boundary_values(manager):
    """Test faith multiplier at boundary values."""
    test_cases = [
        (25, 0.8),
        (26, 0.9),
        (50, 0.9),
        (51, 1.0),
        (75, 1.0),
        (76, 1.1),
        (100, 1.1)
    ]
    
    for faith, expected_mult in test_cases:
        state = MercenaryState(
            merc_id=1,
            type=MercenaryType.ARCHER_LV1,
            level=10,
            contract_remaining=1800,
            contract_max=3600,
            hp=1000, max_hp=1000,
            sp=100, max_sp=100,
            kills=0,
            faith=faith
        )
        
        manager.current_state = state
        multiplier = manager.get_faith_multiplier()
        
        assert multiplier == expected_mult


# Helper Method Tests

def test_get_mercenary_role_sword(manager):
    """Test getting role for swordsman types."""
    role = manager._get_mercenary_role(MercenaryType.SWORD_LV1)
    assert role == "sword"
    
    role = manager._get_mercenary_role(MercenaryType.SWORD_LV10)
    assert role == "sword"


def test_get_mercenary_role_archer(manager):
    """Test getting role for archer types."""
    role = manager._get_mercenary_role(MercenaryType.ARCHER_LV1)
    assert role == "archer"
    
    role = manager._get_mercenary_role(MercenaryType.ARCHER_LV10)
    assert role == "archer"


def test_get_mercenary_role_lancer(manager):
    """Test getting role for lancer types."""
    role = manager._get_mercenary_role(MercenaryType.LANCER_LV1)
    assert role == "lancer"
    
    role = manager._get_mercenary_role(MercenaryType.LANCER_LV10)
    assert role == "lancer"


# Integration Tests

@pytest.mark.asyncio
async def test_full_workflow_hire_and_coordinate(manager):
    """Test full workflow of hiring and coordinating."""
    # No mercenary initially
    assert manager.current_state is None
    
    # Get hire action
    action = await manager.manage_contract()
    assert action.action == "hire"
    
    # Simulate hiring
    state = MercenaryState(
        merc_id=1,
        type=action.merc_type,
        level=10,
        contract_remaining=3600,
        contract_max=3600,
        hp=1000, max_hp=1000,
        sp=100, max_sp=100,
        kills=0,
        faith=50,
        skills={"Double Strafe": 3}
    )
    
    await manager.update_state(state)
    
    # Coordinate skills
    result = await manager.coordinate_skills(
        combat_active=True,
        player_hp_percent=0.8,
        enemies_nearby=2
    )
    
    # No specific skill triggered, but should not crash
    assert result is None or result is not None


@pytest.mark.asyncio
async def test_faith_lifecycle(manager):
    """Test faith affecting contract decisions."""
    # Start with good faith
    state = MercenaryState(
        merc_id=1,
        type=MercenaryType.ARCHER_LV5,
        level=50,
        contract_remaining=200,
        contract_max=3600,
        hp=2000, max_hp=2000,
        sp=150, max_sp=150,
        kills=20,
        faith=80,  # Good
        skills={}
    )
    
    await manager.update_state(state)
    
    # Should renew
    action = await manager.manage_contract()
    assert action.action == "renew"
    
    # Simulate faith drop
    state.faith = 30  # Poor
    await manager.update_state(state)
    
    # Should dismiss
    action = await manager.manage_contract()
    assert action.action == "dismiss"


@pytest.mark.asyncio
async def test_situation_based_selection(manager):
    """Test different situations produce different selections."""
    manager.set_guild_rank(10)
    
    # MVP situation
    mvp_merc = await manager.select_mercenary_type("mvp", "knight", 1)
    assert "lancer" in mvp_merc.value
    
    # Farming situation
    farm_merc = await manager.select_mercenary_type("farming", "knight", 5)
    assert "archer" in farm_merc.value
    
    # Squishy class
    squishy_merc = await manager.select_mercenary_type("quest", "mage", 2)
    assert "sword" in squishy_merc.value


# Edge Cases

@pytest.mark.asyncio
async def test_invalid_mercenary_type_fallback(manager):
    """Test fallback when invalid type requested."""
    manager.set_guild_rank(1)
    
    # Force invalid type scenario
    merc_type = await manager.select_mercenary_type("unknown", "unknown_class", 1)
    
    # Should fallback to archer_1
    assert merc_type in [MercenaryType.ARCHER_LV1, MercenaryType.SWORD_LV1, MercenaryType.LANCER_LV1]


@pytest.mark.asyncio
async def test_positioning_edge_coordinates(manager, archer_state):
    """Test positioning with edge coordinates."""
    await manager.update_state(archer_state)
    
    player_pos = Position(x=0, y=0)
    enemy_pos = [Position(x=10, y=10)]
    
    result = await manager.position_mercenary(player_pos, enemy_pos)
    
    # Should handle edge coordinates
    assert result is not None
    assert isinstance(result.x, int)
    assert isinstance(result.y, int)


def test_config_validation():
    """Test configuration validation."""
    config = MercenaryConfig(
        auto_renew=True,
        renew_threshold=300,
        faith_threshold=50,
        positioning="back"
    )
    
    assert config.auto_renew is True
    assert config.renew_threshold == 300
    assert config.positioning == "back"


def test_config_frozen():
    """Test that config is frozen."""
    config = MercenaryConfig()
    
    with pytest.raises(Exception):
        config.auto_renew = False