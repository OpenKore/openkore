"""
Extended test coverage for runes.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 82-84, 124-162, 176-213, 242-262, 281-299, 329-332, 369-374, 387-400
- Rune loading, usage, cooldown tracking
- Point management
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open

from ai_sidecar.jobs.mechanics.runes import (
    RuneManager,
    RuneType,
    RuneStone,
    RuneCooldown,
)


class TestRuneExtendedCoverage:
    """Extended coverage for rune manager."""
    
    def test_load_rune_definitions_file_not_found(self):
        """Test loading rune definitions when file doesn't exist."""
        with patch.object(Path, "exists", return_value=False):
            manager = RuneManager(data_dir=Path("nonexistent"))
            
            assert len(manager.rune_stones) == 0
    
    def test_load_rune_definitions_invalid_json(self):
        """Test loading rune definitions with invalid JSON."""
        with patch("builtins.open", mock_open(read_data='invalid json{')):
            with patch.object(Path, "exists", return_value=True):
                manager = RuneManager(data_dir=Path("test_data"))
                
                assert len(manager.rune_stones) == 0
    
    def test_load_rune_definitions_with_valid_data(self):
        """Test loading rune definitions with valid data."""
        data = {
            "runes": {
                "rune_of_storm": {
                    "display_name": "Storm Rune",
                    "skill_id": 2001,
                    "cooldown_seconds": 60,
                    "duration_seconds": 10,
                    "sp_cost": 30,
                    "rune_points_cost": 2,
                    "effect_type": "offensive",
                    "is_aoe": True
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = RuneManager(data_dir=Path("test_data"))
                
                assert RuneType.RUNE_OF_STORM in manager.rune_stones
    
    def test_load_rune_definitions_unknown_rune_type(self):
        """Test loading with unknown rune type."""
        data = {
            "runes": {
                "unknown_rune": {
                    "display_name": "Unknown"
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = RuneManager(data_dir=Path("test_data"))
                
                # Unknown types should be skipped
                assert len(manager.rune_stones) == 0
    
    def test_use_rune_not_in_inventory(self):
        """Test using rune not in inventory."""
        manager = RuneManager()
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_use_rune_no_stones_left(self):
        """Test using rune when no stones left."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 0
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_use_rune_on_cooldown(self):
        """Test using rune on cooldown."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_use_rune_no_definition(self):
        """Test using rune without definition."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_use_rune_insufficient_points(self):
        """Test using rune without enough rune points."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 0
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_use_rune_success(self):
        """Test successfully using rune."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        result = manager.use_rune(RuneType.RUNE_OF_STORM)
        
        assert result is True
        assert manager.rune_inventory[RuneType.RUNE_OF_STORM] == 4
        assert manager.current_rune_points == 8
        assert RuneType.RUNE_OF_STORM in manager.rune_cooldowns
    
    def test_add_rune_stones(self):
        """Test adding rune stones to inventory."""
        manager = RuneManager()
        
        manager.add_rune_stones(RuneType.RUNE_OF_STORM, count=3)
        
        assert manager.rune_inventory[RuneType.RUNE_OF_STORM] == 3
    
    def test_add_rune_stones_increments(self):
        """Test adding stones increments existing count."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        
        manager.add_rune_stones(RuneType.RUNE_OF_STORM, count=3)
        
        assert manager.rune_inventory[RuneType.RUNE_OF_STORM] == 8
    
    def test_get_rune_count(self):
        """Test getting rune count."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_CRASH] = 7
        
        count = manager.get_rune_count(RuneType.RUNE_OF_CRASH)
        
        assert count == 7
    
    def test_get_rune_count_not_in_inventory(self):
        """Test getting count for rune not in inventory."""
        manager = RuneManager()
        
        count = manager.get_rune_count(RuneType.RUNE_OF_STORM)
        
        assert count == 0
    
    def test_is_rune_ready_no_cooldown(self):
        """Test rune ready when no cooldown."""
        manager = RuneManager()
        
        result = manager.is_rune_ready(RuneType.RUNE_OF_STORM)
        
        assert result is True
    
    def test_is_rune_ready_cooldown_expired(self):
        """Test rune ready when cooldown expired."""
        manager = RuneManager()
        
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=1
        )
        cooldown.used_at = datetime.now() - timedelta(seconds=10)
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = cooldown
        
        result = manager.is_rune_ready(RuneType.RUNE_OF_STORM)
        
        assert result is True
        # Should clean up cooldown
        assert RuneType.RUNE_OF_STORM not in manager.rune_cooldowns
    
    def test_is_rune_ready_still_on_cooldown(self):
        """Test rune not ready when still on cooldown."""
        manager = RuneManager()
        
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = cooldown
        
        result = manager.is_rune_ready(RuneType.RUNE_OF_STORM)
        
        assert result is False
    
    def test_get_rune_cooldown(self):
        """Test getting rune cooldown time."""
        manager = RuneManager()
        
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = cooldown
        
        remaining = manager.get_rune_cooldown(RuneType.RUNE_OF_STORM)
        
        assert remaining > 0
        assert remaining <= 60
    
    def test_get_rune_cooldown_no_cooldown(self):
        """Test getting cooldown when rune ready."""
        manager = RuneManager()
        
        remaining = manager.get_rune_cooldown(RuneType.RUNE_OF_STORM)
        
        assert remaining == 0.0
    
    def test_add_rune_points(self):
        """Test adding rune points."""
        manager = RuneManager()
        manager.current_rune_points = 50
        
        manager.add_rune_points(20)
        
        assert manager.current_rune_points == 70
    
    def test_add_rune_points_caps_at_max(self):
        """Test adding rune points caps at maximum."""
        manager = RuneManager()
        manager.current_rune_points = 95
        manager.max_rune_points = 100
        
        manager.add_rune_points(20)
        
        assert manager.current_rune_points == 100
    
    def test_consume_rune_points_success(self):
        """Test successfully consuming rune points."""
        manager = RuneManager()
        manager.current_rune_points = 50
        
        result = manager.consume_rune_points(20)
        
        assert result is True
        assert manager.current_rune_points == 30
    
    def test_consume_rune_points_insufficient(self):
        """Test consuming more points than available."""
        manager = RuneManager()
        manager.current_rune_points = 10
        
        result = manager.consume_rune_points(20)
        
        assert result is False
        assert manager.current_rune_points == 10
    
    def test_get_recommended_rune_boss(self):
        """Test recommended rune for boss situation."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_CRASH] = 3
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_CRASH,
            display_name="Crash",
            skill_id=2002,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=40,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_CRASH] = rune
        
        recommended = manager.get_recommended_rune("boss")
        
        assert recommended == RuneType.RUNE_OF_CRASH
    
    def test_get_recommended_rune_farming(self):
        """Test recommended rune for farming."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive",
            is_aoe=True
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        recommended = manager.get_recommended_rune("farming")
        
        assert recommended == RuneType.RUNE_OF_STORM
    
    def test_get_recommended_rune_pvp(self):
        """Test recommended rune for PvP."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_DETECTION] = 3
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_DETECTION,
            display_name="Detection",
            skill_id=2003,
            cooldown_seconds=30,
            duration_seconds=20,
            sp_cost=20,
            rune_points_cost=1,
            effect_type="utility"
        )
        manager.rune_stones[RuneType.RUNE_OF_DETECTION] = rune
        
        recommended = manager.get_recommended_rune("pvp")
        
        assert recommended == RuneType.RUNE_OF_DETECTION
    
    def test_get_recommended_rune_emergency(self):
        """Test recommended rune for emergency."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_BIRTH] = 2
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_BIRTH,
            display_name="Birth",
            skill_id=2004,
            cooldown_seconds=120,
            duration_seconds=0,
            sp_cost=50,
            rune_points_cost=3,
            effect_type="defensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_BIRTH] = rune
        
        recommended = manager.get_recommended_rune("emergency")
        
        assert recommended == RuneType.RUNE_OF_BIRTH
    
    def test_get_recommended_rune_none_available(self):
        """Test recommended rune with none available."""
        manager = RuneManager()
        
        recommended = manager.get_recommended_rune("boss")
        
        assert recommended is None
    
    def test_get_recommended_rune_insufficient_points(self):
        """Test recommended rune with insufficient points."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_CRASH] = 3
        manager.current_rune_points = 1  # Need 2 for crash
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_CRASH,
            display_name="Crash",
            skill_id=2002,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=40,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_CRASH] = rune
        
        recommended = manager.get_recommended_rune("boss")
        
        assert recommended is None
    
    def test_get_available_runes_empty(self):
        """Test getting available runes when none available."""
        manager = RuneManager()
        
        available = manager.get_available_runes()
        
        assert len(available) == 0
    
    def test_get_available_runes_filters_no_inventory(self):
        """Test available runes filters out those without inventory."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 0
        
        available = manager.get_available_runes()
        
        assert RuneType.RUNE_OF_STORM not in available
    
    def test_get_available_runes_filters_on_cooldown(self):
        """Test available runes filters out those on cooldown."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        # Put on cooldown
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        
        available = manager.get_available_runes()
        
        assert RuneType.RUNE_OF_STORM not in available
    
    def test_get_available_runes_filters_no_definition(self):
        """Test available runes filters those without definition."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        # No definition in rune_stones
        
        available = manager.get_available_runes()
        
        assert RuneType.RUNE_OF_STORM not in available
    
    def test_get_available_runes_filters_insufficient_points(self):
        """Test available runes filters those requiring too many points."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 1  # Need 2
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        available = manager.get_available_runes()
        
        assert RuneType.RUNE_OF_STORM not in available
    
    def test_get_available_runes_success(self):
        """Test getting available runes successfully."""
        manager = RuneManager()
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.current_rune_points = 10
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        available = manager.get_available_runes()
        
        assert RuneType.RUNE_OF_STORM in available
    
    def test_get_status_comprehensive(self):
        """Test getting comprehensive status."""
        manager = RuneManager()
        manager.current_rune_points = 45
        manager.max_rune_points = 100
        manager.rune_inventory[RuneType.RUNE_OF_STORM] = 5
        manager.rune_inventory[RuneType.RUNE_OF_CRASH] = 0
        
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_FIGHTING,
            cooldown_seconds=60
        )
        manager.rune_cooldowns[RuneType.RUNE_OF_FIGHTING] = cooldown
        
        rune = RuneStone(
            rune_type=RuneType.RUNE_OF_STORM,
            display_name="Storm",
            skill_id=2001,
            cooldown_seconds=60,
            duration_seconds=10,
            sp_cost=30,
            rune_points_cost=2,
            effect_type="offensive"
        )
        manager.rune_stones[RuneType.RUNE_OF_STORM] = rune
        
        status = manager.get_status()
        
        assert status["rune_points"] == 45
        assert status["max_rune_points"] == 100
        assert "rune_of_storm" in status["rune_inventory"]
        assert "rune_of_crash" not in status["rune_inventory"]  # 0 count filtered
        assert "rune_of_fighting" in status["active_cooldowns"]
        assert "rune_of_storm" in status["available_runes"]
    
    def test_reset(self):
        """Test resetting rune state."""
        manager = RuneManager()
        manager.current_rune_points = 50
        
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        manager.rune_cooldowns[RuneType.RUNE_OF_STORM] = cooldown
        
        manager.reset()
        
        assert manager.current_rune_points == 0
        assert len(manager.rune_cooldowns) == 0


class TestRuneCooldownModel:
    """Test RuneCooldown model behavior."""
    
    def test_is_ready_property_true(self):
        """Test is_ready when cooldown expired."""
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=1
        )
        cooldown.used_at = datetime.now() - timedelta(seconds=10)
        
        assert cooldown.is_ready is True
    
    def test_is_ready_property_false(self):
        """Test is_ready when still on cooldown."""
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        
        assert cooldown.is_ready is False
    
    def test_time_remaining_positive(self):
        """Test time remaining when on cooldown."""
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=60
        )
        
        remaining = cooldown.time_remaining
        
        assert remaining > 0
        assert remaining <= 60
    
    def test_time_remaining_zero(self):
        """Test time remaining when ready."""
        cooldown = RuneCooldown(
            rune_type=RuneType.RUNE_OF_STORM,
            cooldown_seconds=1
        )
        cooldown.used_at = datetime.now() - timedelta(seconds=10)
        
        remaining = cooldown.time_remaining
        
        assert remaining == 0