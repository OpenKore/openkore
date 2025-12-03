"""
Comprehensive tests for environment/events.py module.

Tests seasonal event management, quest tracking, reward optimization,
and event farming strategies.
"""

import json
import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

from ai_sidecar.environment.events import (
    EventType,
    EventReward,
    EventQuest,
    SeasonalEvent,
    EventManager
)
from ai_sidecar.environment.time_core import TimeManager


# Event Model Tests

class TestEventRewardModel:
    """Test EventReward pydantic model."""
    
    def test_event_reward_creation(self):
        """Test creating event reward."""
        reward = EventReward(
            reward_type="item",
            reward_id=501,
            reward_name="Red Potion",
            quantity=10,
            probability=0.5
        )
        assert reward.reward_type == "item"
        assert reward.quantity == 10
        assert reward.probability == 0.5


class TestEventQuestModel:
    """Test EventQuest pydantic model."""
    
    def test_event_quest_creation(self):
        """Test creating event quest."""
        quest = EventQuest(
            quest_id=1000,
            quest_name="Christmas Quest",
            description="Deliver gifts",
            is_daily=True,
            is_repeatable=True
        )
        assert quest.quest_name == "Christmas Quest"
        assert quest.is_daily is True


class TestSeasonalEventModel:
    """Test SeasonalEvent pydantic model."""
    
    def test_seasonal_event_creation(self):
        """Test creating seasonal event."""
        start = datetime(2025, 12, 20)
        end = datetime(2025, 12, 31)
        
        event = SeasonalEvent(
            event_id="christmas_2025",
            event_type=EventType.CHRISTMAS,
            event_name="Christmas Event",
            description="Holiday celebration",
            start_date=start,
            end_date=end,
            exp_bonus=1.5,
            drop_bonus=1.3
        )
        assert event.event_id == "christmas_2025"
        assert event.exp_bonus == 1.5


# EventManager Tests

class TestEventManagerInit:
    """Test EventManager initialization."""
    
    def test_init_no_data_file(self, tmp_path):
        """Test initialization without data file."""
        time_mgr = Mock(spec=TimeManager)
        manager = EventManager(tmp_path, time_mgr)
        assert len(manager.events) == 0
    
    def test_init_with_valid_data(self, tmp_path):
        """Test initialization with valid event data."""
        data_file = tmp_path / "seasonal_events.json"
        test_data = {
            "events": {
                "test_event": {
                    "event_type": "custom",
                    "event_name": "Test Event",
                    "description": "Test",
                    "start_month": 6,
                    "start_day": 1,
                    "end_month": 6,
                    "end_day": 30,
                    "exp_bonus": 1.5,
                    "drop_bonus": 1.3,
                    "event_maps": ["prontera"],
                    "special_monsters": ["Poring"],
                    "special_quests": ["Simple Quest"]
                }
            }
        }
        
        with open(data_file, "w") as f:
            json.dump(test_data, f)
        
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 6, 15)
        
        manager = EventManager(tmp_path, time_mgr)
        assert "test_event" in manager.events
    
    def test_init_with_year_spanning_event(self, tmp_path):
        """Test loading event that spans year boundary."""
        data_file = tmp_path / "seasonal_events.json"
        test_data = {
            "events": {
                "winter_event": {
                    "event_type": "custom",
                    "event_name": "Winter",
                    "description": "Winter event",
                    "start_month": 12,
                    "start_day": 20,
                    "end_month": 1,
                    "end_day": 5,
                    "exp_bonus": 1.2
                }
            }
        }
        
        with open(data_file, "w") as f:
            json.dump(test_data, f)
        
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 12, 25)
        
        manager = EventManager(tmp_path, time_mgr)
        event = manager.events["winter_event"]
        
        # End date should be next year
        assert event.end_date.year == 2026


