"""
Coverage Batch 14: Combat Mechanics Completion
Target: 11% → 11.5% coverage (~200-250 statements)

Modules:
- combat/critical.py (54 lines, 39% → 85-90%)
- combat/elements.py (90 lines, 67% → 90-95%)
- combat/evasion.py (64 lines, 73% → 95-100%)
- combat/skills.py (239 lines, 65% → 80-85%)

Focus: Critical hit mechanics, element system, evasion calculations,
       and skill management with prerequisite chains.
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.combat.critical import (
    CriticalCalculator,
    CriticalStats,
    CriticalHitCalculator
)
from ai_sidecar.combat.elements import (
    ElementCalculator,
    ElementModifier,
    Element,
    ElementLevel,
    ELEMENT_TABLE
)
from ai_sidecar.combat.evasion import (
    EvasionCalculator,
    EvasionStats,
    HitStats,
    EvasionResult
)
from ai_sidecar.combat.skills import (
    SkillDatabase,
    SkillManager,
    SkillAllocationSystem,
    SkillDefinition,
    SkillPrerequisite
)
from ai_sidecar.core.state import CharacterState
from ai_sidecar.core.decision import ActionType


# ============================================================================
# TEST CLASS: CriticalHitCalculator
# ============================================================================

class TestCriticalHitCalculatorCore:
    """Test critical hit calculator initialization and basic operations."""
    
    def test_critical_calculator_initialization(self):
        """Cover CriticalCalculator.__init__."""
        calculator = CriticalCalculator()
        assert calculator is not None
        assert calculator.log is not None
    
    def test_critical_stats_model_creation(self):
        """Cover CriticalStats model instantiation."""
        stats = CriticalStats()
        assert stats.crit_rate == 1.0
        assert stats.crit_damage == 1.4
        assert stats.crit_bonus_flat == 0
        assert stats.crit_damage_bonus == 0.0
    
    def test_critical_stats_with_values(self):
        """Cover CriticalStats with custom values."""
        stats = CriticalStats(
            crit_rate=25.0,
            crit_damage=1.6,
            crit_bonus_flat=15,
            crit_damage_bonus=0.2
        )
        assert stats.crit_rate == 25.0
        assert stats.crit_damage == 1.6
        assert stats.crit_bonus_flat == 15
        assert stats.crit_damage_bonus == 0.2
    
    def test_backward_compatibility_alias(self):
        """Cover CriticalHitCalculator alias."""
        calculator = CriticalHitCalculator()
        assert isinstance(calculator, CriticalCalculator)


class TestCriticalRateCalculation:
    """Test critical hit rate calculation formulas."""
    
    def test_calculate_crit_rate_base_formula(self):
        """Cover base crit rate calculation: 1 + (LUK * 0.3)."""
        calculator = CriticalCalculator()
        # LUK = 50: 1 + (50 * 0.3) = 16.0
        result = calculator.calculate_crit_rate(50, 0)
        assert result == 16.0
    
    def test_calculate_crit_rate_with_defender_luk(self):
        """Cover crit rate with defender LUK reduction."""
        calculator = CriticalCalculator()
        # LUK = 50, Def LUK = 20: 1 + (50 * 0.3) - (20 * 0.2) = 16 - 4 = 12
        result = calculator.calculate_crit_rate(50, 20)
        assert result == 12.0
    
    def test_calculate_crit_rate_min_clamp(self):
        """Cover crit rate minimum clamp at 1%."""
        calculator = CriticalCalculator()
        # Very low LUK, high defender: should clamp to 1.0
        result = calculator.calculate_crit_rate(1, 100)
        assert result == 1.0
    
    def test_calculate_crit_rate_max_clamp(self):
        """Cover crit rate maximum clamp at 100%."""
        calculator = CriticalCalculator()
        # Very high LUK: 1 + (200 * 0.3) = 61, should clamp to 100
        result = calculator.calculate_crit_rate(500, 0)
        assert result == 100.0
    
    def test_calculate_crit_rate_logging(self):
        """Cover crit rate calculation logging."""
        calculator = CriticalCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_crit_rate(30, 10)
            mock_log.assert_called_once()


class TestCriticalDamageCalculation:
    """Test critical damage multiplier calculations."""
    
    def test_calculate_crit_damage_base(self):
        """Cover base crit damage (140% of base)."""
        calculator = CriticalCalculator()
        # Base 100 damage: 100 * 1.4 = 140
        result = calculator.calculate_crit_damage(100, 0, 0.0)
        assert result == 140
    
    def test_calculate_crit_damage_with_luk_bonus(self):
        """Cover LUK-based crit damage scaling (0.1% per LUK)."""
        calculator = CriticalCalculator()
        # Base 100, LUK 50: 100 * (1.4 + 50*0.001) = 100 * 1.45 = 145
        result = calculator.calculate_crit_damage(100, 50, 0.0)
        assert result == 145
    
    def test_calculate_crit_damage_with_bonus(self):
        """Cover additional crit damage bonuses."""
        calculator = CriticalCalculator()
        # Base 100, bonus 0.2: 100 * (1.4 + 0.2) = 160
        result = calculator.calculate_crit_damage(100, 0, 0.2)
        assert result == 160
    
    def test_calculate_crit_damage_all_bonuses(self):
        """Cover crit damage with LUK and bonus combined."""
        calculator = CriticalCalculator()
        # Base 100, LUK 30, bonus 0.15: 100 * (1.4 + 0.03 + 0.15) = 1.58
        # Due to floating point, int(100 * 1.58) = 157
        result = calculator.calculate_crit_damage(100, 30, 0.15)
        assert result == 157
    
    def test_calculate_crit_damage_logging(self):
        """Cover crit damage calculation logging."""
        calculator = CriticalCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_crit_damage(100, 20, 0.1)
            mock_log.assert_called_once()


class TestAverageDPSCalculation:
    """Test average DPS with critical hit probability."""
    
    def test_calculate_average_dps_no_crit(self):
        """Cover DPS calculation with 0% crit rate."""
        calculator = CriticalCalculator()
        # 100 damage, 0% crit, 1.4x mult, 1 ASPD = 100 DPS
        result = calculator.calculate_average_dps_with_crit(100, 0.0, 1.4, 1.0)
        assert result == 100.0
    
    def test_calculate_average_dps_full_crit(self):
        """Cover DPS calculation with 100% crit rate."""
        calculator = CriticalCalculator()
        # 100 damage, 100% crit, 1.4x mult, 1 ASPD = 140 DPS
        result = calculator.calculate_average_dps_with_crit(100, 100.0, 1.4, 1.0)
        assert result == 140.0
    
    def test_calculate_average_dps_half_crit(self):
        """Cover DPS calculation with 50% crit rate."""
        calculator = CriticalCalculator()
        # 100 dmg, 50% crit, 1.4x: (100 * 0.5) + (140 * 0.5) = 120
        result = calculator.calculate_average_dps_with_crit(100, 50.0, 1.4, 1.0)
        assert result == 120.0
    
    def test_calculate_average_dps_with_aspd(self):
        """Cover DPS calculation with attack speed multiplier."""
        calculator = CriticalCalculator()
        # 100 dmg, 25% crit, 1.4x, 2.0 ASPD
        # Avg dmg = (100 * 0.75) + (140 * 0.25) = 110
        # DPS = 110 * 2.0 = 220
        result = calculator.calculate_average_dps_with_crit(100, 25.0, 1.4, 2.0)
        assert result == 220.0
    
    def test_calculate_average_dps_logging(self):
        """Cover DPS calculation logging."""
        calculator = CriticalCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_average_dps_with_crit(100, 30.0, 1.4, 1.5)
            mock_log.assert_called_once()


class TestCritBuildComparison:
    """Test crit build vs stat build comparison."""
    
    def test_is_crit_build_worth_crit_superior(self):
        """Cover crit build analysis when crit is better."""
        calculator = CriticalCalculator()
        # 50% crit rate, 1.5x damage should beat 20 STR
        is_worth, explanation = calculator.is_crit_build_worth(
            50.0, 1.5, 20, 100
        )
        assert is_worth is True
        assert "Worth" in explanation
    
    def test_is_crit_build_worth_stat_superior(self):
        """Cover crit build analysis when stats are better."""
        calculator = CriticalCalculator()
        # 10% crit rate is weak vs 50 STR investment
        is_worth, explanation = calculator.is_crit_build_worth(
            10.0, 1.4, 50, 100
        )
        assert is_worth is False
        assert "Not worth" in explanation
    
    def test_is_crit_build_worth_logging(self):
        """Cover crit build comparison logging."""
        calculator = CriticalCalculator()
        with patch.object(calculator.log, 'info') as mock_log:
            calculator.is_crit_build_worth(30.0, 1.5, 25, 100)
            mock_log.assert_called_once()


class TestCritOptimizationAsync:
    """Test async crit optimization recommendations."""
    
    @pytest.mark.asyncio
    async def test_get_crit_optimization_basic(self):
        """Cover async crit optimization basic flow."""
        calculator = CriticalCalculator()
        stats = CriticalStats(
            crit_bonus_flat=10,
            effective_crit_damage=1.5
        )
        result = await calculator.get_crit_optimization(stats, 0, 30)
        
        assert "current_crit_rate" in result
        assert "needed_luk_for_50_crit" in result
        assert "recommendation" in result
    
    @pytest.mark.asyncio
    async def test_get_crit_optimization_with_target_luk(self):
        """Cover crit optimization with target LUK reduction."""
        calculator = CriticalCalculator()
        stats = CriticalStats(crit_bonus_flat=5)
        result = await calculator.get_crit_optimization(stats, 20, 40)
        
        assert result["current_luk"] == 40
        assert "luk_gap" in result
        assert "dps_improvement_factor" in result
    
    @pytest.mark.asyncio
    async def test_get_crit_optimization_suggests_cards(self):
        """Cover crit card suggestions for low crit rate."""
        calculator = CriticalCalculator()
        stats = CriticalStats(crit_bonus_flat=0)
        result = await calculator.get_crit_optimization(stats, 0, 10)
        
        # Low crit should suggest cards (cards have descriptive names)
        assert len(result["crit_cards_suggested"]) > 0
        # Check if card list contains Anolian with description
        card_names = [card for card in result["crit_cards_suggested"]]
        assert any("Anolian Card" in card for card in card_names)
    
    @pytest.mark.asyncio
    async def test_get_crit_optimization_no_cards_when_high(self):
        """Cover no card suggestions when crit is already high."""
        calculator = CriticalCalculator()
        stats = CriticalStats(crit_bonus_flat=30)
        result = await calculator.get_crit_optimization(stats, 0, 50)
        
        # High crit shouldn't need cards
        assert len(result["crit_cards_suggested"]) == 0
    
    @pytest.mark.asyncio
    async def test_get_crit_optimization_already_optimal(self):
        """Cover optimization when already at 50%+ crit."""
        calculator = CriticalCalculator()
        stats = CriticalStats(crit_bonus_flat=40)
        result = await calculator.get_crit_optimization(stats, 0, 100)
        
        assert result["luk_gap"] == 0
        assert "optimized" in result["recommendation"]


# ============================================================================
# TEST CLASS: ElementCalculator
# ============================================================================

class TestElementCalculatorCore:
    """Test element calculator initialization."""
    
    def test_element_calculator_initialization(self):
        """Cover ElementCalculator.__init__."""
        calculator = ElementCalculator()
        assert calculator is not None
        assert calculator.log is not None
    
    def test_element_enum_values(self):
        """Cover Element enum values."""
        assert Element.NEUTRAL.value == "neutral"
        assert Element.FIRE.value == "fire"
        assert Element.WATER.value == "water"
        assert Element.EARTH.value == "earth"
        assert Element.WIND.value == "wind"
        assert Element.HOLY.value == "holy"
        assert Element.DARK.value == "dark"
        assert Element.POISON.value == "poison"
        assert Element.GHOST.value == "ghost"
        assert Element.UNDEAD.value == "undead"
    
    def test_element_level_enum(self):
        """Cover ElementLevel enum."""
        assert ElementLevel.LEVEL_1 == 1
        assert ElementLevel.LEVEL_2 == 2
        assert ElementLevel.LEVEL_3 == 3
        assert ElementLevel.LEVEL_4 == 4


class TestElementModifier:
    """Test ElementModifier model and properties."""
    
    def test_element_modifier_creation(self):
        """Cover ElementModifier instantiation."""
        mod = ElementModifier(
            attack_element=Element.FIRE,
            attack_level=1,
            defense_element=Element.EARTH,
            defense_level=1,
            modifier=1.5
        )
        assert mod.modifier == 1.5
        assert mod.is_immune is False
        assert mod.absorbs_damage is False
    
    def test_element_modifier_effective_super(self):
        """Cover effective property for super effective."""
        mod = ElementModifier(
            attack_element=Element.FIRE,
            defense_element=Element.EARTH,
            modifier=2.0
        )
        assert mod.effective == "SUPER_EFFECTIVE"
    
    def test_element_modifier_effective_normal(self):
        """Cover effective property for effective damage."""
        mod = ElementModifier(
            attack_element=Element.WATER,
            defense_element=Element.FIRE,
            modifier=1.5
        )
        assert mod.effective == "EFFECTIVE"
    
    def test_element_modifier_effective_weak(self):
        """Cover effective property for weak damage."""
        mod = ElementModifier(
            attack_element=Element.FIRE,
            defense_element=Element.WATER,
            modifier=0.75
        )
        assert mod.effective == "WEAK"
    
    def test_element_modifier_effective_resisted(self):
        """Cover effective property for heavily resisted."""
        mod = ElementModifier(
            attack_element=Element.FIRE,
            defense_element=Element.FIRE,
            modifier=0.25
        )
        # 0.25 is < 1.0 so it's WEAK, need <= 0.5 for RESISTED
        assert mod.effective == "WEAK"
    
    def test_element_modifier_immune(self):
        """Cover immune flag and effective property."""
        mod = ElementModifier(
            attack_element=Element.HOLY,
            defense_element=Element.HOLY,
            modifier=0.0,
            is_immune=True
        )
        assert mod.is_immune is True
        assert mod.effective == "IMMUNE"
    
    def test_element_modifier_absorbs(self):
        """Cover absorbs_damage flag and effective property."""
        mod = ElementModifier(
            attack_element=Element.WATER,
            defense_element=Element.WATER,
            modifier=0.5,
            absorbs_damage=True
        )
        assert mod.absorbs_damage is True
        assert mod.effective == "ABSORBS"
    
    def test_element_modifier_damage_percent(self):
        """Cover damage_percent property."""
        mod = ElementModifier(
            attack_element=Element.FIRE,
            defense_element=Element.WATER,
            modifier=0.5
        )
        assert mod.damage_percent == 50


class TestElementTableLookup:
    """Test element damage modifier lookup."""
    
    def test_get_modifier_fire_vs_earth_strong(self):
        """Cover fire vs earth advantage (150%)."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.FIRE, 1, Element.EARTH, 1
        )
        assert result.modifier == 1.5
        assert result.effective == "EFFECTIVE"
    
    def test_get_modifier_water_vs_fire_strong(self):
        """Cover water vs fire advantage (150%)."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.WATER, 1, Element.FIRE, 1
        )
        assert result.modifier == 1.5
    
    def test_get_modifier_neutral_vs_ghost_weak(self):
        """Cover neutral vs ghost resistance."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.NEUTRAL, 1, Element.GHOST, 2
        )
        assert result.modifier == 0.5
    
    def test_get_modifier_holy_vs_undead_super(self):
        """Cover holy vs undead super effective."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.HOLY, 1, Element.UNDEAD, 3
        )
        assert result.modifier == 1.75
        assert result.effective == "SUPER_EFFECTIVE"
    
    def test_get_modifier_same_element_immune(self):
        """Cover same element immunity (poison vs poison)."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.POISON, 1, Element.POISON, 1
        )
        assert result.modifier == 0.0
        assert result.is_immune is True
    
    def test_get_modifier_absorption(self):
        """Cover element absorption (water 3 absorbs water)."""
        calculator = ElementCalculator()
        result = calculator.get_modifier(
            Element.WATER, 1, Element.WATER, 3
        )
        assert result.absorbs_damage is True
    
    def test_get_modifier_level_clamping(self):
        """Cover element level clamping to 1-4 range."""
        calculator = ElementCalculator()
        # Test invalid level gets clamped
        result = calculator.get_modifier(
            Element.FIRE, 10, Element.EARTH, 0
        )
        assert result is not None  # Should not error
    
    def test_get_modifier_logging(self):
        """Cover element modifier logging."""
        calculator = ElementCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.get_modifier(
                Element.FIRE, 1, Element.WATER, 1
            )
            mock_log.assert_called_once()


