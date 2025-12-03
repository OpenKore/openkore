"""
Doram Manager - Doram race-specific mechanics.

Manages spirit points, companion summoning, and unique Doram abilities.
Dorams are a unique race with cat-like features and specialized skill trees.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class DoramBranch(str, Enum):
    """Doram job specialization branches."""

    PHYSICAL = "physical"  # Physical Summoner
    SEA = "sea"  # Sea Summoner
    LAND = "land"  # Land Summoner


class SpiritType(str, Enum):
    """Types of spirits for Doram abilities."""

    CUTE_SPIRIT = "cute_spirit"
    MIGHTY_SPIRIT = "mighty_spirit"
    RAPID_SPIRIT = "rapid_spirit"
    ANCIENT_SPIRIT = "ancient_spirit"


class CompanionType(str, Enum):
    """Types of animal companions Dorams can summon."""

    CAT = "cat"
    DOG = "dog"
    BIRD = "bird"
    FISH = "fish"
    PLANT = "plant"


class ActiveCompanion(BaseModel):
    """A summoned companion."""

    model_config = ConfigDict(frozen=False)

    companion_type: CompanionType = Field(description="Type of companion")
    summoned_at: datetime = Field(default_factory=datetime.now)
    duration_seconds: int = Field(ge=1, description="Companion duration")
    hp: int = Field(ge=0, description="Companion HP")
    max_hp: int = Field(ge=1, description="Companion max HP")

    @property
    def is_expired(self) -> bool:
        """Check if companion has expired."""
        expiry = self.summoned_at + timedelta(seconds=self.duration_seconds)
        return datetime.now() >= expiry or self.hp <= 0


class DoramManager:
    """
    Manage Doram race-specific mechanics.

    Mechanics:
    - Spirit point system (replaces SP for some skills)
    - Animal companion summoning
    - Branch-specific abilities
    - Unique status effects
    """

    def __init__(self, data_dir: Path | None = None) -> None:
        """
        Initialize Doram manager.

        Args:
            data_dir: Optional data directory for ability definitions
        """
        self.log = structlog.get_logger()

        # State
        self.current_branch: DoramBranch | None = None
        self.spirit_points: int = 0
        self.max_spirit_points: int = 10
        self.active_companions: list[ActiveCompanion] = []
        self.max_companions: int = 1
        
        # Buffs
        self.active_spirits: set[SpiritType] = set()
        self.spirit_expires: dict[SpiritType, datetime] = {}

        # Definitions
        self.ability_costs: dict[str, int] = {}

        if data_dir:
            self._load_ability_definitions(Path(data_dir))

    def _load_ability_definitions(self, data_dir: Path) -> None:
        """Load Doram ability definitions from JSON."""
        # This would load from a doram_abilities.json file
        # For now, we'll define some basic costs
        self.ability_costs = {
            "picky_peck": 1,
            "lunatic_carrot_beat": 2,
            "savage_bebe_claw": 2,
            "chattering": 1,
            "hiss": 1,
            "purring": 2,
            "tuna_belly": 3,
            "tuna_party": 4,
            "fresh_shrimp": 2,
            "tasty_shrimp_party": 3,
        }
        self.log.info("Doram ability costs loaded", ability_count=len(self.ability_costs))

    def set_branch(self, branch: DoramBranch) -> None:
        """
        Set Doram specialization branch.

        Args:
            branch: Specialization branch
        """
        self.current_branch = branch
        self.log.info("Doram branch set", branch=branch.value)

    def get_spirit_points(self) -> int:
        """Get current spirit points."""
        return self.spirit_points

    def add_spirit_points(self, points: int) -> None:
        """
        Add spirit points.

        Args:
            points: Points to add
        """
        self.spirit_points = min(
            self.spirit_points + points,
            self.max_spirit_points
        )
        self.log.debug("Spirit points added", points=points, total=self.spirit_points)

    def consume_spirit_points(self, points: int) -> bool:
        """
        Consume spirit points for ability use.

        Args:
            points: Points to consume

        Returns:
            True if points were consumed
        """
        if self.spirit_points < points:
            self.log.warning(
                "Not enough spirit points",
                required=points,
                available=self.spirit_points
            )
            return False

        self.spirit_points -= points
        self.log.debug("Spirit points consumed", consumed=points, remaining=self.spirit_points)
        return True

    def can_use_ability(self, ability_name: str) -> tuple[bool, int]:
        """
        Check if ability can be used.

        Args:
            ability_name: Name of ability

        Returns:
            Tuple of (can_use, points_required)
        """
        cost = self.ability_costs.get(ability_name, 0)
        can_use = self.spirit_points >= cost
        return can_use, cost

    def summon_companion(
        self, companion_type: CompanionType, duration: int = 300
    ) -> bool:
        """
        Summon an animal companion.

        Args:
            companion_type: Type of companion to summon
            duration: Companion duration in seconds

        Returns:
            True if companion was summoned
        """
        # Clean up expired companions
        self.cleanup_expired_companions()

        # Check companion limit
        if len(self.active_companions) >= self.max_companions:
            self.log.warning("Maximum companion count reached", max=self.max_companions)
            return False

        # Create companion
        companion = ActiveCompanion(
            companion_type=companion_type,
            duration_seconds=duration,
            hp=1000,
            max_hp=1000,
        )

        self.active_companions.append(companion)
        self.log.info(
            "Companion summoned",
            type=companion_type.value,
            count=len(self.active_companions)
        )

        return True

    def cleanup_expired_companions(self) -> int:
        """
        Remove expired companions.

        Returns:
            Number of companions removed
        """
        initial_count = len(self.active_companions)
        self.active_companions = [c for c in self.active_companions if not c.is_expired]
        removed = initial_count - len(self.active_companions)

        if removed > 0:
            self.log.debug("Expired companions removed", removed=removed)

        return removed

    def get_active_companions(self) -> list[ActiveCompanion]:
        """
        Get list of active companions.

        Returns:
            List of active companions
        """
        self.cleanup_expired_companions()
        return self.active_companions.copy()

    def damage_companion(self, companion_type: CompanionType, damage: int) -> bool:
        """
        Apply damage to a companion.

        Args:
            companion_type: Type of companion
            damage: Damage amount

        Returns:
            True if companion was damaged
        """
        for companion in self.active_companions:
            if companion.companion_type == companion_type:
                companion.hp = max(0, companion.hp - damage)
                
                if companion.hp <= 0:
                    self.log.info("Companion defeated", type=companion_type.value)
                else:
                    self.log.debug(
                        "Companion damaged",
                        type=companion_type.value,
                        hp=companion.hp,
                        max_hp=companion.max_hp
                    )
                
                return True

        return False

    def activate_spirit(self, spirit_type: SpiritType, duration: int = 180) -> None:
        """
        Activate a spirit buff.

        Args:
            spirit_type: Type of spirit to activate
            duration: Buff duration in seconds
        """
        self.active_spirits.add(spirit_type)
        self.spirit_expires[spirit_type] = datetime.now() + timedelta(seconds=duration)
        self.log.info("Spirit activated", spirit=spirit_type.value, duration=duration)

    def is_spirit_active(self, spirit_type: SpiritType) -> bool:
        """
        Check if a spirit buff is active.

        Args:
            spirit_type: Spirit type to check

        Returns:
            True if spirit is active
        """
        if spirit_type not in self.active_spirits:
            return False

        expires_at = self.spirit_expires.get(spirit_type)
        if not expires_at or datetime.now() >= expires_at:
            self.active_spirits.discard(spirit_type)
            self.spirit_expires.pop(spirit_type, None)
            return False

        return True

    def get_active_spirits(self) -> list[SpiritType]:
        """
        Get list of active spirit buffs.

        Returns:
            List of active spirits
        """
        # Clean up expired spirits
        active = []
        for spirit in list(self.active_spirits):
            if self.is_spirit_active(spirit):
                active.append(spirit)

        return active

    def get_branch_bonus(self, skill_type: str) -> float:
        """
        Get damage bonus based on branch specialization.

        Args:
            skill_type: Type of skill (physical, sea, land)

        Returns:
            Damage multiplier
        """
        if not self.current_branch:
            return 1.0

        # Branch-specific bonuses
        bonuses = {
            DoramBranch.PHYSICAL: {"physical": 1.3},
            DoramBranch.SEA: {"sea": 1.3, "water": 1.2},
            DoramBranch.LAND: {"land": 1.3, "earth": 1.2},
        }

        branch_bonuses = bonuses.get(self.current_branch, {})
        return branch_bonuses.get(skill_type.lower(), 1.0)

    def should_generate_spirit_points(self, min_threshold: int = 5) -> bool:
        """
        Determine if spirit points should be generated.

        Args:
            min_threshold: Minimum points before generating

        Returns:
            True if should generate points
        """
        return self.spirit_points < min_threshold

    def get_recommended_ability(self, situation: str) -> str | None:
        """
        Get recommended ability for situation.

        Args:
            situation: Situation type (boss, farming, pvp)

        Returns:
            Recommended ability name
        """
        if not self.current_branch:
            return None

        recommendations = {
            DoramBranch.PHYSICAL: {
                "boss": "savage_bebe_claw",
                "farming": "picky_peck",
                "pvp": "savage_bebe_claw",
            },
            DoramBranch.SEA: {
                "boss": "tuna_party",
                "farming": "fresh_shrimp",
                "pvp": "tasty_shrimp_party",
            },
            DoramBranch.LAND: {
                "boss": "lunatic_carrot_beat",
                "farming": "chattering",
                "pvp": "lunatic_carrot_beat",
            },
        }

        branch_recs = recommendations.get(self.current_branch, {})
        ability = branch_recs.get(situation)

        # Check if we have enough spirit points
        if ability:
            can_use, _ = self.can_use_ability(ability)
            if can_use:
                return ability

        return None

    def get_status(self) -> dict[str, Any]:
        """Get Doram manager status."""
        self.cleanup_expired_companions()

        return {
            "branch": self.current_branch.value if self.current_branch else None,
            "spirit_points": self.spirit_points,
            "max_spirit_points": self.max_spirit_points,
            "active_companions": [
                {
                    "type": c.companion_type.value,
                    "hp": c.hp,
                    "max_hp": c.max_hp,
                    "expires_in": (
                        c.summoned_at + timedelta(seconds=c.duration_seconds) - datetime.now()
                    ).total_seconds(),
                }
                for c in self.active_companions
            ],
            "active_spirits": [s.value for s in self.get_active_spirits()],
            "spirit_time_remaining": {
                spirit.value: max(0, (expires_at - datetime.now()).total_seconds())
                for spirit, expires_at in self.spirit_expires.items()
                if spirit in self.active_spirits
            },
        }

    def reset(self) -> None:
        """Reset Doram state (e.g., after death)."""
        self.spirit_points = 0
        self.active_companions.clear()
        self.active_spirits.clear()
        self.spirit_expires.clear()
        self.log.debug("Doram state reset")

    def deactivate_spirit(self, spirit_type: SpiritType) -> None:
        """
        Deactivate a specific spirit buff.
        
        Args:
            spirit_type: Spirit type to deactivate
        """
        if spirit_type in self.active_spirits:
            self.active_spirits.discard(spirit_type)
            self.spirit_expires.pop(spirit_type, None)
            self.log.info("Spirit deactivated", spirit=spirit_type.value)
        else:
            self.log.debug("Spirit not active", spirit=spirit_type.value)