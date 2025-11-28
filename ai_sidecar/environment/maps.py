"""
Map Environment System for OpenKore AI Sidecar.

Manages map-specific environmental properties including type, environment,
time/weather effects, access restrictions, and modifiers.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.environment.day_night import DayNightManager
from ai_sidecar.environment.time_core import GamePeriod, TimeManager
from ai_sidecar.environment.weather import WeatherManager, WeatherType


class MapType(str, Enum):
    """Map types in RO."""

    TOWN = "town"
    FIELD = "field"
    DUNGEON = "dungeon"
    INSTANCE = "instance"
    PVP = "pvp"
    WOE = "woe"
    BATTLEGROUND = "battleground"


class MapEnvironment(str, Enum):
    """Map environment types affecting gameplay."""

    OUTDOOR = "outdoor"  # Affected by day/night and weather
    INDOOR = "indoor"  # Fixed lighting
    UNDERGROUND = "underground"  # Always dark
    UNDERWATER = "underwater"  # Water effects
    VOLCANIC = "volcanic"  # Fire effects
    FROZEN = "frozen"  # Ice effects
    DESERT = "desert"  # Heat effects


class MapProperties(BaseModel):
    """Map environmental properties."""

    map_name: str
    map_type: MapType = MapType.FIELD
    environment: MapEnvironment = MapEnvironment.OUTDOOR

    # Time effects
    has_day_night: bool = True
    has_weather: bool = True

    # Fixed conditions
    fixed_time_period: Optional[GamePeriod] = None
    fixed_weather: Optional[WeatherType] = None

    # Restrictions
    level_requirement: int = Field(default=0, ge=0)
    quest_requirement: Optional[int] = None
    time_restriction: Optional[Dict[str, Any]] = None

    # Modifiers
    exp_modifier: float = Field(default=1.0, ge=0.0)
    drop_modifier: float = Field(default=1.0, ge=0.0)
    movement_modifier: float = Field(default=1.0, ge=0.0)


class MapEnvironmentManager:
    """
    Manage map-specific environmental effects.

    Features:
    - Map property lookup
    - Time/weather effects per map
    - Access restrictions
    - Optimal farming recommendations
    """

    def __init__(
        self,
        data_dir: Path,
        time_manager: TimeManager,
        day_night_manager: DayNightManager,
        weather_manager: WeatherManager,
    ):
        """
        Initialize MapEnvironmentManager.

        Args:
            data_dir: Directory containing map configuration files
            time_manager: TimeManager instance
            day_night_manager: DayNightManager instance
            weather_manager: WeatherManager instance
        """
        self.log = structlog.get_logger()
        self.time_manager = time_manager
        self.day_night = day_night_manager
        self.weather = weather_manager
        self.map_properties: Dict[str, MapProperties] = {}
        self._load_map_data(data_dir)

    def _load_map_data(self, data_dir: Path) -> None:
        """
        Load map property data.

        Args:
            data_dir: Data directory path
        """
        try:
            maps_file = data_dir / "map_environments.json"
            if maps_file.exists():
                with open(maps_file, "r") as f:
                    data = json.load(f)

                    maps_data = data.get("maps", {})
                    for map_name, map_config in maps_data.items():
                        # Parse fixed time/weather if present
                        fixed_time = map_config.get("fixed_time_period")
                        if fixed_time:
                            fixed_time = GamePeriod(fixed_time)

                        fixed_weather = map_config.get("fixed_weather")
                        if fixed_weather:
                            fixed_weather = WeatherType(fixed_weather)

                        properties = MapProperties(
                            map_name=map_name,
                            map_type=MapType(map_config.get("map_type", "field")),
                            environment=MapEnvironment(
                                map_config.get("environment", "outdoor")
                            ),
                            has_day_night=map_config.get("has_day_night", True),
                            has_weather=map_config.get("has_weather", True),
                            fixed_time_period=fixed_time,
                            fixed_weather=fixed_weather,
                            level_requirement=map_config.get("level_requirement", 0),
                            quest_requirement=map_config.get("quest_requirement"),
                            exp_modifier=map_config.get("exp_modifier", 1.0),
                            drop_modifier=map_config.get("drop_modifier", 1.0),
                            movement_modifier=map_config.get("movement_modifier", 1.0),
                        )

                        self.map_properties[map_name] = properties

            self.log.info("map_data_loaded", count=len(self.map_properties))
        except Exception as e:
            self.log.error("failed_to_load_map_data", error=str(e))

    def get_map_properties(self, map_name: str) -> Optional[MapProperties]:
        """
        Get properties for a map.

        Args:
            map_name: Map name

        Returns:
            MapProperties or None if not found
        """
        return self.map_properties.get(map_name)

    def get_effective_time_period(self, map_name: str) -> GamePeriod:
        """
        Get effective time period for map (considering overrides).

        Args:
            map_name: Map name

        Returns:
            Effective GamePeriod
        """
        props = self.get_map_properties(map_name)

        if props and props.fixed_time_period:
            return props.fixed_time_period

        if props and not props.has_day_night:
            # Indoor/underground maps default to specific periods
            if props.environment == MapEnvironment.UNDERGROUND:
                return GamePeriod.NIGHT
            return GamePeriod.NOON

        return self.time_manager.get_current_period()

    def get_effective_weather(self, map_name: str) -> WeatherType:
        """
        Get effective weather for map.

        Args:
            map_name: Map name

        Returns:
            Effective WeatherType
        """
        props = self.get_map_properties(map_name)

        if props and props.fixed_weather:
            return props.fixed_weather

        if props and not props.has_weather:
            return WeatherType.CLEAR

        return self.weather.get_weather(map_name)

    def can_access_map(
        self, map_name: str, character_state: dict
    ) -> Tuple[bool, str]:
        """
        Check if character can access map.

        Args:
            map_name: Map name
            character_state: Character state dictionary

        Returns:
            Tuple of (can_access, reason)
        """
        props = self.get_map_properties(map_name)
        if not props:
            return True, "No restrictions"

        # Check level requirement
        char_level = character_state.get("level", 1)
        if char_level < props.level_requirement:
            return False, f"Level {props.level_requirement} required"

        # Check quest requirement
        if props.quest_requirement:
            completed_quests = character_state.get("completed_quests", [])
            if props.quest_requirement not in completed_quests:
                return (
                    False,
                    f"Quest {props.quest_requirement} required",
                )

        # Check time restrictions
        if props.time_restriction:
            # Check if current time is within allowed windows
            # Implementation depends on restriction format
            pass

        return True, "Access granted"

    def get_combined_modifiers(self, map_name: str) -> Dict[str, float]:
        """
        Get all active modifiers for a map.

        Args:
            map_name: Map name

        Returns:
            Dictionary of modifier types to values
        """
        modifiers = {
            "exp": 1.0,
            "drop": 1.0,
            "movement": 1.0,
            "spawn_rate": 1.0,
            "visibility": 1.0,
        }

        # Map base modifiers
        props = self.get_map_properties(map_name)
        if props:
            modifiers["exp"] *= props.exp_modifier
            modifiers["drop"] *= props.drop_modifier
            modifiers["movement"] *= props.movement_modifier

        # Day/night modifiers
        if props and props.has_day_night:
            day_night_mods = self.day_night.get_phase_modifiers()
            modifiers["exp"] *= day_night_mods.exp_modifier
            modifiers["drop"] *= day_night_mods.drop_modifier
            modifiers["spawn_rate"] *= day_night_mods.monster_spawn_rate
            modifiers["visibility"] *= day_night_mods.visibility_range

        # Weather modifiers
        if props and props.has_weather:
            weather_effect = self.weather.get_weather_effect(map_name)
            modifiers["movement"] *= weather_effect.movement_speed_modifier
            modifiers["visibility"] *= weather_effect.visibility_modifier

        return modifiers

    def get_optimal_maps_for_time(
        self, current_time: Any, target_type: str
    ) -> List[str]:
        """
        Get optimal maps for current time (farming/grinding).

        Args:
            current_time: Current game time
            target_type: Type of activity ("farming", "grinding", "questing")

        Returns:
            List of recommended map names
        """
        optimal = []
        is_night = not self.time_manager.is_daytime()

        for map_name, props in self.map_properties.items():
            # Skip restricted maps
            if props.map_type in [MapType.PVP, MapType.WOE]:
                continue

            # Get combined modifiers
            mods = self.get_combined_modifiers(map_name)

            # Calculate score based on target type
            score = 0.0
            if target_type == "farming":
                score = mods["exp"] + mods["drop"]
            elif target_type == "grinding":
                score = mods["exp"] * 2  # Prioritize EXP
            elif target_type == "questing":
                score = 1.0  # All maps equal for quests

            # Bonus for good visibility
            score *= mods["visibility"]

            if score > 1.2:  # At least 20% bonus
                optimal.append((map_name, score))

        # Sort by score
        optimal.sort(key=lambda x: x[1], reverse=True)
        return [name for name, _ in optimal[:10]]

    def get_maps_with_condition(
        self,
        weather: Optional[WeatherType] = None,
        time_period: Optional[GamePeriod] = None,
        map_type: Optional[MapType] = None,
    ) -> List[str]:
        """
        Find maps matching specific conditions.

        Args:
            weather: Desired weather type
            time_period: Desired time period
            map_type: Desired map type

        Returns:
            List of matching map names
        """
        matching = []

        for map_name, props in self.map_properties.items():
            # Check map type
            if map_type and props.map_type != map_type:
                continue

            # Check time period
            if time_period:
                effective_time = self.get_effective_time_period(map_name)
                if effective_time != time_period:
                    continue

            # Check weather
            if weather:
                effective_weather = self.get_effective_weather(map_name)
                if effective_weather != weather:
                    continue

            matching.append(map_name)

        return matching

    def is_safe_zone(self, map_name: str) -> bool:
        """
        Check if map is a safe zone (no PvP/monsters).

        Args:
            map_name: Map name

        Returns:
            True if safe zone
        """
        props = self.get_map_properties(map_name)
        if not props:
            return False

        return props.map_type == MapType.TOWN

    def get_map_difficulty(self, map_name: str) -> str:
        """
        Estimate map difficulty based on properties.

        Args:
            map_name: Map name

        Returns:
            Difficulty rating (easy, normal, hard, extreme)
        """
        props = self.get_map_properties(map_name)
        if not props:
            return "unknown"

        if props.level_requirement >= 100:
            return "extreme"
        elif props.level_requirement >= 70:
            return "hard"
        elif props.level_requirement >= 40:
            return "normal"
        else:
            return "easy"

    def get_environment_summary(self, map_name: str) -> Dict[str, Any]:
        """
        Get comprehensive environment summary for a map.

        Args:
            map_name: Map name

        Returns:
            Environment summary dictionary
        """
        props = self.get_map_properties(map_name)
        if not props:
            return {"error": "Map not found"}

        return {
            "map_name": map_name,
            "map_type": props.map_type.value,
            "environment": props.environment.value,
            "time_period": self.get_effective_time_period(map_name).value,
            "weather": self.get_effective_weather(map_name).value,
            "has_day_night": props.has_day_night,
            "has_weather": props.has_weather,
            "modifiers": self.get_combined_modifiers(map_name),
            "difficulty": self.get_map_difficulty(map_name),
            "is_safe_zone": self.is_safe_zone(map_name),
        }