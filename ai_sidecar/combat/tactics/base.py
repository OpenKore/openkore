"""
Base Tactics Abstract Class for Combat AI.

Defines the interface for all role-specific tactical behaviors.
Each tactics implementation provides specialized combat logic
for different character roles (tank, DPS, support, etc.).
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Any, Protocol, runtime_checkable

from pydantic import BaseModel, Field, ConfigDict


class TacticalRole(str, Enum):
    """Available tactical roles."""
    
    TANK = "tank"
    MELEE_DPS = "melee_dps"
    RANGED_DPS = "ranged_dps"
    MAGIC_DPS = "magic_dps"
    SUPPORT = "support"
    HYBRID = "hybrid"


class Position(BaseModel):
    """Position on the game map."""
    
    model_config = ConfigDict(frozen=True)
    
    x: int = Field(description="X coordinate")
    y: int = Field(description="Y coordinate")
    
    def distance_to(self, other: "Position") -> float:
        """Calculate Euclidean distance to another position."""
        dx = self.x - other.x
        dy = self.y - other.y
        return (dx * dx + dy * dy) ** 0.5
    
    def manhattan_distance(self, other: "Position") -> int:
        """Calculate Manhattan distance to another position."""
        return abs(self.x - other.x) + abs(self.y - other.y)


class Skill(BaseModel):
    """Skill information for combat decisions."""
    
    model_config = ConfigDict(frozen=True)
    
    id: int = Field(description="Skill database ID")
    name: str = Field(description="Skill handle name")
    level: int = Field(default=1, ge=1, description="Current skill level")
    sp_cost: int = Field(default=0, ge=0, description="SP cost to use")
    cast_time: float = Field(default=0.0, ge=0.0, description="Cast time in seconds")
    cooldown: float = Field(default=0.0, ge=0.0, description="Cooldown in seconds")
    range: int = Field(default=0, ge=0, description="Skill range in cells")
    target_type: str = Field(default="single", description="Target type")
    element: str = Field(default="neutral", description="Skill element")
    is_offensive: bool = Field(default=True, description="Whether skill deals damage")


@runtime_checkable
class Actor(Protocol):
    """Protocol for any actor in combat (monster, player, NPC)."""
    
    @property
    def actor_id(self) -> int:
        """Unique actor identifier."""
        ...
    
    @property
    def name(self) -> str:
        """Actor name."""
        ...
    
    @property
    def hp(self) -> int:
        """Current HP."""
        ...
    
    @property
    def hp_max(self) -> int:
        """Maximum HP."""
        ...
    
    @property
    def position(self) -> tuple[int, int]:
        """Current position (x, y)."""
        ...


@dataclass
class ThreatEntry:
    """Threat information for an actor."""
    
    actor_id: int
    threat_value: float
    last_attack_time: float = 0.0
    damage_taken: int = 0
    is_targeting_self: bool = False


class CombatContextProtocol(Protocol):
    """Protocol for combat context interface."""
    
    @property
    def character_hp(self) -> int:
        """Character's current HP."""
        ...
    
    @property
    def character_hp_max(self) -> int:
        """Character's max HP."""
        ...
    
    @property
    def character_sp(self) -> int:
        """Character's current SP."""
        ...
    
    @property
    def character_sp_max(self) -> int:
        """Character's max SP."""
        ...
    
    @property
    def character_position(self) -> Position:
        """Character's current position."""
        ...
    
    @property
    def nearby_monsters(self) -> list[Any]:
        """List of monsters in range."""
        ...
    
    @property
    def party_members(self) -> list[Any]:
        """List of party members."""
        ...
    
    @property
    def cooldowns(self) -> dict[str, float]:
        """Active skill cooldowns."""
        ...
    
    @property
    def threat_level(self) -> float:
        """Current threat level 0.0-1.0."""
        ...


class TargetPriority(BaseModel):
    """Target with calculated priority score."""
    
    model_config = ConfigDict(frozen=True)
    
    actor_id: int = Field(description="Target actor ID")
    priority_score: float = Field(description="Priority score (higher = more important)")
    reason: str = Field(default="", description="Reason for priority")
    distance: float = Field(default=0.0, description="Distance to target")
    hp_percent: float = Field(default=1.0, description="Target HP percentage")


