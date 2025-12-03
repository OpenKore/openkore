"""
Combat Configuration for Ragnarok Online.

RO-specific skill priorities, rotations, and combat parameters
organized by job class and tactical role.
"""

from enum import Enum
from typing import Dict, List


class SkillPriority(str, Enum):
    """Skill priority levels for combat rotation."""
    
    EMERGENCY = "emergency"  # Use immediately when available
    HIGH = "high"  # Primary combat skills
    MEDIUM = "medium"  # Secondary/situational skills
    LOW = "low"  # Filler/basic skills
    BUFF = "buff"  # Pre-combat buffs


# RO Skill Priorities by Class Role
# Format: role -> list of skills in priority order
SKILL_PRIORITIES = {
    "buffer": [
        "blessing",
        "increase_agi",
        "kyrie_eleison",
        "angelus",
        "gloria",
        "magnificat",
        "aspersio",
        "assumptio",
    ],
    "healer": [
        "heal",
        "sanctuary",
        "resurrection",
        "recovery",
        "cure",
        "status_recovery",
        "coluceo_heal",
        "highness_heal",
    ],
    "dps_melee": [
        "bash",
        "magnum_break",
        "bowling_bash",
        "brandish_spear",
        "spiral_pierce",
        "holy_cross",
        "grand_cross",
        "sonic_blow",
        "meteor_assault",
    ],
    "dps_ranged": [
        "double_strafe",
        "arrow_shower",
        "blitz_beat",
        "charge_arrow",
        "sharp_shooting",
        "focused_arrow_strike",
        "arrow_vulcan",
        "throw_stone",
    ],
    "dps_magic": [
        "fire_bolt",
        "frost_diver",
        "jupitel_thunder",
        "storm_gust",
        "meteor_storm",
        "heaven_drive",
        "lord_of_vermillion",
        "soul_strike",
        "holy_light",
    ],
    "tank": [
        "provoke",
        "endure",
        "devotion",
        "shield_charge",
        "shield_boomerang",
        "sacrifice",
        "defender",
        "auto_guard",
    ],
}


# Skill categories for decision making
OFFENSIVE_SKILLS = {
    # Melee physical
    "bash", "magnum_break", "bowling_bash", "brandish_spear",
    "spiral_pierce", "holy_cross", "grand_cross", "sonic_blow",
    "meteor_assault", "shield_charge", "shield_boomerang",
    
    # Ranged physical
    "double_strafe", "arrow_shower", "charge_arrow", "sharp_shooting",
    "focused_arrow_strike", "arrow_vulcan", "throw_stone", "blitz_beat",
    
    # Magic
    "fire_bolt", "frost_diver", "jupitel_thunder", "storm_gust",
    "meteor_storm", "heaven_drive", "lord_of_vermillion",
    "soul_strike", "holy_light", "cold_bolt", "lightning_bolt",
}


AOE_SKILLS = {
    "magnum_break", "bowling_bash", "arrow_shower", "meteor_assault",
    "storm_gust", "meteor_storm", "heaven_drive", "lord_of_vermillion",
    "sanctuary", "grand_cross", "blitz_beat",
}


BUFF_SKILLS = {
    "blessing", "increase_agi", "kyrie_eleison", "angelus", "gloria",
    "magnificat", "aspersio", "assumptio", "endure", "provoke",
    "defender", "auto_guard", "adrenaline_rush", "weapon_perfection",
    "over_thrust", "concentration", "aura_blade",
}


DEBUFF_SKILLS = {
    "provoke", "frost_diver", "lex_aeterna", "lex_divina",
    "curse", "stone_curse", "sleep", "freeze",
}


HEALING_SKILLS = {
    "heal", "sanctuary", "recovery", "coluceo_heal", "highness_heal",
    "potion_pitcher",
}


