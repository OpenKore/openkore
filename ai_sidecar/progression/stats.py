"""
Stat point distribution engine for autonomous character progression.

Implements intelligent stat allocation based on build templates, diminishing
returns calculations, and RO-specific stat cost formulas.

Features:
- Build templates for different playstyles (DPS, Tank, Mage, etc.)
- Diminishing returns at soft caps (99/130)
- RO stat cost formula: cost = 1 + floor((stat_value - 1) / 10)
- Dynamic reallocation recommendations
- Point-per-level allocation strategy
"""

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field, model_validator

from ai_sidecar.core.state import CharacterState
from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class BuildType(str, Enum):
    """Build archetype enumeration."""
    
    MELEE_DPS = "melee_dps"      # High STR/AGI for physical damage
    AGI_CRIT = "agi_crit"        # Critical hit builds
    TANK = "tank"                # High VIT for tanking
    MAGIC_DPS = "magic_dps"      # High INT/DEX for magic damage
    SUPPORT = "support"          # INT/DEX for healing/buffing
    HYBRID = "hybrid"            # Balanced stats
    CUSTOM = "custom"            # User-defined ratios


class StatRatios(BaseModel):
    """Stat distribution ratios for a build template."""
    
    str_ratio: float = Field(ge=0.0, le=1.0, description="STR allocation ratio")
    agi_ratio: float = Field(ge=0.0, le=1.0, description="AGI allocation ratio")
    vit_ratio: float = Field(ge=0.0, le=1.0, description="VIT allocation ratio")
    int_ratio: float = Field(ge=0.0, le=1.0, description="INT allocation ratio")
    dex_ratio: float = Field(ge=0.0, le=1.0, description="DEX allocation ratio")
    luk_ratio: float = Field(ge=0.0, le=1.0, description="LUK allocation ratio")
    
    @model_validator(mode='after')
    def validate_sum(self) -> 'StatRatios':
        """Ensure ratios sum to approximately 1.0."""
        total = (
            self.str_ratio + self.agi_ratio + self.vit_ratio +
            self.int_ratio + self.dex_ratio + self.luk_ratio
        )
        
        # Allow small floating point error
        if not (0.99 <= total <= 1.01):
            raise ValueError(f"Stat ratios must sum to 1.0, got {total:.3f}")
        
        return self


class StatAllocationPlan(BaseModel):
    """Plan for allocating stat points."""
    
    stat_name: str = Field(description="Stat to allocate (STR/AGI/VIT/INT/DEX/LUK)")
    points: int = Field(ge=1, description="Number of points to allocate")
    target_value: int = Field(description="Target stat value after allocation")
    priority: float = Field(description="Allocation priority score")


