"""
Job Class Registry - Central registry for all RO job class definitions.

Loads job class definitions from JSON configuration files and provides
query methods for job lookup, evolution paths, and skill inheritance.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class JobBranch(str, Enum):
    """Job class branches in Ragnarok Online."""

    SWORDMAN = "swordman"
    MAGE = "mage"
    ARCHER = "archer"
    THIEF = "thief"
    MERCHANT = "merchant"
    ACOLYTE = "acolyte"
    TAEKWON = "taekwon"
    GUNSLINGER = "gunslinger"
    NINJA = "ninja"
    DORAM = "doram"


class JobTier(str, Enum):
    """Job class tiers/advancement stages."""

    NOVICE = "novice"
    FIRST = "first"
    SECOND = "second"
    TRANSCENDENT = "transcendent"
    THIRD = "third"
    FOURTH = "fourth"
    EXTENDED = "extended"


class CombatRole(str, Enum):
    """Primary combat role classifications."""

    TANK = "tank"
    MELEE_DPS = "melee_dps"
    RANGED_DPS = "ranged_dps"
    MAGIC_DPS = "magic_dps"
    HEALER = "healer"
    SUPPORT = "support"
    HYBRID = "hybrid"


class PositioningStyle(str, Enum):
    """Preferred positioning in combat."""

    MELEE = "melee"  # Close range (1 cell)
    SHORT_RANGE = "short"  # 2-4 cells
    MID_RANGE = "mid"  # 5-9 cells
    LONG_RANGE = "long"  # 10+ cells
    MOBILE = "mobile"  # Constant movement
    STATIONARY = "stationary"  # Plant and cast


class JobClass(BaseModel):
    """
    Complete job class definition.

    Includes classification, stats, skills, equipment preferences,
    and special mechanics flags.
    """

    model_config = ConfigDict(frozen=True)

    # Identity
    job_id: int = Field(description="Job class ID from RO")
    name: str = Field(description="Internal job name (lowercase)")
    display_name: str = Field(description="Display name")

    # Classification
    branch: JobBranch | None = Field(default=None, description="Job branch")
    tier: JobTier = Field(description="Job tier")
    primary_role: CombatRole = Field(description="Primary combat role")
    secondary_roles: list[CombatRole] = Field(
        default_factory=list, description="Secondary roles"
    )
    positioning: PositioningStyle = Field(description="Preferred positioning")

    # Stats
    recommended_stats: dict[str, int] = Field(
        default_factory=dict, description="Recommended stat allocations"
    )
    stat_weights: dict[str, float] = Field(
        default_factory=dict, description="Stat priority weights for auto-allocation"
    )

    # Skills
    key_skills: list[str] = Field(
        default_factory=list, description="Most important skills for this job"
    )
    passive_skills: list[str] = Field(
        default_factory=list, description="Always-on passives to track"
    )
    buff_skills: list[str] = Field(
        default_factory=list, description="Self-buffs to maintain"
    )

    # Equipment
    weapon_types: list[str] = Field(
        default_factory=list, description="Usable weapon types"
    )
    preferred_weapon: str = Field(default="", description="Optimal weapon type")
    armor_type: str = Field(default="light", description="Heavy/Light/Robe")

    # Special mechanics flags
    has_spirit_spheres: bool = Field(
        default=False, description="Uses spirit sphere system"
    )
    has_ammo: bool = Field(default=False, description="Requires ammunition")
    has_songs: bool = Field(default=False, description="Uses songs/dances")
    has_traps: bool = Field(default=False, description="Can place traps")
    has_poisons: bool = Field(default=False, description="Uses poison system")
    has_runes: bool = Field(default=False, description="Uses rune stones")
    has_magic_circles: bool = Field(
        default=False, description="Uses magic circles"
    )
    has_summons: bool = Field(default=False, description="Can summon entities")
    has_combo_skills: bool = Field(
        default=False, description="Has combo skill chains"
    )

    # Upgrade paths
    evolves_to: list[str] = Field(
        default_factory=list, description="Job classes this can advance to"
    )
    evolves_from: str | None = Field(
        default=None, description="Previous job class"
    )


class JobClassRegistry:
    """
    Central registry for all job class definitions.

    Loads from JSON configuration files and provides query methods
    for job lookup, evolution paths, and skill inheritance.
    """

    def __init__(self, data_dir: Path) -> None:
        """
        Initialize job class registry.

        Args:
            data_dir: Directory containing job_classes.json
        """
        self.log = structlog.get_logger()
        self.data_dir = Path(data_dir)
        self.jobs: dict[int, JobClass] = {}
        self.jobs_by_name: dict[str, JobClass] = {}
        self._load_job_definitions()

    def _load_job_definitions(self) -> None:
        """Load all job class definitions from JSON."""
        job_file = self.data_dir / "job_classes.json"

        if not job_file.exists():
            self.log.warning(
                "job_classes.json not found, registry will be empty",
                path=str(job_file),
            )
            return

        try:
            with open(job_file, encoding="utf-8") as f:
                data = json.load(f)

            jobs_data = data.get("jobs", [])
            for job_dict in jobs_data:
                try:
                    job = JobClass.model_validate(job_dict)
                    self.jobs[job.job_id] = job
                    self.jobs_by_name[job.name] = job
                except Exception as e:
                    self.log.error(
                        "Failed to load job definition",
                        job_name=job_dict.get("name", "unknown"),
                        error=str(e),
                    )

            self.log.info("Job class registry loaded", job_count=len(self.jobs))

        except Exception as e:
            self.log.error(
                "Failed to load job_classes.json",
                error=str(e),
                path=str(job_file),
            )

    def get_job(self, job_id: int) -> JobClass | None:
        """
        Get job class by ID.

        Args:
            job_id: Job class ID

        Returns:
            JobClass if found, None otherwise
        """
        return self.jobs.get(job_id)

    def get_job_by_name(self, name: str) -> JobClass | None:
        """
        Get job class by name.

        Args:
            name: Job name (case-insensitive)

        Returns:
            JobClass if found, None otherwise
        """
        return self.jobs_by_name.get(name.lower())

    def get_jobs_by_branch(self, branch: JobBranch) -> list[JobClass]:
        """
        Get all jobs in a branch.

        Args:
            branch: Job branch to filter by

        Returns:
            List of job classes in the branch
        """
        return [job for job in self.jobs.values() if job.branch == branch]

    def get_jobs_by_tier(self, tier: JobTier) -> list[JobClass]:
        """
        Get all jobs of a specific tier.

        Args:
            tier: Job tier to filter by

        Returns:
            List of job classes of that tier
        """
        return [job for job in self.jobs.values() if job.tier == tier]

    def get_jobs_by_role(self, role: CombatRole) -> list[JobClass]:
        """
        Get all jobs with a specific role.

        Args:
            role: Combat role to filter by

        Returns:
            List of job classes with that role (primary or secondary)
        """
        return [
            job
            for job in self.jobs.values()
            if job.primary_role == role or role in job.secondary_roles
        ]

    def get_evolution_path(self, job_name: str) -> list[str]:
        """
        Get full evolution path for a job (from Novice to current).

        Args:
            job_name: Job name to get path for

        Returns:
            List of job names in evolution order
        """
        job = self.get_job_by_name(job_name)
        if not job:
            return []

        path: list[str] = [job.name]

        # Traverse backwards to novice
        current = job
        while current.evolves_from:
            parent = self.get_job_by_name(current.evolves_from)
            if not parent:
                break
            path.insert(0, parent.name)
            current = parent

        return path

    def get_all_skills_for_job(self, job_name: str) -> set[str]:
        """
        Get all skills available to a job (including inherited from previous jobs).

        Args:
            job_name: Job name

        Returns:
            Set of all skill names available to this job
        """
        evolution_path = self.get_evolution_path(job_name)
        all_skills: set[str] = set()

        for job_path_name in evolution_path:
            job = self.get_job_by_name(job_path_name)
            if job:
                all_skills.update(job.key_skills)
                all_skills.update(job.passive_skills)
                all_skills.update(job.buff_skills)

        return all_skills

    def get_job_count(self) -> int:
        """Get total number of registered job classes."""
        return len(self.jobs)

    def list_all_jobs(self) -> list[str]:
        """
        Get list of all job names.

        Returns:
            Sorted list of job names
        """
        return sorted(self.jobs_by_name.keys())

    def get_jobs_with_special_mechanics(self, mechanic: str) -> list[JobClass]:
        """
        Get jobs that use a specific special mechanic.

        Args:
            mechanic: Mechanic name (e.g., 'spirit_spheres', 'traps')

        Returns:
            List of job classes with that mechanic
        """
        attr_name = f"has_{mechanic}"
        return [
            job
            for job in self.jobs.values()
            if getattr(job, attr_name, False)
        ]

    def validate_job_id(self, job_id: int) -> bool:
        """
        Check if a job ID is valid.

        Args:
            job_id: Job ID to validate

        Returns:
            True if job ID exists in registry
        """
        return job_id in self.jobs