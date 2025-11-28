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
        assert mgr.get_elemental_bonus("fire") == 1.5