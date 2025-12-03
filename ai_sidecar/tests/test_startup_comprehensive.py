"""
Comprehensive tests for startup.py - covering all uncovered lines.
Target: 100% coverage of startup feedback and progress indicators.
"""

import pytest
import asyncio
import sys
from datetime import timedelta
from io import StringIO
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.utils.startup import (
    StepStatus,
    StartupStep,
    StartupProgress,
    SpinnerProgress,
    show_quick_status,
    format_loading_error,
    wait_with_progress,
)


class TestStartupStep:
    """Test StartupStep dataclass."""

    def test_step_creation(self):
        """Test creating a startup step."""
        step = StartupStep(
            name="Test Step", description="Testing step creation"
        )
        assert step.name == "Test Step"
        assert step.description == "Testing step creation"
        assert step.status == StepStatus.PENDING
        assert step.duration_ms == 0.0

    def test_status_icon(self):
        """Test status icon property."""
        step = StartupStep(name="Test", description="Test")
        
        step.status = StepStatus.PENDING
        assert step.status_icon == "⏳"
        
        step.status = StepStatus.RUNNING
        assert step.status_icon == "🔄"
        
        step.status = StepStatus.SUCCESS
        assert step.status_icon == "✅"
        
        step.status = StepStatus.FAILED
        assert step.status_icon == "❌"
        
        step.status = StepStatus.SKIPPED
        assert step.status_icon == "⏭️"
        
        step.status = StepStatus.WARNING
        assert step.status_icon == "⚠️"


class TestStartupProgress:
    """Test StartupProgress class."""

    def test_init_default(self):
        """Test initialization with defaults."""
        progress = StartupProgress()
        assert progress.show_banner is True
        assert progress.show_progress is True
        assert len(progress._steps) == 0

    def test_init_custom(self):
        """Test initialization with custom output."""
        output = Mock()
        progress = StartupProgress(
            show_banner=False,
            show_progress=False,
            output=output
        )
        assert progress.show_banner is False
        assert progress.show_progress is False
        assert progress._output == output

    def test_display_banner(self):
        """Test displaying banner."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with patch('ai_sidecar.utils.startup._get_version', return_value='1.0.0'):
            progress.display_banner()
        
        output.assert_called()
        call_args = output.call_args[0][0]
        assert "AI Sidecar" in call_args
        assert "1.0.0" in call_args

    def test_display_banner_disabled(self):
        """Test banner not displayed when disabled."""
        output = Mock()
        progress = StartupProgress(show_banner=False, output=output)
        progress.display_banner()
        output.assert_not_called()

    def test_add_step(self):
        """Test adding a step."""
        progress = StartupProgress()
        step = progress.add_step("Test", "Testing")
        
        assert step.name == "Test"
        assert step.description == "Testing"
        assert step in progress._steps

    def test_step_context_success(self):
        """Test step context manager success."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Load", "Loading config") as step:
            assert step.status == StepStatus.RUNNING
            step.details["file"] = "config.yaml"
        
        assert step.status == StepStatus.SUCCESS
        assert step.duration_ms > 0
        assert "file" in step.details

    def test_step_context_failure_critical(self):
        """Test step context manager with critical failure."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with pytest.raises(ValueError):
            with progress.step("Load", "Loading config", critical=True):
                raise ValueError("Test error")
        
        assert len(progress._steps) == 1
        step = progress._steps[0]
        assert step.status == StepStatus.FAILED
        assert step.error == "Test error"

    def test_step_context_failure_non_critical(self):
        """Test step context manager with non-critical failure."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Load", "Loading config", critical=False):
            raise ValueError("Test error")
        
        step = progress._steps[0]
        assert step.status == StepStatus.FAILED

    def test_step_context_no_progress(self):
        """Test step context with progress disabled."""
        output = Mock()
        progress = StartupProgress(show_progress=False, output=output)
        
        with progress.step("Load", "Loading"):
            pass
        
        # Should still track step, just not output
        assert len(progress._steps) == 1

    def test_skip_step(self):
        """Test skipping a step."""
        output = Mock()
        progress = StartupProgress(output=output)
        progress.skip_step("Optional", "Not needed")
        
        assert len(progress._steps) == 1
        step = progress._steps[0]
        assert step.status == StepStatus.SKIPPED
        assert step.name == "Optional"

    def test_warn_step(self):
        """Test warning step."""
        output = Mock()
        progress = StartupProgress(output=output)
        progress.warn_step("Config", "Using defaults")
        
        assert len(progress._steps) == 1
        step = progress._steps[0]
        assert step.status == StepStatus.WARNING
        assert step.error == "Using defaults"

    def test_display_summary_success(self):
        """Test displaying success summary."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Step1", "First step"):
            pass
        with progress.step("Step2", "Second step"):
            pass
        
        progress.display_summary()
        
        # Check output was called
        calls = output.call_args_list
        assert len(calls) > 0
        
        # Check for success message
        summary_calls = [c for c in calls if "Startup complete" in str(c)]
        assert len(summary_calls) > 0

    def test_display_summary_with_failures(self):
        """Test displaying summary with failures."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Step1", "First step"):
            pass
        
        with progress.step("Step2", "Second step", critical=False):
            raise ValueError("Error")
        
        progress.display_summary()
        
        calls = output.call_args_list
        failure_calls = [c for c in calls if "Startup failed" in str(c)]
        assert len(failure_calls) > 0

    def test_display_summary_with_warnings(self):
        """Test displaying summary with warnings."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Step1", "First step"):
            pass
        
        progress.warn_step("Config", "Using defaults")
        
        progress.display_summary()
        
        calls = output.call_args_list
        warning_calls = [c for c in calls if "Warnings:" in str(c)]
        assert len(warning_calls) > 0

    def test_display_summary_with_skipped(self):
        """Test displaying summary with skipped steps."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Step1", "First step"):
            pass
        
        progress.skip_step("Optional", "Not needed")
        
        progress.display_summary()
        
        # Verify skipped count is included
        calls = output.call_args_list
        assert any("skipped" in str(c).lower() for c in calls)

    def test_success_property(self):
        """Test success property."""
        progress = StartupProgress()
        
        with progress.step("Step1", "First step"):
            pass
        
        assert progress.success is True
        
        with progress.step("Step2", "Second step", critical=False):
            raise ValueError("Error")
        
        assert progress.success is False

    def test_steps_property(self):
        """Test steps property returns copy."""
        progress = StartupProgress()
        
        with progress.step("Step1", "First step"):
            pass
        
        steps = progress.steps
        assert len(steps) == 1
        
        # Modifying returned list shouldn't affect internal
        steps.clear()
        assert len(progress._steps) == 1


