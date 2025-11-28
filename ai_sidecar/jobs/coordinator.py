"""
Job AI Coordinator - Main coordinator for job-specific AI behaviors.

Integrates all job mechanics managers and provides unified interface for
job-specific decision making and action execution.
"""

from pathlib import Path
from typing import Any

import structlog

from ai_sidecar.jobs.mechanics.doram import DoramManager
from ai_sidecar.jobs.mechanics.magic_circles import MagicCircleManager
from ai_sidecar.jobs.mechanics.poisons import PoisonManager
from ai_sidecar.jobs.mechanics.runes import RuneManager
from ai_sidecar.jobs.mechanics.spirit_spheres import SpiritSphereManager
from ai_sidecar.jobs.mechanics.traps import TrapManager
from ai_sidecar.jobs.registry import JobClass, JobClassRegistry
from ai_sidecar.jobs.rotations import SkillRotationEngine

logger = structlog.get_logger(__name__)


class JobAICoordinator:
    """
    Main coordinator for job-specific AI behaviors.

    Manages all job mechanics and provides unified interface for:
    - Job-specific skill rotations
    - Special mechanics (spheres, traps, poisons, etc.)
    - Tactical decision making
    - State management
    """

    def __init__(self, data_dir: Path) -> None:
        """
        Initialize job AI coordinator.

        Args:
            data_dir: Directory containing job data files
        """
        self.log = structlog.get_logger()
        self.data_dir = Path(data_dir)

        # Core systems
        self.job_registry = JobClassRegistry(self.data_dir)
        self.rotation_engine = SkillRotationEngine(self.data_dir)

        # Special mechanics managers
        self.spirit_sphere_mgr = SpiritSphereManager(self.data_dir)
        self.trap_mgr = TrapManager(self.data_dir)
        self.poison_mgr = PoisonManager(self.data_dir)
        self.rune_mgr = RuneManager(self.data_dir)
        self.magic_circle_mgr = MagicCircleManager(self.data_dir)
        self.doram_mgr = DoramManager(self.data_dir)

        # Current state
        self.current_job: JobClass | None = None
        self.current_job_id: int | None = None

        self.log.info("Job AI Coordinator initialized")

    async def set_job(self, job_id: int) -> bool:
        """
        Set current job and configure appropriate mechanics.

        Args:
            job_id: Job class ID

        Returns:
            True if job was set successfully
        """
        job = self.job_registry.get_job(job_id)
        if not job:
            self.log.error("Invalid job ID", job_id=job_id)
            return False

        self.current_job = job
        self.current_job_id = job_id

        # Load job-specific rotation
        await self.rotation_engine.load_rotation_for_job(job.name)

        self.log.info(
            "Job set",
            job_id=job_id,
            job_name=job.name,
            role=job.primary_role.value,
        )

        return True

    def get_current_job(self) -> JobClass | None:
        """Get current job class."""
        return self.current_job

    async def get_next_action(
        self,
        character_state: dict[str, Any],
        target_state: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """
        Get next recommended action based on job and state.

        Args:
            character_state: Current character state
            target_state: Optional target state

        Returns:
            Action dict with type, skill, parameters, etc.
        """
        if not self.current_job:
            return {"type": "wait", "reason": "no_job_set"}

        # Check special mechanics that need maintenance
        maintenance_action = self._check_mechanics_maintenance(character_state)
        if maintenance_action:
            return maintenance_action

        # Get skill rotation action
        rotation_action = await self.rotation_engine.get_next_skill(
            character_state, target_state
        )

        # Apply job-specific modifications
        if rotation_action:
            return self._enhance_action_with_mechanics(rotation_action, character_state)

        return {"type": "wait", "reason": "no_action_available"}

    def _check_mechanics_maintenance(
        self, character_state: dict[str, Any]
    ) -> dict[str, Any] | None:
        """
        Check if any special mechanics need maintenance.

        Args:
            character_state: Current character state

        Returns:
            Maintenance action if needed, None otherwise
        """
        if not self.current_job:
            return None

        # Spirit spheres (Monk/Champion/Shura)
        if self.current_job.has_spirit_spheres:
            if self.spirit_sphere_mgr.should_generate_spheres():
                return {
                    "type": "use_skill",
                    "skill": "Summon Spirit Sphere",
                    "reason": "generate_spheres",
                }

        # Poison coating (Assassin Cross)
        if self.current_job.has_poisons:
            if self.poison_mgr.should_reapply_coating():
                poison_type = self.poison_mgr.get_recommended_poison("boss")
                if poison_type:
                    return {
                        "type": "apply_poison",
                        "poison": poison_type.value,
                        "reason": "maintain_coating",
                    }

        # Rune points (Rune Knight)
        if self.current_job.has_runes:
            available_runes = self.rune_mgr.get_available_runes()
            if available_runes and character_state.get("in_combat", False):
                rune = self.rune_mgr.get_recommended_rune("boss")
                if rune:
                    return {
                        "type": "use_rune",
                        "rune": rune.value,
                        "reason": "tactical_rune",
                    }

        return None

    def _enhance_action_with_mechanics(
        self, action: dict[str, Any], character_state: dict[str, Any]
    ) -> dict[str, Any]:
        """
        Enhance action with job-specific mechanics.

        Args:
            action: Base action from rotation
            character_state: Current character state

        Returns:
            Enhanced action with mechanics info
        """
        enhanced = action.copy()

        if not self.current_job:
            return enhanced

        # Add spirit sphere info for sphere skills
        if self.current_job.has_spirit_spheres and "skill" in action:
            can_use, required = self.spirit_sphere_mgr.can_use_skill(action["skill"])
            enhanced["spirit_spheres"] = {
                "can_use": can_use,
                "required": required,
                "current": self.spirit_sphere_mgr.get_sphere_count(),
            }

        # Add poison info
        if self.current_job.has_poisons:
            coating = self.poison_mgr.get_current_coating()
            enhanced["poison_coating"] = coating.value if coating else None
            enhanced["edp_active"] = self.poison_mgr.is_edp_active()

        # Add rune info
        if self.current_job.has_runes:
            enhanced["rune_points"] = self.rune_mgr.current_rune_points
            enhanced["available_runes"] = [
                r.value for r in self.rune_mgr.get_available_runes()
            ]

        # Add magic circle info
        if self.current_job.has_magic_circles:
            enhanced["active_insignia"] = (
                self.magic_circle_mgr.get_active_insignia().value
                if self.magic_circle_mgr.get_active_insignia()
                else None
            )
            enhanced["circle_count"] = self.magic_circle_mgr.get_circle_count()

        return enhanced

    def update_mechanics_state(self, event_type: str, event_data: dict[str, Any]) -> None:
        """
        Update mechanics state based on game events.

        Args:
            event_type: Type of event (skill_used, item_used, etc.)
            event_data: Event-specific data
        """
        if not self.current_job:
            return

        # Spirit sphere events
        if self.current_job.has_spirit_spheres:
            if event_type == "skill_used":
                skill_name = event_data.get("skill_name", "")
                
                # Consume spheres
                self.spirit_sphere_mgr.consume_spheres(skill_name)
                
                # Generate spheres
                if self.spirit_sphere_mgr.is_generation_skill(skill_name):
                    count = event_data.get("spheres_generated", 1)
                    self.spirit_sphere_mgr.generate_multiple_spheres(count)

        # Poison events
        if self.current_job.has_poisons:
            if event_type == "attack":
                self.poison_mgr.use_coating_charge()
            elif event_type == "buff_applied":
                if event_data.get("buff_name") == "Enchant Deadly Poison":
                    self.poison_mgr.activate_edp(event_data.get("duration", 40))

        # Rune events
        if self.current_job.has_runes:
            if event_type == "rune_used":
                # Cooldown is handled internally
                pass
            elif event_type == "combat_tick":
                # Generate rune points
                self.rune_mgr.add_rune_points(event_data.get("points", 1))

        # Trap events
        if self.current_job.has_traps:
            if event_type == "trap_triggered":
                position = event_data.get("position", (0, 0))
                self.trap_mgr.trigger_trap(position)

        # Magic circle events
        if self.current_job.has_magic_circles:
            if event_type == "circle_placed":
                # Handled through action system
                pass

        # Doram events
        if self.current_job.job_id >= 4218:  # Doram job IDs
            if event_type == "ability_used":
                ability = event_data.get("ability_name", "")
                cost = self.doram_mgr.ability_costs.get(ability, 0)
                self.doram_mgr.consume_spirit_points(cost)

    def get_mechanics_status(self) -> dict[str, Any]:
        """
        Get status of all active mechanics.

        Returns:
            Status dict for all mechanics
        """
        if not self.current_job:
            return {"job_set": False}

        status: dict[str, Any] = {
            "job_set": True,
            "job_name": self.current_job.name,
            "job_id": self.current_job_id,
            "role": self.current_job.primary_role.value,
        }

        # Add active mechanics
        if self.current_job.has_spirit_spheres:
            status["spirit_spheres"] = self.spirit_sphere_mgr.get_status()

        if self.current_job.has_traps:
            status["traps"] = self.trap_mgr.get_status()

        if self.current_job.has_poisons:
            status["poisons"] = self.poison_mgr.get_status()

        if self.current_job.has_runes:
            status["runes"] = self.rune_mgr.get_status()

        if self.current_job.has_magic_circles:
            status["magic_circles"] = self.magic_circle_mgr.get_status()

        if self.current_job.job_id >= 4218:  # Doram
            status["doram"] = self.doram_mgr.get_status()

        return status

    def reset_mechanics(self) -> None:
        """Reset all mechanics state (e.g., after death or map change)."""
        self.spirit_sphere_mgr.reset()
        self.trap_mgr.reset()
        self.poison_mgr.reset()
        self.rune_mgr.reset()
        self.magic_circle_mgr.reset()
        self.doram_mgr.reset()
        
        self.log.info("All mechanics reset")

    def get_job_stats(self) -> dict[str, Any]:
        """
        Get recommended stats for current job.

        Returns:
            Stat recommendations
        """
        if not self.current_job:
            return {}

        return {
            "recommended_stats": self.current_job.recommended_stats,
            "stat_weights": self.current_job.stat_weights,
            "positioning": self.current_job.positioning.value,
            "armor_type": self.current_job.armor_type,
            "preferred_weapon": self.current_job.preferred_weapon,
        }

    def get_job_skills(self) -> set[str]:
        """
        Get all skills available to current job.

        Returns:
            Set of skill names
        """
        if not self.current_job:
            return set()

        return self.job_registry.get_all_skills_for_job(self.current_job.name)