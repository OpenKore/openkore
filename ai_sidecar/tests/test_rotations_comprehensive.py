"""
Comprehensive tests for jobs/rotations.py to achieve 90%+ coverage.

Tests skill rotation engine, condition evaluation, cooldown management,
combo tracking, and priority-based skill selection.
"""

import pytest
import time
import json
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.jobs.rotations import (
    SkillRotationEngine,
    SkillPriority,
    SkillCondition,
    SkillRotationStep,
    SkillRotation
)


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test rotation data."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Sample skill rotations
    rotations_data = {
        "rotations": {
            "knight": {
                "farming": {
                    "steps": [
                        {
                            "skill_name": "Bowling Bash",
                            "priority": "high",
                            "conditions": {
                                "min_sp_percent": 20,
                                "min_targets_in_range": 2
                            },
                            "cast_time_ms": 500,
                            "after_cast_delay_ms": 1000,
                            "cooldown_ms": 0,
                            "comment": "AoE skill for multiple targets"
                        },
                        {
                            "skill_name": "Bash",
                            "priority": "medium",
                            "conditions": {
                                "min_sp_percent": 10
                            },
                            "cast_time_ms": 0,
                            "after_cast_delay_ms": 800,
                            "cooldown_ms": 0,
                            "comment": "Single target skill"
                        },
                        {
                            "skill_name": "Provoke",
                            "priority": "low",
                            "conditions": {
                                "min_sp_percent": 5
                            },
                            "cast_time_ms": 0,
                            "after_cast_delay_ms": 1000,
                            "cooldown_ms": 30000,
                            "comment": "Debuff for defense down"
                        }
                    ],
                    "opener": ["Provoke", "Bowling Bash"],
                    "finisher": ["Bash"],
                    "emergency": ["Heal"]
                },
                "boss": {
                    "steps": [
                        {
                            "skill_name": "Hundred Spear",
                            "priority": "critical",
                            "conditions": {
                                "min_hp_percent": 30,
                                "min_sp_percent": 40
                            },
                            "cast_time_ms": 1000,
                            "after_cast_delay_ms": 1500,
                            "cooldown_ms": 5000,
                            "comment": "High damage burst skill"
                        }
                    ],
                    "opener": ["Provoke", "Hundred Spear"],
                    "finisher": [],
                    "emergency": ["Heal"]
                }
            },
            "monk": {
                "farming": {
                    "steps": [
                        {
                            "skill_name": "Raging Thrust",
                            "priority": "high",
                            "conditions": {
                                "spirit_spheres": 5
                            },
                            "cast_time_ms": 500,
                            "after_cast_delay_ms": 1000,
                            "cooldown_ms": 0,
                            "comment": "Combo finisher"
                        },
                        {
                            "skill_name": "Triple Attack",
                            "priority": "medium",
                            "conditions": {},
                            "cast_time_ms": 0,
                            "after_cast_delay_ms": 800,
                            "cooldown_ms": 0,
                            "comment": "Basic attack"
                        }
                    ],
                    "opener": ["Call Spirit"],
                    "finisher": ["Raging Thrust"],
                    "emergency": ["Heal"]
                }
            }
        }
    }
    
    (data_dir / "skill_rotations.json").write_text(json.dumps(rotations_data))
    
    return data_dir


