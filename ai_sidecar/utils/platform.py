"""
Cross-platform detection and endpoint configuration for AI Sidecar.

Provides automatic platform detection with smart endpoint selection for ZeroMQ
communication. Supports Windows, Linux, macOS, WSL (1 & 2), Cygwin, and Docker.

Features:
- Automatic platform detection with caching (<0.1ms overhead)
- Smart endpoint selection based on platform capabilities
- Validation of endpoint compatibility with current platform
- Comprehensive logging for debugging platform issues

Usage:
    >>> from ai_sidecar.utils.platform import detect_platform, get_default_zmq_endpoint
    >>> info = detect_platform()
    >>> print(info.platform_name)
    'linux'
    >>> endpoint = get_default_zmq_endpoint()
    >>> print(endpoint)
    'ipc:///tmp/openkore-ai.sock'
"""

from __future__ import annotations

import os
import sys
from dataclasses import dataclass, field
from enum import Enum
from functools import lru_cache
from pathlib import Path
from typing import Final

import structlog


# =============================================================================
# Constants
# =============================================================================

# Default endpoints for different platforms
DEFAULT_IPC_PATH: Final[str] = "/tmp/openkore-ai.sock"
DEFAULT_IPC_ENDPOINT: Final[str] = f"ipc://{DEFAULT_IPC_PATH}"
DEFAULT_TCP_HOST: Final[str] = "127.0.0.1"
DEFAULT_TCP_PORT: Final[int] = 5555
DEFAULT_TCP_ENDPOINT: Final[str] = f"tcp://{DEFAULT_TCP_HOST}:{DEFAULT_TCP_PORT}"

# WSL detection markers
WSL_PROC_VERSION_MARKERS: Final[tuple[str, ...]] = (
    "microsoft",
    "wsl",
)
WSL2_PROC_VERSION_MARKERS: Final[tuple[str, ...]] = (
    "wsl2",
    "microsoft-standard-wsl2",
)

# Cygwin detection
CYGWIN_MARKERS: Final[tuple[str, ...]] = (
    "cygwin",
    "msys",
)

# Docker detection paths
DOCKER_ENV_FILE: Final[str] = "/.dockerenv"
DOCKER_CGROUP_PATH: Final[str] = "/proc/1/cgroup"
DOCKER_CGROUP_MARKERS: Final[tuple[str, ...]] = (
    "docker",
    "containerd",
    "kubepods",
)

# Logger
logger = structlog.get_logger(__name__)


# =============================================================================
# Platform Types and Info
# =============================================================================

class PlatformType(str, Enum):
    """
    Enumeration of supported platform types.
    
    Used to categorize the runtime environment for endpoint selection.
    """
    
    WINDOWS = "windows"
    """Native Windows (including Windows Server)"""
    
    UNIX_LIKE = "unix_like"
    """Unix-like systems (Linux, macOS, BSD)"""
    
    WSL = "wsl"
    """Windows Subsystem for Linux (WSL 1 or 2)"""
    
    CYGWIN = "cygwin"
    """Cygwin or MSYS2 environment on Windows"""
    
    UNKNOWN = "unknown"
    """Unknown or unsupported platform"""


@dataclass(frozen=True, slots=True)
class PlatformInfo:
    """
    Immutable container for platform detection results.
    
    Contains all metadata needed for endpoint selection and logging.
    Frozen to ensure thread-safety and caching correctness.
    
    Attributes:
        platform_type: The detected platform category
        can_use_ipc: Whether IPC sockets work on this platform
        default_endpoint: Recommended ZMQ endpoint for this platform
        default_ipc_path: Default IPC socket path (Unix-like only)
        default_tcp_endpoint: Default TCP endpoint
        is_container: Whether running in a container (Docker/Kubernetes)
        wsl_version: WSL version (1 or 2) if running in WSL, None otherwise
        platform_name: Human-readable platform name
        sys_platform: Raw sys.platform value
        os_name: Raw os.name value
        detection_details: Additional detection metadata for debugging
    """
    
    platform_type: PlatformType
    can_use_ipc: bool
    default_endpoint: str
    default_ipc_path: str | None
    default_tcp_endpoint: str
    is_container: bool
    wsl_version: int | None
    platform_name: str
    sys_platform: str
    os_name: str
    detection_details: dict[str, str] = field(default_factory=dict)
    
    def __str__(self) -> str:
        """Human-readable representation."""
        parts = [f"Platform: {self.platform_name}"]
        if self.wsl_version:
            parts.append(f"(WSL{self.wsl_version})")
        if self.is_container:
            parts.append("[container]")
        parts.append(f"| IPC: {'✓' if self.can_use_ipc else '✗'}")
        parts.append(f"| Default: {self.default_endpoint}")
        return " ".join(parts)
    
    def to_dict(self) -> dict[str, str | bool | int | None]:
        """Convert to dictionary for logging and serialization."""
        return {
            "platform_type": self.platform_type.value,
            "can_use_ipc": self.can_use_ipc,
            "default_endpoint": self.default_endpoint,
            "default_ipc_path": self.default_ipc_path,
            "default_tcp_endpoint": self.default_tcp_endpoint,
            "is_container": self.is_container,
            "wsl_version": self.wsl_version,
            "platform_name": self.platform_name,
            "sys_platform": self.sys_platform,
            "os_name": self.os_name,
        }


