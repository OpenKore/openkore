"""
Comprehensive tests for enchanting.py - covering all uncovered lines.
Target: 100% coverage of enchanting systems, probability calculations, and strategies.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.crafting.enchanting import (
    EnchantType,
    EnchantSlot,
    EnchantOption,
    EnchantPool,
    EnchantingManager,
)
from ai_sidecar.crafting.core import Material, CraftingManager


@pytest.fixture
def mock_crafting_manager():
    """Create mock crafting manager."""
    return Mock(spec=CraftingManager)


@pytest.fixture
def enchant_data_file(tmp_path):
    """Create temporary enchant data file."""
    enchant_file = tmp_path / "enchants.json"
    enchant_data = {
        "mora_enchants": {
            "temporal_boots": {
                "item_id": 2001,
                "item_name": "Temporal Boots",
                "slots": {
                    "slot_1": {
                        "enchants": [
                            {
                                "enchant_id": 1,
                                "enchant_name": "STR+3",
                                "stat_bonus": {"str": 3},
                                "weight": 100,
                                "is_desirable": True,
                            },
                            {
                                "enchant_id": 2,
                                "enchant_name": "AGI+3",
                                "stat_bonus": {"agi": 3},
                                "weight": 100,
                                "is_desirable": True,
                            },
                        ],
                        "cost_zeny": 50000,
                        "cost_items": [
                            {"item_id": 6001, "item_name": "Mora Coin", "quantity_required": 5}
                        ],
                        "can_reset": True,
                        "reset_cost_zeny": 10000,
                    }
                }
            }
        }
    }
    enchant_file.write_text(json.dumps(enchant_data))
    return tmp_path


@pytest.fixture
def enchanting_manager(mock_crafting_manager, enchant_data_file):
    """Create EnchantingManager instance."""
    return EnchantingManager(enchant_data_file, mock_crafting_manager)


class TestEnchantingManagerInit:
    """Test EnchantingManager initialization."""

    def test_init_with_data(self, mock_crafting_manager, enchant_data_file):
        """Test initialization with enchant data."""
        manager = EnchantingManager(enchant_data_file, mock_crafting_manager)
        assert len(manager.enchant_pools) > 0

    def test_init_missing_file(self, mock_crafting_manager, tmp_path):
        """Test initialization with missing file."""
        manager = EnchantingManager(tmp_path, mock_crafting_manager)
        assert len(manager.enchant_pools) == 0

    def test_init_invalid_json(self, mock_crafting_manager, tmp_path):
        """Test initialization with invalid JSON."""
        bad_file = tmp_path / "enchants.json"
        bad_file.write_text("invalid json")
        
        manager = EnchantingManager(tmp_path, mock_crafting_manager)
        assert len(manager.enchant_pools) == 0


class TestEnchantModels:
    """Test enchant models."""

    def test_enchant_option_creation(self):
        """Test creating enchant option."""
        enchant = EnchantOption(
            enchant_id=1,
            enchant_name="STR+5",
            stat_bonus={"str": 5},
            weight=50,
            is_desirable=True,
        )
        assert enchant.total_stat_value == 5

    def test_enchant_option_multiple_stats(self):
        """Test enchant with multiple stats."""
        enchant = EnchantOption(
            enchant_id=1,
            enchant_name="Mixed",
            stat_bonus={"str": 3, "agi": 2, "atk": 10},
            weight=50,
        )
        assert enchant.total_stat_value == 15

    def test_enchant_pool_creation(self):
        """Test creating enchant pool."""
        pool = EnchantPool(
            item_id=2001,
            item_name="Test Item",
            enchant_type=EnchantType.MORA,
            slot=EnchantSlot.SLOT_1,
            possible_enchants=[
                EnchantOption(
                    enchant_id=1, enchant_name="STR+3",
                    stat_bonus={"str": 3}, weight=100
                ),
            ],
            cost_zeny=50000,
        )
        assert pool.total_weight == 100

    def test_enchant_pool_has_desirable(self):
        """Test checking for desirable enchants."""
        pool = EnchantPool(
            item_id=2001,
            item_name="Test Item",
            enchant_type=EnchantType.MORA,
            slot=EnchantSlot.SLOT_1,
            possible_enchants=[
                EnchantOption(
                    enchant_id=1, enchant_name="Good",
                    stat_bonus={"str": 3}, weight=50, is_desirable=True
                ),
                EnchantOption(
                    enchant_id=2, enchant_name="Bad",
                    stat_bonus={"luk": 1}, weight=50
                ),
            ],
        )
        assert pool.has_desirable_enchants is True


class TestEnchantRetrieval:
    """Test enchant retrieval methods."""

    def test_get_enchant_options(self, enchanting_manager):
        """Test getting enchant options."""
        options = enchanting_manager.get_enchant_options(2001, EnchantSlot.SLOT_1)
        assert len(options) > 0

    def test_get_enchant_options_not_found(self, enchanting_manager):
        """Test getting options for non-existent item."""
        options = enchanting_manager.get_enchant_options(9999, EnchantSlot.SLOT_1)
        assert len(options) == 0


class TestProbabilityCalculations:
    """Test probability calculations."""

    def test_calculate_enchant_probability(self, enchanting_manager):
        """Test calculating enchant probability."""
        prob = enchanting_manager.calculate_enchant_probability(
            1, 2001, EnchantSlot.SLOT_1
        )
        assert 0 <= prob <= 100

    def test_calculate_enchant_probability_not_found(self, enchanting_manager):
        """Test probability for non-existent enchant."""
        prob = enchanting_manager.calculate_enchant_probability(
            9999, 2001, EnchantSlot.SLOT_1
        )
        assert prob == 0.0

    def test_calculate_enchant_probability_invalid_pool(self, enchanting_manager):
        """Test probability with invalid pool."""
        prob = enchanting_manager.calculate_enchant_probability(
            1, 9999, EnchantSlot.SLOT_1
        )
        assert prob == 0.0

    def test_get_expected_attempts(self, enchanting_manager):
        """Test calculating expected attempts."""
        attempts = enchanting_manager.get_expected_attempts(
            1, 2001, EnchantSlot.SLOT_1
        )
        assert attempts > 0

    def test_get_expected_attempts_zero_probability(self, enchanting_manager):
        """Test expected attempts with zero probability."""
        attempts = enchanting_manager.get_expected_attempts(
            9999, 2001, EnchantSlot.SLOT_1
        )
        assert attempts == 0


class TestEnchantCost:
    """Test enchant cost calculations."""

    def test_get_enchant_cost(self, enchanting_manager):
        """Test getting enchant cost."""
        cost = enchanting_manager.get_enchant_cost(2001, EnchantSlot.SLOT_1)
        assert "zeny" in cost
        assert "items" in cost
        assert "can_reset" in cost

    def test_get_enchant_cost_not_found(self, enchanting_manager):
        """Test cost for non-existent pool."""
        cost = enchanting_manager.get_enchant_cost(9999, EnchantSlot.SLOT_1)
        assert "error" in cost


class TestResetDecision:
    """Test enchant reset decisions."""

    def test_should_reset_enchant_no_matches(self, enchanting_manager):
        """Test reset decision with no matches."""
        current = [1, 2]
        target = [3, 4]
        should_reset = enchanting_manager.should_reset_enchant(current, target, 2001)
        assert should_reset is True

    def test_should_reset_enchant_some_matches(self, enchanting_manager):
        """Test reset decision with partial matches."""
        current = [1, 2]
        target = [1, 3, 4]
        should_reset = enchanting_manager.should_reset_enchant(current, target, 2001)
        assert should_reset is True

    def test_should_reset_enchant_mostly_complete(self, enchanting_manager):
        """Test reset decision with mostly complete."""
        current = [1, 2]
        target = [1, 2, 3]
        should_reset = enchanting_manager.should_reset_enchant(current, target, 2001)
        assert should_reset is False


class TestOptimalStrategy:
    """Test optimal enchanting strategy."""

    def test_get_optimal_strategy(self, enchanting_manager):
        """Test getting optimal strategy."""
        character_state = {
            "str": 80,
            "job": "Knight",
        }
        
        strategy = enchanting_manager.get_optimal_enchant_strategy(
            2001, character_state, budget=1000000
        )
        
        assert "total_expected_cost" in strategy
        assert "recommendations" in strategy
        assert "affordable" in strategy

    def test_get_optimal_strategy_no_pools(self, enchanting_manager):
        """Test strategy for item with no pools."""
        strategy = enchanting_manager.get_optimal_enchant_strategy(
            9999, {}, budget=1000000
        )
        assert "error" in strategy

    def test_get_optimal_strategy_low_budget(self, enchanting_manager):
        """Test strategy with insufficient budget."""
        strategy = enchanting_manager.get_optimal_enchant_strategy(
            2001, {}, budget=1000
        )
        assert strategy["affordable"] is False


class TestEnchantParsing:
    """Test enchant data parsing."""

    def test_parse_enchant_type(self, enchanting_manager):
        """Test parsing enchant type."""
        assert enchanting_manager._parse_enchant_type("mora_enchants") == EnchantType.MORA
        assert enchanting_manager._parse_enchant_type("malangdo_system") == EnchantType.MALANGDO
        assert enchanting_manager._parse_enchant_type("temporal_boots") == EnchantType.TEMPORAL
        assert enchanting_manager._parse_enchant_type("unknown") is None


class TestStatistics:
    """Test enchanting statistics."""

    def test_get_statistics(self, enchanting_manager):
        """Test getting statistics."""
        stats = enchanting_manager.get_statistics()
        
        assert "total_pools" in stats
        assert "by_enchant_type" in stats
        assert "resetable_pools" in stats
        assert "total_enchant_options" in stats

    def test_get_statistics_empty(self, mock_crafting_manager, tmp_path):
        """Test statistics with no pools."""
        manager = EnchantingManager(tmp_path, mock_crafting_manager)
        stats = manager.get_statistics()
        
        assert stats["total_pools"] == 0