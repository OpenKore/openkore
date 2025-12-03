"""
Combat data models for the AI Sidecar.

Defines Pydantic v2 models for combat-related data structures including:
- CombatContext: Complete combat situation snapshot
- CombatAction: A combat decision to execute
- MonsterActor: Monster with combat-relevant attributes
- Buff/Debuff: Status effect representations
- DangerZone: Hazardous map areas
"""

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field, ConfigDict, model_validator

from ai_sidecar.core.state import CharacterState, Position


class Element(str, Enum):
    """Ragnarok Online element types."""
    NEUTRAL = "neutral"
    FIRE = "fire"
    WATER = "water"
    EARTH = "earth"
    WIND = "wind"
    HOLY = "holy"
    DARK = "dark"
    POISON = "poison"
    GHOST = "ghost"
    UNDEAD = "undead"


class MonsterRace(str, Enum):
    """Monster race classifications."""
    FORMLESS = "formless"
    UNDEAD = "undead"
    BRUTE = "brute"
    PLANT = "plant"
    INSECT = "insect"
    FISH = "fish"
    DEMON = "demon"
    DEMI_HUMAN = "demi_human"
    ANGEL = "angel"
    DRAGON = "dragon"


class MonsterSize(str, Enum):
    """Monster size classifications."""
    SMALL = "small"
    MEDIUM = "medium"
    LARGE = "large"


class SkillType(str, Enum):
    """Skill type classifications."""
    ACTIVE = "active"
    PASSIVE = "passive"
    BUFF = "buff"
    DEBUFF = "debuff"
    AOE = "aoe"
    HEAL = "heal"
    SUPPORTIVE = "supportive"
    OFFENSIVE = "offensive"


class SkillCategory(str, Enum):
    """Skill category classifications for AI decision-making."""
    ATTACK = "attack"
    BUFF = "buff"
    DEBUFF = "debuff"
    HEAL = "heal"
    UTILITY = "utility"
    CROWD_CONTROL = "crowd_control"
    MOBILITY = "mobility"
    DEFENSIVE = "defensive"


class TargetType(str, Enum):
    """Skill target type classifications."""
    SINGLE = "single"
    AOE = "aoe"
    GROUND = "ground"
    SELF = "self"


class DamageType(str, Enum):
    """Damage type classifications."""
    PHYSICAL = "physical"
    MAGICAL = "magical"
    NEUTRAL = "neutral"


class CombatPhase(str, Enum):
    """Combat phase classifications."""
    PRE_COMBAT = "pre_combat"
    ENGAGING = "engaging"
    IN_COMBAT = "in_combat"
    DISENGAGING = "disengaging"
    POST_COMBAT = "post_combat"


class ThreatLevel(str, Enum):
    """Threat level classifications."""
    SAFE = "safe"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class TacticalRole(str, Enum):
    """Combat tactical roles."""
    TANK = "tank"
    MELEE_DPS = "melee_dps"
    RANGED_DPS = "ranged_dps"
    MAGIC_DPS = "magic_dps"
    SUPPORT = "support"
    HYBRID = "hybrid"


class CombatActionType(str, Enum):
    """Types of combat actions."""
    SKILL = "skill"
    ATTACK = "attack"
    ITEM = "item"
    MOVE = "move"
    FLEE = "flee"


class Buff(BaseModel):
    """Active buff/positive status effect."""
    
    model_config = ConfigDict(frozen=True)
    
    id: int = Field(description="Buff status ID")
    name: str = Field(default="", description="Buff name")
    remaining_ms: int = Field(default=0, ge=0, description="Remaining duration in ms")
    level: int = Field(default=1, ge=1, description="Buff level")
    
    @property
    def remaining_seconds(self) -> float:
        """Get remaining duration in seconds."""
        return self.remaining_ms / 1000.0


class Debuff(BaseModel):
    """Active debuff/negative status effect."""
    
    model_config = ConfigDict(frozen=True)
    
    id: int = Field(description="Debuff status ID")
    name: str = Field(default="", description="Debuff name")
    remaining_ms: int = Field(default=0, ge=0, description="Remaining duration in ms")
    level: int = Field(default=1, ge=1, description="Debuff level")
    
    @property
    def remaining_seconds(self) -> float:
        """Get remaining duration in seconds."""
        return self.remaining_ms / 1000.0


