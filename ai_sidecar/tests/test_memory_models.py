"""
Tests for memory models.
"""

import pytest
from datetime import datetime, timedelta

from ai_sidecar.memory.models import (
    Memory,
    MemoryType,
    MemoryTier,
    MemoryImportance,
    MemoryQuery,
)


def test_memory_creation():
    """Test creating a memory."""
    memory = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Test memory",
        tags=["test"],
    )
    
    assert memory.memory_id is not None
    assert memory.memory_type == MemoryType.EVENT
    assert memory.tier == MemoryTier.WORKING
    assert memory.importance == MemoryImportance.NORMAL
    assert memory.strength == 1.0
    assert memory.access_count == 0


def test_memory_touch():
    """Test memory reinforcement on access."""
    memory = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Test memory",
    )
    
    original_strength = memory.strength
    memory.touch()
    
    assert memory.access_count == 1
    assert memory.strength >= original_strength


def test_memory_decay():
    """Test memory decay over time."""
    memory = Memory(
        memory_type=MemoryType.EVENT,
        importance=MemoryImportance.NORMAL,
        content={"test": "data"},
        summary="Test memory",
    )
    
    memory.apply_decay(1.0)  # 1 hour
    assert memory.strength < 1.0
    
    # Critical memories don't decay
    critical_memory = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.CRITICAL,
        content={"test": "data"},
        summary="Critical memory",
    )
    
    original_strength = critical_memory.strength
    critical_memory.apply_decay(10.0)
    assert critical_memory.strength == original_strength


def test_memory_should_forget():
    """Test memory forgetting threshold."""
    memory = Memory(
        memory_type=MemoryType.EVENT,
        content={"test": "data"},
        summary="Test memory",
    )
    
    assert not memory.should_forget
    
    memory.strength = 0.05
    assert memory.should_forget


def test_memory_query():
    """Test memory query model."""
    query = MemoryQuery(
        memory_types=[MemoryType.EVENT, MemoryType.DECISION],
        tags=["combat"],
        min_importance=MemoryImportance.NORMAL,
        min_strength=0.5,
        time_range_hours=24,
        limit=10,
    )
    
    assert len(query.memory_types) == 2
    assert "combat" in query.tags
    assert query.limit == 10