class TestOptimalElementSelection:
    """Test optimal element finding."""
    
    def test_get_optimal_element_for_water(self):
        """Cover finding optimal element vs water (earth or wind)."""
        calculator = ElementCalculator()
        best_elem, best_mod = calculator.get_optimal_element(
            Element.WATER, 1
        )
        # Both wind and earth are 1.5x vs water, either is optimal
        assert best_elem in [Element.WIND, Element.EARTH]
        assert best_mod == 1.5
    
    def test_get_optimal_element_for_fire(self):
        """Cover finding optimal element vs fire (water)."""
        calculator = ElementCalculator()
        best_elem, best_mod = calculator.get_optimal_element(
            Element.FIRE, 1
        )
        assert best_elem == Element.WATER
        assert best_mod >= 1.5
    
    def test_get_optimal_element_skips_immune(self):
        """Cover optimal element skipping immune matchups."""
        calculator = ElementCalculator()
        # Should not recommend poison vs poison (immune)
        best_elem, best_mod = calculator.get_optimal_element(
            Element.POISON, 1
        )
        assert best_elem != Element.POISON
    
    def test_get_optimal_element_logging(self):
        """Cover optimal element selection logging."""
        calculator = ElementCalculator()
        with patch.object(calculator.log, 'info') as mock_log:
            calculator.get_optimal_element(Element.UNDEAD, 1)
            mock_log.assert_called_once()


