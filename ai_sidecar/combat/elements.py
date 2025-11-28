"""
Element System for Advanced Combat Mechanics.

Implements the complete Ragnarok Online element table with damage
calculation, element optimization, and converter/endow management.

Reference: https://irowiki.org/wiki/Element
"""

from __future__ import annotations

from enum import IntEnum
from typing import Dict, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.combat.models import Element


class ElementLevel(IntEnum):
    """Element levels (1-4) for monsters and attacks."""
    LEVEL_1 = 1
    LEVEL_2 = 2
    LEVEL_3 = 3
    LEVEL_4 = 4


class ElementModifier(BaseModel):
    """Element damage modifier calculation result."""
    
    model_config = ConfigDict(frozen=True)
    
    attack_element: Element = Field(description="Attacking element")
    attack_level: int = Field(default=1, ge=1, le=4, description="Attack element level")
    defense_element: Element = Field(description="Defending element")
    defense_level: int = Field(default=1, ge=1, le=4, description="Defense element level")
    modifier: float = Field(description="Damage multiplier")
    is_immune: bool = Field(default=False, description="Target is immune")
    absorbs_damage: bool = Field(default=False, description="Target absorbs damage")
    
    @property
    def effective(self) -> str:
        """Human-readable effectiveness rating."""
        if self.absorbs_damage:
            return "ABSORBS"
        if self.is_immune:
            return "IMMUNE"
        if self.modifier >= 1.75:
            return "SUPER_EFFECTIVE"
        if self.modifier >= 1.25:
            return "EFFECTIVE"
        if self.modifier < 1.0:
            return "WEAK"
        if self.modifier <= 0.5:
            return "RESISTED"
        return "NORMAL"
    
    @property
    def damage_percent(self) -> int:
        """Damage as percentage (100 = normal)."""
        return int(self.modifier * 100)


# Complete RO Element Table
# Format: ELEMENT_TABLE[attack_element][defense_element][defense_level] = modifier
# Negative values = absorption
ELEMENT_TABLE: Dict[Element, Dict[Element, Dict[int, float]]] = {
    Element.NEUTRAL: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.EARTH: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.FIRE: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WIND: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.POISON: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.HOLY: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.DARK: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.GHOST: {1: 0.7, 2: 0.5, 3: 0.25, 4: 0.0},  # Ghost resistant to Neutral
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
    },
    Element.WATER: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 0.25, 2: 0.0, 3: -0.25, 4: -0.5},  # Absorbs at level 3+
        Element.EARTH: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.FIRE: {1: 1.5, 2: 1.75, 3: 2.0, 4: 2.0},
        Element.WIND: {1: 0.9, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.POISON: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.HOLY: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.DARK: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.GHOST: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
    },
    Element.EARTH: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.5, 2: 1.75, 3: 2.0, 4: 2.0},
        Element.EARTH: {1: 0.25, 2: 0.0, 3: -0.25, 4: -0.5},
        Element.FIRE: {1: 0.9, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.WIND: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.POISON: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
        Element.HOLY: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.DARK: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.GHOST: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
    },
    Element.FIRE: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 0.9, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.EARTH: {1: 1.5, 2: 1.75, 3: 2.0, 4: 2.0},
        Element.FIRE: {1: 0.25, 2: 0.0, 3: -0.25, 4: -0.5},
        Element.WIND: {1: 1.5, 2: 1.75, 3: 2.0, 4: 2.0},
        Element.POISON: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.HOLY: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.DARK: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.GHOST: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
    },
    Element.WIND: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.5, 2: 1.75, 3: 2.0, 4: 2.0},
        Element.EARTH: {1: 0.9, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.FIRE: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WIND: {1: 0.25, 2: 0.0, 3: -0.25, 4: -0.5},
        Element.POISON: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.HOLY: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.DARK: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.GHOST: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
    },
    Element.POISON: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.EARTH: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.FIRE: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.WIND: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.POISON: {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0},
        Element.HOLY: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.DARK: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.GHOST: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.UNDEAD: {1: 0.5, 2: 0.25, 3: 0.0, 4: -0.25},
    },
    Element.HOLY: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.EARTH: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.FIRE: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.WIND: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.POISON: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.HOLY: {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0},
        Element.DARK: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
        Element.GHOST: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.UNDEAD: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
    },
    Element.DARK: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.EARTH: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.FIRE: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.WIND: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.POISON: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.HOLY: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
        Element.DARK: {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0},
        Element.GHOST: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.UNDEAD: {1: 0.5, 2: 0.25, 3: 0.0, 4: -0.25},
    },
    Element.GHOST: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.EARTH: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.FIRE: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.WIND: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.POISON: {1: 1.0, 2: 0.75, 3: 0.5, 4: 0.25},
        Element.HOLY: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.DARK: {1: 0.75, 2: 0.5, 3: 0.25, 4: 0.0},
        Element.GHOST: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
        Element.UNDEAD: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
    },
    Element.UNDEAD: {
        Element.NEUTRAL: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.WATER: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
        Element.EARTH: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
        Element.FIRE: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
        Element.WIND: {1: 1.0, 2: 1.0, 3: 1.25, 4: 1.5},
        Element.POISON: {1: 0.5, 2: 0.25, 3: 0.0, 4: -0.25},
        Element.HOLY: {1: 1.25, 2: 1.5, 3: 1.75, 4: 2.0},
        Element.DARK: {1: 0.5, 2: 0.25, 3: 0.0, 4: -0.25},
        Element.GHOST: {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0},
        Element.UNDEAD: {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0},
    },
}


