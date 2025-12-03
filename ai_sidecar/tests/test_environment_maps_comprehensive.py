"""
Comprehensive tests for environment/maps.py module.

Tests map properties, environmental effects, access restrictions,
and optimal map recommendations based on time/weather.
"""

import json
import pytest
from pathlib import Path
from unittest.mock import Mock, MagicMock

from ai_sidecar.environment.maps import (
    MapType,
    MapEnvironment,
    MapProperties,
    MapEnvironmentManager
)
from ai_sidecar.environment.time_core import GamePeriod, TimeManager
from ai_sidecar.environment.day_night import DayNightManager, PhaseModifiers
from ai_sidecar.environment.weather import WeatherManager, WeatherType, WeatherEffect


# MapType and MapEnvironment Enum Tests

class TestMapEnums:
    """Test map-related enums."""
    
    def test_map_type_values(self):
        """Test MapType enum values."""
        assert MapType.TOWN == "town"
        assert MapType.FIELD == "field"
        assert MapType.DUNGEON == "dungeon"
        assert MapType.PVP == "pvp"
    
    def test_map_environment_values(self):
        """Test MapEnvironment enum values."""
        assert MapEnvironment.OUTDOOR == "outdoor"
        assert MapEnvironment.INDOOR == "indoor"
        assert MapEnvironment.UNDERGROUND == "underground"


# MapProperties Model Tests

class TestMapPropertiesModel:
    """Test MapProperties pydantic model."""
    
    def test_map_properties_minimal(self):
        """Test creating map properties with minimal fields."""
        props = MapProperties(map_name="prontera")
        assert props.map_name == "prontera"
        assert props.map_type == MapType.FIELD
        assert props.environment == MapEnvironment.OUTDOOR
        assert props.has_day_night is True
        assert props.has_weather is True
    
    def test_map_properties_full(self):
        """Test creating map properties with all fields."""
        props = MapProperties(
            map_name="nameless_island",
            map_type=MapType.DUNGEON,
            environment=MapEnvironment.UNDERGROUND,
            has_day_night=False,
            has_weather=False,
            fixed_time_period=GamePeriod.NIGHT,
            fixed_weather=WeatherType.CLEAR,
            level_requirement=95,
            quest_requirement=1234,
            exp_modifier=1.5,
            drop_modifier=1.3,
            movement_modifier=0.9
        )
        assert props.map_name == "nameless_island"
        assert props.environment == MapEnvironment.UNDERGROUND
        assert props.fixed_time_period == GamePeriod.NIGHT
        assert props.level_requirement == 95
    
    def test_map_properties_modifiers_validation(self):
        """Test modifier validation."""
        # Valid modifiers
        props = MapProperties(
            map_name="test",
            exp_modifier=2.0,
            drop_modifier=0.5,
            movement_modifier=1.0
        )
        assert props.exp_modifier == 2.0
        
        # Invalid negative modifier
        with pytest.raises(ValueError):
            MapProperties(map_name="test", exp_modifier=-1.0)


# MapEnvironmentManager Tests

class TestMapEnvironmentManagerInit:
    """Test MapEnvironmentManager initialization."""
    
    def test_init_with_valid_data(self, tmp_path):
        """Test initialization with valid map data."""
        # Create test data file
        data_file = tmp_path / "map_environments.json"
        test_data = {
            "maps": {
                "prontera": {
                    "map_type": "town",
                    "environment": "outdoor",
                    "level_requirement": 0
                }
            }
        }
        
        with open(data_file, "w") as f:
            json.dump(test_data, f)
        
        time_mgr = Mock(spec=TimeManager)
        day_night_mgr = Mock(spec=DayNightManager)
        weather_mgr = Mock(spec=WeatherManager)
        
        manager = MapEnvironmentManager(
            tmp_path,
            time_mgr,
            day_night_mgr,
            weather_mgr
        )
        
        assert "prontera" in manager.map_properties
        assert manager.map_properties["prontera"].map_type == MapType.TOWN
    
    def test_init_no_data_file(self, tmp_path):
        """Test initialization when data file doesn't exist."""
        time_mgr = Mock(spec=TimeManager)
        day_night_mgr = Mock(spec=DayNightManager)
        weather_mgr = Mock(spec=WeatherManager)
        
        manager = MapEnvironmentManager(
            tmp_path,
            time_mgr,
            day_night_mgr,
            weather_mgr
        )
        
        assert len(manager.map_properties) == 0
    
    def test_init_invalid_json(self, tmp_path):
        """Test handling of invalid JSON."""
        data_file = tmp_path / "map_environments.json"
        with open(data_file, "w") as f:
            f.write("{invalid json")
        
        time_mgr = Mock()
        day_night_mgr = Mock()
        weather_mgr = Mock()
        
        manager = MapEnvironmentManager(
            tmp_path,
            time_mgr,
            day_night_mgr,
            weather_mgr
        )
        
        assert len(manager.map_properties) == 0