class TestIsEventActive:
    """Test event active checking."""
    
    def test_is_event_active_at_recurring_within_period(self):
        """Test recurring event within active period."""
        manager = self._create_test_manager()
        
        # Event active Dec 20-31
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CHRISTMAS,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 12, 20),
            end_date=datetime(2025, 12, 31),
            is_recurring=True
        )
        
        # Check during event (Dec 25)
        check_time = datetime(2025, 12, 25)
        assert manager._is_event_active_at(event, check_time) is True
    
    def test_is_event_active_at_recurring_before_period(self):
        """Test recurring event before active period."""
        manager = self._create_test_manager()
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CHRISTMAS,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 12, 20),
            end_date=datetime(2025, 12, 31),
            is_recurring=True
        )
        
        # Check before event (Dec 1)
        check_time = datetime(2025, 12, 1)
        assert manager._is_event_active_at(event, check_time) is False
    
    def test_is_event_active_at_year_spanning(self):
        """Test recurring event spanning year boundary."""
        manager = self._create_test_manager()
        
        # Event Dec 25 - Jan 5
        event = SeasonalEvent(
            event_id="winter",
            event_type=EventType.CUSTOM,
            event_name="Winter",
            description="Winter event",
            start_date=datetime(2025, 12, 25),
            end_date=datetime(2026, 1, 5),
            is_recurring=True
        )
        
        # Check in December (should be active)
        assert manager._is_event_active_at(event, datetime(2025, 12, 28)) is True
        
        # Check in January (should be active)
        assert manager._is_event_active_at(event, datetime(2026, 1, 3)) is True
        
        # Check in February (should not be active)
        assert manager._is_event_active_at(event, datetime(2026, 2, 1)) is False
    
    def test_is_event_active_at_non_recurring(self):
        """Test non-recurring event."""
        manager = self._create_test_manager()
        
        event = SeasonalEvent(
            event_id="one_time",
            event_type=EventType.CUSTOM,
            event_name="One Time",
            description="One-time event",
            start_date=datetime(2025, 6, 1),
            end_date=datetime(2025, 6, 30),
            is_recurring=False
        )
        
        # Within period
        assert manager._is_event_active_at(event, datetime(2025, 6, 15)) is True
        
        # After period
        assert manager._is_event_active_at(event, datetime(2025, 7, 1)) is False
    
    def _create_test_manager(self):
        """Helper to create test manager."""
        time_mgr = Mock(spec=TimeManager)
        return EventManager(Path("/tmp"), time_mgr)


class TestRefreshActiveEvents:
    """Test active event refresh."""
    
    def test_refresh_filters_active_events(self):
        """Test that refresh only includes active events."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 12, 25)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        # Add active event
        active_event = SeasonalEvent(
            event_id="active",
            event_type=EventType.CHRISTMAS,
            event_name="Active",
            description="Active event",
            start_date=datetime(2025, 12, 20),
            end_date=datetime(2025, 12, 31),
            is_recurring=True
        )
        manager.events["active"] = active_event
        
        # Add inactive event
        inactive_event = SeasonalEvent(
            event_id="inactive",
            event_type=EventType.SUMMER,
            event_name="Inactive",
            description="Inactive event",
            start_date=datetime(2025, 7, 1),
            end_date=datetime(2025, 7, 31),
            is_recurring=True
        )
        manager.events["inactive"] = inactive_event
        
        manager.refresh_active_events()
        
        assert len(manager.active_events) == 1
        assert manager.active_events[0].event_id == "active"


class TestGetActiveEvents:
    """Test getting active events."""
    
    def test_get_active_events(self):
        """Test getting list of active events."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 6, 15)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="summer",
            event_type=EventType.SUMMER,
            event_name="Summer",
            description="Summer event",
            start_date=datetime(2025, 6, 1),
            end_date=datetime(2025, 6, 30),
            is_recurring=True
        )
        manager.events["summer"] = event
        
        active = manager.get_active_events()
        assert len(active) == 1
        assert active[0].event_id == "summer"


