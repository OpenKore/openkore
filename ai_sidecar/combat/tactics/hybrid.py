"""
Hybrid Tactics Implementation.

Adaptive tactical behavior for versatile classes:
- Dynamic role switching based on situation
- Multi-role skill usage
- Party composition awareness
- Flexible engagement strategies

Suitable for classes like Crusader/Paladin, Sage/Scholar, Bard/Dancer.
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


class HybridTacticsConfig(TacticsConfig):
    """Hybrid-specific configuration."""
    
    # Role thresholds
    tank_mode_party_threshold: int = 2  # Min party size to consider tanking
    support_mode_threshold: float = 0.60  # Party HP below this triggers support
    
    # Adaptive settings
    auto_switch_roles: bool = True
    preferred_role: str = "dps"  # dps, tank, support
    
    # Engagement flexibility
    melee_range: int = 2
    ranged_range: int = 9


class ActiveRole:
    """Tracks currently active role state."""
    
    def __init__(self, role: str = "dps"):
        self.current_role = role
        self.role_duration: float = 0.0
        self.switch_cooldown: float = 0.0


class HybridTactics(BaseTactics):
    """
    Hybrid tactical behavior with adaptive role switching.
    
    Priorities vary by active role:
    - Tank Mode: Aggro, positioning, survival
    - DPS Mode: Damage, target priority
    - Support Mode: Healing, buffing, party protection
    
    Automatically switches roles based on party composition
    and combat situation.
    """
    
    role = TacticalRole.HYBRID
    
    # Tank skills
    TANK_SKILLS = [
        "grand_cross", "cr_grandcross",
        "shield_charge", "cr_shieldcharge",
        "shield_boomerang", "cr_shieldboomerang",
        "devotion", "cr_devotion",
        "defender", "cr_defender",
        "providence", "cr_providence",
    ]
    
    # DPS skills
    DPS_SKILLS = [
        "holy_cross", "cr_holycross",
        "grand_cross", "cr_grandcross",
        "bash", "sm_bash",
        "magnum_break", "sm_magnum",
        "shield_boomerang", "cr_shieldboomerang",
    ]
    
    # Support skills
    SUPPORT_SKILLS = [
        "heal", "al_heal",
        "devotion", "cr_devotion",
        "gospel", "pa_gospel",
        "pressure", "pa_pressure",
        "battle_chant", "pa_sacrifice",
    ]
    
    # Buff skills
    BUFF_SKILLS = [
        "auto_guard", "cr_autoguard",
        "reflect_shield", "cr_reflectshield",
        "defender", "cr_defender",
        "providence", "cr_providence",
    ]
    
    def __init__(self, config: HybridTacticsConfig | None = None):
        """Initialize hybrid tactics."""
        super().__init__(config or HybridTacticsConfig())
        self.hybrid_config = config or HybridTacticsConfig()
        self._active_role = ActiveRole(self.hybrid_config.preferred_role)
        self._role_switch_timer: float = 0.0
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select target based on active role.
        
        Automatically evaluates and switches roles if needed.
        """
        # Evaluate and potentially switch role
        if self.hybrid_config.auto_switch_roles:
            self._evaluate_role_switch(context)
        
        if self._active_role.current_role == "tank":
            return self._select_tank_target(context)
        elif self._active_role.current_role == "support":
            return self._select_support_target(context)
        else:
            return self._select_dps_target(context)
    
    async def select_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """
        Select skill based on active role.
        """
        # Always check for emergency self-heal
        if self._needs_emergency_heal(context):
            heal = self._select_heal_skill(context)
            if heal:
                return heal
        
        # Role-specific skill selection
        if self._active_role.current_role == "tank":
            return self._select_tank_skill(context, target)
        elif self._active_role.current_role == "support":
            return self._select_support_skill(context, target)
        else:
            return self._select_dps_skill(context, target)
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine positioning based on active role.
        """
        if self._active_role.current_role == "tank":
            return self._evaluate_tank_positioning(context)
        elif self._active_role.current_role == "support":
            return self._evaluate_support_positioning(context)
        else:
            return self._evaluate_dps_positioning(context)
    
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Assess threat considering hybrid role.
        
        Hybrids have moderate survivability - not as tanky
        as pure tanks but tougher than pure DPS.
        """
        threat = 0.0
        
        # HP-based threat
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.30:
            threat += 0.4
        elif hp_percent < 0.50:
            threat += 0.2
        
        # Enemy proximity
        close_enemies = sum(
            1 for m in context.nearby_monsters
            if self.get_distance_to_target(context, m.position) < 3
        )
        
        # Tank mode has higher tolerance for close enemies
        if self._active_role.current_role == "tank":
            threat += min(0.2, close_enemies * 0.05)
        else:
            threat += min(0.3, close_enemies * 0.1)
        
        # Party emergency check
        for member in context.party_members:
            if self._get_ally_hp_percent(member) < 0.3:
                threat += 0.1
        
        return min(1.0, threat)
    
    # Role switching logic
    
    def _evaluate_role_switch(self, context: CombatContextProtocol) -> None:
        """Evaluate if role switch is needed."""
        if self._role_switch_timer > 0:
            return  # On cooldown
        
        new_role = self._determine_optimal_role(context)
        
        if new_role != self._active_role.current_role:
            logger.info(
                f"Hybrid switching role: "
                f"{self._active_role.current_role} -> {new_role}"
            )
            self._active_role.current_role = new_role
            self._active_role.role_duration = 0.0
            self._role_switch_timer = 5.0  # 5 second cooldown
    
    def _determine_optimal_role(
        self,
        context: CombatContextProtocol
    ) -> str:
        """Determine optimal role based on situation."""
        party_size = len(context.party_members)
        
        # Check if support is needed
        if self._party_needs_support(context):
            return "support"
        
        # Check if tank is needed
        if self._party_needs_tank(context):
            return "tank"
        
        # Default to preferred role
        return self.hybrid_config.preferred_role
    
    def _party_needs_support(self, context: CombatContextProtocol) -> bool:
        """Check if party desperately needs support."""
        if not context.party_members:
            return False
        
        low_hp_count = sum(
            1 for m in context.party_members
            if self._get_ally_hp_percent(m) < self.hybrid_config.support_mode_threshold
        )
        
        # Switch to support if multiple allies are low
        return low_hp_count >= 2
    
    def _party_needs_tank(self, context: CombatContextProtocol) -> bool:
        """Check if party needs a tank."""
        party_size = len(context.party_members)
        
        if party_size < self.hybrid_config.tank_mode_party_threshold:
            return False
        
        # Check if there's already a tank in party
        # (simplified - would check actual party composition)
        
        # Check if multiple enemies are targeting party
        enemy_count = len(context.nearby_monsters)
        return enemy_count >= 3
    
    # Role-specific target selection
    
    def _select_tank_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Tank target selection - prioritize aggro management."""
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        # Find enemies targeting allies
        for monster in monsters:
            entry = self._threat_table.get(monster.actor_id)
            if entry and not entry.is_targeting_self:
                distance = self.get_distance_to_target(context, monster.position)
                hp_percent = monster.hp / max(monster.hp_max, 1)
                return TargetPriority(
                    actor_id=monster.actor_id,
                    priority_score=150,
                    reason="ally_target",
                    distance=distance,
                    hp_percent=hp_percent
                )
        
        # Default to nearest
        return self.prioritize_targets(context, monsters)[0] if monsters else None
    
    def _select_support_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Support target selection - prioritize low HP allies."""
        # Find ally most in need
        best_target = None
        lowest_hp = 1.0
        
        for member in context.party_members:
            hp_percent = self._get_ally_hp_percent(member)
            if hp_percent < lowest_hp:
                lowest_hp = hp_percent
                distance = self._get_ally_distance(context, member)
                best_target = TargetPriority(
                    actor_id=self._get_ally_id(member),
                    priority_score=100 + (1 - hp_percent) * 100,
                    reason="heal_target",
                    distance=distance,
                    hp_percent=hp_percent
                )
        
        if best_target and lowest_hp < 0.8:
            return best_target
        
        # If no healing needed, target enemies
        return self._select_dps_target(context)
    
    def _select_dps_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """DPS target selection - prioritize low HP enemies."""
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        return self.prioritize_targets(context, monsters)[0]
    
    # Role-specific skill selection
    
    def _select_tank_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """Select tank-oriented skill."""
        # Check for buff upkeep
        buff = self._select_buff_skill(context)
        if buff:
            return buff
        
        # Tank skills
        for skill_name in self.TANK_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=self._get_skill_range(skill_name),
                    target_type="single",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_support_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """Select support-oriented skill."""
        # Healing if target is ally
        if target.hp_percent < 0.8:
            heal = self._select_heal_skill(context)
            if heal:
                return heal
        
        # Support skills
        for skill_name in self.SUPPORT_SKILLS:
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
    
    def _select_dps_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """Select DPS-oriented skill."""
        for skill_name in self.DPS_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                skill = Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=self._get_sp_cost(skill_name),
                    cooldown=0,
                    range=self._get_skill_range(skill_name),
                    target_type="single",
                    is_offensive=True
                )
                if self.can_use_skill(skill, context):
                    return skill
        
        return None
    
    def _select_buff_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select buff skill."""
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
    
    def _select_heal_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select healing skill."""
        if context.cooldowns.get("heal", 0) <= 0:
            skill = Skill(
                id=28,  # Heal
                name="heal",
                level=10,
                sp_cost=15,
                cooldown=0,
                range=9,
                target_type="single",
                is_offensive=False
            )
            if self.can_use_skill(skill, context):
                return skill
        
        return None
    
    def _needs_emergency_heal(self, context: CombatContextProtocol) -> bool:
        """Check if emergency self-heal is needed."""
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        return hp_percent < 0.30
    
    # Role-specific positioning
    
    def _evaluate_tank_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Tank positioning - front line."""
        if not context.nearby_monsters:
            return None
        
        # Position between party and enemies
        party_center = self._calculate_party_center(context)
        threat_center = self._calculate_threat_center(context)
        
        if party_center and threat_center:
            return self._calculate_intercept_position(party_center, threat_center)
        
        return None
    
    def _evaluate_support_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Support positioning - behind party."""
        party_center = self._calculate_party_center(context)
        threat_center = self._calculate_threat_center(context)
        
        if party_center and threat_center:
            return self._calculate_safe_position(party_center, threat_center)
        
        return None
    
    def _evaluate_dps_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """DPS positioning - near target."""
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        # Move toward nearest target
        nearest = min(
            monsters,
            key=lambda m: self.get_distance_to_target(context, m.position)
        )
        
        distance = self.get_distance_to_target(context, nearest.position)
        if distance > self.hybrid_config.melee_range:
            current = context.character_position
            target = Position(x=nearest.position[0], y=nearest.position[1])
            return self._move_toward(current, target, 2)
        
        return None
    
    # Helper methods
    
    def _get_ally_hp_percent(self, ally: Any) -> float:
        """Get ally HP percentage."""
        if hasattr(ally, "hp") and hasattr(ally, "hp_max"):
            return ally.hp / max(ally.hp_max, 1)
        return 1.0
    
    def _get_ally_id(self, ally: Any) -> int:
        """Get ally ID."""
        return getattr(ally, "actor_id", 0)
    
    def _get_ally_distance(self, context: CombatContextProtocol, ally: Any) -> float:
        """Get distance to ally."""
        if hasattr(ally, "position"):
            return self.get_distance_to_target(context, ally.position)
        return 0.0
    
    def _calculate_party_center(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate party center."""
        members = [m for m in context.party_members if hasattr(m, "position")]
        if not members:
            return None
        
        sum_x = sum(m.position[0] for m in members)
        sum_y = sum(m.position[1] for m in members)
        return Position(x=sum_x // len(members), y=sum_y // len(members))
    
    def _calculate_threat_center(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate enemy center."""
        if not context.nearby_monsters:
            return None
        
        sum_x = sum(m.position[0] for m in context.nearby_monsters)
        sum_y = sum(m.position[1] for m in context.nearby_monsters)
        count = len(context.nearby_monsters)
        return Position(x=sum_x // count, y=sum_y // count)
    
    def _calculate_intercept_position(
        self,
        party: Position,
        threat: Position
    ) -> Position:
        """Calculate position between party and threats."""
        dx = threat.x - party.x
        dy = threat.y - party.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        intercept_dist = 2
        new_x = party.x + int(dx / distance * intercept_dist)
        new_y = party.y + int(dy / distance * intercept_dist)
        
        return Position(x=new_x, y=new_y)
    
    def _calculate_safe_position(
        self,
        party: Position,
        threat: Position
    ) -> Position:
        """Calculate position behind party."""
        dx = party.x - threat.x
        dy = party.y - threat.y
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        safe_dist = 3
        new_x = party.x + int(dx / distance * safe_dist)
        new_y = party.y + int(dy / distance * safe_dist)
        
        return Position(x=new_x, y=new_y)
    
    def _move_toward(
        self,
        current: Position,
        target: Position,
        distance: int
    ) -> Position:
        """Move toward target."""
        dx = target.x - current.x
        dy = target.y - current.y
        dist = ((dx * dx + dy * dy) ** 0.5) or 1
        
        new_x = current.x + int(dx / dist * distance)
        new_y = current.y + int(dy / dist * distance)
        
        return Position(x=new_x, y=new_y)
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID."""
        skill_ids = {
            "grand_cross": 254,
            "cr_grandcross": 254,
            "holy_cross": 253,
            "cr_holycross": 253,
            "shield_charge": 249,
            "cr_shieldcharge": 249,
            "shield_boomerang": 250,
            "cr_shieldboomerang": 250,
            "devotion": 251,
            "cr_devotion": 251,
            "defender": 252,
            "cr_defender": 252,
            "providence": 248,
            "cr_providence": 248,
            "auto_guard": 249,
            "cr_autoguard": 249,
            "reflect_shield": 252,
            "cr_reflectshield": 252,
            "heal": 28,
            "al_heal": 28,
            "gospel": 369,
            "pa_gospel": 369,
            "bash": 5,
            "sm_bash": 5,
            "magnum_break": 7,
            "sm_magnum": 7,
        }
        return skill_ids.get(skill_name, 0)
    
    def _get_sp_cost(self, skill_name: str) -> int:
        """Get SP cost."""
        costs = {
            "grand_cross": 37,
            "holy_cross": 11,
            "shield_charge": 10,
            "shield_boomerang": 12,
            "devotion": 25,
            "defender": 30,
            "providence": 30,
            "auto_guard": 30,
            "heal": 15,
            "gospel": 80,
            "bash": 15,
            "magnum_break": 30,
        }
        return costs.get(skill_name, 20)
    
    def _get_skill_range(self, skill_name: str) -> int:
        """Get skill range."""
        ranges = {
            "grand_cross": 3,
            "holy_cross": 2,
            "shield_charge": 3,
            "shield_boomerang": 9,
            "devotion": 7,
            "bash": 1,
            "magnum_break": 2,
        }
        return ranges.get(skill_name, 1)