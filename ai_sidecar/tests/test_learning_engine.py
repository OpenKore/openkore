"""
Tests for learning engine.
"""

import pytest
import tempfile
from datetime import datetime

from ai_sidecar.memory.manager import MemoryManager
from ai_sidecar.memory.decision_models import DecisionContext, DecisionOutcome
from ai_sidecar.learning.engine import LearningEngine


@pytest.fixture
async def learning_engine():
    """Create learning engine with memory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        mm = MemoryManager(db_path=f"{tmpdir}/test_memory.db")
        await mm.initialize()
        le = LearningEngine(mm)
        yield le
        await mm.shutdown()


@pytest.mark.asyncio
async def test_record_decision(learning_engine):
    """Test recording a decision."""
    context = DecisionContext(
        game_state_snapshot={"hp": 100},
        available_options=["attack", "flee"],
        considered_factors=["hp_level", "monster_strength"],
        confidence_level=0.8,
        reasoning="HP is high, attack is safe",
    )
    
    record_id = await learning_engine.record_decision(
        "combat", {"action": "attack"}, context
    )
    
    assert record_id is not None
    assert record_id in learning_engine.pending_outcomes


@pytest.mark.asyncio
async def test_record_outcome(learning_engine):
    """Test recording decision outcome."""
    context = DecisionContext(
        game_state_snapshot={"hp": 100},
        available_options=["attack"],
        considered_factors=["hp_level"],
        confidence_level=0.9,
        reasoning="Safe to attack",
    )
    
    record_id = await learning_engine.record_decision(
        "combat", {"action": "attack", "strategy": "aggressive"}, context
    )
    
    await learning_engine.record_outcome(
        record_id, success=True, actual_result={"damage": 500}, reward_signal=0.8
    )
    
    # Should be removed from pending
    assert record_id not in learning_engine.pending_outcomes
    
    # Strategy should be tracked
    assert "combat:aggressive" in learning_engine.strategy_scores


@pytest.mark.asyncio
async def test_strategy_learning(learning_engine):
    """Test strategy success rate learning."""
    context = DecisionContext(
        game_state_snapshot={},
        available_options=["option1"],
        considered_factors=[],
        confidence_level=0.5,
        reasoning="Test",
    )
    
    # Record multiple successful decisions
    for i in range(5):
        record_id = await learning_engine.record_decision(
            "test", {"strategy": "winner"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=True, actual_result={}, reward_signal=1.0
        )
    
    # Record failed decision
    record_id = await learning_engine.record_decision(
        "test", {"strategy": "loser"}, context
    )
    await learning_engine.record_outcome(
        record_id, success=False, actual_result={}, reward_signal=-1.0
    )
    
    # Winner should have high success rate
    winner_scores = learning_engine.strategy_scores.get("test:winner")
    assert winner_scores is not None
    assert winner_scores["success_count"] == 5
    assert winner_scores["total_count"] == 5


@pytest.mark.asyncio
async def test_get_best_action(learning_engine):
    """Test getting best action based on learning."""
    context = DecisionContext(
        game_state_snapshot={},
        available_options=["a", "b"],
        considered_factors=[],
        confidence_level=0.5,
        reasoning="Test",
    )
    
    # Train strategy A with success
    for i in range(10):
        record_id = await learning_engine.record_decision(
            "combat", {"strategy": "strategyA"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=True, actual_result={}, reward_signal=0.5
        )
    
    # Train strategy B with failure
    for i in range(10):
        record_id = await learning_engine.record_decision(
            "combat", {"strategy": "strategyB"}, context
        )
        await learning_engine.record_outcome(
            record_id, success=False, actual_result={}, reward_signal=-0.5
        )
    
    options = [{"strategy": "strategyA"}, {"strategy": "strategyB"}]
    best_action, confidence = await learning_engine.get_best_action("combat", options)
    
    assert best_action["strategy"] == "strategyA"
    assert confidence > 0.5


@pytest.mark.asyncio
async def test_cleanup_pending(learning_engine):
    """Test cleanup of timed-out pending outcomes."""
    context = DecisionContext(
        game_state_snapshot={},
        available_options=["test"],
        considered_factors=[],
        confidence_level=0.5,
        reasoning="Test",
    )
    
    record_id = await learning_engine.record_decision("test", {}, context)
    
    # Manually set old timestamp
    learning_engine.pending_outcomes[record_id].timestamp = datetime.now()
    learning_engine._outcome_timeout = timedelta(seconds=0)  # Instant timeout
    
    cleaned = await learning_engine.cleanup_pending()
    assert cleaned >= 1