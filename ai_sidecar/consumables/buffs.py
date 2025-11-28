"""
Buff Management System - P0 Critical Component.

Provides intelligent buff tracking, duration management, and automatic rebuffing
with priority-based decision making for Ragnarok Online.
"""

import json
from datetime import datetime, timedelta
from enum import Enum, IntEnum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class BuffCategory(str, Enum):
    """Categories of buffs in RO."""
    
    OFFENSIVE = "offensive"      # ATK, MATK, ASPD buffs
    DEFENSIVE = "defensive"      # DEF, MDEF, damage reduction
    UTILITY = "utility"          # Speed, cast time, aftercast delay
    SUSTAIN = "sustain"          # HP/SP regen, leech effects
    PARTY = "party"              # Buffs that affect party members
    SCROLL = "scroll"            # Consumable buff scrolls
    FOOD = "food"                # Food buffs (cooking, cash shop food)


class BuffSource(str, Enum):
    """Source of the buff."""
    
    SELF_SKILL = "self_skill"    # Own skill (Blessing, AGI Up)
    PARTY_SKILL = "party_skill"  # Party member's skill
    ITEM = "item"                # Consumable item (scrolls, food)
    EQUIPMENT = "equipment"      # Equipment effect (autocast)
    CARD = "card"                # Card effect
    NPC = "npc"                  # NPC buff (Kafra, Job Master)


class BuffPriority(IntEnum):
    """Priority for rebuffing decisions."""
    
    CRITICAL = 10     # Must have for survival (Kyrie, Safety Wall)
    HIGH = 7          # Very important (Blessing, Agi Up, Weapon Perfection)
    MEDIUM = 5        # Nice to have (Loud Exclamation, Gloria)
    LOW = 3           # Convenience (Increase HP Recovery)
    OPTIONAL = 1      # Only if nothing else to do


