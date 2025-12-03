"""
Comprehensive test suite for Job-Specific Mechanics System.

Tests all job mechanics managers and the coordinator.
"""

from pathlib import Path

import pytest

from ai_sidecar.jobs.coordinator import JobAICoordinator
from ai_sidecar.jobs.mechanics.doram import CompanionType, DoramBranch, DoramManager, SpiritType
from ai_sidecar.jobs.mechanics.magic_circles import CircleType, MagicCircleManager
from ai_sidecar.jobs.mechanics.poisons import PoisonManager, PoisonType
from ai_sidecar.jobs.mechanics.runes import RuneManager, RuneType
from ai_sidecar.jobs.mechanics.spirit_spheres import SpiritSphereManager
from ai_sidecar.jobs.mechanics.traps import TrapManager, TrapType


@pytest.fixture
def data_dir():
    """Get data directory path."""
    return Path(__file__).parent.parent / "data"


# ==================== Spirit Sphere Manager Tests ====================


class TestSpiritSphereManager:
    """Test Spirit Sphere Manager."""

    def test_initialization(self, data_dir):
        """Test manager initialization."""
        mgr = SpiritSphereManager(data_dir)
        assert mgr.current_spheres == 0
        assert mgr.max_spheres == 5

    def test_generate_sphere(self):
        """Test sphere generation."""
        mgr = SpiritSphereManager()
        assert mgr.generate_sphere()
        assert mgr.get_sphere_count() == 1

    def test_generate_multiple_spheres(self):
        """Test multiple sphere generation."""
        mgr = SpiritSphereManager()
        generated = mgr.generate_multiple_spheres(3)
        assert generated == 3
        assert mgr.get_sphere_count() == 3

    def test_sphere_limit(self):
        """Test sphere maximum limit."""
        mgr = SpiritSphereManager()
        mgr.generate_multiple_spheres(10)
        assert mgr.get_sphere_count() == 5

    def test_consume_spheres(self, data_dir):
        """Test sphere consumption."""
        mgr = SpiritSphereManager(data_dir)
        mgr.set_sphere_count(5)
        consumed = mgr.consume_spheres("Asura Strike")
        assert consumed == 5
        assert mgr.get_sphere_count() == 0

    def test_rising_dragon(self):
        """Test Rising Dragon buff."""
        mgr = SpiritSphereManager()
        mgr.activate_rising_dragon()
        assert mgr.max_spheres == 15
        mgr.deactivate_rising_dragon()
        assert mgr.max_spheres == 5


# ==================== Trap Manager Tests ====================


class TestTrapManager:
    """Test Trap Manager."""

    def test_initialization(self, data_dir):
        """Test manager initialization."""
        mgr = TrapManager(data_dir)
        assert len(mgr.placed_traps) == 0

    def test_place_trap(self, data_dir):
        """Test trap placement."""
        mgr = TrapManager(data_dir)
        result = mgr.place_trap(TrapType.BLAST_MINE, (10, 10))
        assert result
        assert mgr.get_trap_count() == 1

    def test_trap_limit(self, data_dir):
        """Test trap placement limit."""
        mgr = TrapManager(data_dir)
        mgr.max_traps = 2
        
        mgr.place_trap(TrapType.BLAST_MINE, (10, 10))
        mgr.place_trap(TrapType.CLAYMORE_TRAP, (15, 15))
        
        # Should fail due to limit
        result = mgr.place_trap(TrapType.ANKLE_SNARE, (20, 20))
        assert not result

    def test_trigger_trap(self, data_dir):
        """Test trap triggering."""
        mgr = TrapManager(data_dir)
        mgr.place_trap(TrapType.BLAST_MINE, (10, 10))
        
        trap = mgr.trigger_trap((10, 10))
        assert trap is not None
        assert trap.is_triggered

    def test_detonator_check(self, data_dir):
        """Test Detonator availability check."""
        mgr = TrapManager(data_dir)
        assert not mgr.should_use_detonator()
        
        mgr.place_trap(TrapType.BLAST_MINE, (10, 10))
        assert mgr.should_use_detonator()


# ==================== Poison Manager Tests ====================


