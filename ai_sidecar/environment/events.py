"""
Seasonal Events System for OpenKore AI Sidecar.

Manages seasonal and special events including detection, quest tracking,
reward optimization, and event farming strategies.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.environment.time_core import TimeManager


class EventType(str, Enum):
    """Types of seasonal events."""

    CHRISTMAS = "christmas"
    NEW_YEAR = "new_year"
    VALENTINE = "valentine"
    EASTER = "easter"
    SUMMER = "summer"
    HALLOWEEN = "halloween"
    THANKSGIVING = "thanksgiving"
    ANNIVERSARY = "anniversary"
    SERVER_BIRTHDAY = "server_birthday"
    CUSTOM = "custom"


class EventReward(BaseModel):
    """Event reward definition."""

    reward_type: str  # "item", "exp", "zeny", "title", "costume"
    reward_id: int
    reward_name: str
    quantity: int = Field(default=1, ge=1)
    probability: float = Field(default=1.0, ge=0.0, le=1.0)


class EventQuest(BaseModel):
    """Event quest definition."""

    quest_id: int
    quest_name: str
    description: str
    requirements: Dict[str, Any] = Field(default_factory=dict)
    rewards: List[EventReward] = Field(default_factory=list)
    is_daily: bool = False
    is_repeatable: bool = False


class SeasonalEvent(BaseModel):
    """Seasonal event definition."""

    event_id: str
    event_type: EventType
    event_name: str
    description: str

    # Timing
    start_date: datetime
    end_date: datetime
    is_recurring: bool = True  # Happens every year

    # Content
    event_maps: List[str] = Field(default_factory=list)
    event_npcs: Dict[str, Tuple[int, int]] = Field(default_factory=dict)
    event_monsters: List[str] = Field(default_factory=list)
    event_quests: List[EventQuest] = Field(default_factory=list)

    # Rewards
    special_drops: Dict[str, List[EventReward]] = Field(default_factory=dict)
    participation_rewards: List[EventReward] = Field(default_factory=list)

    # Bonuses
    exp_bonus: float = Field(default=1.0, ge=1.0)
    drop_bonus: float = Field(default=1.0, ge=1.0)
    special_buffs: List[str] = Field(default_factory=list)


class EventManager:
    """
    Manage seasonal and special events.

    Features:
    - Event detection and timing
    - Quest tracking
    - Reward optimization
    - Event farming strategies
    """

    def __init__(self, data_dir: Path, time_manager: TimeManager):
        """
        Initialize EventManager.

        Args:
            data_dir: Directory containing event configuration files
            time_manager: TimeManager instance for time calculations
        """
        self.log = structlog.get_logger()
        self.time_manager = time_manager
        self.events: Dict[str, SeasonalEvent] = {}
        self.active_events: List[SeasonalEvent] = []
        self.completed_quests: Dict[str, List[int]] = {}  # event_id -> quest_ids
        self._load_events(data_dir)

    def _load_events(self, data_dir: Path) -> None:
        """
        Load event definitions from configuration.

        Args:
            data_dir: Data directory path
        """
        try:
            events_file = data_dir / "seasonal_events.json"
            if events_file.exists():
                with open(events_file, "r") as f:
                    data = json.load(f)

                    events_data = data.get("events", {})
                    current_year = datetime.now().year

                    for event_id, event_config in events_data.items():
                        # Parse dates
                        start_month = event_config.get("start_month", 1)
                        start_day = event_config.get("start_day", 1)
                        end_month = event_config.get("end_month", 12)
                        end_day = event_config.get("end_day", 31)

                        start_date = datetime(
                            current_year, start_month, start_day
                        )

                        # Handle events that span year boundary
                        if end_month < start_month:
                            end_date = datetime(
                                current_year + 1, end_month, end_day, 23, 59, 59
                            )
                        else:
                            end_date = datetime(
                                current_year, end_month, end_day, 23, 59, 59
                            )

                        # Parse quests
                        quests = []
                        for quest_data in event_config.get("special_quests", []):
                            if isinstance(quest_data, str):
                                # Simple quest name
                                quest = EventQuest(
                                    quest_id=hash(quest_data) % 10000,
                                    quest_name=quest_data,
                                    description=f"Event quest: {quest_data}",
                                    requirements={},
                                    rewards=[],
                                )
                            else:
                                # Detailed quest
                                quest = EventQuest(**quest_data)
                            quests.append(quest)

                        event = SeasonalEvent(
                            event_id=event_id,
                            event_type=EventType(event_config.get("event_type", "custom")),
                            event_name=event_config.get("event_name", event_id),
                            description=event_config.get("description", ""),
                            start_date=start_date,
                            end_date=end_date,
                            is_recurring=event_config.get("is_recurring", True),
                            event_maps=event_config.get("event_maps", []),
                            event_monsters=event_config.get("special_monsters", []),
                            event_quests=quests,
                            exp_bonus=event_config.get("exp_bonus", 1.0),
                            drop_bonus=event_config.get("drop_bonus", 1.0),
                        )

                        self.events[event_id] = event

            self.log.info("events_loaded", count=len(self.events))
            self.refresh_active_events()
        except Exception as e:
            self.log.error("failed_to_load_events", error=str(e))

    def refresh_active_events(self) -> None:
        """Refresh list of currently active events."""
        now = self.time_manager.get_server_time()
        self.active_events = []

        for event in self.events.values():
            if self._is_event_active_at(event, now):
                self.active_events.append(event)

        self.log.info("active_events_refreshed", count=len(self.active_events))

    def _is_event_active_at(self, event: SeasonalEvent, check_time: datetime) -> bool:
        """
        Check if event is active at specific time.

        Args:
            event: Event to check
            check_time: Time to check

        Returns:
            True if event is active
        """
        # Handle recurring events
        if event.is_recurring:
            # Check if current date falls within event period
            current_month_day = (check_time.month, check_time.day)
            start_month_day = (event.start_date.month, event.start_date.day)
            end_month_day = (event.end_date.month, event.end_date.day)

            if start_month_day <= end_month_day:
                # Event doesn't span year boundary
                return start_month_day <= current_month_day <= end_month_day
            else:
                # Event spans year boundary (e.g., Dec-Jan)
                return current_month_day >= start_month_day or current_month_day <= end_month_day

        # Non-recurring event
        return event.start_date <= check_time <= event.end_date

    def get_active_events(self) -> List[SeasonalEvent]:
        """
        Get all currently active events.

        Returns:
            List of active SeasonalEvent objects
        """
        self.refresh_active_events()
        return self.active_events

    def is_event_active(self, event_id: str) -> bool:
        """
        Check if specific event is active.

        Args:
            event_id: Event identifier

        Returns:
            True if event is active
        """
        return any(e.event_id == event_id for e in self.active_events)

    def get_event_time_remaining(self, event_id: str) -> Optional[timedelta]:
        """
        Get time remaining for an event.

        Args:
            event_id: Event identifier

        Returns:
            Time remaining or None if not active
        """
        event = self.events.get(event_id)
        if not event:
            return None

        now = self.time_manager.get_server_time()
        if not self._is_event_active_at(event, now):
            return None

        # Calculate time until end
        if event.is_recurring:
            # For recurring events, calculate until this year's end date
            end_date = datetime(
                now.year, event.end_date.month, event.end_date.day, 23, 59, 59
            )
            if now > end_date:
                # Already passed this year, calculate for next year
                end_date = datetime(
                    now.year + 1, event.end_date.month, event.end_date.day, 23, 59, 59
                )
            return end_date - now

        return event.end_date - now

    def get_event_quests(self, event_id: str) -> List[EventQuest]:
        """
        Get available quests for an event.

        Args:
            event_id: Event identifier

        Returns:
            List of EventQuest objects
        """
        event = self.events.get(event_id)
        if not event:
            return []
        return event.event_quests

    def get_incomplete_quests(self, event_id: str) -> List[EventQuest]:
        """
        Get incomplete quests for an event.

        Args:
            event_id: Event identifier

        Returns:
            List of incomplete EventQuest objects
        """
        all_quests = self.get_event_quests(event_id)
        completed = self.completed_quests.get(event_id, [])

        return [q for q in all_quests if q.quest_id not in completed]

    def get_daily_quests(self) -> List[Tuple[str, EventQuest]]:
        """
        Get all daily event quests across active events.

        Returns:
            List of (event_id, EventQuest) tuples
        """
        daily = []
        for event in self.active_events:
            for quest in event.event_quests:
                if quest.is_daily:
                    daily.append((event.event_id, quest))
        return daily

    def calculate_event_priority(self, event: SeasonalEvent) -> float:
        """
        Calculate priority for farming an event.

        Args:
            event: Event to evaluate

        Returns:
            Priority score (higher = more important)
        """
        priority = 0.0

        # Time sensitivity (ending soon = higher priority)
        time_remaining = self.get_event_time_remaining(event.event_id)
        if time_remaining:
            days_remaining = time_remaining.days
            if days_remaining < 1:
                priority += 100.0
            elif days_remaining < 3:
                priority += 50.0
            elif days_remaining < 7:
                priority += 25.0

        # Reward value
        priority += event.exp_bonus * 10
        priority += event.drop_bonus * 10

        # Quest availability
        incomplete = self.get_incomplete_quests(event.event_id)
        priority += len(incomplete) * 5

        return priority

    def get_optimal_event_strategy(
        self, event_id: str, own_state: dict
    ) -> dict:
        """
        Get optimal strategy for event participation.

        Args:
            event_id: Event identifier
            own_state: Character state dict

        Returns:
            Strategy dictionary
        """
        event = self.events.get(event_id)
        if not event:
            return {}

        strategy = {
            "event_id": event_id,
            "priority": self.calculate_event_priority(event),
            "time_remaining": str(self.get_event_time_remaining(event_id)),
            "recommended_maps": event.event_maps,
            "target_monsters": event.event_monsters,
            "incomplete_quests": [],
            "daily_quests": [],
            "expected_bonuses": {
                "exp": event.exp_bonus,
                "drop": event.drop_bonus,
            },
        }

        # Add quest information
        incomplete = self.get_incomplete_quests(event_id)
        strategy["incomplete_quests"] = [
            {"id": q.quest_id, "name": q.quest_name} for q in incomplete
        ]

        daily = [q for q in event.event_quests if q.is_daily]
        strategy["daily_quests"] = [
            {"id": q.quest_id, "name": q.quest_name} for q in daily
        ]

        return strategy

    def get_event_exp_bonus(self) -> float:
        """
        Get combined EXP bonus from active events.

        Returns:
            Total EXP multiplier
        """
        total_bonus = 1.0
        for event in self.active_events:
            total_bonus *= event.exp_bonus
        return total_bonus

    def get_event_drop_bonus(self) -> float:
        """
        Get combined drop bonus from active events.

        Returns:
            Total drop rate multiplier
        """
        total_bonus = 1.0
        for event in self.active_events:
            total_bonus *= event.drop_bonus
        return total_bonus

    def mark_quest_complete(self, event_id: str, quest_id: int) -> None:
        """
        Mark an event quest as completed.

        Args:
            event_id: Event identifier
            quest_id: Quest identifier
        """
        if event_id not in self.completed_quests:
            self.completed_quests[event_id] = []

        if quest_id not in self.completed_quests[event_id]:
            self.completed_quests[event_id].append(quest_id)
            self.log.info("quest_completed", event=event_id, quest=quest_id)

    def get_event_monsters(self, event_id: str) -> List[str]:
        """
        Get special monsters for an event.

        Args:
            event_id: Event identifier

        Returns:
            List of monster names
        """
        event = self.events.get(event_id)
        if not event:
            return []
        return event.event_monsters

    def get_event_maps(self, event_id: str) -> List[str]:
        """
        Get event-specific maps.

        Args:
            event_id: Event identifier

        Returns:
            List of map names
        """
        event = self.events.get(event_id)
        if not event:
            return []
        return event.event_maps

    def should_participate(
        self, event_id: str, character_level: int, available_time_hours: float
    ) -> Tuple[bool, str]:
        """
        Determine if should participate in an event.

        Args:
            event_id: Event identifier
            character_level: Character's level
            available_time_hours: Available playtime

        Returns:
            Tuple of (should_participate, reason)
        """
        event = self.events.get(event_id)
        if not event:
            return False, "Event not found"

        if not self.is_event_active(event_id):
            return False, "Event not currently active"

        # Check time remaining
        time_remaining = self.get_event_time_remaining(event_id)
        if time_remaining and time_remaining.total_seconds() < 3600:
            return True, "Event ending soon - high priority"

        # Check bonuses
        if event.exp_bonus > 1.2 or event.drop_bonus > 1.2:
            return True, "Significant bonuses available"

        # Check quest availability
        incomplete = self.get_incomplete_quests(event_id)
        if incomplete:
            return True, f"{len(incomplete)} quests available"

        return False, "Low priority event"