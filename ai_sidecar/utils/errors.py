"""
User-friendly error handling for AI Sidecar.

Provides structured error classes with clear messages and recovery suggestions.
Designed to help users quickly understand and resolve issues.
"""

from enum import Enum
from typing import Any


class ErrorCategory(str, Enum):
    """Categories for error classification and filtering."""
    
    CONFIGURATION = "configuration"
    CONNECTION = "connection"
    INITIALIZATION = "initialization"
    RUNTIME = "runtime"
    RESOURCE = "resource"
    VALIDATION = "validation"
    DEPENDENCY = "dependency"


class RecoverySuggestion:
    """
    A recovery suggestion with steps and optional documentation link.
    
    Attributes:
        summary: Brief description of what to do
        steps: List of specific actions to take
        docs_link: Optional link to relevant documentation
    """
    
    def __init__(
        self,
        summary: str,
        steps: list[str] | None = None,
        docs_link: str | None = None,
    ) -> None:
        self.summary = summary
        self.steps = steps or []
        self.docs_link = docs_link
    
    def format(self, indent: str = "  ") -> str:
        """Format the suggestion for display."""
        lines = [f"💡 {self.summary}"]
        
        for i, step in enumerate(self.steps, 1):
            lines.append(f"{indent}{i}. {step}")
        
        if self.docs_link:
            lines.append(f"{indent}📖 See: {self.docs_link}")
        
        return "\n".join(lines)


