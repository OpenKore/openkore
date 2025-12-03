"""
Comprehensive tests for Blacksmith/Whitesmith Forging system.

Tests cover:
- Forgeable weapon models
- Forge result tracking
- Success rate calculations
- Material requirements
- Element application
- Star crumb usage
- Fame tracking
- Optimal forge selection
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import json

from ai_sidecar.crafting.forging import (
    ForgeElement,
    ForgeableWeapon,
    ForgeResult,
    ForgingManager
)
from ai_sidecar.crafting.core import Material, CraftingManager


# Fixtures

@pytest.fixture
def mock_crafting_manager():
    """Create mock crafting manager."""
    return Mock(spec=CraftingManager)


@pytest.fixture
def temp_data_dir(tmp_path):
    """Create temporary data directory."""
    data_dir = tmp_path / "forge_data"
    data_dir.mkdir()
    return data_dir


@pytest.fixture
def sample_weapon():
    """Create sample forgeable weapon."""
    return ForgeableWeapon(
        weapon_id=1201,
        weapon_name="Knife",
        weapon_level=1,
        base_materials=[
            Material(item_id=1003, item_name="Coal", quantity_required=50, is_consumed=True),
            Material(item_id=998, item_name="Iron", quantity_required=1, is_consumed=True)
        ],
        base_success_rate=100.0
    )


@pytest.fixture
def high_level_weapon():
    """Create high level forgeable weapon."""
    return ForgeableWeapon(
        weapon_id=1185,
        weapon_name="Violet Fear",
        weapon_level=4,
        base_materials=[
            Material(item_id=1003, item_name="Coal", quantity_required=50, is_consumed=True),
            Material(item_id=984, item_name="Oridecon", quantity_required=10, is_consumed=True)
        ],
        element_stone=Material(item_id=994, item_name="Flame Heart", quantity_required=1, is_consumed=True),
        star_crumb_count=3,
        base_success_rate=55.0
    )


@pytest.fixture
def forging_manager(temp_data_dir, mock_crafting_manager):
    """Create forging manager with temp directory."""
    return ForgingManager(temp_data_dir, mock_crafting_manager)


# Model Tests

class TestForgeElementEnum:
    """Test ForgeElement enum."""
    
    def test_all_elements_defined(self):
        """Test all elements are defined."""
        assert ForgeElement.NONE
        assert ForgeElement.FIRE
        assert ForgeElement.ICE
        assert ForgeElement.WIND
        assert ForgeElement.EARTH
        assert ForgeElement.VERY_STRONG_FIRE
        assert ForgeElement.VERY_STRONG_ICE
        assert ForgeElement.VERY_STRONG_WIND
        assert ForgeElement.VERY_STRONG_EARTH
    
    def test_element_values(self):
        """Test element string values."""
        assert ForgeElement.FIRE.value == "fire"
        assert ForgeElement.VERY_STRONG_FIRE.value == "very_strong_fire"


class TestForgeableWeaponModel:
    """Test ForgeableWeapon model."""
    
    def test_create_basic_weapon(self, sample_weapon):
        """Test creating basic forgeable weapon."""
        assert sample_weapon.weapon_id == 1201
        assert sample_weapon.weapon_name == "Knife"
        assert sample_weapon.weapon_level == 1
        assert len(sample_weapon.base_materials) == 2
    
    def test_weapon_requires_element_stone(self, high_level_weapon):
        """Test weapon with element stone."""
        assert high_level_weapon.requires_element_stone is True
        assert high_level_weapon.element_stone is not None
    
    def test_weapon_no_element_stone(self, sample_weapon):
        """Test weapon without element stone."""
        assert sample_weapon.requires_element_stone is False
        assert sample_weapon.element_stone is None
    
    def test_weapon_is_vvs(self, high_level_weapon):
        """Test VVS weapon detection."""
        assert high_level_weapon.is_vvs_weapon is True
        assert high_level_weapon.star_crumb_count == 3
    
    def test_weapon_not_vvs(self, sample_weapon):
        """Test non-VVS weapon."""
        assert sample_weapon.is_vvs_weapon is False
        assert sample_weapon.star_crumb_count == 0
    
    def test_weapon_immutable(self, sample_weapon):
        """Test weapon is frozen."""
        with pytest.raises(Exception):
            sample_weapon.weapon_level = 2


class TestForgeResultModel:
    """Test ForgeResult model."""
    
    def test_create_success_result(self):
        """Test creating successful forge result."""
        result = ForgeResult(
            success=True,
            weapon_id=1201,
            weapon_name="Knife",
            element=ForgeElement.FIRE,
            crafter_name="Smith"
        )
        
        assert result.success is True
        assert result.weapon_name == "Knife"
        assert result.element == ForgeElement.FIRE
    
    def test_create_failure_result(self):
        """Test creating failed forge result."""
        result = ForgeResult(
            success=False,
            crafter_name="Smith"
        )
        
        assert result.success is False
        assert result.weapon_id is None
    
    def test_result_with_fame(self):
        """Test result with fame gained."""
        result = ForgeResult(
            success=True,
            weapon_id=1201,
            weapon_name="Knife",
            fame_gained=5,
            crafter_name="Smith"
        )
        
        assert result.fame_gained == 5
    
    def test_result_with_star_count(self):
        """Test result with star count."""
        result = ForgeResult(
            success=True,
            weapon_id=1185,
            weapon_name="Violet Fear",
            star_count=3,
            crafter_name="Smith"
        )
        
        assert result.star_count == 3


# ForgingManager Tests

class TestForgingManagerInit:
    """Test forging manager initialization."""
    
    def test_manager_initialization(self, forging_manager):
        """Test manager initializes correctly."""
        assert forging_manager.forgeable_weapons == {}
        assert forging_manager.fame_records == {}
        assert forging_manager.log is not None
    
    def test_manager_with_nonexistent_file(self, temp_data_dir, mock_crafting_manager):
        """Test initialization with missing data file."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        # Should not crash, just log warning
        assert len(manager.forgeable_weapons) == 0


