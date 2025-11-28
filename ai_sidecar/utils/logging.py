"""
Structured logging module for AI Sidecar.

Uses structlog for structured, context-rich logging with support for
JSON output (production) and colored console output (development).
"""

import logging
import sys
from functools import lru_cache
from typing import Any

import structlog
from structlog.types import Processor

from ai_sidecar.config import get_settings, LoggingConfig


def _add_app_context(
    logger: logging.Logger, method_name: str, event_dict: dict[str, Any]
) -> dict[str, Any]:
    """Add application context to log entries."""
    settings = get_settings()
    event_dict["app"] = settings.app_name
    return event_dict


def _get_log_level(config: LoggingConfig) -> int:
    """Convert string log level to logging constant."""
    level_map = {
        "DEBUG": logging.DEBUG,
        "INFO": logging.INFO,
        "WARNING": logging.WARNING,
        "ERROR": logging.ERROR,
        "CRITICAL": logging.CRITICAL,
    }
    return level_map.get(config.level, logging.INFO)


def _build_processors(config: LoggingConfig) -> list[Processor]:
    """Build the processor chain based on configuration."""
    processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        _add_app_context,
    ]
    
    if config.include_timestamp:
        processors.append(structlog.processors.TimeStamper(fmt="iso"))
    
    if config.include_caller:
        processors.append(structlog.processors.CallsiteParameterAdder(
            parameters=[
                structlog.processors.CallsiteParameter.FILENAME,
                structlog.processors.CallsiteParameter.LINENO,
                structlog.processors.CallsiteParameter.FUNC_NAME,
            ]
        ))
    
    processors.append(structlog.processors.StackInfoRenderer())
    processors.append(structlog.processors.UnicodeDecoder())
    
    return processors


def _get_renderer(config: LoggingConfig) -> Processor:
    """Get the appropriate renderer based on format configuration."""
    if config.format == "json":
        return structlog.processors.JSONRenderer()
    elif config.format == "console":
        return structlog.dev.ConsoleRenderer(
            colors=True,
            exception_formatter=structlog.dev.plain_traceback,
        )
    else:  # text
        return structlog.processors.KeyValueRenderer(
            key_order=["timestamp", "level", "event"],
        )


def setup_logging() -> None:
    """
    Configure structlog and stdlib logging based on application settings.
    
    Should be called once at application startup.
    """
    config = get_settings().logging
    log_level = _get_log_level(config)
    
    # Build processor chain
    processors = _build_processors(config)
    
    # Configure structlog
    structlog.configure(
        processors=processors + [
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    # Configure stdlib logging
    formatter = structlog.stdlib.ProcessorFormatter(
        foreign_pre_chain=processors,
        processors=[
            structlog.stdlib.ProcessorFormatter.remove_processors_meta,
            _get_renderer(config),
        ],
    )
    
    # Setup handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)
    
    # Configure root logger
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(log_level)
    
    # Add file handler if configured
    if config.file_path:
        file_handler = logging.FileHandler(config.file_path)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
    
    # Silence noisy loggers
    for logger_name in ["asyncio", "zmq"]:
        logging.getLogger(logger_name).setLevel(logging.WARNING)


@lru_cache(maxsize=128)
def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """
    Get a configured structlog logger.
    
    Args:
        name: Logger name. If None, uses the calling module's name.
    
    Returns:
        A bound structlog logger instance.
    
    Example:
        >>> logger = get_logger(__name__)
        >>> logger.info("processing tick", tick=12345, actors=42)
    """
    return structlog.get_logger(name)


def bind_context(**kwargs: Any) -> None:
    """
    Bind context variables that will be included in all subsequent log calls.
    
    Useful for adding request-specific or tick-specific context.
    
    Args:
        **kwargs: Key-value pairs to bind to the logging context.
    
    Example:
        >>> bind_context(tick=12345, character="MyChar")
        >>> logger.info("processing")  # Will include tick and character
    """
    structlog.contextvars.bind_contextvars(**kwargs)


def clear_context() -> None:
    """Clear all bound context variables."""
    structlog.contextvars.clear_contextvars()


def unbind_context(*keys: str) -> None:
    """
    Remove specific keys from the bound context.
    
    Args:
        *keys: Keys to remove from context.
    """
    structlog.contextvars.unbind_contextvars(*keys)