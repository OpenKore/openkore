"""
Comprehensive unit tests for ZMQ Server.

Tests the async ZeroMQ REP socket server for IPC with OpenKore,
including initialization, message handling, error cases, and lifecycle.
"""

import asyncio
import json
import time
from unittest.mock import AsyncMock, MagicMock, Mock, patch

import pytest
import zmq
import zmq.asyncio

from ai_sidecar.ipc.zmq_server import ZMQServer, create_server
from ai_sidecar.config import ZMQConfig


@pytest.fixture
def zmq_config():
    """Create test ZMQ configuration."""
    return ZMQConfig(
        endpoint="tcp://127.0.0.1:5555",
        recv_timeout_ms=1000,
        send_timeout_ms=1000,
        linger_ms=0,
        high_water_mark=1000,
    )


@pytest.fixture
def mock_message_handler():
    """Create a mock async message handler."""
    async def handler(message: dict) -> dict:
        return {
            "type": "decision",
            "tick": message.get("tick"),
            "actions": [],
        }
    return AsyncMock(side_effect=handler)


@pytest.fixture
def mock_context():
    """Create a mock ZMQ async context."""
    context = MagicMock(spec=zmq.asyncio.Context)
    socket = MagicMock(spec=zmq.asyncio.Socket)
    
    # Mock socket methods
    socket.setsockopt = Mock()
    socket.bind = Mock()
    socket.close = Mock()
    socket.recv = AsyncMock()
    socket.send = AsyncMock()
    
    context.socket.return_value = socket
    context.term = Mock()
    
    return context, socket


class TestZMQServerInit:
    """Test ZMQ server initialization."""
    
    def test_init_with_default_config(self):
        """Test initialization with default config from settings."""
        server = ZMQServer()
        
        assert server._config is not None
        assert server._message_handler is None
        assert not server._running
        assert server._message_count == 0
        assert server._error_count == 0
        assert server._last_message_time is None
    
    def test_init_with_custom_config(self, zmq_config):
        """Test initialization with custom config."""
        server = ZMQServer(config=zmq_config)
        
        assert server._config == zmq_config
        assert server._config.endpoint == "tcp://127.0.0.1:5555"
    
    def test_init_with_message_handler(self, mock_message_handler):
        """Test initialization with message handler."""
        server = ZMQServer(message_handler=mock_message_handler)
        
        assert server._message_handler == mock_message_handler
    
    def test_set_message_handler(self, mock_message_handler):
        """Test setting message handler after initialization."""
        server = ZMQServer()
        assert server._message_handler is None
        
        server.set_message_handler(mock_message_handler)
        assert server._message_handler == mock_message_handler


class TestZMQServerProperties:
    """Test ZMQ server properties."""
    
    def test_is_running_property(self):
        """Test is_running property."""
        server = ZMQServer()
        
        assert not server.is_running
        server._running = True
        assert server.is_running
    
    def test_stats_property(self, zmq_config):
        """Test stats property returns correct information."""
        server = ZMQServer(config=zmq_config)
        server._message_count = 10
        server._error_count = 2
        server._last_message_time = 12345.67
        server._running = True
        
        stats = server.stats
        
        assert stats["running"] is True
        assert stats["messages_processed"] == 10
        assert stats["errors"] == 2
        assert stats["last_message_time"] == 12345.67
        assert stats["endpoint"] == "tcp://127.0.0.1:5555"


class TestZMQServerStartStop:
    """Test ZMQ server start and stop operations."""
    
    @pytest.mark.asyncio
    async def test_start_success(self, zmq_config, mock_context):
        """Test successful server start."""
        context, socket = mock_context
        
        with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context', return_value=context):
            server = ZMQServer(config=zmq_config)
            
            # Mock the run loop to exit immediately
            server._run_loop = AsyncMock()
            
            await server.start()
            
            assert server._running
            assert server._context == context
            assert server._socket == socket
            
            # Verify socket configuration
            assert socket.setsockopt.call_count >= 5
            socket.bind.assert_called_once_with("tcp://127.0.0.1:5555")
            server._run_loop.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_start_already_running(self, zmq_config):
        """Test starting server when already running."""
        server = ZMQServer(config=zmq_config)
        server._running = True
        
        # Should return early without error
        await server.start()
        
        assert server._running
        assert server._context is None  # Not created
    
    @pytest.mark.asyncio
    async def test_start_bind_error(self, zmq_config, mock_context):
        """Test handling bind errors during start."""
        context, socket = mock_context
        socket.bind.side_effect = zmq.ZMQError("Address already in use")
        
        with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context', return_value=context):
            server = ZMQServer(config=zmq_config)
            
            with pytest.raises(zmq.ZMQError):
                await server.start()
            
            # Cleanup should have been called
            socket.close.assert_called_once()
            context.term.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_stop_when_running(self, zmq_config, mock_context):
        """Test stopping a running server."""
        context, socket = mock_context
        
        with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context', return_value=context):
            server = ZMQServer(config=zmq_config)
            server._context = context
            server._socket = socket
            server._running = True
            server._message_count = 5
            server._error_count = 1
            
            await server.stop()
            
            assert not server._running
            socket.close.assert_called_once()
            context.term.assert_called_once()
            assert server._socket is None
            assert server._context is None
    
    @pytest.mark.asyncio
    async def test_stop_when_not_running(self):
        """Test stopping server when not running."""
        server = ZMQServer()
        
        # Should return early without error
        await server.stop()
        
        assert not server._running


