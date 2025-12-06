"""
Integration tests for configuration with platform detection.

Tests the integration between config.py and platform.py to ensure:
- Automatic platform-based defaults work correctly
- Explicit configuration overrides work (backward compatibility)
- Validation errors are raised for incompatible configurations
- Environment variable overrides work
"""

import os
import sys
from pathlib import Path
from unittest.mock import patch, mock_open

import pytest
from pydantic import ValidationError

from ai_sidecar.config import (
    ZMQConfig,
    Settings,
    get_settings,
    get_config_summary,
    validate_config,
    print_config_help,
    DEFAULT_ZMQ_ENDPOINT_UNIX,
    DEFAULT_ZMQ_ENDPOINT_WINDOWS,
)
from ai_sidecar.utils.platform import (
    clear_platform_cache,
    DEFAULT_IPC_ENDPOINT,
    DEFAULT_TCP_ENDPOINT,
)


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture(autouse=True)
def clear_caches():
    """Clear all caches before and after each test."""
    clear_platform_cache()
    get_settings.cache_clear()
    yield
    clear_platform_cache()
    get_settings.cache_clear()


@pytest.fixture
def mock_linux_env():
    """Mock a Linux environment."""
    with patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', mock_open(read_data="")), \
         patch.object(Path, 'exists', return_value=False):
        yield


@pytest.fixture
def mock_windows_env():
    """Mock a Windows environment."""
    with patch.object(sys, 'platform', 'win32'), \
         patch.object(os, 'name', 'nt'):
        yield


@pytest.fixture
def mock_wsl2_env():
    """Mock a WSL2 environment."""
    proc_version_content = "Linux version 5.15.90.1-microsoft-standard-WSL2"
    with patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', mock_open(read_data=proc_version_content)), \
         patch.object(Path, 'exists', return_value=False):
        yield


@pytest.fixture
def mock_wsl1_env():
    """Mock a WSL1 environment."""
    proc_version_content = "Linux version 4.4.0-18362-Microsoft"
    with patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', mock_open(read_data=proc_version_content)), \
         patch.object(Path, 'exists', return_value=False):
        yield


# =============================================================================
# Test Automatic Platform-Based Defaults
# =============================================================================

class TestAutomaticPlatformDefaults:
    """Test that configuration automatically uses platform-appropriate defaults."""
    
    def test_linux_defaults_to_ipc(self, mock_linux_env):
        """Test Linux defaults to IPC endpoint."""
        config = ZMQConfig()
        
        assert config.endpoint == DEFAULT_IPC_ENDPOINT
        assert config.endpoint.startswith("ipc://")
    
    def test_windows_defaults_to_tcp(self, mock_windows_env):
        """Test Windows defaults to TCP endpoint."""
        config = ZMQConfig()
        
        assert config.endpoint == DEFAULT_TCP_ENDPOINT
        assert config.endpoint.startswith("tcp://")
    
    def test_wsl2_defaults_to_ipc(self, mock_wsl2_env):
        """Test WSL2 defaults to IPC endpoint."""
        config = ZMQConfig()
        
        assert config.endpoint == DEFAULT_IPC_ENDPOINT
        assert config.endpoint.startswith("ipc://")
    
    def test_wsl1_defaults_to_tcp(self, mock_wsl1_env):
        """Test WSL1 defaults to TCP endpoint."""
        config = ZMQConfig()
        
        assert config.endpoint == DEFAULT_TCP_ENDPOINT
        assert config.endpoint.startswith("tcp://")


# =============================================================================
# Test Explicit Configuration Override (Backward Compatibility)
# =============================================================================

class TestExplicitConfigOverride:
    """Test that explicit configuration overrides platform defaults."""
    
    def test_explicit_tcp_on_linux(self, mock_linux_env):
        """Test explicit TCP endpoint works on Linux."""
        config = ZMQConfig(endpoint="tcp://192.168.1.100:5555")
        
        assert config.endpoint == "tcp://192.168.1.100:5555"
    
    def test_explicit_ipc_on_linux(self, mock_linux_env):
        """Test explicit IPC endpoint works on Linux."""
        config = ZMQConfig(endpoint="ipc:///var/run/custom.sock")
        
        assert config.endpoint == "ipc:///var/run/custom.sock"
    
    def test_explicit_tcp_on_windows(self, mock_windows_env):
        """Test explicit TCP endpoint works on Windows."""
        config = ZMQConfig(endpoint="tcp://0.0.0.0:6666")
        
        assert config.endpoint == "tcp://0.0.0.0:6666"
    
    def test_explicit_inproc_on_linux(self, mock_linux_env):
        """Test explicit inproc endpoint works."""
        config = ZMQConfig(endpoint="inproc://test-channel")
        
        assert config.endpoint == "inproc://test-channel"
    
    def test_explicit_inproc_on_windows(self, mock_windows_env):
        """Test explicit inproc endpoint works on Windows."""
        config = ZMQConfig(endpoint="inproc://test-channel")
        
        assert config.endpoint == "inproc://test-channel"


