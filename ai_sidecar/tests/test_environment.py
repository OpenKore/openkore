"""
Comprehensive tests for Environmental Systems.

Tests time management, day/night cycles, weather effects,
seasonal events, map environments, and environmental coordination.
"""

from datetime import datetime, timedelta
from pathlib import Path

import pytest

from ai_sidecar.environment import (
    DayNightManager,
    DayNightPhase,
    EnvironmentCoordinator,
    EventManager,
    EventType,
    GamePeriod,
    MapEnvironment,
    MapEnvironmentManager,
    MapType,
    Season,
    ServerResetType,
    TimeManager,
    WeatherManager,
    WeatherType,
)


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test configs."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()

    # Create minimal test configs
    time_config = {
        "periods": {
            "dawn": {"start_hour": 5, "end_hour": 6, "is_day": True},
            "morning": {"start_hour": 7, "end_hour": 11, "is_day": True},
            "night": {"start_hour": 0, "end_hour": 4, "is_day": False},
        },
        "game_time_ratio": 4,
        "real_hours_per_game_day": 6,
    }

    day_night_config = {
        "phases": {
            "night": {
                "monster_spawn_rate": 1.2,
                "visibility_range": 0.7,
                "skill_modifiers": {"Moon Slasher": 1.5},
            },
            "day": {"monster_spawn_rate": 1.0, "skill_modifiers": {"Sunshine": 1.5}},
        },
        "night_only_monsters": {"prt_fild01": ["Nightmare"]},
        "day_only_monsters": {"prt_fild08": ["Poring"]},
    }

    weather_config = {
        "weather_types": {
            "rain": {
                "visibility_modifier": 0.8,
                "element_modifiers": {"water": 1.2, "fire": 0.8},
                "skill_modifiers": {"Water Ball": 1.3},
            }
        },
        "map_weather": {
            "prt_fild08": {"possible": ["clear", "rain"], "default": "clear"}
        },
    }

    events_config = {
        "events": {
            "test_event": {
                "event_type": "custom",
                "event_name": "Test Event",
                "start_month": 12,
                "start_day": 1,
                "end_month": 12,
                "end_day": 31,
                "is_recurring": True,
                "exp_bonus": 1.5,
                "drop_bonus": 1.3,
                "special_quests": ["test_quest"],
            }
        }
    }

    maps_config = {
        "maps": {
            "prontera": {
                "map_type": "town",
                "environment": "outdoor",
                "has_day_night": True,
                "has_weather": True,
                "level_requirement": 0,
            },
            "gl_prison": {
                "map_type": "dungeon",
                "environment": "underground",
                "has_day_night": False,
                "fixed_time_period": "night",
                "level_requirement": 40,
            },
        }
    }

    # Write config files
    import json

    with open(data_dir / "time_periods.json", "w") as f:
        json.dump(time_config, f)
    with open(data_dir / "day_night_modifiers.json", "w") as f:
        json.dump(day_night_config, f)
    with open(data_dir / "weather_effects.json", "w") as f:
        json.dump(weather_config, f)
    with open(data_dir / "seasonal_events.json", "w") as f:
        json.dump(events_config, f)
    with open(data_dir / "map_environments.json", "w") as f:
        json.dump(maps_config, f)

    return data_dir


