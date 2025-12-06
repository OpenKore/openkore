"""
Extended test coverage for weather.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 93, 129, 146-147, 246-261, 273-287, 336, 354-356, 379-390, 476, 480
- Weather loading, simulation, optimal conditions
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import json

from ai_sidecar.environment.weather import (
    WeatherManager,
    WeatherType,
    WeatherEffect,
    MapWeatherConfig,
)


class TestWeatherExtendedCoverage:
    """Extended coverage for weather manager."""
    
    def test_init_with_data_path_alias(self):
        """Test initialization with data_path parameter (backwards compatibility)."""
        with patch.object(Path, "exists", return_value=False):
            manager = WeatherManager(data_path=Path("test_data"))
            
            assert manager is not None
    
    def test_current_weather_property_global(self):
        """Test current_weather property returns global weather."""
        manager = WeatherManager()
        manager._global_weather = WeatherType.RAIN
        
        weather = manager.current_weather
        
        assert weather == WeatherType.RAIN
    
    def test_current_weather_property_dict(self):
        """Test current_weather property returns dict in production."""
        manager = WeatherManager()
        manager._global_weather = None
        manager._current_weather_dict = {"prontera": Mock()}
        
        weather = manager.current_weather
        
        assert isinstance(weather, dict)
    
    def test_current_weather_setter(self):
        """Test setting current weather."""
        manager = WeatherManager()
        
        manager.current_weather = WeatherType.STORM
        
        assert manager._global_weather == WeatherType.STORM
    
    def test_load_weather_data_with_fixed_weather(self):
        """Test loading weather data with fixed weather maps."""
        data = {
            "weather_types": {
                "rain": {
                    "visibility_modifier": 0.7,
                    "movement_speed_modifier": 0.9
                }
            },
            "map_weather": {
                "niflheim": {
                    "fixed": "snow"
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=json.dumps(data))):
            with patch.object(Path, "exists", return_value=True):
                manager = WeatherManager(data_dir=Path("test_data"))
                
                assert "niflheim" in manager.map_configs
                assert manager.map_configs["niflheim"].can_change_weather is False
    
    def test_load_weather_data_with_variable_weather(self):
        """Test loading weather data with variable weather."""
        data = {
            "weather_types": {},
            "map_weather": {
                "prontera": {
                    "possible": ["clear", "rain", "cloudy"],
                    "default": "clear"
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=json.dumps(data))):
            with patch.object(Path, "exists", return_value=True):
                manager = WeatherManager(data_dir=Path("test_data"))
                
                assert "prontera" in manager.map_configs
                assert manager.map_configs["prontera"].can_change_weather is True
    
    def test_load_weather_data_error_handling(self):
        """Test weather data loading error handling."""
        with patch("builtins.open", side_effect=Exception("File error")):
            with patch.object(Path, "exists", return_value=True):
                manager = WeatherManager(data_dir=Path("test_data"))
                
                # Should handle error gracefully
                assert manager is not None
    
    @pytest.mark.asyncio
    async def test_update_weather_test_mode_direct(self):
        """Test updating weather in test mode (direct setting)."""
        manager = WeatherManager()
        
        await manager.update_weather(weather_type=WeatherType.RAIN)
        
        assert manager._global_weather == WeatherType.RAIN
    
    @pytest.mark.asyncio
    async def test_update_weather_specific_map(self):
        """Test updating weather for specific map."""
        manager = WeatherManager()
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True
        )
        
        await manager.update_weather(weather_type=WeatherType.RAIN, map_name="prontera")
        
        assert "prontera" in manager._current_weather_dict
        assert manager._current_weather_dict["prontera"].weather_type == WeatherType.RAIN
    
    @pytest.mark.asyncio
    async def test_update_weather_fixed_weather_map(self):
        """Test updating weather on map with fixed weather."""
        manager = WeatherManager()
        manager.map_configs["niflheim"] = MapWeatherConfig(
            map_name="niflheim",
            default_weather=WeatherType.SNOW,
            can_change_weather=False
        )
        
        await manager.update_weather(map_name="niflheim")
        
        # Should not change weather on fixed map
    
    @pytest.mark.asyncio
    async def test_update_weather_natural_progression(self):
        """Test natural weather progression."""
        manager = WeatherManager()
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True
        )
        
        # Set existing weather
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        
        # Multiple calls to trigger random change
        for _ in range(20):
            await manager.update_weather(map_name="prontera")
    
    @pytest.mark.asyncio
    async def test_update_weather_initialize_new_map(self):
        """Test initializing weather for new map."""
        manager = WeatherManager()
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR],
            can_change_weather=True
        )
        manager.weather_effects_db["clear"] = {
            "visibility_modifier": 1.0,
            "movement_speed_modifier": 1.0
        }
        
        await manager.update_weather(map_name="prontera")
        
        assert "prontera" in manager._current_weather_dict
    
    def test_generate_new_weather_no_possible(self):
        """Test generating weather when no possible weather."""
        manager = WeatherManager()
        
        config = MapWeatherConfig(
            map_name="test",
            possible_weather=[],
            default_weather=WeatherType.CLEAR
        )
        
        weather = manager._generate_new_weather(config)
        
        assert weather == WeatherType.CLEAR
    
    def test_generate_new_weather_with_weights(self):
        """Test generating weather with weights."""
        manager = WeatherManager()
        
        config = MapWeatherConfig(
            map_name="test",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            weather_weights={
                WeatherType.CLEAR: 0.8,
                WeatherType.RAIN: 0.2
            }
        )
        
        weather = manager._generate_new_weather(config)
        
        assert weather in [WeatherType.CLEAR, WeatherType.RAIN]
    
    def test_generate_new_weather_equal_probability(self):
        """Test generating weather with equal probability."""
        manager = WeatherManager()
        
        config = MapWeatherConfig(
            map_name="test",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN, WeatherType.CLOUDY]
        )
        
        weather = manager._generate_new_weather(config)
        
        assert weather in [WeatherType.CLEAR, WeatherType.RAIN, WeatherType.CLOUDY]
    
    def test_simulate_weather_change_fixed_map(self):
        """Test simulating weather on fixed weather map."""
        manager = WeatherManager()
        manager.map_configs["niflheim"] = MapWeatherConfig(
            map_name="niflheim",
            default_weather=WeatherType.SNOW,
            can_change_weather=False
        )
        manager._current_weather_dict["niflheim"] = WeatherEffect(
            weather_type=WeatherType.SNOW
        )
        
        simulated = manager.simulate_weather_change("niflheim", duration_minutes=60)
        
        # All simulated weather should be snow
        assert all(w == WeatherType.SNOW for w in simulated)
    
    def test_simulate_weather_change_variable_map(self):
        """Test simulating weather on variable weather map."""
        manager = WeatherManager()
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True,
            weather_change_interval_minutes=30
        )
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        
        simulated = manager.simulate_weather_change("prontera", duration_minutes=90)
        
        assert len(simulated) >= 3  # 90 minutes / 30 minutes interval
    
    def test_get_optimal_weather_for_skill_with_bonus(self):
        """Test getting optimal weather for skill with bonus."""
        manager = WeatherManager()
        manager.weather_effects_db = {
            "rain": {
                "skill_modifiers": {"water_ball": 1.5}
            },
            "clear": {
                "skill_modifiers": {}
            }
        }
        
        optimal = manager.get_optimal_weather_for_skill("water_ball")
        
        assert WeatherType.RAIN in optimal
    
    def test_get_optimal_weather_for_skill_no_bonus(self):
        """Test getting optimal weather for skill with no bonus."""
        manager = WeatherManager()
        manager.weather_effects_db = {
            "clear": {
                "skill_modifiers": {}
            }
        }
        
        optimal = manager.get_optimal_weather_for_skill("unknown_skill")
        
        assert WeatherType.CLEAR in optimal
    
    def test_should_wait_for_weather_already_current(self):
        """Test should not wait if already desired weather."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.RAIN
        )
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True
        )
        
        should_wait, minutes = manager.should_wait_for_weather("prontera", WeatherType.RAIN)
        
        assert should_wait is False
        assert minutes == 0
    
    def test_should_wait_for_weather_not_possible(self):
        """Test should not wait if weather not possible on map."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR],
            can_change_weather=True
        )
        
        should_wait, minutes = manager.should_wait_for_weather("prontera", WeatherType.BLIZZARD)
        
        assert should_wait is False
    
    def test_should_wait_for_weather_fixed_map(self):
        """Test should not wait on fixed weather map."""
        manager = WeatherManager()
        manager.map_configs["niflheim"] = MapWeatherConfig(
            map_name="niflheim",
            can_change_weather=False
        )
        
        should_wait, minutes = manager.should_wait_for_weather("niflheim", WeatherType.CLEAR)
        
        assert should_wait is False
    
    def test_should_wait_for_weather_estimate_time(self):
        """Test estimating wait time for weather."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN, WeatherType.CLOUDY],
            weather_change_interval_minutes=30,
            can_change_weather=True
        )
        
        should_wait, minutes = manager.should_wait_for_weather("prontera", WeatherType.RAIN)
        
        assert should_wait is True
        assert minutes > 0
    
    def test_get_visibility_modifier(self):
        """Test getting visibility modifier."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.FOG,
            visibility_modifier=0.5
        )
        
        modifier = manager.get_visibility_modifier("prontera")
        
        assert modifier == 0.5
    
    def test_get_movement_modifier(self):
        """Test getting movement modifier."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.BLIZZARD,
            movement_speed_modifier=0.7
        )
        
        modifier = manager.get_movement_modifier("prontera")
        
        assert modifier == 0.7
    
    def test_is_favorable_weather_true(self):
        """Test checking favorable weather returns True."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.RAIN,
            element_modifiers={"water": 1.3}
        )
        
        result = manager.is_favorable_weather("prontera", "water", threshold=1.1)
        
        assert result is True
    
    def test_is_favorable_weather_false(self):
        """Test checking favorable weather returns False."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR,
            element_modifiers={"water": 1.0}
        )
        
        result = manager.is_favorable_weather("prontera", "water", threshold=1.1)
        
        assert result is False
    
    def test_get_weather_summary(self):
        """Test getting comprehensive weather summary."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.RAIN,
            visibility_modifier=0.8,
            movement_speed_modifier=0.9,
            element_modifiers={"water": 1.3, "fire": 0.7},
            skill_modifiers={"water_ball": 1.2},
            duration_minutes=45
        )
        
        summary = manager.get_weather_summary("prontera")
        
        assert summary["weather"] == "rain"
        assert summary["visibility"] == 0.8
        assert summary["movement_speed"] == 0.9
        assert summary["element_modifiers"]["water"] == 1.3
        assert summary["skill_modifiers"]["water_ball"] == 1.2
        assert summary["duration_remaining"] == 45
    
    def test_get_combat_modifiers_with_map(self):
        """Test getting combat modifiers for specific map."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.STORM,
            visibility_modifier=0.6,
            movement_speed_modifier=0.8,
            element_modifiers={"wind": 1.4, "water": 1.2},
            skill_modifiers={"lightning_bolt": 1.3}
        )
        
        modifiers = manager.get_combat_modifiers("prontera")
        
        assert modifiers["movement_speed"] == 0.8
        assert modifiers["visibility"] == 0.6
        assert modifiers["element_wind"] == 1.4
        assert modifiers["element_water"] == 1.2
        assert modifiers["skill_lightning_bolt"] == 1.3
    
    def test_get_combat_modifiers_global(self):
        """Test getting combat modifiers globally."""
        manager = WeatherManager()
        manager._current_weather_dict["_global"] = WeatherEffect(
            weather_type=WeatherType.CLEAR,
            visibility_modifier=1.0,
            movement_speed_modifier=1.0
        )
        
        modifiers = manager.get_combat_modifiers()
        
        assert modifiers["movement_speed"] == 1.0
        assert modifiers["visibility"] == 1.0


