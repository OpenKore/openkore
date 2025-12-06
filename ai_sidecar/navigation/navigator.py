"""
Navigation service for cross-map travel.

Provides high-level API for:
- Route calculation and action generation
- Navigation progress tracking
- Integration with game state and actions
"""

import time
from typing import Dict, List, Optional, Tuple

from ai_sidecar.utils.logging import get_logger
from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState, Position
from ai_sidecar.navigation.models import (
    Portal,
    PortalType,
    NavigationPreference,
    NavigationRoute,
    NavigationStep,
    NavigationState,
    NavigationProgress,
    NavigationItems,
)
from ai_sidecar.navigation.portal_database import PortalDatabase
from ai_sidecar.navigation.pathfinder import NavigationPathfinder

logger = get_logger(__name__)


class NavigationService:
    """
    High-level navigation service for cross-map travel.
    
    Provides:
    - Route calculation
    - Action generation for portals, NPCs, items
    - Navigation progress tracking
    - Integration with game state
    """
    
    # Singleton instance
    _instance: Optional["NavigationService"] = None
    
    def __init__(self, tables_dir: Optional[str] = None):
        """
        Initialize navigation service.
        
        Args:
            tables_dir: Path to OpenKore tables directory
        """
        from pathlib import Path
        
        self._db = PortalDatabase(
            tables_dir=Path(tables_dir) if tables_dir else None
        )
        self._pathfinder: Optional[NavigationPathfinder] = None
        self._current_navigation: Optional[NavigationProgress] = None
        self._initialized = False
        
        logger.info("Navigation service created")
    
    @classmethod
    def get_instance(cls, tables_dir: Optional[str] = None) -> "NavigationService":
        """Get singleton instance of navigation service."""
        if cls._instance is None:
            cls._instance = cls(tables_dir)
        return cls._instance
    
    def initialize(self) -> bool:
        """
        Initialize the navigation system.
        
        Loads portal database and prepares pathfinder.
        
        Returns:
            True if initialized successfully
        """
        if self._initialized:
            return True
        
        logger.info("Initializing navigation service")
        
        if not self._db.load():
            logger.error("Failed to load portal database")
            return False
        
        self._pathfinder = NavigationPathfinder(self._db)
        self._initialized = True
        
        stats = self._db.get_statistics()
        logger.info(
            "Navigation service initialized",
            portals=stats['portals'],
            maps=stats['maps'],
            connections=stats['connections']
        )
        
        return True
    
    def get_route_to_map(
        self,
        current_map: str,
        target_map: str,
        current_x: int = 0,
        current_y: int = 0,
        preference: NavigationPreference = NavigationPreference.BALANCED
    ) -> Optional[NavigationRoute]:
        """
        Calculate route from current position to target map.
        
        Args:
            current_map: Current map name
            target_map: Target map name
            current_x: Current X position
            current_y: Current Y position
            preference: Navigation optimization preference
            
        Returns:
            NavigationRoute or None if no route found
        """
        if not self._ensure_initialized():
            return None
        
        logger.info(
            "Calculating route",
            from_map=current_map,
            to_map=target_map,
            preference=preference.name
        )
        
        route = self._pathfinder.find_route(
            current_map, target_map, preference, current_x, current_y
        )
        
        if route:
            logger.debug(
                "Route calculated",
                steps=route.step_count,
                cost=route.total_cost,
                time=f"{route.estimated_time:.1f}s"
            )
        else:
            logger.warning(
                "No route found",
                from_map=current_map,
                to_map=target_map
            )
        
        return route
    
    def generate_navigation_actions(
        self,
        route: NavigationRoute,
        game_state: Optional[GameState] = None,
        priority: int = 50
    ) -> List[Action]:
        """
        Generate game actions for a navigation route.
        
        Args:
            route: Navigation route to follow
            game_state: Current game state for context
            priority: Base priority for generated actions
            
        Returns:
            List of Action objects to execute
        """
        if route.is_empty():
            logger.debug("Empty route, no actions needed")
            return []
        
        actions = []
        
        for i, step in enumerate(route.steps):
            step_actions = self._generate_step_actions(
                step, 
                priority=priority - i,  # Higher priority for earlier steps
                game_state=game_state
            )
            actions.extend(step_actions)
        
        logger.info(
            "Generated navigation actions",
            route_steps=route.step_count,
            total_actions=len(actions)
        )
        
        return actions
    
    def _generate_step_actions(
        self,
        step: NavigationStep,
        priority: int,
        game_state: Optional[GameState] = None
    ) -> List[Action]:
        """
        Generate actions for a single navigation step.
        
        Args:
            step: Navigation step
            priority: Action priority
            game_state: Current game state
            
        Returns:
            List of actions for this step
        """
        actions = []
        
        # First, move to the portal/NPC location
        move_action = Action(
            action_type=ActionType.MOVE,
            priority=priority,
            x=step.x,
            y=step.y,
            extra={
                'navigation': True,
                'step_description': f"Walk to {step.description}",
                'target_map': step.to_map,
            }
        )
        actions.append(move_action)
        
        # Then, take appropriate action based on step type
        if step.action_type == "TAKE_PORTAL":
            # Simple portal - just walk through
            portal_action = Action(
                action_type=ActionType.TAKE_PORTAL,
                priority=priority - 1,
                x=step.x,
                y=step.y,
                extra={
                    'navigation': True,
                    'to_map': step.to_map,
                    'dest_x': step.extra_data.get('dest_x', 0),
                    'dest_y': step.extra_data.get('dest_y', 0),
                }
            )
            actions.append(portal_action)
            
        elif step.action_type == "USE_KAFRA":
            # Kafra teleport - talk to NPC
            kafra_action = Action(
                action_type=ActionType.USE_KAFRA,
                priority=priority - 1,
                x=step.x,
                y=step.y,
                extra={
                    'navigation': True,
                    'conversation': step.extra_data.get('conversation', 'c r0'),
                    'to_map': step.to_map,
                    'cost': step.cost,
                }
            )
            actions.append(kafra_action)
            
        elif step.action_type == "TALK_NPC":
            # Warp NPC - talk and select option
            npc_action = Action(
                action_type=ActionType.TALK_NPC,
                priority=priority - 1,
                x=step.x,
                y=step.y,
                extra={
                    'navigation': True,
                    'conversation': step.extra_data.get('conversation', 'c r0'),
                    'to_map': step.to_map,
                }
            )
            actions.append(npc_action)
            
        elif step.action_type == "USE_ITEM":
            # Use teleport item
            item_id = step.extra_data.get('item_id', NavigationItems.BUTTERFLY_WING)
            item_action = Action(
                action_type=ActionType.USE_ITEM,
                priority=priority - 1,
                item_id=item_id,
                extra={
                    'navigation': True,
                    'item_name': 'Butterfly Wing' if item_id == NavigationItems.BUTTERFLY_WING else 'Fly Wing',
                }
            )
            actions.append(item_action)
        
        return actions
    
    def start_navigation(
        self,
        target_map: str,
        game_state: GameState,
        preference: NavigationPreference = NavigationPreference.BALANCED
    ) -> Optional[List[Action]]:
        """
        Start navigation to a target map.
        
        Args:
            target_map: Destination map name
            game_state: Current game state
            preference: Navigation preference
            
        Returns:
            List of actions to start navigation, or None if failed
        """
        if not self._ensure_initialized():
            return None
        
        current_map = game_state.map.name if game_state.map else ""
        current_pos = game_state.character.position if game_state.character else Position(x=0, y=0)
        
        logger.info(
            "Starting navigation",
            from_map=current_map,
            to_map=target_map,
            current_pos=f"({current_pos.x}, {current_pos.y})"
        )
        
        # Calculate route
        route = self.get_route_to_map(
            current_map, target_map,
            current_pos.x, current_pos.y,
            preference
        )
        
        if not route:
            logger.warning(
                "Cannot start navigation - no route found",
                from_map=current_map,
                to_map=target_map
            )
            return None
        
        # Create progress tracker
        self._current_navigation = NavigationProgress(
            route=route,
            current_step_index=0,
            state=NavigationState.WALKING_TO_PORTAL,
            current_map=current_map,
            current_x=current_pos.x,
            current_y=current_pos.y,
            started_at=time.time(),
            eta_seconds=route.estimated_time
        )
        
        # Generate actions
        actions = self.generate_navigation_actions(route, game_state)
        
        return actions
    
    def update_navigation_progress(
        self,
        game_state: GameState
    ) -> Tuple[NavigationState, Optional[List[Action]]]:
        """
        Update navigation progress based on current game state.
        
        Args:
            game_state: Current game state
            
        Returns:
            Tuple of (current state, additional actions if needed)
        """
        if not self._current_navigation:
            return NavigationState.IDLE, None
        
        progress = self._current_navigation
        current_map = game_state.map.name if game_state.map else ""
        current_pos = game_state.character.position if game_state.character else Position(x=0, y=0)
        
        # Update position
        progress.current_map = current_map
        progress.current_x = current_pos.x
        progress.current_y = current_pos.y
        
        # Check if we've reached the destination
        if current_map == progress.route.dest_map:
            progress.state = NavigationState.ARRIVED
            logger.info(
                "Navigation complete",
                destination=progress.route.dest_map,
                elapsed=f"{time.time() - progress.started_at:.1f}s"
            )
            self._current_navigation = None
            return NavigationState.ARRIVED, None
        
        # Check if we've moved to a new map in the route
        current_step = progress.current_step
        if current_step and current_map == current_step.to_map:
            if progress.advance():
                logger.debug(
                    "Advanced to next navigation step",
                    step=progress.current_step_index,
                    map=current_map
                )
        
        # Generate actions for current step if needed
        if progress.current_step:
            actions = self._generate_step_actions(
                progress.current_step,
                priority=50,
                game_state=game_state
            )
            return progress.state, actions
        
        return progress.state, None
    
    def cancel_navigation(self) -> None:
        """Cancel current navigation."""
        if self._current_navigation:
            logger.info(
                "Navigation cancelled",
                destination=self._current_navigation.route.dest_map
            )
            self._current_navigation = None
    
    def get_navigation_progress(self) -> Optional[NavigationProgress]:
        """Get current navigation progress."""
        return self._current_navigation
    
    def is_navigating(self) -> bool:
        """Check if currently navigating."""
        return self._current_navigation is not None
    
    # Utility methods
    
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
        if not self._ensure_initialized():
            return -1.0
        
        return self._pathfinder.estimate_travel_time(from_map, to_map, preference)
    
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
        if not self._ensure_initialized():
            return -1
        
        return self._pathfinder.estimate_travel_cost(from_map, to_map, preference)
    
    def is_map_accessible(self, from_map: str, to_map: str) -> bool:
        """
        Check if a map is accessible from another.
        
        Args:
            from_map: Source map
            to_map: Destination map
            
        Returns:
            True if route exists
        """
        if not self._ensure_initialized():
            return False
        
        return self._pathfinder.is_map_accessible(from_map, to_map)
    
    def get_nearest_kafra(self, from_map: str) -> Optional[str]:
        """
        Find the nearest city with Kafra service.
        
        Args:
            from_map: Current map
            
        Returns:
            City map name or None
        """
        if not self._ensure_initialized():
            return None
        
        return self._pathfinder.find_nearest_city(from_map)
    
    def get_reachable_maps(self, from_map: str, max_hops: int = 10) -> List[str]:
        """
        Get all maps reachable within a number of portal hops.
        
        Args:
            from_map: Starting map
            max_hops: Maximum number of portals
            
        Returns:
            List of reachable map names
        """
        if not self._ensure_initialized():
            return []
        
        return self._pathfinder.get_reachable_maps(from_map, max_hops)
    
    def optimize_multi_stop_route(
        self,
        start_map: str,
        destinations: List[str],
        preference: NavigationPreference = NavigationPreference.BALANCED
    ) -> List[Tuple[str, NavigationRoute]]:
        """
        Optimize route visiting multiple destinations (traveling salesman).
        
        Uses greedy nearest-neighbor heuristic.
        
        Args:
            start_map: Starting map
            destinations: List of maps to visit
            preference: Navigation preference
            
        Returns:
            List of (destination, route) tuples in optimal order
        """
        if not self._ensure_initialized():
            return []
        
        if not destinations:
            return []
        
        result = []
        current = start_map
        remaining = list(destinations)
        
        while remaining:
            # Find nearest unvisited destination
            best_dest = None
            best_route = None
            best_time = float('inf')
            
            for dest in remaining:
                route = self.get_route_to_map(current, dest, preference=preference)
                if route and route.estimated_time < best_time:
                    best_dest = dest
                    best_route = route
                    best_time = route.estimated_time
            
            if best_dest:
                result.append((best_dest, best_route))
                remaining.remove(best_dest)
                current = best_dest
            else:
                # Can't reach remaining destinations
                logger.warning(
                    "Cannot reach all destinations",
                    unreachable=remaining
                )
                break
        
        logger.info(
            "Multi-stop route optimized",
            stops=len(result),
            unreachable=len(remaining)
        )
        
        return result
    
    def get_map_info(self, map_name: str):
        """Get information about a map."""
        if not self._ensure_initialized():
            return None
        return self._db.get_map_info(map_name)
    
    def get_statistics(self) -> Dict[str, int]:
        """Get navigation system statistics."""
        if not self._ensure_initialized():
            return {}
        return self._db.get_statistics()
    
    def _ensure_initialized(self) -> bool:
        """Ensure service is initialized."""
        if not self._initialized:
            return self.initialize()
        return True


# Convenience function for getting navigation service
def get_navigation_service(tables_dir: Optional[str] = None) -> NavigationService:
    """Get the navigation service singleton."""
    return NavigationService.get_instance(tables_dir)