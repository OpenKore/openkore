"""
NPC data models for AI Sidecar.

Defines Pydantic v2 models for NPC entities, dialogue systems,
and NPC interaction tracking.
"""

from datetime import datetime
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field, ConfigDict


class NPCType(str, Enum):
    """Types of NPCs in Ragnarok Online."""

    SHOP = "shop"
    QUEST = "quest"
    SERVICE = "service"  # Kafra, refiner, etc.
    WARP = "warp"
    GUILD = "guild"
    EVENT = "event"
    GENERIC = "generic"


class DialogueChoice(BaseModel):
    """A selectable option in NPC dialogue."""

    model_config = ConfigDict(frozen=False)

    index: int = Field(ge=0, description="Choice index")
    text: str = Field(description="Choice text displayed to player")
    leads_to: str | None = Field(default=None, description="Next dialogue ID if known")
    is_exit: bool = Field(default=False, description="Does this choice exit dialogue")
    requires_item: int | None = Field(
        default=None, description="Item ID required for this choice"
    )
    requires_zeny: int | None = Field(
        default=None, description="Zeny amount required"
    )


class DialogueState(BaseModel):
    """Current state of NPC dialogue interaction."""

    model_config = ConfigDict(frozen=False)

    npc_id: int = Field(description="NPC actor ID")
    npc_name: str = Field(description="NPC name")
    current_text: str = Field(description="Current dialogue text")
    choices: list[DialogueChoice] = Field(
        default_factory=list, description="Available dialogue choices"
    )
    waiting_for_input: bool = Field(
        default=False, description="Is waiting for player input"
    )
    input_type: Literal["choice", "number", "text", "none"] = Field(
        default="none", description="Type of input expected"
    )
    history: list[str] = Field(
        default_factory=list, description="Previous dialogue texts"
    )

    def add_to_history(self, text: str) -> None:
        """Add text to dialogue history."""
        self.history.append(text)
        # Keep only last 20 entries to prevent memory bloat
        if len(self.history) > 20:
            self.history = self.history[-20:]


class NPC(BaseModel):
    """NPC entity with full attributes."""

    model_config = ConfigDict(frozen=False)

    # Identity
    npc_id: int = Field(description="NPC actor ID")
    name: str = Field(description="NPC name")
    npc_type: NPCType = Field(description="NPC type classification")

    # Location
    map_name: str = Field(description="Map where NPC is located")
    x: int = Field(ge=0, description="X coordinate")
    y: int = Field(ge=0, description="Y coordinate")

    # Service details
    services: list[str] = Field(
        default_factory=list,
        description="Services offered (storage, teleport, save, etc.)",
    )
    shop_items: list[int] = Field(
        default_factory=list, description="Item IDs if shop NPC"
    )
    quests: list[int] = Field(
        default_factory=list, description="Quest IDs associated with NPC"
    )

    # Dialogue patterns
    dialogue_tree_id: str | None = Field(
        default=None, description="ID of dialogue tree if applicable"
    )
    keywords: list[str] = Field(
        default_factory=list, description="Keywords for text matching"
    )

    # Metadata
    discovered_at: datetime | None = Field(
        default=None, description="When NPC was first discovered"
    )
    last_interaction: datetime | None = Field(
        default=None, description="Last interaction timestamp"
    )
    interaction_count: int = Field(default=0, ge=0, description="Total interactions")

    def distance_to(self, x: int, y: int) -> float:
        """Calculate Euclidean distance to coordinates."""
        return ((self.x - x) ** 2 + (self.y - y) ** 2) ** 0.5

    def is_near(self, x: int, y: int, threshold: int = 5) -> bool:
        """Check if coordinates are near this NPC."""
        return self.distance_to(x, y) <= threshold


class ServiceNPC(BaseModel):
    """Service NPC with specific functions (Kafra, refiner, etc.)."""

    model_config = ConfigDict(frozen=False)

    npc_id: int = Field(description="NPC actor ID")
    name: str = Field(description="NPC name")
    service_type: Literal[
        "kafra",
        "refiner",
        "identifier",
        "repairman",
        "stylist",
        "card_remover",
    ] = Field(description="Type of service provided")

    # Location
    map_name: str = Field(description="Map where NPC is located")
    x: int = Field(ge=0, description="X coordinate")
    y: int = Field(ge=0, description="Y coordinate")

    # Service properties
    service_cost: int = Field(default=0, ge=0, description="Base cost for service")
    available_services: list[str] = Field(
        default_factory=list, description="Specific services available"
    )

    # Service-specific data
    extra_data: dict[str, Any] = Field(
        default_factory=dict, description="Service-specific metadata"
    )