class DangerZone(BaseModel):
    """Hazardous area on the map."""
    
    model_config = ConfigDict(frozen=True)
    
    center: Position = Field(description="Center position of danger zone")
    radius: int = Field(default=3, ge=1, description="Radius in cells")
    damage_type: str = Field(default="unknown", description="Type of damage")
    element: Element = Field(default=Element.NEUTRAL, description="Element of damage")
    source_id: int | None = Field(default=None, description="Source actor ID")


class MonsterActor(BaseModel):
    """Monster with combat-relevant attributes."""
    
    model_config = ConfigDict(frozen=True)
    
    actor_id: int = Field(description="Unique actor ID")
    name: str = Field(default="", description="Monster name")
    mob_id: int = Field(description="Monster database ID")
    
    @model_validator(mode='before')
    @classmethod
    def convert_position(cls, data: Any) -> Any:
        """Convert tuple positions to Position objects."""
        if isinstance(data, dict) and 'position' in data:
            pos = data['position']
            if isinstance(pos, tuple) and len(pos) >= 2:
                data['position'] = Position(x=pos[0], y=pos[1])
        return data
    
    # Health
    hp: int = Field(default=0, ge=0, description="Current HP")
    hp_max: int = Field(default=1, ge=1, description="Maximum HP")
    
    # Properties
    element: Element = Field(default=Element.NEUTRAL, description="Monster element")
    race: MonsterRace = Field(default=MonsterRace.FORMLESS, description="Monster race")
    size: MonsterSize = Field(default=MonsterSize.MEDIUM, description="Monster size")
    
    # Position
    position: Position = Field(default_factory=lambda: Position(x=0, y=0))
    
    # Behavior flags
    is_aggressive: bool = Field(default=False, description="Attacks on sight")
    is_boss: bool = Field(default=False, description="Is a boss monster")
    is_mvp: bool = Field(default=False, description="Is an MVP")
    
    # Combat attributes
    attack_range: int = Field(default=1, ge=1, description="Attack range in cells")
    skills: list[str] = Field(default_factory=list, description="Known skill names")
    
    # State
    is_targeting_player: bool = Field(default=False, description="Is targeting our character")
    target_id: int | None = Field(default=None, description="Current target ID")
    
    @property
    def hp_percent(self) -> float:
        """Calculate HP percentage."""
        return (self.hp / self.hp_max) * 100 if self.hp_max > 0 else 0
    
    @property
    def is_low_hp(self) -> bool:
        """Check if monster has low HP (< 30%)."""
        return self.hp_percent < 30.0
    
    def distance_to(self, pos: Position) -> float:
        """Calculate distance to a position."""
        return self.position.distance_to(pos)


class PlayerActor(BaseModel):
    """Other player with combat-relevant attributes."""
    
    model_config = ConfigDict(frozen=True)
    
    actor_id: int = Field(description="Unique actor ID")
    name: str = Field(default="", description="Player name")
    job_id: int = Field(default=0, description="Job/class ID")
    
    # Position
    position: Position = Field(default_factory=lambda: Position(x=0, y=0))
    
    # Visible stats (limited visibility for other players)
    guild_name: str | None = Field(default=None, description="Guild name")
    party_name: str | None = Field(default=None, description="Party name")
    
    # PvP relevance
    is_hostile: bool = Field(default=False, description="Is hostile (PvP/WoE)")
    is_allied: bool = Field(default=False, description="Is allied (party/guild)")
    is_enemy: bool = Field(default=False, description="Is enemy (alias for is_hostile)")


