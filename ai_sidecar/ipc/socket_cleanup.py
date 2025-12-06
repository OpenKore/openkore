"""
IPC Socket Cleanup Module.

Provides automatic cleanup of stale IPC socket files on Unix-like systems.
This module handles the common scenario where a previous process crashed
without properly cleaning up its socket file, preventing new processes
from binding to the same endpoint.

Features:
- Stale socket detection via connection testing
- Safe cleanup with race condition handling
- Platform-aware operation (Unix only)
- Security validation (path traversal, symlinks)
- Comprehensive logging with structured metadata

Phase 2 Implementation - Cross-Platform ZMQ Architecture
"""

from __future__ import annotations

import os
import socket
import stat
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Final, Optional

import structlog

from ai_sidecar.utils.platform import (
    detect_platform,
    supports_ipc,
    PlatformType,
)


# =============================================================================
# Constants
# =============================================================================

# IPC endpoint prefix
IPC_PREFIX: Final[str] = "ipc://"

# Connection test timeout in seconds (100ms max as per spec)
CONNECTION_TEST_TIMEOUT_S: Final[float] = 0.1

# Expected socket directory for validation
EXPECTED_SOCKET_DIRS: Final[tuple[str, ...]] = (
    "/tmp",
    "/var/run",
    "/run",
)

# Logger for this module
logger = structlog.get_logger(__name__)


# =============================================================================
# Data Classes
# =============================================================================


@dataclass(frozen=True, slots=True)
class CleanupResult:
    """
    Result of an IPC socket cleanup operation.
    
    Attributes:
        success: Whether cleanup was successful or not needed
        was_stale: Whether a stale socket was found and removed
        error: Error message if cleanup failed
        socket_path: The socket path that was processed
        cleanup_time_ms: Time taken for cleanup in milliseconds
    """
    
    success: bool
    was_stale: bool
    error: Optional[str] = None
    socket_path: Optional[Path] = None
    cleanup_time_ms: float = 0.0


@dataclass
class SocketValidationResult:
    """
    Result of socket path validation.
    
    Attributes:
        is_valid: Whether the path is valid for cleanup
        error: Error message if validation failed
        resolved_path: The resolved absolute path
    """
    
    is_valid: bool
    error: Optional[str] = None
    resolved_path: Optional[Path] = None


# =============================================================================
# Public API
# =============================================================================


def cleanup_ipc_socket(endpoint: str) -> CleanupResult:
    """
    Clean up a potentially stale IPC socket file.
    
    This function performs the following steps:
    1. Validate endpoint is IPC format
    2. Check platform supports IPC
    3. Validate socket path for security
    4. Check if socket file exists
    5. Test if socket is stale (exists but not responding)
    6. Remove stale socket if found
    
    Args:
        endpoint: ZMQ endpoint string (e.g., "ipc:///tmp/openkore-ai.sock")
        
    Returns:
        CleanupResult with success status and details
        
    Example:
        >>> result = cleanup_ipc_socket("ipc:///tmp/openkore-ai.sock")
        >>> if result.success:
        ...     print(f"Cleanup successful (stale={result.was_stale})")
    """
    start_time = time.monotonic()
    
    # Check if endpoint is IPC format
    if not endpoint.startswith(IPC_PREFIX):
        logger.debug(
            "cleanup_skipped",
            endpoint=endpoint,
            reason="not_ipc_endpoint",
        )
        return CleanupResult(
            success=True,
            was_stale=False,
            error=None,
            socket_path=None,
            cleanup_time_ms=_elapsed_ms(start_time),
        )
    
    # Check platform support
    if not supports_ipc():
        platform_info = detect_platform()
        logger.debug(
            "cleanup_skipped",
            endpoint=endpoint,
            reason="platform_no_ipc_support",
            platform=platform_info.platform_name,
        )
        return CleanupResult(
            success=True,
            was_stale=False,
            error=None,
            socket_path=None,
            cleanup_time_ms=_elapsed_ms(start_time),
        )
    
    # Extract socket path from endpoint
    socket_path_str = endpoint[len(IPC_PREFIX):]
    
    # Validate socket path for security
    validation = _validate_socket_path(socket_path_str)
    if not validation.is_valid:
        logger.warning(
            "cleanup_validation_failed",
            endpoint=endpoint,
            error=validation.error,
        )
        return CleanupResult(
            success=False,
            was_stale=False,
            error=validation.error,
            socket_path=None,
            cleanup_time_ms=_elapsed_ms(start_time),
        )
    
    socket_path = validation.resolved_path
    assert socket_path is not None  # Guaranteed by validation
    
    # Check if socket file exists
    if not socket_path.exists():
        logger.debug(
            "cleanup_not_needed",
            socket_path=str(socket_path),
            reason="socket_not_exists",
        )
        return CleanupResult(
            success=True,
            was_stale=False,
            error=None,
            socket_path=socket_path,
            cleanup_time_ms=_elapsed_ms(start_time),
        )
    
    # Check if socket is stale
    if not is_socket_stale(socket_path):
        logger.debug(
            "cleanup_not_needed",
            socket_path=str(socket_path),
            reason="socket_in_use",
        )
        return CleanupResult(
            success=True,
            was_stale=False,
            error=None,
            socket_path=socket_path,
            cleanup_time_ms=_elapsed_ms(start_time),
        )
    
    # Socket is stale - attempt cleanup
    logger.info(
        "stale_socket_detected",
        socket_path=str(socket_path),
    )
    
    if safe_remove_socket(socket_path):
        elapsed = _elapsed_ms(start_time)
        logger.info(
            "stale_socket_cleaned",
            socket_path=str(socket_path),
            cleanup_time_ms=elapsed,
        )
        return CleanupResult(
            success=True,
            was_stale=True,
            error=None,
            socket_path=socket_path,
            cleanup_time_ms=elapsed,
        )
    else:
        elapsed = _elapsed_ms(start_time)
        error_msg = f"Failed to remove stale socket: {socket_path}"
        logger.warning(
            "cleanup_failed",
            socket_path=str(socket_path),
            error=error_msg,
        )
        return CleanupResult(
            success=False,
            was_stale=True,
            error=error_msg,
            socket_path=socket_path,
            cleanup_time_ms=elapsed,
        )


