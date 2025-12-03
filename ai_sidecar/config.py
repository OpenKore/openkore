"""
Configuration module for AI Sidecar.

Uses pydantic-settings for type-safe configuration from environment variables
and YAML files. Supports hierarchical configuration with environment overrides.

Features:
- Type-safe configuration with Pydantic v2
- Environment variable overrides
- Helpful validation error messages
- Sensible defaults for new users
"""

from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

from pydantic import Field, field_validator, model_validator, ValidationError
from pydantic_settings import BaseSettings, SettingsConfigDict


# =============================================================================
# Constants for helpful defaults
# =============================================================================

# Default endpoints for different platforms
DEFAULT_ZMQ_ENDPOINT_UNIX = "ipc:///tmp/openkore-ai.sock"
DEFAULT_ZMQ_ENDPOINT_WINDOWS = "tcp://127.0.0.1:5555"
DEFAULT_ZMQ_ENDPOINT = DEFAULT_ZMQ_ENDPOINT_UNIX

# Recommended tick interval (10 ticks/second)
RECOMMENDED_TICK_MS = 100

# Log levels in order of verbosity
LOG_LEVELS = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]


class ZMQConfig(BaseSettings):
    """
    ZeroMQ IPC configuration.
    
    Controls communication between AI Sidecar and OpenKore.
    
    Quick Start:
        - For local (same machine): use ipc:// endpoint
        - For remote: use tcp:// endpoint
    
    Environment Variables:
        AI_ZMQ_ENDPOINT: Socket address
        AI_ZMQ_RECV_TIMEOUT_MS: Receive timeout
        AI_ZMQ_SEND_TIMEOUT_MS: Send timeout
    """
    
    model_config = SettingsConfigDict(
        env_prefix="AI_ZMQ_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Socket endpoint - IPC for local, TCP for remote
    endpoint: str = Field(
        default=DEFAULT_ZMQ_ENDPOINT,
        description="ZeroMQ socket endpoint. Use 'ipc://' for local, 'tcp://' for remote.",
        examples=["ipc:///tmp/openkore-ai.sock", "tcp://127.0.0.1:5555"],
    )
    
    # Timeouts in milliseconds
    recv_timeout_ms: int = Field(
        default=100,  # Increased from 50ms for better reliability
        ge=10,
        le=5000,
        description="Receive timeout in milliseconds. Increase if you see timeout errors.",
    )
    send_timeout_ms: int = Field(
        default=100,  # Increased from 50ms for better reliability
        ge=10,
        le=5000,
        description="Send timeout in milliseconds. Increase if you see timeout errors.",
    )
    
    # Socket options
    linger_ms: int = Field(
        default=0,
        ge=0,
        description="Socket linger time (ms). 0 = close immediately.",
    )
    high_water_mark: int = Field(
        default=1000,
        ge=1,
        le=100000,
        description="Message queue size before dropping. Increase for high-load scenarios.",
    )
    
    @field_validator("endpoint", mode="before")
    @classmethod
    def validate_endpoint(cls, v: str) -> str:
        """Validate ZMQ endpoint format."""
        v = str(v).strip()
        
        if not v:
            raise ValueError(
                "Endpoint cannot be empty. "
                f"Use '{DEFAULT_ZMQ_ENDPOINT}' for local or 'tcp://host:port' for remote."
            )
        
        valid_prefixes = ("ipc://", "tcp://", "inproc://")
        if not any(v.startswith(p) for p in valid_prefixes):
            raise ValueError(
                f"Invalid endpoint format: '{v}'. "
                f"Must start with one of: {', '.join(valid_prefixes)}. "
                f"Example: 'tcp://127.0.0.1:5555' or 'ipc:///tmp/openkore-ai.sock'"
            )
        
        if v.startswith("tcp://"):
            # Validate TCP endpoint has host:port
            addr = v[6:]  # Remove tcp://
            if ":" not in addr:
                raise ValueError(
                    f"TCP endpoint '{v}' must include port. "
                    "Example: 'tcp://127.0.0.1:5555'"
                )
        
        return v


class TickConfig(BaseSettings):
    """
    Tick processor configuration.
    
    Controls how often the AI makes decisions and how much history to keep.
    
    Performance Tips:
        - 100ms (10 ticks/sec) is good balance of responsiveness and CPU
        - Lower values = more responsive but higher CPU
        - Higher values = less CPU but slower reactions
    
    Environment Variables:
        AI_TICK_INTERVAL_MS: Decision interval
        AI_TICK_MAX_PROCESSING_MS: Max time per decision
        AI_TICK_STATE_HISTORY_SIZE: States to remember
    """
    
    model_config = SettingsConfigDict(
        env_prefix="AI_TICK_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Tick timing
    interval_ms: int = Field(
        default=RECOMMENDED_TICK_MS,
        ge=10,
        le=1000,
        description="AI decision interval (ms). 100ms = 10 decisions/sec.",
    )
    max_processing_ms: int = Field(
        default=80,
        ge=5,
        le=500,
        description="Max time to make a decision. Must be < interval_ms.",
    )
    
    # State management
    state_history_size: int = Field(
        default=100,
        ge=10,
        le=10000,
        description="Number of past states to remember. Higher = more memory.",
    )
    
    @model_validator(mode="after")
    def validate_timing(self) -> "TickConfig":
        """Ensure max_processing_ms is less than interval_ms."""
        if self.max_processing_ms >= self.interval_ms:
            raise ValueError(
                f"max_processing_ms ({self.max_processing_ms}) must be less than "
                f"interval_ms ({self.interval_ms}). "
                f"Recommended: max_processing_ms = {int(self.interval_ms * 0.8)}"
            )
        return self


class LoggingConfig(BaseSettings):
    """
    Logging configuration.
    
    Controls log output format and verbosity.
    
    Log Levels (from most to least verbose):
        DEBUG: Everything, including internal state
        INFO: Normal operation (recommended)
        WARNING: Potential issues
        ERROR: Errors that don't stop operation
        CRITICAL: Fatal errors
    
    Environment Variables:
        AI_LOG_LEVEL: Verbosity level
        AI_LOG_FORMAT: Output format (json/console/text)
        AI_LOG_FILE_PATH: Write logs to file
    """
    
    model_config = SettingsConfigDict(
        env_prefix="AI_LOG_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        default="INFO",
        description="Log verbosity. DEBUG for troubleshooting, INFO for normal use.",
    )
    format: Literal["json", "console", "text"] = Field(
        default="console",
        description="Output format. 'console' for humans, 'json' for log aggregators.",
    )
    file_path: str | None = Field(
        default=None,
        description="Log file path. Leave empty for stdout only.",
        examples=["logs/ai_sidecar.log", "/var/log/ai_sidecar.log"],
    )
    include_timestamp: bool = Field(
        default=True,
        description="Include timestamp in logs. Recommended for production.",
    )
    include_caller: bool = Field(
        default=False,
        description="Include file:line in logs. Useful for debugging.",
    )
    
    @field_validator("level", mode="before")
    @classmethod
    def normalize_level(cls, v: str) -> str:
        """Normalize log level to uppercase."""
        if isinstance(v, str):
            v = v.upper().strip()
            if v not in LOG_LEVELS:
                valid = ", ".join(LOG_LEVELS)
                raise ValueError(
                    f"Invalid log level '{v}'. Valid levels: {valid}. "
                    "Recommended: INFO for production, DEBUG for troubleshooting."
                )
        return v


class DecisionConfig(BaseSettings):
    """
    Decision engine configuration.
    
    Controls how the AI makes decisions and what to do when ML is unavailable.
    
    Engine Types:
        stub: Returns empty decisions (for testing)
        rule_based: Uses CPU-only rule system
        ml: Uses machine learning (requires GPU or good CPU)
    
    Fallback Modes (when ML unavailable):
        cpu: Use rule-based AI (recommended)
        idle: Do nothing (safe but not useful)
        defensive: Only defensive actions (safe option)
    
    Environment Variables:
        AI_DECISION_ENGINE_TYPE: Which AI to use
        AI_DECISION_FALLBACK_MODE: Backup behavior
    """
    
    model_config = SettingsConfigDict(
        env_prefix="AI_DECISION_",
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )
    
    # Fallback behavior
    fallback_mode: Literal["cpu", "idle", "defensive"] = Field(
        default="cpu",
        description="Behavior when ML unavailable. 'cpu' uses rule-based AI.",
    )
    
    # Decision limits
    max_actions_per_tick: int = Field(
        default=5,
        ge=1,
        le=20,
        description="Max actions per decision. Higher = more aggressive but may look bot-like.",
    )
    
    # Engine type
    engine_type: Literal["stub", "rule_based", "ml"] = Field(
        default="rule_based",  # Changed from stub to rule_based for better defaults
        description="AI engine type. Start with 'rule_based', upgrade to 'ml' when ready.",
    )
    
    # Confidence threshold
    min_confidence: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Minimum confidence to act. Lower = more actions but more mistakes.",
    )
    
    @field_validator("fallback_mode", mode="before")
    @classmethod
    def validate_fallback_mode(cls, v: str) -> str:
        """Validate and normalize fallback mode."""
        if isinstance(v, str):
            v = v.lower().strip()
            valid_modes = ["cpu", "idle", "defensive"]
            if v not in valid_modes:
                raise ValueError(
                    f"Invalid fallback mode '{v}'. "
                    f"Valid modes: {', '.join(valid_modes)}. "
                    "Recommended: 'cpu' for best experience."
                )
        return v


class Settings(BaseSettings):
    """
    Main application settings aggregating all configuration sections.
    
    This is the root configuration object that combines all subsystems.
    
    Quick Start:
        1. Copy .env.example to .env
        2. Edit values as needed
        3. Run the sidecar
    
    Configuration Precedence (highest to lowest):
        1. Environment variables (AI_*)
        2. .env file
        3. config.yaml
        4. Default values
    
    Environment Variables:
        AI_DEBUG: Enable debug mode (true/false)
        AI_HEALTH_CHECK_INTERVAL_S: Health check frequency
    """
    
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
        description="Application name for logging and identification.",
    )
    debug: bool = Field(
        default=False,
        description="Enable debug mode. Increases logging and enables dev features.",
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
        description="Seconds between health checks. Lower = faster detection, more CPU.",
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
    
    @model_validator(mode="after")
    def apply_debug_defaults(self) -> "Settings":
        """Apply debug mode defaults when enabled."""
        if self.debug:
            # In debug mode, use DEBUG log level unless explicitly set
            # This is handled at runtime in setup_logging
            pass
        return self


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """
    Get cached application settings.
    
    Uses lru_cache to ensure settings are loaded only once per process.
    Call get_settings.cache_clear() to reload settings if needed.
    
    Returns:
        Settings: The application settings instance
        
    Raises:
        ConfigurationError: If configuration is invalid
        
    Example:
        >>> settings = get_settings()
        >>> print(settings.zmq.endpoint)
        'ipc:///tmp/openkore-ai.sock'
    """
    try:
        return Settings()
    except ValidationError as e:
        # Import here to avoid circular imports
        from ai_sidecar.utils.errors import format_validation_errors
        
        error_msg = format_validation_errors(e.errors())
        print(error_msg)
        raise


def get_config_summary() -> dict[str, Any]:
    """
    Get a summary of current configuration (safe for logging).
    
    Excludes any sensitive values that might be present.
    
    Returns:
        dict: Configuration summary with key settings
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
        "health_check_interval_s": settings.health_check_interval_s,
    }


def validate_config() -> tuple[bool, list[str]]:
    """
    Validate configuration and return status with any issues.
    
    Returns:
        Tuple of (is_valid, list_of_issues)
        
    Example:
        >>> valid, issues = validate_config()
        >>> if not valid:
        ...     for issue in issues:
        ...         print(f"⚠️ {issue}")
    """
    issues: list[str] = []
    
    try:
        settings = get_settings()
        
        # Check for potential issues even if valid
        if settings.tick.interval_ms < 50:
            issues.append(
                f"Tick interval ({settings.tick.interval_ms}ms) is very low. "
                "May cause high CPU usage."
            )
        
        if settings.tick.interval_ms > 500:
            issues.append(
                f"Tick interval ({settings.tick.interval_ms}ms) is high. "
                "Bot may react slowly to threats."
            )
        
        if settings.decision.engine_type == "stub":
            issues.append(
                "Decision engine is 'stub'. "
                "Bot won't take any actions. Change to 'rule_based' or 'ml'."
            )
        
        if settings.zmq.endpoint.startswith("tcp://0.0.0.0"):
            issues.append(
                "ZMQ endpoint binds to 0.0.0.0. "
                "This allows connections from any network. Use 127.0.0.1 for local only."
            )
        
        return True, issues
        
    except Exception as e:
        return False, [str(e)]


def print_config_help() -> None:
    """Print configuration help for users."""
    help_text = """
╔══════════════════════════════════════════════════════════════╗
║               AI Sidecar Configuration Help                  ║
╚══════════════════════════════════════════════════════════════╝

📋 Quick Start:
   1. Copy .env.example to .env
   2. Edit the values you need to change
   3. Most defaults work well for beginners

🔧 Key Settings:

   ZMQ_ENDPOINT: How OpenKore connects to AI Sidecar
   • Local: ipc:///tmp/openkore-ai.sock (Unix/Mac)
   • Local: tcp://127.0.0.1:5555 (Windows or remote)

   TICK_INTERVAL_MS: How often AI makes decisions
   • 100ms: Balanced (recommended)
   • 50ms: Fast reactions, higher CPU
   • 200ms: Lower CPU, slower reactions

   DECISION_ENGINE_TYPE: Which AI to use
   • rule_based: Works on any hardware (recommended start)
   • ml: Machine learning (needs good CPU/GPU)
   • stub: Does nothing (testing only)

   LOG_LEVEL: How much logging to show
   • INFO: Normal operation
   • DEBUG: Troubleshooting
   • WARNING: Only problems

📁 Configuration Files:
   • .env: Environment variables (highest priority)
   • config.yaml: Default configuration

📚 Documentation:
   https://github.com/openkore/openkore-ai/docs/configuration.md
"""
    print(help_text)