class TestIsEventActive:
    """Test event active check by ID."""
    
    def test_is_event_active_true(self):
        """Test checking if specific event is active."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 12, 25)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="christmas",
            event_type=EventType.CHRISTMAS,
            event_name="Christmas",
            description="Christmas event",
            start_date=datetime(2025, 12, 20),
            end_date=datetime(2025, 12, 31)
        )
        manager.events["christmas"] = event
        manager.active_events = [event]
        
        assert manager.is_event_active("christmas") is True
    
    def test_is_event_active_false(self):
        """Test checking inactive event."""
        manager = EventManager(Path("/tmp"), Mock())
        manager.active_events = []
        
        assert manager.is_event_active("nonexistent") is False


class TestGetEventTimeRemaining:
    """Test time remaining calculation."""
    
    def test_get_time_remaining_nonexistent_event(self):
        """Test getting time for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        result = manager.get_event_time_remaining("nonexistent")
        assert result is None
    
    def test_get_time_remaining_inactive_event(self):
        """Test getting time for inactive event."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 1, 1)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="summer",
            event_type=EventType.SUMMER,
            event_name="Summer",
            description="Summer",
            start_date=datetime(2025, 7, 1),
            end_date=datetime(2025, 7, 31)
        )
        manager.events["summer"] = event
        
        result = manager.get_event_time_remaining("summer")
        assert result is None
    
    def test_get_time_remaining_recurring_event(self):
        """Test time remaining for recurring event."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 12, 25)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="christmas",
            event_type=EventType.CHRISTMAS,
            event_name="Christmas",
            description="Christmas",
            start_date=datetime(2025, 12, 20),
            end_date=datetime(2025, 12, 31),
            is_recurring=True
        )
        manager.events["christmas"] = event
        
        remaining = manager.get_event_time_remaining("christmas")
        assert remaining is not None
        assert remaining.days < 7
    
    def test_get_time_remaining_non_recurring(self):
        """Test time remaining for non-recurring event."""
        time_mgr = Mock(spec=TimeManager)
        current_time = datetime(2025, 6, 15)
        time_mgr.get_server_time.return_value = current_time
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        end_time = datetime(2025, 6, 30)
        event = SeasonalEvent(
            event_id="one_time",
            event_type=EventType.CUSTOM,
            event_name="One Time",
            description="One-time event",
            start_date=datetime(2025, 6, 1),
            end_date=end_time,
            is_recurring=False
        )
        manager.events["one_time"] = event
        
        remaining = manager.get_event_time_remaining("one_time")
        assert remaining is not None
        assert remaining.days == (end_time - current_time).days


class TestGetEventQuests:
    """Test getting event quests."""
    
    def test_get_quests_nonexistent_event(self):
        """Test getting quests for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        quests = manager.get_event_quests("nonexistent")
        assert quests == []
    
    def test_get_quests_existing_event(self):
        """Test getting quests for existing event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        quest1 = EventQuest(
            quest_id=1,
            quest_name="Quest 1",
            description="First quest"
        )
        quest2 = EventQuest(
            quest_id=2,
            quest_name="Quest 2",
            description="Second quest"
        )
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_quests=[quest1, quest2]
        )
        manager.events["test"] = event
        
        quests = manager.get_event_quests("test")
        assert len(quests) == 2
        assert quests[0].quest_id == 1


class TestGetIncompleteQuests:
    """Test getting incomplete quests."""
    
    def test_get_incomplete_no_completed(self):
        """Test when no quests are completed."""
        manager = EventManager(Path("/tmp"), Mock())
        
        quest1 = EventQuest(quest_id=1, quest_name="Q1", description="Q1")
        quest2 = EventQuest(quest_id=2, quest_name="Q2", description="Q2")
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_quests=[quest1, quest2]
        )
        manager.events["test"] = event
        
        incomplete = manager.get_incomplete_quests("test")
        assert len(incomplete) == 2
    
    def test_get_incomplete_some_completed(self):
        """Test filtering completed quests."""
        manager = EventManager(Path("/tmp"), Mock())
        
        quest1 = EventQuest(quest_id=1, quest_name="Q1", description="Q1")
        quest2 = EventQuest(quest_id=2, quest_name="Q2", description="Q2")
        quest3 = EventQuest(quest_id=3, quest_name="Q3", description="Q3")
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_quests=[quest1, quest2, quest3]
        )
        manager.events["test"] = event
        manager.completed_quests["test"] = [1, 2]
        
        incomplete = manager.get_incomplete_quests("test")
        assert len(incomplete) == 1
        assert incomplete[0].quest_id == 3


class TestGetDailyQuests:
    """Test getting daily quests."""
    
    def test_get_daily_quests_from_active_events(self):
        """Test getting daily quests from active events."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 6, 15)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        daily_quest = EventQuest(
            quest_id=1,
            quest_name="Daily Quest",
            description="Daily",
            is_daily=True
        )
        normal_quest = EventQuest(
            quest_id=2,
            quest_name="Normal Quest",
            description="Normal",
            is_daily=False
        )
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 6, 1),
            end_date=datetime(2025, 6, 30),
            event_quests=[daily_quest, normal_quest]
        )
        manager.events["test"] = event
        manager.active_events = [event]
        
        daily_quests = manager.get_daily_quests()
        assert len(daily_quests) == 1
        assert daily_quests[0][0] == "test"
        assert daily_quests[0][1].quest_id == 1


class TestCalculateEventPriority:
    """Test event priority calculation."""
    
    def test_calculate_priority_ending_soon(self):
        """Test high priority for ending soon."""
        time_mgr = Mock(spec=TimeManager)
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31)
        )
        manager.events["test"] = event
        
        # Mock time remaining to less than 1 day
        manager.get_event_time_remaining = Mock(return_value=timedelta(hours=12))
        
        priority = manager.calculate_event_priority(event)
        assert priority >= 100.0
    
    def test_calculate_priority_with_bonuses(self):
        """Test priority includes bonuses."""
        time_mgr = Mock()
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            exp_bonus=2.0,
            drop_bonus=1.5
        )
        manager.events["test"] = event
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=10))
        manager.get_incomplete_quests = Mock(return_value=[])
        
        priority = manager.calculate_event_priority(event)
        assert priority >= 20.0 + 15.0  # exp_bonus * 10 + drop_bonus * 10
    
    def test_calculate_priority_with_quests(self):
        """Test priority includes quest count."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31)
        )
        
        # Mock 3 incomplete quests
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=10))
        manager.get_incomplete_quests = Mock(return_value=[Mock(), Mock(), Mock()])
        
        priority = manager.calculate_event_priority(event)
        assert priority >= 15.0  # 3 quests * 5


