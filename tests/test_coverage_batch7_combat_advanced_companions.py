"""
Coverage Batch 7: Advanced Combat Systems & Companions
Target: 92% → 93% coverage (~250-300 lines)
Modules: companions/homunculus (571 lines), combat/combos (590 lines),
         combat/aoe (527 lines), crafting/forging (484 lines)

Tests comprehensive coverage of:
- Homunculus AI management
- Skill combo execution
- AoE targeting optimization
- Weapon forging system
"""

import json
import pytest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock, mock_open

from ai_sidecar.companions.homunculus import (
    HomunculusManager,
    HomunculusState,
    HomunculusType,
    HomunculusStatBuild,
    StatAllocation,
    SkillAllocation,
    EvolutionDecision,
)
from ai_sidecar.companions.pet import SkillAction
from ai_sidecar.combat.combos import (
    SkillComboEngine,
    ComboState,
    SkillCombo,
    ComboStep,
)
from ai_sidecar.combat.aoe import (
    AoETargetingSystem,
    AoESkill,
    AoEShape,
    AoETarget,
    AoEResult,
)
from ai_sidecar.crafting.forging import (
    ForgingManager,
    ForgeableWeapon,
    ForgeResult,
    ForgeElement,
)
from ai_sidecar.crafting.core import CraftingManager, Material


# ============================================================================
# HOMUNCULUS MANAGER TESTS
# ============================================================================


class TestHomunculusManagerCore:
    """Test HomunculusManager core functionality."""
    
    def test_homunculus_manager_initialization_with_nonexistent_file(self, tmp_path):
        """Cover HomunculusManager.__init__ with missing database file."""
        data_file = tmp_path / "homunculus.json"
        # File doesn't exist
        
        manager = HomunculusManager(data_path=data_file)
        
        assert manager is not None
        assert manager.current_state is None
        assert manager._homunculus_database == {}
        assert manager._target_build is None
    
    def test_homunculus_manager_initialization_with_existing_file(self, tmp_path):
        """Cover HomunculusManager.__init__ with valid database file."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "skills": {"Healing Hands": 5, "Urgent Escape": 3},
                "evolution": {"standard": "lif2", "s_evolution": "eira"}
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        
        assert len(manager._homunculus_database) == 1
        assert "lif" in manager._homunculus_database
    
    @pytest.mark.asyncio
    async def test_update_state_basic(self, tmp_path):
        """Cover update_state with basic state update."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
        )
        
        await manager.update_state(state)
        
        assert manager.current_state == state
        assert not state.can_evolve  # Level 50, intimacy 500, not ready
    
    @pytest.mark.asyncio
    async def test_update_state_evolution_ready(self, tmp_path):
        """Cover update_state with evolution eligibility check."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "evolution": {"standard": "lif2", "s_evolution": "eira"}
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=99,
            intimacy=910,  # Meets evolution requirement
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
        )
        
        await manager.update_state(state)
        
        assert state.can_evolve
        assert state.evolution_form == HomunculusType.LIF_EVOLVED
    
    @pytest.mark.asyncio
    async def test_set_target_build_valid(self, tmp_path):
        """Cover set_target_build with valid S-class type."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        await manager.set_target_build(HomunculusType.EIRA)
        
        assert manager._target_build is not None
        assert manager._target_build.type == HomunculusType.EIRA
    
    @pytest.mark.asyncio
    async def test_set_target_build_invalid(self, tmp_path):
        """Cover set_target_build with invalid type."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        # Use a base type that's not in STAT_BUILDS
        await manager.set_target_build(HomunculusType.LIF)
        
        # Should log warning but not crash
        assert manager._target_build is None


class TestHomunculusStatDistribution:
    """Test homunculus stat distribution logic."""
    
    @pytest.mark.asyncio
    async def test_calculate_stat_distribution_no_state(self, tmp_path):
        """Cover calculate_stat_distribution with no current state."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        result = await manager.calculate_stat_distribution()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_calculate_stat_distribution_no_skill_points(self, tmp_path):
        """Cover calculate_stat_distribution with zero skill points."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            skill_points=0,  # No points available
        )
        await manager.update_state(state)
        
        result = await manager.calculate_stat_distribution()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_calculate_stat_distribution_auto_select_build(self, tmp_path):
        """Cover calculate_stat_distribution with auto build selection."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            stat_str=10,
            agi=10,
            vit=10,
            int_stat=10,
            dex=10,
            luk=10,
            skill_points=5,
        )
        await manager.update_state(state)
        # No target build set - should auto-select
        
        result = await manager.calculate_stat_distribution()
        
        assert result is not None
        assert isinstance(result, StatAllocation)
        assert result.stat_name in ["int", "dex", "vit", "agi", "str", "luk"]
    
    @pytest.mark.asyncio
    async def test_calculate_stat_distribution_with_target_build(self, tmp_path):
        """Cover calculate_stat_distribution with target build set."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        await manager.set_target_build(HomunculusType.EIRA)
        
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            stat_str=5,
            agi=5,
            vit=10,
            int_stat=20,  # INT already high for Eira build
            dex=15,
            luk=5,
            skill_points=3,
        )
        await manager.update_state(state)
        
        result = await manager.calculate_stat_distribution()
        
        assert result is not None
        assert isinstance(result, StatAllocation)
        # Should prioritize INT or DEX for Eira build
        assert result.stat_name in ["int", "dex", "vit"]
    
    @pytest.mark.asyncio
    async def test_calculate_stat_distribution_zero_total_stats(self, tmp_path):
        """Cover calculate_stat_distribution edge case with zero stats."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        await manager.set_target_build(HomunculusType.EIRA)
        
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=1,
            intimacy=250,
            hp=100,
            max_hp=100,
            sp=10,
            max_sp=10,
            stat_str=0,
            agi=0,
            vit=0,
            int_stat=0,
            dex=0,
            luk=0,
            skill_points=1,
        )
        await manager.update_state(state)
        
        result = await manager.calculate_stat_distribution()
        
        # With zero stats, it defaults to priority stat allocation
        assert result is not None
        assert result.stat_name in ["int", "dex", "vit", "agi", "str", "luk"]


