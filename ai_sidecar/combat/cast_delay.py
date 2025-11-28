"""
Cast and Delay Management System for Advanced Combat Mechanics.

Implements accurate cast time calculation with DEX/INT reduction,
after-cast delay tracking, skill cooldown management, and optimal
skill timing for maximum DPS.

Reference: https://irowiki.org/wiki/Cast_Time
Reference: https://irowiki.org/wiki/Delay
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict


class CastType(str, Enum):
    """Types of skill casting."""
    INSTANT = "instant"
    FIXED_CAST = "fixed_cast"
    VARIABLE_CAST = "variable_cast"
    COMBINED = "combined"
    CHANNELED = "channeled"


class SkillTiming(BaseModel):
    """Timing information for a skill."""
    
    model_config = ConfigDict(frozen=False)
    
    skill_name: str = Field(description="Skill name")
    
    # Base cast times (milliseconds)
    fixed_cast_ms: int = Field(default=0, ge=0, description="Fixed cast time")
    variable_cast_ms: int = Field(default=0, ge=0, description="Variable cast time")
    
    # Delays (milliseconds)
    after_cast_delay_ms: int = Field(default=0, ge=0, description="Global cooldown")
    skill_cooldown_ms: int = Field(default=0, ge=0, description="Skill-specific cooldown")
    animation_delay_ms: int = Field(default=0, ge=0, description="Animation lock")
    
    # Applied reductions
    cast_reduction_percent: float = Field(default=0.0, ge=0.0, le=1.0, description="Cast reduction")
    delay_reduction_percent: float = Field(default=0.0, ge=0.0, le=1.0, description="Delay reduction")
    
    @property
    def total_cast_time_ms(self) -> int:
        """Total time to cast skill."""
        return self.fixed_cast_ms + self.variable_cast_ms
        
    @property
    def total_commitment_ms(self) -> int:
        """Total time committed to this skill."""
        return (
            self.total_cast_time_ms
            + self.after_cast_delay_ms
            + self.animation_delay_ms
        )
        
    @property
    def effective_dps_window_ms(self) -> int:
        """Time until next action possible."""
        return max(
            self.after_cast_delay_ms,
            self.animation_delay_ms,
            self.skill_cooldown_ms,
        )


class CastState(BaseModel):
    """Current casting state."""
    
    model_config = ConfigDict(frozen=False)
    
    is_casting: bool = Field(default=False, description="Currently casting")
    skill_name: Optional[str] = Field(default=None, description="Skill being cast")
    cast_started: Optional[datetime] = Field(default=None, description="Cast start time")
    cast_end_estimate: Optional[datetime] = Field(default=None, description="Expected end time")
    can_be_interrupted: bool = Field(default=True, description="Can be interrupted")


class DelayState(BaseModel):
    """Current delay state."""
    
    model_config = ConfigDict(frozen=False)
    
    in_after_cast_delay: bool = Field(default=False, description="In global cooldown")
    delay_ends: Optional[datetime] = Field(default=None, description="Delay end time")
    in_animation: bool = Field(default=False, description="Animation locked")
    animation_ends: Optional[datetime] = Field(default=None, description="Animation end time")
    skill_cooldowns: Dict[str, datetime] = Field(default_factory=dict, description="Skill cooldowns")


class CastDelayManager:
    """
    Manage casting and delay timings.
    
    Features:
    - Accurate cast time calculation with stats
    - After-cast delay tracking
    - Skill cooldown management
    - Cast interruption detection
    - Optimal skill timing
    """
    
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        """
        Initialize cast/delay manager.
        
        Args:
            data_dir: Directory containing skill timing data
        """
        self.log = structlog.get_logger(__name__)
        
        # Skill timing database
        self.skill_timings: Dict[str, SkillTiming] = {}
        
        # Current state
        self.cast_state = CastState()
        self.delay_state = DelayState()
        
        # Load timing data
        if data_dir:
            self._load_skill_timings(data_dir)
        else:
            self._initialize_default_timings()
            
    def _initialize_default_timings(self) -> None:
        """Initialize with common skill timings."""
        default_timings = [
            SkillTiming(
                skill_name="Storm Gust",
                fixed_cast_ms=1000,
                variable_cast_ms=6000,
                after_cast_delay_ms=5000,
            ),
            SkillTiming(
                skill_name="Meteor Storm",
                fixed_cast_ms=1500,
                variable_cast_ms=7000,
                after_cast_delay_ms=5000,
            ),
            SkillTiming(
                skill_name="Sonic Blow",
                fixed_cast_ms=0,
                variable_cast_ms=0,
                after_cast_delay_ms=2000,
                animation_delay_ms=500,
            ),
            SkillTiming(
                skill_name="Spiral Pierce",
                fixed_cast_ms=0,
                variable_cast_ms=0,
                after_cast_delay_ms=1500,
                animation_delay_ms=300,
            ),
            SkillTiming(
                skill_name="Asura Strike",
                fixed_cast_ms=1000,
                variable_cast_ms=2000,
                after_cast_delay_ms=3000,
                skill_cooldown_ms=10000,
            ),
        ]
        
        for timing in default_timings:
            self.skill_timings[timing.skill_name.lower()] = timing
            
        self.log.info("initialized_default_timings", count=len(default_timings))
        
    def _load_skill_timings(self, data_dir: Path) -> None:
        """Load skill timing data from JSON."""
        timing_file = data_dir / "skill_timings.json"
        
        if not timing_file.exists():
            self.log.warning("timing_data_not_found", path=str(timing_file))
            self._initialize_default_timings()
            return
            
        try:
            with open(timing_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                
            for skill_name, timing_data in data.items():
                timing = SkillTiming(skill_name=skill_name, **timing_data)
                self.skill_timings[skill_name.lower()] = timing
                
            self.log.info("loaded_timing_data", path=str(timing_file), skills=len(self.skill_timings))
            
        except Exception as e:
            self.log.error("failed_to_load_timing_data", path=str(timing_file), error=str(e))
            self._initialize_default_timings()
            
    def calculate_cast_time(
        self,
        skill_name: str,
        dex: int,
        int_stat: int,
        cast_reduction_gear: float = 0.0,
    ) -> SkillTiming:
        """
        Calculate actual cast time based on stats.
        
        Variable Cast = Base * (1 - (DEX*2 + INT) / 530)
        Max reduction: 80% (DEX*2 + INT = 265)
        
        Args:
            skill_name: Skill name
            dex: Character DEX
            int_stat: Character INT
            cast_reduction_gear: Additional reduction from gear (0.0-1.0)
            
        Returns:
            SkillTiming with calculated cast time
        """
        base_timing = self.skill_timings.get(skill_name.lower())
        
        if not base_timing:
            self.log.warning("timing_not_found", skill=skill_name)
            return SkillTiming(skill_name=skill_name)
            
        # Calculate stat reduction
        stat_sum = (dex * 2) + int_stat
        stat_reduction = min(stat_sum / 530.0, 0.8)  # Max 80%
        
        # Total reduction (stats + gear)
        total_reduction = min(stat_reduction + cast_reduction_gear, 0.999)
        
        # Apply to variable cast
        reduced_variable = int(base_timing.variable_cast_ms * (1.0 - total_reduction))
        
        # Create adjusted timing
        adjusted = SkillTiming(
            skill_name=skill_name,
            fixed_cast_ms=base_timing.fixed_cast_ms,
            variable_cast_ms=reduced_variable,
            after_cast_delay_ms=base_timing.after_cast_delay_ms,
            skill_cooldown_ms=base_timing.skill_cooldown_ms,
            animation_delay_ms=base_timing.animation_delay_ms,
            cast_reduction_percent=total_reduction,
        )
        
        self.log.debug(
            "cast_time_calculated",
            skill=skill_name,
            dex=dex,
            int_stat=int_stat,
            reduction=total_reduction,
            variable_ms=reduced_variable,
        )
        
        return adjusted
        
    def calculate_after_cast_delay(
        self,
        skill_name: str,
        agi: int,
        delay_reduction_gear: float = 0.0,
    ) -> int:
        """
        Calculate after-cast delay.
        
        Delay = Base * (1 - (AGI / 250))
        Max reduction: ~80% at 200 AGI
        
        Args:
            skill_name: Skill name
            agi: Character AGI
            delay_reduction_gear: Additional reduction from gear
            
        Returns:
            After-cast delay in milliseconds
        """
        base_timing = self.skill_timings.get(skill_name.lower())
        
        if not base_timing or base_timing.after_cast_delay_ms == 0:
            return 0
            
        # Calculate AGI reduction
        agi_reduction = min(agi / 250.0, 0.8)
        
        # Total reduction
        total_reduction = min(agi_reduction + delay_reduction_gear, 0.999)
        
        # Apply reduction
        reduced_delay = int(base_timing.after_cast_delay_ms * (1.0 - total_reduction))
        
        self.log.debug(
            "delay_calculated",
            skill=skill_name,
            agi=agi,
            reduction=total_reduction,
            delay_ms=reduced_delay,
        )
        
        return reduced_delay
        
    async def start_cast(self, skill_name: str, cast_time_ms: int) -> None:
        """
        Record cast start.
        
        Args:
            skill_name: Skill being cast
            cast_time_ms: Total cast time
        """
        now = datetime.now()
        
        self.cast_state = CastState(
            is_casting=True,
            skill_name=skill_name,
            cast_started=now,
            cast_end_estimate=now + timedelta(milliseconds=cast_time_ms),
            can_be_interrupted=True,
        )
        
        self.log.info("cast_started", skill=skill_name, duration_ms=cast_time_ms)
        
    async def cast_complete(self, skill_name: str, delay_ms: int) -> None:
        """
        Mark cast as complete and start delay.
        
        Args:
            skill_name: Completed skill
            delay_ms: After-cast delay duration
        """
        self.cast_state = CastState()
        
        # Start after-cast delay
        now = datetime.now()
        self.delay_state.in_after_cast_delay = True
        self.delay_state.delay_ends = now + timedelta(milliseconds=delay_ms)
        
        # Add skill cooldown if applicable
        base_timing = self.skill_timings.get(skill_name.lower())
        if base_timing and base_timing.skill_cooldown_ms > 0:
            cooldown_end = now + timedelta(milliseconds=base_timing.skill_cooldown_ms)
            self.delay_state.skill_cooldowns[skill_name.lower()] = cooldown_end
            
        self.log.info(
            "cast_complete",
            skill=skill_name,
            delay_ms=delay_ms,
            cooldown_ms=base_timing.skill_cooldown_ms if base_timing else 0,
        )
        
    async def cast_interrupted(self) -> None:
        """Handle cast interruption."""
        if self.cast_state.skill_name:
            self.log.warning("cast_interrupted", skill=self.cast_state.skill_name)
        self.cast_state = CastState()
        
    async def can_cast_now(self) -> Tuple[bool, Optional[str]]:
        """
        Check if casting is possible now.
        
        Returns:
            Tuple of (can_cast, reason_if_not)
        """
        # Already casting
        if self.cast_state.is_casting:
            return False, "already_casting"
            
        # In after-cast delay
        if self.delay_state.in_after_cast_delay:
            if self.delay_state.delay_ends and datetime.now() < self.delay_state.delay_ends:
                return False, "after_cast_delay"
            else:
                # Delay expired
                self.delay_state.in_after_cast_delay = False
                self.delay_state.delay_ends = None
                
        # In animation
        if self.delay_state.in_animation:
            if self.delay_state.animation_ends and datetime.now() < self.delay_state.animation_ends:
                return False, "animation_delay"
            else:
                # Animation done
                self.delay_state.in_animation = False
                self.delay_state.animation_ends = None
                
        return True, None
        
    async def time_until_can_cast(self) -> int:
        """
        Calculate milliseconds until can cast.
        
        Returns:
            Milliseconds until can cast (0 if can cast now)
        """
        can_cast, reason = await self.can_cast_now()
        
        if can_cast:
            return 0
            
        now = datetime.now()
        delays = []
        
        # Check cast end
        if self.cast_state.cast_end_estimate:
            remaining = (self.cast_state.cast_end_estimate - now).total_seconds() * 1000
            if remaining > 0:
                delays.append(int(remaining))
                
        # Check after-cast delay
        if self.delay_state.delay_ends:
            remaining = (self.delay_state.delay_ends - now).total_seconds() * 1000
            if remaining > 0:
                delays.append(int(remaining))
                
        # Check animation
        if self.delay_state.animation_ends:
            remaining = (self.delay_state.animation_ends - now).total_seconds() * 1000
            if remaining > 0:
                delays.append(int(remaining))
                
        return max(delays) if delays else 0
        
    async def is_skill_on_cooldown(self, skill_name: str) -> Tuple[bool, int]:
        """
        Check skill cooldown status.
        
        Args:
            skill_name: Skill to check
            
        Returns:
            Tuple of (on_cooldown, remaining_ms)
        """
        skill_key = skill_name.lower()
        
        if skill_key not in self.delay_state.skill_cooldowns:
            return False, 0
            
        cooldown_end = self.delay_state.skill_cooldowns[skill_key]
        now = datetime.now()
        
        if now >= cooldown_end:
            # Cooldown expired
            del self.delay_state.skill_cooldowns[skill_key]
            return False, 0
            
        remaining = (cooldown_end - now).total_seconds() * 1000
        return True, int(remaining)
        
    async def get_optimal_skill_order(
        self,
        skills: List[str],
        character_stats: dict,
    ) -> List[str]:
        """
        Order skills for maximum DPS considering delays.
        
        Args:
            skills: Available skills
            character_stats: Character stats dict
            
        Returns:
            Optimized skill order
        """
        # Calculate efficiency for each skill
        skill_efficiency = []
        
        for skill_name in skills:
            timing = self.calculate_cast_time(
                skill_name,
                character_stats.get("dex", 1),
                character_stats.get("int", 1),
            )
            
            # Efficiency = damage potential / time commitment
            # For now, use inverse of commitment time
            if timing.total_commitment_ms > 0:
                efficiency = 1000.0 / timing.total_commitment_ms
            else:
                efficiency = 100.0
                
            skill_efficiency.append((skill_name, efficiency))
            
        # Sort by efficiency
        skill_efficiency.sort(key=lambda x: x[1], reverse=True)
        ordered = [s[0] for s in skill_efficiency]
        
        self.log.debug("skill_order_optimized", order=ordered)
        
        return ordered