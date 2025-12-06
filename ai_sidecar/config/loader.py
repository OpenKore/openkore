"""Configuration loader for AI Sidecar subsystems and externalized values."""

import os
import time
import threading
from pathlib import Path
from typing import Dict, Any, List, Optional, Set, Callable

import yaml
import structlog

logger = structlog.get_logger()


# =============================================================================
# CONFIGURATION FILE PATHS
# =============================================================================
CONFIG_DIR = Path(__file__).parent
CHAT_ABBREVIATIONS_FILE = CONFIG_DIR / "chat_abbreviations.yml"
CONSUMABLE_ITEMS_FILE = CONFIG_DIR / "consumable_items.yml"
JOB_CLASSES_FILE = CONFIG_DIR / "job_classes.yml"
CARD_VALUES_FILE = CONFIG_DIR / "card_values.yml"
SUBSYSTEMS_FILE = CONFIG_DIR / "subsystems.yaml"


# =============================================================================
# BASE CONFIGURATION LOADER
# =============================================================================

class ConfigurationError(Exception):
    """Raised when configuration loading or validation fails."""
    pass


class BaseConfigLoader:
    """Base class for configuration loaders with caching and hot-reload."""
    
    def __init__(self, config_path: Path, auto_reload: bool = False):
        """
        Initialize base config loader.
        
        Args:
            config_path: Path to the configuration file
            auto_reload: Enable automatic reloading on file changes
        """
        self.config_path = config_path
        self.config: Dict[str, Any] = {}
        self._last_modified: float = 0.0
        self._auto_reload = auto_reload
        self._lock = threading.RLock()
        self._reload_callbacks: List[Callable[[], None]] = []
        
        # Initial load
        self._load_config()
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from YAML file."""
        with self._lock:
            if not self.config_path.exists():
                logger.warning(
                    "config_file_not_found",
                    path=str(self.config_path),
                    using="defaults"
                )
                self.config = self._get_defaults()
                return self.config
            
            try:
                file_mtime = os.path.getmtime(self.config_path)
                
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    self.config = yaml.safe_load(f) or {}
                
                self._last_modified = file_mtime
                
                # Validate the loaded config
                self._validate_config()
                
                logger.info(
                    "config_loaded",
                    path=str(self.config_path),
                    version=self.config.get("version", "unknown")
                )
                
                return self.config
                
            except yaml.YAMLError as e:
                logger.error(
                    "config_yaml_parse_error",
                    path=str(self.config_path),
                    error=str(e)
                )
                self.config = self._get_defaults()
                return self.config
                
            except Exception as e:
                logger.error(
                    "config_load_error",
                    path=str(self.config_path),
                    error=str(e)
                )
                self.config = self._get_defaults()
                return self.config
    
    def _get_defaults(self) -> Dict[str, Any]:
        """Get default configuration. Override in subclasses."""
        return {}
    
    def _validate_config(self) -> None:
        """Validate loaded configuration. Override in subclasses."""
        pass
    
    def reload(self) -> bool:
        """
        Reload configuration from file.
        
        Returns:
            True if config was reloaded, False if unchanged
        """
        if not self.config_path.exists():
            return False
        
        try:
            file_mtime = os.path.getmtime(self.config_path)
            
            if file_mtime > self._last_modified:
                self._load_config()
                
                # Notify callbacks
                for callback in self._reload_callbacks:
                    try:
                        callback()
                    except Exception as e:
                        logger.error("reload_callback_error", error=str(e))
                
                logger.info("config_reloaded", path=str(self.config_path))
                return True
                
        except Exception as e:
            logger.error("config_reload_check_error", error=str(e))
        
        return False
    
    def check_and_reload(self) -> bool:
        """Check if file changed and reload if needed."""
        if self._auto_reload:
            return self.reload()
        return False
    
    def register_reload_callback(self, callback: Callable[[], None]) -> None:
        """Register a callback to be called when config is reloaded."""
        self._reload_callbacks.append(callback)
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get a configuration value."""
        self.check_and_reload()
        return self.config.get(key, default)


# =============================================================================
# CHAT ABBREVIATIONS CONFIGURATION
# =============================================================================

