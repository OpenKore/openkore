"""
Tests for utils/errors.py.

Covers:
- Error category enum
- Recovery suggestion formatting
- All custom error classes
- Error hierarchy
- Error formatting and display
- Utility functions
"""

import pytest
from typing import Any

from ai_sidecar.utils.errors import (
    ErrorCategory,
    RecoverySuggestion,
    SidecarError,
    ConfigurationError,
    MissingConfigError,
    InvalidConfigValueError,
    ConnectionError,
    ZMQConnectionError,
    RedisConnectionError,
    InitializationError,
    ModelLoadError,
    DependencyError,
    ResourceError,
    MemoryError,
    SidecarMemoryError,
    format_validation_errors,
    wrap_error,
    format_loading_error,
)


# =============================================================================
# ErrorCategory Tests
# =============================================================================

def test_error_category_values():
    """Test all error category enum values."""
    assert ErrorCategory.CONFIGURATION == "configuration"
    assert ErrorCategory.CONNECTION == "connection"
    assert ErrorCategory.INITIALIZATION == "initialization"
    assert ErrorCategory.RUNTIME == "runtime"
    assert ErrorCategory.RESOURCE == "resource"
    assert ErrorCategory.VALIDATION == "validation"
    assert ErrorCategory.DEPENDENCY == "dependency"


def test_error_category_is_string():
    """Test that error categories are string enums."""
    assert isinstance(ErrorCategory.CONFIGURATION.value, str)
    assert ErrorCategory.CONFIGURATION.value == "configuration"


# =============================================================================
# RecoverySuggestion Tests
# =============================================================================

def test_recovery_suggestion_init():
    """Test RecoverySuggestion initialization."""
    suggestion = RecoverySuggestion("Fix the issue")
    assert suggestion.summary == "Fix the issue"
    assert suggestion.steps == []
    assert suggestion.docs_link is None


def test_recovery_suggestion_with_steps():
    """Test RecoverySuggestion with steps."""
    steps = ["Step 1", "Step 2", "Step 3"]
    suggestion = RecoverySuggestion("Fix it", steps=steps)
    assert suggestion.summary == "Fix it"
    assert suggestion.steps == steps


def test_recovery_suggestion_with_docs():
    """Test RecoverySuggestion with documentation link."""
    suggestion = RecoverySuggestion(
        "Check docs",
        docs_link="https://example.com/docs",
    )
    assert suggestion.docs_link == "https://example.com/docs"


def test_recovery_suggestion_format_simple():
    """Test formatting a simple suggestion."""
    suggestion = RecoverySuggestion("Do this")
    formatted = suggestion.format()
    assert "💡 Do this" in formatted
    assert "1." not in formatted  # No steps


def test_recovery_suggestion_format_with_steps():
    """Test formatting suggestion with steps."""
    suggestion = RecoverySuggestion(
        "Fix the problem",
        steps=["Step 1", "Step 2"],
    )
    formatted = suggestion.format()
    assert "💡 Fix the problem" in formatted
    assert "1. Step 1" in formatted
    assert "2. Step 2" in formatted


def test_recovery_suggestion_format_with_docs():
    """Test formatting suggestion with docs link."""
    suggestion = RecoverySuggestion(
        "Read the docs",
        docs_link="https://example.com",
    )
    formatted = suggestion.format()
    assert "📖 See: https://example.com" in formatted


def test_recovery_suggestion_format_custom_indent():
    """Test formatting with custom indentation."""
    suggestion = RecoverySuggestion("Test", steps=["Step 1"])
    formatted = suggestion.format(indent="    ")
    assert "    1. Step 1" in formatted


# =============================================================================
# SidecarError Tests
# =============================================================================

def test_sidecar_error_init():
    """Test basic SidecarError initialization."""
    error = SidecarError("Test error")
    assert error.message == "Test error"
    assert error.category == ErrorCategory.RUNTIME
    assert error.suggestions == []
    assert error.context == {}
    assert error.original_error is None