def is_socket_stale(socket_path: Path) -> bool:
    """
    Check if a socket file is stale (exists but not responding).
    
    A socket is considered stale if:
    - The file exists
    - It is a socket file (not regular file or directory)
    - No process is listening on it (connection test fails)
    
    Args:
        socket_path: Path to the socket file
        
    Returns:
        True if socket is stale and can be safely removed
        
    Note:
        Returns False if socket doesn't exist or is in use.
        Returns False on any error (fail-safe approach).
    """
    try:
        # Check if path exists
        if not socket_path.exists():
            return False
        
        # Verify it's a socket file (not symlink, directory, or regular file)
        if not _is_unix_socket(socket_path):
            logger.warning(
                "not_a_socket",
                path=str(socket_path),
                reason="path_exists_but_not_socket",
            )
            return False
        
        # Test if socket is responding
        if check_socket_connection(socket_path):
            # Socket is in use - not stale
            return False
        
        # Socket exists but not responding - it's stale
        return True
        
    except Exception as e:
        # On any error, assume socket is not stale (fail-safe)
        logger.debug(
            "stale_check_error",
            socket_path=str(socket_path),
            error=str(e),
        )
        return False


def check_socket_connection(socket_path: Path) -> bool:
    """
    Check if a Unix socket is responsive (has a listener).
    
    Attempts a non-blocking connection to the socket with a short timeout.
    If connection succeeds, the socket is in use. If it fails with
    "Connection refused", the socket is stale.
    
    Args:
        socket_path: Path to the Unix socket file
        
    Returns:
        True if socket is responsive (in use), False otherwise
        
    Note:
        Uses a 100ms timeout to avoid blocking server startup.
    """
    sock = None
    try:
        # Create a Unix domain socket
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        sock.setblocking(False)
        sock.settimeout(CONNECTION_TEST_TIMEOUT_S)
        
        # Attempt to connect
        sock.connect(str(socket_path))
        
        # Connection succeeded - socket is in use
        logger.debug(
            "socket_connection_test",
            socket_path=str(socket_path),
            result="connected",
        )
        return True
        
    except socket.timeout:
        # Timeout - socket might be busy but responding slowly
        # Treat as in-use to be safe
        logger.debug(
            "socket_connection_test",
            socket_path=str(socket_path),
            result="timeout",
        )
        return True
        
    except ConnectionRefusedError:
        # Connection refused - no listener, socket is stale
        logger.debug(
            "socket_connection_test",
            socket_path=str(socket_path),
            result="refused",
        )
        return False
        
    except FileNotFoundError:
        # Socket file doesn't exist
        logger.debug(
            "socket_connection_test",
            socket_path=str(socket_path),
            result="not_found",
        )
        return False
        
    except OSError as e:
        # Other OS error - assume socket might be in use
        logger.debug(
            "socket_connection_test",
            socket_path=str(socket_path),
            result="os_error",
            error=str(e),
        )
        return True
        
    finally:
        if sock is not None:
            try:
                sock.close()
            except Exception:
                pass


