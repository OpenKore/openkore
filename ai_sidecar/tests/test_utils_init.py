"""
Tests for utils/__init__.py - Lazy attribute loading.

Covers:
- __getattr__ lazy import mechanism
- Logging exports
- Error exports  
- Startup exports
- AttributeError for unknown attributes
"""

import pytest
from unittest.mock import patch, Mock


def test_lazy_import_get_logger():
    """Test lazy import of get_logger."""
    from ai_sidecar import utils
    
    # Should lazily import from logging module
    get_logger = utils.get_logger
    
    assert get_logger is not None
    assert callable(get_logger)


def test_lazy_import_setup_logging():
    """Test lazy import of setup_logging."""
    from ai_sidecar import utils
    
    setup_logging = utils.setup_logging
    
    assert setup_logging is not None
    assert callable(setup_logging)


def test_lazy_import_bind_context():
    """Test lazy import of bind_context."""
    from ai_sidecar import utils
    
    bind_context = utils.bind_context
    
    assert bind_context is not None
    assert callable(bind_context)


def test_lazy_import_clear_context():
    """Test lazy import of clear_context."""
    from ai_sidecar import utils
    
    clear_context = utils.clear_context
    
    assert clear_context is not None
    assert callable(clear_context)


def test_lazy_import_unbind_context():
    """Test lazy import of unbind_context."""
    from ai_sidecar import utils
    
    unbind_context = utils.unbind_context
    
    assert unbind_context is not None
    assert callable(unbind_context)


def test_lazy_import_sidecar_error():
    """Test lazy import of SidecarError."""
    from ai_sidecar import utils
    
    SidecarError = utils.SidecarError
    
    assert SidecarError is not None
    assert issubclass(SidecarError, Exception)


def test_lazy_import_configuration_error():
    """Test lazy import of ConfigurationError."""
    from ai_sidecar import utils
    
    ConfigurationError = utils.ConfigurationError
    
    assert ConfigurationError is not None


def test_lazy_import_missing_config_error():
    """Test lazy import of MissingConfigError."""
    from ai_sidecar import utils
    
    MissingConfigError = utils.MissingConfigError
    
    assert MissingConfigError is not None


def test_lazy_import_invalid_config_value_error():
    """Test lazy import of InvalidConfigValueError."""
    from ai_sidecar import utils
    
    InvalidConfigValueError = utils.InvalidConfigValueError
    
    assert InvalidConfigValueError is not None


def test_lazy_import_zmq_connection_error():
    """Test lazy import of ZMQConnectionError."""
    from ai_sidecar import utils
    
    ZMQConnectionError = utils.ZMQConnectionError
    
    assert ZMQConnectionError is not None


def test_lazy_import_redis_connection_error():
    """Test lazy import of RedisConnectionError."""
    from ai_sidecar import utils
    
    RedisConnectionError = utils.RedisConnectionError
    
    assert RedisConnectionError is not None


def test_lazy_import_initialization_error():
    """Test lazy import of InitializationError."""
    from ai_sidecar import utils
    
    InitializationError = utils.InitializationError
    
    assert InitializationError is not None


def test_lazy_import_model_load_error():
    """Test lazy import of ModelLoadError."""
    from ai_sidecar import utils
    
    ModelLoadError = utils.ModelLoadError
    
    assert ModelLoadError is not None


def test_lazy_import_dependency_error():
    """Test lazy import of DependencyError."""
    from ai_sidecar import utils
    
    DependencyError = utils.DependencyError
    
    assert DependencyError is not None


def test_lazy_import_resource_error():
    """Test lazy import of ResourceError."""
    from ai_sidecar import utils
    
    ResourceError = utils.ResourceError
    
    assert ResourceError is not None


def test_lazy_import_error_category():
    """Test lazy import of ErrorCategory."""
    from ai_sidecar import utils
    
    ErrorCategory = utils.ErrorCategory
    
    assert ErrorCategory is not None


def test_lazy_import_recovery_suggestion():
    """Test lazy import of RecoverySuggestion."""
    from ai_sidecar import utils
    
    RecoverySuggestion = utils.RecoverySuggestion
    
    assert RecoverySuggestion is not None


def test_lazy_import_format_validation_errors():
    """Test lazy import of format_validation_errors."""
    from ai_sidecar import utils
    
    format_validation_errors = utils.format_validation_errors
    
    assert format_validation_errors is not None
    assert callable(format_validation_errors)


def test_lazy_import_wrap_error():
    """Test lazy import of wrap_error."""
    from ai_sidecar import utils
    
    wrap_error = utils.wrap_error
    
    assert wrap_error is not None
    assert callable(wrap_error)


def test_lazy_import_format_loading_error():
    """Test lazy import of format_loading_error."""
    from ai_sidecar import utils
    
    format_loading_error = utils.format_loading_error
    
    assert format_loading_error is not None
    assert callable(format_loading_error)


def test_lazy_import_sidecar_memory_error():
    """Test lazy import of SidecarMemoryError alias."""
    from ai_sidecar import utils
    
    SidecarMemoryError = utils.SidecarMemoryError
    
    assert SidecarMemoryError is not None


def test_lazy_import_startup_progress():
    """Test lazy import of StartupProgress."""
    from ai_sidecar import utils
    
    StartupProgress = utils.StartupProgress
    
    assert StartupProgress is not None


def test_lazy_import_startup_step():
    """Test lazy import of StartupStep."""
    from ai_sidecar import utils
    
    StartupStep = utils.StartupStep
    
    assert StartupStep is not None


def test_lazy_import_spinner_progress():
    """Test lazy import of SpinnerProgress."""
    from ai_sidecar import utils
    
    SpinnerProgress = utils.SpinnerProgress
    
    assert SpinnerProgress is not None


def test_lazy_import_show_quick_status():
    """Test lazy import of show_quick_status."""
    from ai_sidecar import utils
    
    show_quick_status = utils.show_quick_status
    
    assert show_quick_status is not None
    assert callable(show_quick_status)


def test_lazy_import_wait_with_progress():
    """Test lazy import of wait_with_progress."""
    from ai_sidecar import utils
    
    wait_with_progress = utils.wait_with_progress
    
    assert wait_with_progress is not None
    assert callable(wait_with_progress)


def test_getattr_unknown_attribute():
    """Test __getattr__ raises AttributeError for unknown attributes."""
    from ai_sidecar import utils
    
    with pytest.raises(AttributeError, match="has no attribute 'unknown_func'"):
        _ = utils.unknown_func


def test_module_all_attribute():
    """Test __all__ contains expected module names."""
    from ai_sidecar import utils
    
    assert "logging" in utils.__all__
    assert "errors" in utils.__all__
    assert "startup" in utils.__all__