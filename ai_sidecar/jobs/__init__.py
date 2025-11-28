"""
Job-Specific Mechanics System for OpenKore AI.

This package provides comprehensive job class definitions, skill rotations,
and special mechanics for all Ragnarok Online job classes.

Modules:
    registry: Job class definitions and registry
    rotations: Skill rotation engine
    coordinator: Main job AI coordinator
    mechanics: Special job-specific mechanics (spheres, traps, etc.)

Example:
    >>> from ai_sidecar.jobs import JobAICoordinator
    >>> coordinator = JobAICoordinator(data_dir)
    >>> await coordinator.set_job(4005)  # Champion
    >>> action = await coordinator.get_next_action(character_state, target_state)
"""

from ai_sidecar.jobs.coordinator import JobAICoordinator
from ai_sidecar.jobs.registry import (
    JobBranch,
    JobClass,
    JobClassRegistry,
    JobTier,
    CombatRole,
    PositioningStyle,
)
from ai_sidecar.jobs.rotations import (
    SkillCondition,
    SkillPriority,
    SkillRotation,
    SkillRotationEngine,
    SkillRotationStep,
)

__all__ = [
    # Main coordinator
    "JobAICoordinator",
    # Registry
    "JobBranch",
    "JobClass",
    "JobClassRegistry",
    "JobTier",
    "CombatRole",
    "PositioningStyle",
    # Rotations
    "SkillCondition",
    "SkillPriority",
    "SkillRotation",
    "SkillRotationEngine",
    "SkillRotationStep",
]