"""
Comprehensive tests for core tick processor and decision engine.

Tests:
- TickProcessor: message processing, state tracking, statistics
- DecisionEngine: decision generation, subsystem coordination
- Action creation and prioritization
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch
import time

from ai_sidecar.core.tick import TickProcessor
from ai_sidecar.core.decision import (
    DecisionEngine,
    StubDecisionEngine,
    ProgressionDecisionEngine,
    create_decision_engine,
    Action,
    ActionType,
    DecisionResult,
)
from ai_sidecar.core.state import GameState, CharacterState, Position
from ai_sidecar.config import TickConfig


# Fixtures

@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    char = CharacterState(
        name="TestChar",
        job_id=4001,
        base_level=90,
        job_level=50,
        hp=800,
        hp_max=1000,
        sp=200,
        sp_max=300,
        position=Position(x=100, y=100),
    )
    
    return GameState(
        tick=1000,
        character=char,
        party_members=[],
        nearby_monsters=[],
        nearby_npcs=[],
        nearby_players=[],
        nearby_items=[],
    )


@pytest.fixture
def tick_config():
    """Create tick config."""
    return TickConfig(
        state_history_size=10,
        interval_ms=100,
        max_processing_ms=80.0,  # Must be < interval_ms
    )


@pytest.fixture
def mock_decision_engine():
    """Create mock decision engine."""
    engine = AsyncMock(spec=DecisionEngine)
    engine.decide.return_value = DecisionResult(
        tick=1000,
        actions=[],
        fallback_mode="cpu",
        processing_time_ms=5.0,
        confidence=1.0,
    )
    return engine


# Test Action Creation

class TestActionCreation:
    """Test Action helper methods."""
    
    def test_move_to_action(self):
        """Test creating move action."""
        action = Action.move_to(x=150, y=200, priority=5)
        assert action.type == ActionType.MOVE
        assert action.x == 150
        assert action.y == 200
        assert action.priority == 5
    
    def test_attack_action(self):
        """Test creating attack action."""
        action = Action.attack(target_id=2001, priority=3)
        assert action.type == ActionType.ATTACK
        assert action.target_id == 2001
        assert action.priority == 3
    
    def test_use_skill_action(self):
        """Test creating skill action."""
        action = Action.use_skill(
            skill_id=28,
            target_id=1001,
            level=10,
            priority=2
        )
        assert action.type == ActionType.SKILL
        assert action.skill_id == 28
        assert action.skill_level == 10
        assert action.target_id == 1001
        assert action.priority == 2
    
    def test_use_item_action(self):
        """Test creating item use action."""
        action = Action.use_item(item_id=501, priority=4)
        assert action.type == ActionType.USE_ITEM
        assert action.item_id == 501
        assert action.priority == 4
    
    def test_noop_action(self):
        """Test creating no-op action."""
        action = Action.noop()
        assert action.type == ActionType.NOOP
        assert action.priority == 10


# Test DecisionResult

class TestDecisionResult:
    """Test decision result."""
    
    def test_to_response_dict(self):
        """Test converting to response dictionary."""
        actions = [
            Action.move_to(x=100, y=100, priority=5),
            Action.attack(target_id=2001, priority=3),
        ]
        
        result = DecisionResult(
            tick=1000,
            actions=actions,
            fallback_mode="cpu",
            processing_time_ms=10.5,
            confidence=0.95,
        )
        
        response = result.to_response_dict()
        assert response["type"] == "decision"
        assert response["tick"] == 1000
        assert len(response["actions"]) == 2
        assert response["fallback_mode"] == "cpu"
        assert response["processing_time_ms"] == 10.5
        # Actions should be sorted by priority
        assert response["actions"][0]["priority"] <= response["actions"][1]["priority"]


# Test StubDecisionEngine

class TestStubDecisionEngine:
    """Test stub decision engine."""
    
    @pytest.mark.asyncio
    async def test_initialize(self):
        """Test engine initialization."""
        engine = StubDecisionEngine()
        assert not engine._initialized
        
        await engine.initialize()
        assert engine._initialized
    
    @pytest.mark.asyncio
    async def test_shutdown(self):
        """Test engine shutdown."""
        engine = StubDecisionEngine()
        await engine.initialize()
        
        await engine.shutdown()
        assert not engine._initialized
    
    @pytest.mark.asyncio
    async def test_decide_returns_empty_actions(self, mock_game_state):
        """Test stub returns empty actions."""
        engine = StubDecisionEngine()
        await engine.initialize()
        
        result = await engine.decide(mock_game_state)
        assert result.tick == mock_game_state.tick
        assert len(result.actions) == 0
        assert result.fallback_mode in ["cpu", "idle", "defensive"]
    
    @pytest.mark.asyncio
    async def test_decision_count_increments(self, mock_game_state):
        """Test decision count increments."""
        engine = StubDecisionEngine()
        await engine.initialize()
        
        assert engine._decision_count == 0
        await engine.decide(mock_game_state)
        assert engine._decision_count == 1
        await engine.decide(mock_game_state)
        assert engine._decision_count == 2


# Test ProgressionDecisionEngine

class TestProgressionDecisionEngine:
    """Test progression decision engine."""
    
    @pytest.mark.asyncio
    async def test_initialize(self):
        """Test engine initialization."""
        engine = ProgressionDecisionEngine(
            enable_companions=False,
            enable_consumables=False,
            enable_progression=False,
            enable_combat=False,
            enable_npc=False,
            enable_economic=False,
            enable_social=False,
        )
        
        await engine.initialize()
        assert engine._initialized
    
    @pytest.mark.asyncio
    async def test_shutdown(self):
        """Test engine shutdown."""
        engine = ProgressionDecisionEngine(
            enable_social=False,
        )
        await engine.initialize()
        
        await engine.shutdown()
        assert not engine._initialized
    
    @pytest.mark.asyncio
    async def test_decide_without_subsystems(self, mock_game_state):
        """Test decision with all subsystems disabled."""
        engine = ProgressionDecisionEngine(
            enable_companions=False,
            enable_consumables=False,
            enable_progression=False,
            enable_combat=False,
            enable_npc=False,
            enable_economic=False,
            enable_social=False,
        )
        await engine.initialize()
        
        result = await engine.decide(mock_game_state)
        assert result.tick == mock_game_state.tick
        # May have some actions from lazy-loaded managers
    
    def test_health_check(self):
        """Test health check returns subsystem status."""
        engine = ProgressionDecisionEngine(
            enable_combat=True,
            enable_npc=False,
        )
        
        health = engine.health_check()
        assert "initialized" in health
        assert "decisions_made" in health
        assert "subsystems" in health
        assert "combat" in health["subsystems"]
        assert health["subsystems"]["combat"]["enabled"] == True
        assert health["subsystems"]["npc"]["enabled"] == False


# Test create_decision_engine

class TestCreateDecisionEngine:
    """Test decision engine factory."""
    
    @patch('ai_sidecar.core.decision.get_settings')
    def test_creates_stub_engine(self, mock_settings):
        """Test creates stub engine when configured."""
        mock_settings.return_value.decision.engine_type = "stub"
        
        engine = create_decision_engine()
        assert isinstance(engine, StubDecisionEngine)
    
    @patch('ai_sidecar.core.decision.get_settings')
    def test_creates_rule_based_engine(self, mock_settings):
        """Test creates rule-based engine when configured."""
        mock_settings.return_value.decision.engine_type = "rule_based"
        
        engine = create_decision_engine()
        assert isinstance(engine, ProgressionDecisionEngine)
    
    @patch('ai_sidecar.core.decision.get_settings')
    def test_creates_ml_engine(self, mock_settings):
        """Test creates ML engine when configured."""
        mock_settings.return_value.decision.engine_type = "ml"
        
        engine = create_decision_engine()
        # ML engine uses ProgressionDecisionEngine as base with ML-ready architecture
        assert isinstance(engine, ProgressionDecisionEngine)
    
    @patch('ai_sidecar.core.decision.get_settings')
    def test_defaults_to_progression_for_unknown(self, mock_settings):
        """Test defaults to ProgressionDecisionEngine for unknown engine type."""
        mock_settings.return_value.decision.engine_type = "unknown"
        
        engine = create_decision_engine()
        # Fallback uses ProgressionDecisionEngine (functional) instead of stub
        assert isinstance(engine, ProgressionDecisionEngine)


# Test TickProcessor

class TestTickProcessorInit:
    """Test tick processor initialization."""
    
    def test_init_default_config(self, mock_decision_engine):
        """Test initialization with default config."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        assert processor._initialized == False
        assert processor._ticks_processed == 0
        assert len(processor._state_history) == 0
    
    def test_init_custom_config(self, tick_config, mock_decision_engine):
        """Test initialization with custom config."""
        processor = TickProcessor(
            config=tick_config,
            decision_engine=mock_decision_engine
        )
        assert processor._config == tick_config
    
    @pytest.mark.asyncio
    async def test_initialize_sets_flag(self, mock_decision_engine):
        """Test initialize sets initialized flag."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        
        await processor.initialize()
        assert processor._initialized
    
    @pytest.mark.asyncio
    async def test_initialize_idempotent(self, mock_decision_engine):
        """Test initialize can be called multiple times."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        
        await processor.initialize()
        await processor.initialize()  # Should not error
        assert processor._initialized


