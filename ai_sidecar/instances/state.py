"""
Instance State Management System.

Manages real-time state throughout instance runs including progress tracking,
floor management, party coordination, and loot tracking.
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.instances.registry import InstanceDefinition

logger = structlog.get_logger(__name__)


class InstancePhase(str, Enum):
    """Current phase in instance."""
    
    NOT_STARTED = "not_started"
    ENTERING = "entering"
    IN_PROGRESS = "in_progress"
    BOSS_FIGHT = "boss_fight"
    CLEARING = "clearing"
    LOOTING = "looting"
    EXITING = "exiting"
    COMPLETED = "completed"
    FAILED = "failed"


class FloorState(BaseModel):
    """State of a single floor in an instance."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    floor_number: int = Field(ge=1)
    monsters_total: int = Field(default=0, ge=0)
    monsters_killed: int = Field(default=0, ge=0)
    boss_spawned: bool = False
    boss_killed: bool = False
    items_dropped: List[str] = Field(default_factory=list)
    time_started: Optional[datetime] = None
    time_completed: Optional[datetime] = None
    
    @property
    def is_cleared(self) -> bool:
        """Floor is considered cleared."""
        return self.boss_killed or (
            self.monsters_total > 0 and
            self.monsters_killed >= self.monsters_total
        )
    
    @property
    def progress_percent(self) -> float:
        """Progress through the floor."""
        if self.boss_killed:
            return 100.0
        
        if self.monsters_total == 0:
            return 0.0
        
        return (self.monsters_killed / self.monsters_total) * 100
    
    @property
    def duration_seconds(self) -> float:
        """Time spent on this floor."""
        if not self.time_started:
            return 0.0
        
        end_time = self.time_completed or datetime.now()
        return (end_time - self.time_started).total_seconds()


