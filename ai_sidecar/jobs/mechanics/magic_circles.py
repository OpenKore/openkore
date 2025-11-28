"""
Magic Circle Manager - Sorcerer/Warlock magic circle mechanics.

Manages magic circle placement, tracking, and effect management for
mage branch advanced classes.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class CircleType(str, Enum):
    """Types of magic circles available."""

    # Elemental Circles
    FIRE_INSIGNIA = "fire_insignia"
    WATER_INSIGNIA = "water_insignia"
    WIND_INSIGNIA = "wind_insignia"
    EARTH_INSIGNIA = "earth_insignia"
    
    # Advanced Circles
    POISON_BUSTER = "poison_buster"
    PSYCHIC_WAVE = "psychic_wave"
    CLOUD_KILL = "cloud_kill"
    STRIKING = "striking"
    WARMER = "warmer"
    VACUUM_EXTREME = "vacuum_extreme"
    
    # Summoning Circles
    SUMMON_FIRE_BALL = "summon_fire_ball"
    SUMMON_WATER_BALL = "summon_water_ball"
    SUMMON_LIGHTNING_BALL = "summon_lightning_ball"
    SUMMON_STONE = "summon_stone"


class PlacedCircle(BaseModel):
    """A placed magic circle on the field."""

    model_config = ConfigDict(frozen=False)

    circle_type: CircleType = Field(description="Type of magic circle")
    position: tuple[int, int] = Field(description="Circle position (x, y)")
    placed_at: datetime = Field(default_factory=datetime.now)
    duration_seconds: int = Field(ge=1, description="Circle duration")
    radius: int = Field(ge=1, description="Effect radius")
    is_active: bool = Field(default=True)

    @property
    def is_expired(self) -> bool:
        """Check if circle has expired."""
        expiry = self.placed_at + timedelta(seconds=self.duration_seconds)
        return datetime.now() >= expiry


class MagicCircleManager:
    """
    Manage Sorcerer/Warlock magic circles.

    Mechanics:
    - Limited number of active circles
    - Different circle types with unique effects
    - Position-based area control
    - Insignia for elemental mastery
    """

    def __init__(self, data_dir: Path | None = None) -> None:
        """
        Initialize magic circle manager.

        Args:
            data_dir: Optional data directory for circle definitions
        """
        self.log = structlog.get_logger()

        # State
        self.placed_circles: list[PlacedCircle] = []
        self.max_circles: int = 2
        self.active_insignia: CircleType | None = None
        self.insignia_expires_at: datetime | None = None

        # Definitions
        self.circle_effects: dict[CircleType, dict[str, Any]] = {}

        if data_dir:
            self._load_circle_effects(Path(data_dir))

    def _load_circle_effects(self, data_dir: Path) -> None:
        """Load magic circle definitions from JSON."""
        circle_file = data_dir / "magic_circle_effects.json"

        if not circle_file.exists():
            self.log.warning(
                "magic_circle_effects.json not found",
                path=str(circle_file),
            )
            return

        try:
            with open(circle_file, encoding="utf-8") as f:
                data = json.load(f)

            circles_data = data.get("circles", {})
            for circle_name, circle_info in circles_data.items():
                try:
                    circle_type = CircleType(circle_name)
                    self.circle_effects[circle_type] = circle_info
                except ValueError:
                    self.log.warning(f"Unknown circle type: {circle_name}")

            self.log.info(
                "Magic circle effects loaded",
                circle_count=len(self.circle_effects),
            )

        except Exception as e:
            self.log.error(
                "Failed to load magic_circle_effects.json",
                error=str(e),
            )

    def place_circle(
        self, circle_type: CircleType, position: tuple[int, int]
    ) -> bool:
        """
        Place a magic circle at position.

        Args:
            circle_type: Type of circle to place
            position: Position tuple (x, y)

        Returns:
            True if circle was placed successfully
        """
        # Clean up expired circles first
        self.cleanup_expired_circles()

        # Check circle limit (insignias don't count toward limit)
        if not self._is_insignia(circle_type):
            if len([c for c in self.placed_circles if not self._is_insignia(c.circle_type)]) >= self.max_circles:
                self.log.warning(
                    "Maximum circle count reached",
                    max=self.max_circles
                )
                return False

        # Get circle definition
        circle_def = self.circle_effects.get(circle_type)
        if not circle_def:
            self.log.error(f"No definition for circle: {circle_type}")
            return False

        # Handle insignia placement
        if self._is_insignia(circle_type):
            # Remove old insignia
            self.placed_circles = [
                c for c in self.placed_circles
                if not self._is_insignia(c.circle_type)
            ]
            self.active_insignia = circle_type
            self.insignia_expires_at = datetime.now() + timedelta(
                seconds=circle_def.get("duration_seconds", 60)
            )

        # Create and place circle
        circle = PlacedCircle(
            circle_type=circle_type,
            position=position,
            duration_seconds=circle_def.get("duration_seconds", 30),
            radius=circle_def.get("radius", 3),
        )

        self.placed_circles.append(circle)
        self.log.info(
            "Magic circle placed",
            type=circle_type.value,
            position=position,
            count=len(self.placed_circles),
        )

        return True

    def _is_insignia(self, circle_type: CircleType) -> bool:
        """Check if circle is an elemental insignia."""
        return circle_type in {
            CircleType.FIRE_INSIGNIA,
            CircleType.WATER_INSIGNIA,
            CircleType.WIND_INSIGNIA,
            CircleType.EARTH_INSIGNIA,
        }

    def get_circle_count(self) -> int:
        """Get current number of active non-insignia circles."""
        self.cleanup_expired_circles()
        return len([c for c in self.placed_circles if not self._is_insignia(c.circle_type)])

    def cleanup_expired_circles(self) -> int:
        """
        Remove expired circles from tracking.

        Returns:
            Number of circles removed
        """
        initial_count = len(self.placed_circles)
        self.placed_circles = [c for c in self.placed_circles if not c.is_expired]
        removed = initial_count - len(self.placed_circles)

        # Check insignia expiry
        if (
            self.active_insignia
            and self.insignia_expires_at
            and datetime.now() >= self.insignia_expires_at
        ):
            self.active_insignia = None
            self.insignia_expires_at = None

        if removed > 0:
            self.log.debug("Expired circles cleaned up", removed=removed)

        return removed

    def get_active_insignia(self) -> CircleType | None:
        """
        Get currently active elemental insignia.

        Returns:
            Insignia type or None
        """
        if (
            self.active_insignia
            and self.insignia_expires_at
            and datetime.now() < self.insignia_expires_at
        ):
            return self.active_insignia

        self.active_insignia = None
        self.insignia_expires_at = None
        return None

    def get_circles_at_position(
        self, position: tuple[int, int], radius: int = 0
    ) -> list[PlacedCircle]:
        """
        Get circles affecting a position.

        Args:
            position: Position to check
            radius: Additional radius to check

        Returns:
            List of circles affecting the position
        """
        self.cleanup_expired_circles()
        affecting: list[PlacedCircle] = []

        for circle in self.placed_circles:
            dx = abs(circle.position[0] - position[0])
            dy = abs(circle.position[1] - position[1])
            distance = (dx ** 2 + dy ** 2) ** 0.5

            if distance <= circle.radius + radius:
                affecting.append(circle)

        return affecting

    def get_recommended_circle(self, situation: str) -> CircleType | None:
        """
        Get recommended circle for situation.

        Args:
            situation: Situation type (boss, farming, pvp)

        Returns:
            Recommended circle type
        """
        recommendations = {
            "boss": [
                CircleType.STRIKING,
                CircleType.POISON_BUSTER,
                CircleType.PSYCHIC_WAVE,
            ],
            "farming": [
                CircleType.CLOUD_KILL,
                CircleType.FIRE_INSIGNIA,
                CircleType.VACUUM_EXTREME,
            ],
            "pvp": [
                CircleType.PSYCHIC_WAVE,
                CircleType.POISON_BUSTER,
                CircleType.WATER_INSIGNIA,
            ],
            "support": [
                CircleType.WARMER,
                CircleType.EARTH_INSIGNIA,
            ],
        }

        candidates = recommendations.get(situation, [])
        # Return first candidate (could be enhanced with availability checks)
        return candidates[0] if candidates else None

    def should_replace_circle(self) -> bool:
        """
        Determine if an old circle should be replaced.

        Returns:
            True if at max and should replace oldest
        """
        self.cleanup_expired_circles()
        non_insignia = [
            c for c in self.placed_circles
            if not self._is_insignia(c.circle_type)
        ]
        return len(non_insignia) >= self.max_circles

    def remove_oldest_circle(self) -> bool:
        """
        Remove the oldest non-insignia circle.

        Returns:
            True if a circle was removed
        """
        non_insignia = [
            c for c in self.placed_circles
            if not self._is_insignia(c.circle_type)
        ]

        if not non_insignia:
            return False

        # Find oldest
        oldest = min(non_insignia, key=lambda c: c.placed_at)
        self.placed_circles.remove(oldest)
        self.log.debug("Oldest circle removed", type=oldest.circle_type.value)
        return True

    def get_elemental_bonus(self, element: str) -> float:
        """
        Get elemental damage bonus from active insignia.

        Args:
            element: Element type to check

        Returns:
            Damage multiplier (1.0 = no bonus)
        """
        insignia = self.get_active_insignia()
        if not insignia:
            return 1.0

        # Map insignias to elements
        insignia_elements = {
            CircleType.FIRE_INSIGNIA: "fire",
            CircleType.WATER_INSIGNIA: "water",
            CircleType.WIND_INSIGNIA: "wind",
            CircleType.EARTH_INSIGNIA: "earth",
        }

        if insignia_elements.get(insignia) == element.lower():
            return 1.5  # 50% damage bonus

        return 1.0

    def get_status(self) -> dict[str, Any]:
        """Get magic circle manager status."""
        self.cleanup_expired_circles()

        status: dict[str, Any] = {
            "active_circles": len([
                c for c in self.placed_circles
                if not self._is_insignia(c.circle_type)
            ]),
            "max_circles": self.max_circles,
            "active_insignia": (
                self.active_insignia.value if self.active_insignia else None
            ),
            "circles": [
                {
                    "type": circle.circle_type.value,
                    "position": circle.position,
                    "radius": circle.radius,
                    "expires_in": (
                        circle.placed_at
                        + timedelta(seconds=circle.duration_seconds)
                        - datetime.now()
                    ).total_seconds(),
                }
                for circle in self.placed_circles
            ],
        }

        if self.active_insignia and self.insignia_expires_at:
            status["insignia_time_left"] = max(
                0, (self.insignia_expires_at - datetime.now()).total_seconds()
            )

        return status

    def reset(self) -> None:
        """Reset magic circle state (e.g., after map change)."""
        self.placed_circles.clear()
        self.active_insignia = None
        self.insignia_expires_at = None
        self.log.debug("Magic circle state reset")