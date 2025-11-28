"""
Character progression module for AI Sidecar.

Implements autonomous character lifecycle management including:
- Character lifecycle state machine (NOVICE → ENDGAME)
- Job advancement automation
- Stat point distribution
- Progression coordination

This module enables fully autonomous character progression from
level 1 to max level without manual intervention.
"""

from ai_sidecar.progression.lifecycle import CharacterLifecycle, LifecycleState
from ai_sidecar.progression.stats import StatDistributionEngine, BuildType
from ai_sidecar.progression.job_advance import JobAdvancementSystem
from ai_sidecar.progression.manager import ProgressionManager

__all__ = [
    "CharacterLifecycle",
    "LifecycleState",
    "StatDistributionEngine",
    "BuildType",
    "JobAdvancementSystem",
    "ProgressionManager",
]