class TestSpinnerProgress:
    """Test SpinnerProgress class."""

    def test_init(self):
        """Test spinner initialization."""
        spinner = SpinnerProgress(message="Loading", spinner_type="dots", interval_ms=100)
        assert spinner.message == "Loading"
        assert spinner._interval == 0.1
        assert spinner._running is False

    def test_init_invalid_spinner_type(self):
        """Test spinner with invalid type."""
        spinner = SpinnerProgress(spinner_type="invalid")
        # Should default to dots
        assert spinner._frames == SpinnerProgress.SPINNERS["dots"]

    @pytest.mark.asyncio
    async def test_start_stop(self):
        """Test starting and stopping spinner."""
        spinner = SpinnerProgress(message="Loading")
        
        await spinner.start()
        assert spinner._running is True
        assert spinner._task is not None
        
        await asyncio.sleep(0.2)  # Let it animate
        
        await spinner.stop("Done")
        assert spinner._running is False

    @pytest.mark.asyncio
    async def test_start_already_running(self):
        """Test starting spinner that's already running."""
        spinner = SpinnerProgress()
        
        await spinner.start()
        task1 = spinner._task
        
        await spinner.start()  # Should not create new task
        assert spinner._task == task1
        
        await spinner.stop()

    @pytest.mark.asyncio
    async def test_fail(self):
        """Test failing spinner."""
        spinner = SpinnerProgress(message="Loading")
        
        await spinner.start()
        await asyncio.sleep(0.1)
        await spinner.fail("Error occurred")
        
        assert spinner._running is False

    @pytest.mark.asyncio
    async def test_animation_frames(self):
        """Test spinner uses different frames."""
        spinner = SpinnerProgress(interval_ms=50)
        
        await spinner.start()
        await asyncio.sleep(0.15)  # Should cycle through frames
        await spinner.stop()
        
        assert spinner._frame_idx > 0


