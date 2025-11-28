"""
Magic DPS Tactics Implementation.

Specialized combat behavior for magic damage dealers:
- Cast timing and interruption avoidance
- Element matching to target weaknesses
- AoE spell positioning
- SP management and conservation
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


class MagicDPSTacticsConfig(TacticsConfig):
    """Magic DPS-specific configuration."""
    
    # Casting safety
    safe_cast_distance: int = 8
    interrupt_avoidance: bool = True
    
    # Element strategy
    element_matching: bool = True
    preferred_element: str = "neutral"  # Can be set based on hunt
    
    # SP management
    sp_conservation_threshold: float = 0.30  # Below this, conserve SP
    use_aoe_threshold: int = 3  # Min enemies for AoE
    
    # Cast optimization
    prefer_instant_cast: bool = False  # When under pressure


class MagicDPSTactics(BaseTactics):
    """
    Magic DPS tactical behavior for Wizards/High Wizards.
    
    Priorities:
    1. Maintain safe casting distance
    2. Match spell element to target weakness
    3. Use AoE spells efficiently
    4. Conserve SP while maximizing damage
    """
    
    role = TacticalRole.MAGIC_DPS
    
    # Element mapping for spells
    ELEMENT_SKILLS = {
        "fire": [
            "fire_bolt", "mg_firebolt",
            "fire_ball", "mg_fireball",
            "fire_wall", "mg_firewall",
            "meteor_storm", "wz_meteor",
            "fire_pillar", "wz_firepillar",
        ],
        "water": [
            "cold_bolt", "mg_coldbolt",
            "frost_diver", "mg_frostdiver",
            "storm_gust", "wz_stormgust",
            "water_ball", "wz_waterball",
        ],
        "wind": [
            "lightning_bolt", "mg_lightningbolt",
            "thunder_storm", "mg_thunderstorm",
            "jupitel_thunder", "wz_jupitel",
            "lord_of_vermilion", "wz_vermilion",
        ],
        "earth": [
            "stone_curse", "mg_stonecurse",
            "earth_spike", "wz_earthspike",
            "heaven_drive", "wz_heavendrive",
            "quagmire", "wz_quagmire",
        ],
    }
    
    # AoE spells
    AOE_SKILLS = [
        "storm_gust", "wz_stormgust",
        "meteor_storm", "wz_meteor",
        "lord_of_vermilion", "wz_vermilion",
        "heaven_drive", "wz_heavendrive",
    ]
    
    # Single target spells
    SINGLE_TARGET_SKILLS = [
        "fire_bolt", "mg_firebolt",
        "cold_bolt", "mg_coldbolt",
        "lightning_bolt", "mg_lightningbolt",
        "jupitel_thunder", "wz_jupitel",
        "earth_spike", "wz_earthspike",
    ]
    
    # Utility spells
    UTILITY_SKILLS = [
        "quagmire", "wz_quagmire",
        "frost_diver", "mg_frostdiver",
        "stone_curse", "mg_stonecurse",
        "fire_wall", "mg_firewall",
        "ice_wall", "wz_icewall",
    ]
    
    # Buff skills
    BUFF_SKILLS = [
        "sight", "mg_sight",
        "energy_coat", "mg_energycoat",
        "amplify_magic", "hw_magicpower",
    ]
    
    # Element counter chart
    ELEMENT_COUNTERS = {
        "fire": "earth",
        "water": "fire",
        "wind": "water",
        "earth": "wind",
        "holy": "undead",
        "undead": "holy",
        "dark": "holy",
    }
    
    def __init__(self, config: MagicDPSTacticsConfig | None = None):
        """Initialize magic DPS tactics."""
        super().__init__(config or MagicDPSTacticsConfig())
        self.magic_config = config or MagicDPSTacticsConfig()
        self._current_cast: str | None = None
        self._cast_start_time: float = 0
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select magic target optimally.
        
        Priority:
        1. Targets weak to available elements
        2. Clustered targets for AoE
        3. High HP targets (magic scales better)
        4. Targets within safe range
        """
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        targets = self.prioritize_targets(
            context, monsters, self._magic_target_score
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
        Select optimal magic skill.
        
        Priority:
        1. Buffs (Energy Coat, Amplify Magic)
        2. Utility (Quagmire on dangerous enemies)
        3. AoE if clustered enemies
        4. Element-matched single target
        5. Default bolt spell
        """
        # SP conservation check
        sp_percent = context.character_sp / max(context.character_sp_max, 1)
        conserve_sp = sp_percent < self.magic_config.sp_conservation_threshold
        
        # Buff check
        if not conserve_sp:
            buff = self._select_buff_skill(context)
            if buff:
                return buff
        
        # Utility check for dangerous targets
        target_monster = self._find_monster_by_id(context, target.actor_id)
        if target_monster and self._is_dangerous_target(target_monster):
            utility = self._select_utility_skill(context)
            if utility:
                return utility
        
        # AoE check
        if not conserve_sp:
            clustered = self._count_clustered_enemies(context, target)
            if clustered >= self.magic_config.use_aoe_threshold:
                aoe = self._select_aoe_skill(context, target_monster)
                if aoe:
                    return aoe
        
        # Element-matched single target
        element = self._get_target_weakness(target_monster)
        if element and self.magic_config.element_matching:
            elemental = self._select_elemental_skill(context, element)
            if elemental:
                return elemental
        
        # Default bolt spell
        return self._select_bolt_spell(context, conserve_sp)
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine mage positioning.
        
        Mages should:
        - Stay at safe casting distance
        - Avoid being approached during casting
        - Position for optimal AoE coverage
        """
        if not context.nearby_monsters:
            return None
        
        current = context.character_position
        
        # Find closest threat
        closest_distance = float('inf')
        closest_monster = None
        
        for monster in context.nearby_monsters:
            dist = self.get_distance_to_target(context, monster.position)
            if dist < closest_distance:
                closest_distance = dist
                closest_monster = monster
        
        if closest_monster is None:
            return None
        
        # If too close, retreat
        if closest_distance < self.magic_config.safe_cast_distance:
            return self._calculate_retreat_position(
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
        Assess threat for magic DPS.
        
        Mages are very fragile - high threat when:
        - Enemies too close
        - Low HP
        - While casting (vulnerable)
        - Low SP (can't fight)
        """
        threat = 0.0
        
        # HP-based threat
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.25:
            threat += 0.5
        elif hp_percent < 0.50:
            threat += 0.25
        
        # SP-based threat (can't cast without SP)
        sp_percent = context.character_sp / max(context.character_sp_max, 1)
        if sp_percent < 0.1:
            threat += 0.3
        elif sp_percent < 0.2:
            threat += 0.15
        
        # Distance-based threat
        for monster in context.nearby_monsters:
            dist = self.get_distance_to_target(context, monster.position)
            if dist < 3:
                threat += 0.2
            elif dist < self.magic_config.safe_cast_distance:
                threat += 0.1
        
        # Currently casting threat
        if self._current_cast:
            threat += 0.1
        
        return min(1.0, threat)
    
    # Magic DPS-specific helper methods
    
    def _magic_target_score(
        self,
        target: Any,
        hp_percent: float,
        distance: float
    ) -> float:
        """Calculate magic target priority score."""
        score = 100.0
        
        # Safe distance bonus
        if self.magic_config.safe_cast_distance <= distance <= 12:
            score += 20
        elif distance < self.magic_config.safe_cast_distance:
            score -= 15  # Penalty for too close
        
        # Magic works well on high HP targets
        score += hp_percent * 10
        
        # Element weakness bonus
        if hasattr(target, "element"):
            weakness = self.ELEMENT_COUNTERS.get(target.element)
            if weakness and self._has_element_spell(weakness):
                score += 30
        
        # Boss/MVP bonus
        if hasattr(target, "is_mvp") and target.is_mvp:
            score += 35
        elif hasattr(target, "is_boss") and target.is_boss:
            score += 15
        
        return max(0, score)
    
    def _has_element_spell(self, element: str) -> bool:
        """Check if we have spells for an element."""
        return element in self.ELEMENT_SKILLS
    
    def _get_target_weakness(self, target: Any | None) -> str | None:
        """Get target's elemental weakness."""
        if target is None:
            return None
        
        if not hasattr(target, "element"):
            return None
        
        return self.ELEMENT_COUNTERS.get(target.element)
    
    def _is_dangerous_target(self, target: Any) -> bool:
        """Check if target is particularly dangerous."""
        if hasattr(target, "is_boss") and target.is_boss:
            return True
        if hasattr(target, "is_mvp") and target.is_mvp:
            return True
        if hasattr(target, "is_aggressive") and target.is_aggressive:
            hp_percent = target.hp / max(target.hp_max, 1)
            if hp_percent > 0.8:
                return True
        return False
    
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
    
    def _select_utility_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select utility/CC skill."""
        for skill_name in self.UTILITY_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=5,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="ground",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_aoe_skill(
        self,
        context: CombatContextProtocol,
        target: Any | None
    ) -> Skill | None:
        """Select AoE skill."""
        for skill_name in self.AOE_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cast_time=self._get_cast_time(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="ground",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_elemental_skill(
        self,
        context: CombatContextProtocol,
        element: str
    ) -> Skill | None:
        """Select skill matching element."""
        skills = self.ELEMENT_SKILLS.get(element, [])
        
        for skill_name in skills:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cast_time=self._get_cast_time(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    element=element,
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_bolt_spell(
        self,
        context: CombatContextProtocol,
        conserve_sp: bool
    ) -> Skill | None:
        """Select default bolt spell."""
        # If conserving SP, prefer lower cost bolts
        bolt_order = self.SINGLE_TARGET_SKILLS if not conserve_sp else [
            "fire_bolt", "mg_firebolt",
            "cold_bolt", "mg_coldbolt",
            "lightning_bolt", "mg_lightningbolt",
        ]
        
        for skill_name in bolt_order:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10 if not conserve_sp else 5,
                    sp_cost=self._get_sp_cost(skill_name),
                    cast_time=self._get_cast_time(skill_name),
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
        target: TargetPriority
    ) -> int:
        """Count enemies in AoE range."""
        monster = self._find_monster_by_id(context, target.actor_id)
        if monster is None:
            return 0
        
        center = Position(x=monster.position[0], y=monster.position[1])
        return sum(
            1 for m in context.nearby_monsters
            if Position(x=m.position[0], y=m.position[1]).distance_to(center) <= 7
        )
    
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
    
    def _calculate_retreat_position(
        self,
        current: Position,
        threat: Position
    ) -> Position:
        """Calculate retreat position away from threat."""
        dx = current.x - threat.x
        dy = current.y - threat.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        move_distance = 5
        new_x = current.x + int(dx / distance * move_distance)
        new_y = current.y + int(dy / distance * move_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID from name."""
        skill_ids = {
            "fire_bolt": 19,
            "mg_firebolt": 19,
            "fire_ball": 17,
            "mg_fireball": 17,
            "fire_wall": 18,
            "mg_firewall": 18,
            "cold_bolt": 14,
            "mg_coldbolt": 14,
            "frost_diver": 15,
            "mg_frostdiver": 15,
            "lightning_bolt": 20,
            "mg_lightningbolt": 20,
            "thunder_storm": 21,
            "mg_thunderstorm": 21,
            "stone_curse": 16,
            "mg_stonecurse": 16,
            "sight": 10,
            "mg_sight": 10,
            "energy_coat": 287,
            "mg_energycoat": 287,
            "meteor_storm": 83,
            "wz_meteor": 83,
            "storm_gust": 89,
            "wz_stormgust": 89,
            "lord_of_vermilion": 85,
            "wz_vermilion": 85,
            "jupitel_thunder": 84,
            "wz_jupitel": 84,
            "earth_spike": 90,
            "wz_earthspike": 90,
            "heaven_drive": 91,
            "wz_heavendrive": 91,
            "quagmire": 92,
            "wz_quagmire": 92,
            "ice_wall": 82,
            "wz_icewall": 82,
            "fire_pillar": 80,
            "wz_firepillar": 80,
            "amplify_magic": 366,
            "hw_magicpower": 366,
        }
        return skill_ids.get(skill_name, 0)
    
    def _get_sp_cost(self, skill_name: str) -> int:
        """Get SP cost for skills."""
        costs = {
            "fire_bolt": 12,
            "cold_bolt": 12,
            "lightning_bolt": 12,
            "fire_ball": 25,
            "fire_wall": 40,
            "frost_diver": 25,
            "thunder_storm": 29,
            "stone_curse": 25,
            "meteor_storm": 64,
            "storm_gust": 78,
            "lord_of_vermilion": 72,
            "jupitel_thunder": 20,
            "earth_spike": 12,
            "heaven_drive": 28,
            "quagmire": 5,
            "energy_coat": 30,
            "amplify_magic": 40,
        }
        return costs.get(skill_name, 15)
    
    def _get_cast_time(self, skill_name: str) -> float:
        """Get cast time for skills."""
        cast_times = {
            "fire_bolt": 0.7,
            "cold_bolt": 0.7,
            "lightning_bolt": 0.7,
            "meteor_storm": 15.0,
            "storm_gust": 4.5,
            "lord_of_vermilion": 3.7,
            "jupitel_thunder": 2.0,
        }
        return cast_times.get(skill_name, 1.0)