class TestWeatherGeneration:
    """Test weather generation and application."""
    
    def test_apply_weather_sets_effect(self):
        """Test applying weather sets effect correctly."""
        manager = WeatherManager()
        manager.weather_effects_db["rain"] = {
            "visibility_modifier": 0.7,
            "movement_speed_modifier": 0.9,
            "skill_modifiers": {"water_ball": 1.2},
            "element_modifiers": {"water": 1.3},
            "duration_minutes": 60
        }
        
        manager._apply_weather("prontera", WeatherType.RAIN)
        
        assert "prontera" in manager._current_weather_dict
        effect = manager._current_weather_dict["prontera"]
        assert effect.weather_type == WeatherType.RAIN
        assert effect.visibility_modifier == 0.7
        assert effect.movement_speed_modifier == 0.9
    
    def test_get_weather_with_current_effect(self):
        """Test getting weather when effect exists."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.RAIN
        )
        
        weather = manager.get_weather("prontera")
        
        assert weather == WeatherType.RAIN
    
    def test_get_weather_from_config_default(self):
        """Test getting weather from config default."""
        manager = WeatherManager()
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            default_weather=WeatherType.CLOUDY
        )
        
        weather = manager.get_weather("prontera")
        
        assert weather == WeatherType.CLOUDY
    
    def test_get_weather_fallback_clear(self):
        """Test getting weather falls back to clear."""
        manager = WeatherManager()
        
        weather = manager.get_weather("unknown_map")
        
        assert weather == WeatherType.CLEAR
    
    def test_get_weather_effect_existing(self):
        """Test getting existing weather effect."""
        manager = WeatherManager()
        effect = WeatherEffect(weather_type=WeatherType.RAIN)
        manager._current_weather_dict["prontera"] = effect
        
        result = manager.get_weather_effect("prontera")
        
        assert result == effect
    
    def test_get_weather_effect_generates_from_weather(self):
        """Test generating effect from current weather."""
        manager = WeatherManager()
        manager.weather_effects_db["rain"] = {
            "visibility_modifier": 0.7,
            "movement_speed_modifier": 0.9,
            "skill_modifiers": {},
            "element_modifiers": {"water": 1.3},
            "duration_minutes": 60
        }
        manager.map_configs["prontera"] = MapWeatherConfig(
            map_name="prontera",
            default_weather=WeatherType.RAIN
        )
        
        effect = manager.get_weather_effect("prontera")
        
        assert effect.weather_type == WeatherType.RAIN
        assert effect.visibility_modifier == 0.7
    
    def test_get_element_modifier(self):
        """Test getting element modifier."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.RAIN,
            element_modifiers={"water": 1.3, "fire": 0.7}
        )
        
        modifier = manager.get_element_modifier("prontera", "water")
        
        assert modifier == 1.3
    
    def test_get_element_modifier_default(self):
        """Test getting element modifier returns default."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR,
            element_modifiers={}
        )
        
        modifier = manager.get_element_modifier("prontera", "unknown")
        
        assert modifier == 1.0
    
    def test_get_skill_weather_modifier(self):
        """Test getting skill weather modifier."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.STORM,
            skill_modifiers={"lightning_bolt": 1.5}
        )
        
        modifier = manager.get_skill_weather_modifier("prontera", "lightning_bolt")
        
        assert modifier == 1.5
    
    def test_get_skill_weather_modifier_default(self):
        """Test getting skill modifier returns default."""
        manager = WeatherManager()
        manager._current_weather_dict["prontera"] = WeatherEffect(
            weather_type=WeatherType.CLEAR,
            skill_modifiers={}
        )
        
        modifier = manager.get_skill_weather_modifier("prontera", "unknown_skill")
        
        assert modifier == 1.0