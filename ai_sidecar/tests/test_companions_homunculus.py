"""
Tests for Homunculus Manager - strategic homunculus AI.

Tests cover:
- State management and updates
- Stat distribution strategies
- Skill allocation logic
- Evolution decision making
- S-class eligibility checking
- Tactical skill usage
- Build targeting
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
import json

from ai_sidecar.companions.homunculus import (
    HomunculusManager, HomunculusState, HomunculusType,
    HomunculusStatBuild, StatAllocation, SkillAllocation,
    EvolutionDecision
)


@pytest.fixture
def data_path(tmp_path):
    """Create temporary data file."""
    data = {
        "lif": {
            "skills": {"Healing Hands": 5, "Urgent Escape": 5},
            "evolution": {"standard": "lif2", "s_evolution": "eira"}
        },
        "amistr": {
            "skills": {"Amistr Bulwark": 5, "Adamantium Skin": 5},
            "evolution": {"standard": "amistr2", "s_evolution": "bayeri"}
        },
        "filir": {
            "skills": {"Flitting": 5, "Moonlight": 5},
            "evolution": {"standard": "filir2", "s_evolution": "sera"}
        },
        "vanilmirth": {
            "skills": {"Caprice": 5, "Chaotic Blessings": 5},
            "evolution": {"standard": "vanilmirth2", "s_evolution": "dieter"}
        }
    }
    
    path = tmp_path / "homunculus.json"
    with open(path, "w") as f:
        json.dump(data, f)
    
    return path


@pytest.fixture
def manager(data_path):
    """Create homunculus manager."""
    return HomunculusManager(data_path)


@pytest.fixture
def lif_state():
    """Create Lif homunculus state."""
    return HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,
        intimacy=500,
        hp=1000,
        max_hp=1000,
        sp=200,
        max_sp=200,
        str=10,
        agi=10,
        vit=20,
        int=40,
        dex=30,
        luk=5,
        skills={"Healing Hands": 3},
        skill_points=2
    )


# Initialization Tests

def test_manager_init_with_data(data_path):
    """Test manager initialization with data file."""
    manager = HomunculusManager(data_path)
    
    assert manager.current_state is None
    assert len(manager._homunculus_database) > 0
    assert "lif" in manager._homunculus_database


def test_manager_init_missing_data():
    """Test initialization with missing data file."""
    manager = HomunculusManager(Path("/nonexistent/path.json"))
    
    assert len(manager._homunculus_database) == 0


def test_manager_init_default_path():
    """Test initialization with default path."""
    manager = HomunculusManager(None)
    
    # Should not crash
    assert manager is not None


# State Update Tests

@pytest.mark.asyncio
async def test_update_state_basic(manager, lif_state):
    """Test basic state update."""
    await manager.update_state(lif_state)
    
    assert manager.current_state == lif_state
    assert manager.current_state.type == HomunculusType.LIF


@pytest.mark.asyncio
async def test_update_state_evolution_eligible(manager):
    """Test state update with evolution eligible."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,  # Above 910
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5
    )
    
    await manager.update_state(state)
    
    assert state.can_evolve is True
    assert state.evolution_form == HomunculusType.LIF_EVOLVED


