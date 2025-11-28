"""
Persistent Memory implementation - SQLite-backed long-term storage.

Provides permanent storage for important memories, strategies, and learning.
"""

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
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


class PersistentMemory:
    """
    Long-term persistent memory using SQLite.
    
    Features:
    - Permanent storage for important memories
    - Strategy learning and performance tracking
    - Entity relationship tracking
    - Query optimization with indices
    """
    
    def __init__(self, db_path: str = "data/memory.db"):
        """
        Initialize persistent memory.
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection: Optional[sqlite3.Connection] = None
    
    async def initialize(self) -> bool:
        """
        Initialize database schema.
        
        Returns:
            True if initialized successfully
        """
        try:
            self._connection = sqlite3.connect(str(self.db_path))
            self._connection.row_factory = sqlite3.Row
            
            cursor = self._connection.cursor()
            
            # Memories table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS memories (
                    memory_id TEXT PRIMARY KEY,
                    memory_type TEXT NOT NULL,
                    importance TEXT NOT NULL,
                    content TEXT NOT NULL,
                    summary TEXT NOT NULL,
                    context TEXT,
                    tags TEXT,
                    created_at TEXT NOT NULL,
                    accessed_at TEXT NOT NULL,
                    access_count INTEGER DEFAULT 0,
                    strength REAL DEFAULT 1.0,
                    related_memories TEXT
                )
            """)
            
            # Decisions table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS decisions (
                    record_id TEXT PRIMARY KEY,
                    decision_type TEXT NOT NULL,
                    action_taken TEXT NOT NULL,
                    context TEXT NOT NULL,
                    outcome TEXT,
                    lesson_learned TEXT,
                    timestamp TEXT NOT NULL,
                    success INTEGER
                )
            """)
            
            # Strategies table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS strategies (
                    strategy_id TEXT PRIMARY KEY,
                    strategy_type TEXT NOT NULL,
                    parameters TEXT NOT NULL,
                    success_rate REAL DEFAULT 0.5,
                    usage_count INTEGER DEFAULT 0,
                    last_updated TEXT NOT NULL,
                    active INTEGER DEFAULT 1
                )
            """)
            
            # Entity memories table (players, NPCs, monsters)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS entities (
                    entity_id TEXT PRIMARY KEY,
                    entity_type TEXT NOT NULL,
                    name TEXT NOT NULL,
                    properties TEXT,
                    first_seen TEXT NOT NULL,
                    last_seen TEXT NOT NULL,
                    interaction_count INTEGER DEFAULT 0,
                    sentiment REAL DEFAULT 0.0
                )
            """)
            
            # Create indices
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_memories_type ON memories(memory_type)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_memories_created ON memories(created_at)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_decisions_type ON decisions(decision_type)"
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_strategies_type ON strategies(strategy_type)"
            )
            
            self._connection.commit()
            logger.info("persistent_memory_initialized", db_path=str(self.db_path))
            return True
        except Exception as e:
            logger.error("persistent_memory_init_failed", error=str(e))
            return False
    
    async def store(self, memory: Memory) -> bool:
        """
        Store memory persistently.
        
        Args:
            memory: Memory to store
        
        Returns:
            True if stored successfully
        """
        if not self._connection:
            return False
        
        try:
            memory.tier = MemoryTier.PERSISTENT
            cursor = self._connection.cursor()
            
            cursor.execute(
                """
                INSERT OR REPLACE INTO memories 
                (memory_id, memory_type, importance, content, summary, context, 
                 tags, created_at, accessed_at, access_count, strength, related_memories)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
                (
                    memory.memory_id,
                    memory.memory_type.value,
                    memory.importance.value,
                    json.dumps(memory.content),
                    memory.summary,
                    json.dumps(memory.context),
                    json.dumps(memory.tags),
                    memory.created_at.isoformat(),
                    memory.accessed_at.isoformat(),
                    memory.access_count,
                    memory.strength,
                    json.dumps(memory.related_memories),
                ),
            )
            
            self._connection.commit()
            return True
        except Exception as e:
            logger.error("persistent_memory_store_failed", error=str(e))
            return False
    
    async def retrieve(self, memory_id: str) -> Optional[Memory]:
        """
        Retrieve memory from persistent storage.
        
        Args:
            memory_id: Memory ID to retrieve
        
        Returns:
            Memory if found, None otherwise
        """
        if not self._connection:
            return None
        
        try:
            cursor = self._connection.cursor()
            cursor.execute("SELECT * FROM memories WHERE memory_id = ?", (memory_id,))
            row = cursor.fetchone()
            
            if row:
                memory = self._row_to_memory(row)
                
                # Update access
                memory.touch()
                cursor.execute(
                    """
                    UPDATE memories SET accessed_at = ?, access_count = ?
                    WHERE memory_id = ?
                """,
                    (memory.accessed_at.isoformat(), memory.access_count, memory_id),
                )
                self._connection.commit()
                
                return memory
            return None
        except Exception as e:
            logger.error("persistent_memory_retrieve_failed", error=str(e))
            return None
    
    async def query(self, query: MemoryQuery) -> List[Memory]:
        """
        Query memories by criteria.
        
        Args:
            query: Query parameters
        
        Returns:
            List of matching memories
        """
        if not self._connection:
            return []
        
        try:
            cursor = self._connection.cursor()
            
            sql = "SELECT * FROM memories WHERE 1=1"
            params = []
            
            if query.memory_types:
                placeholders = ",".join("?" * len(query.memory_types))
                sql += f" AND memory_type IN ({placeholders})"
                params.extend([t.value for t in query.memory_types])
            
            if query.min_strength > 0:
                sql += " AND strength >= ?"
                params.append(query.min_strength)
            
            if query.time_range_hours:
                cutoff = (
                    datetime.now() - timedelta(hours=query.time_range_hours)
                ).isoformat()
                sql += " AND created_at >= ?"
                params.append(cutoff)
            
            sql += " ORDER BY accessed_at DESC LIMIT ?"
            params.append(query.limit)
            
            cursor.execute(sql, params)
            rows = cursor.fetchall()
            
            return [self._row_to_memory(row) for row in rows]
        except Exception as e:
            logger.error("persistent_memory_query_failed", error=str(e))
            return []
    
    async def store_strategy(
        self,
        strategy_id: str,
        strategy_type: str,
        parameters: Dict,
        success_rate: float = 0.5,
    ) -> bool:
        """
        Store or update a strategy.
        
        Args:
            strategy_id: Unique strategy identifier
            strategy_type: Type of strategy
            parameters: Strategy parameters
            success_rate: Current success rate
        
        Returns:
            True if stored successfully
        """
        if not self._connection:
            return False
        
        try:
            cursor = self._connection.cursor()
            cursor.execute(
                """
                INSERT OR REPLACE INTO strategies 
                (strategy_id, strategy_type, parameters, success_rate, usage_count, last_updated, active)
                VALUES (?, ?, ?, ?, COALESCE((SELECT usage_count FROM strategies WHERE strategy_id = ?), 0) + 1, ?, 1)
            """,
                (
                    strategy_id,
                    strategy_type,
                    json.dumps(parameters),
                    success_rate,
                    strategy_id,
                    datetime.now().isoformat(),
                ),
            )
            self._connection.commit()
            return True
        except Exception as e:
            logger.error("persistent_store_strategy_failed", error=str(e))
            return False
    
    async def get_best_strategy(self, strategy_type: str) -> Optional[Dict]:
        """
        Get the best performing strategy of a type.
        
        Args:
            strategy_type: Type of strategy to retrieve
        
        Returns:
            Strategy data if found
        """
        if not self._connection:
            return None
        
        try:
            cursor = self._connection.cursor()
            cursor.execute(
                """
                SELECT * FROM strategies 
                WHERE strategy_type = ? AND active = 1
                ORDER BY success_rate DESC, usage_count DESC
                LIMIT 1
            """,
                (strategy_type,),
            )
            row = cursor.fetchone()
            
            if row:
                return {
                    "strategy_id": row["strategy_id"],
                    "parameters": json.loads(row["parameters"]),
                    "success_rate": row["success_rate"],
                    "usage_count": row["usage_count"],
                }
            return None
        except Exception as e:
            logger.error("persistent_get_best_strategy_failed", error=str(e))
            return None
    
    def _row_to_memory(self, row) -> Memory:
        """
        Convert database row to Memory object.
        
        Args:
            row: SQLite row object
        
        Returns:
            Memory instance
        """
        return Memory(
            memory_id=row["memory_id"],
            memory_type=MemoryType(row["memory_type"]),
            tier=MemoryTier.PERSISTENT,
            importance=MemoryImportance(row["importance"]),
            content=json.loads(row["content"]),
            summary=row["summary"],
            context=json.loads(row["context"]),
            tags=json.loads(row["tags"]),
            created_at=datetime.fromisoformat(row["created_at"]),
            accessed_at=datetime.fromisoformat(row["accessed_at"]),
            access_count=row["access_count"],
            strength=row["strength"],
            related_memories=json.loads(row["related_memories"]),
        )
    
    async def close(self) -> None:
        """Close database connection."""
        if self._connection:
            self._connection.close()