class TacticsConfig(BaseModel):
    """Configuration for tactical behavior."""
    
    model_config = ConfigDict(frozen=True)
    
    # HP thresholds
    emergency_hp_threshold: float = Field(
        default=0.25,
        ge=0.0, le=1.0,
        description="HP % to trigger emergency actions"
    )
    low_hp_threshold: float = Field(
        default=0.50,
        ge=0.0, le=1.0,
        description="HP % considered low"
    )
    
    # SP thresholds
    low_sp_threshold: float = Field(
        default=0.20,
        ge=0.0, le=1.0,
        description="SP % considered low"
    )
    
    # Combat parameters
    max_engagement_range: int = Field(
        default=14,
        ge=1,
        description="Maximum range to engage targets"
    )
    preferred_engagement_range: int = Field(
        default=2,
        ge=1,
        description="Preferred combat range"
    )
    
    # Positioning
    flee_distance: int = Field(
        default=10,
        ge=1,
        description="Distance to maintain when fleeing"
    )
    safe_distance: int = Field(
        default=5,
        ge=1,
        description="Safe distance from threats"
    )
    
    # Threat thresholds
    high_threat_threshold: float = Field(
        default=0.7,
        ge=0.0, le=1.0,
        description="Threat level considered high"
    )
    
    # Target selection
    prefer_low_hp_targets: bool = Field(
        default=True,
        description="Prioritize low HP targets"
    )
    prefer_mvp_targets: bool = Field(
        default=False,
        description="Prioritize MVP/boss targets"
    )


