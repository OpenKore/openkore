"""
Trap Manager - Hunter/Sniper/Ranger trap mechanics.

Manages trap placement, tracking, and strategy for archer branch trap users.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class TrapType(str, Enum):
    """Types of traps available to hunters/rangers."""

    ANKLE_SNARE = "ankle_snare"
    BLAST_MINE = "blast_mine"
    CLAYMORE_TRAP = "claymore_trap"
    FREEZING_TRAP = "freezing_trap"
    LAND_MINE = "land_mine"
    SANDMAN = "sandman"
    SHOCKWAVE_TRAP = "shockwave_trap"
    SKID_TRAP = "skid_trap"
    SPRING_TRAP = "spring_trap"
    CLUSTER_BOMB = "cluster_bomb"
    DETONATOR = "detonator"
    ELECTRIC_SHOCKER = "electric_shocker"
    MAGENTA_TRAP = "magenta_trap"
    FIRE_TRAP = "fire_trap"
    ICE_TRAP = "ice_trap"


class PlacedTrap(BaseModel):
    """A placed trap on the field."""

    model_config = ConfigDict(frozen=False)

    trap_type: TrapType = Field(description="Type of trap")
    position: tuple[int, int] = Field(description="Trap position (x, y)")
    placed_at: datetime = Field(default_factory=datetime.now)
    duration_seconds: int = Field(ge=1, description="Trap duration")
    is_triggered: bool = Field(default=False)

    @property
    def is_expired(self) -> bool:
        """Check if trap has expired."""
        expiry = self.placed_at + timedelta(seconds=self.duration_seconds)
        return datetime.now() >= expiry


class TrapManager:
    """
    Manage Hunter/Sniper/Ranger traps.

    Mechanics:
    - Limited trap count per type
    - Traps have duration
    - Some traps chain (Detonator)
    - Position-based strategy
    """

    def __init__(self, data_dir: Path | None = None) -> None:
        """
        Initialize trap manager.

        Args:
            data_dir: Optional data directory for trap definitions
        """
        self.log = structlog.get_logger()

        # Active traps
        self.placed_traps: list[PlacedTrap] = []
        self.max_traps: int = 3

        # Trap definitions
        self.trap_definitions: dict[TrapType, dict[str, Any]] = {}

        if data_dir:
            self._load_trap_definitions(Path(data_dir))

    def _load_trap_definitions(self, data_dir: Path) -> None:
        """Load trap definitions from JSON."""
        trap_file = data_dir / "trap_definitions.json"

        if not trap_file.exists():
            self.log.warning(
                "trap_definitions.json not found",
                path=str(trap_file),
            )
            return

        try:
            with open(trap_file, encoding="utf-8") as f:
                data = json.load(f)

            traps_data = data.get("traps", {})
            for trap_name, trap_info in traps_data.items():
                try:
                    trap_type = TrapType(trap_name)
                    self.trap_definitions[trap_type] = trap_info
                except ValueError:
                    self.log.warning(f"Unknown trap type: {trap_name}")

            # Load max traps by level
            max_by_level = data.get("max_traps_by_level", {})
            # Use highest level's max for now
            if max_by_level:
                self.max_traps = max(int(v) for v in max_by_level.values())

            self.log.info(
                "Trap definitions loaded",
                trap_types=len(self.trap_definitions),
            )

        except Exception as e:
            self.log.error(
                "Failed to load trap_definitions.json",
                error=str(e),
            )

    def place_trap(
        self, trap_type: TrapType, position: tuple[int, int]
    ) -> bool:
        """
        Place a trap at position.

        Args:
            trap_type: Type of trap to place
            position: Position tuple (x, y)

        Returns:
            True if trap was placed successfully
        """
        # Clean up expired traps first
        self.cleanup_expired_traps()

        # Check trap limit
        if len(self.placed_traps) >= self.max_traps:
            self.log.warning("Maximum trap count reached", max=self.max_traps)
            return False

        # Get trap definition
        trap_def = self.trap_definitions.get(trap_type)
        if not trap_def:
            self.log.error(f"No definition for trap: {trap_type}")
            return False

        # Create and place trap
        trap = PlacedTrap(
            trap_type=trap_type,
            position=position,
            duration_seconds=trap_def.get("duration_seconds", 20),
        )

        self.placed_traps.append(trap)
        self.log.info(
            "Trap placed",
            type=trap_type.value,
            position=position,
            count=len(self.placed_traps),
        )

        return True

    def get_trap_count(self) -> int:
        """Get current number of active traps."""
        self.cleanup_expired_traps()
        return len(self.placed_traps)

    def cleanup_expired_traps(self) -> int:
        """
        Remove expired traps from tracking.

        Returns:
            Number of traps removed
        """
        initial_count = len(self.placed_traps)
        self.placed_traps = [t for t in self.placed_traps if not t.is_expired]
        removed = initial_count - len(self.placed_traps)

        if removed > 0:
            self.log.debug("Expired traps cleaned up", removed=removed)

        return removed

    def find_optimal_trap_position(
        self,
        enemy_positions: list[tuple[int, int]],
        own_position: tuple[int, int],
    ) -> tuple[int, int]:
        """
        Calculate optimal trap placement.

        Args:
            enemy_positions: List of enemy positions
            own_position: Player position

        Returns:
            Optimal trap position
        """
        if not enemy_positions:
            return own_position

        # Find centroid of enemy positions
        avg_x = sum(pos[0] for pos in enemy_positions) / len(enemy_positions)
        avg_y = sum(pos[1] for pos in enemy_positions) / len(enemy_positions)

        # Place trap between player and enemies
        trap_x = int((own_position[0] + avg_x) / 2)
        trap_y = int((own_position[1] + avg_y) / 2)

        return (trap_x, trap_y)

    def should_use_detonator(self) -> bool:
        """
        Determine if Detonator should be used.

        Returns:
            True if we have explosive traps to detonate
        """
        explosive_types = {
            TrapType.BLAST_MINE,
            TrapType.CLAYMORE_TRAP,
            TrapType.CLUSTER_BOMB,
        }

        return any(
            trap.trap_type in explosive_types and not trap.is_triggered
            for trap in self.placed_traps
        )

    def trigger_trap(self, position: tuple[int, int]) -> PlacedTrap | None:
        """
        Trigger a trap at position.

        Args:
            position: Position where trap is triggered

        Returns:
            Triggered trap or None
        """
        for trap in self.placed_traps:
            if trap.position == position and not trap.is_triggered:
                trap.is_triggered = True
                self.log.info("Trap triggered", type=trap.trap_type.value)
                return trap

        return None

    def get_trap_layout_strategy(
        self, situation: str
    ) -> list[tuple[TrapType, str]]:
        """
        Get recommended trap layout for situation.

        Args:
            situation: Situation type (boss, farming, pvp)

        Returns:
            List of (trap_type, placement_hint) tuples
        """
        layouts = {
            "boss": [
                (TrapType.ANKLE_SNARE, "front"),
                (TrapType.CLAYMORE_TRAP, "center"),
                (TrapType.BLAST_MINE, "behind"),
            ],
            "farming": [
                (TrapType.BLAST_MINE, "center"),
                (TrapType.FREEZING_TRAP, "front"),
            ],
            "pvp": [
                (TrapType.ANKLE_SNARE, "escape_route"),
                (TrapType.SANDMAN, "choke_point"),
                (TrapType.CLAYMORE_TRAP, "ambush"),
            ],
        }

        return layouts.get(situation, [])

    def get_status(self) -> dict[str, Any]:
        """Get trap manager status."""
        self.cleanup_expired_traps()

        return {
            "active_traps": len(self.placed_traps),
            "max_traps": self.max_traps,
            "traps": [
                {
                    "type": trap.trap_type.value,
                    "position": trap.position,
                    "triggered": trap.is_triggered,
                    "expires_in": (
                        trap.placed_at
                        + timedelta(seconds=trap.duration_seconds)
                        - datetime.now()
                    ).total_seconds(),
                }
                for trap in self.placed_traps
            ],
        }

    def reset(self) -> None:
        """Reset trap state (e.g., after map change)."""
        self.placed_traps.clear()
        self.log.debug("Trap state reset")

    def get_placed_traps(self) -> list[PlacedTrap]:
        """
        Get all currently placed traps.
        
        Returns:
            List of placed traps (includes expired ones until cleanup)
        """
        return self.placed_traps.copy()