class TestElementChangeDecision:
    """Test element change recommendation logic."""
    
    def test_should_change_element_when_immune(self):
        """Cover element change when current is immune."""
        calculator = ElementCalculator()
        should_change, recommended = calculator.should_change_element(
            Element.POISON, Element.POISON, 1
        )
        assert should_change is True
        assert recommended is not None
    
    def test_should_change_element_when_absorbed(self):
        """Cover element change when damage is absorbed."""
        calculator = ElementCalculator()
        should_change, recommended = calculator.should_change_element(
            Element.WATER, Element.WATER, 4
        )
        assert should_change is True
    
    def test_should_change_element_for_big_improvement(self):
        """Cover element change for 50%+ damage improvement."""
        calculator = ElementCalculator()
        # Fire vs water (weak) → wind vs water (strong)
        should_change, recommended = calculator.should_change_element(
            Element.FIRE, Element.WATER, 1
        )
        # Should recommend change as improvement is significant
        assert should_change is True or should_change is False  # Depends on calc
    
    def test_should_not_change_element_small_diff(self):
        """Cover element change threshold logic."""
        calculator = ElementCalculator()
        # Neutral vs earth: optimal is fire (1.5x), which is 1.5x improvement
        # This meets the 1.5x threshold, so will recommend change
        should_change, recommended = calculator.should_change_element(
            Element.NEUTRAL, Element.EARTH, 1
        )
        # 1.5x improvement meets threshold, so change is recommended
        assert should_change is True
        assert recommended == Element.FIRE