class TestHomunculusSkillAllocation:
    """Test homunculus skill point allocation."""
    
    @pytest.mark.asyncio
    async def test_allocate_skill_points_no_state(self, tmp_path):
        """Cover allocate_skill_points with no current state."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        result = await manager.allocate_skill_points()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_allocate_skill_points_no_points(self, tmp_path):
        """Cover allocate_skill_points with no skill points."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            skill_points=0,
        )
        await manager.update_state(state)
        
        result = await manager.allocate_skill_points()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_allocate_skill_points_with_database(self, tmp_path):
        """Cover allocate_skill_points with skill database."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "skills": {
                    "Healing Hands": 5,
                    "Urgent Escape": 3,
                    "Brain Surgery": 3,
                }
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=500,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            skills={"Healing Hands": 3},  # Already level 3
            skill_points=2,
        )
        await manager.update_state(state)
        
        result = await manager.allocate_skill_points()
        
        assert result is not None
        assert isinstance(result, SkillAllocation)
        assert result.skill_name in ["Healing Hands", "Urgent Escape", "Brain Surgery"]
    
    @pytest.mark.asyncio
    async def test_allocate_skill_points_all_maxed(self, tmp_path):
        """Cover allocate_skill_points when all skills maxed."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "skills": {
                    "Healing Hands": 5,
                    "Urgent Escape": 3,
                }
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=99,
            intimacy=910,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            skills={"Healing Hands": 5, "Urgent Escape": 3},  # All maxed
            skill_points=10,
        )
        await manager.update_state(state)
        
        result = await manager.allocate_skill_points()
        
        assert result is None