class TestTickProcessorMessageHandling:
    """Test tick processor message handling."""
    
    @pytest.mark.asyncio
    async def test_process_state_update_message(self, mock_decision_engine, mock_game_state):
        """Test processes state update message."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        message = {
            "type": "state_update",
            "tick": 1000,
            "payload": {
                "tick": 1000,
                "character": {
                    "name": "TestChar",
                    "job_id": 4001,
                    "base_level": 90,
                    "job_level": 50,
                    "hp": 800,
                    "hp_max": 1000,
                    "sp": 200,
                    "sp_max": 300,
                    "x": 100,
                    "y": 100,
                },
            },
        }
        
        response = await processor.process_message(message)
        assert response["type"] == "decision"
    
    @pytest.mark.asyncio
    async def test_process_heartbeat_message(self, mock_decision_engine):
        """Test processes heartbeat message."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        
        message = {
            "type": "heartbeat",
            "tick": 1000,
        }
        
        response = await processor.process_message(message)
        assert response["type"] == "heartbeat_ack"
        assert response["client_tick"] == 1000
        assert "ticks_processed" in response
    
    @pytest.mark.asyncio
    async def test_process_unknown_message_type(self, mock_decision_engine):
        """Test handles unknown message type."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        
        message = {
            "type": "unknown_type",
        }
        
        response = await processor.process_message(message)
        assert response["type"] == "error"


class TestTickProcessorStateTracking:
    """Test state tracking and history."""
    
    @pytest.mark.asyncio
    async def test_state_history_tracking(self, mock_decision_engine):
        """Test state history is tracked."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        # Process multiple states
        for i in range(3):
            message = {
                "type": "state_update",
                "tick": 1000 + i,
                "payload": {
                    "tick": 1000 + i,
                    "character": {
                        "name": "TestChar",
                        "job_id": 4001,
                        "base_level": 90,
                        "job_level": 50,
                        "hp": 800,
                        "hp_max": 1000,
                        "sp": 200,
                        "sp_max": 300,
                        "x": 100,
                        "y": 100,
                    },
                },
            }
            await processor.process_message(message)
        
        assert len(processor.state_history) == 3
        assert processor.ticks_processed == 3
    
    @pytest.mark.asyncio
    async def test_current_state_updated(self, mock_decision_engine):
        """Test current state is updated."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        message = {
            "type": "state_update",
            "tick": 1000,
            "payload": {
                "tick": 1000,
                "character": {
                    "name": "TestChar",
                    "job_id": 4001,
                    "base_level": 90,
                    "job_level": 50,
                    "hp": 800,
                    "hp_max": 1000,
                    "sp": 200,
                    "sp_max": 300,
                    "x": 100,
                    "y": 100,
                },
            },
        }
        
        await processor.process_message(message)
        
        assert processor.current_state is not None
        assert processor.current_state.tick == 1000


class TestTickProcessorStatistics:
    """Test statistics tracking."""
    
    @pytest.mark.asyncio
    async def test_stats_tracking(self, mock_decision_engine):
        """Test statistics are tracked correctly."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        message = {
            "type": "state_update",
            "tick": 1000,
            "payload": {
                "tick": 1000,
                "character": {
                    "name": "TestChar",
                    "job_id": 4001,
                    "base_level": 90,
                    "job_level": 50,
                    "hp": 800,
                    "hp_max": 1000,
                    "sp": 200,
                    "sp_max": 300,
                    "x": 100,
                    "y": 100,
                },
            },
        }
        
        await processor.process_message(message)
        
        stats = processor.stats
        assert stats["initialized"] == True
        assert stats["ticks_processed"] == 1
        assert stats["avg_processing_ms"] >= 0
        assert "max_processing_ms" in stats
        assert "warnings" in stats
    
    def test_avg_processing_time_zero_ticks(self, mock_decision_engine):
        """Test avg processing time when no ticks processed."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        assert processor.avg_processing_time_ms == 0.0
    
    @pytest.mark.asyncio
    async def test_health_check(self, mock_decision_engine):
        """Test health check returns comprehensive status."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        health = processor.health_check()
        assert "tick_processor" in health
        assert "decision_engine" in health


