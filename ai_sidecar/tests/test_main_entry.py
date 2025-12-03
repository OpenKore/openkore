"""
Tests for main.py entry point.

Covers:
- AISidecar class initialization and lifecycle
- Startup sequence with progress tracking
- Shutdown handling
- Signal handlers
- Command-line argument parsing
- Error handling during startup
- Integration with ZMQ and TickProcessor
"""

import pytest
import asyncio
import sys
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from io import StringIO

from ai_sidecar.main import (
    AISidecar,
    run_sidecar,
    main,
)
from ai_sidecar.utils.startup import StartupProgress
from ai_sidecar.utils.errors import (
    SidecarError,
    ConfigurationError,
    InitializationError,
    ZMQConnectionError,
)


# =============================================================================
# AISidecar Class Tests
# =============================================================================

class TestAISidecar:
    """Test AISidecar application class."""
    
    @pytest.fixture
    def mock_settings(self):
        """Mock settings object."""
        settings = Mock()
        settings.zmq.endpoint = "tcp://localhost:5555"
        settings.tick.interval_ms = 100
        return settings
    
    @pytest.fixture
    def mock_progress(self):
        """Mock startup progress tracker."""
        progress = Mock(spec=StartupProgress)
        progress.step = MagicMock()
        progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        progress.step.return_value.__exit__ = Mock(return_value=False)
        progress.show_summary = Mock()
        return progress
    
    def test_aisidecar_init_no_progress(self, mock_settings):
        """Test AISidecar initialization without progress tracker."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar()
            
            assert sidecar._progress is None
            assert sidecar._server is None
            assert sidecar._tick_processor is None
            assert not sidecar._running
            assert not sidecar.is_running
    
    def test_aisidecar_init_with_progress(self, mock_settings, mock_progress):
        """Test AISidecar initialization with progress tracker."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar(progress=mock_progress)
            
            assert sidecar._progress is mock_progress
            assert not sidecar._running
    
    @pytest.mark.asyncio
    async def test_aisidecar_start_success(self, mock_settings, mock_progress):
        """Test successful AISidecar startup."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
             patch('ai_sidecar.main.TickProcessor') as MockTick, \
             patch('ai_sidecar.main.ZMQServer') as MockZMQ, \
             patch('ai_sidecar.main.__version__', '1.0.0'):
            
            # Setup mocks
            mock_tick = AsyncMock()
            mock_tick.initialize = AsyncMock()
            mock_tick.process_message = AsyncMock()
            MockTick.return_value = mock_tick
            
            mock_server = AsyncMock()
            mock_server.start = AsyncMock()
            MockZMQ.return_value = mock_server
            
            sidecar = AISidecar(progress=mock_progress)
            
            # Start in background task and stop immediately
            start_task = asyncio.create_task(sidecar.start())
            await asyncio.sleep(0.1)  # Let it initialize
            await sidecar.stop()
            
            try:
                await asyncio.wait_for(start_task, timeout=1.0)
            except asyncio.TimeoutError:
                pass  # Expected if start() is still running
            
            assert MockTick.called
            assert MockZMQ.called
    
    @pytest.mark.asyncio
    async def test_aisidecar_start_already_running(self, mock_settings):
        """Test starting AISidecar when already running."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar()
            sidecar._running = True
            
            await sidecar.start()  # Should return early
            
            assert sidecar._running  # Still running
    
    @pytest.mark.asyncio
    async def test_aisidecar_tick_processor_init_error(self, mock_settings, mock_progress):
        """Test error during tick processor initialization."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
             patch('ai_sidecar.main.TickProcessor') as MockTick:
            
            mock_tick = AsyncMock()
            mock_tick.initialize = AsyncMock(side_effect=Exception("Init failed"))
            MockTick.return_value = mock_tick
            
            sidecar = AISidecar(progress=mock_progress)
            
            with pytest.raises(InitializationError) as exc_info:
                await sidecar.start()
            assert "tick processor" in str(exc_info.value).lower()
    
    @pytest.mark.asyncio
    async def test_aisidecar_zmq_server_creation_error(self, mock_settings, mock_progress):
        """Test error during ZMQ server creation."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
             patch('ai_sidecar.main.TickProcessor') as MockTick, \
             patch('ai_sidecar.main.ZMQServer') as MockZMQ:
            
            mock_tick = AsyncMock()
            mock_tick.initialize = AsyncMock()
            MockTick.return_value = mock_tick
            
            MockZMQ.side_effect = Exception("ZMQ failed")
            
            sidecar = AISidecar(progress=mock_progress)
            
            with pytest.raises(ZMQConnectionError) as exc_info:
                await sidecar.start()
            assert "ZMQ" in str(exc_info.value)
    
    @pytest.mark.asyncio
    async def test_aisidecar_stop_when_not_running(self):
        """Test stopping AISidecar when not running."""
        with patch('ai_sidecar.main.get_settings'):
            sidecar = AISidecar()
            
            await sidecar.stop()  # Should handle gracefully
            
            assert not sidecar._running
    
    @pytest.mark.asyncio
    async def test_aisidecar_stop_with_server(self, mock_settings):
        """Test stopping AISidecar with active server."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar()
            sidecar._running = True
            
            mock_server = AsyncMock()
            mock_server.stop = AsyncMock()
            sidecar._server = mock_server
            
            mock_tick = AsyncMock()
            mock_tick.shutdown = AsyncMock()
            sidecar._tick_processor = mock_tick
            
            await sidecar.stop()
            
            assert mock_server.stop.called
            assert mock_tick.shutdown.called
            assert not sidecar._running
    
    @pytest.mark.asyncio
    async def test_aisidecar_cleanup(self, mock_settings):
        """Test cleanup of resources."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar()
            
            mock_tick = AsyncMock()
            mock_tick.shutdown = AsyncMock()
            sidecar._tick_processor = mock_tick
            sidecar._running = True
            
            await sidecar._cleanup()
            
            assert mock_tick.shutdown.called
            assert sidecar._tick_processor is None
            assert not sidecar._running
    
    def test_aisidecar_is_running_property(self, mock_settings):
        """Test is_running property."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
            sidecar = AISidecar()
            
            assert not sidecar.is_running
            
            sidecar._running = True
            assert sidecar.is_running
    
    def test_aisidecar_stats_not_running(self, mock_settings):
        """Test stats when not running."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
             patch('ai_sidecar.main.__version__', '1.0.0'):
            sidecar = AISidecar()
            
            stats = sidecar.stats
            
            assert stats['running'] is False
            assert stats['version'] == '1.0.0'
            assert 'server' not in stats
            assert 'processor' not in stats
    
    def test_aisidecar_stats_with_components(self, mock_settings):
        """Test stats with active components."""
        with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
             patch('ai_sidecar.main.__version__', '1.0.0'):
            sidecar = AISidecar()
            sidecar._running = True
            
            mock_server = Mock()
            mock_server.stats = {'messages': 100}
            sidecar._server = mock_server
            
            mock_tick = Mock()
            mock_tick.stats = {'ticks': 50}
            sidecar._tick_processor = mock_tick
            
            stats = sidecar.stats
            
            assert stats['running'] is True
            assert stats['server'] == {'messages': 100}
            assert stats['processor'] == {'ticks': 50}