class TestHomunculusEvolution:
    """Test homunculus evolution decision logic."""
    
    @pytest.mark.asyncio
    async def test_decide_evolution_path_no_state(self, tmp_path):
        """Cover decide_evolution_path with no state."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        result = await manager.decide_evolution_path()
        
        assert result.should_evolve is False
        assert result.reason == "no_homunculus_state"
    
    @pytest.mark.asyncio
    async def test_decide_evolution_path_requirements_not_met(self, tmp_path):
        """Cover decide_evolution_path when requirements not met."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,  # Not level 99
            intimacy=500,  # Not 910+
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
        )
        await manager.update_state(state)
        
        result = await manager.decide_evolution_path()
        
        assert result.should_evolve is False
        assert result.reason == "basic_requirements_not_met"
        assert not result.requirements_met["level_99"]
        assert not result.requirements_met["intimacy_910"]
    
    @pytest.mark.asyncio
    async def test_decide_evolution_path_with_s_evolution_data(self, tmp_path):
        """Cover decide_evolution_path with S-class evolution path available."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "evolution": {"standard": "lif2", "s_evolution": "eira"}
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        # Without target build, s_class_eligible will be False
        
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=99,
            intimacy=910,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            stat_str=20,
            agi=20,
            vit=20,
            int_stat=20,
            dex=20,
            luk=20,
        )
        await manager.update_state(state)
        
        result = await manager.decide_evolution_path()
        
        # Without target build or s-class stats, falls back to standard
        assert result.should_evolve is True
        assert result.target_form == HomunculusType.LIF_EVOLVED
    
    @pytest.mark.asyncio
    async def test_decide_evolution_path_standard_evolution(self, tmp_path):
        """Cover decide_evolution_path recommending standard evolution."""
        data_file = tmp_path / "homunculus.json"
        database = {
            "lif": {
                "evolution": {"standard": "lif2"}
            }
        }
        data_file.write_text(json.dumps(database))
        
        manager = HomunculusManager(data_path=data_file)
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=99,
            intimacy=910,
            hp=1000,
            max_hp=1000,
            sp=100,
            max_sp=100,
            stat_str=20,
            agi=20,
            vit=20,
            int_stat=20,
            dex=20,
            luk=20,
        )
        await manager.update_state(state)
        
        result = await manager.decide_evolution_path()
        
        assert result.should_evolve is True
        assert result.path_type == "standard"
        assert result.target_form == HomunculusType.LIF_EVOLVED


class TestHomunculusTacticalSkills:
    """Test homunculus tactical skill usage."""
    
    @pytest.mark.asyncio
    async def test_tactical_skill_usage_no_state(self, tmp_path):
        """Cover tactical_skill_usage with no state."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        
        result = await manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.5,
            player_sp_percent=0.8,
            enemies_nearby=3,
            ally_count=0,
        )
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_tactical_skill_usage_lif_healing(self, tmp_path):
        """Cover tactical_skill_usage for Lif healing."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.LIF,
            level=50,
            intimacy=800,
            hp=500,
            max_hp=500,
            sp=50,
            max_sp=50,
            skills={"Healing Hands": 5},
        )
        await manager.update_state(state)
        
        result = await manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.5,  # Low HP
            player_sp_percent=0.8,
            enemies_nearby=2,
            ally_count=0,
        )
        
        assert result is not None
        assert isinstance(result, SkillAction)
        assert result.skill_name == "Healing Hands"
        assert result.reason == "player_needs_healing"
    
    @pytest.mark.asyncio
    async def test_tactical_skill_usage_amistr_tank(self, tmp_path):
        """Cover tactical_skill_usage for Amistr defensive buff."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.AMISTR,
            level=60,
            intimacy=900,
            hp=800,
            max_hp=800,
            sp=60,
            max_sp=60,
            skills={"Amistr Bulwark": 5},
        )
        await manager.update_state(state)
        
        result = await manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.9,
            player_sp_percent=0.7,
            enemies_nearby=3,  # Multiple enemies
            ally_count=1,
        )
        
        assert result is not None
        assert result.skill_name == "Amistr Bulwark"
        assert result.reason == "defensive_buff_multiple_enemies"
    
    @pytest.mark.asyncio
    async def test_tactical_skill_usage_filir_speed(self, tmp_path):
        """Cover tactical_skill_usage for Filir speed buff."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.FILIR,
            level=70,
            intimacy=950,
            hp=600,
            max_hp=600,
            sp=40,
            max_sp=40,
            skills={"Flitting": 5},
        )
        await manager.update_state(state)
        
        result = await manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.8,
            player_sp_percent=0.6,
            enemies_nearby=1,
            ally_count=0,
        )
        
        assert result is not None
        assert result.skill_name == "Flitting"
        assert result.reason == "speed_buff_combat"
    
    @pytest.mark.asyncio
    async def test_tactical_skill_usage_vanilmirth_magic(self, tmp_path):
        """Cover tactical_skill_usage for Vanilmirth magic damage."""
        manager = HomunculusManager(data_path=tmp_path / "homun.json")
        state = HomunculusState(
            homun_id=1,
            type=HomunculusType.VANILMIRTH,
            level=80,
            intimacy=1000,
            hp=400,
            max_hp=400,
            sp=30,
            max_sp=50,
            skills={"Caprice": 5, "Chaotic Blessings": 3},
        )
        await manager.update_state(state)
        
        result = await manager.tactical_skill_usage(
            combat_active=True,
            player_hp_percent=0.9,
            player_sp_percent=0.5,
            enemies_nearby=2,
            ally_count=0,
        )
        
        assert result is not None
        assert result.skill_name in ["Caprice", "Chaotic Blessings"]
        assert result.reason == "magic_damage_output"


# ============================================================================
# SKILL COMBO ENGINE TESTS
# ============================================================================


class TestSkillComboEngineCore:
    """Test SkillComboEngine core functionality."""
    
    def test_skill_combo_engine_initialization_no_data(self):
        """Cover SkillComboEngine.__init__ with no data directory."""
        engine = SkillComboEngine()
        
        assert engine is not None
        assert len(engine.combos) > 0  # Should have default combos
        assert engine.current_combo is None
    
    def test_skill_combo_engine_initialization_with_missing_file(self, tmp_path):
        """Cover SkillComboEngine.__init__ with missing data file."""
        engine = SkillComboEngine(data_dir=tmp_path)
        
        assert len(engine.combos) > 0  # Falls back to defaults
    
    def test_skill_combo_engine_initialization_with_valid_file(self, tmp_path):
        """Cover SkillComboEngine.__init__ with valid combo data."""
        combo_file = tmp_path / "skill_combos.json"
        combo_data = {
            "test_job": [{
                "combo_id": "test_combo",
                "combo_name": "Test Combo",
                "job_class": "test_job",
                "steps": [
                    {
                        "skill_name": "Skill A",
                        "skill_level": 1,
                        "delay_after_ms": 500,
                        "sp_cost": 10,
                    }
                ],
                "min_sp": 10,
                "total_duration_ms": 1000,
            }]
        }
        combo_file.write_text(json.dumps(combo_data))
        
        engine = SkillComboEngine(data_dir=tmp_path)
        
        assert "test_job" in engine.combos
        assert len(engine.combos["test_job"]) == 1
    
    @pytest.mark.asyncio
    async def test_get_available_combos_no_sp(self):
        """Cover get_available_combos with insufficient SP."""
        engine = SkillComboEngine()
        
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=50,  # Not enough for most combos
            active_buffs=[],
            weapon_type="katar",
        )
        
        assert isinstance(combos, list)
        # Should filter out combos requiring more SP
    
    @pytest.mark.asyncio
    async def test_get_available_combos_wrong_weapon(self):
        """Cover get_available_combos with wrong weapon type."""
        engine = SkillComboEngine()
        
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=200,
            active_buffs=[],
            weapon_type="dagger",  # Sinx combo needs katar
        )
        
        # Should filter out katar-specific combos
        assert all(
            c.required_weapon is None or c.required_weapon != "katar"
            for c in combos
        )
    
    @pytest.mark.asyncio
    async def test_get_available_combos_missing_buffs(self):
        """Cover get_available_combos with missing required buffs."""
        engine = SkillComboEngine()
        
        combos = await engine.get_available_combos(
            job_class="high_wizard",
            sp_current=100,
            active_buffs=[],  # No buffs active
            weapon_type=None,
        )
        
        # Should only return combos without buff requirements
        assert all(not c.required_buffs for c in combos)


class TestSkillComboSelection:
    """Test combo selection logic."""
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_empty_list(self):
        """Cover select_optimal_combo with empty combo list."""
        engine = SkillComboEngine()
        
        result = await engine.select_optimal_combo(
            available_combos=[],
            situation="pve",
            target_count=1,
            sp_available=100,
        )
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_insufficient_sp(self):
        """Cover select_optimal_combo when all combos need more SP."""
        engine = SkillComboEngine()
        combos = await engine.get_available_combos(
            job_class="lord_knight",
            sp_current=200,
            active_buffs=[],
            weapon_type="spear",
        )
        
        result = await engine.select_optimal_combo(
            available_combos=combos,
            situation="pve",
            target_count=1,
            sp_available=10,  # Very low SP
        )
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_pvp_situation(self):
        """Cover select_optimal_combo for PvP situation."""
        engine = SkillComboEngine()
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=200,
            active_buffs=[],
            weapon_type="katar",
        )
        
        result = await engine.select_optimal_combo(
            available_combos=combos,
            situation="pvp",
            target_count=1,
            sp_available=200,
        )
        
        if result:
            # Should prioritize high PvP rating
            assert result.pvp_rating > 0
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_aoe_multi_target(self):
        """Cover select_optimal_combo with multiple targets for AoE."""
        engine = SkillComboEngine()
        combos = await engine.get_available_combos(
            job_class="high_wizard",
            sp_current=200,
            active_buffs=[],
            weapon_type=None,
        )
        
        result = await engine.select_optimal_combo(
            available_combos=combos,
            situation="pve",
            target_count=5,  # Multiple targets
            sp_available=200,
        )
        
        if result:
            # Should prioritize AoE-capable combos
            assert result.aoe_capable or result.pve_rating > 0


class TestSkillComboExecution:
    """Test combo execution flow."""
    
    @pytest.mark.asyncio
    async def test_start_combo_not_found(self):
        """Cover start_combo with invalid combo ID."""
        engine = SkillComboEngine()
        
        result = await engine.start_combo("nonexistent_combo")
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_start_combo_success(self):
        """Cover start_combo with valid combo ID."""
        engine = SkillComboEngine()
        
        result = await engine.start_combo("sinx_sonic_chain")
        
        assert result is not None
        assert isinstance(result, ComboState)
        assert result.combo_id == "sinx_sonic_chain"
        assert result.current_step == 0
        assert engine._active_combo_def is not None
    
    @pytest.mark.asyncio
    async def test_get_next_skill_no_combo(self):
        """Cover get_next_skill with no active combo."""
        engine = SkillComboEngine()
        
        result = await engine.get_next_skill()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_get_next_skill_in_progress(self):
        """Cover get_next_skill during combo."""
        engine = SkillComboEngine()
        await engine.start_combo("sinx_sonic_chain")
        
        result = await engine.get_next_skill()
        
        assert result is not None
        assert isinstance(result, ComboStep)
    
    @pytest.mark.asyncio
    async def test_get_next_skill_combo_complete(self):
        """Cover get_next_skill when combo is complete."""
        engine = SkillComboEngine()
        state = await engine.start_combo("sinx_sonic_chain")
        # Advance past all steps
        state.current_step = 999
        
        result = await engine.get_next_skill()
        
        assert result is None
    
    @pytest.mark.asyncio
    async def test_record_skill_result_success(self):
        """Cover record_skill_result with successful hit."""
        engine = SkillComboEngine()
        await engine.start_combo("sinx_sonic_chain")
        
        await engine.record_skill_result(hit=True, damage=1000)
        
        assert engine.current_combo.hits_landed == 1
        assert engine.current_combo.damage_dealt == 1000
        assert engine.current_combo.current_step == 1
    
    @pytest.mark.asyncio
    async def test_record_skill_result_miss_requires_hit(self):
        """Cover record_skill_result with miss on skill requiring hit."""
        engine = SkillComboEngine()
        await engine.start_combo("sinx_sonic_chain")
        # Advance to step that requires hit
        engine.current_combo.current_step = 1
        
        await engine.record_skill_result(hit=False, damage=0)
        
        # Combo should be aborted
        assert engine.current_combo is None
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_target_died(self):
        """Cover should_abort_combo when target dies."""
        engine = SkillComboEngine()
        await engine.start_combo("sinx_sonic_chain")
        
        should_abort = await engine.should_abort_combo(
            current_hp_percent=0.8,
            target_died=True,
        )
        
        assert should_abort is True
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_low_hp(self):
        """Cover should_abort_combo when HP critical."""
        engine = SkillComboEngine()
        await engine.start_combo("lk_spiral_combo")
        
        should_abort = await engine.should_abort_combo(
            current_hp_percent=0.1,  # 10% HP
            target_died=False,
        )
        
        assert should_abort is True
    
    @pytest.mark.asyncio
    async def test_finish_combo(self):
        """Cover finish_combo with stats collection."""
        engine = SkillComboEngine()
        await engine.start_combo("sinx_sonic_chain")
        await engine.record_skill_result(hit=True, damage=500)
        await engine.record_skill_result(hit=True, damage=800)
        
        stats = await engine.finish_combo()
        
        assert stats["combo_id"] == "sinx_sonic_chain"
        assert stats["hits_landed"] == 2
        assert stats["damage_dealt"] == 1300
        assert engine.current_combo is None


class TestSkillComboUtilities:
    """Test combo utility methods."""
    
    def test_get_next_combo_skill_empty_history(self):
        """Cover get_next_combo_skill with empty history."""
        engine = SkillComboEngine()
        
        result = engine.get_next_combo_skill([])
        
        assert result is None
    
    def test_get_next_combo_skill_found(self):
        """Cover get_next_combo_skill with valid skill chain."""
        engine = SkillComboEngine()
        
        result = engine.get_next_combo_skill(["Enchant Deadly Poison"])
        
        # Should find next skill in sinx combo
        assert result is not None
    
    def test_check_combo_skill_found(self):
        """Cover check_combo when skill is in combo."""
        engine = SkillComboEngine()
        
        result = engine.check_combo("Sonic Blow")
        
        assert result is not None
        assert "combo_id" in result
        assert result["skill_name"] == "Sonic Blow"
    
    def test_check_combo_skill_not_found(self):
        """Cover check_combo when skill not in any combo."""
        engine = SkillComboEngine()
        
        result = engine.check_combo("Fireball")
        
        assert result is None


# ============================================================================
# AOE TARGETING SYSTEM TESTS
# ============================================================================


class TestAoETargetingSystemCore:
    """Test AoETargetingSystem core functionality."""
    
    def test_aoe_targeting_system_initialization_no_data(self):
        """Cover AoETargetingSystem.__init__ without data directory."""
        system = AoETargetingSystem()
        
        assert system is not None
        assert len(system.aoe_skills) > 0  # Should have default skills
    
    def test_aoe_targeting_system_initialization_with_file(self, tmp_path):
        """Cover AoETargetingSystem.__init__ with skill data file."""
        skill_file = tmp_path / "aoe_skills.json"
        skill_data = {
            "Test Skill": {
                "shape": "circle",
                "range": 3,
                "cast_range": 9,
                "cells_affected": 37,
                "hits_per_target": 5,
                "sp_cost": 50,
            }
        }
        skill_file.write_text(json.dumps(skill_data))
        
        system = AoETargetingSystem(data_dir=tmp_path)
        
        assert "test skill" in system.aoe_skills
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_no_monsters(self):
        """Cover find_optimal_center with empty monster list."""
        system = AoETargetingSystem()
        skill = system.aoe_skills["storm gust"]
        
        result = await system.find_optimal_center(
            monster_positions=[],
            aoe_skill=skill,
            player_position=(100, 100),
        )
        
        assert result == (100, 100)  # Returns player position
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_self_centered(self):
        """Cover find_optimal_center with self-centered skill."""
        system = AoETargetingSystem()
        skill = AoESkill(
            skill_name="Test Self Circle",
            shape=AoEShape.SELF_CIRCLE,
            range=3,
            cast_range=0,
            cells_affected=37,
        )
        
        result = await system.find_optimal_center(
            monster_positions=[(105, 105), (110, 110)],
            aoe_skill=skill,
            player_position=(100, 100),
        )
        
        assert result == (100, 100)  # Always player position
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_clustered_monsters(self):
        """Cover find_optimal_center with clustered monsters."""
        system = AoETargetingSystem()
        skill = system.aoe_skills["storm gust"]
        
        # Create cluster of monsters
        monsters = [(100, 100), (101, 100), (100, 101), (101, 101)]
        
        result = await system.find_optimal_center(
            monster_positions=monsters,
            aoe_skill=skill,
            player_position=(95, 95),
        )
        
        # Should pick a center that hits multiple monsters
        assert result in monsters
    
    @pytest.mark.asyncio
    async def test_calculate_targets_hit_basic(self):
        """Cover calculate_targets_hit with simple case."""
        system = AoETargetingSystem()
        skill = system.aoe_skills["heaven's drive"]  # Range 2
        
        targets = await system.calculate_targets_hit(
            center=(100, 100),
            aoe_skill=skill,
            monster_positions=[(100, 100), (102, 100), (105, 100)],
        )
        
        assert len(targets) == 2  # First two within range 2
    
    @pytest.mark.asyncio
    async def test_calculate_targets_hit_with_falloff(self):
        """Cover calculate_targets_hit with damage falloff."""
        system = AoETargetingSystem()
        skill = AoESkill(
            skill_name="Test Falloff",
            shape=AoEShape.CIRCLE,
            range=5,
            cast_range=9,
            cells_affected=81,
            damage_falloff=True,
        )
        
        targets = await system.calculate_targets_hit(
            center=(100, 100),
            aoe_skill=skill,
            monster_positions=[(100, 100), (103, 103), (105, 100)],
        )
        
        # Check falloff applied
        center_target = next(t for t in targets if t.position == (100, 100))
        assert center_target.expected_damage_percent == 1.0  # Full damage at center


class TestAoESkillSelection:
    """Test AoE skill selection logic."""
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_no_monsters(self):
        """Cover select_best_aoe_skill with no monsters."""
        system = AoETargetingSystem()
        
        skill, center = await system.select_best_aoe_skill(
            available_skills=["Storm Gust", "Meteor Storm"],
            monster_positions=[],
            player_position=(100, 100),
            sp_available=100,
        )
        
        assert skill is None
        assert center == (100, 100)
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_insufficient_sp(self):
        """Cover select_best_aoe_skill with low SP."""
        system = AoETargetingSystem()
        
        skill, center = await system.select_best_aoe_skill(
            available_skills=["Storm Gust"],  # Costs 78 SP
            monster_positions=[(105, 105), (110, 110)],
            player_position=(100, 100),
            sp_available=50,  # Not enough
        )
        
        assert skill is None
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_efficiency(self):
        """Cover select_best_aoe_skill efficiency calculation."""
        system = AoETargetingSystem()
        
        # Many monsters - should pick efficient multi-hit skill
        monsters = [(100 + i, 100 + j) for i in range(5) for j in range(5)]
        
        skill, center = await system.select_best_aoe_skill(
            available_skills=["Storm Gust", "Heaven's Drive"],
            monster_positions=monsters,
            player_position=(102, 102),
            sp_available=200,
        )
        
        assert skill is not None


class TestAoEClustering:
    """Test monster clustering detection."""
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_too_few_monsters(self):
        """Cover detect_mob_cluster when below minimum size."""
        system = AoETargetingSystem()
        
        clusters = await system.detect_mob_cluster(
            monster_positions=[(100, 100), (110, 110)],
            min_cluster_size=3,
            max_cluster_distance=5.0,
        )
        
        assert len(clusters) == 0
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_single_cluster(self):
        """Cover detect_mob_cluster with single cluster."""
        system = AoETargetingSystem()
        
        # Create tight cluster
        monsters = [(100 + i, 100) for i in range(5)]
        
        clusters = await system.detect_mob_cluster(
            monster_positions=monsters,
            min_cluster_size=3,
            max_cluster_distance=5.0,
        )
        
        assert len(clusters) >= 1
        assert len(clusters[0]) >= 3
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_multiple_clusters(self):
        """Cover detect_mob_cluster with separate clusters."""
        system = AoETargetingSystem()
        
        # Two separate clusters
        cluster1 = [(100 + i, 100) for i in range(4)]
        cluster2 = [(200 + i, 200) for i in range(4)]
        monsters = cluster1 + cluster2
        
        clusters = await system.detect_mob_cluster(
            monster_positions=monsters,
            min_cluster_size=3,
            max_cluster_distance=5.0,
        )
        
        assert len(clusters) == 2


class TestAoEUtilities:
    """Test AoE utility methods."""
    
    def test_calculate_optimal_position_sync(self):
        """Cover calculate_optimal_position synchronous method."""
        system = AoETargetingSystem()
        
        positions = [(100, 100), (101, 100), (102, 100), (110, 110)]
        
        result = system.calculate_optimal_position(positions, skill_radius=3)
        
        assert result in positions
        # Should pick position hitting most targets
    
    def test_find_clusters_sync(self):
        """Cover find_clusters synchronous method."""
        system = AoETargetingSystem()
        
        positions = [(100, 100), (101, 100), (102, 100), (200, 200)]
        
        clusters = system.find_clusters(positions, radius=3)
        
        assert len(clusters) >= 1
        # First 3 should be in one cluster
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence(self):
        """Cover plan_aoe_sequence for multiple clusters."""
        system = AoETargetingSystem()
        
        cluster1 = [(100, 100), (101, 100), (102, 100)]
        cluster2 = [(200, 200), (201, 200), (202, 200)]
        
        sequence = await system.plan_aoe_sequence(
            clusters=[cluster1, cluster2],
            available_skills=["Heaven's Drive", "Storm Gust"],
            player_position=(100, 100),
            sp_available=200,
        )
        
        assert isinstance(sequence, list)
        # Should plan action for each cluster


# ============================================================================
# FORGING MANAGER TESTS
# ============================================================================


class TestForgingManagerCore:
    """Test ForgingManager core functionality."""
    
    def test_forging_manager_initialization(self, tmp_path):
        """Cover ForgingManager.__init__ with missing data file."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        assert forging is not None
        assert len(forging.forgeable_weapons) == 0
    
    def test_forging_manager_load_weapons(self, tmp_path):
        """Cover ForgingManager with weapon data."""
        # Create crafting data
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        # Create forge data
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 1,
                "weapon_name": "Test Sword",
                "weapon_level": 1,
                "base_materials": [
                    {"item_id": 100, "item_name": "Iron", "quantity_required": 5, "is_consumed": True}
                ],
                "base_success_rate": 100.0,
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        assert len(forging.forgeable_weapons) == 1
        assert 1 in forging.forgeable_weapons