class TestUtilityFunctions:
    """Test utility functions."""

    def test_show_quick_status(self):
        """Test showing quick status."""
        config = {
            "server_host": "localhost",
            "server_port": 8000,
            "log_level": "INFO",
            "ai_enabled": True,
        }
        
        with patch('builtins.print') as mock_print:
            show_quick_status(config)
            mock_print.assert_called()

    def test_show_quick_status_with_categories(self):
        """Test status with categorized config."""
        config = {
            "server_host": "localhost",
            "ai_enabled": True,
            "memory_size": 1000,
        }
        
        with patch('builtins.print') as mock_print:
            show_quick_status(config)
            
            # Check that categories are shown
            calls = [str(c) for c in mock_print.call_args_list]
            assert any("Server:" in c for c in calls)

    def test_show_quick_status_long_values(self):
        """Test status truncates long values."""
        config = {
            "long_value": "x" * 100,
        }
        
        with patch('builtins.print') as mock_print:
            show_quick_status(config)
            
            calls = [str(c) for c in mock_print.call_args_list]
            # Should have truncated with ...
            assert any("..." in c for c in calls)

    def test_format_loading_error(self):
        """Test formatting loading error."""
        error = ValueError("Test error message")
        result = format_loading_error("ConfigLoader", error)
        
        assert "ConfigLoader" in result
        assert "Test error message" in result
        assert "Suggestions:" in result

    def test_format_loading_error_long_message(self):
        """Test formatting error with long message."""
        error = ValueError("x" * 100)
        result = format_loading_error("Component", error)
        
        # Should truncate long error messages
        assert len(result) < 1000

    @pytest.mark.asyncio
    async def test_wait_with_progress_success(self):
        """Test waiting with progress."""
        async def quick_task():
            await asyncio.sleep(0.1)
            return "result"
        
        future = asyncio.create_task(quick_task())
        result = await wait_with_progress(future, "Processing", timeout=1.0)
        
        assert result == "result"

    @pytest.mark.asyncio
    async def test_wait_with_progress_timeout(self):
        """Test waiting with timeout."""
        async def slow_task():
            await asyncio.sleep(10)
            return "result"
        
        future = asyncio.create_task(slow_task())
        
        with pytest.raises(asyncio.TimeoutError):
            await wait_with_progress(future, "Processing", timeout=0.1)

    @pytest.mark.asyncio
    async def test_wait_with_progress_error(self):
        """Test waiting with task error."""
        async def error_task():
            await asyncio.sleep(0.1)
            raise ValueError("Task failed")
        
        future = asyncio.create_task(error_task())
        
        with pytest.raises(ValueError):
            await wait_with_progress(future, "Processing")


class TestVersionFunction:
    """Test version retrieval."""

    def test_get_version(self):
        """Test getting version."""
        from ai_sidecar.utils.startup import _get_version
        
        with patch('ai_sidecar.__version__', '1.2.3'):
            version = _get_version()
            assert version == '1.2.3'


class TestStartupProgressIntegration:
    """Integration tests for startup progress."""

    def test_full_startup_sequence(self):
        """Test full startup sequence."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        progress.display_banner()
        
        with progress.step("Config", "Loading configuration"):
            pass
        
        with progress.step("Database", "Connecting to database"):
            pass
        
        progress.skip_step("Optional", "Feature not enabled")
        progress.warn_step("Cache", "Cache not available")
        
        progress.display_summary()
        
        assert progress.success is True
        assert len(progress._steps) == 4

    def test_startup_with_failure(self):
        """Test startup sequence with failure."""
        output = Mock()
        progress = StartupProgress(output=output)
        
        with progress.step("Config", "Loading"):
            pass
        
        try:
            with progress.step("Database", "Connecting", critical=True):
                raise ConnectionError("Cannot connect")
        except ConnectionError:
            pass
        
        progress.display_summary()
        
        assert progress.success is False
        assert any(s.status == StepStatus.FAILED for s in progress._steps)


class TestDefaultOutput:
    """Test default output function."""

    def test_default_output(self):
        """Test default output function."""
        progress = StartupProgress()
        
        with patch('sys.stdout', new=StringIO()) as fake_out:
            progress._default_output("Test message")
            output = fake_out.getvalue()
            assert "Test message" in output