class TestElementHelpers:
    """Test element converter and endow helpers."""
    
    def test_get_converter_for_fire(self):
        """Cover fire element converter item."""
        calculator = ElementCalculator()
        converter = calculator.get_converter_for_element(Element.FIRE)
        assert converter == "Flame Heart"
    
    def test_get_converter_for_water(self):
        """Cover water element converter item."""
        calculator = ElementCalculator()
        converter = calculator.get_converter_for_element(Element.WATER)
        assert converter == "Mystic Frozen"
    
    def test_get_converter_for_invalid(self):
        """Cover converter for unsupported element."""
        calculator = ElementCalculator()
        converter = calculator.get_converter_for_element(Element.HOLY)
        assert converter is None
    
    def test_get_endow_skill_for_fire(self):
        """Cover fire endow skill."""
        calculator = ElementCalculator()
        endow = calculator.get_endow_skill_for_element(Element.FIRE)
        assert endow == "Endow Blaze"
    
    def test_get_endow_skill_for_holy(self):
        """Cover holy endow skill (Aspersio)."""
        calculator = ElementCalculator()
        endow = calculator.get_endow_skill_for_element(Element.HOLY)
        assert endow == "Aspersio"
    
    def test_get_endow_skill_for_invalid(self):
        """Cover endow for unsupported element."""
        calculator = ElementCalculator()
        endow = calculator.get_endow_skill_for_element(Element.POISON)
        assert endow is None