class TestGetMapProperties:
    """Test getting map properties."""
    
    def test_get_existing_map(self):
        """Test getting properties for existing map."""
        manager = self._create_test_manager()
        
        props = manager.get_map_properties("prontera")
        assert props is not None
        assert props.map_name == "prontera"
    
    def test_get_nonexistent_map(self):
        """Test getting properties for non-existent map."""
        manager = self._create_test_manager()
        
        props = manager.get_map_properties("nonexistent_map")
        assert props is None
    
    def _create_test_manager(self):
        """Helper to create manager with test data."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        manager.map_properties["prontera"] = MapProperties(map_name="prontera")
        return manager


class TestGetEffectiveTimePeriod:
    """Test effective time period calculation."""
    
    def test_get_time_with_fixed_period(self):
        """Test map with fixed time period."""
        time_mgr = Mock(spec=TimeManager)
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        # Map with fixed night time
        props = MapProperties(
            map_name="abyss",
            fixed_time_period=GamePeriod.NIGHT
        )
        manager.map_properties["abyss"] = props
        
        result = manager.get_effective_time_period("abyss")
        assert result == GamePeriod.NIGHT
        time_mgr.get_current_period.assert_not_called()
    
    def test_get_time_underground_no_day_night(self):
        """Test underground map without day/night."""
        time_mgr = Mock()
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        props = MapProperties(
            map_name="dungeon",
            environment=MapEnvironment.UNDERGROUND,
            has_day_night=False
        )
        manager.map_properties["dungeon"] = props
        
        result = manager.get_effective_time_period("dungeon")
        assert result == GamePeriod.NIGHT
    
    def test_get_time_indoor_no_day_night(self):
        """Test indoor map without day/night."""
        time_mgr = Mock()
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        props = MapProperties(
            map_name="castle",
            environment=MapEnvironment.INDOOR,
            has_day_night=False
        )
        manager.map_properties["castle"] = props
        
        result = manager.get_effective_time_period("castle")
        assert result == GamePeriod.NOON
    
    def test_get_time_from_time_manager(self):
        """Test getting time from time manager."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_current_period.return_value = GamePeriod.MORNING
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="field", has_day_night=True)
        manager.map_properties["field"] = props
        
        result = manager.get_effective_time_period("field")
        assert result == GamePeriod.MORNING
        time_mgr.get_current_period.assert_called_once()


class TestGetEffectiveWeather:
    """Test effective weather calculation."""
    
    def test_get_weather_with_fixed_weather(self):
        """Test map with fixed weather."""
        weather_mgr = Mock(spec=WeatherManager)
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            weather_mgr
        )
        
        props = MapProperties(
            map_name="snowy_field",
            fixed_weather=WeatherType.SNOW
        )
        manager.map_properties["snowy_field"] = props
        
        result = manager.get_effective_weather("snowy_field")
        assert result == WeatherType.SNOW
        weather_mgr.get_weather.assert_not_called()
    
    def test_get_weather_indoor_no_weather(self):
        """Test indoor map without weather."""
        weather_mgr = Mock()
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            weather_mgr
        )
        
        props = MapProperties(map_name="indoor", has_weather=False)
        manager.map_properties["indoor"] = props
        
        result = manager.get_effective_weather("indoor")
        assert result == WeatherType.CLEAR
    
    def test_get_weather_from_weather_manager(self):
        """Test getting weather from weather manager."""
        weather_mgr = Mock(spec=WeatherManager)
        weather_mgr.get_weather.return_value = WeatherType.RAIN
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            weather_mgr
        )
        
        props = MapProperties(map_name="field", has_weather=True)
        manager.map_properties["field"] = props
        
        result = manager.get_effective_weather("field")
        assert result == WeatherType.RAIN
        weather_mgr.get_weather.assert_called_once_with("field")