class SidecarError(Exception):
    """
    Base exception for AI Sidecar errors.
    
    All custom exceptions inherit from this class to provide:
    - User-friendly error messages
    - Recovery suggestions
    - Error categorization
    - Context preservation
    
    Attributes:
        message: Human-readable error message
        category: Error category for classification
        suggestions: List of recovery suggestions
        context: Additional context about the error
        original_error: The original exception if wrapping another error
    """
    
    def __init__(
        self,
        message: str,
        category: ErrorCategory = ErrorCategory.RUNTIME,
        suggestions: list[RecoverySuggestion] | None = None,
        context: dict[str, Any] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.category = category
        self.suggestions = suggestions or []
        self.context = context or {}
        self.original_error = original_error
    
    def format_error(self, show_context: bool = True) -> str:
        """
        Format the error for user-friendly display.
        
        Args:
            show_context: Whether to include context details
            
        Returns:
            Formatted error message with suggestions
        """
        lines = [
            "",
            "═" * 60,
            f"❌ Error: {self.message}",
            f"   Category: {self.category.value}",
            "═" * 60,
        ]
        
        if show_context and self.context:
            lines.append("📋 Context:")
            for key, value in self.context.items():
                lines.append(f"   • {key}: {value}")
            lines.append("")
        
        if self.original_error:
            lines.append(f"🔍 Caused by: {type(self.original_error).__name__}: {self.original_error}")
            lines.append("")
        
        if self.suggestions:
            lines.append("🛠️ How to fix:")
            for suggestion in self.suggestions:
                lines.append(suggestion.format("   "))
                lines.append("")
        
        lines.append("═" * 60)
        return "\n".join(lines)
    
    def __str__(self) -> str:
        return self.format_error()


# =============================================================================
# Configuration Errors
# =============================================================================

class ConfigurationError(SidecarError):
    """Raised when configuration is invalid or missing."""
    
    def __init__(
        self,
        message: str,
        config_key: str | None = None,
        expected_type: str | None = None,
        actual_value: Any = None,
        suggestions: list[RecoverySuggestion] | None = None,
    ) -> None:
        context = {}
        if config_key:
            context["config_key"] = config_key
        if expected_type:
            context["expected_type"] = expected_type
        if actual_value is not None:
            context["actual_value"] = repr(actual_value)[:100]
        
        if not suggestions:
            suggestions = [
                RecoverySuggestion(
                    "Check your configuration file",
                    [
                        "Review config.yaml for syntax errors",
                        "Verify environment variables are set correctly",
                        "Compare with config.yaml.example for reference",
                    ],
                )
            ]
        
        super().__init__(
            message=message,
            category=ErrorCategory.CONFIGURATION,
            suggestions=suggestions,
            context=context,
        )


class MissingConfigError(ConfigurationError):
    """Raised when a required configuration value is missing."""
    
    def __init__(self, config_key: str, env_var: str | None = None) -> None:
        suggestions = [
            RecoverySuggestion(
                f"Provide a value for '{config_key}'",
                [
                    f"Set in config.yaml: {config_key}: <value>",
                    f"Or set environment variable: {env_var or config_key.upper().replace('.', '_')}",
                    "Or use the default by removing the override",
                ],
            )
        ]
        
        super().__init__(
            message=f"Missing required configuration: {config_key}",
            config_key=config_key,
            suggestions=suggestions,
        )


class InvalidConfigValueError(ConfigurationError):
    """Raised when a configuration value is invalid."""
    
    def __init__(
        self,
        config_key: str,
        value: Any,
        reason: str,
        valid_values: list[str] | None = None,
    ) -> None:
        steps = [f"Current value: {repr(value)}", f"Problem: {reason}"]
        
        if valid_values:
            steps.append(f"Valid values: {', '.join(valid_values)}")
        
        suggestions = [
            RecoverySuggestion(
                f"Correct the value for '{config_key}'",
                steps,
            )
        ]
        
        super().__init__(
            message=f"Invalid configuration value for '{config_key}': {reason}",
            config_key=config_key,
            actual_value=value,
            suggestions=suggestions,
        )


# =============================================================================
# Connection Errors
# =============================================================================

class ConnectionError(SidecarError):
    """Raised when a connection fails."""
    
    def __init__(
        self,
        message: str,
        endpoint: str | None = None,
        service: str | None = None,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        context = {}
        if endpoint:
            context["endpoint"] = endpoint
        if service:
            context["service"] = service
        
        super().__init__(
            message=message,
            category=ErrorCategory.CONNECTION,
            suggestions=suggestions,
            context=context,
            original_error=original_error,
        )


class ZMQConnectionError(ConnectionError):
    """Raised when ZeroMQ connection fails."""
    
    def __init__(
        self,
        message: str,
        endpoint: str,
        original_error: Exception | None = None,
    ) -> None:
        suggestions = [
            RecoverySuggestion(
                "Check ZeroMQ endpoint configuration",
                [
                    f"Verify endpoint is correct: {endpoint}",
                    "For IPC: Ensure the directory exists and is writable",
                    "For TCP: Check if port is not in use by another process",
                    "Ensure OpenKore plugin is running and connected",
                ],
            ),
            RecoverySuggestion(
                "Common ZMQ issues",
                [
                    "IPC socket files may persist after crash - delete /tmp/openkore-ai.sock",
                    "Port conflicts - use 'netstat -an | grep 5555' to check",
                    "Firewall rules may block the connection",
                ],
            ),
        ]
        
        super().__init__(
            message=message,
            endpoint=endpoint,
            service="ZeroMQ",
            suggestions=suggestions,
            original_error=original_error,
        )


class PlatformCompatibilityError(SidecarError):
    """
    Platform compatibility error with platform-specific recovery suggestions.
    
    Raised when an operation is attempted that is not supported on the
    current platform, such as:
    - IPC sockets on Windows
    - Unix-specific features on non-Unix systems
    - Socket cleanup failures due to platform limitations
    
    Attributes:
        platform_name: Name of the current platform
        platform_type: Type of platform (windows, unix, wsl, etc.)
        operation: The operation that failed
        supported_platforms: List of platforms that support this operation
        alternative_suggestion: Platform-specific alternative
        original_error: The underlying exception
    """
    
    def __init__(
        self,
        message: str,
        platform_name: str,
        platform_type: str,
        operation: str,
        supported_platforms: list[str] | None = None,
        alternative_suggestion: str | None = None,
        original_error: Exception | None = None,
    ) -> None:
        # Build recovery steps based on platform context
        recovery_steps = [
            f"Current platform: {platform_name} ({platform_type})",
            f"Operation attempted: {operation}",
        ]
        
        if supported_platforms:
            recovery_steps.append(
                f"Supported platforms: {', '.join(supported_platforms)}"
            )
        
        if alternative_suggestion:
            recovery_steps.append(f"Alternative: {alternative_suggestion}")
        
        # Platform-specific suggestions
        if platform_type.lower() == "windows":
            recovery_steps.extend([
                "Windows does not support Unix IPC sockets",
                "Use TCP endpoint instead: tcp://127.0.0.1:5555",
                "Set AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555 in environment",
            ])
        elif platform_type.lower() == "wsl":
            recovery_steps.extend([
                "WSL has limited IPC support depending on version",
                "WSL1: Use TCP endpoint for reliability",
                "WSL2: IPC should work, check socket path permissions",
            ])
        
        suggestions = [
            RecoverySuggestion(
                f"Platform compatibility issue on {platform_name}",
                recovery_steps,
                docs_link="https://github.com/openkore/openkore-ai/docs/cross-platform.md",
            ),
        ]
        
        # Build context dictionary
        context = {
            "platform_name": platform_name,
            "platform_type": platform_type,
            "operation": operation,
        }
        
        if supported_platforms:
            context["supported_platforms"] = supported_platforms
        
        if alternative_suggestion:
            context["alternative"] = alternative_suggestion
        
        # Call SidecarError directly with CONFIGURATION category
        super().__init__(
            message=message,
            category=ErrorCategory.CONFIGURATION,
            suggestions=suggestions,
            context=context,
            original_error=original_error,
        )
        
        # Store as instance attributes for easy access
        self.platform_name = platform_name
        self.platform_type = platform_type
        self.operation = operation
        self.supported_platforms = supported_platforms or []
        self.alternative_suggestion = alternative_suggestion
    
    @classmethod
    def ipc_not_supported(
        cls,
        platform_name: str,
        platform_type: str,
        endpoint: str,
        tcp_alternative: str = "tcp://127.0.0.1:5555",
    ) -> "PlatformCompatibilityError":
        """
        Factory method for IPC not supported errors.
        
        Args:
            platform_name: Current platform name
            platform_type: Platform type identifier
            endpoint: The IPC endpoint that was attempted
            tcp_alternative: Suggested TCP endpoint to use instead
            
        Returns:
            PlatformCompatibilityError configured for IPC issues
        """
        return cls(
            message=f"IPC endpoint '{endpoint}' is not supported on {platform_name}",
            platform_name=platform_name,
            platform_type=platform_type,
            operation=f"bind to IPC endpoint: {endpoint}",
            supported_platforms=["Linux", "macOS", "FreeBSD", "WSL2"],
            alternative_suggestion=f"Use TCP endpoint: {tcp_alternative}",
        )
    
    @classmethod
    def socket_cleanup_failed(
        cls,
        platform_name: str,
        platform_type: str,
        socket_path: str,
        reason: str,
        original_error: Exception | None = None,
    ) -> "PlatformCompatibilityError":
        """
        Factory method for socket cleanup failures.
        
        Args:
            platform_name: Current platform name
            platform_type: Platform type identifier
            socket_path: Path to the socket that failed cleanup
            reason: Reason for the cleanup failure
            original_error: The underlying exception
            
        Returns:
            PlatformCompatibilityError configured for cleanup failures
        """
        return cls(
            message=f"Failed to clean up socket '{socket_path}': {reason}",
            platform_name=platform_name,
            platform_type=platform_type,
            operation=f"cleanup stale socket: {socket_path}",
            alternative_suggestion="Manually remove the socket file or use TCP endpoint",
            original_error=original_error,
        )


class RedisConnectionError(ConnectionError):
    """Raised when Redis/DragonflyDB connection fails."""
    
    def __init__(
        self,
        host: str = "localhost",
        port: int = 6379,
        original_error: Exception | None = None,
    ) -> None:
        suggestions = [
            RecoverySuggestion(
                "Start Redis or DragonflyDB",
                [
                    "Docker: docker run -d --name dragonfly -p 6379:6379 docker.dragonflydb.io/dragonflydb/dragonfly",
                    "Redis: redis-server",
                    "Verify connection: redis-cli ping",
                ],
            ),
            RecoverySuggestion(
                "Check connection settings",
                [
                    f"Host: {host}, Port: {port}",
                    "Set AI_REDIS_HOST and AI_REDIS_PORT environment variables",
                    "Or update session storage config in config.yaml",
                ],
            ),
        ]
        
        super().__init__(
            message=f"Cannot connect to Redis at {host}:{port}",
            endpoint=f"{host}:{port}",
            service="Redis/DragonflyDB",
            suggestions=suggestions,
            original_error=original_error,
        )


# =============================================================================
# Initialization Errors
# =============================================================================

class InitializationError(SidecarError):
    """Raised when component initialization fails."""
    
    def __init__(
        self,
        message: str,
        component: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.INITIALIZATION,
            suggestions=suggestions,
            context={"component": component},
            original_error=original_error,
        )


class ModelLoadError(InitializationError):
    """Raised when ML model loading fails."""
    
    def __init__(
        self,
        model_name: str,
        model_path: str | None = None,
        original_error: Exception | None = None,
    ) -> None:
        suggestions = [
            RecoverySuggestion(
                "Check model availability",
                [
                    f"Model: {model_name}",
                    f"Path: {model_path or 'default'}",
                    "Verify model files exist and are not corrupted",
                    "Re-download models: python -m ai_sidecar.ml.download_models",
                ],
            ),
            RecoverySuggestion(
                "Use fallback mode",
                [
                    "Set AI_DECISION_FALLBACK_MODE=cpu to use rule-based AI",
                    "ML models are optional - the system works without them",
                ],
            ),
        ]
        
        super().__init__(
            message=f"Failed to load ML model: {model_name}",
            component="ML Model Loader",
            suggestions=suggestions,
            original_error=original_error,
        )


class DependencyError(SidecarError):
    """Raised when a required dependency is missing or incompatible."""
    
    def __init__(
        self,
        package: str,
        required_version: str | None = None,
        installed_version: str | None = None,
    ) -> None:
        msg = f"Missing or incompatible dependency: {package}"
        
        steps = []
        if installed_version:
            steps.append(f"Installed: {installed_version}")
        if required_version:
            steps.append(f"Required: {required_version}")
        steps.append(f"Install: pip install '{package}{'>=' + required_version if required_version else ''}'")
        
        suggestions = [
            RecoverySuggestion(
                "Install the required dependency",
                steps,
            ),
            RecoverySuggestion(
                "Reinstall all dependencies",
                [
                    "pip install -r requirements.txt",
                    "Or: pip install -e '.[dev]' for development",
                ],
            ),
        ]
        
        super().__init__(
            message=msg,
            category=ErrorCategory.DEPENDENCY,
            suggestions=suggestions,
            context={
                "package": package,
                "required": required_version,
                "installed": installed_version,
            },
        )


# =============================================================================
# Resource Errors
# =============================================================================

class ResourceError(SidecarError):
    """Raised when a resource is unavailable or exhausted."""
    
    def __init__(
        self,
        message: str,
        resource_type: str,
        suggestions: list[RecoverySuggestion] | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.RESOURCE,
            suggestions=suggestions,
            context={"resource_type": resource_type},
        )


class MemoryError(ResourceError):
    """Raised when memory limits are exceeded."""
    
    def __init__(self, current_mb: float, limit_mb: float) -> None:
        suggestions = [
            RecoverySuggestion(
                "Reduce memory usage",
                [
                    "Reduce state_history_size in config",
                    "Disable ML features (use CPU fallback)",
                    "Clear cached data periodically",
                ],
            ),
            RecoverySuggestion(
                "Increase memory limit",
                [
                    f"Current limit: {limit_mb}MB",
                    "Set AI_PERFORMANCE_MAX_MEMORY_MB to higher value",
                    "Or set to 0 for unlimited (not recommended)",
                ],
            ),
        ]
        
        super().__init__(
            message=f"Memory limit exceeded: {current_mb:.1f}MB / {limit_mb}MB",
            resource_type="memory",
            suggestions=suggestions,
        )


# =============================================================================
# Utility Functions
# =============================================================================

def format_validation_errors(errors: list[dict[str, Any]]) -> str:
    """
    Format Pydantic validation errors into user-friendly message.
    
    Args:
        errors: List of error dicts from Pydantic ValidationError
        
    Returns:
        Formatted error message with suggestions
    """
    lines = [
        "",
        "⚠️ Configuration Validation Failed",
        "─" * 40,
    ]
    
    for error in errors:
        loc = ".".join(str(x) for x in error.get("loc", []))
        msg = error.get("msg", "Unknown error")
        input_val = error.get("input")
        
        lines.append(f"  ✗ {loc}: {msg}")
        if input_val is not None:
            lines.append(f"    Value: {repr(input_val)[:60]}")
    
    lines.extend([
        "",
        "💡 Check config.yaml or environment variables",
        "   Run: python -c 'from ai_sidecar.config import get_settings; print(get_settings())'",
        "─" * 40,
    ])
    
    return "\n".join(lines)


def wrap_error(
    error: Exception,
    context: str,
    category: ErrorCategory = ErrorCategory.RUNTIME,
) -> SidecarError:
    """
    Wrap a generic exception into a SidecarError with context.
    
    Args:
        error: The original exception
        context: Description of what was happening when error occurred
        category: Error category
        
    Returns:
        A SidecarError wrapping the original exception
    """
    return SidecarError(
        message=f"{context}: {type(error).__name__}: {error}",
        category=category,
        original_error=error,
        suggestions=[
            RecoverySuggestion(
                "Check the error details above",
                [
                    "This is an unexpected error",
                    "Check logs for more details",
                    "Report if this persists: https://github.com/openkore/openkore-ai/issues",
                ],
            )
        ],
    )


def format_loading_error(
    component: str,
    error: Exception,
    suggestions: list[str] | None = None,
) -> str:
    """
    Format a loading/initialization error for display.
    
    Args:
        component: Name of the component that failed to load
        error: The exception that occurred
        suggestions: Optional list of suggestions to fix the issue
        
    Returns:
        Formatted error message
    """
    lines = [
        "",
        "╔" + "═" * 58 + "╗",
        f"║ ⚠️  Failed to load: {component:<37} ║",
        "╠" + "═" * 58 + "╣",
        f"║ Error: {str(error)[:49]:<49} ║",
    ]
    
    # Handle long error messages
    error_str = str(error)
    if len(error_str) > 49:
        remaining = error_str[49:]
        while remaining:
            chunk = remaining[:56]
            remaining = remaining[56:]
            lines.append(f"║   {chunk:<55} ║")
    
    if suggestions:
        lines.append("╠" + "─" * 58 + "╣")
        lines.append("║ 💡 Suggestions:                                          ║")
        for suggestion in suggestions[:5]:  # Limit to 5 suggestions
            # Truncate long suggestions
            if len(suggestion) > 53:
                suggestion = suggestion[:50] + "..."
            lines.append(f"║   • {suggestion:<53} ║")
    
    lines.append("╚" + "═" * 58 + "╝")
    
    return "\n".join(lines)


class DataError(SidecarError):
    """Data processing error."""
    
    def __init__(
        self,
        message: str,
        data_type: str | None = None,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        context = {}
        if data_type:
            context["data_type"] = data_type
        
        super().__init__(
            message=message,
            category=ErrorCategory.VALIDATION,
            suggestions=suggestions,
            context=context,
            original_error=original_error,
        )


class NetworkError(SidecarError):
    """Network communication error."""
    
    def __init__(
        self,
        message: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.CONNECTION,
            suggestions=suggestions,
            original_error=original_error,
        )


class StateError(SidecarError):
    """Invalid state error."""
    
    def __init__(
        self,
        message: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.RUNTIME,
            suggestions=suggestions,
            original_error=original_error,
        )


class ValidationError(SidecarError):
    """Data validation error."""
    
    def __init__(
        self,
        message: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.VALIDATION,
            suggestions=suggestions,
            original_error=original_error,
        )


class CombatError(SidecarError):
    """Combat-related error."""
    
    def __init__(
        self,
        message: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.RUNTIME,
            suggestions=suggestions,
            original_error=original_error,
        )


class DecisionError(SidecarError):
    """Decision making error."""
    
    def __init__(
        self,
        message: str,
        suggestions: list[RecoverySuggestion] | None = None,
        original_error: Exception | None = None,
    ) -> None:
        super().__init__(
            message=message,
            category=ErrorCategory.RUNTIME,
            suggestions=suggestions,
            original_error=original_error,
        )


# Aliases for backward compatibility
SidecarMemoryError = MemoryError
AIError = SidecarError