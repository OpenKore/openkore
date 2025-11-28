"""
Character lifecycle state machine for autonomous progression.

Manages character progression through the complete RO lifecycle from
Novice (level 1) to Endgame optimization using a Finite State Machine.

States: NOVICE → FIRST_JOB → SECOND_JOB → REBIRTH → THIRD_JOB → ENDGAME → OPTIMIZING
"""

from enum import Enum
from typing import Callable, Any
from pathlib import Path
import json

from pydantic import BaseModel, Field

from ai_sidecar.core.state import CharacterState
from ai_sidecar.core.decision import Action
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class LifecycleState(str, Enum):
    """Character lifecycle states."""
    
    NOVICE = "NOVICE"              # Level 1-10, before first job
    FIRST_JOB = "FIRST_JOB"        # Level 10-50, first job class
    SECOND_JOB = "SECOND_JOB"      # Level 50-99, second job class
    REBIRTH = "REBIRTH"            # Transcendence process
    THIRD_JOB = "THIRD_JOB"        # Level 100-175, third job
    ENDGAME = "ENDGAME"            # Max level, gear optimization
    OPTIMIZING = "OPTIMIZING"      # Continuous improvement phase


class StateTransition(BaseModel):
    """Defines a state transition with its condition and action."""
    
    from_state: LifecycleState
    to_state: LifecycleState
    condition_description: str = Field(description="Human-readable condition")
    action_on_entry: str | None = Field(default=None, description="Action to trigger on entering new state")
    
    def check_condition(self, character: CharacterState) -> bool:
        """
        Evaluate if transition condition is met.
        
        Args:
            character: Current character state
            
        Returns:
            True if transition should occur
        """
        # NOVICE → FIRST_JOB: Job level >= 10
        if self.from_state == LifecycleState.NOVICE:
            return character.job_level >= 10
        
        # FIRST_JOB → SECOND_JOB: Base >= 50 and Job >= 40
        elif self.from_state == LifecycleState.FIRST_JOB:
            return character.base_level >= 50 and character.job_level >= 40
        
        # SECOND_JOB → REBIRTH: Base >= 99 and Job >= 50
        elif self.from_state == LifecycleState.SECOND_JOB:
            return character.base_level >= 99 and character.job_level >= 50
        
        # REBIRTH → THIRD_JOB: Job level >= 50 (after transcendence)
        elif self.from_state == LifecycleState.REBIRTH:
            return character.job_level >= 50
        
        # THIRD_JOB → ENDGAME: Base level >= max (usually 175)
        elif self.from_state == LifecycleState.THIRD_JOB:
            # Assuming max level is 175 for renewal servers
            return character.base_level >= 175
        
        # ENDGAME → OPTIMIZING: Manual trigger or completion of endgame goals
        elif self.from_state == LifecycleState.ENDGAME:
            # This transition typically requires manual trigger or achievement check
            return False
        
        return False