class InstanceState(BaseModel):
    """Current state of an active instance."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    instance_id: str
    instance_name: str
    phase: InstancePhase = InstancePhase.NOT_STARTED
    
    # Progress
    current_floor: int = Field(default=1, ge=1)
    total_floors: int = Field(default=1, ge=1)
    floors: Dict[int, FloorState] = Field(default_factory=dict)
    
    # Timing
    started_at: Optional[datetime] = None
    time_limit: Optional[datetime] = None
    last_activity: Optional[datetime] = None
    
    # Resources
    deaths: int = Field(default=0, ge=0)
    resurrections_used: int = Field(default=0, ge=0)
    items_consumed: Dict[str, int] = Field(default_factory=dict)
    
    # Party
    party_members: List[str] = Field(default_factory=list)
    party_alive_count: int = Field(default=0, ge=0)
    
    # Loot
    total_loot: List[str] = Field(default_factory=list)
    loot_value_estimate: int = Field(default=0, ge=0)
    
    @property
    def time_remaining_seconds(self) -> float:
        """Time remaining in instance."""
        if not self.time_limit:
            return float('inf')
        
        delta = self.time_limit - datetime.now()
        return max(0.0, delta.total_seconds())
    
    @property
    def time_remaining_percent(self) -> float:
        """Percentage of time remaining."""
        if not self.started_at or not self.time_limit:
            return 100.0
        
        total_seconds = (self.time_limit - self.started_at).total_seconds()
        if total_seconds <= 0:
            return 0.0
        
        remaining = self.time_remaining_seconds
        return (remaining / total_seconds) * 100
    
    @property
    def overall_progress(self) -> float:
        """Overall instance progress percentage."""
        if self.total_floors == 0:
            return 0.0
        
        cleared_count = sum(1 for f in self.floors.values() if f.is_cleared)
        return (cleared_count / self.total_floors) * 100
    
    @property
    def elapsed_seconds(self) -> float:
        """Time elapsed since instance started."""
        if not self.started_at:
            return 0.0
        
        return (datetime.now() - self.started_at).total_seconds()
    
    @property
    def is_time_critical(self) -> bool:
        """Check if time is becoming critical (< 20% remaining)."""
        return self.time_remaining_percent < 20.0
    
    def get_current_floor_state(self) -> Optional[FloorState]:
        """Get state of current floor."""
        return self.floors.get(self.current_floor)


class InstanceStateManager:
    """
    Manages state throughout an instance run.
    
    Features:
    - Real-time progress tracking
    - Time limit monitoring
    - Death tracking and recovery
    - Loot tracking
    - Party coordination state
    """
    
    def __init__(self):
        """Initialize state manager."""
        self.log = structlog.get_logger(__name__)
        self.current_instance: Optional[InstanceState] = None
        self.instance_history: List[InstanceState] = []
    
    async def start_instance(
        self,
        instance_def: InstanceDefinition,
        party_members: Optional[List[str]] = None
    ) -> InstanceState:
        """
        Initialize state for a new instance.
        
        Args:
            instance_def: Instance definition
            party_members: List of party member names
            
        Returns:
            New instance state
        """
        now = datetime.now()
        time_limit = now + timedelta(minutes=instance_def.time_limit_minutes)
        
        # Initialize floor states
        floors: Dict[int, FloorState] = {}
        for floor_num in range(1, instance_def.floors + 1):
            floors[floor_num] = FloorState(floor_number=floor_num)
        
        # Start first floor
        if floors:
            floors[1].time_started = now
        
        party_members = party_members or []
        
        self.current_instance = InstanceState(
            instance_id=instance_def.instance_id,
            instance_name=instance_def.instance_name,
            phase=InstancePhase.IN_PROGRESS,
            current_floor=1,
            total_floors=instance_def.floors,
            floors=floors,
            started_at=now,
            time_limit=time_limit,
            last_activity=now,
            party_members=party_members,
            party_alive_count=len(party_members),
        )
        
        self.log.info(
            "Instance started",
            instance=instance_def.instance_name,
            floors=instance_def.floors,
            time_limit_minutes=instance_def.time_limit_minutes,
            party_size=len(party_members)
        )
        
        return self.current_instance
    
    async def update_floor_progress(
        self,
        monsters_killed: int = 0,
        boss_killed: bool = False
    ) -> None:
        """
        Update progress on current floor.
        
        Args:
            monsters_killed: Number of monsters killed (increment)
            boss_killed: Whether boss was killed
        """
        if not self.current_instance:
            return
        
        floor_state = self.current_instance.get_current_floor_state()
        if not floor_state:
            return
        
        if monsters_killed > 0:
            floor_state.monsters_killed += monsters_killed
        
        if boss_killed:
            floor_state.boss_killed = True
            self.current_instance.phase = InstancePhase.CLEARING
        
        self.current_instance.last_activity = datetime.now()
        
        self.log.debug(
            "Floor progress updated",
            floor=self.current_instance.current_floor,
            killed=floor_state.monsters_killed,
            total=floor_state.monsters_total,
            boss_killed=boss_killed,
            progress=f"{floor_state.progress_percent:.1f}%"
        )
    
    async def advance_floor(self) -> bool:
        """
        Advance to next floor.
        
        Returns:
            False if no more floors
        """
        if not self.current_instance:
            return False
        
        # Mark current floor as completed
        current_floor_state = self.current_instance.get_current_floor_state()
        if current_floor_state:
            current_floor_state.time_completed = datetime.now()
        
        # Check if more floors
        if self.current_instance.current_floor >= self.current_instance.total_floors:
            self.log.info("All floors completed")
            return False
        
        # Advance to next floor
        self.current_instance.current_floor += 1
        next_floor_state = self.current_instance.get_current_floor_state()
        if next_floor_state:
            next_floor_state.time_started = datetime.now()
        
        self.current_instance.phase = InstancePhase.IN_PROGRESS
        self.current_instance.last_activity = datetime.now()
        
        self.log.info(
            "Advanced to next floor",
            floor=self.current_instance.current_floor,
            total=self.current_instance.total_floors
        )
        
        return True
    
    async def record_death(self, member_name: Optional[str] = None) -> None:
        """
        Record a death (self or party member).
        
        Args:
            member_name: Name of member who died (None = self)
        """
        if not self.current_instance:
            return
        
        self.current_instance.deaths += 1
        
        if member_name and member_name in self.current_instance.party_members:
            self.current_instance.party_alive_count = max(
                0,
                self.current_instance.party_alive_count - 1
            )
        
        self.log.warning(
            "Death recorded",
            member=member_name or "self",
            total_deaths=self.current_instance.deaths,
            party_alive=self.current_instance.party_alive_count
        )
    
    async def record_resurrection(self, member_name: Optional[str] = None) -> None:
        """
        Record a resurrection.
        
        Args:
            member_name: Name of member resurrected (None = self)
        """
        if not self.current_instance:
            return
        
        self.current_instance.resurrections_used += 1
        
        if member_name and member_name in self.current_instance.party_members:
            self.current_instance.party_alive_count = min(
                len(self.current_instance.party_members),
                self.current_instance.party_alive_count + 1
            )
        
        self.log.info(
            "Resurrection recorded",
            member=member_name or "self",
            resurrections=self.current_instance.resurrections_used
        )
    
    async def record_loot(self, items: List[str]) -> None:
        """
        Record items obtained.
        
        Args:
            items: List of item names
        """
        if not self.current_instance:
            return
        
        self.current_instance.total_loot.extend(items)
        
        # Add to current floor loot
        floor_state = self.current_instance.get_current_floor_state()
        if floor_state:
            floor_state.items_dropped.extend(items)
        
        self.log.info(
            "Loot recorded",
            items=items,
            total_items=len(self.current_instance.total_loot)
        )
    
    async def record_consumable_use(self, item_name: str, quantity: int = 1) -> None:
        """
        Record consumable item usage.
        
        Args:
            item_name: Name of consumable
            quantity: Amount used
        """
        if not self.current_instance:
            return
        
        current = self.current_instance.items_consumed.get(item_name, 0)
        self.current_instance.items_consumed[item_name] = current + quantity
    
    async def check_time_critical(self) -> bool:
        """
        Check if time is becoming critical.
        
        Returns:
            True if < 20% time remaining
        """
        if not self.current_instance:
            return False
        
        return self.current_instance.is_time_critical
    
    async def should_abort(self) -> tuple[bool, str]:
        """
        Determine if instance should be aborted.
        
        Returns:
            Tuple of (should_abort, reason)
        """
        if not self.current_instance:
            return False, ""
        
        # Too many deaths
        if self.current_instance.deaths >= 10:
            return True, "Too many deaths (10+)"
        
        # Party wiped
        if (len(self.current_instance.party_members) > 0 and
            self.current_instance.party_alive_count == 0):
            return True, "Party wiped"
        
        # Time critical with poor progress
        if self.current_instance.is_time_critical:
            if self.current_instance.overall_progress < 30.0:
                return True, "Time critical with low progress (<30%)"
        
        # Out of time
        if self.current_instance.time_remaining_seconds <= 0:
            return True, "Time limit exceeded"
        
        return False, ""
    
    async def complete_instance(self, success: bool = True) -> InstanceState:
        """
        Mark instance as completed and archive state.
        
        Args:
            success: Whether instance was completed successfully
            
        Returns:
            Final instance state
        """
        if not self.current_instance:
            raise ValueError("No active instance to complete")
        
        self.current_instance.phase = (
            InstancePhase.COMPLETED if success else InstancePhase.FAILED
        )
        
        # Mark current floor as completed if successful
        if success:
            floor_state = self.current_instance.get_current_floor_state()
            if floor_state and not floor_state.time_completed:
                floor_state.time_completed = datetime.now()
        
        self.log.info(
            "Instance completed",
            instance=self.current_instance.instance_name,
            success=success,
            elapsed=f"{self.current_instance.elapsed_seconds:.1f}s",
            progress=f"{self.current_instance.overall_progress:.1f}%",
            deaths=self.current_instance.deaths,
            loot_items=len(self.current_instance.total_loot)
        )
        
        # Archive to history
        self.instance_history.append(self.current_instance)
        
        # Limit history size
        if len(self.instance_history) > 50:
            self.instance_history = self.instance_history[-25:]
        
        completed = self.current_instance
        self.current_instance = None
        
        return completed
    
    def get_current_state(self) -> Optional[InstanceState]:
        """
        Get current instance state.
        
        Returns:
            Current state or None
        """
        return self.current_instance
    
    def get_history(self, limit: int = 10) -> List[InstanceState]:
        """
        Get instance history.
        
        Args:
            limit: Maximum number of records to return
            
        Returns:
            List of historical instance states
        """
        return self.instance_history[-limit:]