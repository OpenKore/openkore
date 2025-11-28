"""
Combat AI Module for the AI Sidecar.

This module provides comprehensive combat intelligence including:
- Skill point allocation with prerequisite resolution
- Role-based tactical combat behaviors
- Target selection and action prioritization
- Combat context analysis and threat assessment

Phase 4 of the God-Tier RO AI System.
"""

from ai_sidecar.combat.models import (
    # Enums
    Element,
    MonsterRace,
    MonsterSize,
    SkillType,
    TacticalRole,
    CombatActionType,
    # Data models
    Buff,
    Debuff,
    DangerZone,
    MonsterActor,
    PlayerActor,
    SkillInfo,
    CombatAction,
    CombatContext,
    # Utility functions
    get_element_modifier,
    get_size_modifier,
    # Constants
    ELEMENT_CHART,
    SIZE_MODIFIERS,
)

__all__ = [
    # Enums
    "Element",
    "MonsterRace",
    "MonsterSize",
    "SkillType",
    "TacticalRole",
    "CombatActionType",
    # Data models
    "Buff",
    "Debuff",
    "DangerZone",
    "MonsterActor",
    "PlayerActor",
    "SkillInfo",
    "CombatAction",
    "CombatContext",
    # Utility functions
    "get_element_modifier",
    "get_size_modifier",
    # Constants
    "ELEMENT_CHART",
    "SIZE_MODIFIERS",
]