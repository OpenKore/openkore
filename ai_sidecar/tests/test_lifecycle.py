"""
Unit tests for character lifecycle state machine.

Tests:
- State transition logic
- Condition evaluation
- State persistence
- Event hooks
- Progress tracking
"""

import pytest
from pathlib import Path
import tempfile
import json

from ai_sidecar.progression.lifecycle import (
    CharacterLifecycle,
    LifecycleState,
    StateTransition
)
from ai_sidecar.core.state import CharacterState


class TestLifecycleStates:
    """Test lifecycle state definitions and transitions."""
    
    def test_all_states_defined(self):
        """Verify all 7 states are defined."""
        expected_states = {
            "NOVICE", "FIRST_JOB", "SECOND_JOB",
            "REBIRTH", "THIRD_JOB", "ENDGAME", "OPTIMIZING"
        }
        actual_states = {state.value for state in LifecycleState}
        assert actual_states == expected_states
    
    def test_transitions_cover_all_states(self):
        """Verify transitions exist for all states except OPTIMIZING."""
        lifecycle = CharacterLifecycle()
        
        # All states except OPTIMIZING should have a transition
        states_with_transitions = {
            trans.from_state for trans in lifecycle.TRANSITIONS
        }
        
        expected = {
            LifecycleState.NOVICE,
            LifecycleState.FIRST_JOB,
            LifecycleState.SECOND_JOB,
            LifecycleState.REBIRTH,
            LifecycleState.THIRD_JOB,
            LifecycleState.ENDGAME,
        }
        
        assert states_with_transitions == expected


class TestStateTransitions:
    """Test state transition conditions."""
    
    def test_novice_to_first_job_transition(self):
        """Test NOVICE → FIRST_JOB at job level 10."""
        lifecycle = CharacterLifecycle()
        
        # Not ready at level 9
        char = CharacterState(job_level=9, base_level=5)
        transition = lifecycle.check_transition(char)
        assert transition is None
        
        # Ready at level 10
        char = CharacterState(job_level=10, base_level=5)
        transition = lifecycle.check_transition(char)
        assert transition is not None
        assert transition.from_state == LifecycleState.NOVICE
        assert transition.to_state == LifecycleState.FIRST_JOB
    
    def test_first_job_to_second_job_transition(self):
        """Test FIRST_JOB → SECOND_JOB at 50/40."""
        lifecycle = CharacterLifecycle()
        lifecycle._current_state = LifecycleState.FIRST_JOB
        
        # Not ready (low base level)
        char = CharacterState(base_level=40, job_level=40)
        transition = lifecycle.check_transition(char)
        assert transition is None
        
        # Not ready (low job level)
        char = CharacterState(base_level=50, job_level=30)
        transition = lifecycle.check_transition(char)
        assert transition is None
        
        # Ready (both requirements met)
        char = CharacterState(base_level=50, job_level=40)
        transition = lifecycle.check_transition(char)
        assert transition is not None
        assert transition.to_state == LifecycleState.SECOND_JOB
    
    def test_second_job_to_rebirth_transition(self):
        """Test SECOND_JOB → REBIRTH at 99/50."""
        lifecycle = CharacterLifecycle()
        lifecycle._current_state = LifecycleState.SECOND_JOB
        
        char = CharacterState(base_level=99, job_level=50)
        transition = lifecycle.check_transition(char)
        assert transition is not None
        assert transition.to_state == LifecycleState.REBIRTH


class TestStatePersistence:
    """Test state persistence across sessions."""
    
    def test_save_and_load_state(self):
        """Test saving and loading lifecycle state."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "lifecycle.json"
            
            # Create lifecycle and transition to FIRST_JOB
            lifecycle = CharacterLifecycle(state_file=state_file)
            lifecycle._current_state = LifecycleState.FIRST_JOB
            lifecycle._save_state()
            
            # Verify file was created
            assert state_file.exists()
            
            # Load state in new instance
            lifecycle2 = CharacterLifecycle(state_file=state_file)
            assert lifecycle2.current_state == LifecycleState.FIRST_JOB
    
    def test_load_invalid_state_file(self):
        """Test handling of corrupted state file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "lifecycle.json"
            state_file.write_text("invalid json{", encoding="utf-8")
            
            # Should default to NOVICE on error
            lifecycle = CharacterLifecycle(state_file=state_file)
            assert lifecycle.current_state == LifecycleState.NOVICE


