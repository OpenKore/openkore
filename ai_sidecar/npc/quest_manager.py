"""
Quest management and tracking system.

Coordinates quest tracking, objective updates, and quest completion logic.
Integrates with the decision engine to suggest quest-related actions.
"""

from pathlib import Path
from typing import TYPE_CHECKING, Optional

from ai_sidecar.core.decision import Action
from ai_sidecar.npc.dialogue_parser import DialogueParser
from ai_sidecar.npc.quest_actions import QuestActionGenerator
from ai_sidecar.npc.quest_db_loader import QuestDatabaseLoader, get_quest_loader
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestDatabase,
    QuestLog,
    QuestObjectiveType,
)
from ai_sidecar.npc.quest_progress import QuestProgressTracker
from ai_sidecar.npc.quest_suggestions import QuestSuggestionEngine
from ai_sidecar.social import config
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class QuestManager:
    """
    Manages quest tracking, objectives, and completion.

    Coordinates all quest-related activities including:
    - Quest acceptance and tracking
    - Objective progress updates
    - Quest turn-in detection
    - Priority calculation for active quests
    - Quest database loading and caching
    - Quest chain tracking
    """

    def __init__(
        self,
        db_path: Optional[Path] = None,
        custom_quest_paths: Optional[list[Path]] = None,
        auto_load: bool = True
    ) -> None:
        """
        Initialize quest manager.
        
        Args:
            db_path: Path to quest database directory
            custom_quest_paths: Additional paths for custom server quests
            auto_load: Whether to auto-load quest database on init
        """
        self.quest_log = QuestLog()
        self.dialogue_parser = DialogueParser()
        
        # Initialize quest database loader
        self._loader = get_quest_loader(
            db_path=db_path,
            custom_paths=custom_quest_paths
        )
        
        # Load quest database
        if auto_load:
            self.quest_db = self._loader.load_all()
        else:
            self.quest_db = QuestDatabase()
        
        # Initialize sub-modules
        self._progress_tracker = QuestProgressTracker(self.quest_log)
        self._action_generator = QuestActionGenerator(self.quest_log)
        self._suggestion_engine = QuestSuggestionEngine(
            self.quest_db,
            self.quest_log,
            self._loader
        )

        logger.info(
            "Quest manager initialized",
            quests_loaded=len(self.quest_db._quests),
            auto_load=auto_load
        )

    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main quest tick - called from decision engine.

        Args:
            game_state: Current game state

        Returns:
            List of quest-related actions to perform
        """
        actions: list[Action] = []

        try:
            # Priority 1: Update quest progress from game state
            self._progress_tracker.update_progress(game_state)

            # Priority 2: Check for completable quests
            completable = self.quest_log.get_completable_quests()
            if completable:
                turn_in_actions = self._action_generator.create_turn_in_actions(
                    completable, game_state
                )
                actions.extend(turn_in_actions)
                return actions

            # Priority 3: Suggest next quest objectives
            if not actions:
                priority_quest = self.get_priority_quest()
                if priority_quest:
                    objective_actions = self._action_generator.get_objective_actions(
                        priority_quest, game_state
                    )
                    actions.extend(objective_actions[:3])

        except Exception as e:
            logger.error(f"Error in quest tick: {e}", exc_info=True)

        return actions

    # === Event Handlers (delegated to progress tracker) ===
    
    def on_monster_kill(self, monster_id: int, monster_name: str) -> None:
        """Handle monster kill event for quest tracking."""
        self._progress_tracker.on_monster_kill(monster_id, monster_name)

    def on_item_obtained(self, item_id: int, quantity: int) -> None:
        """Handle item acquisition for quest tracking."""
        self._progress_tracker.on_item_obtained(item_id, quantity)

    def on_npc_talk(self, npc_id: int) -> None:
        """Handle NPC conversation for quest tracking."""
        self._progress_tracker.on_npc_talk(npc_id)

    # === Quest Management ===

    def accept_quest(self, quest: Quest) -> bool:
        """
        Add quest to active quests.

        Args:
            quest: Quest to accept

        Returns:
            True if quest was accepted
        """
        success = self.quest_log.add_quest(quest)
        if success:
            logger.info(f"Quest accepted: {quest.name} (ID: {quest.quest_id})")
        else:
            logger.warning(f"Failed to accept quest: {quest.name}")
        return success

    def complete_quest(self, quest_id: int) -> bool:
        """
        Mark quest as completed.

        Args:
            quest_id: ID of quest to complete

        Returns:
            True if quest was completed
        """
        success = self.quest_log.complete_quest(quest_id)
        if success:
            logger.info(f"Quest completed: {quest_id}")
        else:
            logger.warning(f"Failed to complete quest: {quest_id}")
        return success

    def get_priority_quest(self) -> Quest | None:
        """
        Get highest priority active quest.

        Returns:
            Highest priority quest or None
        """
        if not self.quest_log.active_quests:
            return None

        sorted_quests = sorted(
            self.quest_log.active_quests,
            key=lambda q: self._calculate_quest_priority(q),
            reverse=True,
        )

        return sorted_quests[0] if sorted_quests else None

    def _calculate_quest_priority(self, quest: Quest) -> float:
        """Calculate quest priority based on various factors and config."""
        priority = 0.0
        quest_priorities = config.QUEST_PRIORITIES

        # High priority if ready to turn in
        if quest.status == "ready_to_turn_in":
            priority += 100.0

        # Priority based on quest type from config
        quest_type = self._determine_quest_type(quest)
        type_priority = quest_priorities.get(quest_type, 50)
        priority += type_priority

        # Priority based on progress
        priority += quest.progress_percent * 0.5

        # Priority based on rewards
        total_exp = sum(
            r.amount for r in quest.rewards if r.reward_type in ["exp_base", "exp_job"]
        )
        priority += total_exp * 0.001

        total_zeny = sum(r.amount for r in quest.rewards if r.reward_type == "zeny")
        priority += total_zeny * 0.01

        # Bonus for time-limited quests
        if quest.time_limit_seconds:
            priority += 20.0

        # Bonus for daily quests
        if quest.is_daily:
            priority += quest_priorities.get("daily", 80)

        return priority
    
    def _determine_quest_type(self, quest: Quest) -> str:
        """Determine quest type for priority calculation."""
        if quest.is_daily:
            return "daily"
        if quest.is_repeatable:
            return "repeatable"
        
        name_lower = quest.name.lower()
        desc_lower = quest.description.lower()
        
        if any(word in name_lower for word in ["main", "story", "chapter"]):
            return "main_story"
        if any(word in name_lower for word in ["side", "optional"]):
            return "side_quest"
        if any(word in desc_lower for word in ["collect", "gather", "bring"]):
            return "collection"
        
        return "side_quest"

    def get_quest_by_id(self, quest_id: int) -> Quest | None:
        """Get quest by ID from active quests or database."""
        quest = self.quest_log.get_quest(quest_id)
        if quest:
            return quest
        return self.quest_db.get_quest(quest_id)

    # === Database Operations ===

    def load_quest_database(
        self,
        db_path: Optional[Path] = None,
        custom_paths: Optional[list[Path]] = None,
        force_reload: bool = False
    ) -> int:
        """
        Load quest definitions from database files.

        Args:
            db_path: Override default database path
            custom_paths: Additional paths for custom quests
            force_reload: Force reload even if already loaded

        Returns:
            Number of quests loaded
        """
        if force_reload or not self.quest_db._quests:
            if db_path or custom_paths:
                from ai_sidecar.npc.quest_db_loader import reset_quest_loader
                reset_quest_loader()
                self._loader = get_quest_loader(
                    db_path=db_path,
                    custom_paths=custom_paths
                )
            
            self.quest_db = self._loader.load_all()
            
            # Update suggestion engine reference
            self._suggestion_engine = QuestSuggestionEngine(
                self.quest_db,
                self.quest_log,
                self._loader
            )
            
            logger.info(
                "Quest database loaded",
                total_quests=len(self.quest_db._quests),
                stats=self._loader.get_stats()
            )
        
        return len(self.quest_db._quests)
    
    def reload_quest_database(self) -> int:
        """Hot-reload quest database from files."""
        self.quest_db = self._loader.reload()
        
        # Update suggestion engine reference
        self._suggestion_engine = QuestSuggestionEngine(
            self.quest_db,
            self.quest_log,
            self._loader
        )
        
        logger.info(f"Quest database reloaded: {len(self.quest_db._quests)} quests")
        return len(self.quest_db._quests)

    # === Quest Availability & Suggestions (delegated) ===

    def get_available_quests(
        self, level: int, job: str, map_name: str
    ) -> list[Quest]:
        """Get quests available to accept at current level/location."""
        available = []
        level_quests = self.quest_db.get_quests_for_level(level)

        for quest in level_quests:
            if not quest.is_repeatable:
                if self.quest_log.is_quest_completed(quest.quest_id):
                    continue

            if self.quest_log.get_quest(quest.quest_id):
                continue

            prereqs_met = all(
                self.quest_log.is_quest_completed(prereq_id)
                for prereq_id in quest.prerequisite_quests
            )
            if not prereqs_met:
                continue

            if quest.is_daily:
                if not self.quest_log.can_accept_daily_quest(quest.quest_id):
                    continue

            if quest.is_eligible(level, job):
                available.append(quest)

        return available
    
    def get_quest_chain(self, quest_id: int) -> list[Quest]:
        """Get all quests in a chain containing the given quest."""
        return self._suggestion_engine.get_quest_chain(quest_id)
    
    def check_prerequisites(
        self,
        quest_id: int,
        level: int,
        job: str,
        completed_quests: Optional[set[int]] = None
    ) -> tuple[bool, list[str]]:
        """Check if a quest's prerequisites are met."""
        return self._suggestion_engine.check_prerequisites(
            quest_id, level, job, completed_quests
        )
    
    def suggest_next_quests(
        self,
        level: int,
        job: str,
        map_name: Optional[str] = None,
        max_suggestions: int = 5
    ) -> list[tuple[Quest, float]]:
        """Suggest next quests based on level, job, and optionally location."""
        available = self.get_available_quests(level, job, map_name or "")
        return self._suggestion_engine.suggest_next_quests(
            level, job, available, map_name, max_suggestions
        )
    
    def track_objective_progress(
        self,
        quest_id: int,
        objective_type: Optional[QuestObjectiveType] = None
    ) -> dict:
        """Get detailed progress tracking for quest objectives."""
        return self._suggestion_engine.track_objective_progress(
            quest_id, objective_type
        )
    
    def get_quests_by_type(self, quest_type: str) -> list[Quest]:
        """Get all quests of a specific type from database."""
        return self._loader.get_quests_by_type(quest_type)
    
    def get_quests_by_npc(self, npc_id: int) -> list[Quest]:
        """Get all quests available from a specific NPC."""
        return self._loader.get_quests_by_npc(npc_id)
    
    def get_quest_database_stats(self) -> dict:
        """Get statistics about the loaded quest database."""
        return self._loader.get_stats()