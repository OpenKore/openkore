"""
Homunculus Strategic AI for AI Sidecar.

Implements intelligent homunculus management including:
- Stat distribution for S-evolution paths
- Skill point allocation strategies per form
- Tactical skill usage beyond auto-attack
- Evolution decision making (standard vs S-class)
- Intimacy optimization for evolution unlock

RO Homunculus Mechanics:
- Intimacy: 0-1000 scale (requires 910+ for evolution)
- Standard Evolution: Level 99 + 910 intimacy
- S-Evolution: Special requirements + stat thresholds
- Stat Growth: Random within growth rate ranges per type
"""

from __future__ import annotations

import json
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class HomunculusType(str, Enum):
    """All homunculus types including evolved and S-class forms."""
    
    # Base forms
    LIF = "lif"
    AMISTR = "amistr"
    FILIR = "filir"
    VANILMIRTH = "vanilmirth"
    
    # Standard evolved forms
    LIF_EVOLVED = "lif2"
    AMISTR_EVOLVED = "amistr2"
    FILIR_EVOLVED = "filir2"
    VANILMIRTH_EVOLVED = "vanilmirth2"
    
    # S-Class forms
    EIRA = "eira"  # From Lif
    BAYERI = "bayeri"  # From Amistr
    SERA = "sera"  # From Filir
    DIETER = "dieter"  # From Vanilmirth
    ELEANOR = "eleanor"  # New S-class


