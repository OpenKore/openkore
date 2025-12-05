"""
AI Sidecar main entry point.

This is the main module that starts the AI Sidecar service.
It initializes logging, creates the ZMQ server, and runs the main event loop.

Features:
- Startup progress indicators for user feedback
- Graceful shutdown with signal handling
- User-friendly error messages with recovery suggestions
"""

import asyncio
import signal
import sys
from typing import NoReturn

from ai_sidecar import __version__
from ai_sidecar.config import get_settings, get_config_summary, validate_config, print_config_help
from ai_sidecar.utils.logging import setup_logging, get_logger
from ai_sidecar.utils.startup import StartupProgress, show_quick_status
from ai_sidecar.utils.errors import (
    SidecarError,
    ConfigurationError,
    InitializationError,
    ZMQConnectionError,
    format_loading_error,
)
from ai_sidecar.ipc import ZMQServer
from ai_sidecar.core.tick import TickProcessor

logger = get_logger(__name__)


class AISidecar:
    """
    Main application class for the AI Sidecar.
    
    Coordinates the ZMQ server and tick processor with user feedback.
    """
    
    def __init__(self, progress: StartupProgress | None = None) -> None:
        """
        Initialize the AI Sidecar.
        
        Args:
            progress: Optional startup progress tracker for user feedback
        """
        self._progress = progress
        self._settings = get_settings()
        self._server: ZMQServer | None = None
        self._tick_processor: TickProcessor | None = None
        self._shutdown_event = asyncio.Event()
        self._running = False
    
    async def start(self) -> None:
        """Start the AI Sidecar service with progress feedback."""
        if self._running:
            logger.warning("AI Sidecar already running")
            return
        
        logger.info(
            "Starting AI Sidecar",
            version=__version__,
            config=get_config_summary(),
        )
        
        # Initialize tick processor with progress tracking
        try:
            if self._progress:
                with self._progress.step("Tick Processor", "Initializing AI decision engine"):
                    self._tick_processor = TickProcessor()
                    await self._tick_processor.initialize()
            else:
                self._tick_processor = TickProcessor()
                await self._tick_processor.initialize()
        except Exception as e:
            raise InitializationError(
                message="Failed to initialize tick processor",
                component="TickProcessor",
                original_error=e,
            )
        
        # Create ZMQ server with progress tracking
        try:
            if self._progress:
                with self._progress.step("ZMQ Server", "Setting up IPC communication") as step:
                    step.details["endpoint"] = self._settings.zmq.endpoint
                    self._server = ZMQServer(
                        message_handler=self._tick_processor.process_message,
                    )
            else:
                self._server = ZMQServer(
                    message_handler=self._tick_processor.process_message,
                )
        except Exception as e:
            raise ZMQConnectionError(
                message="Failed to create ZMQ server",
                endpoint=self._settings.zmq.endpoint,
                original_error=e,
            )
        
        self._running = True
        
        # Display ready message
        if self._progress:
            self._progress.display_summary()
        
        # Log ready status
        logger.info(
            "AI Sidecar ready",
            endpoint=self._settings.zmq.endpoint,
            tick_interval_ms=self._settings.tick.interval_ms,
        )
        print(f"\n✅ AI Sidecar ready! Listening on: {self._settings.zmq.endpoint}")
        print("   Press Ctrl+C to stop.\n")
        
        # Run server (blocks until shutdown)
        try:
            await self._server.start()
        except Exception as e:
            logger.exception("Server error", error=str(e))
            raise
        finally:
            await self._cleanup()
    
    async def stop(self) -> None:
        """Stop the AI Sidecar service."""
        if not self._running:
            return
        
        logger.info("Stopping AI Sidecar")
        self._shutdown_event.set()
        
        if self._server:
            await self._server.stop()
        
        await self._cleanup()
    
    async def _cleanup(self) -> None:
        """Clean up resources."""
        if self._tick_processor:
            await self._tick_processor.shutdown()
            self._tick_processor = None
        
        self._running = False
        logger.info("AI Sidecar stopped")
    
    @property
    def is_running(self) -> bool:
        """Check if the sidecar is running."""
        return self._running
    
    @property
    def stats(self) -> dict:
        """Get combined statistics."""
        stats = {
            "running": self._running,
            "version": __version__,
        }
        
        if self._server:
            stats["server"] = self._server.stats
        
        if self._tick_processor:
            stats["processor"] = self._tick_processor.stats
        
        return stats


async def run_sidecar() -> None:
    """
    Run the AI Sidecar with startup progress and signal handling.
    
    Provides user feedback during initialization and sets up graceful shutdown.
    """
    # Create startup progress tracker
    progress = StartupProgress()
    progress.display_banner()
    
    # Validate configuration first
    with progress.step("Config", "Validating configuration") as step:
        valid, issues = validate_config()
        if issues:
            for issue in issues:
                step.details[f"warning_{len(step.details)}"] = issue
                logger.warning("Configuration warning", issue=issue)
        
        if not valid:
            raise ConfigurationError(
                message="Configuration validation failed",
            )
    
    # Create sidecar with progress tracking
    sidecar = AISidecar(progress=progress)
    
    # Setup signal handlers
    loop = asyncio.get_running_loop()
    
    async def shutdown_handler() -> None:
        """Handle shutdown signal."""
        print("\n🛑 Shutting down gracefully...")
        logger.info("Received shutdown signal")
        await sidecar.stop()
    
    # Register signal handlers (Unix only)
    if sys.platform != "win32":
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(
                sig,
                lambda: asyncio.create_task(shutdown_handler()),
            )
    
    try:
        await sidecar.start()
    except KeyboardInterrupt:
        print("\n🛑 Keyboard interrupt received")
        logger.info("Keyboard interrupt received")
    except SidecarError as e:
        # User-friendly error with recovery suggestions
        print(e.format_error())
        logger.error("Startup failed", error=str(e), category=e.category.value)
        sys.exit(1)
    except Exception as e:
        # Unknown error - wrap with helpful message
        print(format_loading_error("AI Sidecar", e))
        logger.exception("Fatal error", error=str(e))
        sys.exit(1)
    finally:
        if sidecar.is_running:
            await sidecar.stop()
        print("\n👋 AI Sidecar stopped. Goodbye!")


def main() -> NoReturn:
    """
    Main entry point.
    
    Initializes logging and runs the async event loop with user feedback.
    """
    # Parse command line arguments for help
    if "--help" in sys.argv or "-h" in sys.argv:
        print_config_help()
        sys.exit(0)
    
    if "--version" in sys.argv or "-v" in sys.argv:
        print(f"AI Sidecar v{__version__}")
        sys.exit(0)
    
    # Setup logging first
    try:
        setup_logging()
    except Exception as e:
        print(f"❌ Failed to setup logging: {e}")
        print("   Check your AI_LOG_* environment variables.")
        sys.exit(1)
    
    logger.info("AI Sidecar starting", version=__version__)
    
    # Run the main async function
    try:
        asyncio.run(run_sidecar())
    except KeyboardInterrupt:
        # Already handled in run_sidecar
        pass
    except SidecarError as e:
        # Already logged and displayed
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        print("   Please check the logs for more details.")
        print("   If this persists, report at: https://github.com/openkore/openkore/issues")
        logger.exception("Unhandled exception", error=str(e))
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()