class TestGetOptimalEventStrategy:
    """Test optimal strategy generation."""
    
    def test_get_strategy_nonexistent_event(self):
        """Test getting strategy for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        strategy = manager.get_optimal_event_strategy("nonexistent", {})
        assert strategy == {}
    
    def test_get_strategy_complete(self):
        """Test complete strategy generation."""
        time_mgr = Mock(spec=TimeManager)
        manager = EventManager(Path("/tmp"), time_mgr)
        
        quest = EventQuest(
            quest_id=1,
            quest_name="Test Quest",
            description="Test",
            is_daily=True
        )
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test Event",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_maps=["prontera", "payon"],
            event_monsters=["Poring", "Drops"],
            event_quests=[quest],
            exp_bonus=1.5,
            drop_bonus=1.3
        )
        manager.events["test"] = event
        
        manager.calculate_event_priority = Mock(return_value=75.0)
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=5))
        manager.get_incomplete_quests = Mock(return_value=[quest])
        
        strategy = manager.get_optimal_event_strategy("test", {})
        
        assert strategy["event_id"] == "test"
        assert strategy["priority"] == 75.0
        assert "prontera" in strategy["recommended_maps"]
        assert "Poring" in strategy["target_monsters"]
        assert strategy["expected_bonuses"]["exp"] == 1.5
        assert len(strategy["incomplete_quests"]) == 1
        assert len(strategy["daily_quests"]) == 1


class TestGetEventBonuses:
    """Test event bonus calculations."""
    
    def test_get_exp_bonus_no_events(self):
        """Test exp bonus with no active events."""
        manager = EventManager(Path("/tmp"), Mock())
        manager.active_events = []
        
        bonus = manager.get_event_exp_bonus()
        assert bonus == 1.0
    
    def test_get_exp_bonus_multiple_events(self):
        """Test exp bonus stacks multiplicatively."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event1 = SeasonalEvent(
            event_id="e1",
            event_type=EventType.CUSTOM,
            event_name="E1",
            description="E1",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            exp_bonus=1.5
        )
        event2 = SeasonalEvent(
            event_id="e2",
            event_type=EventType.CUSTOM,
            event_name="E2",
            description="E2",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            exp_bonus=1.2
        )
        manager.active_events = [event1, event2]
        
        bonus = manager.get_event_exp_bonus()
        assert bonus == 1.5 * 1.2
    
    def test_get_drop_bonus_multiple_events(self):
        """Test drop bonus stacks multiplicatively."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event1 = SeasonalEvent(
            event_id="e1",
            event_type=EventType.CUSTOM,
            event_name="E1",
            description="E1",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            drop_bonus=1.4
        )
        event2 = SeasonalEvent(
            event_id="e2",
            event_type=EventType.CUSTOM,
            event_name="E2",
            description="E2",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            drop_bonus=1.1
        )
        manager.active_events = [event1, event2]
        
        bonus = manager.get_event_drop_bonus()
        assert bonus == 1.4 * 1.1


class TestMarkQuestComplete:
    """Test quest completion marking."""
    
    def test_mark_quest_complete_new_event(self):
        """Test marking quest complete for new event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        manager.mark_quest_complete("test", 1234)
        
        assert "test" in manager.completed_quests
        assert 1234 in manager.completed_quests["test"]
    
    def test_mark_quest_complete_existing_event(self):
        """Test adding to existing event's completed quests."""
        manager = EventManager(Path("/tmp"), Mock())
        manager.completed_quests["test"] = [1000, 2000]
        
        manager.mark_quest_complete("test", 3000)
        
        assert len(manager.completed_quests["test"]) == 3
        assert 3000 in manager.completed_quests["test"]
    
    def test_mark_quest_complete_duplicate(self):
        """Test marking same quest complete twice."""
        manager = EventManager(Path("/tmp"), Mock())
        manager.completed_quests["test"] = [1000]
        
        manager.mark_quest_complete("test", 1000)
        
        # Should not duplicate
        assert manager.completed_quests["test"].count(1000) == 1


