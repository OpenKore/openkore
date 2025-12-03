"""
Quest management and tracking system.

Coordinates quest tracking, objective updates, and quest completion logic.
Integrates with the decision engine to suggest quest-related actions.
"""

from typing import TYPE_CHECKING

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.dialogue_parser import DialogueParser
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestDatabase,
    QuestLog,
    QuestObjectiveType,
)
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
    """

    def __init__(self) -> None:
        """Initialize quest manager."""
        self.quest_db = QuestDatabase()
        self.quest_log = QuestLog()
        self.dialogue_parser = DialogueParser()

        logger.info("Quest manager initialized")

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
            self._update_quest_progress(game_state)

            # Priority 2: Check for completable quests
            completable = self.quest_log.get_completable_quests()
            if completable:
                turn_in_actions = self._create_turn_in_actions(completable, game_state)
                actions.extend(turn_in_actions)
                # Return early - focus on turn-in
                return actions

            # Priority 3: Suggest next quest objectives
            if not actions:
                objective_actions = self._get_objective_actions(game_state)
                actions.extend(objective_actions[:3])  # Limit to top 3 actions

        except Exception as e:
            logger.error(f"Error in quest tick: {e}", exc_info=True)

        return actions

    def _update_quest_progress(self, game_state: "GameState") -> None:
        """
        Update all quest objective progress based on game state.

        Args:
            game_state: Current game state
        """
        if not self.quest_log.active_quests:
            return
        
        # Track inventory items for collection quests
        inventory_counts: dict[int, int] = {}
        for item in game_state.inventory:
            inventory_counts[item.id] = inventory_counts.get(item.id, 0) + item.amount
        
        # Update each active quest
        for quest in self.quest_log.active_quests:
            self._update_single_quest_progress(quest, game_state, inventory_counts)
    
    def _update_single_quest_progress(
        self,
        quest: Quest,
        game_state: "GameState",
        inventory_counts: dict[int, int]
    ) -> None:
        """
        Update progress for a single quest.
        
        Args:
            quest: Quest to update
            game_state: Current game state
            inventory_counts: Pre-calculated inventory item counts
        """
        quest_changed = False
        
        for obj in quest.objectives:
            if obj.completed:
                continue
            
            if obj.objective_type == QuestObjectiveType.COLLECT_ITEM:
                # Check inventory for required items
                current_count = inventory_counts.get(obj.target_id, 0)
                if current_count != obj.current_count:
                    old_count = obj.current_count
                    obj.current_count = min(current_count, obj.required_count)
                    if obj.current_count > old_count:
                        logger.debug(
                            f"Quest '{quest.name}' item progress: "
                            f"{obj.target_name} {old_count} -> {obj.current_count}/{obj.required_count}"
                        )
                        quest_changed = True
                    
                    # Check completion
                    if obj.current_count >= obj.required_count:
                        obj.completed = True
                        logger.info(f"Quest objective completed: Collect {obj.target_name}")
            
            elif obj.objective_type == QuestObjectiveType.VISIT_LOCATION:
                # Check if we're at the target location
                if obj.map_name and obj.x is not None and obj.y is not None:
                    if game_state.map_name == obj.map_name:
                        char_pos = game_state.character.position
                        distance = ((char_pos.x - obj.x) ** 2 + (char_pos.y - obj.y) ** 2) ** 0.5
                        
                        if distance <= 5:  # Within 5 cells
                            obj.update_progress(1)
                            logger.info(f"Quest objective completed: Visit {obj.target_name}")
                            quest_changed = True
            
            elif obj.objective_type == QuestObjectiveType.TALK_TO_NPC:
                # Check if NPC is nearby and we recently talked
                for actor in game_state.actors:
                    if actor.id == obj.target_id:
                        char_pos = game_state.character.position
                        distance = char_pos.distance_to(actor.position)
                        
                        # If we're very close, assume we talked
                        if distance <= 2:
                            # Would need actual talk event tracking
                            pass
        
        # Check if quest is now completable
        if quest_changed and quest.all_objectives_complete:
            quest.status = "ready_to_turn_in"
            logger.info(f"Quest ready to turn in: {quest.name}")

    def on_monster_kill(self, monster_id: int, monster_name: str) -> None:
        """
        Handle monster kill event for quest tracking.

        Args:
            monster_id: ID of killed monster
            monster_name: Name of killed monster
        """
        # Update all kill objectives
        for quest in self.quest_log.active_quests:
            kill_objectives = quest.get_objective_by_type(
                QuestObjectiveType.KILL_MONSTER
            )

            for obj in kill_objectives:
                if obj.target_id == monster_id and not obj.completed:
                    obj.update_progress(1)
                    logger.info(
                        f"Quest objective updated: {quest.name} - {obj.target_name} ({obj.current_count}/{obj.required_count})"
                    )

                    # Check if quest is now completable
                    if quest.all_objectives_complete:
                        quest.status = "ready_to_turn_in"
                        logger.info(f"Quest ready to turn in: {quest.name}")

    def on_item_obtained(self, item_id: int, quantity: int) -> None:
        """
        Handle item acquisition for quest tracking.

        Args:
            item_id: ID of obtained item
            quantity: Number obtained
        """
        # Update all collection objectives
        for quest in self.quest_log.active_quests:
            collect_objectives = quest.get_objective_by_type(
                QuestObjectiveType.COLLECT_ITEM
            )

            for obj in collect_objectives:
                if obj.target_id == item_id and not obj.completed:
                    obj.update_progress(quantity)
                    logger.info(
                        f"Quest objective updated: {quest.name} - {obj.target_name} ({obj.current_count}/{obj.required_count})"
                    )

                    # Check if quest is now completable
                    if quest.all_objectives_complete:
                        quest.status = "ready_to_turn_in"
                        logger.info(f"Quest ready to turn in: {quest.name}")

    def on_npc_talk(self, npc_id: int) -> None:
        """
        Handle NPC conversation for quest tracking.

        Args:
            npc_id: ID of NPC being talked to
        """
        # Update talk objectives
        for quest in self.quest_log.active_quests:
            talk_objectives = quest.get_objective_by_type(
                QuestObjectiveType.TALK_TO_NPC
            )

            for obj in talk_objectives:
                if obj.target_id == npc_id and not obj.completed:
                    obj.update_progress(1)
                    logger.info(
                        f"Quest objective updated: {quest.name} - Talk to {obj.target_name}"
                    )

                    # Check if quest is now completable
                    if quest.all_objectives_complete:
                        quest.status = "ready_to_turn_in"
                        logger.info(f"Quest ready to turn in: {quest.name}")

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

        # Sort by priority (calculated)
        sorted_quests = sorted(
            self.quest_log.active_quests,
            key=lambda q: self._calculate_quest_priority(q),
            reverse=True,
        )

        return sorted_quests[0] if sorted_quests else None

    def _calculate_quest_priority(self, quest: Quest) -> float:
        """
        Calculate quest priority based on various factors and config.

        Args:
            quest: Quest to evaluate

        Returns:
            Priority score (higher = more priority)
        """
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
        priority += total_exp * 0.001  # Scale down

        total_zeny = sum(r.amount for r in quest.rewards if r.reward_type == "zeny")
        priority += total_zeny * 0.01  # Scale down

        # Bonus for time-limited quests
        if quest.time_limit_seconds:
            priority += 20.0

        # Bonus for daily quests
        if quest.is_daily:
            priority += quest_priorities.get("daily", 80)

        return priority
    
    def _determine_quest_type(self, quest: Quest) -> str:
        """
        Determine quest type for priority calculation.
        
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
        
        # Default to side quest
        return "side_quest"

    def _create_turn_in_actions(
        self, completable_quests: list[Quest], game_state: "GameState"
    ) -> list[Action]:
        """
        Create actions to turn in completed quests.

        Args:
            completable_quests: Quests ready to turn in
            game_state: Current game state

        Returns:
            List of turn-in actions
        """
        actions: list[Action] = []

        for quest in completable_quests:
            # Determine turn-in NPC
            turn_in_npc_id = quest.turn_in_npc_id or quest.npc_id

            # Check if NPC is nearby
            npc = None
            for actor in game_state.actors:
                if actor.id == turn_in_npc_id:
                    npc = actor
                    break

            if npc:
                # NPC is visible - check distance
                char_pos = game_state.character.position
                distance = char_pos.distance_to(npc.position)

                if distance > 5:
                    # Move to NPC
                    actions.append(
                        Action.move_to(npc.position.x, npc.position.y, priority=1)
                    )
                else:
                    # Talk to NPC
                    actions.append(
                        Action(
                            type=ActionType.TALK_NPC,
                            target_id=turn_in_npc_id,
                            priority=1,
                        )
                    )

        return actions

    def _get_objective_actions(self, game_state: "GameState") -> list[Action]:
        """
        Get actions for progressing quest objectives.

        Args:
            game_state: Current game state

        Returns:
            List of objective-related actions
        """
        actions: list[Action] = []

        # Get priority quest
        priority_quest = self.get_priority_quest()
        if not priority_quest:
            return actions

        # Get incomplete objectives
        incomplete_objectives = [
            obj for obj in priority_quest.objectives if not obj.completed
        ]

        for obj in incomplete_objectives:
            if obj.objective_type == QuestObjectiveType.KILL_MONSTER:
                # Find monster and attack
                for actor in game_state.actors:
                    if (
                        hasattr(actor, "mob_id")
                        and actor.mob_id == obj.target_id
                        and actor.hp
                        and actor.hp > 0
                    ):
                        actions.append(
                            Action.attack(target_id=actor.id, priority=3)
                        )
                        break

            elif obj.objective_type == QuestObjectiveType.TALK_TO_NPC:
                # Find NPC and talk
                for actor in game_state.actors:
                    if actor.id == obj.target_id:
                        char_pos = game_state.character.position
                        distance = char_pos.distance_to(actor.position)

                        if distance > 5:
                            # Move to NPC
                            actions.append(
                                Action.move_to(
                                    actor.position.x, actor.position.y, priority=3
                                )
                            )
                        else:
                            # Talk to NPC
                            actions.append(
                                Action(
                                    type=ActionType.TALK_NPC,
                                    target_id=actor.id,
                                    priority=3,
                                )
                            )
                        break

            elif obj.objective_type == QuestObjectiveType.VISIT_LOCATION:
                # Move to location
                if obj.x is not None and obj.y is not None:
                    char_pos = game_state.character.position
                    distance = (
                        (char_pos.x - obj.x) ** 2 + (char_pos.y - obj.y) ** 2
                    ) ** 0.5

                    if distance > 3:
                        actions.append(Action.move_to(obj.x, obj.y, priority=3))
                    else:
                        # Mark objective complete
                        obj.update_progress(1)

        return actions

    def get_quest_by_id(self, quest_id: int) -> Quest | None:
        """
        Get quest by ID from active quests or database.

        Args:
            quest_id: Quest ID to find

        Returns:
            Quest or None
        """
        # Check active quests first
        quest = self.quest_log.get_quest(quest_id)
        if quest:
            return quest

        # Check database
        return self.quest_db.get_quest(quest_id)

    def load_quest_database(self, quest_data: dict) -> None:
        """
        Load quest definitions from data.

        Args:
            quest_data: Dictionary of quest definitions
        """
        for quest_id_str, quest_dict in quest_data.items():
            try:
                quest_id = int(quest_id_str)
                # Would parse and create Quest objects here
                # For now, this is a placeholder
                logger.debug(f"Loading quest {quest_id}")
            except (ValueError, KeyError) as e:
                logger.warning(f"Failed to load quest {quest_id_str}: {e}")

    def get_available_quests(
        self, level: int, job: str, map_name: str
    ) -> list[Quest]:
        """
        Get quests available to accept at current level/location.

        Args:
            level: Character level
            job: Character job class
            map_name: Current map

        Returns:
            List of available quests
        """
        available = []

        # Get quests for level
        level_quests = self.quest_db.get_quests_for_level(level)

        for quest in level_quests:
            # Check if already completed (unless repeatable)
            if not quest.is_repeatable:
                if self.quest_log.is_quest_completed(quest.quest_id):
                    continue

            # Check if already active
            if self.quest_log.get_quest(quest.quest_id):
                continue

            # Check prerequisites
            prereqs_met = all(
                self.quest_log.is_quest_completed(prereq_id)
                for prereq_id in quest.prerequisite_quests
            )
            if not prereqs_met:
                continue

            # Check daily quest availability
            if quest.is_daily:
                if not self.quest_log.can_accept_daily_quest(quest.quest_id):
                    continue

            # Check eligibility
            if quest.is_eligible(level, job):
                available.append(quest)

        return available