"""
Daily quest system for OpenKore AI.

Manages daily and repeatable quests including Gramps turn-in quests,
Eden Group quests, and hunting board quests with daily reset tracking
and optimization.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.quests.core import QuestManager

logger = structlog.get_logger(__name__)


class DailyQuestCategory(str, Enum):
    """Daily quest categories"""
    GRAMPS = "gramps"
    EDEN = "eden"
    BOARD = "board"
    HUNTING = "hunting"
    INSTANCE = "instance"
    GATHERING = "gathering"
    DONATION = "donation"


class GrampsQuest(BaseModel):
    """Gramps turn-in quest"""
    
    model_config = ConfigDict(frozen=True)
    
    monster_id: int
    monster_name: str
    required_kills: int
    exp_reward: int
    job_exp_reward: int
    level_range: Tuple[int, int]  # (min_level, max_level)
    spawn_maps: List[str] = Field(default_factory=list)


class EdenQuest(BaseModel):
    """Eden Group quest"""
    
    model_config = ConfigDict(frozen=True)
    
    quest_id: int
    quest_name: str
    level_bracket: str  # "1-10", "11-25", etc.
    target_monsters: List[str]
    target_count: int
    exp_reward: int
    job_exp_reward: int
    zeny_reward: int = 0
    is_board_quest: bool = False


class BoardQuest(BaseModel):
    """Hunting board quest"""
    
    model_config = ConfigDict(frozen=True)
    
    board_location: str  # Map where board is
    monster_name: str
    monster_id: int
    required_kills: int
    reward_zeny: int
    reward_exp: int
    available_time_hours: int = 24


class DailyQuestManager:
    """
    Manage daily and repeatable quests.
    
    Features:
    - Track daily reset
    - Optimize quest selection
    - EXP/reward calculations
    - Farming route integration
    """
    
    def __init__(self, data_dir: Path, quest_manager: QuestManager):
        """
        Initialize daily quest manager.
        
        Args:
            data_dir: Directory containing data files
            quest_manager: Core quest manager instance
        """
        self.log = logger.bind(component="daily_quests")
        self.data_dir = Path(data_dir)
        self.quest_manager = quest_manager
        
        # Quest data storage
        self.gramps_quests: Dict[Tuple[int, int], List[GrampsQuest]] = {}
        self.eden_quests: Dict[str, List[EdenQuest]] = {}
        self.board_quests: Dict[str, List[BoardQuest]] = {}
        
        # Daily completion tracking
        self.daily_completion: Dict[str, datetime] = {}
        self.last_reset: Optional[datetime] = None
        
        self._load_daily_data()
        self._check_daily_reset()
    
    def _load_daily_data(self) -> None:
        """Load daily quest data from JSON"""
        daily_file = self.data_dir / "daily_quests.json"
        if not daily_file.exists():
            self.log.warning("daily_data_missing", file=str(daily_file))
            return
        
        try:
            with open(daily_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load Gramps quests
            for gramps_data in data.get("gramps_quests", []):
                level_min = gramps_data["level_min"]
                level_max = gramps_data["level_max"]
                key = (level_min, level_max)
                
                if key not in self.gramps_quests:
                    self.gramps_quests[key] = []
                
                for monster in gramps_data.get("monsters", []):
                    quest = GrampsQuest(
                        monster_id=monster["monster_id"],
                        monster_name=monster["monster_name"],
                        required_kills=monster["required_kills"],
                        exp_reward=monster["exp_reward"],
                        job_exp_reward=monster["job_exp_reward"],
                        level_range=(level_min, level_max),
                        spawn_maps=monster.get("spawn_maps", [])
                    )
                    self.gramps_quests[key].append(quest)
            
            # Load Eden quests
            eden_data = data.get("eden_quests", {})
            for bracket, quests in eden_data.items():
                self.eden_quests[bracket] = []
                for quest_data in quests:
                    quest = EdenQuest(
                        quest_id=quest_data.get("quest_id", 0),
                        quest_name=quest_data["quest_name"],
                        level_bracket=bracket,
                        target_monsters=quest_data["monsters"],
                        target_count=quest_data["target_count"],
                        exp_reward=quest_data.get("exp_reward", 0),
                        job_exp_reward=quest_data.get("job_exp_reward", 0),
                        zeny_reward=quest_data.get("zeny_reward", 0),
                        is_board_quest=quest_data.get("is_board_quest", False)
                    )
                    self.eden_quests[bracket].append(quest)
            
            # Load board quests
            board_data = data.get("board_quests", {})
            for location, quests in board_data.items():
                self.board_quests[location] = []
                for quest_data in quests:
                    quest = BoardQuest(
                        board_location=location,
                        monster_name=quest_data["monster_name"],
                        monster_id=quest_data.get("monster_id", 0),
                        required_kills=quest_data["required_kills"],
                        reward_zeny=quest_data.get("reward_zeny", 0),
                        reward_exp=quest_data.get("reward_exp", 0),
                        available_time_hours=quest_data.get("available_time_hours", 24)
                    )
                    self.board_quests[location].append(quest)
            
            self.log.info(
                "daily_data_loaded",
                gramps_brackets=len(self.gramps_quests),
                eden_brackets=len(self.eden_quests),
                board_locations=len(self.board_quests)
            )
        except Exception as e:
            self.log.error("daily_data_load_error", error=str(e))
    
    def _check_daily_reset(self) -> None:
        """Check if daily reset has occurred"""
        now = datetime.now()
        
        if self.last_reset is None:
            self.last_reset = now
            return
        
        # Check if we've crossed midnight server time (assuming UTC+0 or configurable)
        if now.date() > self.last_reset.date():
            self._perform_daily_reset()
            self.last_reset = now
    
    def _perform_daily_reset(self) -> None:
        """Perform daily reset of quest completion tracking"""
        self.daily_completion.clear()
        self.log.info("daily_reset_performed")
    
    def get_gramps_quest(self, level: int) -> Optional[GrampsQuest]:
        """
        Get appropriate Gramps quest for level.
        
        Args:
            level: Character level
            
        Returns:
            Gramps quest or None
        """
        for (min_lvl, max_lvl), quests in self.gramps_quests.items():
            if min_lvl <= level <= max_lvl:
                # Return first quest in bracket (could be randomized)
                return quests[0] if quests else None
        return None
    
    def get_eden_quests(self, level: int) -> List[EdenQuest]:
        """
        Get Eden quests for level bracket.
        
        Args:
            level: Character level
            
        Returns:
            List of Eden quests
        """
        for bracket, quests in self.eden_quests.items():
            # Parse bracket like "71-85"
            try:
                min_lvl, max_lvl = map(int, bracket.split('-'))
                if min_lvl <= level <= max_lvl:
                    return quests
            except ValueError:
                continue
        return []
    
    def get_board_quests(self, map_name: str) -> List[BoardQuest]:
        """
        Get board quests available on map.
        
        Args:
            map_name: Current map name
            
        Returns:
            List of board quests
        """
        return self.board_quests.get(map_name, [])
    
    def get_optimal_daily_route(self, character_state: dict) -> List[dict]:
        """
        Calculate optimal route for daily quests.
        
        Args:
            character_state: Character state
            
        Returns:
            List of quest waypoints with priorities
        """
        route = []
        level = character_state.get("level", 1)
        current_map = character_state.get("map", "")
        
        # Priority 1: Gramps (highest EXP/time)
        gramps = self.get_gramps_quest(level)
        if gramps and not self.is_daily_completed(DailyQuestCategory.GRAMPS):
            route.append({
                "type": "gramps",
                "quest": gramps,
                "priority": 1,
                "estimated_exp": gramps.exp_reward + gramps.job_exp_reward,
                "maps": gramps.spawn_maps
            })
        
        # Priority 2: Eden quests
        eden_quests = self.get_eden_quests(level)
        if eden_quests and not self.is_daily_completed(DailyQuestCategory.EDEN):
            for quest in eden_quests[:3]:  # Limit to top 3
                route.append({
                    "type": "eden",
                    "quest": quest,
                    "priority": 2,
                    "estimated_exp": quest.exp_reward + quest.job_exp_reward
                })
        
        # Priority 3: Board quests (if on same map)
        board_quests = self.get_board_quests(current_map)
        if board_quests and not self.is_daily_completed(DailyQuestCategory.BOARD):
            for quest in board_quests[:2]:  # Limit to top 2
                route.append({
                    "type": "board",
                    "quest": quest,
                    "priority": 3,
                    "estimated_exp": quest.reward_exp,
                    "estimated_zeny": quest.reward_zeny
                })
        
        return sorted(route, key=lambda x: x["priority"])
    
    def calculate_daily_exp_potential(self, character_state: dict) -> dict:
        """
        Calculate total EXP from all daily quests.
        
        Args:
            character_state: Character state
            
        Returns:
            Dictionary with EXP breakdown
        """
        level = character_state.get("level", 1)
        total_base_exp = 0
        total_job_exp = 0
        total_zeny = 0
        
        # Gramps contribution
        gramps = self.get_gramps_quest(level)
        if gramps:
            total_base_exp += gramps.exp_reward
            total_job_exp += gramps.job_exp_reward
        
        # Eden contribution
        eden_quests = self.get_eden_quests(level)
        for quest in eden_quests:
            total_base_exp += quest.exp_reward
            total_job_exp += quest.job_exp_reward
            total_zeny += quest.zeny_reward
        
        # Board quests (estimate average)
        board_count = sum(len(quests) for quests in self.board_quests.values())
        if board_count > 0:
            avg_board_exp = 50000  # Estimate
            total_base_exp += avg_board_exp * min(board_count, 3)
        
        return {
            "total_base_exp": total_base_exp,
            "total_job_exp": total_job_exp,
            "total_zeny": total_zeny,
            "total_exp": total_base_exp + total_job_exp,
            "gramps_exp": gramps.exp_reward + gramps.job_exp_reward if gramps else 0,
            "eden_exp": sum(q.exp_reward + q.job_exp_reward for q in eden_quests),
        }
    
    def is_daily_completed(self, quest_category: DailyQuestCategory) -> bool:
        """
        Check if daily quest category is done.
        
        Args:
            quest_category: Quest category to check
            
        Returns:
            True if completed today
        """
        self._check_daily_reset()
        
        completion_time = self.daily_completion.get(quest_category.value)
        if not completion_time:
            return False
        
        # Check if completion was today
        return completion_time.date() == datetime.now().date()
    
    def mark_daily_complete(self, quest_category: DailyQuestCategory) -> None:
        """
        Mark daily quest as completed.
        
        Args:
            quest_category: Quest category completed
        """
        self.daily_completion[quest_category.value] = datetime.now()
        self.log.info("daily_completed", category=quest_category.value)
    
    def get_time_until_reset(self) -> timedelta:
        """
        Get time until daily reset.
        
        Returns:
            Time remaining until reset
        """
        now = datetime.now()
        tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        return tomorrow - now
    
    def get_priority_dailies(self, character_state: dict) -> List[dict]:
        """
        Get prioritized list of daily quests to do.
        
        Args:
            character_state: Character state
            
        Returns:
            Sorted list of daily quests by priority
        """
        level = character_state.get("level", 1)
        dailies = []
        
        # Check Gramps
        if not self.is_daily_completed(DailyQuestCategory.GRAMPS):
            gramps = self.get_gramps_quest(level)
            if gramps:
                exp_per_kill = (gramps.exp_reward + gramps.job_exp_reward) / gramps.required_kills
                dailies.append({
                    "category": DailyQuestCategory.GRAMPS,
                    "quest": gramps,
                    "priority_score": exp_per_kill * 10,  # Weight heavily
                    "estimated_time_minutes": gramps.required_kills / 10,  # Assume 10 kills/min
                    "exp_total": gramps.exp_reward + gramps.job_exp_reward
                })
        
        # Check Eden
        if not self.is_daily_completed(DailyQuestCategory.EDEN):
            eden_quests = self.get_eden_quests(level)
            for quest in eden_quests:
                exp_total = quest.exp_reward + quest.job_exp_reward
                exp_per_kill = exp_total / quest.target_count
                dailies.append({
                    "category": DailyQuestCategory.EDEN,
                    "quest": quest,
                    "priority_score": exp_per_kill * 5,
                    "estimated_time_minutes": quest.target_count / 8,
                    "exp_total": exp_total
                })
        
        # Sort by priority score (exp efficiency)
        dailies.sort(key=lambda x: x["priority_score"], reverse=True)
        return dailies
    
    def get_completion_summary(self) -> dict:
        """
        Get daily quest completion summary.
        
        Returns:
            Summary of completed dailies
        """
        completed = []
        pending = []
        
        for category in DailyQuestCategory:
            if self.is_daily_completed(category):
                completed.append(category.value)
            else:
                pending.append(category.value)
        
        time_until_reset = self.get_time_until_reset()
        
        return {
            "completed": completed,
            "pending": pending,
            "completion_rate": len(completed) / len(DailyQuestCategory) * 100,
            "time_until_reset_hours": time_until_reset.total_seconds() / 3600,
            "reset_at": (datetime.now() + time_until_reset).isoformat()
        }