class TestPoisonManager:
    """Test Poison Manager."""

    def test_initialization(self, data_dir):
        """Test manager initialization."""
        mgr = PoisonManager(data_dir)
        assert mgr.current_coating is None

    def test_add_poison_bottles(self):
        """Test adding poison bottles."""
        mgr = PoisonManager()
        mgr.add_poison_bottles(PoisonType.TOXIN, 5)
        assert mgr.get_poison_count(PoisonType.TOXIN) == 5

    def test_apply_coating(self):
        """Test poison coating application."""
        mgr = PoisonManager()
        mgr.add_poison_bottles(PoisonType.TOXIN, 1)
        
        result = mgr.apply_coating(PoisonType.TOXIN)
        assert result
        assert mgr.get_current_coating() == PoisonType.TOXIN

    def test_coating_charges(self):
        """Test coating charge consumption."""
        mgr = PoisonManager()
        mgr.add_poison_bottles(PoisonType.TOXIN, 1)
        mgr.apply_coating(PoisonType.TOXIN, charges=3)
        
        assert mgr.use_coating_charge()
        assert mgr.use_coating_charge()
        assert mgr.use_coating_charge()
        assert mgr.get_current_coating() is None

    def test_edp_activation(self):
        """Test EDP activation."""
        mgr = PoisonManager()
        mgr.activate_edp(40)
        assert mgr.is_edp_active()


# ==================== Rune Manager Tests ====================


class TestRuneManager:
    """Test Rune Manager."""

    def test_initialization(self, data_dir):
        """Test manager initialization."""
        mgr = RuneManager(data_dir)
        assert mgr.current_rune_points == 0

    def test_add_rune_stones(self):
        """Test adding rune stones."""
        mgr = RuneManager()
        mgr.add_rune_stones(RuneType.RUNE_OF_CRASH, 5)
        assert mgr.get_rune_count(RuneType.RUNE_OF_CRASH) == 5

    def test_rune_points(self):
        """Test rune point management."""
        mgr = RuneManager()
        mgr.add_rune_points(50)
        assert mgr.current_rune_points == 50
        
        assert mgr.consume_rune_points(20)
        assert mgr.current_rune_points == 30

    def test_use_rune(self, data_dir):
        """Test rune usage."""
        mgr = RuneManager(data_dir)
        mgr.add_rune_stones(RuneType.RUNE_OF_CRASH, 1)
        mgr.add_rune_points(10)
        
        result = mgr.use_rune(RuneType.RUNE_OF_CRASH)
        assert result
        assert not mgr.is_rune_ready(RuneType.RUNE_OF_CRASH)

    def test_available_runes(self, data_dir):
        """Test getting available runes."""
        mgr = RuneManager(data_dir)
        mgr.add_rune_stones(RuneType.RUNE_OF_CRASH, 1)
        mgr.add_rune_stones(RuneType.RUNE_OF_STORM, 1)
        mgr.add_rune_points(100)
        
        available = mgr.get_available_runes()
        assert len(available) > 0


# ==================== Magic Circle Manager Tests ====================


class TestMagicCircleManager:
    """Test Magic Circle Manager."""

    def test_initialization(self, data_dir):
        """Test manager initialization."""
        mgr = MagicCircleManager(data_dir)
        assert len(mgr.placed_circles) == 0

    def test_place_circle(self, data_dir):
        """Test circle placement."""
        mgr = MagicCircleManager(data_dir)
        result = mgr.place_circle(CircleType.POISON_BUSTER, (10, 10))
        assert result
        assert mgr.get_circle_count() == 1

    def test_insignia_placement(self, data_dir):
        """Test insignia placement."""
        mgr = MagicCircleManager(data_dir)
        mgr.place_circle(CircleType.FIRE_INSIGNIA, (0, 0))
        
        assert mgr.get_active_insignia() == CircleType.FIRE_INSIGNIA

    def test_elemental_bonus(self, data_dir):
        """Test elemental damage bonus."""
        mgr = MagicCircleManager(data_dir)
        mgr.place_circle(CircleType.FIRE_INSIGNIA, (0, 0))
        
        bonus = mgr.get_elemental_bonus("fire")
        assert bonus == 1.5

    def test_circle_limit(self, data_dir):
        """Test circle placement limit."""
        mgr = MagicCircleManager(data_dir)
        mgr.max_circles = 2
        
        mgr.place_circle(CircleType.POISON_BUSTER, (10, 10))
        mgr.place_circle(CircleType.PSYCHIC_WAVE, (20, 20))
        
        # Should fail due to limit
        result = mgr.place_circle(CircleType.STRIKING, (30, 30))
        assert not result


