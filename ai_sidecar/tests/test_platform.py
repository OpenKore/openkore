"""
Comprehensive unit tests for platform detection module.

Tests platform detection, endpoint selection, caching, and edge cases
for Windows, Linux, macOS, WSL (1 & 2), Cygwin, and Docker.
"""

import os
import sys
from pathlib import Path
from unittest.mock import MagicMock, Mock, patch, mock_open

import pytest

from ai_sidecar.utils.platform import (
    # Enums and dataclasses
    PlatformType,
    PlatformInfo,
    # Main detection
    detect_platform,
    # Public API
    get_default_zmq_endpoint,
    get_recommended_endpoint,
    supports_ipc,
    is_wsl,
    get_wsl_version,
    is_docker,
    is_windows,
    is_unix_like,
    # Validation
    validate_endpoint_for_platform,
    get_platform_info_for_logging,
    # Cache management
    clear_platform_cache,
    get_platform_cache_info,
    # Constants
    DEFAULT_IPC_ENDPOINT,
    DEFAULT_TCP_ENDPOINT,
    DEFAULT_IPC_PATH,
)


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture(autouse=True)
def clear_cache_before_test():
    """Clear platform cache before each test to ensure isolation."""
    clear_platform_cache()
    yield
    clear_platform_cache()


