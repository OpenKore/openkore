"""
Comprehensive tests for skill combo system - Batch 4.

Tests combo execution, timing, interruption handling,
and adaptive selection.
"""

from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

import pytest

from ai_sidecar.combat.combos import (
    ComboState,
    ComboStep,
    SkillCombo,
    SkillComboEngine,
)


@pytest.fixture
def combo_engine():
    """Create SkillComboEngine with defaults."""
    return SkillComboEngine()


@pytest.fixture
def test_combo():
    """Create test combo."""
    return SkillCombo(
        combo_id="test_combo",
        combo_name="Test Combo",
        job_class="test_job",
        steps=[
            ComboStep(
                skill_name="Skill1",
                skill_level=5,
                delay_after_ms=500,
                sp_cost=20,
            ),
            ComboStep(
                skill_name="Skill2",
                skill_level=10,
                delay_after_ms=1000,
                sp_cost=40,
                requires_hit=True,
            ),
        ],
        min_sp=60,
        total_duration_ms=2500,
        dps_multiplier=2.0,
        pve_rating=8,
        pvp_rating=6,
    )


class TestComboEngineInit:
    """Test SkillComboEngine initialization."""
    
    def test_init_default_combos(self):
        """Test initialization with default combos."""
        engine = SkillComboEngine()
        
        assert len(engine.combos) > 0
        assert "assassin_cross" in engine.combos or "lord_knight" in engine.combos
    
    def test_init_missing_file(self, tmp_path):
        """Test initialization with missing file."""
        engine = SkillComboEngine(data_dir=tmp_path / "nonexistent")
        
        # Should fall back to defaults
        assert len(engine.combos) > 0


class TestComboModel:
    """Test SkillCombo model."""
    
    def test_combo_total_sp_cost(self, test_combo):
        """Test total SP cost calculation."""
        total = test_combo.total_sp_cost
        
        assert total == 60  # 20 + 40


class TestComboStateModel:
    """Test ComboState model."""
    
    def test_combo_state_creation(self):
        """Test creating combo state."""
        state = ComboState(
            combo_id="test",
            current_step=0,
        )
        
        assert state.combo_id == "test"
        assert state.current_step == 0
    
    def test_combo_state_time_in_combo(self):
        """Test time in combo calculation."""
        state = ComboState(
            combo_id="test",
            started_at=datetime.now() - timedelta(seconds=2),
        )
        
        time_ms = state.time_in_combo_ms
        
        assert time_ms >= 1900  # ~2 seconds


class TestAvailableCombos:
    """Test getting available combos."""
    
    @pytest.mark.asyncio
    async def test_get_available_combos_sufficient_sp(self, combo_engine, test_combo):
        """Test getting combos with sufficient SP."""
        combo_engine.combos["test_job"] = [test_combo]
        
        available = await combo_engine.get_available_combos(
            job_class="test_job",
            sp_current=100,
            active_buffs=[],
        )
        
        assert len(available) == 1
        assert available[0].combo_id == "test_combo"
    
    @pytest.mark.asyncio
    async def test_get_available_combos_insufficient_sp(self, combo_engine, test_combo):
        """Test getting combos with insufficient SP."""
        combo_engine.combos["test_job"] = [test_combo]
        
        available = await combo_engine.get_available_combos(
            job_class="test_job",
            sp_current=30,  # Less than min_sp (60)
            active_buffs=[],
        )
        
        assert len(available) == 0
    
    @pytest.mark.asyncio
    async def test_get_available_combos_wrong_weapon(self, combo_engine):
        """Test combo filtering by weapon."""
        weapon_combo = SkillCombo(
            combo_id="weapon_specific",
            combo_name="Weapon Combo",
            job_class="test_job",
            steps=[ComboStep(skill_name="Skill", sp_cost=10)],
            required_weapon="katar",
            min_sp=10,
        )
        combo_engine.combos["test_job"] = [weapon_combo]
        
        available = await combo_engine.get_available_combos(
            job_class="test_job",
            sp_current=100,
            active_buffs=[],
            weapon_type="sword",  # Wrong weapon
        )
        
        assert len(available) == 0
    
    @pytest.mark.asyncio
    async def test_get_available_combos_missing_buffs(self, combo_engine):
        """Test combo filtering by required buffs."""
        buff_combo = SkillCombo(
            combo_id="buff_specific",
            combo_name="Buff Combo",
            job_class="test_job",
            steps=[ComboStep(skill_name="Skill", sp_cost=10)],
            required_buffs=["Concentration"],
            min_sp=10,
        )
        combo_engine.combos["test_job"] = [buff_combo]
        
        available = await combo_engine.get_available_combos(
            job_class="test_job",
            sp_current=100,
            active_buffs=[],  # Missing required buff
        )
        
        assert len(available) == 0


