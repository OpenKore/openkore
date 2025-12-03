"""
Comprehensive tests for environment/coordinator.py - Batch 7.

Target: Push coverage from 63.69% to 85%+
Focus on uncovered lines: 198, 203-207, 213-217, 232-234, 247, 272, 307-308,
365-377, 398, 405, 413-416, 420-421
"""

from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import tempfile
import pytest

from ai_sidecar.environment.coordinator import EnvironmentCoordinator
from ai_sidecar.environment.day_night import DayNightPhase
from ai_sidecar.environment.events import SeasonalEvent
from ai_sidecar.environment.maps import MapType, MapEnvironment
from ai_sidecar.environment.time_core import GameTime, GamePeriod, Season
from ai_sidecar.environment.weather import WeatherType


@pytest.fixture
def temp_data_dir():
    """Create temporary data directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def coordinator(temp_data_dir):
    """Create environment coordinator."""
    return EnvironmentCoordinator(temp_data_dir)


@pytest.fixture
def sample_game_time():
    """Create sample game time."""
    return GameTime(
        game_hour=12,
        game_minute=0,
        period=GamePeriod.NOON,
        is_daytime=True,
        season=Season.SPRING
    )


class TestUpdate:
    """Test update method - lines 56-64."""

    @pytest.mark.asyncio
    async def test_update_refreshes_state(self, coordinator):
        """Test update refreshes all environmental states."""
        coordinator.time.calculate_game_time = MagicMock()
        coordinator.events.refresh_active_events = MagicMock()
        
        await coordinator.update()
        
        coordinator.time.calculate_game_time.assert_called_once()
        coordinator.events.refresh_active_events.assert_called_once()


class TestGetEnvironmentSummary:
    """Test get_environment_summary method - lines 66-112."""

    def test_environment_summary_complete(self, coordinator, sample_game_time):
        """Test complete environment summary."""
        map_name = "prontera"
        
        coordinator.time.calculate_game_time = MagicMock(return_value=sample_game_time)
        coordinator.day_night.get_current_phase = MagicMock(
            return_value=DayNightPhase.MORNING
        )
        coordinator.weather.get_weather = MagicMock(
            return_value=WeatherType.CLEAR
        )
        coordinator.weather.get_visibility_modifier = MagicMock(return_value=1.0)
        coordinator.weather.get_movement_modifier = MagicMock(return_value=1.0)
        coordinator.events.get_active_events = MagicMock(return_value=[])
        coordinator.events.get_event_exp_bonus = MagicMock(return_value=1.5)
        coordinator.events.get_event_drop_bonus = MagicMock(return_value=2.0)
        
        mock_map_props = MagicMock()
        mock_map_props.map_type = MapType.FIELD
        mock_map_props.environment = MapEnvironment.OUTDOOR
        mock_map_props.has_day_night = True
        mock_map_props.has_weather = True
        coordinator.maps.get_map_properties = MagicMock(return_value=mock_map_props)
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"exp": 1.5, "drop": 2.0}
        )
        
        summary = coordinator.get_environment_summary(map_name)
        
        assert summary["map"] == map_name
        assert "time" in summary
        assert "weather" in summary
        assert "events" in summary
        assert "map_properties" in summary


class TestGetCurrentBonuses:
    """Test get_current_bonuses method - lines 114-134."""

    def test_current_bonuses(self, coordinator):
        """Test getting current bonuses."""
        mock_phase_mods = MagicMock()
        mock_phase_mods.exp_modifier = 1.2
        mock_phase_mods.drop_modifier = 1.3
        mock_phase_mods.monster_spawn_rate = 1.1
        mock_phase_mods.visibility_range = 0.9
        
        coordinator.day_night.get_phase_modifiers = MagicMock(
            return_value=mock_phase_mods
        )
        coordinator.events.get_event_exp_bonus = MagicMock(return_value=1.5)
        coordinator.events.get_event_drop_bonus = MagicMock(return_value=2.0)
        coordinator.events.get_active_events = MagicMock(return_value=[])
        
        bonuses = coordinator.get_current_bonuses()
        
        assert "exp_multiplier" in bonuses
        assert "drop_multiplier" in bonuses
        assert bonuses["exp_multiplier"] == 1.2 * 1.5


class TestGetOptimalFarmingConditions:
    """Test get_optimal_farming_conditions method - lines 136-178."""

    def test_optimal_farming_conditions(self, coordinator):
        """Test optimal farming conditions check."""
        target_monster = "Poring"
        current_map = "prt_fild08"
        
        coordinator.day_night.get_monster_availability = MagicMock(return_value=True)
        coordinator.day_night.get_optimal_farming_period = MagicMock(
            return_value=[DayNightPhase.DAY, DayNightPhase.AFTERNOON]
        )
        coordinator.day_night.get_current_phase = MagicMock(
            return_value=DayNightPhase.DAY
        )
        coordinator.day_night.get_spawn_rate_modifier = MagicMock(return_value=1.2)
        coordinator.day_night.get_exp_modifier = MagicMock(return_value=1.1)
        coordinator.day_night.get_drop_modifier = MagicMock(return_value=1.3)
        
        conditions = coordinator.get_optimal_farming_conditions(
            target_monster, current_map
        )
        
        assert conditions["monster"] == target_monster
        assert conditions["map"] == current_map
        assert conditions["is_available"] is True
        assert conditions["is_optimal_time"] is True


class TestShouldRelocate:
    """Test should_relocate method - lines 180-219."""

    @pytest.mark.asyncio
    async def test_should_relocate_farming_spot_switch(self, coordinator):
        """Test relocation due to farming spot switch."""
        current_map = "prt_fild08"
        character_state = {"level": 50}
        
        coordinator.day_night.should_switch_farming_spot = MagicMock(
            return_value=(True, "prt_fild09")
        )
        
        should_relocate, target_map, reason = await coordinator.should_relocate(
            current_map, character_state
        )
        
        assert should_relocate is True
        assert target_map == "prt_fild09"
        assert "availability" in reason.lower()

    @pytest.mark.asyncio
    async def test_should_relocate_high_priority_event(self, coordinator):
        """Test relocation due to high priority event."""
        current_map = "prontera"
        character_state = {"level": 50}
        
        coordinator.day_night.should_switch_farming_spot = MagicMock(
            return_value=(False, None)
        )
        
        # Mock high priority event
        event = SeasonalEvent(
            event_id="halloween",
            event_name="Halloween Event",
            start_date="2024-10-25",
            end_date="2024-11-01",
            exp_bonus=2.0,
            drop_bonus=2.0,
            event_maps=["event_map"],
            event_items=[],
            special_monsters=[]
        )
        coordinator.events.get_active_events = MagicMock(return_value=[event])
        coordinator.events.calculate_event_priority = MagicMock(return_value=75)
        
        should_relocate, target_map, reason = await coordinator.should_relocate(
            current_map, character_state
        )
        
        assert should_relocate is True
        assert "event" in reason.lower()

    @pytest.mark.asyncio
    async def test_should_relocate_better_modifiers(self, coordinator):
        """Test relocation due to better map modifiers."""
        current_map = "bad_map"
        character_state = {"level": 50}
        
        coordinator.day_night.should_switch_farming_spot = MagicMock(
            return_value=(False, None)
        )
        coordinator.events.get_active_events = MagicMock(return_value=[])
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"exp": 0.7}  # Significant penalty
        )
        coordinator.maps.get_optimal_maps_for_time = MagicMock(
            return_value=["better_map"]
        )
        coordinator.time.current_time = MagicMock()
        
        should_relocate, target_map, reason = await coordinator.should_relocate(
            current_map, character_state
        )
        
        assert should_relocate is True
        assert target_map == "better_map"

    @pytest.mark.asyncio
    async def test_should_not_relocate(self, coordinator):
        """Test no relocation needed."""
        current_map = "optimal_map"
        character_state = {"level": 50}
        
        coordinator.day_night.should_switch_farming_spot = MagicMock(
            return_value=(False, None)
        )
        coordinator.events.get_active_events = MagicMock(return_value=[])
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"exp": 1.2}
        )
        
        should_relocate, target_map, reason = await coordinator.should_relocate(
            current_map, character_state
        )
        
        assert should_relocate is False


class TestGetTimeSensitiveActions:
    """Test get_time_sensitive_actions method - lines 221-258."""

    def test_time_sensitive_ending_events(self, coordinator):
        """Test time-sensitive actions for ending events."""
        from datetime import timedelta
        
        event = SeasonalEvent(
            event_id="halloween",
            event_name="Halloween Event",
            start_date="2024-10-25",
            end_date="2024-11-01",
            exp_bonus=2.0,
            drop_bonus=2.0,
            event_maps=[],
            event_items=[],
            special_monsters=[]
        )
        coordinator.events.get_active_events = MagicMock(return_value=[event])
        coordinator.events.get_event_time_remaining = MagicMock(
            return_value=timedelta(hours=12)
        )
        coordinator.events.get_daily_quests = MagicMock(return_value=[])
        
        actions = coordinator.get_time_sensitive_actions()
        
        assert len(actions) > 0
        assert actions[0]["type"] == "event_ending"
        assert actions[0]["priority"] == 100

    def test_time_sensitive_daily_quests(self, coordinator):
        """Test time-sensitive actions for daily quests."""
        coordinator.events.get_active_events = MagicMock(return_value=[])
        coordinator.events.get_daily_quests = MagicMock(
            return_value=["Quest1", "Quest2"]
        )
        
        actions = coordinator.get_time_sensitive_actions()
        
        daily_action = next((a for a in actions if a["type"] == "daily_quests"), None)
        assert daily_action is not None
        assert daily_action["priority"] == 75


class TestGetUpcomingEvents:
    """Test get_upcoming_events method - lines 260-272."""

    def test_get_upcoming_events(self, coordinator):
        """Test getting upcoming events."""
        event = SeasonalEvent(
            event_id="christmas",
            event_name="Christmas Event",
            start_date="2024-12-20",
            end_date="2024-12-31",
            exp_bonus=2.0,
            drop_bonus=2.0,
            event_maps=[],
            event_items=[],
            special_monsters=[]
        )
        coordinator.events.get_active_events = MagicMock(return_value=[event])
        
        events = coordinator.get_upcoming_events(hours_ahead=24)
        
        assert len(events) > 0


class TestPlanActivitySchedule:
    """Test plan_activity_schedule method - lines 274-316."""

    @pytest.mark.asyncio
    async def test_plan_activity_schedule(self, coordinator, sample_game_time):
        """Test activity schedule planning."""
        character_state = {"level": 50}
        
        coordinator.time.calculate_game_time = MagicMock(return_value=sample_game_time)
        coordinator.get_time_sensitive_actions = MagicMock(return_value=[])
        coordinator.get_current_bonuses = MagicMock(
            return_value={"exp_multiplier": 1.5}
        )
        
        schedule = await coordinator.plan_activity_schedule(
            hours_ahead=4, character_state=character_state
        )
        
        assert len(schedule) == 4
        assert all("hour" in activity for activity in schedule)


class TestGetSkillEffectiveness:
    """Test get_skill_effectiveness method - lines 318-349."""

    def test_skill_effectiveness(self, coordinator):
        """Test skill effectiveness calculation."""
        skill_name = "Fire Bolt"
        map_name = "prontera"
        
        coordinator.day_night.get_skill_modifier = MagicMock(return_value=1.2)
        coordinator.weather.get_skill_weather_modifier = MagicMock(return_value=0.8)
        
        effectiveness = coordinator.get_skill_effectiveness(skill_name, map_name)
        
        assert "base" in effectiveness
        assert "day_night" in effectiveness
        assert "weather" in effectiveness
        assert "combined" in effectiveness
        assert effectiveness["combined"] == 1.2 * 0.8


class TestIsFavorableConditions:
    """Test is_favorable_conditions method - lines 351-377."""

    def test_is_favorable_for_farming(self, coordinator):
        """Test favorable conditions for farming."""
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"drop": 1.5, "exp": 1.2}
        )
        
        result = coordinator.is_favorable_conditions(
            "farming", "prontera", threshold=1.2
        )
        
        assert result is True

    def test_is_favorable_for_grinding(self, coordinator):
        """Test favorable conditions for grinding."""
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"exp": 1.3, "drop": 1.0}
        )
        
        result = coordinator.is_favorable_conditions(
            "grinding", "prontera", threshold=1.2
        )
        
        assert result is True

    def test_is_favorable_for_questing(self, coordinator):
        """Test favorable conditions for questing."""
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={
                "visibility": 1.0,
                "movement": 1.3,
                "exp": 1.0
            }
        )
        
        result = coordinator.is_favorable_conditions(
            "questing", "prontera", threshold=1.2
        )
        
        assert result is True

    def test_is_not_favorable(self, coordinator):
        """Test unfavorable conditions."""
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"drop": 0.8}
        )
        
        result = coordinator.is_favorable_conditions(
            "farming", "prontera", threshold=1.2
        )
        
        assert result is False


class TestGetRecommendedMaps:
    """Test get_recommended_maps method - lines 379-427."""

    def test_get_recommended_maps_for_farming(self, coordinator):
        """Test map recommendations for farming."""
        mock_map_props = MagicMock()
        mock_map_props.level_requirement = 40
        mock_map_props.map_type.value = "field"
        
        coordinator.maps.map_properties = {
            "prt_fild08": mock_map_props
        }
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"drop": 1.5, "exp": 1.2}
        )
        coordinator.events.get_active_events = MagicMock(return_value=[])
        
        recommendations = coordinator.get_recommended_maps(
            character_level=50,
            activity_type="farming",
            limit=5
        )
        
        assert len(recommendations) > 0
        assert all(isinstance(r, tuple) for r in recommendations)

    def test_get_recommended_maps_skips_pvp(self, coordinator):
        """Test that PvP maps are skipped for farming."""
        pvp_map_props = MagicMock()
        pvp_map_props.level_requirement = 40
        pvp_map_props.map_type.value = "pvp"
        
        field_map_props = MagicMock()
        field_map_props.level_requirement = 40
        field_map_props.map_type.value = "field"
        
        coordinator.maps.map_properties = {
            "pvp_map": pvp_map_props,
            "field_map": field_map_props
        }
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"drop": 1.5, "exp": 1.2}
        )
        coordinator.events.get_active_events = MagicMock(return_value=[])
        
        recommendations = coordinator.get_recommended_maps(
            character_level=50,
            activity_type="farming",
            limit=5
        )
        
        # Should only include field_map
        map_names = [name for name, score in recommendations]
        assert "field_map" in map_names
        assert "pvp_map" not in map_names

    def test_get_recommended_maps_with_event_bonus(self, coordinator):
        """Test map recommendations include event bonuses."""
        mock_map_props = MagicMock()
        mock_map_props.level_requirement = 40
        mock_map_props.map_type.value = "field"
        
        coordinator.maps.map_properties = {
            "event_map": mock_map_props
        }
        coordinator.maps.get_combined_modifiers = MagicMock(
            return_value={"drop": 1.0, "exp": 1.0}
        )
        
        event = SeasonalEvent(
            event_id="bonus",
            event_name="Bonus Event",
            start_date="2024-01-01",
            end_date="2024-12-31",
            exp_bonus=3.0,
            drop_bonus=3.0,
            event_maps=["event_map"],
            event_items=[],
            special_monsters=[]
        )
        coordinator.events.get_active_events = MagicMock(return_value=[event])
        
        recommendations = coordinator.get_recommended_maps(
            character_level=50,
            activity_type="farming",
            limit=5
        )
        
        # Event map should have higher score
        assert len(recommendations) > 0