@pytest.mark.asyncio
async def test_update_state_not_evolution_eligible(manager):
    """Test state update when not eligible."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,  # Below 99
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5
    )
    
    await manager.update_state(state)
    
    assert state.can_evolve is False


# Build Targeting Tests

@pytest.mark.asyncio
async def test_set_target_build_valid(manager):
    """Test setting valid target build."""
    await manager.set_target_build(HomunculusType.EIRA)
    
    assert manager._target_build is not None
    assert manager._target_build.type == HomunculusType.EIRA


@pytest.mark.asyncio
async def test_set_target_build_invalid(manager):
    """Test setting invalid target build."""
    await manager.set_target_build(HomunculusType.LIF)  # Not in STAT_BUILDS
    
    # Should log warning but not crash
    assert manager._target_build is None


# Stat Distribution Tests

@pytest.mark.asyncio
async def test_calculate_stat_distribution_no_state(manager):
    """Test stat distribution without state."""
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is None


@pytest.mark.asyncio
async def test_calculate_stat_distribution_no_points(manager, lif_state):
    """Test stat distribution without skill points."""
    lif_state.skill_points = 0
    await manager.update_state(lif_state)
    
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is None


@pytest.mark.asyncio
async def test_calculate_stat_distribution_with_target_build(manager, lif_state):
    """Test stat distribution with target build set."""
    await manager.update_state(lif_state)
    await manager.set_target_build(HomunculusType.EIRA)
    
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is not None
    assert allocation.stat_name in ["str", "agi", "vit", "int", "dex", "luk"]
    assert allocation.points == 1


@pytest.mark.asyncio
async def test_calculate_stat_distribution_auto_detect_build(manager, lif_state):
    """Test auto-detection of build from current type."""
    await manager.update_state(lif_state)
    
    # Should auto-detect EIRA build for Lif
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is not None
    assert manager._target_build is not None
    assert manager._target_build.type == HomunculusType.EIRA


@pytest.mark.asyncio
async def test_calculate_stat_distribution_prioritizes_deficit(manager):
    """Test that stat with largest deficit gets priority."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,
        intimacy=500,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=50,   # High STR
        agi=50,
        vit=50,
        int=10,   # Very low INT (should be priority for Eira)
        dex=50,
        luk=50,
        skill_points=5
    )
    
    await manager.update_state(state)
    await manager.set_target_build(HomunculusType.EIRA)
    
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is not None
    # INT should be prioritized (largest deficit from 35% target)
    assert allocation.stat_name == "int"


@pytest.mark.asyncio
async def test_calculate_stat_distribution_fallback(manager):
    """Test fallback to priority stat."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.AMISTR,
        level=50,
        intimacy=500,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=30, agi=30, vit=30, int=30, dex=30, luk=30,
        skill_points=5
    )
    
    await manager.update_state(state)
    await manager.set_target_build(HomunculusType.BAYERI)
    
    allocation = await manager.calculate_stat_distribution()
    
    assert allocation is not None
    # Should prioritize VIT (first in priority for Bayeri)
    assert allocation.stat_name in manager._target_build.stat_priority


# Skill Allocation Tests

@pytest.mark.asyncio
async def test_allocate_skill_points_no_state(manager):
    """Test skill allocation without state."""
    allocation = await manager.allocate_skill_points()
    
    assert allocation is None


@pytest.mark.asyncio
async def test_allocate_skill_points_no_points(manager, lif_state):
    """Test skill allocation without points."""
    lif_state.skill_points = 0
    await manager.update_state(lif_state)
    
    allocation = await manager.allocate_skill_points()
    
    assert allocation is None


@pytest.mark.asyncio
async def test_allocate_skill_points_priority(manager, lif_state):
    """Test skill allocation follows priority."""
    await manager.update_state(lif_state)
    
    allocation = await manager.allocate_skill_points()
    
    assert allocation is not None
    assert allocation.skill_name in ["Healing Hands", "Urgent Escape"]
    assert allocation.current_level == 3  # Healing Hands current level
    assert allocation.target_level == 4


@pytest.mark.asyncio
async def test_allocate_skill_points_max_level(manager):
    """Test skill allocation when skills at max."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=500,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5,
        skills={"Healing Hands": 5, "Urgent Escape": 5},  # All maxed
        skill_points=2
    )
    
    await manager.update_state(state)
    
    allocation = await manager.allocate_skill_points()
    
    # Should return None when all skills maxed
    assert allocation is None


@pytest.mark.asyncio
async def test_allocate_skill_points_no_database(manager, lif_state):
    """Test skill allocation without database."""
    manager._homunculus_database = {}
    await manager.update_state(lif_state)
    
    allocation = await manager.allocate_skill_points()
    
    assert allocation is None


# Evolution Decision Tests

@pytest.mark.asyncio
async def test_decide_evolution_no_state(manager):
    """Test evolution decision without state."""
    decision = await manager.decide_evolution_path()
    
    assert decision.should_evolve is False
    assert decision.reason == "no_homunculus_state"


