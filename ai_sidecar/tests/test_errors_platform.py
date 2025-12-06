"""
Unit tests for PlatformCompatibilityError class.

Tests error creation, messages, platform context inclusion,
recovery suggestions, and integration with config validation.
"""

import pytest

from ai_sidecar.utils.errors import (
    PlatformCompatibilityError,
    SidecarError,
    RecoverySuggestion,
    ErrorCategory,
)
from ai_sidecar.utils.platform import PlatformType


# =============================================================================
# Test PlatformCompatibilityError Creation
# =============================================================================

class TestPlatformCompatibilityErrorCreation:
    """Test PlatformCompatibilityError instantiation."""
    
    def test_create_basic_error(self):
        """Test creating a basic platform compatibility error."""
        error = PlatformCompatibilityError(
            message="IPC not supported on this platform",
            platform_name="Windows",
            platform_type="windows",
            operation="socket_bind",
        )
        
        assert "IPC not supported" in str(error)
        assert error.platform_name == "Windows"
        assert error.platform_type == "windows"
        assert error.operation == "socket_bind"
    
    def test_create_error_with_platform_type_enum(self):
        """Test creating error with PlatformType enum value."""
        error = PlatformCompatibilityError(
            message="IPC not supported",
            platform_name="Windows",
            platform_type=PlatformType.WINDOWS.value,
            operation="endpoint_config",
        )
        
        assert error.platform_type == "windows"
    
    def test_error_inherits_from_sidecar_error(self):
        """Test that error inherits from SidecarError."""
        error = PlatformCompatibilityError(
            message="Test",
            platform_name="Test",
            platform_type="unknown",
            operation="test",
        )
        
        assert isinstance(error, SidecarError)
        assert isinstance(error, Exception)
    
    def test_error_has_suggestions(self):
        """Test that error has auto-generated suggestions."""
        error = PlatformCompatibilityError(
            message="IPC not supported",
            platform_name="Windows",
            platform_type="windows",
            operation="ipc_bind",
        )
        
        # Should have auto-generated suggestions
        assert len(error.suggestions) > 0
        assert isinstance(error.suggestions[0], RecoverySuggestion)


# =============================================================================
# Test Factory Methods
# =============================================================================

