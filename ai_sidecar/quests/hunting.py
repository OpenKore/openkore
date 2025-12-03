"""
Hunting quest system for OpenKore AI.

Specialized manager for hunting quests with kill tracking,
optimal monster selection, party kill sharing, and route optimization.
"""

import json
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.quests.core import QuestManager

logger = structlog.get_logger(__name__)


class HuntingTarget(BaseModel):
    """Hunting quest target"""
    
    model_config = ConfigDict(frozen=False)
    
    monster_id: int
    monster_name: str
    required_kills: int
    current_kills: int = 0
    spawn_maps: List[str] = Field(default_factory=list)
    element: Optional[str] = None
    race: Optional[str] = None
    size: Optional[str] = None
    
    @property
    def is_complete(self) -> bool:
        """Check if target is complete"""
        return self.current_kills >= self.required_kills
    
    @property
    def progress_percent(self) -> float:
        """Calculate progress percentage"""
        if self.required_kills == 0:
            return 100.0
        return min(100.0, (self.current_kills / self.required_kills) * 100)
    
    def add_kill(self, count: int = 1) -> bool:
        """
        Add kills to target.
        
        Args:
            count: Number of kills to add
            
        Returns:
            True if target completed
        """
        self.current_kills = min(self.required_kills, self.current_kills + count)
        return self.is_complete


class HuntingQuest(BaseModel):
    """Hunting quest definition"""
    
    model_config = ConfigDict(frozen=False)
    
    quest_id: int
    quest_name: str
    targets: List[HuntingTarget]
    base_exp_reward: int = 0
    job_exp_reward: int = 0
    zeny_reward: int = 0
    min_level: int = 1
    max_level: int = 999
    is_party_shared: bool = True
    
    @property
    def is_complete(self) -> bool:
        """Check if all targets are complete"""
        return all(target.is_complete for target in self.targets)
    
    @property
    def overall_progress(self) -> float:
        """Calculate overall progress"""
        if not self.targets:
            return 0.0
        return sum(t.progress_percent for t in self.targets) / len(self.targets)