# ==================== Doram Manager Tests ====================


class TestDoramManager:
    """Test Doram Manager."""

    def test_initialization(self):
        """Test manager initialization."""
        mgr = DoramManager()
        assert mgr.spirit_points == 0

    def test_set_branch(self):
        """Test branch setting."""
        mgr = DoramManager()
        mgr.set_branch(DoramBranch.PHYSICAL)
        assert mgr.current_branch == DoramBranch.PHYSICAL

    def test_spirit_points(self):
        """Test spirit point management."""
        mgr = DoramManager()
        mgr.add_spirit_points(5)
        assert mgr.get_spirit_points() == 5
        
        assert mgr.consume_spirit_points(2)
        assert mgr.get_spirit_points() == 3

    def test_summon_companion(self):
        """Test companion summoning."""
        mgr = DoramManager()
        result = mgr.summon_companion(CompanionType.CAT)
        assert result
        
        companions = mgr.get_active_companions()
        assert len(companions) == 1

    def test_spirit_activation(self):
        """Test spirit buff activation."""
        mgr = DoramManager()
        mgr.activate_spirit(SpiritType.CUTE_SPIRIT)
        assert mgr.is_spirit_active(SpiritType.CUTE_SPIRIT)


# ==================== Job AI Coordinator Tests ====================


class TestJobAICoordinator:
    """Test Job AI Coordinator."""

    @pytest.mark.asyncio
    async def test_initialization(self, data_dir):
        """Test coordinator initialization."""
        coordinator = JobAICoordinator(data_dir)
        assert coordinator.current_job is None

    @pytest.mark.asyncio
    async def test_set_job(self, data_dir):
        """Test setting job."""
        coordinator = JobAICoordinator(data_dir)
        # Note: This requires job_classes.json to exist
        # result = await coordinator.set_job(4005)  # Champion
        # assert result

    @pytest.mark.asyncio
    async def test_mechanics_status(self, data_dir):
        """Test getting mechanics status."""
        coordinator = JobAICoordinator(data_dir)
        status = coordinator.get_mechanics_status()
        assert "job_set" in status

    def test_reset_mechanics(self, data_dir):
        """Test resetting all mechanics."""
        coordinator = JobAICoordinator(data_dir)
        coordinator.reset_mechanics()
        
        # Verify all managers are reset
        assert coordinator.spirit_sphere_mgr.current_spheres == 0
        assert len(coordinator.trap_mgr.placed_traps) == 0
        assert coordinator.poison_mgr.current_coating is None


# ==================== Integration Tests ====================