class TestCanAccessMap:
    """Test map access checking."""
    
    def test_can_access_unknown_map(self):
        """Test accessing unknown map (no restrictions)."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        can_access, reason = manager.can_access_map("unknown", {"level": 50})
        assert can_access is True
        assert "No restrictions" in reason
    
    def test_can_access_level_sufficient(self):
        """Test accessing map with sufficient level."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="high_level", level_requirement=90)
        manager.map_properties["high_level"] = props
        
        can_access, reason = manager.can_access_map("high_level", {"level": 95})
        assert can_access is True
    
    def test_can_access_level_insufficient(self):
        """Test accessing map with insufficient level."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="high_level", level_requirement=90)
        manager.map_properties["high_level"] = props
        
        can_access, reason = manager.can_access_map("high_level", {"level": 50})
        assert can_access is False
        assert "Level 90 required" in reason
    
    def test_can_access_quest_completed(self):
        """Test accessing map with completed quest requirement."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="quest_map", quest_requirement=1234)
        manager.map_properties["quest_map"] = props
        
        can_access, reason = manager.can_access_map(
            "quest_map",
            {"level": 50, "completed_quests": [1234, 5678]}
        )
        assert can_access is True
    
    def test_can_access_quest_not_completed(self):
        """Test accessing map without required quest."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="quest_map", quest_requirement=1234)
        manager.map_properties["quest_map"] = props
        
        can_access, reason = manager.can_access_map(
            "quest_map",
            {"level": 50, "completed_quests": [5678]}
        )
        assert can_access is False
        assert "Quest 1234 required" in reason


class TestGetCombinedModifiers:
    """Test combined modifier calculation."""
    
    def test_get_modifiers_base_only(self):
        """Test modifiers from map properties only."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(
            map_name="test",
            exp_modifier=1.5,
            drop_modifier=1.3,
            movement_modifier=0.9,
            has_day_night=False,
            has_weather=False
        )
        manager.map_properties["test"] = props
        
        mods = manager.get_combined_modifiers("test")
        assert mods["exp"] == 1.5
        assert mods["drop"] == 1.3
        assert mods["movement"] == 0.9
    
    def test_get_modifiers_with_day_night(self):
        """Test modifiers including day/night effects."""
        day_night_mgr = Mock(spec=DayNightManager)
        day_night_mgr.get_phase_modifiers.return_value = PhaseModifiers(
            exp_modifier=1.2,
            drop_modifier=1.1,
            monster_spawn_rate=1.0,
            visibility_range=0.9
        )
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            day_night_mgr,
            Mock()
        )
        
        props = MapProperties(
            map_name="test",
            has_day_night=True,
            exp_modifier=1.0
        )
        manager.map_properties["test"] = props
        
        mods = manager.get_combined_modifiers("test")
        assert mods["exp"] == 1.2  # 1.0 * 1.2
        assert mods["visibility"] == 0.9
    
    def test_get_modifiers_with_weather(self):
        """Test modifiers including weather effects."""
        weather_mgr = Mock(spec=WeatherManager)
        weather_mgr.get_weather_effect.return_value = WeatherEffect(
            weather_type=WeatherType.RAIN,
            visibility_modifier=0.8,
            movement_speed_modifier=0.9,
            skill_modifier=1.0,
            element_modifier={}
        )
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            weather_mgr
        )
        
        props = MapProperties(map_name="test", has_weather=True)
        manager.map_properties["test"] = props
        
        mods = manager.get_combined_modifiers("test")
        assert mods["movement"] == 0.9
        assert mods["visibility"] == 0.8


