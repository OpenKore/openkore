"""
Utilities package for AI Sidecar.

Provides logging, error handling, startup feedback, and common utilities
used across the application.

IMPORTANT: This module does NOT re-export submodule contents to avoid
circular import dependencies. Import directly from submodules:

    from ai_sidecar.utils.logging import get_logger, setup_logging
    from ai_sidecar.utils.errors import SidecarError, ConfigurationError
    from ai_sidecar.utils.startup import StartupProgress

Modules:
- logging: Structured logging with context
- errors: User-friendly error handling with recovery suggestions
- startup: Startup progress indicators and feedback

The circular import chains that this avoids:
- Chain 1: utils/__init__.py -> logging.py -> config.py -> __init__.py
- Chain 2: utils/__init__.py -> startup.py -> ai_sidecar -> config.py
"""

# Expose submodule names for discovery, but don't import their contents
# Users should import directly: from ai_sidecar.utils.logging import get_logger
__all__ = [
    "logging",
    "errors",
    "startup",
]


def __getattr__(name: str):
    """
    Lazy attribute access for backwards compatibility.
    
    This allows code like `from ai_sidecar.utils import get_logger` to still work
    by lazily importing from the appropriate submodule when accessed.
    
    New code should import directly from submodules to avoid any import overhead.
    """
    # Logging exports
    if name in ("get_logger", "setup_logging", "bind_context", "clear_context", "unbind_context"):
        from ai_sidecar.utils import logging as _logging
        return getattr(_logging, name)
    
    # Error exports
    if name in (
        "SidecarError", "ConfigurationError", "MissingConfigError",
        "InvalidConfigValueError", "ZMQConnectionError", "RedisConnectionError",
        "InitializationError", "ModelLoadError", "DependencyError",
        "ResourceError", "ErrorCategory", "RecoverySuggestion",
        "format_validation_errors", "wrap_error", "format_loading_error",
    ):
        from ai_sidecar.utils import errors as _errors
        return getattr(_errors, name)
    
    # Handle SidecarMemoryError alias
    if name == "SidecarMemoryError":
        from ai_sidecar.utils import errors as _errors
        return _errors.MemoryError
    
    # Startup exports
    if name in (
        "StartupProgress", "StartupStep", "SpinnerProgress",
        "show_quick_status", "wait_with_progress",
    ):
        from ai_sidecar.utils import startup as _startup
        return getattr(_startup, name)
    
    raise AttributeError(f"module 'ai_sidecar.utils' has no attribute '{name}'")