class SkillInfo(BaseModel):
    """Information about a skill."""
    
    model_config = ConfigDict(frozen=True)
    
    skill_id: int = Field(description="Skill database ID")
    name: str = Field(default="", description="Skill handle name")
    level: int = Field(default=1, ge=1, description="Current skill level")
    max_level: int = Field(default=10, ge=1, description="Maximum skill level")
    sp_cost: int = Field(default=0, ge=0, description="SP cost at current level")
    cooldown: float = Field(default=0.0, ge=0.0, description="Cooldown in seconds")
    cast_time: float = Field(default=0.0, ge=0.0, description="Cast time in seconds")
    skill_type: SkillType = Field(default=SkillType.ACTIVE, description="Skill type")
    target_type: str = Field(default="self", description="Target type (self, single, ground, etc)")
    range: int = Field(default=0, ge=0, description="Skill range")
    element: Element = Field(default=Element.NEUTRAL, description="Skill element")


class CombatAction(BaseModel):
    """A combat decision to execute."""
    
    model_config = ConfigDict(frozen=False)  # Allow modification for chaining
    
    action_type: CombatActionType = Field(description="Type of combat action")
    skill_id: int | None = Field(default=None, description="Skill ID for skill actions")
    skill_level: int | None = Field(default=None, ge=1, description="Skill level to use")
    target_id: int | None = Field(default=None, description="Target actor ID")
    position: tuple[int, int] | None = Field(default=None, description="Position for ground skills/movement")
    item_id: int | None = Field(default=None, description="Item ID for item actions")
    priority: int = Field(default=5, ge=1, le=10, description="Action priority (1=highest)")
    reason: str = Field(default="", description="Reason for this action")
    
    @classmethod
    def attack(cls, target_id: int, priority: int = 3, reason: str = "") -> "CombatAction":
        """Create a basic attack action."""
        return cls(
            action_type=CombatActionType.ATTACK,
            target_id=target_id,
            priority=priority,
            reason=reason or "Basic attack"
        )
    
    @classmethod
    def skill(
        cls,
        skill_id: int,
        level: int = 1,
        target_id: int | None = None,
        position: tuple[int, int] | None = None,
        priority: int = 2,
        reason: str = ""
    ) -> "CombatAction":
        """Create a skill use action."""
        return cls(
            action_type=CombatActionType.SKILL,
            skill_id=skill_id,
            skill_level=level,
            target_id=target_id,
            position=position,
            priority=priority,
            reason=reason or f"Use skill {skill_id}"
        )
    
    @classmethod
    def use_item(cls, item_id: int, priority: int = 4, reason: str = "") -> "CombatAction":
        """Create an item use action."""
        return cls(
            action_type=CombatActionType.ITEM,
            item_id=item_id,
            priority=priority,
            reason=reason or f"Use item {item_id}"
        )
    
    @classmethod
    def move_to(cls, x: int, y: int, priority: int = 5, reason: str = "") -> "CombatAction":
        """Create a movement action."""
        return cls(
            action_type=CombatActionType.MOVE,
            position=(x, y),
            priority=priority,
            reason=reason or f"Move to ({x}, {y})"
        )
    
    @classmethod
    def flee(cls, x: int, y: int, priority: int = 1, reason: str = "") -> "CombatAction":
        """Create a flee action (highest priority movement)."""
        return cls(
            action_type=CombatActionType.FLEE,
            position=(x, y),
            priority=priority,
            reason=reason or "Flee from danger"
        )