class TestJobMechanicsIntegration:
    """Test integration scenarios."""

    def test_monk_sphere_workflow(self, data_dir):
        """Test Monk sphere generation and consumption."""
        mgr = SpiritSphereManager(data_dir)
        
        # Generate spheres
        mgr.generate_multiple_spheres(5)
        assert mgr.get_sphere_count() == 5
        
        # Use Asura Strike
        can_use, required = mgr.can_use_skill("Asura Strike")
        assert can_use
        assert required == 5
        
        consumed = mgr.consume_spheres("Asura Strike")
        assert consumed == 5
        assert mgr.get_sphere_count() == 0

    def test_hunter_trap_strategy(self, data_dir):
        """Test Hunter trap placement strategy."""
        mgr = TrapManager(data_dir)
        
        # Place boss setup
        mgr.place_trap(TrapType.ANKLE_SNARE, (10, 10))
        mgr.place_trap(TrapType.CLAYMORE_TRAP, (15, 15))
        
        assert mgr.get_trap_count() == 2
        assert mgr.should_use_detonator()

    def test_assassin_poison_rotation(self, data_dir):
        """Test Assassin poison coating rotation."""
        mgr = PoisonManager(data_dir)
        
        # Add poisons
        mgr.add_poison_bottles(PoisonType.TOXIN, 3)
        mgr.add_poison_bottles(PoisonType.ENCHANT_DEADLY_POISON, 1)
        
        # Apply coating
        mgr.apply_coating(PoisonType.TOXIN, charges=10)
        
        # Simulate attacks
        for _ in range(5):
            mgr.use_coating_charge()
        
        # Should recommend reapply
        assert mgr.should_reapply_coating(min_charges=5)

    def test_rune_knight_combat(self, data_dir):
        """Test Rune Knight combat flow."""
        mgr = RuneManager(data_dir)
        
        # Setup runes
        mgr.add_rune_stones(RuneType.RUNE_OF_CRASH, 2)
        mgr.add_rune_stones(RuneType.RUNE_OF_FIGHTING, 1)
        mgr.add_rune_points(100)
        
        # Use offensive rune
        rune = mgr.get_recommended_rune("boss")
        assert rune is not None
        
        result = mgr.use_rune(rune)
        assert result

    def test_sorcerer_circle_combo(self, data_dir):
        """Test Sorcerer magic circle combinations."""
        mgr = MagicCircleManager(data_dir)
        
        # Place insignia
        mgr.place_circle(CircleType.FIRE_INSIGNIA, (0, 0))
        
        # Place tactical circles
        mgr.place_circle(CircleType.POISON_BUSTER, (10, 10))
        mgr.place_circle(CircleType.STRIKING, (15, 15))
        
        # Verify setup
        assert mgr.get_active_insignia() == CircleType.FIRE_INSIGNIA
        assert mgr.get_circle_count() == 2