# =============================================================================
# run_sidecar Function Tests
# =============================================================================

@pytest.mark.asyncio
async def test_run_sidecar_success():
    """Test successful run_sidecar execution."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop') as mock_loop:
        
        # Setup mocks
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock()
        mock_sidecar.stop = AsyncMock()
        mock_sidecar.is_running = True
        MockSidecar.return_value = mock_sidecar
        
        mock_loop_inst = Mock()
        mock_loop_inst.add_signal_handler = Mock()
        mock_loop.return_value = mock_loop_inst
        
        # Run with KeyboardInterrupt to exit
        mock_sidecar.start.side_effect = KeyboardInterrupt()
        
        await run_sidecar()
        
        assert mock_progress.display_banner.called
        assert mock_validate.called
        assert mock_sidecar.start.called


@pytest.mark.asyncio
async def test_run_sidecar_config_validation_warnings():
    """Test run_sidecar with configuration warnings."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop'):
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        step_mock = Mock(details={})
        mock_progress.step.return_value.__enter__ = Mock(return_value=step_mock)
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, ["Warning 1", "Warning 2"])
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock(side_effect=KeyboardInterrupt())
        mock_sidecar.stop = AsyncMock()
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        await run_sidecar()
        
        # Check warnings were logged
        assert len(step_mock.details) >= 2


