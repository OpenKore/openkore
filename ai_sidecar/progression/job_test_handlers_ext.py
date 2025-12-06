"""
Job Test Handlers Module - Extended.

Contains handlers for combat test, quiz test, and maze test.
Split from main handlers module to maintain <500 line files.
"""

import heapq
import math
from typing import TYPE_CHECKING, Any

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.progression.job_test_config import (
    get_job_test_config,
    JobTestConfiguration,
)
from ai_sidecar.progression.job_test_data import (
    match_quiz_answer,
    get_quiz_answers,
)
from ai_sidecar.progression.job_test_handlers import JobTestResult
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class JobTestHandlersExtended:
    """
    Extended job test handlers for combat, quiz, and maze tests.
    
    Separated to maintain modular file sizes.
    """
    
    def __init__(self, config: JobTestConfiguration | None = None):
        """Initialize handlers with configuration."""
        self.config = config or get_job_test_config()
        self._log = logger.bind(component="job_test_handlers_ext")
    
    # =========================================================================
    # COMBAT TEST HANDLER
    # =========================================================================
    
    async def handle_combat_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle combat skill test instances (Knight, Crusader, etc).
        
        Manages instance entry/exit, combat, consumables, and retry.
        """
        instance_map = params.get("instance_map", "job_knight")
        test_stage = params.get("test_stage", 1)
        max_stages = params.get("max_stages", 3)
        retry_count = params.get("retry_count", 0)
        in_instance = params.get("in_instance", False)
        
        self._log.info(
            "Combat test processing",
            instance=instance_map,
            stage=test_stage,
            max_stages=max_stages,
            retry=retry_count,
            in_instance=in_instance
        )
        
        # Check completion
        if test_stage > max_stages:
            self._log.info("Combat test complete", stages=max_stages)
            return JobTestResult(
                completed=True,
                message=f"Combat test complete: All {max_stages} stages cleared"
            )
        
        # Check retry limit
        max_retries = self.config.combat.max_retries
        if retry_count >= max_retries:
            self._log.error("Combat test failed - max retries exceeded", retries=retry_count)
            return JobTestResult(
                completed=False,
                actions=[Action(
                    type=ActionType.NOOP,
                    priority=1,
                    extra={
                        "action_subtype": "combat_test_failed",
                        "reason": "Max retries exceeded",
                        "retry_count": retry_count
                    }
                )],
                message=f"Combat test failed after {retry_count} retries"
            )
        
        actions: list[Action] = []
        char = game_state.character
        
        # Check HP for consumable use
        hp_threshold = self.config.combat.consumable_hp_threshold
        if hasattr(char, 'hp') and hasattr(char, 'hp_max'):
            hp_percent = char.hp / max(char.hp_max, 1)
            if hp_percent < hp_threshold:
                self._log.info("HP low, using consumable", hp_percent=hp_percent)
                actions.append(Action(
                    type=ActionType.USE_ITEM,
                    priority=25,  # High priority
                    extra={
                        "action_subtype": "emergency_heal",
                        "item_type": "potion",
                        "hp_percent": hp_percent
                    }
                ))
        
        if not in_instance:
            # Need to enter instance
            self._log.info("Entering combat test instance", instance=instance_map)
            actions.append(Action(
                type=ActionType.MOVE,
                priority=15,
                extra={
                    "action_subtype": "enter_instance",
                    "instance_map": instance_map,
                    "stage": test_stage
                }
            ))
        else:
            # In instance - combat logic
            instance_config = self.config.combat.instance_maps.get(instance_map, {})
            time_limit = instance_config.get("time_limit", 300)
            
            # Find enemies in instance
            enemies = self._find_instance_enemies(game_state)
            
            if enemies:
                # Attack nearest enemy
                target = enemies[0]
                self._log.debug(
                    "Combat test - attacking enemy",
                    target_id=target.get("actor_id"),
                    stage=test_stage
                )
                
                actions.append(Action(
                    type=ActionType.ATTACK,
                    priority=20,
                    target_id=target.get("actor_id"),
                    extra={
                        "action_subtype": "instance_combat",
                        "stage": test_stage,
                        "instance_map": instance_map
                    }
                ))
            else:
                # No enemies - check if stage complete
                self._log.info("No enemies found - stage may be complete", stage=test_stage)
                actions.append(Action(
                    type=ActionType.NOOP,
                    priority=5,
                    extra={
                        "action_subtype": "check_stage_completion",
                        "stage": test_stage,
                        "next_stage": test_stage + 1
                    }
                ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_stage": test_stage,
                "max_stages": max_stages,
                "retry_count": retry_count,
                "in_instance": in_instance,
                "instance_map": instance_map
            },
            message=f"Combat test stage {test_stage}/{max_stages}"
        )
    
    def _find_instance_enemies(self, game_state: "GameState") -> list[dict[str, Any]]:
        """Find enemies in combat test instance."""
        monsters = game_state.get_monsters() if hasattr(game_state, 'get_monsters') else []
        
        if not monsters:
            return []
        
        char_pos = game_state.character.position
        enemies: list[dict[str, Any]] = []
        
        for monster in monsters:
            dist = char_pos.distance_to(monster.position) if hasattr(monster, 'position') else 999
            enemies.append({
                "actor_id": monster.actor_id,
                "name": getattr(monster, 'name', 'Enemy'),
                "distance": dist,
                "hp": getattr(monster, 'hp', 0),
                "hp_max": getattr(monster, 'hp_max', 1)
            })
        
        # Sort by distance (nearest first)
        enemies.sort(key=lambda e: e["distance"])
        return enemies
    
    # =========================================================================
    # QUIZ TEST HANDLER
    # =========================================================================
    
    async def handle_quiz_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle magic/knowledge quiz tests.
        
        Uses quiz answer database for intelligent response selection.
        """
        current_question = params.get("question_number", 1)
        total_questions = params.get("total_questions", 10)
        quiz_type = params.get("quiz_type", "mage")
        question_text = params.get("question_text", "")
        choices = params.get("choices", [])
        correct_count = params.get("correct_count", 0)
        
        self._log.info(
            "Quiz test processing",
            question=current_question,
            total=total_questions,
            quiz_type=quiz_type
        )
        
        # Check completion
        if current_question > total_questions:
            passing_score = total_questions * 0.7  # 70% to pass
            passed = correct_count >= passing_score
            
            self._log.info(
                "Quiz test complete",
                correct=correct_count,
                total=total_questions,
                passed=passed
            )
            
            return JobTestResult(
                completed=True,
                message=f"Quiz complete: {correct_count}/{total_questions} correct"
                       f" ({'PASSED' if passed else 'FAILED'})"
            )
        
        actions: list[Action] = []
        
        if question_text:
            # Find best answer
            answer = match_quiz_answer(
                question_text,
                quiz_type,
                threshold=self.config.quiz.match_threshold
            )
            
            if answer:
                self._log.info(
                    "Quiz answer found",
                    question=current_question,
                    answer=answer
                )
                
                # Find matching choice index
                answer_index = self._find_answer_index(answer, choices)
                
                actions.append(Action(
                    type=ActionType.NPC_CHOOSE,
                    priority=20,
                    extra={
                        "action_subtype": "quiz_answer",
                        "choice_index": answer_index,
                        "answer_text": answer,
                        "question_number": current_question,
                        "confidence": "high"
                    }
                ))
            else:
                # No match found - use default or educated guess
                self._log.warning(
                    "Quiz answer not found, guessing",
                    question_text=question_text[:50]
                )
                
                # Try to make educated guess based on common patterns
                guess_index = self._make_educated_guess(question_text, choices, quiz_type)
                
                actions.append(Action(
                    type=ActionType.NPC_CHOOSE,
                    priority=20,
                    extra={
                        "action_subtype": "quiz_guess",
                        "choice_index": guess_index,
                        "question_number": current_question,
                        "confidence": "low"
                    }
                ))
        else:
            # No question text - continue dialogue
            self._log.debug("Waiting for quiz question")
            actions.append(Action(
                type=ActionType.TALK_NPC,
                priority=10,
                extra={
                    "action_subtype": "quiz_continue",
                    "dialogue_continue": True
                }
            ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_question": current_question,
                "total_questions": total_questions,
                "correct_count": correct_count,
                "quiz_type": quiz_type
            },
            message=f"Quiz: Question {current_question}/{total_questions}"
        )
    
    def _find_answer_index(self, answer: str, choices: list[str]) -> int:
        """Find choice index that matches answer."""
        if not choices:
            return self.config.quiz.default_answer_index
        
        answer_lower = answer.lower()
        
        # Exact match first
        for i, choice in enumerate(choices):
            if answer_lower in choice.lower() or choice.lower() in answer_lower:
                return i
        
        # Fuzzy match
        from difflib import SequenceMatcher
        best_index = 0
        best_score = 0.0
        
        for i, choice in enumerate(choices):
            score = SequenceMatcher(None, answer_lower, choice.lower()).ratio()
            if score > best_score:
                best_score = score
                best_index = i
        
        return best_index
    
    def _make_educated_guess(
        self,
        question: str,
        choices: list[str],
        quiz_type: str
    ) -> int:
        """Make educated guess when no answer found."""
        if not choices:
            return self.config.quiz.default_answer_index
        
        question_lower = question.lower()
        
        # Look for keyword patterns
        quiz_keywords = {
            "mage": ["magic", "spell", "cast", "int", "dex", "staff"],
            "sage": ["research", "element", "theory", "knowledge"],
            "priest": ["holy", "heal", "support", "bless", "divine"],
            "wizard": ["aoe", "storm", "meteor", "damage"],
            "hunter": ["trap", "falcon", "bow", "range"],
        }
        
        keywords = quiz_keywords.get(quiz_type, [])
        
        # Score each choice by keyword matches
        best_index = 0
        best_score = 0
        
        for i, choice in enumerate(choices):
            choice_lower = choice.lower()
            score = sum(1 for kw in keywords if kw in choice_lower)
            if score > best_score:
                best_score = score
                best_index = i
        
        # If no keywords matched, return default
        if best_score == 0:
            return self.config.quiz.default_answer_index
        
        return best_index
    
    # =========================================================================
    # MAZE TEST HANDLER
    # =========================================================================
    
    async def handle_maze_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle trap/maze navigation tests.
        
        Implements A* pathfinding, trap avoidance, and goal detection.
        """
        maze_map = params.get("maze_map", "job_hunter")
        goal_coords = params.get("goal", {"x": 100, "y": 100})
        trap_locations = params.get("trap_locations", [])
        warp_tiles = params.get("warp_tiles", [])
        
        # Get character position
        char_x = game_state.character.x if hasattr(game_state.character, 'x') else 0
        char_y = game_state.character.y if hasattr(game_state.character, 'y') else 0
        current_pos = (char_x, char_y)
        goal_pos = (goal_coords.get("x", 100), goal_coords.get("y", 100))
        
        self._log.info(
            "Maze test processing",
            maze_map=maze_map,
            current=current_pos,
            goal=goal_pos
        )
        
        # Check if reached goal
        distance_to_goal = math.sqrt(
            (goal_pos[0] - char_x)**2 + (goal_pos[1] - char_y)**2
        )
        
        if distance_to_goal <= self.config.maze.goal_threshold:
            self._log.info("Maze test complete", distance=distance_to_goal)
            return JobTestResult(
                completed=True,
                message=f"Maze completed! Distance to goal: {distance_to_goal:.1f}"
            )
        
        actions: list[Action] = []
        
        # Load maze config if available
        maze_cfg = self.config.maze.maze_configs.get(maze_map, {})
        if maze_cfg:
            trap_locations = trap_locations or maze_cfg.get("trap_tiles", [])
            warp_tiles = warp_tiles or maze_cfg.get("warp_tiles", [])
        
        # Calculate path avoiding traps
        path = self._calculate_safe_path(
            current_pos,
            goal_pos,
            trap_locations,
            warp_tiles,
            maze_map
        )
        
        if path and len(path) > 1:
            # Get next waypoint (skip first as it's current position)
            next_wp = path[1] if len(path) > 1 else path[0]
            
            self._log.debug(
                "Maze navigation",
                next_waypoint=next_wp,
                path_length=len(path),
                distance_to_goal=distance_to_goal
            )
            
            actions.append(Action(
                type=ActionType.MOVE,
                priority=15,
                x=next_wp[0],
                y=next_wp[1],
                extra={
                    "action_subtype": "maze_navigate",
                    "goal": goal_pos,
                    "avoiding_traps": len(trap_locations),
                    "path_remaining": len(path) - 1
                }
            ))
        else:
            # No path found - try direct approach with caution
            self._log.warning(
                "No safe path found, attempting cautious direct approach"
            )
            
            # Move towards goal in small steps
            step_size = 3
            dx = goal_pos[0] - char_x
            dy = goal_pos[1] - char_y
            dist = max(abs(dx), abs(dy), 1)
            
            next_x = char_x + int(dx / dist * step_size)
            next_y = char_y + int(dy / dist * step_size)
            
            actions.append(Action(
                type=ActionType.MOVE,
                priority=10,
                x=next_x,
                y=next_y,
                extra={
                    "action_subtype": "maze_cautious_move",
                    "strategy": "cautious",
                    "step_size": step_size
                }
            ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_position": current_pos,
                "goal_position": goal_pos,
                "distance_to_goal": distance_to_goal,
                "traps_avoided": len(trap_locations),
                "maze_map": maze_map
            },
            message=f"Maze navigation: {distance_to_goal:.1f} cells to goal"
        )
    
    def _calculate_safe_path(
        self,
        start: tuple[int, int],
        goal: tuple[int, int],
        traps: list[tuple[int, int] | list[int]],
        warps: list[tuple[int, int] | list[int]],
        maze_map: str
    ) -> list[tuple[int, int]]:
        """
        Calculate safe path using A* algorithm avoiding traps.
        
        Args:
            start: Starting position
            goal: Goal position
            traps: Trap tile locations to avoid
            warps: Warp tile locations (may reset progress)
            maze_map: Map name for bounds
            
        Returns:
            List of waypoints from start to goal
        """
        # Convert trap/warp lists to sets of tuples
        trap_set: set[tuple[int, int]] = set()
        for t in traps:
            if isinstance(t, (list, tuple)) and len(t) >= 2:
                trap_set.add((int(t[0]), int(t[1])))
        
        warp_set: set[tuple[int, int]] = set()
        for w in warps:
            if isinstance(w, (list, tuple)) and len(w) >= 2:
                warp_set.add((int(w[0]), int(w[1])))
        
        # Combined obstacles
        obstacles = trap_set | warp_set
        
        # Get maze bounds
        maze_cfg = self.config.maze.maze_configs.get(maze_map, {})
        width = maze_cfg.get("width", 200)
        height = maze_cfg.get("height", 200)
        
        # A* pathfinding
        open_set: list[tuple[float, tuple[int, int]]] = []
        heapq.heappush(open_set, (0, start))
        
        came_from: dict[tuple[int, int], tuple[int, int]] = {}
        g_score: dict[tuple[int, int], float] = {start: 0}
        f_score: dict[tuple[int, int], float] = {
            start: self._heuristic(start, goal)
        }
        
        max_iterations = 5000
        iterations = 0
        
        while open_set and iterations < max_iterations:
            iterations += 1
            _, current = heapq.heappop(open_set)
            
            # Close enough to goal
            if self._heuristic(current, goal) <= self.config.maze.goal_threshold:
                return self._reconstruct_path(came_from, current)
            
            for neighbor in self._get_neighbors(current, width, height, obstacles):
                tentative_g = g_score.get(current, float('inf')) + 1
                
                if tentative_g < g_score.get(neighbor, float('inf')):
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f = tentative_g + self._heuristic(neighbor, goal)
                    f_score[neighbor] = f
                    heapq.heappush(open_set, (f, neighbor))
        
        self._log.warning(
            "Pathfinding exhausted",
            iterations=iterations,
            start=start,
            goal=goal
        )
        return []
    
    def _heuristic(self, a: tuple[int, int], b: tuple[int, int]) -> float:
        """Manhattan distance heuristic."""
        return abs(a[0] - b[0]) + abs(a[1] - b[1])
    
    def _get_neighbors(
        self,
        pos: tuple[int, int],
        width: int,
        height: int,
        obstacles: set[tuple[int, int]]
    ) -> list[tuple[int, int]]:
        """Get valid neighboring cells."""
        x, y = pos
        neighbors: list[tuple[int, int]] = []
        
        # 4-directional movement
        for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
            nx, ny = x + dx, y + dy
            
            # Check bounds
            if not (0 <= nx < width and 0 <= ny < height):
                continue
            
            # Check obstacles
            if (nx, ny) in obstacles:
                continue
            
            neighbors.append((nx, ny))
        
        return neighbors
    
    def _reconstruct_path(
        self,
        came_from: dict[tuple[int, int], tuple[int, int]],
        current: tuple[int, int]
    ) -> list[tuple[int, int]]:
        """Reconstruct path from came_from dict."""
        path = [current]
        while current in came_from:
            current = came_from[current]
            path.append(current)
        path.reverse()
        return path