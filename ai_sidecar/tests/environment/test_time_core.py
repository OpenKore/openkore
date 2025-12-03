"""
Comprehensive tests for environment/time_core.py module.

Tests time calculations, day/night detection, season determination,
server reset schedules, and event timing.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open

import pytest

from ai_sidecar.environment.time_core import (
    DayType,
    GamePeriod,
    GameTime,
    Season,
    ServerResetType,
    TimeManager,
)


class TestGamePeriod:
    """Test GamePeriod enum."""
    
    def test_all_periods_defined(self):
        """Test all game periods are defined."""
        assert GamePeriod.DAWN == "dawn"
        assert GamePeriod.MORNING == "morning"
        assert GamePeriod.NOON == "noon"
        assert GamePeriod.AFTERNOON == "afternoon"
        assert GamePeriod.DUSK == "dusk"
        assert GamePeriod.EVENING == "evening"
        assert GamePeriod.NIGHT == "night"


class TestDayType:
    """Test DayType enum."""
    
    def test_weekday_types(self):
        """Test weekday types."""
        assert DayType.MONDAY == "monday"
        assert DayType.TUESDAY == "tuesday"
        assert DayType.WEDNESDAY == "wednesday"
        assert DayType.THURSDAY == "thursday"
        assert DayType.FRIDAY == "friday"
    
    def test_weekend_types(self):
        """Test weekend types."""
        assert DayType.SATURDAY == "saturday"
        assert DayType.SUNDAY == "sunday"
        assert DayType.WEEKEND == "weekend"


class TestSeason:
    """Test Season enum."""
    
    def test_all_seasons_defined(self):
        """Test all seasons are defined."""
        assert Season.SPRING == "spring"
        assert Season.SUMMER == "summer"
        assert Season.AUTUMN == "autumn"
        assert Season.WINTER == "winter"


class TestServerResetType:
    """Test ServerResetType enum."""
    
    def test_reset_types(self):
        """Test reset types are defined."""
        assert ServerResetType.DAILY == "daily"
        assert ServerResetType.WEEKLY == "weekly"
        assert ServerResetType.MONTHLY == "monthly"
        assert ServerResetType.WOE == "woe"
        assert ServerResetType.MAINTENANCE == "maintenance"


class TestGameTime:
    """Test GameTime model."""
    
    def test_default_game_time(self):
        """Test default game time values."""
        game_time = GameTime()
        
        assert game_time.game_hour == 0
        assert game_time.game_minute == 0
        assert game_time.period == GamePeriod.MORNING
        assert game_time.is_daytime is True
        assert game_time.timezone_offset == 0
        assert game_time.day_of_week == DayType.WEEKDAY
        assert game_time.season == Season.SPRING
    
    def test_custom_game_time(self):
        """Test custom game time values."""
        server_time = datetime(2024, 6, 15, 12, 30)
        
        game_time = GameTime(
            game_hour=14,
            game_minute=30,
            period=GamePeriod.AFTERNOON,
            is_daytime=True,
            server_time=server_time,
            timezone_offset=8,
            day_of_week=DayType.SATURDAY,
            season=Season.SUMMER
        )
        
        assert game_time.game_hour == 14
        assert game_time.game_minute == 30
        assert game_time.period == GamePeriod.AFTERNOON
        assert game_time.is_daytime is True
        assert game_time.server_time == server_time
        assert game_time.timezone_offset == 8
        assert game_time.day_of_week == DayType.SATURDAY
        assert game_time.season == Season.SUMMER
    
    def test_hour_constraints(self):
        """Test hour constraints."""
        with pytest.raises(Exception):  # ValidationError
            GameTime(game_hour=25)
    
    def test_minute_constraints(self):
        """Test minute constraints."""
        with pytest.raises(Exception):  # ValidationError
            GameTime(game_minute=60)


class TestTimeManager:
    """Test TimeManager class."""
    
    @pytest.fixture
    def data_dir(self, tmp_path):
        """Create temporary data directory."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        # Create time_periods.json
        time_data = {
            "periods": {
                "dawn": {"start": 5, "end": 7},
                "morning": {"start": 7, "end": 12}
            }
        }
        
        periods_file = data_dir / "time_periods.json"
        periods_file.write_text(json.dumps(time_data))
        
        return data_dir
    
    @pytest.fixture
    def time_manager(self, data_dir):
        """Create TimeManager instance."""
        return TimeManager(data_dir, server_timezone=0)
    
    def test_initialization(self, data_dir):
        """Test TimeManager initialization."""
        manager = TimeManager(data_dir, server_timezone=8)
        
        assert manager.data_dir == data_dir
        assert manager.server_timezone == 8
        assert isinstance(manager.current_time, GameTime)
    
    def test_initialization_loads_config(self, time_manager):
        """Test initialization loads configuration."""
        assert len(time_manager.period_config) > 0
    
    def test_get_server_time_utc(self, time_manager):
        """Test get server time with UTC."""
        with patch('ai_sidecar.environment.time_core.datetime') as mock_datetime:
            mock_datetime.utcnow.return_value = datetime(2024, 6, 15, 12, 0)
            
            server_time = time_manager.get_server_time()
            
            assert server_time.hour == 12
            assert server_time.minute == 0
    
    def test_get_server_time_with_timezone(self, data_dir):
        """Test get server time with timezone offset."""
        manager = TimeManager(data_dir, server_timezone=8)
        
        with patch('ai_sidecar.environment.time_core.datetime') as mock_datetime:
            mock_datetime.utcnow.return_value = datetime(2024, 6, 15, 12, 0)
            
            server_time = manager.get_server_time()
            
            assert server_time.hour == 20  # 12 + 8
    
    def test_calculate_game_time_morning(self, time_manager):
        """Test game time calculation for morning."""
        server_time = datetime(2024, 6, 15, 2, 0)  # 2 AM server time
        
        game_time = time_manager.calculate_game_time(server_time)
        
        assert game_time.game_hour == 8  # 2 * 4 = 8
        assert game_time.period == GamePeriod.MORNING
        assert game_time.is_daytime is True
    
    def test_calculate_game_time_evening(self, time_manager):
        """Test game time calculation for evening."""
        server_time = datetime(2024, 6, 15, 5, 30)  # 5:30 AM server time
        
        game_time = time_manager.calculate_game_time(server_time)
        
        # 5.5 * 4 = 22 hours
        assert game_time.game_hour == 22
        assert game_time.period == GamePeriod.EVENING
        assert game_time.is_daytime is False
    
    def test_calculate_game_time_night(self, time_manager):
        """Test game time calculation for night."""
        server_time = datetime(2024, 6, 15, 0, 30)
        
        game_time = time_manager.calculate_game_time(server_time)
        
        # 0.5 * 4 = 2 hours
        assert game_time.game_hour == 2
        assert game_time.period == GamePeriod.NIGHT
        assert game_time.is_daytime is False
    
    def test_calculate_game_time_sets_day_of_week(self, time_manager):
        """Test game time sets correct day of week."""
        # Monday
        server_time = datetime(2024, 6, 10, 12, 0)  # Monday
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.day_of_week == DayType.MONDAY
        
        # Saturday
        server_time = datetime(2024, 6, 15, 12, 0)  # Saturday
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.day_of_week == DayType.SATURDAY
    
    def test_calculate_game_time_sets_season(self, time_manager):
        """Test game time sets correct season."""
        # Spring (March)
        server_time = datetime(2024, 3, 15, 12, 0)
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.season == Season.SPRING
        
        # Summer (June)
        server_time = datetime(2024, 6, 15, 12, 0)
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.season == Season.SUMMER
        
        # Autumn (September)
        server_time = datetime(2024, 9, 15, 12, 0)
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.season == Season.AUTUMN
        
        # Winter (December)
        server_time = datetime(2024, 12, 15, 12, 0)
        game_time = time_manager.calculate_game_time(server_time)
        assert game_time.season == Season.WINTER
    
    def test_get_period_from_hour_dawn(self, time_manager):
        """Test period detection for dawn."""
        period = time_manager._get_period_from_hour(5)
        assert period == GamePeriod.DAWN
        
        period = time_manager._get_period_from_hour(6)
        assert period == GamePeriod.DAWN
    
    def test_get_period_from_hour_morning(self, time_manager):
        """Test period detection for morning."""
        period = time_manager._get_period_from_hour(7)
        assert period == GamePeriod.MORNING
        
        period = time_manager._get_period_from_hour(11)
        assert period == GamePeriod.MORNING
    
    def test_get_period_from_hour_noon(self, time_manager):
        """Test period detection for noon."""
        period = time_manager._get_period_from_hour(12)
        assert period == GamePeriod.NOON
        
        period = time_manager._get_period_from_hour(13)
        assert period == GamePeriod.NOON
    
    def test_get_period_from_hour_afternoon(self, time_manager):
        """Test period detection for afternoon."""
        period = time_manager._get_period_from_hour(14)
        assert period == GamePeriod.AFTERNOON
        
        period = time_manager._get_period_from_hour(17)
        assert period == GamePeriod.AFTERNOON
    
    def test_get_period_from_hour_dusk(self, time_manager):
        """Test period detection for dusk."""
        period = time_manager._get_period_from_hour(18)
        assert period == GamePeriod.DUSK
        
        period = time_manager._get_period_from_hour(19)
        assert period == GamePeriod.DUSK
    
    def test_get_period_from_hour_evening(self, time_manager):
        """Test period detection for evening."""
        period = time_manager._get_period_from_hour(20)
        assert period == GamePeriod.EVENING
        
        period = time_manager._get_period_from_hour(23)
        assert period == GamePeriod.EVENING
    
    def test_get_period_from_hour_night(self, time_manager):
        """Test period detection for night."""
        period = time_manager._get_period_from_hour(0)
        assert period == GamePeriod.NIGHT
        
        period = time_manager._get_period_from_hour(4)
        assert period == GamePeriod.NIGHT
    
    def test_get_day_type_weekdays(self, time_manager):
        """Test day type for weekdays."""
        assert time_manager._get_day_type(0) == DayType.MONDAY
        assert time_manager._get_day_type(1) == DayType.TUESDAY
        assert time_manager._get_day_type(2) == DayType.WEDNESDAY
        assert time_manager._get_day_type(3) == DayType.THURSDAY
        assert time_manager._get_day_type(4) == DayType.FRIDAY
    
    def test_get_day_type_weekend(self, time_manager):
        """Test day type for weekend."""
        assert time_manager._get_day_type(5) == DayType.SATURDAY
        assert time_manager._get_day_type(6) == DayType.SUNDAY
    
    def test_get_season_spring(self, time_manager):
        """Test season detection for spring."""
        assert time_manager._get_season(3) == Season.SPRING
        assert time_manager._get_season(4) == Season.SPRING
        assert time_manager._get_season(5) == Season.SPRING
    
    def test_get_season_summer(self, time_manager):
        """Test season detection for summer."""
        assert time_manager._get_season(6) == Season.SUMMER
        assert time_manager._get_season(7) == Season.SUMMER
        assert time_manager._get_season(8) == Season.SUMMER
    
    def test_get_season_autumn(self, time_manager):
        """Test season detection for autumn."""
        assert time_manager._get_season(9) == Season.AUTUMN
        assert time_manager._get_season(10) == Season.AUTUMN
        assert time_manager._get_season(11) == Season.AUTUMN
    
    def test_get_season_winter(self, time_manager):
        """Test season detection for winter."""
        assert time_manager._get_season(12) == Season.WINTER
        assert time_manager._get_season(1) == Season.WINTER
        assert time_manager._get_season(2) == Season.WINTER
    
    def test_get_current_period(self, time_manager):
        """Test getting current period."""
        with patch.object(time_manager, 'calculate_game_time') as mock_calc:
            mock_game_time = GameTime(
                game_hour=10,
                period=GamePeriod.MORNING
            )
            mock_calc.return_value = mock_game_time
            
            period = time_manager.get_current_period()
            
            assert period == GamePeriod.MORNING
    
    def test_is_daytime_true(self, time_manager):
        """Test daytime detection."""
        with patch.object(time_manager, 'calculate_game_time') as mock_calc:
            mock_game_time = GameTime(game_hour=12, is_daytime=True)
            mock_calc.return_value = mock_game_time
            
            assert time_manager.is_daytime() is True
    
    def test_is_daytime_false(self, time_manager):
        """Test daytime detection when night."""
        with patch.object(time_manager, 'calculate_game_time') as mock_calc:
            mock_game_time = GameTime(game_hour=20, is_daytime=False)
            mock_calc.return_value = mock_game_time
            
            assert time_manager.is_daytime() is False
    
    def test_is_nighttime(self, time_manager):
        """Test nighttime detection."""
        with patch.object(time_manager, 'is_daytime') as mock_daytime:
            mock_daytime.return_value = False
            
            assert time_manager.is_nighttime() is True
            
            mock_daytime.return_value = True
            
            assert time_manager.is_nighttime() is False
    
    def test_get_time_until_period_same_day(self, time_manager):
        """Test time until period later same day."""
        with patch.object(time_manager, 'calculate_game_time') as mock_calc:
            mock_game_time = GameTime(game_hour=10)  # Morning
            mock_calc.return_value = mock_game_time
            
            time_until = time_manager.get_time_until_period(GamePeriod.AFTERNOON)
            
            # Afternoon starts at 14, current is 10, so 4 game hours
            # 4 game hours = 4 * 15 = 60 real minutes
            assert time_until.total_seconds() == 60 * 60
    
    def test_get_time_until_period_next_day(self, time_manager):
        """Test time until period next day."""
        with patch.object(time_manager, 'calculate_game_time') as mock_calc:
            mock_game_time = GameTime(game_hour=20)  # Evening
            mock_calc.return_value = mock_game_time
            
            time_until = time_manager.get_time_until_period(GamePeriod.MORNING)
            
            # Morning starts at 7, current is 20
            # Hours until: 24 - 20 + 7 = 11 game hours
            # 11 * 15 = 165 real minutes
            assert time_until.total_seconds() == 165 * 60
    
    def test_get_time_until_reset_daily(self, time_manager):
        """Test time until daily reset."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            mock_time.return_value = datetime(2024, 6, 15, 2, 0)  # 2 AM
            
            time_until = time_manager.get_time_until_reset(ServerResetType.DAILY)
            
            # Reset at 4 AM, current 2 AM, so 2 hours
            assert time_until.total_seconds() == 2 * 60 * 60
    
    def test_get_time_until_reset_daily_after_reset(self, time_manager):
        """Test time until daily reset after today's reset."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            mock_time.return_value = datetime(2024, 6, 15, 5, 0)  # 5 AM (after reset)
            
            time_until = time_manager.get_time_until_reset(ServerResetType.DAILY)
            
            # Next reset at 4 AM tomorrow, so 23 hours
            assert time_until.total_seconds() > 22 * 60 * 60
    
    def test_get_time_until_reset_weekly(self, time_manager):
        """Test time until weekly reset."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            # Friday at 2 AM
            mock_time.return_value = datetime(2024, 6, 14, 2, 0)
            
            time_until = time_manager.get_time_until_reset(ServerResetType.WEEKLY)
            
            # Monday at 4 AM, so about 4 days
            assert time_until.days >= 3
    
    def test_get_time_until_reset_monthly(self, time_manager):
        """Test time until monthly reset."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            mock_time.return_value = datetime(2024, 6, 15, 12, 0)
            
            time_until = time_manager.get_time_until_reset(ServerResetType.MONTHLY)
            
            # Next reset July 1 at 4 AM
            assert time_until.days >= 15
    
    def test_get_next_reset_time(self, time_manager):
        """Test getting next reset time."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            mock_time.return_value = datetime(2024, 6, 15, 2, 0)
            
            next_reset = time_manager.get_next_reset_time(ServerResetType.DAILY)
            
            assert next_reset.hour == 4
            assert next_reset.day == 15
    
    def test_get_current_season(self, time_manager):
        """Test getting current season."""
        with patch.object(time_manager, 'get_server_time') as mock_time:
            mock_time.return_value = datetime(2024, 6, 15, 12, 0)
            
            season = time_manager.get_current_season()
            
            assert season == Season.SUMMER
    
    def test_is_event_active(self, time_manager):
        """Test event active check."""
        # Default implementation returns False
        active = time_manager.is_event_active("test_event")
        
        assert active is False
    
    def test_get_active_events(self, time_manager):
        """Test getting active events."""
        # Default implementation returns empty list
        events = time_manager.get_active_events()
        
        assert events == []
    
    def test_load_reset_schedules_missing_file(self, tmp_path):
        """Test loading reset schedules with missing file."""
        manager = TimeManager(tmp_path, server_timezone=0)
        
        # Should initialize empty schedules without error
        assert isinstance(manager.reset_schedules, dict)
    
    def test_load_period_config_missing_file(self, tmp_path):
        """Test loading period config with missing file."""
        manager = TimeManager(tmp_path, server_timezone=0)
        
        # Should initialize empty config without error
        assert isinstance(manager.period_config, dict)