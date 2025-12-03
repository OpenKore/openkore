"""
Comprehensive tests for day/night cycle system - Batch 4.

Tests time phases, modifiers, monster availability,
and farming recommendations.
"""

import json
from pathlib import Path
from unittest.mock import Mock

import pytest

from ai_sidecar.environment.day_night import (
    DayNightManager,
    DayNightPhase,
    PhaseModifiers,
)
from ai_sidecar.environment.time_core import GameTime, TimeManager


@pytest.fixture
def mock_time_manager():
    """Create mock TimeManager."""
    manager = Mock(spec=TimeManager)
    
    # Default to midday
    manager.calculate_game_time.return_value = GameTime(
        real_timestamp=0,
        game_timestamp=0,
        game_hour=12,
        game_minute=0,
        game_second=0,
        is_daytime=True,
    )
    manager.is_daytime.return_value = True
    
    return manager


@pytest.fixture
def temp_day_night_data(tmp_path):
    """Create temporary day/night data directory."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    config_data = {
        "phases": {
            "night": {
                "monster_spawn_rate": 1.2,
                "monster_aggro_range": 1.1,
                "exp_modifier": 1.0,
                "drop_modifier": 1.0,
                "npc_availability": 0.5,
                "visibility_range": 0.8,
                "skill_modifiers": {
                    "Moon Slasher": 1.5
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
                    "Sunshine": 1.3
                }
            }
        },
        "night_only_monsters": {
            "glast_01": ["Ghoul", "Zombie", "Wraith"]
        },
        "day_only_monsters": {
            "prt_fild08": ["Poring", "Drops"]
        }
    }
    
    config_file = data_dir / "day_night_modifiers.json"
    config_file.write_text(json.dumps(config_data))
    
    return data_dir


class TestDayNightManagerInit:
    """Test DayNightManager initialization."""
    
    def test_init_loads_data(self, temp_day_night_data, mock_time_manager):
        """Test initialization loads data."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        
        assert len(manager.phase_modifiers) > 0
        assert len(manager.night_monsters) > 0
    
    def test_init_missing_file(self, tmp_path, mock_time_manager):
        """Test initialization with missing file."""
        manager = DayNightManager(tmp_path / "nonexistent", mock_time_manager)
        
        # Should not crash
        assert len(manager.phase_modifiers) == 0


class TestPhaseDetection:
    """Test time phase detection."""
    
    def test_get_current_phase_early_morning(self, temp_day_night_data, mock_time_manager):
        """Test early morning phase."""
        mock_time_manager.calculate_game_time.return_value = GameTime(
            real_timestamp=0,
            game_timestamp=0,
            game_hour=5,
            game_minute=30,
            game_second=0,
            is_daytime=True,
        )
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.EARLY_MORNING
    
    def test_get_current_phase_midday(self, temp_day_night_data, mock_time_manager):
        """Test midday phase."""
        mock_time_manager.calculate_game_time.return_value = GameTime(
            real_timestamp=0,
            game_timestamp=0,
            game_hour=13,
            game_minute=0,
            game_second=0,
            is_daytime=True,
        )
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.MIDDAY
    
    def test_get_current_phase_midnight(self, temp_day_night_data, mock_time_manager):
        """Test midnight phase."""
        mock_time_manager.calculate_game_time.return_value = GameTime(
            real_timestamp=0,
            game_timestamp=0,
            game_hour=1,
            game_minute=0,
            game_second=0,
            is_daytime=False,
        )
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        phase = manager.get_current_phase()
        
        assert phase == DayNightPhase.MIDNIGHT


class TestPhaseModifiers:
    """Test phase modifier retrieval."""
    
    def test_get_phase_modifiers_current(self, temp_day_night_data, mock_time_manager):
        """Test getting current phase modifiers."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        
        modifiers = manager.get_phase_modifiers()
        
        assert isinstance(modifiers, PhaseModifiers)
    
    def test_get_phase_modifiers_specific(self, temp_day_night_data, mock_time_manager):
        """Test getting specific phase modifiers."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        
        modifiers = manager.get_phase_modifiers(DayNightPhase.EVENING)
        
        assert isinstance(modifiers, PhaseModifiers)


