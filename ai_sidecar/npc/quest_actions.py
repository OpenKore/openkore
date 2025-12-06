"""
Quest action generation module.

Creates game actions for completing quest objectives
and turning in completed quests.
"""

from typing import TYPE_CHECKING

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.quest_models import Quest, QuestLog, QuestObjectiveType
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class QuestActionGenerator:
    """
    Generates game actions for quest progression.
    
    Separates action generation logic from core quest management
    for cleaner architecture and maintainability.
    """
    
    def __init__(self, quest_log: QuestLog) -> None:
        """
        Initialize action generator.
        
        Args:
            quest_log: Player quest log reference
        """
        self.quest_log = quest_log
    
    def create_turn_in_actions(
        self,
        completable_quests: list[Quest],
        game_state: "GameState"
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
                    logger.debug(
                        f"Creating move action for quest turn-in",
                        quest=quest.name,
                        npc_id=turn_in_npc_id,
                        distance=distance
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
                    logger.debug(
                        f"Creating talk action for quest turn-in",
                        quest=quest.name,
                        npc_id=turn_in_npc_id
                    )

        return actions
    
    def get_objective_actions(
        self,
        priority_quest: Quest,
        game_state: "GameState"
    ) -> list[Action]:
        """
        Get actions for progressing quest objectives.

        Args:
            priority_quest: Quest to progress
            game_state: Current game state

        Returns:
            List of objective-related actions
        """
        actions: list[Action] = []

        # Get incomplete objectives
        incomplete_objectives = [
            obj for obj in priority_quest.objectives if not obj.completed
        ]

        for obj in incomplete_objectives:
            if obj.objective_type == QuestObjectiveType.KILL_MONSTER:
                action = self._create_kill_action(obj, game_state)
                if action:
                    actions.append(action)

            elif obj.objective_type == QuestObjectiveType.TALK_TO_NPC:
                action = self._create_talk_action(obj, game_state)
                if action:
                    actions.append(action)

            elif obj.objective_type == QuestObjectiveType.VISIT_LOCATION:
                action = self._create_visit_action(obj, game_state)
                if action:
                    actions.append(action)

        return actions
    
    def _create_kill_action(self, obj, game_state: "GameState") -> Action | None:
        """Create action to kill monster for objective."""
        for actor in game_state.actors:
            if (
                hasattr(actor, "mob_id")
                and actor.mob_id == obj.target_id
                and actor.hp
                and actor.hp > 0
            ):
                logger.debug(
                    f"Creating attack action for kill objective",
                    target_name=obj.target_name,
                    target_id=actor.id
                )
                return Action.attack(target_id=actor.id, priority=3)
        return None
    
    def _create_talk_action(self, obj, game_state: "GameState") -> Action | None:
        """Create action to talk to NPC for objective."""
        for actor in game_state.actors:
            if actor.id == obj.target_id:
                char_pos = game_state.character.position
                distance = char_pos.distance_to(actor.position)

                if distance > 5:
                    # Move to NPC
                    logger.debug(
                        f"Creating move action for talk objective",
                        target_name=obj.target_name,
                        distance=distance
                    )
                    return Action.move_to(
                        actor.position.x, actor.position.y, priority=3
                    )
                else:
                    # Talk to NPC
                    logger.debug(
                        f"Creating talk action for talk objective",
                        target_name=obj.target_name
                    )
                    return Action(
                        type=ActionType.TALK_NPC,
                        target_id=actor.id,
                        priority=3,
                    )
        return None
    
    def _create_visit_action(self, obj, game_state: "GameState") -> Action | None:
        """Create action to visit location for objective."""
        if obj.x is not None and obj.y is not None:
            char_pos = game_state.character.position
            distance = (
                (char_pos.x - obj.x) ** 2 + (char_pos.y - obj.y) ** 2
            ) ** 0.5

            if distance > 3:
                logger.debug(
                    f"Creating move action for visit objective",
                    target_name=obj.target_name,
                    distance=distance
                )
                return Action.move_to(obj.x, obj.y, priority=3)
            else:
                # Mark objective complete
                obj.update_progress(1)
                logger.info(f"Visit objective completed: {obj.target_name}")
        return None