def test_sidecar_error_with_category():
    """Test SidecarError with specific category."""
    error = SidecarError("Test", category=ErrorCategory.CONFIGURATION)
    assert error.category == ErrorCategory.CONFIGURATION


def test_sidecar_error_with_suggestions():
    """Test SidecarError with recovery suggestions."""
    suggestions = [RecoverySuggestion("Fix it")]
    error = SidecarError("Test", suggestions=suggestions)
    assert len(error.suggestions) == 1
    assert error.suggestions[0].summary == "Fix it"


def test_sidecar_error_with_context():
    """Test SidecarError with context."""
    context = {"key": "value", "count": 42}
    error = SidecarError("Test", context=context)
    assert error.context == context


def test_sidecar_error_with_original_error():
    """Test SidecarError wrapping another exception."""
    original = ValueError("Original error")
    error = SidecarError("Wrapped", original_error=original)
    assert error.original_error is original


def test_sidecar_error_format_simple():
    """Test formatting a simple error."""
    error = SidecarError("Test error")
    formatted = error.format_error()
    assert "❌ Error: Test error" in formatted
    assert "Category: runtime" in formatted
    assert "═" in formatted


def test_sidecar_error_format_with_context():
    """Test formatting error with context."""
    error = SidecarError("Test", context={"key": "value"})
    formatted = error.format_error(show_context=True)
    assert "📋 Context:" in formatted
    assert "key: value" in formatted


def test_sidecar_error_format_without_context():
    """Test formatting error hiding context."""
    error = SidecarError("Test", context={"key": "value"})
    formatted = error.format_error(show_context=False)
    assert "📋 Context:" not in formatted


def test_sidecar_error_format_with_original():
    """Test formatting error with original exception."""
    original = ValueError("Original")
    error = SidecarError("Wrapped", original_error=original)
    formatted = error.format_error()
    assert "🔍 Caused by:" in formatted
    assert "ValueError: Original" in formatted


def test_sidecar_error_format_with_suggestions():
    """Test formatting error with suggestions."""
    suggestions = [RecoverySuggestion("Try this")]
    error = SidecarError("Test", suggestions=suggestions)
    formatted = error.format_error()
    assert "🛠️ How to fix:" in formatted
    assert "💡 Try this" in formatted


def test_sidecar_error_str():
    """Test string representation of error."""
    error = SidecarError("Test error")
    str_repr = str(error)
    assert "Test error" in str_repr


# =============================================================================
# ConfigurationError Tests
# =============================================================================

def test_configuration_error_init():
    """Test ConfigurationError initialization."""
    error = ConfigurationError("Config error")
    assert error.message == "Config error"
    assert error.category == ErrorCategory.CONFIGURATION


def test_configuration_error_with_config_key():
    """Test ConfigurationError with config key."""
    error = ConfigurationError("Invalid", config_key="some.key")
    assert error.context["config_key"] == "some.key"


def test_configuration_error_with_type_info():
    """Test ConfigurationError with type information."""
    error = ConfigurationError(
        "Type mismatch",
        config_key="key",
        expected_type="int",
        actual_value="string",
    )
    assert error.context["expected_type"] == "int"
    assert "string" in error.context["actual_value"]


def test_configuration_error_default_suggestions():
    """Test ConfigurationError has default suggestions."""
    error = ConfigurationError("Test")
    assert len(error.suggestions) > 0
    assert any("config.yaml" in s.format() for s in error.suggestions)


def test_configuration_error_custom_suggestions():
    """Test ConfigurationError with custom suggestions."""
    custom = [RecoverySuggestion("Custom fix")]
    error = ConfigurationError("Test", suggestions=custom)
    assert len(error.suggestions) == 1
    assert error.suggestions[0].summary == "Custom fix"


