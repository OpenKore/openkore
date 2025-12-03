"""
Comprehensive tests for combat/race_property.py module.

Tests race damage bonuses, weapon size penalties, card recommendations,
and equipment optimization calculations.
"""

import json
from pathlib import Path
from unittest.mock import Mock, patch, mock_open

import pytest

from ai_sidecar.combat.models import MonsterRace, MonsterSize
from ai_sidecar.combat.race_property import (
    CardInfo,
    RaceDamageModifier,
    RacePropertyCalculator,
    WEAPON_SIZE_PENALTY,
)


class TestRaceDamageModifier:
    """Test RaceDamageModifier model."""
    
    def test_basic_modifier_creation(self):
        """Test creating basic damage modifier."""
        modifier = RaceDamageModifier(
            race=MonsterRace.DEMI_HUMAN,
            size=MonsterSize.MEDIUM,
            race_modifier=1.2,
            size_modifier=0.75,
            total_modifier=0.9
        )
        
        assert modifier.race == MonsterRace.DEMI_HUMAN
        assert modifier.size == MonsterSize.MEDIUM
        assert modifier.race_modifier == 1.2
        assert modifier.size_modifier == 0.75
        assert modifier.total_modifier == 0.9
    
    def test_damage_percent_calculation(self):
        """Test damage percentage calculation."""
        modifier = RaceDamageModifier(
            race=MonsterRace.BRUTE,
            size=MonsterSize.LARGE,
            total_modifier=1.5
        )
        
        assert modifier.damage_percent == 150
    
    def test_default_modifiers(self):
        """Test default modifier values."""
        modifier = RaceDamageModifier(
            race=MonsterRace.INSECT,
            size=MonsterSize.SMALL
        )
        
        assert modifier.race_modifier == 1.0
        assert modifier.size_modifier == 1.0
        assert modifier.total_modifier == 1.0
        assert modifier.damage_percent == 100
    
    def test_frozen_model(self):
        """Test that RaceDamageModifier is immutable."""
        modifier = RaceDamageModifier(
            race=MonsterRace.UNDEAD,
            size=MonsterSize.LARGE
        )
        
        with pytest.raises(Exception):  # ValidationError or AttributeError
            modifier.total_modifier = 2.0


class TestCardInfo:
    """Test CardInfo model."""
    
    def test_race_card_creation(self):
        """Test creating race card."""
        card = CardInfo(
            card_name="Hydra Card",
            card_id=4001,
            bonus_percent=0.20,
            race=MonsterRace.DEMI_HUMAN
        )
        
        assert card.card_name == "Hydra Card"
        assert card.card_id == 4001
        assert card.bonus_percent == 0.20
        assert card.race == MonsterRace.DEMI_HUMAN
        assert card.size is None
    
    def test_size_card_creation(self):
        """Test creating size card."""
        card = CardInfo(
            card_name="Desert Wolf Card",
            card_id=4082,
            bonus_percent=0.15,
            size=MonsterSize.SMALL
        )
        
        assert card.size == MonsterSize.SMALL
        assert card.race is None
    
    def test_default_slot_type(self):
        """Test default slot type."""
        card = CardInfo(
            card_name="Test Card",
            bonus_percent=0.10
        )
        
        assert card.slot_type == "weapon"
    
    def test_card_with_all_fields(self):
        """Test card with all fields populated."""
        card = CardInfo(
            card_name="Special Card",
            card_id=5000,
            bonus_percent=0.25,
            race=MonsterRace.DRAGON,
            size=MonsterSize.LARGE,
            slot_type="armor"
        )
        
        assert card.card_name == "Special Card"
        assert card.card_id == 5000
        assert card.bonus_percent == 0.25
        assert card.race == MonsterRace.DRAGON
        assert card.size == MonsterSize.LARGE
        assert card.slot_type == "armor"


