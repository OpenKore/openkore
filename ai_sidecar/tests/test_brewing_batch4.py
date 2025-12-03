"""
Comprehensive tests for crafting/brewing.py - BATCH 4.
Target: 95%+ coverage (currently 82.63%, 21 uncovered lines).
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, MagicMock
from ai_sidecar.crafting.brewing import (
    BrewingManager,
    BrewableItem,
    PotionType,
)
from ai_sidecar.crafting.core import Material


class TestBrewingManager:
    """Test BrewingManager functionality."""
    
    @pytest.fixture
    def mock_crafting_manager(self):
        """Create mock crafting manager."""
        return Mock()
    
    @pytest.fixture
    def temp_data_dir(self, tmp_path):
        """Create temporary data directory."""
        return tmp_path
    
    @pytest.fixture
    def brewing_manager(self, temp_data_dir, mock_crafting_manager):
        """Create brewing manager instance."""
        return BrewingManager(temp_data_dir, mock_crafting_manager)
    
    @pytest.fixture
    def sample_brewable_item(self):
        """Sample brewable item."""
        return BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[
                Material(item_id=507, item_name="Red Herb", quantity_required=1),
                Material(item_id=713, item_name="Empty Bottle", quantity_required=1),
            ],
            required_skill="Pharmacy",
            required_skill_level=1,
            base_success_rate=70.0,
            batch_size=1,
        )
    
    def test_initialization(self, brewing_manager):
        """Test brewing manager initialization."""
        assert isinstance(brewing_manager.brewable_items, dict)
        assert brewing_manager.crafting is not None
    
    def test_brewable_item_properties(self, sample_brewable_item):
        """Test BrewableItem properties."""
        assert sample_brewable_item.item_id == 501
        assert sample_brewable_item.item_name == "Red Potion"
        assert sample_brewable_item.potion_type == PotionType.HEALING
        assert sample_brewable_item.is_batch_brewable is False
        assert sample_brewable_item.requires_advanced_skill is False
    
    def test_brewable_item_batch_brewable(self):
        """Test batch brewable property."""
        item = BrewableItem(
            item_id=1,
            item_name="Test",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="Pharmacy",
            required_skill_level=1,
            base_success_rate=100.0,
            batch_size=5,
        )
        
        assert item.is_batch_brewable is True
    
    def test_brewable_item_advanced_skill(self):
        """Test requires advanced skill property."""
        item = BrewableItem(
            item_id=1,
            item_name="Test",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="Pharmacy",
            required_skill_level=10,
            base_success_rate=100.0,
        )
        
        assert item.requires_advanced_skill is True
    
    def test_calculate_brew_rate_basic(self, brewing_manager, sample_brewable_item):
        """Test basic brew rate calculation."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        character_state = {
            "int": 50,
            "dex": 40,
            "luk": 30,
            "job_level": 50,
            "skills": {"Pharmacy": 5},
            "brew_bonus": 0,
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        
        # Base 70 + INT*0.6 + DEX*0.4 + LUK*0.2 + skill*1 + job*0.15
        # = 70 + 30 + 16 + 6 + 5 + 7.5 = 134.5 (capped at 100)
        assert rate == 100.0
    
    def test_calculate_brew_rate_low_stats(self, brewing_manager, sample_brewable_item):
        """Test brew rate with low stats."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        character_state = {
            "int": 1,
            "dex": 1,
            "luk": 1,
            "job_level": 1,
            "skills": {},
            "brew_bonus": 0,
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        
        # Base 70 + very low bonuses
        assert 70.0 < rate < 75.0
    
    def test_calculate_brew_rate_item_not_found(self, brewing_manager):
        """Test brew rate for non-existent item."""
        rate = brewing_manager.calculate_brew_rate(9999, {})
        assert rate == 0.0
    
    def test_get_batch_brew_info(self, brewing_manager, sample_brewable_item):
        """Test batch brew info calculation."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {
            507: 10,  # Red Herb
            713: 5,   # Empty Bottle (limiting factor)
        }
        
        info = brewing_manager.get_batch_brew_info(501, inventory)
        
        assert info["can_brew"] is True
        assert info["max_batches"] == 5  # Limited by bottles
        assert info["items_per_batch"] == 1
        assert info["total_items"] == 5
    
    def test_get_batch_brew_info_item_not_found(self, brewing_manager):
        """Test batch info for non-existent item."""
        info = brewing_manager.get_batch_brew_info(9999, {})
        
        assert info["can_brew"] is False
        assert "error" in info
    
    def test_get_batch_brew_info_no_materials(self, brewing_manager, sample_brewable_item):
        """Test batch info with no materials."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        info = brewing_manager.get_batch_brew_info(501, {})
        
        assert info["can_brew"] is False
        assert info["max_batches"] == 0
    
    def test_get_most_profitable_brew(self, brewing_manager, sample_brewable_item):
        """Test finding most profitable brew."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 10, 713: 10}
        character_state = {
            "int": 50,
            "dex": 40,
            "luk": 30,
            "job_level": 50,
            "skills": {"Pharmacy": 5},
        }
        market_prices = {
            501: 500,  # Red Potion sells for 500z
            507: 10,   # Red Herb costs 10z
            713: 5,    # Empty Bottle costs 5z
        }
        
        result = brewing_manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )
        
        assert result is not None
        assert result["item_id"] == 501
        assert result["profit"] > 0
    
    def test_get_most_profitable_brew_no_materials(self, brewing_manager, sample_brewable_item):
        """Test profitable brew with no materials."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        result = brewing_manager.get_most_profitable_brew({}, {}, {})
        
        assert result is None
    
    def test_get_most_profitable_brew_no_skill(self, brewing_manager, sample_brewable_item):
        """Test profitable brew without required skill."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 10, 713: 10}
        character_state = {
            "skills": {},  # No Pharmacy skill
        }
        market_prices = {501: 500, 507: 10, 713: 5}
        
        result = brewing_manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )
        
        assert result is None
    
    def test_get_brewable_items_by_type(self, brewing_manager, sample_brewable_item):
        """Test filtering brewable items by type."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        healing_items = brewing_manager.get_brewable_items_by_type(
            PotionType.HEALING
        )
        
        assert len(healing_items) == 1
        assert healing_items[0].item_id == 501
    
    def test_get_brewable_items_by_type_empty(self, brewing_manager):
        """Test filtering with no matching items."""
        items = brewing_manager.get_brewable_items_by_type(PotionType.GENETICS)
        assert len(items) == 0
    
    def test_get_available_brews(self, brewing_manager, sample_brewable_item):
        """Test getting available brews."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 10, 713: 10}
        character_state = {"skills": {"Pharmacy": 5}}
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        
        assert len(available) == 1
        assert available[0].item_id == 501
    
    def test_get_available_brews_no_skill(self, brewing_manager, sample_brewable_item):
        """Test available brews without skill."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 10, 713: 10}
        character_state = {"skills": {}}  # No Pharmacy
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        
        assert len(available) == 0
    
    def test_get_available_brews_no_materials(self, brewing_manager, sample_brewable_item):
        """Test available brews without materials."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {}
        character_state = {"skills": {"Pharmacy": 10}}
        
        available = brewing_manager.get_available_brews(inventory, character_state)
        
        assert len(available) == 0
    
    def test_get_statistics(self, brewing_manager, sample_brewable_item):
        """Test getting brewing statistics."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        batch_item = BrewableItem(
            item_id=502,
            item_name="Batch Potion",
            potion_type=PotionType.STAT_BOOST,
            materials=[],
            required_skill="Pharmacy",
            required_skill_level=1,
            base_success_rate=100.0,
            batch_size=5,
        )
        brewing_manager.brewable_items[502] = batch_item
        
        stats = brewing_manager.get_statistics()
        
        assert stats["total_brewable"] == 2
        assert stats["batch_brewable"] == 1
        assert PotionType.HEALING in stats["by_potion_type"]
    
    def test_can_brew_by_id(self, brewing_manager, sample_brewable_item):
        """Test can_brew with item ID."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        # Just check if item exists
        assert brewing_manager.can_brew("501") is True
    
    def test_can_brew_by_name(self, brewing_manager, sample_brewable_item):
        """Test can_brew with item name."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        assert brewing_manager.can_brew("Red Potion") is True
    
    def test_can_brew_not_found(self, brewing_manager):
        """Test can_brew with unknown item."""
        assert brewing_manager.can_brew("Unknown Item") is False
    
    def test_can_brew_with_state(self, brewing_manager, sample_brewable_item):
        """Test can_brew with character state."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        character_state = {"skills": {"Pharmacy": 5}}
        
        assert brewing_manager.can_brew("501", character_state=character_state) is True
    
    def test_can_brew_insufficient_skill(self, brewing_manager, sample_brewable_item):
        """Test can_brew without required skill level."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        character_state = {"skills": {"Pharmacy": 0}}
        
        assert brewing_manager.can_brew("501", character_state=character_state) is False
    
    def test_can_brew_with_inventory(self, brewing_manager, sample_brewable_item):
        """Test can_brew with inventory check."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 5, 713: 5}
        character_state = {"skills": {"Pharmacy": 5}}
        
        assert brewing_manager.can_brew(
            "501",
            inventory=inventory,
            character_state=character_state
        ) is True
    
    def test_can_brew_insufficient_materials(self, brewing_manager, sample_brewable_item):
        """Test can_brew without sufficient materials."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 0}  # Missing Red Herb
        character_state = {"skills": {"Pharmacy": 5}}
        
        assert brewing_manager.can_brew(
            "501",
            inventory=inventory,
            character_state=character_state
        ) is False
    
    def test_get_required_materials_by_id(self, brewing_manager, sample_brewable_item):
        """Test getting required materials by ID."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        materials = brewing_manager.get_required_materials("501")
        
        assert len(materials) == 2
        assert materials[0].item_id == 507
        assert materials[1].item_id == 713
    
    def test_get_required_materials_by_name(self, brewing_manager, sample_brewable_item):
        """Test getting required materials by name."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        materials = brewing_manager.get_required_materials("Red Potion")
        
        assert len(materials) == 2
    
    def test_get_required_materials_not_found(self, brewing_manager):
        """Test getting materials for unknown item."""
        materials = brewing_manager.get_required_materials("Unknown")
        assert len(materials) == 0
    
    @pytest.mark.asyncio
    async def test_brew(self, brewing_manager):
        """Test brewing an item."""
        result = await brewing_manager.brew("Red Potion", quantity=3)
        
        assert result["success"] is True
        assert result["recipe"] == "Red Potion"
        assert result["quantity"] == 3
    
    def test_calculate_brew_rate_with_equipment_bonus(
        self, brewing_manager, sample_brewable_item
    ):
        """Test brew rate with equipment bonus."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        character_state = {
            "int": 30,
            "dex": 30,
            "luk": 20,
            "job_level": 30,
            "skills": {"Pharmacy": 3},
            "brew_bonus": 10,  # Equipment bonus
        }
        
        rate = brewing_manager.calculate_brew_rate(501, character_state)
        
        # Should include equipment bonus
        assert rate > 70.0
    
    def test_get_batch_brew_info_details(self, brewing_manager, sample_brewable_item):
        """Test detailed batch brew info."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        inventory = {507: 20, 713: 15}
        
        info = brewing_manager.get_batch_brew_info(501, inventory)
        
        assert "materials" in info
        assert len(info["materials"]) == 2
        
        for mat_info in info["materials"]:
            assert "item_id" in mat_info
            assert "needed_per_batch" in mat_info
            assert "total_needed" in mat_info
            assert "available" in mat_info
    
    def test_get_most_profitable_brew_multiple_options(
        self, brewing_manager, sample_brewable_item
    ):
        """Test profit calculation with multiple options."""
        brewing_manager.brewable_items[501] = sample_brewable_item
        
        # Add another brewable
        expensive_item = BrewableItem(
            item_id=502,
            item_name="Expensive Potion",
            potion_type=PotionType.STAT_BOOST,
            materials=[
                Material(item_id=600, item_name="Rare Herb", quantity_required=1),
            ],
            required_skill="Pharmacy",
            required_skill_level=3,
            base_success_rate=50.0,
            batch_size=1,
        )
        brewing_manager.brewable_items[502] = expensive_item
        
        inventory = {507: 10, 713: 10, 600: 5}
        character_state = {
            "int": 50,
            "dex": 40,
            "luk": 30,
            "job_level": 50,
            "skills": {"Pharmacy": 10},
        }
        market_prices = {
            501: 500,
            502: 2000,  # More expensive
            507: 10,
            713: 5,
            600: 100,
        }
        
        result = brewing_manager.get_most_profitable_brew(
            inventory, character_state, market_prices
        )
        
        assert result is not None
        assert "profit" in result
        assert result["profit"] > 0


class TestBrewingManagerDataLoading:
    """Test data loading functionality."""
    
    @pytest.fixture
    def temp_data_dir(self, tmp_path):
        """Create temporary data directory with brew data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        # Create sample brew data file
        brew_data = {
            "items": [
                {
                    "item_id": 501,
                    "item_name": "Red Potion",
                    "potion_type": "healing",
                    "materials": [
                        {"item_id": 507, "item_name": "Red Herb", "quantity_required": 1}
                    ],
                    "required_skill": "Pharmacy",
                    "required_skill_level": 1,
                    "base_success_rate": 70.0,
                    "batch_size": 1,
                }
            ]
        }
        
        import json
        brew_file = data_dir / "brew_items.json"
        with open(brew_file, "w") as f:
            json.dump(brew_data, f)
        
        return data_dir
    
    def test_load_brew_data_from_file(self, temp_data_dir):
        """Test loading brew data from JSON file."""
        mock_crafting = Mock()
        manager = BrewingManager(temp_data_dir, mock_crafting)
        
        assert 501 in manager.brewable_items
        assert manager.brewable_items[501].item_name == "Red Potion"
    
    def test_load_brew_data_file_not_found(self, tmp_path):
        """Test handling missing brew data file."""
        mock_crafting = Mock()
        manager = BrewingManager(tmp_path, mock_crafting)
        
        # Should handle gracefully
        assert isinstance(manager.brewable_items, dict)
    
    def test_load_brew_data_invalid_item(self, tmp_path):
        """Test handling invalid item data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        # Create invalid brew data
        brew_data = {
            "items": [
                {"item_id": 501}  # Missing required fields
            ]
        }
        
        import json
        brew_file = data_dir / "brew_items.json"
        with open(brew_file, "w") as f:
            json.dump(brew_data, f)
        
        mock_crafting = Mock()
        manager = BrewingManager(data_dir, mock_crafting)
        
        # Should skip invalid items
        assert 501 not in manager.brewable_items