@pytest.mark.asyncio
async def test_run_sidecar_config_validation_failure():
    """Test run_sidecar with configuration validation failure."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate:
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (False, ["Error 1"])
        
        with pytest.raises(ConfigurationError) as exc_info:
            await run_sidecar()
        assert "validation failed" in str(exc_info.value).lower()


@pytest.mark.asyncio
async def test_run_sidecar_sidecar_error():
    """Test run_sidecar handling SidecarError."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop'), \
         patch('sys.exit') as mock_exit:
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        mock_sidecar = AsyncMock()
        test_error = SidecarError("Test error")
        mock_sidecar.start = AsyncMock(side_effect=test_error)
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        # Should not raise, but call sys.exit
        await run_sidecar()
        
        mock_exit.assert_called_with(1)


@pytest.mark.asyncio
async def test_run_sidecar_unexpected_error():
    """Test run_sidecar handling unexpected error."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop'), \
         patch('sys.exit') as mock_exit:
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock(side_effect=RuntimeError("Unexpected"))
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        await run_sidecar()
        
        mock_exit.assert_called_with(1)


# =============================================================================
# main Function Tests
# =============================================================================

def test_main_help_argument():
    """Test main with --help argument."""
    with patch('sys.argv', ['main', '--help']), \
         patch('ai_sidecar.main.print_config_help') as mock_help, \
         patch('sys.exit') as mock_exit:
        
        main()
        
        mock_help.assert_called_once()
        mock_exit.assert_called_with(0)


def test_main_version_argument():
    """Test main with --version argument."""
    with patch('sys.argv', ['main', '--version']), \
         patch('ai_sidecar.main.__version__', '1.2.3'), \
         patch('builtins.print') as mock_print:
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 0
        mock_print.assert_any_call('AI Sidecar v1.2.3')


def test_main_logging_setup_failure():
    """Test main with logging setup failure."""
    with patch('sys.argv', ['main']), \
         patch('ai_sidecar.main.setup_logging', side_effect=Exception("Log fail")), \
         patch('builtins.print'):
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 1


def test_main_success():
    """Test successful main execution."""
    with patch('sys.argv', ['main']), \
         patch('ai_sidecar.main.setup_logging'), \
         patch('ai_sidecar.main.asyncio.run') as mock_run:
        
        mock_run.side_effect = KeyboardInterrupt()
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 0
        assert mock_run.called


def test_main_sidecar_error():
    """Test main handling SidecarError."""
    with patch('sys.argv', ['main']), \
         patch('ai_sidecar.main.setup_logging'), \
         patch('ai_sidecar.main.asyncio.run') as mock_run:
        
        mock_run.side_effect = SidecarError("Test error")
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 1


def test_main_unexpected_exception():
    """Test main handling unexpected exception."""
    with patch('sys.argv', ['main']), \
         patch('ai_sidecar.main.setup_logging'), \
         patch('ai_sidecar.main.asyncio.run') as mock_run, \
         patch('builtins.print'):
        
        mock_run.side_effect = RuntimeError("Unexpected error")
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 1


def test_main_keyboard_interrupt_in_asyncio():
    """Test main handling keyboard interrupt from asyncio.run."""
    with patch('sys.argv', ['main']), \
         patch('ai_sidecar.main.setup_logging'), \
         patch('ai_sidecar.main.asyncio.run') as mock_run, \
         patch('sys.exit') as mock_exit:
        
        mock_run.side_effect = KeyboardInterrupt()
        
        main()
        
        # Should exit with 0 on keyboard interrupt
        mock_exit.assert_called_with(0)


# =============================================================================
# Signal Handler Tests
# =============================================================================

@pytest.mark.asyncio
async def test_shutdown_handler():
    """Test shutdown signal handler."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop') as mock_loop, \
         patch('builtins.print'):
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        # Track signal handler
        registered_handler = None
        
        def capture_handler(sig, handler):
            nonlocal registered_handler
            registered_handler = handler
        
        mock_loop_inst = Mock()
        mock_loop_inst.add_signal_handler = Mock(side_effect=capture_handler)
        mock_loop.return_value = mock_loop_inst
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock(side_effect=KeyboardInterrupt())
        mock_sidecar.stop = AsyncMock()
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        await run_sidecar()
        
        # Signal handler should be registered on Unix
        if sys.platform != "win32":
            assert registered_handler is not None


