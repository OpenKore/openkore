"""
Tests for Job AI Coordinator - job-specific behaviors and mechanics.

Tests cover:
- Job setting and validation
- Mechanics maintenance checking
- Action enhancement with job mechanics
- State updates for all mechanic types
- Status reporting
- Skill rotation integration
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock

from ai_sidecar.jobs.coordinator import JobAICoordinator
from ai_sidecar.jobs.registry import JobClass, JobBranch, JobTier, CombatRole, PositioningStyle
from ai_sidecar.jobs.mechanics.poisons import PoisonType
from ai_sidecar.jobs.mechanics.runes import RuneType
from ai_sidecar.jobs.rotations import SkillRotationStep, SkillPriority


@pytest.fixture
def data_dir(tmp_path):
    """Create temporary data directory."""
    return tmp_path


@pytest.fixture
def mock_job_registry():
    """Mock job registry."""
    registry = Mock()
    
    # Create mock job
    mock_job = Mock(spec=JobClass)
    mock_job.job_id = 4054  # Lord Knight
    mock_job.name = "Lord Knight"
    mock_job.primary_role = CombatRole.MELEE_DPS
    mock_job.positioning = PositioningStyle.MELEE
    mock_job.has_spirit_spheres = False
    mock_job.has_poisons = False
    mock_job.has_runes = False
    mock_job.has_traps = False
    mock_job.has_magic_circles = False
    mock_job.recommended_stats = {"str": 120, "vit": 80, "dex": 50}
    mock_job.stat_weights = {"str": 1.0, "vit": 0.5, "dex": 0.3}
    mock_job.armor_type = "heavy"
    mock_job.preferred_weapon = "two_handed_sword"
    
    registry.get_job = Mock(return_value=mock_job)
    registry.get_all_skills_for_job = Mock(return_value={"Bash", "Magnum Break", "Bowling Bash"})
    
    return registry


@pytest.fixture
def coordinator(data_dir, mock_job_registry):
    """Create coordinator with mocked dependencies."""
    with patch('ai_sidecar.jobs.coordinator.JobClassRegistry', return_value=mock_job_registry), \
         patch('ai_sidecar.jobs.coordinator.SkillRotationEngine'), \
         patch('ai_sidecar.jobs.coordinator.SpiritSphereManager'), \
         patch('ai_sidecar.jobs.coordinator.TrapManager'), \
         patch('ai_sidecar.jobs.coordinator.PoisonManager'), \
         patch('ai_sidecar.jobs.coordinator.RuneManager'), \
         patch('ai_sidecar.jobs.coordinator.MagicCircleManager'), \
         patch('ai_sidecar.jobs.coordinator.DoramManager'):
        
        coord = JobAICoordinator(data_dir)
        coord.job_registry = mock_job_registry
        
        # Add numeric properties to managers to avoid Mock comparison errors
        coord.spirit_sphere_mgr.sphere_count = 5
        coord.poison_mgr.coating_charges = 20
        coord.poison_mgr.edp_duration = 0
        coord.rune_mgr.current_rune_points = 100
        coord.trap_mgr.placed_traps = []
        coord.magic_circle_mgr.circle_count = 0
        coord.doram_mgr.spirit_points = 50
        
        return coord


# Job Setting Tests

@pytest.mark.asyncio
async def test_set_job_success(coordinator, mock_job_registry):
    """Test successful job setting."""
    result = await coordinator.set_job(4054)
    
    assert result is True
    assert coordinator.current_job is not None
    assert coordinator.current_job_id == 4054
    assert coordinator.current_job.name == "Lord Knight"
    mock_job_registry.get_job.assert_called_once_with(4054)


@pytest.mark.asyncio
async def test_set_job_invalid_id(coordinator, mock_job_registry):
    """Test setting invalid job ID."""
    mock_job_registry.get_job.return_value = None
    
    result = await coordinator.set_job(9999)
    
    assert result is False
    assert coordinator.current_job is None


@pytest.mark.asyncio
async def test_set_job_updates_state(coordinator, mock_job_registry):
    """Test that setting job updates coordinator state."""
    await coordinator.set_job(4054)
    
    assert coordinator.current_job.primary_role == CombatRole.MELEE_DPS
    assert coordinator.current_job.positioning == PositioningStyle.MELEE


def test_get_current_job(coordinator):
    """Test getting current job."""
    assert coordinator.get_current_job() is None
    
    coordinator.current_job = Mock()
    coordinator.current_job.name = "Test Job"
    
    job = coordinator.get_current_job()
    assert job is not None
    assert job.name == "Test Job"


# Action Generation Tests

@pytest.mark.asyncio
async def test_get_next_action_no_job_set(coordinator):
    """Test action generation without job set."""
    result = await coordinator.get_next_action({}, None)
    
    assert result["type"] == "wait"
    assert result["reason"] == "no_job_set"


@pytest.mark.asyncio
async def test_get_next_action_with_rotation(coordinator):
    """Test action generation from rotation."""
    await coordinator.set_job(4054)
    
    # Mock rotation engine
    mock_rotation_step = Mock(spec=SkillRotationStep)
    mock_rotation_step.skill_name = "Bowling Bash"
    mock_rotation_step.cast_time_ms = 500
    mock_rotation_step.cooldown_ms = 1000
    
    coordinator.rotation_engine.get_next_skill = AsyncMock(return_value=mock_rotation_step)
    
    character_state = {"hp": 1000, "sp": 500}
    target_state = {"hp": 500, "distance": 3}
    
    result = await coordinator.get_next_action(character_state, target_state)
    
    assert result["type"] == "use_skill"
    assert result["skill"] == "Bowling Bash"
    assert result["cast_time_ms"] == 500
    assert result["cooldown_ms"] == 1000


@pytest.mark.asyncio
async def test_get_next_action_no_rotation_available(coordinator):
    """Test when rotation has no action."""
    await coordinator.set_job(4054)
    
    coordinator.rotation_engine.get_next_skill = AsyncMock(return_value=None)
    
    result = await coordinator.get_next_action({}, None)
    
    assert result["type"] == "wait"
    assert result["reason"] == "no_action_available"


@pytest.mark.asyncio
async def test_get_next_action_with_maintenance_priority(coordinator):
    """Test that mechanics maintenance takes priority over rotation."""
    await coordinator.set_job(4054)
    
    # Setup job with spirit spheres
    coordinator.current_job.has_spirit_spheres = True
    coordinator.spirit_sphere_mgr.should_generate_spheres = Mock(return_value=True)
    
    result = await coordinator.get_next_action({}, None)
    
    assert result["type"] == "use_skill"
    assert result["skill"] == "Summon Spirit Sphere"
    assert result["reason"] == "generate_spheres"


# Mechanics Maintenance Tests

def test_check_mechanics_maintenance_no_job(coordinator):
    """Test mechanics check without job set."""
    result = coordinator._check_mechanics_maintenance({})
    assert result is None


def test_check_mechanics_spirit_spheres(coordinator):
    """Test spirit sphere maintenance."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    
    coordinator.spirit_sphere_mgr.should_generate_spheres = Mock(return_value=True)
    
    result = coordinator._check_mechanics_maintenance({})
    
    assert result is not None
    assert result["type"] == "use_skill"
    assert result["skill"] == "Summon Spirit Sphere"


