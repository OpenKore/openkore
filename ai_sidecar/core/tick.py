"""
Tick processor for AI Sidecar.

Manages the game tick processing cycle, coordinating state updates
and decision generation.
"""

import time
from collections import deque
from typing import Any

from ai_sidecar.config import get_settings, TickConfig
from ai_sidecar.core.state import GameState, parse_game_state
from ai_sidecar.core.decision import DecisionEngine, DecisionResult, create_decision_engine
from ai_sidecar.utils.logging import get_logger, bind_context, clear_context

logger = get_logger(__name__)


class TickProcessor:
    """
    Processes game ticks and generates AI decisions.
    
    Maintains state history and coordinates with the decision engine.
    """
    
    def __init__(
        self,
        config: TickConfig | None = None,
        decision_engine: DecisionEngine | None = None,
    ) -> None:
        """
        Initialize the tick processor.
        
        Args:
            config: Tick configuration. If None, uses default from settings.
            decision_engine: Decision engine to use. If None, creates based on config.
        """
        self._config = config or get_settings().tick
        self._engine = decision_engine or create_decision_engine()
        
        # State history (circular buffer)
        self._state_history: deque[GameState] = deque(
            maxlen=self._config.state_history_size
        )
        
        # Current state
        self._current_state: GameState | None = None
        self._last_tick: int = 0
        
        # Statistics
        self._ticks_processed: int = 0
        self._total_processing_time_ms: float = 0.0
        self._max_processing_time_ms: float = 0.0
        self._warnings_issued: int = 0
        
        # Initialized flag
        self._initialized = False
        
        logger.info(
            "Tick processor created",
            history_size=self._config.state_history_size,
            max_processing_ms=self._config.max_processing_ms,
        )
    
    async def initialize(self) -> None:
        """Initialize the tick processor and decision engine."""
        if self._initialized:
            return
        
        logger.info("Initializing tick processor")
        await self._engine.initialize()
        self._initialized = True
        logger.info("Tick processor initialized")
    
    async def shutdown(self) -> None:
        """Shutdown the tick processor."""
        if not self._initialized:
            return
        
        logger.info(
            "Shutting down tick processor",
            ticks_processed=self._ticks_processed,
            avg_processing_ms=self.avg_processing_time_ms,
        )
        
        await self._engine.shutdown()
        self._initialized = False
    
    async def process_message(self, message: dict[str, Any]) -> dict[str, Any]:
        """
        Process an incoming message and return a response.
        
        This is the main entry point called by the ZMQ server.
        
        Args:
            message: Raw message dict from OpenKore.
        
        Returns:
            Response dict to send back.
        """
        msg_type = message.get("type", "unknown")
        
        if msg_type == "state_update":
            return await self._process_state_update(message)
        elif msg_type == "heartbeat":
            # Heartbeats are handled by ZMQ server
            return self._create_heartbeat_response(message)
        else:
            logger.warning("Unknown message type", type=msg_type)
            return self._create_error_response(
                "unknown_message_type",
                f"Unknown message type: {msg_type}",
            )
    
    async def _process_state_update(self, message: dict[str, Any]) -> dict[str, Any]:
        """
        Process a state update message.
        
        Parses the game state, runs the decision engine, and returns actions.
        """
        start_time = time.perf_counter()
        tick = message.get("tick", 0)
        
        # Bind tick to logging context
        bind_context(tick=tick)
        
        try:
            # Parse game state
            state = parse_game_state(message.get("payload", message))
            
            # Update internal state
            self._update_state(state)
            
            # Generate decision
            decision = await self._engine.decide(state)
            
            # Calculate processing time
            processing_time_ms = (time.perf_counter() - start_time) * 1000
            decision.processing_time_ms = processing_time_ms
            
            # Update statistics
            self._update_stats(processing_time_ms)
            
            # Check for timing warnings
            if processing_time_ms > self._config.max_processing_ms:
                self._warnings_issued += 1
                logger.warning(
                    "Tick processing exceeded time limit",
                    processing_ms=processing_time_ms,
                    limit_ms=self._config.max_processing_ms,
                )
            
            logger.debug(
                "Tick processed",
                tick=tick,
                processing_ms=round(processing_time_ms, 2),
                actions=len(decision.actions),
            )
            
            return decision.to_response_dict()
            
        except Exception as e:
            logger.exception("Error processing state update", error=str(e))
            return self._create_error_response("processing_error", str(e))
        finally:
            clear_context()
    
    def _update_state(self, state: GameState) -> None:
        """Update internal state tracking."""
        # Check for tick regression (server reset?)
        if state.tick < self._last_tick:
            logger.warning(
                "Tick regression detected",
                current=state.tick,
                last=self._last_tick,
            )
        
        self._last_tick = state.tick
        self._current_state = state
        self._state_history.append(state)
    
    def _update_stats(self, processing_time_ms: float) -> None:
        """Update processing statistics."""
        self._ticks_processed += 1
        self._total_processing_time_ms += processing_time_ms
        self._max_processing_time_ms = max(
            self._max_processing_time_ms, processing_time_ms
        )
    
    def _create_heartbeat_response(self, message: dict[str, Any]) -> dict[str, Any]:
        """Create a heartbeat response."""
        return {
            "type": "heartbeat_ack",
            "timestamp": int(time.time() * 1000),
            "client_tick": message.get("tick"),
            "ticks_processed": self._ticks_processed,
            "status": "healthy",
        }
    
    def _create_error_response(
        self, error_type: str, error_message: str
    ) -> dict[str, Any]:
        """Create an error response."""
        return {
            "type": "error",
            "timestamp": int(time.time() * 1000),
            "error": {
                "type": error_type,
                "message": error_message,
            },
            "fallback_mode": get_settings().decision.fallback_mode,
        }
    
    @property
    def current_state(self) -> GameState | None:
        """Get the current game state."""
        return self._current_state
    
    @property
    def state_history(self) -> list[GameState]:
        """Get state history as a list (oldest first)."""
        return list(self._state_history)
    
    @property
    def ticks_processed(self) -> int:
        """Get total ticks processed."""
        return self._ticks_processed
    
    @property
    def avg_processing_time_ms(self) -> float:
        """Get average processing time in milliseconds."""
        if self._ticks_processed == 0:
            return 0.0
        return self._total_processing_time_ms / self._ticks_processed
    
    @property
    def stats(self) -> dict[str, Any]:
        """Get processor statistics."""
        return {
            "initialized": self._initialized,
            "ticks_processed": self._ticks_processed,
            "avg_processing_ms": round(self.avg_processing_time_ms, 2),
            "max_processing_ms": round(self._max_processing_time_ms, 2),
            "warnings": self._warnings_issued,
            "history_size": len(self._state_history),
            "last_tick": self._last_tick,
        }