class TestGetOptimalMapsForTime:
    """Test optimal map recommendations."""
    
    def test_get_optimal_maps_farming(self):
        """Test getting optimal farming maps."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.is_daytime.return_value = True
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        # Add test maps
        manager.map_properties["field1"] = MapProperties(
            map_name="field1",
            exp_modifier=1.5,
            drop_modifier=1.5
        )
        manager.map_properties["field2"] = MapProperties(
            map_name="field2",
            exp_modifier=1.0,
            drop_modifier=1.0
        )
        manager.map_properties["pvp_map"] = MapProperties(
            map_name="pvp_map",
            map_type=MapType.PVP,
            exp_modifier=2.0
        )
        
        # Mock combined modifiers to return base values
        original_get_mods = manager.get_combined_modifiers
        def mock_get_mods(map_name):
            props = manager.map_properties[map_name]
            return {
                "exp": props.exp_modifier,
                "drop": props.drop_modifier,
                "movement": 1.0,
                "spawn_rate": 1.0,
                "visibility": 1.0
            }
        manager.get_combined_modifiers = mock_get_mods
        
        optimal = manager.get_optimal_maps_for_time(None, "farming")
        
        # Should include good maps, exclude PVP
        assert "field1" in optimal
        assert "pvp_map" not in optimal
    
    def test_get_optimal_maps_grinding(self):
        """Test getting optimal grinding maps (prioritize EXP)."""
        time_mgr = Mock()
        time_mgr.is_daytime.return_value = True
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            Mock(),
            Mock()
        )
        
        manager.map_properties["exp_map"] = MapProperties(
            map_name="exp_map",
            exp_modifier=2.0
        )
        
        def mock_get_mods(map_name):
            return {
                "exp": 2.0,
                "drop": 1.0,
                "movement": 1.0,
                "spawn_rate": 1.0,
                "visibility": 1.0
            }
        manager.get_combined_modifiers = mock_get_mods
        
        optimal = manager.get_optimal_maps_for_time(None, "grinding")
        assert "exp_map" in optimal


class TestGetMapsWithCondition:
    """Test conditional map filtering."""
    
    def test_get_maps_by_type(self):
        """Test filtering by map type."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        manager.map_properties["town1"] = MapProperties(
            map_name="town1",
            map_type=MapType.TOWN
        )
        manager.map_properties["field1"] = MapProperties(
            map_name="field1",
            map_type=MapType.FIELD
        )
        
        towns = manager.get_maps_with_condition(map_type=MapType.TOWN)
        assert "town1" in towns
        assert "field1" not in towns
    
    def test_get_maps_by_weather(self):
        """Test filtering by weather type."""
        weather_mgr = Mock(spec=WeatherManager)
        weather_mgr.get_weather.side_effect = lambda m: (
            WeatherType.RAIN if m == "rainy" else WeatherType.CLEAR
        )
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            weather_mgr
        )
        
        manager.map_properties["rainy"] = MapProperties(map_name="rainy")
        manager.map_properties["clear"] = MapProperties(map_name="clear")
        
        # Mock get_effective_weather
        manager.get_effective_weather = lambda m: weather_mgr.get_weather(m)
        
        rainy_maps = manager.get_maps_with_condition(weather=WeatherType.RAIN)
        assert "rainy" in rainy_maps
        assert "clear" not in rainy_maps
    
    def test_get_maps_by_time_period(self):
        """Test filtering by time period."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        manager.map_properties["night_map"] = MapProperties(
            map_name="night_map",
            fixed_time_period=GamePeriod.NIGHT
        )
        manager.map_properties["day_map"] = MapProperties(
            map_name="day_map",
            fixed_time_period=GamePeriod.NOON
        )
        
        night_maps = manager.get_maps_with_condition(time_period=GamePeriod.NIGHT)
        assert "night_map" in night_maps
        assert "day_map" not in night_maps


class TestIsSafeZone:
    """Test safe zone detection."""
    
    def test_is_safe_zone_town(self):
        """Test that towns are safe zones."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="prontera", map_type=MapType.TOWN)
        manager.map_properties["prontera"] = props
        
        assert manager.is_safe_zone("prontera") is True
    
    def test_is_safe_zone_field(self):
        """Test that fields are not safe zones."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="field", map_type=MapType.FIELD)
        manager.map_properties["field"] = props
        
        assert manager.is_safe_zone("field") is False
    
    def test_is_safe_zone_unknown_map(self):
        """Test unknown map is not safe."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        assert manager.is_safe_zone("unknown") is False


