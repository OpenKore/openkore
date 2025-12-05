"""
Job advancement automation system.

Handles autonomous job changes including:
- Job path planning (First → Second → Third job)
- NPC navigation for job change
- Quest prerequisite completion
- Job test automation (placeholders for server-specific tests)

Supports both classic (Novice→1st→2nd→Rebirth→Trans 2nd) and
renewal (Novice→1st→2nd→3rd) job progression paths.
"""

from pathlib import Path
from typing import Any
import json

from pydantic import BaseModel, Field

from ai_sidecar.core.state import CharacterState, GameState
from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.progression.lifecycle import LifecycleState
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class JobNPCLocation(BaseModel):
    """Location of a job advancement NPC."""
    
    map_name: str = Field(description="Map where NPC is located")
    x: int = Field(ge=0, description="X coordinate")
    y: int = Field(ge=0, description="Y coordinate")
    npc_name: str = Field(description="NPC display name")
    npc_id: str | None = Field(default=None, description="NPC internal ID")


class JobRequirements(BaseModel):
    """Requirements for job advancement."""
    
    base_level: int = Field(default=1, ge=1, description="Minimum base level")
    job_level: int = Field(default=1, ge=1, description="Minimum job level")
    zeny_cost: int = Field(default=0, ge=0, description="Zeny cost for job change")
    required_items: list[dict[str, int]] = Field(
        default_factory=list,
        description="Required items (item_id: quantity)"
    )
    test_required: bool = Field(default=False, description="Whether job test is required")
    test_type: str | None = Field(default=None, description="Type of job test")
    test_params: dict[str, Any] = Field(
        default_factory=dict,
        description="Parameters for job test"
    )


class JobPath(BaseModel):
    """Complete job progression path."""
    
    job_id: int = Field(description="Job ID")
    job_name: str = Field(description="Job class name")
    from_job: str | None = Field(default=None, description="Previous job class")
    job_tier: int = Field(ge=1, le=4, description="Job tier (1=Novice, 2=1st, 3=2nd, 4=3rd)")
    requirements: JobRequirements = Field(description="Requirements for this job")
    npc_location: JobNPCLocation | None = Field(default=None, description="Job change NPC")
    
    # For classes with multiple paths (e.g., Swordman → Knight OR Crusader)
    next_jobs: list[str] = Field(
        default_factory=list,
        description="Possible next job advancements"
    )


