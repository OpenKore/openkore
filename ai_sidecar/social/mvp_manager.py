"""
MVP hunting manager for social features.

Manages MVP tracking, spawn timers, hunting coordination,
and drop management in Ragnarok Online.

Integrates with the navigation system for cross-map travel
to MVP spawn locations.
"""

from datetime import datetime, timedelta
from typing import Optional

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.mvp_models import (
    MVPBoss,
    MVPDatabase,
    MVPHuntingStrategy,
    MVPSpawnRecord,
    MVPTracker,
)
from ai_sidecar.social.party_models import Party, PartyRole
from ai_sidecar.navigation.navigator import NavigationService, get_navigation_service
from ai_sidecar.navigation.models import NavigationPreference, NavigationRoute
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class MVPManager:
    """Manages MVP tracking and hunting coordination with navigation support."""
    
    def __init__(self, navigation_service: Optional[NavigationService] = None) -> None:
        """
        Initialize MVP manager.
        
        Args:
            navigation_service: Optional navigation service instance.
                               If not provided, will use singleton.
        """
        self.mvp_db = MVPDatabase()
        self.tracker = MVPTracker()
        self.active_hunt: MVPHuntingStrategy | None = None
        self.spawn_notifications: list[tuple[int, str, datetime]] = []
        self.current_map: str = ""
        self.rotation_index: int = 0  # Current location in rotation
        self.last_rotation_time: datetime | None = None
        self.rotation_interval_seconds: int = 30  # Time to wait at each spot
        
        # Navigation integration
        self._nav_service = navigation_service
        self._pending_navigation: Optional[NavigationRoute] = None
        self._navigation_initialized = False
        
        logger.info("MVP Manager initialized with navigation support")
    
    @property
    def navigation_service(self) -> NavigationService:
        """Get or create navigation service."""
        if self._nav_service is None:
            self._nav_service = get_navigation_service()
        if not self._navigation_initialized:
            self._nav_service.initialize()
            self._navigation_initialized = True
        return self._nav_service
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """Main MVP hunting tick."""
        actions: list[Action] = []
        
        # Update current map
        self.current_map = game_state.map.name
        
        # Update spawn timers (passive tracking)
        self._update_spawn_timers()
        
        # Check for MVP spawn windows
        upcoming = self._get_upcoming_spawns(minutes=10)
        if upcoming and not self.active_hunt:
            # Get spawn notification with navigation info
            actions.extend(self._notify_upcoming_spawns(upcoming, game_state))
        
        # If actively hunting
        if self.active_hunt:
            hunt_actions = self._execute_hunt_strategy(game_state)
            actions.extend(hunt_actions)
        
        return actions
    
    def _update_spawn_timers(self) -> None:
        """Update spawn timers and clean up expired records."""
        # Clean up expired records
        for monster_id in list(self.tracker.records.keys()):
            records = self.tracker.records[monster_id]
            # Keep only non-expired records
            valid_records = [r for r in records if not r.spawn_window_expired]
            if valid_records:
                self.tracker.records[monster_id] = valid_records
            else:
                # Remove if all expired
                del self.tracker.records[monster_id]
    
    def _get_upcoming_spawns(self, minutes: int = 30) -> list[tuple[int, MVPSpawnRecord]]:
        """Get MVPs expected to spawn soon."""
        return self.tracker.get_upcoming_spawns(within_minutes=minutes)
    
    def _execute_hunt_strategy(self, game_state: GameState) -> list[Action]:
        """Execute current MVP hunting strategy."""
        if not self.active_hunt:
            return []
        
        actions: list[Action] = []
        strategy = self.active_hunt
        mvp = strategy.target_mvp
        
        # Check if we're on the right map
        target_map = strategy.get_spawn_map()
        if self.current_map != target_map:
            # Use navigation system to get to target map
            nav_actions = self._navigate_to_map(target_map, game_state)
            if nav_actions:
                actions.extend(nav_actions)
                logger.info(
                    f"Navigating to {target_map} for MVP hunt",
                    current_map=self.current_map,
                    target_map=target_map,
                    action_count=len(nav_actions)
                )
            else:
                logger.warning(
                    f"Cannot navigate to {target_map} - no route found",
                    current_map=self.current_map
                )
            return actions
        
        # Check for spawn window
        spawn_window = self.tracker.get_spawn_window(mvp.monster_id)
        if spawn_window:
            earliest, latest = spawn_window
            now = datetime.now()
            
            if now < earliest:
                # Too early, wait
                minutes_until = int((earliest - now).total_seconds() / 60)
                logger.info(f"Waiting {minutes_until} minutes for {mvp.name} spawn")
                return actions
            
            elif now > latest:
                # Spawn window passed, MVP was likely killed by someone else
                logger.warning(f"{mvp.name} spawn window expired, aborting hunt")
                self.active_hunt = None
                return actions
        
        # We're in spawn window, camp/search
        if strategy.approach_strategy == "camp":
            # Stay at known spawn location
            if mvp.monster_id in self.tracker.known_locations:
                locations = self.tracker.known_locations[mvp.monster_id]
                if locations:
                    map_name, x, y = locations[0]
                    if map_name == self.current_map:
                        # Move to spawn point if not there
                        char_pos = game_state.character.position
                        distance = ((char_pos.x - x) ** 2 + (char_pos.y - y) ** 2) ** 0.5
                        if distance > 3:
                            actions.append(Action.move_to(x, y, priority=5))
        
        elif strategy.approach_strategy == "check_rotation":
            # Rotate through known spawn locations
            rotation_actions = self._execute_location_rotation(
                mvp.monster_id, game_state
            )
            actions.extend(rotation_actions)
        
        # Check if MVP is visible
        for actor in game_state.actors:
            if actor.mob_id == mvp.monster_id:
                # MVP found! Attack
                logger.info(f"MVP {mvp.name} found! Engaging.")
                actions.append(Action.attack(actor.id, priority=1))
                break
        
        return actions
    
    def record_mvp_death(
        self,
        monster_id: int,
        map_name: str,
        killer: str | None = None
    ) -> None:
        """Record MVP death for timer tracking."""
        mvp = self.mvp_db.get(monster_id)
        if not mvp:
            logger.warning(f"Unknown MVP ID: {monster_id}")
            return
        
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=monster_id,
            map_name=map_name,
            killed_at=now,
            killed_by=killer,
            next_spawn_earliest=now + timedelta(minutes=mvp.spawn_time_min),
            next_spawn_latest=now + timedelta(minutes=mvp.spawn_time_max),
            confirmed=True
        )
        
        self.tracker.add_record(record)
        logger.info(
            f"Recorded {mvp.name} death on {map_name}. "
            f"Next spawn: {record.next_spawn_earliest.strftime('%H:%M')} - "
            f"{record.next_spawn_latest.strftime('%H:%M')}"
        )
        
        # If we were hunting this MVP, mark hunt as complete
        if self.active_hunt and self.active_hunt.target_mvp.monster_id == monster_id:
            self.active_hunt = None
    
    def record_mvp_location(
        self,
        monster_id: int,
        map_name: str,
        x: int,
        y: int
    ) -> None:
        """Record a known MVP spawn location."""
        self.tracker.add_location(monster_id, map_name, x, y)
        logger.debug(f"Recorded MVP location: {monster_id} at {map_name} ({x}, {y})")
    
    def get_spawn_window(self, monster_id: int) -> tuple[datetime, datetime] | None:
        """Get expected spawn window for an MVP."""
        return self.tracker.get_spawn_window(monster_id)
    
    def start_hunt(
        self,
        target_id: int,
        party: Party | None = None
    ) -> list[Action]:
        """Start hunting a specific MVP."""
        mvp = self.mvp_db.get(target_id)
        if not mvp:
            logger.error(f"Cannot start hunt: Unknown MVP ID {target_id}")
            return []
        
        # Check if party meets requirements
        party_composition = self._calculate_party_needs(mvp)
        
        if party:
            # Verify party composition
            party_roles = self._count_party_roles(party)
            for role, required_count in party_composition.items():
                actual_count = party_roles.get(role, 0)
                if actual_count < required_count:
                    logger.warning(
                        f"Party lacks required {role.value}: "
                        f"need {required_count}, have {actual_count}"
                    )
        
        # Create hunting strategy
        self.active_hunt = MVPHuntingStrategy(
            target_mvp=mvp,
            party_composition=party_composition,
            approach_strategy="camp" if party else "check_rotation",
            priority_drops=[mvp.card_id] if mvp.card_id else []
        )
        
        logger.info(f"Started hunting {mvp.name}")
        return self._initiate_hunt(mvp)
    
    def stop_hunt(self) -> None:
        """Stop current MVP hunt."""
        if self.active_hunt:
            logger.info(f"Stopped hunting {self.active_hunt.target_mvp.name}")
            self.active_hunt = None
    
    def _calculate_party_needs(self, mvp: MVPBoss) -> dict[PartyRole, int]:
        """Calculate optimal party composition for MVP."""
        composition: dict[PartyRole, int] = {}
        
        # Base requirements
        if mvp.danger_rating >= 7:
            # High danger: need tank and healer
            composition[PartyRole.TANK] = 1
            composition[PartyRole.HEALER] = 1
            composition[PartyRole.DPS_MELEE] = 1
            composition[PartyRole.DPS_RANGED] = 1
        elif mvp.danger_rating >= 4:
            # Medium danger: healer recommended
            composition[PartyRole.HEALER] = 1
            composition[PartyRole.DPS_MELEE] = 1
        else:
            # Low danger: solo-able
            composition[PartyRole.DPS_MELEE] = 1
        
        return composition
    
    def _count_party_roles(self, party: Party) -> dict[PartyRole, int]:
        """Count party members by role."""
        role_counts: dict[PartyRole, int] = {}
        for member in party.members:
            role = member.assigned_role
            role_counts[role] = role_counts.get(role, 0) + 1
        return role_counts
    
    def _execute_location_rotation(
        self, monster_id: int, game_state: GameState
    ) -> list[Action]:
        """
        Rotate through known MVP spawn locations.
        
        Args:
            monster_id: MVP monster ID
            game_state: Current game state
            
        Returns:
            List of movement actions
        """
        actions: list[Action] = []
        
        # Get known locations for this MVP
        locations = self.tracker.known_locations.get(monster_id, [])
        if not locations:
            # No known locations, use spawn maps from database
            mvp = self.mvp_db.get(monster_id)
            if mvp and mvp.spawn_maps:
                # Add default center locations for each map
                for spawn_map in mvp.spawn_maps:
                    locations.append((spawn_map, 150, 150))  # Default center
            if not locations:
                logger.warning(f"No spawn locations for MVP {monster_id}")
                return actions
        
        # Check if we should rotate to next location
        now = datetime.now()
        should_rotate = False
        
        if self.last_rotation_time is None:
            should_rotate = True
        else:
            elapsed = (now - self.last_rotation_time).total_seconds()
            if elapsed >= self.rotation_interval_seconds:
                should_rotate = True
        
        if should_rotate:
            # Move to next location in rotation
            self.rotation_index = (self.rotation_index + 1) % len(locations)
            self.last_rotation_time = now
        
        # Get current target location
        target_map, target_x, target_y = locations[self.rotation_index]
        
        # Check if we're on the right map
        if self.current_map != target_map:
            # Use navigation system to travel to target map
            nav_actions = self._navigate_to_map(target_map, game_state)
            if nav_actions:
                actions.extend(nav_actions)
                logger.info(
                    f"Navigating to {target_map} for rotation point {self.rotation_index + 1}/{len(locations)}",
                    route_actions=len(nav_actions)
                )
            else:
                logger.warning(
                    f"Cannot navigate to {target_map} for rotation - no route found"
                )
        else:
            # Move to target location on current map
            char_pos = game_state.character.position
            distance = ((char_pos.x - target_x) ** 2 + (char_pos.y - target_y) ** 2) ** 0.5
            
            if distance > 5:
                actions.append(Action.move_to(target_x, target_y, priority=4))
                logger.debug(
                    f"Moving to rotation point {self.rotation_index + 1}/{len(locations)} "
                    f"at ({target_x}, {target_y})"
                )
        
        return actions
    
    def set_rotation_interval(self, seconds: int) -> None:
        """Set the time to wait at each rotation location."""
        self.rotation_interval_seconds = max(10, seconds)  # Minimum 10 seconds
        logger.debug(f"Rotation interval set to {self.rotation_interval_seconds}s")
    
    def reset_rotation(self) -> None:
        """Reset rotation to start position."""
        self.rotation_index = 0
        self.last_rotation_time = None
        logger.debug("MVP rotation reset")
    
    def _initiate_hunt(self, mvp: MVPBoss) -> list[Action]:
        """Initiate MVP hunt (navigate to spawn location)."""
        actions: list[Action] = []
        
        # Reset rotation for new hunt
        self.reset_rotation()
        
        # Get spawn location
        if mvp.spawn_maps:
            target_map = mvp.spawn_maps[0]
            logger.info(
                f"Initiating hunt for {mvp.name}",
                target_map=target_map,
                current_map=self.current_map
            )
            
            # If we're not on the target map, use navigation system
            if self.current_map and self.current_map != target_map:
                # Calculate and cache route
                route = self.navigation_service.get_route_to_map(
                    self.current_map,
                    target_map,
                    preference=NavigationPreference.FASTEST
                )
                
                if route:
                    self._pending_navigation = route
                    nav_actions = self.navigation_service.generate_navigation_actions(
                        route, priority=3
                    )
                    actions.extend(nav_actions)
                    logger.info(
                        f"Navigation route calculated for {mvp.name} hunt",
                        steps=route.step_count,
                        estimated_time=f"{route.estimated_time:.1f}s",
                        total_cost=route.total_cost
                    )
                else:
                    logger.warning(
                        f"Cannot find route to {target_map} for {mvp.name} hunt",
                        current_map=self.current_map
                    )
        
        return actions
    
    def load_mvp_database(self, data: dict) -> None:
        """Load MVP database from dictionary."""
        self.mvp_db.load_from_dict(data)
        logger.info(f"Loaded {len(self.mvp_db.get_all())} MVPs into database")
    
    # Navigation integration methods
    
    def _notify_upcoming_spawns(
        self,
        upcoming: list[tuple[int, MVPSpawnRecord]],
        game_state: GameState
    ) -> list[Action]:
        """
        Generate notifications and prepare for upcoming MVP spawns.
        
        Args:
            upcoming: List of (monster_id, spawn_record) tuples
            game_state: Current game state
            
        Returns:
            List of preparation actions
        """
        actions: list[Action] = []
        
        if not upcoming:
            return actions
        
        # Get first upcoming spawn
        monster_id, record = upcoming[0]
        mvp = self.mvp_db.get(monster_id)
        
        if not mvp:
            logger.warning(f"Unknown MVP ID in upcoming spawns: {monster_id}")
            return actions
        
        # Calculate time until spawn
        now = datetime.now()
        time_until = record.next_spawn_earliest - now
        minutes_until = max(0, int(time_until.total_seconds() / 60))
        
        # Log spawn notification with travel info
        target_map = record.map_name
        travel_time = self.navigation_service.estimate_travel_time(
            self.current_map, target_map
        )
        
        if travel_time >= 0:
            travel_minutes = travel_time / 60
            should_leave_in = max(0, minutes_until - travel_minutes - 1)
            
            logger.info(
                f"Upcoming MVP spawn: {mvp.name}",
                map=target_map,
                spawn_in_minutes=minutes_until,
                travel_time_seconds=f"{travel_time:.1f}",
                leave_in_minutes=f"{should_leave_in:.1f}"
            )
            
            # If spawn is soon and we need to travel
            if should_leave_in <= 2 and self.current_map != target_map:
                logger.info(
                    f"Should leave now for {mvp.name} spawn",
                    reason="Travel time would cause miss"
                )
                # Could auto-start hunt here if configured
        else:
            logger.info(
                f"Upcoming MVP spawn: {mvp.name}",
                map=target_map,
                spawn_in_minutes=minutes_until,
                note="Target map unreachable from current location"
            )
        
        # Store notification
        if (monster_id, target_map, record.next_spawn_earliest) not in self.spawn_notifications:
            self.spawn_notifications.append((monster_id, target_map, record.next_spawn_earliest))
            # Keep only recent notifications
            self.spawn_notifications = self.spawn_notifications[-10:]
        
        return actions
    
    def _navigate_to_map(
        self,
        target_map: str,
        game_state: GameState
    ) -> list[Action]:
        """
        Generate navigation actions to travel to target map.
        
        Args:
            target_map: Destination map name
            game_state: Current game state
            
        Returns:
            List of navigation actions
        """
        if not target_map or target_map == self.current_map:
            return []
        
        # Get current position
        current_x = game_state.character.position.x if game_state.character else 0
        current_y = game_state.character.position.y if game_state.character else 0
        
        # Calculate route
        route = self.navigation_service.get_route_to_map(
            self.current_map,
            target_map,
            current_x,
            current_y,
            preference=NavigationPreference.FASTEST
        )
        
        if not route:
            return []
        
        # Store pending navigation for tracking
        self._pending_navigation = route
        
        # Generate actions
        actions = self.navigation_service.generate_navigation_actions(
            route,
            game_state=game_state,
            priority=4
        )
        
        logger.debug(
            f"Generated navigation to {target_map}",
            steps=route.step_count,
            actions=len(actions),
            estimated_time=f"{route.estimated_time:.1f}s"
        )
        
        return actions
    
    def get_travel_time_to_mvp(self, monster_id: int) -> float:
        """
        Estimate travel time to an MVP's spawn location.
        
        Args:
            monster_id: MVP monster ID
            
        Returns:
            Estimated time in seconds, or -1 if unreachable
        """
        mvp = self.mvp_db.get(monster_id)
        if not mvp or not mvp.spawn_maps:
            return -1.0
        
        target_map = mvp.spawn_maps[0]
        return self.navigation_service.estimate_travel_time(
            self.current_map,
            target_map,
            NavigationPreference.FASTEST
        )
    
    def is_mvp_reachable(self, monster_id: int) -> bool:
        """
        Check if an MVP's spawn location is reachable.
        
        Args:
            monster_id: MVP monster ID
            
        Returns:
            True if MVP location is accessible
        """
        mvp = self.mvp_db.get(monster_id)
        if not mvp or not mvp.spawn_maps:
            return False
        
        target_map = mvp.spawn_maps[0]
        return self.navigation_service.is_map_accessible(
            self.current_map,
            target_map
        )
    
    def get_nearest_huntable_mvp(self) -> Optional[MVPBoss]:
        """
        Find the nearest MVP with an active or upcoming spawn window.
        
        Returns:
            MVPBoss object or None if none found
        """
        upcoming = self._get_upcoming_spawns(minutes=60)
        if not upcoming:
            return None
        
        best_mvp = None
        best_time = float('inf')
        
        for monster_id, record in upcoming:
            mvp = self.mvp_db.get(monster_id)
            if not mvp:
                continue
            
            travel_time = self.get_travel_time_to_mvp(monster_id)
            if travel_time >= 0 and travel_time < best_time:
                best_time = travel_time
                best_mvp = mvp
        
        return best_mvp