class TestGetMapDifficulty:
    """Test map difficulty estimation."""
    
    def test_get_difficulty_unknown_map(self):
        """Test difficulty for unknown map."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        assert manager.get_map_difficulty("unknown") == "unknown"
    
    def test_get_difficulty_easy(self):
        """Test easy difficulty."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="beginner", level_requirement=10)
        manager.map_properties["beginner"] = props
        
        assert manager.get_map_difficulty("beginner") == "easy"
    
    def test_get_difficulty_normal(self):
        """Test normal difficulty."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="mid_level", level_requirement=50)
        manager.map_properties["mid_level"] = props
        
        assert manager.get_map_difficulty("mid_level") == "normal"
    
    def test_get_difficulty_hard(self):
        """Test hard difficulty."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="high_level", level_requirement=85)
        manager.map_properties["high_level"] = props
        
        assert manager.get_map_difficulty("high_level") == "hard"
    
    def test_get_difficulty_extreme(self):
        """Test extreme difficulty."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        props = MapProperties(map_name="end_game", level_requirement=100)
        manager.map_properties["end_game"] = props
        
        assert manager.get_map_difficulty("end_game") == "extreme"


class TestGetEnvironmentSummary:
    """Test environment summary generation."""
    
    def test_get_summary_unknown_map(self):
        """Test summary for unknown map."""
        manager = MapEnvironmentManager(
            Path("/tmp"),
            Mock(),
            Mock(),
            Mock()
        )
        
        summary = manager.get_environment_summary("unknown")
        assert "error" in summary
        assert summary["error"] == "Map not found"
    
    def test_get_summary_complete(self):
        """Test complete environment summary."""
        time_mgr = Mock(spec=TimeManager)
        day_night_mgr = Mock(spec=DayNightManager)
        weather_mgr = Mock(spec=WeatherManager)
        
        manager = MapEnvironmentManager(
            Path("/tmp"),
            time_mgr,
            day_night_mgr,
            weather_mgr
        )
        
        props = MapProperties(
            map_name="test_map",
            map_type=MapType.DUNGEON,
            environment=MapEnvironment.UNDERGROUND,
            level_requirement=75
        )
        manager.map_properties["test_map"] = props
        
        # Mock return values
        manager.get_effective_time_period = Mock(return_value=GamePeriod.NIGHT)
        manager.get_effective_weather = Mock(return_value=WeatherType.CLEAR)
        manager.get_combined_modifiers = Mock(return_value={"exp": 1.5})
        
        summary = manager.get_environment_summary("test_map")
        
        assert summary["map_name"] == "test_map"
        assert summary["map_type"] == "dungeon"
        assert summary["environment"] == "underground"
        assert summary["difficulty"] == "hard"
        assert summary["is_safe_zone"] is False


class TestMapDataLoadingEdgeCases:
    """Test edge cases in map data loading."""
    
    def test_load_maps_with_fixed_time_and_weather(self, tmp_path):
        """Test loading maps with fixed time and weather."""
        data_file = tmp_path / "map_environments.json"
        test_data = {
            "maps": {
                "special_map": {
                    "map_type": "dungeon",
                    "environment": "underground",
                    "fixed_time_period": "night",
                    "fixed_weather": "snow",
                    "level_requirement": 80
                }
            }
        }
        
        with open(data_file, "w") as f:
            json.dump(test_data, f)
        
        manager = MapEnvironmentManager(
            tmp_path,
            Mock(),
            Mock(),
            Mock()
        )
        
        assert "special_map" in manager.map_properties
        props = manager.map_properties["special_map"]
        assert props.fixed_time_period == GamePeriod.NIGHT
        assert props.fixed_weather == WeatherType.SNOW


if __name__ == "__main__":
    pytest.main([__file__, "-v"])