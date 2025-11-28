"""
Configuration module for AI Sidecar.

Uses pydantic-settings for type-safe configuration from environment variables
and YAML files. Supports hierarchical configuration with environment overrides.
"""

from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class ZMQConfig(BaseSettings):
    """ZeroMQ IPC configuration."""
    
    model_config = SettingsConfigDict(
        env_prefix="AI_ZMQ_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Socket endpoint - IPC for local, TCP for remote
    endpoint: str = Field(
        default="ipc:///tmp/openkore-ai.sock",
        description="ZeroMQ socket endpoint (ipc:// or tcp://)"
    )
    
    # Timeouts in milliseconds
    recv_timeout_ms: int = Field(
        default=50,
        ge=1,
        le=5000,
        description="Receive timeout in milliseconds"
    )
    send_timeout_ms: int = Field(
        default=50,
        ge=1,
        le=5000,
        description="Send timeout in milliseconds"
    )
    
    # Socket options
    linger_ms: int = Field(
        default=0,
        ge=0,
        description="Socket linger time in milliseconds"
    )
    high_water_mark: int = Field(
        default=1000,
        ge=1,
        description="High water mark for message buffering"
    )


class TickConfig(BaseSettings):
    """Tick processor configuration."""
    
    model_config = SettingsConfigDict(
        env_prefix="AI_TICK_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Tick timing
    interval_ms: int = Field(
        default=100,
        ge=10,
        le=1000,
        description="AI tick interval in milliseconds"
    )
    max_processing_ms: int = Field(
        default=80,
        ge=5,
        le=500,
        description="Maximum time for processing a tick"
    )
    
    # State management
    state_history_size: int = Field(
        default=100,
        ge=10,
        le=10000,
        description="Number of historical states to retain"
    )


class LoggingConfig(BaseSettings):
    """Logging configuration."""
    
    model_config = SettingsConfigDict(
        env_prefix="AI_LOG_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        default="INFO",
        description="Logging level"
    )
    format: Literal["json", "console", "text"] = Field(
        default="console",
        description="Log output format"
    )
    file_path: str | None = Field(
        default=None,
        description="Optional log file path"
    )
    include_timestamp: bool = Field(
        default=True,
        description="Include timestamp in log entries"
    )
    include_caller: bool = Field(
        default=False,
        description="Include caller info in log entries"
    )


class DecisionConfig(BaseSettings):
    """Decision engine configuration."""
    
    model_config = SettingsConfigDict(
        env_prefix="AI_DECISION_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Fallback behavior
    fallback_mode: Literal["cpu", "idle", "defensive"] = Field(
        default="cpu",
        description="Fallback mode when AI sidecar unavailable"
    )
    
    # Decision limits
    max_actions_per_tick: int = Field(
        default=5,
        ge=1,
        le=20,
        description="Maximum actions per decision tick"
    )
    
    # Engine type (stub for now, will be expanded)
    engine_type: Literal["stub", "rule_based", "ml"] = Field(
        default="stub",
        description="Type of decision engine to use"
    )


class Settings(BaseSettings):
    """Main application settings aggregating all configuration sections."""
    
    model_config = SettingsConfigDict(
        env_prefix="AI_",
        env_file=".env",
        env_file_encoding="utf-8",
        env_nested_delimiter="__",
        extra="ignore",
    )
    
    # Application info
    app_name: str = Field(
        default="AI-Sidecar",
        description="Application name"
    )
    debug: bool = Field(
        default=False,
        description="Enable debug mode"
    )
    
    # Sub-configurations
    zmq: ZMQConfig = Field(default_factory=ZMQConfig)
    tick: TickConfig = Field(default_factory=TickConfig)
    logging: LoggingConfig = Field(default_factory=LoggingConfig)
    decision: DecisionConfig = Field(default_factory=DecisionConfig)
    
    # Health check
    health_check_interval_s: float = Field(
        default=5.0,
        ge=1.0,
        le=60.0,
        description="Health check interval in seconds"
    )
    
    @field_validator("debug", mode="before")
    @classmethod
    def parse_debug(cls, v: Any) -> bool:
        """Parse debug flag from various formats."""
        if isinstance(v, bool):
            return v
        if isinstance(v, str):
            return v.lower() in ("true", "1", "yes", "on")
        return bool(v)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """
    Get cached application settings.
    
    Uses lru_cache to ensure settings are loaded only once per process.
    Call get_settings.cache_clear() to reload settings if needed.
    
    Returns:
        Settings: The application settings instance
    """
    return Settings()


def get_config_summary() -> dict[str, Any]:
    """
    Get a summary of current configuration (safe for logging).
    
    Excludes any sensitive values that might be present.
    
    Returns:
        dict: Configuration summary
    """
    settings = get_settings()
    return {
        "app_name": settings.app_name,
        "debug": settings.debug,
        "zmq_endpoint": settings.zmq.endpoint,
        "tick_interval_ms": settings.tick.interval_ms,
        "log_level": settings.logging.level,
        "decision_engine": settings.decision.engine_type,
        "fallback_mode": settings.decision.fallback_mode,
    }