class TestOptimalComboSelection:
    """Test optimal combo selection."""
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_pve(self, combo_engine):
        """Test PvE combo selection."""
        combos = [
            SkillCombo(
                combo_id="pve_strong",
                combo_name="PvE Strong",
                job_class="test",
                steps=[ComboStep(skill_name="S1", sp_cost=20)],
                min_sp=20,
                pve_rating=9,
                pvp_rating=3,
            ),
            SkillCombo(
                combo_id="pvp_strong",
                combo_name="PvP Strong",
                job_class="test",
                steps=[ComboStep(skill_name="S2", sp_cost=20)],
                min_sp=20,
                pve_rating=4,
                pvp_rating=9,
            ),
        ]
        
        optimal = await combo_engine.select_optimal_combo(
            combos,
            situation="pve",
            sp_available=100,
        )
        
        assert optimal.combo_id == "pve_strong"
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_pvp(self, combo_engine):
        """Test PvP combo selection."""
        combos = [
            SkillCombo(
                combo_id="pve_combo",
                combo_name="PvE",
                job_class="test",
                steps=[ComboStep(skill_name="S1", sp_cost=20)],
                min_sp=20,
                pve_rating=9,
                pvp_rating=3,
            ),
            SkillCombo(
                combo_id="pvp_combo",
                combo_name="PvP",
                job_class="test",
                steps=[ComboStep(skill_name="S2", sp_cost=20)],
                min_sp=20,
                pve_rating=4,
                pvp_rating=9,
            ),
        ]
        
        optimal = await combo_engine.select_optimal_combo(
            combos,
            situation="pvp",
            sp_available=100,
        )
        
        assert optimal.combo_id == "pvp_combo"
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_aoe(self, combo_engine):
        """Test AoE combo selection for multiple targets."""
        combos = [
            SkillCombo(
                combo_id="single_target",
                combo_name="Single",
                job_class="test",
                steps=[ComboStep(skill_name="S1", sp_cost=20)],
                min_sp=20,
                pve_rating=8,
                aoe_capable=False,
            ),
            SkillCombo(
                combo_id="aoe_combo",
                combo_name="AoE",
                job_class="test",
                steps=[ComboStep(skill_name="S2", sp_cost=30)],
                min_sp=30,
                pve_rating=7,
                aoe_capable=True,
            ),
        ]
        
        optimal = await combo_engine.select_optimal_combo(
            combos,
            situation="pve",
            target_count=5,  # Multiple targets
            sp_available=100,
        )
        
        # Should prefer AoE
        assert optimal.combo_id == "aoe_combo"
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_insufficient_sp(self, combo_engine):
        """Test combo selection with insufficient SP."""
        combos = [
            SkillCombo(
                combo_id="expensive",
                combo_name="Expensive",
                job_class="test",
                steps=[ComboStep(skill_name="S1", sp_cost=100)],
                min_sp=100,
            ),
        ]
        
        optimal = await combo_engine.select_optimal_combo(
            combos,
            situation="pve",
            sp_available=50,  # Not enough SP
        )
        
        assert optimal is None