class NPCDatabase:
    """
    In-memory NPC database for caching and lookup.

    Provides fast access to NPC data without file I/O on each query.
    """

    def __init__(self) -> None:
        """Initialize empty NPC database."""
        self._npcs: dict[int, NPC] = {}
        self._by_map: dict[str, list[NPC]] = {}
        self._by_type: dict[NPCType, list[NPC]] = {}
        self._service_npcs: dict[str, list[ServiceNPC]] = {}

    def add_npc(self, npc: NPC) -> None:
        """Add NPC to database."""
        self._npcs[npc.npc_id] = npc

        # Index by map
        if npc.map_name not in self._by_map:
            self._by_map[npc.map_name] = []
        self._by_map[npc.map_name].append(npc)

        # Index by type
        if npc.npc_type not in self._by_type:
            self._by_type[npc.npc_type] = []
        self._by_type[npc.npc_type].append(npc)

    def add_service_npc(self, service_npc: ServiceNPC) -> None:
        """Add service NPC to database."""
        service_type = service_npc.service_type
        if service_type not in self._service_npcs:
            self._service_npcs[service_type] = []
        self._service_npcs[service_type].append(service_npc)

    def get_npc(self, npc_id: int) -> NPC | None:
        """Get NPC by ID."""
        return self._npcs.get(npc_id)

    def get_npcs_on_map(self, map_name: str) -> list[NPC]:
        """Get all NPCs on a specific map."""
        return self._by_map.get(map_name, [])

    def get_npcs_by_type(self, npc_type: NPCType) -> list[NPC]:
        """Get all NPCs of a specific type."""
        return self._by_type.get(npc_type, [])

    def find_nearest_service(
        self, service_type: str, map_name: str, x: int, y: int
    ) -> ServiceNPC | None:
        """Find nearest service NPC of given type on map."""
        service_npcs = self._service_npcs.get(service_type, [])
        nearest = None
        min_dist = float("inf")

        for npc in service_npcs:
            if npc.map_name == map_name:
                dist = ((npc.x - x) ** 2 + (npc.y - y) ** 2) ** 0.5
                if dist < min_dist:
                    min_dist = dist
                    nearest = npc

        return nearest

    def find_quest_npcs(self, quest_id: int) -> list[NPC]:
        """Find NPCs associated with a quest."""
        return [npc for npc in self._npcs.values() if quest_id in npc.quests]

    def count(self) -> int:
        """Get total number of NPCs in database."""
        return len(self._npcs)


class ServiceNPCDatabase:
    """
    Database of service NPCs organized by type and location.

    Provides quick lookup for Kafra, refiners, and other service NPCs.
    """

    def __init__(self) -> None:
        """Initialize service NPC database."""
        # Structure: {service_type: {map_name: [ServiceNPC]}}
        self._services: dict[str, dict[str, list[ServiceNPC]]] = {
            "kafra": {},
            "refiner": {},
            "identifier": {},
            "repairman": {},
            "stylist": {},
            "card_remover": {},
        }

    def add_service_npc(self, service_npc: ServiceNPC) -> None:
        """Add a service NPC to the database."""
        service_type = service_npc.service_type
        map_name = service_npc.map_name

        if service_type not in self._services:
            self._services[service_type] = {}

        if map_name not in self._services[service_type]:
            self._services[service_type][map_name] = []

        self._services[service_type][map_name].append(service_npc)

    def get_service_npcs(
        self, service_type: str, map_name: str | None = None
    ) -> list[ServiceNPC]:
        """
        Get service NPCs of given type.

        Args:
            service_type: Type of service (kafra, refiner, etc.)
            map_name: Optional map filter

        Returns:
            List of matching service NPCs
        """
        if service_type not in self._services:
            return []

        if map_name is None:
            # Return all NPCs of this service type
            result = []
            for map_npcs in self._services[service_type].values():
                result.extend(map_npcs)
            return result

        return self._services[service_type].get(map_name, [])

    def find_nearest(
        self, service_type: str, map_name: str, x: int, y: int
    ) -> ServiceNPC | None:
        """Find nearest service NPC of given type on map."""
        npcs = self.get_service_npcs(service_type, map_name)
        if not npcs:
            return None

        nearest = None
        min_dist = float("inf")

        for npc in npcs:
            dist = ((npc.x - x) ** 2 + (npc.y - y) ** 2) ** 0.5
            if dist < min_dist:
                min_dist = dist
                nearest = npc

        return nearest