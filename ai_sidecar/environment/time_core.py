"""
Time Core System for OpenKore AI Sidecar.

Manages game time calculations, server time tracking, and reset schedules.
RO Time System: 6 real hours = 1 game day (24 game hours).
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, Field


class GamePeriod(str, Enum):
    """Game time periods throughout the day."""

    DAWN = "dawn"  # 5:00-6:59
    MORNING = "morning"  # 7:00-11:59
    NOON = "noon"  # 12:00-13:59
    AFTERNOON = "afternoon"  # 14:00-17:59
    DUSK = "dusk"  # 18:00-19:59
    EVENING = "evening"  # 20:00-23:59
    NIGHT = "night"  # 0:00-4:59


class DayType(str, Enum):
    """Day of week types."""

    WEEKDAY = "weekday"
    WEEKEND = "weekend"
    MONDAY = "monday"
    TUESDAY = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY = "thursday"
    FRIDAY = "friday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"


class Season(str, Enum):
    """Game seasons based on real calendar months."""

    SPRING = "spring"  # March-May
    SUMMER = "summer"  # June-August
    AUTUMN = "autumn"  # September-November
    WINTER = "winter"  # December-February


class ServerResetType(str, Enum):
    """Server reset types."""

    DAILY = "daily"  # Daily reset (typically 4-6 AM server time)
    WEEKLY = "weekly"  # Weekly reset (typically Monday)
    MONTHLY = "monthly"  # Monthly reset (first day)
    WOE = "woe"  # WoE time blocks
    MAINTENANCE = "maintenance"


class GameTime(BaseModel):
    """Current game time state."""

    game_hour: int = Field(ge=0, le=23)
    game_minute: int = Field(ge=0, le=59)
    period: GamePeriod = GamePeriod.MORNING
    is_daytime: bool = True

    # Real time reference
    server_time: datetime = Field(default_factory=datetime.now)
    timezone_offset: int = 0  # Server timezone offset from UTC

    # Cycles
    day_of_week: DayType = DayType.WEEKDAY
    season: Season = Season.SPRING


class TimeManager:
    """
    Manage game time calculations and tracking.

    RO Time System:
    - 1 game day = 6 real hours (240 game minutes = 360 real minutes)
    - 1 game minute = 1.5 real minutes
    - Day: 6:00-17:59 game time
    - Night: 18:00-5:59 game time
    """

    GAME_DAY_REAL_HOURS = 6  # 6 real hours = 1 game day
    GAME_MINUTES_PER_REAL_MINUTE = 0.667  # ~40 game minutes per real hour

    def __init__(self, data_dir: Path, server_timezone: int = 0):
        """
        Initialize TimeManager.

        Args:
            data_dir: Directory containing time configuration files
            server_timezone: Server timezone offset from UTC
        """
        self.log = structlog.get_logger()
        self.data_dir = data_dir
        self.server_timezone = server_timezone
        self.current_time = GameTime()
        self.reset_schedules: Dict[ServerResetType, List[datetime]] = {}
        self.period_config: Dict[str, Dict[str, Any]] = {}
        self._load_reset_schedules()
        self._load_period_config()

    def _load_reset_schedules(self) -> None:
        """Load server reset schedules from configuration."""
        try:
            reset_file = self.data_dir / "time_periods.json"
            if reset_file.exists():
                with open(reset_file, "r") as f:
                    data = json.load(f)
                    # Initialize reset schedules
                    self.reset_schedules = {
                        ServerResetType.DAILY: [],
                        ServerResetType.WEEKLY: [],
                        ServerResetType.MONTHLY: [],
                    }
            self.log.info("reset_schedules_loaded")
        except Exception as e:
            self.log.error("failed_to_load_reset_schedules", error=str(e))
            self.reset_schedules = {}

    def _load_period_config(self) -> None:
        """Load time period configuration."""
        try:
            period_file = self.data_dir / "time_periods.json"
            if period_file.exists():
                with open(period_file, "r") as f:
                    data = json.load(f)
                    self.period_config = data.get("periods", {})
            self.log.info("period_config_loaded")
        except Exception as e:
            self.log.error("failed_to_load_period_config", error=str(e))
            self.period_config = {}

    def get_server_time(self) -> datetime:
        """
        Get current server time adjusted for timezone.

        Returns:
            Current server time
        """
        utc_now = datetime.utcnow()
        server_offset = timedelta(hours=self.server_timezone)
        return utc_now + server_offset

    def calculate_game_time(self, server_time: Optional[datetime] = None) -> GameTime:
        """
        Calculate game time from server time.

        Args:
            server_time: Server time to calculate from (default: current)

        Returns:
            GameTime with calculated values
        """
        if server_time is None:
            server_time = self.get_server_time()

        # Calculate game time based on RO's 6-hour cycle
        # 1 real hour = 4 game hours
        hours_since_midnight = server_time.hour + server_time.minute / 60.0
        game_hours = (hours_since_midnight * 4) % 24
        game_hour = int(game_hours)
        game_minute = int((game_hours - game_hour) * 60)

        # Determine period
        period = self._get_period_from_hour(game_hour)

        # Check if daytime
        is_daytime = 6 <= game_hour < 18

        # Get day of week
        day_of_week = self._get_day_type(server_time.weekday())

        # Get season
        season = self._get_season(server_time.month)

        game_time = GameTime(
            game_hour=game_hour,
            game_minute=game_minute,
            period=period,
            is_daytime=is_daytime,
            server_time=server_time,
            timezone_offset=self.server_timezone,
            day_of_week=day_of_week,
            season=season,
        )

        self.current_time = game_time
        return game_time

    def _get_period_from_hour(self, hour: int) -> GamePeriod:
        """
        Get game period from hour.

        Args:
            hour: Hour (0-23)

        Returns:
            Corresponding GamePeriod
        """
        if 5 <= hour < 7:
            return GamePeriod.DAWN
        elif 7 <= hour < 12:
            return GamePeriod.MORNING
        elif 12 <= hour < 14:
            return GamePeriod.NOON
        elif 14 <= hour < 18:
            return GamePeriod.AFTERNOON
        elif 18 <= hour < 20:
            return GamePeriod.DUSK
        elif 20 <= hour < 24:
            return GamePeriod.EVENING
        else:  # 0 <= hour < 5
            return GamePeriod.NIGHT

    def _get_day_type(self, weekday: int) -> DayType:
        """
        Get day type from weekday number.

        Args:
            weekday: Weekday (0=Monday, 6=Sunday)

        Returns:
            Corresponding DayType
        """
        day_map = {
            0: DayType.MONDAY,
            1: DayType.TUESDAY,
            2: DayType.WEDNESDAY,
            3: DayType.THURSDAY,
            4: DayType.FRIDAY,
            5: DayType.SATURDAY,
            6: DayType.SUNDAY,
        }
        return day_map.get(weekday, DayType.WEEKDAY)

    def _get_season(self, month: int) -> Season:
        """
        Get season from month.

        Args:
            month: Month (1-12)

        Returns:
            Corresponding Season
        """
        if 3 <= month <= 5:
            return Season.SPRING
        elif 6 <= month <= 8:
            return Season.SUMMER
        elif 9 <= month <= 11:
            return Season.AUTUMN
        else:  # 12, 1, 2
            return Season.WINTER

    def get_current_period(self) -> GamePeriod:
        """
        Get current game time period.

        Returns:
            Current GamePeriod
        """
        game_time = self.calculate_game_time()
        return game_time.period

    def is_daytime(self) -> bool:
        """
        Check if it's currently daytime in game.

        Returns:
            True if daytime (6:00-17:59)
        """
        game_time = self.calculate_game_time()
        return game_time.is_daytime

    def is_nighttime(self) -> bool:
        """
        Check if it's currently nighttime in game.

        Returns:
            True if nighttime (18:00-5:59)
        """
        return not self.is_daytime()

    def get_time_until_period(self, target_period: GamePeriod) -> timedelta:
        """
        Calculate time until a specific game period.

        Args:
            target_period: Target GamePeriod

        Returns:
            Time remaining until period starts
        """
        current = self.calculate_game_time()

        # Map periods to start hours
        period_hours = {
            GamePeriod.NIGHT: 0,
            GamePeriod.DAWN: 5,
            GamePeriod.MORNING: 7,
            GamePeriod.NOON: 12,
            GamePeriod.AFTERNOON: 14,
            GamePeriod.DUSK: 18,
            GamePeriod.EVENING: 20,
        }

        target_hour = period_hours.get(target_period, 0)
        current_hour = current.game_hour

        # Calculate hours until target
        if target_hour > current_hour:
            hours_diff = target_hour - current_hour
        else:
            hours_diff = 24 - current_hour + target_hour

        # Convert game hours to real hours (1 game hour = 15 real minutes)
        real_minutes = hours_diff * 15
        return timedelta(minutes=real_minutes)

    def get_time_until_reset(self, reset_type: ServerResetType) -> timedelta:
        """
        Calculate time until next server reset.

        Args:
            reset_type: Type of reset to check

        Returns:
            Time until reset
        """
        now = self.get_server_time()

        if reset_type == ServerResetType.DAILY:
            # Daily reset at 4 AM server time
            reset_hour = 4
            next_reset = now.replace(hour=reset_hour, minute=0, second=0, microsecond=0)
            if now.hour >= reset_hour:
                next_reset += timedelta(days=1)
            return next_reset - now

        elif reset_type == ServerResetType.WEEKLY:
            # Weekly reset on Monday at 4 AM
            days_until_monday = (7 - now.weekday()) % 7
            if days_until_monday == 0 and now.hour >= 4:
                days_until_monday = 7
            next_reset = now + timedelta(days=days_until_monday)
            next_reset = next_reset.replace(hour=4, minute=0, second=0, microsecond=0)
            return next_reset - now

        elif reset_type == ServerResetType.MONTHLY:
            # Monthly reset on 1st at 4 AM
            next_month = now.month + 1 if now.month < 12 else 1
            next_year = now.year if now.month < 12 else now.year + 1
            next_reset = datetime(next_year, next_month, 1, 4, 0, 0)
            return next_reset - now

        return timedelta(0)

    def get_next_reset_time(self, reset_type: ServerResetType) -> datetime:
        """
        Get next reset time for type.

        Args:
            reset_type: Type of reset

        Returns:
            Next reset datetime
        """
        now = self.get_server_time()
        time_until = self.get_time_until_reset(reset_type)
        return now + time_until

    def get_current_season(self) -> Season:
        """
        Get current season based on server date.

        Returns:
            Current Season
        """
        server_time = self.get_server_time()
        return self._get_season(server_time.month)

    def is_event_active(self, event_name: str) -> bool:
        """
        Check if a seasonal event is active.

        Args:
            event_name: Name of the event

        Returns:
            True if event is currently active
        """
        # This will be implemented with event manager integration
        # For now, return False
        return False

    def get_active_events(self) -> List[str]:
        """
        Get list of currently active events.

        Returns:
            List of active event names
        """
        # This will be implemented with event manager integration
        return []