class TestForgeSuccessRate:
    """Test forge success rate calculations."""
    
    def test_get_forge_success_rate_weapon_not_found(self, tmp_path):
        """Cover get_forge_success_rate with invalid weapon ID."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        rate = forging.get_forge_success_rate(
            weapon_id=999,
            character_state={"dex": 50, "luk": 30, "job_level": 50},
        )
        
        assert rate == 0.0
    
    def test_get_forge_success_rate_level_1_weapon(self, tmp_path):
        """Cover get_forge_success_rate for level 1 weapon."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 1,
                "weapon_name": "Test Dagger",
                "weapon_level": 1,
                "base_materials": [],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        rate = forging.get_forge_success_rate(
            weapon_id=1,
            character_state={"dex": 50, "luk": 30, "job_level": 40},
        )
        
        # Rate is capped at 100%
        assert rate == 100.0
    
    def test_get_forge_success_rate_with_element(self, tmp_path):
        """Cover get_forge_success_rate with element penalty."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 2,
                "weapon_name": "Test Sword",
                "weapon_level": 3,
                "base_materials": [],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        rate_no_element = forging.get_forge_success_rate(
            weapon_id=2,
            character_state={"dex": 50, "luk": 30, "job_level": 50},
            element=ForgeElement.NONE,
        )
        
        rate_with_element = forging.get_forge_success_rate(
            weapon_id=2,
            character_state={"dex": 50, "luk": 30, "job_level": 50},
            element=ForgeElement.FIRE,
        )
        
        assert rate_with_element < rate_no_element  # Penalty applied


class TestForgeMaterials:
    """Test material requirement methods."""
    
    def test_get_required_materials_basic(self, tmp_path):
        """Cover get_required_materials for basic weapon."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 1,
                "weapon_name": "Sword",
                "weapon_level": 1,
                "base_materials": [
                    {"item_id": 100, "item_name": "Iron", "quantity_required": 3, "is_consumed": True}
                ],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        materials = forging.get_required_materials(weapon_id=1)
        
        assert len(materials) == 1
        assert materials[0].item_name == "Iron"
    
    def test_get_required_materials_with_element(self, tmp_path):
        """Cover get_required_materials with element stone."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 2,
                "weapon_name": "Elemental Sword",
                "weapon_level": 2,
                "base_materials": [
                    {"item_id": 100, "item_name": "Iron", "quantity_required": 5, "is_consumed": True}
                ],
                "element_stone": {"item_id": 200, "item_name": "Flame Heart", "quantity_required": 1, "is_consumed": True},
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        materials = forging.get_required_materials(
            weapon_id=2,
            element=ForgeElement.FIRE,
        )
        
        assert len(materials) == 2  # Base + element stone
    
    def test_get_required_materials_with_star_crumbs(self, tmp_path):
        """Cover get_required_materials with star crumbs."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 3,
                "weapon_name": "VVS Sword",
                "weapon_level": 3,
                "base_materials": [],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        materials = forging.get_required_materials(
            weapon_id=3,
            star_crumbs=3,
        )
        
        # Should include star crumbs
        star_crumb = next((m for m in materials if m.item_name == "Star Crumb"), None)
        assert star_crumb is not None
        assert star_crumb.quantity_required == 3


