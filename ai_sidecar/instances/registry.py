"""
Instance Registry System.

Manages instance definitions, requirements, and provides lookup capabilities
for all Memorial Dungeons and Endless Tower in Ragnarok Online.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class InstanceType(str, Enum):
    """Types of instances in RO."""
    
    MEMORIAL_DUNGEON = "memorial_dungeon"
    ENDLESS_TOWER = "endless_tower"
    GUILD_DUNGEON = "guild_dungeon"
    EVENT_INSTANCE = "event_instance"
    PARTY_INSTANCE = "party_instance"
    SOLO_INSTANCE = "solo_instance"
    INFINITE_DUNGEON = "infinite_dungeon"


class InstanceDifficulty(str, Enum):
    """Difficulty levels."""
    
    EASY = "easy"
    NORMAL = "normal"
    HARD = "hard"
    NIGHTMARE = "nightmare"
    HELL = "hell"


class InstanceRequirement(BaseModel):
    """Requirements to enter an instance."""
    
    model_config = ConfigDict(frozen=True)
    
    min_level: int = Field(default=1, ge=1, le=999)
    max_level: Optional[int] = Field(default=None, ge=1, le=999)
    required_quest: Optional[str] = None
    required_item: Optional[str] = None
    required_job_classes: List[str] = Field(default_factory=list)
    min_party_size: int = Field(default=1, ge=1, le=12)
    max_party_size: int = Field(default=12, ge=1, le=12)
    guild_required: bool = False
    rebirth_required: bool = False


class InstanceReward(BaseModel):
    """Possible rewards from an instance."""
    
    model_config = ConfigDict(frozen=True)
    
    guaranteed_items: List[str] = Field(default_factory=list)
    chance_items: Dict[str, float] = Field(default_factory=dict)
    experience_base: int = Field(default=0, ge=0)
    experience_job: int = Field(default=0, ge=0)
    zeny: int = Field(default=0, ge=0)
    instance_points: int = Field(default=0, ge=0)


class InstanceDefinition(BaseModel):
    """Full instance definition."""
    
    model_config = ConfigDict(frozen=True)
    
    instance_id: str
    instance_name: str
    instance_type: InstanceType
    difficulty: InstanceDifficulty
    
    # Entry info
    entry_npc: str
    entry_map: str
    entry_position: tuple[int, int]
    
    # Instance mechanics
    time_limit_minutes: int = Field(default=60, ge=1)
    cooldown_hours: int = Field(default=24, ge=0)
    floors: int = Field(default=1, ge=1)
    
    # Requirements
    requirements: InstanceRequirement = Field(default_factory=InstanceRequirement)
    
    # Rewards
    rewards: InstanceReward = Field(default_factory=InstanceReward)
    boss_names: List[str] = Field(default_factory=list)
    
    # Strategy info
    recommended_level: int = Field(default=99, ge=1, le=999)
    recommended_party_size: int = Field(default=1, ge=1, le=12)
    estimated_clear_time_minutes: int = Field(default=30, ge=1)


class InstanceRegistry:
    """
    Registry of all known instances.
    
    Features:
    - Instance lookup by various criteria
    - Requirement checking
    - Cooldown tracking
    - Recommended instances based on character
    """
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize instance registry.
        
        Args:
            data_dir: Directory containing instance data files
        """
        self.log = structlog.get_logger(__name__)
        self.instances: Dict[str, InstanceDefinition] = {}
        
        if data_dir:
            self._load_instances(data_dir)
        
        self.log.info("InstanceRegistry initialized", count=len(self.instances))
    
    def _load_instances(self, data_dir: Path) -> None:
        """
        Load instance definitions from JSON file.
        
        Args:
            data_dir: Directory containing instances.json
        """
        instances_file = data_dir / "instances.json"
        
        if not instances_file.exists():
            self.log.warning(
                "Instances data file not found",
                path=str(instances_file)
            )
            return
        
        try:
            with open(instances_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            for instance_id, instance_data in data.items():
                # Parse nested objects
                if "requirements" in instance_data:
                    instance_data["requirements"] = InstanceRequirement(
                        **instance_data["requirements"]
                    )
                
                if "rewards" in instance_data:
                    instance_data["rewards"] = InstanceReward(
                        **instance_data["rewards"]
                    )
                
                # Create definition
                definition = InstanceDefinition(
                    instance_id=instance_id,
                    **instance_data
                )
                self.instances[instance_id] = definition
            
            self.log.info(
                "Loaded instance definitions",
                count=len(self.instances),
                file=str(instances_file)
            )
            
        except Exception as e:
            self.log.error(
                "Failed to load instances",
                error=str(e),
                path=str(instances_file)
            )
    
    async def get_instance(self, instance_id: str) -> Optional[InstanceDefinition]:
        """
        Get instance by ID.
        
        Args:
            instance_id: Instance identifier
            
        Returns:
            Instance definition or None if not found
        """
        return self.instances.get(instance_id)
    
    async def find_instances_by_level(
        self,
        level: int
    ) -> List[InstanceDefinition]:
        """
        Find instances appropriate for a level.
        
        Args:
            level: Character level
            
        Returns:
            List of suitable instances
        """
        suitable = []
        
        for instance in self.instances.values():
            req = instance.requirements
            
            # Check level requirements
            if level < req.min_level:
                continue
            
            if req.max_level and level > req.max_level:
                continue
            
            # Prefer instances within 10 levels of recommended
            if abs(level - instance.recommended_level) <= 10:
                suitable.append(instance)
        
        # Sort by recommended level proximity
        suitable.sort(key=lambda i: abs(level - i.recommended_level))
        
        return suitable
    
    async def find_instances_by_type(
        self,
        instance_type: InstanceType
    ) -> List[InstanceDefinition]:
        """
        Find instances by type.
        
        Args:
            instance_type: Type of instance
            
        Returns:
            List of matching instances
        """
        return [
            instance for instance in self.instances.values()
            if instance.instance_type == instance_type
        ]
    
    async def check_requirements(
        self,
        instance_id: str,
        character_state: Dict[str, Any]
    ) -> tuple[bool, List[str]]:
        """
        Check if character meets requirements.
        
        Args:
            instance_id: Instance to check
            character_state: Character state dict
            
        Returns:
            Tuple of (can_enter, list_of_missing_requirements)
        """
        instance = await self.get_instance(instance_id)
        if not instance:
            return False, [f"Unknown instance: {instance_id}"]
        
        missing: List[str] = []
        req = instance.requirements
        
        # Check level
        char_level = character_state.get("base_level", 1)
        if char_level < req.min_level:
            missing.append(
                f"Level too low (need {req.min_level}, have {char_level})"
            )
        
        if req.max_level and char_level > req.max_level:
            missing.append(
                f"Level too high (max {req.max_level}, have {char_level})"
            )
        
        # Check job class
        if req.required_job_classes:
            char_job = character_state.get("job_class", "").lower()
            valid_jobs = [j.lower() for j in req.required_job_classes]
            if char_job not in valid_jobs:
                missing.append(
                    f"Wrong job class (need one of: {', '.join(req.required_job_classes)})"
                )
        
        # Check rebirth
        if req.rebirth_required:
            is_rebirth = character_state.get("is_rebirth", False)
            if not is_rebirth:
                missing.append("Rebirth required")
        
        # Check quest completion
        if req.required_quest:
            completed_quests = character_state.get("completed_quests", [])
            if req.required_quest not in completed_quests:
                missing.append(f"Quest required: {req.required_quest}")
        
        # Check required item
        if req.required_item:
            inventory = character_state.get("inventory", [])
            has_item = any(
                item.get("name") == req.required_item
                for item in inventory
            )
            if not has_item:
                missing.append(f"Item required: {req.required_item}")
        
        # Check party size
        party_size = character_state.get("party_size", 1)
        if party_size < req.min_party_size:
            missing.append(
                f"Party too small (need {req.min_party_size}, have {party_size})"
            )
        
        if party_size > req.max_party_size:
            missing.append(
                f"Party too large (max {req.max_party_size}, have {party_size})"
            )
        
        # Check guild
        if req.guild_required:
            guild_id = character_state.get("guild_id")
            if not guild_id:
                missing.append("Must be in a guild")
        
        can_enter = len(missing) == 0
        return can_enter, missing
    
    async def get_recommended_instances(
        self,
        character_state: Dict[str, Any],
        cooldowns: Optional[Dict[str, bool]] = None
    ) -> List[InstanceDefinition]:
        """
        Get recommended instances based on character state.
        
        Args:
            character_state: Character state dict
            cooldowns: Dict of instance_id -> is_on_cooldown
            
        Returns:
            List of recommended instances (sorted by priority)
        """
        char_level = character_state.get("base_level", 1)
        party_size = character_state.get("party_size", 1)
        gear_score = character_state.get("gear_score", 0)
        
        cooldowns = cooldowns or {}
        recommendations: List[tuple[InstanceDefinition, float]] = []
        
        for instance in self.instances.values():
            # Skip if on cooldown
            if cooldowns.get(instance.instance_id, False):
                continue
            
            # Check if can enter
            can_enter, missing = await self.check_requirements(
                instance.instance_id,
                character_state
            )
            if not can_enter:
                continue
            
            # Calculate recommendation score
            score = 0.0
            
            # Level appropriateness (0-40 points)
            level_diff = abs(char_level - instance.recommended_level)
            level_score = max(0, 40 - level_diff * 2)
            score += level_score
            
            # Party size match (0-20 points)
            party_diff = abs(party_size - instance.recommended_party_size)
            party_score = max(0, 20 - party_diff * 5)
            score += party_score
            
            # Difficulty match with gear (0-20 points)
            difficulty_scores = {
                InstanceDifficulty.EASY: 10,
                InstanceDifficulty.NORMAL: 15,
                InstanceDifficulty.HARD: 20,
                InstanceDifficulty.NIGHTMARE: 15,
                InstanceDifficulty.HELL: 10,
            }
            if gear_score >= 8000:
                difficulty_scores[InstanceDifficulty.HELL] = 20
                difficulty_scores[InstanceDifficulty.NIGHTMARE] = 18
            elif gear_score >= 5000:
                difficulty_scores[InstanceDifficulty.HARD] = 20
                difficulty_scores[InstanceDifficulty.NIGHTMARE] = 15
            
            score += difficulty_scores.get(instance.difficulty, 10)
            
            # Reward value (0-20 points)
            reward_value = (
                len(instance.rewards.guaranteed_items) * 5 +
                instance.rewards.instance_points / 10
            )
            score += min(20, reward_value)
            
            recommendations.append((instance, score))
        
        # Sort by score descending
        recommendations.sort(key=lambda x: x[1], reverse=True)
        
        return [instance for instance, score in recommendations[:10]]
    
    def get_all_instances(self) -> List[InstanceDefinition]:
        """
        Get all registered instances.
        
        Returns:
            List of all instance definitions
        """
        return list(self.instances.values())
    
    def get_instance_count(self) -> int:
        """
        Get total number of registered instances.
        
        Returns:
            Count of instances
        """
        return len(self.instances)