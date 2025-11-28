"""
Quest, achievement, and daily quest systems for OpenKore AI.

This package provides comprehensive quest management including:
- Core quest tracking and management
- Daily quest systems (Gramps, Eden, Board)
- Achievement tracking and rewards
- Hunting quest optimization
- Integrated quest coordination

Example:
    from ai_sidecar.quests import QuestCoordinator
    
    coordinator = QuestCoordinator(data_dir)
    await coordinator.update(character_state)
    next_action = await coordinator.get_next_quest_action(character_state, current_map)
"""

from ai_sidecar.quests.core import (
    Quest,
    QuestManager,
    QuestObjective,
    QuestObjectiveType,
    QuestRequirement,
    QuestReward,
    QuestStatus,
    QuestType,
)
from ai_sidecar.quests.daily import (
    BoardQuest,
    DailyQuestCategory,
    DailyQuestManager,
    EdenQuest,
    GrampsQuest,
)
from ai_sidecar.quests.achievements import (
    Achievement,
    AchievementCategory,
    AchievementManager,
    AchievementTier,
)
from ai_sidecar.quests.hunting import (
    HuntingQuest,
    HuntingQuestManager,
    HuntingTarget,
)
from ai_sidecar.quests.coordinator import QuestCoordinator

__all__ = [
    # Core quest system
    "Quest",
    "QuestManager",
    "QuestObjective",
    "QuestObjectiveType",
    "QuestRequirement",
    "QuestReward",
    "QuestStatus",
    "QuestType",
    # Daily quests
    "BoardQuest",
    "DailyQuestCategory",
    "DailyQuestManager",
    "EdenQuest",
    "GrampsQuest",
    # Achievements
    "Achievement",
    "AchievementCategory",
    "AchievementManager",
    "AchievementTier",
    # Hunting quests
    "HuntingQuest",
    "HuntingQuestManager",
    "HuntingTarget",
    # Coordinator
    "QuestCoordinator",
]