class TestTimeManager:
    """Test time management functionality."""

    def test_initialization(self, data_dir: Path) -> None:
        """Test TimeManager initialization."""
        manager = TimeManager(data_dir, server_timezone=8)
        assert manager.server_timezone == 8
        assert manager.data_dir == data_dir

    def test_game_time_calculation(self, data_dir: Path) -> None:
        """Test game time calculation from server time."""
        manager = TimeManager(data_dir)

        # Test at specific server times
        test_time = datetime(2024, 1, 1, 12, 0, 0)  # Noon
        game_time = manager.calculate_game_time(test_time)

        assert 0 <= game_time.game_hour <= 23
        assert 0 <= game_time.game_minute <= 59
        assert game_time.period in GamePeriod

    def test_period_detection(self, data_dir: Path) -> None:
        """Test time period detection."""
        manager = TimeManager(data_dir)

        # Test morning detection
        morning_time = datetime(2024, 1, 1, 9, 0, 0)
        game_time = manager.calculate_game_time(morning_time)
        # Due to 4:1 ratio, 9 AM real = 36 game hours = 12 PM game
        assert game_time.period in GamePeriod

    def test_daytime_detection(self, data_dir: Path) -> None:
        """Test daytime/nighttime detection."""
        manager = TimeManager(data_dir)
        
        # Test will vary based on current real time
        is_day = manager.is_daytime()
        is_night = manager.is_nighttime()
        assert is_day != is_night  # Must be one or the other

    def test_reset_time_calculation(self, data_dir: Path) -> None:
        """Test server reset time calculations."""
        manager = TimeManager(data_dir)

        # Test daily reset
        daily_time = manager.get_time_until_reset(ServerResetType.DAILY)
        assert isinstance(daily_time, timedelta)
        assert daily_time.total_seconds() >= 0

        # Test weekly reset
        weekly_time = manager.get_time_until_reset(ServerResetType.WEEKLY)
        assert isinstance(weekly_time, timedelta)

    def test_season_detection(self, data_dir: Path) -> None:
        """Test season detection from month."""
        manager = TimeManager(data_dir)

        season = manager.get_current_season()
        assert season in Season