# =============================================================================
# Edge Cases and Integration Tests
# =============================================================================

@pytest.mark.asyncio
async def test_aisidecar_with_all_features():
    """Test AISidecar with all features enabled."""
    # Create mocks
    mock_settings = Mock()
    mock_settings.zmq.endpoint = "tcp://localhost:5555"
    mock_settings.tick.interval_ms = 100
    
    mock_progress = Mock(spec=StartupProgress)
    mock_progress.step = MagicMock()
    mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
    mock_progress.step.return_value.__exit__ = Mock(return_value=False)
    mock_progress.show_summary = Mock()
    
    with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
         patch('ai_sidecar.main.get_config_summary', return_value={'key': 'value'}), \
         patch('ai_sidecar.main.__version__', '1.0.0'), \
         patch('ai_sidecar.main.TickProcessor') as MockTick, \
         patch('ai_sidecar.main.ZMQServer') as MockZMQ, \
         patch('builtins.print'):
        
        mock_tick = AsyncMock()
        mock_tick.initialize = AsyncMock()
        mock_tick.process_message = AsyncMock()
        MockTick.return_value = mock_tick
        
        mock_server = AsyncMock()
        mock_server.start = AsyncMock()
        MockZMQ.return_value = mock_server
        
        sidecar = AISidecar(progress=mock_progress)
        
        # Start in background
        start_task = asyncio.create_task(sidecar.start())
        await asyncio.sleep(0.1)
        await sidecar.stop()
        
        try:
            await asyncio.wait_for(start_task, timeout=1.0)
        except asyncio.TimeoutError:
            pass


@pytest.mark.asyncio
async def test_aisidecar_start_without_progress():
    """Test AISidecar.start() without progress tracker to cover else branches."""
    mock_settings = Mock()
    mock_settings.zmq.endpoint = "tcp://localhost:5555"
    mock_settings.tick.interval_ms = 100
    
    with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
         patch('ai_sidecar.main.get_config_summary', return_value={}), \
         patch('ai_sidecar.main.TickProcessor') as MockTick, \
         patch('ai_sidecar.main.ZMQServer') as MockZMQ, \
         patch('builtins.print'):
        
        mock_tick = AsyncMock()
        mock_tick.initialize = AsyncMock()
        mock_tick.process_message = AsyncMock()
        mock_tick.shutdown = AsyncMock()
        MockTick.return_value = mock_tick
        
        mock_server = AsyncMock()
        mock_server.start = AsyncMock()
        mock_server.stop = AsyncMock()
        MockZMQ.return_value = mock_server
        
        # Create without progress tracker
        sidecar = AISidecar(progress=None)
        
        # Start in background
        start_task = asyncio.create_task(sidecar.start())
        await asyncio.sleep(0.1)
        await sidecar.stop()
        
        try:
            await asyncio.wait_for(start_task, timeout=1.0)
        except asyncio.TimeoutError:
            pass
        
        assert MockTick.called
        assert MockZMQ.called


@pytest.mark.asyncio
async def test_aisidecar_server_start_exception():
    """Test exception during server.start() execution."""
    mock_settings = Mock()
    mock_settings.zmq.endpoint = "tcp://localhost:5555"
    mock_settings.tick.interval_ms = 100
    
    with patch('ai_sidecar.main.get_settings', return_value=mock_settings), \
         patch('ai_sidecar.main.get_config_summary', return_value={}), \
         patch('ai_sidecar.main.TickProcessor') as MockTick, \
         patch('ai_sidecar.main.ZMQServer') as MockZMQ, \
         patch('builtins.print'):
        
        mock_tick = AsyncMock()
        mock_tick.initialize = AsyncMock()
        mock_tick.process_message = AsyncMock()
        mock_tick.shutdown = AsyncMock()
        MockTick.return_value = mock_tick
        
        mock_server = AsyncMock()
        mock_server.start = AsyncMock(side_effect=RuntimeError("Server error"))
        mock_server.stop = AsyncMock()
        MockZMQ.return_value = mock_server
        
        sidecar = AISidecar(progress=None)
        
        with pytest.raises(RuntimeError, match="Server error"):
            await sidecar.start()
        
        # Cleanup should be called even on exception
        assert mock_tick.shutdown.called


