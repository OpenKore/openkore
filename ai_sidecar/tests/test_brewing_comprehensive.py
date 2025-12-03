"""
Comprehensive tests for brewing.py - covering all uncovered lines.
Target: 100% coverage of potion brewing, success rates, and profitability calculations.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock

from ai_sidecar.crafting.brewing import (
    PotionType,
    BrewableItem,
    BrewingManager,
)
from ai_sidecar.crafting.core import Material, CraftingManager


@pytest.fixture
def mock_crafting_manager():
    """Create mock crafting manager."""
    return Mock(spec=CraftingManager)


@pytest.fixture
def brew_data_file(tmp_path):
    """Create temporary brew data file."""
    brew_file = tmp_path / "brew_items.json"
    brew_data = {
        "items": [
            {
                "item_id": 501,
                "item_name": "Red Potion",
                "potion_type": "healing",
                "materials": [
                    {"item_id": 507, "item_name": "Red Herb", "quantity_required": 1},
                    {"item_id": 713, "item_name": "Empty Bottle", "quantity_required": 1},
                ],
                "required_skill": "AM_PHARMACY",
                "required_skill_level": 1,
                "base_success_rate": 50.0,
                "batch_size": 1,
            },
            {
                "item_id": 545,
                "item_name": "Condensed Red Potion",
                "potion_type": "condensed",
                "materials": [
                    {"item_id": 501, "item_name": "Red Potion", "quantity_required": 10},
                ],
                "required_skill": "AM_TWILIGHT_PHARMACY",
                "required_skill_level": 5,
                "base_success_rate": 70.0,
                "batch_size": 3,
            },
        ]
    }
    brew_file.write_text(json.dumps(brew_data))
    return tmp_path


@pytest.fixture
def brewing_manager(mock_crafting_manager, brew_data_file):
    """Create BrewingManager instance."""
    return BrewingManager(brew_data_file, mock_crafting_manager)


class TestBrewingManagerInit:
    """Test BrewingManager initialization."""

    def test_init_with_data(self, mock_crafting_manager, brew_data_file):
        """Test initialization with brew data."""
        manager = BrewingManager(brew_data_file, mock_crafting_manager)
        assert len(manager.brewable_items) == 2

    def test_init_missing_file(self, mock_crafting_manager, tmp_path):
        """Test initialization with missing file."""
        manager = BrewingManager(tmp_path, mock_crafting_manager)
        assert len(manager.brewable_items) == 0

    def test_init_invalid_json(self, mock_crafting_manager, tmp_path):
        """Test initialization with invalid JSON."""
        bad_file = tmp_path / "brew_items.json"
        bad_file.write_text("invalid json")
        
        manager = BrewingManager(tmp_path, mock_crafting_manager)
        assert len(manager.brewable_items) == 0

    def test_init_invalid_item_data(self, mock_crafting_manager, tmp_path):
        """Test initialization with invalid item data."""
        brew_file = tmp_path / "brew_items.json"
        brew_data = {
            "items": [
                {"item_id": 1, "item_name": "Bad Item"},  # Missing required fields
            ]
        }
        brew_file.write_text(json.dumps(brew_data))
        
        manager = BrewingManager(tmp_path, mock_crafting_manager)
        assert len(manager.brewable_items) == 0


class TestBrewableItemModel:
    """Test BrewableItem model."""

    def test_brewable_item_creation(self):
        """Test creating brewable item."""
        item = BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="AM_PHARMACY",
            required_skill_level=1,
            base_success_rate=50.0,
            batch_size=1,
        )
        assert item.item_id == 501
        assert item.is_batch_brewable is False

    def test_brewable_item_batch(self):
        """Test batch brewable item."""
        item = BrewableItem(
            item_id=545,
            item_name="Condensed Red Potion",
            potion_type=PotionType.CONDENSED,
            materials=[],
            required_skill="AM_TWILIGHT_PHARMACY",
            required_skill_level=5,
            base_success_rate=70.0,
            batch_size=3,
        )
        assert item.is_batch_brewable is True

    def test_brewable_item_advanced_skill(self):
        """Test item requiring advanced skill."""
        item = BrewableItem(
            item_id=545,
            item_name="Advanced Item",
            potion_type=PotionType.GENETICS,
            materials=[],
            required_skill="GN_PHARMACY",
            required_skill_level=7,
            base_success_rate=60.0,
        )
        assert item.requires_advanced_skill is True


class TestBrewRateCalculation:
    """Test brewing success rate calculation."""

    def test_calculate_brew_rate_basic(self, brewing_manager):
        """Test basic brew rate calculation."""
        character_state = {
            "int": 50,
            "dex": 40,
            "luk": 30,
            "job_level": 20,
            "skills": {"AM_PHARMACY": 5},
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        assert 0 <= rate <= 100

    def test_calculate_brew_rate_high_stats(self, brewing_manager):
        """Test brew rate with high stats."""
        character_state = {
            "int": 99,
            "dex": 99,
            "luk": 99,
            "job_level": 50,
            "skills": {"AM_PHARMACY": 10},
            "brew_bonus": 10,
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        assert rate == 100.0  # Should be capped at 100

    def test_calculate_brew_rate_low_stats(self, brewing_manager):
        """Test brew rate with low stats."""
        character_state = {
            "int": 1,
            "dex": 1,
            "luk": 1,
            "job_level": 1,
            "skills": {},
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        assert rate >= 0

    def test_calculate_brew_rate_not_found(self, brewing_manager):
        """Test brew rate for non-existent item."""
        rate = brewing_manager.calculate_brew_rate(9999, {})
        assert rate == 0.0


class TestBatchBrewing:
    """Test batch brewing functionality."""

    def test_get_batch_brew_info(self, brewing_manager):
        """Test getting batch brew info."""
        inventory = {
            507: 10,  # Red Herb
            713: 10,  # Empty Bottle
        }
        
        info = brewing_manager.get_batch_brew_info(501, inventory)
        assert info["can_brew"] is True
        assert info["max_batches"] == 10

    def test_get_batch_brew_info_insufficient_materials(self, brewing_manager):
        """Test batch brew with insufficient materials."""
        inventory = {
            507: 3,  # Only 3 red herbs
            713: 10,  # Enough bottles
        }
        
        info = brewing_manager.get_batch_brew_info(501, inventory)
        assert info["max_batches"] == 3

    def test_get_batch_brew_info_no_materials(self, brewing_manager):
        """Test batch brew with no materials."""
        inventory = {}
        
        info = brewing_manager.get_batch_brew_info(501, inventory)
        assert info["can_brew"] is False
        assert info["max_batches"] == 0

    def test_get_batch_brew_info_not_found(self, brewing_manager):
        """Test batch brew for non-existent item."""
        info = brewing_manager.get_batch_brew_info(9999, {})
        assert info["can_brew"] is False
        assert "error" in info


class TestProfitability:
    """Test profitability calculations."""

    def test_get_most_profitable_brew(self, brewing_manager):
        """Test finding most profitable brew."""
        inventory = {
            507: 100,
            713: 100,
            501: 100,
        }
        character_state = {
            "int": 50,
            "dex": 40,
            "luk": 30,
            "job_level": 20,
            "skills": {
                "AM_PHARMACY": 10,
                "AM_TWILIGHT_PHARMACY": 10,
            },
        }
        market_prices = {
            501: 100,
            545: 500,
            507: 10,
            713: 5,
        }
        
        result = brewing_manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )
        assert result is not None
        assert "profit" in result

    def test_get_most_profitable_brew_no_materials(self, brewing_manager):
        """Test profitability with no materials."""
        result = brewing_manager.get_most_profitable_brew({}, {}, {})
        assert result is None

    def test_get_most_profitable_brew_insufficient_skill(self, brewing_manager):
        """Test profitability with insufficient skill."""
        inventory = {
            507: 100,
            713: 100,
        }
        character_state = {
            "skills": {},  # No skills
        }
        market_prices = {
            501: 100,
            507: 10,
            713: 5,
        }
        
        result = brewing_manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )
        # Should skip items without required skills
        assert result is None or result["profit"] > 0


class TestBrewableItemRetrieval:
    """Test brewable item retrieval."""

    def test_get_brewable_items_by_type(self, brewing_manager):
        """Test getting items by type."""
        healing = brewing_manager.get_brewable_items_by_type(PotionType.HEALING)
        assert len(healing) == 1

    def test_get_brewable_items_by_type_empty(self, brewing_manager):
        """Test getting items for type with no items."""
        special = brewing_manager.get_brewable_items_by_type(PotionType.SPECIAL)
        assert len(special) == 0

    def test_get_available_brews(self, brewing_manager):
        """Test getting available brews."""
        inventory = {
            507: 10,
            713: 10,
        }
        character_state = {
            "skills": {"AM_PHARMACY": 5},
        }
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        assert len(available) > 0

    def test_get_available_brews_no_skill(self, brewing_manager):
        """Test available brews without skill."""
        inventory = {
            507: 10,
            713: 10,
        }
        character_state = {
            "skills": {},
        }
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        assert len(available) == 0

    def test_get_available_brews_no_materials(self, brewing_manager):
        """Test available brews without materials."""
        inventory = {}
        character_state = {
            "skills": {"AM_PHARMACY": 10},
        }
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        assert len(available) == 0


class TestStatistics:
    """Test brewing statistics."""

    def test_get_statistics(self, brewing_manager):
        """Test getting statistics."""
        stats = brewing_manager.get_statistics()
        
        assert stats["total_brewable"] == 2
        assert "by_potion_type" in stats
        assert "batch_brewable" in stats

    def test_get_statistics_empty(self, mock_crafting_manager, tmp_path):
        """Test statistics with no items."""
        manager = BrewingManager(tmp_path, mock_crafting_manager)
        stats = manager.get_statistics()
        
        assert stats["total_brewable"] == 0
        assert stats["batch_brewable"] == 0