class TestSuccessRateCalculation:
    """Test forge success rate calculations."""
    
    def test_success_rate_level_1_weapon(self, forging_manager):
        """Test success rate for level 1 weapon."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=1,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        character_state = {
            "dex": 50,
            "luk": 30,
            "job_level": 50
        }
        
        rate = forging_manager.get_forge_success_rate(1, character_state)
        
        # Level 1 base = 100, caps at 100
        assert rate == 100.0
    
    def test_success_rate_level_4_weapon(self, forging_manager):
        """Test success rate for level 4 weapon."""
        weapon = ForgeableWeapon(
            weapon_id=2,
            weapon_name="Test",
            weapon_level=4,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[2] = weapon
        
        character_state = {
            "dex": 99,
            "luk": 50,
            "job_level": 70
        }
        
        rate = forging_manager.get_forge_success_rate(2, character_state)
        
        # Level 4 base = 55, with good stats should be higher
        assert rate > 55
        assert rate <= 100
    
    def test_success_rate_with_element(self, forging_manager):
        """Test success rate with element reduces rate."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=2,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        
        rate_no_element = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.NONE
        )
        rate_with_element = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.FIRE
        )
        
        assert rate_with_element < rate_no_element
    
    def test_success_rate_with_very_strong_element(self, forging_manager):
        """Test VVS element has bigger penalty."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=2,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        
        rate_normal = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.FIRE
        )
        rate_vvs = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.VERY_STRONG_FIRE
        )
        
        assert rate_vvs < rate_normal
    
    def test_success_rate_with_star_crumbs(self, forging_manager):
        """Test star crumbs reduce success rate."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=2,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        
        rate_no_crumbs = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.NONE, 0
        )
        rate_with_crumbs = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.NONE, 3
        )
        
        assert rate_with_crumbs < rate_no_crumbs
    
    def test_success_rate_caps_at_100(self, forging_manager):
        """Test success rate caps at 100%."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=1,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        # Maxed stats
        character_state = {
            "dex": 150,
            "luk": 150,
            "job_level": 70
        }
        
        rate = forging_manager.get_forge_success_rate(1, character_state)
        
        assert rate <= 100.0
    
    def test_success_rate_floors_at_zero(self, forging_manager):
        """Test success rate doesn't go below 0."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=4,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        # Low stats
        character_state = {
            "dex": 1,
            "luk": 1,
            "job_level": 1
        }
        
        rate = forging_manager.get_forge_success_rate(
            1, character_state, ForgeElement.VERY_STRONG_FIRE, 3
        )
        
        assert rate >= 0.0
    
    def test_success_rate_nonexistent_weapon(self, forging_manager):
        """Test success rate for non-existent weapon."""
        rate = forging_manager.get_forge_success_rate(
            999, {"dex": 50}
        )
        
        assert rate == 0.0