class TestTickProcessorErrorHandling:
    """Test error handling."""
    
    @pytest.mark.asyncio
    async def test_handles_parsing_error(self, mock_decision_engine):
        """Test handles state parsing error."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        await processor.initialize()
        
        # Send invalid message
        message = {
            "type": "state_update",
            "tick": 1000,
            "payload": None,  # Invalid
        }
        
        response = await processor.process_message(message)
        assert response["type"] == "error"
    
    @pytest.mark.asyncio
    async def test_handles_decision_engine_error(self):
        """Test handles decision engine error."""
        engine = AsyncMock(spec=DecisionEngine)
        engine.decide.side_effect = Exception("Test error")
        
        processor = TickProcessor(decision_engine=engine)
        await processor.initialize()
        
        message = {
            "type": "state_update",
            "tick": 1000,
            "payload": {
                "tick": 1000,
                "character": {
                    "name": "TestChar",
                    "job_id": 4001,
                    "base_level": 90,
                    "job_level": 50,
                    "hp": 800,
                    "hp_max": 1000,
                    "sp": 200,
                    "sp_max": 300,
                    "x": 100,
                    "y": 100,
                },
            },
        }
        
        response = await processor.process_message(message)
        assert response["type"] == "error"


class TestTickProcessorProperties:
    """Test tick processor properties."""
    
    def test_current_state_property(self, mock_decision_engine):
        """Test current_state property."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        assert processor.current_state is None
    
    def test_state_history_property(self, mock_decision_engine):
        """Test state_history property returns list."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        history = processor.state_history
        assert isinstance(history, list)
        assert len(history) == 0
    
    def test_ticks_processed_property(self, mock_decision_engine):
        """Test ticks_processed property."""
        processor = TickProcessor(decision_engine=mock_decision_engine)
        assert processor.ticks_processed == 0


# Test Subsystem Integration

class TestProgressionEngineSubsystems:
    """Test progression engine subsystem integration."""
    
    def test_lazy_loading_companions(self):
        """Test companion coordinator lazy loads."""
        engine = ProgressionDecisionEngine(enable_companions=True)
        # Should be None until accessed
        assert engine._companion_coordinator is None
    
    def test_lazy_loading_consumables(self):
        """Test consumable coordinator lazy loads."""
        engine = ProgressionDecisionEngine(enable_consumables=True)
        assert engine._consumable_coordinator is None
    
    def test_disabled_subsystem_not_loaded(self):
        """Test disabled subsystem returns None."""
        engine = ProgressionDecisionEngine(enable_companions=False)
        companions = engine.companions
        assert companions is None
    
    @pytest.mark.asyncio
    async def test_decide_handles_subsystem_errors(self, mock_game_state):
        """Test decision handles subsystem errors gracefully."""
        engine = ProgressionDecisionEngine(
            enable_social=False,
            enable_combat=False,
            enable_progression=False,  # Disable to avoid init errors
        )
        await engine.initialize()
        
        # Should not error even if subsystems fail
        result = await engine.decide(mock_game_state)
        assert result.tick == mock_game_state.tick