class JobAdvancementSystem:
    """
    Autonomous job advancement automation.
    
    Features:
    - Automatic job path selection based on build/preferences
    - NPC navigation for job change
    - Prerequisite validation (levels, items, quests)
    - Job test completion (placeholders for server-specific tests)
    - Support for both classic and renewal job systems
    """
    
    def __init__(
        self,
        job_paths_file: Path,
        job_npcs_file: Path,
        preferred_path: dict[str, str] | None = None
    ):
        """
        Initialize job advancement system.
        
        Args:
            job_paths_file: Path to job_paths.json
            job_npcs_file: Path to job_npcs.json  
            preferred_path: Preferred job choices at each branch
        """
        self.preferred_path = preferred_path or {}
        self._job_paths: dict[str, JobPath] = {}
        self._npc_locations: dict[str, JobNPCLocation] = {}
        
        # Load configuration
        self._load_job_paths(job_paths_file)
        self._load_npc_locations(job_npcs_file)
    
    def _load_job_paths(self, file_path: Path) -> None:
        """Load job advancement paths from JSON."""
        try:
            if not file_path.exists():
                logger.warning(f"Job paths file not found: {file_path}")
                return
            
            data = json.loads(file_path.read_text(encoding="utf-8"))
            
            for job_data in data.get("jobs", []):
                job_path = JobPath.model_validate(job_data)
                self._job_paths[job_path.job_name] = job_path
            
            logger.info(
                "Job paths loaded",
                job_count=len(self._job_paths)
            )
            
        except Exception as e:
            logger.error(f"Failed to load job paths: {e}")
    
    def _load_npc_locations(self, file_path: Path) -> None:
        """Load NPC locations from JSON."""
        try:
            if not file_path.exists():
                logger.warning(f"Job NPCs file not found: {file_path}")
                return
            
            data = json.loads(file_path.read_text(encoding="utf-8"))
            
            # Skip metadata keys when parsing NPC locations
            metadata_keys = {"version", "description", "comment"}
            
            for job_name, npc_data in data.items():
                # Skip metadata fields
                if job_name in metadata_keys:
                    continue
                    
                self._npc_locations[job_name] = JobNPCLocation.model_validate(npc_data)
            
            logger.info(
                "Job NPC locations loaded",
                npc_count=len(self._npc_locations)
            )
            
        except Exception as e:
            logger.error(f"Failed to load NPC locations: {e}")
    
    def get_current_job_path(self, job_class: str) -> JobPath | None:
        """
        Get job path info for current job.
        
        Args:
            job_class: Current job class name
            
        Returns:
            JobPath if found, None otherwise
        """
        return self._job_paths.get(job_class)
    
    def get_next_job_options(self, current_job: str) -> list[str]:
        """
        Get available job advancement options.
        
        Args:
            current_job: Current job class name
            
        Returns:
            List of possible next job class names
        """
        job_path = self._job_paths.get(current_job)
        
        if not job_path:
            return []
        
        return job_path.next_jobs
    
    def select_next_job(self, current_job: str, character: CharacterState) -> str | None:
        """
        Select next job based on preferences and build.
        
        Args:
            current_job: Current job class name
            character: Character state (for build analysis)
            
        Returns:
            Selected next job class name, or None if no advancement available
        """
        options = self.get_next_job_options(current_job)
        
        if not options:
            return None
        
        # Check for user preference
        if current_job in self.preferred_path:
            preferred = self.preferred_path[current_job]
            if preferred in options:
                return preferred
        
        # Auto-select based on stats if no preference
        if len(options) == 1:
            return options[0]
        
        # For multi-path decision, choose based on highest stat
        current_stats = {
            "STR": character.str,
            "AGI": character.agi,
            "VIT": character.vit,
            "INT": character.int_stat if hasattr(character, 'int_stat') else character.int,
            "DEX": character.dex,
            "LUK": character.luk,
        }
        
        # Simple heuristic: pick based on dominant stat
        # This is a placeholder - real implementation would use more sophisticated logic
        logger.info(
            "Auto-selecting job path",
            current_job=current_job,
            options=options,
            using_first_option=options[0]
        )
        
        return options[0]
    
    def check_requirements(
        self,
        target_job: str,
        character: CharacterState
    ) -> tuple[bool, list[str]]:
        """
        Check if character meets requirements for job advancement.
        
        Args:
            target_job: Target job class name
            character: Current character state
            
        Returns:
            Tuple of (requirements_met: bool, missing_requirements: list[str])
        """
        job_path = self._job_paths.get(target_job)
        
        if not job_path:
            return False, [f"Unknown job: {target_job}"]
        
        reqs = job_path.requirements
        missing: list[str] = []
        
        # Check base level
        if character.base_level < reqs.base_level:
            missing.append(
                f"Base level {character.base_level}/{reqs.base_level}"
            )
        
        # Check job level
        if character.job_level < reqs.job_level:
            missing.append(
                f"Job level {character.job_level}/{reqs.job_level}"
            )
        
        # Check zeny
        if character.zeny < reqs.zeny_cost:
            missing.append(
                f"Zeny {character.zeny}/{reqs.zeny_cost}"
            )
        
        # Check required items
        if reqs.required_items:
            for item_req in reqs.required_items:
                for item_id, quantity in item_req.items():
                    # Check if character has item in inventory
                    item_count = self._get_item_count_in_inventory(
                        character,
                        item_id
                    )
                    if item_count < quantity:
                        missing.append(
                            f"Item {item_id}: {item_count}/{quantity}"
                        )
        
        return len(missing) == 0, missing
    
    async def check_advancement(
        self,
        character: CharacterState,
        lifecycle_state: LifecycleState
    ) -> list[Action]:
        """
        Check if character can/should advance to next job.
        
        Args:
            character: Current character state
            lifecycle_state: Current lifecycle state
            
        Returns:
            List of actions needed for job advancement
        """
        # Only check for advancement in relevant states
        if lifecycle_state not in [
            LifecycleState.NOVICE,
            LifecycleState.FIRST_JOB,
            LifecycleState.SECOND_JOB,
            LifecycleState.REBIRTH,
        ]:
            return []
        
        current_job = character.job_class
        next_job = self.select_next_job(current_job, character)
        
        if not next_job:
            return []
        
        # Check requirements
        requirements_met, missing = self.check_requirements(next_job, character)
        
        if not requirements_met:
            logger.debug(
                "Job advancement requirements not met",
                current_job=current_job,
                target_job=next_job,
                missing=missing
            )
            return []
        
        logger.info(
            "Job advancement available",
            current_job=current_job,
            target_job=next_job,
            lifecycle_state=lifecycle_state.value
        )
        
        # Generate navigation action to job NPC
        npc_location = self._npc_locations.get(next_job)
        
        if not npc_location:
            logger.warning(
                "NPC location not found for job",
                job=next_job
            )
            return []
        
        # Create action to navigate to job NPC
        action = Action(
            type=ActionType.NOOP,  # Placeholder - actual navigation handled by OpenKore
            priority=1,  # Highest priority
            extra={
                "action_subtype": "job_advancement",
                "target_job": next_job,
                "npc_map": npc_location.map_name,
                "npc_x": npc_location.x,
                "npc_y": npc_location.y,
                "npc_name": npc_location.npc_name,
                "test_required": self._job_paths[next_job].requirements.test_required,
                "test_type": self._job_paths[next_job].requirements.test_type,
            }
        )
        
        return [action]
    
    async def complete_job_test(
        self,
        test_type: str,
        test_params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Execute job test completion logic.
        
        This is a placeholder implementation. Actual test completion
        would require server-specific logic.
        
        Args:
            test_type: Type of test (hunting_quest, item_quest, etc.)
            test_params: Parameters for the test
            game_state: Current game state
            
        Returns:
            True if test completed/progressed, False otherwise
        """
        logger.info(
            "Job test execution requested",
            test_type=test_type,
            params=test_params
        )
        
        # Placeholder implementations for different test types
        test_handlers = {
            "hunting_quest": self._handle_hunting_test,
            "item_quest": self._handle_item_test,
            "mushroom_quest": self._handle_mushroom_test,
            "undead_quest": self._handle_undead_test,
            "combat_test": self._handle_combat_test,
            "magic_quiz": self._handle_quiz_test,
            "trap_maze": self._handle_maze_test,
        }
        
        handler = test_handlers.get(test_type)
        
        if not handler:
            logger.warning(f"Unknown test type: {test_type}")
            return False
        
        return await handler(test_params, game_state)
    
    async def _handle_hunting_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle hunting quest tests (kill X monsters).
        
        Integrates with combat AI system to hunt specific monsters.
        """
        monster = params.get("monster", "")
        count = params.get("count", 0)
        current_count = params.get("current_count", 0)
        
        logger.info(
            "Hunting test in progress",
            target_monster=monster,
            required_kills=count,
            current_kills=current_count
        )
        
        # Check if test is complete
        if current_count >= count:
            logger.info(
                "Hunting test complete",
                monster=monster,
                kills=current_count
            )
            return True
        
        # Create hunt action for combat AI system
        # The combat AI will handle actual monster hunting
        hunt_action = {
            "action": "hunt_monster",
            "target_monster": monster,
            "target_count": count - current_count,
            "priority": "job_quest",
        }
        
        # Signal combat AI to start hunting
        if hasattr(game_state, 'combat_manager'):
            game_state.combat_manager.set_hunt_target(hunt_action)
        
        return False  # Not complete yet, continue hunting
    
    async def _handle_item_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle item collection tests.
        
        Checks inventory and triggers farming if items are missing.
        """
        items = params.get("items", [])
        
        logger.info("Item collection test in progress", required_items=items)
        
        character = game_state.character
        all_items_collected = True
        missing_items = []
        
        # Check inventory for each required item
        for item_req in items:
            item_id = item_req.get("item_id")
            quantity = item_req.get("quantity", 1)
            
            current_count = self._get_item_count_in_inventory(character, item_id)
            
            if current_count < quantity:
                all_items_collected = False
                missing_items.append({
                    "item_id": item_id,
                    "needed": quantity - current_count,
                    "current": current_count
                })
        
        if all_items_collected:
            logger.info("All items collected for job test")
            return True
        
        # Farm missing items
        logger.info("Missing items, initiating farming", missing=missing_items)
        
        for missing in missing_items:
            # Trigger farming behavior
            farm_action = {
                "action": "farm_item",
                "item_id": missing["item_id"],
                "quantity": missing["needed"],
                "priority": "job_quest"
            }
            
            # Signal farming system
            if hasattr(game_state, 'farming_manager'):
                game_state.farming_manager.add_farm_target(farm_action)
        
        return False  # Not complete, continue farming
    
    async def _handle_mushroom_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle Thief guild mushroom test.
        
        Navigates through the mushroom collection maze.
        """
        logger.info("Mushroom test - navigating maze")
        
        # Mushroom test requires navigating maze and collecting mushrooms
        target_mushrooms = params.get("mushroom_count", 6)
        current_mushrooms = params.get("current_mushrooms", 0)
        
        if current_mushrooms >= target_mushrooms:
            logger.info("Mushroom test complete", collected=current_mushrooms)
            return True
        
        # Navigate using pathfinding to collect mushrooms
        maze_map = params.get("maze_map", "job_thief1")
        
        navigation_action = {
            "action": "navigate_maze",
            "map": maze_map,
            "objective": "collect_mushrooms",
            "target_count": target_mushrooms - current_mushrooms,
            "avoid_warps": True  # Some warps reset progress
        }
        
        if hasattr(game_state, 'navigation_manager'):
            game_state.navigation_manager.execute_maze_navigation(navigation_action)
        
        return False  # Continue collecting
    
    async def _handle_undead_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle Acolyte undead hunting test.
        
        Hunt specified undead monsters for job advancement.
        """
        logger.info("Undead test - hunting undead monsters")
        
        # Acolyte test requires hunting undead monsters
        target_kills = params.get("undead_kills", 10)
        current_kills = params.get("current_kills", 0)
        undead_type = params.get("undead_type", "Zombie")
        
        if current_kills >= target_kills:
            logger.info("Undead test complete", kills=current_kills)
            return True
        
        # Hunt specific undead monsters
        hunt_action = {
            "action": "hunt_monster",
            "target_monster": undead_type,
            "target_count": target_kills - current_kills,
            "monster_race": "undead",  # Filter for undead race
            "priority": "job_quest",
            "preferred_map": params.get("hunt_map", "pay_fild08")
        }
        
        if hasattr(game_state, 'combat_manager'):
            game_state.combat_manager.set_hunt_target(hunt_action)
        
        return False  # Continue hunting
    
    async def _handle_combat_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle combat skill test.
        
        Complete combat test instance (e.g., Knight trial).
        """
        logger.info("Combat test - instance challenge")
        
        # Combat tests are usually instanced battles
        instance_map = params.get("instance_map", "job_knight")
        test_stage = params.get("test_stage", 1)
        max_stages = params.get("max_stages", 3)
        
        if test_stage > max_stages:
            logger.info("Combat test complete", stages_completed=max_stages)
            return True
        
        # Execute combat in test instance
        combat_action = {
            "action": "instance_combat",
            "map": instance_map,
            "stage": test_stage,
            "strategy": params.get("strategy", "aggressive"),
            "time_limit": params.get("time_limit", 300),  # 5 minutes
            "priority": "job_quest"
        }
        
        if hasattr(game_state, 'combat_manager'):
            game_state.combat_manager.enter_instance_combat(combat_action)
        
        return False  # Instance in progress
    
    def can_advance(self, character: CharacterState) -> bool:
        """
        Check if character can advance to any next job.
        
        Args:
            character: Character state
            
        Returns:
            True if can advance to any next job
        """
        current_job = character.job_class
        next_job = self.select_next_job(current_job, character)
        
        if not next_job:
            return False
        
        requirements_met, _ = self.check_requirements(next_job, character)
        return requirements_met
    
    def _get_item_count_in_inventory(
        self,
        character: CharacterState,
        item_id: str
    ) -> int:
        """
        Get count of specific item in character inventory.
        
        Args:
            character: Character state with inventory
            item_id: Item ID to search for
            
        Returns:
            Count of items in inventory
        """
        if not hasattr(character, 'inventory'):
            logger.warning("Character has no inventory attribute")
            return 0
        
        count = 0
        for item in character.inventory:
            if str(item.get('id', '')) == str(item_id):
                count += item.get('amount', 1)
        
        return count
    
    def _get_quiz_answers(self, quiz_type: str) -> dict[str, str]:
        """
        Load quiz answers from database.
        
        Args:
            quiz_type: Type of quiz (mage, sage, etc.)
            
        Returns:
            Dictionary mapping question keywords to answers
        """
        # Quiz answer database for common job tests
        quiz_databases = {
            "mage": {
                "what is magic": "The power of nature",
                "fire element": "Fire Ball",
                "ice element": "Cold Bolt",
                "thunder element": "Lightning Bolt",
                "earth element": "Earth Spike",
                "what does int": "Increases magic damage",
                "what is sp": "Spell Points for casting",
                "mage weapon": "Staff or Rod",
                "magic defense": "Magic Defense (MDEF)",
                "cast time": "DEX reduces cast time"
            },
            "sage": {
                "history of magic": "Ancient times",
                "magic theory": "Understanding elements",
                "advanced magic": "Multiple elements",
                "sage role": "Magic researcher",
                "element weakness": "Fire beats Earth",
                "magic circles": "Ancient spell formations",
                "rune magic": "Symbol-based casting",
                "spell books": "Store magic knowledge",
                "magic academy": "Juno Academy",
                "magic research": "Understanding magic"
            },
            "priest": {
                "what is holy": "Divine power",
                "healing": "Restoration magic",
                "support role": "Assist party members",
                "demon race": "Vulnerable to holy",
                "undead race": "Weak against holy",
                "blessing": "Increases stats",
                "resurrection": "Revive dead allies",
                "sanctuary": "Holy ground healing",
                "prayers": "Divine invocation",
                "faith": "Belief in divinity"
            }
        }
        
        return quiz_databases.get(quiz_type, {})
    
    def _match_quiz_answer(
        self,
        question: str,
        answers_db: dict[str, str]
    ) -> str | None:
        """
        Match quiz question to answer using keyword matching.
        
        Args:
            question: Question text from NPC
            answers_db: Database of answers
            
        Returns:
            Answer string or None if not found
        """
        if not question or not answers_db:
            return None
        
        question_lower = question.lower()
        
        # Try to find matching keywords
        for keyword, answer in answers_db.items():
            if keyword.lower() in question_lower:
                return answer
        
        # No match found
        return None
    
    def _calculate_distance(
        self,
        pos1: dict[str, int],
        pos2: dict[str, int]
    ) -> float:
        """
        Calculate Euclidean distance between two points.
        
        Args:
            pos1: First position {x, y}
            pos2: Second position {x, y}
            
        Returns:
            Distance between points
        """
        import math
        
        dx = pos1['x'] - pos2['x']
        dy = pos1['y'] - pos2['y']
        
        return math.sqrt(dx * dx + dy * dy)
    
    async def _handle_quiz_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle magic quiz test.
        
        Answer quiz questions using knowledge database.
        """
        logger.info("Quiz test - answering questions")
        
        # Quiz tests require answering multiple choice questions
        current_question = params.get("question_number", 1)
        total_questions = params.get("total_questions", 10)
        
        if current_question > total_questions:
            logger.info("Quiz test complete", questions_answered=total_questions)
            return True
        
        # Load quiz answers database
        quiz_answers = self._get_quiz_answers(params.get("quiz_type", "mage"))
        
        question_text = params.get("question_text", "")
        
        # Find matching answer
        answer = self._match_quiz_answer(question_text, quiz_answers)
        
        if answer:
            logger.info(
                "Quiz answer found",
                question=current_question,
                answer=answer
            )
            
            # Send answer to NPC dialogue system
            if hasattr(game_state, 'dialogue_manager'):
                game_state.dialogue_manager.select_option(answer)
        else:
            logger.warning(
                "Quiz answer not found",
                question_text=question_text
            )
        
        return False  # Quiz in progress
    
    async def _handle_maze_test(
        self,
        params: dict[str, Any],
        game_state: GameState
    ) -> bool:
        """
        Handle trap/maze navigation test.
        
        Navigate maze instance avoiding traps.
        """
        logger.info("Maze test - navigating trapped maze")
        
        # Maze tests require careful navigation through trapped areas
        maze_map = params.get("maze_map", "job_hunter")
        goal_coords = params.get("goal", {"x": 100, "y": 100})
        current_pos = {
            "x": game_state.character.x,
            "y": game_state.character.y
        }
        
        # Check if reached goal
        distance = self._calculate_distance(current_pos, goal_coords)
        if distance <= 2:
            logger.info("Maze test complete", reached_goal=True)
            return True
        
        # Navigate carefully avoiding known traps
        trap_locations = params.get("trap_locations", [])
        
        navigation_action = {
            "action": "navigate_maze",
            "map": maze_map,
            "goal": goal_coords,
            "avoid_cells": trap_locations,
            "strategy": "cautious",  # Slow movement to detect traps
            "priority": "job_quest"
        }
        
        if hasattr(game_state, 'navigation_manager'):
            game_state.navigation_manager.execute_maze_navigation(navigation_action)
        
        return False  # Navigation in progress
    
    def get_job_path_summary(self, current_job: str) -> dict[str, Any]:
        """
        Get summary of possible job progression from current job.
        
        Args:
            current_job: Current job class name
            
        Returns:
            Dictionary with progression information
        """
        current_path = self._job_paths.get(current_job)
        
        if not current_path:
            return {
                "current_job": current_job,
                "job_tier": None,
                "next_jobs": [],
                "requirements": {},
            }
        
        next_options = []
        for next_job_name in current_path.next_jobs:
            next_path = self._job_paths.get(next_job_name)
            if next_path:
                next_options.append({
                    "job_name": next_job_name,
                    "job_tier": next_path.job_tier,
                    "requirements": {
                        "base_level": next_path.requirements.base_level,
                        "job_level": next_path.requirements.job_level,
                        "zeny": next_path.requirements.zeny_cost,
                        "test_required": next_path.requirements.test_required,
                    },
                    "npc_location": (
                        next_path.npc_location.model_dump()
                        if next_path.npc_location
                        else None
                    ),
                })
        
        return {
            "current_job": current_job,
            "job_tier": current_path.job_tier,
            "next_jobs": next_options,
        }
    
    def validate_job_path_continuity(self) -> list[str]:
        """
        Validate that all job paths have valid next_jobs references.
        
        Returns:
            List of validation errors (empty if valid)
        """
        errors: list[str] = []
        
        for job_name, job_path in self._job_paths.items():
            for next_job in job_path.next_jobs:
                if next_job not in self._job_paths:
                    errors.append(
                        f"Job '{job_name}' references unknown next job '{next_job}'"
                    )
        
        return errors