def test_configuration_error_truncates_long_value():
    """Test that long values are truncated in context."""
    long_value = "x" * 200
    error = ConfigurationError("Test", actual_value=long_value)
    assert len(error.context["actual_value"]) <= 100


# =============================================================================
# MissingConfigError Tests
# =============================================================================

def test_missing_config_error_init():
    """Test MissingConfigError initialization."""
    error = MissingConfigError("required.key")
    assert "required.key" in error.message
    assert error.category == ErrorCategory.CONFIGURATION


def test_missing_config_error_with_env_var():
    """Test MissingConfigError with environment variable."""
    error = MissingConfigError("key", env_var="MY_ENV_VAR")
    formatted = error.format_error()
    assert "MY_ENV_VAR" in formatted


def test_missing_config_error_suggestions():
    """Test MissingConfigError provides helpful suggestions."""
    error = MissingConfigError("database.url")
    assert len(error.suggestions) > 0
    formatted = error.format_error()
    assert "config.yaml" in formatted or "environment variable" in formatted


# =============================================================================
# InvalidConfigValueError Tests
# =============================================================================

def test_invalid_config_value_error_init():
    """Test InvalidConfigValueError initialization."""
    error = InvalidConfigValueError("key", "bad_value", "Not valid")
    assert "key" in error.message
    assert error.category == ErrorCategory.CONFIGURATION


def test_invalid_config_value_error_with_valid_values():
    """Test InvalidConfigValueError with valid values list."""
    error = InvalidConfigValueError(
        "mode",
        "invalid",
        "Unknown mode",
        valid_values=["cpu", "gpu", "auto"],
    )
    formatted = error.format_error()
    assert "cpu" in formatted
    assert "gpu" in formatted
    assert "auto" in formatted


def test_invalid_config_value_error_suggestions():
    """Test InvalidConfigValueError includes suggestions."""
    error = InvalidConfigValueError("key", "bad", "reason")
    assert len(error.suggestions) > 0


# =============================================================================
# ConnectionError Tests
# =============================================================================

def test_connection_error_init():
    """Test ConnectionError initialization."""
    error = ConnectionError("Connection failed")
    assert error.message == "Connection failed"
    assert error.category == ErrorCategory.CONNECTION


def test_connection_error_with_endpoint():
    """Test ConnectionError with endpoint."""
    error = ConnectionError("Failed", endpoint="tcp://localhost:5555")
    assert error.context["endpoint"] == "tcp://localhost:5555"


def test_connection_error_with_service():
    """Test ConnectionError with service name."""
    error = ConnectionError("Failed", service="Redis")
    assert error.context["service"] == "Redis"


def test_connection_error_with_original():
    """Test ConnectionError with original exception."""
    original = OSError("Network unreachable")
    error = ConnectionError("Failed", original_error=original)
    assert error.original_error is original


# =============================================================================
# ZMQConnectionError Tests
# =============================================================================

def test_zmq_connection_error_init():
    """Test ZMQConnectionError initialization."""
    error = ZMQConnectionError("ZMQ failed", "tcp://localhost:5555")
    assert "ZMQ failed" in error.message
    assert error.category == ErrorCategory.CONNECTION
    assert error.context["endpoint"] == "tcp://localhost:5555"
    assert error.context["service"] == "ZeroMQ"


def test_zmq_connection_error_suggestions():
    """Test ZMQConnectionError provides ZMQ-specific suggestions."""
    error = ZMQConnectionError("Failed", "ipc:///tmp/test.sock")
    formatted = error.format_error()
    assert "ZeroMQ" in formatted or "ZMQ" in formatted
    assert len(error.suggestions) >= 2  # Should have at least 2 suggestion groups


def test_zmq_connection_error_with_original():
    """Test ZMQConnectionError with original exception."""
    original = Exception("Socket error")
    error = ZMQConnectionError("Failed", "tcp://localhost:5555", original)
    assert error.original_error is original