class ElementCalculator:
    """
    Calculate elemental damage modifiers.
    
    Features:
    - Full RO element table lookup
    - Optimal element selection
    - Converter/endow recommendations
    - Element change evaluation
    """
    
    def __init__(self) -> None:
        """Initialize element calculator."""
        self.log = structlog.get_logger(__name__)
        
    def get_modifier(
        self,
        attack_element: Element,
        attack_level: int,
        defense_element: Element,
        defense_level: int,
    ) -> ElementModifier:
        """
        Calculate damage modifier for element interaction.
        
        Args:
            attack_element: Attacking element
            attack_level: Attack element level (1-4)
            defense_element: Defending element  
            defense_level: Defense element level (1-4)
            
        Returns:
            ElementModifier with damage calculation
        """
        # Clamp levels to valid range
        attack_level = max(1, min(4, attack_level))
        defense_level = max(1, min(4, defense_level))
        
        # Lookup modifier
        modifier = ELEMENT_TABLE.get(attack_element, {}).get(
            defense_element, {}
        ).get(defense_level, 1.0)
        
        # Check for special cases
        is_immune = modifier == 0.0
        absorbs_damage = modifier < 0.0
        
        self.log.debug(
            "element_modifier_calculated",
            attack=attack_element.value,
            attack_lvl=attack_level,
            defense=defense_element.value,
            defense_lvl=defense_level,
            modifier=modifier,
            immune=is_immune,
            absorbs=absorbs_damage,
        )
        
        return ElementModifier(
            attack_element=attack_element,
            attack_level=attack_level,
            defense_element=defense_element,
            defense_level=defense_level,
            modifier=abs(modifier) if absorbs_damage else modifier,
            is_immune=is_immune,
            absorbs_damage=absorbs_damage,
        )
        
    def get_optimal_element(
        self,
        target_element: Element,
        target_level: int,
    ) -> Tuple[Element, float]:
        """
        Find best attacking element for target.
        
        Args:
            target_element: Target's element
            target_level: Target's element level
            
        Returns:
            Tuple of (best_element, damage_modifier)
        """
        best_element = Element.NEUTRAL
        best_modifier = 1.0
        
        for attack_elem in Element:
            result = self.get_modifier(
                attack_elem, 1, target_element, target_level
            )
            
            # Skip immune/absorb
            if result.is_immune or result.absorbs_damage:
                continue
                
            if result.modifier > best_modifier:
                best_modifier = result.modifier
                best_element = attack_elem
                
        self.log.info(
            "optimal_element_found",
            target_elem=target_element.value,
            target_lvl=target_level,
            best_elem=best_element.value,
            modifier=best_modifier,
        )
        
        return best_element, best_modifier
        
    def should_change_element(
        self,
        current_element: Element,
        target_element: Element,
        target_level: int,
        change_cost_seconds: float = 5.0,
    ) -> Tuple[bool, Optional[Element]]:
        """
        Determine if changing element is beneficial.
        
        Args:
            current_element: Current attack element
            target_element: Target's element
            target_level: Target's element level
            change_cost_seconds: Time cost to change element
            
        Returns:
            Tuple of (should_change, recommended_element)
        """
        current_result = self.get_modifier(
            current_element, 1, target_element, target_level
        )
        
        # Always change if immune/absorb
        if current_result.is_immune or current_result.absorbs_damage:
            optimal, _ = self.get_optimal_element(target_element, target_level)
            self.log.warning(
                "element_change_critical",
                current=current_element.value,
                reason="immune_or_absorb",
                recommended=optimal.value,
            )
            return True, optimal
            
        optimal_elem, optimal_mod = self.get_optimal_element(
            target_element, target_level
        )
        
        # Change if improvement is significant (>50% more damage)
        improvement = optimal_mod / current_result.modifier
        if improvement >= 1.5:
            self.log.info(
                "element_change_recommended",
                current=current_element.value,
                current_mod=current_result.modifier,
                optimal=optimal_elem.value,
                optimal_mod=optimal_mod,
                improvement=f"{improvement:.1f}x",
            )
            return True, optimal_elem
            
        return False, None
        
    def get_converter_for_element(self, element: Element) -> Optional[str]:
        """
        Get item name for element converter.
        
        Args:
            element: Target element
            
        Returns:
            Converter item name or None
        """
        converters = {
            Element.FIRE: "Flame Heart",
            Element.WATER: "Mystic Frozen",
            Element.WIND: "Rough Wind",
            Element.EARTH: "Great Nature",
        }
        return converters.get(element)
        
    def get_endow_skill_for_element(self, element: Element) -> Optional[str]:
        """
        Get endow skill name for element.
        
        Args:
            element: Target element
            
        Returns:
            Skill name or None
        """
        endows = {
            Element.FIRE: "Endow Blaze",
            Element.WATER: "Endow Tsunami",
            Element.WIND: "Endow Tornado",
            Element.EARTH: "Endow Quake",
            Element.HOLY: "Aspersio",
        }
        return endows.get(element)
        
    def analyze_element_matchup(
        self,
        attack_element: Element,
        defense_element: Element,
        defense_level: int = 1,
    ) -> dict:
        """
        Comprehensive element matchup analysis.
        
        Args:
            attack_element: Attacking element
            defense_element: Defending element
            defense_level: Defense element level
            
        Returns:
            Analysis dictionary with recommendations
        """
        result = self.get_modifier(
            attack_element, 1, defense_element, defense_level
        )
        
        optimal_elem, optimal_mod = self.get_optimal_element(
            defense_element, defense_level
        )
        
        analysis = {
            "current_element": attack_element.value,
            "target_element": defense_element.value,
            "target_level": defense_level,
            "current_modifier": result.modifier,
            "current_effectiveness": result.effective,
            "is_immune": result.is_immune,
            "absorbs_damage": result.absorbs_damage,
            "optimal_element": optimal_elem.value,
            "optimal_modifier": optimal_mod,
            "improvement_factor": (
                optimal_mod / result.modifier if result.modifier > 0 else 0
            ),
            "should_change": result.is_immune
            or result.absorbs_damage
            or optimal_mod >= result.modifier * 1.5,
        }
        
        # Add converter/endow info
        if analysis["should_change"]:
            converter = self.get_converter_for_element(optimal_elem)
            endow = self.get_endow_skill_for_element(optimal_elem)
            analysis["converter_item"] = converter
            analysis["endow_skill"] = endow
            
        return analysis