# =============================================================================
# Detection Functions (Internal)
# =============================================================================

def _read_file_safe(path: str, max_bytes: int = 4096) -> str | None:
    """
    Safely read a file, returning None on any error.
    
    Args:
        path: File path to read
        max_bytes: Maximum bytes to read (prevents memory issues)
    
    Returns:
        File contents as lowercase string, or None if unreadable
    """
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read(max_bytes).lower()
    except (OSError, IOError, PermissionError):
        return None


def _detect_wsl_version() -> int | None:
    """
    Detect if running in WSL and determine version.
    
    WSL detection strategy:
    1. Check /proc/version for 'microsoft' or 'wsl' markers
    2. Distinguish WSL2 from WSL1 by kernel version markers
    
    Returns:
        1 for WSL1, 2 for WSL2, None if not WSL
    """
    proc_version = _read_file_safe("/proc/version")
    if proc_version is None:
        return None
    
    # Check for WSL markers
    is_wsl = any(marker in proc_version for marker in WSL_PROC_VERSION_MARKERS)
    if not is_wsl:
        return None
    
    # Check for WSL2 specific markers
    is_wsl2 = any(marker in proc_version for marker in WSL2_PROC_VERSION_MARKERS)
    return 2 if is_wsl2 else 1


def _detect_docker() -> bool:
    """
    Detect if running inside a Docker container.
    
    Detection strategy:
    1. Check for /.dockerenv file
    2. Check /proc/1/cgroup for container markers
    
    Returns:
        True if running in Docker/container, False otherwise
    """
    # Check for .dockerenv file (most reliable)
    if Path(DOCKER_ENV_FILE).exists():
        return True
    
    # Check cgroup for container markers
    cgroup_content = _read_file_safe(DOCKER_CGROUP_PATH)
    if cgroup_content is None:
        return False
    
    return any(marker in cgroup_content for marker in DOCKER_CGROUP_MARKERS)


def _detect_cygwin() -> bool:
    """
    Detect if running in Cygwin or MSYS2.
    
    Returns:
        True if running in Cygwin/MSYS2, False otherwise
    """
    platform_lower = sys.platform.lower()
    return any(marker in platform_lower for marker in CYGWIN_MARKERS)


def _get_platform_name() -> str:
    """
    Get human-readable platform name.
    
    Returns:
        Platform name string
    """
    platform_map = {
        "win32": "Windows",
        "darwin": "macOS",
        "linux": "Linux",
        "freebsd": "FreeBSD",
        "openbsd": "OpenBSD",
        "netbsd": "NetBSD",
    }
    
    platform_lower = sys.platform.lower()
    
    # Check for Cygwin first
    if _detect_cygwin():
        return "Cygwin"
    
    # Check for exact match
    if platform_lower in platform_map:
        return platform_map[platform_lower]
    
    # Check for partial match
    for key, name in platform_map.items():
        if key in platform_lower:
            return name
    
    return sys.platform.capitalize()


# =============================================================================
# Main Detection Function
# =============================================================================

