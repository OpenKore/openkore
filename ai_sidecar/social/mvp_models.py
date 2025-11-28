"""
MVP hunting data models for social features.

Defines Pydantic v2 models for MVP boss tracking, spawn timers,
hunting strategies, and drop management in Ragnarok Online.
"""

from datetime import datetime, timedelta
from typing import Literal

from pydantic import BaseModel, Field

from ai_sidecar.social.party_models import PartyRole


class MVPBoss(BaseModel):
    """MVP boss with spawn information and attributes."""
    
    monster_id: int = Field(description="Monster database ID")
    name: str = Field(description="Boss name")
    base_level: int = Field(ge=1, le=999, description="Boss level")
    hp: int = Field(ge=1, description="Boss HP")
    
    # Spawn info
    spawn_maps: list[str] = Field(description="Maps where boss spawns")
    spawn_time_min: int = Field(
        ge=0,
        description="Minimum spawn time in minutes"
    )
    spawn_time_max: int = Field(
        ge=0,
        description="Maximum spawn time in minutes"
    )
    spawn_variance: int = Field(
        default=10,
        ge=0,
        description="Spawn time variance in minutes"
    )
    
    # Drops
    mvp_drops: list[tuple[int, float]] = Field(
        default_factory=list,
        description="MVP drops as (item_id, drop_rate%)"
    )
    card_id: int | None = Field(default=None, description="Card ID if drops card")
    card_rate: float = Field(
        default=0.01,
        ge=0.0,
        le=100.0,
        description="Card drop rate percentage"
    )
    
    # Combat info
    element: str = Field(default="neutral", description="Boss element")
    race: str = Field(default="demon", description="Boss race")
    size: str = Field(default="large", description="Boss size")
    recommended_level: int = Field(
        default=99,
        ge=1,
        le=999,
        description="Recommended player level"
    )
    recommended_party_size: int = Field(
        default=3,
        ge=1,
        le=12,
        description="Recommended party size"
    )
    danger_rating: int = Field(
        default=5,
        ge=1,
        le=10,
        description="Danger rating (1=easy, 10=extreme)"
    )
    
    @property
    def is_high_value(self) -> bool:
        """Check if MVP has high-value drops."""
        return self.card_id is not None or len(self.mvp_drops) > 3
    
    @property
    def average_spawn_time(self) -> int:
        """Get average spawn time in minutes."""
        return (self.spawn_time_min + self.spawn_time_max) // 2


class MVPSpawnRecord(BaseModel):
    """Record of MVP spawn/death for timer tracking."""
    
    monster_id: int = Field(description="Monster ID")
    map_name: str = Field(description="Map where killed")
    killed_at: datetime = Field(description="Timestamp of death")
    killed_by: str | None = Field(default=None, description="Who got MVP credit")
    next_spawn_earliest: datetime = Field(
        description="Earliest possible next spawn"
    )
    next_spawn_latest: datetime = Field(
        description="Latest possible next spawn"
    )
    confirmed: bool = Field(
        default=False,
        description="Is spawn time confirmed (vs estimated)"
    )
    
    @property
    def is_spawn_window_active(self) -> bool:
        """Check if currently in spawn window."""
        now = datetime.now()
        return self.next_spawn_earliest <= now <= self.next_spawn_latest
    
    @property
    def minutes_until_spawn(self) -> int:
        """Get minutes until earliest spawn (negative if window started)."""
        now = datetime.now()
        delta = self.next_spawn_earliest - now
        return int(delta.total_seconds() / 60)
    
    @property
    def spawn_window_expired(self) -> bool:
        """Check if spawn window has passed."""
        return datetime.now() > self.next_spawn_latest


class MVPHuntingStrategy(BaseModel):
    """Strategy for hunting a specific MVP."""
    
    target_mvp: MVPBoss = Field(description="Target MVP boss")
    party_composition: dict[PartyRole, int] = Field(
        description="Required party composition (role -> count)"
    )
    approach_strategy: Literal["camp", "check_rotation", "follow_timer"] = Field(
        description="Hunting approach strategy"
    )
    priority_drops: list[int] = Field(
        default_factory=list,
        description="Item IDs to prioritize (e.g., valuable drops)"
    )
    abort_conditions: list[str] = Field(
        default_factory=list,
        description="Conditions that trigger hunt abort"
    )
    
    # Tactical settings
    preferred_spawn_map: str | None = Field(
        default=None,
        description="Preferred map if boss spawns on multiple"
    )
    backup_maps: list[str] = Field(
        default_factory=list,
        description="Backup maps to check"
    )
    max_wait_time: int = Field(
        default=60,
        ge=0,
        description="Max minutes to wait at spawn point"
    )
    
    def get_spawn_map(self) -> str:
        """Get the spawn map to use for hunting."""
        if self.preferred_spawn_map and self.preferred_spawn_map in self.target_mvp.spawn_maps:
            return self.preferred_spawn_map
        return self.target_mvp.spawn_maps[0] if self.target_mvp.spawn_maps else ""
    
    def is_party_ready(self, party_roles: dict[PartyRole, int]) -> bool:
        """Check if party meets composition requirements."""
        for role, required_count in self.party_composition.items():
            actual_count = party_roles.get(role, 0)
            if actual_count < required_count:
                return False
        return True