class TestComboExecution:
    """Test combo execution flow."""
    
    @pytest.mark.asyncio
    async def test_start_combo(self, combo_engine, test_combo):
        """Test starting a combo."""
        combo_engine.combos["test_job"] = [test_combo]
        
        state = await combo_engine.start_combo("test_combo")
        
        assert state is not None
        assert state.combo_id == "test_combo"
        assert state.current_step == 0
        assert combo_engine.current_combo is not None
    
    @pytest.mark.asyncio
    async def test_start_nonexistent_combo(self, combo_engine):
        """Test starting nonexistent combo."""
        state = await combo_engine.start_combo("nonexistent")
        
        assert state is None
    
    @pytest.mark.asyncio
    async def test_get_next_skill(self, combo_engine, test_combo):
        """Test getting next skill in combo."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        skill = await combo_engine.get_next_skill()
        
        assert skill is not None
        assert skill.skill_name == "Skill1"
    
    @pytest.mark.asyncio
    async def test_get_next_skill_combo_complete(self, combo_engine, test_combo):
        """Test getting next skill when combo complete."""
        combo_engine.combos["test_job"] = [test_combo]
        state = await combo_engine.start_combo("test_combo")
        state.current_step = 2  # Beyond last step
        
        skill = await combo_engine.get_next_skill()
        
        assert skill is None


class TestSkillResultRecording:
    """Test recording skill results."""
    
    @pytest.mark.asyncio
    async def test_record_skill_result_hit(self, combo_engine, test_combo):
        """Test recording successful hit."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        await combo_engine.record_skill_result(hit=True, damage=500)
        
        assert combo_engine.current_combo.hits_landed == 1
        assert combo_engine.current_combo.damage_dealt == 500
        assert combo_engine.current_combo.current_step == 1
    
    @pytest.mark.asyncio
    async def test_record_skill_result_miss_no_requirement(self, combo_engine, test_combo):
        """Test recording miss on non-required hit."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        # First skill doesn't require hit
        await combo_engine.record_skill_result(hit=False, damage=0)
        
        # Should continue
        assert combo_engine.current_combo is not None
        assert combo_engine.current_combo.current_step == 1
    
    @pytest.mark.asyncio
    async def test_record_skill_result_miss_required_hit(self, combo_engine, test_combo):
        """Test recording miss on required hit."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        # Advance to second skill (requires hit)
        combo_engine.current_combo.current_step = 1
        
        await combo_engine.record_skill_result(hit=False, damage=0)
        
        # Should abort
        assert combo_engine.current_combo is None


class TestComboAbortion:
    """Test combo abortion logic."""
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_target_died(self, combo_engine, test_combo):
        """Test aborting when target dies."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        should_abort = await combo_engine.should_abort_combo(
            current_hp_percent=1.0,
            target_died=True,
        )
        
        assert should_abort
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_critical_hp(self, combo_engine, test_combo):
        """Test aborting at critical HP."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        should_abort = await combo_engine.should_abort_combo(
            current_hp_percent=0.10,  # Critical HP
            target_died=False,
        )
        
        assert should_abort
    
    @pytest.mark.asyncio
    async def test_should_not_abort_combo_normal(self, combo_engine, test_combo):
        """Test not aborting in normal conditions."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        should_abort = await combo_engine.should_abort_combo(
            current_hp_percent=0.80,
            target_died=False,
        )
        
        assert not should_abort
    
    @pytest.mark.asyncio
    async def test_abort_combo(self, combo_engine, test_combo):
        """Test manually aborting combo."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        await combo_engine.abort_combo()
        
        assert combo_engine.current_combo is None
        assert combo_engine._active_combo_def is None


class TestComboCompletion:
    """Test combo completion."""
    
    @pytest.mark.asyncio
    async def test_finish_combo(self, combo_engine, test_combo):
        """Test finishing a combo."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        # Execute all steps
        await combo_engine.record_skill_result(True, 300)
        await combo_engine.record_skill_result(True, 400)
        
        stats = await combo_engine.finish_combo()
        
        assert stats["completed"] is True
        assert stats["steps_executed"] == 2
        assert stats["hits_landed"] == 2
        assert stats["damage_dealt"] == 700
    
    @pytest.mark.asyncio
    async def test_finish_combo_incomplete(self, combo_engine, test_combo):
        """Test finishing incomplete combo."""
        combo_engine.combos["test_job"] = [test_combo]
        await combo_engine.start_combo("test_combo")
        
        # Only execute first step
        await combo_engine.record_skill_result(True, 300)
        
        stats = await combo_engine.finish_combo()
        
        assert stats["completed"] is False
        assert stats["steps_executed"] == 1


class TestComboStepModel:
    """Test ComboStep model."""
    
    def test_combo_step_creation(self):
        """Test creating combo step."""
        step = ComboStep(
            skill_name="Test Skill",
            skill_level=10,
            delay_after_ms=1000,
            requires_hit=True,
            sp_cost=50,
        )
        
        assert step.skill_name == "Test Skill"
        assert step.requires_hit is True