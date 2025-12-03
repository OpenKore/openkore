"""
Skill Combo System for Advanced Combat Mechanics.

Implements job-specific skill combos with timing optimization,
interruption handling, and adaptive combo selection.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict


class ComboStep(BaseModel):
    """Single step in a combo sequence."""
    
    model_config = ConfigDict(frozen=False)
    
    skill_name: str = Field(description="Skill name")
    skill_level: int = Field(default=1, ge=1, description="Skill level")
    delay_after_ms: int = Field(default=0, ge=0, description="Minimum delay after skill")
    requires_hit: bool = Field(default=False, description="Must hit to continue")
    cancellable: bool = Field(default=True, description="Can cancel into next skill")
    sp_cost: int = Field(default=0, ge=0, description="SP cost")


class SkillCombo(BaseModel):
    """Complete skill combo definition."""
    
    model_config = ConfigDict(frozen=False)
    
    combo_id: str = Field(description="Unique combo identifier")
    combo_name: str = Field(description="Human-readable combo name")
    job_class: str = Field(description="Job that can use this combo")
    
    # Combo steps
    steps: List[ComboStep] = Field(description="Combo steps in order")
    
    # Requirements
    requires_target: bool = Field(default=True, description="Needs a target")
    min_sp: int = Field(default=0, ge=0, description="Minimum SP required")
    required_buffs: List[str] = Field(default_factory=list, description="Required active buffs")
    required_weapon: Optional[str] = Field(default=None, description="Required weapon type")
    
    # Timing
    total_duration_ms: int = Field(default=0, ge=0, description="Total combo duration")
    dps_multiplier: float = Field(default=1.0, ge=0.0, description="DPS vs single skill")
    
    # Situational
    pve_rating: int = Field(default=5, ge=1, le=10, description="PvE effectiveness (1-10)")
    pvp_rating: int = Field(default=5, ge=1, le=10, description="PvP effectiveness (1-10)")
    aoe_capable: bool = Field(default=False, description="Can hit multiple targets")
    
    @property
    def total_sp_cost(self) -> int:
        """Calculate total SP cost for combo."""
        return sum(step.sp_cost for step in self.steps)


class ComboState(BaseModel):
    """Current state of combo execution."""
    
    model_config = ConfigDict(frozen=False)
    
    combo_id: str = Field(description="Active combo ID")
    current_step: int = Field(default=0, ge=0, description="Current step index")
    started_at: datetime = Field(default_factory=datetime.now, description="Combo start time")
    last_skill_at: Optional[datetime] = Field(default=None, description="Last skill execution")
    hits_landed: int = Field(default=0, ge=0, description="Number of hits landed")
    damage_dealt: int = Field(default=0, ge=0, description="Total damage dealt")
    
    @property
    def is_complete(self) -> bool:
        """Check if combo is finished."""
        # Will be updated when combo is loaded
        return False
        
    @property
    def time_in_combo_ms(self) -> int:
        """Time since combo started in milliseconds."""
        elapsed = datetime.now() - self.started_at
        return int(elapsed.total_seconds() * 1000)


class SkillComboEngine:
    """
    Execute and optimize skill combos.
    
    Features:
    - Job-specific combo definitions
    - Timing optimization
    - Combo interruption handling
    - Adaptive combo selection
    - PvE vs PvP combo switching
    """
    
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        """
        Initialize combo engine.
        
        Args:
            data_dir: Directory containing combo data files
        """
        self.log = structlog.get_logger(__name__)
        
        # Combo database: job_class -> list of combos
        self.combos: Dict[str, List[SkillCombo]] = {}
        
        # Current execution state
        self.current_combo: Optional[ComboState] = None
        self._active_combo_def: Optional[SkillCombo] = None
        
        # Load combo data
        if data_dir:
            self._load_combos(data_dir)
        else:
            self._initialize_default_combos()
            
    def _initialize_default_combos(self) -> None:
        """Initialize with common job combos."""
        default_combos = [
            # Assassin Cross
            SkillCombo(
                combo_id="sinx_sonic_chain",
                combo_name="Sonic Blow Chain",
                job_class="assassin_cross",
                steps=[
                    ComboStep(
                        skill_name="Enchant Deadly Poison",
                        skill_level=5,
                        delay_after_ms=500,
                        sp_cost=40,
                    ),
                    ComboStep(
                        skill_name="Soul Breaker",
                        skill_level=10,
                        delay_after_ms=1000,
                        sp_cost=40,
                        requires_hit=True,
                    ),
                    ComboStep(
                        skill_name="Sonic Blow",
                        skill_level=10,
                        delay_after_ms=0,
                        sp_cost=50,
                    ),
                ],
                min_sp=130,
                required_weapon="katar",
                total_duration_ms=3500,
                dps_multiplier=2.5,
                pve_rating=8,
                pvp_rating=9,
            ),
            # Lord Knight
            SkillCombo(
                combo_id="lk_spiral_combo",
                combo_name="Spiral Pierce Combo",
                job_class="lord_knight",
                steps=[
                    ComboStep(
                        skill_name="Concentration",
                        skill_level=5,
                        delay_after_ms=0,
                        sp_cost=14,
                    ),
                    ComboStep(
                        skill_name="Spiral Pierce",
                        skill_level=5,
                        delay_after_ms=1500,
                        sp_cost=18,
                        requires_hit=True,
                    ),
                ],
                min_sp=32,
                required_weapon="spear",
                total_duration_ms=2500,
                dps_multiplier=2.0,
                pve_rating=9,
                pvp_rating=7,
            ),
            # High Wizard
            SkillCombo(
                combo_id="hwiz_storm_combo",
                combo_name="Storm Gust Combo",
                job_class="high_wizard",
                steps=[
                    ComboStep(
                        skill_name="Quagmire",
                        skill_level=5,
                        delay_after_ms=1000,
                        sp_cost=5,
                    ),
                    ComboStep(
                        skill_name="Storm Gust",
                        skill_level=10,
                        delay_after_ms=5000,
                        sp_cost=78,
                    ),
                ],
                min_sp=83,
                total_duration_ms=11000,
                dps_multiplier=3.0,
                pve_rating=10,
                pvp_rating=6,
                aoe_capable=True,
            ),
        ]
        
        for combo in default_combos:
            if combo.job_class not in self.combos:
                self.combos[combo.job_class] = []
            self.combos[combo.job_class].append(combo)
            
        self.log.info("initialized_default_combos", count=len(default_combos))
        
    def _load_combos(self, data_dir: Path) -> None:
        """Load combo data from JSON file."""
        combo_file = data_dir / "skill_combos.json"
        
        if not combo_file.exists():
            self.log.warning("combo_data_not_found", path=str(combo_file))
            self._initialize_default_combos()
            return
            
        try:
            with open(combo_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                
            for job_class, combos_list in data.items():
                self.combos[job_class] = []
                for combo_data in combos_list:
                    combo = SkillCombo(**combo_data)
                    self.combos[job_class].append(combo)
                    
            self.log.info("loaded_combo_data", path=str(combo_file), jobs=len(self.combos))
            
        except Exception as e:
            self.log.error("failed_to_load_combo_data", path=str(combo_file), error=str(e))
            self._initialize_default_combos()
            
    async def get_available_combos(
        self,
        job_class: str,
        sp_current: int,
        active_buffs: List[str],
        weapon_type: Optional[str] = None,
    ) -> List[SkillCombo]:
        """
        Get combos available to execute.
        
        Args:
            job_class: Character's job class
            sp_current: Current SP
            active_buffs: Active buff names
            weapon_type: Current weapon type
            
        Returns:
            List of available combos
        """
        job_combos = self.combos.get(job_class.lower(), [])
        available = []
        
        for combo in job_combos:
            # Check SP requirement
            if sp_current < combo.min_sp:
                continue
                
            # Check weapon requirement
            if combo.required_weapon and weapon_type:
                if weapon_type.lower() != combo.required_weapon.lower():
                    continue
                    
            # Check buff requirements
            if combo.required_buffs:
                if not all(buff in active_buffs for buff in combo.required_buffs):
                    continue
                    
            available.append(combo)
            
        self.log.debug(
            "available_combos_found",
            job=job_class,
            sp=sp_current,
            available=len(available),
        )
        
        return available
        
    async def select_optimal_combo(
        self,
        available_combos: List[SkillCombo],
        situation: str = "pve",
        target_count: int = 1,
        sp_available: int = 100,
    ) -> Optional[SkillCombo]:
        """
        Select best combo for situation.
        
        Args:
            available_combos: Available combo list
            situation: "pve", "pvp", or "boss"
            target_count: Number of targets
            sp_available: Available SP
            
        Returns:
            Best combo or None
        """
        if not available_combos:
            return None
            
        # Filter by SP
        valid_combos = [c for c in available_combos if c.min_sp <= sp_available]
        
        if not valid_combos:
            return None
            
        # Score combos
        scored_combos = []
        for combo in valid_combos:
            score = 0.0
            
            # Situation rating
            if situation == "pvp":
                score += combo.pvp_rating * 2.0
            elif situation == "boss":
                score += combo.pve_rating * 1.5
                score += combo.dps_multiplier * 3.0
            else:  # pve
                score += combo.pve_rating * 1.5
                
            # AoE bonus for multiple targets
            if target_count > 1 and combo.aoe_capable:
                score += target_count * 2.0
                
            # Efficiency (DPS per SP)
            if combo.total_sp_cost > 0:
                efficiency = combo.dps_multiplier / combo.total_sp_cost
                score += efficiency * 10.0
                
            scored_combos.append((combo, score))
            
        # Sort by score
        scored_combos.sort(key=lambda x: x[1], reverse=True)
        best_combo = scored_combos[0][0]
        
        self.log.info(
            "optimal_combo_selected",
            combo=best_combo.combo_name,
            situation=situation,
            score=scored_combos[0][1],
        )
        
        return best_combo
        
    def get_next_combo_skill(self, skill_history: list[str]) -> str | None:
        """
        Get next skill in combo based on skill history.
        
        Args:
            skill_history: List of recently used skills
            
        Returns:
            Next skill name or None
        """
        if not skill_history:
            return None
            
        last_skill = skill_history[-1].lower()
        
        # Check if last skill is part of a combo
        for job_combos in self.combos.values():
            for combo in job_combos:
                for i, step in enumerate(combo.steps):
                    if step.skill_name.lower() == last_skill:
                        # Return next skill if available
                        if i + 1 < len(combo.steps):
                            return combo.steps[i + 1].skill_name
        
        return None
    
    def check_combo(self, skill_name: str) -> dict | None:
        """
        Check if skill starts or continues a combo.
        
        Args:
            skill_name: Name of skill to check
            
        Returns:
            Combo info dict or None if no combo found
        """
        # Check if skill is part of any combo
        for job_combos in self.combos.values():
            for combo in job_combos:
                # Check if skill is in this combo
                for step in combo.steps:
                    if step.skill_name.lower() == skill_name.lower():
                        return {
                            "combo_id": combo.combo_id,
                            "combo_name": combo.combo_name,
                            "skill_name": step.skill_name,
                            "skill_level": step.skill_level,
                            "is_starter": combo.steps[0].skill_name.lower() == skill_name.lower(),
                            "total_steps": len(combo.steps),
                        }
        
        return None
        
    async def start_combo(self, combo_id: str) -> Optional[ComboState]:
        """
        Initialize combo execution.
        
        Args:
            combo_id: ID of combo to start
            
        Returns:
            ComboState or None if combo not found
        """
        # Find combo definition
        combo_def = None
        for job_combos in self.combos.values():
            for combo in job_combos:
                if combo.combo_id == combo_id:
                    combo_def = combo
                    break
            if combo_def:
                break
                
        if not combo_def:
            self.log.error("combo_not_found", combo_id=combo_id)
            return None
            
        # Create state
        self.current_combo = ComboState(
            combo_id=combo_id,
            current_step=0,
            started_at=datetime.now(),
        )
        self._active_combo_def = combo_def
        
        self.log.info(
            "combo_started",
            combo=combo_def.combo_name,
            steps=len(combo_def.steps),
        )
        
        return self.current_combo
        
    async def get_next_skill(self) -> Optional[ComboStep]:
        """
        Get next skill in combo sequence.
        
        Returns:
            Next ComboStep or None if combo complete
        """
        if not self.current_combo or not self._active_combo_def:
            return None
            
        # Check if combo complete
        if self.current_combo.current_step >= len(self._active_combo_def.steps):
            return None
            
        next_step = self._active_combo_def.steps[self.current_combo.current_step]
        
        self.log.debug(
            "next_combo_skill",
            step=self.current_combo.current_step + 1,
            total=len(self._active_combo_def.steps),
            skill=next_step.skill_name,
        )
        
        return next_step
        
    async def record_skill_result(self, hit: bool, damage: int) -> None:
        """
        Record result of skill execution.
        
        Args:
            hit: Whether skill hit
            damage: Damage dealt
        """
        if not self.current_combo or not self._active_combo_def:
            return
            
        # Update state
        self.current_combo.last_skill_at = datetime.now()
        if hit:
            self.current_combo.hits_landed += 1
        self.current_combo.damage_dealt += damage
        
        # Check if this step requires hit to continue
        current_step = self._active_combo_def.steps[self.current_combo.current_step]
        if current_step.requires_hit and not hit:
            self.log.warning(
                "combo_interrupted_miss",
                combo=self._active_combo_def.combo_name,
                step=self.current_combo.current_step + 1,
            )
            await self.abort_combo()
            return
            
        # Advance to next step
        self.current_combo.current_step += 1
        
        self.log.debug(
            "combo_step_completed",
            step=self.current_combo.current_step,
            hit=hit,
            damage=damage,
        )
        
    async def should_abort_combo(
        self,
        current_hp_percent: float,
        target_died: bool = False,
    ) -> bool:
        """
        Determine if combo should be aborted.
        
        Args:
            current_hp_percent: Current HP percentage (0.0-1.0)
            target_died: Whether target died
            
        Returns:
            True if should abort
        """
        if not self.current_combo:
            return False
            
        # Abort if target died
        if target_died and self._active_combo_def and self._active_combo_def.requires_target:
            self.log.info("combo_aborted_target_died")
            return True
            
        # Abort if critically low HP
        if current_hp_percent < 0.15:
            self.log.warning("combo_aborted_low_hp", hp=current_hp_percent)
            return True
            
        return False
        
    async def abort_combo(self) -> None:
        """Abort current combo."""
        if self.current_combo:
            self.log.warning(
                "combo_aborted",
                combo_id=self.current_combo.combo_id,
                step=self.current_combo.current_step,
            )
        self.current_combo = None
        self._active_combo_def = None
        
    async def finish_combo(self) -> dict:
        """
        Complete combo and return stats.
        
        Returns:
            Combo statistics dictionary
        """
        if not self.current_combo or not self._active_combo_def:
            return {}
            
        stats = {
            "combo_id": self.current_combo.combo_id,
            "combo_name": self._active_combo_def.combo_name,
            "completed": self.current_combo.current_step >= len(self._active_combo_def.steps),
            "steps_executed": self.current_combo.current_step,
            "total_steps": len(self._active_combo_def.steps),
            "hits_landed": self.current_combo.hits_landed,
            "damage_dealt": self.current_combo.damage_dealt,
            "duration_ms": self.current_combo.time_in_combo_ms,
        }
        
        self.log.info("combo_finished", **stats)
        
        # Clear state
        self.current_combo = None
        self._active_combo_def = None
        
        return stats


# Alias for backward compatibility
ComboManager = SkillComboEngine