@pytest.fixture
def mock_linux_platform():
    """Mock a standard Linux platform."""
    with patch.object(sys, 'platform', 'linux'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', mock_open(read_data="")), \
         patch.object(Path, 'exists', return_value=False):
        yield


@pytest.fixture
def mock_windows_platform():
    """Mock a Windows platform."""
    with patch.object(sys, 'platform', 'win32'), \
         patch.object(os, 'name', 'nt'):
        yield


@pytest.fixture
def mock_macos_platform():
    """Mock a macOS platform."""
    with patch.object(sys, 'platform', 'darwin'), \
         patch.object(os, 'name', 'posix'), \
         patch('builtins.open', mock_open(read_data="")), \
         patch.object(Path, 'exists', return_value=False):
        yield


# =============================================================================
# Test PlatformType Enum
# =============================================================================

class TestPlatformType:
    """Test PlatformType enumeration."""
    
    def test_platform_type_values(self):
        """Test all platform type values exist."""
        assert PlatformType.WINDOWS.value == "windows"
        assert PlatformType.UNIX_LIKE.value == "unix_like"
        assert PlatformType.WSL.value == "wsl"
        assert PlatformType.CYGWIN.value == "cygwin"
        assert PlatformType.UNKNOWN.value == "unknown"
    
    def test_platform_type_is_string_enum(self):
        """Test that PlatformType inherits from str."""
        assert isinstance(PlatformType.WINDOWS, str)
        assert PlatformType.WINDOWS == "windows"


# =============================================================================
# Test PlatformInfo Dataclass
# =============================================================================

class TestPlatformInfo:
    """Test PlatformInfo dataclass."""
    
    def test_create_platform_info(self):
        """Test creating a PlatformInfo instance."""
        info = PlatformInfo(
            platform_type=PlatformType.UNIX_LIKE,
            can_use_ipc=True,
            default_endpoint=DEFAULT_IPC_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=False,
            wsl_version=None,
            platform_name="Linux",
            sys_platform="linux",
            os_name="posix",
        )
        
        assert info.platform_type == PlatformType.UNIX_LIKE
        assert info.can_use_ipc is True
        assert info.default_endpoint == DEFAULT_IPC_ENDPOINT
        assert info.platform_name == "Linux"
    
    def test_platform_info_is_frozen(self):
        """Test that PlatformInfo is immutable."""
        info = PlatformInfo(
            platform_type=PlatformType.WINDOWS,
            can_use_ipc=False,
            default_endpoint=DEFAULT_TCP_ENDPOINT,
            default_ipc_path=None,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=False,
            wsl_version=None,
            platform_name="Windows",
            sys_platform="win32",
            os_name="nt",
        )
        
        with pytest.raises(AttributeError):
            info.platform_type = PlatformType.UNIX_LIKE
    
    def test_platform_info_str_representation(self):
        """Test string representation."""
        info = PlatformInfo(
            platform_type=PlatformType.UNIX_LIKE,
            can_use_ipc=True,
            default_endpoint=DEFAULT_IPC_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=False,
            wsl_version=None,
            platform_name="Linux",
            sys_platform="linux",
            os_name="posix",
        )
        
        str_repr = str(info)
        assert "Linux" in str_repr
        assert "IPC: ✓" in str_repr
    
    def test_platform_info_str_wsl(self):
        """Test string representation for WSL."""
        info = PlatformInfo(
            platform_type=PlatformType.WSL,
            can_use_ipc=True,
            default_endpoint=DEFAULT_IPC_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=False,
            wsl_version=2,
            platform_name="WSL2",
            sys_platform="linux",
            os_name="posix",
        )
        
        str_repr = str(info)
        assert "WSL2" in str_repr
        assert "(WSL2)" in str_repr
    
    def test_platform_info_str_container(self):
        """Test string representation for container."""
        info = PlatformInfo(
            platform_type=PlatformType.UNIX_LIKE,
            can_use_ipc=True,
            default_endpoint=DEFAULT_IPC_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=True,
            wsl_version=None,
            platform_name="Linux",
            sys_platform="linux",
            os_name="posix",
        )
        
        str_repr = str(info)
        assert "[container]" in str_repr
    
    def test_platform_info_to_dict(self):
        """Test conversion to dictionary."""
        info = PlatformInfo(
            platform_type=PlatformType.WINDOWS,
            can_use_ipc=False,
            default_endpoint=DEFAULT_TCP_ENDPOINT,
            default_ipc_path=None,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=False,
            wsl_version=None,
            platform_name="Windows",
            sys_platform="win32",
            os_name="nt",
        )
        
        d = info.to_dict()
        
        assert d["platform_type"] == "windows"
        assert d["can_use_ipc"] is False
        assert d["platform_name"] == "Windows"
        assert d["wsl_version"] is None


# =============================================================================
# Test Platform Detection - Linux
# =============================================================================

class TestLinuxPlatformDetection:
    """Test platform detection on Linux."""
    
    def test_detect_linux_platform(self, mock_linux_platform):
        """Test detection of standard Linux."""
        info = detect_platform()
        
        assert info.platform_type == PlatformType.UNIX_LIKE
        assert info.can_use_ipc is True
        assert info.default_endpoint == DEFAULT_IPC_ENDPOINT
        assert info.platform_name == "Linux"
        assert info.wsl_version is None
    
    def test_linux_supports_ipc(self, mock_linux_platform):
        """Test Linux IPC support."""
        assert supports_ipc() is True
    
    def test_linux_is_not_wsl(self, mock_linux_platform):
        """Test Linux is not detected as WSL."""
        assert is_wsl() is False
        assert get_wsl_version() is None
    
    def test_linux_is_not_windows(self, mock_linux_platform):
        """Test Linux is not detected as Windows."""
        assert is_windows() is False
    
    def test_linux_is_unix_like(self, mock_linux_platform):
        """Test Linux is detected as Unix-like."""
        assert is_unix_like() is True


# =============================================================================
# Test Platform Detection - Windows
# =============================================================================

class TestWindowsPlatformDetection:
    """Test platform detection on Windows."""
    
    def test_detect_windows_platform(self, mock_windows_platform):
        """Test detection of native Windows."""
        info = detect_platform()
        
        assert info.platform_type == PlatformType.WINDOWS
        assert info.can_use_ipc is False
        assert info.default_endpoint == DEFAULT_TCP_ENDPOINT
        assert info.platform_name == "Windows"
    
    def test_windows_does_not_support_ipc(self, mock_windows_platform):
        """Test Windows IPC (lack of) support."""
        assert supports_ipc() is False
    
    def test_windows_is_not_wsl(self, mock_windows_platform):
        """Test Windows is not detected as WSL."""
        assert is_wsl() is False
    
    def test_windows_is_windows(self, mock_windows_platform):
        """Test Windows is detected as Windows."""
        assert is_windows() is True
    
    def test_windows_is_not_unix_like(self, mock_windows_platform):
        """Test Windows is not Unix-like."""
        assert is_unix_like() is False
    
    def test_windows_default_endpoint(self, mock_windows_platform):
        """Test Windows default endpoint is TCP."""
        endpoint = get_default_zmq_endpoint()
        assert endpoint == DEFAULT_TCP_ENDPOINT
        assert endpoint.startswith("tcp://")


# =============================================================================
# Test Platform Detection - macOS
# =============================================================================

class TestMacOSPlatformDetection:
    """Test platform detection on macOS."""
    
    def test_detect_macos_platform(self, mock_macos_platform):
        """Test detection of macOS."""
        info = detect_platform()
        
        assert info.platform_type == PlatformType.UNIX_LIKE
        assert info.can_use_ipc is True
        assert info.default_endpoint == DEFAULT_IPC_ENDPOINT
        assert info.platform_name == "macOS"
    
    def test_macos_supports_ipc(self, mock_macos_platform):
        """Test macOS IPC support."""
        assert supports_ipc() is True


# =============================================================================
# Test Platform Detection - WSL
# =============================================================================

class TestWSLPlatformDetection:
    """Test platform detection on WSL."""
    
    def test_detect_wsl1(self):
        """Test detection of WSL1."""
        proc_version_content = "Linux version 4.4.0-18362-Microsoft (gcc version 5.4.0)"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            info = detect_platform()
            
            assert info.platform_type == PlatformType.WSL
            assert info.wsl_version == 1
            assert info.can_use_ipc is False  # WSL1 has IPC issues
            assert info.default_endpoint == DEFAULT_TCP_ENDPOINT
    
    def test_detect_wsl2(self):
        """Test detection of WSL2."""
        proc_version_content = "Linux version 5.15.90.1-microsoft-standard-WSL2"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            info = detect_platform()
            
            assert info.platform_type == PlatformType.WSL
            assert info.wsl_version == 2
            assert info.can_use_ipc is True  # WSL2 supports IPC
            assert info.default_endpoint == DEFAULT_IPC_ENDPOINT
    
    def test_wsl2_supports_ipc(self):
        """Test WSL2 IPC support."""
        proc_version_content = "Linux version 5.15.90.1-microsoft-standard-WSL2"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            assert supports_ipc() is True
    
    def test_wsl1_does_not_support_ipc(self):
        """Test WSL1 IPC (lack of) support."""
        proc_version_content = "Linux version 4.4.0-18362-Microsoft"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            assert supports_ipc() is False
    
    def test_is_wsl_returns_true(self):
        """Test is_wsl returns True for WSL."""
        proc_version_content = "Linux version 5.15.90.1-microsoft-standard-WSL2"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            assert is_wsl() is True
    
    def test_get_wsl_version_returns_version(self):
        """Test get_wsl_version returns correct version."""
        proc_version_content = "Linux version 5.15.90.1-microsoft-standard-WSL2"
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data=proc_version_content)), \
             patch.object(Path, 'exists', return_value=False):
            assert get_wsl_version() == 2


