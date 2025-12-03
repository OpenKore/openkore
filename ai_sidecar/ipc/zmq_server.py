"""
ZeroMQ server for AI Sidecar IPC.

Implements an async REP socket server that receives game state updates
from OpenKore and responds with AI decisions.
"""

import asyncio
import json
import time
from typing import Any, Callable, Coroutine

import zmq
import zmq.asyncio

from ai_sidecar.config import get_settings, ZMQConfig
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)

# Type alias for message handlers
MessageHandler = Callable[[dict[str, Any]], Coroutine[Any, Any, dict[str, Any]]]


class ZMQServer:
    """
    Async ZeroMQ REP socket server for IPC with OpenKore.
    
    Handles incoming state updates and responds with AI decisions.
    Supports graceful shutdown and automatic reconnection.
    """
    
    def __init__(
        self,
        config: ZMQConfig | None = None,
        message_handler: MessageHandler | None = None,
        port: int | None = None,
    ) -> None:
        """
        Initialize the ZeroMQ server.
        
        Args:
            config: ZMQ configuration. If None, uses default from settings.
            message_handler: Async callback for processing messages.
                            Must accept a dict and return a dict response.
            port: Port number to bind to. If provided, overrides config endpoint.
        """
        self._config = config or get_settings().zmq
        
        # Override endpoint if port is provided
        if port is not None:
            self._config = ZMQConfig(
                endpoint=f"tcp://*:{port}",
                recv_timeout_ms=self._config.recv_timeout_ms,
                send_timeout_ms=self._config.send_timeout_ms,
                linger_ms=self._config.linger_ms,
                high_water_mark=self._config.high_water_mark,
            )
        self._message_handler = message_handler
        
        # ZMQ context and socket (created on start)
        self._context: zmq.asyncio.Context | None = None
        self._socket: zmq.asyncio.Socket | None = None
        
        # Server state
        self._running = False
        self._message_count = 0
        self._error_count = 0
        self._last_message_time: float | None = None
        
        logger.info(
            "ZMQ server initialized",
            endpoint=self._config.endpoint,
            recv_timeout=self._config.recv_timeout_ms,
        )
    
    def set_message_handler(self, handler: MessageHandler) -> None:
        """Set the message handler callback."""
        self._message_handler = handler
    
    async def start(self) -> None:
        """
        Start the ZeroMQ server and begin listening for messages.
        
        Creates the ZMQ context and socket, binds to the endpoint,
        and enters the main message processing loop.
        """
        if self._running:
            logger.warning("Server already running")
            return
        
        logger.info("Starting ZMQ server", endpoint=self._config.endpoint)
        
        # Create async context
        self._context = zmq.asyncio.Context()
        
        # Create REP socket
        self._socket = self._context.socket(zmq.REP)
        
        # Configure socket options
        self._socket.setsockopt(zmq.LINGER, self._config.linger_ms)
        self._socket.setsockopt(zmq.RCVHWM, self._config.high_water_mark)
        self._socket.setsockopt(zmq.SNDHWM, self._config.high_water_mark)
        self._socket.setsockopt(zmq.RCVTIMEO, self._config.recv_timeout_ms)
        self._socket.setsockopt(zmq.SNDTIMEO, self._config.send_timeout_ms)
        
        # Bind to endpoint
        try:
            self._socket.bind(self._config.endpoint)
            logger.info("ZMQ socket bound", endpoint=self._config.endpoint)
        except zmq.ZMQError as e:
            logger.error("Failed to bind socket", endpoint=self._config.endpoint, error=str(e))
            await self._cleanup()
            raise
        
        self._running = True
        
        # Enter main loop
        await self._run_loop()
    
    async def stop(self) -> None:
        """Stop the ZeroMQ server gracefully."""
        if not self._running:
            return
        
        logger.info("Stopping ZMQ server")
        self._running = False
        
        await self._cleanup()
        
        logger.info(
            "ZMQ server stopped",
            messages_processed=self._message_count,
            errors=self._error_count,
        )
    
    async def _cleanup(self) -> None:
        """Clean up ZMQ resources."""
        if self._socket:
            self._socket.close(linger=0)
            self._socket = None
        
        if self._context:
            self._context.term()
            self._context = None
    
    async def _run_loop(self) -> None:
        """Main message processing loop."""
        logger.info("Entering message loop")
        
        while self._running:
            try:
                await self._process_one_message()
            except asyncio.CancelledError:
                logger.info("Message loop cancelled")
                break
            except Exception as e:
                logger.exception("Unexpected error in message loop", error=str(e))
                self._error_count += 1
                # Brief pause to prevent tight error loops
                await asyncio.sleep(0.01)
    
    async def _process_one_message(self) -> None:
        """Process a single message from the socket."""
        if not self._socket:
            return
        
        try:
            # Receive message (with timeout from socket options)
            raw_message = await self._socket.recv(flags=zmq.NOBLOCK)
        except zmq.Again:
            # No message available, brief yield
            await asyncio.sleep(0.001)
            return
        except zmq.ZMQError as e:
            logger.error("ZMQ receive error", error=str(e))
            self._error_count += 1
            return
        
        # Track timing
        recv_time = time.time()
        self._last_message_time = recv_time
        
        # Parse and process message
        try:
            message = json.loads(raw_message.decode("utf-8"))
            response = await self._handle_message(message)
        except json.JSONDecodeError as e:
            logger.error("Invalid JSON received", error=str(e))
            response = self._create_error_response("invalid_json", str(e))
            self._error_count += 1
        except Exception as e:
            logger.exception("Error processing message", error=str(e))
            response = self._create_error_response("processing_error", str(e))
            self._error_count += 1
        
        # Send response
        try:
            response_bytes = json.dumps(response).encode("utf-8")
            await self._socket.send(response_bytes)
            self._message_count += 1
        except zmq.ZMQError as e:
            logger.error("ZMQ send error", error=str(e))
            self._error_count += 1
    
    async def _handle_message(self, message: dict[str, Any]) -> dict[str, Any]:
        """
        Handle an incoming message and return a response.
        
        Args:
            message: Parsed JSON message from OpenKore.
        
        Returns:
            Response dict to send back.
        """
        msg_type = message.get("type", "unknown")
        
        logger.debug(
            "Received message",
            type=msg_type,
            tick=message.get("tick"),
        )
        
        # Handle heartbeat specially
        if msg_type == "heartbeat":
            return self._handle_heartbeat(message)
        
        # Delegate to message handler
        if self._message_handler:
            return await self._message_handler(message)
        
        # No handler, return acknowledgment
        return {
            "type": "ack",
            "timestamp": int(time.time() * 1000),
            "tick": message.get("tick"),
            "status": "no_handler",
        }
    
    def _handle_heartbeat(self, message: dict[str, Any]) -> dict[str, Any]:
        """Handle heartbeat message."""
        return {
            "type": "heartbeat_ack",
            "timestamp": int(time.time() * 1000),
            "client_tick": message.get("tick"),
            "messages_processed": self._message_count,
            "errors": self._error_count,
            "status": "healthy",
        }
    
    def _create_error_response(
        self, error_type: str, error_message: str
    ) -> dict[str, Any]:
        """Create a standardized error response."""
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
    def port(self) -> int:
        """Get the port number from endpoint."""
        # Extract port from endpoint like "tcp://*:5556"
        try:
            return int(self._config.endpoint.split(":")[-1])
        except (ValueError, IndexError):
            return 0
    
    @property
    def is_running(self) -> bool:
        """Check if the server is running."""
        return self._running
    
    @property
    def stats(self) -> dict[str, Any]:
        """Get server statistics."""
        return {
            "running": self._running,
            "messages_processed": self._message_count,
            "errors": self._error_count,
            "last_message_time": self._last_message_time,
            "endpoint": self._config.endpoint,
        }


async def create_server(
    message_handler: MessageHandler | None = None,
) -> ZMQServer:
    """
    Factory function to create and configure a ZMQ server.
    
    Args:
        message_handler: Optional message handler callback.
    
    Returns:
        Configured ZMQServer instance (not started).
    """
    return ZMQServer(message_handler=message_handler)