"""
Tests for memory manager (three-tier coordination).
"""

import pytest
import tempfile

from ai_sidecar.memory.models import Memory, MemoryType, MemoryImportance, MemoryQuery
from ai_sidecar.memory.manager import MemoryManager


@pytest.fixture
async def memory_manager():
    """Create memory manager for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mm = MemoryManager(db_path=f"{tmpdir}/test_memory.db")
        await mm.initialize()
        yield mm
        await mm.shutdown()


@pytest.mark.asyncio
async def test_store_and_retrieve(memory_manager):
    """Test storing and retrieving across tiers."""
    memory = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Test event",
        tags=["test"],
    )
    
    memory_id = await memory_manager.store(memory)
    assert memory_id is not None
    
    # Should retrieve from working memory
    retrieved = await memory_manager.retrieve(memory_id)
    assert retrieved is not None
    assert retrieved.memory_id == memory_id


@pytest.mark.asyncio
async def test_critical_immediate_persist(memory_manager):
    """Test critical memories go straight to persistent storage."""
    memory = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.CRITICAL,
        content={"critical": "pattern"},
        summary="Critical pattern",
    )
    
    memory_id = await memory_manager.store(memory)
    
    # Should be in persistent memory
    persistent_result = await memory_manager.persistent.retrieve(memory_id)
    assert persistent_result is not None


@pytest.mark.asyncio
async def test_remember_event(memory_manager):
    """Test convenience method for remembering events."""
    memory_id = await memory_manager.remember_event(
        "combat_start", {"monster_id": 123}, MemoryImportance.NORMAL
    )
    
    assert memory_id is not None
    
    retrieved = await memory_manager.retrieve(memory_id)
    assert retrieved.memory_type == MemoryType.EVENT


@pytest.mark.asyncio
async def test_query_across_tiers(memory_manager):
    """Test querying memories across all tiers."""
    # Store memories
    for i in range(5):
        memory = Memory(
            memory_type=MemoryType.EVENT,
            content={"index": i},
            summary=f"Event {i}",
            tags=["test"],
        )
        await memory_manager.store(memory)
    
    # Query
    query = MemoryQuery(memory_types=[MemoryType.EVENT], limit=10)
    results = await memory_manager.query(query)
    
    assert len(results) == 5


@pytest.mark.asyncio
async def test_consolidation(memory_manager):
    """Test memory consolidation between tiers."""
    # Store important memory
    memory = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.IMPORTANT,
        content={"pattern": "data"},
        summary="Important pattern",
    )
    
    await memory_manager.store(memory)
    
    # Run consolidation
    stats = await memory_manager.consolidate()
    
    assert "working_to_session" in stats
    assert "session_to_persistent" in stats
    assert "decayed" in stats


@pytest.mark.asyncio
async def test_relevant_memories(memory_manager):
    """Test getting relevant memories by context."""
    # Store memories with different content
    combat = Memory(
        memory_type=MemoryType.EVENT,
        content={"combat": "data"},
        summary="Combat with monster",
        tags=["combat", "monster"],
    )
    
    trading = Memory(
        memory_type=MemoryType.ECONOMIC,
        content={"trading": "data"},
        summary="Trading at NPC",
        tags=["trading", "npc"],
    )
    
    await memory_manager.store(combat)
    await memory_manager.store(trading)
    
    # Query for combat-related memories
    relevant = await memory_manager.get_relevant_memories("combat monster", limit=5)
    
    assert len(relevant) >= 1
    # Combat memory should score higher
    assert relevant[0].memory_type == MemoryType.EVENT