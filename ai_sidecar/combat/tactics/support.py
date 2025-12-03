"""
Support Tactics Implementation.

Specialized combat behavior for support/healer role:
- Healing priority management
- Buff rotation and upkeep
- Party member protection
- Emergency response handling
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


class SupportTacticsConfig(TacticsConfig):
    """Support-specific configuration."""
    
    # Healing thresholds
    heal_trigger_threshold: float = 0.80  # Heal when ally below this
    emergency_heal_threshold: float = 0.35  # Emergency heal priority
    
    # Buff management
    maintain_buffs: bool = True
    buff_refresh_threshold: float = 10.0  # Refresh when < 10s remaining
    
    # Self preservation
    self_heal_priority: float = 0.75  # Self-heal when below this
    
    # Positioning
    safe_distance_from_combat: int = 5
    max_heal_range: int = 9
    
    # Optional flexibility for test compatibility
    aggro_maintain_level: float = 0.5
    emergency_threshold: float = 0.2


class SupportTactics(BaseTactics):
    """
    Support/Healer tactical behavior for Priests/High Priests.
    
    Priorities:
    1. Emergency healing (low HP allies)
    2. Maintain buffs on party
    3. Regular healing to keep party topped
    4. Debuff removal
    5. Self-preservation
    """
    
    role = TacticalRole.SUPPORT
    
    # Healing skills by priority
    EMERGENCY_HEALS = [
        "sanctuary", "pr_sanctuary",
        "heal", "al_heal",
        "highness_heal", "hlif_heal",
    ]
    
    REGULAR_HEALS = [
        "heal", "al_heal",
        "highness_heal", "hlif_heal",
    ]
    
    # Buff skills
    PARTY_BUFFS = [
        "blessing", "al_blessing",
        "increase_agi", "al_incagi",
        "angelus", "pr_angelus",
        "magnificat", "pr_magnificat",
        "gloria", "pr_gloria",
        "imposito_manus", "pr_impositio",
        "suffragium", "pr_suffragium",
    ]
    
    DEFENSIVE_BUFFS = [
        "kyrie_eleison", "pr_kyrie",
        "assumptio", "hp_assumptio",
        "safety_wall", "pr_safetywall",
    ]
    
    # Debuff removal
    DISPEL_SKILLS = [
        "cure", "al_cure",
        "status_recovery", "pr_strecovery",
    ]
    
    # Resurrection
    RESURRECT_SKILLS = [
        "resurrection", "pr_resurrection",
    ]
    
    # Offensive skills (for solo)
    OFFENSIVE_SKILLS = [
        "holy_light", "al_holylight",
        "turn_undead", "pr_turnundead",
        "magnus_exorcismus", "pr_magnus",
    ]
    
    def __init__(self, config: SupportTacticsConfig | None = None):
        """Initialize support tactics."""
        super().__init__(config or SupportTacticsConfig())
        self.support_config = config or SupportTacticsConfig()
        self._buff_timers: dict[str, dict[int, float]] = {}  # skill -> {target_id: remaining}
        self._heal_priority_queue: list[int] = []
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select support target (ally needing help).
        
        Priority:
        1. Dead allies (for resurrection)
        2. Critically low HP allies
        3. Low HP allies
        4. Debuffed allies
        5. Self if low
        6. Enemies (only for solo combat)
        """
        # Check party members for healing needs
        heal_target = self._find_healing_target(context)
        if heal_target:
            return heal_target
        
        # Check for buff needs
        buff_target = self._find_buff_target(context)
        if buff_target:
            return buff_target
        
        # If no party needs, check for enemies (solo mode)
        if context.nearby_monsters and not context.party_members:
            return self._find_offensive_target(context)
        
        return None
    
    async def select_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """
        Select optimal support skill.
        
        Priority:
        1. Emergency heal if target critical
        2. Defensive buff if target in danger
        3. Regular heal
        4. Party buffs
        5. Offensive (for solo)
        """
        # Self-healing check
        if self._needs_self_heal(context):
            return self._select_heal_skill(context, is_emergency=True)
        
        # Determine if this is a party target or enemy
        is_ally = self._is_ally_target(context, target.actor_id)
        
        if is_ally:
            # Check for emergency heal
            if target.hp_percent < self.support_config.emergency_heal_threshold:
                skill = self._select_emergency_heal(context)
                if skill:
                    return skill
            
            # Check for defensive buff (low HP but not critical)
            if target.hp_percent < self.support_config.heal_trigger_threshold:
                defensive = self._select_defensive_buff(context)
                if defensive:
                    return defensive
            
            # Regular heal
            heal = self._select_heal_skill(context, is_emergency=False)
            if heal:
                return heal
            
            # Party buff
            buff = self._select_party_buff(context, target.actor_id)
            if buff:
                return buff
        else:
            # Offensive skills for enemies
            return self._select_offensive_skill(context)
        
        return None
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine support positioning.
        
        Support should:
        - Stay safe distance from combat
        - Be within heal range of party
        - Not draw aggro
        """
        current = context.character_position
        
        # Find party center
        party_center = self._calculate_party_center(context)
        
        # No party - check for threats
        if party_center is None:
            if context.nearby_monsters:
                # Solo - stay away from enemies
                threat_center = self._calculate_threat_center(context)
                if threat_center:
                    return self._calculate_safe_position(current, threat_center)
            return None
        
        # Have party - position relative to party and threats
        threat_center = self._calculate_threat_center(context)
        
        if threat_center:
            return self._calculate_support_position(
                party_center, threat_center
            )
        
        # No threats - check if need to move toward party
        party_distance = current.distance_to(party_center)
        if party_distance > self.support_config.max_heal_range:
            # Move to get within heal range
            # Calculate exact distance needed to be within range
            needed_dist = int(party_distance - self.support_config.max_heal_range + 1)
            return self._move_toward(current, party_center, needed_dist)
        
        return None
    
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Assess threat for support.
        
        Support threat based on:
        - Own HP state
        - Party HP states
        - Enemies targeting support
        - SP level (can't heal without SP)
        """
        threat = 0.0
        
        # Self HP
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.25:
            threat += 0.4
        elif hp_percent < 0.50:
            threat += 0.2
        
        # SP threat (can't heal without SP)
        sp_percent = context.character_sp / max(context.character_sp_max, 1)
        if sp_percent < 0.15:
            threat += 0.3
        
        # Party HP emergencies
        emergency_count = sum(
            1 for p in context.party_members
            if self._get_ally_hp_percent(p) < self.support_config.emergency_heal_threshold
        )
        threat += min(0.3, emergency_count * 0.1)
        
        # Enemies close to support
        close_enemies = sum(
            1 for m in context.nearby_monsters
            if self.get_distance_to_target(context, m.position) < 3
        )
        threat += min(0.2, close_enemies * 0.1)
        
        return min(1.0, threat)
    
    # Support-specific helper methods
    
    def _find_healing_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Find ally most in need of healing."""
        targets = []
        
        # Check self first
        self_hp = context.character_hp / max(context.character_hp_max, 1)
        if self_hp < self.support_config.self_heal_priority:
            targets.append(TargetPriority(
                actor_id=0,  # Self
                priority_score=200 - (self_hp * 100),
                reason="self_heal",
                distance=0,
                hp_percent=self_hp
            ))
        
        # Check party members
        for member in context.party_members:
            hp_percent = self._get_ally_hp_percent(member)
            
            if hp_percent >= self.support_config.heal_trigger_threshold:
                continue
            
            # Calculate priority based on HP
            priority = 100 + (1 - hp_percent) * 100
            
            # Emergency bonus
            if hp_percent < self.support_config.emergency_heal_threshold:
                priority += 50
            
            distance = self._get_ally_distance(context, member)
            
            targets.append(TargetPriority(
                actor_id=self._get_ally_id(member),
                priority_score=priority,
                reason="heal_needed",
                distance=distance,
                hp_percent=hp_percent
            ))
        
        if not targets:
            return None
        
        # Return highest priority
        return max(targets, key=lambda t: t.priority_score)
    
    def _find_buff_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Find ally needing buffs."""
        # For simplicity, check if any party member needs buffs
        for member in context.party_members:
            member_id = self._get_ally_id(member)
            needs_buff = self._needs_buff(member_id)
            
            if needs_buff:
                hp_percent = self._get_ally_hp_percent(member)
                distance = self._get_ally_distance(context, member)
                
                return TargetPriority(
                    actor_id=member_id,
                    priority_score=50,
                    reason="buff_needed",
                    distance=distance,
                    hp_percent=hp_percent
                )
        
        return None
    
    def _find_offensive_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Find enemy target for solo combat."""
        if not context.nearby_monsters:
            return None
        
        targets = self.prioritize_targets(context, context.nearby_monsters)
        return targets[0] if targets else None
    
    def _is_ally_target(self, context: CombatContextProtocol, actor_id: int) -> bool:
        """Check if target is an ally."""
        if actor_id == 0:  # Self
            return True
        
        for member in context.party_members:
            if self._get_ally_id(member) == actor_id:
                return True
        
        return False
    
    def _needs_self_heal(self, context: CombatContextProtocol) -> bool:
        """Check if support needs to heal self."""
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        return hp_percent < self.support_config.emergency_heal_threshold
    
    def _select_emergency_heal(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select emergency healing skill."""
        for skill_name in self.EMERGENCY_HEALS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_heal_skill(
        self,
        context: CombatContextProtocol,
        is_emergency: bool
    ) -> Skill | None:
        """Select healing skill."""
        skills = self.EMERGENCY_HEALS if is_emergency else self.REGULAR_HEALS
        
        for skill_name in skills:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10 if is_emergency else 6,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_defensive_buff(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select defensive buff skill."""
        for skill_name in self.DEFENSIVE_BUFFS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_party_buff(
        self,
        context: CombatContextProtocol,
        target_id: int
    ) -> Skill | None:
        """Select party buff skill."""
        for skill_name in self.PARTY_BUFFS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=False
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_offensive_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select offensive skill for solo combat."""
        for skill_name in self.OFFENSIVE_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=True,
                    element="holy"
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _needs_buff(self, member_id: int) -> bool:
        """Check if party member needs buffs (simplified)."""
        # In production, check actual buff status
        return True
    
    def _get_ally_hp_percent(self, ally: Any) -> float:
        """Get ally HP percentage."""
        if hasattr(ally, "hp") and hasattr(ally, "hp_max"):
            return ally.hp / max(ally.hp_max, 1)
        return 1.0
    
    def _get_ally_id(self, ally: Any) -> int:
        """Get ally actor ID."""
        if hasattr(ally, "actor_id"):
            return ally.actor_id
        return 0
    
    def _get_ally_distance(self, context: CombatContextProtocol, ally: Any) -> float:
        """Get distance to ally."""
        if hasattr(ally, "position"):
            return self.get_distance_to_target(context, ally.position)
        return 0.0
    
    def _calculate_party_center(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate party center position."""
        members = [m for m in context.party_members if hasattr(m, "position")]
        if not members:
            return None
        
        # Handle both tuple and Position types
        sum_x = sum(m.position.x if hasattr(m.position, 'x') else m.position[0] for m in members)
        sum_y = sum(m.position.y if hasattr(m.position, 'y') else m.position[1] for m in members)
        count = len(members)
        
        return Position(x=sum_x // count, y=sum_y // count)
    
    def _calculate_threat_center(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate enemy center position."""
        if not context.nearby_monsters:
            return None
        
        # Handle both tuple and Position types
        sum_x = sum(m.position.x if hasattr(m.position, 'x') else m.position[0] for m in context.nearby_monsters)
        sum_y = sum(m.position.y if hasattr(m.position, 'y') else m.position[1] for m in context.nearby_monsters)
        count = len(context.nearby_monsters)
        
        return Position(x=sum_x // count, y=sum_y // count)
    
    def _calculate_safe_position(
        self,
        current: Position,
        threat: Position
    ) -> Position:
        """Calculate safe position away from threats."""
        dx = current.x - threat.x
        dy = current.y - threat.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        move_distance = self.support_config.safe_distance_from_combat
        new_x = current.x + int(dx / distance * move_distance)
        new_y = current.y + int(dy / distance * move_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _calculate_support_position(
        self,
        party_center: Position,
        threat_center: Position
    ) -> Position:
        """Calculate optimal support position (behind party)."""
        dx = party_center.x - threat_center.x
        dy = party_center.y - threat_center.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        # Position 3 cells behind party
        behind_distance = 3
        new_x = party_center.x + int(dx / distance * behind_distance)
        new_y = party_center.y + int(dy / distance * behind_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _move_toward(self, current: Position, target: Position, distance: int) -> Position:
        """Move toward a target position."""
        dx = target.x - current.x
        dy = target.y - current.y
        dist = ((dx * dx + dy * dy) ** 0.5) or 1
        
        new_x = current.x + int(dx / dist * distance)
        new_y = current.y + int(dy / dist * distance)
        
        return Position(x=new_x, y=new_y)
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID from name."""
        skill_ids = {
            "heal": 28,
            "al_heal": 28,
            "blessing": 34,
            "al_blessing": 34,
            "increase_agi": 29,
            "al_incagi": 29,
            "cure": 35,
            "al_cure": 35,
            "holy_light": 33,
            "al_holylight": 33,
            "angelus": 69,
            "pr_angelus": 69,
            "magnificat": 71,
            "pr_magnificat": 71,
            "gloria": 76,
            "pr_gloria": 76,
            "kyrie_eleison": 73,
            "pr_kyrie": 73,
            "sanctuary": 70,
            "pr_sanctuary": 70,
            "turn_undead": 77,
            "pr_turnundead": 77,
            "magnus_exorcismus": 79,
            "pr_magnus": 79,
            "resurrection": 78,
            "pr_resurrection": 78,
            "status_recovery": 74,
            "pr_strecovery": 74,
            "imposito_manus": 75,
            "pr_impositio": 75,
            "suffragium": 72,
            "pr_suffragium": 72,
            "safety_wall": 68,
            "pr_safetywall": 68,
            "assumptio": 361,
            "hp_assumptio": 361,
            "highness_heal": 475,
            "hlif_heal": 475,
        }
        return skill_ids.get(skill_name, 0)
    
    def _get_sp_cost(self, skill_name: str) -> int:
        """Get SP cost for skills."""
        costs = {
            "heal": 13,
            "blessing": 28,
            "increase_agi": 18,
            "cure": 15,
            "holy_light": 15,
            "angelus": 23,
            "magnificat": 40,
            "gloria": 20,
            "kyrie_eleison": 20,
            "sanctuary": 15,
            "turn_undead": 20,
            "magnus_exorcismus": 40,
            "resurrection": 60,
            "status_recovery": 5,
            "imposito_manus": 13,
            "suffragium": 8,
            "safety_wall": 30,
            "assumptio": 20,
        }
        return costs.get(skill_name, 15)