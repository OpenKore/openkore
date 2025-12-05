"""Configuration loader for AI Sidecar subsystems."""

import yaml
from pathlib import Path
from typing import Dict, Any, List
import structlog

logger = structlog.get_logger()


class SubsystemConfig:
    """Manages AI Sidecar subsystem configuration."""
    
    def __init__(self, config_path: str = None):
        """
        Initialize subsystem configuration.
        
        Args:
            config_path: Path to subsystems.yaml file. If None, uses default location.
        """
        if config_path is None:
            config_path = Path(__file__).parent / "subsystems.yaml"
        
        self.config_path = Path(config_path)
        self.config = self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """
        Load configuration from YAML file.
        
        Returns:
            Dict containing configuration data
        """
        if not self.config_path.exists():
            logger.warning(
                "Config file not found, using defaults",
                path=str(self.config_path)
            )
            return self._get_default_config()
        
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
                logger.info(
                    "Loaded subsystem configuration",
                    path=str(self.config_path),
                    subsystems=len(config.get('subsystems', {}))
                )
                return config
        except Exception as e:
            logger.error(
                "Failed to load config, using defaults",
                error=str(e),
                path=str(self.config_path)
            )
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """
        Get default configuration (all enabled).
        
        Returns:
            Dict with all subsystems enabled
        """
        return {
            "subsystems": {
                "core": {"enabled": True},
                "social": {"enabled": True},
                "progression": {"enabled": True},
                "combat": {"enabled": True},
                "companions": {"enabled": True},
                "consumables": {"enabled": True},
                "equipment": {"enabled": True},
                "economy": {"enabled": True},
                "npc_quest": {"enabled": True},
                "instances": {"enabled": True},
                "environment": {"enabled": True},
            }
        }
    
    def is_enabled(self, subsystem: str) -> bool:
        """
        Check if subsystem is enabled.
        
        Args:
            subsystem: Name of the subsystem to check
        
        Returns:
            True if enabled, False otherwise (defaults to True)
        """
        subsystems = self.config.get("subsystems", {})
        subsystem_config = subsystems.get(subsystem, {})
        # Default to enabled if not specified
        return subsystem_config.get("enabled", True)
    
    def is_feature_enabled(self, subsystem: str, feature: str) -> bool:
        """
        Check if specific feature within a subsystem is enabled.
        
        Args:
            subsystem: Name of the subsystem
            feature: Name of the feature within the subsystem
        
        Returns:
            True if both subsystem and feature are enabled
        """
        # If subsystem is disabled, all features are disabled
        if not self.is_enabled(subsystem):
            return False
        
        subsystems = self.config.get("subsystems", {})
        subsystem_config = subsystems.get(subsystem, {})
        features = subsystem_config.get("features", {})
        
        # Default to enabled if not specified
        return features.get(feature, True)
    
    def get_enabled_subsystems(self) -> List[str]:
        """
        Get list of enabled subsystems.
        
        Returns:
            List of subsystem names that are enabled
        """
        subsystems = self.config.get("subsystems", {})
        return [
            name for name, config in subsystems.items()
            if config.get("enabled", True)
        ]
    
    def get_subsystem_description(self, subsystem: str) -> str:
        """
        Get description for a subsystem.
        
        Args:
            subsystem: Name of the subsystem
        
        Returns:
            Description string or empty string if not found
        """
        subsystems = self.config.get("subsystems", {})
        subsystem_config = subsystems.get(subsystem, {})
        return subsystem_config.get("description", "")
    
    def apply_preset(self, preset_name: str) -> None:
        """
        Apply a configuration preset.
        
        Args:
            preset_name: Name of the preset to apply
        """
        presets = self.config.get("presets", {})
        preset = presets.get(preset_name)
        
        if not preset:
            logger.warning(f"Preset not found: {preset_name}")
            return
        
        # If enable_all is set, enable everything
        if preset.get("enable_all", False):
            for subsystem in self.config["subsystems"]:
                self.config["subsystems"][subsystem]["enabled"] = True
            logger.info(f"Applied preset: {preset_name} (all enabled)")
            return
        
        # Otherwise, disable all first, then enable specified ones
        for subsystem in self.config["subsystems"]:
            self.config["subsystems"][subsystem]["enabled"] = False
        
        # Enable specified subsystems
        if "enable" in preset:
            for subsystem in preset["enable"]:
                if subsystem in self.config["subsystems"]:
                    self.config["subsystems"][subsystem]["enabled"] = True
        
        logger.info(
            f"Applied preset: {preset_name}",
            enabled=preset.get("enable", [])
        )
    
    def get_config_summary(self) -> Dict[str, Any]:
        """
        Get summary of current configuration.
        
        Returns:
            Dict with configuration summary
        """
        enabled_subsystems = self.get_enabled_subsystems()
        
        summary = {
            "total_subsystems": len(self.config.get("subsystems", {})),
            "enabled_subsystems": len(enabled_subsystems),
            "disabled_subsystems": len(self.config.get("subsystems", {})) - len(enabled_subsystems),
            "subsystems": {}
        }
        
        for name in self.config.get("subsystems", {}).keys():
            subsystem_config = self.config["subsystems"][name]
            summary["subsystems"][name] = {
                "enabled": subsystem_config.get("enabled", True),
                "description": subsystem_config.get("description", ""),
                "features": subsystem_config.get("features", {})
            }
        
        return summary
    
    def reload(self) -> None:
        """Reload configuration from file."""
        self.config = self._load_config()
        logger.info("Configuration reloaded")


# Global config instance
_config: SubsystemConfig = None


def get_config() -> SubsystemConfig:
    """
    Get global configuration instance (singleton pattern).
    
    Returns:
        SubsystemConfig instance
    """
    global _config
    if _config is None:
        _config = SubsystemConfig()
    return _config


def reset_config() -> None:
    """Reset global configuration (useful for testing)."""
    global _config
    _config = None