class ChatAbbreviationsConfig(BaseConfigLoader):
    """Configuration for chat text abbreviations and typo patterns."""
    
    def __init__(self, config_path: Path = None, auto_reload: bool = True):
        super().__init__(config_path or CHAT_ABBREVIATIONS_FILE, auto_reload)
    
    def _get_defaults(self) -> Dict[str, Any]:
        """Default abbreviations if config file is missing."""
        return {
            "version": "1.0.0",
            "abbreviations": {
                "please": "pls", "thanks": "thx", "okay": "ok", "because": "cuz",
                "you": "u", "are": "r", "before": "b4", "later": "l8r",
                "tonight": "2nite", "tomorrow": "tmrw", "awesome": "awesom",
                "nothing": "nothin", "something": "somethin"
            },
            "typo_patterns": {
                "adjacent_keys": {
                    "a": ["s", "q", "w", "z"], "s": ["a", "d", "w", "x", "z"],
                    "d": ["s", "f", "e", "r", "c", "x"], "e": ["w", "r", "d", "f"],
                    "r": ["e", "t", "f", "g"], "t": ["r", "y", "g", "h"],
                    "o": ["i", "p", "k", "l"], "p": ["o", "l"]
                },
                "common_typos": {
                    "the": ["teh", "hte"], "and": ["adn", "nad"],
                    "that": ["taht", "htat"], "what": ["waht", "hwat"]
                }
            },
            "emoticons": {
                "happy": [":)", "^^", ":D", "=)"],
                "sad": [":(", "T_T", ";_;"],
                "laugh": ["lol", "haha", "xD", "rofl"],
                "love": ["<3", "♥"],
                "confused": ["???", "?", "o.O"],
                "surprised": ["!", "!!", "o_o", "O_O"],
                "angry": [">:(", "DX"],
                "neutral": [".", "..."]
            },
            "settings": {
                "abbreviation_chance": 0.7,
                "typo_chance": 0.02,
                "emoticon_chance": 0.4,
                "min_typo_length": 3,
                "max_typos_per_message": 2
            }
        }
    
    def _validate_config(self) -> None:
        """Validate abbreviations configuration."""
        if "abbreviations" not in self.config:
            logger.warning("chat_config_missing_abbreviations")
            self.config["abbreviations"] = self._get_defaults()["abbreviations"]
        
        if "typo_patterns" not in self.config:
            logger.warning("chat_config_missing_typo_patterns")
            self.config["typo_patterns"] = self._get_defaults()["typo_patterns"]
    
    @property
    def abbreviations(self) -> Dict[str, str]:
        """Get abbreviation mappings."""
        self.check_and_reload()
        return self.config.get("abbreviations", {})
    
    @property
    def typo_patterns(self) -> Dict[str, Any]:
        """Get typo pattern definitions."""
        self.check_and_reload()
        return self.config.get("typo_patterns", {})
    
    @property
    def emoticons(self) -> Dict[str, List[str]]:
        """Get emoticon mappings."""
        self.check_and_reload()
        return self.config.get("emoticons", {})
    
    @property
    def settings(self) -> Dict[str, Any]:
        """Get chat settings."""
        self.check_and_reload()
        return self.config.get("settings", {})


# =============================================================================
# CONSUMABLE ITEMS CONFIGURATION
# =============================================================================