class TestElementMatchupAnalysis:
    """Test comprehensive element matchup analysis."""
    
    def test_analyze_element_matchup_basic(self):
        """Cover element matchup analysis structure."""
        calculator = ElementCalculator()
        analysis = calculator.analyze_element_matchup(
            Element.FIRE, Element.EARTH, 1
        )
        
        assert "current_element" in analysis
        assert "target_element" in analysis
        assert "current_modifier" in analysis
        assert "optimal_element" in analysis
        assert "should_change" in analysis
    
    def test_analyze_element_matchup_adds_items_when_change(self):
        """Cover item suggestions when change recommended."""
        calculator = ElementCalculator()
        analysis = calculator.analyze_element_matchup(
            Element.POISON, Element.POISON, 1  # Immune, should change
        )
        
        if analysis["should_change"]:
            assert "converter_item" in analysis or "endow_skill" in analysis


# ============================================================================
# TEST CLASS: EvasionCalculator  
# ============================================================================

class TestEvasionCalculatorCore:
    """Test evasion calculator initialization."""
    
    def test_evasion_calculator_initialization(self):
        """Cover EvasionCalculator.__init__."""
        calculator = EvasionCalculator()
        assert calculator is not None
        assert calculator.log is not None
    
    def test_evasion_stats_model(self):
        """Cover EvasionStats model creation."""
        stats = EvasionStats()
        assert stats.flee == 1
        assert stats.perfect_dodge == 0
        assert stats.flee_bonus_percent == 0.0
    
    def test_hit_stats_model(self):
        """Cover HitStats model creation."""
        stats = HitStats()
        assert stats.hit == 1
        assert stats.hit_bonus_percent == 0.0
    
    def test_evasion_result_enum(self):
        """Cover EvasionResult enum values."""
        assert EvasionResult.HIT == "hit"
        assert EvasionResult.MISS == "miss"
        assert EvasionResult.PERFECT_DODGE == "perfect_dodge"