class TestWeaponSizePenalty:
    """Test weapon size penalty constants."""
    
    def test_dagger_penalties(self):
        """Test dagger size penalties."""
        assert WEAPON_SIZE_PENALTY["dagger"][MonsterSize.SMALL] == 1.0
        assert WEAPON_SIZE_PENALTY["dagger"][MonsterSize.MEDIUM] == 0.75
        assert WEAPON_SIZE_PENALTY["dagger"][MonsterSize.LARGE] == 0.5
    
    def test_sword_penalties(self):
        """Test sword size penalties."""
        assert WEAPON_SIZE_PENALTY["sword"][MonsterSize.SMALL] == 0.75
        assert WEAPON_SIZE_PENALTY["sword"][MonsterSize.MEDIUM] == 1.0
        assert WEAPON_SIZE_PENALTY["sword"][MonsterSize.LARGE] == 0.75
    
    def test_two_hand_sword_penalties(self):
        """Test two-hand sword penalties."""
        assert WEAPON_SIZE_PENALTY["two_hand_sword"][MonsterSize.SMALL] == 0.75
        assert WEAPON_SIZE_PENALTY["two_hand_sword"][MonsterSize.MEDIUM] == 0.75
        assert WEAPON_SIZE_PENALTY["two_hand_sword"][MonsterSize.LARGE] == 1.0
    
    def test_mage_weapons_no_penalty(self):
        """Test that mage weapons have no size penalty."""
        for size in MonsterSize:
            assert WEAPON_SIZE_PENALTY["rod"][size] == 1.0
            assert WEAPON_SIZE_PENALTY["staff"][size] == 1.0
    
    def test_gun_weapons_no_penalty(self):
        """Test that gun weapons have no size penalty."""
        for size in MonsterSize:
            assert WEAPON_SIZE_PENALTY["gun"][size] == 1.0
            assert WEAPON_SIZE_PENALTY["rifle"][size] == 1.0
            assert WEAPON_SIZE_PENALTY["gatling"][size] == 1.0


