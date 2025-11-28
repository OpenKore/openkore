"""
MVP hunting manager for social features.

Manages MVP tracking, spawn timers, hunting coordination,
and drop management in Ragnarok Online.
"""

from datetime import datetime, timedelta

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
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class MVPManager:
    """Manages MVP tracking and hunting coordination."""
    
    def __init__(self) -> None:
        self.mvp_db = MVPDatabase()
        self.tracker = MVPTracker()
        self.active_hunt: MVPHuntingStrategy | None = None
        self.spawn_notifications: list[tuple[int, str, datetime]] = []
        self.current_map: str = ""
    
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
            # Notify about upcoming spawns (placeholder)
            logger.info(f"Upcoming MVP spawn: {upcoming[0][0]}")
        
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
            # Move to target map (placeholder - would need portal/warp logic)
            logger.info(f"Need to move to {target_map} for MVP hunt")
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
            # Rotate through known locations
            # Placeholder implementation
            pass
        
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
    
    def _initiate_hunt(self, mvp: MVPBoss) -> list[Action]:
        """Initiate MVP hunt (move to spawn location)."""
        actions: list[Action] = []
        
        # Get spawn location
        if mvp.spawn_maps:
            target_map = mvp.spawn_maps[0]
            logger.info(f"Initiating hunt on {target_map}")
            # Would create warp/move action here
        
        return actions
    
    def load_mvp_database(self, data: dict) -> None:
        """Load MVP database from dictionary."""
        self.mvp_db.load_from_dict(data)
        logger.info(f"Loaded {len(self.mvp_db.get_all())} MVPs into database")