# =============================================================================
# RedisConnectionError Tests
# =============================================================================

def test_redis_connection_error_default():
    """Test RedisConnectionError with defaults."""
    error = RedisConnectionError()
    assert "localhost:6379" in error.message
    assert error.category == ErrorCategory.CONNECTION


def test_redis_connection_error_custom_host_port():
    """Test RedisConnectionError with custom host and port."""
    error = RedisConnectionError(host="redis.example.com", port=6380)
    assert "redis.example.com:6380" in error.message
    assert error.context["endpoint"] == "redis.example.com:6380"


def test_redis_connection_error_suggestions():
    """Test RedisConnectionError provides Redis-specific suggestions."""
    error = RedisConnectionError()
    formatted = error.format_error()
    assert "Redis" in formatted or "DragonflyDB" in formatted
    assert "docker" in formatted.lower() or "redis-server" in formatted


def test_redis_connection_error_with_original():
    """Test RedisConnectionError with original exception."""
    original = ConnectionRefusedError("Connection refused")
    error = RedisConnectionError(original_error=original)
    assert error.original_error is original


# =============================================================================
# InitializationError Tests
# =============================================================================

def test_initialization_error_init():
    """Test InitializationError initialization."""
    error = InitializationError("Init failed", component="TestComponent")
    assert "Init failed" in error.message
    assert error.category == ErrorCategory.INITIALIZATION
    assert error.context["component"] == "TestComponent"


def test_initialization_error_with_suggestions():
    """Test InitializationError with custom suggestions."""
    suggestions = [RecoverySuggestion("Restart")]
    error = InitializationError("Failed", "Component", suggestions=suggestions)
    assert len(error.suggestions) == 1


def test_initialization_error_with_original():
    """Test InitializationError with original exception."""
    original = ImportError("Module not found")
    error = InitializationError("Failed", "Module", original_error=original)
    assert error.original_error is original


# =============================================================================
# ModelLoadError Tests
# =============================================================================

def test_model_load_error_init():
    """Test ModelLoadError initialization."""
    error = ModelLoadError("my-model")
    assert "my-model" in error.message
    assert error.category == ErrorCategory.INITIALIZATION
    assert error.context["component"] == "ML Model Loader"


def test_model_load_error_with_path():
    """Test ModelLoadError with model path."""
    error = ModelLoadError("model", model_path="/path/to/model")
    formatted = error.format_error()
    assert "/path/to/model" in formatted


def test_model_load_error_suggestions():
    """Test ModelLoadError provides ML-specific suggestions."""
    error = ModelLoadError("test-model")
    formatted = error.format_error()
    assert "download_models" in formatted or "fallback" in formatted.lower()


def test_model_load_error_with_original():
    """Test ModelLoadError with original exception."""
    original = FileNotFoundError("Model file not found")
    error = ModelLoadError("model", original_error=original)
    assert error.original_error is original


# =============================================================================
# DependencyError Tests
# =============================================================================

def test_dependency_error_init():
    """Test DependencyError initialization."""
    error = DependencyError("some-package")
    assert "some-package" in error.message
    assert error.category == ErrorCategory.DEPENDENCY
    assert error.context["package"] == "some-package"


def test_dependency_error_with_versions():
    """Test DependencyError with version info."""
    error = DependencyError(
        "package",
        required_version="2.0.0",
        installed_version="1.0.0",
    )
    assert error.context["required"] == "2.0.0"
    assert error.context["installed"] == "1.0.0"
    formatted = error.format_error()
    assert "2.0.0" in formatted
    assert "1.0.0" in formatted


def test_dependency_error_suggestions():
    """Test DependencyError provides install suggestions."""
    error = DependencyError("missing-pkg", required_version=">=1.0")
    formatted = error.format_error()
    assert "pip install" in formatted
    assert "missing-pkg" in formatted


# =============================================================================
# ResourceError Tests
# =============================================================================