@pytest.mark.asyncio
async def test_decide_evolution_requirements_not_met(manager):
    """Test evolution when requirements not met."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,  # Not 99
        intimacy=500,  # Not 910
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5
    )
    
    await manager.update_state(state)
    
    decision = await manager.decide_evolution_path()
    
    assert decision.should_evolve is False
    assert decision.reason == "basic_requirements_not_met"
    assert decision.requirements_met["level_99"] is False
    assert decision.requirements_met["intimacy_910"] is False


@pytest.mark.asyncio
async def test_decide_evolution_standard_path(manager):
    """Test standard evolution recommendation."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5
    )
    
    await manager.update_state(state)
    
    decision = await manager.decide_evolution_path()
    
    assert decision.should_evolve is True
    assert decision.target_form == HomunculusType.LIF_EVOLVED
    assert decision.path_type == "standard"


@pytest.mark.asyncio
async def test_decide_evolution_s_class_eligible(manager):
    """Test S-class evolution when eligible."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=5, agi=5, vit=20,
        int=70,   # High INT aligned with Eira build
        dex=50,   # High DEX aligned with Eira build
        luk=5
    )
    
    await manager.update_state(state)
    await manager.set_target_build(HomunculusType.EIRA)
    
    decision = await manager.decide_evolution_path()
    
    assert decision.should_evolve is True
    assert decision.target_form == HomunculusType.EIRA
    assert decision.path_type == "s_class"


@pytest.mark.asyncio
async def test_decide_evolution_no_path_data(manager, lif_state):
    """Test evolution with no path data in database."""
    lif_state.level = 99
    lif_state.intimacy = 950
    manager._homunculus_database = {"lif": {}}  # No evolution key
    
    await manager.update_state(lif_state)
    
    decision = await manager.decide_evolution_path()
    
    assert decision.should_evolve is False
    assert decision.reason == "no_evolution_path"


# S-Class Eligibility Tests

def test_check_s_class_eligibility_no_build(manager, lif_state):
    """Test S-class check without target build."""
    result = manager._check_s_class_eligibility(lif_state)
    
    assert result is False


def test_check_s_class_eligibility_zero_stats(manager):
    """Test S-class check with zero stats."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=0, agi=0, vit=0, int=0, dex=0, luk=0
    )
    
    manager._target_build = manager.STAT_BUILDS[HomunculusType.EIRA]
    
    result = manager._check_s_class_eligibility(state)
    
    assert result is False


def test_check_s_class_eligibility_aligned_stats(manager):
    """Test S-class check with aligned stats."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=5, agi=5, vit=15,
        int=60,  # 35% of total (171) = 59.85 - aligned
        dex=40,  # 25% of total = 42.75 - close enough (80% threshold)
        luk=46
    )
    
    manager._target_build = manager.STAT_BUILDS[HomunculusType.EIRA]
    
    result = manager._check_s_class_eligibility(state)
    
    assert result is True


def test_check_s_class_eligibility_misaligned_stats(manager):
    """Test S-class check with misaligned stats."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=99,
        intimacy=950,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=80,  # Wrong priority
        agi=5, vit=5,
        int=10,  # Too low
        dex=5,   # Too low
        luk=5
    )
    
    manager._target_build = manager.STAT_BUILDS[HomunculusType.EIRA]
    
    result = manager._check_s_class_eligibility(state)
    
    assert result is False


# Tactical Skill Usage Tests

@pytest.mark.asyncio
async def test_tactical_skill_no_state(manager):
    """Test tactical skill usage without state."""
    result = await manager.tactical_skill_usage(True, 0.8, 0.8, 2, 1)
    
    assert result is None


