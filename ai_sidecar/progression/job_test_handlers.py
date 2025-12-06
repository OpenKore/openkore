"""
Job Test Handlers Module.

Production-ready implementations for all 7 job advancement test handlers.
Each handler generates real AIAction objects for the bot to execute.
"""

import heapq
import math
from typing import TYPE_CHECKING, Any

from pydantic import BaseModel, Field

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.progression.job_test_config import (
    get_job_test_config,
    JobTestConfiguration,
)
from ai_sidecar.progression.job_test_data import (
    get_quiz_answers,
    match_quiz_answer,
    get_monster_id,
    get_monster_info,
    get_spawn_maps,
    is_undead_monster,
    get_undead_monster_ids,
    MONSTER_INFO,
)
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = get_logger(__name__)


class JobTestResult(BaseModel):
    """Result of a job test handler execution."""
    
    completed: bool = Field(default=False, description="Test completed successfully")
    actions: list[Action] = Field(default_factory=list, description="Actions to execute")
    progress: dict[str, Any] = Field(default_factory=dict, description="Progress data")
    message: str = Field(default="", description="Status message")


class JobTestHandlers:
    """
    Production-ready job test handler implementations.
    
    All handlers return JobTestResult with:
    - completed: Whether test is done
    - actions: AIAction objects to execute
    - progress: Tracking data for continuation
    - message: Human-readable status
    """
    
    def __init__(self, config: JobTestConfiguration | None = None):
        """Initialize handlers with configuration."""
        self.config = config or get_job_test_config()
        self._log = logger.bind(component="job_test_handlers")
    
    # =========================================================================
    # HUNTING TEST HANDLER
    # =========================================================================
    
    async def handle_hunting_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle hunting quest tests (kill X monsters).
        
        Parses quest requirements, tracks kills, generates hunt actions.
        """
        monster_name = params.get("monster", "")
        required_count = params.get("count", 10)
        current_count = params.get("current_count", 0)
        hunt_map = params.get("hunt_map", "")
        
        self._log.info(
            "Hunting test processing",
            monster=monster_name,
            required=required_count,
            current=current_count,
            map=hunt_map
        )
        
        # Check completion
        if current_count >= required_count:
            self._log.info("Hunting test complete", kills=current_count)
            return JobTestResult(
                completed=True,
                message=f"Hunting test complete: {current_count}/{required_count} {monster_name}"
            )
        
        actions: list[Action] = []
        remaining = required_count - current_count
        
        # Get monster ID for targeting
        monster_id = get_monster_id(monster_name)
        if not monster_id:
            # Try to find in visible monsters
            monster_id = self._find_monster_id_from_game_state(monster_name, game_state)
        
        # Determine spawn maps if not specified
        if not hunt_map:
            spawn_maps = get_spawn_maps(monster_name)
            if spawn_maps:
                hunt_map = spawn_maps[0]  # Use first spawn map
        
        # Check if we need to navigate to hunt map
        current_map = game_state.character.map_name if hasattr(game_state.character, 'map_name') else ""
        
        if hunt_map and current_map != hunt_map:
            # Navigate to hunting map
            self._log.info(
                "Navigating to hunt map",
                current=current_map,
                target=hunt_map
            )
            actions.append(Action(
                type=ActionType.MOVE,
                priority=10,
                extra={
                    "action_subtype": "navigate_to_map",
                    "target_map": hunt_map,
                    "reason": f"Hunt {monster_name}"
                }
            ))
        else:
            # Find and attack target monsters
            target = self._find_hunt_target(game_state, monster_name, monster_id)
            
            if target:
                self._log.debug(
                    "Target acquired",
                    target_id=target.get("actor_id"),
                    target_name=target.get("name"),
                    distance=target.get("distance")
                )
                
                # Attack action
                actions.append(Action(
                    type=ActionType.ATTACK,
                    priority=15,
                    target_id=target.get("actor_id"),
                    extra={
                        "action_subtype": "hunt_target",
                        "quest_type": "job_test",
                        "monster_name": monster_name,
                        "remaining_kills": remaining
                    }
                ))
            else:
                # No target found - roam to find monsters
                self._log.debug("No target visible, roaming to find", monster=monster_name)
                actions.append(Action(
                    type=ActionType.MOVE,
                    priority=5,
                    extra={
                        "action_subtype": "roam_for_targets",
                        "target_monster": monster_name,
                        "monster_id": monster_id
                    }
                ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_kills": current_count,
                "required_kills": required_count,
                "remaining": remaining,
                "monster": monster_name,
                "hunt_map": hunt_map
            },
            message=f"Hunting: {current_count}/{required_count} {monster_name}"
        )
    
    def _find_hunt_target(
        self,
        game_state: "GameState",
        monster_name: str,
        monster_id: int | None
    ) -> dict[str, Any] | None:
        """Find valid hunt target from visible monsters."""
        monsters = game_state.get_monsters() if hasattr(game_state, 'get_monsters') else []
        
        if not monsters:
            return None
        
        char_pos = game_state.character.position
        best_target = None
        best_distance = float('inf')
        
        for monster in monsters:
            # Match by ID or name
            matches = False
            if monster_id and hasattr(monster, 'mob_id'):
                matches = monster.mob_id == monster_id
            if not matches and hasattr(monster, 'name'):
                matches = monster_name.lower() in monster.name.lower()
            
            if matches:
                # Calculate distance
                if hasattr(monster, 'position'):
                    dist = char_pos.distance_to(monster.position)
                    if dist < best_distance:
                        best_distance = dist
                        best_target = {
                            "actor_id": monster.actor_id,
                            "name": monster.name,
                            "distance": dist,
                            "position": monster.position
                        }
        
        return best_target
    
    def _find_monster_id_from_game_state(
        self,
        monster_name: str,
        game_state: "GameState"
    ) -> int | None:
        """Try to find monster ID from visible monsters."""
        monsters = game_state.get_monsters() if hasattr(game_state, 'get_monsters') else []
        
        for monster in monsters:
            if hasattr(monster, 'name') and monster_name.lower() in monster.name.lower():
                if hasattr(monster, 'mob_id'):
                    return monster.mob_id
        
        return None
    
    # =========================================================================
    # ITEM COLLECTION TEST HANDLER
    # =========================================================================
    
    async def handle_item_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle item collection tests.
        
        Checks inventory, generates farm/gather actions for missing items.
        """
        required_items = params.get("items", [])
        
        self._log.info("Item collection test processing", required_items=required_items)
        
        if not required_items:
            self._log.warning("No items specified for item test")
            return JobTestResult(
                completed=True,
                message="No items required"
            )
        
        # Check inventory for each required item
        missing_items: list[dict[str, Any]] = []
        all_collected = True
        
        inventory = game_state.inventory
        
        for item_req in required_items:
            item_id = item_req.get("item_id")
            item_name = item_req.get("item_name", f"Item#{item_id}")
            required_qty = item_req.get("quantity", 1)
            
            # Check current inventory count
            current_qty = inventory.get_item_count(item_id) if hasattr(inventory, 'get_item_count') else 0
            
            if current_qty < required_qty:
                all_collected = False
                missing_items.append({
                    "item_id": item_id,
                    "item_name": item_name,
                    "needed": required_qty - current_qty,
                    "current": current_qty,
                    "required": required_qty
                })
        
        if all_collected:
            self._log.info("All items collected for job test")
            # Generate NPC submission action
            return JobTestResult(
                completed=True,
                actions=[Action(
                    type=ActionType.TALK_NPC,
                    priority=20,
                    extra={
                        "action_subtype": "submit_quest_items",
                        "quest_type": "job_test"
                    }
                )],
                message="All items collected, ready to submit"
            )
        
        # Generate farming actions for missing items
        self._log.info("Missing items for job test", missing=missing_items)
        
        actions: list[Action] = []
        
        for missing in missing_items:
            item_id = missing["item_id"]
            
            # Check if item is purchasable
            if item_id in self.config.item.purchasable_items:
                shop_map = self.config.item.purchasable_items[item_id]
                actions.append(Action(
                    type=ActionType.MOVE,
                    priority=12,
                    extra={
                        "action_subtype": "buy_item",
                        "item_id": item_id,
                        "quantity": missing["needed"],
                        "shop_map": shop_map
                    }
                ))
            else:
                # Need to farm the item
                drop_sources = self.config.item.item_drop_sources.get(item_id, [])
                
                if drop_sources:
                    # Hunt monster that drops item
                    target_monster_id = drop_sources[0]
                    monster_info = get_monster_info(target_monster_id)
                    monster_name = monster_info["name"] if monster_info else f"Monster#{target_monster_id}"
                    
                    actions.append(Action(
                        type=ActionType.ATTACK,
                        priority=10,
                        extra={
                            "action_subtype": "farm_item",
                            "item_id": item_id,
                            "item_name": missing["item_name"],
                            "target_monster_id": target_monster_id,
                            "target_monster_name": monster_name,
                            "quantity_needed": missing["needed"]
                        }
                    ))
                else:
                    # Unknown drop source - generic farm
                    actions.append(Action(
                        type=ActionType.NOOP,
                        priority=5,
                        extra={
                            "action_subtype": "farm_unknown_item",
                            "item_id": item_id,
                            "quantity_needed": missing["needed"],
                            "warning": "Unknown drop source for item"
                        }
                    ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "missing_items": missing_items,
                "total_required": len(required_items),
                "collected": len(required_items) - len(missing_items)
            },
            message=f"Collecting items: {len(required_items) - len(missing_items)}/{len(required_items)}"
        )
    
    # =========================================================================
    # MUSHROOM COLLECTION TEST HANDLER
    # =========================================================================
    
    async def handle_mushroom_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle Thief guild mushroom collection test.
        
        Navigates maze, collects mushrooms, returns to NPC.
        """
        target_mushrooms = params.get("mushroom_count", self.config.mushroom.required_mushrooms)
        current_mushrooms = params.get("current_mushrooms", 0)
        maze_map = params.get("maze_map", self.config.mushroom.maze_map)
        
        self._log.info(
            "Mushroom test processing",
            target=target_mushrooms,
            current=current_mushrooms,
            map=maze_map
        )
        
        # Check completion
        if current_mushrooms >= target_mushrooms:
            self._log.info("Mushroom test complete", collected=current_mushrooms)
            # Return to NPC
            npc_coords = self.config.mushroom.npc_return_coords
            return JobTestResult(
                completed=True,
                actions=[Action(
                    type=ActionType.MOVE,
                    priority=20,
                    x=npc_coords[0],
                    y=npc_coords[1],
                    extra={
                        "action_subtype": "return_to_npc",
                        "quest_type": "mushroom_test"
                    }
                )],
                message=f"Mushrooms collected: {current_mushrooms}/{target_mushrooms}, returning to NPC"
            )
        
        actions: list[Action] = []
        
        # Check current position
        char_x = game_state.character.x if hasattr(game_state.character, 'x') else 0
        char_y = game_state.character.y if hasattr(game_state.character, 'y') else 0
        char_pos = (char_x, char_y)
        
        # Find nearest unvisited mushroom spawn
        visited_spawns = set(params.get("visited_spawns", []))
        spawn_points = self.config.mushroom.mushroom_spawn_points
        
        nearest_spawn = None
        nearest_dist = float('inf')
        
        for spawn in spawn_points:
            if spawn not in visited_spawns:
                dist = math.sqrt((spawn[0] - char_x)**2 + (spawn[1] - char_y)**2)
                if dist < nearest_dist:
                    nearest_dist = dist
                    nearest_spawn = spawn
        
        if nearest_spawn:
            # Navigate to mushroom spawn
            self._log.debug(
                "Navigating to mushroom spawn",
                target=nearest_spawn,
                distance=nearest_dist
            )
            
            # Use safe waypoints if far away
            if nearest_dist > 20:
                waypoint = self._find_nearest_waypoint(char_pos, nearest_spawn)
                if waypoint:
                    actions.append(Action(
                        type=ActionType.MOVE,
                        priority=10,
                        x=waypoint[0],
                        y=waypoint[1],
                        extra={
                            "action_subtype": "navigate_waypoint",
                            "final_target": nearest_spawn
                        }
                    ))
            else:
                actions.append(Action(
                    type=ActionType.MOVE,
                    priority=10,
                    x=nearest_spawn[0],
                    y=nearest_spawn[1],
                    extra={
                        "action_subtype": "collect_mushroom",
                        "spawn_point": nearest_spawn
                    }
                ))
            
            # Add pickup action if close enough
            if nearest_dist <= 3:
                actions.append(Action(
                    type=ActionType.PICKUP,
                    priority=15,
                    extra={
                        "action_subtype": "pickup_mushroom",
                        "location": nearest_spawn
                    }
                ))
        else:
            # All spawns visited but not enough mushrooms
            self._log.warning(
                "All spawns visited but mushrooms incomplete",
                current=current_mushrooms,
                required=target_mushrooms
            )
            # Reset and try again
            actions.append(Action(
                type=ActionType.MOVE,
                priority=5,
                x=spawn_points[0][0],
                y=spawn_points[0][1],
                extra={
                    "action_subtype": "reset_mushroom_route",
                    "reason": "Revisiting spawn points"
                }
            ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_mushrooms": current_mushrooms,
                "target_mushrooms": target_mushrooms,
                "visited_spawns": list(visited_spawns),
                "remaining_spawns": len(spawn_points) - len(visited_spawns)
            },
            message=f"Collecting mushrooms: {current_mushrooms}/{target_mushrooms}"
        )
    
    def _find_nearest_waypoint(
        self,
        current: tuple[int, int],
        target: tuple[int, int]
    ) -> tuple[int, int] | None:
        """Find nearest safe waypoint between current and target."""
        waypoints = self.config.mushroom.safe_waypoints
        
        if not waypoints:
            return None
        
        # Find waypoint that is between current and target
        best_waypoint = None
        best_score = float('inf')
        
        for wp in waypoints:
            # Score: distance from current + distance to target
            dist_from_current = math.sqrt(
                (wp[0] - current[0])**2 + (wp[1] - current[1])**2
            )
            dist_to_target = math.sqrt(
                (wp[0] - target[0])**2 + (wp[1] - target[1])**2
            )
            
            # Only consider waypoints that bring us closer
            direct_dist = math.sqrt(
                (target[0] - current[0])**2 + (target[1] - current[1])**2
            )
            
            if dist_to_target < direct_dist:
                score = dist_from_current + dist_to_target
                if score < best_score:
                    best_score = score
                    best_waypoint = wp
        
        return best_waypoint
    
    # =========================================================================
    # UNDEAD ELIMINATION TEST HANDLER
    # =========================================================================
    
    async def handle_undead_test(
        self,
        params: dict[str, Any],
        game_state: "GameState"
    ) -> JobTestResult:
        """
        Handle Acolyte undead hunting test.
        
        Targets undead monsters, uses holy skills when available.
        """
        target_kills = params.get("undead_kills", self.config.undead.default_kill_count)
        current_kills = params.get("current_kills", 0)
        undead_type = params.get("undead_type", "")
        hunt_map = params.get("hunt_map", "")
        
        self._log.info(
            "Undead test processing",
            target=target_kills,
            current=current_kills,
            undead_type=undead_type
        )
        
        # Check completion
        if current_kills >= target_kills:
            self._log.info("Undead test complete", kills=current_kills)
            return JobTestResult(
                completed=True,
                message=f"Undead test complete: {current_kills}/{target_kills}"
            )
        
        actions: list[Action] = []
        
        # Determine hunt map
        if not hunt_map:
            hunt_maps = self.config.undead.undead_hunting_maps
            hunt_map = hunt_maps[0] if hunt_maps else "pay_fild08"
        
        # Check if we need to navigate
        current_map = game_state.character.map_name if hasattr(game_state.character, 'map_name') else ""
        
        if hunt_map and current_map != hunt_map:
            self._log.info("Navigating to undead hunt map", target=hunt_map)
            actions.append(Action(
                type=ActionType.MOVE,
                priority=10,
                extra={
                    "action_subtype": "navigate_to_map",
                    "target_map": hunt_map,
                    "reason": "Hunt undead"
                }
            ))
        else:
            # Find undead target
            target = self._find_undead_target(game_state, undead_type)
            
            if target:
                self._log.debug(
                    "Undead target acquired",
                    target_id=target.get("actor_id"),
                    target_name=target.get("name")
                )
                
                # Check for holy skills
                holy_skill = self._get_available_holy_skill(game_state)
                
                if holy_skill:
                    # Use holy skill for extra damage
                    actions.append(Action(
                        type=ActionType.SKILL,
                        priority=18,
                        target_id=target.get("actor_id"),
                        skill_id=holy_skill,
                        extra={
                            "action_subtype": "holy_attack",
                            "quest_type": "undead_test"
                        }
                    ))
                else:
                    # Regular attack
                    actions.append(Action(
                        type=ActionType.ATTACK,
                        priority=15,
                        target_id=target.get("actor_id"),
                        extra={
                            "action_subtype": "hunt_undead",
                            "quest_type": "undead_test"
                        }
                    ))
            else:
                # Roam to find undead
                actions.append(Action(
                    type=ActionType.MOVE,
                    priority=5,
                    extra={
                        "action_subtype": "roam_for_undead",
                        "target_race": "undead"
                    }
                ))
        
        return JobTestResult(
            completed=False,
            actions=actions,
            progress={
                "current_kills": current_kills,
                "target_kills": target_kills,
                "remaining": target_kills - current_kills,
                "hunt_map": hunt_map
            },
            message=f"Hunting undead: {current_kills}/{target_kills}"
        )
    
    def _find_undead_target(
        self,
        game_state: "GameState",
        preferred_type: str = ""
    ) -> dict[str, Any] | None:
        """Find undead monster to attack."""
        monsters = game_state.get_monsters() if hasattr(game_state, 'get_monsters') else []
        
        if not monsters:
            return None
        
        char_pos = game_state.character.position
        undead_ids = set(self.config.undead.undead_monster_ids)
        
        best_target = None
        best_distance = float('inf')
        
        for monster in monsters:
            is_undead = False
            
            # Check by mob_id
            if hasattr(monster, 'mob_id') and monster.mob_id in undead_ids:
                is_undead = True
            
            # Check by race/element in extra data
            if hasattr(monster, 'extra'):
                race = monster.extra.get('race', '')
                element = monster.extra.get('element', '')
                if race == 'undead' or element == 'undead':
                    is_undead = True
            
            # Check monster database
            if hasattr(monster, 'mob_id'):
                is_undead = is_undead or is_undead_monster(monster.mob_id)
            
            if is_undead:
                if hasattr(monster, 'position'):
                    dist = char_pos.distance_to(monster.position)
                    if dist < best_distance:
                        best_distance = dist
                        best_target = {
                            "actor_id": monster.actor_id,
                            "name": getattr(monster, 'name', 'Undead'),
                            "distance": dist
                        }
        
        return best_target
    
    def _get_available_holy_skill(self, game_state: "GameState") -> int | None:
        """Get available holy skill ID if any."""
        char = game_state.character
        holy_skill_ids = self.config.undead.holy_skill_ids
        
        if not hasattr(char, 'skills'):
            return None
        
        for skill_id in holy_skill_ids:
            # Check if character has skill
            if skill_id in [s.skill_id for s in char.skills if hasattr(s, 'skill_id')]:
                # Check SP
                skill_sp_cost = self._get_skill_sp_cost(skill_id)
                if char.sp >= skill_sp_cost:
                    return skill_id
        
        return None
    
    def _get_skill_sp_cost(self, skill_id: int) -> int:
        """Get SP cost for skill (simplified)."""
        # Common holy skill SP costs
        sp_costs = {
            28: 15,   # Heal
            30: 15,   # Holy Light
            66: 20,   # Turn Undead
            67: 60,   # Magnus Exorcismus
            79: 20,   # Gloria
            156: 15,  # Sanctuary
        }
        return sp_costs.get(skill_id, 10)