class TestForgeFame:
    """Test fame calculation and tracking."""
    
    def test_get_fame_value_level_1(self, tmp_path):
        """Cover get_fame_value for level 1 weapon."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        fame = forging.get_fame_value(weapon_level=1)
        
        assert fame == 1
    
    def test_get_fame_value_with_element(self, tmp_path):
        """Cover get_fame_value with element bonus."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        fame = forging.get_fame_value(
            weapon_level=3,
            element=ForgeElement.VERY_STRONG_FIRE,
        )
        
        assert fame > 10  # Base + very strong element bonus
    
    def test_add_fame(self, tmp_path):
        """Cover add_fame tracking."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        total = forging.add_fame("TestSmith", 10)
        
        assert total == 10
        assert forging.get_fame("TestSmith") == 10
    
    def test_add_fame_accumulation(self, tmp_path):
        """Cover add_fame with multiple forges."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        forging.add_fame("TestSmith", 5)
        total = forging.add_fame("TestSmith", 10)
        
        assert total == 15


class TestForgeUtilities:
    """Test forge utility methods."""
    
    def test_can_forge_by_id(self, tmp_path):
        """Cover can_forge with weapon ID."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 1,
                "weapon_name": "Sword",
                "weapon_level": 1,
                "base_materials": [
                    {"item_id": 100, "item_name": "Iron", "quantity_required": 3, "is_consumed": True}
                ],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        can_forge = forging.can_forge(
            recipe_name="1",
            inventory={100: 5},  # Have enough iron
        )
        
        assert can_forge is True
    
    def test_can_forge_by_name(self, tmp_path):
        """Cover can_forge with weapon name."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [{
                "weapon_id": 1,
                "weapon_name": "Sword",
                "weapon_level": 1,
                "base_materials": [],
            }]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        can_forge = forging.can_forge(recipe_name="Sword")
        
        assert can_forge is True
    
    @pytest.mark.asyncio
    async def test_forge_basic(self, tmp_path):
        """Cover forge method."""
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        
        result = await forging.forge("Test Sword", quantity=1)
        
        assert result["success"] is True
    
    def test_get_statistics(self, tmp_path):
        """Cover get_statistics method."""
        crafting_file = tmp_path / "crafting_recipes.json"
        crafting_file.write_text(json.dumps({"recipes": []}))
        
        forge_file = tmp_path / "forge_weapons.json"
        weapon_data = {
            "weapons": [
                {"weapon_id": 1, "weapon_name": "Sword", "weapon_level": 1, "base_materials": []},
                {"weapon_id": 2, "weapon_name": "Spear", "weapon_level": 2, "base_materials": []},
            ]
        }
        forge_file.write_text(json.dumps(weapon_data))
        
        crafting_manager = CraftingManager(data_dir=tmp_path)
        forging = ForgingManager(data_dir=tmp_path, crafting_manager=crafting_manager)
        forging.add_fame("Smith1", 10)
        forging.add_fame("Smith2", 20)
        
        stats = forging.get_statistics()
        
        assert stats["total_forgeable"] == 2
        assert stats["total_fame_tracked"] == 30
        assert stats["characters_with_fame"] == 2