def safe_remove_socket(socket_path: Path) -> bool:
    """
    Safely remove a socket file with proper error handling.
    
    Performs the following checks before removal:
    - Verifies the file is a socket (not a regular file or directory)
    - Handles race conditions where another process removes the file
    - Logs all operations for debugging
    
    Args:
        socket_path: Path to the socket file to remove
        
    Returns:
        True if socket was removed or didn't exist, False on error
        
    Note:
        This function is designed to be resilient to race conditions.
        If the file disappears between check and removal, it returns True.
    """
    try:
        # First verify it's a socket file
        if socket_path.exists() and not _is_unix_socket(socket_path):
            logger.warning(
                "safe_remove_aborted",
                socket_path=str(socket_path),
                reason="not_a_socket_file",
            )
            return False
        
        # Attempt to remove the socket file
        socket_path.unlink(missing_ok=True)
        
        logger.debug(
            "socket_removed",
            socket_path=str(socket_path),
        )
        return True
        
    except PermissionError as e:
        logger.warning(
            "socket_remove_permission_denied",
            socket_path=str(socket_path),
            error=str(e),
        )
        return False
        
    except OSError as e:
        # Handle race condition where file was removed by another process
        if not socket_path.exists():
            logger.debug(
                "socket_already_removed",
                socket_path=str(socket_path),
            )
            return True
        
        logger.warning(
            "socket_remove_error",
            socket_path=str(socket_path),
            error=str(e),
        )
        return False


# =============================================================================
# Private Helper Functions
# =============================================================================


def _validate_socket_path(socket_path_str: str) -> SocketValidationResult:
    """
    Validate a socket path for security concerns.
    
    Checks for:
    - Path traversal attempts (..)
    - Symlinks pointing outside expected directories
    - Invalid or dangerous paths
    
    Args:
        socket_path_str: The socket path string to validate
        
    Returns:
        SocketValidationResult with validation status
    """
    try:
        # Basic path checks
        if not socket_path_str:
            return SocketValidationResult(
                is_valid=False,
                error="Socket path cannot be empty",
            )
        
        # Check for obvious path traversal
        if ".." in socket_path_str:
            return SocketValidationResult(
                is_valid=False,
                error="Socket path contains path traversal sequence (..)",
            )
        
        # Convert to Path and resolve
        socket_path = Path(socket_path_str)
        
        # Don't resolve symlinks for the socket itself, but check parent
        parent_dir = socket_path.parent
        
        # Ensure parent directory exists
        if not parent_dir.exists():
            return SocketValidationResult(
                is_valid=False,
                error=f"Parent directory does not exist: {parent_dir}",
            )
        
        # Resolve parent to catch symlink escapes
        resolved_parent = parent_dir.resolve()
        
        # Check if parent is in expected directories (optional security check)
        # This is a soft check - we warn but don't fail for custom paths
        is_expected_dir = any(
            str(resolved_parent).startswith(expected)
            for expected in EXPECTED_SOCKET_DIRS
        )
        
        if not is_expected_dir:
            logger.debug(
                "socket_path_unusual_location",
                socket_path=str(socket_path),
                parent=str(resolved_parent),
                expected_dirs=EXPECTED_SOCKET_DIRS,
            )
        
        # Check if socket path itself is a symlink
        if socket_path.is_symlink():
            resolved_socket = socket_path.resolve()
            resolved_socket_parent = resolved_socket.parent
            
            # Verify symlink doesn't escape to unexpected directory
            symlink_in_expected = any(
                str(resolved_socket_parent).startswith(expected)
                for expected in EXPECTED_SOCKET_DIRS
            )
            
            if not symlink_in_expected:
                return SocketValidationResult(
                    is_valid=False,
                    error=f"Socket symlink points outside expected directories: {resolved_socket}",
                )
        
        # Construct the validated path
        validated_path = resolved_parent / socket_path.name
        
        return SocketValidationResult(
            is_valid=True,
            error=None,
            resolved_path=validated_path,
        )
        
    except Exception as e:
        return SocketValidationResult(
            is_valid=False,
            error=f"Path validation error: {e}",
        )


def _is_unix_socket(path: Path) -> bool:
    """
    Check if a path is a Unix domain socket file.
    
    Args:
        path: Path to check
        
    Returns:
        True if path is a Unix socket file
    """
    try:
        mode = path.stat().st_mode
        return stat.S_ISSOCK(mode)
    except (OSError, ValueError):
        return False


def _elapsed_ms(start_time: float) -> float:
    """
    Calculate elapsed time in milliseconds.
    
    Args:
        start_time: Start time from time.monotonic()
        
    Returns:
        Elapsed time in milliseconds
    """
    return (time.monotonic() - start_time) * 1000


# =============================================================================
# Module Initialization
# =============================================================================


def get_cleanup_info() -> dict:
    """
    Get information about the cleanup module configuration.
    
    Returns:
        Dictionary with cleanup configuration details
    """
    platform_info = detect_platform()
    
    return {
        "platform": platform_info.platform_name,
        "supports_ipc": platform_info.can_use_ipc,
        "cleanup_enabled": platform_info.can_use_ipc,
        "connection_timeout_ms": CONNECTION_TEST_TIMEOUT_S * 1000,
        "expected_socket_dirs": list(EXPECTED_SOCKET_DIRS),
    }


# Note: Function was renamed from test_socket_connection to check_socket_connection
# to avoid pytest collecting it as a test function