class TestSkillRotationEngineInit:
    """Test SkillRotationEngine initialization."""
    
    def test_init_loads_rotations(self, data_dir):
        """Test engine loads rotation data on init."""
        engine = SkillRotationEngine(data_dir)
        
        assert len(engine.rotations) > 0
        assert "knight" in engine.rotations
        assert "farming" in engine.rotations["knight"]
        
    def test_init_creates_empty_state(self, data_dir):
        """Test engine initializes empty state tracking."""
        engine = SkillRotationEngine(data_dir)
        
        assert isinstance(engine.active_cooldowns, dict)
        assert isinstance(engine.combo_state, dict)
        assert engine.last_skill_time == 0.0
        
    def test_init_handles_missing_file(self, tmp_path):
        """Test handles missing skill_rotations.json."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        
        engine = SkillRotationEngine(empty_dir)
        
        assert len(engine.rotations) == 0


class TestLoadRotations:
    """Test _load_rotations method."""
    
    def test_loads_multiple_jobs(self, data_dir):
        """Test loads rotations for multiple jobs."""
        engine = SkillRotationEngine(data_dir)
        
        assert "knight" in engine.rotations
        assert "monk" in engine.rotations
        
    def test_loads_multiple_situations(self, data_dir):
        """Test loads multiple rotation types per job."""
        engine = SkillRotationEngine(data_dir)
        
        assert "farming" in engine.rotations["knight"]
        assert "boss" in engine.rotations["knight"]
        
    def test_handles_malformed_data(self, tmp_path):
        """Test handles malformed JSON gracefully."""
        bad_dir = tmp_path / "bad"
        bad_dir.mkdir()
        
        (bad_dir / "skill_rotations.json").write_text("{invalid json")
        
        engine = SkillRotationEngine(bad_dir)
        assert len(engine.rotations) == 0


class TestGetNextSkill:
    """Test get_next_skill method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_returns_none_no_rotation(self, engine):
        """Test returns None when rotation doesn't exist."""
        result = engine.get_next_skill("unknown_job", "farming", {})
        
        assert result is None
        
    def test_selects_by_priority(self, engine):
        """Test selects highest priority eligible skill."""
        char_state = {
            "hp_percent": 100,
            "sp_percent": 50,
            "targets_in_range": 1
        }
        
        result = engine.get_next_skill("knight", "farming", char_state)
        
        # Should get Bash (medium priority) since Bowling Bash needs 2 targets
        assert result is not None
        assert result.skill_name == "Bash"
        
    def test_respects_cooldowns(self, engine):
        """Test skips skills on cooldown."""
        char_state = {"hp_percent": 100, "sp_percent": 50, "targets_in_range": 1}
        
        # Put Bash on cooldown
        engine.active_cooldowns["Bash"] = time.time() + 10
        
        result = engine.get_next_skill("knight", "farming", char_state)
        
        # Should get Provoke (low priority) since Bash is on cooldown
        assert result is not None
        assert result.skill_name != "Bash"
        
    def test_checks_conditions(self, engine):
        """Test only returns skills meeting conditions."""
        char_state = {
            "hp_percent": 100,
            "sp_percent": 5,  # Too low for most skills
            "targets_in_range": 1
        }
        
        result = engine.get_next_skill("knight", "farming", char_state)
        
        # Should get Provoke (needs 5% SP) or None
        if result:
            assert result.conditions.min_sp_percent <= 5
            
    def test_considers_combo_state(self, engine):
        """Test considers last skill for combos."""
        char_state = {"hp_percent": 100, "sp_percent": 100, "spirit_spheres": 5}
        
        engine.combo_state["monk"] = "Call Spirit"
        
        result = engine.get_next_skill("monk", "farming", char_state)
        
        assert result is not None


class TestGetEligibleSkillsByPriority:
    """Test _get_eligible_skills_by_priority method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_filters_by_priority(self, engine):
        """Test only returns skills of specified priority."""
        rotation = engine.rotations["knight"]["farming"]
        char_state = {"hp_percent": 100, "sp_percent": 100, "targets_in_range": 3}
        
        high_priority = engine._get_eligible_skills_by_priority(
            rotation.steps,
            SkillPriority.HIGH,
            char_state,
            None,
            None,
            time.time()
        )
        
        assert all(s.priority == SkillPriority.HIGH for s in high_priority)
        
    def test_excludes_cooldown_skills(self, engine):
        """Test excludes skills on cooldown."""
        rotation = engine.rotations["knight"]["farming"]
        char_state = {"hp_percent": 100, "sp_percent": 100}
        
        # Put a skill on cooldown
        engine.active_cooldowns["Provoke"] = time.time() + 10
        
        skills = engine._get_eligible_skills_by_priority(
            rotation.steps,
            SkillPriority.LOW,
            char_state,
            None,
            None,
            time.time()
        )
        
        assert all(s.skill_name != "Provoke" for s in skills)
        
    def test_checks_conditions(self, engine):
        """Test checks skill conditions."""
        rotation = engine.rotations["knight"]["farming"]
        char_state = {
            "hp_percent": 100,
            "sp_percent": 5,  # Too low for Bowling Bash
            "targets_in_range": 5
        }
        
        skills = engine._get_eligible_skills_by_priority(
            rotation.steps,
            SkillPriority.HIGH,
            char_state,
            None,
            None,
            time.time()
        )
        
        # Bowling Bash should be excluded (needs 20% SP)
        assert all(s.skill_name != "Bowling Bash" for s in skills)


class TestIsSkillReady:
    """Test _is_skill_ready method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_ready_when_no_cooldown(self, engine):
        """Test skill is ready when not on cooldown."""
        result = engine._is_skill_ready("Bash", time.time())
        
        assert result is True
        
    def test_not_ready_on_cooldown(self, engine):
        """Test skill is not ready when on cooldown."""
        current = time.time()
        engine.active_cooldowns["Bash"] = current + 5
        
        result = engine._is_skill_ready("Bash", current)
        
        assert result is False
        
    def test_ready_after_cooldown_expires(self, engine):
        """Test skill becomes ready after cooldown expires."""
        current = time.time()
        engine.active_cooldowns["Bash"] = current - 1  # Expired
        
        result = engine._is_skill_ready("Bash", current)
        
        assert result is True


