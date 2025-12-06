"""
Quest Database Loader Module.

Handles loading quest definitions from YAML/JSON files,
indexing, and caching of quest data.

Supports:
- YAML and JSON formats
- Multiple quest database files
- Hot-reload for updates
- Quest indexing by type, level, NPC
- Custom server quest loading
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import yaml

from ai_sidecar.npc.quest_models import Quest, QuestDatabase
from ai_sidecar.npc.quest_parser import QuestParser, determine_quest_type
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class QuestDatabaseLoader:
    """
    Loads and manages quest database from YAML/JSON files.
    
    Features:
    - Multi-file support (organized by type/region)
    - Validation of quest data
    - Efficient indexing for fast lookups
    - Hot-reload capability
    - Custom server quest support
    """
    
    # Default quest database path
    DEFAULT_DB_PATH = Path(__file__).parent.parent / "data" / "quests"
    
    def __init__(
        self,
        db_path: Optional[Path] = None,
        custom_paths: Optional[List[Path]] = None
    ) -> None:
        """
        Initialize quest database loader.
        
        Args:
            db_path: Path to quest database directory (default: data/quests/)
            custom_paths: Additional paths for custom server quests
        """
        self.db_path = db_path or self.DEFAULT_DB_PATH
        self.custom_paths = custom_paths or []
        
        # Parser instance
        self._parser = QuestParser()
        
        # Quest storage
        self._quests: Dict[int, Quest] = {}
        self._loaded_files: Set[str] = set()
        self._last_load_time: Optional[datetime] = None
        
        # Indexes for fast lookups
        self._by_type: Dict[str, List[int]] = {}
        self._by_npc: Dict[int, List[int]] = {}
        self._by_level_range: Dict[Tuple[int, int], List[int]] = {}
        self._by_prerequisite: Dict[int, List[int]] = {}
        self._chains: Dict[int, List[int]] = {}
        
        # Statistics
        self._stats: Dict[str, Any] = {
            "total_quests": 0,
            "by_type": {},
            "parse_errors": 0,
            "validation_errors": 0,
        }
        
        logger.info(
            f"Quest database loader initialized",
            db_path=str(self.db_path),
            custom_paths=[str(p) for p in self.custom_paths]
        )
    
    def load_all(self) -> QuestDatabase:
        """
        Load all quest databases and return populated QuestDatabase.
        
        Returns:
            Populated QuestDatabase instance
        """
        logger.info("Loading quest database...")
        
        # Clear existing data
        self._quests.clear()
        self._loaded_files.clear()
        self._clear_indexes()
        self._parser.reset_stats()
        
        # Load main database
        if self.db_path.exists():
            self._load_directory(self.db_path)
        else:
            logger.warning(f"Quest database path not found: {self.db_path}")
        
        # Load custom server quests
        for custom_path in self.custom_paths:
            if custom_path.exists():
                self._load_directory(custom_path)
            else:
                logger.warning(f"Custom quest path not found: {custom_path}")
        
        # Build indexes
        self._build_indexes()
        
        # Create QuestDatabase instance
        quest_db = QuestDatabase()
        for quest in self._quests.values():
            quest_db.add_quest(quest)
        
        self._last_load_time = datetime.now()
        self._update_stats()
        
        logger.info(
            f"Quest database loaded successfully",
            total_quests=self._stats["total_quests"],
            by_type=self._stats["by_type"],
            parse_errors=self._stats["parse_errors"],
            validation_errors=self._stats["validation_errors"]
        )
        
        return quest_db
    
    def _load_directory(self, directory: Path) -> None:
        """Load all quest files from a directory."""
        for file_path in directory.iterdir():
            if file_path.is_file():
                if file_path.suffix in {".yml", ".yaml"}:
                    self._load_yaml_file(file_path)
                elif file_path.suffix == ".json":
                    self._load_json_file(file_path)
    
    def _load_yaml_file(self, file_path: Path) -> None:
        """Load quests from YAML file."""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = yaml.safe_load(f)
            
            self._loaded_files.add(str(file_path))
            quests = self._parser.parse_quest_data(data, str(file_path))
            self._quests.update(quests)
            
            logger.debug(f"Loaded YAML quest file: {file_path.name}, quests: {len(quests)}")
            
        except yaml.YAMLError as e:
            logger.error(f"YAML parse error in {file_path}: {e}")
            self._stats["parse_errors"] += 1
        except Exception as e:
            logger.error(f"Error loading quest file {file_path}: {e}", exc_info=True)
            self._stats["parse_errors"] += 1
    
    def _load_json_file(self, file_path: Path) -> None:
        """Load quests from JSON file."""
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            self._loaded_files.add(str(file_path))
            quests = self._parser.parse_quest_data(data, str(file_path))
            self._quests.update(quests)
            
            logger.debug(f"Loaded JSON quest file: {file_path.name}, quests: {len(quests)}")
            
        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error in {file_path}: {e}")
            self._stats["parse_errors"] += 1
        except Exception as e:
            logger.error(f"Error loading quest file {file_path}: {e}", exc_info=True)
            self._stats["parse_errors"] += 1
    
    def _clear_indexes(self) -> None:
        """Clear all indexes."""
        self._by_type.clear()
        self._by_npc.clear()
        self._by_level_range.clear()
        self._by_prerequisite.clear()
        self._chains.clear()
    
    def _build_indexes(self) -> None:
        """Build all indexes for fast lookups."""
        logger.debug("Building quest indexes...")
        
        for quest_id, quest in self._quests.items():
            # Index by type
            quest_type = determine_quest_type(quest)
            if quest_type not in self._by_type:
                self._by_type[quest_type] = []
            self._by_type[quest_type].append(quest_id)
            
            # Index by NPC
            if quest.npc_id not in self._by_npc:
                self._by_npc[quest.npc_id] = []
            self._by_npc[quest.npc_id].append(quest_id)
            
            # Index by level range (10-level buckets)
            level_bucket = (quest.min_level // 10 * 10, (quest.max_level // 10 + 1) * 10)
            if level_bucket not in self._by_level_range:
                self._by_level_range[level_bucket] = []
            self._by_level_range[level_bucket].append(quest_id)
            
            # Index by prerequisite
            for prereq_id in quest.prerequisite_quests:
                if prereq_id not in self._by_prerequisite:
                    self._by_prerequisite[prereq_id] = []
                self._by_prerequisite[prereq_id].append(quest_id)
        
        # Build quest chains
        self._build_quest_chains()
        
        logger.debug(
            f"Indexes built",
            types=len(self._by_type),
            npcs=len(self._by_npc),
            level_ranges=len(self._by_level_range),
            chains=len(self._chains)
        )
    
    def _build_quest_chains(self) -> None:
        """Build quest chain mappings."""
        starters = [
            q_id for q_id, quest in self._quests.items()
            if not quest.prerequisite_quests
        ]
        
        for starter_id in starters:
            chain = self._traverse_chain(starter_id, set())
            if len(chain) > 1:
                self._chains[starter_id] = chain
    
    def _traverse_chain(self, quest_id: int, visited: Set[int]) -> List[int]:
        """Recursively traverse quest chain."""
        if quest_id in visited or quest_id not in self._quests:
            return []
        
        visited.add(quest_id)
        chain = [quest_id]
        
        quest = self._quests[quest_id]
        for next_id in quest.next_quests:
            chain.extend(self._traverse_chain(next_id, visited))
        
        return chain
    
    def _update_stats(self) -> None:
        """Update statistics."""
        self._stats["total_quests"] = len(self._quests)
        self._stats["by_type"] = {
            quest_type: len(quest_ids)
            for quest_type, quest_ids in self._by_type.items()
        }
        self._stats["parse_errors"] = self._parser.parse_errors
        self._stats["validation_errors"] = self._parser.validation_errors
    
    # === Query Methods ===
    
    def get_quests_by_type(self, quest_type: str) -> List[Quest]:
        """Get all quests of a specific type."""
        quest_ids = self._by_type.get(quest_type, [])
        return [self._quests[q_id].model_copy() for q_id in quest_ids if q_id in self._quests]
    
    def get_quests_by_npc(self, npc_id: int) -> List[Quest]:
        """Get all quests from a specific NPC."""
        quest_ids = self._by_npc.get(npc_id, [])
        return [self._quests[q_id].model_copy() for q_id in quest_ids if q_id in self._quests]
    
    def get_quests_for_level(self, level: int) -> List[Quest]:
        """Get all quests available for a specific level."""
        available = []
        for quest in self._quests.values():
            if quest.min_level <= level <= quest.max_level:
                available.append(quest.model_copy())
        return available
    
    def get_quest_chain(self, quest_id: int) -> List[Quest]:
        """Get full quest chain containing or starting from a quest."""
        if quest_id in self._chains:
            chain_ids = self._chains[quest_id]
            return [self._quests[q_id].model_copy() for q_id in chain_ids if q_id in self._quests]
        
        for starter_id, chain_ids in self._chains.items():
            if quest_id in chain_ids:
                return [self._quests[q_id].model_copy() for q_id in chain_ids if q_id in self._quests]
        
        if quest_id in self._quests:
            return [self._quests[quest_id].model_copy()]
        return []
    
    def get_dependent_quests(self, quest_id: int) -> List[Quest]:
        """Get quests that require this quest as a prerequisite."""
        dependent_ids = self._by_prerequisite.get(quest_id, [])
        return [self._quests[q_id].model_copy() for q_id in dependent_ids if q_id in self._quests]
    
    def get_quest(self, quest_id: int) -> Optional[Quest]:
        """Get a single quest by ID."""
        quest = self._quests.get(quest_id)
        return quest.model_copy() if quest else None
    
    def reload(self) -> QuestDatabase:
        """Hot-reload quest database from files."""
        logger.info("Hot-reloading quest database...")
        return self.load_all()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get loader statistics."""
        return {
            **self._stats,
            "loaded_files": len(self._loaded_files),
            "last_load_time": self._last_load_time.isoformat() if self._last_load_time else None,
            "index_counts": {
                "by_type": len(self._by_type),
                "by_npc": len(self._by_npc),
                "by_level_range": len(self._by_level_range),
                "chains": len(self._chains),
            }
        }


# Global loader instance (singleton pattern)
_loader: Optional[QuestDatabaseLoader] = None


def get_quest_loader(
    db_path: Optional[Path] = None,
    custom_paths: Optional[List[Path]] = None
) -> QuestDatabaseLoader:
    """
    Get global quest database loader instance.
    
    Args:
        db_path: Override default database path
        custom_paths: Additional paths for custom quests
        
    Returns:
        QuestDatabaseLoader singleton instance
    """
    global _loader
    if _loader is None:
        _loader = QuestDatabaseLoader(db_path=db_path, custom_paths=custom_paths)
    return _loader


def reset_quest_loader() -> None:
    """Reset the global quest loader (useful for testing)."""
    global _loader
    _loader = None