class MVPTracker(BaseModel):
    """Tracks MVP spawns and deaths across the server."""
    
    records: dict[int, list[MVPSpawnRecord]] = Field(
        default_factory=dict,
        description="Spawn records per monster_id"
    )
    known_locations: dict[int, list[tuple[str, int, int]]] = Field(
        default_factory=dict,
        description="Known spawn locations per monster_id (map, x, y)"
    )
    
    def add_record(self, record: MVPSpawnRecord) -> None:
        """Add a new spawn record."""
        if record.monster_id not in self.records:
            self.records[record.monster_id] = []
        
        self.records[record.monster_id].append(record)
        
        # Keep only last 10 records per MVP
        if len(self.records[record.monster_id]) > 10:
            self.records[record.monster_id] = self.records[record.monster_id][-10:]
    
    def get_latest_record(self, monster_id: int) -> MVPSpawnRecord | None:
        """Get most recent spawn record for an MVP."""
        if monster_id not in self.records or not self.records[monster_id]:
            return None
        return max(self.records[monster_id], key=lambda r: r.killed_at)
    
    def get_spawn_window(self, monster_id: int) -> tuple[datetime, datetime] | None:
        """Get expected spawn window for an MVP."""
        record = self.get_latest_record(monster_id)
        if record is None:
            return None
        return (record.next_spawn_earliest, record.next_spawn_latest)
    
    def is_spawn_window_active(self, monster_id: int) -> bool:
        """Check if MVP's spawn window is currently active."""
        record = self.get_latest_record(monster_id)
        return record is not None and record.is_spawn_window_active
    
    def get_upcoming_spawns(self, within_minutes: int = 30) -> list[tuple[int, MVPSpawnRecord]]:
        """
        Get MVPs expected to spawn within the specified time window.
        
        Returns:
            List of (monster_id, spawn_record) tuples
        """
        upcoming = []
        cutoff_time = datetime.now() + timedelta(minutes=within_minutes)
        
        for monster_id, records in self.records.items():
            latest = self.get_latest_record(monster_id)
            if latest and not latest.spawn_window_expired:
                if latest.next_spawn_earliest <= cutoff_time:
                    upcoming.append((monster_id, latest))
        
        # Sort by earliest spawn time
        upcoming.sort(key=lambda x: x[1].next_spawn_earliest)
        return upcoming
    
    def add_location(self, monster_id: int, map_name: str, x: int, y: int) -> None:
        """Record a known spawn location."""
        if monster_id not in self.known_locations:
            self.known_locations[monster_id] = []
        
        location = (map_name, x, y)
        if location not in self.known_locations[monster_id]:
            self.known_locations[monster_id].append(location)


class MVPDatabase:
    """In-memory database of MVP boss definitions."""
    
    def __init__(self) -> None:
        self._mvps: dict[int, MVPBoss] = {}
    
    def add(self, mvp: MVPBoss) -> None:
        """Add an MVP to the database."""
        self._mvps[mvp.monster_id] = mvp
    
    def get(self, monster_id: int) -> MVPBoss | None:
        """Get MVP by monster ID."""
        return self._mvps.get(monster_id)
    
    def get_all(self) -> list[MVPBoss]:
        """Get all MVPs."""
        return list(self._mvps.values())
    
    def get_by_name(self, name: str) -> MVPBoss | None:
        """Get MVP by name (case-insensitive)."""
        name_lower = name.lower()
        for mvp in self._mvps.values():
            if mvp.name.lower() == name_lower:
                return mvp
        return None
    
    def get_by_map(self, map_name: str) -> list[MVPBoss]:
        """Get all MVPs that spawn on a specific map."""
        return [mvp for mvp in self._mvps.values() if map_name in mvp.spawn_maps]
    
    def load_from_dict(self, data: dict[str, dict]) -> None:
        """Load MVPs from dictionary (typically from JSON)."""
        for monster_id_str, mvp_data in data.items():
            try:
                monster_id = int(monster_id_str)
                mvp_data_copy = mvp_data.copy()
                mvp_data_copy["monster_id"] = monster_id
                mvp = MVPBoss(**mvp_data_copy)
                self.add(mvp)
            except (ValueError, TypeError) as e:
                # Skip invalid entries
                continue