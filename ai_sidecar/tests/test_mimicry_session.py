"""
Comprehensive tests for mimicry/session.py module.

Tests session management for anti-detection including:
- Session lifecycle
- Play time tracking
- Break patterns
- Fatigue simulation
- Session state transitions
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import json

from ai_sidecar.mimicry.session import (
    SessionState,
    SessionBehavior,
    PlaySession,
    HumanSessionManager
)


class TestSessionModels:
    """Test Pydantic models for session management."""
    
    def test_play_session_creation(self):
        """Test PlaySession model creation."""
        session = PlaySession()
        assert session.session_id is not None
        assert session.current_state == SessionState.STARTING
        assert session.actions_performed == 0
    
    def test_play_session_duration_seconds(self):
        """Test duration calculation in seconds."""
        session = PlaySession()
        # Simulate time passing
        session.started_at = datetime.now() - timedelta(seconds=30)
        assert session.duration_seconds >= 29
    
    def test_play_session_duration_hours(self):
        """Test duration calculation in hours."""
        session = PlaySession()
        session.started_at = datetime.now() - timedelta(hours=2)
        assert session.duration_hours >= 1.9
    
    def test_session_behavior_defaults(self):
        """Test SessionBehavior default values."""
        behavior = SessionBehavior(state=SessionState.ACTIVE)
        assert behavior.action_speed_multiplier == 1.0
        assert behavior.error_rate_multiplier == 1.0
        assert behavior.social_interaction_chance == 0.1


class TestHumanSessionManagerInit:
    """Test HumanSessionManager initialization."""
    
    def test_init_with_data_dir(self, tmp_path):
        """Test initialization with data directory."""
        manager = HumanSessionManager(data_dir=tmp_path)
        assert manager.data_dir == tmp_path
        assert manager.current_session is None
        assert manager.patterns is not None
    
    def test_init_loads_patterns_if_exists(self, tmp_path):
        """Test loading patterns from file."""
        patterns_file = tmp_path / "session_patterns.json"
        test_patterns = {
            "weekday_patterns": {
                "typical_start_hours": [19, 20, 21],
                "typical_end_hours": [23, 0, 1],
                "average_session_minutes": 150,
                "max_session_minutes": 300
            }
        }
        patterns_file.write_text(json.dumps(test_patterns))
        
        manager = HumanSessionManager(data_dir=tmp_path)
        assert "weekday_patterns" in manager.patterns
        assert manager.patterns["weekday_patterns"]["average_session_minutes"] == 150
    
    def test_init_uses_defaults_if_no_file(self, tmp_path):
        """Test default patterns when file doesn't exist."""
        manager = HumanSessionManager(data_dir=tmp_path)
        assert "weekday_patterns" in manager.patterns
        assert "weekend_patterns" in manager.patterns
        assert "break_patterns" in manager.patterns


class TestStartSession:
    """Test session start functionality."""
    
    @pytest.mark.asyncio
    async def test_start_session_creates_new(self, tmp_path):
        """Test starting a new session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        session = await manager.start_session()
        
        assert session is not None
        assert manager.current_session == session
        assert session.current_state == SessionState.STARTING
    
    @pytest.mark.asyncio
    async def test_start_session_generates_unique_id(self, tmp_path):
        """Test unique session IDs."""
        manager = HumanSessionManager(data_dir=tmp_path)
        session1 = await manager.start_session()
        
        manager.current_session = None
        session2 = await manager.start_session()
        
        assert session1.session_id != session2.session_id


class TestUpdateSessionState:
    """Test session state updates."""
    
    @pytest.mark.asyncio
    async def test_update_state_no_session(self, tmp_path):
        """Test update with no active session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        state = await manager.update_session_state()
        
        assert state == SessionState.STARTING
    
    @pytest.mark.asyncio
    async def test_update_state_starting_phase(self, tmp_path):
        """Test STARTING state for new sessions."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        
        state = await manager.update_session_state()
        
        assert state == SessionState.STARTING
    
    @pytest.mark.asyncio
    async def test_update_state_warming_up(self, tmp_path):
        """Test transition to WARMING_UP."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=10)
        
        state = await manager.update_session_state()
        
        assert state == SessionState.WARMING_UP
    
    @pytest.mark.asyncio
    async def test_update_state_active(self, tmp_path):
        """Test transition to ACTIVE."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=30)
        
        state = await manager.update_session_state()
        
        assert state == SessionState.ACTIVE
    
    @pytest.mark.asyncio
    async def test_update_state_focused_high_activity(self, tmp_path):
        """Test transition to FOCUSED with high activity."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=90)
        manager.current_session.actions_performed = 1000  # High activity
        
        state = await manager.update_session_state()
        
        assert state == SessionState.FOCUSED
    
    @pytest.mark.asyncio
    async def test_update_state_fatigued(self, tmp_path):
        """Test transition to FATIGUED."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=150)
        
        state = await manager.update_session_state()
        
        assert state == SessionState.FATIGUED
    
    @pytest.mark.asyncio
    async def test_update_state_winding_down(self, tmp_path):
        """Test transition to WINDING_DOWN."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=200)
        
        state = await manager.update_session_state()
        
        assert state == SessionState.WINDING_DOWN