@pytest.mark.asyncio
async def test_tactical_skill_lif_healing(manager):
    """Test Lif uses healing when player HP low."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=50,
        intimacy=500,
        hp=1000, max_hp=1000,
        sp=200, max_sp=200,
        str=10, agi=10, vit=10, int=40, dex=30, luk=5,
        skills={"Healing Hands": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.5,  # Low HP
        player_sp_percent=0.8,
        enemies_nearby=1,
        ally_count=0
    )
    
    assert result is not None
    assert result.skill_name == "Healing Hands"
    assert "healing" in result.reason.lower()


@pytest.mark.asyncio
async def test_tactical_skill_amistr_defensive(manager):
    """Test Amistr uses defensive buff with multiple enemies."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.AMISTR,
        level=50,
        intimacy=500,
        hp=2000, max_hp=2000,
        sp=100, max_sp=100,
        str=40, agi=10, vit=50, int=10, dex=20, luk=5,
        skills={"Amistr Bulwark": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.8,
        player_sp_percent=0.8,
        enemies_nearby=3,  # Multiple enemies
        ally_count=0
    )
    
    assert result is not None
    assert result.skill_name == "Amistr Bulwark"


@pytest.mark.asyncio
async def test_tactical_skill_filir_speed_buff(manager):
    """Test Filir uses speed buff in combat."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.FILIR,
        level=50,
        intimacy=500,
        hp=800, max_hp=800,
        sp=150, max_sp=150,
        str=20, agi=60, vit=10, int=10, dex=50, luk=10,
        skills={"Flitting": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.9,
        player_sp_percent=0.9,
        enemies_nearby=1,
        ally_count=0
    )
    
    assert result is not None
    assert result.skill_name == "Flitting"


@pytest.mark.asyncio
async def test_tactical_skill_vanilmirth_magic(manager):
    """Test Vanilmirth uses magic skills in combat."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.VANILMIRTH,
        level=50,
        intimacy=500,
        hp=900, max_hp=900,
        sp=50,  # Above 20
        max_sp=200,
        str=10, agi=10, vit=20, int=50, dex=30, luk=10,
        skills={"Caprice": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.8,
        player_sp_percent=0.8,
        enemies_nearby=1,
        ally_count=0
    )
    
    assert result is not None
    assert result.skill_name in ["Caprice", "Chaotic Blessings"]


@pytest.mark.asyncio
async def test_tactical_skill_no_sp(manager):
    """Test no magic skills when SP too low."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.VANILMIRTH,
        level=50,
        intimacy=500,
        hp=900, max_hp=900,
        sp=10,  # Too low
        max_sp=200,
        str=10, agi=10, vit=20, int=50, dex=30, luk=10,
        skills={"Caprice": 5}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.8,
        player_sp_percent=0.8,
        enemies_nearby=1,
        ally_count=0
    )
    
    assert result is None


@pytest.mark.asyncio
async def test_tactical_skill_evolved_forms(manager):
    """Test tactical skills work for evolved forms."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.EIRA,  # S-class Lif
        level=150,
        intimacy=1000,
        hp=3000, max_hp=3000,
        sp=500, max_sp=500,
        str=10, agi=10, vit=30, int=100, dex=80, luk=10,
        skills={"Healing Hands": 10}
    )
    
    await manager.update_state(state)
    
    result = await manager.tactical_skill_usage(
        combat_active=True,
        player_hp_percent=0.5,
        player_sp_percent=0.8,
        enemies_nearby=1,
        ally_count=0
    )
    
    assert result is not None
    assert result.skill_name == "Healing Hands"


# Helper Method Tests

def test_get_base_type_base_forms(manager):
    """Test getting base type for base forms."""
    assert manager._get_base_type(HomunculusType.LIF) == HomunculusType.LIF
    assert manager._get_base_type(HomunculusType.AMISTR) == HomunculusType.AMISTR


def test_get_base_type_evolved_forms(manager):
    """Test getting base type for evolved forms."""
    assert manager._get_base_type(HomunculusType.LIF_EVOLVED) == HomunculusType.LIF
    assert manager._get_base_type(HomunculusType.AMISTR_EVOLVED) == HomunculusType.AMISTR