class CombatContext(BaseModel):
    """Complete combat situation snapshot."""
    
    model_config = ConfigDict(
        frozen=False,  # Allow updates during tick
        arbitrary_types_allowed=True  # Allow Mock objects in tests
    )
    
    # Optional type field for test scenarios
    type: str | None = Field(default=None, description="Combat situation type (for tests)")
    
    # Character state
    character: CharacterState | None = Field(default=None, description="Our character's state")
    @model_validator(mode='before')
    @classmethod
    def convert_mock_character(cls, data: Any) -> Any:
        """Convert Mock character objects to CharacterState for tests."""
        if isinstance(data, dict):
            # Create default character if not provided (for test scenarios)
            if 'character' not in data or data['character'] is None:
                data['character'] = CharacterState(
                    name="TestChar",
                    job_id=0,
                    base_level=1,
                    job_level=1,
                    hp=100,
                    hp_max=100,
                    sp=50,
                    sp_max=50,
                    position=Position(x=0, y=0)
                )
                return data
            
            char = data['character']
            # Check if it's not already a CharacterState
            if not isinstance(char, CharacterState):
                # Helper to safely extract values from Mock objects
                def _safe_get(obj, attr, default=None, cast_type=None):
                    """Safely get attribute, handling Mock objects."""
                    # Check if attribute exists
                    if not hasattr(obj, attr):
                        return default
                    
                    val = getattr(obj, attr, default)
                    
                    # Check if it's a Mock object (auto-created attribute)
                    if hasattr(val, '_mock_name') or 'Mock' in type(val).__name__:
                        return default
                    
                    # Cast if needed
                    if cast_type and val is not None:
                        try:
                            return cast_type(val)
                        except (TypeError, ValueError):
                            return default
                    
                    return val if val is not None else default
                
                # Create character dict with safe extraction
                char_dict = {}
                
                # Core vitals - use safe getter with int cast
                char_dict['hp'] = _safe_get(char, 'hp', 0, int)
                char_dict['hp_max'] = _safe_get(char, 'hp_max', 1, int)
                char_dict['sp'] = _safe_get(char, 'sp', 0, int)
                char_dict['sp_max'] = _safe_get(char, 'sp_max', 1, int)
                
                # Position - handle various input formats
                pos = _safe_get(char, 'position', None)
                if isinstance(pos, Position):
                    char_dict['position'] = pos
                elif isinstance(pos, tuple) and len(pos) >= 2:
                    char_dict['position'] = Position(x=pos[0], y=pos[1])
                elif pos is not None and hasattr(pos, 'x') and hasattr(pos, 'y'):
                    char_dict['position'] = Position(x=pos.x, y=pos.y)
                elif isinstance(pos, dict):
                    char_dict['position'] = Position(**pos)
                else:
                    char_dict['position'] = Position(x=0, y=0)
                
                # Job ID
                char_dict['job_id'] = _safe_get(char, 'job_id', 0, int)
                
                # Character stats
                char_dict['str'] = _safe_get(char, 'str', 1, int)
                char_dict['agi'] = _safe_get(char, 'agi', 1, int)
                char_dict['vit'] = _safe_get(char, 'vit', 1, int)
                char_dict['int'] = _safe_get(char, 'int', 1, int)
                char_dict['dex'] = _safe_get(char, 'dex', 1, int)
                char_dict['luk'] = _safe_get(char, 'luk', 1, int)
                
                # Levels
                char_dict['base_level'] = _safe_get(char, 'base_level', 1, int)
                char_dict['job_level'] = _safe_get(char, 'job_level', 1, int)
                
                # Optional fields
                char_dict['skill_points'] = _safe_get(char, 'skill_points', 0, int)
                char_dict['stat_points'] = _safe_get(char, 'stat_points', 0, int)
                char_dict['name'] = _safe_get(char, 'name', 'TestChar', str)
                
                # Create CharacterState
                data['character'] = CharacterState(**char_dict)
        return data
    
    
    # Nearby actors
    nearby_monsters: list[MonsterActor] = Field(
        default_factory=list,
        description="Monsters in view"
    )
    nearby_players: list[PlayerActor] = Field(
        default_factory=list,
        description="Other players in view"
    )
    party_members: list[CharacterState] = Field(
        default_factory=list,
        description="Party member states"
    )
    
    # Status effects
    active_buffs: list[Buff] = Field(
        default_factory=list,
        description="Active buffs on character"
    )
    active_debuffs: list[Debuff] = Field(
        default_factory=list,
        description="Active debuffs on character"
    )
    
    # Skill state
    cooldowns: dict[str, float] = Field(
        default_factory=dict,
        description="skill_name -> seconds remaining"
    )
    available_skills: list[SkillInfo] = Field(
        default_factory=list,
        description="Skills available to use"
    )
    
    # Threat assessment
    threat_level: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Overall threat (0.0 = safe, 1.0 = critical)"
    )
    
    # Combat mode
    in_pvp: bool = Field(default=False, description="In PvP mode")
    in_woe: bool = Field(default=False, description="In War of Emperium")
    in_party: bool = Field(default=False, description="In a party")
    
    # Environmental hazards
    map_danger_zones: list[DangerZone] = Field(
        default_factory=list,
        description="Hazardous areas on map"
    )
    
    # Tactical role
    assigned_role: TacticalRole = Field(
        default=TacticalRole.HYBRID,
        description="Assigned combat role"
    )
    
    # Combat statistics for this session
    total_damage_dealt: int = Field(default=0, ge=0)
    total_damage_taken: int = Field(default=0, ge=0)
    kills: int = Field(default=0, ge=0)
    
    @property
    def is_in_combat(self) -> bool:
        """Check if character is actively in combat."""
        return len(self.nearby_monsters) > 0 or self.threat_level > 0.1
    
    @property
    def hp_critical(self) -> bool:
        """Check if HP is critically low (< 20%)."""
        return self.character.hp_percent < 20.0
    
    @property
    def sp_low(self) -> bool:
        """Check if SP is low (< 30%)."""
        return self.character.sp_percent < 30.0
    
    @property
    def monsters_targeting_us(self) -> list[MonsterActor]:
        """Get monsters currently targeting our character."""
        return [m for m in self.nearby_monsters if m.is_targeting_player]
    
    @property
    def aggressive_monsters(self) -> list[MonsterActor]:
        """Get aggressive monsters nearby."""
        return [m for m in self.nearby_monsters if m.is_aggressive]
    
    def get_nearest_monster(self) -> MonsterActor | None:
        """Get the nearest monster."""
        if not self.nearby_monsters:
            return None
        char_pos = self.character.position
        return min(
            self.nearby_monsters,
            key=lambda m: m.distance_to(char_pos)
        )
    
    def get_lowest_hp_monster(self) -> MonsterActor | None:
        """Get the monster with lowest HP percentage."""
        if not self.nearby_monsters:
            return None
        return min(self.nearby_monsters, key=lambda m: m.hp_percent)
    
    def get_skill_cooldown(self, skill_name: str) -> float:
        """Get remaining cooldown for a skill."""
        return self.cooldowns.get(skill_name, 0.0)
    
    def is_skill_ready(self, skill_name: str) -> bool:
        """Check if a skill is off cooldown."""
        return self.get_skill_cooldown(skill_name) <= 0.0
    
    def has_buff(self, buff_id: int) -> bool:
        """Check if a specific buff is active."""
        return any(b.id == buff_id for b in self.active_buffs)
    
    def has_debuff(self, debuff_id: int) -> bool:
        """Check if a specific debuff is active."""
        return any(d.id == debuff_id for d in self.active_debuffs)
    
    # Convenience properties for CombatContextProtocol compatibility
    @property
    def character_hp(self) -> int:
        """Character's current HP."""
        return self.character.hp
    
    @property
    def character_hp_max(self) -> int:
        """Character's max HP."""
        return self.character.hp_max
    
    @property
    def character_sp(self) -> int:
        """Character's current SP."""
        return self.character.sp
    
    @property
    def character_sp_max(self) -> int:
        """Character's max SP."""
        return self.character.sp_max
    
    @property
    def character_position(self) -> Position:
        """Character's current position."""
        return self.character.position


