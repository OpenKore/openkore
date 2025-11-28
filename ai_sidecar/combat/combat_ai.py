"""
Combat AI Engine.

Core combat decision system that evaluates situations and selects
optimal actions based on tactical role and current context.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from ai_sidecar.combat.models import (
    Buff,
    CombatAction,
    CombatActionType,
    CombatContext,
    Debuff,
    MonsterActor,
    PlayerActor,
)
from ai_sidecar.combat.tactics import (
    BaseTactics,
    HybridTactics,
    MagicDPSTactics,
    MeleeDPSTactics,
    Position,
    RangedDPSTactics,
    Skill,
    SupportTactics,
    TacticalRole,
    TacticsConfig,
    TankTactics,
    TargetPriority,
    create_tactics,
    get_default_role_for_job,
)

if TYPE_CHECKING:
    from ai_sidecar.core.state import CharacterState, GameState


class CombatState(str, Enum):
    """Current combat state machine state."""
    
    IDLE = "idle"
    ENGAGING = "engaging"
    IN_COMBAT = "in_combat"
    RETREATING = "retreating"
    EMERGENCY = "emergency"


@dataclass
class CombatMetrics:
    """Performance metrics for combat AI."""
    
    decisions_made: int = 0
    average_decision_time_ms: float = 0.0
    targets_selected: int = 0
    skills_used: int = 0
    retreats_triggered: int = 0
    emergency_actions: int = 0
    _decision_times: list[float] = field(default_factory=list)
    
    def record_decision_time(self, duration_ms: float) -> None:
        """Record a decision time and update average."""
        self._decision_times.append(duration_ms)
        # Keep only last 100 for rolling average
        if len(self._decision_times) > 100:
            self._decision_times.pop(0)
        self.average_decision_time_ms = sum(self._decision_times) / len(self._decision_times)
        self.decisions_made += 1


class CombatAIConfig(BaseModel):
    """Configuration for CombatAI."""
    
    model_config = {"frozen": True}
    
    # Performance settings
    max_decision_time_ms: float = Field(default=50.0, description="Maximum decision time")
    enable_performance_tracking: bool = Field(default=True)
    
    # Combat thresholds
    emergency_hp_threshold: float = Field(default=0.20, ge=0.0, le=1.0)
    retreat_hp_threshold: float = Field(default=0.35, ge=0.0, le=1.0)
    engage_threat_threshold: float = Field(default=0.7, ge=0.0, le=1.0)
    
    # Aggro settings
    auto_engage_aggressive: bool = Field(default=True)
    max_simultaneous_targets: int = Field(default=3, ge=1)
    
    # Safety settings
    avoid_mvp_solo: bool = Field(default=True)
    avoid_boss_solo: bool = Field(default=True)
    flee_from_players_in_pvp: bool = Field(default=False)


class CombatAI:
    """
    Role-optimized tactical AI for combat situations.
    
    Coordinates tactics, evaluates combat situations, and produces
    optimal combat actions within time constraints.
    """
    
    # Maps TacticalRole to tactics classes
    TACTICAL_ROLES: dict[TacticalRole, type[BaseTactics]] = {
        TacticalRole.TANK: TankTactics,
        TacticalRole.MELEE_DPS: MeleeDPSTactics,
        TacticalRole.RANGED_DPS: RangedDPSTactics,
        TacticalRole.MAGIC_DPS: MagicDPSTactics,
        TacticalRole.SUPPORT: SupportTactics,
        TacticalRole.HYBRID: HybridTactics,
    }
    
    def __init__(
        self,
        config: CombatAIConfig | None = None,
        tactics_config: TacticsConfig | None = None,
    ):
        """
        Initialize CombatAI.
        
        Args:
            config: CombatAI configuration
            tactics_config: Configuration for tactics instances
        """
        self.config = config or CombatAIConfig()
        self.tactics_config = tactics_config
        
        # Initialize tactics instances (lazy loaded per role)
        self._tactics_cache: dict[TacticalRole, BaseTactics] = {}
        
        # Combat state
        self._current_state = CombatState.IDLE
        self._current_role: TacticalRole | None = None
        self._current_target_id: int | None = None
        self._last_action_tick: int = 0
        
        # Metrics
        self.metrics = CombatMetrics()
    
    def get_tactics(self, role: TacticalRole) -> BaseTactics:
        """Get or create tactics instance for role."""
        if role not in self._tactics_cache:
            self._tactics_cache[role] = create_tactics(role, self.tactics_config)
        return self._tactics_cache[role]
    
    def set_role(self, role: TacticalRole | str) -> None:
        """Set the active tactical role."""
        if isinstance(role, str):
            role = TacticalRole(role.lower())
        self._current_role = role
    
    async def evaluate_combat_situation(
        self,
        game_state: "GameState",
    ) -> CombatContext:
        """
        Analyze current combat environment.
        
        Creates a comprehensive snapshot of the combat situation
        including nearby enemies, party status, and threat assessment.
        
        Args:
            game_state: Current game state
        
        Returns:
            CombatContext with full situation analysis
        """
        character = game_state.character
        
        # Get nearby actors from game state
        nearby_monsters = self._extract_nearby_monsters(game_state)
        nearby_players = self._extract_nearby_players(game_state)
        party_members = self._extract_party_members(game_state)
        
        # Extract buff/debuff status
        active_buffs = self._extract_buffs(character)
        active_debuffs = self._extract_debuffs(character)
        
        # Get cooldown tracking (from character or game state)
        cooldowns = self._extract_cooldowns(game_state)
        
        # Assess threat level
        threat_level = self._calculate_threat_level(
            character, nearby_monsters, nearby_players, game_state
        )
        
        # Detect PvP/WoE modes
        in_pvp = self._is_in_pvp(game_state)
        in_woe = self._is_in_woe(game_state)
        
        # Build danger zones (from map data)
        danger_zones = self._extract_danger_zones(game_state)
        
        return CombatContext(
            character=character,
            nearby_monsters=nearby_monsters,
            nearby_players=nearby_players,
            party_members=party_members,
            active_buffs=active_buffs,
            active_debuffs=active_debuffs,
            cooldowns=cooldowns,
            threat_level=threat_level,
            in_pvp=in_pvp,
            in_woe=in_woe,
            map_danger_zones=danger_zones,
        )
    
    async def select_target(
        self,
        context: CombatContext,
    ) -> MonsterActor | PlayerActor | None:
        """
        Select optimal target based on role and priorities.
        
        Args:
            context: Current combat context
        
        Returns:
            Selected target actor or None
        """
        if self._current_role is None:
            self._current_role = get_default_role_for_job(context.character.job)
        
        tactics = self.get_tactics(self._current_role)
        
        # Get target priority from tactics
        target_priority = await tactics.select_target(context)
        if target_priority is None:
            return None
        
        # Find the actual actor
        target = self._find_actor_by_id(
            target_priority.target_id,
            context.nearby_monsters,
            context.nearby_players,
        )
        
        if target is not None:
            self._current_target_id = target_priority.target_id
            self.metrics.targets_selected += 1
        
        return target
    
    async def select_action(
        self,
        context: CombatContext,
        target: MonsterActor | PlayerActor | None = None,
    ) -> CombatAction | None:
        """
        Choose optimal combat action.
        
        Args:
            context: Current combat context
            target: Optional pre-selected target
        
        Returns:
            CombatAction to execute or None
        """
        start_time = time.perf_counter()
        
        try:
            # Check emergency conditions first
            if self._is_emergency(context):
                self._current_state = CombatState.EMERGENCY
                return await self._create_emergency_action(context)
            
            # Check retreat conditions
            if self._should_retreat(context):
                self._current_state = CombatState.RETREATING
                return await self._create_retreat_action(context)
            
            # No target means idle or searching
            if target is None:
                self._current_state = CombatState.IDLE
                return None
            
            # Update state based on engagement
            self._current_state = CombatState.IN_COMBAT
            
            if self._current_role is None:
                self._current_role = get_default_role_for_job(context.character.job)
            
            tactics = self.get_tactics(self._current_role)
            
            # Create target priority for tactics
            target_priority = TargetPriority(
                target_id=target.actor_id,
                priority=1.0,
                reason="pre-selected target",
                is_monster=isinstance(target, MonsterActor),
            )
            
            # Get skill from tactics
            skill = await tactics.select_skill(context, target_priority)
            
            if skill is not None:
                self.metrics.skills_used += 1
                return CombatAction(
                    action_type=CombatActionType.SKILL,
                    skill_id=skill.skill_id,
                    target_id=target.actor_id,
                    priority=8,
                    reason=f"Tactics: {skill.skill_name}",
                )
            
            # Check positioning
            position = await tactics.evaluate_positioning(context)
            if position is not None:
                return CombatAction(
                    action_type=CombatActionType.MOVE,
                    position=(position.x, position.y),
                    priority=5,
                    reason="tactical repositioning",
                )
            
            # Default to basic attack
            return CombatAction(
                action_type=CombatActionType.ATTACK,
                target_id=target.actor_id,
                priority=6,
                reason="basic attack",
            )
            
        finally:
            # Track decision time
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            if self.config.enable_performance_tracking:
                self.metrics.record_decision_time(elapsed_ms)
    
    async def decide(
        self,
        context: CombatContext,
    ) -> list[CombatAction]:
        """
        Main decision method - produces all combat actions for this tick.
        
        Args:
            context: Current combat context
        
        Returns:
            List of combat actions to execute
        """
        actions: list[CombatAction] = []
        
        # Priority 1: Emergency actions
        if self._is_emergency(context):
            emergency = await self._create_emergency_action(context)
            if emergency:
                self.metrics.emergency_actions += 1
                return [emergency]
        
        # Priority 2: Pre-combat buffs
        buff_action = await self._check_prebattle_buffs(context)
        if buff_action:
            actions.append(buff_action)
        
        # Priority 3: Select and engage target
        target = await self.select_target(context)
        if target:
            action = await self.select_action(context, target)
            if action:
                actions.append(action)
        
        return actions
    
    # =========================================================================
    # Private helper methods
    # =========================================================================
    
    def _extract_nearby_monsters(self, game_state: "GameState") -> list[MonsterActor]:
        """Extract monster actors from game state."""
        monsters = []
        
        # Check if game_state has actors/monsters attribute
        if hasattr(game_state, "actors"):
            for actor in game_state.actors:
                if hasattr(actor, "mob_id") and actor.mob_id:
                    monsters.append(MonsterActor(
                        actor_id=actor.actor_id if hasattr(actor, "actor_id") else actor.id,
                        name=getattr(actor, "name", "Unknown"),
                        mob_id=actor.mob_id,
                        hp=getattr(actor, "hp", 100),
                        hp_max=getattr(actor, "hp_max", 100),
                        element=getattr(actor, "element", "neutral"),
                        race=getattr(actor, "race", "formless"),
                        size=getattr(actor, "size", "medium"),
                        position=getattr(actor, "position", (0, 0)),
                        is_aggressive=getattr(actor, "is_aggressive", False),
                        is_boss=getattr(actor, "is_boss", False),
                        is_mvp=getattr(actor, "is_mvp", False),
                        attack_range=getattr(actor, "attack_range", 1),
                        skills=getattr(actor, "skills", []),
                    ))
        
        return monsters
    
    def _extract_nearby_players(self, game_state: "GameState") -> list[PlayerActor]:
        """Extract player actors from game state."""
        players = []
        
        if hasattr(game_state, "players"):
            for player in game_state.players:
                players.append(PlayerActor(
                    actor_id=getattr(player, "actor_id", player.id if hasattr(player, "id") else 0),
                    name=getattr(player, "name", "Unknown"),
                    job_class=getattr(player, "job_class", "novice"),
                    guild_name=getattr(player, "guild_name", None),
                    position=getattr(player, "position", (0, 0)),
                    is_enemy=getattr(player, "is_enemy", False),
                    hp_percent=getattr(player, "hp_percent", 1.0),
                ))
        
        return players
    
    def _extract_party_members(self, game_state: "GameState") -> list["CharacterState"]:
        """Extract party member states from game state."""
        if hasattr(game_state, "party_members"):
            return list(game_state.party_members)
        return []
    
    def _extract_buffs(self, character: "CharacterState") -> list[Buff]:
        """Extract active buffs from character state."""
        buffs = []
        
        if hasattr(character, "buffs"):
            for buff_data in character.buffs:
                if isinstance(buff_data, Buff):
                    buffs.append(buff_data)
                elif isinstance(buff_data, dict):
                    buffs.append(Buff(**buff_data))
        
        return buffs
    
    def _extract_debuffs(self, character: "CharacterState") -> list[Debuff]:
        """Extract active debuffs from character state."""
        debuffs = []
        
        if hasattr(character, "debuffs"):
            for debuff_data in character.debuffs:
                if isinstance(debuff_data, Debuff):
                    debuffs.append(debuff_data)
                elif isinstance(debuff_data, dict):
                    debuffs.append(Debuff(**debuff_data))
        
        return debuffs
    
    def _extract_cooldowns(self, game_state: "GameState") -> dict[str, float]:
        """Extract skill cooldowns."""
        if hasattr(game_state, "cooldowns"):
            return dict(game_state.cooldowns)
        if hasattr(game_state.character, "cooldowns"):
            return dict(game_state.character.cooldowns)
        return {}
    
    def _calculate_threat_level(
        self,
        character: "CharacterState",
        monsters: list[MonsterActor],
        players: list[PlayerActor],
        game_state: "GameState",
    ) -> float:
        """
        Calculate overall threat level (0.0 to 1.0).
        
        Factors:
        - HP percentage
        - Number and strength of nearby enemies
        - Presence of MVPs/bosses
        - PvP situation
        """
        if not monsters and not players:
            return 0.0
        
        threat = 0.0
        
        # HP factor (lower HP = higher threat)
        hp_percent = character.hp / max(character.hp_max, 1)
        hp_threat = 1.0 - hp_percent
        threat += hp_threat * 0.3
        
        # Monster factor
        monster_threat = 0.0
        for monster in monsters:
            if monster.is_mvp:
                monster_threat += 0.4
            elif monster.is_boss:
                monster_threat += 0.2
            elif monster.is_aggressive:
                monster_threat += 0.08
            else:
                monster_threat += 0.03
        monster_threat = min(monster_threat, 0.5)
        threat += monster_threat
        
        # Player factor (in PvP)
        if self._is_in_pvp(game_state):
            enemy_players = [p for p in players if p.is_enemy]
            player_threat = len(enemy_players) * 0.15
            threat += min(player_threat, 0.3)
        
        return min(threat, 1.0)
    
    def _is_in_pvp(self, game_state: "GameState") -> bool:
        """Check if in PvP mode."""
        if hasattr(game_state, "pvp_mode"):
            return bool(game_state.pvp_mode)
        if hasattr(game_state, "map_type"):
            return game_state.map_type in ("pvp", "gvg", "battlefield")
        return False
    
    def _is_in_woe(self, game_state: "GameState") -> bool:
        """Check if in War of Emperium."""
        if hasattr(game_state, "woe_active"):
            return bool(game_state.woe_active)
        if hasattr(game_state, "map_name"):
            return "agit" in str(game_state.map_name).lower()
        return False
    
    def _extract_danger_zones(self, game_state: "GameState") -> list:
        """Extract danger zones from map data."""
        if hasattr(game_state, "danger_zones"):
            return list(game_state.danger_zones)
        return []
    
    def _find_actor_by_id(
        self,
        actor_id: int,
        monsters: list[MonsterActor],
        players: list[PlayerActor],
    ) -> MonsterActor | PlayerActor | None:
        """Find actor by ID in monster/player lists."""
        for monster in monsters:
            if monster.actor_id == actor_id:
                return monster
        for player in players:
            if player.actor_id == actor_id:
                return player
        return None
    
    def _is_emergency(self, context: CombatContext) -> bool:
        """Check if in emergency state (critical HP)."""
        hp_percent = context.character.hp / max(context.character.hp_max, 1)
        return hp_percent <= self.config.emergency_hp_threshold
    
    def _should_retreat(self, context: CombatContext) -> bool:
        """Check if should retreat (low HP but not emergency)."""
        hp_percent = context.character.hp / max(context.character.hp_max, 1)
        
        # Check HP threshold
        if hp_percent <= self.config.retreat_hp_threshold:
            return True
        
        # Check threat level
        if context.threat_level >= self.config.engage_threat_threshold:
            # Too dangerous - check if can handle
            if hp_percent < 0.5:
                return True
        
        # Check MVP/Boss solo avoidance
        if self.config.avoid_mvp_solo:
            has_mvp = any(m.is_mvp for m in context.nearby_monsters)
            solo = len(context.party_members) == 0
            if has_mvp and solo:
                return True
        
        if self.config.avoid_boss_solo:
            has_boss = any(m.is_boss for m in context.nearby_monsters)
            solo = len(context.party_members) == 0
            if has_boss and solo:
                return True
        
        return False
    
    async def _create_emergency_action(
        self,
        context: CombatContext,
    ) -> CombatAction | None:
        """Create emergency action (heal item or flee)."""
        # Priority 1: Use healing item
        # Check if we have potions (would check inventory)
        # For now, flee
        self.metrics.retreats_triggered += 1
        
        return CombatAction(
            action_type=CombatActionType.FLEE,
            priority=10,
            reason="emergency - critical HP",
        )
    
    async def _create_retreat_action(
        self,
        context: CombatContext,
    ) -> CombatAction | None:
        """Create retreat action."""
        self.metrics.retreats_triggered += 1
        
        # Try to move away from threats
        if context.nearby_monsters:
            # Calculate escape direction
            char_pos = context.character.position
            avg_threat_x = sum(m.position[0] for m in context.nearby_monsters) / len(context.nearby_monsters)
            avg_threat_y = sum(m.position[1] for m in context.nearby_monsters) / len(context.nearby_monsters)
            
            # Move opposite direction
            dx = char_pos[0] - avg_threat_x
            dy = char_pos[1] - avg_threat_y
            
            # Normalize and scale
            import math
            dist = math.sqrt(dx*dx + dy*dy) or 1
            escape_x = int(char_pos[0] + (dx / dist) * 5)
            escape_y = int(char_pos[1] + (dy / dist) * 5)
            
            return CombatAction(
                action_type=CombatActionType.MOVE,
                position=(escape_x, escape_y),
                priority=9,
                reason="retreating from threats",
            )
        
        return CombatAction(
            action_type=CombatActionType.FLEE,
            priority=9,
            reason="retreating - low HP",
        )
    
    async def _check_prebattle_buffs(
        self,
        context: CombatContext,
    ) -> CombatAction | None:
        """Check if any pre-battle buffs should be applied."""
        if self._current_role is None:
            return None
        
        tactics = self.get_tactics(self._current_role)
        
        # Delegate to tactics for buff decisions
        # This would check for missing important buffs
        # Implementation depends on specific buff tracking
        
        return None
    
    # =========================================================================
    # State accessors
    # =========================================================================
    
    @property
    def current_state(self) -> CombatState:
        """Get current combat state."""
        return self._current_state
    
    @property
    def current_role(self) -> TacticalRole | None:
        """Get current tactical role."""
        return self._current_role
    
    @property
    def current_target_id(self) -> int | None:
        """Get current target ID."""
        return self._current_target_id