@lru_cache(maxsize=1)
def detect_platform() -> PlatformInfo:
    """
    Detect current platform with comprehensive edge case handling.
    
    Uses caching to ensure detection only happens once per process.
    Subsequent calls return cached result with <0.1ms overhead.
    
    Detection priority:
    1. Check for WSL (Linux running on Windows)
    2. Check for Cygwin/MSYS2
    3. Check for native Windows
    4. Check for Unix-like (Linux, macOS, BSD)
    5. Fallback to UNKNOWN
    
    Returns:
        PlatformInfo: Immutable platform detection result
    
    Example:
        >>> info = detect_platform()
        >>> if info.can_use_ipc:
        ...     endpoint = info.default_endpoint
        ... else:
        ...     endpoint = info.default_tcp_endpoint
    """
    detection_details: dict[str, str] = {
        "sys_platform": sys.platform,
        "os_name": os.name,
    }
    
    # Check for container first (affects logging but not IPC capability)
    is_container = _detect_docker()
    if is_container:
        detection_details["container"] = "docker"
    
    # Check for WSL (must be before generic Linux check)
    wsl_version = _detect_wsl_version()
    if wsl_version is not None:
        detection_details["wsl_version"] = str(wsl_version)
        
        # WSL2 can use IPC, WSL1 has issues
        can_use_ipc = wsl_version >= 2
        
        info = PlatformInfo(
            platform_type=PlatformType.WSL,
            can_use_ipc=can_use_ipc,
            default_endpoint=DEFAULT_IPC_ENDPOINT if can_use_ipc else DEFAULT_TCP_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH if can_use_ipc else None,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=is_container,
            wsl_version=wsl_version,
            platform_name=f"WSL{wsl_version}",
            sys_platform=sys.platform,
            os_name=os.name,
            detection_details=detection_details,
        )
        
        logger.info(
            "platform_detected",
            platform_type=info.platform_type.value,
            wsl_version=wsl_version,
            can_use_ipc=can_use_ipc,
            default_endpoint=info.default_endpoint,
            is_container=is_container,
        )
        
        return info
    
    # Check for Cygwin/MSYS2
    if _detect_cygwin():
        detection_details["cygwin"] = "true"
        
        # Cygwin has limited IPC support, prefer TCP
        info = PlatformInfo(
            platform_type=PlatformType.CYGWIN,
            can_use_ipc=False,
            default_endpoint=DEFAULT_TCP_ENDPOINT,
            default_ipc_path=None,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=is_container,
            wsl_version=None,
            platform_name="Cygwin",
            sys_platform=sys.platform,
            os_name=os.name,
            detection_details=detection_details,
        )
        
        logger.info(
            "platform_detected",
            platform_type=info.platform_type.value,
            can_use_ipc=False,
            default_endpoint=info.default_endpoint,
        )
        
        return info
    
    # Check for native Windows
    if sys.platform == "win32" or os.name == "nt":
        info = PlatformInfo(
            platform_type=PlatformType.WINDOWS,
            can_use_ipc=False,
            default_endpoint=DEFAULT_TCP_ENDPOINT,
            default_ipc_path=None,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=is_container,
            wsl_version=None,
            platform_name="Windows",
            sys_platform=sys.platform,
            os_name=os.name,
            detection_details=detection_details,
        )
        
        logger.info(
            "platform_detected",
            platform_type=info.platform_type.value,
            can_use_ipc=False,
            default_endpoint=info.default_endpoint,
        )
        
        return info
    
    # Check for Unix-like systems (Linux, macOS, BSD)
    if os.name == "posix" or sys.platform in ("linux", "darwin"):
        platform_name = _get_platform_name()
        
        info = PlatformInfo(
            platform_type=PlatformType.UNIX_LIKE,
            can_use_ipc=True,
            default_endpoint=DEFAULT_IPC_ENDPOINT,
            default_ipc_path=DEFAULT_IPC_PATH,
            default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
            is_container=is_container,
            wsl_version=None,
            platform_name=platform_name,
            sys_platform=sys.platform,
            os_name=os.name,
            detection_details=detection_details,
        )
        
        logger.info(
            "platform_detected",
            platform_type=info.platform_type.value,
            platform_name=platform_name,
            can_use_ipc=True,
            default_endpoint=info.default_endpoint,
            is_container=is_container,
        )
        
        return info
    
    # Unknown platform - default to TCP for safety
    logger.warning(
        "unknown_platform_detected",
        sys_platform=sys.platform,
        os_name=os.name,
        fallback_endpoint=DEFAULT_TCP_ENDPOINT,
    )
    
    return PlatformInfo(
        platform_type=PlatformType.UNKNOWN,
        can_use_ipc=False,
        default_endpoint=DEFAULT_TCP_ENDPOINT,
        default_ipc_path=None,
        default_tcp_endpoint=DEFAULT_TCP_ENDPOINT,
        is_container=is_container,
        wsl_version=None,
        platform_name=f"Unknown ({sys.platform})",
        sys_platform=sys.platform,
        os_name=os.name,
        detection_details=detection_details,
    )


# =============================================================================
# Public API Functions
# =============================================================================