# Skill rotation strategies by role
SKILL_ROTATIONS = {
    "knight_bash": {
        "buff_phase": ["endure", "provoke"],
        "opener": ["bash"],
        "spam": ["bash", "magnum_break"],
        "aoe": ["magnum_break", "bowling_bash"],
        "finisher": ["bash"],
    },
    "knight_bowling": {
        "buff_phase": ["endure"],
        "opener": ["bowling_bash"],
        "spam": ["bowling_bash", "bash"],
        "aoe": ["bowling_bash"],
        "finisher": ["bash"],
    },
    "wizard_storm_gust": {
        "buff_phase": [],
        "opener": ["frost_diver", "storm_gust"],
        "spam": ["storm_gust"],
        "aoe": ["storm_gust", "lord_of_vermillion"],
        "finisher": ["jupitel_thunder"],
    },
    "wizard_safety": {
        "buff_phase": ["safety_wall"],
        "opener": ["safety_wall", "fire_bolt"],
        "spam": ["fire_bolt", "cold_bolt", "lightning_bolt"],
        "aoe": ["fire_wall", "heaven_drive"],
        "finisher": ["fire_bolt"],
    },
    "priest_full_support": {
        "buff_phase": ["blessing", "increase_agi", "kyrie_eleison"],
        "opener": ["heal"],
        "spam": ["heal", "sanctuary"],
        "aoe": ["sanctuary", "magnus_exorcismus"],
        "finisher": ["holy_light"],
    },
    "hunter_ds": {
        "buff_phase": ["improve_concentration"],
        "opener": ["double_strafe"],
        "spam": ["double_strafe"],
        "aoe": ["arrow_shower", "blitz_beat"],
        "finisher": ["double_strafe"],
    },
    "assassin_sonic": {
        "buff_phase": ["enchant_poison"],
        "opener": ["sonic_blow"],
        "spam": ["sonic_blow"],
        "aoe": ["meteor_assault"],
        "finisher": ["sonic_blow"],
    },
}


# SP efficiency ratings (damage per SP)
# Higher = more SP efficient
SKILL_SP_EFFICIENCY = {
    "bash": 3.5,
    "magnum_break": 2.8,
    "bowling_bash": 3.2,
    "double_strafe": 4.0,
    "arrow_shower": 2.5,
    "fire_bolt": 3.8,
    "cold_bolt": 3.8,
    "lightning_bolt": 3.8,
    "jupitel_thunder": 3.0,
    "storm_gust": 2.2,
    "sonic_blow": 2.5,
}


# Skill cast times (seconds) - affects when to use
SKILL_CAST_TIMES = {
    "fire_bolt": 0.7,
    "cold_bolt": 0.7,
    "lightning_bolt": 0.7,
    "fire_ball": 1.0,
    "fire_wall": 1.5,
    "frost_diver": 0.7,
    "storm_gust": 3.0,
    "meteor_storm": 5.0,
    "lord_of_vermillion": 4.0,
    "heaven_drive": 1.0,
    "jupitel_thunder": 1.5,
    "safety_wall": 2.0,
    "magnus_exorcismus": 2.0,
}


# Skill cooldowns (seconds)
SKILL_COOLDOWNS = {
    "magnum_break": 2.0,
    "bowling_bash": 1.0,
    "sonic_blow": 0.5,
    "meteor_assault": 1.0,
    "arrow_shower": 0.5,
    "sharp_shooting": 1.5,
    "storm_gust": 5.0,
    "meteor_storm": 10.0,
    "grand_cross": 3.0,
}


