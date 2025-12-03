"""
Startup feedback and progress indicators for AI Sidecar.

Provides visual feedback during initialization to help users understand
what's happening and identify potential issues early.
"""

import asyncio
import sys
import time
from contextlib import contextmanager
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable, Generator


def _get_version() -> str:
    """Get version lazily to avoid circular import.
    
    This function defers the import of __version__ until runtime
    rather than module load time, breaking the circular dependency
    chain: startup.py -> ai_sidecar -> config.py -> utils -> startup.py
    """
    from ai_sidecar import __version__
    return __version__


class StepStatus(str, Enum):
    """Status of an initialization step."""
    
    PENDING = "pending"
    RUNNING = "running"
    SUCCESS = "success"
    FAILED = "failed"
    SKIPPED = "skipped"
    WARNING = "warning"


@dataclass
class StartupStep:
    """
    Represents a single initialization step.
    
    Attributes:
        name: Human-readable step name
        description: What this step does
        status: Current status
        duration_ms: Time taken in milliseconds
        error: Error message if failed
        details: Additional details
    """
    
    name: str
    description: str
    status: StepStatus = StepStatus.PENDING
    duration_ms: float = 0.0
    error: str | None = None
    details: dict[str, Any] = field(default_factory=dict)
    
    @property
    def status_icon(self) -> str:
        """Get status icon for display."""
        icons = {
            StepStatus.PENDING: "⏳",
            StepStatus.RUNNING: "🔄",
            StepStatus.SUCCESS: "✅",
            StepStatus.FAILED: "❌",
            StepStatus.SKIPPED: "⏭️",
            StepStatus.WARNING: "⚠️",
        }
        return icons.get(self.status, "?")


class StartupProgress:
    """
    Manages startup progress display and tracking.
    
    Provides visual feedback during the initialization process,
    showing what's loading and any issues encountered.
    """
    
    def __init__(
        self,
        show_banner: bool = True,
        show_progress: bool = True,
        output: Callable[[str], None] | None = None,
    ) -> None:
        """
        Initialize startup progress tracker.
        
        Args:
            show_banner: Whether to show startup banner
            show_progress: Whether to show progress indicators
            output: Custom output function (default: print)
        """
        self.show_banner = show_banner
        self.show_progress = show_progress
        self._output = output or self._default_output
        self._steps: list[StartupStep] = []
        self._current_step: StartupStep | None = None
        self._start_time = time.monotonic()
    
    def _default_output(self, msg: str) -> None:
        """Default output to stdout."""
        print(msg, flush=True)
    
    def display_banner(self) -> None:
        """Display the startup banner."""
        if not self.show_banner:
            return
        
        version = _get_version()
        banner = f"""
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   🤖 AI Sidecar for OpenKore                                 ║
║   Version: {version:<46}║
║                                                              ║
║   God-Tier Ragnarok Online AI System                         ║
║   Adaptive • Intelligent • Human-Like                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
"""
        self._output(banner)
    
    def add_step(self, name: str, description: str) -> StartupStep:
        """
        Add an initialization step.
        
        Args:
            name: Step name
            description: What the step does
            
        Returns:
            The created step object
        """
        step = StartupStep(name=name, description=description)
        self._steps.append(step)
        return step
    
    @contextmanager
    def step(
        self,
        name: str,
        description: str,
        critical: bool = True,
    ) -> Generator[StartupStep, None, None]:
        """
        Context manager for tracking a step's progress.
        
        Args:
            name: Step name
            description: What the step does
            critical: If True, failure stops startup
            
        Yields:
            The step object
            
        Example:
            with progress.step("Config", "Loading configuration") as step:
                load_config()
                step.details["config_file"] = "config.yaml"
        """
        step = self.add_step(name, description)
        self._current_step = step
        step.status = StepStatus.RUNNING
        
        if self.show_progress:
            self._output(f"  {step.status_icon} {name}: {description}...")
        
        start = time.monotonic()
        
        try:
            yield step
            
            step.duration_ms = (time.monotonic() - start) * 1000
            step.status = StepStatus.SUCCESS
            
            if self.show_progress:
                self._output(
                    f"  {step.status_icon} {name}: Done ({step.duration_ms:.0f}ms)"
                )
        
        except Exception as e:
            step.duration_ms = (time.monotonic() - start) * 1000
            step.status = StepStatus.FAILED
            step.error = str(e)
            
            if self.show_progress:
                self._output(f"  {step.status_icon} {name}: FAILED - {e}")
            
            if critical:
                raise
        
        finally:
            self._current_step = None
    
    def skip_step(self, name: str, reason: str) -> None:
        """
        Record a skipped step.
        
        Args:
            name: Step name
            reason: Why it was skipped
        """
        step = self.add_step(name, reason)
        step.status = StepStatus.SKIPPED
        
        if self.show_progress:
            self._output(f"  {step.status_icon} {name}: Skipped - {reason}")
    
    def warn_step(self, name: str, warning: str) -> None:
        """
        Record a warning for a step.
        
        Args:
            name: Step name
            warning: Warning message
        """
        step = self.add_step(name, warning)
        step.status = StepStatus.WARNING
        step.error = warning
        
        if self.show_progress:
            self._output(f"  {step.status_icon} {name}: {warning}")
    
    def display_summary(self) -> None:
        """Display startup summary."""
        total_time = (time.monotonic() - self._start_time) * 1000
        
        success_count = sum(1 for s in self._steps if s.status == StepStatus.SUCCESS)
        failed_count = sum(1 for s in self._steps if s.status == StepStatus.FAILED)
        warning_count = sum(1 for s in self._steps if s.status == StepStatus.WARNING)
        skipped_count = sum(1 for s in self._steps if s.status == StepStatus.SKIPPED)
        
        self._output("")
        self._output("─" * 60)
        
        if failed_count == 0:
            self._output(f"✅ Startup complete in {total_time:.0f}ms")
        else:
            self._output(f"❌ Startup failed after {total_time:.0f}ms")
        
        self._output(
            f"   Steps: {success_count} succeeded, {failed_count} failed, "
            f"{warning_count} warnings, {skipped_count} skipped"
        )
        
        if warning_count > 0:
            self._output("")
            self._output("⚠️ Warnings:")
            for step in self._steps:
                if step.status == StepStatus.WARNING:
                    self._output(f"   • {step.name}: {step.error}")
        
        if failed_count > 0:
            self._output("")
            self._output("❌ Failures:")
            for step in self._steps:
                if step.status == StepStatus.FAILED:
                    self._output(f"   • {step.name}: {step.error}")
        
        self._output("─" * 60)
    
    @property
    def success(self) -> bool:
        """Check if all critical steps succeeded."""
        return not any(s.status == StepStatus.FAILED for s in self._steps)
    
    @property
    def steps(self) -> list[StartupStep]:
        """Get all tracked steps."""
        return self._steps.copy()


