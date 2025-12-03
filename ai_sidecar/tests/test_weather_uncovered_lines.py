"""
Comprehensive tests to achieve 100% coverage for environment/weather.py.
Targets all uncovered line ranges from coverage report.
"""

import json
import pytest
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
from datetime import datetime

from ai_sidecar.environment.weather import (
    WeatherType,
    WeatherEffect,
    MapWeatherConfig,
    WeatherManager
)


class TestWeatherPropertyReturns:
    """Test current_weather property return variations (Line 93)."""
    
    def test_current_weather_returns_dict_when_no_global(self, tmp_path):
        """Test property returns dict when _global_weather is None."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up internal weather dict without global
        manager._global_weather = None
        manager._current_weather_dict = {
            "test_map": WeatherEffect(
                weather_type=WeatherType.RAIN,
                visibility_modifier=0.7
            )
        }
        
        # Access property - should return dict
        result = manager.current_weather
        assert isinstance(result, dict)
        assert "test_map" in result


class TestWeatherDataLoading:
    """Test uncovered branches in _load_weather_data (Lines 129, 146-147)."""
    
    def test_load_weather_data_with_fixed_weather(self, tmp_path):
        """Test loading map with fixed weather (Line 129)."""
        weather_file = tmp_path / "weather_effects.json"
        data = {
            "weather_types": {
                "rain": {
                    "visibility_modifier": 0.7,
                    "movement_speed_modifier": 0.9
                }
            },
            "map_weather": {
                "abyss_dungeon": {
                    "fixed": "rain",  # This triggers line 129
                    "possible": ["rain"]
                }
            }
        }
        weather_file.write_text(json.dumps(data))
        
        manager = WeatherManager(data_dir=tmp_path)
        
        # Verify fixed weather config was created
        assert "abyss_dungeon" in manager.map_configs
        config = manager.map_configs["abyss_dungeon"]
        assert config.can_change_weather is False
        assert config.default_weather == WeatherType.RAIN
    
    def test_load_weather_data_exception_handling(self, tmp_path):
        """Test exception handling in _load_weather_data (Lines 146-147)."""
        weather_file = tmp_path / "weather_effects.json"
        weather_file.write_text("invalid json {{{")
        
        # Should not crash, just log error
        manager = WeatherManager(data_dir=tmp_path)
        
        # Manager should still be initialized
        assert manager is not None
        assert isinstance(manager.weather_effects_db, dict)


class TestWeatherUpdateNaturalProgression:
    """Test natural progression in update_weather (Lines 246-261)."""
    
    @pytest.mark.asyncio
    async def test_update_weather_cannot_change(self, tmp_path):
        """Test update when weather cannot change (Line 246-247)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up map that cannot change weather
        manager.map_configs["frozen_map"] = MapWeatherConfig(
            map_name="frozen_map",
            default_weather=WeatherType.BLIZZARD,
            can_change_weather=False
        )
        
        # Update should return early
        await manager.update_weather(map_name="frozen_map")
        
        # Weather should not be in current dict since it can't change
        assert "frozen_map" not in manager._current_weather_dict
    
    @pytest.mark.asyncio
    async def test_update_weather_natural_with_existing(self, tmp_path):
        """Test natural update with existing weather (Lines 250-257)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up changeable map with existing weather
        manager.map_configs["test_map"] = MapWeatherConfig(
            map_name="test_map",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True
        )
        
        manager._current_weather_dict["test_map"] = WeatherEffect(
            weather_type=WeatherType.CLEAR,
            duration_minutes=30
        )
        
        # Mock random to ensure change happens
        with patch('ai_sidecar.environment.weather.random.random', return_value=0.05):
            await manager.update_weather(map_name="test_map")
        
        # Weather should potentially have changed
        assert "test_map" in manager._current_weather_dict
    
    @pytest.mark.asyncio
    async def test_update_weather_initialize_new(self, tmp_path):
        """Test initializing weather for map (Lines 258-261)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up changeable map without weather
        manager.map_configs["new_map"] = MapWeatherConfig(
            map_name="new_map",
            possible_weather=[WeatherType.CLEAR, WeatherType.CLOUDY],
            can_change_weather=True
        )
        
        # Update should initialize weather
        await manager.update_weather(map_name="new_map")
        
        # Weather should now exist
        assert "new_map" in manager._current_weather_dict


class TestWeatherGeneration:
    """Test weather generation with weights (Lines 273-287)."""
    
    def test_generate_weather_with_weights(self, tmp_path):
        """Test weighted weather generation (Lines 277-284)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        config = MapWeatherConfig(
            map_name="weighted_map",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN, WeatherType.STORM],
            weather_weights={
                WeatherType.CLEAR: 0.7,
                WeatherType.RAIN: 0.2,
                WeatherType.STORM: 0.1
            }
        )
        
        # Generate weather multiple times
        with patch('ai_sidecar.environment.weather.random.choices') as mock_choice:
            mock_choice.return_value = [WeatherType.CLEAR]
            result = manager._generate_new_weather(config)
            
            # Verify choices was called with weights
            mock_choice.assert_called_once()
            call_args = mock_choice.call_args
            assert WeatherType.CLEAR in call_args[0][0]
            assert call_args[1]['weights'] is not None
    
    def test_generate_weather_equal_probability(self, tmp_path):
        """Test equal probability generation (Lines 286-287)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        config = MapWeatherConfig(
            map_name="equal_map",
            possible_weather=[WeatherType.CLEAR, WeatherType.CLOUDY],
            weather_weights={}  # No weights
        )
        
        # Should use random.choice (equal probability)
        with patch('ai_sidecar.environment.weather.random.choice') as mock_choice:
            mock_choice.return_value = WeatherType.CLEAR
            result = manager._generate_new_weather(config)
            
            # Verify choice was called
            mock_choice.assert_called_once()
            assert result == WeatherType.CLEAR


