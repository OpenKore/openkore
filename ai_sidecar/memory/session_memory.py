"""
Session Memory implementation - Redis-backed fast storage.

Provides cross-session persistence with TTL-based expiration.
"""

import json
from typing import Dict, List, Optional

from ai_sidecar.memory.decision_models import DecisionRecord
from ai_sidecar.memory.models import Memory, MemoryImportance, MemoryTier, MemoryType
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class SessionMemory:
    """
    Session-level memory backed by DragonFlyDB/Redis.
    
    Features:
    - TTL-based expiration
    - Cross-session persistence
    - Type-based indexing
    - Decision history tracking
    """
    
    def __init__(self, connection_url: str = "redis://localhost:6379"):
        """
        Initialize session memory.
        
        Args:
            connection_url: Redis connection URL
        """
        self.connection_url = connection_url
        self._client = None
        self._prefix = "ro_ai:memory:"
        self._ttl_hours = 24  # Default TTL
    
    async def connect(self) -> bool:
        """
        Connect to DragonFlyDB/Redis.
        
        Returns:
            True if connected successfully
        """
        try:
            import redis.asyncio as aioredis
            
            self._client = aioredis.from_url(self.connection_url)
            await self._client.ping()
            logger.info("session_memory_connected", url=self.connection_url)
            return True
        except ImportError:
            logger.warning("redis not installed, session memory unavailable")
            return False
        except Exception as e:
            logger.warning("session_memory_connection_failed", error=str(e))
            return False
    
    async def store(self, memory: Memory) -> bool:
        """
        Store memory in session storage.
        
        Args:
            memory: Memory to store
        
        Returns:
            True if stored successfully
        """
        if not self._client:
            return False
        
        try:
            memory.tier = MemoryTier.SESSION
            key = f"{self._prefix}{memory.memory_id}"
            
            # Calculate TTL based on importance
            ttl_multiplier = {
                MemoryImportance.TRIVIAL: 0.5,
                MemoryImportance.NORMAL: 1.0,
                MemoryImportance.IMPORTANT: 3.0,
                MemoryImportance.CRITICAL: 24.0,
            }.get(memory.importance, 1.0)
            
            ttl_seconds = int(self._ttl_hours * ttl_multiplier * 3600)
            
            await self._client.setex(key, ttl_seconds, memory.model_dump_json())
            
            # Add to type index
            type_key = f"{self._prefix}type:{memory.memory_type.value}"
            await self._client.sadd(type_key, memory.memory_id)
            await self._client.expire(type_key, ttl_seconds)
            
            return True
        except Exception as e:
            logger.error("session_memory_store_failed", error=str(e))
            return False
    
    async def retrieve(self, memory_id: str) -> Optional[Memory]:
        """
        Retrieve memory from session storage.
        
        Args:
            memory_id: Memory ID to retrieve
        
        Returns:
            Memory if found, None otherwise
        """
        if not self._client:
            return None
        
        try:
            key = f"{self._prefix}{memory_id}"
            data = await self._client.get(key)
            if data:
                memory = Memory.model_validate_json(data)
                memory.touch()
                # Update in storage
                await self._client.set(key, memory.model_dump_json(), keepttl=True)
                return memory
            return None
        except Exception as e:
            logger.error("session_memory_retrieve_failed", error=str(e))
            return None
    
    async def query_by_type(
        self, memory_type: MemoryType, limit: int = 50
    ) -> List[Memory]:
        """
        Query memories by type.
        
        Args:
            memory_type: Type of memories to retrieve
            limit: Maximum number to return
        
        Returns:
            List of memories
        """
        if not self._client:
            return []
        
        try:
            type_key = f"{self._prefix}type:{memory_type.value}"
            memory_ids = await self._client.smembers(type_key)
            
            results = []
            for memory_id in list(memory_ids)[:limit]:
                memory_id_str = (
                    memory_id.decode() if isinstance(memory_id, bytes) else memory_id
                )
                memory = await self.retrieve(memory_id_str)
                if memory:
                    results.append(memory)
            
            return results
        except Exception as e:
            logger.error("session_memory_query_failed", error=str(e))
            return []
    
    async def get_decision_history(
        self, decision_type: str, limit: int = 20
    ) -> List[Dict]:
        """
        Get recent decisions of a specific type.
        
        Args:
            decision_type: Type of decisions to retrieve
            limit: Maximum number to return
        
        Returns:
            List of decision dictionaries
        """
        if not self._client:
            return []
        
        try:
            key = f"{self._prefix}decisions:{decision_type}"
            data = await self._client.lrange(key, 0, limit - 1)
            return [json.loads(d) for d in data]
        except Exception as e:
            logger.error("session_get_decision_history_failed", error=str(e))
            return []
    
    async def store_decision(self, record: DecisionRecord) -> bool:
        """
        Store a decision record.
        
        Args:
            record: Decision record to store
        
        Returns:
            True if stored successfully
        """
        if not self._client:
            return False
        
        try:
            key = f"{self._prefix}decisions:{record.decision_type}"
            await self._client.lpush(key, record.model_dump_json())
            await self._client.ltrim(key, 0, 99)  # Keep last 100
            await self._client.expire(key, self._ttl_hours * 3600)
            return True
        except Exception as e:
            logger.error("session_store_decision_failed", error=str(e))
            return False
    
    async def close(self) -> None:
        """Close Redis connection."""
        if self._client:
            await self._client.close()