class TestEvaluateCondition:
    """Test evaluate_condition method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_min_hp_percent(self, engine):
        """Test min HP percent condition."""
        condition = SkillCondition(min_hp_percent=50)
        
        assert engine.evaluate_condition(condition, {"hp_percent": 60}, None) is True
        assert engine.evaluate_condition(condition, {"hp_percent": 40}, None) is False
        
    def test_max_hp_percent(self, engine):
        """Test max HP percent condition."""
        condition = SkillCondition(max_hp_percent=50)
        
        assert engine.evaluate_condition(condition, {"hp_percent": 40}, None) is True
        assert engine.evaluate_condition(condition, {"hp_percent": 60}, None) is False
        
    def test_min_sp_percent(self, engine):
        """Test min SP percent condition."""
        condition = SkillCondition(min_sp_percent=30)
        
        assert engine.evaluate_condition(condition, {"sp_percent": 40}, None) is True
        assert engine.evaluate_condition(condition, {"sp_percent": 20}, None) is False
        
    def test_target_hp_percent(self, engine):
        """Test target HP percent condition."""
        condition = SkillCondition(target_hp_percent=50)
        
        assert engine.evaluate_condition(condition, {}, {"hp_percent": 40}) is True
        assert engine.evaluate_condition(condition, {}, {"hp_percent": 60}) is False
        assert engine.evaluate_condition(condition, {}, None) is False
        
    def test_target_count(self, engine):
        """Test target count condition."""
        condition = SkillCondition(target_count=3)
        
        assert engine.evaluate_condition(condition, {"targets_in_range": 5}, None) is True
        assert engine.evaluate_condition(condition, {"targets_in_range": 2}, None) is False
        
    def test_has_buff(self, engine):
        """Test has buff condition."""
        condition = SkillCondition(has_buff="Blessing")
        
        assert engine.evaluate_condition(condition, {"buffs": ["Blessing", "Agi Up"]}, None) is True
        assert engine.evaluate_condition(condition, {"buffs": ["Agi Up"]}, None) is False
        
    def test_missing_buff(self, engine):
        """Test missing buff condition."""
        condition = SkillCondition(missing_buff="Curse")
        
        assert engine.evaluate_condition(condition, {"buffs": ["Blessing"]}, None) is True
        assert engine.evaluate_condition(condition, {"buffs": ["Curse"]}, None) is False
        
    def test_combo_after(self, engine):
        """Test combo after condition."""
        condition = SkillCondition(combo_after="Skill A")
        
        assert engine.evaluate_condition(condition, {}, None, "Skill A") is True
        assert engine.evaluate_condition(condition, {}, None, "Skill B") is False
        
    def test_spirit_spheres(self, engine):
        """Test spirit spheres condition."""
        condition = SkillCondition(spirit_spheres=5)
        
        assert engine.evaluate_condition(condition, {"spirit_spheres": 5}, None) is True
        assert engine.evaluate_condition(condition, {"spirit_spheres": 3}, None) is False
        
    def test_min_targets_in_range(self, engine):
        """Test min targets in range condition."""
        condition = SkillCondition(min_targets_in_range=3)
        
        assert engine.evaluate_condition(condition, {"targets_in_range": 5}, None) is True
        assert engine.evaluate_condition(condition, {"targets_in_range": 2}, None) is False
        
    def test_all_conditions_must_pass(self, engine):
        """Test all conditions must be met."""
        condition = SkillCondition(
            min_hp_percent=50,
            min_sp_percent=30
        )
        
        # Both met
        assert engine.evaluate_condition(condition, {"hp_percent": 60, "sp_percent": 40}, None) is True
        
        # Only one met
        assert engine.evaluate_condition(condition, {"hp_percent": 60, "sp_percent": 20}, None) is False
        assert engine.evaluate_condition(condition, {"hp_percent": 40, "sp_percent": 40}, None) is False


class TestTrackSkillUsage:
    """Test track_skill_usage method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_tracks_cooldown(self, engine):
        """Test tracks skill cooldown."""
        before = time.time()
        engine.track_skill_usage("knight", "Bash", 5000)
        after = time.time()
        
        assert "Bash" in engine.active_cooldowns
        cooldown_end = engine.active_cooldowns["Bash"]
        
        # Cooldown should be ~5 seconds from now
        assert before + 4.9 <= cooldown_end <= after + 5.1
        
    def test_tracks_combo_state(self, engine):
        """Test updates combo state."""
        engine.track_skill_usage("knight", "Bash", 0)
        
        assert engine.combo_state["knight"] == "Bash"
        
    def test_updates_last_skill_time(self, engine):
        """Test updates last skill time."""
        before = time.time()
        engine.track_skill_usage("knight", "Bash", 0)
        after = time.time()
        
        assert before <= engine.last_skill_time <= after