# Skill ranges (cells)
SKILL_RANGES = {
    # Melee
    "bash": 1,
    "magnum_break": 5,  # AoE radius
    "bowling_bash": 2,
    "holy_cross": 1,
    "grand_cross": 7,  # AoE radius
    "sonic_blow": 1,
    "meteor_assault": 1,
    
    # Ranged
    "double_strafe": 9,
    "arrow_shower": 9,
    "charge_arrow": 9,
    "blitz_beat": 5,
    
    # Magic
    "fire_bolt": 9,
    "cold_bolt": 9,
    "lightning_bolt": 9,
    "fire_ball": 9,
    "fire_wall": 9,
    "frost_diver": 9,
    "storm_gust": 9,
    "meteor_storm": 9,
    "lord_of_vermillion": 9,
    "heaven_drive": 9,
    "jupitel_thunder": 9,
    
    # Support
    "heal": 9,
    "blessing": 9,
    "increase_agi": 9,
    "kyrie_eleison": 9,
    "sanctuary": 9,
}


# Combat thresholds
COMBAT_THRESHOLDS = {
    # HP percentages
    "emergency_hp": 0.20,
    "low_hp": 0.35,
    "safe_hp": 0.70,
    
    # SP percentages
    "emergency_sp": 0.10,
    "low_sp": 0.25,
    "conservative_sp": 0.40,
    
    # Combat decisions
    "flee_threshold": 0.25,  # HP% to flee
    "kiting_distance": 7,  # Distance to maintain when kiting
    "melee_range": 2,  # Optimal melee range
    "safe_cast_distance": 6,  # Safe distance for casting
    
    # AoE thresholds
    "min_aoe_targets": 3,  # Minimum mobs to use AoE
    "optimal_aoe_targets": 5,  # Optimal mob count for AoE
    
    # Buff refresh
    "buff_refresh_time": 30.0,  # Seconds before buff expires to recast
}


# Skill SP costs by level (simplified - level 10 costs)
SKILL_SP_COSTS = {
    "bash": {"1": 8, "5": 12, "10": 15},
    "magnum_break": {"1": 30, "10": 30},
    "bowling_bash": {"1": 13, "5": 17, "10": 24},
    "double_strafe": {"1": 12, "10": 12},
    "arrow_shower": {"1": 15, "10": 15},
    "fire_bolt": {"1": 12, "5": 20, "10": 28},
    "cold_bolt": {"1": 12, "5": 20, "10": 28},
    "lightning_bolt": {"1": 12, "5": 20, "10": 28},
    "storm_gust": {"1": 78, "10": 78},
    "meteor_storm": {"1": 20, "10": 110},
    "sonic_blow": {"1": 16, "10": 16},
    "heal": {"1": 13, "5": 25, "10": 39},
    "blessing": {"1": 28, "10": 64},
    "increase_agi": {"1": 18, "10": 54},
}


def get_skill_priority_for_role(role: str) -> List[str]:
    """
    Get skill priority list for a given role.
    
    Args:
        role: Tactical role name
    
    Returns:
        List of skill names in priority order
    """
    return SKILL_PRIORITIES.get(role, [])


def is_aoe_skill(skill_name: str) -> bool:
    """Check if a skill is AoE."""
    return skill_name in AOE_SKILLS


def is_buff_skill(skill_name: str) -> bool:
    """Check if a skill is a buff."""
    return skill_name in BUFF_SKILLS


def get_skill_range(skill_name: str, default: int = 1) -> int:
    """Get skill range in cells."""
    return SKILL_RANGES.get(skill_name, default)


def get_skill_sp_cost(skill_name: str, level: int = 10) -> int:
    """Get SP cost for a skill at given level."""
    costs = SKILL_SP_COSTS.get(skill_name, {})
    return costs.get(str(level), costs.get("10", 0))


def should_use_aoe(monster_count: int) -> bool:
    """Determine if AoE skills should be used based on monster count."""
    return monster_count >= COMBAT_THRESHOLDS["min_aoe_targets"]


def get_optimal_skill_rotation(build_type: str) -> Dict[str, List[str]]:
    """Get skill rotation for a build type."""
    return SKILL_ROTATIONS.get(build_type, {
        "buff_phase": [],
        "opener": [],
        "spam": [],
        "aoe": [],
        "finisher": [],
    })