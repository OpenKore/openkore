"""
Environment Coordinator for OpenKore AI Sidecar.

Main coordinator integrating all environmental systems including time,
day/night, weather, events, and map environments. Acts as the primary
interface for environmental decision making.
"""

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog

from pydantic import BaseModel, Field

from ai_sidecar.environment.day_night import DayNightManager
from ai_sidecar.environment.events import EventManager, SeasonalEvent
from ai_sidecar.environment.maps import MapEnvironmentManager
from ai_sidecar.environment.time_core import TimeManager
from ai_sidecar.environment.weather import WeatherManager


class EnvironmentCoordinator:
    """
    Main environment coordinator integrating all environmental systems.

    Acts as facade for:
    - Time Manager
    - Day/Night Manager
    - Weather Manager
    - Event Manager
    - Map Environment Manager

    Provides unified interface for environmental decision making.
    """

    def __init__(self, data_dir: Path, server_timezone: int = 0):
        """
        Initialize EnvironmentCoordinator.

        Args:
            data_dir: Directory containing environment configuration files
            server_timezone: Server timezone offset from UTC
        """
        self.log = structlog.get_logger()

        # Initialize core systems
        self.time = TimeManager(data_dir, server_timezone)
        self.day_night = DayNightManager(data_dir, self.time)
        self.weather = WeatherManager(data_dir, self.time)
        self.events = EventManager(data_dir, self.time)
        self.maps = MapEnvironmentManager(
            data_dir, self.time, self.day_night, self.weather
        )

        self.log.info("environment_coordinator_initialized")

    async def update(self) -> None:
        """Update all environmental states."""
        # Update time
        self.time.calculate_game_time()

        # Refresh active events
        self.events.refresh_active_events()

        self.log.debug("environment_updated")

    def get_environment_summary(self, map_name: str) -> dict:
        """
        Get complete environmental summary for a map.

        Args:
            map_name: Map name

        Returns:
            Comprehensive environment summary
        """
        game_time = self.time.calculate_game_time()
        phase = self.day_night.get_current_phase()
        weather = self.weather.get_weather(map_name)
        active_events = self.events.get_active_events()
        map_props = self.maps.get_map_properties(map_name)

        summary = {
            "map": map_name,
            "time": {
                "game_hour": game_time.game_hour,
                "game_minute": game_time.game_minute,
                "period": game_time.period.value,
                "is_daytime": game_time.is_daytime,
                "phase": phase.value,
                "season": game_time.season.value,
            },
            "weather": {
                "type": weather.value,
                "visibility": self.weather.get_visibility_modifier(map_name),
                "movement": self.weather.get_movement_modifier(map_name),
            },
            "events": {
                "active_count": len(active_events),
                "exp_bonus": self.events.get_event_exp_bonus(),
                "drop_bonus": self.events.get_event_drop_bonus(),
                "events": [e.event_name for e in active_events],
            },
            "map_properties": {
                "type": map_props.map_type.value if map_props else "unknown",
                "environment": map_props.environment.value if map_props else "unknown",
                "has_day_night": map_props.has_day_night if map_props else True,
                "has_weather": map_props.has_weather if map_props else True,
            },
            "modifiers": self.maps.get_combined_modifiers(map_name),
        }

        return summary

    def get_current_bonuses(self) -> dict:
        """
        Get all current environmental bonuses.

        Returns:
            Dictionary of active bonuses
        """
        # Day/night bonuses
        phase_mods = self.day_night.get_phase_modifiers()

        # Event bonuses
        event_exp = self.events.get_event_exp_bonus()
        event_drop = self.events.get_event_drop_bonus()

        return {
            "exp_multiplier": phase_mods.exp_modifier * event_exp,
            "drop_multiplier": phase_mods.drop_modifier * event_drop,
            "spawn_rate": phase_mods.monster_spawn_rate,
            "visibility": phase_mods.visibility_range,
            "event_count": len(self.events.get_active_events()),
        }

    def get_optimal_farming_conditions(
        self, target_monster: str, current_map: str
    ) -> dict:
        """
        Get optimal conditions for farming target.

        Args:
            target_monster: Target monster name
            current_map: Current map name

        Returns:
            Optimal farming conditions
        """
        # Check monster availability
        is_available = self.day_night.get_monster_availability(
            current_map, target_monster
        )

        # Get optimal farming periods
        optimal_phases = self.day_night.get_optimal_farming_period(target_monster)

        # Get current conditions
        current_phase = self.day_night.get_current_phase()
        is_optimal = current_phase in optimal_phases

        # Get modifiers
        spawn_rate = self.day_night.get_spawn_rate_modifier()
        exp_mod = self.day_night.get_exp_modifier()
        drop_mod = self.day_night.get_drop_modifier()

        return {
            "monster": target_monster,
            "map": current_map,
            "is_available": is_available,
            "is_optimal_time": is_optimal,
            "current_phase": current_phase.value,
            "optimal_phases": [p.value for p in optimal_phases],
            "modifiers": {
                "spawn_rate": spawn_rate,
                "exp": exp_mod,
                "drop": drop_mod,
            },
        }

    async def should_relocate(
        self, current_map: str, character_state: dict
    ) -> Tuple[bool, Optional[str], str]:
        """
        Check if should relocate based on environmental factors.

        Args:
            current_map: Current map name
            character_state: Character state dictionary

        Returns:
            Tuple of (should_relocate, target_map, reason)
        """
        # Check day/night farming spot switch
        should_switch, recommended_map = self.day_night.should_switch_farming_spot(
            current_map
        )
        if should_switch and recommended_map:
            return True, recommended_map, "Time-based monster availability changed"

        # Check event maps
        active_events = self.events.get_active_events()
        for event in active_events:
            if event.event_maps and current_map not in event.event_maps:
                priority = self.events.calculate_event_priority(event)
                if priority > 50:  # High priority event
                    target = event.event_maps[0] if event.event_maps else None
                    return True, target, f"High priority event: {event.event_name}"

        # Check current map modifiers
        modifiers = self.maps.get_combined_modifiers(current_map)
        if modifiers.get("exp", 1.0) < 0.8:  # Significant penalty
            # Find better map
            optimal_maps = self.maps.get_optimal_maps_for_time(
                self.time.current_time, "farming"
            )
            if optimal_maps and optimal_maps[0] != current_map:
                return True, optimal_maps[0], "Better farming location available"

        return False, None, "Current location is optimal"

    def get_time_sensitive_actions(self) -> List[dict]:
        """
        Get pending time-sensitive actions.

        Returns:
            List of time-sensitive action dictionaries
        """
        actions = []

        # Check for ending events
        for event in self.events.get_active_events():
            time_remaining = self.events.get_event_time_remaining(event.event_id)
            if time_remaining and time_remaining.days < 1:
                actions.append(
                    {
                        "type": "event_ending",
                        "priority": 100,
                        "event": event.event_name,
                        "time_remaining": str(time_remaining),
                        "action": f"Complete event quests: {event.event_name}",
                    }
                )

        # Check for daily quests
        daily_quests = self.events.get_daily_quests()
        if daily_quests:
            actions.append(
                {
                    "type": "daily_quests",
                    "priority": 75,
                    "count": len(daily_quests),
                    "action": f"Complete {len(daily_quests)} daily quests",
                }
            )

        # Sort by priority
        actions.sort(key=lambda x: x["priority"], reverse=True)
        return actions

    def get_upcoming_events(self, hours_ahead: int = 24) -> List[SeasonalEvent]:
        """
        Get events starting within specified hours.

        Args:
            hours_ahead: Hours to look ahead

        Returns:
            List of upcoming SeasonalEvent objects
        """
        # This would need implementation to check future event start times
        # For now, return currently active events
        return self.events.get_active_events()

    async def plan_activity_schedule(
        self, hours_ahead: int, character_state: dict
    ) -> List[dict]:
        """
        Plan activities considering all environmental factors.

        Args:
            hours_ahead: Hours to plan ahead
            character_state: Character state dictionary

        Returns:
            List of planned activity dictionaries
        """
        schedule = []

        # Current time
        current_hour = self.time.calculate_game_time().game_hour

        # Plan for each hour
        for hour_offset in range(hours_ahead):
            planned_hour = (current_hour + hour_offset) % 24

            # Determine optimal activity
            activity = {
                "hour": planned_hour,
                "recommended_action": "farming",
                "priority_level": "normal",
                "bonuses": {},
            }

            # Check for time-sensitive events
            time_sensitive = self.get_time_sensitive_actions()
            if time_sensitive:
                activity["recommended_action"] = time_sensitive[0]["action"]
                activity["priority_level"] = "high"

            # Add event bonuses
            bonuses = self.get_current_bonuses()
            activity["bonuses"] = bonuses

            schedule.append(activity)

        return schedule

    def get_skill_effectiveness(
        self, skill_name: str, map_name: str
    ) -> Dict[str, float]:
        """
        Calculate skill effectiveness on a map.

        Args:
            skill_name: Skill name
            map_name: Map name

        Returns:
            Dictionary of effectiveness factors
        """
        effectiveness = {
            "base": 1.0,
            "day_night": 1.0,
            "weather": 1.0,
            "combined": 1.0,
        }

        # Day/night modifier
        day_night_mod = self.day_night.get_skill_modifier(skill_name)
        effectiveness["day_night"] = day_night_mod

        # Weather modifier
        weather_mod = self.weather.get_skill_weather_modifier(map_name, skill_name)
        effectiveness["weather"] = weather_mod

        # Combined effectiveness
        effectiveness["combined"] = day_night_mod * weather_mod

        return effectiveness

    def is_favorable_conditions(
        self, activity_type: str, map_name: str, threshold: float = 1.2
    ) -> bool:
        """
        Check if current conditions are favorable for activity.

        Args:
            activity_type: Type of activity ("farming", "grinding", "questing")
            map_name: Map name
            threshold: Minimum bonus threshold

        Returns:
            True if conditions are favorable
        """
        modifiers = self.maps.get_combined_modifiers(map_name)

        if activity_type == "farming":
            return modifiers.get("drop", 1.0) >= threshold
        elif activity_type == "grinding":
            return modifiers.get("exp", 1.0) >= threshold
        elif activity_type == "questing":
            # Questing benefits from visibility and movement
            visibility = modifiers.get("visibility", 1.0)
            movement = modifiers.get("movement", 1.0)
            return (visibility * movement) >= threshold

        return False

    def get_recommended_maps(
        self, character_level: int, activity_type: str, limit: int = 5
    ) -> List[Tuple[str, float]]:
        """
        Get recommended maps for character.

        Args:
            character_level: Character's level
            activity_type: Type of activity
            limit: Maximum maps to return

        Returns:
            List of (map_name, score) tuples
        """
        recommendations = []

        for map_name, props in self.maps.map_properties.items():
            # Check level requirement
            if props.level_requirement > character_level:
                continue

            # Skip PvP/WoE maps for farming
            if activity_type in ["farming", "grinding"] and props.map_type.value in [
                "pvp",
                "woe",
            ]:
                continue

            # Calculate score
            modifiers = self.maps.get_combined_modifiers(map_name)
            score = 0.0

            if activity_type == "farming":
                score = modifiers.get("drop", 1.0) * 2 + modifiers.get("exp", 1.0)
            elif activity_type == "grinding":
                score = modifiers.get("exp", 1.0) * 3
            else:
                score = 1.0

            # Add event bonus
            for event in self.events.get_active_events():
                if map_name in event.event_maps:
                    score *= event.drop_bonus * event.exp_bonus

            recommendations.append((map_name, score))

        # Sort by score
        recommendations.sort(key=lambda x: x[1], reverse=True)
        return recommendations[:limit]
    
    async def tick(self, game_state, tick: int) -> List[dict]:
        """
        Main environment coordinator tick.
        
        P3 Bridge Features (100%):
        - Server time synchronization
        - Weather/season tracking
        - Event detection and management
        - Map hazard awareness
        - Time-based optimization recommendations
        
        Args:
            game_state: Current game state
            tick: Current game tick
            
        Returns:
            List of environment-related actions
        """
        actions = []
        
        try:
            # Update environmental state from game
            await self._sync_environment_data(game_state)
            
            # Refresh active events
            self.events.refresh_active_events()
            
            # Check for hazards on current map
            hazard_actions = await self._handle_map_hazards(game_state)
            if hazard_actions:
                actions.extend(hazard_actions)
                return actions  # Priority action
            
            # Check for event-based actions
            event_actions = await self._check_event_actions(game_state)
            if event_actions:
                actions.extend(event_actions)
            
            # Check for relocation recommendations
            if not actions and tick % 300 == 0:  # Check every 5 minutes
                should_relocate, target_map, reason = await self.should_relocate(
                    game_state.map.name,
                    {"level": game_state.character.base_level}
                )
                
                if should_relocate and target_map:
                    actions.append({
                        "type": "relocate",
                        "priority": 5,
                        "target_map": target_map,
                        "reason": reason
                    })
        
        except Exception as e:
            self.log.error(f"Error in environment coordinator tick: {e}", exc_info=True)
        
        return actions
    
    async def _sync_environment_data(self, game_state) -> None:
        """
        Synchronize environment data from game state.
        
        Args:
            game_state: Current game state
        """
        # Update server time
        if hasattr(game_state, 'environment') and game_state.environment:
            env = game_state.environment
            
            # Update time manager
            if hasattr(env, 'server_time'):
                self.time.server_time = env.server_time
            
            # Update day/night state
            if hasattr(env, 'is_night'):
                self.day_night.is_night = env.is_night
            
            # Update weather
            if hasattr(env, 'weather_type'):
                self.weather.current_weather_type = env.weather_type
            
            # Update season
            if hasattr(env, 'season'):
                self.time.current_season = env.season
            
            # Process active events
            if hasattr(env, 'active_events'):
                await self._process_server_events(env.active_events)
    
    async def _process_server_events(self, server_events: List) -> None:
        """
        Process server events from game state.
        
        Args:
            server_events: List of server event payloads
        """
        from ai_sidecar.environment.events import SeasonalEvent
        
        for event_data in server_events:
            try:
                # Convert to SeasonalEvent if needed
                if hasattr(event_data, 'event_id'):
                    event = SeasonalEvent(
                        event_id=event_data.event_id,
                        event_name=event_data.event_name,
                        event_type=event_data.event_type,
                        start_date=event_data.start_time,
                        end_date=event_data.end_time,
                        is_active=event_data.is_active,
                        exp_bonus=event_data.bonus_exp,
                        drop_bonus=event_data.bonus_drop,
                        event_maps=[]
                    )
                    
                    # Add or update in event manager
                    self.events.add_or_update_event(event)
            except Exception as e:
                self.log.error(f"Failed to process event: {e}")
    
    async def _handle_map_hazards(self, game_state) -> List[dict]:
        """
        Handle map hazards (poison swamps, lava, etc.).
        
        Args:
            game_state: Current game state
            
        Returns:
            List of hazard avoidance actions
        """
        actions = []
        
        if not hasattr(game_state, 'environment') or not game_state.environment:
            return actions
        
        env = game_state.environment
        if not hasattr(env, 'map_hazards'):
            return actions
        
        char_pos = game_state.character.position
        
        # Check each hazard
        for hazard in env.map_hazards:
            hazard_pos = hazard.position
            distance = ((char_pos.x - hazard_pos["x"]) ** 2 +
                       (char_pos.y - hazard_pos["y"]) ** 2) ** 0.5
            
            # If we're within hazard radius, move away
            if distance < hazard.radius:
                # Calculate safe position (opposite direction)
                dx = char_pos.x - hazard_pos["x"]
                dy = char_pos.y - hazard_pos["y"]
                
                # Normalize and extend
                magnitude = (dx ** 2 + dy ** 2) ** 0.5
                if magnitude > 0:
                    safe_x = char_pos.x + int(dx / magnitude * (hazard.radius + 3))
                    safe_y = char_pos.y + int(dy / magnitude * (hazard.radius + 3))
                    
                    actions.append({
                        "type": "move",
                        "priority": 1,  # High priority
                        "x": safe_x,
                        "y": safe_y,
                        "extra": {
                            "reason": f"Avoiding {hazard.hazard_type} hazard",
                            "damage": hazard.damage_per_tick
                        }
                    })
        
        return actions
    
    async def _check_event_actions(self, game_state) -> List[dict]:
        """
        Check for event-specific actions.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of event-related actions
        """
        actions = []
        
        # Get time-sensitive actions
        time_sensitive = self.get_time_sensitive_actions()
        
        for action in time_sensitive[:2]:  # Top 2 most urgent
            actions.append({
                "type": action["type"],
                "priority": 4,
                "extra": {
                    "event": action.get("event"),
                    "reason": action["action"]
                }
            })
        
        return actions
    
    def get_hazard_warning(self, map_name: str, position: dict) -> dict | None:
        """
        Check if position has hazards.
        
        Args:
            map_name: Map name
            position: Position to check
            
        Returns:
            Hazard warning or None
        """
        # Would check known hazard locations
        return None
    
    def get_environment_bonuses_summary(self) -> dict:
        """
        Get summary of all active bonuses.
        
        Returns:
            Dictionary of active bonuses
        """
        bonuses = self.get_current_bonuses()
        
        return {
            "total_exp_multiplier": bonuses["exp_multiplier"],
            "total_drop_multiplier": bonuses["drop_multiplier"],
            "spawn_rate": bonuses["spawn_rate"],
            "visibility": bonuses["visibility"],
            "active_event_count": bonuses["event_count"],
            "recommendation": "Excellent farming conditions" if bonuses["exp_multiplier"] > 1.5 else "Normal conditions"
        }