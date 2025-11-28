"""
Progression manager - coordinates all character progression systems.

Orchestrates the interaction between:
- Character lifecycle state machine
- Stat distribution engine  
- Job advancement system

Provides a unified interface for the decision engine to handle all
progression-related actions.
"""

from pathlib import Path
from typing import Any

from ai_sidecar.core.state import GameState, CharacterState
from ai_sidecar.core.decision import Action
from ai_sidecar.progression.lifecycle import CharacterLifecycle, LifecycleState
from ai_sidecar.progression.stats import StatDistributionEngine, BuildType
from ai_sidecar.progression.job_advance import JobAdvancementSystem
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class ProgressionManager:
    """
    Central coordinator for all character progression systems.
    
    Manages:
    - Lifecycle state transitions (NOVICE → ENDGAME)
    - Automatic stat point allocation
    - Job advancement automation
    - Progression goal tracking
    
    This is the primary interface used by the decision engine for
    all progression-related functionality.
    """
    
    def __init__(
        self,
        data_dir: Path,
        state_dir: Path,
        build_type: BuildType = BuildType.HYBRID,
        soft_cap: int = 99,
        preferred_jobs: dict[str, str] | None = None
    ):
        """
        Initialize progression manager.
        
        Args:
            data_dir: Directory containing job_paths.json, job_npcs.json, etc.
            state_dir: Directory for persisting state files
            build_type: Default build archetype for stat distribution
            soft_cap: Stat soft cap (99 for pre-renewal, 130 for renewal)
            preferred_jobs: Preferred job choices at each branch point
        """
        self.data_dir = data_dir
        self.state_dir = state_dir
        
        # Ensure directories exist
        data_dir.mkdir(parents=True, exist_ok=True)
        state_dir.mkdir(parents=True, exist_ok=True)
        
        # Initialize subsystems
        self.lifecycle = CharacterLifecycle(
            state_file=state_dir / "lifecycle_state.json"
        )
        
        self.stat_engine = StatDistributionEngine(
            build_type=build_type,
            soft_cap=soft_cap
        )
        
        self.job_system = JobAdvancementSystem(
            job_paths_file=data_dir / "job_paths.json",
            job_npcs_file=data_dir / "job_npcs.json",
            preferred_path=preferred_jobs
        )
        
        self._initialized = False
    
    async def initialize(self) -> None:
        """Initialize all progression systems."""
        if self._initialized:
            return
        
        logger.info("Initializing progression manager")
        
        # Validate job path data
        errors = self.job_system.validate_job_path_continuity()
        if errors:
            logger.warning(
                "Job path validation errors found",
                error_count=len(errors),
                errors=errors[:5]  # Log first 5 errors
            )
        
        self._initialized = True
        logger.info("Progression manager initialized")
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """
        Main progression tick - called from decision engine.
        
        Coordinates all progression systems and returns prioritized actions.
        
        Priority order:
        1. Lifecycle state transitions
        2. Job advancement actions
        3. Stat point allocation
        
        Args:
            game_state: Current game state
            
        Returns:
            Prioritized list of progression actions
        """
        if not self._initialized:
            await self.initialize()
        
        character = game_state.character
        actions: list[Action] = []
        
        # Priority 1: Check lifecycle transitions
        lifecycle_actions = await self.lifecycle.tick(character)
        if lifecycle_actions:
            actions.extend(lifecycle_actions)
            logger.debug(
                "Lifecycle actions generated",
                count=len(lifecycle_actions),
                state=self.lifecycle.current_state.value
            )
        
        # Priority 2: Check job advancement (only in relevant states)
        if self.lifecycle.current_state in [
            LifecycleState.NOVICE,
            LifecycleState.FIRST_JOB,
            LifecycleState.SECOND_JOB,
            LifecycleState.REBIRTH,
        ]:
            job_actions = await self.job_system.check_advancement(
                character,
                self.lifecycle.current_state
            )
            if job_actions:
                actions.extend(job_actions)
                logger.debug(
                    "Job advancement actions generated",
                    count=len(job_actions)
                )
        
        # Priority 3: Allocate stat points if available
        if character.stat_points > 0:
            stat_actions = await self.stat_engine.allocate_points(character)
            if stat_actions:
                actions.extend(stat_actions)
                logger.debug(
                    "Stat allocation actions generated",
                    count=len(stat_actions),
                    points=character.stat_points
                )
        
        # Log summary if any progression actions were generated
        if actions:
            logger.info(
                "Progression tick complete",
                total_actions=len(actions),
                lifecycle_state=self.lifecycle.current_state.value,
                character=character.name,
                base_level=character.base_level,
                job_level=character.job_level
            )
        
        return actions
    
    def update_build_type(self, build_type: BuildType) -> None:
        """
        Update stat distribution build type.
        
        Args:
            build_type: New build archetype to use
        """
        logger.info(
            "Updating build type",
            old_build=self.stat_engine.build_type.value,
            new_build=build_type.value
        )
        
        self.stat_engine = StatDistributionEngine(
            build_type=build_type,
            soft_cap=self.stat_engine.soft_cap
        )
    
    def auto_detect_build(self, character: CharacterState) -> BuildType:
        """
        Auto-detect optimal build type from job class.
        
        Args:
            character: Current character state
            
        Returns:
            Recommended build type
        """
        build = self.stat_engine.recommend_build_for_job(character.job_class)
        
        logger.info(
            "Build type auto-detected",
            job_class=character.job_class,
            build_type=build.value
        )
        
        return build
    
    def get_progression_status(self, character: CharacterState) -> dict[str, Any]:
        """
        Get comprehensive progression status.
        
        Args:
            character: Current character state
            
        Returns:
            Dictionary with full progression status
        """
        # Get lifecycle progress
        transition_progress = self.lifecycle.get_transition_progress(character)
        goals = self.lifecycle.get_state_goals()
        
        # Get stat distribution status
        stat_summary = self.stat_engine.get_stat_distribution_summary(character)
        
        # Get job path info
        job_summary = self.job_system.get_job_path_summary(character.job_class)
        
        return {
            "lifecycle": {
                "current_state": self.lifecycle.current_state.value,
                "transition_progress": transition_progress,
                "goals": goals,
            },
            "stats": stat_summary,
            "job": job_summary,
            "character": {
                "name": character.name,
                "job_class": character.job_class,
                "base_level": character.base_level,
                "job_level": character.job_level,
                "stat_points": character.stat_points,
                "skill_points": character.skill_points,
            },
        }
    
    def force_lifecycle_state(self, state: LifecycleState) -> None:
        """
        Manually set lifecycle state (for testing/recovery).
        
        Args:
            state: State to force
        """
        self.lifecycle.force_state(state)
    
    async def shutdown(self) -> None:
        """Clean up progression manager resources."""
        logger.info("Shutting down progression manager")
        self._initialized = False