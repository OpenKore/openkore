"""
Navigation pathfinder using Dijkstra's algorithm.

Calculates optimal routes between maps considering:
- Portal costs (zeny)
- Travel time estimates
- Safety preferences
- Caching for performance
"""

import heapq
from collections import defaultdict
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Callable, Dict, List, Optional, Set, Tuple

from ai_sidecar.utils.logging import get_logger
from ai_sidecar.navigation.models import (
    Portal,
    PortalType,
    NavigationPreference,
    NavigationRoute,
    NavigationStep,
    MapCategory,
)
from ai_sidecar.navigation.portal_database import PortalDatabase, MapConnection

logger = get_logger(__name__)


@dataclass
class PathNode:
    """Node in the pathfinding priority queue."""
    map_name: str
    cost: float
    prev_map: Optional[str] = None
    prev_portal: Optional[Portal] = None
    
    def __lt__(self, other: "PathNode") -> bool:
        """Compare nodes by cost for heap ordering."""
        return self.cost < other.cost


@dataclass
class CostWeights:
    """Weights for multi-objective cost calculation."""
    zeny: float = 1.0       # Weight for zeny cost
    time: float = 1.0       # Weight for travel time
    danger: float = 0.0     # Weight for danger level
    portals: float = 0.1    # Weight for number of portals
    
    @classmethod
    def for_preference(cls, pref: NavigationPreference) -> "CostWeights":
        """Create weights based on navigation preference."""
        if pref == NavigationPreference.FASTEST:
            return cls(zeny=0.1, time=1.0, danger=0.0, portals=0.5)
        elif pref == NavigationPreference.CHEAPEST:
            return cls(zeny=1.0, time=0.1, danger=0.0, portals=0.0)
        elif pref == NavigationPreference.SAFEST:
            return cls(zeny=0.1, time=0.3, danger=1.0, portals=0.2)
        else:  # BALANCED
            return cls(zeny=0.5, time=0.5, danger=0.2, portals=0.1)