# =============================================================================
# Test Platform Detection - Cygwin
# =============================================================================

class TestCygwinPlatformDetection:
    """Test platform detection on Cygwin."""
    
    def test_detect_cygwin(self):
        """Test detection of Cygwin."""
        with patch.object(sys, 'platform', 'cygwin'), \
             patch.object(os, 'name', 'posix'):
            info = detect_platform()
            
            assert info.platform_type == PlatformType.CYGWIN
            assert info.can_use_ipc is False
            assert info.default_endpoint == DEFAULT_TCP_ENDPOINT
            assert info.platform_name == "Cygwin"
    
    def test_detect_msys(self):
        """Test detection of MSYS2."""
        with patch.object(sys, 'platform', 'msys'), \
             patch.object(os, 'name', 'posix'):
            info = detect_platform()
            
            assert info.platform_type == PlatformType.CYGWIN
            assert info.can_use_ipc is False


# =============================================================================
# Test Platform Detection - Docker
# =============================================================================

class TestDockerDetection:
    """Test Docker container detection."""
    
    def test_detect_docker_via_dockerenv(self, mock_linux_platform):
        """Test Docker detection via /.dockerenv file."""
        with patch.object(Path, 'exists', return_value=True):
            clear_platform_cache()
            info = detect_platform()
            
            assert info.is_container is True
    
    def test_detect_docker_via_cgroup(self):
        """Test Docker detection via /proc/1/cgroup."""
        cgroup_content = "12:devices:/docker/abc123\n"
        
        def mock_exists(self):
            return str(self) == "/proc/1/cgroup"
        
        def mock_read(path, *args, **kwargs):
            if "/proc/1/cgroup" in str(path):
                return mock_open(read_data=cgroup_content)()
            return mock_open(read_data="")()
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch.object(Path, 'exists', return_value=False), \
             patch('builtins.open', side_effect=mock_read):
            info = detect_platform()
            
            assert info.is_container is True
    
    def test_is_docker_returns_true(self):
        """Test is_docker returns True in container."""
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch.object(Path, 'exists', return_value=True), \
             patch('builtins.open', mock_open(read_data="")):
            assert is_docker() is True
    
    def test_is_docker_returns_false(self, mock_linux_platform):
        """Test is_docker returns False outside container."""
        assert is_docker() is False


