"""
Skill Rotation Engine - Manages optimal skill rotations for job classes.

Provides priority-based skill selection, condition evaluation, combo tracking,
and cooldown management for combat rotations.
"""

import json
import time
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class SkillPriority(str, Enum):
    """Skill priority levels for rotation ordering."""

    CRITICAL = "critical"  # Use immediately (emergency heals, etc)
    HIGH = "high"  # Use when available
    MEDIUM = "medium"  # Use after high priority
    LOW = "low"  # Use as filler
    MAINTENANCE = "maintenance"  # Periodic refresh (buffs)


class SkillCondition(BaseModel):
    """
    Conditions for using a skill.

    All conditions must be met for skill to be eligible.
    """

    model_config = ConfigDict(frozen=True)

    # HP/SP conditions
    min_hp_percent: float | None = Field(default=None, ge=0, le=100)
    max_hp_percent: float | None = Field(default=None, ge=0, le=100)
    min_sp_percent: float | None = Field(default=None, ge=0, le=100)

    # Target conditions
    target_hp_percent: float | None = Field(default=None, ge=0, le=100)
    target_count: int | None = Field(default=None, ge=1)

    # Buff conditions
    has_buff: str | None = Field(default=None, description="Required buff")
    missing_buff: str | None = Field(
        default=None, description="Buff that should be missing"
    )

    # Combo conditions
    combo_after: str | None = Field(
        default=None, description="Previous skill required"
    )

    # Special mechanics
    spirit_spheres: int | None = Field(
        default=None, ge=0, le=15, description="Required spirit spheres"
    )
    min_targets_in_range: int | None = Field(
        default=None, ge=1, description="Minimum enemies in AoE range"
    )


class SkillRotationStep(BaseModel):
    """Single step in skill rotation."""

    model_config = ConfigDict(frozen=True)

    skill_name: str = Field(description="Skill name")
    priority: SkillPriority = Field(description="Skill priority level")
    conditions: SkillCondition | None = Field(
        default=None, description="Conditions for skill use"
    )
    cast_time_ms: int = Field(default=0, ge=0, description="Cast time in ms")
    after_cast_delay_ms: int = Field(default=0, ge=0, description="After cast delay")
    cooldown_ms: int = Field(default=0, ge=0, description="Cooldown in ms")
    comment: str = Field(default="", description="Description/notes")


class SkillRotation(BaseModel):
    """Complete skill rotation for a job."""

    model_config = ConfigDict(frozen=True)

    job_name: str = Field(description="Job name")
    rotation_type: str = Field(
        description="Rotation type (farming, boss, pvp, support)"
    )
    steps: list[SkillRotationStep] = Field(
        default_factory=list, description="Rotation steps"
    )
    opener: list[str] = Field(
        default_factory=list, description="Opening sequence"
    )
    finisher: list[str] = Field(
        default_factory=list, description="Finishing sequence"
    )
    emergency: list[str] = Field(
        default_factory=list, description="Emergency skills"
    )


