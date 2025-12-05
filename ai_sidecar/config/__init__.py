"""Configuration management for AI Sidecar."""

from .loader import SubsystemConfig, get_config, reset_config

# Import get_settings from parent module (ai_sidecar.config not ai_sidecar.config package)
# Use relative import to avoid circular import
import sys
import importlib.util
from pathlib import Path

# Get the parent config.py file path
config_file = Path(__file__).parent.parent / "config.py"

# Load it as a module
spec = importlib.util.spec_from_file_location("_ai_sidecar_config", config_file)
_config_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(_config_module)

# Import all needed items from the loaded module
get_settings = _config_module.get_settings
Settings = _config_module.Settings
TickConfig = _config_module.TickConfig
ZMQConfig = _config_module.ZMQConfig
DecisionConfig = _config_module.DecisionConfig
LoggingConfig = _config_module.LoggingConfig
get_config_summary = _config_module.get_config_summary
validate_config = _config_module.validate_config
print_config_help = _config_module.print_config_help

__all__ = [
    "SubsystemConfig",
    "get_config",
    "reset_config",
    "get_settings",
    "Settings",
    "TickConfig",
    "ZMQConfig",
    "DecisionConfig",
    "LoggingConfig",
    "get_config_summary",
    "validate_config",
    "print_config_help",
]