"""
Game state representation for AI Sidecar.

Defines Pydantic models for representing game state received from OpenKore.
These models are used for validation, serialization, and type-safe access.
"""

from enum import IntEnum
from typing import Any

from pydantic import BaseModel, Field


class ActorType(IntEnum):
    """Actor type enumeration matching OpenKore constants."""
    UNKNOWN = 0
    PLAYER = 1
    MONSTER = 2
    NPC = 3
    PET = 4
    HOMUNCULUS = 5
    MERCENARY = 6
    ELEMENTAL = 7
    ITEM = 8
    PORTAL = 9


class Position(BaseModel):
    """2D position on the map."""
    x: int = Field(ge=0, description="X coordinate")
    y: int = Field(ge=0, description="Y coordinate")
    
    def distance_to(self, other: "Position") -> float:
        """Calculate Euclidean distance to another position."""
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5
    
    def manhattan_distance(self, other: "Position") -> int:
        """Calculate Manhattan distance to another position."""
        return abs(self.x - other.x) + abs(self.y - other.y)


class ActorState(BaseModel):
    """State of a single actor (monster, player, NPC, etc.)."""
    
    id: int = Field(description="Unique actor ID")
    type: ActorType = Field(default=ActorType.UNKNOWN, description="Actor type")
    name: str = Field(default="", description="Actor name or job name")
    
    # Position
    position: Position = Field(default_factory=lambda: Position(x=0, y=0))
    
    # For monsters/players with HP
    hp: int | None = Field(default=None, ge=0, description="Current HP")
    hp_max: int | None = Field(default=None, ge=0, description="Maximum HP")
    
    # Movement
    moving: bool = Field(default=False, description="Is actor moving")
    destination: Position | None = Field(default=None, description="Movement destination")
    
    # Combat state
    attacking: bool = Field(default=False, description="Is attacking")
    target_id: int | None = Field(default=None, description="Current target ID")
    
    # Monster-specific
    mob_id: int | None = Field(default=None, description="Monster database ID")
    
    # Additional data
    extra: dict[str, Any] = Field(default_factory=dict, description="Extra actor data")
    
    @property
    def hp_percent(self) -> float | None:
        """Calculate HP percentage."""
        if self.hp is not None and self.hp_max and self.hp_max > 0:
            return (self.hp / self.hp_max) * 100
        return None


class CharacterState(BaseModel):
    """State of the player character."""
    
    # Identity
    name: str = Field(default="", description="Character name")
    job_id: int = Field(default=0, description="Job/class ID")
    base_level: int = Field(default=1, ge=1, le=999, description="Base level")
    job_level: int = Field(default=1, ge=1, le=999, description="Job level")
    
    # Position
    position: Position = Field(default_factory=lambda: Position(x=0, y=0))
    
    # Vitals
    hp: int = Field(default=0, ge=0, description="Current HP")
    hp_max: int = Field(default=1, ge=1, description="Maximum HP")
    sp: int = Field(default=0, ge=0, description="Current SP")
    sp_max: int = Field(default=1, ge=1, description="Maximum SP")
    
    # Experience
    base_exp: int = Field(default=0, ge=0, description="Current base experience")
    base_exp_max: int = Field(default=1, ge=1, description="Base exp for next level")
    job_exp: int = Field(default=0, ge=0, description="Current job experience")
    job_exp_max: int = Field(default=1, ge=1, description="Job exp for next level")
    
    # Stats
    weight: int = Field(default=0, ge=0, description="Current weight")
    weight_max: int = Field(default=1, ge=1, description="Maximum weight")
    zeny: int = Field(default=0, ge=0, description="Currency amount")
    
    # Movement
    moving: bool = Field(default=False, description="Is character moving")
    sitting: bool = Field(default=False, description="Is character sitting")
    
    # Combat state
    attacking: bool = Field(default=False, description="Is attacking")
    target_id: int | None = Field(default=None, description="Current target ID")
    
    # Status effects (list of status IDs)
    status_effects: list[int] = Field(default_factory=list, description="Active status effect IDs")
    
    # Progression fields
    stat_points: int = Field(default=0, ge=0, description="Available stat points")
    skill_points: int = Field(default=0, ge=0, description="Available skill points")
    
    # Character stats (RO's 6 core stats)
    # Note: Using stat_str and int_stat to avoid Python builtin conflicts
    stat_str: int = Field(default=1, ge=1, le=999, description="Strength stat", alias="str")
    agi: int = Field(default=1, ge=1, le=999, description="Agility stat")
    vit: int = Field(default=1, ge=1, le=999, description="Vitality stat")
    int_stat: int = Field(default=1, ge=1, le=999, description="Intelligence stat", alias="int")
    dex: int = Field(default=1, ge=1, le=999, description="Dexterity stat")
    luk: int = Field(default=1, ge=1, le=999, description="Luck stat")
    
    # Progression state
    lifecycle_state: str = Field(default="NOVICE", description="Character lifecycle state")
    job_class: str = Field(default="Novice", description="Current job class name")
    
    @property
    def hp_percent(self) -> float:
        """Calculate HP percentage."""
        return (self.hp / self.hp_max) * 100 if self.hp_max > 0 else 0
    
    @property
    def sp_percent(self) -> float:
        """Calculate SP percentage."""
        return (self.sp / self.sp_max) * 100 if self.sp_max > 0 else 0
    
    @property
    def weight_percent(self) -> float:
        """Calculate weight percentage."""
        return (self.weight / self.weight_max) * 100 if self.weight_max > 0 else 0


