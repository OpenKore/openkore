"""
Comprehensive tests for Instance Cooldown Management system.

Tests cover:
- Cooldown entry model and properties
- Cooldown tracking per character
- Daily and weekly resets
- Availability checking
- Completion recording
- Schedule optimization
- Reset handling
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, AsyncMock

from ai_sidecar.instances.cooldowns import (
    CooldownEntry,
    CooldownManager
)
from ai_sidecar.instances.registry import InstanceRegistry


# Fixtures

@pytest.fixture
def cooldown_manager():
    """Create cooldown manager."""
    return CooldownManager()


@pytest.fixture
def mock_registry():
    """Create mock instance registry."""
    registry = Mock(spec=InstanceRegistry)
    registry.instances = {
        "endless_tower": Mock(instance_id="endless_tower"),
        "orc_memory": Mock(instance_id="orc_memory"),
        "nidhogg": Mock(instance_id="nidhogg"),
    }
    return registry


@pytest.fixture
def sample_entry():
    """Create sample cooldown entry."""
    now = datetime.now()
    return CooldownEntry(
        instance_id="endless_tower",
        character_name="TestChar",
        last_completed=now - timedelta(hours=12),
        cooldown_ends=now + timedelta(hours=12),
        times_completed_today=1,
        times_completed_week=3
    )


# CooldownEntry Model Tests

class TestCooldownEntryModel:
    """Test CooldownEntry model."""
    
    def test_create_entry(self):
        """Test creating cooldown entry."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test_instance",
            character_name="TestChar",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24)
        )
        
        assert entry.instance_id == "test_instance"
        assert entry.character_name == "TestChar"
        assert entry.times_completed_today == 0
        assert entry.times_completed_week == 0
    
    def test_entry_is_available_true(self):
        """Test is_available when cooldown expired."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1)
        )
        
        assert entry.is_available is True
    
    def test_entry_is_available_false(self):
        """Test is_available when on cooldown."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now - timedelta(hours=1),
            cooldown_ends=now + timedelta(hours=23)
        )
        
        assert entry.is_available is False
    
    def test_entry_time_until_available_zero(self):
        """Test time_until_available when already available."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1)
        )
        
        time_until = entry.time_until_available
        assert time_until == timedelta(0)
    
    def test_entry_time_until_available_positive(self):
        """Test time_until_available when on cooldown."""
        now = datetime.now()
        cooldown_ends = now + timedelta(hours=5)
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now,
            cooldown_ends=cooldown_ends
        )
        
        time_until = entry.time_until_available
        assert time_until > timedelta(hours=4, minutes=59)
        assert time_until < timedelta(hours=5, minutes=1)
    
    def test_entry_hours_until_available(self):
        """Test hours_until_available calculation."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=3, minutes=30)
        )
        
        hours = entry.hours_until_available
        assert 3.4 <= hours <= 3.6
    
    def test_entry_hours_until_available_zero(self):
        """Test hours_until_available when available."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1)
        )
        
        assert entry.hours_until_available == 0.0
    
    def test_entry_with_high_completion_counts(self):
        """Test entry with high completion counts."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=10,
            times_completed_week=50
        )
        
        assert entry.times_completed_today == 10
        assert entry.times_completed_week == 50


# CooldownManager Initialization Tests

class TestCooldownManagerInit:
    """Test cooldown manager initialization."""
    
    def test_manager_initialization(self, cooldown_manager):
        """Test manager initializes correctly."""
        assert cooldown_manager.cooldowns == {}
        assert cooldown_manager.last_daily_reset is not None
        assert cooldown_manager.last_weekly_reset is not None
    
    def test_manager_has_logger(self, cooldown_manager):
        """Test manager has logger."""
        assert cooldown_manager.log is not None
    
    def test_manager_reset_constants(self):
        """Test reset time constants."""
        assert CooldownManager.DAILY_RESET_HOUR == 0
        assert CooldownManager.WEEKLY_RESET_DAY == 2


# Reset Handling Tests

