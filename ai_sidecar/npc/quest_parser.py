"""
Quest data parsing module.

Handles parsing of quest definitions from YAML/JSON data,
including validation of quest structures and conversion to models.
"""

from typing import Any, Dict, List, Optional

from pydantic import ValidationError

from ai_sidecar.npc.quest_models import (
    Quest,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
)
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


# Quest type mapping from YAML to internal enum
QUEST_TYPE_MAPPING: Dict[str, str] = {
    "STORY": "story",
    "EPISODE": "episode",
    "JOB_CHANGE": "job_change",
    "EDEN": "eden",
    "DAILY": "daily",
    "REPEATABLE": "repeatable",
    "HUNTING": "hunting",
    "GATHERING": "gathering",
    "ACCESS": "access",
    "HEADGEAR": "headgear",
    "EVENT": "event",
    "TUTORIAL": "tutorial",
    "GRAMPS": "gramps",
    "BOARD": "board",
    "INSTANCE": "instance",
}

# Objective type mapping from YAML to enum
OBJECTIVE_TYPE_MAPPING: Dict[str, QuestObjectiveType] = {
    "kill_monster": QuestObjectiveType.KILL_MONSTER,
    "collect_item": QuestObjectiveType.COLLECT_ITEM,
    "deliver_item": QuestObjectiveType.DELIVER_ITEM,
    "talk_to_npc": QuestObjectiveType.TALK_TO_NPC,
    "visit_location": QuestObjectiveType.VISIT_LOCATION,
    "use_skill": QuestObjectiveType.USE_SKILL,
    "reach_level": QuestObjectiveType.REACH_LEVEL,
}