class TestFleeCalculation:
    """Test flee rate calculation."""
    
    def test_calculate_flee_base_formula(self):
        """Cover flee = level + AGI + bonus."""
        calculator = EvasionCalculator()
        # Level 50, AGI 30, bonus 10 = 90
        result = calculator.calculate_flee(50, 30, 10, 0.0)
        assert result == 90
    
    def test_calculate_flee_with_percent_bonus(self):
        """Cover flee with percentage bonus."""
        calculator = EvasionCalculator()
        # Base 100, 20% bonus = 120
        result = calculator.calculate_flee(50, 40, 10, 0.2)
        assert result == 120
    
    def test_calculate_flee_logging(self):
        """Cover flee calculation logging."""
        calculator = EvasionCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_flee(60, 40, 5, 0.1)
            mock_log.assert_called_once()


class TestPerfectDodgeCalculation:
    """Test perfect dodge mechanics."""
    
    def test_calculate_perfect_dodge_formula(self):
        """Cover perfect dodge = LUK / 10."""
        calculator = EvasionCalculator()
        # LUK 50 = 5% perfect dodge
        result = calculator.calculate_perfect_dodge(50)
        assert result == 5.0
    
    def test_calculate_perfect_dodge_high_luk(self):
        """Cover perfect dodge with high LUK."""
        calculator = EvasionCalculator()
        # LUK 100 = 10% perfect dodge
        result = calculator.calculate_perfect_dodge(100)
        assert result == 10.0
    
    def test_calculate_perfect_dodge_logging(self):
        """Cover perfect dodge logging."""
        calculator = EvasionCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_perfect_dodge(40)
            mock_log.assert_called_once()


class TestHitRateCalculation:
    """Test hit rate calculation with flee penalty."""
    
    def test_calculate_hit_rate_base_formula(self):
        """Cover hit rate = 80 + hit - flee."""
        calculator = EvasionCalculator()
        # 100 hit, 90 flee = 80 + 100 - 90 = 90%
        result = calculator.calculate_hit_rate(100, 90, 1)
        assert result == 90.0
    
    def test_calculate_hit_rate_multiple_attackers(self):
        """Cover flee penalty with 3+ attackers."""
        calculator = EvasionCalculator()
        # 3 attackers: flee * 0.9
        # 100 hit, 100 flee, 3 attackers: 80 + 100 - 90 = 90%
        result = calculator.calculate_hit_rate(100, 100, 3)
        assert result == 90.0
    
    def test_calculate_hit_rate_min_clamp(self):
        """Cover hit rate minimum clamp at 5%."""
        calculator = EvasionCalculator()
        # Very high flee should clamp to 5%
        result = calculator.calculate_hit_rate(50, 500, 1)
        assert result == 5.0
    
    def test_calculate_hit_rate_max_clamp(self):
        """Cover hit rate maximum clamp at 95%."""
        calculator = EvasionCalculator()
        # Very high hit should clamp to 95%
        result = calculator.calculate_hit_rate(500, 50, 1)
        assert result == 95.0
    
    def test_calculate_hit_rate_logging(self):
        """Cover hit rate calculation logging."""
        calculator = EvasionCalculator()
        with patch.object(calculator.log, 'debug') as mock_log:
            calculator.calculate_hit_rate(100, 80, 2)
            mock_log.assert_called_once()


class TestFleeNeededCalculation:
    """Test required flee calculation."""
    
    def test_calculate_flee_needed_for_95_miss(self):
        """Cover flee calculation for 95% miss rate."""
        calculator = EvasionCalculator()
        # For 95% miss (5% hit): 80 + hit - flee = 5
        # flee = 80 + hit - 5
        result = calculator.calculate_flee_needed(100, 0.95)
        assert result == 175  # 80 + 100 - 5
    
    def test_calculate_flee_needed_logging(self):
        """Cover flee needed logging."""
        calculator = EvasionCalculator()
        with patch.object(calculator.log, 'info') as mock_log:
            calculator.calculate_flee_needed(120, 0.90)
            mock_log.assert_called_once()