class TestRequiredMaterials:
    """Test material requirement calculations."""
    
    def test_materials_basic_weapon(self, forging_manager, sample_weapon):
        """Test materials for basic weapon."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        materials = forging_manager.get_required_materials(sample_weapon.weapon_id)
        
        assert len(materials) == 2
        assert materials[0].item_name == "Coal"
        assert materials[1].item_name == "Iron"
    
    def test_materials_with_element(self, forging_manager, high_level_weapon):
        """Test materials with element stone."""
        forging_manager.forgeable_weapons[high_level_weapon.weapon_id] = high_level_weapon
        
        materials = forging_manager.get_required_materials(
            high_level_weapon.weapon_id,
            ForgeElement.FIRE
        )
        
        # Should include base materials + element stone
        assert len(materials) > len(high_level_weapon.base_materials)
    
    def test_materials_with_star_crumbs(self, forging_manager, sample_weapon):
        """Test materials with star crumbs."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        materials = forging_manager.get_required_materials(
            sample_weapon.weapon_id,
            ForgeElement.NONE,
            3
        )
        
        # Should include star crumbs
        star_crumb_materials = [m for m in materials if m.item_name == "Star Crumb"]
        assert len(star_crumb_materials) == 1
        assert star_crumb_materials[0].quantity_required == 3
    
    def test_materials_nonexistent_weapon(self, forging_manager):
        """Test materials for non-existent weapon."""
        materials = forging_manager.get_required_materials(999)
        
        assert materials == []


class TestFameCalculation:
    """Test fame point calculations."""
    
    def test_fame_level_1_weapon(self, forging_manager):
        """Test fame for level 1 weapon."""
        fame = forging_manager.get_fame_value(1)
        
        assert fame == 1
    
    def test_fame_level_4_weapon(self, forging_manager):
        """Test fame for level 4 weapon."""
        fame = forging_manager.get_fame_value(4)
        
        assert fame == 15
    
    def test_fame_with_normal_element(self, forging_manager):
        """Test fame with normal element."""
        fame_base = forging_manager.get_fame_value(2)
        fame_element = forging_manager.get_fame_value(2, ForgeElement.FIRE)
        
        assert fame_element > fame_base
        assert fame_element == fame_base + 2
    
    def test_fame_with_vvs_element(self, forging_manager):
        """Test fame with very strong element."""
        fame_base = forging_manager.get_fame_value(2)
        fame_vvs = forging_manager.get_fame_value(2, ForgeElement.VERY_STRONG_FIRE)
        
        assert fame_vvs > fame_base
        assert fame_vvs == fame_base + 5
    
    def test_fame_with_star_crumbs(self, forging_manager):
        """Test fame with star crumbs."""
        fame_base = forging_manager.get_fame_value(2)
        fame_crumbs = forging_manager.get_fame_value(2, ForgeElement.NONE, 3)
        
        assert fame_crumbs == fame_base + 9  # 3 per crumb