# =============================================================================
# Test Endpoint Functions
# =============================================================================

class TestEndpointFunctions:
    """Test endpoint-related functions."""
    
    def test_get_default_zmq_endpoint_linux(self, mock_linux_platform):
        """Test default endpoint on Linux."""
        endpoint = get_default_zmq_endpoint()
        assert endpoint == DEFAULT_IPC_ENDPOINT
    
    def test_get_default_zmq_endpoint_windows(self, mock_windows_platform):
        """Test default endpoint on Windows."""
        endpoint = get_default_zmq_endpoint()
        assert endpoint == DEFAULT_TCP_ENDPOINT
    
    def test_get_recommended_endpoint_alias(self, mock_linux_platform):
        """Test get_recommended_endpoint is alias for get_default_zmq_endpoint."""
        assert get_recommended_endpoint() == get_default_zmq_endpoint()


# =============================================================================
# Test Validation Functions
# =============================================================================

class TestValidationFunctions:
    """Test endpoint validation functions."""
    
    def test_validate_ipc_on_linux(self, mock_linux_platform):
        """Test IPC validation on Linux (should pass)."""
        is_valid, error = validate_endpoint_for_platform("ipc:///tmp/test.sock")
        
        assert is_valid is True
        assert error is None
    
    def test_validate_ipc_on_windows(self, mock_windows_platform):
        """Test IPC validation on Windows (should fail)."""
        is_valid, error = validate_endpoint_for_platform("ipc:///tmp/test.sock")
        
        assert is_valid is False
        assert error is not None
        assert "not supported" in error.lower() or "Windows" in error
    
    def test_validate_tcp_on_linux(self, mock_linux_platform):
        """Test TCP validation on Linux (should pass)."""
        is_valid, error = validate_endpoint_for_platform("tcp://127.0.0.1:5555")
        
        assert is_valid is True
        assert error is None
    
    def test_validate_tcp_on_windows(self, mock_windows_platform):
        """Test TCP validation on Windows (should pass)."""
        is_valid, error = validate_endpoint_for_platform("tcp://127.0.0.1:5555")
        
        assert is_valid is True
        assert error is None
    
    def test_validate_inproc_endpoint(self, mock_linux_platform):
        """Test inproc validation (should pass anywhere)."""
        is_valid, error = validate_endpoint_for_platform("inproc://test")
        
        assert is_valid is True
        assert error is None


# =============================================================================
# Test Cache Behavior
# =============================================================================

