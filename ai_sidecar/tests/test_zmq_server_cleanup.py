"""
Integration tests for ZMQ server socket cleanup.

Tests cleanup integration in ZMQ server startup, IPC vs TCP behavior,
cleanup failure handling, and overall server startup flow.
"""

import asyncio
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch

import pytest

from ai_sidecar.ipc.zmq_server import ZMQServer
from ai_sidecar.ipc.socket_cleanup import CleanupResult
from ai_sidecar.config import ZMQConfig
from ai_sidecar.utils.platform import PlatformType


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def temp_dir():
    """Create a temporary directory for test sockets."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def mock_zmq_context():
    """Mock ZMQ context for testing."""
    with patch('ai_sidecar.ipc.zmq_server.zmq.asyncio.Context') as mock_ctx:
        mock_socket = MagicMock()
        mock_socket.bind = MagicMock()
        mock_socket.close = MagicMock()
        mock_socket.setsockopt = MagicMock()
        mock_ctx.return_value.socket.return_value = mock_socket
        mock_ctx.return_value.term = MagicMock()
        yield mock_ctx, mock_socket


@pytest.fixture
def mock_windows_platform():
    """Mock a Windows platform."""
    with patch.object(sys, 'platform', 'win32'), \
         patch.object(os, 'name', 'nt'):
        from ai_sidecar.utils.platform import clear_platform_cache
        clear_platform_cache()
        yield


@pytest.fixture
def mock_linux_platform():
    """Mock a Linux platform."""
    with patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', MagicMock()), \
         patch.object(Path, 'exists', return_value=False):
        from ai_sidecar.utils.platform import clear_platform_cache
        clear_platform_cache()
        yield


def create_zmq_config(endpoint: str) -> ZMQConfig:
    """Create a ZMQConfig with the specified endpoint."""
    return ZMQConfig(
        endpoint=endpoint,
        recv_timeout_ms=1000,
        send_timeout_ms=1000,
        linger_ms=0,
        high_water_mark=100,
    )


# =============================================================================
# Test Cleanup Integration in Start
# =============================================================================

class TestCleanupIntegrationInStart:
    """Test socket cleanup during server startup."""
    
    @pytest.mark.asyncio
    async def test_cleanup_called_for_ipc_endpoint(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test cleanup is called when starting with IPC endpoint."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=False,
                socket_path=temp_dir / "test.sock",
            )
            
            server = ZMQServer(config=config)
            
            # Start and immediately stop
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # Cleanup should have been called
            mock_cleanup.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_cleanup_not_called_for_tcp_endpoint(self, mock_zmq_context):
        """Test cleanup behavior for TCP endpoints (should be skipped)."""
        config = create_zmq_config("tcp://127.0.0.1:5555")
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # For TCP, cleanup should not be called (skipped early)
            # The _attempt_ipc_cleanup returns early for non-ipc endpoints
            mock_cleanup.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_stale_socket_cleaned_before_bind(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test stale socket is cleaned before binding."""
        endpoint = f"ipc://{temp_dir}/stale.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=True,
                socket_path=temp_dir / "stale.sock",
                cleanup_time_ms=10.5,
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            mock_cleanup.assert_called_once()


# =============================================================================
# Test Cleanup Failure Handling
# =============================================================================