class BaseTactics(ABC):
    """
    Abstract base class for tactical combat behaviors.
    
    Each tactical role (tank, DPS, support, etc.) implements
    this interface with role-specific decision logic.
    
    Subclasses must implement:
    - select_target(): Choose optimal combat target
    - select_skill(): Choose optimal skill for target
    - evaluate_positioning(): Determine optimal position
    - get_threat_assessment(): Evaluate current danger
    """
    
    role: TacticalRole
    
    def __init__(self, config: TacticsConfig | None = None):
        """
        Initialize tactics with optional configuration.
        
        Args:
            config: Tactical configuration parameters
        """
        self.config = config or TacticsConfig()
        self._threat_table: dict[int, ThreatEntry] = {}
    
    @abstractmethod
    async def select_target(
        self,
        context: CombatContextProtocol
    ) -> TargetPriority | None:
        """
        Select the optimal combat target.
        
        Role-specific target selection considers:
        - Tank: Highest threat, aggro management
        - DPS: Lowest HP, burst potential
        - Support: Allies needing healing
        
        Args:
            context: Current combat situation
        
        Returns:
            Target with priority info, or None if no valid target
        """
        pass
    
    @abstractmethod
    async def select_skill(
        self,
        context: CombatContextProtocol,
        target: TargetPriority
    ) -> Skill | None:
        """
        Select optimal skill for the target.
        
        Considers:
        - SP availability
        - Cooldowns
        - Target element/size
        - Situation (AoE vs single)
        
        Args:
            context: Current combat situation
            target: Selected target
        
        Returns:
            Skill to use, or None for basic attack
        """
        pass
    
    @abstractmethod
    async def evaluate_positioning(
        self,
        context: CombatContextProtocol
    ) -> Position | None:
        """
        Determine optimal position for the character.
        
        Role-specific positioning:
        - Tank: Between party and threats
        - Ranged DPS: Maximum skill range
        - Support: Safe distance, near allies
        
        Args:
            context: Current combat situation
        
        Returns:
            Target position to move to, or None to stay
        """
        pass
    
    @abstractmethod
    def get_threat_assessment(
        self,
        context: CombatContextProtocol
    ) -> float:
        """
        Evaluate current threat level.
        
        Considers:
        - Number and power of enemies
        - Character HP/SP state
        - Party composition
        - Map danger zones
        
        Args:
            context: Current combat situation
        
        Returns:
            Threat level from 0.0 (safe) to 1.0 (critical)
        """
        pass
    
    # Shared helper methods
    
    def is_emergency(self, context: CombatContextProtocol) -> bool:
        """Check if character is in emergency state."""
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        return hp_percent <= self.config.emergency_hp_threshold
    
    def is_low_hp(self, context: CombatContextProtocol) -> bool:
        """Check if character HP is low."""
        hp_percent = context.character_hp / max(context.character_hp_max, 1)
        return hp_percent <= self.config.low_hp_threshold
    
    def is_low_sp(self, context: CombatContextProtocol) -> bool:
        """Check if character SP is low."""
        sp_percent = context.character_sp / max(context.character_sp_max, 1)
        return sp_percent <= self.config.low_sp_threshold
    
    def can_use_skill(
        self,
        skill: Skill,
        context: CombatContextProtocol
    ) -> bool:
        """Check if a skill can be used."""
        # Check SP
        if context.character_sp < skill.sp_cost:
            return False
        
        # Check cooldown
        if skill.name in context.cooldowns:
            if context.cooldowns[skill.name] > 0:
                return False
        
        return True
    
    def get_distance_to_target(
        self,
        context: CombatContextProtocol,
        target_position: tuple[int, int] | Position
    ) -> float:
        """Calculate distance to a target position."""
        char_pos = context.character_position
        # Handle both tuple and Position types
        if hasattr(target_position, 'x') and hasattr(target_position, 'y'):
            target_pos = target_position
        else:
            target_pos = Position(x=target_position[0], y=target_position[1])
        return char_pos.distance_to(target_pos)
    
    def prioritize_targets(
        self,
        context: CombatContextProtocol,
        targets: list[Any],
        scoring_func: Any | None = None
    ) -> list[TargetPriority]:
        """
        Create prioritized target list.
        
        Args:
            context: Combat context
            targets: List of potential targets
            scoring_func: Optional custom scoring function
        
        Returns:
            Sorted list of targets with priorities
        """
        priorities = []
        
        for target in targets:
            hp_percent = target.hp / max(target.hp_max, 1)
            distance = self.get_distance_to_target(
                context, target.position
            )
            
            # Default scoring: closer and lower HP = higher priority
            if scoring_func:
                score = scoring_func(target, hp_percent, distance)
            else:
                score = self._default_target_score(
                    target, hp_percent, distance
                )
            
            priorities.append(TargetPriority(
                actor_id=target.actor_id,
                priority_score=score,
                reason="default_scoring",
                distance=distance,
                hp_percent=hp_percent
            ))
        
        # Sort by priority score (descending)
        return sorted(priorities, key=lambda p: p.priority_score, reverse=True)
    
    def _default_target_score(
        self,
        target: Any,
        hp_percent: float,
        distance: float
    ) -> float:
        """Calculate default target priority score."""
        score = 100.0
        
        # Prefer closer targets
        if distance > 0:
            score -= distance * 2
        
        # Prefer lower HP targets (if configured)
        if self.config.prefer_low_hp_targets:
            score += (1 - hp_percent) * 30
        
        # Prefer MVP/boss targets (if configured)
        if self.config.prefer_mvp_targets:
            if hasattr(target, "is_mvp") and target.is_mvp:
                score += 50
            elif hasattr(target, "is_boss") and target.is_boss:
                score += 25
        
        return max(0, score)
    
    def update_threat(
        self,
        actor_id: int,
        damage_dealt: int = 0,
        damage_taken: int = 0,
        is_targeting: bool = False
    ) -> None:
        """Update threat table entry for an actor."""
        if actor_id not in self._threat_table:
            self._threat_table[actor_id] = ThreatEntry(
                actor_id=actor_id,
                threat_value=0.0
            )
        
        entry = self._threat_table[actor_id]
        entry.threat_value += damage_dealt * 1.0
        entry.threat_value += damage_taken * 1.5
        entry.damage_taken += damage_taken
        entry.is_targeting_self = is_targeting
        
        if is_targeting:
            entry.threat_value += 20
    
    def get_threat_for_actor(self, actor_id: int) -> float:
        """Get threat value for an actor."""
        if actor_id in self._threat_table:
            return self._threat_table[actor_id].threat_value
        return 0.0
    
    def clear_threat_table(self) -> None:
        """Clear all threat entries."""
        self._threat_table.clear()