class TestSkillModifiers:
    """Test skill modifier calculations."""
    
    def test_get_skill_modifier_exists(self, temp_day_night_data, mock_time_manager):
        """Test getting existing skill modifier."""
        # Set to night time
        mock_time_manager.calculate_game_time.return_value = GameTime(
            real_timestamp=0,
            game_timestamp=0,
            game_hour=22,
            game_minute=0,
            game_second=0,
            is_daytime=False,
        )
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_skill_modifier("Moon Slasher")
        
        # Night skill should have bonus
        assert modifier > 1.0
    
    def test_get_skill_modifier_default(self, temp_day_night_data, mock_time_manager):
        """Test default skill modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_skill_modifier("Unknown Skill")
        
        assert modifier == 1.0


class TestMonsterAvailability:
    """Test monster spawn availability."""
    
    def test_get_monster_availability_night_only(self, temp_day_night_data, mock_time_manager):
        """Test night-only monster availability."""
        # Set to night
        mock_time_manager.is_daytime.return_value = False
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.get_monster_availability("glast_01", "Ghoul")
        
        assert available is True
    
    def test_get_monster_availability_night_only_during_day(self, temp_day_night_data, mock_time_manager):
        """Test night-only monster during day."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.get_monster_availability("glast_01", "Ghoul")
        
        assert available is False
    
    def test_get_monster_availability_day_only(self, temp_day_night_data, mock_time_manager):
        """Test day-only monster availability."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.get_monster_availability("prt_fild08", "Poring")
        
        assert available is True
    
    def test_get_monster_availability_always(self, temp_day_night_data, mock_time_manager):
        """Test always-available monster."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.get_monster_availability("prontera", "Unknown Monster")
        
        # Unknown monsters available all times
        assert available is True


class TestAvailableMonsters:
    """Test getting available monsters."""
    
    def test_get_available_monsters_night(self, temp_day_night_data, mock_time_manager):
        """Test getting night monsters."""
        # Set to night
        mock_time_manager.is_daytime.return_value = False
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        monsters = manager.get_available_monsters("glast_01")
        
        assert "Ghoul" in monsters
        assert "Zombie" in monsters
    
    def test_get_available_monsters_day(self, temp_day_night_data, mock_time_manager):
        """Test getting day monsters."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        monsters = manager.get_available_monsters("prt_fild08")
        
        assert "Poring" in monsters


class TestNPCAvailability:
    """Test NPC availability."""
    
    def test_is_npc_available_daytime(self, temp_day_night_data, mock_time_manager):
        """Test NPC availability during day."""
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.is_npc_available(1, "prontera")
        
        # Default NPCs available during day
        assert available is True
    
    def test_is_npc_available_night(self, temp_day_night_data, mock_time_manager):
        """Test NPC availability at night."""
        mock_time_manager.is_daytime.return_value = False
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        available = manager.is_npc_available(1, "prontera")
        
        # Default NPCs not available at night
        assert available is False


class TestVisibilityModifier:
    """Test visibility modifier."""
    
    def test_get_visibility_modifier(self, temp_day_night_data, mock_time_manager):
        """Test getting visibility modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        visibility = manager.get_visibility_modifier()
        
        assert visibility > 0.0
        assert visibility <= 1.0