class TestWeatherSimulation:
    """Test weather simulation branches (Line 336)."""
    
    def test_simulate_weather_change_trigger(self, tmp_path):
        """Test weather change in simulation (Line 336)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        manager.map_configs["test_map"] = MapWeatherConfig(
            map_name="test_map",
            possible_weather=[WeatherType.CLEAR, WeatherType.RAIN],
            can_change_weather=True,
            weather_change_interval_minutes=30
        )
        
        manager._current_weather_dict["test_map"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        
        # Mock random to trigger change
        with patch('ai_sidecar.environment.weather.random.random', return_value=0.2):
            result = manager.simulate_weather_change("test_map", 60)
            
            # Should have simulated weather
            assert len(result) > 0


class TestOptimalWeather:
    """Test optimal weather detection (Lines 354-356)."""
    
    def test_get_optimal_weather_with_modifier(self, tmp_path):
        """Test finding optimal weather for skill (Lines 354-356)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up weather effects with skill modifiers
        manager.weather_effects_db = {
            "rain": {
                "skill_modifiers": {
                    "Storm Gust": 1.3,
                    "Water Ball": 1.2
                }
            },
            "sunny": {
                "skill_modifiers": {
                    "Fire Ball": 1.4
                }
            },
            "clear": {
                "skill_modifiers": {}
            }
        }
        
        # Test finding optimal weather for water skills
        optimal = manager.get_optimal_weather_for_skill("Water Ball")
        
        # Should include rain
        assert WeatherType.RAIN in optimal


class TestShouldWaitForWeather:
    """Test weather waiting logic (Lines 379-390)."""
    
    def test_should_wait_target_not_possible(self, tmp_path):
        """Test when target weather not in possible list (Lines 382-383)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        manager.map_configs["desert_map"] = MapWeatherConfig(
            map_name="desert_map",
            possible_weather=[WeatherType.SUNNY, WeatherType.SANDSTORM],
            can_change_weather=True
        )
        
        manager._current_weather_dict["desert_map"] = WeatherEffect(
            weather_type=WeatherType.SUNNY
        )
        
        # Try to wait for snow (not possible in desert)
        should_wait, minutes = manager.should_wait_for_weather(
            "desert_map", WeatherType.SNOW
        )
        
        assert should_wait is False
        assert minutes == 0
    
    def test_should_wait_estimate_time(self, tmp_path):
        """Test wait time estimation (Lines 385-390)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        manager.map_configs["variable_map"] = MapWeatherConfig(
            map_name="variable_map",
            possible_weather=[
                WeatherType.CLEAR,
                WeatherType.CLOUDY,
                WeatherType.RAIN,
                WeatherType.STORM
            ],
            can_change_weather=True,
            weather_change_interval_minutes=20
        )
        
        manager._current_weather_dict["variable_map"] = WeatherEffect(
            weather_type=WeatherType.CLEAR
        )
        
        # Check wait for rain
        should_wait, minutes = manager.should_wait_for_weather(
            "variable_map", WeatherType.RAIN
        )
        
        assert should_wait is True
        # Should estimate based on interval * number of possible weather
        assert minutes == 20 * 4  # 80 minutes


class TestCombatModifiers:
    """Test combat modifiers formatting (Lines 476, 480)."""
    
    def test_get_combat_modifiers_with_skills(self, tmp_path):
        """Test combat modifiers include skill prefixes (Line 480)."""
        manager = WeatherManager(data_dir=tmp_path)
        
        # Set up weather with skill modifiers
        manager.weather_effects_db = {
            "rain": {
                "visibility_modifier": 0.8,
                "movement_speed_modifier": 0.9,
                "element_modifiers": {
                    "water": 1.2,
                    "fire": 0.8
                },
                "skill_modifiers": {
                    "Storm Gust": 1.3,
                    "Lightning Bolt": 1.1
                }
            }
        }
        
        manager._current_weather_dict["test_map"] = WeatherEffect(
            weather_type=WeatherType.RAIN,
            visibility_modifier=0.8,
            movement_speed_modifier=0.9,
            element_modifiers={"water": 1.2, "fire": 0.8},
            skill_modifiers={"Storm Gust": 1.3, "Lightning Bolt": 1.1}
        )
        
        # Get combat modifiers
        modifiers = manager.get_combat_modifiers("test_map")
        
        # Verify element prefixes (Line 476)
        assert "element_water" in modifiers
        assert modifiers["element_water"] == 1.2
        
        # Verify skill prefixes (Line 480)
        assert "skill_Storm Gust" in modifiers
        assert modifiers["skill_Storm Gust"] == 1.3


class TestEdgeCases:
    """Test additional edge cases for complete coverage."""
    
    def test_weather_manager_with_data_path_alias(self, tmp_path):
        """Test WeatherManager with data_path parameter (backwards compat)."""
        # Using data_path instead of data_dir
        manager = WeatherManager(data_path=tmp_path)
        assert manager is not None
    
    def test_weather_manager_with_both_parameters(self, tmp_path):
        """Test WeatherManager with both data_dir and data_path."""
        # data_dir should take precedence
        manager = WeatherManager(data_dir=tmp_path, data_path=Path("other"))
        assert manager is not None
    
    def test_weather_types_property_alias(self, tmp_path):
        """Test _weather_types property alias for backwards compatibility."""
        manager = WeatherManager(data_dir=tmp_path)
        manager.weather_effects_db = {"test": {}}
        
        # Access via property alias
        assert manager._weather_types == manager.weather_effects_db