class TestFactoryMethods:
    """Test factory methods for common error scenarios."""
    
    def test_ipc_not_supported_windows(self):
        """Test IPC not supported factory for Windows."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="Windows",
            platform_type="windows",
            endpoint="ipc:///tmp/test.sock",
        )
        
        assert "IPC" in str(error)
        assert "Windows" in str(error)
        assert error.platform_type == "windows"
        # Should have suggestions
        assert len(error.suggestions) > 0
    
    def test_ipc_not_supported_wsl1(self):
        """Test IPC not supported factory for WSL1."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="WSL1",
            platform_type="wsl",
            endpoint="ipc:///tmp/wsl.sock",
        )
        
        assert error.platform_type == "wsl"
    
    def test_ipc_not_supported_with_tcp_alternative(self):
        """Test IPC not supported factory with custom TCP alternative."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="Windows",
            platform_type="windows",
            endpoint="ipc:///tmp/test.sock",
            tcp_alternative="tcp://localhost:6666",
        )
        
        assert error.alternative_suggestion is not None
        assert "6666" in error.alternative_suggestion
    
    def test_socket_cleanup_failed(self):
        """Test socket cleanup failed factory."""
        error = PlatformCompatibilityError.socket_cleanup_failed(
            socket_path="/tmp/test.sock",
            platform_name="Linux",
            platform_type="unix_like",
            reason="Permission denied",
        )
        
        assert "cleanup" in str(error).lower() or "test.sock" in str(error)
        assert "Permission denied" in str(error)
        assert error.platform_type == "unix_like"
    
    def test_socket_cleanup_failed_with_original_error(self):
        """Test socket cleanup factory with original exception."""
        original = PermissionError("Access denied")
        error = PlatformCompatibilityError.socket_cleanup_failed(
            socket_path="/tmp/test.sock",
            platform_name="Linux",
            platform_type="unix_like",
            reason="Permission denied",
            original_error=original,
        )
        
        assert error.original_error is original


# =============================================================================
# Test Error Messages
# =============================================================================

class TestErrorMessages:
    """Test error message content and formatting."""
    
    def test_message_contains_platform_info(self):
        """Test that error context includes platform information."""
        error = PlatformCompatibilityError(
            message="Feature not available",
            platform_name="Cygwin",
            platform_type="cygwin",
            operation="ipc_bind",
        )
        
        # Platform info should be in context
        assert error.context["platform_name"] == "Cygwin"
        assert error.context["platform_type"] == "cygwin"
    
    def test_message_contains_operation(self):
        """Test that context includes the failed operation."""
        error = PlatformCompatibilityError(
            message="Cannot perform operation",
            platform_name="Windows",
            platform_type="windows",
            operation="socket_cleanup",
        )
        
        assert error.operation == "socket_cleanup"
        assert error.context["operation"] == "socket_cleanup"
    
    def test_format_error_output(self):
        """Test formatted error output."""
        error = PlatformCompatibilityError(
            message="IPC not supported",
            platform_name="Windows",
            platform_type="windows",
            operation="bind",
        )
        
        formatted = error.format_error()
        
        assert "Error" in formatted
        assert len(formatted) > 50  # Should have substantial output


# =============================================================================
# Test Recovery Suggestions
# =============================================================================

class TestRecoverySuggestions:
    """Test recovery suggestion generation and content."""
    
    def test_windows_platform_suggests_tcp(self):
        """Test that Windows platform errors suggest using TCP."""
        error = PlatformCompatibilityError(
            message="IPC not supported",
            platform_name="Windows",
            platform_type="windows",
            operation="ipc_bind",
        )
        
        # Check suggestions contain TCP advice
        formatted = str(error)
        assert "tcp" in formatted.lower() or "TCP" in formatted
    
    def test_ipc_error_suggests_tcp_via_factory(self):
        """Test that IPC errors from factory suggest TCP."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="Windows",
            platform_type="windows",
            endpoint="ipc:///tmp/test.sock",
        )
        
        # Should have alternative suggestion
        assert error.alternative_suggestion is not None
        assert "tcp" in error.alternative_suggestion.lower()
    
    def test_supported_platforms_listed(self):
        """Test that supported platforms are listed in IPC errors."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="Windows",
            platform_type="windows",
            endpoint="ipc:///tmp/test.sock",
        )
        
        assert len(error.supported_platforms) > 0
        assert "Linux" in error.supported_platforms


# =============================================================================
# Test Error Metadata
# =============================================================================

class TestErrorMetadata:
    """Test error metadata and context."""
    
    def test_error_category(self):
        """Test that error has correct category."""
        error = PlatformCompatibilityError(
            message="Test",
            platform_name="Test",
            platform_type="unknown",
            operation="test",
        )
        
        # Should be categorized as configuration error
        assert error.category == ErrorCategory.CONFIGURATION
    
    def test_error_context_dict(self):
        """Test error context dictionary."""
        error = PlatformCompatibilityError(
            message="Test error",
            platform_name="Linux",
            platform_type="unix_like",
            operation="test_operation",
            supported_platforms=["Linux", "macOS"],
        )
        
        assert isinstance(error.context, dict)
        assert "platform_name" in error.context
        assert "platform_type" in error.context
        assert "operation" in error.context
        assert error.context["platform_name"] == "Linux"
    
    def test_error_with_alternative_suggestion(self):
        """Test error with alternative suggestion in context."""
        error = PlatformCompatibilityError(
            message="IPC not supported",
            platform_name="Windows",
            platform_type="windows",
            operation="bind",
            alternative_suggestion="Use TCP instead",
        )
        
        assert error.alternative_suggestion == "Use TCP instead"
        assert "alternative" in error.context


# =============================================================================
# Test Platform Context Integration
# =============================================================================

class TestPlatformContextIntegration:
    """Test integration with platform detection context."""
    
    def test_all_platform_types_supported(self):
        """Test error creation for various platform types."""
        platform_types = [
            ("windows", "Windows"),
            ("unix_like", "Linux"),
            ("wsl", "WSL2"),
            ("cygwin", "Cygwin"),
            ("unknown", "Unknown"),
        ]
        
        for platform_type, name in platform_types:
            error = PlatformCompatibilityError(
                message=f"Error on {name}",
                platform_name=name,
                platform_type=platform_type,
                operation="test",
            )
            
            assert error.platform_type == platform_type
            assert error.platform_name == name


# =============================================================================
# Test Error Handling in Practice
# =============================================================================

class TestErrorHandlingPractice:
    """Test error handling patterns in practice."""
    
    def test_error_can_be_raised_and_caught(self):
        """Test that error can be raised and caught properly."""
        with pytest.raises(PlatformCompatibilityError) as exc_info:
            raise PlatformCompatibilityError(
                message="Test exception",
                platform_name="Test",
                platform_type="unknown",
                operation="test",
            )
        
        assert "Test exception" in str(exc_info.value)
    
    def test_error_can_be_caught_as_sidecar_error(self):
        """Test catching as parent SidecarError."""
        with pytest.raises(SidecarError):
            raise PlatformCompatibilityError(
                message="Test",
                platform_name="Test",
                platform_type="unknown",
                operation="test",
            )
    
    def test_error_message_actionable(self):
        """Test that error message provides actionable information."""
        error = PlatformCompatibilityError.ipc_not_supported(
            platform_name="Windows",
            platform_type="windows",
            endpoint="ipc:///tmp/test.sock",
        )
        
        error_str = str(error)
        
        # Should mention what went wrong
        assert len(error_str) > 20
        # Should have suggestions
        assert len(error.suggestions) > 0
    
    def test_original_error_preserved(self):
        """Test that original error is preserved."""
        original = OSError("Socket error")
        error = PlatformCompatibilityError(
            message="Wrapper error",
            platform_name="Linux",
            platform_type="unix_like",
            operation="socket_op",
            original_error=original,
        )
        
        assert error.original_error is original
        assert "Socket error" in str(original)