class ConsumableItemsConfig(BaseConfigLoader):
    """Configuration for consumable item inventory management."""
    
    def __init__(self, config_path: Path = None, auto_reload: bool = True):
        super().__init__(config_path or CONSUMABLE_ITEMS_FILE, auto_reload)
        self._consumables_by_id: Dict[int, Dict[str, Any]] = {}
        self._build_id_index()
    
    def _get_defaults(self) -> Dict[str, Any]:
        """Default consumables if config file is missing."""
        return {
            "version": "1.0.0",
            "consumables": [
                {"item_id": 501, "name": "Red Potion", "min_count": 100, "max_count": 200, "priority": 70, "npc_purchasable": True},
                {"item_id": 502, "name": "Orange Potion", "min_count": 50, "max_count": 100, "priority": 60, "npc_purchasable": True},
                {"item_id": 503, "name": "Yellow Potion", "min_count": 30, "max_count": 80, "priority": 50, "npc_purchasable": True},
                {"item_id": 1750, "name": "Arrow", "min_count": 500, "max_count": 2000, "priority": 80, "npc_purchasable": True},
            ],
            "settings": {
                "auto_restock_enabled": True,
                "max_weight_for_restock": 50,
                "min_zeny_for_restock": 10000,
                "max_items_per_trip": 10,
                "min_priority_threshold": 40,
                "check_interval_ticks": 100,
                "deposit_before_restock": True,
                "protected_items": [501, 502, 503, 504, 505, 601, 602, 1750]
            },
            "category_priorities": {
                "healing": 70,
                "mana": 55,
                "ammunition": 80,
                "cure": 45,
                "buffs": 50,
                "utility": 65,
                "misc": 30
            }
        }
    
    def _validate_config(self) -> None:
        """Validate consumables configuration."""
        consumables = self.config.get("consumables", [])
        
        for item in consumables:
            if "item_id" not in item:
                logger.warning("consumable_missing_item_id", item=item)
            if "min_count" not in item:
                item["min_count"] = 50
            if "priority" not in item:
                item["priority"] = 50
    
    def _build_id_index(self) -> None:
        """Build index of consumables by item ID for fast lookup."""
        self._consumables_by_id = {}
        for item in self.config.get("consumables", []):
            item_id = item.get("item_id")
            if item_id:
                self._consumables_by_id[item_id] = item
    
    def reload(self) -> bool:
        """Override reload to rebuild index."""
        result = super().reload()
        if result:
            self._build_id_index()
        return result
    
    @property
    def consumables(self) -> List[Dict[str, Any]]:
        """Get all consumable definitions."""
        self.check_and_reload()
        return self.config.get("consumables", [])
    
    def get_consumable(self, item_id: int) -> Optional[Dict[str, Any]]:
        """Get consumable definition by item ID."""
        self.check_and_reload()
        return self._consumables_by_id.get(item_id)
    
    def get_consumables_dict(self) -> Dict[int, Dict[str, Any]]:
        """Get consumables as dict keyed by item_id (legacy format)."""
        self.check_and_reload()
        return {
            item["item_id"]: {
                "name": item.get("name", f"Item {item['item_id']}"),
                "min_count": item.get("min_count", 50),
                "priority": item.get("priority", 50)
            }
            for item in self.consumables
            if "item_id" in item
        }
    
    def get_npc_purchasable(self) -> List[Dict[str, Any]]:
        """Get consumables that can be bought from NPCs."""
        self.check_and_reload()
        return [
            item for item in self.consumables
            if item.get("npc_purchasable", False)
        ]
    
    @property
    def settings(self) -> Dict[str, Any]:
        """Get restocking settings."""
        self.check_and_reload()
        return self.config.get("settings", {})
    
    @property
    def protected_items(self) -> Set[int]:
        """Get set of item IDs that should never be auto-sold."""
        self.check_and_reload()
        return set(self.settings.get("protected_items", []))


# =============================================================================
# JOB CLASSES CONFIGURATION
# =============================================================================

class JobClassesConfig(BaseConfigLoader):
    """Configuration for job class definitions and categorization."""
    
    def __init__(self, config_path: Path = None, auto_reload: bool = True):
        super().__init__(config_path or JOB_CLASSES_FILE, auto_reload)
        self._job_to_category: Dict[int, str] = {}
        self._build_job_index()
    
    def _get_defaults(self) -> Dict[str, Any]:
        """Default job classes if config file is missing."""
        return {
            "version": "1.0.0",
            "job_categories": {
                "merchant": {
                    "name": "Merchant Classes",
                    "job_ids": [5, 10, 18, 4006, 4011, 4019],
                    "capabilities": ["cart_access", "vending"]
                },
                "swordsman": {
                    "name": "Swordsman Classes",
                    "job_ids": [1, 7, 14, 4001, 4008, 4015],
                    "capabilities": ["melee_combat", "high_hp"]
                },
                "mage": {
                    "name": "Mage Classes",
                    "job_ids": [2, 9, 16, 4002, 4010, 4017],
                    "capabilities": ["magic_damage"]
                },
                "archer": {
                    "name": "Archer Classes",
                    "job_ids": [3, 11, 19, 20, 4003, 4012, 4020, 4021],
                    "capabilities": ["ranged_combat", "ammunition_user"]
                },
                "thief": {
                    "name": "Thief Classes",
                    "job_ids": [4, 12, 17, 4004, 4013, 4018],
                    "capabilities": ["high_flee", "steal"]
                },
                "acolyte": {
                    "name": "Acolyte Classes",
                    "job_ids": [6, 8, 15, 4005, 4009, 4016],
                    "capabilities": ["healing", "buff_skills"]
                },
                "novice": {
                    "name": "Novice Classes",
                    "job_ids": [0, 23, 4023],
                    "capabilities": ["basic_skills"]
                }
            },
            "job_requirements": {
                "ammunition_required": {
                    "job_ids": [3, 11, 19, 20, 24, 4003, 4012, 4020, 4021]
                },
                "cart_users": {
                    "job_ids": [5, 10, 18, 4006, 4011, 4019]
                }
            }
        }
    
    def _build_job_index(self) -> None:
        """Build reverse index from job ID to category."""
        self._job_to_category = {}
        for category, data in self.config.get("job_categories", {}).items():
            for job_id in data.get("job_ids", []):
                self._job_to_category[job_id] = category
    
    def reload(self) -> bool:
        """Override reload to rebuild index."""
        result = super().reload()
        if result:
            self._build_job_index()
        return result
    
    def get_merchant_job_ids(self) -> Set[int]:
        """Get set of merchant class job IDs (jobs with cart access)."""
        self.check_and_reload()
        merchant_data = self.config.get("job_categories", {}).get("merchant", {})
        return set(merchant_data.get("job_ids", [5, 10, 18, 4006, 4011, 4019]))
    
    def get_job_category(self, job_id: int) -> Optional[str]:
        """Get category name for a job ID."""
        self.check_and_reload()
        return self._job_to_category.get(job_id)
    
    def get_job_capabilities(self, job_id: int) -> List[str]:
        """Get capabilities for a job ID."""
        self.check_and_reload()
        category = self._job_to_category.get(job_id)
        if category:
            cat_data = self.config.get("job_categories", {}).get(category, {})
            return cat_data.get("capabilities", [])
        return []
    
    def has_capability(self, job_id: int, capability: str) -> bool:
        """Check if a job has a specific capability."""
        return capability in self.get_job_capabilities(job_id)
    
    def is_merchant_class(self, job_id: int) -> bool:
        """Check if job is a merchant class (has cart access)."""
        return job_id in self.get_merchant_job_ids()
    
    def requires_ammunition(self, job_id: int) -> bool:
        """Check if job requires ammunition (arrows, bullets, etc)."""
        self.check_and_reload()
        ammo_req = self.config.get("job_requirements", {}).get("ammunition_required", {})
        return job_id in ammo_req.get("job_ids", [])
    
    def get_jobs_by_category(self, category: str) -> List[int]:
        """Get all job IDs in a category."""
        self.check_and_reload()
        cat_data = self.config.get("job_categories", {}).get(category, {})
        return cat_data.get("job_ids", [])


