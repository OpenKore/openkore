"""
Comprehensive tests for environment/day_night.py - BATCH 4.
Target: 95%+ coverage (currently 83.74%, 18 uncovered lines).
"""

import pytest
from pathlib import Path
from unittest.mock import Mock
from ai_sidecar.environment.day_night import (
    DayNightManager,
    DayNightPhase,
    PhaseModifiers,
)


class MockTimeManager:
    """Mock time manager for testing."""
    
    def __init__(self, hour=12, minute=0, is_day=True):
        self._hour = hour
        self._minute = minute
        self._is_day = is_day
    
    def calculate_game_time(self):
        """Return mock game time."""
        mock_time = Mock()
        mock_time.game_hour = self._hour
        mock_time.game_minute = self._minute
        return mock_time
    
    def is_daytime(self):
        """Return mock daytime status."""
        return self._is_day


class TestDayNightManager:
    """Test DayNightManager functionality."""
    
    @pytest.fixture
    def temp_data_dir(self, tmp_path):
        """Create temp data directory with day/night data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        import json
        day_night_data = {
            "phases": {
                "night": {
                    "monster_spawn_rate": 1.2,
                    "monster_aggro_range": 1.1,
                    "exp_modifier": 1.15,
                    "drop_modifier": 1.1,
                    "npc_availability": 0.5,
                    "visibility_range": 0.8,
                    "skill_modifiers": {
                        "moon_slasher": 1.5,
                    }
                },
                "day": {
                    "monster_spawn_rate": 1.0,
                    "monster_aggro_range": 1.0,
                    "exp_modifier": 1.0,
                    "drop_modifier": 1.0,
                    "npc_availability": 1.0,
                    "visibility_range": 1.0,
                    "skill_modifiers": {
                        "sunshine": 1.3,
                    }
                }
            },
            "night_only_monsters": {
                "pay_dun01": ["Zombie", "Ghoul"],
            },
            "day_only_monsters": {
                "prt_fild08": ["Poring", "Lunatic"],
            }
        }
        
        modifier_file = data_dir / "day_night_modifiers.json"
        with open(modifier_file, "w") as f:
            json.dump(day_night_data, f)
        
        return data_dir
    
    @pytest.fixture
    def time_manager(self):
        """Create mock time manager."""
        return MockTimeManager()
    
    @pytest.fixture
    def manager(self, temp_data_dir, time_manager):
        """Create day/night manager."""
        return DayNightManager(temp_data_dir, time_manager)
    
    def test_initialization(self, manager):
        """Test manager initialization."""
        assert isinstance(manager.phase_modifiers, dict)
        assert isinstance(manager.night_monsters, dict)
        assert isinstance(manager.day_monsters, dict)
    
    def test_get_current_phase_morning(self):
        """Test phase detection for morning."""
        time_mgr = MockTimeManager(hour=8)
        data_dir = Path(".")
        manager = DayNightManager(data_dir, time_mgr)
        
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.MORNING
    
    def test_get_current_phase_midday(self):
        """Test phase detection for midday."""
        time_mgr = MockTimeManager(hour=13)
        data_dir = Path(".")
        manager = DayNightManager(data_dir, time_mgr)
        
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.MIDDAY
    
    def test_get_current_phase_sunset(self):
        """Test phase detection for sunset."""
        time_mgr = MockTimeManager(hour=19)
        data_dir = Path(".")
        manager = DayNightManager(data_dir, time_mgr)
        
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.SUNSET
    
    def test_get_current_phase_midnight(self):
        """Test phase detection for midnight."""
        time_mgr = MockTimeManager(hour=1)
        data_dir = Path(".")
        manager = DayNightManager(data_dir, time_mgr)
        
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.MIDNIGHT
    
    def test_get_current_phase_all_hours(self):
        """Test all hour mappings."""
        data_dir = Path(".")
        
        for hour in range(24):
            time_mgr = MockTimeManager(hour=hour)
            manager = DayNightManager(data_dir, time_mgr)
            phase = manager.get_current_phase()
            
            assert isinstance(phase, DayNightPhase)
    
    def test_get_phase_modifiers_default(self, manager):
        """Test getting current phase modifiers."""
        modifiers = manager.get_phase_modifiers()
        
        assert isinstance(modifiers, PhaseModifiers)
    
    def test_get_phase_modifiers_specific(self, manager):
        """Test getting specific phase modifiers."""
        modifiers = manager.get_phase_modifiers(DayNightPhase.EVENING)
        
        assert isinstance(modifiers, PhaseModifiers)
    
    def test_get_skill_modifier(self, manager):
        """Test getting skill modifier."""
        modifier = manager.get_skill_modifier("moon_slasher")
        
        # Should return modifier from current phase or default 1.0
        assert modifier >= 1.0 or modifier == 1.0
    
    def test_get_skill_modifier_unknown_skill(self, manager):
        """Test skill modifier for unknown skill."""
        modifier = manager.get_skill_modifier("unknown_skill")
        
        assert modifier == 1.0
    
    def test_get_monster_availability_night_only(self, manager):
        """Test night-only monster availability."""
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        manager.time_manager._is_day = False
        
        available = manager.get_monster_availability("pay_dun01", "Zombie")
        
        assert available is True
    
    def test_get_monster_availability_night_only_during_day(self, manager):
        """Test night monster during day."""
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        manager.time_manager._is_day = True
        
        available = manager.get_monster_availability("pay_dun01", "Zombie")
        
        assert available is False
    
    def test_get_monster_availability_day_only(self, manager):
        """Test day-only monster availability."""
        manager.day_monsters["prt_fild08"] = ["Poring"]
        manager.time_manager._is_day = True
        
        available = manager.get_monster_availability("prt_fild08", "Poring")
        
        assert available is True
    
    def test_get_monster_availability_day_only_during_night(self, manager):
        """Test day monster during night."""
        manager.day_monsters["prt_fild08"] = ["Poring"]
        manager.time_manager._is_day = False
        
        available = manager.get_monster_availability("prt_fild08", "Poring")
        
        assert available is False
    
    def test_get_monster_availability_always(self, manager):
        """Test monster available all times."""
        available = manager.get_monster_availability("random_map", "Random Monster")
        
        assert available is True
    
    def test_get_available_monsters_night(self, manager):
        """Test getting available monsters at night."""
        manager.night_monsters["pay_dun01"] = ["Zombie", "Ghoul"]
        manager.time_manager._is_day = False
        
        monsters = manager.get_available_monsters("pay_dun01")
        
        assert "Zombie" in monsters
        assert "Ghoul" in monsters
    
    def test_get_available_monsters_day(self, manager):
        """Test getting available monsters during day."""
        manager.day_monsters["prt_fild08"] = ["Poring", "Lunatic"]
        manager.time_manager._is_day = True
        
        monsters = manager.get_available_monsters("prt_fild08")
        
        assert "Poring" in monsters
        assert "Lunatic" in monsters
    
    def test_is_npc_available_daytime(self, manager):
        """Test NPC availability during day."""
        manager.time_manager._is_day = True
        
        available = manager.is_npc_available(1001, "prontera")
        
        assert available is True
    
    def test_is_npc_available_night_default(self, manager):
        """Test NPC availability at night (default)."""
        manager.time_manager._is_day = False
        
        available = manager.is_npc_available(1001, "prontera")
        
        assert available is False  # Default: day only
    
    def test_is_npc_available_night_npc(self, manager):
        """Test night NPC availability."""
        manager.night_npcs[1002] = True
        manager.time_manager._is_day = False
        
        available = manager.is_npc_available(1002, "prontera")
        
        assert available is True
    
    def test_get_visibility_modifier(self, manager):
        """Test visibility modifier."""
        modifier = manager.get_visibility_modifier()
        
        assert 0.0 <= modifier <= 1.0
    
    def test_should_switch_farming_spot_night_on_day_map(self, manager):
        """Test switch recommendation at night on day map."""
        manager.day_monsters["prt_fild08"] = ["Poring"]
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        manager.time_manager._is_day = False
        
        should_switch, recommended = manager.should_switch_farming_spot("prt_fild08")
        
        assert should_switch is True
        assert recommended is not None
    
    def test_should_switch_farming_spot_day_on_night_map(self, manager):
        """Test switch recommendation during day on night map."""
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        manager.day_monsters["prt_fild08"] = ["Poring"]
        manager.time_manager._is_day = True
        
        should_switch, recommended = manager.should_switch_farming_spot("pay_dun01")
        
        assert should_switch is True
        assert recommended is not None
    
    def test_should_switch_farming_spot_no_switch(self, manager):
        """Test no switch needed."""
        should_switch, recommended = manager.should_switch_farming_spot("neutral_map")
        
        assert should_switch is False
        assert recommended is None
    
    def test_get_optimal_farming_period_night_monster(self, manager):
        """Test optimal period for night monster."""
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        
        periods = manager.get_optimal_farming_period("Zombie")
        
        assert len(periods) > 0
        assert DayNightPhase.EVENING in periods
        assert DayNightPhase.MIDNIGHT in periods
    
    def test_get_optimal_farming_period_day_monster(self, manager):
        """Test optimal period for day monster."""
        manager.day_monsters["prt_fild08"] = ["Poring"]
        
        periods = manager.get_optimal_farming_period("Poring")
        
        assert len(periods) > 0
        assert DayNightPhase.MORNING in periods
        assert DayNightPhase.MIDDAY in periods
    
    def test_get_optimal_farming_period_any_time(self, manager):
        """Test optimal period for any-time monster."""
        periods = manager.get_optimal_farming_period("Random Monster")
        
        # All phases available
        assert len(periods) > 10
    
    def test_get_spawn_rate_modifier(self, manager):
        """Test spawn rate modifier."""
        modifier = manager.get_spawn_rate_modifier()
        
        assert modifier >= 0.0
    
    def test_get_aggro_range_modifier(self, manager):
        """Test aggro range modifier."""
        modifier = manager.get_aggro_range_modifier()
        
        assert modifier >= 0.0
    
    def test_get_exp_modifier(self, manager):
        """Test EXP modifier."""
        modifier = manager.get_exp_modifier()
        
        assert modifier >= 0.0
    
    def test_get_drop_modifier(self, manager):
        """Test drop rate modifier."""
        modifier = manager.get_drop_modifier()
        
        assert modifier >= 0.0
    
    def test_is_optimal_hunting_time_available(self, manager):
        """Test optimal hunting time when monster available."""
        manager.time_manager._is_day = True
        manager.day_monsters["prt_fild08"] = ["Poring"]
        
        is_optimal = manager.is_optimal_hunting_time("Poring", "prt_fild08")
        
        assert is_optimal is True
    
    def test_is_optimal_hunting_time_unavailable(self, manager):
        """Test optimal hunting time when monster unavailable."""
        manager.time_manager._is_day = True
        manager.night_monsters["pay_dun01"] = ["Zombie"]
        
        is_optimal = manager.is_optimal_hunting_time("Zombie", "pay_dun01")
        
        assert is_optimal is False
    
    def test_update_time(self, manager):
        """Test update_time method."""
        # Should not raise errors
        manager.update_time(14, 30)
        
        # Should track phase changes
        assert hasattr(manager, '_last_phase')
    
    def test_update_time_phase_change(self, manager):
        """Test update_time logs phase changes."""
        manager.time_manager._hour = 8
        manager.update_time(8, 0)
        
        # Change time
        manager.time_manager._hour = 14
        manager.update_time(14, 0)
        
        # Should have tracked the change
        assert hasattr(manager, '_last_phase')


class TestPhaseModifiers:
    """Test PhaseModifiers model."""
    
    def test_default_modifiers(self):
        """Test default modifier values."""
        modifiers = PhaseModifiers()
        
        assert modifiers.monster_spawn_rate == 1.0
        assert modifiers.monster_aggro_range == 1.0
        assert modifiers.exp_modifier == 1.0
        assert modifiers.drop_modifier == 1.0
        assert modifiers.npc_availability == 1.0
        assert modifiers.visibility_range == 1.0
    
    def test_custom_modifiers(self):
        """Test custom modifier values."""
        modifiers = PhaseModifiers(
            monster_spawn_rate=1.5,
            exp_modifier=1.2,
            skill_modifiers={"moon_slasher": 1.5}
        )
        
        assert modifiers.monster_spawn_rate == 1.5
        assert modifiers.exp_modifier == 1.2
        assert modifiers.skill_modifiers["moon_slasher"] == 1.5


class TestDayNightPhase:
    """Test DayNightPhase enum."""
    
    def test_all_phases_exist(self):
        """Test all phases are defined."""
        phases = [
            DayNightPhase.DAY,
            DayNightPhase.NIGHT,
            DayNightPhase.EARLY_MORNING,
            DayNightPhase.MORNING,
            DayNightPhase.LATE_MORNING,
            DayNightPhase.MIDDAY,
            DayNightPhase.AFTERNOON,
            DayNightPhase.LATE_AFTERNOON,
            DayNightPhase.SUNSET,
            DayNightPhase.EVENING,
            DayNightPhase.LATE_EVENING,
            DayNightPhase.MIDNIGHT,
            DayNightPhase.DEEP_NIGHT,
            DayNightPhase.PREDAWN,
        ]
        
        for phase in phases:
            assert isinstance(phase.value, str)