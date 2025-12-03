"""
Day/Night Cycle System for OpenKore AI Sidecar.

Manages day/night phases and their effects on gameplay including
monster spawns, NPC availability, skill modifiers, and visibility.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.environment.time_core import TimeManager


class DayNightPhase(str, Enum):
    """Detailed day/night phases throughout the day."""

    # Simple day/night indicators (for tests/compatibility)
    DAY = "day"
    NIGHT = "night"
    
    # Detailed phases
    EARLY_MORNING = "early_morning"  # 5:00-6:59
    MORNING = "morning"  # 7:00-9:59
    LATE_MORNING = "late_morning"  # 10:00-11:59
    MIDDAY = "midday"  # 12:00-13:59
    AFTERNOON = "afternoon"  # 14:00-15:59
    LATE_AFTERNOON = "late_afternoon"  # 16:00-17:59
    SUNSET = "sunset"  # 18:00-19:59
    EVENING = "evening"  # 20:00-21:59
    LATE_EVENING = "late_evening"  # 22:00-23:59
    MIDNIGHT = "midnight"  # 0:00-1:59
    DEEP_NIGHT = "deep_night"  # 2:00-3:59
    PREDAWN = "predawn"  # 4:00-4:59


class PhaseModifiers(BaseModel):
    """Modifiers applied during a specific time phase."""

    monster_spawn_rate: float = Field(default=1.0, ge=0.0)
    monster_aggro_range: float = Field(default=1.0, ge=0.0)
    exp_modifier: float = Field(default=1.0, ge=0.0)
    drop_modifier: float = Field(default=1.0, ge=0.0)
    npc_availability: float = Field(default=1.0, ge=0.0, le=1.0)
    visibility_range: float = Field(default=1.0, ge=0.0)
    skill_modifiers: Dict[str, float] = Field(default_factory=dict)


class DayNightManager:
    """
    Manage day/night cycle effects on gameplay.

    Effects include:
    - Monster spawn rate changes
    - NPC availability (shops closed at night)
    - Skill effectiveness (Moon Slasher, Sunshine)
    - Player visibility
    - Event timing
    """

    def __init__(self, data_dir: Path, time_manager: TimeManager):
        """
        Initialize DayNightManager.

        Args:
            data_dir: Directory containing day/night configuration files
            time_manager: TimeManager instance for time calculations
        """
        self.log = structlog.get_logger()
        self.time_manager = time_manager
        self.phase_modifiers: Dict[DayNightPhase, PhaseModifiers] = {}
        self.night_monsters: Dict[str, List[str]] = {}  # Map -> night-only monsters
        self.day_monsters: Dict[str, List[str]] = {}  # Map -> day-only monsters
        self.night_npcs: Dict[int, bool] = {}  # NPC ID -> available at night
        self._load_phase_data(data_dir)

    def _load_phase_data(self, data_dir: Path) -> None:
        """
        Load phase modifiers and monster spawn data.

        Args:
            data_dir: Data directory path
        """
        try:
            modifier_file = data_dir / "day_night_modifiers.json"
            if modifier_file.exists():
                with open(modifier_file, "r") as f:
                    data = json.load(f)

                    # Load phase modifiers
                    phases_data = data.get("phases", {})
                    for phase_key, mods in phases_data.items():
                        if phase_key in ["night", "evening", "late_evening"]:
                            # Apply night modifiers to all night phases
                            for night_phase in [
                                DayNightPhase.SUNSET,
                                DayNightPhase.EVENING,
                                DayNightPhase.LATE_EVENING,
                                DayNightPhase.MIDNIGHT,
                                DayNightPhase.DEEP_NIGHT,
                                DayNightPhase.PREDAWN,
                            ]:
                                self.phase_modifiers[night_phase] = PhaseModifiers(
                                    **mods
                                )
                        elif phase_key == "day":
                            # Apply day modifiers to all day phases
                            for day_phase in [
                                DayNightPhase.EARLY_MORNING,
                                DayNightPhase.MORNING,
                                DayNightPhase.LATE_MORNING,
                                DayNightPhase.MIDDAY,
                                DayNightPhase.AFTERNOON,
                                DayNightPhase.LATE_AFTERNOON,
                            ]:
                                self.phase_modifiers[day_phase] = PhaseModifiers(
                                    **mods
                                )

                    # Load monster spawn data
                    self.night_monsters = data.get("night_only_monsters", {})
                    self.day_monsters = data.get("day_only_monsters", {})

            self.log.info("day_night_data_loaded")
        except Exception as e:
            self.log.error("failed_to_load_day_night_data", error=str(e))

    def get_current_phase(self) -> DayNightPhase:
        """
        Get current detailed time phase.

        Returns:
            Current DayNightPhase
        """
        game_time = self.time_manager.calculate_game_time()
        hour = game_time.game_hour

        if 5 <= hour < 7:
            return DayNightPhase.EARLY_MORNING
        elif 7 <= hour < 10:
            return DayNightPhase.MORNING
        elif 10 <= hour < 12:
            return DayNightPhase.LATE_MORNING
        elif 12 <= hour < 14:
            return DayNightPhase.MIDDAY
        elif 14 <= hour < 16:
            return DayNightPhase.AFTERNOON
        elif 16 <= hour < 18:
            return DayNightPhase.LATE_AFTERNOON
        elif 18 <= hour < 20:
            return DayNightPhase.SUNSET
        elif 20 <= hour < 22:
            return DayNightPhase.EVENING
        elif 22 <= hour < 24:
            return DayNightPhase.LATE_EVENING
        elif 0 <= hour < 2:
            return DayNightPhase.MIDNIGHT
        elif 2 <= hour < 4:
            return DayNightPhase.DEEP_NIGHT
        else:  # 4 <= hour < 5
            return DayNightPhase.PREDAWN

    def get_phase_modifiers(
        self, phase: Optional[DayNightPhase] = None
    ) -> PhaseModifiers:
        """
        Get modifiers for current or specified phase.

        Args:
            phase: Specific phase (default: current)

        Returns:
            PhaseModifiers for the phase
        """
        if phase is None:
            phase = self.get_current_phase()

        return self.phase_modifiers.get(phase, PhaseModifiers())

    def get_skill_modifier(self, skill_name: str) -> float:
        """
        Get time-based modifier for a skill.

        Args:
            skill_name: Name of the skill

        Returns:
            Skill modifier multiplier
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.skill_modifiers.get(skill_name, 1.0)

    def get_monster_availability(self, map_name: str, monster_name: str) -> bool:
        """
        Check if monster spawns during current time.

        Args:
            map_name: Map name
            monster_name: Monster name

        Returns:
            True if monster spawns at current time
        """
        is_night = not self.time_manager.is_daytime()

        # Check night-only monsters
        if map_name in self.night_monsters:
            if monster_name in self.night_monsters[map_name]:
                return is_night

        # Check day-only monsters
        if map_name in self.day_monsters:
            if monster_name in self.day_monsters[map_name]:
                return not is_night

        # Default: spawns at all times
        return True

    def get_available_monsters(self, map_name: str) -> List[str]:
        """
        Get monsters available at current time on map.

        Args:
            map_name: Map name

        Returns:
            List of available monster names
        """
        is_night = not self.time_manager.is_daytime()
        available = []

        # Add night monsters if it's night
        if is_night and map_name in self.night_monsters:
            available.extend(self.night_monsters[map_name])

        # Add day monsters if it's day
        if not is_night and map_name in self.day_monsters:
            available.extend(self.day_monsters[map_name])

        return available

    def is_npc_available(self, npc_id: int, map_name: str) -> bool:
        """
        Check if NPC is available at current time.

        Args:
            npc_id: NPC identifier
            map_name: Map where NPC is located

        Returns:
            True if NPC is available
        """
        # Most NPCs are available during the day
        is_daytime = self.time_manager.is_daytime()

        # Check if NPC has specific availability
        if npc_id in self.night_npcs:
            return self.night_npcs[npc_id] or is_daytime

        # Default: available during daytime only
        return is_daytime

    def get_visibility_modifier(self) -> float:
        """
        Get visibility modifier for current time.

        Returns:
            Visibility multiplier (0.0-1.0)
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.visibility_range

    def should_switch_farming_spot(
        self, current_map: str
    ) -> Tuple[bool, Optional[str]]:
        """
        Check if should switch farming spots due to day/night.

        Args:
            current_map: Current map name

        Returns:
            Tuple of (should_switch, recommended_map)
        """
        is_night = not self.time_manager.is_daytime()

        # Check if current map has better options at different times
        if is_night:
            # If on a day-only monster map at night, recommend switching
            if current_map in self.day_monsters and self.day_monsters[current_map]:
                # Find a map with night monsters
                for map_name, monsters in self.night_monsters.items():
                    if monsters:
                        return True, map_name
        else:
            # If on a night-only monster map during day, recommend switching
            if (
                current_map in self.night_monsters
                and self.night_monsters[current_map]
            ):
                # Find a map with day monsters
                for map_name, monsters in self.day_monsters.items():
                    if monsters:
                        return True, map_name

        return False, None

    def get_optimal_farming_period(self, monster_name: str) -> List[DayNightPhase]:
        """
        Get optimal farming periods for a monster.

        Args:
            monster_name: Monster name

        Returns:
            List of optimal DayNightPhase values
        """
        optimal_phases = []

        # Check if monster is time-restricted
        is_night_only = any(
            monster_name in monsters for monsters in self.night_monsters.values()
        )
        is_day_only = any(
            monster_name in monsters for monsters in self.day_monsters.values()
        )

        if is_night_only:
            # Night phases
            optimal_phases = [
                DayNightPhase.SUNSET,
                DayNightPhase.EVENING,
                DayNightPhase.LATE_EVENING,
                DayNightPhase.MIDNIGHT,
                DayNightPhase.DEEP_NIGHT,
            ]
        elif is_day_only:
            # Day phases
            optimal_phases = [
                DayNightPhase.MORNING,
                DayNightPhase.LATE_MORNING,
                DayNightPhase.MIDDAY,
                DayNightPhase.AFTERNOON,
            ]
        else:
            # All phases
            optimal_phases = list(DayNightPhase)

        return optimal_phases

    def get_spawn_rate_modifier(self) -> float:
        """
        Get current spawn rate modifier.

        Returns:
            Spawn rate multiplier
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.monster_spawn_rate

    def get_aggro_range_modifier(self) -> float:
        """
        Get current aggro range modifier.

        Returns:
            Aggro range multiplier
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.monster_aggro_range

    def get_exp_modifier(self) -> float:
        """
        Get current EXP modifier.

        Returns:
            EXP multiplier
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.exp_modifier

    def get_drop_modifier(self) -> float:
        """
        Get current drop rate modifier.

        Returns:
            Drop rate multiplier
        """
        current_phase = self.get_current_phase()
        modifiers = self.get_phase_modifiers(current_phase)
        return modifiers.drop_modifier

    def is_optimal_hunting_time(self, monster_name: str, map_name: str) -> bool:
        """
        Check if current time is optimal for hunting a specific monster.

        Args:
            monster_name: Monster name
            map_name: Map name

        Returns:
            True if optimal time
        """
        # Check availability
        if not self.get_monster_availability(map_name, monster_name):
            return False

        # Check spawn rate bonus
        spawn_rate = self.get_spawn_rate_modifier()
        if spawn_rate > 1.1:  # 10% bonus or more
            return True

        return True
    
    def update_time(self, hour: int, minute: int) -> None:
        """
        Update time-based effects.
        
        This method processes time advancement and updates any time-sensitive
        modifiers or states. It's called periodically by the environment coordinator.
        
        Args:
            hour: Current game hour
            minute: Current game minute
        """
        # Log phase changes
        current_phase = self.get_current_phase()
        
        # Track phase changes (would store last_phase as instance variable in real impl)
        if not hasattr(self, '_last_phase'):
            self._last_phase = current_phase
        elif self._last_phase != current_phase:
            self.log.info(
                "day_night_phase_changed",
                old_phase=self._last_phase.value,
                new_phase=current_phase.value
            )
            self._last_phase = current_phase