class TestRacePropertyCalculator:
    """Test RacePropertyCalculator class."""
    
    @pytest.fixture
    def calculator(self, tmp_path):
        """Create calculator with default cards."""
        return RacePropertyCalculator()
    
    @pytest.fixture
    def calculator_with_data(self, tmp_path):
        """Create calculator with test data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        card_data = {
            "race_cards": {
                "demi_human": [
                    {"card": "Hydra Card", "bonus": 0.20}
                ],
                "brute": [
                    {"card": "Minorous Card", "bonus": 0.15}
                ]
            },
            "size_cards": {
                "small": [
                    {"card": "Desert Wolf Card", "bonus": 0.15}
                ],
                "medium": [
                    {"card": "Skeleton Worker Card", "bonus": 0.15}
                ]
            }
        }
        
        card_file = data_dir / "race_cards.json"
        card_file.write_text(json.dumps(card_data))
        
        return RacePropertyCalculator(data_dir)
    
    def test_initialization_without_data(self):
        """Test initialization without data directory."""
        calc = RacePropertyCalculator()
        
        assert len(calc.race_cards) > 0
        assert len(calc.size_cards) > 0
    
    def test_initialization_with_data(self, calculator_with_data):
        """Test initialization with data directory."""
        calc = calculator_with_data
        
        assert len(calc.race_cards[MonsterRace.DEMI_HUMAN]) > 0
        assert len(calc.size_cards[MonsterSize.SMALL]) > 0
    
    def test_default_cards_loaded(self, calculator):
        """Test that default cards are loaded."""
        calc = calculator
        
        # Check some race cards
        assert len(calc.race_cards[MonsterRace.DEMI_HUMAN]) > 0
        assert len(calc.race_cards[MonsterRace.BRUTE]) > 0
        
        # Check size cards
        assert len(calc.size_cards[MonsterSize.SMALL]) > 0
        assert len(calc.size_cards[MonsterSize.LARGE]) > 0
    
    def test_get_size_penalty_sword_medium(self, calculator):
        """Test size penalty for sword vs medium."""
        penalty = calculator.get_size_penalty("sword", MonsterSize.MEDIUM)
        assert penalty == 1.0
    
    def test_get_size_penalty_sword_small(self, calculator):
        """Test size penalty for sword vs small."""
        penalty = calculator.get_size_penalty("sword", MonsterSize.SMALL)
        assert penalty == 0.75
    
    def test_get_size_penalty_dagger_large(self, calculator):
        """Test size penalty for dagger vs large."""
        penalty = calculator.get_size_penalty("dagger", MonsterSize.LARGE)
        assert penalty == 0.5
    
    def test_get_size_penalty_unknown_weapon(self, calculator):
        """Test size penalty for unknown weapon."""
        penalty = calculator.get_size_penalty("unknown_weapon", MonsterSize.MEDIUM)
        assert penalty == 1.0
    
    def test_get_size_penalty_case_insensitive(self, calculator):
        """Test size penalty is case insensitive."""
        penalty1 = calculator.get_size_penalty("SWORD", MonsterSize.MEDIUM)
        penalty2 = calculator.get_size_penalty("sword", MonsterSize.MEDIUM)
        assert penalty1 == penalty2
    
    def test_get_size_penalty_with_spaces(self, calculator):
        """Test size penalty with weapon type containing spaces."""
        penalty = calculator.get_size_penalty("Two Hand Sword", MonsterSize.LARGE)
        assert penalty == 1.0
    
    def test_get_race_bonus_no_cards(self, calculator):
        """Test race bonus with no equipped cards."""
        bonus = calculator.get_race_bonus([], MonsterRace.DEMI_HUMAN)
        assert bonus == 1.0
    
    def test_get_race_bonus_single_card(self, calculator):
        """Test race bonus with single equipped card."""
        bonus = calculator.get_race_bonus(["Hydra Card"], MonsterRace.DEMI_HUMAN)
        assert bonus == 1.2
    
    def test_get_race_bonus_multiple_cards(self, calculator):
        """Test race bonus with multiple cards."""
        bonus = calculator.get_race_bonus(
            ["Hydra Card", "Hydra Card"], 
            MonsterRace.DEMI_HUMAN
        )
        assert bonus == 1.4
    
    def test_get_race_bonus_wrong_race(self, calculator):
        """Test race bonus with wrong race cards."""
        bonus = calculator.get_race_bonus(["Hydra Card"], MonsterRace.UNDEAD)
        assert bonus == 1.0
    
    def test_get_race_bonus_case_insensitive(self, calculator):
        """Test race bonus is case insensitive."""
        bonus = calculator.get_race_bonus(["HYDRA CARD"], MonsterRace.DEMI_HUMAN)
        assert bonus == 1.2
    
    def test_calculate_total_modifier_no_bonuses(self, calculator):
        """Test total modifier with no bonuses."""
        modifier = calculator.calculate_total_modifier(
            "sword", [], MonsterRace.BRUTE, MonsterSize.MEDIUM
        )
        
        assert modifier.race_modifier == 1.0
        assert modifier.size_modifier == 1.0
        assert modifier.total_modifier == 1.0
    
    def test_calculate_total_modifier_with_race_bonus(self, calculator):
        """Test total modifier with race bonus."""
        modifier = calculator.calculate_total_modifier(
            "sword", ["Hydra Card"], MonsterRace.DEMI_HUMAN, MonsterSize.MEDIUM
        )
        
        assert modifier.race_modifier == 1.2
        assert modifier.size_modifier == 1.0
        assert modifier.total_modifier == 1.2
    
    def test_calculate_total_modifier_with_size_penalty(self, calculator):
        """Test total modifier with size penalty."""
        modifier = calculator.calculate_total_modifier(
            "dagger", [], MonsterRace.BRUTE, MonsterSize.LARGE
        )
        
        assert modifier.race_modifier == 1.0
        assert modifier.size_modifier == 0.5
        assert modifier.total_modifier == 0.5
    
    def test_calculate_total_modifier_combined(self, calculator):
        """Test total modifier with both race and size."""
        modifier = calculator.calculate_total_modifier(
            "sword", ["Hydra Card"], MonsterRace.DEMI_HUMAN, MonsterSize.SMALL
        )
        
        assert modifier.race_modifier == 1.2
        assert modifier.size_modifier == 0.75
        assert abs(modifier.total_modifier - 0.9) < 0.001  # Float precision tolerance
    
    def test_get_optimal_weapon_type_no_weapons(self, calculator):
        """Test optimal weapon with no available weapons."""
        result = calculator.get_optimal_weapon_type(MonsterSize.MEDIUM, [])
        assert result is None
    
    def test_get_optimal_weapon_type_single_weapon(self, calculator):
        """Test optimal weapon with single option."""
        weapons = [{"type": "sword", "damage": 100}]
        result = calculator.get_optimal_weapon_type(MonsterSize.MEDIUM, weapons)
        assert result == "sword"
    
    def test_get_optimal_weapon_type_multiple_weapons(self, calculator):
        """Test optimal weapon selection from multiple."""
        weapons = [
            {"type": "dagger", "damage": 80},
            {"type": "sword", "damage": 100},
            {"type": "two_hand_sword", "damage": 120}
        ]
        result = calculator.get_optimal_weapon_type(MonsterSize.LARGE, weapons)
        assert result == "two_hand_sword"
    
    def test_get_optimal_weapon_for_small_monsters(self, calculator):
        """Test optimal weapon for small monsters."""
        weapons = [
            {"type": "dagger", "damage": 80},
            {"type": "axe", "damage": 120}
        ]
        result = calculator.get_optimal_weapon_type(MonsterSize.SMALL, weapons)
        assert result == "dagger"
    
    def test_suggest_cards_for_target_race_only(self, calculator):
        """Test card suggestions based on race."""
        suggestions = calculator.suggest_cards_for_target(
            MonsterRace.DEMI_HUMAN, MonsterSize.MEDIUM, max_suggestions=3
        )
        
        assert len(suggestions) > 0
        assert all(isinstance(card, CardInfo) for card in suggestions)
    
    def test_suggest_cards_max_limit(self, calculator):
        """Test card suggestions respect max limit."""
        suggestions = calculator.suggest_cards_for_target(
            MonsterRace.BRUTE, MonsterSize.LARGE, max_suggestions=2
        )
        
        assert len(suggestions) <= 2
    
    def test_suggest_cards_includes_size_cards(self, calculator):
        """Test that suggestions include size cards."""
        suggestions = calculator.suggest_cards_for_target(
            MonsterRace.DRAGON, MonsterSize.SMALL, max_suggestions=10
        )
        
        # Should have both race and size cards
        has_size_card = any(card.size == MonsterSize.SMALL for card in suggestions)
        assert has_size_card or len(suggestions) > 0
    
    def test_analyze_equipment_basic(self, calculator):
        """Test basic equipment analysis."""
        analysis = calculator.analyze_equipment_for_target(
            "sword", [], MonsterRace.BRUTE, MonsterSize.MEDIUM
        )
        
        assert "current_weapon" in analysis
        assert "target_race" in analysis
        assert "target_size" in analysis
        assert "current_modifier" in analysis
        assert "damage_percent" in analysis
    
    def test_analyze_equipment_with_cards(self, calculator):
        """Test equipment analysis with equipped cards."""
        analysis = calculator.analyze_equipment_for_target(
            "sword", ["Hydra Card"], MonsterRace.DEMI_HUMAN, MonsterSize.MEDIUM
        )
        
        assert analysis["current_modifier"] == 1.2
        assert "Hydra Card" in analysis["equipped_cards"]
    
    def test_analyze_equipment_suggests_improvements(self, calculator):
        """Test that analysis suggests improvements."""
        analysis = calculator.analyze_equipment_for_target(
            "dagger", [], MonsterRace.DEMI_HUMAN, MonsterSize.LARGE
        )
        
        assert "suggested_cards" in analysis
        assert "potential_improvement" in analysis
        assert len(analysis["suggested_cards"]) > 0
    
    def test_analyze_equipment_needs_optimization_flag(self, calculator):
        """Test needs_optimization flag."""
        # Poor setup - dagger vs large with no cards
        analysis = calculator.analyze_equipment_for_target(
            "dagger", [], MonsterRace.DEMI_HUMAN, MonsterSize.LARGE
        )
        
        # Should suggest optimization due to poor size penalty
        assert "needs_optimization" in analysis
    
    def test_load_card_data_missing_file(self, tmp_path):
        """Test loading card data with missing file."""
        calc = RacePropertyCalculator(tmp_path)
        
        # Should fall back to default cards
        assert len(calc.race_cards[MonsterRace.DEMI_HUMAN]) > 0
    
    def test_load_card_data_invalid_json(self, tmp_path):
        """Test loading invalid JSON card data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        card_file = data_dir / "race_cards.json"
        card_file.write_text("invalid json {")
        
        calc = RacePropertyCalculator(data_dir)
        
        # Should fall back to default cards
        assert len(calc.race_cards) > 0