class SpinnerProgress:
    """
    Animated spinner for long-running operations.
    
    Provides visual feedback that something is happening
    during operations that might take a while.
    """
    
    SPINNERS = {
        "dots": ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
        "braille": ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
        "arrows": ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"],
        "simple": ["|", "/", "-", "\\"],
    }
    
    def __init__(
        self,
        message: str = "Loading",
        spinner_type: str = "dots",
        interval_ms: int = 100,
    ) -> None:
        """
        Initialize spinner.
        
        Args:
            message: Message to display
            spinner_type: Type of spinner animation
            interval_ms: Animation interval
        """
        self.message = message
        self._frames = self.SPINNERS.get(spinner_type, self.SPINNERS["dots"])
        self._interval = interval_ms / 1000
        self._frame_idx = 0
        self._running = False
        self._task: asyncio.Task | None = None
    
    async def _animate(self) -> None:
        """Run the animation loop."""
        try:
            while self._running:
                frame = self._frames[self._frame_idx % len(self._frames)]
                sys.stdout.write(f"\r  {frame} {self.message}...")
                sys.stdout.flush()
                self._frame_idx += 1
                await asyncio.sleep(self._interval)
        except asyncio.CancelledError:
            pass
        finally:
            # Clear the line
            sys.stdout.write("\r" + " " * (len(self.message) + 10) + "\r")
            sys.stdout.flush()
    
    async def start(self) -> None:
        """Start the spinner animation."""
        if self._running:
            return
        
        self._running = True
        self._task = asyncio.create_task(self._animate())
    
    async def stop(self, status: str = "Done") -> None:
        """
        Stop the spinner and show final status.
        
        Args:
            status: Final status message
        """
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        print(f"  ✅ {self.message}: {status}")
    
    async def fail(self, error: str) -> None:
        """
        Stop the spinner with failure status.
        
        Args:
            error: Error message
        """
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        
        print(f"  ❌ {self.message}: {error}")


