"""
AI Sidecar main entry point.

This is the main module that starts the AI Sidecar service.
It initializes logging, creates the ZMQ server, and runs the main event loop.

Features:
- Startup progress indicators for user feedback
- Graceful shutdown with signal handling
- User-friendly error messages with recovery suggestions
- CLI debug controls (--debug, --verbose, --trace, --profile)
- Cross-platform support with automatic endpoint selection
"""

import argparse
import asyncio
import os
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
from ai_sidecar.utils.platform import detect_platform, PlatformInfo
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


def parse_arguments() -> argparse.Namespace:
    """
    Parse command line arguments.
    
    Returns:
        Parsed arguments namespace
    """
    parser = argparse.ArgumentParser(
        description="OpenKore AI Sidecar - Intelligent game automation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                          Start with default settings
  %(prog)s --debug                   Enable debug logging
  %(prog)s --verbose                 Enable verbose output
  %(prog)s --trace                   Enable trace-level logging
  %(prog)s --debug-modules combat,memory  Debug specific modules only
  %(prog)s --profile                 Enable performance profiling
  
Environment Variables:
  AI_LOG_LEVEL                       Set log level (DEBUG, INFO, WARNING, ERROR)
  AI_DEBUG_MODULES                   Comma-separated list of modules to debug
  AI_DEBUG_PROFILE                   Enable profiling (true/false)
  
For configuration help:
  %(prog)s --config-help
        """,
    )
    
    # Version
    parser.add_argument(
        "-v", "--version",
        action="version",
        version=f"AI Sidecar v{__version__}",
    )
    
    # Debug flags
    parser.add_argument(
        "-d", "--debug",
        action="store_true",
        help="Enable debug logging (sets AI_LOG_LEVEL=DEBUG)",
    )
    
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose output (same as --debug)",
    )
    
    parser.add_argument(
        "--trace",
        action="store_true",
        help="Enable trace-level logging (maximum verbosity)",
    )
    
    parser.add_argument(
        "--debug-modules",
        type=str,
        metavar="MODULES",
        help="Comma-separated list of modules to debug (e.g., combat,memory,ipc)",
    )
    
    # Performance profiling
    parser.add_argument(
        "--profile",
        action="store_true",
        help="Enable performance profiling (creates .prof files)",
    )
    
    parser.add_argument(
        "--profile-dir",
        type=str,
        default="profiles",
        metavar="DIR",
        help="Directory for profile output (default: profiles/)",
    )
    
    # Configuration help
    parser.add_argument(
        "--config-help",
        action="store_true",
        help="Display configuration help and exit",
    )
    
    return parser.parse_args()


def apply_cli_overrides(args: argparse.Namespace) -> None:
    """
    Apply CLI argument overrides to environment variables.
    
    This allows CLI flags to override environment and config file settings.
    
    Args:
        args: Parsed command line arguments
    """
    # Debug level overrides
    if args.trace:
        os.environ["AI_LOG_LEVEL"] = "DEBUG"
        os.environ["AI_DEBUG_MODE"] = "trace"
    elif args.debug or args.verbose:
        os.environ["AI_LOG_LEVEL"] = "DEBUG"
        os.environ["AI_DEBUG_MODE"] = "debug"
    
    # Module filtering
    if args.debug_modules:
        os.environ["AI_DEBUG_MODULES"] = args.debug_modules
    
    # Profiling
    if args.profile:
        os.environ["AI_DEBUG_PROFILE"] = "true"
        os.environ["AI_DEBUG_PROFILE_DIR"] = args.profile_dir


def main() -> NoReturn:
    """
    Main entry point.
    
    Parses CLI arguments, initializes logging, and runs the async event loop.
    """
    # Parse command line arguments
    args = parse_arguments()
    
    # Handle config help
    if args.config_help:
        print_config_help()
        sys.exit(0)
    
    # Apply CLI overrides to environment
    apply_cli_overrides(args)
    
    # Setup logging with CLI settings
    try:
        setup_logging()
    except Exception as e:
        print(f"❌ Failed to setup logging: {e}")
        print("   Check your AI_LOG_* environment variables.")
        sys.exit(1)
    
    logger.info("AI Sidecar starting", version=__version__)
    
    # Log platform detection results for cross-platform debugging
    _log_platform_info()
    
    # Log debug configuration if enabled
    if args.debug or args.verbose or args.trace:
        debug_mode = os.getenv("AI_DEBUG_MODE", "debug")
        modules = os.getenv("AI_DEBUG_MODULES", "all")
        logger.info(
            "Debug mode enabled",
            mode=debug_mode,
            modules=modules,
            profile=args.profile,
        )
    
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


def _log_platform_info() -> None:
    """
    Log platform detection results for debugging cross-platform issues.
    
    This helps diagnose endpoint selection and IPC compatibility issues
    by providing detailed platform information at startup.
    """
    platform_info: PlatformInfo = detect_platform()
    settings = get_settings()
    
    # Log platform detection at info level for visibility
    logger.info(
        "Platform detected",
        platform=platform_info.platform_name,
        platform_type=platform_info.platform_type.value,
        supports_ipc=platform_info.can_use_ipc,
        is_container=platform_info.is_container,
        wsl_version=platform_info.wsl_version,
    )
    
    # Log endpoint selection reasoning
    endpoint = settings.zmq.endpoint
    endpoint_type = "ipc" if endpoint.startswith("ipc://") else "tcp"
    
    logger.info(
        "Endpoint configured",
        endpoint=endpoint,
        endpoint_type=endpoint_type,
        default_endpoint=platform_info.default_endpoint,
        using_default=(endpoint == platform_info.default_endpoint),
    )
    
    # Warn if IPC used on unsupported platform
    if endpoint.startswith("ipc://") and not platform_info.can_use_ipc:
        logger.warning(
            "IPC endpoint on unsupported platform",
            endpoint=endpoint,
            platform=platform_info.platform_name,
            recommended=platform_info.default_tcp_endpoint,
            hint="Consider using TCP endpoint for this platform",
        )


if __name__ == "__main__":
    main()