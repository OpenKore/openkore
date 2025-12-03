"""
Core quest management system for OpenKore AI.

Provides comprehensive quest tracking, objective progress, reward calculation,
and quest recommendations based on character state and game context.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class QuestType(str, Enum):
    """Quest types in RO"""
    MAIN_STORY = "main_story"
    EPISODE = "episode"
    JOB_CHANGE = "job_change"
    ACCESS = "access"
    DAILY = "daily"
    REPEATABLE = "repeatable"
    GRAMPS = "gramps"
    EDEN = "eden"
    BOARD = "board"
    HUNTING = "hunting"
    GATHERING = "gathering"
    INSTANCE = "instance"
    HEADGEAR = "headgear"
    SEASONAL = "seasonal"
    TUTORIAL = "tutorial"


class QuestStatus(str, Enum):
    """Quest status"""
    NOT_STARTED = "not_started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    COOLDOWN = "cooldown"
    LOCKED = "locked"  # Prerequisites not met


class QuestObjectiveType(str, Enum):
    """Quest objective types"""
    KILL_MONSTER = "kill_monster"
    COLLECT_ITEM = "collect_item"
    TALK_NPC = "talk_npc"
    VISIT_MAP = "visit_map"
    DELIVER_ITEM = "deliver_item"
    USE_SKILL = "use_skill"
    EQUIP_ITEM = "equip_item"
    REACH_LEVEL = "reach_level"
    REACH_JOB_LEVEL = "reach_job_level"
    COMPLETE_INSTANCE = "complete_instance"


class QuestObjective(BaseModel):
    """Single quest objective"""
    
    model_config = ConfigDict(frozen=False)
    
    objective_id: int
    objective_type: QuestObjectiveType
    target_id: Optional[int] = None  # Monster ID, Item ID, NPC ID, etc.
    target_name: str
    required_count: int = 1
    current_count: int = 0
    map_name: Optional[str] = None
    coordinates: Optional[Tuple[int, int]] = None
    
    @property
    def is_complete(self) -> bool:
        """Check if objective is complete"""
        return self.current_count >= self.required_count
    
    @property
    def progress_percent(self) -> float:
        """Calculate progress percentage"""
        if self.required_count == 0:
            return 100.0
        return min(100.0, (self.current_count / self.required_count) * 100)
    
    def update_progress(self, amount: int) -> bool:
        """
        Update objective progress.
        
        Args:
            amount: Amount to add to current count
            
        Returns:
            True if objective completed after update
        """
        self.current_count = min(self.required_count, self.current_count + amount)
        return self.is_complete


class QuestReward(BaseModel):
    """Quest reward definition"""
    
    model_config = ConfigDict(frozen=True)
    
    reward_type: str  # "exp", "job_exp", "zeny", "item", "title"
    reward_id: Optional[int] = None
    reward_name: str
    quantity: int = 1
    is_optional: bool = False  # For choice rewards


class QuestRequirement(BaseModel):
    """Quest requirement/prerequisite"""
    
    model_config = ConfigDict(frozen=True)
    
    requirement_type: str  # "quest", "level", "job_level", "job", "item"
    requirement_id: Optional[int] = None
    requirement_name: str
    required_value: Any = None


class Quest(BaseModel):
    """Complete quest definition"""
    
    model_config = ConfigDict(frozen=False)
    
    quest_id: int
    quest_name: str
    quest_type: QuestType
    description: str
    
    # Status
    status: QuestStatus = QuestStatus.NOT_STARTED
    
    # Objectives
    objectives: List[QuestObjective] = Field(default_factory=list)
    
    # Requirements
    requirements: List[QuestRequirement] = Field(default_factory=list)
    min_level: int = 1
    max_level: int = 999
    job_requirements: List[str] = Field(default_factory=list)
    
    # Rewards
    rewards: List[QuestReward] = Field(default_factory=list)
    base_exp_reward: int = 0
    job_exp_reward: int = 0
    zeny_reward: int = 0
    
    # Timing
    is_daily: bool = False
    is_repeatable: bool = False
    cooldown_hours: int = 24
    last_completed: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    
    # NPCs
    start_npc: Optional[str] = None
    start_map: Optional[str] = None
    start_coordinates: Optional[Tuple[int, int]] = None
    end_npc: Optional[str] = None
    end_map: Optional[str] = None
    end_coordinates: Optional[Tuple[int, int]] = None
    
    @property
    def is_complete(self) -> bool:
        """Check if all objectives are complete"""
        return all(obj.is_complete for obj in self.objectives)
    
    @property
    def overall_progress(self) -> float:
        """Calculate overall quest progress percentage"""
        if not self.objectives:
            return 0.0
        return sum(obj.progress_percent for obj in self.objectives) / len(self.objectives)
    
    @property
    def can_start(self) -> bool:
        """Check if quest can be started"""
        if self.status != QuestStatus.NOT_STARTED:
            return False
        if self.is_daily and self.last_completed:
            cooldown_end = self.last_completed + timedelta(hours=self.cooldown_hours)
            if datetime.now() < cooldown_end:
                return False
        return True
    
    def get_cooldown_remaining(self) -> Optional[timedelta]:
        """Get remaining cooldown time for daily/repeatable quests"""
        if not self.last_completed:
            return None
        if not (self.is_daily or self.is_repeatable):
            return None
        
        cooldown_end = self.last_completed + timedelta(hours=self.cooldown_hours)
        remaining = cooldown_end - datetime.now()
        return remaining if remaining.total_seconds() > 0 else None


class QuestManager:
    """
    Core quest management system.
    
    Features:
    - Quest tracking
    - Objective progress
    - Reward calculation
    - Quest recommendations
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize quest manager.
        
        Args:
            data_dir: Directory containing quest data files
        """
        self.log = logger.bind(component="quest_manager")
        self.data_dir = Path(data_dir)
        self.quests: Dict[int, Quest] = {}
        self.active_quests: Dict[int, Quest] = {}
        self.completed_quests: List[int] = []
        self._load_quest_data()
    
    def _load_quest_data(self) -> None:
        """Load quest definitions from data files"""
        quest_file = self.data_dir / "quests.json"
        if not quest_file.exists():
            self.log.warning("quest_data_missing", file=str(quest_file))
            return
        
        try:
            with open(quest_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
                
            for quest_data in data.get("quests", []):
                try:
                    quest = self._parse_quest(quest_data)
                    self.quests[quest.quest_id] = quest
                except Exception as e:
                    self.log.error(
                        "quest_parse_error",
                        quest_id=quest_data.get("quest_id"),
                        error=str(e)
                    )
            
            self.log.info("quests_loaded", count=len(self.quests))
        except Exception as e:
            self.log.error("quest_data_load_error", error=str(e))
    
    def _parse_quest(self, data: dict) -> Quest:
        """Parse quest data into Quest model"""
        objectives = [QuestObjective(**obj) for obj in data.get("objectives", [])]
        requirements = [QuestRequirement(**req) for req in data.get("requirements", [])]
        rewards = [QuestReward(**rwd) for rwd in data.get("rewards", [])]
        
        return Quest(
            quest_id=data["quest_id"],
            quest_name=data["quest_name"],
            quest_type=QuestType(data["quest_type"]),
            description=data.get("description", ""),
            objectives=objectives,
            requirements=requirements,
            rewards=rewards,
            min_level=data.get("min_level", 1),
            max_level=data.get("max_level", 999),
            job_requirements=data.get("job_requirements", []),
            base_exp_reward=data.get("base_exp_reward", 0),
            job_exp_reward=data.get("job_exp_reward", 0),
            zeny_reward=data.get("zeny_reward", 0),
            is_daily=data.get("is_daily", False),
            is_repeatable=data.get("is_repeatable", False),
            cooldown_hours=data.get("cooldown_hours", 24),
            start_npc=data.get("start_npc"),
            start_map=data.get("start_map"),
            end_npc=data.get("end_npc"),
            end_map=data.get("end_map"),
        )
    
    def get_quest(self, quest_id: int) -> Optional[Quest]:
        """Get quest by ID"""
        return self.active_quests.get(quest_id) or self.quests.get(quest_id)
    
    def get_active_quests(self) -> List[Quest]:
        """Get all active quests"""
        return list(self.active_quests.values())
    
    def get_available_quests(self, character_state) -> List[Quest]:
        """Get quests available for character (accepts dict or CharacterState)"""
        available = []
        
        # Handle both dict and CharacterState objects
        if isinstance(character_state, dict):
            level = character_state.get("level", 1)
            job = character_state.get("job", "Novice")
        else:
            # CharacterState object
            level = getattr(character_state, 'base_level', 1)
            job = getattr(character_state, 'job_class', 'Novice')
        
        for quest in self.quests.values():
            if quest.quest_id in self.active_quests:
                continue
            if quest.quest_id in self.completed_quests and not quest.is_repeatable:
                continue
            if not (quest.min_level <= level <= quest.max_level):
                continue
            if quest.job_requirements and job not in quest.job_requirements:
                continue
            if not self._check_requirements(quest, character_state):
                continue
            if quest.get_cooldown_remaining():
                continue
            
            available.append(quest)
        
        return available
    
    def _check_requirements(self, quest: Quest, character_state) -> bool:
        """Check if character meets quest requirements (accepts dict or CharacterState)"""
        # Handle both dict and CharacterState objects
        def get_value(key: str, default=None):
            if isinstance(character_state, dict):
                return character_state.get(key, default)
            else:
                # Map keys to CharacterState attributes
                attr_map = {
                    "level": "base_level",
                    "job_level": "job_level",
                    "job": "job_class"
                }
                attr_name = attr_map.get(key, key)
                return getattr(character_state, attr_name, default)
        
        for req in quest.requirements:
            if req.requirement_type == "quest":
                if req.requirement_id not in self.completed_quests:
                    return False
            elif req.requirement_type == "level":
                if get_value("level", 1) < req.required_value:
                    return False
            elif req.requirement_type == "job_level":
                if get_value("job_level", 1) < req.required_value:
                    return False
            elif req.requirement_type == "job":
                if get_value("job") != req.required_value:
                    return False
        return True
    
    def start_quest(self, quest_id: int) -> bool:
        """Start a quest"""
        quest = self.quests.get(quest_id)
        if not quest:
            self.log.error("quest_not_found", quest_id=quest_id)
            return False
        
        if not quest.can_start:
            self.log.warning("quest_cannot_start", quest_id=quest_id, status=quest.status)
            return False
        
        quest.status = QuestStatus.IN_PROGRESS
        self.active_quests[quest_id] = quest
        self.log.info("quest_started", quest_id=quest_id, name=quest.quest_name)
        return True
    
    def update_objective(self, quest_id: int, objective_id: int, progress: int) -> bool:
        """Update quest objective progress"""
        quest = self.active_quests.get(quest_id)
        if not quest:
            return False
        
        for obj in quest.objectives:
            if obj.objective_id == objective_id:
                obj.update_progress(progress)
                self.log.debug(
                    "objective_updated",
                    quest_id=quest_id,
                    objective_id=objective_id,
                    progress=f"{obj.current_count}/{obj.required_count}"
                )
                
                if quest.is_complete:
                    quest.status = QuestStatus.COMPLETED
                    self.log.info("quest_ready_complete", quest_id=quest_id)
                
                return True
        
        return False
    
    def complete_quest(self, quest_id: int) -> List[QuestReward]:
        """Complete a quest and get rewards"""
        quest = self.active_quests.get(quest_id)
        if not quest:
            return []
        
        if not quest.is_complete:
            self.log.warning("quest_not_complete", quest_id=quest_id)
            return []
        
        quest.status = QuestStatus.COMPLETED
        quest.last_completed = datetime.now()
        self.completed_quests.append(quest_id)
        del self.active_quests[quest_id]
        
        self.log.info("quest_completed", quest_id=quest_id, name=quest.quest_name)
        return quest.rewards
    
    def abandon_quest(self, quest_id: int) -> bool:
        """Abandon an active quest"""
        quest = self.active_quests.get(quest_id)
        if not quest:
            return False
        
        quest.status = QuestStatus.FAILED
        del self.active_quests[quest_id]
        self.log.info("quest_abandoned", quest_id=quest_id)
        return True
    
    def check_quest_requirements(
        self,
        quest_id: int,
        character_state: dict
    ) -> Tuple[bool, List[str]]:
        """Check if character meets quest requirements"""
        quest = self.quests.get(quest_id)
        if not quest:
            return False, ["Quest not found"]
        
        missing = []
        level = character_state.get("level", 1)
        
        if level < quest.min_level:
            missing.append(f"Level {quest.min_level} required (current: {level})")
        if level > quest.max_level:
            missing.append(f"Level too high (max: {quest.max_level}, current: {level})")
        
        job = character_state.get("job", "Novice")
        if quest.job_requirements and job not in quest.job_requirements:
            missing.append(f"Job requirement: {', '.join(quest.job_requirements)}")
        
        for req in quest.requirements:
            if req.requirement_type == "quest":
                if req.requirement_id not in self.completed_quests:
                    missing.append(f"Complete quest: {req.requirement_name}")
            elif req.requirement_type == "level":
                if level < req.required_value:
                    missing.append(f"Level {req.required_value} required")
            elif req.requirement_type == "job_level":
                job_level = character_state.get("job_level", 1)
                if job_level < req.required_value:
                    missing.append(f"Job level {req.required_value} required")
        
        return len(missing) == 0, missing
    
    def get_recommended_quests(
        self,
        character_state: dict,
        limit: int = 5
    ) -> List[Quest]:
        """Get recommended quests for character"""
        available = self.get_available_quests(character_state)
        if not available:
            return []
        
        def priority_score(q: Quest) -> float:
            score = 0.0
            if q.is_daily:
                score += 100.0
            score += (q.base_exp_reward + q.job_exp_reward) * 0.001
            score += q.zeny_reward * 0.01
            return score
        
        available.sort(key=priority_score, reverse=True)
        return available[:limit]
    
    async def tick(self, game_state=None) -> list:
        """
        Perform periodic tick processing for quest management.
        
        Args:
            game_state: Optional game state for context
            
        Checks:
        - Quest time limits
        - Daily quest resets
        - Objective auto-completion detection
        
        Returns:
            List of actions to perform
        """
        current_time = datetime.now()
        actions = []
        
        # Check for expired quests
        for quest in list(self.active_quests.values()):
            if quest.expires_at and current_time > quest.expires_at:
                self.log.warning("quest_expired", quest_id=quest.quest_id)
                quest.status = QuestStatus.FAILED
                del self.active_quests[quest.quest_id]
        
        # Check for ready-to-complete quests
        for quest in self.active_quests.values():
            if quest.is_complete and quest.status != QuestStatus.COMPLETED:
                self.log.info("quest_ready_for_completion", quest_id=quest.quest_id)
        
        return actions
    
    async def accept_quest(self, quest_id: str | int) -> bool:
        """Accept a quest by ID or name."""
        # Try as int first
        try:
            qid = int(quest_id) if isinstance(quest_id, str) and quest_id.isdigit() else quest_id
            return self.start_quest(qid)
        except (ValueError, TypeError):
            # Try finding by name
            for quest in self.quests.values():
                if quest.quest_name.lower() == str(quest_id).lower():
                    return self.start_quest(quest.quest_id)
        return False