class TestResetHandling:
    """Test daily and weekly reset handling."""
    
    def test_daily_reset_initialization(self, cooldown_manager):
        """Test daily reset time is initialized."""
        assert cooldown_manager.last_daily_reset is not None
        
        # Should be at midnight UTC
        reset_time = cooldown_manager.last_daily_reset
        assert reset_time.hour == 0
        assert reset_time.minute == 0
        assert reset_time.second == 0
    
    def test_weekly_reset_initialization(self, cooldown_manager):
        """Test weekly reset time is initialized."""
        assert cooldown_manager.last_weekly_reset is not None
        
        # Should be on Tuesday
        reset_time = cooldown_manager.last_weekly_reset
        assert reset_time.weekday() == 2  # Tuesday
        assert reset_time.hour == 0
    
    def test_apply_daily_reset(self, cooldown_manager):
        """Test daily reset clears today counts."""
        # Add some entries with today counts
        now = datetime.now()
        cooldown_manager.cooldowns[("char1", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="char1",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=5,
            times_completed_week=10
        )
        
        cooldown_manager._apply_daily_reset()
        
        entry = cooldown_manager.cooldowns[("char1", "inst1")]
        assert entry.times_completed_today == 0
        assert entry.times_completed_week == 10  # Should not change
    
    def test_apply_weekly_reset(self, cooldown_manager):
        """Test weekly reset clears week counts."""
        # Add some entries with week counts
        now = datetime.now()
        cooldown_manager.cooldowns[("char1", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="char1",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=5,
            times_completed_week=20
        )
        
        cooldown_manager._apply_weekly_reset()
        
        entry = cooldown_manager.cooldowns[("char1", "inst1")]
        assert entry.times_completed_week == 0
        assert entry.times_completed_today == 5  # Should not change
    
    @pytest.mark.asyncio
    async def test_handle_reset_daily(self, cooldown_manager):
        """Test manual daily reset trigger."""
        now = datetime.now()
        cooldown_manager.cooldowns[("char1", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="char1",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=3,
            times_completed_week=10
        )
        
        await cooldown_manager.handle_reset("daily")
        
        entry = cooldown_manager.cooldowns[("char1", "inst1")]
        assert entry.times_completed_today == 0
    
    @pytest.mark.asyncio
    async def test_handle_reset_weekly(self, cooldown_manager):
        """Test manual weekly reset trigger."""
        now = datetime.now()
        cooldown_manager.cooldowns[("char1", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="char1",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=3,
            times_completed_week=15
        )
        
        await cooldown_manager.handle_reset("weekly")
        
        entry = cooldown_manager.cooldowns[("char1", "inst1")]
        assert entry.times_completed_week == 0
    
    @pytest.mark.asyncio
    async def test_handle_reset_unknown_type(self, cooldown_manager):
        """Test handling unknown reset type."""
        # Should not crash
        await cooldown_manager.handle_reset("monthly")


# Cooldown Checking Tests

class TestCooldownChecking:
    """Test cooldown availability checking."""
    
    @pytest.mark.asyncio
    async def test_check_cooldown_no_entry(self, cooldown_manager):
        """Test checking cooldown with no existing entry."""
        is_available, time_until = await cooldown_manager.check_cooldown(
            "new_instance",
            "TestChar"
        )
        
        assert is_available is True
        assert time_until is None
    
    @pytest.mark.asyncio
    async def test_check_cooldown_available(self, cooldown_manager):
        """Test checking available instance."""
        now = datetime.now()
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1)
        )
        
        is_available, time_until = await cooldown_manager.check_cooldown(
            "inst1",
            "TestChar"
        )
        
        assert is_available is True
        assert time_until is None
    
    @pytest.mark.asyncio
    async def test_check_cooldown_on_cooldown(self, cooldown_manager):
        """Test checking instance on cooldown."""
        now = datetime.now()
        cooldown_ends = now + timedelta(hours=5)
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now,
            cooldown_ends=cooldown_ends
        )
        
        is_available, time_until = await cooldown_manager.check_cooldown(
            "inst1",
            "TestChar"
        )
        
        assert is_available is False
        assert time_until is not None
        assert time_until > timedelta(hours=4, minutes=59)


# Completion Recording Tests

class TestRecordCompletion:
    """Test recording instance completions."""
    
    @pytest.mark.asyncio
    async def test_record_first_completion(self, cooldown_manager):
        """Test recording first completion creates entry."""
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            24
        )
        
        key = ("TestChar", "inst1")
        assert key in cooldown_manager.cooldowns
        
        entry = cooldown_manager.cooldowns[key]
        assert entry.instance_id == "inst1"
        assert entry.character_name == "TestChar"
        assert entry.times_completed_today == 1
        assert entry.times_completed_week == 1
    
    @pytest.mark.asyncio
    async def test_record_subsequent_completion(self, cooldown_manager):
        """Test recording subsequent completion updates entry."""
        now = datetime.now()
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1),
            times_completed_today=2,
            times_completed_week=5
        )
        
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            24
        )
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.times_completed_today == 3
        assert entry.times_completed_week == 6
    
    @pytest.mark.asyncio
    async def test_record_completion_sets_cooldown(self, cooldown_manager):
        """Test completion sets appropriate cooldown."""
        before = datetime.now()
        
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            12  # 12 hour cooldown
        )
        
        after = datetime.now()
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        
        expected_cooldown = before + timedelta(hours=12)
        assert entry.cooldown_ends >= expected_cooldown - timedelta(seconds=1)
        assert entry.cooldown_ends <= after + timedelta(hours=12, seconds=1)
    
    @pytest.mark.asyncio
    async def test_record_completion_zero_cooldown(self, cooldown_manager):
        """Test recording with zero cooldown."""
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            0
        )
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.is_available is True