class TestZMQServerMessageHandling:
    """Test ZMQ server message handling."""
    
    def test_handle_heartbeat(self):
        """Test heartbeat message handling."""
        server = ZMQServer()
        server._message_count = 10
        server._error_count = 2
        
        message = {
            "type": "heartbeat",
            "tick": 123,
            "timestamp": 1234567890,
        }
        
        response = server._handle_heartbeat(message)
        
        assert response["type"] == "heartbeat_ack"
        assert response["client_tick"] == 123
        assert response["messages_processed"] == 10
        assert response["errors"] == 2
        assert response["status"] == "healthy"
        assert "timestamp" in response
    
    @pytest.mark.asyncio
    async def test_handle_message_heartbeat(self):
        """Test async message handling for heartbeat."""
        server = ZMQServer()
        
        message = {"type": "heartbeat", "tick": 456}
        response = await server._handle_message(message)
        
        assert response["type"] == "heartbeat_ack"
        assert response["client_tick"] == 456
    
    @pytest.mark.asyncio
    async def test_handle_message_with_handler(self, mock_message_handler):
        """Test message handling with custom handler."""
        server = ZMQServer(message_handler=mock_message_handler)
        
        message = {"type": "state_update", "tick": 789}
        response = await server._handle_message(message)
        
        mock_message_handler.assert_called_once_with(message)
        assert response["type"] == "decision"
        assert response["tick"] == 789
    
    @pytest.mark.asyncio
    async def test_handle_message_without_handler(self):
        """Test message handling without custom handler."""
        server = ZMQServer()
        
        message = {"type": "state_update", "tick": 999}
        response = await server._handle_message(message)
        
        assert response["type"] == "ack"
        assert response["tick"] == 999
        assert response["status"] == "no_handler"
    
    def test_create_error_response(self, zmq_config):
        """Test error response creation."""
        server = ZMQServer(config=zmq_config)
        
        response = server._create_error_response("test_error", "Test error message")
        
        assert response["type"] == "error"
        assert response["error"]["type"] == "test_error"
        assert response["error"]["message"] == "Test error message"
        assert "timestamp" in response
        assert "fallback_mode" in response


class TestZMQServerMessageProcessing:
    """Test ZMQ server message processing loop."""
    
    @pytest.mark.asyncio
    async def test_process_one_message_success(self, mock_context, mock_message_handler):
        """Test successful processing of one message."""
        context, socket = mock_context
        
        message = {"type": "heartbeat", "tick": 100}
        socket.recv.return_value = json.dumps(message).encode("utf-8")
        
        server = ZMQServer(message_handler=mock_message_handler)
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._message_count == 1
        assert server._last_message_time is not None
        socket.recv.assert_called_once()
        socket.send.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_process_one_message_no_socket(self):
        """Test processing when socket is None."""
        server = ZMQServer()
        server._socket = None
        
        # Should return early without error
        await server._process_one_message()
        
        assert server._message_count == 0
    
    @pytest.mark.asyncio
    async def test_process_one_message_no_message_available(self, mock_context):
        """Test processing when no message is available."""
        context, socket = mock_context
        socket.recv.side_effect = zmq.Again()
        
        server = ZMQServer()
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._message_count == 0
        assert server._error_count == 0
    
    @pytest.mark.asyncio
    async def test_process_one_message_zmq_error(self, mock_context):
        """Test processing with ZMQ receive error."""
        context, socket = mock_context
        socket.recv.side_effect = zmq.ZMQError("Connection error")
        
        server = ZMQServer()
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._error_count == 1
        assert server._message_count == 0
    
    @pytest.mark.asyncio
    async def test_process_one_message_invalid_json(self, mock_context):
        """Test processing with invalid JSON."""
        context, socket = mock_context
        socket.recv.return_value = b"not valid json"
        
        server = ZMQServer()
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._error_count == 1
        socket.send.assert_called_once()
        
        # Verify error response was sent
        sent_data = socket.send.call_args[0][0]
        response = json.loads(sent_data.decode("utf-8"))
        assert response["type"] == "error"
        assert response["error"]["type"] == "invalid_json"
    
    @pytest.mark.asyncio
    async def test_process_one_message_handler_exception(self, mock_context):
        """Test processing when handler raises exception."""
        context, socket = mock_context
        
        message = {"type": "state_update", "tick": 200}
        socket.recv.return_value = json.dumps(message).encode("utf-8")
        
        # Handler that raises exception
        async def failing_handler(msg):
            raise ValueError("Handler failed")
        
        server = ZMQServer(message_handler=failing_handler)
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._error_count == 1
        socket.send.assert_called_once()
        
        # Verify error response was sent
        sent_data = socket.send.call_args[0][0]
        response = json.loads(sent_data.decode("utf-8"))
        assert response["type"] == "error"
        assert response["error"]["type"] == "processing_error"
    
    @pytest.mark.asyncio
    async def test_process_one_message_send_error(self, mock_context):
        """Test processing with ZMQ send error."""
        context, socket = mock_context
        
        message = {"type": "heartbeat", "tick": 300}
        socket.recv.return_value = json.dumps(message).encode("utf-8")
        socket.send.side_effect = zmq.ZMQError("Send failed")
        
        server = ZMQServer()
        server._socket = socket
        
        await server._process_one_message()
        
        assert server._error_count == 1
        # Message was processed but not counted as successful
        assert server._message_count == 0