# =============================================================================
# Test Validation Errors
# =============================================================================

class TestValidationErrors:
    """Test validation errors for incompatible configurations."""
    
    def test_ipc_on_windows_raises_error(self, mock_windows_env):
        """Test IPC endpoint on Windows raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ZMQConfig(endpoint="ipc:///tmp/test.sock")
        
        # Check error message mentions Windows
        error_str = str(exc_info.value)
        assert "Windows" in error_str or "not compatible" in error_str.lower()
    
    def test_ipc_on_wsl1_raises_error(self, mock_wsl1_env):
        """Test IPC endpoint on WSL1 raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ZMQConfig(endpoint="ipc:///tmp/test.sock")
        
        # Check error message
        error_str = str(exc_info.value)
        assert "WSL" in error_str or "not compatible" in error_str.lower()
    
    def test_empty_endpoint_raises_error(self, mock_linux_env):
        """Test empty endpoint raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ZMQConfig(endpoint="")
        
        error_str = str(exc_info.value)
        assert "empty" in error_str.lower()
    
    def test_invalid_protocol_raises_error(self, mock_linux_env):
        """Test invalid protocol raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ZMQConfig(endpoint="http://localhost:8080")
        
        error_str = str(exc_info.value)
        assert "Invalid" in error_str or "tcp://" in error_str
    
    def test_tcp_without_port_raises_error(self, mock_linux_env):
        """Test TCP endpoint without port raises validation error."""
        with pytest.raises(ValidationError) as exc_info:
            ZMQConfig(endpoint="tcp://localhost")
        
        error_str = str(exc_info.value)
        assert "port" in error_str.lower()


# =============================================================================
# Test Environment Variable Override
# =============================================================================

class TestEnvironmentVariableOverride:
    """Test environment variable overrides work correctly."""
    
    def test_env_var_overrides_default(self, mock_linux_env):
        """Test AI_ZMQ_ENDPOINT env var overrides default."""
        with patch.dict(os.environ, {"AI_ZMQ_ENDPOINT": "tcp://custom:9999"}):
            config = ZMQConfig()
            
            assert config.endpoint == "tcp://custom:9999"
    
    def test_env_var_ipc_on_linux(self, mock_linux_env):
        """Test IPC env var works on Linux."""
        with patch.dict(os.environ, {"AI_ZMQ_ENDPOINT": "ipc:///custom/path.sock"}):
            config = ZMQConfig()
            
            assert config.endpoint == "ipc:///custom/path.sock"
    
    def test_env_var_tcp_on_windows(self, mock_windows_env):
        """Test TCP env var works on Windows."""
        with patch.dict(os.environ, {"AI_ZMQ_ENDPOINT": "tcp://192.168.1.1:5555"}):
            config = ZMQConfig()
            
            assert config.endpoint == "tcp://192.168.1.1:5555"
    
    def test_env_var_ipc_on_windows_fails(self, mock_windows_env):
        """Test IPC env var on Windows raises error."""
        with patch.dict(os.environ, {"AI_ZMQ_ENDPOINT": "ipc:///tmp/test.sock"}):
            with pytest.raises(ValidationError):
                ZMQConfig()


# =============================================================================
# Test Settings Integration
# =============================================================================

class TestSettingsIntegration:
    """Test full Settings class integration with platform detection."""
    
    def test_settings_uses_platform_defaults_linux(self, mock_linux_env):
        """Test Settings uses platform-appropriate defaults on Linux."""
        settings = Settings()
        
        assert settings.zmq.endpoint == DEFAULT_IPC_ENDPOINT
    
    def test_settings_uses_platform_defaults_windows(self, mock_windows_env):
        """Test Settings uses platform-appropriate defaults on Windows."""
        settings = Settings()
        
        assert settings.zmq.endpoint == DEFAULT_TCP_ENDPOINT
    
    def test_get_settings_cached(self, mock_linux_env):
        """Test get_settings is cached."""
        settings1 = get_settings()
        settings2 = get_settings()
        
        assert settings1 is settings2


# =============================================================================
# Test Configuration Summary
# =============================================================================

class TestConfigSummary:
    """Test configuration summary includes platform info."""
    
    def test_summary_includes_platform_info(self, mock_linux_env):
        """Test config summary includes platform information."""
        summary = get_config_summary()
        
        assert "platform" in summary
        assert "platform_type" in summary
        assert "supports_ipc" in summary
        assert "is_container" in summary
    
    def test_summary_platform_correct_linux(self, mock_linux_env):
        """Test summary shows correct platform for Linux."""
        summary = get_config_summary()
        
        assert summary["platform"] == "Linux"
        assert summary["supports_ipc"] is True
    
    def test_summary_platform_correct_windows(self, mock_windows_env):
        """Test summary shows correct platform for Windows."""
        summary = get_config_summary()
        
        assert summary["platform"] == "Windows"
        assert summary["supports_ipc"] is False


