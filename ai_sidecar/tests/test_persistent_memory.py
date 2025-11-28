"""
Tests for persistent memory.
"""

import pytest
import tempfile
from pathlib import Path

from ai_sidecar.memory.models import Memory, MemoryType, MemoryImportance, MemoryQuery
from ai_sidecar.memory.persistent_memory import PersistentMemory


@pytest.fixture
async def persistent_memory():
    """Create temporary persistent memory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        pm = PersistentMemory(db_path=f"{tmpdir}/test_memory.db")
        await pm.initialize()
        yield pm
        await pm.close()


@pytest.mark.asyncio
async def test_initialize(persistent_memory):
    """Test database initialization."""
    # Database should be initialized by fixture
    assert persistent_memory._connection is not None


@pytest.mark.asyncio
async def test_store_and_retrieve(persistent_memory):
    """Test storing and retrieving memories."""
    memory = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.IMPORTANT,
        content={"pattern": "test"},
        summary="Test pattern",
        tags=["test"],
    )
    
    success = await persistent_memory.store(memory)
    assert success
    
    retrieved = await persistent_memory.retrieve(memory.memory_id)
    assert retrieved is not None
    assert retrieved.memory_id == memory.memory_id
    assert retrieved.memory_type == MemoryType.PATTERN


@pytest.mark.asyncio
async def test_query(persistent_memory):
    """Test querying memories."""
    # Store multiple memories
    for i in range(5):
        memory = Memory(
            memory_type=MemoryType.EVENT if i % 2 == 0 else MemoryType.DECISION,
            content={"index": i},
            summary=f"Memory {i}",
            tags=["test"],
        )
        await persistent_memory.store(memory)
    
    # Query for events only
    query = MemoryQuery(memory_types=[MemoryType.EVENT])
    results = await persistent_memory.query(query)
    
    assert len(results) == 3
    for r in results:
        assert r.memory_type == MemoryType.EVENT


@pytest.mark.asyncio
async def test_store_strategy(persistent_memory):
    """Test storing strategies."""
    success = await persistent_memory.store_strategy(
        strategy_id="combat:aggressive",
        strategy_type="combat",
        parameters={"aggression": 0.8},
        success_rate=0.75,
    )
    
    assert success
    
    # Retrieve best strategy
    best = await persistent_memory.get_best_strategy("combat")
    assert best is not None
    assert best["strategy_id"] == "combat:aggressive"
    assert best["success_rate"] == 0.75


@pytest.mark.asyncio
async def test_strategy_usage_count(persistent_memory):
    """Test strategy usage count increment."""
    # Store same strategy twice
    await persistent_memory.store_strategy(
        "test_strat", "test", {"param": 1}, 0.5
    )
    await persistent_memory.store_strategy(
        "test_strat", "test", {"param": 1}, 0.6
    )
    
    best = await persistent_memory.get_best_strategy("test")
    assert best["usage_count"] == 2