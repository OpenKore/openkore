"""
Flee and Perfect Dodge System for Advanced Combat Mechanics.

Implements flee rate calculation, perfect dodge mechanics, hit accuracy,
and evasion-based tactical decisions.

Reference: https://irowiki.org/wiki/Flee
Reference: https://irowiki.org/wiki/Perfect_Dodge
"""

from __future__ import annotations

from enum import Enum
from typing import Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict


class EvasionResult(str, Enum):
    """Result of evasion check."""
    HIT = "hit"
    MISS = "miss"
    PERFECT_DODGE = "perfect_dodge"


class EvasionStats(BaseModel):
    """Evasion-related statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    flee: int = Field(default=1, ge=1, description="Base flee")
    perfect_dodge: int = Field(default=0, ge=0, description="Lucky stat")
    flee_bonus_percent: float = Field(default=0.0, ge=0.0, description="Flee bonus from skills/items")
    
    # Calculated values
    effective_flee: int = Field(default=1, ge=1, description="Flee after bonuses")
    perfect_dodge_percent: float = Field(default=0.0, ge=0.0, description="Perfect dodge %")


class HitStats(BaseModel):
    """Hit-related statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    hit: int = Field(default=1, ge=1, description="Base hit")
    hit_bonus_percent: float = Field(default=0.0, ge=0.0, description="Hit bonus from skills/items")
    
    # Calculated
    effective_hit: int = Field(default=1, ge=1, description="Hit after bonuses")