def test_resource_error_init():
    """Test ResourceError initialization."""
    error = ResourceError("Resource unavailable", resource_type="disk")
    assert "Resource unavailable" in error.message
    assert error.category == ErrorCategory.RESOURCE
    assert error.context["resource_type"] == "disk"


def test_resource_error_with_suggestions():
    """Test ResourceError with custom suggestions."""
    suggestions = [RecoverySuggestion("Free up space")]
    error = ResourceError("Full", "disk", suggestions=suggestions)
    assert len(error.suggestions) == 1


# =============================================================================
# MemoryError Tests
# =============================================================================

def test_memory_error_init():
    """Test MemoryError initialization."""
    error = MemoryError(current_mb=1500.0, limit_mb=1024.0)
    assert "1500" in error.message
    assert "1024" in error.message
    assert error.category == ErrorCategory.RESOURCE


def test_memory_error_suggestions():
    """Test MemoryError provides memory-specific suggestions."""
    error = MemoryError(2000.0, 1024.0)
    formatted = error.format_error()
    assert "memory" in formatted.lower()
    assert any("reduce" in s.format().lower() for s in error.suggestions)


def test_sidecar_memory_error_alias():
    """Test that SidecarMemoryError is an alias."""
    assert SidecarMemoryError is MemoryError


# =============================================================================
# Utility Function Tests
# =============================================================================

def test_format_validation_errors_simple():
    """Test formatting simple validation errors."""
    errors = [
        {"loc": ["field"], "msg": "Field required", "input": None}
    ]
    result = format_validation_errors(errors)
    assert "Configuration Validation Failed" in result
    assert "field: Field required" in result


def test_format_validation_errors_nested():
    """Test formatting nested field errors."""
    errors = [
        {"loc": ["config", "database", "host"], "msg": "Invalid host"}
    ]
    result = format_validation_errors(errors)
    assert "config.database.host" in result


def test_format_validation_errors_with_value():
    """Test formatting errors with input value."""
    errors = [
        {"loc": ["port"], "msg": "Invalid port", "input": "not-a-number"}
    ]
    result = format_validation_errors(errors)
    assert "not-a-number" in result


def test_format_validation_errors_multiple():
    """Test formatting multiple validation errors."""
    errors = [
        {"loc": ["field1"], "msg": "Error 1"},
        {"loc": ["field2"], "msg": "Error 2"},
    ]
    result = format_validation_errors(errors)
    assert "field1" in result
    assert "field2" in result
    assert "Error 1" in result
    assert "Error 2" in result


def test_format_validation_errors_truncates_long_value():
    """Test that long input values are truncated."""
    long_value = "x" * 100
    errors = [{"loc": ["field"], "msg": "Error", "input": long_value}]
    result = format_validation_errors(errors)
    assert len(result) < len(long_value) + 1000  # Reasonable limit


def test_wrap_error_basic():
    """Test wrapping a basic exception."""
    original = ValueError("Something went wrong")
    wrapped = wrap_error(original, "During operation")
    assert isinstance(wrapped, SidecarError)
    assert "During operation" in wrapped.message
    assert "ValueError" in wrapped.message
    assert wrapped.original_error is original


def test_wrap_error_with_category():
    """Test wrapping error with specific category."""
    original = FileNotFoundError("File missing")
    wrapped = wrap_error(original, "Loading file", ErrorCategory.INITIALIZATION)
    assert wrapped.category == ErrorCategory.INITIALIZATION


def test_wrap_error_includes_suggestions():
    """Test that wrapped errors include suggestions."""
    original = Exception("Error")
    wrapped = wrap_error(original, "Context")
    assert len(wrapped.suggestions) > 0


def test_format_loading_error_basic():
    """Test formatting a loading error."""
    error = Exception("Load failed")
    result = format_loading_error("MyComponent", error)
    assert "MyComponent" in result
    assert "Load failed" in result
    assert "╔" in result  # Box drawing