# Get Available Instances Tests

class TestGetAvailableInstances:
    """Test getting available instances."""
    
    @pytest.mark.asyncio
    async def test_get_available_all_available(self, cooldown_manager, mock_registry):
        """Test when all instances are available."""
        available = await cooldown_manager.get_available_instances(
            "TestChar",
            mock_registry
        )
        
        assert len(available) == 3
        assert "endless_tower" in available
        assert "orc_memory" in available
        assert "nidhogg" in available
    
    @pytest.mark.asyncio
    async def test_get_available_some_on_cooldown(self, cooldown_manager, mock_registry):
        """Test with some instances on cooldown."""
        now = datetime.now()
        cooldown_manager.cooldowns[("TestChar", "endless_tower")] = CooldownEntry(
            instance_id="endless_tower",
            character_name="TestChar",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24)
        )
        
        available = await cooldown_manager.get_available_instances(
            "TestChar",
            mock_registry
        )
        
        assert len(available) == 2
        assert "endless_tower" not in available
        assert "orc_memory" in available
        assert "nidhogg" in available
    
    @pytest.mark.asyncio
    async def test_get_available_all_on_cooldown(self, cooldown_manager, mock_registry):
        """Test when all instances on cooldown."""
        now = datetime.now()
        for instance_id in ["endless_tower", "orc_memory", "nidhogg"]:
            cooldown_manager.cooldowns[("TestChar", instance_id)] = CooldownEntry(
                instance_id=instance_id,
                character_name="TestChar",
                last_completed=now,
                cooldown_ends=now + timedelta(hours=24)
            )
        
        available = await cooldown_manager.get_available_instances(
            "TestChar",
            mock_registry
        )
        
        assert len(available) == 0


# Optimal Schedule Tests

