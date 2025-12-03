"""
Target Prioritization System for Ragnarok Online Combat AI.

Implements intelligent target selection with:
- MVP/Boss priority weights
- Aggressive mob detection
- Quest target tracking
- Optimal level calculations
- Distance-based prioritization
- Race/element-specific targeting
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from enum import Enum
from typing import TYPE_CHECKING

from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace, get_element_modifier

if TYPE_CHECKING:
    from ai_sidecar.core.state import CharacterState, Position

logger = logging.getLogger(__name__)


class TargetPriorityType(str, Enum):
    """Types of targeting priorities for RO combat."""
    
    MVP = "mvp"
    MINI_BOSS = "mini_boss"
    AGGRESSIVE_TARGETING_US = "aggressive_targeting_us"
    QUEST_TARGET = "quest_target"
    OPTIMAL_LEVEL = "optimal_level"
    NEARBY = "nearby"
    PASSIVE = "passive"
    LOW_HP = "low_hp"
    ELEMENTAL_ADVANTAGE = "elemental_advantage"


# RO-Specific Target Priority Weights
TARGET_WEIGHTS = {
    TargetPriorityType.MVP: 1000.0,
    TargetPriorityType.MINI_BOSS: 500.0,
    TargetPriorityType.AGGRESSIVE_TARGETING_US: 200.0,
    TargetPriorityType.QUEST_TARGET: 150.0,
    TargetPriorityType.OPTIMAL_LEVEL: 100.0,
    TargetPriorityType.NEARBY: 50.0,
    TargetPriorityType.PASSIVE: 10.0,
    TargetPriorityType.LOW_HP: 75.0,
    TargetPriorityType.ELEMENTAL_ADVANTAGE: 120.0,
}


@dataclass
class TargetScore:
    """Target with calculated priority score."""
    
    monster: MonsterActor
    total_score: float
    priority_reasons: list[tuple[TargetPriorityType, float]]
    distance: float
    
    def get_reason_summary(self) -> str:
        """Get human-readable summary of targeting reasons."""
        if not self.priority_reasons:
            return "default"
        
        # Get top 3 reasons
        top_reasons = sorted(
            self.priority_reasons,
            key=lambda x: x[1],
            reverse=True
        )[:3]
        
        return ", ".join(f"{r[0].value}({r[1]:.0f})" for r in top_reasons)


class TargetingSystem:
    """
    Intelligent target selection system for RO combat.
    
    Priorities (in order):
    1. MVP monsters (high value targets)
    2. Aggressive monsters targeting us
    3. Quest targets
    4. Optimal level monsters for exp
    5. Nearby monsters
    6. Passive monsters (lowest priority)
    
    Additional factors:
    - Distance (closer = higher priority)
    - HP percentage (low HP for finishing)
    - Elemental advantage
    - Monster danger vs character power
    """
    
    # Optimal level range for EXP (RO mechanic)
    # Best exp when monster level is char_level +/- 5
    OPTIMAL_LEVEL_RANGE = 5
    
    # Distance penalty multiplier (cells)
    DISTANCE_PENALTY_PER_CELL = 2.0
    
    # HP threshold for "low HP" bonus
    LOW_HP_THRESHOLD = 0.3
    
    def __init__(self, quest_targets: set[int] | None = None):
        """
        Initialize targeting system.
        
        Args:
            quest_targets: Set of monster IDs that are quest objectives
        """
        self.quest_targets = quest_targets or set()
        self._last_target_id: int | None = None
        self._target_lock_duration = 5  # Lock target for 5 ticks
        self._ticks_since_target_change = 0
    
    def select_target(
        self,
        character: CharacterState,
        nearby_monsters: list[MonsterActor],
        current_weapon_element: Element = Element.NEUTRAL,
        prefer_finish_low_hp: bool = True,
    ) -> MonsterActor | None:
        """
        Select the optimal target from nearby monsters.
        
        Args:
            character: Character state
            nearby_monsters: List of monsters in range
            current_weapon_element: Element of equipped weapon/spell
            prefer_finish_low_hp: Prioritize finishing low HP targets
        
        Returns:
            Best target monster or None if no valid targets
        """
        if not nearby_monsters:
            logger.debug("No monsters nearby to target")
            return None
        
        # Score all targets
        scored_targets = self._score_all_targets(
            character,
            nearby_monsters,
            current_weapon_element,
            prefer_finish_low_hp,
        )
        
        if not scored_targets:
            return None
        
        # Get best target
        best_target = scored_targets[0]
        
        logger.info(
            f"Selected target: {best_target.monster.name} "
            f"(score: {best_target.total_score:.1f}, "
            f"reasons: {best_target.get_reason_summary()})"
        )
        
        self._last_target_id = best_target.monster.actor_id
        self._ticks_since_target_change = 0
        
        return best_target.monster
    
    def _score_all_targets(
        self,
        character: CharacterState,
        monsters: list[MonsterActor],
        weapon_element: Element,
        prefer_low_hp: bool,
    ) -> list[TargetScore]:
        """Score and sort all potential targets."""
        scored: list[TargetScore] = []
        
        for monster in monsters:
            score_data = self._calculate_target_score(
                character,
                monster,
                weapon_element,
                prefer_low_hp,
            )
            scored.append(score_data)
        
        # Sort by total score (highest first)
        return sorted(scored, key=lambda x: x.total_score, reverse=True)
    
    def _calculate_target_score(
        self,
        character: CharacterState,
        monster: MonsterActor,
        weapon_element: Element,
        prefer_low_hp: bool,
    ) -> TargetScore:
        """Calculate comprehensive priority score for a target."""
        reasons: list[tuple[TargetPriorityType, float]] = []
        total_score = 0.0
        
        # Calculate distance
        char_pos = character.position
        monster_pos = monster.position
        distance = ((char_pos.x - monster_pos.x) ** 2 + 
                   (char_pos.y - monster_pos.y) ** 2) ** 0.5
        
        # 1. MVP Priority (highest)
        if monster.is_mvp:
            mvp_score = TARGET_WEIGHTS[TargetPriorityType.MVP]
            reasons.append((TargetPriorityType.MVP, mvp_score))
            total_score += mvp_score
            logger.debug(f"MVP bonus: {mvp_score}")
        
        # 2. Mini-boss Priority
        elif monster.is_boss:
            boss_score = TARGET_WEIGHTS[TargetPriorityType.MINI_BOSS]
            reasons.append((TargetPriorityType.MINI_BOSS, boss_score))
            total_score += boss_score
            logger.debug(f"Mini-boss bonus: {boss_score}")
        
        # 3. Aggressive targeting us (immediate threat)
        if monster.is_targeting_player:
            aggro_score = TARGET_WEIGHTS[TargetPriorityType.AGGRESSIVE_TARGETING_US]
            reasons.append((TargetPriorityType.AGGRESSIVE_TARGETING_US, aggro_score))
            total_score += aggro_score
            logger.debug(f"Targeting us bonus: {aggro_score}")
        
        # 4. Quest target
        if monster.mob_id in self.quest_targets:
            quest_score = TARGET_WEIGHTS[TargetPriorityType.QUEST_TARGET]
            reasons.append((TargetPriorityType.QUEST_TARGET, quest_score))
            total_score += quest_score
            logger.debug(f"Quest target bonus: {quest_score}")
        
        # 5. Optimal level for EXP (RO mechanic)
        if hasattr(monster, "level"):
            level_diff = abs(character.level - monster.level)
            if level_diff <= self.OPTIMAL_LEVEL_RANGE:
                # Closer to character level = better EXP
                level_score = TARGET_WEIGHTS[TargetPriorityType.OPTIMAL_LEVEL]
                level_score *= (1.0 - level_diff / (self.OPTIMAL_LEVEL_RANGE * 2))
                reasons.append((TargetPriorityType.OPTIMAL_LEVEL, level_score))
                total_score += level_score
                logger.debug(f"Optimal level bonus: {level_score}")
        
        # 6. Low HP targets (finish off)
        if prefer_low_hp:
            hp_percent = monster.hp / max(monster.hp_max, 1)
            if hp_percent <= self.LOW_HP_THRESHOLD:
                # Lower HP = higher bonus
                low_hp_score = TARGET_WEIGHTS[TargetPriorityType.LOW_HP]
                low_hp_score *= (1.0 - hp_percent)
                reasons.append((TargetPriorityType.LOW_HP, low_hp_score))
                total_score += low_hp_score
                logger.debug(f"Low HP bonus: {low_hp_score}")
        
        # 7. Elemental advantage
        element_modifier = get_element_modifier(weapon_element, monster.element)
        if element_modifier > 1.0:
            element_score = TARGET_WEIGHTS[TargetPriorityType.ELEMENTAL_ADVANTAGE]
            element_score *= (element_modifier - 1.0)
            reasons.append((TargetPriorityType.ELEMENTAL_ADVANTAGE, element_score))
            total_score += element_score
            logger.debug(f"Elemental advantage bonus: {element_score}")
        
        # 8. Distance penalty (prefer closer targets)
        distance_penalty = distance * self.DISTANCE_PENALTY_PER_CELL
        total_score -= distance_penalty
        
        # 9. Base priority by aggro type
        if monster.is_aggressive:
            nearby_score = TARGET_WEIGHTS[TargetPriorityType.NEARBY]
            reasons.append((TargetPriorityType.NEARBY, nearby_score))
            total_score += nearby_score
        else:
            passive_score = TARGET_WEIGHTS[TargetPriorityType.PASSIVE]
            reasons.append((TargetPriorityType.PASSIVE, passive_score))
            total_score += passive_score
        
        return TargetScore(
            monster=monster,
            total_score=max(0, total_score),  # Never negative
            priority_reasons=reasons,
            distance=distance,
        )
    
    def add_quest_target(self, mob_id: int) -> None:
        """Add a monster ID as quest target."""
        self.quest_targets.add(mob_id)
        logger.info(f"Added quest target: mob_id={mob_id}")
    
    def remove_quest_target(self, mob_id: int) -> None:
        """Remove a monster ID from quest targets."""
        self.quest_targets.discard(mob_id)
        logger.info(f"Removed quest target: mob_id={mob_id}")
    
    def clear_quest_targets(self) -> None:
        """Clear all quest targets."""
        self.quest_targets.clear()
        logger.info("Cleared all quest targets")
    
    def should_switch_target(
        self,
        current_target: MonsterActor,
        nearby_monsters: list[MonsterActor],
        character: CharacterState,
    ) -> bool:
        """
        Determine if we should switch from current target.
        
        Reasons to switch:
        - Current target died
        - Much higher priority target appeared (MVP, aggressive)
        - Current target is too far away
        
        Args:
            current_target: Currently engaged target
            nearby_monsters: All nearby monsters
            character: Character state
        
        Returns:
            True if should switch targets
        """
        if not current_target:
            return True
        
        # Target died or out of range
        if current_target not in nearby_monsters:
            logger.debug("Current target no longer valid")
            return True
        
        # Get current target score
        current_score = self._calculate_target_score(
            character,
            current_target,
            Element.NEUTRAL,  # Simplified for comparison
            prefer_low_hp=False,
        )
        
        # Check if any other target has significantly higher priority
        for monster in nearby_monsters:
            if monster.actor_id == current_target.actor_id:
                continue
            
            alt_score = self._calculate_target_score(
                character,
                monster,
                Element.NEUTRAL,
                prefer_low_hp=False,
            )
            
            # Switch if alternative is 50% better (avoid target hopping)
            if alt_score.total_score > current_score.total_score * 1.5:
                logger.info(
                    f"Switching target: {current_target.name} "
                    f"({current_score.total_score:.0f}) -> "
                    f"{monster.name} ({alt_score.total_score:.0f})"
                )
                return True
        
        return False
    
    def get_priority_summary(self, character: CharacterState) -> dict[str, int]:
        """Get summary of current targeting priorities (for debugging)."""
        return {
            "mvp_weight": TARGET_WEIGHTS[TargetPriorityType.MVP],
            "boss_weight": TARGET_WEIGHTS[TargetPriorityType.MINI_BOSS],
            "aggressive_weight": TARGET_WEIGHTS[TargetPriorityType.AGGRESSIVE_TARGETING_US],
            "quest_targets": len(self.quest_targets),
            "optimal_level_range": self.OPTIMAL_LEVEL_RANGE,
        }


def create_default_targeting_system() -> TargetingSystem:
    """Create targeting system with default configuration."""
    return TargetingSystem()


# Alias for backward compatibility
TargetSelector = TargetingSystem

# Additional method for select_targets (test compatibility)
def select_targets(self, monsters: list, target_type: str = "single") -> list:
    """
    Select targets based on type (backwards compatibility).
    
    Args:
        monsters: List of monsters
        target_type: Type of targeting (single, aoe, etc.)
    
    Returns:
        List of selected targets
    """
    if not monsters:
        return []
    return monsters[:1] if target_type == "single" else monsters

# Add method to TargetingSystem
TargetingSystem.select_targets = select_targets