def test_get_base_type_s_class_forms(manager):
    """Test getting base type for S-class forms."""
    assert manager._get_base_type(HomunculusType.EIRA) == HomunculusType.LIF
    assert manager._get_base_type(HomunculusType.BAYERI) == HomunculusType.AMISTR
    assert manager._get_base_type(HomunculusType.SERA) == HomunculusType.FILIR
    assert manager._get_base_type(HomunculusType.DIETER) == HomunculusType.VANILMIRTH


def test_get_evolution_path(manager):
    """Test getting evolution path from database."""
    path = manager._get_evolution_path(HomunculusType.LIF)
    
    assert path is not None
    assert "standard" in path
    assert "s_evolution" in path


def test_get_evolution_path_not_found(manager):
    """Test evolution path for unlisted type."""
    manager._homunculus_database = {}
    
    path = manager._get_evolution_path(HomunculusType.LIF)
    
    assert path is None or path == {}


def test_get_skill_priority(manager):
    """Test getting skill priorities."""
    priority = manager._get_skill_priority(HomunculusType.LIF)
    
    assert len(priority) > 0
    assert "Healing Hands" in priority


def test_get_skill_priority_evolved_form(manager):
    """Test skill priority for evolved forms uses base type."""
    priority_base = manager._get_skill_priority(HomunculusType.LIF)
    priority_evolved = manager._get_skill_priority(HomunculusType.EIRA)
    
    assert priority_base == priority_evolved


# Stat Build Tests

def test_stat_builds_defined():
    """Test that stat builds are properly defined."""
    assert len(HomunculusManager.STAT_BUILDS) == 4
    assert HomunculusType.EIRA in HomunculusManager.STAT_BUILDS
    assert HomunculusType.BAYERI in HomunculusManager.STAT_BUILDS
    assert HomunculusType.SERA in HomunculusManager.STAT_BUILDS
    assert HomunculusType.DIETER in HomunculusManager.STAT_BUILDS


def test_stat_build_ratios_sum_to_one():
    """Test that stat build ratios approximately sum to 1.0."""
    for build in HomunculusManager.STAT_BUILDS.values():
        total = sum(build.target_ratios.values())
        assert 0.99 <= total <= 1.01  # Allow small floating point error


# Edge Cases

@pytest.mark.asyncio
async def test_state_with_zero_total_stats(manager):
    """Test handling state with all zero stats."""
    state = HomunculusState(
        homun_id=1,
        type=HomunculusType.LIF,
        level=1,
        intimacy=250,
        hp=100, max_hp=100,
        sp=50, max_sp=50,
        str=0, agi=0, vit=0, int=0, dex=0, luk=0,
        skill_points=1
    )
    
    await manager.update_state(state)
    await manager.set_target_build(HomunculusType.EIRA)
    
    allocation = await manager.calculate_stat_distribution()
    
    # Should return None or handle gracefully
    assert allocation is None


@pytest.mark.asyncio
async def test_multiple_skill_allocations(manager, lif_state):
    """Test allocating multiple skill points sequentially."""
    await manager.update_state(lif_state)
    
    # Allocate first point
    alloc1 = await manager.allocate_skill_points()
    assert alloc1 is not None
    
    # Update state with new skill level
    lif_state.skills[alloc1.skill_name] = alloc1.target_level
    lif_state.skill_points -= 1
    
    # Allocate second point
    alloc2 = await manager.allocate_skill_points()
    assert alloc2 is not None


@pytest.mark.asyncio
async def test_evolution_all_types(manager):
    """Test evolution decisions for all base types."""
    types_to_test = [
        HomunculusType.LIF,
        HomunculusType.AMISTR,
        HomunculusType.FILIR,
        HomunculusType.VANILMIRTH
    ]
    
    for homun_type in types_to_test:
        state = HomunculusState(
            homun_id=1,
            type=homun_type,
            level=99,
            intimacy=950,
            hp=1000, max_hp=1000,
            sp=200, max_sp=200,
            str=20, agi=20, vit=20, int=20, dex=20, luk=20
        )
        
        await manager.update_state(state)
        
        decision = await manager.decide_evolution_path()
        
        assert decision.should_evolve is True
        assert decision.requirements_met["level_99"] is True
        assert decision.requirements_met["intimacy_910"] is True