# =============================================================================
# CARD VALUES CONFIGURATION
# =============================================================================

class CardValuesConfig(BaseConfigLoader):
    """Configuration for card market value estimates."""
    
    def __init__(self, config_path: Path = None, auto_reload: bool = True):
        super().__init__(config_path or CARD_VALUES_FILE, auto_reload)
    
    def _get_defaults(self) -> Dict[str, Any]:
        """Default card values if config file is missing."""
        return {
            "version": "1.0.0",
            "default_card_value": 50000,
            "cards": {
                4001: 50000,   # Poring Card
                4002: 50000,   # Fabre Card
                4003: 80000,   # Pupa Card
                4019: 70000,   # Creamy Card
                4028: 200000,  # Marc Card
                4030: 300000,  # Matyr Card
                4040: 500000,  # Hydra Card
            },
            "settings": {
                "auto_update_from_market": True,
                "cache_max_age": 86400,
                "unknown_card_multiplier": 1.0,
                "verbose_logging": True,
                "server_economy_type": "mid_rate",
                "economy_multipliers": {
                    "low_rate": 2.0,
                    "mid_rate": 1.0,
                    "high_rate": 0.5
                }
            }
        }
    
    def _validate_config(self) -> None:
        """Validate card values configuration."""
        if "cards" not in self.config:
            logger.warning("card_config_missing_cards_section")
            self.config["cards"] = self._get_defaults()["cards"]
        
        if "default_card_value" not in self.config:
            self.config["default_card_value"] = 50000
    
    def get_card_value(self, card_id: int) -> int:
        """
        Get estimated market value for a card.
        
        Args:
            card_id: Card item ID
            
        Returns:
            Estimated value in zeny
        """
        self.check_and_reload()
        
        cards = self.config.get("cards", {})
        default_value = self.config.get("default_card_value", 50000)
        
        # Check for direct value
        if card_id in cards:
            base_value = cards[card_id]
        else:
            base_value = default_value
            if self.config.get("settings", {}).get("verbose_logging", True):
                logger.debug("card_value_using_default", card_id=card_id, value=base_value)
        
        # Apply economy multiplier
        settings = self.config.get("settings", {})
        economy_type = settings.get("server_economy_type", "mid_rate")
        multipliers = settings.get("economy_multipliers", {})
        multiplier = multipliers.get(economy_type, 1.0)
        
        return int(base_value * multiplier)
    
    def get_all_card_values(self) -> Dict[int, int]:
        """Get all card values as dict."""
        self.check_and_reload()
        return self.config.get("cards", {})
    
    @property
    def default_value(self) -> int:
        """Get default card value."""
        self.check_and_reload()
        return self.config.get("default_card_value", 50000)
    
    @property
    def settings(self) -> Dict[str, Any]:
        """Get card value settings."""
        self.check_and_reload()
        return self.config.get("settings", {})