class TestZMQServerRunLoop:
    """Test ZMQ server main run loop."""
    
    @pytest.mark.asyncio
    async def test_run_loop_cancelled(self, mock_context):
        """Test run loop handles cancellation."""
        context, socket = mock_context
        
        server = ZMQServer()
        server._running = True
        server._socket = socket
        
        # Mock process to raise CancelledError after one iteration
        call_count = 0
        async def process_mock():
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise asyncio.CancelledError()
        
        server._process_one_message = process_mock
        
        await server._run_loop()
        
        # Should have stopped gracefully
        assert call_count == 1
    
    @pytest.mark.asyncio
    async def test_run_loop_unexpected_error(self, mock_context):
        """Test run loop handles unexpected errors."""
        context, socket = mock_context
        
        server = ZMQServer()
        server._running = True
        server._socket = socket
        
        # Mock process to raise exception once, then complete
        call_count = 0
        async def process_mock():
            nonlocal call_count
            call_count += 1
            if call_count == 1:
                raise RuntimeError("Unexpected error")
            server._running = False
        
        server._process_one_message = process_mock
        
        await server._run_loop()
        
        # Should have caught error and continued
        assert call_count == 2
        assert server._error_count == 1


class TestZMQServerFactoryFunction:
    """Test factory function for creating servers."""
    
    @pytest.mark.asyncio
    async def test_create_server_without_handler(self):
        """Test creating server without handler."""
        server = await create_server()
        
        assert isinstance(server, ZMQServer)
        assert server._message_handler is None
        assert not server.is_running
    
    @pytest.mark.asyncio
    async def test_create_server_with_handler(self, mock_message_handler):
        """Test creating server with handler."""
        server = await create_server(message_handler=mock_message_handler)
        
        assert isinstance(server, ZMQServer)
        assert server._message_handler == mock_message_handler
        assert not server.is_running


class TestZMQServerIntegration:
    """Integration tests for ZMQ server."""
    
    @pytest.mark.asyncio
    async def test_full_lifecycle(self, zmq_config, mock_context, mock_message_handler):
        """Test full server lifecycle: start, process, stop."""
        context, socket = mock_context
        
        # Setup mock message
        message = {"type": "state_update", "tick": 1}
        socket.recv.side_effect = [
            json.dumps(message).encode("utf-8"),
            asyncio.CancelledError(),  # Stop after one message
        ]
        
        with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context', return_value=context):
            server = ZMQServer(config=zmq_config, message_handler=mock_message_handler)
            
            # Start server (will process one message then cancel)
            try:
                await server.start()
            except asyncio.CancelledError:
                pass
            
            # Stop server
            await server.stop()
            
            # Verify state
            assert not server.is_running
            assert server._message_count == 1
            assert server._error_count == 0
            assert server._socket is None
            assert server._context is None
    
    @pytest.mark.asyncio
    async def test_multiple_messages_processing(self, zmq_config, mock_context):
        """Test processing multiple messages in sequence."""
        context, socket = mock_context
        
        messages = [
            {"type": "heartbeat", "tick": i}
            for i in range(5)
        ]
        
        # Setup mock to return messages then cancel
        socket.recv.side_effect = [
            json.dumps(msg).encode("utf-8") for msg in messages
        ] + [asyncio.CancelledError()]
        
        with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context', return_value=context):
            server = ZMQServer(config=zmq_config)
            
            try:
                await server.start()
            except asyncio.CancelledError:
                pass
            
            await server.stop()
            
            # All messages should have been processed
            assert server._message_count == 5
            assert server._error_count == 0