class SkillRotationEngine:
    """
    Manage optimal skill rotations for each job class.

    Features:
    - Job-specific rotations
    - Situation-aware rotation selection
    - Combo skill tracking
    - Cooldown management
    - Priority-based skill selection
    """

    def __init__(self, data_dir: Path) -> None:
        """
        Initialize skill rotation engine.

        Args:
            data_dir: Directory containing skill_rotations.json
        """
        self.log = structlog.get_logger()
        self.data_dir = Path(data_dir)

        # Rotations by job name -> rotation type -> rotation
        self.rotations: dict[str, dict[str, SkillRotation]] = {}

        # Active state tracking
        self.active_cooldowns: dict[str, float] = {}
        self.combo_state: dict[str, str] = {}  # job_name -> last_skill
        self.last_skill_time: float = 0.0

        self._load_rotations()

    def _load_rotations(self) -> None:
        """Load all skill rotations from JSON."""
        rotation_file = self.data_dir / "skill_rotations.json"

        if not rotation_file.exists():
            self.log.warning(
                "skill_rotations.json not found",
                path=str(rotation_file),
            )
            return

        try:
            with open(rotation_file, encoding="utf-8") as f:
                data = json.load(f)

            rotations_data = data.get("rotations", {})

            for job_name, job_rotations in rotations_data.items():
                self.rotations[job_name] = {}

                for rotation_type, rotation_dict in job_rotations.items():
                    # Add job_name and rotation_type to dict
                    rotation_dict["job_name"] = job_name
                    rotation_dict["rotation_type"] = rotation_type

                    try:
                        rotation = SkillRotation.model_validate(rotation_dict)
                        self.rotations[job_name][rotation_type] = rotation
                    except Exception as e:
                        self.log.error(
                            "Failed to load rotation",
                            job=job_name,
                            type=rotation_type,
                            error=str(e),
                        )

            self.log.info(
                "Skill rotations loaded",
                job_count=len(self.rotations),
            )

        except Exception as e:
            self.log.error(
                "Failed to load skill_rotations.json",
                error=str(e),
                path=str(rotation_file),
            )

    def get_next_skill(
        self,
        job_name: str,
        rotation_type: str,
        character_state: dict[str, Any],
        target_state: dict[str, Any] | None = None,
    ) -> SkillRotationStep | None:
        """
        Get next skill to use based on rotation and current state.

        Considers:
        - Cooldowns
        - Conditions
        - Combo chains
        - Resource availability
        - Priority

        Args:
            job_name: Current job name
            rotation_type: Type of rotation (farming, boss, etc)
            character_state: Character state dict
            target_state: Optional target state dict

        Returns:
            Next skill to use or None
        """
        rotation = self.get_rotation_for_situation(job_name, rotation_type)
        if not rotation:
            return None

        current_time = time.time()

        # Check combo state first
        last_skill = self.combo_state.get(job_name)

        # Filter eligible skills by priority order
        priority_order = [
            SkillPriority.CRITICAL,
            SkillPriority.HIGH,
            SkillPriority.MEDIUM,
            SkillPriority.LOW,
            SkillPriority.MAINTENANCE,
        ]

        for priority in priority_order:
            eligible = self._get_eligible_skills_by_priority(
                rotation.steps,
                priority,
                character_state,
                target_state,
                last_skill,
                current_time,
            )

            if eligible:
                # Return highest priority eligible skill
                return eligible[0]

        return None

    def _get_eligible_skills_by_priority(
        self,
        steps: list[SkillRotationStep],
        priority: SkillPriority,
        character_state: dict[str, Any],
        target_state: dict[str, Any] | None,
        last_skill: str | None,
        current_time: float,
    ) -> list[SkillRotationStep]:
        """Get eligible skills for a specific priority level."""
        eligible: list[SkillRotationStep] = []

        for step in steps:
            if step.priority != priority:
                continue

            # Check cooldown
            if not self._is_skill_ready(step.skill_name, current_time):
                continue

            # Check conditions
            if step.conditions:
                if not self.evaluate_condition(
                    step.conditions, character_state, target_state, last_skill
                ):
                    continue

            eligible.append(step)

        return eligible

    def _is_skill_ready(self, skill_name: str, current_time: float) -> bool:
        """Check if skill is off cooldown."""
        if skill_name not in self.active_cooldowns:
            return True

        return current_time >= self.active_cooldowns[skill_name]

    def evaluate_condition(
        self,
        condition: SkillCondition,
        character_state: dict[str, Any],
        target_state: dict[str, Any] | None,
        last_skill: str | None = None,
    ) -> bool:
        """
        Check if skill conditions are met.

        Args:
            condition: Skill condition to evaluate
            character_state: Character state
            target_state: Target state
            last_skill: Last skill used

        Returns:
            True if all conditions are met
        """
        # HP conditions
        if condition.min_hp_percent is not None:
            hp_pct = character_state.get("hp_percent", 100)
            if hp_pct < condition.min_hp_percent:
                return False

        if condition.max_hp_percent is not None:
            hp_pct = character_state.get("hp_percent", 100)
            if hp_pct > condition.max_hp_percent:
                return False

        # SP conditions
        if condition.min_sp_percent is not None:
            sp_pct = character_state.get("sp_percent", 100)
            if sp_pct < condition.min_sp_percent:
                return False

        # Target HP condition
        if condition.target_hp_percent is not None:
            if not target_state:
                return False
            target_hp = target_state.get("hp_percent", 100)
            if target_hp > condition.target_hp_percent:
                return False

        # Target count condition
        if condition.target_count is not None:
            targets = character_state.get("targets_in_range", 0)
            if targets < condition.target_count:
                return False

        # Buff conditions
        if condition.has_buff:
            buffs = character_state.get("buffs", [])
            if condition.has_buff not in buffs:
                return False

        if condition.missing_buff:
            buffs = character_state.get("buffs", [])
            if condition.missing_buff in buffs:
                return False

        # Combo condition
        if condition.combo_after:
            if last_skill != condition.combo_after:
                return False

        # Spirit spheres
        if condition.spirit_spheres is not None:
            spheres = character_state.get("spirit_spheres", 0)
            if spheres < condition.spirit_spheres:
                return False

        # Min targets in range
        if condition.min_targets_in_range is not None:
            targets = character_state.get("targets_in_range", 0)
            if targets < condition.min_targets_in_range:
                return False

        return True

    def track_skill_usage(
        self, job_name: str, skill_name: str, cooldown_ms: int = 0
    ) -> None:
        """
        Record skill usage for cooldown and combo tracking.

        Args:
            job_name: Current job name
            skill_name: Skill that was used
            cooldown_ms: Cooldown duration in milliseconds
        """
        current_time = time.time()

        # Track cooldown
        if cooldown_ms > 0:
            cooldown_seconds = cooldown_ms / 1000.0
            self.active_cooldowns[skill_name] = current_time + cooldown_seconds

        # Track combo state
        self.combo_state[job_name] = skill_name
        self.last_skill_time = current_time

        self.log.debug(
            "Skill used",
            job=job_name,
            skill=skill_name,
            cooldown_ms=cooldown_ms,
        )

    def get_rotation_for_situation(
        self, job_name: str, situation: str
    ) -> SkillRotation | None:
        """
        Get appropriate rotation for current situation.

        Args:
            job_name: Job name
            situation: Situation type (farming, boss, pvp, support)

        Returns:
            Skill rotation or None if not found
        """
        job_rotations = self.rotations.get(job_name.lower())
        if not job_rotations:
            return None

        return job_rotations.get(situation)

    def get_opener_sequence(
        self, job_name: str, situation: str
    ) -> list[str]:
        """
        Get opening skill sequence.

        Args:
            job_name: Job name
            situation: Situation type

        Returns:
            List of skill names for opening sequence
        """
        rotation = self.get_rotation_for_situation(job_name, situation)
        return rotation.opener if rotation else []

    def get_emergency_skills(
        self, job_name: str, situation: str
    ) -> list[str]:
        """
        Get emergency skill list.

        Args:
            job_name: Job name
            situation: Situation type

        Returns:
            List of emergency skill names
        """
        rotation = self.get_rotation_for_situation(job_name, situation)
        return rotation.emergency if rotation else []

    def reset_combo_state(self, job_name: str | None = None) -> None:
        """
        Reset combo tracking (after target switch, etc).

        Args:
            job_name: Specific job to reset, or None for all
        """
        if job_name:
            self.combo_state.pop(job_name, None)
        else:
            self.combo_state.clear()

    def clear_cooldowns(self) -> None:
        """Clear all active cooldowns."""
        self.active_cooldowns.clear()

    def get_active_cooldowns(self) -> dict[str, float]:
        """Get dict of skills on cooldown and when they'll be ready."""
        current_time = time.time()
        return {
            skill: remaining
            for skill, ready_time in self.active_cooldowns.items()
            if (remaining := ready_time - current_time) > 0
        }