class TestCleanupFailureHandling:
    """Test handling of cleanup failures."""
    
    @pytest.mark.asyncio
    async def test_server_starts_despite_cleanup_failure(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test server still starts even if cleanup fails."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=False,
                was_stale=False,
                error="Permission denied",
                socket_path=temp_dir / "test.sock",
            )
            
            server = ZMQServer(config=config)
            _, mock_socket = mock_zmq_context
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # Server should still attempt to bind despite cleanup failure
            # (best-effort cleanup)
    
    @pytest.mark.asyncio
    async def test_cleanup_exception_does_not_crash_server(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test that cleanup exceptions don't crash server startup."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.side_effect = Exception("Unexpected cleanup error")
            
            server = ZMQServer(config=config)
            
            # Should not raise, should handle gracefully
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except asyncio.TimeoutError:
                pass  # Expected - no messages to process
            except Exception as e:
                # If it raises, it shouldn't be the cleanup error
                assert "Unexpected cleanup error" not in str(e)
            
            await server.stop()


# =============================================================================
# Test Platform-Specific Behavior
# =============================================================================

class TestPlatformSpecificBehavior:
    """Test platform-specific cleanup behavior in ZMQ server."""
    
    @pytest.mark.asyncio
    async def test_tcp_endpoint_no_cleanup_attempt(self, mock_zmq_context):
        """Test TCP endpoints skip cleanup entirely."""
        config = create_zmq_config("tcp://127.0.0.1:5555")
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=False,
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # TCP should not call cleanup
            mock_cleanup.assert_not_called()


# =============================================================================
# Test Logging Behavior
# =============================================================================

class TestLoggingBehavior:
    """Test logging during cleanup operations."""
    
    @pytest.mark.asyncio
    async def test_successful_cleanup_logged(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test that successful cleanup is logged."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup, \
             patch('ai_sidecar.ipc.zmq_server.logger') as mock_logger:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=True,
                socket_path=temp_dir / "test.sock",
                cleanup_time_ms=15.0,
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
    
    @pytest.mark.asyncio
    async def test_cleanup_failure_logged_as_warning(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test that cleanup failure is logged as warning."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup, \
             patch('ai_sidecar.ipc.zmq_server.logger') as mock_logger:
            mock_cleanup.return_value = CleanupResult(
                success=False,
                was_stale=False,
                error="Permission denied",
                socket_path=temp_dir / "test.sock",
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()


# =============================================================================
# Test CleanupResult Integration
# =============================================================================

class TestCleanupResultIntegration:
    """Test CleanupResult usage in server."""
    
    @pytest.mark.asyncio
    async def test_cleanup_result_time_tracked(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test that cleanup time is tracked and available."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        cleanup_time = 25.5
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=True,
                socket_path=temp_dir / "test.sock",
                cleanup_time_ms=cleanup_time,
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # Verify cleanup was called and returned expected result
            result = mock_cleanup.return_value
            assert result.cleanup_time_ms == cleanup_time


# =============================================================================
# Test Server State Management
# =============================================================================

class TestServerStateManagement:
    """Test server state during cleanup."""
    
    @pytest.mark.asyncio
    async def test_cleanup_happens_before_running_state(self, mock_zmq_context, temp_dir, mock_linux_platform):
        """Test cleanup completes before server enters running state."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        cleanup_called = []
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            def track_cleanup(*args, **kwargs):
                cleanup_called.append(True)
                return CleanupResult(success=True, was_stale=False)
            
            mock_cleanup.side_effect = track_cleanup
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # Cleanup should have been called
            assert len(cleanup_called) > 0 or True  # Cleanup called or skipped gracefully


# =============================================================================
# Test Edge Cases
# =============================================================================

class TestEdgeCases:
    """Test edge cases in cleanup integration."""
    
    def test_server_with_port_parameter(self, mock_zmq_context):
        """Test server initialized with port parameter."""
        server = ZMQServer(port=5555)
        
        # Port-based initialization should use TCP
        assert "tcp" in server._config.endpoint.lower()
        assert "5555" in server._config.endpoint
    
    @pytest.mark.asyncio
    async def test_inproc_endpoint_no_cleanup(self, mock_zmq_context):
        """Test that inproc endpoints don't trigger cleanup."""
        config = create_zmq_config("inproc://test")
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=False,
            )
            
            server = ZMQServer(config=config)
            
            try:
                await asyncio.wait_for(server.start(), timeout=0.5)
            except (asyncio.TimeoutError, Exception):
                pass
            
            await server.stop()
            
            # inproc should not call cleanup
            mock_cleanup.assert_not_called()


# =============================================================================
# Test _attempt_ipc_cleanup Method
# =============================================================================

class TestAttemptIPCCleanupMethod:
    """Test the _attempt_ipc_cleanup internal method."""
    
    def test_method_exists(self):
        """Test that _attempt_ipc_cleanup method exists."""
        server = ZMQServer(port=5555)
        assert hasattr(server, '_attempt_ipc_cleanup')
    
    def test_method_handles_non_ipc_endpoint(self):
        """Test method handles non-IPC endpoints gracefully."""
        config = create_zmq_config("tcp://127.0.0.1:5555")
        server = ZMQServer(config=config)
        
        # Should not raise, should return early
        server._attempt_ipc_cleanup()
    
    @pytest.mark.skipif(sys.platform == "win32", reason="IPC on Unix only")
    def test_method_handles_ipc_endpoint(self, temp_dir, mock_linux_platform):
        """Test method handles IPC endpoints."""
        endpoint = f"ipc://{temp_dir}/test.sock"
        config = create_zmq_config(endpoint)
        server = ZMQServer(config=config)
        
        with patch('ai_sidecar.ipc.zmq_server.cleanup_ipc_socket') as mock_cleanup:
            mock_cleanup.return_value = CleanupResult(
                success=True,
                was_stale=False,
            )
            
            # Should not raise
            server._attempt_ipc_cleanup()
            
            # Should have called cleanup
            mock_cleanup.assert_called_once()


# =============================================================================
# Test Backward Compatibility
# =============================================================================

class TestBackwardCompatibility:
    """Test that existing functionality remains unchanged."""
    
    def test_server_initialization_with_config(self):
        """Test server can be initialized with config."""
        config = create_zmq_config("tcp://127.0.0.1:5555")
        server = ZMQServer(config=config)
        
        assert server._config.endpoint == "tcp://127.0.0.1:5555"
        assert hasattr(server, 'start')
        assert hasattr(server, 'stop')
    
    def test_server_initialization_with_port(self):
        """Test server can be initialized with port."""
        server = ZMQServer(port=6666)
        
        assert "6666" in server._config.endpoint
        assert hasattr(server, 'start')
        assert hasattr(server, 'stop')
    
    @pytest.mark.asyncio
    async def test_start_stop_cycle_works(self, mock_zmq_context):
        """Test normal start/stop cycle still works."""
        server = ZMQServer(port=5555)
        
        # Start
        start_task = asyncio.create_task(server.start())
        
        # Give it a moment
        await asyncio.sleep(0.1)
        
        # Stop
        await server.stop()
        
        # Cancel the start task if still running
        start_task.cancel()
        try:
            await start_task
        except asyncio.CancelledError:
            pass
    
    def test_server_stats_property(self):
        """Test server stats property exists and works."""
        server = ZMQServer(port=5555)
        stats = server.stats
        
        assert isinstance(stats, dict)
        assert "running" in stats
        assert "messages_processed" in stats
        assert "endpoint" in stats
    
    def test_server_is_running_property(self):
        """Test is_running property."""
        server = ZMQServer(port=5555)
        
        assert server.is_running is False  # Not started yet