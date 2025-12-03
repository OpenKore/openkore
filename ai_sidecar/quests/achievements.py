"""
Achievement system for OpenKore AI.

Manages achievement tracking, title rewards, achievement points,
and completion recommendations based on character progress.
"""

import json
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class AchievementCategory(str, Enum):
    """Achievement categories"""
    ADVENTURE = "adventure"
    BATTLE = "battle"
    COLLECTION = "collection"
    SOCIAL = "social"
    JOB = "job"
    SPECIAL = "special"


class AchievementTier(str, Enum):
    """Achievement tiers"""
    BRONZE = "bronze"
    SILVER = "silver"
    GOLD = "gold"
    PLATINUM = "platinum"


class Achievement(BaseModel):
    """Achievement definition"""
    
    model_config = ConfigDict(frozen=False)
    
    achievement_id: int
    achievement_name: str
    category: AchievementCategory
    tier: AchievementTier
    description: str
    
    # Progress
    target_value: int
    current_value: int = 0
    is_complete: bool = False
    completed_at: Optional[datetime] = None
    
    # Rewards
    title_reward: Optional[str] = None
    item_rewards: List[Tuple[int, int]] = Field(default_factory=list)  # (item_id, quantity)
    achievement_points: int = 0
    
    @property
    def progress_percent(self) -> float:
        """Calculate progress percentage"""
        if self.target_value == 0:
            return 100.0
        return min(100.0, (self.current_value / self.target_value) * 100)
    
    def update_progress(self, value: int) -> bool:
        """
        Update achievement progress.
        
        Args:
            value: New progress value
            
        Returns:
            True if achievement completed
        """
        self.current_value = value
        if self.current_value >= self.target_value and not self.is_complete:
            self.is_complete = True
            self.completed_at = datetime.now()
            return True
        return False
    
    def add_progress(self, amount: int) -> bool:
        """
        Add to achievement progress.
        
        Args:
            amount: Amount to add
            
        Returns:
            True if achievement completed
        """
        return self.update_progress(self.current_value + amount)


