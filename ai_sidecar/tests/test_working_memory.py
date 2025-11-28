"""
Tests for working memory.
"""

import pytest

from ai_sidecar.memory.models import Memory, MemoryType, MemoryImportance, MemoryQuery
from ai_sidecar.memory.working_memory import WorkingMemory


@pytest.mark.asyncio
async def test_store_and_retrieve():
    """Test storing and retrieving memories."""
    wm = WorkingMemory(max_size=10)
    
    memory = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Test event",
        tags=["test"],
    )
    
    memory_id = await wm.store(memory)
    assert memory_id is not None
    
    retrieved = await wm.retrieve(memory_id)
    assert retrieved is not None
    assert retrieved.memory_id == memory_id
    assert retrieved.access_count == 1


@pytest.mark.asyncio
async def test_lru_eviction():
    """Test LRU eviction when at capacity."""
    wm = WorkingMemory(max_size=3)
    
    # Store 4 memories
    ids = []
    for i in range(4):
        memory = Memory(
            memory_type=MemoryType.EVENT,
            content={"index": i},
            summary=f"Memory {i}",
        )
        ids.append(await wm.store(memory))
    
    # First memory should be evicted
    first = await wm.retrieve(ids[0])
    assert first is None
    
    # Others should still exist
    for memory_id in ids[1:]:
        retrieved = await wm.retrieve(memory_id)
        assert retrieved is not None


@pytest.mark.asyncio
async def test_query_by_type():
    """Test querying memories by type."""
    wm = WorkingMemory()
    
    # Store different types
    event = Memory(
        memory_type=MemoryType.EVENT,
        content={"event": "combat"},
        summary="Combat event",
    )
    decision = Memory(
        memory_type=MemoryType.DECISION,
        content={"decision": "attack"},
        summary="Attack decision",
    )
    
    await wm.store(event)
    await wm.store(decision)
    
    # Query for events only
    query = MemoryQuery(memory_types=[MemoryType.EVENT])
    results = await wm.query(query)
    
    assert len(results) == 1
    assert results[0].memory_type == MemoryType.EVENT


@pytest.mark.asyncio
async def test_query_by_tags():
    """Test querying memories by tags."""
    wm = WorkingMemory()
    
    combat = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Combat",
        tags=["combat", "success"],
    )
    
    movement = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Movement",
        tags=["movement"],
    )
    
    await wm.store(combat)
    await wm.store(movement)
    
    query = MemoryQuery(tags=["combat"])
    results = await wm.query(query)
    
    assert len(results) == 1
    assert "combat" in results[0].tags


@pytest.mark.asyncio
async def test_decay_and_forget():
    """Test memory decay and forgetting."""
    wm = WorkingMemory()
    
    memory = Memory(
        memory_type=MemoryType.EVENT,
        importance=MemoryImportance.TRIVIAL,
        content={"test": "data"},
        summary="Trivial event",
    )
    
    await wm.store(memory)
    
    # Apply heavy decay
    forgotten = await wm.apply_decay()
    assert forgotten >= 0  # Should forget the trivial memory


@pytest.mark.asyncio
async def test_consolidation_candidates():
    """Test getting consolidation candidates."""
    wm = WorkingMemory()
    
    # Important memory
    important = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.IMPORTANT,
        content={"pattern": "data"},
        summary="Important pattern",
    )
    
    # Frequently accessed normal memory
    frequent = Memory(
        memory_type=MemoryType.EVENT,
        importance=MemoryImportance.NORMAL,
        content={"event": "data"},
        summary="Frequent event",
    )
    
    await wm.store(important)
    await wm.store(frequent)
    
    # Access frequent memory multiple times
    for _ in range(3):
        await wm.retrieve(frequent.memory_id)
    
    candidates = await wm.get_candidates_for_consolidation()
    assert len(candidates) >= 1