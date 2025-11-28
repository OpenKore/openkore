"""
Instance Navigation System.

Handles pathfinding and positioning within instances including floor-to-floor
navigation, boss arena positioning, and loot collection routing.
"""

import heapq
import math
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.instances.strategy import BossStrategy

logger = structlog.get_logger(__name__)


class FloorMap(BaseModel):
    """Map data for an instance floor."""
    
    width: int = Field(ge=1)
    height: int = Field(ge=1)
    walkable_tiles: set[Tuple[int, int]] = Field(default_factory=set)
    boss_spawn_point: Optional[Tuple[int, int]] = None
    exit_portal: Optional[Tuple[int, int]] = None
    safe_zones: List[Tuple[int, int]] = Field(default_factory=list)
    danger_zones: List[Tuple[int, int]] = Field(default_factory=list)


class MonsterPosition(BaseModel):
    """Position of a monster on the floor."""
    
    monster_id: int
    monster_name: str
    position: Tuple[int, int]
    is_boss: bool = False
    is_aggressive: bool = False


class InstanceNavigator:
    """
    Handles navigation within instances.
    
    Features:
    - Floor-to-floor navigation
    - Monster avoidance pathing
    - Boss arena positioning
    - Loot collection routing
    - Emergency exit pathing
    """
    
    def __init__(self):
        """Initialize navigator."""
        self.log = structlog.get_logger(__name__)
        self.floor_maps: Dict[str, Dict[int, FloorMap]] = {}
        self.path_cache: Dict[Tuple, List[Tuple[int, int]]] = {}
    
    async def load_floor_map(
        self,
        instance_id: str,
        floor: int
    ) -> Optional[FloorMap]:
        """
        Load map data for a specific floor.
        
        Args:
            instance_id: Instance identifier
            floor: Floor number
            
        Returns:
            FloorMap or None if not found
        """
        if instance_id in self.floor_maps:
            return self.floor_maps[instance_id].get(floor)
        
        # In production, this would load from data files
        # For now, create a basic map
        basic_map = FloorMap(
            width=100,
            height=100,
            walkable_tiles=set(
                (x, y) for x in range(10, 90) for y in range(10, 90)
            ),
            boss_spawn_point=(50, 50),
            exit_portal=(10, 10)
        )
        
        if instance_id not in self.floor_maps:
            self.floor_maps[instance_id] = {}
        
        self.floor_maps[instance_id][floor] = basic_map
        return basic_map
    
    async def get_route_to_boss(
        self,
        current_pos: Tuple[int, int],
        floor_map: FloorMap
    ) -> List[Tuple[int, int]]:
        """
        Get optimal route to boss spawn.
        
        Args:
            current_pos: Current position
            floor_map: Floor map data
            
        Returns:
            List of waypoints to boss
        """
        if not floor_map.boss_spawn_point:
            return []
        
        return await self._find_path(
            current_pos,
            floor_map.boss_spawn_point,
            floor_map
        )
    
    async def get_clearing_route(
        self,
        current_pos: Tuple[int, int],
        floor_map: FloorMap,
        remaining_monsters: List[MonsterPosition]
    ) -> List[Tuple[int, int]]:
        """
        Get route to clear all monsters efficiently.
        
        Uses nearest-neighbor greedy algorithm for simplicity.
        
        Args:
            current_pos: Current position
            floor_map: Floor map data
            remaining_monsters: List of monsters to clear
            
        Returns:
            List of waypoints for efficient clearing
        """
        if not remaining_monsters:
            return []
        
        route: List[Tuple[int, int]] = []
        visited: set[int] = set()
        pos = current_pos
        
        while len(visited) < len(remaining_monsters):
            # Find nearest unvisited monster
            nearest = None
            nearest_dist = float('inf')
            
            for monster in remaining_monsters:
                if monster.monster_id in visited:
                    continue
                
                dist = self._manhattan_distance(pos, monster.position)
                if dist < nearest_dist:
                    nearest_dist = dist
                    nearest = monster
            
            if nearest:
                route.append(nearest.position)
                visited.add(nearest.monster_id)
                pos = nearest.position
        
        return route
    
    async def get_safe_position(
        self,
        boss_position: Tuple[int, int],
        strategy: BossStrategy
    ) -> Tuple[int, int]:
        """
        Get safe position during boss fight.
        
        Args:
            boss_position: Boss current position
            strategy: Boss strategy with positioning requirements
            
        Returns:
            Safe position coordinates
        """
        # Check predefined safe zones
        if strategy.safe_zones:
            # Return closest safe zone
            return min(
                strategy.safe_zones,
                key=lambda p: self._manhattan_distance(boss_position, p)
            )
        
        # Calculate safe position based on positioning strategy
        if strategy.positioning == "melee":
            # Stay close to boss
            return self._get_adjacent_position(boss_position, distance=2)
        
        elif strategy.positioning == "ranged":
            # Stay at range (5-7 tiles)
            return self._get_adjacent_position(boss_position, distance=6)
        
        elif strategy.positioning == "kite":
            # Stay far and ready to move (8-10 tiles)
            return self._get_adjacent_position(boss_position, distance=9)
        
        return boss_position
    
    def _get_adjacent_position(
        self,
        center: Tuple[int, int],
        distance: int
    ) -> Tuple[int, int]:
        """
        Get position at specified distance from center.
        
        Args:
            center: Center position
            distance: Desired distance
            
        Returns:
            Position at specified distance
        """
        cx, cy = center
        # Return position to the south (easier for bot)
        return (cx, cy + distance)
    
    async def get_loot_route(
        self,
        current_pos: Tuple[int, int],
        loot_positions: List[Tuple[int, int]]
    ) -> List[Tuple[int, int]]:
        """
        Get efficient route to collect all loot.
        
        Uses nearest-neighbor for efficiency.
        
        Args:
            current_pos: Current position
            loot_positions: List of loot item positions
            
        Returns:
            Ordered list of positions to visit
        """
        if not loot_positions:
            return []
        
        route: List[Tuple[int, int]] = []
        remaining = loot_positions.copy()
        pos = current_pos
        
        while remaining:
            # Find nearest loot
            nearest = min(
                remaining,
                key=lambda p: self._manhattan_distance(pos, p)
            )
            
            route.append(nearest)
            remaining.remove(nearest)
            pos = nearest
        
        return route
    
    async def get_emergency_exit(
        self,
        current_pos: Tuple[int, int],
        floor_map: FloorMap
    ) -> List[Tuple[int, int]]:
        """
        Get fastest route to exit portal.
        
        Args:
            current_pos: Current position
            floor_map: Floor map data
            
        Returns:
            Path to exit
        """
        if not floor_map.exit_portal:
            self.log.warning("No exit portal defined for floor")
            return []
        
        return await self._find_path(
            current_pos,
            floor_map.exit_portal,
            floor_map
        )
    
    async def _find_path(
        self,
        start: Tuple[int, int],
        goal: Tuple[int, int],
        floor_map: FloorMap
    ) -> List[Tuple[int, int]]:
        """
        Find path using A* algorithm.
        
        Args:
            start: Starting position
            goal: Goal position
            floor_map: Floor map data
            
        Returns:
            List of waypoints
        """
        # Check cache
        cache_key = (start, goal, id(floor_map))
        if cache_key in self.path_cache:
            return self.path_cache[cache_key]
        
        # A* pathfinding
        open_set = []
        heapq.heappush(open_set, (0, start))
        came_from: Dict[Tuple[int, int], Tuple[int, int]] = {}
        g_score: Dict[Tuple[int, int], float] = {start: 0}
        f_score: Dict[Tuple[int, int], float] = {
            start: self._manhattan_distance(start, goal)
        }
        
        while open_set:
            _, current = heapq.heappop(open_set)
            
            if current == goal:
                # Reconstruct path
                path = self._reconstruct_path(came_from, current)
                self.path_cache[cache_key] = path
                return path
            
            for neighbor in self._get_neighbors(current, floor_map):
                tentative_g = g_score[current] + 1
                
                if neighbor not in g_score or tentative_g < g_score[neighbor]:
                    came_from[neighbor] = current
                    g_score[neighbor] = tentative_g
                    f = tentative_g + self._manhattan_distance(neighbor, goal)
                    f_score[neighbor] = f
                    heapq.heappush(open_set, (f, neighbor))
        
        # No path found
        self.log.warning(
            "No path found",
            start=start,
            goal=goal
        )
        return []
    
    def _reconstruct_path(
        self,
        came_from: Dict[Tuple[int, int], Tuple[int, int]],
        current: Tuple[int, int]
    ) -> List[Tuple[int, int]]:
        """
        Reconstruct path from came_from dict.
        
        Args:
            came_from: Parent tracking dict
            current: Goal position
            
        Returns:
            Path from start to goal
        """
        path = [current]
        while current in came_from:
            current = came_from[current]
            path.append(current)
        
        path.reverse()
        return path
    
    def _get_neighbors(
        self,
        pos: Tuple[int, int],
        floor_map: FloorMap
    ) -> List[Tuple[int, int]]:
        """
        Get valid neighboring positions.
        
        Args:
            pos: Current position
            floor_map: Floor map data
            
        Returns:
            List of valid neighbors
        """
        x, y = pos
        neighbors = []
        
        # 4-directional movement
        for dx, dy in [(0, 1), (1, 0), (0, -1), (-1, 0)]:
            nx, ny = x + dx, y + dy
            
            # Check bounds
            if not (0 <= nx < floor_map.width and 0 <= ny < floor_map.height):
                continue
            
            # Check walkable
            if (nx, ny) not in floor_map.walkable_tiles:
                continue
            
            neighbors.append((nx, ny))
        
        return neighbors
    
    def _manhattan_distance(
        self,
        pos1: Tuple[int, int],
        pos2: Tuple[int, int]
    ) -> float:
        """Calculate Manhattan distance between two positions."""
        return abs(pos1[0] - pos2[0]) + abs(pos1[1] - pos2[1])
    
    def _euclidean_distance(
        self,
        pos1: Tuple[int, int],
        pos2: Tuple[int, int]
    ) -> float:
        """Calculate Euclidean distance between two positions."""
        dx = pos1[0] - pos2[0]
        dy = pos1[1] - pos2[1]
        return math.sqrt(dx * dx + dy * dy)
    
    def clear_cache(self) -> None:
        """Clear path cache."""
        self.path_cache.clear()
        self.log.debug("Path cache cleared")