class AchievementManager:
    """
    Manage achievement tracking and rewards.
    
    Features:
    - Progress tracking
    - Title management
    - Achievement point calculation
    - Completion recommendations
    """
    
    def __init__(self, data_dir: Path | None = None, data_path: Path | None = None):
        """
        Initialize achievement manager.
        
        Args:
            data_dir: Directory containing achievement data
            data_path: Alias for data_dir (backwards compatibility)
        """
        self.log = logger.bind(component="achievements")
        # Support both parameters for backwards compatibility
        final_data_dir = data_dir or data_path or Path("data/achievements")
        self.data_dir = Path(final_data_dir)
        self.achievements: Dict[int, Achievement] = {}
        self.completed_achievements: List[int] = []
        self.total_points: int = 0
        self.unlocked_titles: List[str] = []
        self._load_achievement_data()
    
    @property
    def _achievements(self) -> Dict[int, Achievement]:
        """Backwards compatibility alias for achievements."""
        return self.achievements
    
    def _load_achievement_data(self) -> None:
        """Load achievement definitions from data files"""
        achievement_file = self.data_dir / "achievements.json"
        if not achievement_file.exists():
            self.log.warning("achievement_data_missing", file=str(achievement_file))
            return
        
        try:
            with open(achievement_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for ach_data in data.get("achievements", []):
                try:
                    achievement = Achievement(
                        achievement_id=ach_data["achievement_id"],
                        achievement_name=ach_data["achievement_name"],
                        category=AchievementCategory(ach_data["category"]),
                        tier=AchievementTier(ach_data["tier"]),
                        description=ach_data["description"],
                        target_value=ach_data["target_value"],
                        title_reward=ach_data.get("title_reward"),
                        item_rewards=ach_data.get("item_rewards", []),
                        achievement_points=ach_data.get("achievement_points", 0)
                    )
                    self.achievements[achievement.achievement_id] = achievement
                except Exception as e:
                    self.log.error(
                        "achievement_parse_error",
                        achievement_id=ach_data.get("achievement_id"),
                        error=str(e)
                    )
            
            self.log.info("achievements_loaded", count=len(self.achievements))
        except Exception as e:
            self.log.error("achievement_data_load_error", error=str(e))
    
    def get_achievement(self, achievement_id: int) -> Optional[Achievement]:
        """
        Get achievement by ID.
        
        Args:
            achievement_id: Achievement ID
            
        Returns:
            Achievement or None
        """
        return self.achievements.get(achievement_id)
    
    def get_achievements_by_category(
        self, 
        category: AchievementCategory
    ) -> List[Achievement]:
        """
        Get all achievements in category.
        
        Args:
            category: Achievement category
            
        Returns:
            List of achievements
        """
        return [
            ach for ach in self.achievements.values()
            if ach.category == category
        ]
    
    def update_progress(self, achievement_id: int, value: int) -> bool:
        """
        Update achievement progress.
        
        Args:
            achievement_id: Achievement ID
            value: New progress value
            
        Returns:
            True if achievement completed
        """
        achievement = self.achievements.get(achievement_id)
        if not achievement:
            return False
        
        completed = achievement.update_progress(value)
        
        if completed:
            self.log.info(
                "achievement_completed",
                achievement_id=achievement_id,
                name=achievement.achievement_name
            )
            self.completed_achievements.append(achievement_id)
            self.total_points += achievement.achievement_points
            
            if achievement.title_reward:
                self.unlocked_titles.append(achievement.title_reward)
        
        return completed
    
    def add_progress(self, achievement_id: int, amount: int) -> bool:
        """
        Add to achievement progress.
        
        Args:
            achievement_id: Achievement ID
            amount: Amount to add
            
        Returns:
            True if achievement completed
        """
        achievement = self.achievements.get(achievement_id)
        if not achievement:
            return False
        
        return self.update_progress(
            achievement_id,
            achievement.current_value + amount
        )
    
    async def track_progress(self, achievement_id: int | str, value: int) -> bool:
        """
        Track/update achievement progress (alias for add_progress).
        
        Args:
            achievement_id: Achievement ID (int or string that parses to int)
            value: Amount to add
            
        Returns:
            True if achievement completed
        """
        # Convert string ID to int if needed
        try:
            aid = int(achievement_id) if isinstance(achievement_id, str) else achievement_id
        except (ValueError, TypeError):
            # Invalid ID - log and return False
            self.log.warning("invalid_achievement_id", achievement_id=achievement_id)
            return False
        
        return self.add_progress(aid, value)
    
    async def check_completion(self, achievement_id: int | None = None) -> bool:
        """
        Check if achievement is complete or check all achievements.
        
        Args:
            achievement_id: Achievement ID (None to check all)
            
        Returns:
            True if complete (or if any complete when checking all)
        """
        if achievement_id is None:
            # Check all achievements
            return any(ach.is_complete for ach in self.achievements.values())
        
        achievement = self.achievements.get(achievement_id)
        return achievement.is_complete if achievement else False
    
    def claim_rewards(self, achievement_id: int) -> List[Tuple[str, Any]]:
        """
        Claim achievement rewards.
        
        Args:
            achievement_id: Achievement ID
            
        Returns:
            List of rewards (reward_type, reward_value)
        """
        achievement = self.achievements.get(achievement_id)
        if not achievement or not achievement.is_complete:
            return []
        
        rewards = []
        
        if achievement.title_reward:
            rewards.append(("title", achievement.title_reward))
        
        for item_id, quantity in achievement.item_rewards:
            rewards.append(("item", (item_id, quantity)))
        
        if achievement.achievement_points > 0:
            rewards.append(("points", achievement.achievement_points))
        
        self.log.info(
            "rewards_claimed",
            achievement_id=achievement_id,
            rewards=len(rewards)
        )
        
        return rewards
    
    def get_near_completion(
        self, 
        threshold_percent: float = 75.0
    ) -> List[Achievement]:
        """
        Get achievements near completion.
        
        Args:
            threshold_percent: Minimum progress percentage
            
        Returns:
            List of near-complete achievements
        """
        near_complete = []
        
        for achievement in self.achievements.values():
            if achievement.is_complete:
                continue
            
            if achievement.progress_percent >= threshold_percent:
                near_complete.append(achievement)
        
        # Sort by progress percentage (descending)
        near_complete.sort(key=lambda a: a.progress_percent, reverse=True)
        
        return near_complete
    
    def get_recommended_achievements(
        self, 
        character_state: dict
    ) -> List[Achievement]:
        """
        Get recommended achievements to pursue.
        
        Args:
            character_state: Character state
            
        Returns:
            List of recommended achievements
        """
        level = character_state.get("level", 1)
        job = character_state.get("job", "Novice")
        
        recommendations = []
        
        # Prioritize near-complete achievements
        near_complete = self.get_near_completion(threshold_percent=50.0)
        recommendations.extend(near_complete[:3])
        
        # Add level-appropriate achievements
        for achievement in self.achievements.values():
            if achievement.is_complete:
                continue
            if achievement in recommendations:
                continue
            
            # Simple level-based filtering (can be enhanced)
            if achievement.category == AchievementCategory.BATTLE:
                if level >= 30:  # Combat achievements for higher levels
                    recommendations.append(achievement)
            elif achievement.category == AchievementCategory.ADVENTURE:
                if level >= 20:  # Exploration achievements
                    recommendations.append(achievement)
            
            if len(recommendations) >= 10:
                break
        
        return recommendations[:10]
    
    def calculate_completion_rate(self) -> float:
        """
        Calculate overall achievement completion rate.
        
        Returns:
            Completion percentage
        """
        if not self.achievements:
            return 0.0
        
        completed_count = sum(1 for a in self.achievements.values() if a.is_complete)
        return (completed_count / len(self.achievements)) * 100
    
    def get_completion_by_category(self) -> Dict[str, float]:
        """
        Get completion rate by category.
        
        Returns:
            Dictionary of category completion rates
        """
        category_stats = {}
        
        for category in AchievementCategory:
            category_achievements = self.get_achievements_by_category(category)
            if not category_achievements:
                continue
            
            completed = sum(1 for a in category_achievements if a.is_complete)
            rate = (completed / len(category_achievements)) * 100
            category_stats[category.value] = rate
        
        return category_stats
    
    def get_statistics(self) -> dict:
        """
        Get achievement statistics.
        
        Returns:
            Dictionary of achievement stats
        """
        total_achievements = len(self.achievements)
        completed_count = len(self.completed_achievements)
        
        return {
            "total_achievements": total_achievements,
            "completed": completed_count,
            "incomplete": total_achievements - completed_count,
            "completion_rate": self.calculate_completion_rate(),
            "total_points": self.total_points,
            "unlocked_titles": len(self.unlocked_titles),
            "by_category": self.get_completion_by_category(),
            "by_tier": self._get_completion_by_tier()
        }
    
    def _get_completion_by_tier(self) -> Dict[str, int]:
        """Get completion count by tier"""
        tier_stats = {tier.value: 0 for tier in AchievementTier}
        
        for achievement in self.achievements.values():
            if achievement.is_complete:
                tier_stats[achievement.tier.value] += 1
        
        return tier_stats
    
    def get_title_list(self) -> List[str]:
        """
        Get list of unlocked titles.
        
        Returns:
            List of title names
        """
        return self.unlocked_titles.copy()
    
    def has_title(self, title: str) -> bool:
        """
        Check if title is unlocked.
        
        Args:
            title: Title name
            
        Returns:
            True if unlocked
        """
        return title in self.unlocked_titles