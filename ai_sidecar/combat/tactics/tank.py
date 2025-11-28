"""
Tank Tactics Implementation.

Specialized combat behavior for tanking role:
- Aggro management and threat generation
- Positioning between party and threats
- Provoke rotation and target switching
- Defensive skill prioritization
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


class TankTacticsConfig(TacticsConfig):
    """Tank-specific configuration."""
    
    # Tank positioning
    front_line_distance: int = 2
    
    # Aggro management
    aggro_check_interval: float = 1.0
    provoke_threshold: float = 0.8  # Provoke if ally threat > this
    
    # Defensive thresholds
    use_defender_hp: float = 0.60
    use_guard_hp: float = 0.40


class TankTactics(BaseTactics):
    """
    Tank tactical behavior for aggro management.
    
    Priorities:
    1. Generate and maintain threat on all enemies
    2. Position between party members and threats
    3. Use defensive skills when HP is low
    4. Provoke enemies targeting allies
    """
    
    role = TacticalRole.TANK
    
    # Tank skills by category
    PROVOKE_SKILLS = ["provoke", "sm_provoke"]
    DEFENSIVE_SKILLS = ["defender", "cr_defender", "guard", "cr_guard"]
    AGGRO_SKILLS = ["bash", "sm_bash", "magnum_break", "sm_magnum"]
    AOE_AGGRO_SKILLS = ["bowling_bash", "kn_bowlingbash", "magnum_break"]
    
    def __init__(self, config: TankTacticsConfig | None = None):
        """Initialize tank tactics."""
        super().__init__(config or TankTacticsConfig())
        self.tank_config = config or TankTacticsConfig()
        self._provoke_rotation: list[int] = []
        self._last_provoke_target: int | None = None
    
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select tank target based on threat management.
        
        Priority order:
        1. Enemies targeting party members (need provoke)
        2. Loose enemies (not targeting tank)
        3. Highest threat enemies
        4. Nearest enemies
        """
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        # Check for enemies targeting allies
        ally_targets = self._find_enemies_targeting_allies(context)
        if ally_targets:
            return ally_targets[0]
        
        # Check for loose enemies (not in threat table)
        loose_enemies = self._find_loose_enemies(context)
        if loose_enemies:
            return loose_enemies[0]
        
        # Default to highest threat
        return self._select_highest_threat_target(context)
    
    async def select_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """
        Select tank skill based on situation.
        
        Priority:
        1. Defensive skill if HP low
        2. Provoke if target on ally
        3. AoE aggro if multiple enemies
        4. Single target aggro skill
        """
        # Check if we need defensive skills first
        if self.is_low_hp(context):
            defensive = self._select_defensive_skill(context)
            if defensive:
                return defensive
        
        # Check if target needs to be provoked
        target_entry = self._threat_table.get(target.actor_id)
        needs_provoke = (
            target_entry is None or 
            not target_entry.is_targeting_self
        )
        
        if needs_provoke:
            provoke = self._select_provoke_skill(context)
            if provoke:
                return provoke
        
        # Check for AoE situation (3+ enemies nearby)
        if len(context.nearby_monsters) >= 3:
            aoe = self._select_aoe_skill(context)
            if aoe:
                return aoe
        
        # Single target aggro skill
        return self._select_aggro_skill(context)
    
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine tank positioning.
        
        Tank should be:
        - Between party members and enemies
        - Within melee range of primary target
        - Not surrounded (maintain escape route)
        """
        if not context.nearby_monsters:
            return None
        
        # Calculate threat centroid
        threat_center = self._calculate_threat_centroid(context)
        if threat_center is None:
            return None
        
        # Calculate party center (if party exists)
        party_center = self._calculate_party_centroid(context)
        
        if party_center:
            # Position between party and threats
            target_pos = self._calculate_interception_point(
                party_center, threat_center
            )
        else:
            # Solo - just stay near threats
            target_pos = Position(
                x=int(threat_center.x),
                y=int(threat_center.y)
            )
        
        # Only move if distance is significant
        current = context.character_position
        if current.distance_to(target_pos) < 2:
            return None
        
        return target_pos
    
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Assess threat level for tank.
        
        Considers:
        - Number of enemies
        - Loose aggro (enemies on allies)
        - HP state
        - Defensive cooldowns
        """
        threat = 0.0
        
        # Base threat from enemy count
        enemy_count = len(context.nearby_monsters)
        threat += min(0.3, enemy_count * 0.1)
        
        # Threat from loose aggro
        loose = len(self._find_loose_enemies(context))
        threat += loose * 0.15
        
        # HP-based threat
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        if hp_percent < 0.3:
            threat += 0.4
        elif hp_percent < 0.5:
            threat += 0.2
        
        # Check for enemies targeting allies
        ally_targets = self._find_enemies_targeting_allies(context)
        threat += len(ally_targets) * 0.1
        
        return min(1.0, threat)
    
    # Tank-specific helper methods
    
    def _find_enemies_targeting_allies(
        self,
        context: CombatContextProtocol
    ) -> list[TargetPriority]:
        """Find enemies that are targeting party members."""
        targeting_allies = []
        
        for monster in context.nearby_monsters:
            entry = self._threat_table.get(monster.actor_id)
            if entry and not entry.is_targeting_self:
                # This enemy is targeting someone else
                distance = self.get_distance_to_target(
                    context, monster.position
                )
                hp_percent = monster.hp / max(monster.hp_max, 1)
                
                targeting_allies.append(TargetPriority(
                    actor_id=monster.actor_id,
                    priority_score=150 - distance,  # Very high priority
                    reason="targeting_ally",
                    distance=distance,
                    hp_percent=hp_percent
                ))
        
        return sorted(
            targeting_allies, 
            key=lambda t: t.priority_score, 
            reverse=True
        )
    
    def _find_loose_enemies(
        self,
        context: CombatContextProtocol
    ) -> list[TargetPriority]:
        """Find enemies not in threat table (loose aggro)."""
        loose = []
        
        for monster in context.nearby_monsters:
            if monster.actor_id not in self._threat_table:
                distance = self.get_distance_to_target(
                    context, monster.position
                )
                hp_percent = monster.hp / max(monster.hp_max, 1)
                
                loose.append(TargetPriority(
                    actor_id=monster.actor_id,
                    priority_score=120 - distance,
                    reason="loose_enemy",
                    distance=distance,
                    hp_percent=hp_percent
                ))
        
        return sorted(loose, key=lambda t: t.priority_score, reverse=True)
    
    def _select_highest_threat_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """Select target with highest threat value."""
        if not context.nearby_monsters:
            return None
        
        best_target = None
        best_score = -1.0
        
        for monster in context.nearby_monsters:
            threat = self.get_threat_for_actor(monster.actor_id)
            distance = self.get_distance_to_target(
                context, monster.position
            )
            hp_percent = monster.hp / max(monster.hp_max, 1)
            
            # Score combines threat and proximity
            score = threat + (20 - min(20, distance))
            
            if score > best_score:
                best_score = score
                best_target = TargetPriority(
                    actor_id=monster.actor_id,
                    priority_score=score,
                    reason="highest_threat",
                    distance=distance,
                    hp_percent=hp_percent
                )
        
        return best_target
    
    def _select_defensive_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select appropriate defensive skill."""
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        
        for skill_name in self.DEFENSIVE_SKILLS:
            if skill_name not in context.cooldowns:
                continue
            
            # Check skill applicability by HP threshold
            if skill_name in ["guard", "cr_guard"]:
                if hp_percent > self.tank_config.use_guard_hp:
                    continue
            elif skill_name in ["defender", "cr_defender"]:
                if hp_percent > self.tank_config.use_defender_hp:
                    continue
            
            if context.cooldowns.get(skill_name, 0) <= 0:
                return Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=1,
                    sp_cost=30,
                    cooldown=0,
                    range=0,
                    target_type="self",
                    is_offensive=False
                )
        
        return None
    
    def _select_provoke_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select provoke skill if available."""
        for skill_name in self.PROVOKE_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                return Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=4,
                    cooldown=0,
                    range=9,
                    target_type="single",
                    is_offensive=False
                )
        
        return None
    
    def _select_aoe_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select AoE aggro generation skill."""
        for skill_name in self.AOE_AGGRO_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                return Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=30,
                    cooldown=2.0,
                    range=2,
                    target_type="ground",
                    is_offensive=True
                )
        
        return None
    
    def _select_aggro_skill(
        self,
        context: CombatContextProtocol
    ) -> Skill | None:
        """Select single-target aggro skill."""
        for skill_name in self.AGGRO_SKILLS:
            if context.cooldowns.get(skill_name, 0) <= 0:
                return Skill(
                    id=self._get_skill_id(skill_name),
                    name=skill_name,
                    level=10,
                    sp_cost=15,
                    cooldown=0,
                    range=1,
                    target_type="single",
                    is_offensive=True
                )
        
        return None
    
    def _calculate_threat_centroid(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate center position of nearby threats."""
        monsters = context.nearby_monsters
        if not monsters:
            return None
        
        sum_x = sum(m.position[0] for m in monsters)
        sum_y = sum(m.position[1] for m in monsters)
        count = len(monsters)
        
        return Position(x=sum_x // count, y=sum_y // count)
    
    def _calculate_party_centroid(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """Calculate center position of party members."""
        party = context.party_members
        if not party:
            return None
        
        sum_x = sum(p.position[0] for p in party if hasattr(p, "position"))
        sum_y = sum(p.position[1] for p in party if hasattr(p, "position"))
        count = len([p for p in party if hasattr(p, "position")])
        
        if count == 0:
            return None
        
        return Position(x=sum_x // count, y=sum_y // count)
    
    def _calculate_interception_point(
        self,
        party_center: Position,
        threat_center: Position
    ) -> Position:
        """Calculate position between party and threats."""
        # Position should be 2-3 cells in front of party, toward threats
        dx = threat_center.x - party_center.x
        dy = threat_center.y - party_center.y
        
        distance = ((dx * dx + dy * dy) ** 0.5) or 1
        
        # Move 3 cells from party toward threats
        intercept_distance = min(3, distance / 2)
        
        new_x = party_center.x + int(dx / distance * intercept_distance)
        new_y = party_center.y + int(dy / distance * intercept_distance)
        
        return Position(x=new_x, y=new_y)
    
    def _get_skill_id(self, skill_name: str) -> int:
        """Get skill ID from name (simplified mapping)."""
        skill_ids = {
            "provoke": 6,
            "sm_provoke": 6,
            "bash": 5,
            "sm_bash": 5,
            "magnum_break": 7,
            "sm_magnum": 7,
            "defender": 205,
            "cr_defender": 205,
            "guard": 204,
            "cr_guard": 204,
            "bowling_bash": 62,
            "kn_bowlingbash": 62,
        }
        return skill_ids.get(skill_name, 0)