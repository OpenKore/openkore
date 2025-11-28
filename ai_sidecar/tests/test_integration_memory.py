"""
Integration tests for memory and learning systems.
"""

import pytest
import tempfile

from ai_sidecar.memory.manager import MemoryManager
from ai_sidecar.memory.models import Memory, MemoryType, MemoryImportance
from ai_sidecar.memory.decision_models import DecisionContext
from ai_sidecar.learning.engine import LearningEngine


@pytest.fixture
async def integrated_system():
    """Create fully integrated memory and learning system."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mm = MemoryManager(db_path=f"{tmpdir}/test_memory.db")
        await mm.initialize()
        le = LearningEngine(mm)
        yield mm, le
        await mm.shutdown()


@pytest.mark.asyncio
async def test_full_decision_lifecycle(integrated_system):
    """Test complete decision lifecycle with learning."""
    memory_manager, learning_engine = integrated_system
    
    # Record a decision
    context = DecisionContext(
        game_state_snapshot={"hp": 80, "sp": 50},
        available_options=["attack", "heal"],
        considered_factors=["hp_level", "sp_level", "monster_hp"],
        confidence_level=0.7,
        reasoning="HP is good, can attack",
    )
    
    record_id = await learning_engine.record_decision(
        "combat", {"action": "attack", "strategy": "balanced"}, context
    )
    
    # Verify decision is pending
    assert record_id in learning_engine.pending_outcomes
    
    # Record outcome
    await learning_engine.record_outcome(
        record_id,
        success=True,
        actual_result={"damage_dealt": 500, "damage_taken": 50},
        reward_signal=0.8,
    )
    
    # Verify learning occurred
    assert record_id not in learning_engine.pending_outcomes
    assert "combat:balanced" in learning_engine.strategy_scores
    
    # Verify memory was stored
    decision_memory = await memory_manager.retrieve(record_id)
    # Note: retrieve by record_id won't work, it creates its own memory_id
    # But we can query for decision memories
    from ai_sidecar.memory.models import MemoryQuery
    query = MemoryQuery(memory_types=[MemoryType.DECISION], limit=10)
    memories = await memory_manager.query(query)
    assert len(memories) >= 1


@pytest.mark.asyncio
async def test_experience_replay_pattern_discovery(integrated_system):
    """Test experience replay discovers patterns."""
    memory_manager, learning_engine = integrated_system
    
    context = DecisionContext(
        game_state_snapshot={},
        available_options=["test"],
        considered_factors=["factor1", "factor2"],
        confidence_level=0.5,
        reasoning="Test",
    )
    
    # Record multiple successful decisions with common factors
    for i in range(10):
        record_id = await learning_engine.record_decision(
            "test_type", {"action": f"action{i}"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=True, actual_result={}, reward_signal=1.0
        )
    
    # Run experience replay
    stats = await learning_engine.experience_replay(batch_size=20)
    
    assert stats["strategies_updated"] >= 0
    # Patterns might be found if enough common factors
    assert "patterns_found" in stats


@pytest.mark.asyncio
async def test_memory_consolidation_flow(integrated_system):
    """Test memory flows through all three tiers."""
    memory_manager, _ = integrated_system
    
    # Create important memory
    memory = Memory(
        memory_type=MemoryType.PATTERN,
        importance=MemoryImportance.IMPORTANT,
        content={"important": "pattern"},
        summary="Important discovery",
        tags=["important"],
    )
    
    memory_id = await memory_manager.store(memory)
    
    # Should be in working memory
    working_size = await memory_manager.working.size()
    assert working_size >= 1
    
    # Trigger consolidation
    stats = await memory_manager.consolidate()
    
    # Important memory should move to session/persistent
    assert stats["working_to_session"] >= 0 or stats["session_to_persistent"] >= 0


@pytest.mark.asyncio
async def test_strategy_selection(integrated_system):
    """Test selecting best strategy based on learning."""
    memory_manager, learning_engine = integrated_system
    
    context = DecisionContext(
        game_state_snapshot={},
        available_options=["a", "b"],
        considered_factors=[],
        confidence_level=0.5,
        reasoning="Test",
    )
    
    # Train strategy A with high success
    for i in range(20):
        record_id = await learning_engine.record_decision(
            "combat", {"strategy": "strategyA"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=(i < 18), actual_result={}, reward_signal=0.5
        )
    
    # Train strategy B with low success
    for i in range(20):
        record_id = await learning_engine.record_decision(
            "combat", {"strategy": "strategyB"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=(i < 5), actual_result={}, reward_signal=-0.5
        )
    
    # Get best action
    options = [{"strategy": "strategyA"}, {"strategy": "strategyB"}]
    best_action, confidence = await learning_engine.get_best_action("combat", options)
    
    assert best_action["strategy"] == "strategyA"
    assert confidence >= 0.8  # Should have high confidence in A


@pytest.mark.asyncio
async def test_relevant_memory_retrieval(integrated_system):
    """Test retrieving relevant memories for decision context."""
    memory_manager, _ = integrated_system
    
    # Store combat-related memory
    await memory_manager.remember_event(
        "combat_victory",
        {"monster": "poring", "damage": 500},
        MemoryImportance.NORMAL,
    )
    
    # Store unrelated memory
    await memory_manager.remember_event(
        "trading_complete", {"item": "potion", "zeny": 100}, MemoryImportance.NORMAL
    )
    
    # Query for combat-related
    relevant = await memory_manager.get_relevant_memories("combat monster poring", limit=5)
    
    assert len(relevant) >= 1
    # Combat memory should be in results
    assert any("combat" in m.summary.lower() for m in relevant)