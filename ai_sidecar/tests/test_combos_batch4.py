"""
Comprehensive tests for combat/combos.py - BATCH 4.
Target: 95%+ coverage (currently 85.57%, 23 uncovered lines).
"""

import pytest
from pathlib import Path
from ai_sidecar.combat.combos import (
    SkillComboEngine,
    SkillCombo,
    ComboStep,
    ComboState,
)


class TestSkillComboEngine:
    """Test SkillComboEngine functionality."""
    
    @pytest.fixture
    def engine(self):
        """Create engine with default combos."""
        return SkillComboEngine()
    
    @pytest.fixture
    def sinx_combo(self):
        """Sample Assassin Cross combo."""
        return SkillCombo(
            combo_id="test_sinx_combo",
            combo_name="Test SinX Combo",
            job_class="assassin_cross",
            steps=[
                ComboStep(
                    skill_name="Enchant Deadly Poison",
                    skill_level=5,
                    delay_after_ms=500,
                    sp_cost=40,
                ),
                ComboStep(
                    skill_name="Sonic Blow",
                    skill_level=10,
                    delay_after_ms=1000,
                    sp_cost=50,
                    requires_hit=True,
                ),
            ],
            min_sp=90,
            required_weapon="katar",
            total_duration_ms=2500,
            dps_multiplier=2.0,
            pve_rating=8,
            pvp_rating=9,
        )
    
    def test_initialization(self, engine):
        """Test engine initialization."""
        assert engine.current_combo is None
        assert engine._active_combo_def is None
        assert len(engine.combos) > 0  # Should have default combos
    
    def test_default_combos_loaded(self, engine):
        """Test that default combos are loaded."""
        assert "assassin_cross" in engine.combos
        assert "lord_knight" in engine.combos
        assert "high_wizard" in engine.combos
    
    @pytest.mark.asyncio
    async def test_get_available_combos_basic(self, engine):
        """Test getting available combos."""
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=150,
            active_buffs=[],
            weapon_type="katar",
        )
        
        assert len(combos) > 0
        assert all(c.job_class == "assassin_cross" for c in combos)
    
    @pytest.mark.asyncio
    async def test_get_available_combos_insufficient_sp(self, engine):
        """Test filtering by SP requirement."""
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=10,  # Too low
            active_buffs=[],
        )
        
        assert len(combos) == 0
    
    @pytest.mark.asyncio
    async def test_get_available_combos_wrong_weapon(self, engine):
        """Test filtering by weapon requirement."""
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=200,
            active_buffs=[],
            weapon_type="sword",  # Wrong weapon
        )
        
        # Should filter out katar-required combos
        assert len(combos) == 0 or all(
            c.required_weapon != "katar" for c in combos
        )
    
    @pytest.mark.asyncio
    async def test_get_available_combos_missing_buffs(self, engine):
        """Test filtering by buff requirements."""
        # Create combo with buff requirement
        combo = SkillCombo(
            combo_id="buff_combo",
            combo_name="Buff Test",
            job_class="test_class",
            steps=[ComboStep(skill_name="test", sp_cost=10)],
            required_buffs=["blessing", "increase_agi"],
        )
        engine.combos["test_class"] = [combo]
        
        # Without required buffs
        combos = await engine.get_available_combos(
            job_class="test_class",
            sp_current=100,
            active_buffs=["blessing"],  # Missing one buff
        )
        
        assert len(combos) == 0
        
        # With all required buffs
        combos = await engine.get_available_combos(
            job_class="test_class",
            sp_current=100,
            active_buffs=["blessing", "increase_agi"],
        )
        
        assert len(combos) == 1
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_pve(self, engine):
        """Test optimal combo selection for PvE."""
        combos = await engine.get_available_combos(
            job_class="high_wizard",
            sp_current=100,
            active_buffs=[],
        )
        
        if combos:
            best = await engine.select_optimal_combo(
                available_combos=combos,
                situation="pve",
                target_count=1,
                sp_available=100,
            )
            
            assert best is not None
            assert best.pve_rating > 0
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_pvp(self, engine):
        """Test optimal combo selection for PvP."""
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=150,
            active_buffs=[],
            weapon_type="katar",
        )
        
        if combos:
            best = await engine.select_optimal_combo(
                available_combos=combos,
                situation="pvp",
                target_count=1,
                sp_available=150,
            )
            
            assert best is not None
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_aoe(self, engine):
        """Test optimal combo selection for multiple targets."""
        combos = await engine.get_available_combos(
            job_class="high_wizard",
            sp_current=100,
            active_buffs=[],
        )
        
        if combos:
            best = await engine.select_optimal_combo(
                available_combos=combos,
                situation="pve",
                target_count=5,  # Multiple targets
                sp_available=100,
            )
            
            # Should prefer AoE combo if available
            assert best is not None
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_empty(self, engine):
        """Test optimal combo with empty list."""
        best = await engine.select_optimal_combo(
            available_combos=[],
            situation="pve",
            target_count=1,
            sp_available=100,
        )
        
        assert best is None
    
    @pytest.mark.asyncio
    async def test_select_optimal_combo_insufficient_sp(self, engine):
        """Test optimal combo with insufficient SP."""
        combos = await engine.get_available_combos(
            job_class="assassin_cross",
            sp_current=200,
            active_buffs=[],
            weapon_type="katar",
        )
        
        best = await engine.select_optimal_combo(
            available_combos=combos,
            situation="pve",
            target_count=1,
            sp_available=10,  # Too low
        )
        
        assert best is None
    
    def test_get_next_combo_skill_no_history(self, engine):
        """Test getting next skill with no history."""
        next_skill = engine.get_next_combo_skill([])
        assert next_skill is None
    
    def test_get_next_combo_skill_valid(self, engine, sinx_combo):
        """Test getting next skill in combo chain."""
        engine.combos["assassin_cross"] = [sinx_combo]
        
        # After first skill
        next_skill = engine.get_next_combo_skill(["Enchant Deadly Poison"])
        assert next_skill == "Sonic Blow"
    
    def test_get_next_combo_skill_end_of_combo(self, engine, sinx_combo):
        """Test getting next skill at end of combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        
        # After last skill
        next_skill = engine.get_next_combo_skill(["Sonic Blow"])
        assert next_skill is None
    
    def test_check_combo_found(self, engine, sinx_combo):
        """Test checking if skill is part of combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        
        combo_info = engine.check_combo("Sonic Blow")
        
        assert combo_info is not None
        assert combo_info["combo_id"] == sinx_combo.combo_id
        assert combo_info["skill_name"] == "Sonic Blow"
    
    def test_check_combo_not_found(self, engine):
        """Test checking skill not in any combo."""
        combo_info = engine.check_combo("Unknown Skill")
        assert combo_info is None
    
    def test_check_combo_starter(self, engine, sinx_combo):
        """Test checking if skill is combo starter."""
        engine.combos["assassin_cross"] = [sinx_combo]
        
        combo_info = engine.check_combo("Enchant Deadly Poison")
        
        assert combo_info is not None
        assert combo_info["is_starter"] is True
    
    @pytest.mark.asyncio
    async def test_start_combo(self, engine, sinx_combo):
        """Test starting a combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        
        state = await engine.start_combo(sinx_combo.combo_id)
        
        assert state is not None
        assert state.combo_id == sinx_combo.combo_id
        assert state.current_step == 0
        assert engine.current_combo == state
        assert engine._active_combo_def == sinx_combo
    
    @pytest.mark.asyncio
    async def test_start_combo_invalid_id(self, engine):
        """Test starting combo with invalid ID."""
        state = await engine.start_combo("nonexistent_combo")
        assert state is None
    
    @pytest.mark.asyncio
    async def test_get_next_skill(self, engine, sinx_combo):
        """Test getting next skill in sequence."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        # Get first skill
        skill = await engine.get_next_skill()
        assert skill is not None
        assert skill.skill_name == "Enchant Deadly Poison"
    
    @pytest.mark.asyncio
    async def test_get_next_skill_no_combo(self, engine):
        """Test getting next skill with no active combo."""
        skill = await engine.get_next_skill()
        assert skill is None
    
    @pytest.mark.asyncio
    async def test_get_next_skill_combo_complete(self, engine, sinx_combo):
        """Test getting next skill when combo is complete."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        # Advance to end
        engine.current_combo.current_step = len(sinx_combo.steps)
        
        skill = await engine.get_next_skill()
        assert skill is None
    
    @pytest.mark.asyncio
    async def test_record_skill_result_hit(self, engine, sinx_combo):
        """Test recording successful skill hit."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        await engine.record_skill_result(hit=True, damage=500)
        
        assert engine.current_combo.current_step == 1
        assert engine.current_combo.hits_landed == 1
        assert engine.current_combo.damage_dealt == 500
    
    @pytest.mark.asyncio
    async def test_record_skill_result_miss_required(self, engine, sinx_combo):
        """Test recording miss on skill that requires hit."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        # Advance to skill that requires hit
        engine.current_combo.current_step = 1
        
        await engine.record_skill_result(hit=False, damage=0)
        
        # Combo should be aborted
        assert engine.current_combo is None
    
    @pytest.mark.asyncio
    async def test_record_skill_result_miss_optional(self, engine, sinx_combo):
        """Test recording miss on skill that doesn't require hit."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        await engine.record_skill_result(hit=False, damage=0)
        
        # Combo should continue (first skill doesn't require hit)
        assert engine.current_combo is not None
        assert engine.current_combo.current_step == 1
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_target_died(self, engine, sinx_combo):
        """Test aborting combo when target dies."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        should_abort = await engine.should_abort_combo(
            current_hp_percent=1.0,
            target_died=True,
        )
        
        assert should_abort is True
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_low_hp(self, engine, sinx_combo):
        """Test aborting combo on critical HP."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        should_abort = await engine.should_abort_combo(
            current_hp_percent=0.1,  # 10% HP
            target_died=False,
        )
        
        assert should_abort is True
    
    @pytest.mark.asyncio
    async def test_should_abort_combo_healthy(self, engine, sinx_combo):
        """Test not aborting combo when healthy."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        should_abort = await engine.should_abort_combo(
            current_hp_percent=0.8,
            target_died=False,
        )
        
        assert should_abort is False
    
    @pytest.mark.asyncio
    async def test_abort_combo(self, engine, sinx_combo):
        """Test manually aborting combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        assert engine.current_combo is not None
        
        await engine.abort_combo()
        
        assert engine.current_combo is None
        assert engine._active_combo_def is None
    
    @pytest.mark.asyncio
    async def test_finish_combo(self, engine, sinx_combo):
        """Test finishing a combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        # Execute combo steps
        await engine.record_skill_result(hit=True, damage=300)
        await engine.record_skill_result(hit=True, damage=500)
        
        stats = await engine.finish_combo()
        
        assert stats["combo_id"] == sinx_combo.combo_id
        assert stats["completed"] is True
        assert stats["steps_executed"] == 2
        assert stats["hits_landed"] == 2
        assert stats["damage_dealt"] == 800
        assert engine.current_combo is None
    
    @pytest.mark.asyncio
    async def test_finish_combo_incomplete(self, engine, sinx_combo):
        """Test finishing incomplete combo."""
        engine.combos["assassin_cross"] = [sinx_combo]
        await engine.start_combo(sinx_combo.combo_id)
        
        # Execute only one step
        await engine.record_skill_result(hit=True, damage=300)
        
        stats = await engine.finish_combo()
        
        assert stats["completed"] is False
        assert stats["steps_executed"] == 1
        assert stats["total_steps"] == 2
    
    @pytest.mark.asyncio
    async def test_finish_combo_no_active(self, engine):
        """Test finishing when no combo is active."""
        stats = await engine.finish_combo()
        assert stats == {}
    
    def test_combo_step_properties(self):
        """Test ComboStep model properties."""
        step = ComboStep(
            skill_name="Test Skill",
            skill_level=5,
            delay_after_ms=1000,
            requires_hit=True,
            sp_cost=30,
        )
        
        assert step.skill_name == "Test Skill"
        assert step.skill_level == 5
        assert step.delay_after_ms == 1000
        assert step.requires_hit is True
        assert step.sp_cost == 30
    
    def test_combo_total_sp_cost(self, sinx_combo):
        """Test calculating total SP cost."""
        assert sinx_combo.total_sp_cost == 90  # 40 + 50
    
    def test_combo_state_properties(self, sinx_combo):
        """Test ComboState properties."""
        state = ComboState(
            combo_id=sinx_combo.combo_id,
            current_step=1,
            hits_landed=2,
            damage_dealt=800,
        )
        
        assert state.combo_id == sinx_combo.combo_id
        assert state.current_step == 1
        assert state.hits_landed == 2
        assert state.damage_dealt == 800
        assert state.time_in_combo_ms >= 0
    
    def test_combo_state_age(self, sinx_combo):
        """Test ComboState time calculation."""
        state = ComboState(combo_id=sinx_combo.combo_id)
        
        import time
        time.sleep(0.1)
        
        assert state.time_in_combo_ms >= 100