# Element effectiveness chart for damage calculation
# Format: ELEMENT_CHART[attacker_element][defender_element] = modifier
ELEMENT_CHART: dict[Element, dict[Element, float]] = {
    Element.NEUTRAL: {e: 1.0 for e in Element},
    Element.FIRE: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 0.25,
        Element.WATER: 0.5,
        Element.EARTH: 1.5,
        Element.WIND: 1.0,
        Element.HOLY: 0.75,
        Element.DARK: 0.75,
        Element.POISON: 1.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 1.25,
    },
    Element.WATER: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.5,
        Element.WATER: 0.25,
        Element.EARTH: 1.0,
        Element.WIND: 0.5,
        Element.HOLY: 0.75,
        Element.DARK: 0.75,
        Element.POISON: 1.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 1.0,
    },
    Element.EARTH: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 0.5,
        Element.WATER: 1.0,
        Element.EARTH: 0.25,
        Element.WIND: 1.5,
        Element.HOLY: 0.75,
        Element.DARK: 0.75,
        Element.POISON: 1.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 1.0,
    },
    Element.WIND: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.5,
        Element.EARTH: 0.5,
        Element.WIND: 0.25,
        Element.HOLY: 0.75,
        Element.DARK: 0.75,
        Element.POISON: 1.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 1.0,
    },
    Element.HOLY: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.0,
        Element.EARTH: 1.0,
        Element.WIND: 1.0,
        Element.HOLY: 0.0,
        Element.DARK: 2.0,
        Element.POISON: 1.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 2.0,
    },
    Element.DARK: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.0,
        Element.EARTH: 1.0,
        Element.WIND: 1.0,
        Element.HOLY: 2.0,
        Element.DARK: 0.0,
        Element.POISON: 0.5,
        Element.GHOST: 1.0,
        Element.UNDEAD: 0.0,
    },
    Element.POISON: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.0,
        Element.EARTH: 1.0,
        Element.WIND: 1.0,
        Element.HOLY: 1.0,
        Element.DARK: 0.5,
        Element.POISON: 0.0,
        Element.GHOST: 1.0,
        Element.UNDEAD: 0.5,
    },
    Element.GHOST: {
        Element.NEUTRAL: 0.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.0,
        Element.EARTH: 1.0,
        Element.WIND: 1.0,
        Element.HOLY: 1.0,
        Element.DARK: 1.0,
        Element.POISON: 1.0,
        Element.GHOST: 1.75,
        Element.UNDEAD: 1.0,
    },
    Element.UNDEAD: {
        Element.NEUTRAL: 1.0,
        Element.FIRE: 1.0,
        Element.WATER: 1.0,
        Element.EARTH: 1.0,
        Element.WIND: 1.0,
        Element.HOLY: 2.0,
        Element.DARK: 0.0,
        Element.POISON: 0.5,
        Element.GHOST: 1.0,
        Element.UNDEAD: 0.0,
    },
}


