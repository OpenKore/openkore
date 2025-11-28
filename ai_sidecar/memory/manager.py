"""
Memory Manager - orchestrates three-tier memory system.

Coordinates Working, Session, and Persistent memory tiers.
"""

from datetime import datetime
from typing import Dict, List, Optional

from ai_sidecar.memory.decision_models import DecisionRecord
from ai_sidecar.memory.models import (
    Memory,
    MemoryImportance,
    MemoryQuery,
    MemoryType,
)
from ai_sidecar.memory.persistent_memory import PersistentMemory
from ai_sidecar.memory.session_memory import SessionMemory
from ai_sidecar.memory.working_memory import WorkingMemory
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class MemoryManager:
    """
    Orchestrates three-tier memory system.
    
    Provides unified interface for memory storage and retrieval,
    automatic consolidation, and decay management.
    """
    
    def __init__(
        self, redis_url: Optional[str] = None, db_path: str = "data/memory.db"
    ):
        """
        Initialize memory manager.
        
        Args:
            redis_url: Redis connection URL (None for local only)
            db_path: Path to SQLite database
        """
        self.working = WorkingMemory()
        self.session = SessionMemory(redis_url or "redis://localhost:6379")
        self.persistent = PersistentMemory(db_path)
        
        self._consolidation_interval = 300  # 5 minutes
        self._last_consolidation = datetime.now()
    
    async def initialize(self) -> bool:
        """
        Initialize all memory tiers.
        
        Returns:
            True if persistent memory initialized (session is optional)
        """
        session_ok = await self.session.connect()
        persistent_ok = await self.persistent.initialize()
        
        if not session_ok:
            logger.warning(
                "session_memory_unavailable", msg="Falling back to working memory only"
            )
        
        return persistent_ok
    
    async def store(self, memory: Memory, immediate_persist: bool = False) -> str:
        """
        Store a memory, starting in working memory.
        
        Args:
            memory: Memory to store
            immediate_persist: If True, store directly to persistent memory
        
        Returns:
            Memory ID
        """
        memory_id = await self.working.store(memory)
        
        # Critical memories go straight to persistent
        if memory.importance == MemoryImportance.CRITICAL or immediate_persist:
            await self.persistent.store(memory)
        
        return memory_id
    
    async def retrieve(self, memory_id: str) -> Optional[Memory]:
        """
        Retrieve memory from any tier.
        
        Checks working -> session -> persistent, promoting as needed.
        
        Args:
            memory_id: Memory ID to retrieve
        
        Returns:
            Memory if found, None otherwise
        """
        # Try working memory first
        memory = await self.working.retrieve(memory_id)
        if memory:
            return memory
        
        # Try session memory
        memory = await self.session.retrieve(memory_id)
        if memory:
            # Promote to working memory
            await self.working.store(memory)
            return memory
        
        # Try persistent memory
        memory = await self.persistent.retrieve(memory_id)
        if memory:
            # Promote to working memory
            await self.working.store(memory)
            return memory
        
        return None
    
    async def query(self, query: MemoryQuery) -> List[Memory]:
        """
        Query memories across all tiers.
        
        Args:
            query: Query parameters
        
        Returns:
            List of matching memories
        """
        results = []
        seen_ids = set()
        
        # Query working memory
        working_results = await self.working.query(query)
        for m in working_results:
            results.append(m)
            seen_ids.add(m.memory_id)
        
        # Query session memory if needed
        if len(results) < query.limit:
            for memory_type in query.memory_types:
                session_results = await self.session.query_by_type(
                    memory_type, query.limit - len(results)
                )
                for m in session_results:
                    if m.memory_id not in seen_ids:
                        results.append(m)
                        seen_ids.add(m.memory_id)
        
        # Query persistent memory if needed
        if len(results) < query.limit:
            persistent_results = await self.persistent.query(query)
            for m in persistent_results:
                if m.memory_id not in seen_ids:
                    results.append(m)
                    seen_ids.add(m.memory_id)
        
        return results[: query.limit]
    
    async def remember_event(
        self, event_type: str, details: Dict, importance: MemoryImportance = MemoryImportance.NORMAL
    ) -> str:
        """
        Convenience method to remember an event.
        
        Args:
            event_type: Type of event
            details: Event details
            importance: Memory importance level
        
        Returns:
            Memory ID
        """
        memory = Memory(
            memory_type=MemoryType.EVENT,
            importance=importance,
            content={"event_type": event_type, "details": details},
            summary=f"{event_type}: {str(details)[:100]}",
            tags=[event_type],
        )
        return await self.store(memory)
    
    async def remember_decision(self, record: DecisionRecord) -> str:
        """
        Remember a decision for learning.
        
        Args:
            record: Decision record to store
        
        Returns:
            Memory ID
        """
        memory = Memory(
            memory_type=MemoryType.DECISION,
            importance=MemoryImportance.NORMAL,
            content=record.model_dump(),
            summary=f"Decision: {record.decision_type}",
            tags=[record.decision_type, "decision"],
        )
        
        # Also store in session for quick access
        await self.session.store_decision(record)
        
        return await self.store(memory)
    
    async def get_relevant_memories(
        self, context: str, limit: int = 10
    ) -> List[Memory]:
        """
        Get memories relevant to a context (simple keyword matching).
        
        Args:
            context: Context string to match against
            limit: Maximum memories to return
        
        Returns:
            List of relevant memories
        """
        # Split context into keywords
        keywords = context.lower().split()
        
        query = MemoryQuery(min_strength=0.3, limit=limit * 3)  # Get more to filter
        
        candidates = await self.query(query)
        
        # Score by keyword matches
        scored = []
        for memory in candidates:
            score = 0
            content_str = str(memory.content).lower()
            summary_str = memory.summary.lower()
            
            for kw in keywords:
                if kw in content_str:
                    score += 1
                if kw in summary_str:
                    score += 2
                if kw in memory.tags:
                    score += 3
            
            if score > 0:
                scored.append((score, memory))
        
        scored.sort(key=lambda x: x[0], reverse=True)
        return [m for _, m in scored[:limit]]
    
    async def consolidate(self) -> Dict[str, int]:
        """
        Consolidate memories between tiers.
        
        Returns:
            Statistics about consolidation
        """
        stats = {"working_to_session": 0, "session_to_persistent": 0, "decayed": 0}
        
        # Apply decay first
        stats["decayed"] = await self.working.apply_decay()
        
        # Working -> Session
        candidates = await self.working.get_candidates_for_consolidation()
        for memory in candidates:
            if await self.session.store(memory):
                stats["working_to_session"] += 1
        
        # Important/Critical -> Persistent
        for memory in candidates:
            if memory.importance in [
                MemoryImportance.IMPORTANT,
                MemoryImportance.CRITICAL,
            ]:
                if await self.persistent.store(memory):
                    stats["session_to_persistent"] += 1
        
        self._last_consolidation = datetime.now()
        logger.info("memory_consolidation_complete", **stats)
        
        return stats
    
    async def tick(self) -> None:
        """Periodic maintenance tick."""
        now = datetime.now()
        if (now - self._last_consolidation).total_seconds() > self._consolidation_interval:
            await self.consolidate()
    
    async def shutdown(self) -> None:
        """Shutdown memory manager and close connections."""
        await self.session.close()
        await self.persistent.close()