class HomunculusState(BaseModel):
    """Complete homunculus state and statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    homun_id: int = Field(description="Unique homunculus ID")
    type: HomunculusType = Field(description="Homunculus type")
    level: int = Field(default=1, ge=1, le=175, description="Current level")
    intimacy: int = Field(default=250, ge=0, le=1000, description="Intimacy level")
    
    # Current stats
    hp: int = Field(default=0, ge=0, description="Current HP")
    max_hp: int = Field(default=0, ge=0, description="Maximum HP")
    sp: int = Field(default=0, ge=0, description="Current SP")
    max_sp: int = Field(default=0, ge=0, description="Maximum SP")
    
    # Base stats
    stat_str: int = Field(default=1, ge=0, description="STR", alias="str")
    agi: int = Field(default=1, ge=0, description="AGI")
    vit: int = Field(default=1, ge=0, description="VIT")
    int_stat: int = Field(default=1, ge=0, description="INT", alias="int")
    dex: int = Field(default=1, ge=0, description="DEX")
    luk: int = Field(default=1, ge=0, description="LUK")
    
    # Skills
    skills: dict[str, int] = Field(
        default_factory=dict,
        description="Skill name -> level mapping"
    )
    skill_points: int = Field(default=0, ge=0, description="Available skill points")
    
    # Evolution
    can_evolve: bool = Field(default=False, description="Meets evolution requirements")
    evolution_form: HomunculusType | None = Field(
        default=None,
        description="Available evolution target"
    )


class HomunculusStatBuild(BaseModel):
    """Stat distribution strategy for a specific evolution path."""
    
    model_config = ConfigDict(frozen=True)
    
    type: HomunculusType = Field(description="Target homunculus type")
    stat_priority: list[str] = Field(description="Stat allocation order")
    target_ratios: dict[str, float] = Field(description="Target stat distribution ratios")
    evolution_path: list[HomunculusType] = Field(description="Evolution sequence")
    description: str = Field(default="", description="Build description")


class StatAllocation(BaseModel):
    """Stat point allocation decision."""
    
    model_config = ConfigDict(frozen=True)
    
    stat_name: str = Field(description="Stat to increase")
    points: int = Field(default=1, ge=1, description="Points to allocate")
    reason: str = Field(description="Allocation reasoning")


class SkillAllocation(BaseModel):
    """Skill point allocation decision."""
    
    model_config = ConfigDict(frozen=True)
    
    skill_name: str = Field(description="Skill to level up")
    current_level: int = Field(default=0, ge=0, description="Current skill level")
    target_level: int = Field(ge=1, description="Target skill level")
    reason: str = Field(description="Allocation reasoning")


class EvolutionDecision(BaseModel):
    """Evolution path decision."""
    
    model_config = ConfigDict(frozen=True)
    
    should_evolve: bool = Field(description="Whether to evolve")
    target_form: HomunculusType | None = Field(description="Evolution target")
    path_type: str = Field(
        default="standard",
        description="Evolution type: standard or s_class"
    )
    requirements_met: dict[str, bool] = Field(
        default_factory=dict,
        description="Requirement checklist"
    )
    reason: str = Field(description="Decision reasoning")


class HomunculusManager:
    """
    Strategic homunculus AI.
    
    Features:
    - Intelligent stat distribution for optimal S-evolution
    - Skill build planning per homunculus form
    - Tactical skill usage in combat
    - Evolution path recommendation
    """
    
    # Stat build templates for S-evolution paths
    STAT_BUILDS = {
        HomunculusType.EIRA: HomunculusStatBuild(
            type=HomunculusType.EIRA,
            stat_priority=["int", "dex", "vit", "agi", "str", "luk"],
            target_ratios={"int": 0.35, "dex": 0.25, "vit": 0.20, "agi": 0.10, "str": 0.05, "luk": 0.05},
            evolution_path=[HomunculusType.LIF, HomunculusType.EIRA],
            description="INT/DEX magic build for Eira"
        ),
        HomunculusType.BAYERI: HomunculusStatBuild(
            type=HomunculusType.BAYERI,
            stat_priority=["vit", "str", "agi", "dex", "int", "luk"],
            target_ratios={"vit": 0.35, "str": 0.30, "agi": 0.15, "dex": 0.10, "int": 0.05, "luk": 0.05},
            evolution_path=[HomunculusType.AMISTR, HomunculusType.BAYERI],
            description="VIT/STR tank build for Bayeri"
        ),
        HomunculusType.SERA: HomunculusStatBuild(
            type=HomunculusType.SERA,
            stat_priority=["agi", "dex", "str", "luk", "vit", "int"],
            target_ratios={"agi": 0.35, "dex": 0.25, "str": 0.15, "luk": 0.12, "vit": 0.08, "int": 0.05},
            evolution_path=[HomunculusType.FILIR, HomunculusType.SERA],
            description="AGI/DEX speed build for Sera"
        ),
        HomunculusType.DIETER: HomunculusStatBuild(
            type=HomunculusType.DIETER,
            stat_priority=["int", "vit", "dex", "str", "agi", "luk"],
            target_ratios={"int": 0.30, "vit": 0.25, "dex": 0.20, "str": 0.10, "agi": 0.10, "luk": 0.05},
            evolution_path=[HomunculusType.VANILMIRTH, HomunculusType.DIETER],
            description="INT/VIT hybrid build for Dieter"
        ),
    }
    
    def __init__(self, data_path: Path | None = None):
        """
        Initialize homunculus manager.
        
        Args:
            data_path: Path to homunculus database JSON
        """
        self.current_state: HomunculusState | None = None
        self._homunculus_database: dict[str, dict[str, Any]] = {}
        self._target_build: HomunculusStatBuild | None = None
        
        # Load homunculus database
        if data_path is None:
            data_path = Path(__file__).parent.parent / "data" / "homunculus.json"
        
        if data_path.exists():
            with open(data_path, "r") as f:
                self._homunculus_database = json.load(f)
            logger.info(
                "homunculus_database_loaded",
                type_count=len(self._homunculus_database)
            )
        else:
            logger.warning("homunculus_database_not_found", path=str(data_path))
    
    async def update_state(self, state: HomunculusState) -> None:
        """
        Update current homunculus state.
        
        Args:
            state: New state from game
        """
        self.current_state = state
        
        # Check evolution eligibility
        if state.level >= 99 and state.intimacy >= 910:
            state.can_evolve = True
            # Determine available evolution form
            evolution = self._get_evolution_path(state.type)
            if evolution:
                state.evolution_form = evolution.get("standard")
    
    async def set_target_build(self, target_type: HomunculusType) -> None:
        """
        Set target build for stat distribution.
        
        Args:
            target_type: Target S-class type to build toward
        """
        if target_type in self.STAT_BUILDS:
            self._target_build = self.STAT_BUILDS[target_type]
            logger.info("target_build_set", target=target_type)
        else:
            logger.warning("invalid_target_build", target=target_type)
    
    async def calculate_stat_distribution(self) -> StatAllocation | None:
        """
        Calculate optimal stat point allocation.
        
        Uses target build ratios to determine which stat needs points.
        Considers current stat distribution vs target ratios.
        
        Returns:
            Stat allocation decision
        """
        if not self.current_state or self.current_state.skill_points < 1:
            return None
        
        if not self._target_build:
            # Auto-select build based on current type
            base_type = self._get_base_type(self.current_state.type)
            for s_type, build in self.STAT_BUILDS.items():
                if base_type in build.evolution_path:
                    self._target_build = build
                    break
        
        if not self._target_build:
            return None
        
        state = self.current_state
        
        # Calculate current stat distribution
        total_stats = (
            state.stat_str + state.agi + state.vit +
            state.int_stat + state.dex + state.luk
        )
        
        if total_stats == 0:
            return None
        
        current_ratios = {
            "str": state.stat_str / total_stats,
            "agi": state.agi / total_stats,
            "vit": state.vit / total_stats,
            "int": state.int_stat / total_stats,
            "dex": state.dex / total_stats,
            "luk": state.luk / total_stats,
        }
        
        # Find stat with largest deficit from target
        max_deficit = 0.0
        target_stat = None
        
        for stat in self._target_build.stat_priority:
            target_ratio = self._target_build.target_ratios.get(stat, 0.0)
            current_ratio = current_ratios.get(stat, 0.0)
            deficit = target_ratio - current_ratio
            
            if deficit > max_deficit:
                max_deficit = deficit
                target_stat = stat
        
        if target_stat:
            return StatAllocation(
                stat_name=target_stat,
                points=1,
                reason=f"build_toward_{self._target_build.type}_deficit_{max_deficit:.2f}"
            )
        
        # Fallback: allocate to highest priority stat
        return StatAllocation(
            stat_name=self._target_build.stat_priority[0],
            points=1,
            reason="default_priority_stat"
        )
    
    async def allocate_skill_points(self) -> SkillAllocation | None:
        """
        Intelligent skill point allocation based on build.
        
        Prioritizes essential skills before optional ones.
        Considers skill synergies and role requirements.
        
        Returns:
            Skill allocation decision
        """
        if not self.current_state or self.current_state.skill_points < 1:
            return None
        
        state = self.current_state
        homun_data = self._homunculus_database.get(state.type.value, {})
        available_skills = homun_data.get("skills", {})
        
        if not available_skills:
            return None
        
        # Skill priority by homunculus type
        skill_priority = self._get_skill_priority(state.type)
        
        # Find first skill that can be leveled up
        for skill_name in skill_priority:
            if skill_name not in available_skills:
                continue
            
            max_level = available_skills[skill_name]
            current_level = state.skills.get(skill_name, 0)
            
            if current_level < max_level:
                return SkillAllocation(
                    skill_name=skill_name,
                    current_level=current_level,
                    target_level=current_level + 1,
                    reason=f"priority_skill_for_{state.type}"
                )
        
        return None
    
    async def decide_evolution_path(self) -> EvolutionDecision:
        """
        Evaluate and decide evolution path.
        
        Considers:
        - Current stats and build alignment
        - Player class synergy
        - Economic factors (S-class requirements)
        
        Returns:
            Evolution decision with requirements checklist
        """
        if not self.current_state:
            return EvolutionDecision(
                should_evolve=False,
                target_form=None,
                reason="no_homunculus_state"
            )
        
        state = self.current_state
        
        # Check basic requirements
        requirements = {
            "level_99": state.level >= 99,
            "intimacy_910": state.intimacy >= 910,
        }
        
        if not all(requirements.values()):
            return EvolutionDecision(
                should_evolve=False,
                target_form=None,
                requirements_met=requirements,
                reason="basic_requirements_not_met"
            )
        
        # Check S-class eligibility
        s_class_eligible = self._check_s_class_eligibility(state)
        
        evolution_data = self._get_evolution_path(state.type)
        if not evolution_data:
            return EvolutionDecision(
                should_evolve=False,
                target_form=None,
                requirements_met=requirements,
                reason="no_evolution_path"
            )
        
        # Recommend S-class if eligible and stats align
        if s_class_eligible and self._target_build:
            s_form = evolution_data.get("s_evolution")
            if s_form:
                requirements["s_class_stats"] = True
                return EvolutionDecision(
                    should_evolve=True,
                    target_form=HomunculusType(s_form),
                    path_type="s_class",
                    requirements_met=requirements,
                    reason="s_class_recommended_stats_aligned"
                )
        
        # Recommend standard evolution
        standard_form = evolution_data.get("standard")
        if standard_form:
            return EvolutionDecision(
                should_evolve=True,
                target_form=HomunculusType(standard_form),
                path_type="standard",
                requirements_met=requirements,
                reason="standard_evolution_recommended"
            )
        
        return EvolutionDecision(
            should_evolve=False,
            target_form=None,
            requirements_met=requirements,
            reason="no_viable_evolution"
        )
    
    async def tactical_skill_usage(
        self,
        combat_active: bool,
        player_hp_percent: float,
        player_sp_percent: float,
        enemies_nearby: int,
        ally_count: int
    ) -> SkillAction | None:
        """
        Intelligent skill usage beyond auto-attack.
        
        Args:
            combat_active: Whether in active combat
            player_hp_percent: Player HP percentage
            player_sp_percent: Player SP percentage
            enemies_nearby: Number of nearby enemies
            ally_count: Number of nearby allies
        
        Returns:
            Skill action if should use a skill
        """
        if not self.current_state:
            return None
        
        state = self.current_state
        
        # Type-specific skill usage logic
        if state.type in [HomunculusType.LIF, HomunculusType.LIF_EVOLVED, HomunculusType.EIRA]:
            # Healing homunculus
            if player_hp_percent < 0.6 and "Healing Hands" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Healing Hands",
                    target_id=None,
                    reason="player_needs_healing"
                )
        
        elif state.type in [HomunculusType.AMISTR, HomunculusType.AMISTR_EVOLVED, HomunculusType.BAYERI]:
            # Tank homunculus
            if combat_active and enemies_nearby > 2 and "Amistr Bulwark" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Amistr Bulwark",
                    target_id=None,
                    reason="defensive_buff_multiple_enemies"
                )
        
        elif state.type in [HomunculusType.FILIR, HomunculusType.FILIR_EVOLVED, HomunculusType.SERA]:
            # Speed/DPS homunculus
            if combat_active and "Flitting" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Flitting",
                    target_id=None,
                    reason="speed_buff_combat"
                )
        
        elif state.type in [HomunculusType.VANILMIRTH, HomunculusType.VANILMIRTH_EVOLVED, HomunculusType.DIETER]:
            # Magic homunculus
            if combat_active and enemies_nearby > 0 and state.sp > 20:
                magic_skills = ["Caprice", "Chaotic Blessings"]
                for skill in magic_skills:
                    if skill in state.skills:
                        from ai_sidecar.companions.pet import SkillAction
                        return SkillAction(
                            skill_name=skill,
                            target_id=None,
                            reason="magic_damage_output"
                        )
        
        return None
    
    def _get_base_type(self, homun_type: HomunculusType) -> HomunculusType:
        """Get base form of homunculus."""
        type_map = {
            HomunculusType.LIF: HomunculusType.LIF,
            HomunculusType.LIF_EVOLVED: HomunculusType.LIF,
            HomunculusType.EIRA: HomunculusType.LIF,
            HomunculusType.AMISTR: HomunculusType.AMISTR,
            HomunculusType.AMISTR_EVOLVED: HomunculusType.AMISTR,
            HomunculusType.BAYERI: HomunculusType.AMISTR,
            HomunculusType.FILIR: HomunculusType.FILIR,
            HomunculusType.FILIR_EVOLVED: HomunculusType.FILIR,
            HomunculusType.SERA: HomunculusType.FILIR,
            HomunculusType.VANILMIRTH: HomunculusType.VANILMIRTH,
            HomunculusType.VANILMIRTH_EVOLVED: HomunculusType.VANILMIRTH,
            HomunculusType.DIETER: HomunculusType.VANILMIRTH,
        }
        return type_map.get(homun_type, homun_type)
    
    def _get_evolution_path(self, homun_type: HomunculusType) -> dict[str, str] | None:
        """Get evolution paths for homunculus type."""
        homun_data = self._homunculus_database.get(homun_type.value, {})
        return homun_data.get("evolution")
    
    def _check_s_class_eligibility(self, state: HomunculusState) -> bool:
        """Check if homunculus meets S-class stat requirements."""
        if not self._target_build:
            return False
        
        # Simplified check: if stats are reasonably aligned with target
        total_stats = (
            state.stat_str + state.agi + state.vit +
            state.int_stat + state.dex + state.luk
        )
        
        if total_stats == 0:
            return False
        
        # Check if top priority stats are above threshold
        stat_values = {
            "str": state.stat_str,
            "agi": state.agi,
            "vit": state.vit,
            "int": state.int_stat,
            "dex": state.dex,
            "luk": state.luk,
        }
        
        top_stats = self._target_build.stat_priority[:2]
        for stat in top_stats:
            expected = self._target_build.target_ratios.get(stat, 0) * total_stats
            actual = stat_values.get(stat, 0)
            if actual < expected * 0.8:  # Within 80% of target
                return False
        
        return True
    
    def _get_skill_priority(self, homun_type: HomunculusType) -> list[str]:
        """Get skill priority list for homunculus type."""
        # Skill priorities by type
        priorities = {
            HomunculusType.LIF: ["Healing Hands", "Urgent Escape", "Brain Surgery", "Mental Change"],
            HomunculusType.AMISTR: ["Amistr Bulwark", "Adamantium Skin", "Bloodlust", "Castling"],
            HomunculusType.FILIR: ["Flitting", "Moonlight", "Accelerated Flight", "S.B.R.44"],
            HomunculusType.VANILMIRTH: ["Caprice", "Chaotic Blessings", "Instruction Change", "Bio Explosion"],
        }
        
        base_type = self._get_base_type(homun_type)
        return priorities.get(base_type, [])