class CharacterLifecycle:
    """
    Finite state machine managing character progression through RO lifecycle.
    
    Tracks progression state and handles autonomous transitions between
    lifecycle phases (Novice → First Job → Second Job → Rebirth → Third Job
    → Endgame → Optimizing).
    
    Features:
    - Deterministic state transitions based on level requirements
    - Event hooks for state entry/exit
    - State persistence across sessions
    - Action triggers for job advancement, stat resets, etc.
    """
    
    # State transition definitions
    TRANSITIONS: list[StateTransition] = [
        StateTransition(
            from_state=LifecycleState.NOVICE,
            to_state=LifecycleState.FIRST_JOB,
            condition_description="job_level >= 10",
            action_on_entry="initiate_job_advancement"
        ),
        StateTransition(
            from_state=LifecycleState.FIRST_JOB,
            to_state=LifecycleState.SECOND_JOB,
            condition_description="base_level >= 50 and job_level >= 40",
            action_on_entry="initiate_second_job"
        ),
        StateTransition(
            from_state=LifecycleState.SECOND_JOB,
            to_state=LifecycleState.REBIRTH,
            condition_description="base_level >= 99 and job_level >= 50",
            action_on_entry="initiate_rebirth"
        ),
        StateTransition(
            from_state=LifecycleState.REBIRTH,
            to_state=LifecycleState.THIRD_JOB,
            condition_description="job_level >= 50",
            action_on_entry="initiate_third_job"
        ),
        StateTransition(
            from_state=LifecycleState.THIRD_JOB,
            to_state=LifecycleState.ENDGAME,
            condition_description="base_level >= 175",
            action_on_entry="enter_endgame_mode"
        ),
        StateTransition(
            from_state=LifecycleState.ENDGAME,
            to_state=LifecycleState.OPTIMIZING,
            condition_description="endgame_goals_complete",
            action_on_entry="enter_optimization_mode"
        ),
    ]
    
    def __init__(self, state_file: Path | None = None):
        """
        Initialize lifecycle state machine.
        
        Args:
            state_file: Optional path to persist state across sessions
        """
        self._current_state: LifecycleState = LifecycleState.NOVICE
        self._state_file = state_file
        self._event_hooks: dict[str, list[Callable]] = {
            "on_state_enter": [],
            "on_state_exit": [],
            "on_transition": [],
        }
        
        # Load persisted state if available
        if state_file and state_file.exists():
            self._load_state()
    
    @property
    def current_state(self) -> LifecycleState:
        """Get current lifecycle state."""
        return self._current_state
    
    def register_hook(self, event: str, callback: Callable) -> None:
        """
        Register event hook callback.
        
        Args:
            event: Event name (on_state_enter, on_state_exit, on_transition)
            callback: Function to call on event
        """
        if event in self._event_hooks:
            self._event_hooks[event].append(callback)
        else:
            logger.warning(f"Unknown event type: {event}")
    
    def check_transition(self, character: CharacterState) -> StateTransition | None:
        """
        Check if any state transition should occur.
        
        Args:
            character: Current character state
            
        Returns:
            StateTransition if transition should occur, None otherwise
        """
        for transition in self.TRANSITIONS:
            if transition.from_state == self._current_state:
                if transition.check_condition(character):
                    return transition
        return None
    
    async def execute_transition(
        self,
        transition: StateTransition,
        character: CharacterState
    ) -> list[Action]:
        """
        Execute a state transition.
        
        Args:
            transition: Transition to execute
            character: Current character state
            
        Returns:
            List of actions to execute for this transition
        """
        old_state = self._current_state
        new_state = transition.to_state
        
        logger.info(
            "Lifecycle transition",
            from_state=old_state.value,
            to_state=new_state.value,
            character=character.name,
            base_level=character.base_level,
            job_level=character.job_level
        )
        
        # Trigger exit hooks for old state
        for hook in self._event_hooks["on_state_exit"]:
            await hook(old_state, character)
        
        # Update state
        self._current_state = new_state
        
        # Persist state
        if self._state_file:
            self._save_state()
        
        # Trigger entry hooks for new state
        for hook in self._event_hooks["on_state_enter"]:
            await hook(new_state, character)
        
        # Trigger transition hooks
        for hook in self._event_hooks["on_transition"]:
            await hook(old_state, new_state, character)
        
        # Generate actions for transition
        actions: list[Action] = []
        
        if transition.action_on_entry:
            # Trigger specific action (handled by JobAdvancementSystem)
            logger.info(
                "Transition action required",
                action=transition.action_on_entry,
                state=new_state.value
            )
            # Actions will be generated by manager based on new state
        
        return actions
    
    async def tick(self, character: CharacterState) -> list[Action]:
        """
        Check for and execute state transitions.
        
        Called every AI tick to evaluate if progression state should change.
        
        Args:
            character: Current character state
            
        Returns:
            List of actions if transition occurs, empty list otherwise
        """
        transition = self.check_transition(character)
        
        if transition:
            return await self.execute_transition(transition, character)
        
        return []
    
    def get_state_goals(self, state: LifecycleState | None = None) -> dict[str, Any]:
        """
        Get progression goals for a specific state.
        
        Args:
            state: State to get goals for (defaults to current state)
            
        Returns:
            Dictionary of goals and requirements for the state
        """
        state = state or self._current_state
        
        goals = {
            LifecycleState.NOVICE: {
                "target_job_level": 10,
                "recommended_maps": ["prt_fild01", "pay_fild01"],
                "primary_focus": "Reach job level 10 for first job advancement",
            },
            LifecycleState.FIRST_JOB: {
                "target_base_level": 50,
                "target_job_level": 40,
                "primary_focus": "Level to prepare for second job advancement",
            },
            LifecycleState.SECOND_JOB: {
                "target_base_level": 99,
                "target_job_level": 50,
                "primary_focus": "Reach max level for rebirth/transcendence",
            },
            LifecycleState.REBIRTH: {
                "primary_focus": "Complete rebirth process and job change",
            },
            LifecycleState.THIRD_JOB: {
                "target_base_level": 175,
                "target_job_level": 60,
                "primary_focus": "Reach max level for third job",
            },
            LifecycleState.ENDGAME: {
                "primary_focus": "Optimize gear, participate in end-game content",
                "activities": ["MVP hunting", "WoE", "gear optimization"],
            },
            LifecycleState.OPTIMIZING: {
                "primary_focus": "Continuous improvement and optimization",
                "activities": ["alternative builds", "economy", "guild activities"],
            },
        }
        
        return goals.get(state, {})
    
    def _save_state(self) -> None:
        """Persist current state to file."""
        if not self._state_file:
            return
        
        try:
            self._state_file.parent.mkdir(parents=True, exist_ok=True)
            
            state_data = {
                "current_state": self._current_state.value,
                "version": "1.0",
            }
            
            self._state_file.write_text(
                json.dumps(state_data, indent=2),
                encoding="utf-8"
            )
            
            logger.debug("Lifecycle state saved", state=self._current_state.value)
            
        except Exception as e:
            logger.error("Failed to save lifecycle state", error=str(e))
    
    def _load_state(self) -> None:
        """Load persisted state from file."""
        if not self._state_file or not self._state_file.exists():
            return
        
        try:
            state_data = json.loads(self._state_file.read_text(encoding="utf-8"))
            state_value = state_data.get("current_state")
            
            if state_value:
                self._current_state = LifecycleState(state_value)
                logger.info("Lifecycle state loaded", state=self._current_state.value)
            
        except Exception as e:
            logger.error("Failed to load lifecycle state", error=str(e))
            # Keep default NOVICE state on error
    
    def force_state(self, state: LifecycleState) -> None:
        """
        Manually set lifecycle state (for testing or recovery).
        
        Args:
            state: State to force
        """
        old_state = self._current_state
        self._current_state = state
        
        if self._state_file:
            self._save_state()
        
        logger.warning(
            "Lifecycle state forced",
            from_state=old_state.value,
            to_state=state.value
        )
    
    def get_transition_progress(self, character: CharacterState) -> dict[str, Any]:
        """
        Get progress toward next transition.
        
        Args:
            character: Current character state
            
        Returns:
            Dictionary with progress information
        """
        next_transition = None
        for trans in self.TRANSITIONS:
            if trans.from_state == self._current_state:
                next_transition = trans
                break
        
        if not next_transition:
            return {
                "current_state": self._current_state.value,
                "next_state": None,
                "progress_percent": 100.0,
                "description": "No further transitions"
            }
        
        # Calculate progress based on level requirements
        progress = 0.0
        description = ""
        
        if self._current_state == LifecycleState.NOVICE:
            progress = (character.job_level / 10) * 100
            description = f"Job level {character.job_level}/10"
        
        elif self._current_state == LifecycleState.FIRST_JOB:
            # Dual requirement: base 50 AND job 40
            base_progress = (character.base_level / 50) * 100
            job_progress = (character.job_level / 40) * 100
            progress = min(base_progress, job_progress)
            description = f"Base {character.base_level}/50, Job {character.job_level}/40"
        
        elif self._current_state == LifecycleState.SECOND_JOB:
            # Dual requirement: base 99 AND job 50
            base_progress = (character.base_level / 99) * 100
            job_progress = (character.job_level / 50) * 100
            progress = min(base_progress, job_progress)
            description = f"Base {character.base_level}/99, Job {character.job_level}/50"
        
        elif self._current_state == LifecycleState.REBIRTH:
            # Rebirth is a process, not level-based
            progress = 50.0  # Assume mid-process
            description = "Completing rebirth process"
        
        elif self._current_state == LifecycleState.THIRD_JOB:
            progress = (character.base_level / 175) * 100
            description = f"Base level {character.base_level}/175"
        
        elif self._current_state == LifecycleState.ENDGAME:
            # Endgame is qualitative, not quantitative
            progress = 75.0
            description = "Endgame content progression"
        
        return {
            "current_state": self._current_state.value,
            "next_state": next_transition.to_state.value,
            "progress_percent": min(progress, 100.0),
            "description": description,
            "condition": next_transition.condition_description,
        }