def get_default_zmq_endpoint() -> str:
    """
    Get the platform-appropriate default ZMQ endpoint.
    
    This is the recommended way to get the default endpoint for
    ZeroMQ communication. It automatically selects:
    - IPC socket for Unix-like systems (Linux, macOS, WSL2)
    - TCP socket for Windows, Cygwin, WSL1, and unknown platforms
    
    Returns:
        str: ZMQ endpoint string (e.g., 'ipc:///tmp/openkore-ai.sock')
    
    Example:
        >>> endpoint = get_default_zmq_endpoint()
        >>> # On Linux: 'ipc:///tmp/openkore-ai.sock'
        >>> # On Windows: 'tcp://127.0.0.1:5555'
    """
    return detect_platform().default_endpoint


def supports_ipc() -> bool:
    """
    Check if current platform supports IPC sockets.
    
    Returns:
        bool: True if IPC sockets are supported
    
    Example:
        >>> if supports_ipc():
        ...     print("Can use IPC sockets")
        ... else:
        ...     print("Must use TCP sockets")
    """
    return detect_platform().can_use_ipc


def is_wsl() -> bool:
    """
    Check if running in Windows Subsystem for Linux.
    
    Returns:
        bool: True if running in WSL (1 or 2)
    
    Example:
        >>> if is_wsl():
        ...     print(f"Running in WSL{get_wsl_version()}")
    """
    return detect_platform().wsl_version is not None


def get_wsl_version() -> int | None:
    """
    Get WSL version if running in WSL.
    
    Returns:
        int | None: 1 for WSL1, 2 for WSL2, None if not WSL
    """
    return detect_platform().wsl_version


def is_docker() -> bool:
    """
    Check if running inside a Docker container.
    
    Returns:
        bool: True if running in Docker/container
    """
    return detect_platform().is_container


def is_windows() -> bool:
    """
    Check if running on native Windows.
    
    Note: Returns False for WSL and Cygwin.
    
    Returns:
        bool: True if native Windows
    """
    return detect_platform().platform_type == PlatformType.WINDOWS


def is_unix_like() -> bool:
    """
    Check if running on a Unix-like system.
    
    Returns:
        bool: True for Linux, macOS, BSD, etc.
    """
    return detect_platform().platform_type == PlatformType.UNIX_LIKE


def get_recommended_endpoint() -> str:
    """
    Alias for get_default_zmq_endpoint().
    
    Provided for semantic clarity when the intent is to get
    a recommended endpoint based on platform capabilities.
    
    Returns:
        str: Recommended ZMQ endpoint for current platform
    """
    return get_default_zmq_endpoint()


# =============================================================================
# Validation Functions
# =============================================================================

def validate_endpoint_for_platform(endpoint: str) -> tuple[bool, str | None]:
    """
    Validate that an endpoint is compatible with the current platform.
    
    Args:
        endpoint: ZMQ endpoint string to validate
    
    Returns:
        tuple: (is_valid, error_message)
            - (True, None) if endpoint is compatible
            - (False, "error message") if incompatible
    
    Example:
        >>> valid, error = validate_endpoint_for_platform("ipc:///tmp/test.sock")
        >>> if not valid:
        ...     print(f"Error: {error}")
    """
    platform_info = detect_platform()
    endpoint_lower = endpoint.lower().strip()
    
    # Check for IPC endpoint on non-IPC platform
    if endpoint_lower.startswith("ipc://"):
        if not platform_info.can_use_ipc:
            return False, (
                f"IPC sockets are not supported on {platform_info.platform_name}. "
                f"Use TCP endpoint instead: {platform_info.default_tcp_endpoint}"
            )
    
    # All other endpoints are generally compatible
    return True, None


def get_platform_info_for_logging() -> dict[str, str | bool | int | None]:
    """
    Get platform information formatted for structured logging.
    
    Returns:
        dict: Platform info suitable for log context
    """
    return detect_platform().to_dict()


# =============================================================================
# Cache Management
# =============================================================================

def clear_platform_cache() -> None:
    """
    Clear the platform detection cache.
    
    Useful for testing or when platform environment changes.
    Should rarely be needed in production.
    
    Warning:
        This will cause platform detection to run again on next call.
    """
    detect_platform.cache_clear()
    logger.debug("platform_cache_cleared")


def get_platform_cache_info() -> dict[str, int]:
    """
    Get cache statistics for platform detection.
    
    Returns:
        dict: Cache info with hits, misses, maxsize, currsize
    """
    info = detect_platform.cache_info()
    return {
        "hits": info.hits,
        "misses": info.misses,
        "maxsize": info.maxsize or 0,
        "currsize": info.currsize,
    }