class BuffState(BaseModel):
    """Current state of a single buff."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    buff_id: str
    buff_name: str
    icon_id: Optional[int] = None
    category: BuffCategory
    source: BuffSource
    priority: BuffPriority
    
    # Duration tracking
    start_time: datetime
    base_duration_seconds: float
    remaining_seconds: float = Field(ge=0)
    
    # Effect details
    stat_bonuses: Dict[str, int] = Field(default_factory=dict)
    percentage_bonuses: Dict[str, float] = Field(default_factory=dict)
    special_effects: List[str] = Field(default_factory=list)
    
    # Rebuff configuration
    rebuff_threshold_seconds: float = Field(default=5.0, ge=0)
    auto_rebuff: bool = True
    rebuff_skill: Optional[str] = None
    rebuff_item: Optional[str] = None
    
    # Stacking info
    is_stackable: bool = False
    max_stacks: int = Field(default=1, ge=1)
    current_stacks: int = Field(default=1, ge=1)
    
    @property
    def is_expiring_soon(self) -> bool:
        """Check if buff is expiring soon and needs rebuff."""
        return self.remaining_seconds <= self.rebuff_threshold_seconds
    
    @property
    def is_expired(self) -> bool:
        """Check if buff has expired."""
        return self.remaining_seconds <= 0
    
    @property
    def duration_percentage(self) -> float:
        """Get remaining duration as percentage (0.0 to 1.0)."""
        if self.base_duration_seconds <= 0:
            return 0.0
        return max(0.0, min(1.0, self.remaining_seconds / self.base_duration_seconds))


class BuffSet(BaseModel):
    """A predefined set of buffs for a situation."""
    
    name: str
    description: str
    buffs: List[str] = Field(default_factory=list)
    situation: str
    priority_order: List[str] = Field(default_factory=list)


class RebuffAction(BaseModel):
    """Action to rebuff a buff."""
    
    buff_id: str
    buff_name: str
    method: str  # "skill" or "item"
    skill_name: Optional[str] = None
    item_name: Optional[str] = None
    priority: int
    sp_cost: int = 0


class BuffAction(BaseModel):
    """Generic buff application action."""
    
    action_type: str  # "apply_buff", "remove_buff", "rebuff"
    buff_name: str
    method: str = "skill"
    target: Optional[str] = None
    priority: int = 5


class BuffManager:
    """
    Intelligent buff tracking and management.
    
    Features:
    - Real-time duration tracking with server sync
    - Predictive rebuffing before expiration
    - Priority-based buff application order
    - Buff conflict detection (mutually exclusive buffs)
    - Party buff coordination
    - Emergency buff detection and instant rebuff
    """
    
    def __init__(self, data_path: Optional[Path] = None):
        """
        Initialize buff manager.
        
        Args:
            data_path: Path to buff data JSON file
        """
        self.log = structlog.get_logger(__name__)
        self.active_buffs: Dict[str, BuffState] = {}
        self.buff_sets: Dict[str, BuffSet] = {}
        self.buff_history: List[Tuple[str, datetime, str]] = []
        self.conflicting_buffs: Dict[str, Set[str]] = {}
        self.buff_database: Dict[str, Dict[str, Any]] = {}
        
        # Load buff database
        if data_path:
            self._load_buff_database(data_path)
        
        self.log.info("BuffManager initialized")
    
    def _load_buff_database(self, data_path: Path) -> None:
        """
        Load buff definitions from JSON file.
        
        Args:
            data_path: Path to buffs.json
        """
        try:
            with open(data_path, "r") as f:
                self.buff_database = json.load(f)
            
            # Build conflict mapping
            for buff_id, data in self.buff_database.items():
                conflicts = data.get("conflicts_with", [])
                if conflicts:
                    self.conflicting_buffs[buff_id] = set(conflicts)
            
            self.log.info(
                "Loaded buff database",
                buff_count=len(self.buff_database),
                conflicts=len(self.conflicting_buffs),
            )
        except Exception as e:
            self.log.error("Failed to load buff database", error=str(e))
    
    async def update_buff_timers(self, elapsed_seconds: float) -> None:
        """
        Update all buff durations.
        
        Args:
            elapsed_seconds: Time elapsed since last update
        """
        expired_buffs: List[str] = []
        
        for buff_id, buff in self.active_buffs.items():
            buff.remaining_seconds = max(0, buff.remaining_seconds - elapsed_seconds)
            
            if buff.is_expired:
                expired_buffs.append(buff_id)
                self.buff_history.append((buff_id, datetime.now(), "expired"))
        
        # Remove expired buffs
        for buff_id in expired_buffs:
            del self.active_buffs[buff_id]
            self.log.debug("Buff expired", buff_id=buff_id)
    
    async def check_rebuff_needs(
        self,
        available_sp: int = 0,
        in_combat: bool = False,
    ) -> List[BuffState]:
        """
        Get list of buffs that need rebuffing.
        
        Considers:
        - Priority order (critical first)
        - Available resources (SP, items)
        - Current combat state (don't rebuff mid-combat if risky)
        
        Args:
            available_sp: Current SP available for skills
            in_combat: Whether currently in combat
            
        Returns:
            List of buffs needing rebuff, sorted by priority
        """
        rebuff_needed: List[BuffState] = []
        
        for buff in self.active_buffs.values():
            if not buff.auto_rebuff:
                continue
            
            # Skip rebuffing in combat for low priority buffs
            if in_combat and buff.priority < BuffPriority.HIGH:
                continue
            
            if buff.is_expiring_soon:
                rebuff_needed.append(buff)
        
        # Sort by priority (highest first)
        rebuff_needed.sort(key=lambda b: b.priority, reverse=True)
        
        return rebuff_needed
    
    async def get_rebuff_action(
        self,
        buff: BuffState,
        available_sp: int = 0,
    ) -> Optional[RebuffAction]:
        """
        Determine how to rebuff.
        
        Considers:
        - Use skill if available and have SP
        - Use item if skill on cooldown
        - Request party member if party buff
        
        Args:
            buff: Buff that needs rebuffing
            available_sp: Current SP available
            
        Returns:
            Rebuff action or None if can't rebuff
        """
        # Try skill first
        if buff.rebuff_skill and available_sp > 0:
            # Estimate SP cost (would need skill database)
            estimated_sp = 20  # Placeholder
            
            if available_sp >= estimated_sp:
                return RebuffAction(
                    buff_id=buff.buff_id,
                    buff_name=buff.buff_name,
                    method="skill",
                    skill_name=buff.rebuff_skill,
                    priority=buff.priority,
                    sp_cost=estimated_sp,
                )
        
        # Try item as fallback
        if buff.rebuff_item:
            return RebuffAction(
                buff_id=buff.buff_id,
                buff_name=buff.buff_name,
                method="item",
                item_name=buff.rebuff_item,
                priority=buff.priority,
            )
        
        return None
    
    async def detect_buff_expiration(self) -> List[BuffState]:
        """
        Get buffs that just expired (for logging/alerting).
        
        Returns:
            List of recently expired buffs
        """
        # Check last few history entries
        recent_expirations: List[BuffState] = []
        cutoff = datetime.now() - timedelta(seconds=1)
        
        for buff_id, timestamp, action in reversed(self.buff_history[-10:]):
            if action == "expired" and timestamp >= cutoff:
                # Buff no longer in active, but we can reconstruct basic info
                if buff_id in self.buff_database:
                    data = self.buff_database[buff_id]
                    # Create minimal BuffState for reporting
                    recent_expirations.append(
                        BuffState(
                            buff_id=buff_id,
                            buff_name=data.get("display_name", buff_id),
                            category=BuffCategory(data.get("category", "utility")),
                            source=BuffSource(data.get("source", "self_skill")),
                            priority=BuffPriority(data.get("priority", 5)),
                            start_time=timestamp,
                            base_duration_seconds=0,
                            remaining_seconds=0,
                        )
                    )
        
        return recent_expirations
    
    async def calculate_buff_value(
        self,
        buff: BuffState,
        situation: str = "farming",
    ) -> float:
        """
        Calculate effective value of a buff for prioritization.
        
        Considers:
        - Current situation (farming vs MVP)
        - Character build synergy
        - Party composition
        
        Args:
            buff: Buff to evaluate
            situation: Current situation context
            
        Returns:
            Numeric value for prioritization
        """
        base_value = float(buff.priority)
        
        # Situation modifiers
        if situation == "mvp":
            if buff.category == BuffCategory.DEFENSIVE:
                base_value *= 1.5
        elif situation == "farming":
            if buff.category == BuffCategory.OFFENSIVE:
                base_value *= 1.3
        
        # Duration value (longer duration = more valuable to maintain)
        if buff.base_duration_seconds > 300:  # > 5 min
            base_value *= 1.2
        
        return base_value
    
    async def apply_buff_set(self, set_name: str) -> List[BuffAction]:
        """
        Apply a predefined buff set in optimal order.
        
        Args:
            set_name: Name of buff set to apply
            
        Returns:
            List of buff actions to execute
        """
        if set_name not in self.buff_sets:
            self.log.warning("Unknown buff set", set_name=set_name)
            return []
        
        buff_set = self.buff_sets[set_name]
        actions: List[BuffAction] = []
        
        # Use priority order if specified, otherwise use buffs list order
        order = buff_set.priority_order if buff_set.priority_order else buff_set.buffs
        
        for buff_name in order:
            # Skip if already active
            if buff_name in self.active_buffs:
                continue
            
            actions.append(
                BuffAction(
                    action_type="apply_buff",
                    buff_name=buff_name,
                    priority=5,
                )
            )
        
        return actions
    
    async def handle_buff_conflict(self, new_buff: str) -> Optional[str]:
        """
        Handle mutually exclusive buffs.
        
        Example: Agi Up vs Agi Down, Two-Hand Quicken vs One-Hand Quicken
        
        Args:
            new_buff: ID of new buff being applied
            
        Returns:
            Buff ID to remove if conflict exists, None otherwise
        """
        if new_buff not in self.conflicting_buffs:
            return None
        
        conflicts = self.conflicting_buffs[new_buff]
        
        # Check if any conflicting buff is active
        for buff_id in conflicts:
            if buff_id in self.active_buffs:
                self.log.info(
                    "Buff conflict detected",
                    new_buff=new_buff,
                    conflicting_buff=buff_id,
                )
                return buff_id
        
        return None
    
    def add_buff(
        self,
        buff_id: str,
        duration_seconds: float,
        source: BuffSource = BuffSource.SELF_SKILL,
    ) -> None:
        """
        Add a new active buff.
        
        Args:
            buff_id: Buff identifier
            duration_seconds: Buff duration
            source: Source of the buff
        """
        if buff_id not in self.buff_database:
            self.log.warning("Unknown buff", buff_id=buff_id)
            return
        
        data = self.buff_database[buff_id]
        
        buff_state = BuffState(
            buff_id=buff_id,
            buff_name=data.get("display_name", buff_id),
            category=BuffCategory(data.get("category", "utility")),
            source=source,
            priority=BuffPriority(data.get("priority", 5)),
            start_time=datetime.now(),
            base_duration_seconds=duration_seconds,
            remaining_seconds=duration_seconds,
            stat_bonuses=data.get("stat_bonuses", {}),
            percentage_bonuses=data.get("percentage_bonuses", {}),
            special_effects=data.get("special_effects", []),
            rebuff_skill=data.get("rebuff_skill"),
            rebuff_item=data.get("rebuff_item"),
        )
        
        self.active_buffs[buff_id] = buff_state
        self.buff_history.append((buff_id, datetime.now(), "applied"))
        
        self.log.debug(
            "Buff added",
            buff_id=buff_id,
            duration=duration_seconds,
            priority=buff_state.priority,
        )
    
    def remove_buff(self, buff_id: str) -> None:
        """
        Remove an active buff.
        
        Args:
            buff_id: Buff identifier to remove
        """
        if buff_id in self.active_buffs:
            del self.active_buffs[buff_id]
            self.buff_history.append((buff_id, datetime.now(), "removed"))
            self.log.debug("Buff removed", buff_id=buff_id)
    
    def get_active_buffs_summary(self) -> Dict[str, Any]:
        """
        Get summary of all active buffs.
        
        Returns:
            Dict with buff counts and details
        """
        return {
            "total_active": len(self.active_buffs),
            "by_category": self._count_by_category(),
            "expiring_soon": len([
                b for b in self.active_buffs.values() if b.is_expiring_soon
            ]),
            "critical_buffs": len([
                b for b in self.active_buffs.values()
                if b.priority == BuffPriority.CRITICAL
            ]),
        }
    
    def _count_by_category(self) -> Dict[str, int]:
        """Count active buffs by category."""
        counts: Dict[str, int] = {}
        for buff in self.active_buffs.values():
            counts[buff.category.value] = counts.get(buff.category.value, 0) + 1
        return counts