# =============================================================================
# Test Configuration Validation
# =============================================================================

class TestConfigValidation:
    """Test configuration validation with platform awareness."""
    
    def test_validate_config_linux_ipc(self, mock_linux_env):
        """Test validate_config passes for IPC on Linux."""
        is_valid, issues = validate_config()
        
        assert is_valid is True
    
    def test_validate_config_windows_tcp(self, mock_windows_env):
        """Test validate_config passes for TCP on Windows."""
        is_valid, issues = validate_config()
        
        assert is_valid is True
    
    def test_validate_config_warns_on_security(self, mock_linux_env):
        """Test validate_config warns about security issues."""
        with patch.dict(os.environ, {"AI_ZMQ_ENDPOINT": "tcp://0.0.0.0:5555"}):
            get_settings.cache_clear()
            is_valid, issues = validate_config()
            
            assert is_valid is True
            assert any("0.0.0.0" in issue for issue in issues)


# =============================================================================
# Test Configuration Help
# =============================================================================

class TestConfigHelp:
    """Test configuration help output."""
    
    def test_help_includes_platform_info_linux(self, mock_linux_env, capsys):
        """Test help output includes platform info on Linux."""
        print_config_help()
        
        captured = capsys.readouterr()
        assert "Linux" in captured.out
        assert "IPC Support" in captured.out
        assert "✓" in captured.out  # IPC supported
    
    def test_help_includes_platform_info_windows(self, mock_windows_env, capsys):
        """Test help output includes platform info on Windows."""
        print_config_help()
        
        captured = capsys.readouterr()
        assert "Windows" in captured.out
        assert "IPC Support" in captured.out


# =============================================================================
# Test Backward Compatibility
# =============================================================================

class TestBackwardCompatibility:
    """Test backward compatibility with existing configurations."""
    
    def test_existing_unix_endpoint_still_works(self, mock_linux_env):
        """Test existing Unix IPC endpoint configuration still works."""
        config = ZMQConfig(endpoint=DEFAULT_ZMQ_ENDPOINT_UNIX)
        
        assert config.endpoint == DEFAULT_ZMQ_ENDPOINT_UNIX
    
    def test_existing_windows_endpoint_still_works(self, mock_windows_env):
        """Test existing Windows TCP endpoint configuration still works."""
        config = ZMQConfig(endpoint=DEFAULT_ZMQ_ENDPOINT_WINDOWS)
        
        assert config.endpoint == DEFAULT_ZMQ_ENDPOINT_WINDOWS
    
    def test_constants_still_exist(self):
        """Test that legacy constants still exist."""
        assert DEFAULT_ZMQ_ENDPOINT_UNIX == "ipc:///tmp/openkore-ai.sock"
        assert DEFAULT_ZMQ_ENDPOINT_WINDOWS == "tcp://127.0.0.1:5555"
    
    def test_other_config_fields_unchanged(self, mock_linux_env):
        """Test other ZMQConfig fields work as before."""
        config = ZMQConfig(
            recv_timeout_ms=500,
            send_timeout_ms=500,
            linger_ms=100,
            high_water_mark=2000,
        )
        
        assert config.recv_timeout_ms == 500
        assert config.send_timeout_ms == 500
        assert config.linger_ms == 100
        assert config.high_water_mark == 2000


# =============================================================================
# Test Edge Cases
# =============================================================================

class TestEdgeCases:
    """Test edge cases in configuration with platform detection."""
    
    def test_whitespace_in_endpoint_stripped(self, mock_linux_env):
        """Test whitespace in endpoint is stripped."""
        config = ZMQConfig(endpoint="  tcp://localhost:5555  ")
        
        assert config.endpoint == "tcp://localhost:5555"
    
    def test_case_sensitivity_in_protocol(self, mock_linux_env):
        """Test protocol is case-sensitive."""
        # TCP should work
        config = ZMQConfig(endpoint="tcp://localhost:5555")
        assert config.endpoint == "tcp://localhost:5555"
        
        # Mixed case might fail validation
        with pytest.raises(ValidationError):
            ZMQConfig(endpoint="TCP://localhost:5555")
    
    def test_container_detection_doesnt_affect_ipc(self, mock_linux_env):
        """Test container detection doesn't affect IPC support on Linux."""
        with patch.object(Path, 'exists', return_value=True):  # Docker detected
            clear_platform_cache()
            config = ZMQConfig()
            
            # Should still use IPC on Linux even in container
            assert config.endpoint == DEFAULT_IPC_ENDPOINT