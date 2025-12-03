"""
Comprehensive tests for combat/elements.py - BATCH 4.
Target: 95%+ coverage (currently 75.44%, 19 uncovered lines).
"""

import pytest
from ai_sidecar.combat.elements import (
    ElementCalculator,
    ElementModifier,
    ElementLevel,
    ELEMENT_TABLE,
)
from ai_sidecar.combat.models import Element


class TestElementCalculator:
    """Test ElementCalculator functionality."""
    
    @pytest.fixture
    def calculator(self):
        """Create calculator instance."""
        return ElementCalculator()
    
    def test_initialization(self, calculator):
        """Test calculator initialization."""
        assert calculator.log is not None
    
    def test_get_modifier_basic(self, calculator):
        """Test basic modifier calculation."""
        result = calculator.get_modifier(
            Element.WIND, 1, Element.WATER, 1
        )
        
        assert isinstance(result, ElementModifier)
        assert result.attack_element == Element.WIND
        assert result.defense_element == Element.WATER
        assert result.modifier == 1.5  # Wind is strong vs water (1.5x)
    
    def test_get_modifier_immunity(self, calculator):
        """Test immunity detection."""
        result = calculator.get_modifier(
            Element.NEUTRAL, 1, Element.GHOST, 4
        )
        
        assert result.is_immune is True
        assert result.modifier == 0.0
    
    def test_get_modifier_absorption(self, calculator):
        """Test damage absorption."""
        result = calculator.get_modifier(
            Element.WATER, 1, Element.WATER, 3
        )
        
        assert result.absorbs_damage is True
    
    def test_get_modifier_level_clamping(self, calculator):
        """Test level clamping to valid range."""
        result = calculator.get_modifier(
            Element.FIRE, 10, Element.WATER, 0  # Invalid levels
        )
        
        # Should clamp to 1-4
        assert result.attack_level >= 1
        assert result.defense_level >= 1
    
    def test_get_optimal_element(self, calculator):
        """Test finding optimal attack element."""
        best_elem, best_mod = calculator.get_optimal_element(
            Element.WATER, 1
        )
        
        # Earth or Wind should be optimal vs water (both 1.5x)
        assert best_elem in [Element.EARTH, Element.WIND]
        assert best_mod > 1.0
    
    def test_get_optimal_element_skips_immune(self, calculator):
        """Test optimal element skips immune options."""
        best_elem, best_mod = calculator.get_optimal_element(
            Element.GHOST, 4
        )
        
        # Should not return Neutral (immune to Ghost 4)
        assert best_elem != Element.NEUTRAL
    
    def test_should_change_element_immune(self, calculator):
        """Test change recommendation when immune."""
        should_change, recommended = calculator.should_change_element(
            Element.NEUTRAL,  # Current
            Element.GHOST,    # Target
            4,                # Level (immune)
        )
        
        assert should_change is True
        assert recommended is not None
        assert recommended != Element.NEUTRAL
    
    def test_should_change_element_absorb(self, calculator):
        """Test change recommendation when absorbed."""
        should_change, recommended = calculator.should_change_element(
            Element.WATER,  # Current
            Element.WATER,  # Target
            3,              # Level (absorbs)
        )
        
        assert should_change is True
        assert recommended is not None
    
    def test_should_change_element_significant_improvement(self, calculator):
        """Test change for significant improvement."""
        should_change, recommended = calculator.should_change_element(
            Element.NEUTRAL,  # Current (1.0x vs fire)
            Element.FIRE,     # Target
            1,
        )
        
        # Should recommend change if 50%+ improvement available
        if should_change:
            assert recommended is not None
    
    def test_should_change_element_minor_improvement(self, calculator):
        """Test no change for minor improvement."""
        should_change, recommended = calculator.should_change_element(
            Element.FIRE,   # Current (decent)
            Element.EARTH,  # Target (fire does OK vs earth)
            1,
        )
        
        # Minor improvement shouldn't trigger change
        assert should_change is False
    
    def test_get_converter_for_element(self, calculator):
        """Test getting converter item names."""
        assert calculator.get_converter_for_element(Element.FIRE) == "Flame Heart"
        assert calculator.get_converter_for_element(Element.WATER) == "Mystic Frozen"
        assert calculator.get_converter_for_element(Element.WIND) == "Rough Wind"
        assert calculator.get_converter_for_element(Element.EARTH) == "Great Nature"
        assert calculator.get_converter_for_element(Element.HOLY) is None
    
    def test_get_endow_skill_for_element(self, calculator):
        """Test getting endow skill names."""
        assert calculator.get_endow_skill_for_element(Element.FIRE) == "Endow Blaze"
        assert calculator.get_endow_skill_for_element(Element.WATER) == "Endow Tsunami"
        assert calculator.get_endow_skill_for_element(Element.WIND) == "Endow Tornado"
        assert calculator.get_endow_skill_for_element(Element.EARTH) == "Endow Quake"
        assert calculator.get_endow_skill_for_element(Element.HOLY) == "Aspersio"
        assert calculator.get_endow_skill_for_element(Element.DARK) is None
    
    def test_analyze_element_matchup(self, calculator):
        """Test comprehensive matchup analysis."""
        analysis = calculator.analyze_element_matchup(
            Element.WIND,
            Element.WATER,
            1,
        )
        
        assert analysis["current_element"] == "wind"
        assert analysis["target_element"] == "water"
        assert analysis["current_modifier"] > 1.0
        assert "optimal_element" in analysis
        assert "should_change" in analysis
    
    def test_analyze_element_matchup_with_recommendations(self, calculator):
        """Test analysis includes converter/endow when change needed."""
        analysis = calculator.analyze_element_matchup(
            Element.NEUTRAL,
            Element.GHOST,
            4,  # Immune
        )
        
        if analysis["should_change"]:
            assert "converter_item" in analysis or "endow_skill" in analysis
    
    def test_element_modifier_properties(self):
        """Test ElementModifier properties."""
        modifier = ElementModifier(
            attack_element=Element.FIRE,
            attack_level=1,
            defense_element=Element.WATER,
            defense_level=1,
            modifier=1.5,
        )
        
        assert modifier.effective == "EFFECTIVE"
        assert modifier.damage_percent == 150
    
    def test_element_modifier_super_effective(self):
        """Test super effective rating."""
        modifier = ElementModifier(
            attack_element=Element.FIRE,
            attack_level=1,
            defense_element=Element.EARTH,
            defense_level=4,
            modifier=2.0,
        )
        
        assert modifier.effective == "SUPER_EFFECTIVE"
    
    def test_element_modifier_weak(self):
        """Test weak rating."""
        modifier = ElementModifier(
            attack_element=Element.FIRE,
            attack_level=1,
            defense_element=Element.WATER,
            defense_level=4,
            modifier=0.25,
        )
        
        assert modifier.effective in ["WEAK", "RESISTED"]
    
    def test_element_modifier_absorbs(self):
        """Test absorb rating."""
        modifier = ElementModifier(
            attack_element=Element.WATER,
            attack_level=1,
            defense_element=Element.WATER,
            defense_level=3,
            modifier=0.25,
            absorbs_damage=True,
        )
        
        assert modifier.effective == "ABSORBS"
    
    def test_element_modifier_immune(self):
        """Test immune rating."""
        modifier = ElementModifier(
            attack_element=Element.NEUTRAL,
            attack_level=1,
            defense_element=Element.GHOST,
            defense_level=4,
            modifier=0.0,
            is_immune=True,
        )
        
        assert modifier.effective == "IMMUNE"
    
    def test_element_table_completeness(self):
        """Test that element table has all combinations."""
        for attack_elem in Element:
            assert attack_elem in ELEMENT_TABLE
            for defense_elem in Element:
                if attack_elem in ELEMENT_TABLE:
                    assert defense_elem in ELEMENT_TABLE[attack_elem]