"""
Critical Hit System for Advanced Combat Mechanics.

Implements critical hit rate calculation, critical damage calculation,
and optimization recommendations for critical-focused builds.

Reference: https://irowiki.org/wiki/Critical
"""

from __future__ import annotations

from typing import Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict


class CriticalStats(BaseModel):
    """Critical hit statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    crit_rate: float = Field(default=1.0, ge=0.0, description="Base crit % (LUK based)")
    crit_damage: float = Field(default=1.4, ge=1.0, description="Base 40% bonus (140%)")
    crit_bonus_flat: int = Field(default=0, ge=0, description="Flat crit bonus from cards/equips")
    crit_damage_bonus: float = Field(default=0.0, ge=0.0, description="Additional crit damage bonus")
    
    # Calculated
    effective_crit_rate: float = Field(default=1.0, ge=0.0, description="Final crit rate")
    effective_crit_damage: float = Field(default=1.4, ge=1.0, description="Final crit damage multiplier")


class CriticalCalculator:
    """
    Calculate critical hit mechanics.
    
    Features:
    - Crit rate calculation
    - Crit damage calculation
    - Target LUK reduction
    - Critical vs non-critical DPS comparison
    - Optimal crit gear recommendations
    """
    
    def __init__(self) -> None:
        """Initialize critical calculator."""
        self.log = structlog.get_logger(__name__)
        
    def calculate_crit_rate(self, attacker_luk: int, defender_luk: int = 0) -> float:
        """
        Calculate critical hit rate.
        
        Crit = 1 + (Attacker_LUK * 0.3) - (Defender_LUK * 0.2)
        
        Args:
            attacker_luk: Attacker's LUK stat
            defender_luk: Defender's LUK stat (reduces crit rate)
            
        Returns:
            Critical hit rate percentage (0.0-100.0)
        """
        base_crit = 1.0 + (attacker_luk * 0.3) - (defender_luk * 0.2)
        crit_rate = max(1.0, min(100.0, base_crit))  # Clamp 1-100%
        
        self.log.debug(
            "crit_rate_calculated",
            attacker_luk=attacker_luk,
            defender_luk=defender_luk,
            crit_rate=crit_rate,
        )
        
        return crit_rate
        
    def calculate_crit_damage(
        self,
        base_damage: int,
        luk: int = 0,
        crit_damage_bonus: float = 0.0,
    ) -> int:
        """
        Calculate critical hit damage.
        
        Base crit = 140% damage + LUK scaling
        Additional bonuses stack additively
        
        Args:
            base_damage: Base damage before crit
            luk: Character's LUK stat (adds minor bonus)
            crit_damage_bonus: Additional crit damage bonus (0.0-1.0)
            
        Returns:
            Critical hit damage
        """
        # LUK adds minor crit damage scaling (0.1% per point)
        luk_bonus = luk * 0.001
        total_multiplier = 1.4 + luk_bonus + crit_damage_bonus
        crit_damage = int(base_damage * total_multiplier)
        
        self.log.debug(
            "crit_damage_calculated",
            base=base_damage,
            luk=luk,
            bonus=crit_damage_bonus,
            crit_dmg=crit_damage,
        )
        
        return crit_damage
        
    def calculate_average_dps_with_crit(
        self,
        base_damage: int,
        crit_rate: float,
        crit_damage_multiplier: float,
        attack_speed: float = 1.0,
    ) -> float:
        """
        Calculate average DPS including crits.
        
        Average DPS = (Normal_DMG * (100-Crit%) + Crit_DMG * Crit%) * Attack_Speed
        
        Args:
            base_damage: Base damage per hit
            crit_rate: Critical hit rate (0.0-100.0)
            crit_damage_multiplier: Crit damage multiplier (1.4 = 140%)
            attack_speed: Attacks per second
            
        Returns:
            Average DPS
        """
        crit_rate_decimal = crit_rate / 100.0
        
        # Calculate weighted damage
        normal_damage_weight = base_damage * (1.0 - crit_rate_decimal)
        crit_damage_weight = (base_damage * crit_damage_multiplier) * crit_rate_decimal
        
        average_damage = normal_damage_weight + crit_damage_weight
        dps = average_damage * attack_speed
        
        self.log.debug(
            "average_dps_calculated",
            base_dmg=base_damage,
            crit_rate=crit_rate,
            crit_mult=crit_damage_multiplier,
            aspd=attack_speed,
            dps=dps,
        )
        
        return dps
        
    def is_crit_build_worth(
        self,
        current_crit_rate: float,
        current_crit_damage: float,
        str_or_dex_alternative: int,
        base_damage_with_stats: int = 100,
    ) -> Tuple[bool, str]:
        """
        Compare crit build vs pure stat build.
        
        Args:
            current_crit_rate: Current crit rate (%)
            current_crit_damage: Current crit damage multiplier
            str_or_dex_alternative: How much STR/DEX could invest instead
            base_damage_with_stats: Expected damage with stat investment
            
        Returns:
            Tuple of (is_worth_it, explanation)
        """
        # Calculate crit build DPS (assume 100 base)
        crit_dps = self.calculate_average_dps_with_crit(
            100, current_crit_rate, current_crit_damage
        )
        
        # Calculate stat build DPS (higher base, no crit bonus)
        # Rough estimate: +1 STR = +1% damage
        stat_multiplier = 1.0 + (str_or_dex_alternative * 0.01)
        stat_dps = base_damage_with_stats * stat_multiplier
        
        is_worth = crit_dps >= stat_dps
        
        explanation = (
            f"Crit DPS: {crit_dps:.1f} vs Stat DPS: {stat_dps:.1f} "
            f"({'Worth' if is_worth else 'Not worth'} it)"
        )
        
        self.log.info(
            "crit_build_comparison",
            crit_dps=crit_dps,
            stat_dps=stat_dps,
            is_worth=is_worth,
        )
        
        return is_worth, explanation
        
    async def get_crit_optimization(
        self,
        current_stats: CriticalStats,
        target_luk: int = 0,
        current_luk: int = 1,
    ) -> dict:
        """
        Get recommendations for crit optimization.
        
        Args:
            current_stats: Current critical stats
            target_luk: Target's LUK (reduces crit)
            current_luk: Character's current LUK
            
        Returns:
            Optimization recommendations
        """
        # Calculate current effective rate (base + flat bonus)
        base_rate = self.calculate_crit_rate(current_luk, target_luk)
        current_rate = base_rate + current_stats.crit_bonus_flat
        
        # Calculate needed LUK for 50% crit
        # Crit = 1 + (LUK * 0.3) + Bonus - (Target_LUK * 0.2)
        # 50 = 1 + (LUK * 0.3) + Bonus - (Target_LUK * 0.2)
        # Solve for LUK:
        target_reduction = target_luk * 0.2
        needed_luk_for_50 = int(
            (50 - 1 - current_stats.crit_bonus_flat + target_reduction) / 0.3
        )
        luk_gap = max(0, needed_luk_for_50 - current_luk)
        
        # Calculate potential DPS improvement
        current_dps = self.calculate_average_dps_with_crit(
            100,
            current_rate,
            current_stats.effective_crit_damage,
        )
        
        optimal_dps = self.calculate_average_dps_with_crit(
            100,
            50.0,  # 50% crit
            current_stats.effective_crit_damage,
        )
        
        improvement = (optimal_dps / current_dps) if current_dps > 0 else 1.0
        
        recommendation = {
            "current_crit_rate": current_rate,
            "current_crit_damage_mult": current_stats.effective_crit_damage,
            "current_luk": current_luk,
            "needed_luk_for_50_crit": needed_luk_for_50,
            "luk_gap": luk_gap,
            "current_dps_relative": current_dps,
            "optimal_dps_relative": optimal_dps,
            "dps_improvement_factor": improvement,
            "recommendation": (
                f"Invest +{luk_gap} LUK for 50% crit rate ({improvement:.1f}x DPS improvement)"
                if luk_gap > 0
                else "Crit rate optimized"
            ),
            "crit_cards_suggested": [
                "Anolian Card (+15 Crit)",
                "Andre Card (+5 Crit)",
                "Zerom Card (+10 Crit, +2 LUK)",
            ]
            if current_rate < 40
            else [],
        }
        
        return recommendation


# Alias for backward compatibility
CriticalHitCalculator = CriticalCalculator