def show_quick_status(config: dict[str, Any]) -> None:
    """
    Show a quick status display of configuration.
    
    Args:
        config: Configuration dictionary
    """
    print("\n📋 Configuration Summary:")
    print("─" * 40)
    
    # Group by category
    grouped: dict[str, list[tuple[str, Any]]] = {}
    
    for key, value in config.items():
        if "_" in key:
            category = key.split("_")[0].title()
        else:
            category = "General"
        
        if category not in grouped:
            grouped[category] = []
        grouped[category].append((key, value))
    
    for category, items in sorted(grouped.items()):
        print(f"\n  {category}:")
        for key, value in items:
            # Truncate long values
            str_value = str(value)
            if len(str_value) > 40:
                str_value = str_value[:37] + "..."
            print(f"    • {key}: {str_value}")
    
    print("\n" + "─" * 40)


def format_loading_error(component: str, error: Exception) -> str:
    """
    Format a loading error with helpful context.
    
    Args:
        component: Component that failed to load
        error: The exception that occurred
        
    Returns:
        Formatted error message
    """
    return f"""
╔══════════════════════════════════════════════════════════════╗
║ ❌ Failed to load: {component:<39}║
╠══════════════════════════════════════════════════════════════╣
║ Error: {str(error)[:50]:<51}║
║                                                              ║
║ 💡 Suggestions:                                              ║
║   1. Check the logs for detailed error information           ║
║   2. Verify all dependencies are installed                   ║
║   3. Review configuration in config.yaml                     ║
║   4. Try: pip install -r requirements.txt                    ║
╚══════════════════════════════════════════════════════════════╝
"""


async def wait_with_progress(
    future: asyncio.Future | asyncio.Task,
    message: str = "Processing",
    timeout: float = 30.0,
) -> Any:
    """
    Wait for a future with progress indication.
    
    Args:
        future: The async operation to wait for
        message: Progress message
        timeout: Timeout in seconds
        
    Returns:
        Result of the future
        
    Raises:
        asyncio.TimeoutError: If operation times out
    """
    spinner = SpinnerProgress(message)
    await spinner.start()
    
    try:
        result = await asyncio.wait_for(future, timeout=timeout)
        await spinner.stop()
        return result
    except asyncio.TimeoutError:
        await spinner.fail(f"Timeout after {timeout}s")
        raise
    except Exception as e:
        await spinner.fail(str(e))
        raise


def check_dependencies() -> bool:
    """
    Check if all dependencies are installed.
    
    Returns:
        True if all dependencies are present, False otherwise
    """
    required_packages = ["structlog", "pydantic", "zmq"]
    missing = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)
    
    return len(missing) == 0


def load_config() -> dict:
    """
    Load configuration from file or environment.
    
    Returns:
        Configuration dictionary
    """
    from ai_sidecar.config import get_settings
    
    try:
        settings = get_settings()
        return {
            "app_name": settings.app_name,
            "version": settings.version if hasattr(settings, 'version') else "unknown",
            "logging_level": settings.logging.level,
        }
    except Exception as e:
        logger = get_logger(__name__)
        logger.error("config_load_failed", error=str(e))
        return {}


def validate_environment() -> bool:
    """
    Validate environment for running AI Sidecar.
    
    Checks:
    - Python version
    - Required dependencies
    - Configuration validity
    - System resources
    
    Returns:
        True if environment is valid, False otherwise
    """
    import platform
    import sys
    
    from ai_sidecar.utils.logging import get_logger
    
    # Check Python version
    python_version = sys.version_info
    if python_version < (3, 10):
        raise RuntimeError(
            f"Python 3.10+ required, found {python_version.major}.{python_version.minor}"
        )
    
    # Check for critical dependencies
    required_packages = ["structlog", "pydantic", "zmq"]
    missing = []
    
    for package in required_packages:
        try:
            __import__(package)
        except ImportError:
            missing.append(package)
    
    if missing:
        raise RuntimeError(
            f"Missing required packages: {', '.join(missing)}. "
            "Install with: pip install -r requirements.txt"
        )
    
    logger = get_logger(__name__)
    logger.info(
        "environment_validated",
        python_version=f"{python_version.major}.{python_version.minor}.{python_version.micro}",
        platform=platform.system(),
    )
    
    return True