class TestOptimalSchedule:
    """Test optimal schedule planning."""
    
    @pytest.mark.asyncio
    async def test_schedule_all_available(self, cooldown_manager):
        """Test scheduling when all available."""
        desired = ["inst1", "inst2", "inst3"]
        
        schedule = await cooldown_manager.get_optimal_schedule(
            "TestChar",
            desired
        )
        
        assert len(schedule) == 3
        for instance_id in desired:
            assert instance_id in schedule
    
    @pytest.mark.asyncio
    async def test_schedule_with_cooldowns(self, cooldown_manager):
        """Test scheduling with some on cooldown."""
        now = datetime.now()
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now - timedelta(hours=20),
            cooldown_ends=now + timedelta(hours=4)
        )
        
        desired = ["inst1", "inst2"]
        schedule = await cooldown_manager.get_optimal_schedule(
            "TestChar",
            desired
        )
        
        # inst2 should be scheduled now
        assert schedule["inst2"] <= datetime.now() + timedelta(minutes=1)
        
        # inst1 should be scheduled after cooldown
        assert schedule["inst1"] >= now + timedelta(hours=3, minutes=59)
    
    @pytest.mark.asyncio
    async def test_schedule_spacing(self, cooldown_manager):
        """Test schedule spaces out available instances."""
        desired = ["inst1", "inst2", "inst3"]
        
        schedule = await cooldown_manager.get_optimal_schedule(
            "TestChar",
            desired
        )
        
        times = sorted(schedule.values())
        # Should be spaced by approximately 1 hour
        if len(times) > 1:
            time_diff = times[1] - times[0]
            assert timedelta(minutes=59) <= time_diff <= timedelta(hours=1, minutes=1)
    
    @pytest.mark.asyncio
    async def test_schedule_empty_list(self, cooldown_manager):
        """Test scheduling with empty list."""
        schedule = await cooldown_manager.get_optimal_schedule(
            "TestChar",
            []
        )
        
        assert len(schedule) == 0


# Cooldown Summary Tests

class TestCooldownSummary:
    """Test cooldown summary generation."""
    
    def test_summary_no_cooldowns(self, cooldown_manager):
        """Test summary with no cooldowns."""
        summary = cooldown_manager.get_cooldown_summary("TestChar")
        
        assert summary["total_instances"] == 0
        assert summary["available"] == 0
        assert summary["on_cooldown"] == 0
        assert summary["times_run_today"] == 0
        assert summary["times_run_week"] == 0
    
    def test_summary_with_cooldowns(self, cooldown_manager):
        """Test summary with mixed cooldown states."""
        now = datetime.now()
        
        # Available instance
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now - timedelta(hours=25),
            cooldown_ends=now - timedelta(hours=1),
            times_completed_today=1,
            times_completed_week=3
        )
        
        # On cooldown instance
        cooldown_manager.cooldowns[("TestChar", "inst2")] = CooldownEntry(
            instance_id="inst2",
            character_name="TestChar",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=12),
            times_completed_today=2,
            times_completed_week=5
        )
        
        summary = cooldown_manager.get_cooldown_summary("TestChar")
        
        assert summary["total_instances"] == 2
        assert summary["available"] == 1
        assert summary["on_cooldown"] == 1
        assert summary["times_run_today"] == 3
        assert summary["times_run_week"] == 8
    
    def test_summary_cooldown_details(self, cooldown_manager):
        """Test summary includes cooldown details."""
        now = datetime.now()
        cooldown_manager.cooldowns[("TestChar", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="TestChar",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=5),
            times_completed_today=1,
            times_completed_week=1
        )
        
        summary = cooldown_manager.get_cooldown_summary("TestChar")
        
        assert "cooldown_details" in summary
        assert len(summary["cooldown_details"]) == 1
        
        detail = summary["cooldown_details"][0]
        assert detail["instance_id"] == "inst1"
        assert 4.9 <= detail["hours_remaining"] <= 5.1
    
    def test_summary_different_character(self, cooldown_manager):
        """Test summary is character-specific."""
        now = datetime.now()
        cooldown_manager.cooldowns[("Char1", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="Char1",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=1,
            times_completed_week=1
        )
        
        cooldown_manager.cooldowns[("Char2", "inst1")] = CooldownEntry(
            instance_id="inst1",
            character_name="Char2",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=2,
            times_completed_week=5
        )
        
        summary1 = cooldown_manager.get_cooldown_summary("Char1")
        summary2 = cooldown_manager.get_cooldown_summary("Char2")
        
        assert summary1["times_run_today"] == 1
        assert summary2["times_run_today"] == 2


# Edge Cases and Error Handling

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.mark.asyncio
    async def test_negative_cooldown_hours(self, cooldown_manager):
        """Test handling negative cooldown hours."""
        # Should still work, treating as immediate availability
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            -5
        )
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        # Cooldown should be in the past
        assert entry.is_available is True
    
    @pytest.mark.asyncio
    async def test_very_long_cooldown(self, cooldown_manager):
        """Test handling very long cooldown."""
        await cooldown_manager.record_completion(
            "inst1",
            "TestChar",
            8760  # 1 year
        )
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.is_available is False
        assert entry.hours_until_available > 8700
    
    def test_entry_with_zero_completions(self):
        """Test entry with zero completion counts."""
        now = datetime.now()
        entry = CooldownEntry(
            instance_id="test",
            character_name="Test",
            last_completed=now,
            cooldown_ends=now + timedelta(hours=24),
            times_completed_today=0,
            times_completed_week=0
        )
        
        assert entry.times_completed_today == 0
        assert entry.times_completed_week == 0
    
    @pytest.mark.asyncio
    async def test_multiple_characters_same_instance(self, cooldown_manager):
        """Test multiple characters can run same instance."""
        await cooldown_manager.record_completion("inst1", "Char1", 24)
        await cooldown_manager.record_completion("inst1", "Char2", 24)
        
        assert ("Char1", "inst1") in cooldown_manager.cooldowns
        assert ("Char2", "inst1") in cooldown_manager.cooldowns
        
        # Both should be on cooldown
        is_avail1, _ = await cooldown_manager.check_cooldown("inst1", "Char1")
        is_avail2, _ = await cooldown_manager.check_cooldown("inst1", "Char2")
        
        assert is_avail1 is False
        assert is_avail2 is False
    
    @pytest.mark.asyncio
    async def test_character_multiple_instances(self, cooldown_manager):
        """Test character can run multiple instances."""
        await cooldown_manager.record_completion("inst1", "TestChar", 24)
        await cooldown_manager.record_completion("inst2", "TestChar", 12)
        await cooldown_manager.record_completion("inst3", "TestChar", 6)
        
        assert len([k for k in cooldown_manager.cooldowns if k[0] == "TestChar"]) == 3


