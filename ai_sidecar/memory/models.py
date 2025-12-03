"""
Memory models for the three-tier memory system.

Defines data structures for memories, queries, and consolidation.
"""

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Optional

import hashlib
from pydantic import BaseModel, Field, field_validator


class MemoryTier(str, Enum):
    """Memory storage tiers with different access speeds."""
    
    WORKING = "working"      # RAM - current session, ~100ms access
    SESSION = "session"      # DragonFlyDB/Redis - fast, ~1ms access
    PERSISTENT = "persistent"  # SQLite/OpenMemory - slow, ~10ms access


class MemoryType(str, Enum):
    """Types of memories stored in the system."""
    
    EVENT = "event"           # What happened (combat, NPC interaction)
    DECISION = "decision"     # What we decided and why
    OUTCOME = "outcome"       # Results of decisions
    PATTERN = "pattern"       # Recognized patterns
    COMBAT_PATTERN = "combat_pattern"  # Combat-specific patterns
    STRATEGY = "strategy"     # Learned strategies
    ENTITY = "entity"         # Players, monsters, NPCs we've interacted with
    LOCATION = "location"     # Map areas and their properties
    ECONOMIC = "economic"     # Price history, market patterns
    SHORT_TERM = "short_term" # Temporary memories for current session
    FACT = "fact"             # Factual information


class MemoryImportance(str, Enum):
    """Importance levels for memory retention and decay."""
    
    TRIVIAL = "trivial"       # Decay in minutes
    NORMAL = "normal"         # Decay in hours
    IMPORTANT = "important"   # Decay in days
    CRITICAL = "critical"     # Never decay


class Memory(BaseModel):
    """
    Individual memory unit in the three-tier system.
    
    Memories have content, metadata, relationships, and decay properties.
    """
    
    memory_id: str = Field(
        default_factory=lambda: hashlib.md5(
            str(datetime.now()).encode()
        ).hexdigest()[:16]
    )
    memory_type: MemoryType
    tier: MemoryTier = MemoryTier.WORKING
    importance: MemoryImportance = MemoryImportance.NORMAL
    
    # Content - can be string or dict for flexibility
    content: str | Dict[str, Any] | None = Field(default=None)
    summary: str = Field(default="")
    context: Dict[str, Any] = Field(default_factory=dict)
    
    @field_validator('content', mode='before')
    @classmethod
    def default_content_from_summary(cls, v, info):
        """Default content to summary if not provided."""
        if v is None and 'summary' in info.data:
            return info.data['summary']
        return v if v is not None else ""
    
    # Metadata
    created_at: datetime = Field(default_factory=datetime.now)
    accessed_at: datetime = Field(default_factory=datetime.now)
    access_count: int = 0
    
    # Relationships
    related_memories: List[str] = Field(default_factory=list)  # Memory IDs
    tags: List[str] = Field(default_factory=list)
    
    # Decay properties
    decay_rate: float = 0.1  # Per hour
    strength: float = 1.0    # 0-1, decays over time
    
    def touch(self) -> None:
        """Update access timestamp and count, reinforcing memory."""
        self.accessed_at = datetime.now()
        self.access_count += 1
        # Reinforce memory on access
        self.strength = min(1.0, self.strength + 0.1)
    
    def apply_decay(self, hours_elapsed: float) -> None:
        """
        Apply time-based decay to memory strength.
        
        Args:
            hours_elapsed: Hours since last decay application
        """
        if self.importance == MemoryImportance.CRITICAL:
            return  # Critical memories don't decay
        
        decay_multiplier = {
            MemoryImportance.TRIVIAL: 3.0,
            MemoryImportance.NORMAL: 1.0,
            MemoryImportance.IMPORTANT: 0.3,
        }.get(self.importance, 1.0)
        
        self.strength -= self.decay_rate * decay_multiplier * hours_elapsed
        self.strength = max(0.0, self.strength)
    
    @property
    def should_forget(self) -> bool:
        """Check if memory should be forgotten (strength too low)."""
        return self.strength < 0.1


class MemoryQuery(BaseModel):
    """Query parameters for memory retrieval across tiers."""
    
    memory_types: List[MemoryType] = Field(default_factory=list)
    tags: List[str] = Field(default_factory=list)
    min_importance: Optional[MemoryImportance] = None
    min_strength: float = 0.0
    time_range_hours: Optional[float] = None
    limit: int = 50


class MemoryConsolidation(BaseModel):
    """Record of memory consolidation between tiers."""
    
    source_tier: MemoryTier
    target_tier: MemoryTier
    memory_ids: List[str]
    consolidated_at: datetime = Field(default_factory=datetime.now)
    reason: str