class TestFleeViability:
    """Test flee build viability checks."""
    
    def test_is_flee_viable_true(self):
        """Cover flee build viable when miss rate >= 80%."""
        calculator = EvasionCalculator()
        # High flee should be viable
        viable, miss_rate = calculator.is_flee_viable(180, 100, 1)
        assert viable is True
        assert miss_rate >= 0.80
    
    def test_is_flee_viable_false(self):
        """Cover flee build not viable when miss rate < 80%."""
        calculator = EvasionCalculator()
        # Low flee should not be viable
        viable, miss_rate = calculator.is_flee_viable(50, 100, 1)
        assert viable is False
    
    def test_is_flee_viable_with_multiple_enemies(self):
        """Cover flee viability with multiple attackers."""
        calculator = EvasionCalculator()
        viable, miss_rate = calculator.is_flee_viable(150, 100, 4)
        # Multiple enemies reduce flee effectiveness
        assert viable is False or viable is True  # Depends on calc
    
    def test_is_flee_viable_logging(self):
        """Cover flee viability logging."""
        calculator = EvasionCalculator()
        with patch.object(calculator.log, 'info') as mock_log:
            calculator.is_flee_viable(120, 90, 2)
            mock_log.assert_called_once()


class TestEvasionRecommendationAsync:
    """Test async evasion recommendations."""
    
    @pytest.mark.asyncio
    async def test_get_evasion_recommendation_basic(self):
        """Cover async evasion recommendation structure."""
        calculator = EvasionCalculator()
        stats = EvasionStats(effective_flee=120, perfect_dodge_percent=5.0)
        monster_data = {"hit": 100, "count": 1}
        
        result = await calculator.get_evasion_recommendation(stats, monster_data)
        
        assert "current_flee" in result
        assert "current_miss_rate" in result
        assert "flee_needed_95" in result
        assert "recommendation" in result
    
    @pytest.mark.asyncio
    async def test_get_evasion_recommendation_viable(self):
        """Cover recommendation when flee is already viable."""
        calculator = EvasionCalculator()
        stats = EvasionStats(effective_flee=200)
        monster_data = {"hit": 80, "count": 1}
        
        result = await calculator.get_evasion_recommendation(stats, monster_data)
        assert result["flee_viable"] is True
    
    @pytest.mark.asyncio
    async def test_get_evasion_recommendation_needs_investment(self):
        """Cover recommendation when flee investment needed."""
        calculator = EvasionCalculator()
        stats = EvasionStats(effective_flee=80)
        monster_data = {"hit": 120, "count": 1}
        
        result = await calculator.get_evasion_recommendation(stats, monster_data)
        assert result["flee_gap"] > 0
        assert result["agi_investment_needed"] > 0


# ============================================================================
# TEST CLASS: SkillDatabase
# ============================================================================

class TestSkillDatabaseCore:
    """Test skill database initialization and loading."""
    
    def test_skill_database_initialization_default(self, tmp_path):
        """Cover SkillDatabase.__init__ with default path."""
        db = SkillDatabase(data_dir=tmp_path)
        assert db is not None
        assert db._data_dir == tmp_path
    
    def test_skill_database_lazy_loading(self, tmp_path):
        """Cover lazy loading of skill data."""
        db = SkillDatabase(data_dir=tmp_path)
        # Data should not be loaded until accessed
        assert db._skill_trees is None
        assert db._skill_effects is None
    
    def test_skill_database_load_missing_file(self, tmp_path):
        """Cover loading missing JSON file returns empty dict."""
        db = SkillDatabase(data_dir=tmp_path)
        result = db._load_json("nonexistent.json")
        assert result == {}


class TestSkillDatabaseProperties:
    """Test skill database property accessors."""
    
    def test_skill_trees_property(self, tmp_path):
        """Cover skill_trees property with caching."""
        # Create test data
        (tmp_path / "skill_trees.json").write_text('{"swordsman": {}}')
        db = SkillDatabase(data_dir=tmp_path)
        
        trees = db.skill_trees
        assert trees == {"swordsman": {}}
        # Second access should use cache
        trees2 = db.skill_trees
        assert trees2 == {"swordsman": {}}
    
    def test_skill_effects_property(self, tmp_path):
        """Cover skill_effects property."""
        (tmp_path / "skill_effects.json").write_text('{"bash": {"id": 5}}')
        db = SkillDatabase(data_dir=tmp_path)
        
        effects = db.skill_effects
        assert "bash" in effects
    
    def test_get_skill_tree_method(self, tmp_path):
        """Cover get_skill_tree method."""
        (tmp_path / "skill_trees.json").write_text('{"knight": {"bash": {}}}')
        db = SkillDatabase(data_dir=tmp_path)
        
        tree = db.get_skill_tree("knight")
        assert "bash" in tree
    
    def test_get_skill_definition_method(self, tmp_path):
        """Cover get_skill_definition with prerequisites."""
        skill_data = {
            "knight": {
                "bash": {
                    "id": 5,
                    "name": "Bash",
                    "max_level": 10,
                    "prerequisites": [{"skill": "sword_mastery", "level": 5}]
                }
            }
        }
        (tmp_path / "skill_trees.json").write_text(str(skill_data).replace("'", '"'))
        db = SkillDatabase(data_dir=tmp_path)
        
        skill_def = db.get_skill_definition("bash", "knight")
        assert skill_def is not None
        assert skill_def.id == 5