@pytest.mark.asyncio
async def test_run_sidecar_signal_handler_windows():
    """Test run_sidecar on Windows platform (no signal handlers)."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop') as mock_loop, \
         patch('ai_sidecar.main.sys.platform', 'win32'):
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock(side_effect=KeyboardInterrupt())
        mock_sidecar.stop = AsyncMock()
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        mock_loop_inst = Mock()
        mock_loop_inst.add_signal_handler = Mock()
        mock_loop.return_value = mock_loop_inst
        
        await run_sidecar()
        
        # On Windows, signal handlers should not be registered
        assert not mock_loop_inst.add_signal_handler.called


def test_main_with_h_short_arg():
    """Test main with -h short argument."""
    with patch('sys.argv', ['main', '-h']), \
         patch('ai_sidecar.main.print_config_help') as mock_help:
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 0
        mock_help.assert_called_once()


def test_main_with_v_short_arg():
    """Test main with -v short argument."""
    with patch('sys.argv', ['main', '-v']), \
         patch('ai_sidecar.main.__version__', '2.0.0'), \
         patch('builtins.print') as mock_print:
        
        with pytest.raises(SystemExit) as exc_info:
            main()
        
        assert exc_info.value.code == 0


@pytest.mark.asyncio
async def test_run_sidecar_shutdown_handler_execution():
    """Test that shutdown handler can be executed when called."""
    with patch('ai_sidecar.main.StartupProgress') as MockProgress, \
         patch('ai_sidecar.main.validate_config') as mock_validate, \
         patch('ai_sidecar.main.AISidecar') as MockSidecar, \
         patch('ai_sidecar.main.asyncio.get_running_loop') as mock_loop, \
         patch('builtins.print') as mock_print:
        
        mock_progress = Mock()
        mock_progress.display_banner = Mock()
        mock_progress.step = MagicMock()
        mock_progress.step.return_value.__enter__ = Mock(return_value=Mock(details={}))
        mock_progress.step.return_value.__exit__ = Mock(return_value=False)
        MockProgress.return_value = mock_progress
        
        mock_validate.return_value = (True, [])
        
        # Track the shutdown handler
        shutdown_handler_coro = None
        
        async def mock_start():
            # Allow shutdown handler to be called
            await asyncio.sleep(0.05)
            if shutdown_handler_coro:
                await shutdown_handler_coro
            raise KeyboardInterrupt()
        
        mock_sidecar = AsyncMock()
        mock_sidecar.start = AsyncMock(side_effect=mock_start)
        mock_sidecar.stop = AsyncMock()
        mock_sidecar.is_running = False
        MockSidecar.return_value = mock_sidecar
        
        def capture_handler(sig, handler):
            nonlocal shutdown_handler_coro
            # The handler is a lambda that creates a task
            # We need to extract the coroutine
            result = handler()
            if asyncio.iscoroutine(result):
                shutdown_handler_coro = result
        
        mock_loop_inst = Mock()
        mock_loop_inst.add_signal_handler = Mock(side_effect=capture_handler)
        mock_loop.return_value = mock_loop_inst
        
        await run_sidecar()
        
        # Verify shutdown was called
        assert mock_sidecar.stop.called


@pytest.mark.asyncio 
async def test_aisidecar_stop_without_server():
    """Test stop() when running but server is None."""
    mock_settings = Mock()
    mock_settings.zmq.endpoint = "tcp://localhost:5555"
    mock_settings.tick.interval_ms = 100
    
    with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
        sidecar = AISidecar()
        sidecar._running = True
        sidecar._server = None  # No server
        
        mock_tick = AsyncMock()
        mock_tick.shutdown = AsyncMock()
        sidecar._tick_processor = mock_tick
        
        await sidecar.stop()
        
        # Should still call cleanup
        assert mock_tick.shutdown.called
        assert not sidecar._running


@pytest.mark.asyncio
async def test_aisidecar_cleanup_without_processor():
    """Test _cleanup() when tick_processor is None."""
    mock_settings = Mock()
    mock_settings.zmq.endpoint = "tcp://localhost:5555"
    
    with patch('ai_sidecar.main.get_settings', return_value=mock_settings):
        sidecar = AISidecar()
        sidecar._tick_processor = None  # No processor
        sidecar._running = True
        
        await sidecar._cleanup()
        
        assert not sidecar._running
        assert sidecar._tick_processor is None