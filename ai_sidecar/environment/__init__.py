"""
Environment Systems for OpenKore AI Sidecar.

This package provides comprehensive time-sensitive and environmental systems:
- Time management and game time calculations
- Day/night cycle with gameplay effects
- Weather systems affecting skills and elements
- Seasonal event detection and optimization
- Map environment properties and restrictions
- Environmental coordination and decision making

Phase 9J of the God-Tier RO AI System.
"""

from ai_sidecar.environment.coordinator import EnvironmentCoordinator
from ai_sidecar.environment.time_core import (
    DayType,
    GamePeriod,
    GameTime,
    Season,
    ServerResetType,
    TimeManager,
)
from ai_sidecar.environment.day_night import (
    DayNightManager,
    DayNightPhase,
    PhaseModifiers,
)
from ai_sidecar.environment.weather import (
    MapWeatherConfig,
    WeatherEffect,
    WeatherManager,
    WeatherType,
)
from ai_sidecar.environment.events import (
    EventManager,
    EventQuest,
    EventReward,
    EventType,
    SeasonalEvent,
)
from ai_sidecar.environment.maps import (
    MapEnvironment,
    MapEnvironmentManager,
    MapProperties,
    MapType,
)

__all__ = [
    # Main coordinator
    "EnvironmentCoordinator",
    # Time core
    "DayType",
    "GamePeriod",
    "GameTime",
    "Season",
    "ServerResetType",
    "TimeManager",
    # Day/Night
    "DayNightManager",
    "DayNightPhase",
    "PhaseModifiers",
    # Weather
    "MapWeatherConfig",
    "WeatherEffect",
    "WeatherManager",
    "WeatherType",
    # Events
    "EventManager",
    "EventQuest",
    "EventReward",
    "EventType",
    "SeasonalEvent",
    # Maps
    "MapEnvironment",
    "MapEnvironmentManager",
    "MapProperties",
    "MapType",
]

__version__ = "1.0.0"