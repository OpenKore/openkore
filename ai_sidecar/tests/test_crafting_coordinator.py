"""
Tests for Crafting Coordinator - unified crafting system interface.

Tests cover:
- Crafting opportunity detection
- Profit potential calculation
- Material shopping lists
- Recipe validation
- Multiple crafting type routing
- Statistics aggregation
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock

from ai_sidecar.crafting.coordinator import CraftingCoordinator
from ai_sidecar.crafting.core import CraftingType, CraftingRecipe, Material


@pytest.fixture
def data_dir(tmp_path):
    """Create temporary data directory."""
    return tmp_path


@pytest.fixture
def mock_crafting_manager():
    """Mock crafting manager."""
    manager = Mock()
    
    # Create mock recipe
    recipe = Mock(spec=CraftingRecipe)
    recipe.recipe_id = 1
    recipe.recipe_name = "Test Potion"
    recipe.result_item_id = 501
    recipe.result_item_name = "Red Potion"
    recipe.crafting_type = CraftingType.BREW
    recipe.npc_map = "prontera"
    recipe.npc_name = "Alchemist"
    recipe.materials = [
        Material(item_id=713, item_name="Empty Bottle", quantity_required=1, quantity_owned=5),
        Material(item_id=507, item_name="Red Herb", quantity_required=1, quantity_owned=10)
    ]
    
    manager.get_craftable_recipes = Mock(return_value=[recipe])
    manager.calculate_success_rate = Mock(return_value=0.95)
    manager.get_recipe = Mock(return_value=recipe)
    manager.get_recipes_by_type = Mock(return_value=[recipe])
    manager.check_materials = Mock(return_value=(True, []))
    manager.get_missing_materials = Mock(return_value=[])
    manager.get_statistics = Mock(return_value={"recipes_learned": 10})
    
    return manager


@pytest.fixture
def coordinator(data_dir):
    """Create coordinator with mocked dependencies."""
    with patch('ai_sidecar.crafting.coordinator.CraftingManager') as mock_craft, \
         patch('ai_sidecar.crafting.coordinator.ForgingManager') as mock_forge, \
         patch('ai_sidecar.crafting.coordinator.BrewingManager') as mock_brew, \
         patch('ai_sidecar.crafting.coordinator.RefiningManager') as mock_refine, \
         patch('ai_sidecar.crafting.coordinator.EnchantingManager') as mock_enchant, \
         patch('ai_sidecar.crafting.coordinator.CardManager') as mock_card:
        
        coord = CraftingCoordinator(data_dir)
        
        # Setup mocks with return values
        coord.crafting.get_statistics = Mock(return_value={})
        coord.forging.get_statistics = Mock(return_value={})
        coord.forging.get_optimal_forge_target = Mock(return_value=None)
        coord.forging.get_fame = Mock(return_value=100)
        coord.brewing.get_statistics = Mock(return_value={})
        coord.brewing.get_most_profitable_brew = Mock(return_value=None)
        coord.refining.get_statistics = Mock(return_value={})
        coord.enchanting.get_statistics = Mock(return_value={})
        coord.cards.get_statistics = Mock(return_value={})
        
        return coord


# Initialization Tests

def test_coordinator_init(data_dir):
    """Test coordinator initialization."""
    with patch('ai_sidecar.crafting.coordinator.CraftingManager'), \
         patch('ai_sidecar.crafting.coordinator.ForgingManager'), \
         patch('ai_sidecar.crafting.coordinator.BrewingManager'), \
         patch('ai_sidecar.crafting.coordinator.RefiningManager'), \
         patch('ai_sidecar.crafting.coordinator.EnchantingManager'), \
         patch('ai_sidecar.crafting.coordinator.CardManager'):
        
        coord = CraftingCoordinator(data_dir)
        
        assert coord.data_dir == data_dir
        assert coord.crafting is not None
        assert coord.forging is not None
        assert coord.brewing is not None
        assert coord.refining is not None
        assert coord.enchanting is not None
        assert coord.cards is not None


# Crafting Opportunities Tests

@pytest.mark.asyncio
async def test_get_crafting_opportunities_basic(coordinator, mock_crafting_manager):
    """Test getting basic crafting opportunities."""
    coordinator.crafting = mock_crafting_manager
    
    character_state = {"job": "alchemist", "level": 50}
    inventory = {"713": 5, "507": 10}
    
    opportunities = await coordinator.get_crafting_opportunities(
        character_state, inventory
    )
    
    assert len(opportunities) > 0
    assert opportunities[0]["type"] == "recipe"
    assert opportunities[0]["recipe_name"] == "Test Potion"
    assert opportunities[0]["success_rate"] == 0.95


@pytest.mark.asyncio
async def test_get_crafting_opportunities_with_market_prices(coordinator, mock_crafting_manager):
    """Test opportunities with profit calculation."""
    coordinator.crafting = mock_crafting_manager
    
    character_state = {"job": "alchemist"}
    inventory = {"713": 5, "507": 10}
    market_prices = {
        713: 100,  # Empty Bottle
        507: 50,   # Red Herb
        501: 500   # Red Potion
    }
    
    opportunities = await coordinator.get_crafting_opportunities(
        character_state, inventory, market_prices
    )
    
    assert len(opportunities) > 0
    opp = opportunities[0]
    assert "profit" in opp
    assert "material_cost" in opp
    assert opp["material_cost"] == 150  # 100 + 50
    assert opp["profit"] == 350  # 500 - 150


@pytest.mark.asyncio
async def test_get_crafting_opportunities_with_forging(coordinator):
    """Test opportunities including forging."""
    forge_target = {
        "weapon_name": "Claymore",
        "success_rate": 0.8,
        "profit": 5000
    }
    coordinator.forging.get_optimal_forge_target = Mock(return_value=forge_target)
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[])
    
    opportunities = await coordinator.get_crafting_opportunities({}, {})
    
    assert len(opportunities) == 1
    assert opportunities[0]["type"] == "forge"
    assert opportunities[0]["weapon_name"] == "Claymore"


@pytest.mark.asyncio
async def test_get_crafting_opportunities_with_brewing(coordinator):
    """Test opportunities including brewing."""
    brew_target = {
        "potion_name": "White Potion",
        "success_rate": 0.9,
        "profit": 1000
    }
    coordinator.brewing.get_most_profitable_brew = Mock(return_value=brew_target)
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[])
    
    opportunities = await coordinator.get_crafting_opportunities({}, {})
    
    assert len(opportunities) == 1
    assert opportunities[0]["type"] == "brew"
    assert opportunities[0]["potion_name"] == "White Potion"


@pytest.mark.asyncio
async def test_get_crafting_opportunities_sorted_by_profit(coordinator, mock_crafting_manager):
    """Test that opportunities are sorted by profit."""
    coordinator.crafting = mock_crafting_manager
    
    # Setup forge with high profit
    coordinator.forging.get_optimal_forge_target = Mock(return_value={
        "weapon_name": "Claymore",
        "profit": 10000
    })
    
    # Setup brew with medium profit
    coordinator.brewing.get_most_profitable_brew = Mock(return_value={
        "potion_name": "White Potion",
        "profit": 5000
    })
    
    market_prices = {713: 100, 507: 50, 501: 2000}  # Recipe profit: 1850
    
    opportunities = await coordinator.get_crafting_opportunities(
        {}, {}, market_prices
    )
    
    assert len(opportunities) == 3
    # Should be sorted by profit descending
    assert opportunities[0]["profit"] == 10000
    assert opportunities[1]["profit"] == 5000
    assert opportunities[2]["profit"] == 1850


# Profit Potential Tests

def test_get_profit_potential_forge(coordinator):
    """Test profit potential for forging."""
    forge_target = {"weapon_name": "Claymore", "profit": 5000}
    coordinator.forging.get_optimal_forge_target = Mock(return_value=forge_target)
    
    profitable = coordinator.get_profit_potential(
        CraftingType.FORGE, {}, {}, {}
    )
    
    assert len(profitable) == 1
    assert profitable[0]["weapon_name"] == "Claymore"


def test_get_profit_potential_brew(coordinator):
    """Test profit potential for brewing."""
    brew_target = {"potion_name": "White Potion", "profit": 1000}
    coordinator.brewing.get_most_profitable_brew = Mock(return_value=brew_target)
    
    profitable = coordinator.get_profit_potential(
        CraftingType.BREW, {}, {}, {}
    )
    
    assert len(profitable) == 1
    assert profitable[0]["potion_name"] == "White Potion"


def test_get_profit_potential_generic_recipes(coordinator, mock_crafting_manager):
    """Test profit potential for generic recipes."""
    coordinator.crafting = mock_crafting_manager
    
    market_prices = {713: 100, 507: 50, 501: 2000}
    inventory = {"713": 5, "507": 10}
    
    # Use COOK for generic recipe path (BREW/FORGE have special handling)
    profitable = coordinator.get_profit_potential(
        CraftingType.COOK, {}, inventory, market_prices
    )
    
    assert len(profitable) > 0
    assert profitable[0]["profit"] > 0


def test_get_profit_potential_no_materials(coordinator):
    """Test profit potential when missing materials."""
    recipe = Mock(spec=CraftingRecipe)
    recipe.recipe_id = 1
    recipe.materials = []
    
    coordinator.crafting.get_recipes_by_type = Mock(return_value=[recipe])
    coordinator.crafting.check_materials = Mock(return_value=(False, []))
    
    profitable = coordinator.get_profit_potential(
        CraftingType.COOK, {}, {}, {}
    )
    
    assert len(profitable) == 0


def test_get_profit_potential_negative_profit_filtered(coordinator):
    """Test that negative profit items are filtered out."""
    recipe = Mock(spec=CraftingRecipe)
    recipe.recipe_id = 1
    recipe.recipe_name = "Expensive Potion"
    recipe.result_item_id = 501
    recipe.materials = [
        Material(item_id=713, item_name="Empty Bottle", quantity_required=1, quantity_owned=5)
    ]
    
    coordinator.crafting.get_recipes_by_type = Mock(return_value=[recipe])
    coordinator.crafting.check_materials = Mock(return_value=(True, []))
    
    # Cost more than result
    market_prices = {713: 5000, 501: 100}
    
    profitable = coordinator.get_profit_potential(
        CraftingType.BREW, {}, {}, market_prices
    )
    
    assert len(profitable) == 0


# Shopping List Tests

def test_get_material_shopping_list_single_recipe(coordinator):
    """Test shopping list for single recipe."""
    material = Material(item_id=713, item_name="Empty Bottle", quantity_required=5, quantity_owned=0)
    coordinator.crafting.get_missing_materials = Mock(return_value=[material])
    
    shopping_list = coordinator.get_material_shopping_list([1], {})
    
    assert len(shopping_list) == 1
    assert shopping_list[0]["item_id"] == 713
    assert shopping_list[0]["item_name"] == "Empty Bottle"
    assert shopping_list[0]["quantity"] == 5


def test_get_material_shopping_list_multiple_recipes(coordinator):
    """Test shopping list aggregates materials from multiple recipes."""
    material1 = Material(item_id=713, item_name="Empty Bottle", quantity_required=3, quantity_owned=0)
    material2 = Material(item_id=713, item_name="Empty Bottle", quantity_required=2, quantity_owned=0)
    
    coordinator.crafting.get_missing_materials = Mock(side_effect=[
        [material1],
        [material2]
    ])
    
    shopping_list = coordinator.get_material_shopping_list([1, 2], {})
    
    assert len(shopping_list) == 1
    assert shopping_list[0]["item_id"] == 713
    assert shopping_list[0]["quantity"] == 5  # 3 + 2


def test_get_material_shopping_list_multiple_items(coordinator):
    """Test shopping list with different materials."""
    mat1 = Material(item_id=713, item_name="Empty Bottle", quantity_required=5, quantity_owned=0)
    mat2 = Material(item_id=507, item_name="Red Herb", quantity_required=3, quantity_owned=0)
    
    coordinator.crafting.get_missing_materials = Mock(return_value=[mat1, mat2])
    
    shopping_list = coordinator.get_material_shopping_list([1], {})
    
    assert len(shopping_list) == 2
    item_ids = {item["item_id"] for item in shopping_list}
    assert 713 in item_ids
    assert 507 in item_ids


def test_get_material_shopping_list_empty(coordinator):
    """Test shopping list when all materials available."""
    coordinator.crafting.get_missing_materials = Mock(return_value=[])
    
    shopping_list = coordinator.get_material_shopping_list([1], {})
    
    assert len(shopping_list) == 0


# Next Action Tests

@pytest.mark.asyncio
async def test_get_next_crafting_action_no_opportunities(coordinator):
    """Test next action when no opportunities."""
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[])
    coordinator.forging.get_optimal_forge_target = Mock(return_value=None)
    coordinator.brewing.get_most_profitable_brew = Mock(return_value=None)
    
    action = await coordinator.get_next_crafting_action({}, {}, "prontera")
    
    assert action["action"] == "none"
    assert "No crafting opportunities" in action["reason"]


@pytest.mark.asyncio
async def test_get_next_crafting_action_at_correct_location(coordinator, mock_crafting_manager):
    """Test action when already at crafting location."""
    coordinator.crafting = mock_crafting_manager
    
    action = await coordinator.get_next_crafting_action({}, {}, "prontera")
    
    assert action["action"] == "craft"
    assert "crafting_type" in action
    assert "target" in action


@pytest.mark.asyncio
async def test_get_next_crafting_action_wrong_location(coordinator, mock_crafting_manager):
    """Test action when at wrong location."""
    coordinator.crafting = mock_crafting_manager
    
    action = await coordinator.get_next_crafting_action({}, {}, "geffen")
    
    assert action["action"] == "move"
    assert action["target_map"] == "prontera"
    assert action["target_npc"] == "Alchemist"


@pytest.mark.asyncio
async def test_get_next_crafting_action_no_npc_map(coordinator):
    """Test action when recipe has no NPC map."""
    recipe = Mock()
    recipe.recipe_id = 1
    recipe.npc_map = None
    recipe.npc_name = None
    recipe.materials = []  # Fix: Add materials attribute to prevent iteration error
    
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[recipe])
    coordinator.crafting.calculate_success_rate = Mock(return_value=0.9)
    coordinator.crafting.get_recipe = Mock(return_value=recipe)
    coordinator.forging.get_optimal_forge_target = Mock(return_value=None)
    coordinator.brewing.get_most_profitable_brew = Mock(return_value=None)
    
    action = await coordinator.get_next_crafting_action({}, {}, "anywhere")
    
    assert action["action"] == "craft"


# Value Calculation Tests

def test_calculate_total_crafting_value(coordinator):
    """Test total value calculation."""
    coordinator.forging.get_fame = Mock(return_value=50)
    
    character_state = {"name": "TestChar"}
    
    value = coordinator.calculate_total_crafting_value(character_state)
    
    assert "total_value" in value
    assert "breakdown" in value
    assert value["breakdown"]["forging_fame"] == 50000  # 50 * 1000


def test_calculate_total_crafting_value_zero_fame(coordinator):
    """Test value calculation with zero fame."""
    coordinator.forging.get_fame = Mock(return_value=0)
    
    value = coordinator.calculate_total_crafting_value({"name": "NewChar"})
    
    assert value["total_value"] == 0
    assert value["breakdown"]["forging_fame"] == 0


# Statistics Tests

def test_get_statistics(coordinator):
    """Test getting aggregate statistics."""
    coordinator.crafting.get_statistics = Mock(return_value={"recipes": 10})
    coordinator.forging.get_statistics = Mock(return_value={"forged": 5})
    coordinator.brewing.get_statistics = Mock(return_value={"brewed": 20})
    coordinator.refining.get_statistics = Mock(return_value={"refined": 15})
    coordinator.enchanting.get_statistics = Mock(return_value={"enchanted": 3})
    coordinator.cards.get_statistics = Mock(return_value={"cards": 50})
    
    stats = coordinator.get_statistics()
    
    assert "crafting" in stats
    assert "forging" in stats
    assert "brewing" in stats
    assert "refining" in stats
    assert "enchanting" in stats
    assert "cards" in stats
    assert stats["crafting"]["recipes"] == 10


# Integration Tests

@pytest.mark.asyncio
async def test_full_workflow_profitable_craft(coordinator):
    """Test full workflow finding profitable craft."""
    # Setup profitable recipe
    recipe = Mock()
    recipe.recipe_id = 1
    recipe.recipe_name = "Blue Potion"
    recipe.result_item_id = 505
    recipe.result_item_name = "Blue Potion"
    recipe.crafting_type = CraftingType.BREW
    recipe.npc_map = "alberta"
    recipe.npc_name = "Brewer"
    recipe.materials = [
        Material(item_id=713, item_name="Empty Bottle", quantity_required=1, quantity_owned=10),
        Material(item_id=510, item_name="Blue Herb", quantity_required=1, quantity_owned=10)
    ]
    
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[recipe])
    coordinator.crafting.calculate_success_rate = Mock(return_value=0.95)
    coordinator.crafting.get_recipe = Mock(return_value=recipe)
    
    market_prices = {713: 100, 510: 200, 505: 1000}  # Profit: 700
    
    opportunities = await coordinator.get_crafting_opportunities(
        {}, {}, market_prices
    )
    
    assert len(opportunities) > 0
    assert opportunities[0]["profit"] == 700
    
    # Get next action
    action = await coordinator.get_next_crafting_action({}, {}, "prontera")
    
    assert action["action"] == "move"
    assert action["target_map"] == "alberta"


@pytest.mark.asyncio
async def test_multiple_crafting_types_integration(coordinator):
    """Test handling multiple crafting types simultaneously."""
    # Setup recipe
    recipe = Mock()
    recipe.recipe_id = 1
    recipe.crafting_type = CraftingType.BREW
    recipe.recipe_name = "Potion"
    recipe.result_item_id = 501
    recipe.result_item_name = "Red Potion"
    recipe.materials = [
        Material(item_id=713, item_name="Empty Bottle", quantity_required=1, quantity_owned=5)
    ]
    
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[recipe])
    coordinator.crafting.calculate_success_rate = Mock(return_value=0.9)
    
    # Setup forging
    coordinator.forging.get_optimal_forge_target = Mock(return_value={
        "weapon_name": "Sword",
        "profit": 3000
    })
    
    # Setup brewing
    coordinator.brewing.get_most_profitable_brew = Mock(return_value={
        "potion_name": "White Potion",
        "profit": 1000
    })
    
    market_prices = {713: 100, 501: 500}
    
    opportunities = await coordinator.get_crafting_opportunities(
        {}, {}, market_prices
    )
    
    assert len(opportunities) == 3
    types = {opp["type"] for opp in opportunities}
    assert "recipe" in types
    assert "forge" in types
    assert "brew" in types


# Edge Cases

@pytest.mark.asyncio
async def test_empty_inventory(coordinator):
    """Test with empty inventory."""
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[])
    
    opportunities = await coordinator.get_crafting_opportunities({}, {})
    
    assert len(opportunities) == 0


def test_get_profit_potential_forge_no_target(coordinator):
    """Test profit potential when no forge target available."""
    coordinator.forging.get_optimal_forge_target = Mock(return_value=None)
    
    profitable = coordinator.get_profit_potential(
        CraftingType.FORGE, {}, {}, {}
    )
    
    assert len(profitable) == 0


def test_get_profit_potential_brew_no_target(coordinator):
    """Test profit potential when no brew target available."""
    coordinator.brewing.get_most_profitable_brew = Mock(return_value=None)
    
    profitable = coordinator.get_profit_potential(
        CraftingType.BREW, {}, {}, {}
    )
    
    assert len(profitable) == 0


@pytest.mark.asyncio
async def test_get_next_action_best_opportunity_selected(coordinator):
    """Test that best opportunity is selected for action."""
    recipe1 = Mock()
    recipe1.recipe_id = 1
    recipe1.recipe_name = "Cheap Potion"
    recipe1.crafting_type = CraftingType.BREW
    recipe1.result_item_id = 501
    recipe1.result_item_name = "Red Potion"
    recipe1.npc_map = "prontera"
    recipe1.materials = [
        Material(item_id=713, item_name="Empty Bottle", quantity_required=1, quantity_owned=5)
    ]
    
    coordinator.crafting.get_craftable_recipes = Mock(return_value=[recipe1])
    coordinator.crafting.calculate_success_rate = Mock(return_value=0.9)
    coordinator.crafting.get_recipe = Mock(return_value=recipe1)
    
    market_prices = {713: 100, 501: 500}
    
    # Get opportunities first to trigger profit calculation
    await coordinator.get_crafting_opportunities({}, {}, market_prices)
    
    action = await coordinator.get_next_crafting_action({}, {}, "prontera")
    
    assert action["action"] == "craft"


def test_shopping_list_complex_aggregation(coordinator):
    """Test complex shopping list aggregation."""
    mat1_recipe1 = Material(item_id=713, item_name="Empty Bottle", quantity_required=5, quantity_owned=0)
    mat2_recipe1 = Material(item_id=507, item_name="Red Herb", quantity_required=3, quantity_owned=0)
    
    mat1_recipe2 = Material(item_id=713, item_name="Empty Bottle", quantity_required=2, quantity_owned=0)
    mat3_recipe2 = Material(item_id=508, item_name="Yellow Herb", quantity_required=1, quantity_owned=0)
    
    coordinator.crafting.get_missing_materials = Mock(side_effect=[
        [mat1_recipe1, mat2_recipe1],
        [mat1_recipe2, mat3_recipe2]
    ])
    
    shopping_list = coordinator.get_material_shopping_list([1, 2], {})
    
    assert len(shopping_list) == 3
    
    # Check Empty Bottle aggregation
    bottle = next(item for item in shopping_list if item["item_id"] == 713)
    assert bottle["quantity"] == 7  # 5 + 2


def test_value_calculation_default_character_name(coordinator):
    """Test value calculation with default character name."""
    coordinator.forging.get_fame = Mock(return_value=25)
    
    value = coordinator.calculate_total_crafting_value({})
    
    coordinator.forging.get_fame.assert_called_once_with("Unknown")


@pytest.mark.asyncio
async def test_opportunities_no_market_prices_unsorted(coordinator, mock_crafting_manager):
    """Test that opportunities without market prices aren't sorted by profit."""
    coordinator.crafting = mock_crafting_manager
    
    opportunities = await coordinator.get_crafting_opportunities({}, {})
    
    # Should still return opportunities, just without profit sorting
    assert len(opportunities) > 0
    assert "profit" not in opportunities[0]