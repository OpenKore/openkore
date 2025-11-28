"""
Memory system for AI Sidecar.

Three-tier memory architecture:
- Working Memory: Fast RAM storage (~100ms access)
- Session Memory: DragonFlyDB/Redis (~1ms access)
- Persistent Memory: SQLite (~10ms access)
"""

from .models import (
    Memory,
    MemoryType,
    MemoryTier,
    MemoryImportance,
    MemoryQuery,
    MemoryConsolidation,
)
from .decision_models import (
    DecisionContext,
    DecisionOutcome,
    DecisionRecord,
    ExperienceReplay,
)
from .working_memory import WorkingMemory
from .session_memory import SessionMemory
from .persistent_memory import PersistentMemory
from .manager import MemoryManager

__all__ = [
    "Memory",
    "MemoryType",
    "MemoryTier",
    "MemoryImportance",
    "MemoryQuery",
    "MemoryConsolidation",
    "DecisionContext",
    "DecisionOutcome",
    "DecisionRecord",
    "ExperienceReplay",
    "WorkingMemory",
    "SessionMemory",
    "PersistentMemory",
    "MemoryManager",
]