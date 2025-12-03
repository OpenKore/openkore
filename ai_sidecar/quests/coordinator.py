"""
Quest coordinator for OpenKore AI.

Main quest coordinator integrating all quest systems:
- Quest Manager
- Daily Quest Manager
- Achievement Manager
- Hunting Quest Manager

Acts as facade for unified quest operations.
"""

from pathlib import Path
from typing import Dict, List, Optional

import structlog

from ai_sidecar.quests.achievements import AchievementManager
from ai_sidecar.quests.core import Quest, QuestManager
from ai_sidecar.quests.daily import DailyQuestManager, DailyQuestCategory
from ai_sidecar.quests.hunting import HuntingQuestManager

logger = structlog.get_logger(__name__)


class QuestCoordinator:
    """
    Main quest coordinator integrating all quest systems.
    
    Acts as facade for:
    - Quest Manager
    - Daily Quest Manager
    - Achievement Manager
    - Hunting Quest Manager
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize quest coordinator.
        
        Args:
            data_dir: Directory containing quest data files
        """
        self.log = logger.bind(component="quest_coordinator")
        
        # Initialize core systems
        self.quests = QuestManager(data_dir)
        self.daily = DailyQuestManager(data_dir, self.quests)
        self.achievements = AchievementManager(data_dir)
        self.hunting = HuntingQuestManager(data_dir, self.quests)
        
        self.log.info("quest_coordinator_initialized")
    
    async def update(self, character_state: dict) -> None:
        """
        Update all quest systems.
        
        Args:
            character_state: Current character state
        """
        try:
            # Check daily reset
            self.daily._check_daily_reset()
            
            # Update quest recommendations based on level/job changes
            level = character_state.get("level", 1)
            job = character_state.get("job", "Novice")
            
            # Check for new available quests
            available = self.quests.get_available_quests(character_state)
            if available:
                self.log.debug(
                    "quests_available",
                    count=len(available),
                    level=level,
                    job=job
                )
        except Exception as e:
            self.log.error("update_error", error=str(e))
    
    def get_all_active_quests(self) -> List[Quest]:
        """
        Get all active quests across systems.
        
        Returns:
            List of all active quests
        """
        return self.quests.get_active_quests()
    
    def get_quest_priorities(self, character_state: dict) -> List[dict]:
        """
        Get prioritized quest list.
        
        Args:
            character_state: Character state
            
        Returns:
            Sorted list of quests by priority
        """
        priorities = []
        
        # Priority 1: Completable quests
        for quest in self.quests.get_active_quests():
            if quest.is_complete:
                priorities.append({
                    "quest": quest,
                    "priority": 1,
                    "reason": "Ready to turn in",
                    "action": "turn_in"
                })
        
        # Priority 2: Daily quests
        daily_quests = self.daily.get_priority_dailies(character_state)
        for daily_info in daily_quests[:3]:  # Top 3 dailies
            priorities.append({
                "quest": daily_info["quest"],
                "priority": 2,
                "reason": f"Daily quest ({daily_info['category'].value})",
                "action": "progress",
                "exp_per_kill": daily_info.get("priority_score", 0)
            })
        
        # Priority 3: In-progress quests
        for quest in self.quests.get_active_quests():
            if not quest.is_complete and quest.overall_progress > 0:
                priorities.append({
                    "quest": quest,
                    "priority": 3,
                    "reason": f"In progress ({quest.overall_progress:.1f}%)",
                    "action": "progress"
                })
        
        # Priority 4: Near-complete achievements
        near_achievements = self.achievements.get_near_completion(threshold_percent=75.0)
        for achievement in near_achievements[:2]:  # Top 2
            priorities.append({
                "achievement": achievement,
                "priority": 4,
                "reason": f"Achievement {achievement.progress_percent:.1f}% complete",
                "action": "achievement_progress"
            })
        
        # Sort by priority
        priorities.sort(key=lambda x: x["priority"])
        return priorities
    
    def get_optimal_activity(
        self, 
        character_state: dict, 
        available_time_minutes: int
    ) -> dict:
        """
        Get optimal activity based on time and quests.
        
        Args:
            character_state: Character state
            available_time_minutes: Available play time
            
        Returns:
            Recommended activity with details
        """
        # Calculate EXP potential from dailies
        daily_exp = self.daily.calculate_daily_exp_potential(character_state)
        
        # Get active hunting quests
        active_hunts = self.hunting.get_active_hunts()
        
        # Short session (< 30 min): Focus on quick dailies
        if available_time_minutes < 30:
            priority_dailies = self.daily.get_priority_dailies(character_state)
            if priority_dailies:
                best_daily = priority_dailies[0]
                return {
                    "activity_type": "daily_quest",
                    "quest": best_daily["quest"],
                    "estimated_time": best_daily["estimated_time_minutes"],
                    "estimated_exp": best_daily["exp_total"],
                    "reason": "Quick daily quest for time available"
                }
        
        # Medium session (30-60 min): Dailies + hunting
        elif available_time_minutes < 60:
            if not self.daily.is_daily_completed(DailyQuestCategory.GRAMPS):
                gramps = self.daily.get_gramps_quest(character_state.get("level", 1))
                if gramps:
                    return {
                        "activity_type": "gramps_quest",
                        "quest": gramps,
                        "estimated_time": 45,
                        "estimated_exp": gramps.exp_reward + gramps.job_exp_reward,
                        "reason": "Gramps quest provides excellent EXP"
                    }
        
        # Long session (60+ min): Optimize for maximum EXP
        else:
            # Check if we have incomplete hunting quests
            if active_hunts:
                hunt = active_hunts[0]
                exp_data = self.hunting.calculate_exp_per_kill(hunt.quest_id)
                best_map, _ = self.hunting.get_best_farming_map(hunt.quest_id)
                
                return {
                    "activity_type": "hunting_quest",
                    "quest": hunt,
                    "estimated_time": available_time_minutes,
                    "estimated_exp": exp_data.get("total_exp", 0),
                    "best_map": best_map,
                    "reason": "Complete hunting quest for rewards"
                }
            
            # Otherwise, do dailies + grinding
            return {
                "activity_type": "daily_routine",
                "estimated_time": available_time_minutes,
                "estimated_exp": daily_exp["total_exp"],
                "activities": ["dailies", "grinding"],
                "reason": "Complete daily quests and grind"
            }
        
        # Default: Just grind
        return {
            "activity_type": "grinding",
            "estimated_time": available_time_minutes,
            "reason": "No active quests, continue grinding"
        }
    
    def record_monster_kill(
        self, 
        monster_id: int, 
        monster_name: str
    ) -> List[dict]:
        """
        Record kill for all applicable quests.
        
        Args:
            monster_id: Killed monster ID
            monster_name: Monster name
            
        Returns:
            List of updated quest info
        """
        updates = []
        
        # Update hunting quests
        affected_hunts = self.hunting.record_kill(monster_id)
        for quest_id in affected_hunts:
            progress = self.hunting.get_hunting_progress(quest_id)
            updates.append({
                "type": "hunting_quest",
                "quest_id": quest_id,
                "progress": progress
            })
        
        # Update achievement progress (e.g., monster kills)
        # Achievement ID for "kill X monsters" would be determined by game data
        
        self.log.debug(
            "monster_kill_recorded",
            monster_id=monster_id,
            monster_name=monster_name,
            updates=len(updates)
        )
        
        return updates
    
    def record_item_collected(
        self, 
        item_id: int, 
        item_name: str, 
        quantity: int
    ) -> List[dict]:
        """
        Record item collection for quests.
        
        Args:
            item_id: Collected item ID
            item_name: Item name
            quantity: Quantity collected
            
        Returns:
            List of updated quest info
        """
        updates = []
        
        # Update quest objectives
        for quest in self.quests.get_active_quests():
            for obj in quest.objectives:
                if obj.target_id == item_id and not obj.is_complete:
                    self.quests.update_objective(
                        quest.quest_id,
                        obj.objective_id,
                        quantity
                    )
                    updates.append({
                        "type": "quest_objective",
                        "quest_id": quest.quest_id,
                        "objective_id": obj.objective_id,
                        "progress": f"{obj.current_count}/{obj.required_count}"
                    })
        
        self.log.debug(
            "item_collected_recorded",
            item_id=item_id,
            item_name=item_name,
            quantity=quantity,
            updates=len(updates)
        )
        
        return updates
    
    async def get_next_quest_action(
        self, 
        character_state: dict,
        current_map: str
    ) -> dict:
        """
        Get next recommended quest action.
        
        Args:
            character_state: Character state
            current_map: Current map name
            
        Returns:
            Recommended action
        """
        # Check for completable quests first
        for quest in self.quests.get_active_quests():
            if quest.is_complete:
                return {
                    "action": "turn_in_quest",
                    "quest_id": quest.quest_id,
                    "quest_name": quest.quest_name,
                    "npc": quest.end_npc or quest.start_npc,
                    "map": quest.end_map or quest.start_map
                }
        
        # Get priority quests
        priorities = self.get_quest_priorities(character_state)
        if not priorities:
            return {
                "action": "no_quests",
                "recommendation": "Accept new quests or continue grinding"
            }
        
        # Get highest priority quest
        top_priority = priorities[0]
        
        if "quest" in top_priority:
            quest = top_priority["quest"]
            # Find next incomplete objective
            for obj in quest.objectives:
                if not obj.is_complete:
                    return {
                        "action": "progress_objective",
                        "quest_id": quest.quest_id,
                        "objective": {
                            "type": obj.objective_type.value,
                            "target": obj.target_name,
                            "progress": f"{obj.current_count}/{obj.required_count}",
                            "map": obj.map_name
                        }
                    }
        
        return {
            "action": "continue",
            "message": "Continue current quest progress"
        }
    
    def calculate_daily_completion_rate(self) -> float:
        """
        Calculate today's daily quest completion rate.
        
        Returns:
            Completion percentage
        """
        return self.daily.get_completion_summary()["completion_rate"]
    
    def get_pending_rewards(self) -> List[dict]:
        """
        Get all unclaimed quest rewards.
        
        Returns:
            List of pending rewards
        """
        pending = []
        
        # Check completed quests
        for quest in self.quests.get_active_quests():
            if quest.is_complete:
                pending.append({
                    "type": "quest",
                    "quest_id": quest.quest_id,
                    "quest_name": quest.quest_name,
                    "rewards": [
                        {
                            "type": r.reward_type,
                            "name": r.reward_name,
                            "quantity": r.quantity
                        }
                        for r in quest.rewards
                    ]
                })
        
        # Check completed achievements
        for achievement in self.achievements.achievements.values():
            if achievement.is_complete:
                rewards = self.achievements.claim_rewards(achievement.achievement_id)
                if rewards:
                    pending.append({
                        "type": "achievement",
                        "achievement_id": achievement.achievement_id,
                        "achievement_name": achievement.achievement_name,
                        "rewards": rewards
                    })
        
        return pending
    
    def get_statistics(self) -> dict:
        """
        Get comprehensive quest statistics.
        
        Returns:
            Dictionary of all quest statistics
        """
        return {
            "active_quests": len(self.quests.get_active_quests()),
            "completed_quests": len(self.quests.completed_quests),
            "daily_completion": self.daily.get_completion_summary(),
            "achievement_stats": self.achievements.get_statistics(),
            "active_hunts": len(self.hunting.get_active_hunts())
        }