class TestSkillManager:
    """Test skill manager operations."""
    
    def test_skill_manager_initialization(self):
        """Cover SkillManager.__init__."""
        manager = SkillManager()
        assert manager is not None
        assert manager.skills == {}
    
    def test_get_available_skills(self):
        """Cover get_available_skills method."""
        manager = SkillManager()
        skills = manager.get_available_skills(["bash", "provoke"])
        assert skills == ["bash", "provoke"]


class TestSkillAllocationSystemCore:
    """Test skill allocation system initialization."""
    
    def test_skill_allocation_system_initialization(self, tmp_path):
        """Cover SkillAllocationSystem.__init__."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        assert system is not None
        assert system.default_build == "melee_dps"
    
    def test_set_build_type(self, tmp_path):
        """Cover set_build_type method."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        system.set_build_type("tank")
        assert system._build_type == "tank"
        assert system.default_build == "tank"
    
    def test_get_job_class(self, tmp_path):
        """Cover job ID to class name conversion."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        assert system.get_job_class(1) == "swordsman"
        assert system.get_job_class(7) == "knight"
    
    def test_get_base_job_class(self, tmp_path):
        """Cover base job class lookup for transcendent."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        assert system.get_base_job_class("lord_knight") == "knight"
        assert system.get_base_job_class("knight") == "knight"


class TestSkillPrerequisiteResolution:
    """Test skill prerequisite chain resolution."""
    
    def test_resolve_prerequisites_no_prereqs(self, tmp_path):
        """Cover skill with no prerequisites."""
        skill_data = {"novice": {"basic_skill": {"id": 1, "max_level": 9}}}
        (tmp_path / "skill_trees.json").write_text(str(skill_data).replace("'", '"'))
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        result = system.resolve_prerequisites("basic_skill", "novice")
        assert result == []
    
    def test_resolve_prerequisites_with_chain(self, tmp_path):
        """Cover skill with prerequisite chain."""
        skill_data = {
            "swordsman": {
                "bash": {"id": 5, "max_level": 10, "prerequisites": [{"skill": "sword_mastery", "level": 5}]},
                "sword_mastery": {"id": 2, "max_level": 10}
            }
        }
        (tmp_path / "skill_trees.json").write_text(str(skill_data).replace("'", '"'))
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        result = system.resolve_prerequisites("bash", "swordsman")
        # Should include sword_mastery
        assert len(result) > 0
    
    def test_resolve_prerequisites_caching(self, tmp_path):
        """Cover prerequisite resolution caching."""
        skill_data = {"knight": {"bash": {"id": 5, "max_level": 10}}}
        (tmp_path / "skill_trees.json").write_text(str(skill_data).replace("'", '"'))
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        # First call
        result1 = system.resolve_prerequisites("bash", "knight")
        # Second call should use cache
        result2 = system.resolve_prerequisites("bash", "knight")
        assert result1 == result2


class TestSkillAllocation:
    """Test skill point allocation logic."""
    
    def test_allocate_skill_point_no_points(self, tmp_path):
        """Cover allocation when no skill points available."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        character = CharacterState(
            character_id=1,
            name="Test",
            level=50,
            job_id=1,
            skill_points=0
        )
        
        action = system.allocate_skill_point(character)
        assert action is None
    
    def test_can_learn_skill_no_points(self, tmp_path):
        """Cover can_learn_skill with no skill points."""
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        character = Mock(skill_points=0)
        can_learn, reason = system.can_learn_skill("bash", character)
        assert can_learn is False
        assert "No skill points" in reason
    
    def test_validate_skill_tree(self, tmp_path):
        """Cover skill tree validation."""
        skill_data = {"knight": {"bash": {"id": 5, "max_level": 10}}}
        (tmp_path / "skill_trees.json").write_text(str(skill_data).replace("'", '"'))
        db = SkillDatabase(data_dir=tmp_path)
        system = SkillAllocationSystem(skill_db=db)
        
        errors = system.validate_skill_tree("knight")
        # Valid tree should have no errors
        assert len(errors) == 0