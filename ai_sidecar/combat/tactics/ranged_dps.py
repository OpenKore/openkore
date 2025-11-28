"""
Ranged DPS Tactics Implementation.

Specialized combat behavior for ranged damage dealers:
- Kiting and distance management
- Arrow/Bolt element matching
- Trap deployment strategies
- Efficient skill rotation for Hunters/Snipers
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


class RangedDPSTacticsConfig(TacticsConfig):
    """Ranged DPS-specific configuration."""
    
    # Ranged positioning
    optimal_range: int = 9  # Max bow range
    min_safe_distance: int = 4  # Minimum distance from enemies
    kiting_enabled: bool = True
    
    # Trap management
    use_traps: bool = True
    trap_placement_distance: int = 3
    
    # Arrow management
    element_matching: bool = True
    
    # Focus target
    prefer_single_target: bool = True


class RangedDPSTactics(BaseTactics):
    """
    Ranged DPS tactical behavior for Hunters/Snipers.
    
    Priorities:
    1. Maintain safe distance from enemies
    2. Match arrow element to target weakness
    3. Deploy traps strategically
    4. Execute kiting patterns when needed
    """
    
    role = TacticalRole.RANGED_DPS
    
    # Ranged attack skills
    PRIMARY_SKILLS = [
        "double_strafe", "ac_double",
        "arrow_shower", "ac_shower",
        "blitz_beat", "ht_blitzbeat",
        "falcon_assault", "sn_falconassault",
    ]
    
    # Single target skills
    SINGLE_TARGET_SKILLS = [
        "double_strafe", "ac_double",
        "blitz_beat", "ht_blitzbeat",
        "sharp_shooting", "sn_sharpshooting",
    ]
    
    # AoE skills
    AOE_SKILLS = [
        "arrow_shower", "ac_shower",
        "arrow_storm", "ra_arrowstorm",
    ]
    
    # Trap skills
    TRAP_SKILLS = [
        "ankle_snare", "ht_anklesnare",
        "sandman", "ht_sandman",
        "freezing_trap", "ht_freezingtrap",
        "blast_mine", "ht_blastmine",
        "claymore_trap", "ht_claymoretrap",
        "land_mine", "ht_landmine",
    ]
    
    # Buff skills
    BUFF_SKILLS = [
        "improve_concentration", "ac_concentration",
        "true_sight", "sn_sight",
        "wind_walk", "sn_windwalk",
    ]
    
    def __init__(self, config: RangedDPSTacticsConfig | None = None):
        """Initialize ranged DPS tactics."""
        super().__init__(config or RangedDPSTacticsConfig())
        self.ranged_config = config or RangedDPSTacticsConfig()
        self._deployed_traps: list[Position] = []
        self._kiting_direction: tuple[int, int] = (0, 0)
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select ranged target optimally.
        
        Priority:
        1. Targets within optimal range
        2. Targets weak to current arrow element
        3. Lowest HP targets
        4. Targets not in trap range
        """
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        targets = self.prioritize_targets(
            context, monsters, self._ranged_target_score
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
        Select optimal ranged skill.
        
        Priority:
        1. Buffs if needed
        2. Trap deployment if enemy approaching
        3. AoE if multiple targets clustered
        4. Single target damage skill
        """
        # Check buffs first
        buff = self._select_buff_skill(context)
        if buff:
            return buff
        
        # Check if enemy is too close - deploy trap
        if target.distance < self.ranged_config.min_safe_distance:
            trap = self._select_trap_skill(context)
            if trap:
                return trap
        
        # Check AoE opportunity
        clustered = self._count_clustered_enemies(context, target)
        if clustered >= 3 and not self.ranged_config.prefer_single_target:
            aoe = self._select_aoe_skill(context)
            if aoe:
                return aoe
        
        # Single target damage
        return self._select_damage_skill(context)
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine ranged positioning with kiting.
        
        Ranged DPS should:
        - Maintain optimal range to targets
        - Kite away from approaching enemies
        - Avoid standing in danger zones
        """
        if not context.nearby_monsters:
            return None
        
        current = context.character_position
        
        # Find closest enemy
        closest_distance = float('inf')
        closest_monster = None
        
        for monster in context.nearby_monsters:
            dist = self.get_distance_to_target(context, monster.position)
            if dist < closest_distance:
                closest_distance = dist
                closest_monster = monster
        
        if closest_monster is None:
            return None
        
        # If enemy too close, kite away
        if closest_distance < self.ranged_config.min_safe_distance:
            return self._calculate_kite_position(
                current,
                Position(
                    x=closest_monster.position[0],
                    y=closest_monster.position[1]
                )
            )
        
        # If too far, move closer to optimal range
        if closest_distance > self.ranged_config.optimal_range:
            return self._calculate_approach_position(
                current,
                Position(
                    x=closest_monster.position[0],
                    y=closest_monster.position[1]
                )
            )
        
        return None
    
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Assess threat for ranged DPS.
        
        Ranged is squishy - high threat when:
        - Enemies in melee range
        - Low HP
        - No escape route
        """
        threat = 0.0
        
        # HP-based threat
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.25:
            threat += 0.5
        elif hp_percent < 0.50:
            threat += 0.25
        
        # Count enemies too close
        too_close = sum(
            1 for m in context.nearby_monsters
            if self.get_distance_to_target(context, m.position) 
            < self.ranged_config.min_safe_distance
        )
        
        threat += min(0.4, too_close * 0.15)
        
        # Check for surrounding (multiple enemies in different directions)
        if self._is_surrounded(context):
            threat += 0.3
        
        return min(1.0, threat)
    
    # Ranged DPS-specific helper methods
    
    def _ranged_target_score(
        self,
        target: Any,
        hp_percent: float,
        distance: float
    ) -> float:
        """Calculate ranged target priority score."""
        score = 100.0
        
        # Optimal range bonus
        if self.ranged_config.min_safe_distance <= distance <= self.ranged_config.optimal_range:
            score += 30
        elif distance > self.ranged_config.optimal_range:
            score -= (distance - self.ranged_config.optimal_range) * 5
        elif distance < self.ranged_config.min_safe_distance:
            score -= 20  # Penalty for being too close
        
        # Low HP bonus
        score += (1 - hp_percent) * 25
        
        # Boss/MVP bonus
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
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=0,
                    target_type="self",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_trap_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select trap skill for defense."""
        if not self.ranged_config.use_traps:
            return None
        
        for skill_name in self.TRAP_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=5,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=self.ranged_config.trap_placement_distance,
                    target_type="ground",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_aoe_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select AoE skill."""
        for skill_name in self.AOE_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="ground",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_damage_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select single target damage skill."""
        for skill_name in self.SINGLE_TARGET_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
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
        """Count enemies clustered around target."""
        target_monster = None
        for m in context.nearby_monsters:
            if m.actor_id == center_target.actor_id:
                target_monster = m
                break
        
        if target_monster is None:
            return 0
        
        center = Position(
            x=target_monster.position[0],
            y=target_monster.position[1]
        )
        
        return sum(
            1 for m in context.nearby_monsters
            if Position(x=m.position[0], y=m.position[1]).distance_to(center) <= 5
        )
    
    def _calculate_kite_position(
        self,
        current: Position,
        threat: Position
    ) -> Position:
        """Calculate position to kite away from threat."""
        # Move directly away from threat
        dx = current.x - threat.x
        dy = current.y - threat.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        # Move 3-4 cells away
        move_distance = 4
        
        new_x = current.x + int(dx / distance * move_distance)
        new_y = current.y + int(dy / distance * move_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _calculate_approach_position(
        self,
        current: Position,
        target: Position
    ) -> Position:
        """Calculate position to approach target to optimal range."""
        dx = target.x - current.x
        dy = target.y - current.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        # Move to optimal range
        target_distance = self.ranged_config.optimal_range - 1
        move_distance = distance - target_distance
        
        if move_distance <= 0:
            return current
        
        new_x = current.x + int(dx / distance * move_distance)
        new_y = current.y + int(dy / distance * move_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _is_surrounded(self, context: CombatContextProtocol) -> bool:
        """Check if character is surrounded by enemies."""
        current = context.character_position
        
        # Check enemies in 4 quadrants
        quadrants = [False, False, False, False]  # NE, SE, SW, NW
        
        for monster in context.nearby_monsters:
            dist = self.get_distance_to_target(context, monster.position)
            if dist > 5:
                continue
            
            dx = monster.position[0] - current.x
            dy = monster.position[1] - current.y
            
            if dx >= 0 and dy >= 0:
                quadrants[0] = True
            elif dx >= 0 and dy < 0:
                quadrants[1] = True
            elif dx < 0 and dy < 0:
                quadrants[2] = True
            else:
                quadrants[3] = True
        
        # Surrounded if enemies in 3+ quadrants
        return sum(quadrants) >= 3
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID from name."""
        skill_ids = {
            "double_strafe": 46,
            "ac_double": 46,
            "arrow_shower": 47,
            "ac_shower": 47,
            "improve_concentration": 45,
            "ac_concentration": 45,
            "blitz_beat": 129,
            "ht_blitzbeat": 129,
            "ankle_snare": 116,
            "ht_anklesnare": 116,
            "sandman": 119,
            "ht_sandman": 119,
            "freezing_trap": 120,
            "ht_freezingtrap": 120,
            "blast_mine": 117,
            "ht_blastmine": 117,
            "claymore_trap": 121,
            "ht_claymoretrap": 121,
            "land_mine": 115,
            "ht_landmine": 115,
            "falcon_assault": 381,
            "sn_falconassault": 381,
            "sharp_shooting": 382,
            "sn_sharpshooting": 382,
            "true_sight": 380,
            "sn_sight": 380,
            "wind_walk": 389,
            "sn_windwalk": 389,
        }
        return skill_ids.get(skill_name, 0)
    
    def _get_sp_cost(self, skill_name: str) -> int:
        """Get SP cost for skills."""
        costs = {
            "double_strafe": 12,
            "ac_double": 12,
            "arrow_shower": 15,
            "ac_shower": 15,
            "improve_concentration": 40,
            "ac_concentration": 40,
            "blitz_beat": 28,
            "ht_blitzbeat": 28,
            "ankle_snare": 12,
            "ht_anklesnare": 12,
            "blast_mine": 10,
            "ht_blastmine": 10,
            "claymore_trap": 15,
            "ht_claymoretrap": 15,
            "falcon_assault": 30,
            "sn_falconassault": 30,
            "sharp_shooting": 50,
            "sn_sharpshooting": 50,
            "true_sight": 30,
            "sn_sight": 30,
        }
        return costs.get(skill_name, 15)