class NavigationPathfinder:
    """
    Pathfinder for cross-map navigation.
    
    Uses Dijkstra's algorithm with configurable cost functions
    to find optimal routes between maps.
    """
    
    # Default time estimates (seconds)
    WALK_SPEED = 30.0  # Cells per second (approximate)
    MAP_SIZE_AVG = 300.0  # Average map dimension
    PORTAL_WALK_TIME = 5.0  # Time to walk to nearby portal
    NPC_TALK_TIME = 3.0  # Time for NPC dialogue
    MAP_LOAD_TIME = 2.0  # Time to load new map
    
    def __init__(self, portal_db: PortalDatabase):
        """
        Initialize pathfinder.
        
        Args:
            portal_db: Portal database instance
        """
        self._db = portal_db
        self._route_cache: Dict[str, NavigationRoute] = {}
        self._max_cache_size = 1000
        
        logger.info("Navigation pathfinder initialized")
    
    def find_route(
        self,
        from_map: str,
        to_map: str,
        preference: NavigationPreference = NavigationPreference.BALANCED,
        from_x: int = 0,
        from_y: int = 0,
    ) -> Optional[NavigationRoute]:
        """
        Find optimal route between two maps.
        
        Args:
            from_map: Source map name
            to_map: Destination map name
            preference: Optimization preference
            from_x: Starting X position
            from_y: Starting Y position
            
        Returns:
            NavigationRoute or None if no route found
        """
        # Same map - no navigation needed
        if from_map == to_map:
            logger.debug("Same map, no navigation needed", map=from_map)
            return NavigationRoute(
                source_map=from_map,
                dest_map=to_map,
                steps=[],
                total_cost=0,
                estimated_time=0.0,
                maps_traversed=[from_map],
                is_valid=True
            )
        
        # Check cache
        cache_key = self._get_cache_key(from_map, to_map, preference)
        if cache_key in self._route_cache:
            cached = self._route_cache[cache_key]
            logger.debug(
                "Using cached route",
                from_map=from_map,
                to_map=to_map,
                steps=cached.step_count
            )
            return cached
        
        logger.info(
            "Finding route",
            from_map=from_map,
            to_map=to_map,
            preference=preference.name
        )
        
        # Run Dijkstra's algorithm
        weights = CostWeights.for_preference(preference)
        path = self._dijkstra(from_map, to_map, weights)
        
        if not path:
            logger.warning(
                "No route found",
                from_map=from_map,
                to_map=to_map
            )
            return None
        
        # Build route from path
        route = self._build_route(path, from_map, to_map, preference, from_x, from_y)
        
        # Cache the route
        self._cache_route(cache_key, route)
        
        logger.info(
            "Route found",
            from_map=from_map,
            to_map=to_map,
            steps=route.step_count,
            cost=route.total_cost,
            time=f"{route.estimated_time:.1f}s"
        )
        
        return route
    
    def _dijkstra(
        self,
        start: str,
        goal: str,
        weights: CostWeights
    ) -> Optional[List[Tuple[str, Optional[Portal]]]]:
        """
        Run Dijkstra's algorithm to find shortest path.
        
        Args:
            start: Starting map
            goal: Target map
            weights: Cost calculation weights
            
        Returns:
            List of (map, portal) tuples representing the path
        """
        # Priority queue: (cost, map_name)
        pq: List[PathNode] = [PathNode(map_name=start, cost=0.0)]
        
        # Best known cost to reach each map
        best_cost: Dict[str, float] = {start: 0.0}
        
        # Track the path: map -> (prev_map, portal_used)
        came_from: Dict[str, Tuple[Optional[str], Optional[Portal]]] = {
            start: (None, None)
        }
        
        # Track visited nodes
        visited: Set[str] = set()
        
        while pq:
            current = heapq.heappop(pq)
            
            if current.map_name in visited:
                continue
            
            visited.add(current.map_name)
            
            # Found goal
            if current.map_name == goal:
                return self._reconstruct_path(came_from, goal)
            
            # Explore neighbors
            for neighbor in self._db.get_neighbors(current.map_name):
                if neighbor in visited:
                    continue
                
                # Get connection and calculate cost
                connection = self._db.get_connection(current.map_name, neighbor)
                if not connection:
                    continue
                
                # Find best portal for this connection
                portal, edge_cost = self._get_best_portal(connection, weights)
                
                total_cost = current.cost + edge_cost
                
                # Update if better path found
                if neighbor not in best_cost or total_cost < best_cost[neighbor]:
                    best_cost[neighbor] = total_cost
                    came_from[neighbor] = (current.map_name, portal)
                    heapq.heappush(pq, PathNode(
                        map_name=neighbor,
                        cost=total_cost,
                        prev_map=current.map_name,
                        prev_portal=portal
                    ))
        
        return None  # No path found
    
    def _get_best_portal(
        self,
        connection: MapConnection,
        weights: CostWeights
    ) -> Tuple[Optional[Portal], float]:
        """
        Get the best portal for a connection based on weights.
        
        Args:
            connection: MapConnection with available portals
            weights: Cost calculation weights
            
        Returns:
            Tuple of (best portal, calculated cost)
        """
        if not connection.portals:
            return None, float('inf')
        
        best_portal = None
        best_cost = float('inf')
        
        for portal in connection.portals:
            cost = self._calculate_edge_cost(portal, weights)
            if cost < best_cost:
                best_cost = cost
                best_portal = portal
        
        return best_portal, best_cost
    
    def _calculate_edge_cost(self, portal: Portal, weights: CostWeights) -> float:
        """
        Calculate weighted cost for using a portal.
        
        Args:
            portal: Portal to evaluate
            weights: Cost calculation weights
            
        Returns:
            Weighted cost value
        """
        # Base costs
        zeny_cost = portal.cost
        time_cost = self._estimate_portal_time(portal)
        
        # Get danger level for destination
        dest_info = self._db.get_map_info(portal.to_map)
        danger_cost = dest_info.danger_level if dest_info else 5
        
        # Portal transition cost (1 per portal)
        portal_cost = 1.0
        
        # Weighted sum
        total = (
            weights.zeny * (zeny_cost / 1000.0) +  # Normalize zeny
            weights.time * (time_cost / 10.0) +    # Normalize time
            weights.danger * danger_cost +
            weights.portals * portal_cost
        )
        
        return total
    
    def _estimate_portal_time(self, portal: Portal) -> float:
        """
        Estimate time to use a portal.
        
        Args:
            portal: Portal to estimate
            
        Returns:
            Estimated time in seconds
        """
        time = self.MAP_LOAD_TIME
        
        if portal.portal_type == PortalType.PORTAL:
            time += self.PORTAL_WALK_TIME
        elif portal.portal_type in (PortalType.KAFRA, PortalType.WARP_NPC):
            time += self.PORTAL_WALK_TIME + self.NPC_TALK_TIME
        elif portal.portal_type == PortalType.DUNGEON_WARP:
            time += self.PORTAL_WALK_TIME * 1.5
        
        return time
    
    def _reconstruct_path(
        self,
        came_from: Dict[str, Tuple[Optional[str], Optional[Portal]]],
        goal: str
    ) -> List[Tuple[str, Optional[Portal]]]:
        """
        Reconstruct path from came_from mapping.
        
        Args:
            came_from: Mapping of map -> (prev_map, portal)
            goal: Target map
            
        Returns:
            List of (map, portal) tuples in order
        """
        path = []
        current = goal
        
        while current is not None:
            prev_map, portal = came_from.get(current, (None, None))
            path.append((current, portal))
            current = prev_map
        
        path.reverse()
        return path
    
    def _build_route(
        self,
        path: List[Tuple[str, Optional[Portal]]],
        from_map: str,
        to_map: str,
        preference: NavigationPreference,
        from_x: int,
        from_y: int
    ) -> NavigationRoute:
        """
        Build NavigationRoute from path.
        
        Args:
            path: List of (map, portal) tuples
            from_map: Source map
            to_map: Destination map
            preference: Navigation preference
            from_x: Starting X position
            from_y: Starting Y position
            
        Returns:
            Complete NavigationRoute
        """
        steps = []
        total_cost = 0
        total_time = 0.0
        requirements = []
        maps = []
        
        prev_x, prev_y = from_x, from_y
        
        for i, (map_name, portal) in enumerate(path):
            maps.append(map_name)
            
            if portal is None:
                continue  # First node has no incoming portal
            
            # Create step for moving to portal
            step = self._create_navigation_step(portal, prev_x, prev_y)
            steps.append(step)
            
            total_cost += portal.cost
            total_time += self._estimate_portal_time(portal)
            requirements.extend(portal.requirements)
            
            # Update position for next iteration
            prev_x, prev_y = portal.to_x, portal.to_y
        
        return NavigationRoute(
            source_map=from_map,
            dest_map=to_map,
            steps=steps,
            total_cost=total_cost,
            estimated_time=total_time,
            requirements=list(set(requirements)),
            preference=preference,
            maps_traversed=maps,
            is_valid=True
        )
    
    def _create_navigation_step(
        self,
        portal: Portal,
        current_x: int,
        current_y: int
    ) -> NavigationStep:
        """
        Create a navigation step for using a portal.
        
        Args:
            portal: Portal to use
            current_x: Current X position
            current_y: Current Y position
            
        Returns:
            NavigationStep
        """
        # Determine action type based on portal type
        action_type = self._get_action_type(portal.portal_type)
        
        # Build description
        description = self._build_step_description(portal, action_type)
        
        # Calculate walk time to portal
        walk_time = self._estimate_walk_time(
            current_x, current_y,
            portal.from_x, portal.from_y
        )
        
        return NavigationStep(
            action_type=action_type,
            from_map=portal.from_map,
            to_map=portal.to_map,
            x=portal.from_x,
            y=portal.from_y,
            portal=portal,
            cost=portal.cost,
            estimated_time=walk_time + self._estimate_portal_time(portal),
            description=description,
            extra_data={
                'dest_x': portal.to_x,
                'dest_y': portal.to_y,
                'conversation': portal.conversation,
                'portal_type': portal.portal_type.name,
            }
        )
    
    def _get_action_type(self, portal_type: PortalType) -> str:
        """Map portal type to action type string."""
        mapping = {
            PortalType.PORTAL: "TAKE_PORTAL",
            PortalType.KAFRA: "USE_KAFRA",
            PortalType.WARP_NPC: "TALK_NPC",
            PortalType.BUTTERFLY_WING: "USE_ITEM",
            PortalType.FLY_WING: "USE_ITEM",
            PortalType.TELEPORT_SKILL: "USE_SKILL",
            PortalType.DUNGEON_WARP: "TAKE_PORTAL",
            PortalType.GUILD_HALL: "TAKE_PORTAL",
            PortalType.INSTANCE: "TAKE_PORTAL",
            PortalType.COMMAND: "COMMAND",
        }
        return mapping.get(portal_type, "TAKE_PORTAL")
    
    def _build_step_description(self, portal: Portal, action_type: str) -> str:
        """Build human-readable step description."""
        dest_info = self._db.get_map_info(portal.to_map)
        dest_name = dest_info.display_name if dest_info else portal.to_map
        
        if action_type == "USE_KAFRA":
            return f"Use Kafra to teleport to {dest_name} ({portal.cost}z)"
        elif action_type == "TALK_NPC":
            return f"Talk to warp NPC to go to {dest_name}"
        elif action_type == "USE_ITEM":
            return f"Use item to travel to {dest_name}"
        else:
            return f"Take portal to {dest_name}"
    
    def _estimate_walk_time(
        self,
        from_x: int,
        from_y: int,
        to_x: int,
        to_y: int
    ) -> float:
        """
        Estimate time to walk between two points.
        
        Args:
            from_x, from_y: Starting position
            to_x, to_y: Target position
            
        Returns:
            Estimated time in seconds
        """
        if from_x == 0 and from_y == 0:
            # Unknown starting position, use average
            return self.MAP_SIZE_AVG / self.WALK_SPEED / 2
        
        # Manhattan distance
        distance = abs(to_x - from_x) + abs(to_y - from_y)
        return distance / self.WALK_SPEED
    
    def _get_cache_key(
        self,
        from_map: str,
        to_map: str,
        preference: NavigationPreference
    ) -> str:
        """Generate cache key for route."""
        return f"{from_map}:{to_map}:{preference.name}"
    
    def _cache_route(self, key: str, route: NavigationRoute) -> None:
        """Cache a route, evicting old entries if needed."""
        if len(self._route_cache) >= self._max_cache_size:
            # Simple eviction: remove oldest entries
            keys_to_remove = list(self._route_cache.keys())[:100]
            for k in keys_to_remove:
                del self._route_cache[k]
        
        self._route_cache[key] = route
    
    def clear_cache(self) -> None:
        """Clear the route cache."""
        self._route_cache.clear()
        logger.debug("Route cache cleared")
    
    # Public utility methods
    
    def is_map_accessible(self, from_map: str, to_map: str) -> bool:
        """
        Check if a map is accessible from another.
        
        Args:
            from_map: Source map
            to_map: Destination map
            
        Returns:
            True if route exists
        """
        route = self.find_route(from_map, to_map)
        return route is not None
    
    def estimate_travel_time(
        self,
        from_map: str,
        to_map: str,
        preference: NavigationPreference = NavigationPreference.FASTEST
    ) -> float:
        """
        Estimate travel time between maps.
        
        Args:
            from_map: Source map
            to_map: Destination map
            preference: Navigation preference
            
        Returns:
            Estimated time in seconds, or -1 if unreachable
        """
        route = self.find_route(from_map, to_map, preference)
        return route.estimated_time if route else -1.0
    
    def estimate_travel_cost(
        self,
        from_map: str,
        to_map: str,
        preference: NavigationPreference = NavigationPreference.CHEAPEST
    ) -> int:
        """
        Estimate zeny cost to travel between maps.
        
        Args:
            from_map: Source map
            to_map: Destination map
            preference: Navigation preference
            
        Returns:
            Total zeny cost, or -1 if unreachable
        """
        route = self.find_route(from_map, to_map, preference)
        return route.total_cost if route else -1
    
    def get_reachable_maps(self, from_map: str, max_hops: int = 10) -> List[str]:
        """
        Get all maps reachable within a number of portal hops.
        
        Args:
            from_map: Starting map
            max_hops: Maximum number of portals
            
        Returns:
            List of reachable map names
        """
        reachable = {from_map}
        frontier = {from_map}
        
        for _ in range(max_hops):
            next_frontier = set()
            for map_name in frontier:
                for neighbor in self._db.get_neighbors(map_name):
                    if neighbor not in reachable:
                        reachable.add(neighbor)
                        next_frontier.add(neighbor)
            frontier = next_frontier
            if not frontier:
                break
        
        return list(reachable)
    
    def find_nearest_city(self, from_map: str) -> Optional[str]:
        """
        Find the nearest city with Kafra service.
        
        Args:
            from_map: Current map
            
        Returns:
            City map name or None
        """
        cities = ['prontera', 'geffen', 'payon', 'morocc', 'alberta',
                  'izlude', 'aldebaran', 'yuno', 'comodo']
        
        best_route = None
        best_city = None
        
        for city in cities:
            route = self.find_route(from_map, city, NavigationPreference.FASTEST)
            if route:
                if best_route is None or route.estimated_time < best_route.estimated_time:
                    best_route = route
                    best_city = city
        
        return best_city