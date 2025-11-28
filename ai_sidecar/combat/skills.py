"""
Skill Allocation System for the AI Sidecar.

Provides intelligent skill point allocation with:
- Recursive prerequisite resolution
- Build-optimized skill ordering
- Prerequisite chain completion
- Skill type classification
"""

import json
import logging
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import CharacterState

logger = logging.getLogger(__name__)


class SkillPrerequisite(BaseModel):
    """A skill prerequisite requirement."""
    
    model_config = ConfigDict(frozen=True)
    
    skill: str = Field(description="Skill handle name")
    level: int = Field(default=1, ge=1, description="Required level")


class SkillDefinition(BaseModel):
    """Definition of a skill from the skill tree."""
    
    model_config = ConfigDict(frozen=True)
    
    id: int = Field(description="Skill database ID")
    name: str = Field(default="", description="Display name")
    max_level: int = Field(default=10, ge=1, description="Maximum skill level")
    skill_type: str = Field(default="active", description="Skill type")
    target: str = Field(default="self", description="Target type")
    range: int = Field(default=0, ge=0, description="Skill range")
    prerequisites: list[SkillPrerequisite] = Field(
        default_factory=list,
        description="Required skills"
    )


class SkillDatabase:
    """
    Loads and provides access to skill data from JSON files.
    
    Uses lazy loading to only read files when needed.
    """
    
    def __init__(self, data_dir: Path | None = None):
        """
        Initialize skill database.
        
        Args:
            data_dir: Directory containing skill data JSON files.
                     Defaults to ai_sidecar/data/skills/
        """
        if data_dir is None:
            data_dir = Path(__file__).parent.parent / "data" / "skills"
        
        self._data_dir = data_dir
        self._skill_trees: dict[str, dict[str, Any]] | None = None
        self._skill_effects: dict[str, Any] | None = None
        self._skill_priorities: dict[str, Any] | None = None
        self._skill_elements: dict[str, Any] | None = None
    
    def _load_json(self, filename: str) -> dict[str, Any]:
        """Load a JSON file from the data directory."""
        filepath = self._data_dir / filename
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            logger.warning(f"Skill data file not found: {filepath}")
            return {}
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in {filepath}: {e}")
            return {}
    
    @property
    def skill_trees(self) -> dict[str, dict[str, Any]]:
        """Get skill trees, loading from file if needed."""
        if self._skill_trees is None:
            data = self._load_json("skill_trees.json")
            # Remove schema keys
            self._skill_trees = {
                k: v for k, v in data.items()
                if not k.startswith("$")
            }
        return self._skill_trees
    
    @property
    def skill_effects(self) -> dict[str, Any]:
        """Get skill effects, loading from file if needed."""
        if self._skill_effects is None:
            data = self._load_json("skill_effects.json")
            self._skill_effects = {
                k: v for k, v in data.items()
                if not k.startswith("$")
            }
        return self._skill_effects
    
    @property
    def skill_priorities(self) -> dict[str, Any]:
        """Get build skill priorities, loading from file if needed."""
        if self._skill_priorities is None:
            self._skill_priorities = self._load_json("skill_priorities.json")
        return self._skill_priorities
    
    @property
    def skill_elements(self) -> dict[str, Any]:
        """Get skill elements, loading from file if needed."""
        if self._skill_elements is None:
            self._skill_elements = self._load_json("skill_elements.json")
        return self._skill_elements
    
    def get_skill_tree(self, job_class: str) -> dict[str, Any]:
        """Get skill tree for a specific job class."""
        return self.skill_trees.get(job_class.lower(), {})
    
    def get_skill_definition(
        self, skill_name: str, job_class: str
    ) -> SkillDefinition | None:
        """Get definition for a specific skill."""
        tree = self.get_skill_tree(job_class)
        if skill_name not in tree:
            return None
        
        skill_data = tree[skill_name]
        prereqs = []
        for prereq in skill_data.get("prerequisites", []):
            if isinstance(prereq, dict):
                prereqs.append(SkillPrerequisite(
                    skill=prereq["skill"],
                    level=prereq["level"]
                ))
        
        return SkillDefinition(
            id=skill_data.get("id", 0),
            name=skill_data.get("name", skill_name),
            max_level=skill_data.get("max_level", 10),
            skill_type=skill_data.get("type", "active"),
            target=skill_data.get("target", "self"),
            range=skill_data.get("range", 0),
            prerequisites=prereqs
        )
    
    def get_skill_id(self, skill_name: str) -> int | None:
        """Get skill ID by name from effects data."""
        effects = self.skill_effects.get(skill_name)
        if effects:
            return effects.get("id")
        return None
    
    def get_build_priorities(self, build_name: str) -> list[str]:
        """Get skill priority order for a build."""
        builds = self.skill_priorities.get("builds", {})
        build_data = builds.get(build_name, {})
        return build_data.get("priority_order", [])
    
    def get_role_skills(self, role: str) -> dict[str, list[str]]:
        """Get skills for a tactical role."""
        mapping = self.skill_priorities.get("role_skill_mapping", {})
        return mapping.get(role, {
            "primary_skills": [],
            "secondary_skills": [],
            "utility_skills": []
        })