def test_check_mechanics_poison_coating(coordinator):
    """Test poison coating maintenance."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = False
    
    coordinator.poison_mgr.should_reapply_coating = Mock(return_value=True)
    coordinator.poison_mgr.get_recommended_poison = Mock(return_value=PoisonType.ENCHANT_DEADLY_POISON)
    
    result = coordinator._check_mechanics_maintenance({})
    
    assert result is not None
    assert result["type"] == "apply_poison"
    assert result["poison"] == "enchant_deadly_poison"
    assert result["reason"] == "maintain_coating"


def test_check_mechanics_rune_usage(coordinator):
    """Test rune usage in combat."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = True
    
    coordinator.rune_mgr.get_available_runes = Mock(return_value=[RuneType.RUNE_OF_STORM])
    coordinator.rune_mgr.get_recommended_rune = Mock(return_value=RuneType.RUNE_OF_STORM)
    
    result = coordinator._check_mechanics_maintenance({"in_combat": True})
    
    assert result is not None
    assert result["type"] == "use_rune"
    assert result["rune"] == "rune_of_storm"


def test_check_mechanics_no_runes_out_of_combat(coordinator):
    """Test that runes aren't recommended out of combat."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = True
    
    coordinator.rune_mgr.get_available_runes = Mock(return_value=[RuneType.RUNE_OF_STORM])
    
    result = coordinator._check_mechanics_maintenance({"in_combat": False})
    
    assert result is None


def test_check_mechanics_no_poison_available(coordinator):
    """Test when no poison is recommended."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = True
    
    coordinator.poison_mgr.should_reapply_coating = Mock(return_value=True)
    coordinator.poison_mgr.get_recommended_poison = Mock(return_value=None)
    
    result = coordinator._check_mechanics_maintenance({})
    
    assert result is None