class InventoryItem(BaseModel):
    """Single inventory item."""
    
    index: int = Field(description="Inventory slot index")
    item_id: int = Field(description="Item database ID")
    name: str = Field(default="", description="Item name")
    amount: int = Field(default=1, ge=1, description="Stack amount")
    equipped: bool = Field(default=False, description="Is item equipped")
    identified: bool = Field(default=True, description="Is item identified")
    type: int = Field(default=0, description="Item type")


class InventoryState(BaseModel):
    """Inventory state."""
    
    items: list[InventoryItem] = Field(default_factory=list, description="Inventory items")
    
    def get_item_by_id(self, item_id: int) -> InventoryItem | None:
        """Find item by database ID."""
        for item in self.items:
            if item.item_id == item_id:
                return item
        return None
    
    def get_item_count(self, item_id: int) -> int:
        """Get total count of an item type."""
        return sum(item.amount for item in self.items if item.item_id == item_id)


class MapState(BaseModel):
    """Map/field state."""
    
    name: str = Field(default="", description="Map name")
    width: int = Field(default=0, ge=0, description="Map width")
    height: int = Field(default=0, ge=0, description="Map height")
    
    # Walkability (optional, may be large)
    # walkable: list[list[bool]] | None = None


class GameState(BaseModel):
    """
    Complete game state snapshot.
    
    This is the main model received from OpenKore on each tick.
    It aggregates all game state into a single object for AI processing.
    """
    
    # Metadata
    tick: int = Field(default=0, ge=0, description="Server tick number")
    timestamp: int = Field(default=0, description="Unix timestamp in milliseconds")
    
    # Core state
    character: CharacterState = Field(
        default_factory=CharacterState,
        description="Player character state"
    )
    
    # Actors in view
    actors: list[ActorState] = Field(
        default_factory=list,
        description="Visible actors (monsters, players, NPCs)"
    )
    
    # Inventory
    inventory: InventoryState = Field(
        default_factory=InventoryState,
        description="Inventory state"
    )
    
    # Map info
    map: MapState = Field(
        default_factory=MapState,
        description="Current map state"
    )
    
    # AI mode from OpenKore (0=manual, 1=auto, 2=?)
    ai_mode: int = Field(default=1, ge=0, le=2, description="OpenKore AI mode")
    
    def get_monsters(self) -> list[ActorState]:
        """Get all monsters in view."""
        return [a for a in self.actors if a.type == ActorType.MONSTER]
    
    def get_players(self) -> list[ActorState]:
        """Get all players in view."""
        return [a for a in self.actors if a.type == ActorType.PLAYER]
    
    def get_npcs(self) -> list[ActorState]:
        """Get all NPCs in view."""
        return [a for a in self.actors if a.type == ActorType.NPC]
    
    def get_actor_by_id(self, actor_id: int) -> ActorState | None:
        """Find actor by ID."""
        for actor in self.actors:
            if actor.id == actor_id:
                return actor
        return None
    
    def get_nearest_monster(self) -> tuple[ActorState | None, float]:
        """
        Get the nearest monster to the character.
        
        Returns:
            Tuple of (actor, distance) or (None, inf) if no monsters.
        """
        char_pos = self.character.position
        nearest = None
        min_dist = float("inf")
        
        for actor in self.get_monsters():
            dist = char_pos.distance_to(actor.position)
            if dist < min_dist:
                min_dist = dist
                nearest = actor
        
        return nearest, min_dist


def parse_game_state(data: dict[str, Any]) -> GameState:
    """
    Parse raw JSON data into a GameState object.
    
    Handles missing fields gracefully with defaults.
    
    Args:
        data: Raw dictionary from JSON parsing.
    
    Returns:
        Validated GameState object.
    """
    # Extract payload if wrapped
    if "payload" in data:
        data = data["payload"]
    
    return GameState.model_validate(data)