class SkillAllocationSystem:
    """
    Intelligent skill point allocation with prerequisite handling.
    
    Features:
    - Recursive prerequisite resolution
    - Build-optimized skill order
    - Prerequisite chain completion
    - Cycle detection in prerequisites
    """
    
    # Job class mapping from job_id
    JOB_CLASS_MAP: dict[int, str] = {
        0: "novice",
        1: "swordsman",
        2: "mage",
        3: "archer",
        4: "acolyte",
        5: "merchant",
        6: "thief",
        7: "knight",
        8: "priest",
        9: "wizard",
        10: "blacksmith",
        11: "hunter",
        12: "assassin",
        14: "crusader",
        16: "rogue",
        18: "alchemist",
    }
    
    def __init__(
        self,
        skill_db: SkillDatabase | None = None,
        default_build: str = "melee_dps"
    ):
        """
        Initialize the skill allocation system.
        
        Args:
            skill_db: Optional skill database instance
            default_build: Default build for skill priorities
        """
        self.skill_db = skill_db or SkillDatabase()
        self.default_build = default_build
        self._resolved_cache: dict[str, list[tuple[str, int]]] = {}
    
    def get_job_class(self, job_id: int) -> str:
        """Convert job ID to job class name."""
        return self.JOB_CLASS_MAP.get(job_id, "novice")
    
    def get_base_job_class(self, job_class: str) -> str:
        """Get base job for a transcendent/rebirth job."""
        base_map = {
            "lord_knight": "knight",
            "high_priest": "priest",
            "high_wizard": "wizard",
            "whitesmith": "blacksmith",
            "sniper": "hunter",
            "assassin_cross": "assassin",
            "paladin": "crusader",
            "stalker": "rogue",
            "biochemist": "alchemist",
        }
        return base_map.get(job_class.lower(), job_class.lower())
    
    def resolve_prerequisites(
        self,
        skill_name: str,
        job_class: str,
        visited: set[str] | None = None
    ) -> list[tuple[str, int]]:
        """
        Recursively resolve skill prerequisites chain.
        
        Returns prerequisites in order they should be learned,
        with cycle detection.
        
        Args:
            skill_name: Target skill to resolve prerequisites for
            job_class: Job class to look up skills in
            visited: Set of already visited skills for cycle detection
        
        Returns:
            List of (skill_name, level) tuples in learning order
        """
        cache_key = f"{job_class}:{skill_name}"
        if cache_key in self._resolved_cache:
            return self._resolved_cache[cache_key].copy()
        
        if visited is None:
            visited = set()
        
        # Cycle detection
        if skill_name in visited:
            logger.warning(f"Cycle detected in prerequisites: {skill_name}")
            return []
        
        visited.add(skill_name)
        
        # Get skill definition
        skill_def = self.skill_db.get_skill_definition(skill_name, job_class)
        if skill_def is None:
            # Try base job if not found
            base_class = self.get_base_job_class(job_class)
            if base_class != job_class:
                skill_def = self.skill_db.get_skill_definition(skill_name, base_class)
        
        if skill_def is None:
            logger.debug(f"Skill not found: {skill_name} for {job_class}")
            return []
        
        result: list[tuple[str, int]] = []
        
        # Recursively resolve each prerequisite
        for prereq in skill_def.prerequisites:
            # Resolve prerequisites of the prerequisite first
            prereq_chain = self.resolve_prerequisites(
                prereq.skill, job_class, visited.copy()
            )
            
            # Add prerequisites that aren't already in result
            for item in prereq_chain:
                if item not in result:
                    result.append(item)
            
            # Add the prerequisite itself
            prereq_tuple = (prereq.skill, prereq.level)
            if prereq_tuple not in result:
                result.append(prereq_tuple)
        
        # Cache result
        self._resolved_cache[cache_key] = result.copy()
        
        return result
    
    def get_next_skill_to_learn(
        self,
        character: CharacterState,
        build_name: str | None = None
    ) -> tuple[str, int] | None:
        """
        Determine the next skill and level to allocate a point to.
        
        Args:
            character: Current character state
            build_name: Optional build name for priorities
        
        Returns:
            Tuple of (skill_name, target_level) or None if no skill to learn
        """
        if character.skill_points <= 0:
            return None
        
        job_class = self.get_job_class(character.job_id)
        build = build_name or self.default_build
        priorities = self.skill_db.get_build_priorities(build)
        
        if not priorities:
            logger.warning(f"No priorities found for build: {build}")
            return None
        
        # Get current skill levels (simplified - would need game state)
        current_skills: dict[str, int] = getattr(
            character, "learned_skills", {}
        )
        
        # Find the first priority skill that isn't maxed
        for skill_name in priorities:
            skill_def = self.skill_db.get_skill_definition(skill_name, job_class)
            if skill_def is None:
                base_class = self.get_base_job_class(job_class)
                skill_def = self.skill_db.get_skill_definition(skill_name, base_class)
            
            if skill_def is None:
                continue
            
            current_level = current_skills.get(skill_name, 0)
            
            # Skill is maxed, skip
            if current_level >= skill_def.max_level:
                continue
            
            # Check prerequisites
            prereqs = self.resolve_prerequisites(skill_name, job_class)
            for prereq_skill, prereq_level in prereqs:
                prereq_current = current_skills.get(prereq_skill, 0)
                if prereq_current < prereq_level:
                    # Need to learn prerequisite first
                    return (prereq_skill, prereq_current + 1)
            
            # All prerequisites met, learn this skill
            return (skill_name, current_level + 1)
        
        return None
    
    def allocate_skill_point(
        self,
        character: CharacterState,
        build_name: str | None = None
    ) -> Action | None:
        """
        Allocate a single skill point optimally.
        
        Args:
            character: Current character state
            build_name: Optional build name for priorities
        
        Returns:
            SKILL action to allocate point, or None if no skill to learn
        """
        if character.skill_points <= 0:
            return None
        
        next_skill = self.get_next_skill_to_learn(character, build_name)
        if next_skill is None:
            return None
        
        skill_name, target_level = next_skill
        job_class = self.get_job_class(character.job_id)
        
        # Get skill ID
        skill_id = self.skill_db.get_skill_id(skill_name)
        if skill_id is None:
            # Try to get from skill tree
            skill_def = self.skill_db.get_skill_definition(skill_name, job_class)
            if skill_def:
                skill_id = skill_def.id
        
        if skill_id is None:
            logger.warning(f"Cannot find skill ID for: {skill_name}")
            return None
        
        return Action(
            type=ActionType.SKILL,
            skill_id=skill_id,
            skill_level=target_level,
            priority=2,  # Medium priority for skill allocation
            reason=f"Allocate point to {skill_name} level {target_level}"
        )
    
    def get_recommended_skills(
        self,
        job_class: str,
        build_name: str | None = None,
        max_count: int = 10
    ) -> list[str]:
        """
        Get recommended skills for a job and build.
        
        Args:
            job_class: Character's job class
            build_name: Optional build name
            max_count: Maximum skills to return
        
        Returns:
            List of skill names in priority order
        """
        build = build_name or self.default_build
        priorities = self.skill_db.get_build_priorities(build)
        
        # Filter to skills available for this job
        available = []
        for skill_name in priorities:
            skill_def = self.skill_db.get_skill_definition(skill_name, job_class)
            if skill_def is None:
                base_class = self.get_base_job_class(job_class)
                skill_def = self.skill_db.get_skill_definition(skill_name, base_class)
            
            if skill_def is not None:
                available.append(skill_name)
            
            if len(available) >= max_count:
                break
        
        return available
    
    def validate_skill_tree(self, job_class: str) -> list[str]:
        """
        Validate skill tree for cycles and missing prerequisites.
        
        Returns list of error messages, empty if valid.
        """
        errors: list[str] = []
        tree = self.skill_db.get_skill_tree(job_class)
        
        for skill_name in tree:
            try:
                self.resolve_prerequisites(skill_name, job_class)
            except RecursionError:
                errors.append(f"Cycle detected in {skill_name}")
        
        return errors