class TestShouldTakeBreak:
    """Test break decision logic."""
    
    @pytest.mark.asyncio
    async def test_should_break_no_session(self, tmp_path):
        """Test break check with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        should_break, duration = await manager.should_take_break()
        
        assert should_break is False
        assert duration == 0
    
    @pytest.mark.asyncio
    async def test_should_break_short_session(self, tmp_path):
        """Test no break needed for short session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=10)
        
        # May or may not break, but should not error
        should_break, duration = await manager.should_take_break()
        assert isinstance(should_break, bool)
    
    @pytest.mark.asyncio
    async def test_should_break_after_long_time(self, tmp_path):
        """Test break recommendation after long play."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(minutes=150)
        
        # After 2.5 hours, should consider breaking
        should_break, duration = await manager.should_take_break()
        assert isinstance(should_break, bool)
        if should_break:
            assert duration > 0


class TestSimulateAFK:
    """Test AFK behavior simulation."""
    
    @pytest.mark.asyncio
    async def test_simulate_afk_no_session(self, tmp_path):
        """Test AFK with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.simulate_afk(duration_seconds=60)
        # Should not error
    
    @pytest.mark.asyncio
    async def test_simulate_afk_sets_state(self, tmp_path):
        """Test AFK state setting."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        original_state = manager.current_session.current_state
        
        await manager.simulate_afk(duration_seconds=60)
        
        # State should be restored after AFK
        assert manager.current_session.current_state == original_state
    
    @pytest.mark.asyncio
    async def test_simulate_afk_updates_time(self, tmp_path):
        """Test AFK time tracking."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        
        await manager.simulate_afk(duration_seconds=120)
        
        assert manager.current_session.afk_minutes == 2.0
    
    @pytest.mark.asyncio
    async def test_simulate_afk_increments_breaks(self, tmp_path):
        """Test break counter increment."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        
        await manager.simulate_afk(duration_seconds=60)
        
        assert manager.current_session.total_breaks == 1


class TestShouldEndSession:
    """Test session end decision logic."""
    
    @pytest.mark.asyncio
    async def test_should_end_no_session(self, tmp_path):
        """Test end check with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        should_end, reason = await manager.should_end_session()
        
        assert should_end is False
        assert reason == ""
    
    @pytest.mark.asyncio
    async def test_should_end_max_time_weekday(self, tmp_path):
        """Test ending after max weekday time."""
        manager = HumanSessionManager(data_dir=tmp_path)
        # Set very short max time
        manager.patterns["weekday_patterns"]["max_session_minutes"] = 10
        
        await manager.start_session()
        # Set session to well over max time
        manager.current_session.started_at = datetime.now() - timedelta(hours=1)
        
        should_end, reason = await manager.should_end_session()
        
        # With 60 minute session and 10 minute max, should end
        assert should_end is True
    
    @pytest.mark.asyncio
    async def test_should_end_fatigue_based(self, tmp_path):
        """Test fatigue-based ending."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        manager.current_session.started_at = datetime.now() - timedelta(hours=4)
        
        # After 4 hours, fatigue chance increases
        should_end, reason = await manager.should_end_session()
        # Might end, but should not error
        assert isinstance(should_end, bool)
    
    @pytest.mark.asyncio
    async def test_should_end_very_late_night(self, tmp_path):
        """Test ending very late at night."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        
        # Mock current hour to be 3 AM
        with patch('ai_sidecar.mimicry.session.datetime') as mock_dt:
            mock_now = datetime.now().replace(hour=3)
            mock_dt.now.return_value = mock_now
            mock_dt.side_effect = lambda *args, **kw: datetime(*args, **kw)
            
            should_end, reason = await manager.should_end_session()
            # Might end late at night
            assert isinstance(should_end, bool)


class TestGetSessionBehavior:
    """Test behavior profile retrieval."""
    
    def test_get_behavior_no_session(self, tmp_path):
        """Test behavior with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.STARTING
    
    def test_get_behavior_starting(self, tmp_path):
        """Test STARTING behavior profile."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession(current_state=SessionState.STARTING)
        
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.STARTING
        assert behavior.action_speed_multiplier == 0.8
        assert behavior.error_rate_multiplier == 1.2
    
    def test_get_behavior_active(self, tmp_path):
        """Test ACTIVE behavior profile."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession(current_state=SessionState.ACTIVE)
        
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.ACTIVE
        assert behavior.action_speed_multiplier == 1.0
        assert behavior.error_rate_multiplier == 1.0
    
    def test_get_behavior_focused(self, tmp_path):
        """Test FOCUSED behavior profile."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession(current_state=SessionState.FOCUSED)
        
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.FOCUSED
        assert behavior.action_speed_multiplier == 1.1
        assert behavior.error_rate_multiplier == 0.9
    
    def test_get_behavior_fatigued(self, tmp_path):
        """Test FATIGUED behavior profile."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession(current_state=SessionState.FATIGUED)
        
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.FATIGUED
        assert behavior.action_speed_multiplier == 0.75
        assert behavior.error_rate_multiplier == 1.3
    
    def test_get_behavior_afk(self, tmp_path):
        """Test AFK behavior profile."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession(current_state=SessionState.AFK)
        
        behavior = manager.get_session_behavior()
        
        assert behavior.state == SessionState.AFK
        assert behavior.action_speed_multiplier == 0.0