class TestOptimalForgeTarget:
    """Test optimal forge target selection."""
    
    def test_optimal_no_materials(self, forging_manager, sample_weapon):
        """Test optimal with no materials."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        inventory = {}
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        
        result = forging_manager.get_optimal_forge_target(
            inventory, character_state
        )
        
        assert result is None
    
    def test_optimal_with_materials(self, forging_manager, sample_weapon):
        """Test optimal with materials available."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        inventory = {
            1003: 100,  # Coal
            998: 10     # Iron
        }
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        
        result = forging_manager.get_optimal_forge_target(
            inventory, character_state
        )
        
        assert result is not None
        assert result["weapon_id"] == sample_weapon.weapon_id
    
    def test_optimal_with_market_prices(self, forging_manager, sample_weapon):
        """Test optimal considers market prices."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        inventory = {
            1003: 100,
            998: 10
        }
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        market_prices = {
            1201: 50000,  # Weapon sells for this
            1003: 100,    # Coal costs
            998: 1000     # Iron costs
        }
        
        result = forging_manager.get_optimal_forge_target(
            inventory, character_state, market_prices
        )
        
        assert result is not None
        assert "estimated_profit" in result
    
    def test_optimal_selects_best_score(self, forging_manager):
        """Test optimal selects highest scoring weapon."""
        # Add multiple weapons
        weapon1 = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Low Level",
            weapon_level=1,
            base_materials=[
                Material(item_id=1, item_name="Mat1", quantity_required=1, is_consumed=True)
            ]
        )
        weapon2 = ForgeableWeapon(
            weapon_id=2,
            weapon_name="High Level",
            weapon_level=4,
            base_materials=[
                Material(item_id=1, item_name="Mat1", quantity_required=1, is_consumed=True)
            ]
        )
        
        forging_manager.forgeable_weapons[1] = weapon1
        forging_manager.forgeable_weapons[2] = weapon2
        
        inventory = {1: 100}
        character_state = {"dex": 99, "luk": 50, "job_level": 70}
        
        result = forging_manager.get_optimal_forge_target(
            inventory, character_state
        )
        
        assert result is not None
        assert "score" in result


class TestFameTracking:
    """Test fame point tracking."""
    
    def test_add_fame_new_character(self, forging_manager):
        """Test adding fame to new character."""
        total = forging_manager.add_fame("Smith", 10)
        
        assert total == 10
        assert forging_manager.get_fame("Smith") == 10
    
    def test_add_fame_existing_character(self, forging_manager):
        """Test adding fame to existing character."""
        forging_manager.add_fame("Smith", 10)
        total = forging_manager.add_fame("Smith", 5)
        
        assert total == 15
        assert forging_manager.get_fame("Smith") == 15
    
    def test_get_fame_nonexistent_character(self, forging_manager):
        """Test getting fame for non-existent character."""
        fame = forging_manager.get_fame("Unknown")
        
        assert fame == 0
    
    def test_fame_multiple_characters(self, forging_manager):
        """Test tracking fame for multiple characters."""
        forging_manager.add_fame("Smith1", 10)
        forging_manager.add_fame("Smith2", 20)
        forging_manager.add_fame("Smith1", 5)
        
        assert forging_manager.get_fame("Smith1") == 15
        assert forging_manager.get_fame("Smith2") == 20


class TestStatistics:
    """Test statistics generation."""
    
    def test_statistics_empty(self, forging_manager):
        """Test statistics with no weapons."""
        stats = forging_manager.get_statistics()
        
        assert stats["total_forgeable"] == 0
        assert stats["by_weapon_level"] == {}
        assert stats["total_fame_tracked"] == 0
    
    def test_statistics_with_weapons(self, forging_manager, sample_weapon, high_level_weapon):
        """Test statistics with weapons."""
        forging_manager.forgeable_weapons[1] = sample_weapon
        forging_manager.forgeable_weapons[2] = high_level_weapon
        
        stats = forging_manager.get_statistics()
        
        assert stats["total_forgeable"] == 2
        assert 1 in stats["by_weapon_level"]
        assert 4 in stats["by_weapon_level"]
    
    def test_statistics_with_fame(self, forging_manager):
        """Test statistics includes fame."""
        forging_manager.add_fame("Smith1", 100)
        forging_manager.add_fame("Smith2", 200)
        
        stats = forging_manager.get_statistics()
        
        assert stats["total_fame_tracked"] == 300
        assert stats["characters_with_fame"] == 2


# Edge Cases

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    def test_success_rate_with_missing_stats(self, forging_manager):
        """Test success rate with incomplete character state."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=2,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        character_state = {}  # Missing all stats
        
        # Should use defaults (0) and not crash
        rate = forging_manager.get_forge_success_rate(1, character_state)
        
        assert rate >= 0
    
    def test_zero_star_crumbs(self, forging_manager, sample_weapon):
        """Test with zero star crumbs."""
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        materials = forging_manager.get_required_materials(
            sample_weapon.weapon_id,
            ForgeElement.NONE,
            0
        )
        
        # Should not include star crumbs
        star_crumbs = [m for m in materials if m.item_name == "Star Crumb"]
        assert len(star_crumbs) == 0
    
    def test_negative_fame(self, forging_manager):
        """Test adding negative fame."""
        forging_manager.add_fame("Smith", 100)
        total = forging_manager.add_fame("Smith", -50)
        
        assert total == 50
    
    def test_weapon_with_empty_materials(self, forging_manager):
        """Test weapon with no materials."""
        weapon = ForgeableWeapon(
            weapon_id=1,
            weapon_name="Test",
            weapon_level=1,
            base_materials=[]
        )
        forging_manager.forgeable_weapons[1] = weapon
        
        materials = forging_manager.get_required_materials(1)
        
        assert len(materials) == 0
    
    def test_optimal_forge_with_no_weapons(self, forging_manager):
        """Test optimal forge with no weapons registered."""
        inventory = {1: 100}
        character_state = {"dex": 50}
        
        result = forging_manager.get_optimal_forge_target(
            inventory, character_state
        )
        
        assert result is None


