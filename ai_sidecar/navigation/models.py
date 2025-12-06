"""
Navigation data models for portal/warp navigation system.

Defines data structures for portals, routes, and navigation state.
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional, List, Dict, Any


class PortalType(Enum):
    """Type of portal or warp mechanism."""
    PORTAL = auto()          # Standard map portal (walk through)
    KAFRA = auto()           # Kafra teleport service (NPC talk)
    WARP_NPC = auto()        # Warp NPC (talk to teleport)
    BUTTERFLY_WING = auto()  # Butterfly wing item (return to save point)
    FLY_WING = auto()        # Fly wing item (random teleport on map)
    TELEPORT_SKILL = auto()  # Teleport skill (acolyte/wizard)
    DUNGEON_WARP = auto()    # Dungeon-specific warp
    GUILD_HALL = auto()      # Guild hall portal
    INSTANCE = auto()        # Instance portal
    COMMAND = auto()         # GM/test command warp


class NavigationPreference(Enum):
    """Navigation optimization preference."""
    FASTEST = auto()         # Minimize travel time
    CHEAPEST = auto()        # Minimize zeny cost
    SAFEST = auto()          # Avoid dangerous maps
    BALANCED = auto()        # Balance between time and cost


@dataclass
class Portal:
    """
    Represents a portal or warp connection between maps.
    
    Attributes:
        from_map: Source map name
        from_x: X coordinate on source map
        from_y: Y coordinate on source map
        to_map: Destination map name
        to_x: X coordinate on destination map
        to_y: Y coordinate on destination map
        portal_type: Type of portal mechanism
        cost: Zeny cost (0 for free portals)
        conversation: NPC conversation sequence for kafra/warp NPCs
        requirements: List of requirements (level, quest completion, etc.)
        bidirectional: Whether this portal works both ways
        npc_id: NPC ID for kafra/warp NPCs
        item_id: Item ID for wing items
        estimated_walk_time: Estimated time to walk to portal (seconds)
    """
    from_map: str
    from_x: int
    from_y: int
    to_map: str
    to_x: int
    to_y: int
    portal_type: PortalType = PortalType.PORTAL
    cost: int = 0
    conversation: Optional[str] = None
    requirements: List[str] = field(default_factory=list)
    bidirectional: bool = False
    npc_id: Optional[int] = None
    item_id: Optional[int] = None
    estimated_walk_time: float = 0.0
    
    @property
    def source_key(self) -> str:
        """Get unique key for source location."""
        return f"{self.from_map}:{self.from_x}:{self.from_y}"
    
    @property
    def dest_key(self) -> str:
        """Get unique key for destination location."""
        return f"{self.to_map}:{self.to_x}:{self.to_y}"
    
    @property
    def edge_key(self) -> str:
        """Get unique key for this portal edge."""
        return f"{self.from_map}->{self.to_map}"
    
    def get_reverse(self) -> "Portal":
        """Get the reverse portal (for bidirectional portals)."""
        return Portal(
            from_map=self.to_map,
            from_x=self.to_x,
            from_y=self.to_y,
            to_map=self.from_map,
            to_x=self.from_x,
            to_y=self.from_y,
            portal_type=self.portal_type,
            cost=self.cost,
            conversation=self.conversation,
            requirements=self.requirements.copy(),
            bidirectional=True,
            npc_id=self.npc_id,
            item_id=self.item_id,
            estimated_walk_time=self.estimated_walk_time,
        )


@dataclass
class KafraDestination:
    """
    Kafra teleport destination.
    
    Attributes:
        name: Display name of destination
        map_name: Internal map name
        x: Destination X coordinate
        y: Destination Y coordinate
        cost: Zeny cost for teleport
        menu_option: Menu option number in kafra dialogue
        requirements: Access requirements (level, quest, etc.)
    """
    name: str
    map_name: str
    x: int
    y: int
    cost: int
    menu_option: int
    requirements: List[str] = field(default_factory=list)


@dataclass
class WarpNPC:
    """
    Warp NPC that provides teleportation services.
    
    Attributes:
        npc_name: Name of the NPC
        map_name: Map where NPC is located
        x: NPC X coordinate
        y: NPC Y coordinate
        destinations: List of available destinations
        conversation_sequence: NPC conversation pattern
    """
    npc_name: str
    map_name: str
    x: int
    y: int
    destinations: List[KafraDestination] = field(default_factory=list)
    conversation_sequence: str = "c r0"  # Default: click, select first option


@dataclass
class NavigationStep:
    """
    A single step in a navigation route.
    
    Attributes:
        action_type: Type of action (MOVE, TAKE_PORTAL, TALK_NPC, USE_ITEM)
        from_map: Source map
        to_map: Destination map (may be same for MOVE)
        x: Target X coordinate
        y: Target Y coordinate
        portal: Portal being used (if applicable)
        cost: Zeny cost for this step
        estimated_time: Estimated time for this step (seconds)
        description: Human-readable description
        extra_data: Additional action-specific data
    """
    action_type: str
    from_map: str
    to_map: str
    x: int
    y: int
    portal: Optional[Portal] = None
    cost: int = 0
    estimated_time: float = 0.0
    description: str = ""
    extra_data: Dict[str, Any] = field(default_factory=dict)


@dataclass
class NavigationRoute:
    """
    A complete route from source to destination.
    
    Attributes:
        source_map: Starting map
        dest_map: Target map
        steps: Ordered list of navigation steps
        total_cost: Total zeny cost for the route
        estimated_time: Total estimated travel time (seconds)
        requirements: Combined requirements for the route
        preference: Navigation preference used
        maps_traversed: List of maps in order
        is_valid: Whether this route is currently valid
    """
    source_map: str
    dest_map: str
    steps: List[NavigationStep] = field(default_factory=list)
    total_cost: int = 0
    estimated_time: float = 0.0
    requirements: List[str] = field(default_factory=list)
    preference: NavigationPreference = NavigationPreference.BALANCED
    maps_traversed: List[str] = field(default_factory=list)
    is_valid: bool = True
    
    @property
    def step_count(self) -> int:
        """Get the number of steps in this route."""
        return len(self.steps)
    
    @property
    def portal_count(self) -> int:
        """Get the number of portal transitions."""
        return sum(1 for step in self.steps if step.portal is not None)
    
    def is_empty(self) -> bool:
        """Check if route has no steps."""
        return len(self.steps) == 0


class NavigationState(Enum):
    """Current state of navigation progress."""
    IDLE = auto()           # Not navigating
    PLANNING = auto()       # Computing route
    WALKING_TO_PORTAL = auto()  # Moving to portal location
    TAKING_PORTAL = auto()  # Using portal
    TALKING_TO_NPC = auto()  # In NPC dialogue
    USING_ITEM = auto()     # Using teleport item
    WAITING = auto()        # Waiting for map load
    ARRIVED = auto()        # Reached destination
    FAILED = auto()         # Navigation failed
    BLOCKED = auto()        # Path blocked by monsters/obstacles


@dataclass
class NavigationProgress:
    """
    Tracks progress through a navigation route.
    
    Attributes:
        route: The navigation route being followed
        current_step_index: Index of current step (0-based)
        state: Current navigation state
        current_map: Current map name
        current_x: Current X position
        current_y: Current Y position
        retries: Number of retry attempts
        max_retries: Maximum retry attempts
        error_message: Error message if failed
        started_at: Timestamp when navigation started
        eta_seconds: Estimated time to arrival
    """
    route: NavigationRoute
    current_step_index: int = 0
    state: NavigationState = NavigationState.IDLE
    current_map: str = ""
    current_x: int = 0
    current_y: int = 0
    retries: int = 0
    max_retries: int = 3
    error_message: str = ""
    started_at: float = 0.0
    eta_seconds: float = 0.0
    
    @property
    def current_step(self) -> Optional[NavigationStep]:
        """Get the current navigation step."""
        if 0 <= self.current_step_index < len(self.route.steps):
            return self.route.steps[self.current_step_index]
        return None
    
    @property
    def is_complete(self) -> bool:
        """Check if navigation is complete."""
        return self.state == NavigationState.ARRIVED
    
    @property
    def has_failed(self) -> bool:
        """Check if navigation has failed."""
        return self.state == NavigationState.FAILED
    
    @property
    def progress_percent(self) -> float:
        """Get progress as percentage (0-100)."""
        if self.route.is_empty():
            return 0.0
        return (self.current_step_index / len(self.route.steps)) * 100.0
    
    def advance(self) -> bool:
        """
        Advance to the next step.
        
        Returns:
            True if advanced, False if at end
        """
        if self.current_step_index < len(self.route.steps) - 1:
            self.current_step_index += 1
            return True
        return False


# Common item IDs for navigation
class NavigationItems:
    """Common item IDs used in navigation."""
    BUTTERFLY_WING = 602   # Return to save point
    FLY_WING = 601         # Random teleport on current map
    GIANT_FLY_WING = 12212  # Teleport party members
    

# Common map categories for safety assessment
class MapCategory(Enum):
    """Categories of maps for navigation safety assessment."""
    CITY = auto()          # Safe city map
    FIELD = auto()         # Open field
    DUNGEON = auto()       # Dangerous dungeon
    PVP = auto()           # PvP enabled
    GVG = auto()           # Guild vs Guild
    INSTANCE = auto()      # Private instance
    SPECIAL = auto()       # Special event maps
    UNKNOWN = auto()       # Unknown category


@dataclass
class MapInfo:
    """
    Information about a map for navigation purposes.
    
    Attributes:
        name: Internal map name
        display_name: Human-readable name
        category: Map category
        base_level_requirement: Minimum base level
        is_save_point_allowed: Can save here
        is_memo_allowed: Can use memo skill here
        is_teleport_allowed: Can teleport here
        danger_level: Danger rating (0-10)
        has_kafra: Whether map has kafra service
        connected_maps: List of directly connected maps
    """
    name: str
    display_name: str = ""
    category: MapCategory = MapCategory.UNKNOWN
    base_level_requirement: int = 0
    is_save_point_allowed: bool = True
    is_memo_allowed: bool = True
    is_teleport_allowed: bool = True
    danger_level: int = 0
    has_kafra: bool = False
    connected_maps: List[str] = field(default_factory=list)
    
    def __post_init__(self):
        if not self.display_name:
            self.display_name = self.name