class TestFarmingSpotRecommendations:
    """Test farming spot switching."""
    
    def test_should_switch_farming_spot_day_map_at_night(self, temp_day_night_data, mock_time_manager):
        """Test switching from day map at night."""
        # Set to night
        mock_time_manager.is_daytime.return_value = False
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        should_switch, recommended = manager.should_switch_farming_spot("prt_fild08")
        
        # Should recommend switching
        assert should_switch is True
        assert recommended is not None
    
    def test_should_switch_farming_spot_night_map_at_day(self, temp_day_night_data, mock_time_manager):
        """Test switching from night map at day."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        should_switch, recommended = manager.should_switch_farming_spot("glast_01")
        
        # Should recommend switching
        assert should_switch is True
        assert recommended is not None
    
    def test_should_not_switch_farming_spot(self, temp_day_night_data, mock_time_manager):
        """Test not switching when on correct map."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        should_switch, recommended = manager.should_switch_farming_spot("prt_fild08")
        
        # Should not switch
        assert should_switch is False
        assert recommended is None


class TestOptimalFarmingPeriod:
    """Test optimal farming period calculation."""
    
    def test_get_optimal_farming_period_night_only(self, temp_day_night_data, mock_time_manager):
        """Test optimal period for night monster."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        periods = manager.get_optimal_farming_period("Ghoul")
        
        # Should be night phases
        assert DayNightPhase.EVENING in periods
        assert DayNightPhase.MIDNIGHT in periods
        assert DayNightPhase.MIDDAY not in periods
    
    def test_get_optimal_farming_period_day_only(self, temp_day_night_data, mock_time_manager):
        """Test optimal period for day monster."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        periods = manager.get_optimal_farming_period("Poring")
        
        # Should be day phases
        assert DayNightPhase.MORNING in periods
        assert DayNightPhase.MIDDAY in periods
        assert DayNightPhase.MIDNIGHT not in periods
    
    def test_get_optimal_farming_period_always(self, temp_day_night_data, mock_time_manager):
        """Test optimal period for always-available monster."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        periods = manager.get_optimal_farming_period("Unknown Monster")
        
        # Should be all phases
        assert len(periods) == len(list(DayNightPhase))


class TestModifierAccessors:
    """Test modifier accessor methods."""
    
    def test_get_spawn_rate_modifier(self, temp_day_night_data, mock_time_manager):
        """Test getting spawn rate modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_spawn_rate_modifier()
        
        assert modifier > 0.0
    
    def test_get_aggro_range_modifier(self, temp_day_night_data, mock_time_manager):
        """Test getting aggro range modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_aggro_range_modifier()
        
        assert modifier > 0.0
    
    def test_get_exp_modifier(self, temp_day_night_data, mock_time_manager):
        """Test getting EXP modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_exp_modifier()
        
        assert modifier >= 0.0
    
    def test_get_drop_modifier(self, temp_day_night_data, mock_time_manager):
        """Test getting drop modifier."""
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        modifier = manager.get_drop_modifier()
        
        assert modifier >= 0.0


class TestOptimalHuntingTime:
    """Test optimal hunting time check."""
    
    def test_is_optimal_hunting_time_available(self, temp_day_night_data, mock_time_manager):
        """Test optimal hunting when monster available."""
        # Set to day
        mock_time_manager.is_daytime.return_value = True
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        is_optimal = manager.is_optimal_hunting_time("Poring", "prt_fild08")
        
        assert is_optimal is True
    
    def test_is_optimal_hunting_time_unavailable(self, temp_day_night_data, mock_time_manager):
        """Test not optimal when monster unavailable."""
        # Set to night
        mock_time_manager.is_daytime.return_value = False
        
        manager = DayNightManager(temp_day_night_data, mock_time_manager)
        is_optimal = manager.is_optimal_hunting_time("Poring", "prt_fild08")
        
        # Day monster at night
        assert is_optimal is False


class TestPhaseModifiersModel:
    """Test PhaseModifiers model."""
    
    def test_phase_modifiers_creation(self):
        """Test creating phase modifiers."""
        modifiers = PhaseModifiers(
            monster_spawn_rate=1.5,
            exp_modifier=1.2,
        )
        
        assert modifiers.monster_spawn_rate == 1.5
        assert modifiers.exp_modifier == 1.2