# Integration Tests

class TestIntegration:
    """Test integrated workflows."""
    
    def test_full_forge_workflow(self, forging_manager, sample_weapon):
        """Test complete forge workflow."""
        # Register weapon
        forging_manager.forgeable_weapons[sample_weapon.weapon_id] = sample_weapon
        
        # Check materials needed
        materials = forging_manager.get_required_materials(sample_weapon.weapon_id)
        assert len(materials) > 0
        
        # Calculate success rate
        character_state = {"dex": 50, "luk": 30, "job_level": 50}
        rate = forging_manager.get_forge_success_rate(
            sample_weapon.weapon_id,
            character_state
        )
        assert rate > 0
        
        # Calculate fame
        fame = forging_manager.get_fame_value(sample_weapon.weapon_level)
        assert fame > 0
        
        # Track fame
        forging_manager.add_fame("Smith", fame)
        assert forging_manager.get_fame("Smith") == fame
    
    def test_vvs_weapon_workflow(self, forging_manager, high_level_weapon):
        """Test VVS weapon forging workflow."""
        forging_manager.forgeable_weapons[high_level_weapon.weapon_id] = high_level_weapon
        
        # Get materials with element and star crumbs
        materials = forging_manager.get_required_materials(
            high_level_weapon.weapon_id,
            ForgeElement.VERY_STRONG_FIRE,
            3
        )
        
        # Should have base + element + star crumbs
        assert len(materials) > len(high_level_weapon.base_materials)
        
        # Calculate reduced success rate
        character_state = {"dex": 99, "luk": 50, "job_level": 70}
        rate = forging_manager.get_forge_success_rate(
            high_level_weapon.weapon_id,
            character_state,
            ForgeElement.VERY_STRONG_FIRE,
            3
        )
        
        # Should be significantly reduced from base
        assert rate < 100
        
        # Calculate high fame
        fame = forging_manager.get_fame_value(
            high_level_weapon.weapon_level,
            ForgeElement.VERY_STRONG_FIRE,
            3
        )
        
        # Should get major fame bonus
        assert fame > 20