class StatDistributionEngine:
    """
    Intelligent stat point allocation engine.
    
    Uses build templates and optimization algorithms to allocate stat points
    efficiently while respecting RO's stat cost mechanics and soft caps.
    
    RO Stat Mechanics:
    - Stats cost more as they increase: cost = 1 + floor((stat_value - 1) / 10)
    - Soft cap at 99 for pre-renewal, 130 with bonuses for renewal
    - Each stat starts at 1
    - Maximum base stat is 99 without bonuses
    """
    
    # Build template definitions (ratios must sum to 1.0)
    BUILD_TEMPLATES: dict[BuildType, StatRatios] = {
        BuildType.MELEE_DPS: StatRatios(
            str_ratio=0.35, agi_ratio=0.25, vit_ratio=0.10,
            int_ratio=0.00, dex_ratio=0.25, luk_ratio=0.05
        ),
        BuildType.AGI_CRIT: StatRatios(
            str_ratio=0.25, agi_ratio=0.35, vit_ratio=0.05,
            int_ratio=0.00, dex_ratio=0.15, luk_ratio=0.20
        ),
        BuildType.TANK: StatRatios(
            str_ratio=0.15, agi_ratio=0.10, vit_ratio=0.40,
            int_ratio=0.05, dex_ratio=0.20, luk_ratio=0.10
        ),
        BuildType.MAGIC_DPS: StatRatios(
            str_ratio=0.00, agi_ratio=0.05, vit_ratio=0.15,
            int_ratio=0.45, dex_ratio=0.30, luk_ratio=0.05
        ),
        BuildType.SUPPORT: StatRatios(
            str_ratio=0.00, agi_ratio=0.10, vit_ratio=0.25,
            int_ratio=0.35, dex_ratio=0.25, luk_ratio=0.05
        ),
        BuildType.HYBRID: StatRatios(
            str_ratio=0.20, agi_ratio=0.15, vit_ratio=0.20,
            int_ratio=0.15, dex_ratio=0.20, luk_ratio=0.10
        ),
    }
    
    # Soft caps for diminishing returns
    SOFT_CAP_PRE_RENEWAL = 99
    SOFT_CAP_RENEWAL = 130
    
    def __init__(
        self,
        build_type: BuildType = BuildType.HYBRID,
        custom_ratios: StatRatios | None = None,
        soft_cap: int = 99
    ):
        """
        Initialize stat distribution engine.
        
        Args:
            build_type: Build archetype to use
            custom_ratios: Custom stat ratios (overrides build_type)
            soft_cap: Soft cap for diminishing returns (99 or 130)
        """
        self.build_type = build_type
        self.soft_cap = soft_cap
        
        if build_type == BuildType.CUSTOM and custom_ratios:
            self.ratios = custom_ratios
        else:
            self.ratios = self.BUILD_TEMPLATES.get(
                build_type,
                self.BUILD_TEMPLATES[BuildType.HYBRID]
            )
    
    @staticmethod
    def calculate_stat_cost(current_value: int) -> int:
        """
        Calculate cost to increase a stat by 1 point.
        
        RO Formula: cost = 1 + floor((stat_value - 1) / 10)
        
        Examples:
        - Stats 1-9: cost 1 point
        - Stats 10-19: cost 2 points
        - Stats 20-29: cost 3 points
        - Stats 90-99: cost 10 points
        
        Args:
            current_value: Current stat value
            
        Returns:
            Number of stat points required to increase by 1
        """
        if current_value < 1:
            current_value = 1
        
        return 1 + ((current_value - 1) // 10)
    
    @staticmethod
    def calculate_total_cost(from_value: int, to_value: int) -> int:
        """
        Calculate total cost to increase stat from one value to another.
        
        Args:
            from_value: Starting stat value
            to_value: Target stat value
            
        Returns:
            Total stat points required
        """
        if to_value <= from_value:
            return 0
        
        total_cost = 0
        for value in range(from_value, to_value):
            total_cost += StatDistributionEngine.calculate_stat_cost(value)
        
        return total_cost
    
    def get_stat_ratios_dict(self) -> dict[str, float]:
        """Get stat ratios as a dictionary."""
        return {
            "STR": self.ratios.str_ratio,
            "AGI": self.ratios.agi_ratio,
            "VIT": self.ratios.vit_ratio,
            "INT": self.ratios.int_ratio,
            "DEX": self.ratios.dex_ratio,
            "LUK": self.ratios.luk_ratio,
        }
    
    def calculate_diminishing_returns_penalty(self, stat_value: int) -> float:
        """
        Calculate penalty factor for stats above soft cap.
        
        Args:
            stat_value: Current stat value
            
        Returns:
            Penalty multiplier (0.0-1.0, where 1.0 = no penalty)
        """
        if stat_value < self.soft_cap:
            return 1.0
        
        # Progressive penalty above soft cap
        excess = stat_value - self.soft_cap
        penalty = 1.0 - (excess * 0.01)  # 1% penalty per point over cap
        
        return max(penalty, 0.5)  # Minimum 50% effectiveness
    
    def calculate_stat_priority(
        self,
        stat_name: str,
        current_value: int,
        total_stats: int
    ) -> float:
        """
        Calculate priority score for allocating to a stat.
        
        Considers:
        1. How far current allocation is from target ratio
        2. Diminishing returns at higher values
        3. Point cost (stats cost more as they increase)
        
        Args:
            stat_name: Stat name (STR/AGI/VIT/INT/DEX/LUK)
            current_value: Current stat value
            total_stats: Sum of all current stats
            
        Returns:
            Priority score (higher = more important to allocate)
        """
        target_ratio = self.get_stat_ratios_dict().get(stat_name, 0.0)
        
        # Skip if target ratio is 0
        if target_ratio == 0.0:
            return 0.0
        
        # Current ratio
        current_ratio = current_value / max(total_stats, 1)
        
        # Base score: how far below target ratio
        ratio_deficit = target_ratio - current_ratio
        
        # Diminishing returns penalty
        dr_penalty = 1.0 - self.calculate_diminishing_returns_penalty(current_value)
        
        # Point cost consideration (higher level stats cost more)
        cost_factor = self.calculate_stat_cost(current_value)
        cost_weight = 1.0 / cost_factor  # Prefer cheaper stats
        
        # Combined priority score
        priority = (ratio_deficit * cost_weight) - dr_penalty
        
        return max(priority, 0.0)
    
    def get_next_stat_allocation(self, character: CharacterState) -> str | None:
        """
        Determine which stat should receive the next point.
        
        Args:
            character: Current character state
            
        Returns:
            Stat name (STR/AGI/VIT/INT/DEX/LUK) or None if no points available
        """
        if character.stat_points <= 0:
            return None
        
        current_stats = {
            "STR": character.str,
            "AGI": character.agi,
            "VIT": character.vit,
            "INT": character.int_stat if hasattr(character, 'int_stat') else character.int,
            "DEX": character.dex,
            "LUK": character.luk,
        }
        
        total = sum(current_stats.values())
        
        # Calculate priorities for each stat
        priorities = {}
        for stat_name, current_value in current_stats.items():
            if current_value >= self.soft_cap:
                # Don't allocate beyond soft cap unless all stats are at cap
                if all(v >= self.soft_cap for v in current_stats.values()):
                    priorities[stat_name] = self.calculate_stat_priority(
                        stat_name, current_value, total
                    )
            else:
                priorities[stat_name] = self.calculate_stat_priority(
                    stat_name, current_value, total
                )
        
        # Return stat with highest priority
        if not priorities:
            return None
        
        return max(priorities.items(), key=lambda x: x[1])[0]
    
    def generate_allocation_plan(
        self,
        character: CharacterState,
        points_to_allocate: int | None = None
    ) -> list[StatAllocationPlan]:
        """
        Generate complete allocation plan for available points.
        
        Args:
            character: Current character state
            points_to_allocate: Number of points to plan for (None = all available)
            
        Returns:
            List of allocation steps in priority order
        """
        points = points_to_allocate or character.stat_points
        
        if points <= 0:
            return []
        
        plan: list[StatAllocationPlan] = []
        
        # Simulate stat allocation
        simulated_stats = {
            "STR": character.str,
            "AGI": character.agi,
            "VIT": character.vit,
            "INT": character.int_stat if hasattr(character, 'int_stat') else character.int,
            "DEX": character.dex,
            "LUK": character.luk,
        }
        
        remaining = points
        
        while remaining > 0:
            # Calculate next stat to allocate
            total = sum(simulated_stats.values())
            priorities = {}
            
            for stat_name, current_value in simulated_stats.items():
                priority = self.calculate_stat_priority(stat_name, current_value, total)
                if priority > 0:
                    priorities[stat_name] = priority
            
            if not priorities:
                logger.warning("No valid stats to allocate, stopping plan generation")
                break
            
            # Get highest priority stat
            next_stat = max(priorities.items(), key=lambda x: x[1])
            stat_name = next_stat[0]
            priority_score = next_stat[1]
            
            # Add to plan
            plan.append(StatAllocationPlan(
                stat_name=stat_name,
                points=1,
                target_value=simulated_stats[stat_name] + 1,
                priority=priority_score
            ))
            
            # Simulate allocation
            simulated_stats[stat_name] += 1
            remaining -= 1
        
        # Consolidate consecutive allocations to same stat
        consolidated: list[StatAllocationPlan] = []
        
        for allocation in plan:
            if consolidated and consolidated[-1].stat_name == allocation.stat_name:
                # Merge with previous allocation
                last = consolidated[-1]
                consolidated[-1] = StatAllocationPlan(
                    stat_name=last.stat_name,
                    points=last.points + allocation.points,
                    target_value=allocation.target_value,
                    priority=last.priority
                )
            else:
                consolidated.append(allocation)
        
        return consolidated
    
    async def allocate_points(self, character: CharacterState) -> list[Action]:
        """
        Auto-allocate all available stat points.
        
        Args:
            character: Current character state
            
        Returns:
            List of stat allocation actions
        """
        if character.stat_points <= 0:
            return []
        
        actions: list[Action] = []
        
        # Generate allocation plan
        plan = self.generate_allocation_plan(character)
        
        if not plan:
            logger.warning(
                "No allocation plan generated",
                stat_points=character.stat_points,
                character=character.name
            )
            return []
        
        logger.info(
            "Stat allocation plan generated",
            character=character.name,
            points=character.stat_points,
            allocations=len(plan)
        )
        
        # Create actions for each allocation
        for allocation in plan:
            action = Action(
                type=ActionType.NOOP,  # Will be replaced with actual stat increase action
                priority=2,  # High priority
                extra={
                    "action_subtype": "add_stat",
                    "stat": allocation.stat_name,
                    "amount": allocation.points,
                    "target_value": allocation.target_value,
                }
            )
            actions.append(action)
            
            logger.debug(
                "Stat allocation queued",
                stat=allocation.stat_name,
                points=allocation.points,
                priority=allocation.priority
            )
        
        return actions
    
    def recommend_build_for_job(self, job_class: str) -> BuildType:
        """
        Recommend build type based on job class.
        
        Args:
            job_class: Current job class name
            
        Returns:
            Recommended build type
        """
        job_lower = job_class.lower()
        
        # Melee DPS classes
        if any(job in job_lower for job in [
            "swordman", "knight", "lord knight", "rune knight",
            "ninja", "gunslinger"
        ]):
            return BuildType.MELEE_DPS
        
        # AGI/Crit classes
        elif any(job in job_lower for job in [
            "thief", "assassin", "rogue", "guillotine cross",
            "shadow chaser"
        ]):
            return BuildType.AGI_CRIT
        
        # Tank classes
        elif any(job in job_lower for job in [
            "crusader", "paladin", "royal guard"
        ]):
            return BuildType.TANK
        
        # Magic DPS classes
        elif any(job in job_lower for job in [
            "mage", "wizard", "high wizard", "warlock",
            "sage", "professor", "sorcerer"
        ]):
            return BuildType.MAGIC_DPS
        
        # Support classes
        elif any(job in job_lower for job in [
            "acolyte", "priest", "high priest", "arch bishop",
            "monk", "champion", "sura",
            "bard", "clown", "dancer", "gypsy", "minstrel", "wanderer"
        ]):
            return BuildType.SUPPORT
        
        # Default to hybrid for unknown classes
        else:
            logger.warning(
                "Unknown job class for build recommendation",
                job_class=job_class,
                using_default="HYBRID"
            )
            return BuildType.HYBRID
    
    def get_stat_distribution_summary(self, character: CharacterState) -> dict[str, Any]:
        """
        Get summary of current stat distribution vs target.
        
        Args:
            character: Current character state
            
        Returns:
            Dictionary with distribution analysis
        """
        current_stats = {
            "STR": character.str,
            "AGI": character.agi,
            "VIT": character.vit,
            "INT": character.int_stat if hasattr(character, 'int_stat') else character.int,
            "DEX": character.dex,
            "LUK": character.luk,
        }
        
        total = sum(current_stats.values())
        target_ratios = self.get_stat_ratios_dict()
        
        # Calculate variance from target
        variance = {}
        for stat_name, current_value in current_stats.items():
            current_ratio = current_value / max(total, 1)
            target_ratio = target_ratios[stat_name]
            variance[stat_name] = {
                "current": current_value,
                "current_ratio": round(current_ratio, 3),
                "target_ratio": round(target_ratio, 3),
                "deficit": round(target_ratio - current_ratio, 3),
                "above_softcap": current_value >= self.soft_cap,
            }
        
        return {
            "build_type": self.build_type.value,
            "total_stats": total,
            "available_points": character.stat_points,
            "soft_cap": self.soft_cap,
            "stats": variance,
        }