# Action Enhancement Tests

def test_enhance_action_no_job(coordinator):
    """Test action enhancement without job."""
    action = {"type": "use_skill", "skill": "Test"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert result == action  # No enhancement


def test_enhance_action_spirit_spheres(coordinator):
    """Test enhancing action with spirit sphere info."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.spirit_sphere_mgr.can_use_skill = Mock(return_value=(True, 3))
    coordinator.spirit_sphere_mgr.get_sphere_count = Mock(return_value=5)
    
    action = {"type": "use_skill", "skill": "Triple Attack"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert "spirit_spheres" in result
    assert result["spirit_spheres"]["can_use"] is True
    assert result["spirit_spheres"]["required"] == 3
    assert result["spirit_spheres"]["current"] == 5


def test_enhance_action_poison_coating(coordinator):
    """Test enhancing action with poison info."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.poison_mgr.get_current_coating = Mock(return_value=PoisonType.ENCHANT_DEADLY_POISON)
    coordinator.poison_mgr.is_edp_active = Mock(return_value=True)
    
    action = {"type": "attack"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert result["poison_coating"] == "enchant_deadly_poison"
    assert result["edp_active"] is True


def test_enhance_action_runes(coordinator):
    """Test enhancing action with rune info."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = True
    coordinator.current_job.has_magic_circles = False
    
    coordinator.rune_mgr.current_rune_points = 100
    coordinator.rune_mgr.get_available_runes = Mock(return_value=[RuneType.RUNE_OF_STORM, RuneType.RUNE_OF_CRASH])
    
    action = {"type": "use_skill"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert result["rune_points"] == 100
    assert "available_runes" in result
    assert len(result["available_runes"]) == 2


def test_enhance_action_magic_circles(coordinator):
    """Test enhancing action with magic circle info."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_magic_circles = True
    
    from ai_sidecar.jobs.mechanics.magic_circles import CircleType
    coordinator.magic_circle_mgr.get_active_insignia = Mock(return_value=CircleType.FIRE_INSIGNIA)
    coordinator.magic_circle_mgr.get_circle_count = Mock(return_value=2)
    
    action = {"type": "use_skill"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert result["active_insignia"] == "fire_insignia"
    assert result["circle_count"] == 2


def test_enhance_action_no_active_insignia(coordinator):
    """Test magic circle info when no insignia active."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_magic_circles = True
    
    coordinator.magic_circle_mgr.get_active_insignia = Mock(return_value=None)
    coordinator.magic_circle_mgr.get_circle_count = Mock(return_value=0)
    
    action = {"type": "use_skill"}
    result = coordinator._enhance_action_with_mechanics(action, {})
    
    assert result["active_insignia"] is None
    assert result["circle_count"] == 0


# State Update Tests

def test_update_mechanics_no_job(coordinator):
    """Test state update without job."""
    coordinator.update_mechanics_state("skill_used", {"skill_name": "Test"})
    # Should not raise exception


def test_update_mechanics_spirit_spheres_consume(coordinator):
    """Test spirit sphere consumption on skill use."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4047  # Monk
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.spirit_sphere_mgr.consume_spheres = Mock()
    coordinator.spirit_sphere_mgr.is_generation_skill = Mock(return_value=False)
    coordinator.spirit_sphere_mgr.get_sphere_count = Mock(return_value=5)
    
    coordinator.update_mechanics_state("skill_used", {"skill_name": "Triple Attack"})
    
    coordinator.spirit_sphere_mgr.consume_spheres.assert_called_once_with("Triple Attack")


def test_update_mechanics_spirit_spheres_generate(coordinator):
    """Test spirit sphere generation."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4047  # Monk
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.spirit_sphere_mgr.consume_spheres = Mock()
    coordinator.spirit_sphere_mgr.is_generation_skill = Mock(return_value=True)
    coordinator.spirit_sphere_mgr.generate_multiple_spheres = Mock()
    coordinator.spirit_sphere_mgr.get_sphere_count = Mock(return_value=4)
    
    coordinator.update_mechanics_state("skill_used", {
        "skill_name": "Summon Spirit Sphere",
        "spheres_generated": 1
    })
    
    coordinator.spirit_sphere_mgr.generate_multiple_spheres.assert_called_once_with(1)


def test_update_mechanics_poison_attack(coordinator):
    """Test poison coating charge consumption on attack."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4062  # Assassin Cross
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.poison_mgr.use_coating_charge = Mock()
    coordinator.poison_mgr.coating_charges = 20
    
    coordinator.update_mechanics_state("attack", {})
    
    coordinator.poison_mgr.use_coating_charge.assert_called_once()


def test_update_mechanics_edp_activation(coordinator):
    """Test EDP buff activation."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4062  # Assassin Cross
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.poison_mgr.activate_edp = Mock()
    coordinator.poison_mgr.edp_duration = 0
    
    coordinator.update_mechanics_state("buff_applied", {
        "buff_name": "Enchant Deadly Poison",
        "duration": 40
    })
    
    coordinator.poison_mgr.activate_edp.assert_called_once_with(40)


def test_update_mechanics_rune_points(coordinator):
    """Test rune point generation."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4082  # Rune Knight
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = True
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.rune_mgr.add_rune_points = Mock()
    coordinator.rune_mgr.current_rune_points = 50
    
    coordinator.update_mechanics_state("combat_tick", {"points": 2})
    
    coordinator.rune_mgr.add_rune_points.assert_called_once_with(2)


def test_update_mechanics_trap_triggered(coordinator):
    """Test trap triggering."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4075  # Ranger
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = True
    coordinator.current_job.has_magic_circles = False
    
    coordinator.trap_mgr.trigger_trap = Mock()
    coordinator.trap_mgr.placed_traps = []
    
    coordinator.update_mechanics_state("trap_triggered", {"position": (100, 200)})
    
    coordinator.trap_mgr.trigger_trap.assert_called_once_with((100, 200))


def test_update_mechanics_doram_ability(coordinator):
    """Test Doram ability usage."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4218  # Doram job ID
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.doram_mgr.ability_costs = {"Lunatic Carrot Beat": 20}
    coordinator.doram_mgr.consume_spirit_points = Mock()
    
    coordinator.update_mechanics_state("ability_used", {
        "ability_name": "Lunatic Carrot Beat"
    })
    
    coordinator.doram_mgr.consume_spirit_points.assert_called_once_with(20)


# Status Reporting Tests

def test_get_mechanics_status_no_job(coordinator):
    """Test status report without job."""
    status = coordinator.get_mechanics_status()
    
    assert status["job_set"] is False


def test_get_mechanics_status_basic_job(coordinator, mock_job_registry):
    """Test status report with basic job."""
    coordinator.current_job = mock_job_registry.get_job(4054)
    coordinator.current_job_id = 4054
    
    status = coordinator.get_mechanics_status()
    
    assert status["job_set"] is True
    assert status["job_name"] == "Lord Knight"
    assert status["job_id"] == 4054
    assert status["role"] == "melee_dps"


def test_get_mechanics_status_with_spheres(coordinator):
    """Test status with spirit spheres."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4048  # Champion
    coordinator.current_job.name = "Champion"
    coordinator.current_job.primary_role = CombatRole.MELEE_DPS
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    coordinator.current_job_id = 4048
    
    coordinator.spirit_sphere_mgr.get_status = Mock(return_value={
        "count": 5,
        "max": 5
    })
    
    status = coordinator.get_mechanics_status()
    
    assert "spirit_spheres" in status
    assert status["spirit_spheres"]["count"] == 5


def test_get_mechanics_status_with_all_mechanics(coordinator):
    """Test status with all mechanics enabled."""
    coordinator.current_job = Mock()
    coordinator.current_job.name = "Test Job"
    coordinator.current_job.primary_role = CombatRole.HYBRID
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = True
    coordinator.current_job.has_traps = True
    coordinator.current_job.has_magic_circles = True
    coordinator.current_job.job_id = 9999
    coordinator.current_job_id = 9999
    
    coordinator.spirit_sphere_mgr.get_status = Mock(return_value={"count": 5})
    coordinator.trap_mgr.get_status = Mock(return_value={"traps_placed": 3})
    coordinator.poison_mgr.get_status = Mock(return_value={"coating": "deadly"})
    coordinator.rune_mgr.get_status = Mock(return_value={"points": 100})
    coordinator.magic_circle_mgr.get_status = Mock(return_value={"circles": 2})
    
    status = coordinator.get_mechanics_status()
    
    assert "spirit_spheres" in status
    assert "traps" in status
    assert "poisons" in status
    assert "runes" in status
    assert "magic_circles" in status


def test_get_mechanics_status_doram(coordinator):
    """Test status for Doram job."""
    coordinator.current_job = Mock()
    coordinator.current_job.name = "Summoner"
    coordinator.current_job.primary_role = CombatRole.MAGIC_DPS
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    coordinator.current_job.job_id = 4218
    coordinator.current_job_id = 4218
    
    coordinator.doram_mgr.get_status = Mock(return_value={
        "spirit_points": 50,
        "active_companions": []
    })
    
    status = coordinator.get_mechanics_status()
    
    assert "doram" in status
    assert status["doram"]["spirit_points"] == 50


# Reset Tests

def test_reset_mechanics(coordinator):
    """Test resetting all mechanics."""
    coordinator.spirit_sphere_mgr.reset = Mock()
    coordinator.trap_mgr.reset = Mock()
    coordinator.poison_mgr.reset = Mock()
    coordinator.rune_mgr.reset = Mock()
    coordinator.magic_circle_mgr.reset = Mock()
    coordinator.doram_mgr.reset = Mock()
    
    coordinator.reset_mechanics()
    
    coordinator.spirit_sphere_mgr.reset.assert_called_once()
    coordinator.trap_mgr.reset.assert_called_once()
    coordinator.poison_mgr.reset.assert_called_once()
    coordinator.rune_mgr.reset.assert_called_once()
    coordinator.magic_circle_mgr.reset.assert_called_once()
    coordinator.doram_mgr.reset.assert_called_once()


# Job Stats Tests

def test_get_job_stats_no_job(coordinator):
    """Test stats request without job."""
    stats = coordinator.get_job_stats()
    assert stats == {}


def test_get_job_stats_with_job(coordinator, mock_job_registry):
    """Test stats request with job set."""
    coordinator.current_job = mock_job_registry.get_job(4054)
    
    stats = coordinator.get_job_stats()
    
    assert "recommended_stats" in stats
    assert "stat_weights" in stats
    assert "positioning" in stats
    assert "armor_type" in stats
    assert "preferred_weapon" in stats
    assert stats["armor_type"] == "heavy"


# Job Skills Tests

def test_get_job_skills_no_job(coordinator):
    """Test skills request without job."""
    skills = coordinator.get_job_skills()
    assert skills == set()


def test_get_job_skills_with_job(coordinator, mock_job_registry):
    """Test skills request with job set."""
    coordinator.current_job = mock_job_registry.get_job(4054)
    
    skills = coordinator.get_job_skills()
    
    assert len(skills) > 0
    assert "Bash" in skills
    mock_job_registry.get_all_skills_for_job.assert_called_once()


# Integration Tests

@pytest.mark.asyncio
async def test_full_workflow_monk(coordinator):
    """Test full workflow with Monk job."""
    # Setup Monk job
    monk_job = Mock()
    monk_job.job_id = 4047
    monk_job.name = "Monk"
    monk_job.primary_role = CombatRole.MELEE_DPS
    monk_job.positioning = PositioningStyle.MELEE
    monk_job.has_spirit_spheres = True
    monk_job.has_poisons = False
    monk_job.has_runes = False
    monk_job.has_traps = False
    monk_job.has_magic_circles = False
    monk_job.recommended_stats = {"str": 100, "agi": 90}
    monk_job.stat_weights = {"str": 1.0, "agi": 0.8}
    monk_job.armor_type = "light"
    monk_job.preferred_weapon = "knuckles"
    
    coordinator.job_registry.get_job = Mock(return_value=monk_job)
    
    # Set job
    await coordinator.set_job(4047)
    assert coordinator.current_job.name == "Monk"
    
    # Test sphere generation maintenance
    coordinator.spirit_sphere_mgr.should_generate_spheres = Mock(return_value=True)
    action = coordinator._check_mechanics_maintenance({})
    assert action["skill"] == "Summon Spirit Sphere"
    
    # Update state with skill use
    coordinator.spirit_sphere_mgr.consume_spheres = Mock()
    coordinator.spirit_sphere_mgr.is_generation_skill = Mock(return_value=True)
    coordinator.spirit_sphere_mgr.generate_multiple_spheres = Mock()
    
    coordinator.update_mechanics_state("skill_used", {
        "skill_name": "Summon Spirit Sphere",
        "spheres_generated": 1
    })
    
    coordinator.spirit_sphere_mgr.generate_multiple_spheres.assert_called_once()


@pytest.mark.asyncio
async def test_full_workflow_assassin_cross(coordinator):
    """Test full workflow with Assassin Cross job."""
    # Setup Assassin Cross job
    sin_x_job = Mock()
    sin_x_job.job_id = 4062
    sin_x_job.name = "Assassin Cross"
    sin_x_job.primary_role = CombatRole.MELEE_DPS
    sin_x_job.positioning = PositioningStyle.MELEE
    sin_x_job.has_spirit_spheres = False
    sin_x_job.has_poisons = True
    sin_x_job.has_runes = False
    sin_x_job.has_traps = False
    sin_x_job.has_magic_circles = False
    sin_x_job.recommended_stats = {"agi": 120, "str": 80}
    sin_x_job.stat_weights = {"agi": 1.0, "str": 0.7}
    sin_x_job.armor_type = "light"
    sin_x_job.preferred_weapon = "katar"
    
    coordinator.job_registry.get_job = Mock(return_value=sin_x_job)
    
    # Set job
    await coordinator.set_job(4062)
    
    # Test poison coating maintenance
    coordinator.poison_mgr.should_reapply_coating = Mock(return_value=True)
    coordinator.poison_mgr.get_recommended_poison = Mock(return_value=PoisonType.ENCHANT_DEADLY_POISON)
    
    action = coordinator._check_mechanics_maintenance({})
    assert action["type"] == "apply_poison"
    assert action["poison"] == "enchant_deadly_poison"
    
    # Test attack consumes coating
    coordinator.poison_mgr.use_coating_charge = Mock()
    coordinator.update_mechanics_state("attack", {})
    coordinator.poison_mgr.use_coating_charge.assert_called_once()
    
    # Test EDP activation
    coordinator.poison_mgr.activate_edp = Mock()
    coordinator.update_mechanics_state("buff_applied", {
        "buff_name": "Enchant Deadly Poison",
        "duration": 40
    })
    coordinator.poison_mgr.activate_edp.assert_called_once()


@pytest.mark.asyncio
async def test_multiple_jobs_switching(coordinator):
    """Test switching between multiple jobs."""
    job1 = Mock()
    job1.job_id = 4054
    job1.name = "Lord Knight"
    job1.primary_role = CombatRole.MELEE_DPS
    job1.has_spirit_spheres = False
    job1.has_poisons = False
    job1.has_runes = False
    job1.has_traps = False
    job1.has_magic_circles = False
    
    job2 = Mock()
    job2.job_id = 4047
    job2.name = "Monk"
    job2.primary_role = CombatRole.MELEE_DPS
    job2.has_spirit_spheres = True
    job2.has_poisons = False
    job2.has_runes = False
    job2.has_traps = False
    job2.has_magic_circles = False
    
    def mock_get_job(job_id):
        return job1 if job_id == 4054 else job2
    
    coordinator.job_registry.get_job = Mock(side_effect=mock_get_job)
    
    # Set first job
    await coordinator.set_job(4054)
    assert coordinator.current_job.name == "Lord Knight"
    
    # Switch to second job
    await coordinator.set_job(4047)
    assert coordinator.current_job.name == "Monk"
    assert coordinator.current_job_id == 4047


def test_edge_case_empty_character_state(coordinator):
    """Test handling empty character state."""
    coordinator.current_job = Mock()
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_poisons = False
    coordinator.current_job.has_runes = True
    
    coordinator.rune_mgr.get_available_runes = Mock(return_value=[])
    
    result = coordinator._check_mechanics_maintenance({})
    assert result is None


def test_edge_case_missing_event_data(coordinator):
    """Test handling missing event data fields."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4062  # Assassin Cross
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_spirit_spheres = False
    coordinator.current_job.has_runes = False
    coordinator.current_job.has_traps = False
    coordinator.current_job.has_magic_circles = False
    
    coordinator.poison_mgr.activate_edp = Mock()
    coordinator.poison_mgr.edp_duration = 0
    
    # Missing duration field
    coordinator.update_mechanics_state("buff_applied", {
        "buff_name": "Enchant Deadly Poison"
    })
    
    # Should use default
    coordinator.poison_mgr.activate_edp.assert_called_once()


def test_concurrent_mechanics_updates(coordinator):
    """Test multiple mechanics active simultaneously."""
    coordinator.current_job = Mock()
    coordinator.current_job.job_id = 4000  # Generic test job
    coordinator.current_job.has_spirit_spheres = True
    coordinator.current_job.has_poisons = True
    coordinator.current_job.has_runes = True
    coordinator.current_job.has_traps = True
    coordinator.current_job.has_magic_circles = True
    
    # All mechanics should be callable - add numeric properties to avoid Mock comparison errors
    coordinator.spirit_sphere_mgr.consume_spheres = Mock()
    coordinator.spirit_sphere_mgr.sphere_count = 5
    coordinator.poison_mgr.use_coating_charge = Mock()
    coordinator.poison_mgr.coating_charges = 20
    coordinator.trap_mgr.trigger_trap = Mock()
    coordinator.trap_mgr.placed_traps = []
    
    coordinator.update_mechanics_state("skill_used", {"skill_name": "Test"})
    coordinator.update_mechanics_state("attack", {})
    coordinator.update_mechanics_state("trap_triggered", {"position": (0, 0)})
    
    coordinator.spirit_sphere_mgr.consume_spheres.assert_called_once()
    coordinator.poison_mgr.use_coating_charge.assert_called_once()
    coordinator.trap_mgr.trigger_trap.assert_called_once()