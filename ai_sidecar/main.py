"""
AI Sidecar main entry point.

This is the main module that starts the AI Sidecar service.
It initializes logging, creates the ZMQ server, and runs the main event loop.
"""

import asyncio
import signal
import sys
from typing import NoReturn

from ai_sidecar import __version__
from ai_sidecar.config import get_settings, get_config_summary
from ai_sidecar.utils.logging import setup_logging, get_logger
from ai_sidecar.ipc import ZMQServer
from ai_sidecar.core.tick import TickProcessor

logger = get_logger(__name__)


class AISidecar:
    """
    Main application class for the AI Sidecar.
    
    Coordinates the ZMQ server and tick processor.
    """
    
    def __init__(self) -> None:
        """Initialize the AI Sidecar."""
        self._settings = get_settings()
        self._server: ZMQServer | None = None
        self._tick_processor: TickProcessor | None = None
        self._shutdown_event = asyncio.Event()
        self._running = False
    
    async def start(self) -> None:
        """Start the AI Sidecar service."""
        if self._running:
            logger.warning("AI Sidecar already running")
            return
        
        logger.info(
            "Starting AI Sidecar",
            version=__version__,
            config=get_config_summary(),
        )
        
        # Create tick processor
        self._tick_processor = TickProcessor()
        await self._tick_processor.initialize()
        
        # Create ZMQ server with tick processor as message handler
        self._server = ZMQServer(
            message_handler=self._tick_processor.process_message,
        )
        
        self._running = True
        
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
    Run the AI Sidecar with signal handling.
    
    Sets up signal handlers for graceful shutdown.
    """
    sidecar = AISidecar()
    
    # Setup signal handlers
    loop = asyncio.get_running_loop()
    
    async def shutdown_handler() -> None:
        """Handle shutdown signal."""
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
        logger.info("Keyboard interrupt received")
    except Exception as e:
        logger.exception("Fatal error", error=str(e))
        sys.exit(1)
    finally:
        if sidecar.is_running:
            await sidecar.stop()


def main() -> NoReturn:
    """
    Main entry point.
    
    Initializes logging and runs the async event loop.
    """
    # Setup logging first
    setup_logging()
    
    logger.info("AI Sidecar starting", version=__version__)
    
    # Run the main async function
    try:
        asyncio.run(run_sidecar())
    except Exception as e:
        logger.exception("Unhandled exception", error=str(e))
        sys.exit(1)
    
    sys.exit(0)


if __name__ == "__main__":
    main()