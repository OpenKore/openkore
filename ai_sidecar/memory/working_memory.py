"""
Working Memory implementation - fast in-memory storage.

Provides O(1) access with LRU eviction and indexing for quick queries.
"""

import asyncio
from collections import OrderedDict
from datetime import datetime
from typing import Dict, List, Optional

from ai_sidecar.memory.models import (
    Memory,
    MemoryImportance,
    MemoryQuery,
    MemoryTier,
    MemoryType,
)
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class WorkingMemory:
    """
    Fast in-memory storage for current session.
    
    Features:
    - LRU eviction when at capacity
    - Quick access indices by type and tag
    - O(1) retrieval by ID
    - Thread-safe with asyncio.Lock
    """
    
    def __init__(self, max_size: int = 1000):
        """
        Initialize working memory.
        
        Args:
            max_size: Maximum number of memories to store
        """
        self.memories: OrderedDict[str, Memory] = OrderedDict()
        self.max_size = max_size
        self._lock = asyncio.Lock()
        
        # Quick access indices
        self._by_type: Dict[MemoryType, List[str]] = {}
        self._by_tag: Dict[str, List[str]] = {}
    
    async def store(self, memory: Memory) -> str:
        """
        Store a memory in working memory.
        
        Args:
            memory: Memory to store
        
        Returns:
            Memory ID
        """
        async with self._lock:
            # Evict if at capacity
            if len(self.memories) >= self.max_size:
                await self._evict_oldest()
            
            memory.tier = MemoryTier.WORKING
            self.memories[memory.memory_id] = memory
            
            # Update indices
            if memory.memory_type not in self._by_type:
                self._by_type[memory.memory_type] = []
            self._by_type[memory.memory_type].append(memory.memory_id)
            
            for tag in memory.tags:
                if tag not in self._by_tag:
                    self._by_tag[tag] = []
                self._by_tag[tag].append(memory.memory_id)
            
            return memory.memory_id
    
    async def retrieve(self, memory_id: str) -> Optional[Memory]:
        """
        Retrieve a memory by ID.
        
        Args:
            memory_id: Memory ID to retrieve
        
        Returns:
            Memory if found, None otherwise
        """
        async with self._lock:
            memory = self.memories.get(memory_id)
            if memory:
                memory.touch()
                # Move to end (most recently accessed)
                self.memories.move_to_end(memory_id)
            return memory
    
    async def query(self, query: MemoryQuery) -> List[Memory]:
        """
        Query memories by criteria.
        
        Args:
            query: Query parameters
        
        Returns:
            List of matching memories
        """
        results = []
        
        async with self._lock:
            for memory in self.memories.values():
                # Filter by type
                if query.memory_types and memory.memory_type not in query.memory_types:
                    continue
                
                # Filter by tags
                if query.tags and not any(t in memory.tags for t in query.tags):
                    continue
                
                # Filter by importance
                if query.min_importance:
                    importance_order = [
                        MemoryImportance.TRIVIAL,
                        MemoryImportance.NORMAL,
                        MemoryImportance.IMPORTANT,
                        MemoryImportance.CRITICAL,
                    ]
                    if importance_order.index(memory.importance) < importance_order.index(
                        query.min_importance
                    ):
                        continue
                
                # Filter by strength
                if memory.strength < query.min_strength:
                    continue
                
                # Filter by time
                if query.time_range_hours:
                    age = (datetime.now() - memory.created_at).total_seconds() / 3600
                    if age > query.time_range_hours:
                        continue
                
                results.append(memory)
                if len(results) >= query.limit:
                    break
        
        return results
    
    async def get_recent(self, count: int = 10) -> List[Memory]:
        """
        Get most recent memories.
        
        Args:
            count: Number of memories to return
        
        Returns:
            List of recent memories
        """
        async with self._lock:
            return list(self.memories.values())[-count:]
    
    async def get_candidates_for_consolidation(self) -> List[Memory]:
        """
        Get memories that should be moved to session memory.
        
        Returns:
            List of memories ready for consolidation
        """
        candidates = []
        async with self._lock:
            for memory in self.memories.values():
                # Important memories or frequently accessed
                if memory.importance in [
                    MemoryImportance.IMPORTANT,
                    MemoryImportance.CRITICAL,
                ]:
                    candidates.append(memory)
                elif memory.access_count >= 3:
                    candidates.append(memory)
        return candidates
    
    async def apply_decay(self) -> int:
        """
        Apply decay to all memories, remove forgotten ones.
        
        Returns:
            Count of forgotten memories
        """
        forgotten = 0
        async with self._lock:
            to_remove = []
            for memory_id, memory in self.memories.items():
                memory.apply_decay(0.5)  # Assume 30 min between decays
                if memory.should_forget:
                    to_remove.append(memory_id)
            
            for memory_id in to_remove:
                del self.memories[memory_id]
                forgotten += 1
        
        return forgotten
    
    async def _evict_oldest(self) -> None:
        """Evict oldest/weakest memory."""
        if not self.memories:
            return
        
        # Find weakest memory
        weakest_id = min(self.memories.keys(), key=lambda k: self.memories[k].strength)
        del self.memories[weakest_id]
    
    async def clear(self) -> None:
        """Clear all memories (for testing)."""
        async with self._lock:
            self.memories.clear()
            self._by_type.clear()
            self._by_tag.clear()
    
    def get_all(self) -> List[Memory]:
        """Get all memories (synchronous accessor for internal use)."""
        return list(self.memories.values())
    
    def is_full(self) -> bool:
        """Check if memory is at capacity (synchronous accessor)."""
        return len(self.memories) >= self.max_size
    
    async def size(self) -> int:
        """Get current memory count."""
        async with self._lock:
            return len(self.memories)