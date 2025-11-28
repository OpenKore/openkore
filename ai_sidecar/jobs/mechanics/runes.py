"""
Rune Manager - Rune Knight rune stone mechanics.

Manages rune stone inventory, usage cooldowns, and tactical rune selection
for swordsman branch Rune Knights.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class RuneType(str, Enum):
    """Types of rune stones available to Rune Knights."""

    # Offensive Runes
    RUNE_OF_STORM = "rune_of_storm"
    RUNE_OF_CRASH = "rune_of_crash"
    RUNE_OF_FIGHTING = "rune_of_fighting"
    
    # Defensive Runes
    RUNE_OF_REFRESH = "rune_of_refresh"
    RUNE_OF_BIRTH = "rune_of_birth"
    
    # Utility Runes
    RUNE_OF_DETECTION = "rune_of_detection"
    RUNE_OF_RELEASE = "rune_of_release"
    
    # Advanced Runes
    RUNE_OF_ABUNDANCE = "rune_of_abundance"
    RUNE_OF_MILLENNIUM = "rune_of_millennium"
    RUNE_OF_DESTRUCTION = "rune_of_destruction"
    RUNE_OF_LUX_ANIMA = "rune_of_lux_anima"
    RUNE_OF_TURISUS = "rune_of_turisus"
    RUNE_OF_ISA = "rune_of_isa"
    RUNE_OF_HAGALAZ = "rune_of_hagalaz"
    RUNE_OF_OTHILIA = "rune_of_othilia"
    RUNE_OF_URUZ = "rune_of_uruz"


class RuneStone(BaseModel):
    """A rune stone definition."""

    model_config = ConfigDict(frozen=True)

    rune_type: RuneType = Field(description="Type of rune stone")
    display_name: str = Field(description="Display name")
    skill_id: int = Field(description="Skill ID")
    cooldown_seconds: int = Field(ge=0, description="Cooldown duration")
    duration_seconds: int = Field(ge=0, description="Effect duration")
    sp_cost: int = Field(ge=0, description="SP consumption")
    rune_points_cost: int = Field(ge=1, description="Rune points needed")
    effect_type: str = Field(description="Type of effect")
    is_aoe: bool = Field(default=False, description="Area of effect")


class RuneCooldown(BaseModel):
    """Tracks rune cooldown."""

    model_config = ConfigDict(frozen=False)

    rune_type: RuneType = Field(description="Rune on cooldown")
    used_at: datetime = Field(default_factory=datetime.now)
    cooldown_seconds: int = Field(ge=0, description="Cooldown duration")

    @property
    def is_ready(self) -> bool:
        """Check if cooldown has expired."""
        ready_at = self.used_at + timedelta(seconds=self.cooldown_seconds)
        return datetime.now() >= ready_at

    @property
    def time_remaining(self) -> float:
        """Get remaining cooldown time in seconds."""
        ready_at = self.used_at + timedelta(seconds=self.cooldown_seconds)
        remaining = (ready_at - datetime.now()).total_seconds()
        return max(0, remaining)


class RuneManager:
    """
    Manage Rune Knight rune stones.

    Mechanics:
    - Limited rune stone inventory
    - Cooldowns per rune type
    - Rune point resource management
    - Tactical rune selection
    """

    def __init__(self, data_dir: Path | None = None) -> None:
        """
        Initialize rune manager.

        Args:
            data_dir: Optional data directory for rune definitions
        """
        self.log = structlog.get_logger()

        # State
        self.rune_inventory: dict[RuneType, int] = {}
        self.rune_cooldowns: dict[RuneType, RuneCooldown] = {}
        self.current_rune_points: int = 0
        self.max_rune_points: int = 100

        # Definitions
        self.rune_stones: dict[RuneType, RuneStone] = {}

        if data_dir:
            self._load_rune_definitions(Path(data_dir))

    def _load_rune_definitions(self, data_dir: Path) -> None:
        """Load rune stone definitions from JSON."""
        rune_file = data_dir / "rune_stones.json"

        if not rune_file.exists():
            self.log.warning(
                "rune_stones.json not found",
                path=str(rune_file),
            )
            return

        try:
            with open(rune_file, encoding="utf-8") as f:
                data = json.load(f)

            runes_data = data.get("runes", {})
            for rune_name, rune_info in runes_data.items():
                try:
                    rune_type = RuneType(rune_name)
                    rune = RuneStone(
                        rune_type=rune_type,
                        display_name=rune_info.get("display_name", rune_name),
                        skill_id=rune_info.get("skill_id", 0),
                        cooldown_seconds=rune_info.get("cooldown_seconds", 60),
                        duration_seconds=rune_info.get("duration_seconds", 0),
                        sp_cost=rune_info.get("sp_cost", 0),
                        rune_points_cost=rune_info.get("rune_points_cost", 1),
                        effect_type=rune_info.get("effect_type", "unknown"),
                        is_aoe=rune_info.get("is_aoe", False),
                    )
                    self.rune_stones[rune_type] = rune
                except ValueError:
                    self.log.warning(f"Unknown rune type: {rune_name}")

            self.log.info(
                "Rune definitions loaded",
                rune_count=len(self.rune_stones),
            )

        except Exception as e:
            self.log.error(
                "Failed to load rune_stones.json",
                error=str(e),
            )

    def use_rune(self, rune_type: RuneType) -> bool:
        """
        Use a rune stone.

        Args:
            rune_type: Type of rune to use

        Returns:
            True if rune was used successfully
        """
        # Check if we have the rune
        if rune_type not in self.rune_inventory:
            self.log.warning(
                "Cannot use rune - not in inventory",
                rune=rune_type.value,
            )
            return False

        if self.rune_inventory[rune_type] <= 0:
            self.log.warning(
                "Cannot use rune - no stones left",
                rune=rune_type.value,
            )
            return False

        # Check cooldown
        if not self.is_rune_ready(rune_type):
            cooldown = self.rune_cooldowns[rune_type]
            self.log.warning(
                "Cannot use rune - on cooldown",
                rune=rune_type.value,
                time_remaining=cooldown.time_remaining,
            )
            return False

        # Get rune definition
        rune_def = self.rune_stones.get(rune_type)
        if not rune_def:
            self.log.error(f"No definition for rune: {rune_type}")
            return False

        # Check rune points
        if self.current_rune_points < rune_def.rune_points_cost:
            self.log.warning(
                "Cannot use rune - not enough rune points",
                rune=rune_type.value,
                required=rune_def.rune_points_cost,
                current=self.current_rune_points,
            )
            return False

        # Use rune
        self.rune_inventory[rune_type] -= 1
        self.current_rune_points -= rune_def.rune_points_cost

        # Set cooldown
        self.rune_cooldowns[rune_type] = RuneCooldown(
            rune_type=rune_type,
            cooldown_seconds=rune_def.cooldown_seconds,
        )

        self.log.info(
            "Rune used",
            rune=rune_type.value,
            remaining=self.rune_inventory[rune_type],
            rune_points=self.current_rune_points,
        )

        return True

    def add_rune_stones(self, rune_type: RuneType, count: int = 1) -> None:
        """
        Add rune stones to inventory.

        Args:
            rune_type: Type of rune
            count: Number of stones to add
        """
        if rune_type not in self.rune_inventory:
            self.rune_inventory[rune_type] = 0

        self.rune_inventory[rune_type] += count
        self.log.debug(
            "Rune stones added",
            rune=rune_type.value,
            added=count,
            total=self.rune_inventory[rune_type],
        )

    def get_rune_count(self, rune_type: RuneType) -> int:
        """
        Get number of rune stones in inventory.

        Args:
            rune_type: Type of rune

        Returns:
            Number of stones
        """
        return self.rune_inventory.get(rune_type, 0)

    def is_rune_ready(self, rune_type: RuneType) -> bool:
        """
        Check if rune is off cooldown.

        Args:
            rune_type: Type of rune

        Returns:
            True if rune is ready to use
        """
        if rune_type not in self.rune_cooldowns:
            return True

        cooldown = self.rune_cooldowns[rune_type]
        if cooldown.is_ready:
            # Clean up expired cooldown
            del self.rune_cooldowns[rune_type]
            return True

        return False

    def get_rune_cooldown(self, rune_type: RuneType) -> float:
        """
        Get remaining cooldown for rune.

        Args:
            rune_type: Type of rune

        Returns:
            Remaining cooldown in seconds (0 if ready)
        """
        if rune_type not in self.rune_cooldowns:
            return 0.0

        return self.rune_cooldowns[rune_type].time_remaining

    def add_rune_points(self, points: int) -> None:
        """
        Add rune points.

        Args:
            points: Points to add
        """
        self.current_rune_points = min(
            self.current_rune_points + points,
            self.max_rune_points
        )
        self.log.debug(
            "Rune points added",
            points=points,
            total=self.current_rune_points,
        )

    def consume_rune_points(self, points: int) -> bool:
        """
        Consume rune points.

        Args:
            points: Points to consume

        Returns:
            True if points were consumed
        """
        if self.current_rune_points < points:
            return False

        self.current_rune_points -= points
        return True

    def get_recommended_rune(self, situation: str) -> RuneType | None:
        """
        Get recommended rune for situation.

        Args:
            situation: Situation type (boss, farming, pvp, emergency)

        Returns:
            Recommended rune type
        """
        recommendations = {
            "boss": [
                RuneType.RUNE_OF_CRASH,
                RuneType.RUNE_OF_FIGHTING,
                RuneType.RUNE_OF_DESTRUCTION,
            ],
            "farming": [
                RuneType.RUNE_OF_STORM,
                RuneType.RUNE_OF_ABUNDANCE,
            ],
            "pvp": [
                RuneType.RUNE_OF_DETECTION,
                RuneType.RUNE_OF_ISA,
                RuneType.RUNE_OF_HAGALAZ,
            ],
            "emergency": [
                RuneType.RUNE_OF_BIRTH,
                RuneType.RUNE_OF_REFRESH,
            ],
        }

        candidates = recommendations.get(situation, [])

        # Find first available and ready rune
        for rune_type in candidates:
            if self.get_rune_count(rune_type) > 0 and self.is_rune_ready(rune_type):
                rune_def = self.rune_stones.get(rune_type)
                if rune_def and self.current_rune_points >= rune_def.rune_points_cost:
                    return rune_type

        return None

    def get_available_runes(self) -> list[RuneType]:
        """
        Get list of runes that can be used now.

        Returns:
            List of available rune types
        """
        available: list[RuneType] = []

        for rune_type, count in self.rune_inventory.items():
            if count <= 0:
                continue

            if not self.is_rune_ready(rune_type):
                continue

            rune_def = self.rune_stones.get(rune_type)
            if not rune_def:
                continue

            if self.current_rune_points < rune_def.rune_points_cost:
                continue

            available.append(rune_type)

        return available

    def get_status(self) -> dict[str, Any]:
        """Get rune manager status."""
        return {
            "rune_points": self.current_rune_points,
            "max_rune_points": self.max_rune_points,
            "rune_inventory": {
                rune_type.value: count
                for rune_type, count in self.rune_inventory.items()
                if count > 0
            },
            "active_cooldowns": {
                rune_type.value: cooldown.time_remaining
                for rune_type, cooldown in self.rune_cooldowns.items()
                if not cooldown.is_ready
            },
            "available_runes": [
                rune.value for rune in self.get_available_runes()
            ],
        }

    def reset(self) -> None:
        """Reset rune state (e.g., after death)."""
        self.rune_cooldowns.clear()
        self.current_rune_points = 0
        self.log.debug("Rune state reset")