class TestCalculatePlayWindow:
    """Test play window calculation."""
    
    def test_calculate_window_weekday(self, tmp_path):
        """Test weekday play window."""
        manager = HumanSessionManager(data_dir=tmp_path)
        
        with patch('ai_sidecar.mimicry.session.datetime') as mock_dt:
            # Mock to be a weekday (Monday = 0)
            mock_now = datetime(2024, 1, 8, 12, 0)  # Monday
            mock_dt.now.return_value = mock_now
            mock_dt.side_effect = lambda *args, **kw: datetime(*args, **kw)
            
            start_time, end_time = manager.calculate_play_window()
            
            assert isinstance(start_time, datetime)
            assert isinstance(end_time, datetime)
            assert end_time > start_time
    
    def test_calculate_window_weekend(self, tmp_path):
        """Test weekend play window."""
        manager = HumanSessionManager(data_dir=tmp_path)
        
        with patch('ai_sidecar.mimicry.session.datetime') as mock_dt:
            # Mock to be a weekend (Saturday = 5)
            mock_now = datetime(2024, 1, 13, 12, 0)  # Saturday
            mock_dt.now.return_value = mock_now
            mock_dt.side_effect = lambda *args, **kw: datetime(*args, **kw)
            
            start_time, end_time = manager.calculate_play_window()
            
            assert isinstance(start_time, datetime)
            assert isinstance(end_time, datetime)


class TestRecordAction:
    """Test action recording."""
    
    def test_record_action_no_session(self, tmp_path):
        """Test recording with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.record_action("kill")
        # Should not error
    
    def test_record_action_kill(self, tmp_path):
        """Test recording kill action."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession()
        
        manager.record_action("kill")
        
        assert manager.current_session.actions_performed == 1
        assert manager.current_session.monsters_killed == 1
    
    def test_record_action_loot(self, tmp_path):
        """Test recording loot action."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession()
        
        manager.record_action("loot")
        
        assert manager.current_session.actions_performed == 1
        assert manager.current_session.items_looted == 1
    
    def test_record_action_chat(self, tmp_path):
        """Test recording chat action."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession()
        
        manager.record_action("chat")
        
        assert manager.current_session.actions_performed == 1
        assert manager.current_session.messages_sent == 1
    
    def test_record_multiple_actions(self, tmp_path):
        """Test recording multiple actions."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession()
        
        manager.record_action("kill")
        manager.record_action("loot")
        manager.record_action("chat")
        
        assert manager.current_session.actions_performed == 3
        assert manager.current_session.monsters_killed == 1
        assert manager.current_session.items_looted == 1
        assert manager.current_session.messages_sent == 1


class TestEndSession:
    """Test session ending."""
    
    @pytest.mark.asyncio
    async def test_end_session_no_session(self, tmp_path):
        """Test ending with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.end_session()
        # Should not error
    
    @pytest.mark.asyncio
    async def test_end_session_archives(self, tmp_path):
        """Test session archival."""
        manager = HumanSessionManager(data_dir=tmp_path)
        await manager.start_session()
        session_id = manager.current_session.session_id
        
        await manager.end_session()
        
        assert manager.current_session is None
        assert len(manager.session_history) == 1
        assert manager.session_history[0].session_id == session_id
    
    @pytest.mark.asyncio
    async def test_end_session_limits_history(self, tmp_path):
        """Test history size limiting."""
        manager = HumanSessionManager(data_dir=tmp_path)
        
        # Create 52 sessions
        for i in range(52):
            await manager.start_session()
            await manager.end_session()
        
        # Should only keep last 50
        assert len(manager.session_history) == 50


class TestGetSessionStats:
    """Test session statistics."""
    
    def test_get_stats_no_session(self, tmp_path):
        """Test stats with no session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        stats = manager.get_session_stats()
        
        assert stats["active"] is False
    
    def test_get_stats_active_session(self, tmp_path):
        """Test stats with active session."""
        manager = HumanSessionManager(data_dir=tmp_path)
        manager.current_session = PlaySession()
        manager.current_session.actions_performed = 100
        manager.current_session.monsters_killed = 50
        
        stats = manager.get_session_stats()
        
        assert stats["active"] is True
        assert stats["actions_performed"] == 100
        assert stats["monsters_killed"] == 50
        assert "session_id" in stats
        assert "state" in stats