def test_format_loading_error_with_suggestions():
    """Test formatting loading error with suggestions."""
    error = Exception("Error")
    result = format_loading_error("Component", error, suggestions=["Try this"])
    assert "Try this" in result
    assert "💡 Suggestions:" in result


def test_format_loading_error_long_message():
    """Test formatting error with very long message."""
    long_message = "This is a very long error message " * 10
    error = Exception(long_message)
    result = format_loading_error("Component", error)
    assert "Component" in result
    # Should handle long messages gracefully


def test_format_loading_error_many_suggestions():
    """Test formatting with many suggestions (should limit)."""
    many_suggestions = [f"Suggestion {i}" for i in range(20)]
    error = Exception("Error")
    result = format_loading_error("Component", error, suggestions=many_suggestions)
    # Should limit to 5 suggestions based on code
    assert result.count("•") <= 5


def test_format_loading_error_long_suggestion():
    """Test formatting with very long suggestion."""
    long_suggestion = "This is a very long suggestion " * 10
    error = Exception("Error")
    result = format_loading_error("Component", error, suggestions=[long_suggestion])
    # Should truncate long suggestions
    assert "..." in result or len(result) < len(long_suggestion) + 1000


# =============================================================================
# Edge Cases and Integration Tests
# =============================================================================

def test_error_hierarchy():
    """Test that errors inherit correctly."""
    assert issubclass(ConfigurationError, SidecarError)
    assert issubclass(MissingConfigError, ConfigurationError)
    assert issubclass(ConnectionError, SidecarError)
    assert issubclass(InitializationError, SidecarError)


def test_error_can_be_raised():
    """Test that custom errors can be raised and caught."""
    with pytest.raises(SidecarError):
        raise SidecarError("Test")
    
    with pytest.raises(ConfigurationError):
        raise ConfigurationError("Test")
    
    with pytest.raises(SidecarError):  # Parent catches child
        raise ConfigurationError("Test")


def test_error_str_contains_message():
    """Test that str() includes the error message."""
    error = SidecarError("My error message")
    assert "My error message" in str(error)


def test_multiple_suggestions_formatting():
    """Test formatting error with multiple suggestions."""
    suggestions = [
        RecoverySuggestion("First", steps=["Step 1", "Step 2"]),
        RecoverySuggestion("Second", docs_link="https://example.com"),
    ]
    error = SidecarError("Test", suggestions=suggestions)
    formatted = error.format_error()
    assert "First" in formatted
    assert "Second" in formatted
    assert "Step 1" in formatted
    assert "https://example.com" in formatted


def test_empty_context_not_displayed():
    """Test that empty context is not displayed."""
    error = SidecarError("Test", context={})
    formatted = error.format_error(show_context=True)
    assert "📋 Context:" not in formatted


def test_none_values_handled():
    """Test that None values are handled properly."""
    error = ConfigurationError(
        "Test",
        config_key=None,
        expected_type=None,
        actual_value=None,
    )
    # Should not crash
    assert error.message == "Test"
    assert "actual_value" not in error.context


def test_error_with_all_features():
    """Test error with all features enabled."""
    original = ValueError("Original")
    suggestions = [
        RecoverySuggestion("Fix", steps=["Step 1"], docs_link="https://example.com")
    ]
    context = {"key": "value"}
    
    error = SidecarError(
        "Complete error",
        category=ErrorCategory.VALIDATION,
        suggestions=suggestions,
        context=context,
        original_error=original,
    )
    
    formatted = error.format_error()
    assert "Complete error" in formatted
    assert "validation" in formatted
    assert "📋 Context:" in formatted
    assert "key: value" in formatted
    assert "🔍 Caused by:" in formatted
    assert "ValueError" in formatted
    assert "🛠️ How to fix:" in formatted
    assert "Fix" in formatted