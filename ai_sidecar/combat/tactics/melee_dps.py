"""
Melee DPS Tactics Implementation.

Specialized combat behavior for melee damage dealers:
- Burst damage and combo chains
- Target prioritization by HP
- Efficient skill rotation
- Two-Hand Quicken and buff management
"""

import logging
from typing import Any

from ai_sidecar.combat.tactics.base import (
    BaseTactics,
    CombatContextProtocol,
    Position,
    Skill,
    TacticalRole,
    TacticsConfig,
    TargetPriority,
)

logger = logging.getLogger(__name__)


class MeleeDPSTacticsConfig(TacticsConfig):
    """Melee DPS-specific configuration."""
    
    # DPS positioning
    optimal_range: int = 1
    max_chase_distance: int = 10
    
    # Buff management
    maintain_buffs: bool = True
    buff_refresh_threshold: float = 5.0  # Refresh buff when < 5s remaining
    
    # Damage optimization
    prefer_criticals: bool = True
    use_burst_skills: bool = True
    combo_enabled: bool = True


class MeleeDPSTactics(BaseTactics):
    """
    Melee DPS tactical behavior for maximum damage output.
    
    Priorities:
    1. Maintain offensive buffs (Two-Hand Quicken, etc.)
    2. Select lowest HP targets for quick kills
    3. Execute burst damage rotations
    4. Position for maximum attack uptime
    """
    
    role = TacticalRole.MELEE_DPS
    
    # Buff skills
    BUFF_SKILLS = [
        "two_hand_quicken", "kn_twohandquicken",
        "aura_blade", "kn_aurablade",
        "concentration", "kn_concentration",
        "spear_quicken", "kn_spearquicken",
    ]
    
    # Damage skills by priority
    BURST_SKILLS = [
        "bowling_bash", "kn_bowlingbash",
        "brandish_spear", "kn_brandishspear",
        "pierce", "kn_pierce",
        "spiral_pierce", "lk_spiralpierce",
    ]
    
    SINGLE_TARGET_SKILLS = [
        "bash", "sm_bash",
        "pierce", "kn_pierce",
        "spiral_pierce", "lk_spiralpierce",
    ]
    
    AOE_SKILLS = [
        "bowling_bash", "kn_bowlingbash",
        "brandish_spear", "kn_brandishspear",
        "magnum_break", "sm_magnum",
    ]
    
    def __init__(self, config: MeleeDPSTacticsConfig | None = None):
        """Initialize melee DPS tactics."""
        super().__init__(config or MeleeDPSTacticsConfig())
        self.dps_config = config or MeleeDPSTacticsConfig()
        self._combo_state: str | None = None
        self._buff_timers: dict[str, float] = {}
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select DPS target for maximum damage efficiency.
        
        Priority order:
        1. Very low HP targets (quick kills)
        2. Targets within range
        3. Softest targets (lowest defense)
        4. Nearest targets
        """
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        # Priority scoring for DPS
        targets = self.prioritize_targets(
            context, 
            monsters, 
            self._dps_target_score
        )
        
        if targets:
            return targets[0]
        
        return None
    
    async def select_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """
        Select optimal damage skill.
        
        Priority:
        1. Maintain buffs if needed
        2. AoE if multiple targets clustered
        3. Burst skill for high damage
        4. Standard rotation skill
        """
        # Check if buffs need refresh
        if self.dps_config.maintain_buffs:
            buff = self._select_buff_skill(context)
            if buff:
                return buff
        
        # Check AoE opportunity
        clustered = self._count_clustered_enemies(context, target)
        if clustered >= 3:
            aoe = self._select_aoe_skill(context)
            if aoe:
                return aoe
        
        # Check for burst opportunity on low HP target
        if target.hp_percent < 0.5 and self.dps_config.use_burst_skills:
            burst = self._select_burst_skill(context)
            if burst:
                return burst
        
        # Standard damage skill
        return self._select_damage_skill(context, target)
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine DPS positioning.
        
        Melee DPS should:
        - Be adjacent to target (range 1)
        - Chase targets within range
        - Avoid being surrounded
        """
        if not context.nearby_monsters:
            return None
        
        # Find primary target
        targets = self.prioritize_targets(
            context, context.nearby_monsters, self._dps_target_score
        )
        
        if not targets:
            return None
        
        primary = targets[0]
        target_monster = self._find_monster_by_id(
            context, primary.actor_id
        )
        
        if target_monster is None:
            return None
        
        # Check distance to target
        current = context.character_position
        target_pos = Position(
            x=target_monster.position[0],
            y=target_monster.position[1]
        )
        
        distance = current.distance_to(target_pos)
        
        # Already in range
        if distance <= self.dps_config.optimal_range:
            return None
        
        # Target too far to chase
        if distance > self.dps_config.max_chase_distance:
            return None
        
        # Move toward target
        return self._calculate_approach_position(current, target_pos)
    
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Assess threat level for melee DPS.
        
        DPS is squishy - threat increases with:
        - Multiple enemies targeting us
        - Low HP state
        - Being surrounded
        """
        threat = 0.0
        
        # HP-based threat
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.25:
            threat += 0.5
        elif hp_percent < 0.50:
            threat += 0.25
        
        # Count enemies in melee range
        melee_enemies = sum(
            1 for m in context.nearby_monsters
            if self.get_distance_to_target(context, m.position) <= 2
        )
        
        threat += min(0.3, melee_enemies * 0.1)
        
        # Check for aggressive/boss enemies
        for monster in context.nearby_monsters:
            if hasattr(monster, "is_boss") and monster.is_boss:
                threat += 0.2
            if hasattr(monster, "is_mvp") and monster.is_mvp:
                threat += 0.3
        
        return min(1.0, threat)
    
    # Melee DPS-specific helper methods
    
    def _dps_target_score(
        self,
        target: Any,
        hp_percent: float,
        distance: float
    ) -> float:
        """Calculate DPS target priority score."""
        score = 100.0
        
        # Strong preference for low HP (finish kills quickly)
        if hp_percent < 0.25:
            score += 50
        elif hp_percent < 0.50:
            score += 30
        else:
            score += (1 - hp_percent) * 20
        
        # Prefer closer targets
        if distance > 0:
            score -= distance * 3
        
        # Bonus for being in melee range
        if distance <= 1:
            score += 15
        
        # Bonus for MVP/boss (better drops)
        if hasattr(target, "is_mvp") and target.is_mvp:
            score += 40
        elif hasattr(target, "is_boss") and target.is_boss:
            score += 20
        
        return max(0, score)
    
    def _select_buff_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select buff skill if needed."""
        for skill_name in self.BUFF_SKILLS:
            # Check if buff is already active
            remaining = self._buff_timers.get(skill_name, 0)
            if remaining > self.dps_config.buff_refresh_threshold:
                continue
            
            # Check cooldown and SP
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_buff_sp_cost(skill_name),
                    cooldown=0,
                    range=0,
                    target_type="self",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_burst_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select high damage burst skill."""
        for skill_name in self.BURST_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_skill_sp_cost(skill_name),
                    cooldown=0,
                    range=2,
                    target_type="single",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_aoe_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select AoE damage skill."""
        for skill_name in self.AOE_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_skill_sp_cost(skill_name),
                    cooldown=0,
                    range=2,
                    target_type="ground",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_damage_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """Select standard damage skill."""
        for skill_name in self.SINGLE_TARGET_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_skill_sp_cost(skill_name),
                    cooldown=0,
                    range=1,
                    target_type="single",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _count_clustered_enemies(
        self,
        context: CombatContextProtocol,
        center_target: TargetPriority
    ) -> int:
        """Count enemies clustered around a target."""
        target_monster = self._find_monster_by_id(
            context, center_target.actor_id
        )
        if target_monster is None:
            return 0
        
        center = Position(
            x=target_monster.position[0],
            y=target_monster.position[1]
        )
        
        count = 0
        for monster in context.nearby_monsters:
            pos = Position(x=monster.position[0], y=monster.position[1])
            if center.distance_to(pos) <= 3:  # AoE radius
                count += 1
        
        return count
    
    def _find_monster_by_id(
        self,
        context: CombatContextProtocol,
        actor_id: int
    ) -> Any | None:
        """Find monster by actor ID."""
        for monster in context.nearby_monsters:
            if monster.actor_id == actor_id:
                return monster
        return None
    
    def _calculate_approach_position(
        self,
        current: Position,
        target: Position
    ) -> Position:
        """Calculate position to approach target."""
        dx = target.x - current.x
        dy = target.y - current.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        # Move to position adjacent to target
        move_distance = max(0, distance - 1)
        
        new_x = current.x + int(dx / distance * move_distance)
        new_y = current.y + int(dy / distance * move_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID from name."""
        skill_ids = {
            "two_hand_quicken": 60,
            "kn_twohandquicken": 60,
            "aura_blade": 355,
            "kn_aurablade": 355,
            "concentration": 357,
            "kn_concentration": 357,
            "spear_quicken": 61,
            "kn_spearquicken": 61,
            "bowling_bash": 62,
            "kn_bowlingbash": 62,
            "brandish_spear": 57,
            "kn_brandishspear": 57,
            "pierce": 56,
            "kn_pierce": 56,
            "spiral_pierce": 397,
            "lk_spiralpierce": 397,
            "bash": 5,
            "sm_bash": 5,
            "magnum_break": 7,
            "sm_magnum": 7,
        }
        return skill_ids.get(skill_name, 0)
    
    def _get_buff_sp_cost(self, skill_name: str) -> int:
        """Get SP cost for buff skills."""
        costs = {
            "two_hand_quicken": 14,
            "kn_twohandquicken": 14,
            "aura_blade": 18,
            "kn_aurablade": 18,
            "concentration": 25,
            "kn_concentration": 25,
            "spear_quicken": 14,
            "kn_spearquicken": 14,
        }
        return costs.get(skill_name, 20)
    
    def _get_skill_sp_cost(self, skill_name: str) -> int:
        """Get SP cost for damage skills."""
        costs = {
            "bowling_bash": 13,
            "kn_bowlingbash": 13,
            "brandish_spear": 12,
            "kn_brandishspear": 12,
            "pierce": 7,
            "kn_pierce": 7,
            "spiral_pierce": 30,
            "lk_spiralpierce": 30,
            "bash": 15,
            "sm_bash": 15,
            "magnum_break": 30,
            "sm_magnum": 30,
        }
        return costs.get(skill_name, 15)