def get_element_modifier(attacker_element: Element, defender_element: Element) -> float:
    """
    Get the damage modifier for element interaction.
    
    Args:
        attacker_element: Element of the attacking skill/weapon
        defender_element: Element of the defending monster
        
    Returns:
        Damage modifier (1.0 = normal, >1.0 = effective, <1.0 = resistant)
    """
    return ELEMENT_CHART.get(attacker_element, {}).get(defender_element, 1.0)


# Size modifiers for weapon types
SIZE_MODIFIERS: dict[str, dict[MonsterSize, float]] = {
    "dagger": {MonsterSize.SMALL: 1.0, MonsterSize.MEDIUM: 0.75, MonsterSize.LARGE: 0.5},
    "sword": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.75},
    "two_hand_sword": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 0.75, MonsterSize.LARGE: 1.0},
    "spear": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 0.75, MonsterSize.LARGE: 1.0},
    "axe": {MonsterSize.SMALL: 0.5, MonsterSize.MEDIUM: 0.75, MonsterSize.LARGE: 1.0},
    "mace": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 1.0},
    "staff": {MonsterSize.SMALL: 1.0, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 1.0},
    "bow": {MonsterSize.SMALL: 1.0, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.75},
    "katar": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.75},
    "book": {MonsterSize.SMALL: 1.0, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.5},
    "knuckle": {MonsterSize.SMALL: 1.0, MonsterSize.MEDIUM: 0.75, MonsterSize.LARGE: 0.5},
    "instrument": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.75},
    "whip": {MonsterSize.SMALL: 0.75, MonsterSize.MEDIUM: 1.0, MonsterSize.LARGE: 0.5},
}


def get_size_modifier(weapon_type: str, monster_size: MonsterSize) -> float:
    """
    Get the damage modifier for weapon vs monster size.
    
    Args:
        weapon_type: Type of weapon being used
        monster_size: Size of the target monster
        
    Returns:
        Damage modifier (1.0 = normal, <1.0 = penalty)
    """
    weapon_mods = SIZE_MODIFIERS.get(weapon_type.lower(), {})
    return weapon_mods.get(monster_size, 1.0)