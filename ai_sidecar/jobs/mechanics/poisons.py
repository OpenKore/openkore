"""
Poison Manager - Assassin/Assassin Cross/Guillotine Cross poison mechanics.

Manages poison creation, weapon coating, and effect tracking for thief branch poison users.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class PoisonType(str, Enum):
    """Types of poisons available to assassins."""

    # Basic poisons
    POISON = "poison"
    VENOM_DUST = "venom_dust"
    
    # Assassin Cross poisons
    ENCHANT_DEADLY_POISON = "enchant_deadly_poison"
    VENOM_SPLASHER = "venom_splasher"
    
    # Guillotine Cross poisons
    POISON_SMOKE = "poison_smoke"
    VENOM_KNIFE = "venom_knife"
    WEAPON_BLOCKING = "weapon_blocking"
    BLOOD_SUCKER = "blood_sucker"
    
    # Poison bottles
    PARALYZE = "paralyze"
    PYREXIA = "pyrexia"
    TOXIN = "toxin"
    LEECH_END = "leech_end"
    OBLIVION_CURSE = "oblivion_curse"
    DEATH_HURT = "death_hurt"
    DISHEART = "disheart"


class PoisonEffect(BaseModel):
    """A poison effect definition."""

    model_config = ConfigDict(frozen=True)

    poison_type: PoisonType = Field(description="Type of poison")
    display_name: str = Field(description="Display name")
    damage_per_second: int = Field(ge=0, description="Damage over time")
    duration_seconds: int = Field(ge=0, description="Effect duration")
    additional_effects: list[str] = Field(
        default_factory=list, description="Status effects"
    )
    success_rate: int = Field(ge=0, le=100, description="Application chance")


class WeaponCoating(BaseModel):
    """Tracks weapon poison coating."""

    model_config = ConfigDict(frozen=False)

    poison_type: PoisonType = Field(description="Poison on weapon")
    applied_at: datetime = Field(default_factory=datetime.now)
    duration_seconds: int = Field(ge=1, description="Coating duration")
    charges: int = Field(ge=0, description="Remaining charges")

    @property
    def is_expired(self) -> bool:
        """Check if coating has expired."""
        expiry = self.applied_at + timedelta(seconds=self.duration_seconds)
        return datetime.now() >= expiry or self.charges <= 0


class PoisonManager:
    """
    Manage Assassin/Assassin Cross/Guillotine Cross poisons.

    Mechanics:
    - Weapon coating with poison
    - Multiple poison types with different effects
    - Poison crafting and bottle management
    - EDP (Enchant Deadly Poison) special mechanics
    """

    def __init__(self, data_dir: Path | None = None) -> None:
        """
        Initialize poison manager.

        Args:
            data_dir: Optional data directory for poison definitions
        """
        self.log = structlog.get_logger()

        # State
        self.current_coating: WeaponCoating | None = None
        self.poison_bottles: dict[PoisonType, int] = {}
        self.edp_active: bool = False
        self.edp_expires_at: datetime | None = None

        # Definitions
        self.poison_effects: dict[PoisonType, PoisonEffect] = {}

        if data_dir:
            self._load_poison_effects(Path(data_dir))

    def _load_poison_effects(self, data_dir: Path) -> None:
        """Load poison effect definitions from JSON."""
        poison_file = data_dir / "poison_effects.json"

        if not poison_file.exists():
            self.log.warning(
                "poison_effects.json not found",
                path=str(poison_file),
            )
            return

        try:
            with open(poison_file, encoding="utf-8") as f:
                data = json.load(f)

            poisons_data = data.get("poisons", {})
            for poison_name, poison_info in poisons_data.items():
                try:
                    poison_type = PoisonType(poison_name)
                    effect = PoisonEffect(
                        poison_type=poison_type,
                        display_name=poison_info.get("display_name", poison_name),
                        damage_per_second=poison_info.get("damage_per_second", 0),
                        duration_seconds=poison_info.get("duration_seconds", 0),
                        additional_effects=poison_info.get(
                            "additional_effects", []
                        ),
                        success_rate=poison_info.get("success_rate", 100),
                    )
                    self.poison_effects[poison_type] = effect
                except ValueError:
                    self.log.warning(f"Unknown poison type: {poison_name}")

            self.log.info(
                "Poison effects loaded",
                poison_count=len(self.poison_effects),
            )

        except Exception as e:
            self.log.error(
                "Failed to load poison_effects.json",
                error=str(e),
            )

    def apply_coating(
        self, poison_type: PoisonType, duration: int = 60, charges: int = 30
    ) -> bool:
        """
        Apply poison coating to weapon.

        Args:
            poison_type: Type of poison to apply
            duration: Coating duration in seconds
            charges: Number of attack charges

        Returns:
            True if coating was applied successfully
        """
        # Check if we have the poison
        if poison_type not in self.poison_bottles:
            self.log.warning(
                "Cannot apply poison - not in inventory",
                poison=poison_type.value,
            )
            return False

        if self.poison_bottles[poison_type] <= 0:
            self.log.warning(
                "Cannot apply poison - no bottles left",
                poison=poison_type.value,
            )
            return False

        # Remove old coating
        if self.current_coating:
            self.log.debug(
                "Replacing existing coating",
                old=self.current_coating.poison_type.value,
            )

        # Apply new coating
        self.current_coating = WeaponCoating(
            poison_type=poison_type,
            duration_seconds=duration,
            charges=charges,
        )

        # Consume one bottle
        self.poison_bottles[poison_type] -= 1

        self.log.info(
            "Poison coating applied",
            poison=poison_type.value,
            duration=duration,
            charges=charges,
        )

        return True

    def use_coating_charge(self) -> bool:
        """
        Use one charge of weapon coating.

        Returns:
            True if charge was used, False if no coating active
        """
        if not self.current_coating:
            return False

        if self.current_coating.is_expired:
            self.current_coating = None
            self.log.debug("Poison coating expired")
            return False

        self.current_coating.charges -= 1

        if self.current_coating.charges <= 0:
            self.log.debug("Poison coating depleted")
            self.current_coating = None

        return True

    def get_current_coating(self) -> PoisonType | None:
        """
        Get currently active poison coating.

        Returns:
            Poison type or None if no coating active
        """
        if not self.current_coating or self.current_coating.is_expired:
            self.current_coating = None
            return None

        return self.current_coating.poison_type

    def add_poison_bottles(self, poison_type: PoisonType, count: int = 1) -> None:
        """
        Add poison bottles to inventory.

        Args:
            poison_type: Type of poison
            count: Number of bottles to add
        """
        if poison_type not in self.poison_bottles:
            self.poison_bottles[poison_type] = 0

        self.poison_bottles[poison_type] += count
        self.log.debug(
            "Poison bottles added",
            poison=poison_type.value,
            added=count,
            total=self.poison_bottles[poison_type],
        )

    def get_poison_count(self, poison_type: PoisonType) -> int:
        """
        Get number of poison bottles in inventory.

        Args:
            poison_type: Type of poison

        Returns:
            Number of bottles
        """
        return self.poison_bottles.get(poison_type, 0)

    def activate_edp(self, duration: int = 40) -> None:
        """
        Activate Enchant Deadly Poison.

        Args:
            duration: EDP duration in seconds
        """
        self.edp_active = True
        self.edp_expires_at = datetime.now() + timedelta(seconds=duration)
        self.log.info("EDP activated", duration=duration)

    def deactivate_edp(self) -> None:
        """Deactivate Enchant Deadly Poison."""
        if self.edp_active:
            self.edp_active = False
            self.edp_expires_at = None
            self.log.info("EDP deactivated")

    def is_edp_active(self) -> bool:
        """
        Check if EDP is currently active.

        Returns:
            True if EDP is active
        """
        if not self.edp_active:
            return False

        if self.edp_expires_at and datetime.now() >= self.edp_expires_at:
            self.deactivate_edp()
            return False

        return True

    def get_poison_effect(self, poison_type: PoisonType) -> PoisonEffect | None:
        """
        Get effect definition for a poison type.

        Args:
            poison_type: Type of poison

        Returns:
            Poison effect or None
        """
        return self.poison_effects.get(poison_type)

    def should_reapply_coating(self, min_charges: int = 5) -> bool:
        """
        Determine if coating should be reapplied.

        Args:
            min_charges: Minimum charges before reapplying

        Returns:
            True if coating should be reapplied
        """
        if not self.current_coating:
            return True

        if self.current_coating.is_expired:
            return True

        return self.current_coating.charges < min_charges

    def get_recommended_poison(self, situation: str) -> PoisonType | None:
        """
        Get recommended poison for situation.

        Args:
            situation: Situation type (boss, farming, pvp)

        Returns:
            Recommended poison type
        """
        recommendations = {
            "boss": PoisonType.ENCHANT_DEADLY_POISON,
            "farming": PoisonType.TOXIN,
            "pvp": PoisonType.PARALYZE,
            "mvp": PoisonType.ENCHANT_DEADLY_POISON,
        }

        poison = recommendations.get(situation)
        
        # Check if we have the poison
        if poison and self.get_poison_count(poison) > 0:
            return poison

        # Fall back to any available poison
        for p_type, count in self.poison_bottles.items():
            if count > 0:
                return p_type

        return None

    def get_status(self) -> dict[str, Any]:
        """Get poison manager status."""
        status: dict[str, Any] = {
            "coating_active": self.current_coating is not None,
            "edp_active": self.is_edp_active(),
            "poison_inventory": {
                p_type.value: count
                for p_type, count in self.poison_bottles.items()
                if count > 0
            },
        }

        if self.current_coating and not self.current_coating.is_expired:
            time_left = (
                self.current_coating.applied_at
                + timedelta(seconds=self.current_coating.duration_seconds)
                - datetime.now()
            ).total_seconds()

            status["current_coating"] = {
                "poison": self.current_coating.poison_type.value,
                "charges": self.current_coating.charges,
                "time_left": max(0, time_left),
            }

        if self.edp_active and self.edp_expires_at:
            status["edp_time_left"] = max(
                0, (self.edp_expires_at - datetime.now()).total_seconds()
            )

        return status

    def reset(self) -> None:
        """Reset poison state (e.g., after death)."""
        self.current_coating = None
        self.edp_active = False
        self.edp_expires_at = None
        self.log.debug("Poison state reset")