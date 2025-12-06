"""
Quest suggestion and analysis module.

Provides intelligent quest recommendations based on character
level, job, location, and quest progress.
"""

from typing import TYPE_CHECKING, Optional

from ai_sidecar.npc.quest_models import Quest, QuestLog, QuestObjectiveType
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.npc.quest_db_loader import QuestDatabaseLoader
    from ai_sidecar.npc.quest_models import QuestDatabase

logger = get_logger(__name__)


class QuestSuggestionEngine:
    """
    Provides intelligent quest suggestions and analysis.
    
    Separates suggestion logic from core quest management
    for cleaner architecture and maintainability.
    """
    
    def __init__(
        self,
        quest_db: "QuestDatabase",
        quest_log: QuestLog,
        loader: "QuestDatabaseLoader"
    ) -> None:
        """
        Initialize suggestion engine.
        
        Args:
            quest_db: Quest database reference
            quest_log: Player quest log reference
            loader: Quest database loader reference
        """
        self.quest_db = quest_db
        self.quest_log = quest_log
        self._loader = loader
    
    def check_prerequisites(
        self,
        quest_id: int,
        level: int,
        job: str,
        completed_quests: Optional[set[int]] = None
    ) -> tuple[bool, list[str]]:
        """
        Check if a quest's prerequisites are met.
        
        Args:
            quest_id: Quest to check
            level: Current character level
            job: Current job class
            completed_quests: Set of completed quest IDs (uses quest_log if None)
            
        Returns:
            Tuple of (all_met: bool, unmet_reasons: list[str])
        """
        quest = self.quest_db.get_quest(quest_id)
        if not quest:
            return False, [f"Quest {quest_id} not found in database"]
        
        unmet_reasons: list[str] = []
        
        # Check level requirement
        if level < quest.min_level:
            unmet_reasons.append(f"Level {quest.min_level} required (current: {level})")
        
        if level > quest.max_level:
            unmet_reasons.append(f"Level too high (max: {quest.max_level})")
        
        # Check job requirement
        if quest.required_job and quest.required_job.lower() != job.lower():
            unmet_reasons.append(f"Job '{quest.required_job}' required (current: {job})")
        
        # Check prerequisite quests
        completed = completed_quests or set(self.quest_log.completed_quests)
        for prereq_id in quest.prerequisite_quests:
            if prereq_id not in completed:
                prereq_quest = self.quest_db.get_quest(prereq_id)
                prereq_name = prereq_quest.name if prereq_quest else f"Quest {prereq_id}"
                unmet_reasons.append(f"Prerequisite not completed: {prereq_name}")
        
        # Check if already active
        if self.quest_log.get_quest(quest_id):
            unmet_reasons.append("Quest already active")
        
        # Check if already completed (non-repeatable)
        if not quest.is_repeatable and quest_id in completed:
            unmet_reasons.append("Quest already completed (non-repeatable)")
        
        all_met = len(unmet_reasons) == 0
        
        if not all_met:
            logger.debug(
                f"Quest {quest.name} prerequisites not met",
                quest_id=quest_id,
                reasons=unmet_reasons
            )
        
        return all_met, unmet_reasons
    
    def suggest_next_quests(
        self,
        level: int,
        job: str,
        available_quests: list[Quest],
        map_name: Optional[str] = None,
        max_suggestions: int = 5
    ) -> list[tuple[Quest, float]]:
        """
        Suggest next quests based on level, job, and optionally location.
        
        Returns quests sorted by relevance score.
        
        Args:
            level: Current character level
            job: Current job class
            available_quests: Pre-filtered available quests
            map_name: Current map (optional, for proximity bonus)
            max_suggestions: Maximum number of suggestions
            
        Returns:
            List of (quest, relevance_score) tuples, sorted by score descending
        """
        suggestions: list[tuple[Quest, float]] = []
        
        for quest in available_quests:
            score = self._calculate_suggestion_score(quest, level, job, map_name)
            suggestions.append((quest, score))
        
        # Sort by score (descending)
        suggestions.sort(key=lambda x: x[1], reverse=True)
        
        # Log suggestions
        if suggestions:
            logger.debug(
                f"Quest suggestions for level {level} {job}",
                top_suggestions=[
                    {"name": q.name, "score": s}
                    for q, s in suggestions[:max_suggestions]
                ]
            )
        
        return suggestions[:max_suggestions]
    
    def _calculate_suggestion_score(
        self,
        quest: Quest,
        level: int,
        job: str,
        map_name: Optional[str] = None
    ) -> float:
        """
        Calculate relevance score for quest suggestion.
        
        Args:
            quest: Quest to score
            level: Character level
            job: Character job
            map_name: Current map
            
        Returns:
            Relevance score (higher = more relevant)
        """
        score = 50.0  # Base score
        
        # Level appropriateness (higher score if level is in middle of range)
        level_range = quest.max_level - quest.min_level
        if level_range > 0:
            level_position = (level - quest.min_level) / level_range
            # Bonus for being in the middle of the range
            if 0.3 <= level_position <= 0.7:
                score += 20.0
            elif level_position < 0.3:
                score += 10.0  # Slightly underleveled
            else:
                score -= 10.0  # Overleveled
        
        # Quest type bonuses
        quest_type = self._determine_quest_type(quest)
        type_bonuses = {
            "main_story": 30.0,
            "job_change": 25.0,
            "daily": 20.0,
            "eden": 15.0,
            "hunting": 10.0,
        }
        score += type_bonuses.get(quest_type, 0.0)
        
        # Reward value bonus
        total_exp = sum(
            r.amount for r in quest.rewards
            if r.reward_type in ["exp_base", "exp_job"]
        )
        exp_per_level = total_exp / max(1, level)
        if exp_per_level > 1000:
            score += 15.0
        elif exp_per_level > 500:
            score += 10.0
        
        # Chain continuation bonus
        if quest.prerequisite_quests:
            # This quest continues a chain we've started
            score += 10.0
        
        # Daily quest bonus (if not done today)
        if quest.is_daily:
            score += 15.0
        
        return score
    
    def _determine_quest_type(self, quest: Quest) -> str:
        """
        Determine quest type from quest properties.
        
        Args:
            quest: Quest to evaluate
            
        Returns:
            Quest type string
        """
        # Check quest properties
        if quest.is_daily:
            return "daily"
        
        if quest.is_repeatable:
            return "repeatable"
        
        # Check quest name/description for hints
        name_lower = quest.name.lower()
        desc_lower = quest.description.lower()
        
        if any(word in name_lower for word in ["main", "story", "chapter"]):
            return "main_story"
        
        if any(word in name_lower for word in ["side", "optional"]):
            return "side_quest"
        
        if any(word in desc_lower for word in ["collect", "gather", "bring"]):
            return "collection"
        
        if "job" in name_lower and "change" in name_lower:
            return "job_change"
        
        if "eden" in name_lower:
            return "eden"
        
        if any(word in desc_lower for word in ["kill", "hunt", "slay"]):
            return "hunting"
        
        # Default to side quest
        return "side_quest"
    
    def track_objective_progress(
        self,
        quest_id: int,
        objective_type: Optional[QuestObjectiveType] = None
    ) -> dict:
        """
        Get detailed progress tracking for quest objectives.
        
        Args:
            quest_id: Quest to track
            objective_type: Filter by objective type (optional)
            
        Returns:
            Dictionary with progress details
        """
        quest = self.quest_log.get_quest(quest_id)
        if not quest:
            return {"error": f"Quest {quest_id} not in active quests"}
        
        progress = {
            "quest_id": quest_id,
            "quest_name": quest.name,
            "status": quest.status,
            "overall_progress": quest.progress_percent,
            "all_complete": quest.all_objectives_complete,
            "objectives": [],
        }
        
        for obj in quest.objectives:
            if objective_type and obj.objective_type != objective_type:
                continue
            
            obj_progress = {
                "id": obj.objective_id,
                "type": obj.objective_type.value,
                "target_name": obj.target_name,
                "progress": f"{obj.current_count}/{obj.required_count}",
                "percent": (obj.current_count / obj.required_count * 100) if obj.required_count > 0 else 0,
                "completed": obj.completed,
            }
            
            # Add location info if relevant
            if obj.map_name:
                obj_progress["location"] = {
                    "map": obj.map_name,
                    "x": obj.x,
                    "y": obj.y,
                }
            
            progress["objectives"].append(obj_progress)
        
        logger.debug(
            f"Quest progress tracked",
            quest_id=quest_id,
            overall=progress["overall_progress"],
            objectives_complete=sum(1 for o in progress["objectives"] if o["completed"]),
            objectives_total=len(progress["objectives"])
        )
        
        return progress
    
    def get_quest_chain(self, quest_id: int) -> list[Quest]:
        """
        Get all quests in a chain containing the given quest.
        
        Args:
            quest_id: Any quest ID in the chain
            
        Returns:
            Ordered list of quests in the chain
        """
        return self._loader.get_quest_chain(quest_id)