class HuntingQuestManager:
    """
    Specialized manager for hunting quests.
    
    Features:
    - Kill tracking
    - Optimal monster selection
    - Party kill sharing
    - Route optimization
    """
    
    def __init__(self, data_dir: Path, quest_manager: QuestManager):
        """
        Initialize hunting quest manager.
        
        Args:
            data_dir: Directory containing data files
            quest_manager: Core quest manager instance
        """
        self.log = logger.bind(component="hunting_quests")
        self.data_dir = Path(data_dir)
        self.quest_manager = quest_manager
        self.active_hunts: Dict[int, HuntingQuest] = {}
        self.kill_counts: Dict[int, int] = {}  # monster_id -> kills
        self._load_hunting_data()
    
    def _load_hunting_data(self) -> None:
        """Load hunting quest data from JSON"""
        hunting_file = self.data_dir / "hunting_quests.json"
        if not hunting_file.exists():
            self.log.warning("hunting_data_missing", file=str(hunting_file))
            return
        
        try:
            with open(hunting_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load hunting quests for reference (not active yet)
            quest_count = len(data.get("hunting_quests", []))
            self.log.info("hunting_data_loaded", quest_count=quest_count)
        except Exception as e:
            self.log.error("hunting_data_load_error", error=str(e))
    
    def start_hunt(self, quest_id: int) -> bool:
        """
        Start a hunting quest.
        
        Args:
            quest_id: Hunting quest ID
            
        Returns:
            True if started successfully
        """
        # Load quest from data
        hunting_file = self.data_dir / "hunting_quests.json"
        if not hunting_file.exists():
            return False
        
        try:
            with open(hunting_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for quest_data in data.get("hunting_quests", []):
                if quest_data["quest_id"] == quest_id:
                    # Parse targets
                    targets = []
                    for target_data in quest_data["targets"]:
                        target = HuntingTarget(
                            monster_id=target_data["monster_id"],
                            monster_name=target_data["monster_name"],
                            required_kills=target_data["required_kills"],
                            spawn_maps=target_data.get("spawn_maps", []),
                            element=target_data.get("element"),
                            race=target_data.get("race"),
                            size=target_data.get("size")
                        )
                        targets.append(target)
                    
                    # Create hunting quest
                    quest = HuntingQuest(
                        quest_id=quest_id,
                        quest_name=quest_data["quest_name"],
                        targets=targets,
                        base_exp_reward=quest_data.get("base_exp_reward", 0),
                        job_exp_reward=quest_data.get("job_exp_reward", 0),
                        zeny_reward=quest_data.get("zeny_reward", 0),
                        min_level=quest_data.get("min_level", 1),
                        max_level=quest_data.get("max_level", 999),
                        is_party_shared=quest_data.get("is_party_shared", True)
                    )
                    
                    self.active_hunts[quest_id] = quest
                    self.log.info("hunt_started", quest_id=quest_id, name=quest.quest_name)
                    return True
        except Exception as e:
            self.log.error("hunt_start_error", quest_id=quest_id, error=str(e))
        
        return False
    
    def record_kill(self, monster_id: int, is_party_kill: bool = False) -> List[int]:
        """
        Record a monster kill, return affected quest IDs.
        
        Args:
            monster_id: Killed monster ID
            is_party_kill: Whether kill was by party member
            
        Returns:
            List of affected hunting quest IDs
        """
        affected_quests = []
        
        # Update kill count
        self.kill_counts[monster_id] = self.kill_counts.get(monster_id, 0) + 1
        
        # Update all active hunting quests
        for quest_id, quest in self.active_hunts.items():
            # Check if quest shares party kills
            if is_party_kill and not quest.is_party_shared:
                continue
            
            # Update targets
            for target in quest.targets:
                if target.monster_id == monster_id and not target.is_complete:
                    completed = target.add_kill(1)
                    affected_quests.append(quest_id)
                    
                    self.log.debug(
                        "kill_recorded",
                        quest_id=quest_id,
                        monster_id=monster_id,
                        progress=f"{target.current_kills}/{target.required_kills}",
                        completed=completed
                    )
                    
                    if completed:
                        self.log.info(
                            "target_completed",
                            quest_id=quest_id,
                            monster=target.monster_name
                        )
        
        return affected_quests
    
    def get_optimal_hunting_targets(self, active_quests: List[int]) -> List[dict]:
        """
        Get optimal targets for multiple quests.
        
        Args:
            active_quests: List of active quest IDs
            
        Returns:
            List of optimal hunting targets with priorities
        """
        # Collect all targets from active quests
        target_map: Dict[int, List[Tuple[HuntingQuest, HuntingTarget]]] = defaultdict(list)
        
        for quest_id in active_quests:
            quest = self.active_hunts.get(quest_id)
            if not quest:
                continue
            
            for target in quest.targets:
                if not target.is_complete:
                    target_map[target.monster_id].append((quest, target))
        
        # Calculate priority for each unique monster
        optimal_targets = []
        for monster_id, quest_targets in target_map.items():
            # Count how many quests need this monster
            quest_count = len(quest_targets)
            
            # Calculate total kills needed
            total_needed = sum(
                t.required_kills - t.current_kills
                for _, t in quest_targets
            )
            
            # Get spawn maps (union of all maps)
            spawn_maps = set()
            for _, target in quest_targets:
                spawn_maps.update(target.spawn_maps)
            
            # Priority: monsters that satisfy multiple quests
            priority = quest_count * 10 + (100 - total_needed)
            
            optimal_targets.append({
                "monster_id": monster_id,
                "monster_name": quest_targets[0][1].monster_name,
                "quest_count": quest_count,
                "total_needed": total_needed,
                "spawn_maps": list(spawn_maps),
                "priority": priority,
                "affected_quests": [q.quest_id for q, _ in quest_targets]
            })
        
        # Sort by priority
        optimal_targets.sort(key=lambda x: x["priority"], reverse=True)
        return optimal_targets
    
    def get_hunting_progress(self, quest_id: int) -> dict:
        """
        Get progress for a hunting quest.
        
        Args:
            quest_id: Hunting quest ID
            
        Returns:
            Progress dictionary
        """
        quest = self.active_hunts.get(quest_id)
        if not quest:
            return {}
        
        targets_progress = []
        for target in quest.targets:
            targets_progress.append({
                "monster_id": target.monster_id,
                "monster_name": target.monster_name,
                "current": target.current_kills,
                "required": target.required_kills,
                "progress_percent": target.progress_percent,
                "is_complete": target.is_complete
            })
        
        return {
            "quest_id": quest.quest_id,
            "quest_name": quest.quest_name,
            "overall_progress": quest.overall_progress,
            "is_complete": quest.is_complete,
            "targets": targets_progress
        }
    
    def calculate_exp_per_kill(self, quest_id: int) -> dict:
        """
        Calculate EXP efficiency per kill.
        
        Args:
            quest_id: Hunting quest ID
            
        Returns:
            EXP efficiency data
        """
        quest = self.active_hunts.get(quest_id)
        if not quest:
            return {}
        
        total_kills_needed = sum(
            t.required_kills - t.current_kills
            for t in quest.targets
            if not t.is_complete
        )
        
        if total_kills_needed == 0:
            return {
                "total_exp": quest.base_exp_reward + quest.job_exp_reward,
                "exp_per_kill": 0,
                "kills_remaining": 0
            }
        
        total_exp = quest.base_exp_reward + quest.job_exp_reward
        exp_per_kill = total_exp / total_kills_needed
        
        return {
            "total_exp": total_exp,
            "base_exp": quest.base_exp_reward,
            "job_exp": quest.job_exp_reward,
            "exp_per_kill": exp_per_kill,
            "kills_remaining": total_kills_needed
        }
    
    def get_best_farming_map(self, quest_id: int) -> Tuple[str, List[str]]:
        """
        Get best map for quest completion.
        
        Args:
            quest_id: Hunting quest ID
            
        Returns:
            Tuple of (best_map, all_maps)
        """
        quest = self.active_hunts.get(quest_id)
        if not quest:
            return "", []
        
        # Count target monsters per map
        map_coverage: Dict[str, int] = defaultdict(int)
        
        for target in quest.targets:
            if target.is_complete:
                continue
            for spawn_map in target.spawn_maps:
                map_coverage[spawn_map] += 1
        
        if not map_coverage:
            return "", []
        
        # Find map with most target coverage
        best_map = max(map_coverage.items(), key=lambda x: x[1])[0]
        all_maps = list(map_coverage.keys())
        
        return best_map, all_maps
    
    def complete_hunt(self, quest_id: int) -> bool:
        """
        Complete a hunting quest.
        
        Args:
            quest_id: Hunting quest ID
            
        Returns:
            True if completed successfully
        """
        quest = self.active_hunts.get(quest_id)
        if not quest or not quest.is_complete:
            return False
        
        del self.active_hunts[quest_id]
        self.log.info("hunt_completed", quest_id=quest_id, name=quest.quest_name)
        return True
    
    def get_active_hunts(self) -> List[HuntingQuest]:
        """
        Get all active hunting quests.
        
        Returns:
            List of active hunts
        """
        return list(self.active_hunts.values())
    
    def track_kill(self, monster_id: int, monster_name: str = "", is_party_kill: bool = False) -> List[int]:
        """
        Track monster kill and update hunting quest progress.
        
        This is an alias for record_kill() with additional logging.
        
        Args:
            monster_id: Killed monster ID
            monster_name: Monster name (for logging)
            is_party_kill: Whether kill was by party member
            
        Returns:
            List of affected hunting quest IDs
        """
        affected = self.record_kill(monster_id, is_party_kill)
        
        if affected:
            self.log.debug(
                "kill_tracked",
                monster_id=monster_id,
                monster_name=monster_name,
                affected_quests=affected,
                party_kill=is_party_kill
            )
        
        return affected