class TestDayNightManager:
    """Test day/night cycle system."""

    def test_initialization(self, data_dir: Path) -> None:
        """Test DayNightManager initialization."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        assert len(manager.phase_modifiers) > 0
        assert isinstance(manager.night_monsters, dict)

    def test_phase_detection(self, data_dir: Path) -> None:
        """Test detailed phase detection."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        phase = manager.get_current_phase()
        assert phase in DayNightPhase

    def test_phase_modifiers(self, data_dir: Path) -> None:
        """Test phase modifier application."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        modifiers = manager.get_phase_modifiers()
        assert modifiers.monster_spawn_rate >= 0
        assert modifiers.visibility_range >= 0

    def test_skill_modifiers(self, data_dir: Path) -> None:
        """Test skill modifiers by time."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        moon_mod = manager.get_skill_modifier("Moon Slasher")
        assert moon_mod >= 0

    def test_monster_availability(self, data_dir: Path) -> None:
        """Test time-based monster spawns."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        available = manager.get_monster_availability("prt_fild01", "Nightmare")
        assert isinstance(available, bool)

    def test_farming_spot_switch(self, data_dir: Path) -> None:
        """Test farming spot switch recommendations."""
        time_mgr = TimeManager(data_dir)
        manager = DayNightManager(data_dir, time_mgr)

        should_switch, recommended = manager.should_switch_farming_spot("prt_fild08")
        assert isinstance(should_switch, bool)


class TestWeatherManager:
    """Test weather system."""

    def test_initialization(self, data_dir: Path) -> None:
        """Test WeatherManager initialization."""
        time_mgr = TimeManager(data_dir)
        manager = WeatherManager(data_dir, time_mgr)

        assert len(manager.weather_effects_db) > 0
        assert isinstance(manager.map_configs, dict)

    def test_weather_effects(self, data_dir: Path) -> None:
        """Test weather effect calculations."""
        time_mgr = TimeManager(data_dir)
        manager = WeatherManager(data_dir, time_mgr)

        effect = manager.get_weather_effect("prt_fild08")
        assert effect.weather_type in WeatherType
        assert 0 <= effect.visibility_modifier <= 1.0

    def test_element_modifiers(self, data_dir: Path) -> None:
        """Test elemental modifiers from weather."""
        time_mgr = TimeManager(data_dir)
        manager = WeatherManager(data_dir, time_mgr)

        water_mod = manager.get_element_modifier("prt_fild08", "water")
        assert water_mod >= 0

    def test_skill_weather_modifier(self, data_dir: Path) -> None:
        """Test skill modifiers from weather."""
        time_mgr = TimeManager(data_dir)
        manager = WeatherManager(data_dir, time_mgr)

        skill_mod = manager.get_skill_weather_modifier("prt_fild08", "Water Ball")
        assert skill_mod >= 0

    def test_weather_simulation(self, data_dir: Path) -> None:
        """Test weather change simulation."""
        time_mgr = TimeManager(data_dir)
        manager = WeatherManager(data_dir, time_mgr)

        simulated = manager.simulate_weather_change("prt_fild08", 60)
        assert len(simulated) > 0
        assert all(w in WeatherType for w in simulated)


class TestEventManager:
    """Test event system."""

    def test_initialization(self, data_dir: Path) -> None:
        """Test EventManager initialization."""
        time_mgr = TimeManager(data_dir)
        manager = EventManager(data_dir, time_mgr)

        assert len(manager.events) > 0

    def test_event_detection(self, data_dir: Path) -> None:
        """Test active event detection."""
        time_mgr = TimeManager(data_dir)
        manager = EventManager(data_dir, time_mgr)

        active = manager.get_active_events()
        assert isinstance(active, list)

    def test_event_timing(self, data_dir: Path) -> None:
        """Test event time remaining calculation."""
        time_mgr = TimeManager(data_dir)
        manager = EventManager(data_dir, time_mgr)

        if manager.events:
            event_id = list(manager.events.keys())[0]
            time_remaining = manager.get_event_time_remaining(event_id)
            # May be None if not active
            if time_remaining:
                assert isinstance(time_remaining, timedelta)

    def test_event_bonuses(self, data_dir: Path) -> None:
        """Test event bonus calculations."""
        time_mgr = TimeManager(data_dir)
        manager = EventManager(data_dir, time_mgr)

        exp_bonus = manager.get_event_exp_bonus()
        drop_bonus = manager.get_event_drop_bonus()

        assert exp_bonus >= 1.0
        assert drop_bonus >= 1.0

    def test_quest_tracking(self, data_dir: Path) -> None:
        """Test quest completion tracking."""
        time_mgr = TimeManager(data_dir)
        manager = EventManager(data_dir, time_mgr)

        if manager.events:
            event_id = list(manager.events.keys())[0]
            manager.mark_quest_complete(event_id, 12345)
            assert event_id in manager.completed_quests
            assert 12345 in manager.completed_quests[event_id]


class TestMapEnvironmentManager:
    """Test map environment management."""

    def test_initialization(self, data_dir: Path) -> None:
        """Test MapEnvironmentManager initialization."""
        time_mgr = TimeManager(data_dir)
        day_night = DayNightManager(data_dir, time_mgr)
        weather = WeatherManager(data_dir, time_mgr)
        manager = MapEnvironmentManager(data_dir, time_mgr, day_night, weather)

        assert len(manager.map_properties) > 0

    def test_map_properties(self, data_dir: Path) -> None:
        """Test map property lookup."""
        time_mgr = TimeManager(data_dir)
        day_night = DayNightManager(data_dir, time_mgr)
        weather = WeatherManager(data_dir, time_mgr)
        manager = MapEnvironmentManager(data_dir, time_mgr, day_night, weather)

        props = manager.get_map_properties("prontera")
        assert props is not None
        assert props.map_type == MapType.TOWN

    def test_effective_time_period(self, data_dir: Path) -> None:
        """Test effective time period calculation."""
        time_mgr = TimeManager(data_dir)
        day_night = DayNightManager(data_dir, time_mgr)
        weather = WeatherManager(data_dir, time_mgr)
        manager = MapEnvironmentManager(data_dir, time_mgr, day_night, weather)

        # Normal map follows game time
        period = manager.get_effective_time_period("prontera")
        assert period in GamePeriod

        # Fixed time map
        fixed_period = manager.get_effective_time_period("gl_prison")
        assert fixed_period == GamePeriod.NIGHT

    def test_map_access(self, data_dir: Path) -> None:
        """Test map access restrictions."""
        time_mgr = TimeManager(data_dir)
        day_night = DayNightManager(data_dir, time_mgr)
        weather = WeatherManager(data_dir, time_mgr)
        manager = MapEnvironmentManager(data_dir, time_mgr, day_night, weather)

        # Low level character
        char_state = {"level": 10, "completed_quests": []}
        can_access, reason = manager.can_access_map("prontera", char_state)
        assert can_access is True

        # High level requirement
        can_access, reason = manager.can_access_map("gl_prison", char_state)
        assert can_access is False

    def test_combined_modifiers(self, data_dir: Path) -> None:
        """Test combined modifier calculations."""
        time_mgr = TimeManager(data_dir)
        day_night = DayNightManager(data_dir, time_mgr)
        weather = WeatherManager(data_dir, time_mgr)
        manager = MapEnvironmentManager(data_dir, time_mgr, day_night, weather)

        modifiers = manager.get_combined_modifiers("prontera")
        assert "exp" in modifiers
        assert "drop" in modifiers
        assert all(v >= 0 for v in modifiers.values())


class TestEnvironmentCoordinator:
    """Test integrated environment coordinator."""

    @pytest.fixture
    def coordinator(self, data_dir: Path) -> EnvironmentCoordinator:
        """Create coordinator instance."""
        return EnvironmentCoordinator(data_dir, server_timezone=8)

    async def test_initialization(self, coordinator: EnvironmentCoordinator) -> None:
        """Test coordinator initialization."""
        assert coordinator.time is not None
        assert coordinator.day_night is not None
        assert coordinator.weather is not None
        assert coordinator.events is not None
        assert coordinator.maps is not None

    async def test_update(self, coordinator: EnvironmentCoordinator) -> None:
        """Test environmental state updates."""
        await coordinator.update()
        # Should complete without errors

    async def test_environment_summary(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test environment summary generation."""
        summary = coordinator.get_environment_summary("prontera")

        assert "map" in summary
        assert "time" in summary
        assert "weather" in summary
        assert "events" in summary
        assert "modifiers" in summary

    async def test_current_bonuses(self, coordinator: EnvironmentCoordinator) -> None:
        """Test current bonus calculation."""
        bonuses = coordinator.get_current_bonuses()

        assert "exp_multiplier" in bonuses
        assert "drop_multiplier" in bonuses
        assert bonuses["exp_multiplier"] >= 1.0

    async def test_optimal_conditions(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test optimal farming condition detection."""
        conditions = coordinator.get_optimal_farming_conditions(
            "Poring", "prt_fild08"
        )

        assert "monster" in conditions
        assert "map" in conditions
        assert "is_available" in conditions
        assert "modifiers" in conditions

    async def test_relocation_decision(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test relocation recommendations."""
        char_state = {"level": 50, "completed_quests": []}
        should_relocate, target, reason = await coordinator.should_relocate(
            "prontera", char_state
        )

        assert isinstance(should_relocate, bool)
        if should_relocate:
            assert target is not None
            assert isinstance(reason, str)

    async def test_time_sensitive_actions(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test time-sensitive action detection."""
        actions = coordinator.get_time_sensitive_actions()

        assert isinstance(actions, list)
        for action in actions:
            assert "type" in action
            assert "priority" in action

    async def test_skill_effectiveness(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test skill effectiveness calculation."""
        effectiveness = coordinator.get_skill_effectiveness("Water Ball", "prt_fild08")

        assert "base" in effectiveness
        assert "day_night" in effectiveness
        assert "weather" in effectiveness
        assert "combined" in effectiveness

    async def test_recommended_maps(
        self, coordinator: EnvironmentCoordinator
    ) -> None:
        """Test map recommendations."""
        recommendations = coordinator.get_recommended_maps(50, "farming", limit=5)

        assert isinstance(recommendations, list)
        assert len(recommendations) <= 5
        for map_name, score in recommendations:
            assert isinstance(map_name, str)
            assert score >= 0


class TestIntegration:
    """Test integrated scenarios."""

    async def test_full_environment_cycle(self, data_dir: Path) -> None:
        """Test complete environmental cycle."""
        coordinator = EnvironmentCoordinator(data_dir)

        # Update environment
        await coordinator.update()

        # Get summary
        summary = coordinator.get_environment_summary("prontera")
        assert summary is not None

        # Check bonuses
        bonuses = coordinator.get_current_bonuses()
        assert bonuses["exp_multiplier"] >= 1.0

    async def test_event_aware_planning(self, data_dir: Path) -> None:
        """Test event-aware activity planning."""
        coordinator = EnvironmentCoordinator(data_dir)

        char_state = {"level": 75, "completed_quests": []}
        schedule = await coordinator.plan_activity_schedule(4, char_state)

        assert isinstance(schedule, list)
        assert len(schedule) == 4

    async def test_weather_skill_synergy(self, data_dir: Path) -> None:
        """Test weather and skill synergy."""
        coordinator = EnvironmentCoordinator(data_dir)

        # Check if Water Ball gets bonuses in rain
        effectiveness = coordinator.get_skill_effectiveness("Water Ball", "prt_fild08")
        assert effectiveness["combined"] >= 0