"""
Combat AI Module for the AI Sidecar.

This module provides comprehensive combat intelligence including:
- Skill point allocation with prerequisite resolution
- Role-based tactical combat behaviors
- Target selection and action prioritization
- Combat context analysis and threat assessment
- RO-specific targeting system with priority weights
- Combat configuration with skill priorities and rotations

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

from ai_sidecar.combat.targeting import (
    TargetingSystem,
    TargetScore,
    TargetPriorityType,
    TARGET_WEIGHTS,
    create_default_targeting_system,
)

from ai_sidecar.combat.combat_config import (
    SKILL_PRIORITIES,
    OFFENSIVE_SKILLS,
    AOE_SKILLS,
    BUFF_SKILLS,
    DEBUFF_SKILLS,
    HEALING_SKILLS,
    SKILL_ROTATIONS,
    COMBAT_THRESHOLDS,
    SKILL_RANGES,
    SKILL_SP_COSTS,
    get_skill_priority_for_role,
    is_aoe_skill,
    is_buff_skill,
    get_skill_range,
    get_skill_sp_cost,
    should_use_aoe,
    get_optimal_skill_rotation,
)

__all__ = [
    # Enums
    "Element",
    "MonsterRace",
    "MonsterSize",
    "SkillType",
    "TacticalRole",
    "CombatActionType",
    "TargetPriorityType",
    # Data models
    "Buff",
    "Debuff",
    "DangerZone",
    "MonsterActor",
    "PlayerActor",
    "SkillInfo",
    "CombatAction",
    "CombatContext",
    "TargetScore",
    # Utility functions
    "get_element_modifier",
    "get_size_modifier",
    "get_skill_priority_for_role",
    "is_aoe_skill",
    "is_buff_skill",
    "get_skill_range",
    "get_skill_sp_cost",
    "should_use_aoe",
    "get_optimal_skill_rotation",
    "create_default_targeting_system",
    # Systems
    "TargetingSystem",
    # Constants
    "ELEMENT_CHART",
    "SIZE_MODIFIERS",
    "TARGET_WEIGHTS",
    "SKILL_PRIORITIES",
    "OFFENSIVE_SKILLS",
    "AOE_SKILLS",
    "BUFF_SKILLS",
    "DEBUFF_SKILLS",
    "HEALING_SKILLS",
    "SKILL_ROTATIONS",
    "COMBAT_THRESHOLDS",
    "SKILL_RANGES",
    "SKILL_SP_COSTS",
]