# =============================================================================
# SUBSYSTEM CONFIGURATION (Original class, preserved)
# =============================================================================

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


# =============================================================================
# GLOBAL CONFIG INSTANCES (Singleton pattern)
# =============================================================================

_subsystem_config: SubsystemConfig = None
_chat_config: ChatAbbreviationsConfig = None
_consumables_config: ConsumableItemsConfig = None
_job_classes_config: JobClassesConfig = None
_card_values_config: CardValuesConfig = None


def get_config() -> SubsystemConfig:
    """
    Get global subsystem configuration instance (singleton pattern).
    
    Returns:
        SubsystemConfig instance
    """
    global _subsystem_config
    if _subsystem_config is None:
        _subsystem_config = SubsystemConfig()
    return _subsystem_config


def get_chat_config() -> ChatAbbreviationsConfig:
    """
    Get global chat abbreviations configuration instance.
    
    Returns:
        ChatAbbreviationsConfig instance
    """
    global _chat_config
    if _chat_config is None:
        _chat_config = ChatAbbreviationsConfig()
    return _chat_config


def get_consumables_config() -> ConsumableItemsConfig:
    """
    Get global consumable items configuration instance.
    
    Returns:
        ConsumableItemsConfig instance
    """
    global _consumables_config
    if _consumables_config is None:
        _consumables_config = ConsumableItemsConfig()
    return _consumables_config


def get_job_classes_config() -> JobClassesConfig:
    """
    Get global job classes configuration instance.
    
    Returns:
        JobClassesConfig instance
    """
    global _job_classes_config
    if _job_classes_config is None:
        _job_classes_config = JobClassesConfig()
    return _job_classes_config


def get_card_values_config() -> CardValuesConfig:
    """
    Get global card values configuration instance.
    
    Returns:
        CardValuesConfig instance
    """
    global _card_values_config
    if _card_values_config is None:
        _card_values_config = CardValuesConfig()
    return _card_values_config


def reset_config() -> None:
    """Reset all global configurations (useful for testing)."""
    global _subsystem_config, _chat_config, _consumables_config
    global _job_classes_config, _card_values_config
    
    _subsystem_config = None
    _chat_config = None
    _consumables_config = None
    _job_classes_config = None
    _card_values_config = None
    
    logger.info("all_configs_reset")


def reload_all_configs() -> Dict[str, bool]:
    """
    Reload all configuration files.
    
    Returns:
        Dict of config names to reload status
    """
    results = {}
    
    if _chat_config:
        results["chat_abbreviations"] = _chat_config.reload()
    if _consumables_config:
        results["consumable_items"] = _consumables_config.reload()
    if _job_classes_config:
        results["job_classes"] = _job_classes_config.reload()
    if _card_values_config:
        results["card_values"] = _card_values_config.reload()
    if _subsystem_config:
        _subsystem_config.reload()
        results["subsystems"] = True
    
    logger.info("all_configs_reloaded", results=results)
    return results


def get_config_summary() -> Dict[str, Any]:
    """
    Get summary of all loaded configurations.
    
    Returns:
        Dict with configuration status and info
    """
    return {
        "subsystems": {
            "loaded": _subsystem_config is not None,
            "path": str(SUBSYSTEMS_FILE),
            "exists": SUBSYSTEMS_FILE.exists()
        },
        "chat_abbreviations": {
            "loaded": _chat_config is not None,
            "path": str(CHAT_ABBREVIATIONS_FILE),
            "exists": CHAT_ABBREVIATIONS_FILE.exists()
        },
        "consumable_items": {
            "loaded": _consumables_config is not None,
            "path": str(CONSUMABLE_ITEMS_FILE),
            "exists": CONSUMABLE_ITEMS_FILE.exists()
        },
        "job_classes": {
            "loaded": _job_classes_config is not None,
            "path": str(JOB_CLASSES_FILE),
            "exists": JOB_CLASSES_FILE.exists()
        },
        "card_values": {
            "loaded": _card_values_config is not None,
            "path": str(CARD_VALUES_FILE),
            "exists": CARD_VALUES_FILE.exists()
        }
    }