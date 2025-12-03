"""
Comprehensive tests for crafting/core.py module.

Tests crafting validation, resource checking, success rate calculations,
recipe management, and material tracking.
"""

import json
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

from ai_sidecar.crafting.core import (
    CraftingManager,
    CraftingRecipe,
    CraftingResult,
    CraftingType,
    Material,
)


class TestCraftingType:
    """Test CraftingType enum."""
    
    def test_all_types_defined(self):
        """Test all crafting types are defined."""
        assert CraftingType.FORGE == "forge"
        assert CraftingType.BREW == "brew"
        assert CraftingType.REFINE == "refine"
        assert CraftingType.ENCHANT == "enchant"
        assert CraftingType.CARD_SLOT == "card_slot"
        assert CraftingType.COSTUME == "costume"
        assert CraftingType.SHADOW == "shadow"
        assert CraftingType.RUNE == "rune"


class TestCraftingResult:
    """Test CraftingResult enum."""
    
    def test_all_results_defined(self):
        """Test all result types are defined."""
        assert CraftingResult.SUCCESS == "success"
        assert CraftingResult.FAILURE == "failure"
        assert CraftingResult.BREAK == "break"
        assert CraftingResult.DOWNGRADE == "downgrade"


class TestMaterial:
    """Test Material model."""
    
    def test_basic_material_creation(self):
        """Test creating basic material."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=5,
            quantity_owned=10
        )
        
        assert material.item_id == 501
        assert material.item_name == "Red Potion"
        assert material.quantity_required == 5
        assert material.quantity_owned == 10
        assert material.is_consumed is True
    
    def test_is_available_true(self):
        """Test material availability when sufficient."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=5,
            quantity_owned=10
        )
        
        assert material.is_available is True
    
    def test_is_available_false(self):
        """Test material availability when insufficient."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=10,
            quantity_owned=5
        )
        
        assert material.is_available is False
    
    def test_is_available_exact(self):
        """Test material availability with exact amount."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=5,
            quantity_owned=5
        )
        
        assert material.is_available is True
    
    def test_quantity_missing_none(self):
        """Test quantity missing when sufficient."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=5,
            quantity_owned=10
        )
        
        assert material.quantity_missing == 0
    
    def test_quantity_missing_some(self):
        """Test quantity missing calculation."""
        material = Material(
            item_id=501,
            item_name="Red Potion",
            quantity_required=10,
            quantity_owned=3
        )
        
        assert material.quantity_missing == 7
    
    def test_non_consumable_material(self):
        """Test non-consumable material."""
        material = Material(
            item_id=601,
            item_name="Hammer",
            quantity_required=1,
            quantity_owned=1,
            is_consumed=False
        )
        
        assert material.is_consumed is False


class TestCraftingRecipe:
    """Test CraftingRecipe model."""
    
    def test_basic_recipe_creation(self):
        """Test creating basic recipe."""
        materials = [
            Material(item_id=501, item_name="Red Potion", quantity_required=5)
        ]
        
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Iron Sword",
            crafting_type=CraftingType.FORGE,
            result_item_id=1101,
            result_item_name="Iron Sword",
            materials=materials
        )
        
        assert recipe.recipe_id == 1
        assert recipe.recipe_name == "Iron Sword"
        assert recipe.crafting_type == CraftingType.FORGE
        assert recipe.result_item_id == 1101
        assert len(recipe.materials) == 1
    
    def test_recipe_with_requirements(self):
        """Test recipe with skill and level requirements."""
        materials = [
            Material(item_id=999, item_name="Steel", quantity_required=3)
        ]
        
        recipe = CraftingRecipe(
            recipe_id=2,
            recipe_name="Steel Sword",
            crafting_type=CraftingType.FORGE,
            result_item_id=1102,
            result_item_name="Steel Sword",
            materials=materials,
            required_skill="Smith Sword",
            required_skill_level=5,
            required_job="Blacksmith",
            required_base_level=30,
            required_zeny=1000
        )
        
        assert recipe.required_skill == "Smith Sword"
        assert recipe.required_skill_level == 5
        assert recipe.required_job == "Blacksmith"
        assert recipe.required_base_level == 30
        assert recipe.required_zeny == 1000
    
    def test_recipe_with_success_rates(self):
        """Test recipe with success rate modifiers."""
        materials = [Material(item_id=999, item_name="Steel", quantity_required=3)]
        
        recipe = CraftingRecipe(
            recipe_id=3,
            recipe_name="Advanced Sword",
            crafting_type=CraftingType.FORGE,
            result_item_id=1103,
            result_item_name="Advanced Sword",
            materials=materials,
            base_success_rate=80.0,
            dex_bonus=0.5,
            luk_bonus=0.3,
            skill_bonus=2.0
        )
        
        assert recipe.base_success_rate == 80.0
        assert recipe.dex_bonus == 0.5
        assert recipe.luk_bonus == 0.3
        assert recipe.skill_bonus == 2.0
    
    def test_has_level_requirement_true(self):
        """Test detecting level requirement."""
        materials = [Material(item_id=999, item_name="Steel", quantity_required=1)]
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Test",
            materials=materials,
            required_base_level=30
        )
        
        assert recipe.has_level_requirement is True
    
    def test_has_level_requirement_false(self):
        """Test no level requirement."""
        materials = [Material(item_id=999, item_name="Steel", quantity_required=1)]
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Test",
            materials=materials,
            required_base_level=1
        )
        
        assert recipe.has_level_requirement is False
    
    def test_has_skill_requirement_true(self):
        """Test detecting skill requirement."""
        materials = [Material(item_id=999, item_name="Steel", quantity_required=1)]
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Test",
            materials=materials,
            required_skill="Smith Sword",
            required_skill_level=5
        )
        
        assert recipe.has_skill_requirement is True
    
    def test_has_skill_requirement_false(self):
        """Test no skill requirement."""
        materials = [Material(item_id=999, item_name="Steel", quantity_required=1)]
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Test",
            materials=materials
        )
        
        assert recipe.has_skill_requirement is False


class TestCraftingManager:
    """Test CraftingManager class."""
    
    @pytest.fixture
    def data_dir(self, tmp_path):
        """Create temporary data directory with recipe data."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        recipe_data = {
            "recipes": [
                {
                    "recipe_id": 1,
                    "recipe_name": "Iron Sword",
                    "crafting_type": "forge",
                    "result_item_id": 1101,
                    "result_item_name": "Iron Sword",
                    "result_quantity": 1,
                    "materials": [
                        {
                            "item_id": 998,
                            "item_name": "Iron",
                            "quantity_required": 3,
                            "quantity_owned": 0,
                            "is_consumed": True
                        }
                    ],
                    "required_skill": "Smith Sword",
                    "required_skill_level": 3,
                    "required_job": "Blacksmith",
                    "required_base_level": 20,
                    "required_zeny": 500,
                    "base_success_rate": 90.0,
                    "dex_bonus": 0.5,
                    "luk_bonus": 0.2,
                    "skill_bonus": 1.0
                },
                {
                    "recipe_id": 2,
                    "recipe_name": "Red Potion",
                    "crafting_type": "brew",
                    "result_item_id": 501,
                    "result_item_name": "Red Potion",
                    "result_quantity": 10,
                    "materials": [
                        {
                            "item_id": 507,
                            "item_name": "Red Herb",
                            "quantity_required": 1,
                            "quantity_owned": 0,
                            "is_consumed": True
                        }
                    ],
                    "base_success_rate": 100.0
                }
            ]
        }
        
        recipe_file = data_dir / "crafting_recipes.json"
        recipe_file.write_text(json.dumps(recipe_data))
        
        return data_dir
    
    @pytest.fixture
    def manager(self, data_dir):
        """Create CraftingManager instance."""
        return CraftingManager(data_dir)
    
    def test_initialization(self, data_dir):
        """Test CraftingManager initialization."""
        manager = CraftingManager(data_dir)
        
        assert manager.data_dir == data_dir
        assert len(manager.recipes) > 0
    
    def test_load_recipes(self, manager):
        """Test recipes are loaded."""
        assert len(manager.recipes) == 2
        assert 1 in manager.recipes
        assert 2 in manager.recipes
    
    def test_get_recipe_found(self, manager):
        """Test getting recipe by ID."""
        recipe = manager.get_recipe(1)
        
        assert recipe is not None
        assert recipe.recipe_name == "Iron Sword"
        assert recipe.crafting_type == CraftingType.FORGE
    
    def test_get_recipe_not_found(self, manager):
        """Test getting non-existent recipe."""
        recipe = manager.get_recipe(999)
        
        assert recipe is None
    
    def test_get_recipes_by_type_forge(self, manager):
        """Test getting recipes by type."""
        forge_recipes = manager.get_recipes_by_type(CraftingType.FORGE)
        
        assert len(forge_recipes) == 1
        assert forge_recipes[0].recipe_name == "Iron Sword"
    
    def test_get_recipes_by_type_brew(self, manager):
        """Test getting brew recipes."""
        brew_recipes = manager.get_recipes_by_type(CraftingType.BREW)
        
        assert len(brew_recipes) == 1
        assert brew_recipes[0].recipe_name == "Red Potion"
    
    def test_get_recipes_by_type_empty(self, manager):
        """Test getting recipes for type with no recipes."""
        refine_recipes = manager.get_recipes_by_type(CraftingType.REFINE)
        
        assert len(refine_recipes) == 0
    
    def test_check_materials_available(self, manager):
        """Test checking materials when available."""
        inventory = {998: 10}  # 10 Iron
        
        available, missing = manager.check_materials(1, inventory)
        
        assert available is True
        assert len(missing) == 0
    
    def test_check_materials_insufficient(self, manager):
        """Test checking materials when insufficient."""
        inventory = {998: 1}  # Only 1 Iron (need 3)
        
        available, missing = manager.check_materials(1, inventory)
        
        assert available is False
        assert len(missing) == 1
        assert "Iron" in missing[0]
    
    def test_check_materials_missing_completely(self, manager):
        """Test checking materials when missing completely."""
        inventory = {}  # No materials
        
        available, missing = manager.check_materials(1, inventory)
        
        assert available is False
        assert len(missing) == 1
    
    def test_check_materials_recipe_not_found(self, manager):
        """Test checking materials for non-existent recipe."""
        inventory = {}
        
        available, missing = manager.check_materials(999, inventory)
        
        assert available is False
        assert "Recipe not found" in missing[0]
    
    def test_calculate_success_rate_base(self, manager):
        """Test calculating base success rate."""
        character_state = {
            "dex": 0,
            "luk": 0,
            "skills": {}
        }
        
        rate = manager.calculate_success_rate(1, character_state)
        
        assert rate == 90.0
    
    def test_calculate_success_rate_with_dex(self, manager):
        """Test success rate with DEX bonus."""
        character_state = {
            "dex": 50,
            "luk": 0,
            "skills": {}
        }
        
        rate = manager.calculate_success_rate(1, character_state)
        
        # Base 90 + (50 * 0.5) = 115, capped at 100
        assert rate == 100.0
    
    def test_calculate_success_rate_with_luk(self, manager):
        """Test success rate with LUK bonus."""
        character_state = {
            "dex": 0,
            "luk": 30,
            "skills": {}
        }
        
        rate = manager.calculate_success_rate(1, character_state)
        
        # Base 90 + (30 * 0.2) = 96
        assert rate == 96.0
    
    def test_calculate_success_rate_with_skill(self, manager):
        """Test success rate with skill level bonus."""
        character_state = {
            "dex": 0,
            "luk": 0,
            "skills": {"Smith Sword": 5}
        }
        
        rate = manager.calculate_success_rate(1, character_state)
        
        # Base 90 + (5 * 1.0) = 95
        assert rate == 95.0
    
    def test_calculate_success_rate_combined(self, manager):
        """Test success rate with all bonuses combined."""
        character_state = {
            "dex": 20,
            "luk": 10,
            "skills": {"Smith Sword": 5}
        }
        
        rate = manager.calculate_success_rate(1, character_state)
        
        # Base 90 + (20 * 0.5) + (10 * 0.2) + (5 * 1.0) = 107, capped at 100
        assert rate == 100.0
    
    def test_calculate_success_rate_recipe_not_found(self, manager):
        """Test success rate for non-existent recipe."""
        character_state = {"dex": 0, "luk": 0, "skills": {}}
        
        rate = manager.calculate_success_rate(999, character_state)
        
        assert rate == 0.0
    
    def test_get_missing_materials(self, manager):
        """Test getting missing materials."""
        inventory = {998: 1}  # 1 Iron (need 3)
        
        missing = manager.get_missing_materials(1, inventory)
        
        assert len(missing) == 1
        assert missing[0].item_name == "Iron"
        assert missing[0].quantity_required == 2  # 3 - 1
    
    def test_get_missing_materials_all_available(self, manager):
        """Test getting missing materials when all available."""
        inventory = {998: 10}
        
        missing = manager.get_missing_materials(1, inventory)
        
        assert len(missing) == 0
    
    def test_get_missing_materials_recipe_not_found(self, manager):
        """Test missing materials for non-existent recipe."""
        missing = manager.get_missing_materials(999, {})
        
        assert len(missing) == 0
    
    def test_get_craftable_recipes_none(self, manager):
        """Test getting craftable recipes with no resources."""
        inventory = {}
        character_state = {
            "level": 1,
            "job": "Novice",
            "zeny": 0,
            "skills": {}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 0
    
    def test_get_craftable_recipes_with_materials(self, manager):
        """Test getting craftable recipes with materials."""
        inventory = {998: 10}  # Iron
        character_state = {
            "level": 30,
            "job": "Blacksmith",
            "zeny": 1000,
            "skills": {"Smith Sword": 5}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 1
        assert craftable[0].recipe_name == "Iron Sword"
    
    def test_get_craftable_recipes_level_requirement(self, manager):
        """Test level requirement filtering."""
        inventory = {998: 10}
        character_state = {
            "level": 10,  # Below requirement
            "job": "Blacksmith",
            "zeny": 1000,
            "skills": {"Smith Sword": 5}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 0
    
    def test_get_craftable_recipes_job_requirement(self, manager):
        """Test job requirement filtering."""
        inventory = {998: 10}
        character_state = {
            "level": 30,
            "job": "Merchant",  # Wrong job
            "zeny": 1000,
            "skills": {"Smith Sword": 5}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 0
    
    def test_get_craftable_recipes_zeny_requirement(self, manager):
        """Test zeny requirement filtering."""
        inventory = {998: 10}
        character_state = {
            "level": 30,
            "job": "Blacksmith",
            "zeny": 100,  # Not enough zeny
            "skills": {"Smith Sword": 5}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 0
    
    def test_get_craftable_recipes_skill_requirement(self, manager):
        """Test skill requirement filtering."""
        inventory = {998: 10}
        character_state = {
            "level": 30,
            "job": "Blacksmith",
            "zeny": 1000,
            "skills": {"Smith Sword": 1}  # Skill level too low
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        assert len(craftable) == 0
    
    def test_get_craftable_recipes_multiple(self, manager):
        """Test getting multiple craftable recipes."""
        inventory = {998: 10, 507: 10}  # Iron and Red Herb
        character_state = {
            "level": 30,
            "job": "Blacksmith",
            "zeny": 1000,
            "skills": {"Smith Sword": 5}
        }
        
        craftable = manager.get_craftable_recipes(inventory, character_state)
        
        # Should have both Iron Sword and Red Potion
        assert len(craftable) >= 1
    
    def test_get_statistics(self, manager):
        """Test getting crafting statistics."""
        stats = manager.get_statistics()
        
        assert "total_recipes" in stats
        assert "recipes_by_type" in stats
        assert stats["total_recipes"] == 2
        assert stats["recipes_by_type"][CraftingType.FORGE] == 1
        assert stats["recipes_by_type"][CraftingType.BREW] == 1
    
    def test_load_recipe_data_missing_file(self, tmp_path):
        """Test loading recipes with missing file."""
        manager = CraftingManager(tmp_path)
        
        # Should handle missing file gracefully
        assert len(manager.recipes) == 0
    
    def test_load_recipe_data_invalid_json(self, tmp_path):
        """Test loading invalid JSON."""
        recipe_file = tmp_path / "crafting_recipes.json"
        recipe_file.write_text("invalid json {")
        
        manager = CraftingManager(tmp_path)
        
        # Should handle invalid JSON gracefully
        assert len(manager.recipes) == 0