class TestJobCoordinatorComprehensive:
    """Comprehensive tests for Job AI Coordinator."""
    
    @pytest.fixture
    def coordinator(self, data_dir):
        """Create coordinator instance."""
        return JobAICoordinator(data_dir)
    
    @pytest.mark.asyncio
    async def test_set_job_invalid(self, coordinator):
        """Test setting invalid job."""
        result = await coordinator.set_job(99999)
        assert result is False
        assert coordinator.current_job is None
    
    @pytest.mark.asyncio
    async def test_set_job_valid(self, coordinator, monkeypatch):
        """Test setting valid job."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        # Create mock job
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        
        # Mock job registry
        monkeypatch.setattr(coordinator.job_registry, 'get_job', lambda job_id: mock_job if job_id == 4005 else None)
        
        # Mock rotation engine
        async def mock_load_rotation(job_name):
            pass
        
        result = await coordinator.set_job(4005)
        assert result is True
        assert coordinator.current_job == mock_job
        assert coordinator.current_job_id == 4005
    
    def test_get_current_job_none(self, coordinator):
        """Test getting current job when none set."""
        assert coordinator.get_current_job() is None
    
    def test_get_current_job_set(self, coordinator, monkeypatch):
        """Test getting current job when set."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE
        )
        coordinator.current_job = mock_job
        
        assert coordinator.get_current_job() == mock_job
    
    @pytest.mark.asyncio
    async def test_get_next_action_no_job(self, coordinator):
        """Test getting next action without job set."""
        action = await coordinator.get_next_action({})
        assert action["type"] == "wait"
        assert action["reason"] == "no_job_set"
    
    @pytest.mark.asyncio
    async def test_get_next_action_with_maintenance(self, coordinator, monkeypatch):
        """Test getting next action with maintenance needed."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        coordinator.current_job = mock_job
        
        # Mock maintenance check to return action
        monkeypatch.setattr(coordinator, '_check_mechanics_maintenance', 
                          lambda cs: {"type": "use_skill", "skill": "Summon Spirit Sphere"})
        
        action = await coordinator.get_next_action({})
        assert action["type"] == "use_skill"
        assert action["skill"] == "Summon Spirit Sphere"
    
    @pytest.mark.asyncio
    async def test_get_next_action_with_rotation(self, coordinator, monkeypatch):
        """Test getting next action from rotation."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE
        )
        coordinator.current_job = mock_job
        
        # Mock no maintenance
        monkeypatch.setattr(coordinator, '_check_mechanics_maintenance', lambda cs: None)
        
        # Mock rotation engine
        async def mock_get_next_skill(job_name, rotation_type, char_state, target_state):
            from unittest.mock import Mock
            skill_step = Mock()
            skill_step.skill_name = "Raging Palm Strike"
            skill_step.cast_time_ms = 1000
            skill_step.cooldown_ms = 2000
            return skill_step
        
        monkeypatch.setattr(coordinator.rotation_engine, 'get_next_skill', mock_get_next_skill)
        
        action = await coordinator.get_next_action({}, {})
        assert action["type"] == "use_skill"
        assert "skill" in action
    
    @pytest.mark.asyncio
    async def test_get_next_action_no_rotation(self, coordinator, monkeypatch):
        """Test getting next action when no rotation available."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE
        )
        coordinator.current_job = mock_job
        
        # Mock no maintenance
        monkeypatch.setattr(coordinator, '_check_mechanics_maintenance', lambda cs: None)
        
        # Mock rotation engine returning None
        async def mock_get_next_skill(job_name, rotation_type, char_state, target_state):
            return None
        
        monkeypatch.setattr(coordinator.rotation_engine, 'get_next_skill', mock_get_next_skill)
        
        action = await coordinator.get_next_action({})
        assert action["type"] == "wait"
        assert action["reason"] == "no_action_available"
    
    def test_check_mechanics_maintenance_no_job(self, coordinator):
        """Test maintenance check without job."""
        action = coordinator._check_mechanics_maintenance({})
        assert action is None
    
    def test_check_mechanics_maintenance_spirit_spheres(self, coordinator, monkeypatch):
        """Test maintenance for spirit spheres."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        coordinator.current_job = mock_job
        
        # Mock sphere manager to need generation
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'should_generate_spheres', lambda: True)
        
        action = coordinator._check_mechanics_maintenance({})
        assert action is not None
        assert action["type"] == "use_skill"
        assert action["skill"] == "Summon Spirit Sphere"
    
    def test_check_mechanics_maintenance_poisons(self, coordinator, monkeypatch):
        """Test maintenance for poison coating."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        from ai_sidecar.jobs.mechanics.poisons import PoisonType
        
        mock_job = JobClass(
            job_id=4059,
            name="guillotine_cross",
            display_name="Guillotine Cross",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_poisons=True
        )
        coordinator.current_job = mock_job
        
        # Mock poison manager to need reapply
        monkeypatch.setattr(coordinator.poison_mgr, 'should_reapply_coating', lambda: True)
        monkeypatch.setattr(coordinator.poison_mgr, 'get_recommended_poison', 
                          lambda target: PoisonType.TOXIN)
        
        action = coordinator._check_mechanics_maintenance({})
        assert action is not None
        assert action["type"] == "apply_poison"
    
    def test_check_mechanics_maintenance_runes(self, coordinator, monkeypatch):
        """Test maintenance for runes."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        from ai_sidecar.jobs.mechanics.runes import RuneType
        
        mock_job = JobClass(
            job_id=4054,
            name="rune_knight",
            display_name="Rune Knight",
            tier=JobTier.THIRD,
            primary_role=CombatRole.TANK,
            positioning=PositioningStyle.MELEE,
            has_runes=True
        )
        coordinator.current_job = mock_job
        
        # Mock rune manager
        monkeypatch.setattr(coordinator.rune_mgr, 'get_available_runes', 
                          lambda: [RuneType.RUNE_OF_CRASH])
        monkeypatch.setattr(coordinator.rune_mgr, 'get_recommended_rune', 
                          lambda target: RuneType.RUNE_OF_CRASH)
        
        action = coordinator._check_mechanics_maintenance({"in_combat": True})
        assert action is not None
        assert action["type"] == "use_rune"
    
    def test_enhance_action_no_job(self, coordinator):
        """Test action enhancement without job."""
        action = {"type": "use_skill", "skill": "Test"}
        enhanced = coordinator._enhance_action_with_mechanics(action, {})
        assert enhanced == action
    
    def test_enhance_action_with_spirit_spheres(self, coordinator, monkeypatch):
        """Test action enhancement with spirit spheres."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        coordinator.current_job = mock_job
        
        # Mock sphere manager
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'can_use_skill', 
                          lambda skill: (True, 5))
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'get_sphere_count', lambda: 5)
        
        action = {"type": "use_skill", "skill": "Asura Strike"}
        enhanced = coordinator._enhance_action_with_mechanics(action, {})
        
        assert "spirit_spheres" in enhanced
        assert enhanced["spirit_spheres"]["can_use"] is True
        assert enhanced["spirit_spheres"]["required"] == 5
        assert enhanced["spirit_spheres"]["current"] == 5
    
    def test_enhance_action_with_poisons(self, coordinator, monkeypatch):
        """Test action enhancement with poison coating."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        from ai_sidecar.jobs.mechanics.poisons import PoisonType
        
        mock_job = JobClass(
            job_id=4059,
            name="guillotine_cross",
            display_name="Guillotine Cross",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_poisons=True
        )
        coordinator.current_job = mock_job
        
        # Mock poison manager
        monkeypatch.setattr(coordinator.poison_mgr, 'get_current_coating', 
                          lambda: PoisonType.TOXIN)
        monkeypatch.setattr(coordinator.poison_mgr, 'is_edp_active', lambda: True)
        
        action = {"type": "attack"}
        enhanced = coordinator._enhance_action_with_mechanics(action, {})
        
        assert enhanced["poison_coating"] == PoisonType.TOXIN.value
        assert enhanced["edp_active"] is True
    
    def test_enhance_action_with_runes(self, coordinator, monkeypatch):
        """Test action enhancement with runes."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        from ai_sidecar.jobs.mechanics.runes import RuneType
        
        mock_job = JobClass(
            job_id=4054,
            name="rune_knight",
            display_name="Rune Knight",
            tier=JobTier.THIRD,
            primary_role=CombatRole.TANK,
            positioning=PositioningStyle.MELEE,
            has_runes=True
        )
        coordinator.current_job = mock_job
        coordinator.rune_mgr.current_rune_points = 50
        
        # Mock available runes
        monkeypatch.setattr(coordinator.rune_mgr, 'get_available_runes', 
                          lambda: [RuneType.RUNE_OF_CRASH])
        
        action = {"type": "use_skill"}
        enhanced = coordinator._enhance_action_with_mechanics(action, {})
        
        assert enhanced["rune_points"] == 50
        assert RuneType.RUNE_OF_CRASH.value in enhanced["available_runes"]
    
    def test_enhance_action_with_magic_circles(self, coordinator, monkeypatch):
        """Test action enhancement with magic circles."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        from ai_sidecar.jobs.mechanics.magic_circles import CircleType
        
        mock_job = JobClass(
            job_id=4081,
            name="sorcerer",
            display_name="Sorcerer",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MAGIC_DPS,
            positioning=PositioningStyle.LONG_RANGE,
            has_magic_circles=True
        )
        coordinator.current_job = mock_job
        
        # Mock magic circle manager
        monkeypatch.setattr(coordinator.magic_circle_mgr, 'get_active_insignia', 
                          lambda: CircleType.FIRE_INSIGNIA)
        monkeypatch.setattr(coordinator.magic_circle_mgr, 'get_circle_count', lambda: 3)
        
        action = {"type": "use_skill"}
        enhanced = coordinator._enhance_action_with_mechanics(action, {})
        
        assert enhanced["active_insignia"] == CircleType.FIRE_INSIGNIA.value
        assert enhanced["circle_count"] == 3
    
    def test_update_mechanics_state_no_job(self, coordinator):
        """Test update mechanics without job."""
        # Should not raise error
        coordinator.update_mechanics_state("skill_used", {})
    
    def test_update_mechanics_spirit_sphere_skill(self, coordinator, monkeypatch):
        """Test spirit sphere update on skill use."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        coordinator.current_job = mock_job
        
        # Mock sphere manager
        consume_called = []
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'consume_spheres', 
                          lambda skill: consume_called.append(skill) or 5)
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'is_generation_skill', 
                          lambda skill: False)
        
        coordinator.update_mechanics_state("skill_used", {"skill_name": "Asura Strike"})
        assert "Asura Strike" in consume_called
    
    def test_update_mechanics_sphere_generation(self, coordinator, monkeypatch):
        """Test spirit sphere generation on skill use."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_spirit_spheres=True
        )
        coordinator.current_job = mock_job
        
        # Mock sphere manager
        generated_count = []
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'consume_spheres', lambda skill: 0)
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'is_generation_skill', 
                          lambda skill: True)
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'generate_multiple_spheres', 
                          lambda count: generated_count.append(count) or count)
        
        coordinator.update_mechanics_state("skill_used", 
                                         {"skill_name": "Triple Attack", "spheres_generated": 3})
        assert 3 in generated_count
    
    def test_update_mechanics_poison_attack(self, coordinator, monkeypatch):
        """Test poison coating update on attack."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4059,
            name="guillotine_cross",
            display_name="Guillotine Cross",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_poisons=True
        )
        coordinator.current_job = mock_job
        
        # Mock poison manager
        used = []
        monkeypatch.setattr(coordinator.poison_mgr, 'use_coating_charge', 
                          lambda: used.append(True) or True)
        
        coordinator.update_mechanics_state("attack", {})
        assert len(used) == 1
    
    def test_update_mechanics_edp_buff(self, coordinator, monkeypatch):
        """Test EDP buff application."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4059,
            name="guillotine_cross",
            display_name="Guillotine Cross",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            has_poisons=True
        )
        coordinator.current_job = mock_job
        
        # Mock poison manager
        activated = []
        monkeypatch.setattr(coordinator.poison_mgr, 'activate_edp', 
                          lambda dur: activated.append(dur))
        
        coordinator.update_mechanics_state("buff_applied", 
                                         {"buff_name": "Enchant Deadly Poison", "duration": 45})
        assert 45 in activated
    
    def test_update_mechanics_rune_used(self, coordinator, monkeypatch):
        """Test rune usage event."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4054,
            name="rune_knight",
            display_name="Rune Knight",
            tier=JobTier.THIRD,
            primary_role=CombatRole.TANK,
            positioning=PositioningStyle.MELEE,
            has_runes=True
        )
        coordinator.current_job = mock_job
        
        # Should not raise error
        coordinator.update_mechanics_state("rune_used", {})
    
    def test_update_mechanics_rune_points(self, coordinator, monkeypatch):
        """Test rune point generation."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4054,
            name="rune_knight",
            display_name="Rune Knight",
            tier=JobTier.THIRD,
            primary_role=CombatRole.TANK,
            positioning=PositioningStyle.MELEE,
            has_runes=True
        )
        coordinator.current_job = mock_job
        
        # Mock rune manager
        added_points = []
        monkeypatch.setattr(coordinator.rune_mgr, 'add_rune_points', 
                          lambda pts: added_points.append(pts))
        
        coordinator.update_mechanics_state("combat_tick", {"points": 10})
        assert 10 in added_points
    
    def test_update_mechanics_trap_triggered(self, coordinator, monkeypatch):
        """Test trap trigger event."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4013,
            name="ranger",
            display_name="Ranger",
            tier=JobTier.THIRD,
            primary_role=CombatRole.RANGED_DPS,
            positioning=PositioningStyle.LONG_RANGE,
            has_traps=True
        )
        coordinator.current_job = mock_job
        
        # Mock trap manager
        triggered_pos = []
        monkeypatch.setattr(coordinator.trap_mgr, 'trigger_trap', 
                          lambda pos: triggered_pos.append(pos))
        
        coordinator.update_mechanics_state("trap_triggered", {"position": (10, 10)})
        assert (10, 10) in triggered_pos
    
    def test_update_mechanics_magic_circle(self, coordinator, monkeypatch):
        """Test magic circle placement event."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4081,
            name="sorcerer",
            display_name="Sorcerer",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MAGIC_DPS,
            positioning=PositioningStyle.LONG_RANGE,
            has_magic_circles=True
        )
        coordinator.current_job = mock_job
        
        # Should not raise error
        coordinator.update_mechanics_state("circle_placed", {})
    
    def test_update_mechanics_doram_ability(self, coordinator, monkeypatch):
        """Test Doram ability usage."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4218,
            name="spirit_handler",
            display_name="spirit_handler",
            tier=JobTier.EXTENDED,
            primary_role=CombatRole.MAGIC_DPS,
            positioning=PositioningStyle.MID_RANGE
        )
        coordinator.current_job = mock_job
        coordinator.doram_mgr.ability_costs = {"Hiss": 5}
        
        # Mock doram manager
        consumed = []
        monkeypatch.setattr(coordinator.doram_mgr, 'consume_spirit_points', 
                          lambda pts: consumed.append(pts))
        
        coordinator.update_mechanics_state("ability_used", {"ability_name": "Hiss"})
        assert 5 in consumed
    
    def test_get_mechanics_status_no_job(self, coordinator):
        """Test getting mechanics status without job."""
        status = coordinator.get_mechanics_status()
        assert status["job_set"] is False
    
    def test_get_mechanics_status_with_all_mechanics(self, coordinator, monkeypatch):
        """Test getting status with all mechanics."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4218,
            name="spirit_handler",
            display_name="spirit_handler",
            tier=JobTier.EXTENDED,
            primary_role=CombatRole.MAGIC_DPS,
            positioning=PositioningStyle.MID_RANGE,
            has_spirit_spheres=True,
            has_traps=True,
            has_poisons=True,
            has_runes=True,
            has_magic_circles=True
        )
        coordinator.current_job = mock_job
        coordinator.current_job_id = 4218
        
        # Mock all managers to return status
        monkeypatch.setattr(coordinator.spirit_sphere_mgr, 'get_status', lambda: {"spheres": 5})
        monkeypatch.setattr(coordinator.trap_mgr, 'get_status', lambda: {"traps": 2})
        monkeypatch.setattr(coordinator.poison_mgr, 'get_status', lambda: {"coating": "toxin"})
        monkeypatch.setattr(coordinator.rune_mgr, 'get_status', lambda: {"points": 50})
        monkeypatch.setattr(coordinator.magic_circle_mgr, 'get_status', lambda: {"circles": 3})
        monkeypatch.setattr(coordinator.doram_mgr, 'get_status', lambda: {"spirit_points": 10})
        
        status = coordinator.get_mechanics_status()
        
        assert status["job_set"] is True
        assert status["job_name"] == "spirit_handler"
        assert "spirit_spheres" in status
        assert "traps" in status
        assert "poisons" in status
        assert "runes" in status
        assert "magic_circles" in status
        assert "doram" in status
    
    def test_get_job_stats_no_job(self, coordinator):
        """Test getting job stats without job."""
        stats = coordinator.get_job_stats()
        assert stats == {}
    
    def test_get_job_stats_with_job(self, coordinator):
        """Test getting job stats with job set."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="champion",
            display_name="Champion",
            tier=JobTier.TRANSCENDENT,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE,
            recommended_stats={"str": 120, "agi": 90, "vit": 70},
            stat_weights={"str": 1.5, "agi": 1.2},
            armor_type="light",
            preferred_weapon="knuckle"
        )
        coordinator.current_job = mock_job
        
        stats = coordinator.get_job_stats()
        
        assert "recommended_stats" in stats
        assert "stat_weights" in stats
        assert stats["positioning"] == PositioningStyle.MELEE.value
        assert stats["armor_type"] == "light"
        assert stats["preferred_weapon"] == "knuckle"
    
    def test_get_job_skills_no_job(self, coordinator):
        """Test getting job skills without job."""
        skills = coordinator.get_job_skills()
        assert skills == set()
    
    def test_get_job_skills_with_job(self, coordinator, monkeypatch):
        """Test getting job skills with job set."""
        from ai_sidecar.jobs.registry import JobClass, CombatRole, PositioningStyle, JobTier
        
        mock_job = JobClass(
            job_id=4005,
            name="Champion",
            display_name="Champion",
            tier=JobTier.THIRD,
            primary_role=CombatRole.MELEE_DPS,
            positioning=PositioningStyle.MELEE
        )
        coordinator.current_job = mock_job
        
        # Mock job registry
        mock_skills = {"Asura Strike", "Raging Palm Strike", "Guillotine Fist"}
        monkeypatch.setattr(coordinator.job_registry, 'get_all_skills_for_job', 
                          lambda name: mock_skills)
        
        skills = coordinator.get_job_skills()
        assert skills == mock_skills