# Integration Tests

class TestIntegration:
    """Test integrated workflows."""
    
    @pytest.mark.asyncio
    async def test_full_run_cycle(self, cooldown_manager):
        """Test complete run cycle: check -> run -> record."""
        # Check availability
        is_avail, _ = await cooldown_manager.check_cooldown("inst1", "TestChar")
        assert is_avail is True
        
        # Record completion
        await cooldown_manager.record_completion("inst1", "TestChar", 24)
        
        # Check again - should be on cooldown
        is_avail, time_until = await cooldown_manager.check_cooldown("inst1", "TestChar")
        assert is_avail is False
        assert time_until is not None
    
    @pytest.mark.asyncio
    async def test_daily_reset_workflow(self, cooldown_manager):
        """Test workflow through daily reset."""
        # Record some runs
        await cooldown_manager.record_completion("inst1", "TestChar", 1)
        await cooldown_manager.record_completion("inst1", "TestChar", 1)
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.times_completed_today == 2
        
        # Apply daily reset
        await cooldown_manager.handle_reset("daily")
        
        # Counts should be reset
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.times_completed_today == 0
        assert entry.times_completed_week == 2  # Week count preserved
    
    @pytest.mark.asyncio
    async def test_weekly_reset_workflow(self, cooldown_manager):
        """Test workflow through weekly reset."""
        # Record some runs
        for _ in range(5):
            await cooldown_manager.record_completion("inst1", "TestChar", 0)
        
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.times_completed_week == 5
        
        # Apply weekly reset
        await cooldown_manager.handle_reset("weekly")
        
        # Week count should be reset
        entry = cooldown_manager.cooldowns[("TestChar", "inst1")]
        assert entry.times_completed_week == 0
        assert entry.times_completed_today == 5  # Day count preserved