class TestGetRotationForSituation:
    """Test get_rotation_for_situation method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_returns_correct_rotation(self, engine):
        """Test returns rotation for job and situation."""
        rotation = engine.get_rotation_for_situation("knight", "farming")
        
        assert rotation is not None
        assert rotation.job_name == "knight"
        assert rotation.rotation_type == "farming"
        
    def test_case_insensitive_job_name(self, engine):
        """Test job name is case insensitive."""
        rotation = engine.get_rotation_for_situation("Knight", "farming")
        
        assert rotation is not None
        
    def test_returns_none_unknown_job(self, engine):
        """Test returns None for unknown job."""
        rotation = engine.get_rotation_for_situation("unknown", "farming")
        
        assert rotation is None
        
    def test_returns_none_unknown_situation(self, engine):
        """Test returns None for unknown situation."""
        rotation = engine.get_rotation_for_situation("knight", "unknown")
        
        assert rotation is None


class TestGetOpenerSequence:
    """Test get_opener_sequence method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_returns_opener_skills(self, engine):
        """Test returns opener sequence."""
        opener = engine.get_opener_sequence("knight", "farming")
        
        assert isinstance(opener, list)
        assert len(opener) > 0
        assert "Provoke" in opener
        
    def test_returns_empty_no_rotation(self, engine):
        """Test returns empty list when rotation not found."""
        opener = engine.get_opener_sequence("unknown", "farming")
        
        assert opener == []


class TestGetEmergencySkills:
    """Test get_emergency_skills method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_returns_emergency_skills(self, engine):
        """Test returns emergency skill list."""
        emergency = engine.get_emergency_skills("knight", "farming")
        
        assert isinstance(emergency, list)
        assert "Heal" in emergency
        
    def test_returns_empty_no_rotation(self, engine):
        """Test returns empty list when rotation not found."""
        emergency = engine.get_emergency_skills("unknown", "farming")
        
        assert emergency == []


class TestResetComboState:
    """Test reset_combo_state method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_resets_specific_job(self, engine):
        """Test resets combo state for specific job."""
        engine.combo_state["knight"] = "Bash"
        engine.combo_state["monk"] = "Triple Attack"
        
        engine.reset_combo_state("knight")
        
        assert "knight" not in engine.combo_state
        assert "monk" in engine.combo_state
        
    def test_resets_all_jobs(self, engine):
        """Test resets all combo states."""
        engine.combo_state["knight"] = "Bash"
        engine.combo_state["monk"] = "Triple Attack"
        
        engine.reset_combo_state()
        
        assert len(engine.combo_state) == 0


class TestClearCooldowns:
    """Test clear_cooldowns method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_clears_all_cooldowns(self, engine):
        """Test clears all cooldowns."""
        engine.active_cooldowns["Bash"] = time.time() + 10
        engine.active_cooldowns["Provoke"] = time.time() + 20
        
        engine.clear_cooldowns()
        
        assert len(engine.active_cooldowns) == 0


class TestGetActiveCooldowns:
    """Test get_active_cooldowns method."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_returns_only_active_cooldowns(self, engine):
        """Test returns only skills with remaining cooldown."""
        current = time.time()
        
        engine.active_cooldowns["Bash"] = current + 5  # Active
        engine.active_cooldowns["Provoke"] = current - 1  # Expired
        
        active = engine.get_active_cooldowns()
        
        assert "Bash" in active
        assert "Provoke" not in active
        
    def test_returns_remaining_time(self, engine):
        """Test returns remaining cooldown time."""
        current = time.time()
        engine.active_cooldowns["Bash"] = current + 5
        
        active = engine.get_active_cooldowns()
        
        # Should be approximately 5 seconds
        assert 4.9 <= active["Bash"] <= 5.1


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.fixture
    def engine(self, data_dir):
        return SkillRotationEngine(data_dir)
    
    def test_empty_character_state(self, engine):
        """Test handles empty character state."""
        result = engine.get_next_skill("knight", "farming", {})
        
        # Should not crash, may or may not return skill
        assert result is None or isinstance(result, SkillRotationStep)
        
    def test_missing_state_fields(self, engine):
        """Test handles missing state fields gracefully."""
        condition = SkillCondition(min_hp_percent=50)
        
        # Missing hp_percent field - should use 100 as default
        result = engine.evaluate_condition(condition, {}, None)
        
        # Since we check if hp_percent < min, and default would be 100, should be True
        assert result is True
        
    def test_zero_cooldown_skill(self, engine):
        """Test tracks skill with zero cooldown."""
        engine.track_skill_usage("knight", "Bash", 0)
        
        # Should not add to cooldowns (or add with time = now)
        assert "Bash" not in engine.active_cooldowns or engine._is_skill_ready("Bash", time.time())