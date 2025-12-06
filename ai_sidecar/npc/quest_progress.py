"""
Quest progress tracking module.

Handles quest progress updates from game events like
monster kills, item collection, and NPC interactions.
"""

from typing import TYPE_CHECKING

from ai_sidecar.npc.quest_models import Quest, QuestLog, QuestObjectiveType
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class QuestProgressTracker:
    """
    Tracks and updates quest objective progress.
    
    Separates progress tracking logic from core quest management
    for cleaner architecture and maintainability.
    """
    
    def __init__(self, quest_log: QuestLog) -> None:
        """
        Initialize progress tracker.
        
        Args:
            quest_log: Player quest log reference
        """
        self.quest_log = quest_log
    
    def update_progress(self, game_state: "GameState") -> None:
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
            self._update_single_quest(quest, game_state, inventory_counts)
    
    def _update_single_quest(
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
                quest_changed = self._update_collect_objective(
                    quest, obj, inventory_counts
                ) or quest_changed
            
            elif obj.objective_type == QuestObjectiveType.VISIT_LOCATION:
                quest_changed = self._update_visit_objective(
                    quest, obj, game_state
                ) or quest_changed
            
            elif obj.objective_type == QuestObjectiveType.TALK_TO_NPC:
                # NPC talk tracking requires event-based updates
                self._check_npc_proximity(quest, obj, game_state)
        
        # Check if quest is now completable
        if quest_changed and quest.all_objectives_complete:
            quest.status = "ready_to_turn_in"
            logger.info(f"Quest ready to turn in: {quest.name}")
    
    def _update_collect_objective(
        self,
        quest: Quest,
        obj,
        inventory_counts: dict[int, int]
    ) -> bool:
        """Update collection objective progress."""
        current_count = inventory_counts.get(obj.target_id, 0)
        if current_count != obj.current_count:
            old_count = obj.current_count
            obj.current_count = min(current_count, obj.required_count)
            if obj.current_count > old_count:
                logger.debug(
                    f"Quest '{quest.name}' item progress: "
                    f"{obj.target_name} {old_count} -> {obj.current_count}/{obj.required_count}"
                )
                
                # Check completion
                if obj.current_count >= obj.required_count:
                    obj.completed = True
                    logger.info(f"Quest objective completed: Collect {obj.target_name}")
                return True
        return False
    
    def _update_visit_objective(
        self,
        quest: Quest,
        obj,
        game_state: "GameState"
    ) -> bool:
        """Update visit location objective progress."""
        if obj.map_name and obj.x is not None and obj.y is not None:
            if game_state.map_name == obj.map_name:
                char_pos = game_state.character.position
                distance = ((char_pos.x - obj.x) ** 2 + (char_pos.y - obj.y) ** 2) ** 0.5
                
                if distance <= 5:  # Within 5 cells
                    obj.update_progress(1)
                    logger.info(f"Quest objective completed: Visit {obj.target_name}")
                    return True
        return False
    
    def _check_npc_proximity(
        self,
        quest: Quest,
        obj,
        game_state: "GameState"
    ) -> None:
        """Check if NPC is nearby for talk objectives."""
        for actor in game_state.actors:
            if actor.id == obj.target_id:
                char_pos = game_state.character.position
                distance = char_pos.distance_to(actor.position)
                
                # If we're very close, assume we talked
                if distance <= 2:
                    # Would need actual talk event tracking
                    pass
    
    def on_monster_kill(self, monster_id: int, monster_name: str) -> None:
        """
        Handle monster kill event for quest tracking.

        Args:
            monster_id: ID of killed monster
            monster_name: Name of killed monster
        """
        for quest in self.quest_log.active_quests:
            kill_objectives = quest.get_objective_by_type(
                QuestObjectiveType.KILL_MONSTER
            )

            for obj in kill_objectives:
                if obj.target_id == monster_id and not obj.completed:
                    obj.update_progress(1)
                    logger.info(
                        f"Quest objective updated: {quest.name} - {obj.target_name} "
                        f"({obj.current_count}/{obj.required_count})"
                    )

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
        for quest in self.quest_log.active_quests:
            collect_objectives = quest.get_objective_by_type(
                QuestObjectiveType.COLLECT_ITEM
            )

            for obj in collect_objectives:
                if obj.target_id == item_id and not obj.completed:
                    obj.update_progress(quantity)
                    logger.info(
                        f"Quest objective updated: {quest.name} - {obj.target_name} "
                        f"({obj.current_count}/{obj.required_count})"
                    )

                    if quest.all_objectives_complete:
                        quest.status = "ready_to_turn_in"
                        logger.info(f"Quest ready to turn in: {quest.name}")

    def on_npc_talk(self, npc_id: int) -> None:
        """
        Handle NPC conversation for quest tracking.

        Args:
            npc_id: ID of NPC being talked to
        """
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

                    if quest.all_objectives_complete:
                        quest.status = "ready_to_turn_in"
                        logger.info(f"Quest ready to turn in: {quest.name}")