class TestCacheBehavior:
    """Test caching of platform detection."""
    
    def test_detection_is_cached(self, mock_linux_platform):
        """Test that platform detection is cached."""
        # First call
        info1 = detect_platform()
        cache_info1 = get_platform_cache_info()
        
        # Second call (should be cached)
        info2 = detect_platform()
        cache_info2 = get_platform_cache_info()
        
        assert info1 is info2  # Same object (cached)
        assert cache_info2["hits"] == cache_info1["hits"] + 1
    
    def test_clear_cache(self, mock_linux_platform):
        """Test cache clearing."""
        # Populate cache
        detect_platform()
        cache_info1 = get_platform_cache_info()
        assert cache_info1["currsize"] == 1
        
        # Clear cache
        clear_platform_cache()
        cache_info2 = get_platform_cache_info()
        assert cache_info2["currsize"] == 0
    
    def test_cache_info_structure(self, mock_linux_platform):
        """Test cache info structure."""
        detect_platform()
        cache_info = get_platform_cache_info()
        
        assert "hits" in cache_info
        assert "misses" in cache_info
        assert "maxsize" in cache_info
        assert "currsize" in cache_info
        
        assert isinstance(cache_info["hits"], int)
        assert isinstance(cache_info["misses"], int)


# =============================================================================
# Test Logging Integration
# =============================================================================

class TestLoggingIntegration:
    """Test logging-related functions."""
    
    def test_get_platform_info_for_logging(self, mock_linux_platform):
        """Test platform info for logging."""
        log_info = get_platform_info_for_logging()
        
        assert isinstance(log_info, dict)
        assert "platform_type" in log_info
        assert "can_use_ipc" in log_info
        assert "platform_name" in log_info
    
    def test_platform_info_for_logging_structure(self, mock_linux_platform):
        """Test logging info has correct structure."""
        log_info = get_platform_info_for_logging()
        
        # All values should be JSON-serializable types
        for key, value in log_info.items():
            assert isinstance(value, (str, bool, int, type(None)))


# =============================================================================
# Test Edge Cases
# =============================================================================

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    def test_unknown_platform(self):
        """Test handling of unknown platform."""
        with patch.object(sys, 'platform', 'unknown_os'), \
             patch.object(os, 'name', 'unknown'):
            info = detect_platform()
            
            assert info.platform_type == PlatformType.UNKNOWN
            assert info.can_use_ipc is False
            assert info.default_endpoint == DEFAULT_TCP_ENDPOINT
    
    def test_unreadable_proc_version(self):
        """Test handling when /proc/version is unreadable."""
        def raise_permission_error(*args, **kwargs):
            raise PermissionError("Access denied")
        
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', side_effect=raise_permission_error), \
             patch.object(Path, 'exists', return_value=False):
            # Should not raise, should fall back to regular Linux
            info = detect_platform()
            
            assert info.platform_type == PlatformType.UNIX_LIKE
            assert info.can_use_ipc is True
    
    def test_empty_proc_version(self):
        """Test handling of empty /proc/version."""
        with patch.object(sys, 'platform', 'linux'), \
             patch.object(os, 'name', 'posix'), \
             patch('builtins.open', mock_open(read_data="")), \
             patch.object(Path, 'exists', return_value=False):
            info = detect_platform()
            
            # Should be regular Linux, not WSL
            assert info.platform_type == PlatformType.UNIX_LIKE
            assert info.wsl_version is None


# =============================================================================
# Test Constants
# =============================================================================

class TestConstants:
    """Test module constants."""
    
    def test_default_ipc_endpoint_format(self):
        """Test IPC endpoint format."""
        assert DEFAULT_IPC_ENDPOINT.startswith("ipc://")
        assert DEFAULT_IPC_PATH in DEFAULT_IPC_ENDPOINT
    
    def test_default_tcp_endpoint_format(self):
        """Test TCP endpoint format."""
        assert DEFAULT_TCP_ENDPOINT.startswith("tcp://")
        assert "127.0.0.1" in DEFAULT_TCP_ENDPOINT
        assert "5555" in DEFAULT_TCP_ENDPOINT
    
    def test_default_ipc_path(self):
        """Test default IPC path."""
        assert DEFAULT_IPC_PATH == "/tmp/openkore-ai.sock"