class TestGetEventMonstersAndMaps:
    """Test getting event monsters and maps."""
    
    def test_get_event_monsters_existing(self):
        """Test getting monsters for existing event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_monsters=["Poring", "Drops", "Poporing"]
        )
        manager.events["test"] = event
        
        monsters = manager.get_event_monsters("test")
        assert len(monsters) == 3
        assert "Poring" in monsters
    
    def test_get_event_monsters_nonexistent(self):
        """Test getting monsters for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        monsters = manager.get_event_monsters("nonexistent")
        assert monsters == []
    
    def test_get_event_maps_existing(self):
        """Test getting maps for existing event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            event_maps=["prontera", "payon", "geffen"]
        )
        manager.events["test"] = event
        
        maps = manager.get_event_maps("test")
        assert len(maps) == 3
        assert "geffen" in maps
    
    def test_get_event_maps_nonexistent(self):
        """Test getting maps for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        maps = manager.get_event_maps("nonexistent")
        assert maps == []


class TestShouldParticipate:
    """Test event participation decision."""
    
    def test_should_participate_nonexistent_event(self):
        """Test participation check for non-existent event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        should, reason = manager.should_participate("nonexistent", 99, 10.0)
        assert should is False
        assert "not found" in reason
    
    def test_should_participate_inactive_event(self):
        """Test participation check for inactive event."""
        time_mgr = Mock(spec=TimeManager)
        time_mgr.get_server_time.return_value = datetime(2025, 1, 1)
        
        manager = EventManager(Path("/tmp"), time_mgr)
        
        event = SeasonalEvent(
            event_id="summer",
            event_type=EventType.SUMMER,
            event_name="Summer",
            description="Summer",
            start_date=datetime(2025, 7, 1),
            end_date=datetime(2025, 7, 31)
        )
        manager.events["summer"] = event
        manager.active_events = []
        
        should, reason = manager.should_participate("summer", 99, 10.0)
        assert should is False
        assert "not currently active" in reason
    
    def test_should_participate_ending_soon(self):
        """Test high priority for ending soon."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31)
        )
        manager.events["test"] = event
        manager.active_events = [event]
        manager.is_event_active = Mock(return_value=True)
        manager.get_event_time_remaining = Mock(return_value=timedelta(minutes=30))
        
        should, reason = manager.should_participate("test", 99, 10.0)
        assert should is True
        assert "ending soon" in reason
    
    def test_should_participate_good_bonuses(self):
        """Test participation for significant bonuses."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            exp_bonus=1.5,
            drop_bonus=1.0
        )
        manager.events["test"] = event
        manager.active_events = [event]
        manager.is_event_active = Mock(return_value=True)
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=10))
        manager.get_incomplete_quests = Mock(return_value=[])
        
        should, reason = manager.should_participate("test", 99, 10.0)
        assert should is True
        assert "bonuses" in reason
    
    def test_should_participate_quests_available(self):
        """Test participation for available quests."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31)
        )
        manager.events["test"] = event
        manager.active_events = [event]
        manager.is_event_active = Mock(return_value=True)
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=10))
        manager.get_incomplete_quests = Mock(return_value=[Mock(), Mock()])
        
        should, reason = manager.should_participate("test", 99, 10.0)
        assert should is True
        assert "quests available" in reason
    
    def test_should_participate_low_priority(self):
        """Test low priority event."""
        manager = EventManager(Path("/tmp"), Mock())
        
        event = SeasonalEvent(
            event_id="test",
            event_type=EventType.CUSTOM,
            event_name="Test",
            description="Test",
            start_date=datetime(2025, 1, 1),
            end_date=datetime(2025, 1, 31),
            exp_bonus=1.0,
            drop_bonus=1.0
        )
        manager.events["test"] = event
        manager.active_events = [event]
        manager.is_event_active = Mock(return_value=True)
        manager.get_event_time_remaining = Mock(return_value=timedelta(days=20))
        manager.get_incomplete_quests = Mock(return_value=[])
        
        should, reason = manager.should_participate("test", 99, 10.0)
        assert should is False
        assert "Low priority" in reason


if __name__ == "__main__":
    pytest.main([__file__, "-v"])