class EvasionCalculator:
    """
    Calculate flee and hit mechanics.
    
    Features:
    - Flee rate calculation
    - Perfect dodge calculation
    - Hit accuracy calculation
    - Flee penalty from multiple attackers
    - Optimal flee thresholds
    """
    
    def __init__(self) -> None:
        """Initialize evasion calculator."""
        self.log = structlog.get_logger(__name__)
        
    def calculate_flee(
        self,
        base_level: int,
        agi: int,
        flee_bonus: int = 0,
        flee_bonus_percent: float = 0.0,
    ) -> int:
        """
        Calculate flee.
        
        Flee = Base Level + AGI + Bonus
        
        Args:
            base_level: Character base level
            agi: Character AGI
            flee_bonus: Flat flee bonus
            flee_bonus_percent: Percentage flee bonus
            
        Returns:
            Total flee value
        """
        base_flee = base_level + agi + flee_bonus
        total_flee = int(base_flee * (1.0 + flee_bonus_percent))
        
        self.log.debug(
            "flee_calculated",
            level=base_level,
            agi=agi,
            bonus=flee_bonus,
            flee=total_flee,
        )
        
        return total_flee
        
    def calculate_perfect_dodge(self, luk: int) -> float:
        """
        Calculate perfect dodge chance.
        
        Perfect Dodge = LUK / 10 (in %)
        
        Args:
            luk: Character LUK
            
        Returns:
            Perfect dodge percentage (0.0-100.0)
        """
        perfect_dodge = luk / 10.0
        
        self.log.debug("perfect_dodge_calculated", luk=luk, percent=perfect_dodge)
        
        return perfect_dodge
        
    def calculate_hit_rate(
        self,
        attacker_hit: int,
        defender_flee: int,
        num_attackers: int = 1,
    ) -> float:
        """
        Calculate hit rate.
        
        Hit Rate = 80 + Attacker_Hit - Defender_Flee
        Flee reduces by 10% per extra attacker after first 2
        
        Args:
            attacker_hit: Attacker's hit value
            defender_flee: Defender's flee value
            num_attackers: Number of attackers on defender
            
        Returns:
            Hit rate percentage (0.0-100.0)
        """
        # Apply flee penalty for multiple attackers
        effective_flee = defender_flee
        if num_attackers > 2:
            penalty_multiplier = 1.0 - ((num_attackers - 2) * 0.1)
            penalty_multiplier = max(0.0, penalty_multiplier)
            effective_flee = int(defender_flee * penalty_multiplier)
            
        # Calculate hit rate
        hit_rate = 80.0 + attacker_hit - effective_flee
        hit_rate = max(5.0, min(95.0, hit_rate))  # Clamp 5-95%
        
        self.log.debug(
            "hit_rate_calculated",
            attacker_hit=attacker_hit,
            defender_flee=defender_flee,
            num_attackers=num_attackers,
            effective_flee=effective_flee,
            hit_rate=hit_rate,
        )
        
        return hit_rate
        
    def calculate_flee_needed(
        self,
        monster_hit: int,
        desired_miss_rate: float = 0.95,
    ) -> int:
        """
        Calculate flee needed for desired miss rate.
        
        Args:
            monster_hit: Monster's hit value
            desired_miss_rate: Desired miss rate (0.0-1.0)
            
        Returns:
            Required flee value
        """
        # Hit Rate = 80 + Monster_Hit - Flee
        # Miss Rate = 1 - (Hit Rate / 100)
        # Solve for Flee:
        target_hit_rate = (1.0 - desired_miss_rate) * 100
        required_flee = int(80 + monster_hit - target_hit_rate)
        
        self.log.info(
            "flee_needed_calculated",
            monster_hit=monster_hit,
            desired_miss=desired_miss_rate,
            required_flee=required_flee,
        )
        
        return required_flee
        
    def is_flee_viable(
        self,
        player_flee: int,
        monster_hit: int,
        monster_count: int,
    ) -> Tuple[bool, float]:
        """
        Check if flee build is viable against monsters.
        
        Args:
            player_flee: Player's flee value
            monster_hit: Monster's hit value
            monster_count: Number of monsters
            
        Returns:
            Tuple of (viable, actual_miss_rate)
        """
        hit_rate = self.calculate_hit_rate(monster_hit, player_flee, monster_count)
        miss_rate = 1.0 - (hit_rate / 100.0)
        
        # Consider viable if miss rate >= 80%
        viable = miss_rate >= 0.80
        
        self.log.info(
            "flee_viability_check",
            flee=player_flee,
            monster_hit=monster_hit,
            count=monster_count,
            miss_rate=miss_rate,
            viable=viable,
        )
        
        return viable, miss_rate
        
    async def get_evasion_recommendation(
        self,
        current_stats: EvasionStats,
        monster_data: dict,
    ) -> dict:
        """
        Get recommendations for evasion against monster.
        
        Args:
            current_stats: Current evasion stats
            monster_data: Monster info dict
            
        Returns:
            Recommendation dictionary
        """
        monster_hit = monster_data.get("hit", 100)
        monster_count = monster_data.get("count", 1)
        
        # Calculate current performance
        current_hit_rate = self.calculate_hit_rate(
            monster_hit,
            current_stats.effective_flee,
            monster_count,
        )
        current_miss_rate = 1.0 - (current_hit_rate / 100.0)
        
        # Calculate needed flee for 95% miss rate
        needed_flee = self.calculate_flee_needed(monster_hit, 0.95)
        flee_gap = needed_flee - current_stats.effective_flee
        
        # Estimate AGI needed to close gap
        # Assuming flee_bonus stays constant
        agi_needed = flee_gap if flee_gap > 0 else 0
        
        recommendation = {
            "current_flee": current_stats.effective_flee,
            "current_miss_rate": current_miss_rate,
            "current_hit_rate": current_hit_rate / 100.0,
            "perfect_dodge_chance": current_stats.perfect_dodge_percent / 100.0,
            "flee_needed_95": needed_flee,
            "flee_gap": flee_gap,
            "agi_investment_needed": agi_needed,
            "flee_viable": flee_gap <= 0,
            "recommendation": (
                "Flee build viable" if flee_gap <= 0
                else f"Need +{flee_gap} flee (+{agi_needed} AGI)"
            ),
        }
        
        return recommendation