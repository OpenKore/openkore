"""
Comprehensive tests for cards.py - covering all uncovered lines.
Target: 100% coverage of card slotting, combos, and optimal card selection.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.crafting.cards import (
    CardSlotType,
    Card,
    CardCombo,
    CardManager,
)


@pytest.fixture
def card_data_file(tmp_path):
    """Create temporary card data file."""
    card_file = tmp_path / "cards.json"
    card_data = {
        "cards": [
            {
                "card_id": 4001,
                "card_name": "Poring Card",
                "slot_type": "armor",
                "effects": {"luk": 2, "perfect_dodge": 1},
                "combo_with": [4002],
                "market_value": 5000,
                "drop_source": "Poring",
            },
            {
                "card_id": 4002,
                "card_name": "Drops Card",
                "slot_type": "armor",
                "effects": {"dex": 1},
                "combo_with": [4001],
                "market_value": 3000,
                "drop_source": "Drops",
            },
            {
                "card_id": 4003,
                "card_name": "Hydra Card",
                "slot_type": "weapon",
                "effects": {"damage_vs_demi_human": 20},
                "market_value": 50000,
                "drop_source": "Hydra",
            },
        ],
        "combos": [
            {
                "combo_id": 1,
                "combo_name": "Poring Set",
                "required_cards": [4001, 4002],
                "combo_effect": "Additional perfect dodge +5",
                "stat_bonus": {"perfect_dodge": 5},
            }
        ]
    }
    card_file.write_text(json.dumps(card_data))
    return tmp_path


@pytest.fixture
def card_manager(card_data_file):
    """Create CardManager instance with test data."""
    return CardManager(card_data_file)


class TestCardManagerInit:
    """Test CardManager initialization."""

    def test_init_with_data(self, card_data_file):
        """Test initialization with card data."""
        manager = CardManager(card_data_file)
        assert len(manager.cards) == 3
        assert len(manager.combos) == 1

    def test_init_missing_file(self, tmp_path):
        """Test initialization with missing file."""
        manager = CardManager(tmp_path)
        assert len(manager.cards) == 0
        assert len(manager.combos) == 0

    def test_init_invalid_json(self, tmp_path):
        """Test initialization with invalid JSON."""
        bad_file = tmp_path / "cards.json"
        bad_file.write_text("invalid json")
        
        manager = CardManager(tmp_path)
        assert len(manager.cards) == 0

    def test_init_invalid_card_data(self, tmp_path):
        """Test initialization with invalid card data."""
        card_file = tmp_path / "cards.json"
        card_data = {
            "cards": [
                {"card_id": 1, "card_name": "Bad Card"},  # Missing required fields
            ]
        }
        card_file.write_text(json.dumps(card_data))
        
        manager = CardManager(tmp_path)
        # Should skip invalid card
        assert len(manager.cards) == 0

    def test_init_invalid_combo_data(self, tmp_path):
        """Test initialization with invalid combo data."""
        card_file = tmp_path / "cards.json"
        card_data = {
            "cards": [],
            "combos": [
                {"combo_id": 1, "combo_name": "Bad Combo"},  # Missing required fields
            ]
        }
        card_file.write_text(json.dumps(card_data))
        
        manager = CardManager(tmp_path)
        assert len(manager.combos) == 0


class TestCardModel:
    """Test Card model."""

    def test_card_creation(self):
        """Test creating a card."""
        card = Card(
            card_id=4001,
            card_name="Test Card",
            slot_type=CardSlotType.WEAPON,
            effects={"atk": 10},
            combo_with=[4002],
            market_value=10000,
        )
        assert card.card_id == 4001
        assert card.has_combos is True

    def test_card_no_combos(self):
        """Test card without combos."""
        card = Card(
            card_id=4001,
            card_name="Test Card",
            slot_type=CardSlotType.WEAPON,
        )
        assert card.has_combos is False


class TestCardComboModel:
    """Test CardCombo model."""

    def test_combo_creation(self):
        """Test creating a combo."""
        combo = CardCombo(
            combo_id=1,
            combo_name="Test Combo",
            required_cards=[4001, 4002],
            combo_effect="Test effect",
            stat_bonus={"str": 5},
        )
        assert combo.card_count == 2

    def test_combo_is_complete(self):
        """Test combo completion flag."""
        combo = CardCombo(
            combo_id=1,
            combo_name="Test Combo",
            required_cards=[4001, 4002],
            combo_effect="Test effect",
            is_complete=True,
        )
        assert combo.is_complete is True


class TestCardRetrieval:
    """Test card retrieval methods."""

    def test_get_card(self, card_manager):
        """Test getting card by ID."""
        card = card_manager.get_card(4001)
        assert card is not None
        assert card.card_name == "Poring Card"

    def test_get_card_not_found(self, card_manager):
        """Test getting non-existent card."""
        card = card_manager.get_card(9999)
        assert card is None

    def test_get_valid_cards(self, card_manager):
        """Test getting valid cards for slot type."""
        armor_cards = card_manager.get_valid_cards(CardSlotType.ARMOR)
        assert len(armor_cards) == 2

    def test_get_valid_cards_weapon(self, card_manager):
        """Test getting weapon cards."""
        weapon_cards = card_manager.get_valid_cards(CardSlotType.WEAPON)
        assert len(weapon_cards) == 1

    def test_get_valid_cards_empty(self, card_manager):
        """Test getting cards for empty slot type."""
        accessory_cards = card_manager.get_valid_cards(CardSlotType.ACCESSORY)
        assert len(accessory_cards) == 0


class TestCardCombos:
    """Test card combo detection."""

    def test_check_combo_active(self, card_manager):
        """Test detecting active combo."""
        equipped = [4001, 4002]
        combos = card_manager.check_combo(equipped)
        assert len(combos) == 1
        assert combos[0].is_complete is True

    def test_check_combo_incomplete(self, card_manager):
        """Test with incomplete combo."""
        equipped = [4001]
        combos = card_manager.check_combo(equipped)
        assert len(combos) == 0

    def test_check_combo_no_cards(self, card_manager):
        """Test with no cards equipped."""
        combos = card_manager.check_combo([])
        assert len(combos) == 0

    def test_get_missing_combo_cards(self, card_manager):
        """Test getting missing combo cards."""
        equipped = [4001]
        missing = card_manager.get_missing_combo_cards(1, equipped)
        assert 4002 in missing

    def test_get_missing_combo_cards_complete(self, card_manager):
        """Test missing cards with complete combo."""
        equipped = [4001, 4002]
        missing = card_manager.get_missing_combo_cards(1, equipped)
        assert len(missing) == 0

    def test_get_missing_combo_cards_invalid(self, card_manager):
        """Test missing cards for invalid combo."""
        missing = card_manager.get_missing_combo_cards(9999, [])
        assert len(missing) == 0


class TestCardRemoval:
    """Test card removal risk calculation."""

    def test_calculate_removal_risk_single_card(self, card_manager):
        """Test removal risk for single card."""
        risk = card_manager.calculate_card_removal_risk(1001, 1)
        assert risk["success_rate"] == 90.0
        assert risk["card_destruction_rate"] == 10.0

    def test_calculate_removal_risk_two_cards(self, card_manager):
        """Test removal risk for two cards."""
        risk = card_manager.calculate_card_removal_risk(1001, 2)
        assert risk["success_rate"] == 80.0
        assert risk["card_destruction_rate"] == 20.0

    def test_calculate_removal_risk_three_cards(self, card_manager):
        """Test removal risk for three cards."""
        risk = card_manager.calculate_card_removal_risk(1001, 3)
        assert risk["success_rate"] == 70.0
        assert risk["card_destruction_rate"] == 30.0

    def test_calculate_removal_risk_four_cards(self, card_manager):
        """Test removal risk for four+ cards."""
        risk = card_manager.calculate_card_removal_risk(1001, 4)
        assert risk["success_rate"] == 60.0
        assert risk["card_destruction_rate"] == 40.0

    def test_calculate_removal_risk_recommendations(self, card_manager):
        """Test risk recommendations."""
        low_risk = card_manager.calculate_card_removal_risk(1001, 1)
        assert "Low risk" in low_risk["recommendation"]
        
        medium_risk = card_manager.calculate_card_removal_risk(1001, 3)
        assert "Medium risk" in medium_risk["recommendation"]
        
        high_risk = card_manager.calculate_card_removal_risk(1001, 4)
        assert "High risk" in high_risk["recommendation"]


class TestOptimalCardSetup:
    """Test optimal card configuration selection."""

    def test_get_optimal_card_setup(self, card_manager):
        """Test getting optimal card setup."""
        character_state = {
            "str": 80,
            "agi": 60,
            "vit": 40,
            "int": 30,
            "dex": 50,
            "luk": 20,
            "job": "Swordman",
        }
        available_cards = [4001, 4002, 4003]
        equipment = {
            "armor": {"has_slots": True, "slot_count": 1},
            "weapon": {"has_slots": True, "slot_count": 2},
        }
        
        result = card_manager.get_optimal_card_setup(
            character_state, available_cards, equipment
        )
        
        assert "recommendations" in result
        assert "active_combos" in result

    def test_get_optimal_card_setup_no_slots(self, card_manager):
        """Test optimal setup with no slotted equipment."""
        character_state = {"str": 50}
        equipment = {
            "armor": {"has_slots": False},
        }
        
        result = card_manager.get_optimal_card_setup(character_state, [], equipment)
        assert len(result["recommendations"]) == 0

    def test_get_optimal_card_setup_no_available(self, card_manager):
        """Test optimal setup with no available cards."""
        character_state = {"str": 50}
        equipment = {
            "armor": {"has_slots": True, "slot_count": 1},
        }
        
        result = card_manager.get_optimal_card_setup(character_state, [], equipment)
        assert len(result["recommendations"]) == 0

    def test_map_equipment_to_card_slot(self, card_manager):
        """Test equipment slot mapping."""
        assert card_manager._map_equipment_to_card_slot("weapon") == CardSlotType.WEAPON
        assert card_manager._map_equipment_to_card_slot("armor") == CardSlotType.ARMOR
        assert card_manager._map_equipment_to_card_slot("garment") == CardSlotType.GARMENT
        assert card_manager._map_equipment_to_card_slot("shoes") == CardSlotType.FOOTGEAR
        assert card_manager._map_equipment_to_card_slot("headgear") == CardSlotType.HEADGEAR
        assert card_manager._map_equipment_to_card_slot("shield") == CardSlotType.SHIELD
        assert card_manager._map_equipment_to_card_slot("accessory1") == CardSlotType.ACCESSORY
        assert card_manager._map_equipment_to_card_slot("invalid") is None

    def test_get_primary_stat(self, card_manager):
        """Test primary stat determination."""
        character_state = {
            "str": 90,
            "agi": 40,
            "vit": 30,
            "int": 20,
            "dex": 50,
            "luk": 10,
        }
        stat = card_manager._get_primary_stat(character_state)
        assert stat == "str"

    def test_score_card_for_build(self, card_manager):
        """Test card scoring for build."""
        card = Card(
            card_id=4001,
            card_name="STR Card",
            slot_type=CardSlotType.WEAPON,
            effects={"str": 5},
            market_value=10000,
        )
        
        character_state = {
            "str": 90,
            "job": "Knight",
        }
        
        score = card_manager._score_card_for_build(card, character_state)
        assert score > 0

    def test_score_card_with_combos(self, card_manager):
        """Test scoring card with combo potential."""
        card = Card(
            card_id=4001,
            card_name="Combo Card",
            slot_type=CardSlotType.WEAPON,
            combo_with=[4002],
            market_value=5000,
        )
        
        character_state = {"str": 50}
        score = card_manager._score_card_for_build(card, character_state)
        assert score >= 50.0  # Combo bonus


class TestStatistics:
    """Test card statistics."""

    def test_get_statistics(self, card_manager):
        """Test getting statistics."""
        stats = card_manager.get_statistics()
        
        assert stats["total_cards"] == 3
        assert "by_slot_type" in stats
        assert stats["total_combos"] == 1
        assert stats["cards_with_combos"] == 2

    def test_get_statistics_empty(self):
        """Test statistics with no cards."""
        manager = CardManager(Path("/tmp/nonexistent"))
        stats = manager.get_statistics()
        
        assert stats["total_cards"] == 0
        assert stats["total_combos"] == 0