class TestLifecycleExecution:
    """Test lifecycle tick execution."""
    
    @pytest.mark.asyncio
    async def test_execute_transition(self):
        """Test executing a state transition."""
        lifecycle = CharacterLifecycle()
        
        # Create transition
        transition = StateTransition(
            from_state=LifecycleState.NOVICE,
            to_state=LifecycleState.FIRST_JOB,
            condition_description="test",
            action_on_entry="test_action"
        )
        
        char = CharacterState(job_level=10, name="TestChar")
        actions = await lifecycle.execute_transition(transition, char)
        
        # State should be updated
        assert lifecycle.current_state == LifecycleState.FIRST_JOB
    
    @pytest.mark.asyncio
    async def test_tick_triggers_transition(self):
        """Test that tick triggers appropriate transition."""
        lifecycle = CharacterLifecycle()
        
        # Character ready for transition
        char = CharacterState(job_level=10, name="TestChar")
        actions = await lifecycle.tick(char)
        
        # Should have transitioned to FIRST_JOB
        assert lifecycle.current_state == LifecycleState.FIRST_JOB


class TestProgressTracking:
    """Test progress tracking toward next transition."""
    
    def test_progress_calculation_novice(self):
        """Test progress calculation for NOVICE state."""
        lifecycle = CharacterLifecycle()
        
        char = CharacterState(job_level=5, base_level=3)
        progress = lifecycle.get_transition_progress(char)
        
        assert progress["current_state"] == "NOVICE"
        assert progress["next_state"] == "FIRST_JOB"
        assert progress["progress_percent"] == 50.0  # 5/10 = 50%
    
    def test_progress_calculation_first_job(self):
        """Test progress for FIRST_JOB with dual requirements."""
        lifecycle = CharacterLifecycle()
        lifecycle._current_state = LifecycleState.FIRST_JOB
        
        # Base at 40/50, Job at 40/40 → bottleneck is base at 80%
        char = CharacterState(base_level=40, job_level=40)
        progress = lifecycle.get_transition_progress(char)
        
        assert progress["current_state"] == "FIRST_JOB"
        assert progress["progress_percent"] == 80.0  # min(80%, 100%)
    
    def test_goals_for_each_state(self):
        """Test that goals are defined for all states."""
        lifecycle = CharacterLifecycle()
        
        for state in LifecycleState:
            goals = lifecycle.get_state_goals(state)
            assert isinstance(goals, dict)
            assert "primary_focus" in goals


class TestEventHooks:
    """Test event hook system."""
    
    @pytest.mark.asyncio
    async def test_register_and_trigger_hooks(self):
        """Test registering and triggering event hooks."""
        lifecycle = CharacterLifecycle()
        
        # Track hook calls
        calls = []
        
        async def on_enter(state, char):
            calls.append(("enter", state))
        
        async def on_exit(state, char):
            calls.append(("exit", state))
        
        lifecycle.register_hook("on_state_enter", on_enter)
        lifecycle.register_hook("on_state_exit", on_exit)
        
        # Execute transition
        transition = StateTransition(
            from_state=LifecycleState.NOVICE,
            to_state=LifecycleState.FIRST_JOB,
            condition_description="test"
        )
        
        char = CharacterState(job_level=10)
        await lifecycle.execute_transition(transition, char)
        
        # Both hooks should have been called
        assert len(calls) == 2
        assert calls[0] == ("exit", LifecycleState.NOVICE)
        assert calls[1] == ("enter", LifecycleState.FIRST_JOB)


class TestManualStateControl:
    """Test manual state control for testing/recovery."""
    
    def test_force_state(self):
        """Test forcing lifecycle state."""
        lifecycle = CharacterLifecycle()
        assert lifecycle.current_state == LifecycleState.NOVICE
        
        lifecycle.force_state(LifecycleState.ENDGAME)
        assert lifecycle.current_state == LifecycleState.ENDGAME