class QuestParser:
    """
    Parses quest definitions from dictionary data.
    
    Converts raw dictionary data (from YAML/JSON) into
    validated Quest model instances.
    """
    
    def __init__(self) -> None:
        """Initialize parser with stats tracking."""
        self.parse_errors = 0
        self.validation_errors = 0
    
    def reset_stats(self) -> None:
        """Reset parsing statistics."""
        self.parse_errors = 0
        self.validation_errors = 0
    
    def parse_quest_data(
        self,
        data: Dict[str, Any],
        source_file: str
    ) -> Dict[int, Quest]:
        """
        Parse quest data from loaded dictionary.
        
        Args:
            data: Dictionary containing quest data
            source_file: Source file path for logging
            
        Returns:
            Dictionary of parsed quests keyed by quest_id
        """
        quests: Dict[int, Quest] = {}
        
        if not data:
            return quests
        
        # Quest sections to parse
        quest_sections = [
            "eden_group",
            "job_change_first",
            "job_change_second",
            "story_quests",
            "access_quests",
            "daily_quests",
            "headgear_quests",
            "gathering_quests",
            "event_quests",
            "custom_quests",
        ]
        
        for section in quest_sections:
            if section in data:
                quests_list = data[section]
                if isinstance(quests_list, list):
                    for quest_dict in quests_list:
                        quest = self.parse_single_quest(quest_dict, source_file)
                        if quest:
                            quests[quest.quest_id] = quest
        
        # Also check for flat "quests" key
        if "quests" in data and isinstance(data["quests"], list):
            for quest_dict in data["quests"]:
                quest = self.parse_single_quest(quest_dict, source_file)
                if quest:
                    quests[quest.quest_id] = quest
        
        return quests
    
    def parse_single_quest(
        self,
        quest_dict: Dict[str, Any],
        source_file: str
    ) -> Optional[Quest]:
        """
        Parse a single quest definition.
        
        Args:
            quest_dict: Dictionary containing quest definition
            source_file: Source file for logging
            
        Returns:
            Parsed Quest object or None on error
        """
        try:
            quest_id = quest_dict.get("quest_id")
            if not quest_id:
                logger.warning(f"Quest missing ID in {source_file}")
                self.parse_errors += 1
                return None
            
            # Parse objectives
            objectives = []
            for obj_dict in quest_dict.get("objectives", []):
                objective = self.parse_objective(obj_dict)
                if objective:
                    objectives.append(objective)
            
            # Parse rewards
            rewards = []
            for reward_dict in quest_dict.get("rewards", []):
                reward = self.parse_reward(reward_dict)
                if reward:
                    rewards.append(reward)
            
            # Create Quest object
            quest = Quest(
                quest_id=quest_id,
                name=quest_dict.get("name", f"Quest {quest_id}"),
                description=quest_dict.get("description", ""),
                npc_id=quest_dict.get("npc_id", 0),
                npc_name=quest_dict.get("npc_name", "Unknown NPC"),
                prerequisite_quests=quest_dict.get("prerequisite_quests", []),
                next_quests=quest_dict.get("next_quests", []),
                min_level=quest_dict.get("min_level", 1),
                max_level=quest_dict.get("max_level", 999),
                required_job=quest_dict.get("required_job"),
                objectives=objectives,
                rewards=rewards,
                turn_in_npc_id=quest_dict.get("turn_in_npc_id"),
                is_repeatable=quest_dict.get("is_repeatable", False),
                is_daily=quest_dict.get("is_daily", False),
                time_limit_seconds=quest_dict.get("time_limit_seconds"),
            )
            
            logger.debug(f"Parsed quest: {quest.name} (ID: {quest_id})")
            return quest
            
        except ValidationError as e:
            logger.error(f"Quest validation error in {source_file}: {e}")
            self.validation_errors += 1
            return None
        except Exception as e:
            logger.error(
                f"Error parsing quest {quest_dict.get('quest_id', 'unknown')} "
                f"from {source_file}: {e}",
                exc_info=True
            )
            self.parse_errors += 1
            return None
    
    def parse_objective(self, obj_dict: Dict[str, Any]) -> Optional[QuestObjective]:
        """Parse a single quest objective."""
        try:
            obj_type_str = obj_dict.get("objective_type", "")
            obj_type = OBJECTIVE_TYPE_MAPPING.get(
                obj_type_str.lower(),
                QuestObjectiveType.KILL_MONSTER
            )
            
            return QuestObjective(
                objective_id=str(obj_dict.get("objective_id", "")),
                objective_type=obj_type,
                target_id=obj_dict.get("target_id", 0),
                target_name=obj_dict.get("target_name", "Unknown"),
                required_count=obj_dict.get("required_count", 1),
                current_count=0,
                map_name=obj_dict.get("map_name"),
                x=obj_dict.get("x"),
                y=obj_dict.get("y"),
                completed=False,
            )
        except Exception as e:
            logger.warning(f"Error parsing objective: {e}")
            return None
    
    def parse_reward(self, reward_dict: Dict[str, Any]) -> Optional[QuestReward]:
        """Parse a single quest reward."""
        try:
            reward_type = reward_dict.get("reward_type", "item")
            
            # Map reward types
            type_mapping = {
                "exp_base": "exp_base",
                "exp_job": "exp_job",
                "base_exp": "exp_base",
                "job_exp": "exp_job",
                "zeny": "zeny",
                "item": "item",
                "skill_point": "skill_point",
            }
            
            mapped_type = type_mapping.get(reward_type, "item")
            
            return QuestReward(
                reward_type=mapped_type,
                item_id=reward_dict.get("item_id"),
                amount=reward_dict.get("amount", 1),
            )
        except Exception as e:
            logger.warning(f"Error parsing reward: {e}")
            return None


def determine_quest_type(quest: Quest) -> str:
    """
    Determine quest type from properties.
    
    Args:
        quest: Quest to analyze
        
    Returns:
        Quest type string
    """
    name_lower = quest.name.lower()
    desc_lower = quest.description.lower()
    
    if quest.is_daily:
        return "daily"
    if quest.is_repeatable:
        return "repeatable"
    if "job change" in name_lower or "job change" in desc_lower:
        return "job_change"
    if "eden" in name_lower:
        return "eden"
    if "story" in name_lower or "chapter" in name_lower or "main" in name_lower:
        return "story"
    if "access" in name_lower or "unlock" in desc_lower:
        return "access"
    if "headgear" in name_lower or "hat" in name_lower:
        return "headgear"
    if "collect" in desc_lower or "gather" in desc_lower:
        return "gathering"
    if "kill" in desc_lower or "hunt" in desc_lower:
        return "hunting"
    if any(word in name_lower for word in ["christmas", "halloween", "event"]):
        return "event"
    
    return "misc"