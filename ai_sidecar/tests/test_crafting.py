"""
Comprehensive tests for crafting and enchanting systems.
"""

from pathlib import Path

import pytest

from ai_sidecar.crafting import (
    BrewableItem,
    BrewingManager,
    Card,
    CardCombo,
    CardManager,
    CardSlotType,
    CraftingCoordinator,
    CraftingManager,
    CraftingRecipe,
    CraftingType,
    EnchantingManager,
    EnchantOption,
    EnchantSlot,
    EnchantType,
    ForgeableWeapon,
    ForgeElement,
    ForgingManager,
    Material,
    PotionType,
    RefineOre,
    RefiningManager,
)


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test data"""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Create minimal test data files
    (data_dir / "crafting_recipes.json").write_text('{"recipes": []}')
    (data_dir / "forge_weapons.json").write_text('{"weapons": []}')
    (data_dir / "brew_items.json").write_text('{"items": []}')
    (data_dir / "refine_rates.json").write_text(
        '{"weapon_rates": {}, "armor_rates": {}, "ore_types": {}}'
    )
    (data_dir / "enchants.json").write_text('{}')
    (data_dir / "cards.json").write_text('{"cards": [], "combos": []}')
    
    return data_dir


@pytest.fixture
def character_state() -> dict:
    """Sample character state"""
    return {
        "name": "TestChar",
        "level": 99,
        "job_level": 70,
        "job": "Whitesmith",
        "str": 80,
        "agi": 50,
        "vit": 60,
        "int": 40,
        "dex": 90,
        "luk": 50,
        "zeny": 10000000,
        "skills": {
            "Smith Sword": 10,
            "Smith Dagger": 10,
            "Pharmacy": 10,
        },
    }


@pytest.fixture
def inventory() -> dict:
    """Sample inventory"""
    return {
        998: 1000,   # Iron
        999: 500,    # Steel
        984: 100,    # Oridecon
        985: 100,    # Elunium
        1010: 10,    # Iron Hammer
        507: 200,    # Red Herb
        713: 100,    # Empty Bottle
    }


class TestCraftingManager:
    """Test core crafting system"""
    
    def test_crafting_manager_init(self, data_dir: Path):
        """Test crafting manager initialization"""
        manager = CraftingManager(data_dir)
        assert manager is not None
        assert isinstance(manager.recipes, dict)
    
    def test_material_availability(self):
        """Test material availability check"""
        material = Material(
            item_id=998,
            item_name="Iron",
            quantity_required=50,
            quantity_owned=100
        )
        
        assert material.is_available
        assert material.quantity_missing == 0
        
        material.quantity_owned = 30
        assert not material.is_available
        assert material.quantity_missing == 20
    
    def test_recipe_requirements(self):
        """Test recipe requirement properties"""
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1101,
            result_item_name="Blade",
            materials=[],
            required_base_level=50,
            required_skill="Smith Sword",
            required_skill_level=5
        )
        
        assert recipe.has_level_requirement
        assert recipe.has_skill_requirement
    
    def test_material_check(self, data_dir: Path, inventory: dict):
        """Test material availability check"""
        manager = CraftingManager(data_dir)
        
        recipe = CraftingRecipe(
            recipe_id=1001,
            recipe_name="Test Craft",
            crafting_type=CraftingType.FORGE,
            result_item_id=1101,
            result_item_name="Blade",
            materials=[
                Material(item_id=998, item_name="Iron", quantity_required=35),
                Material(item_id=999, item_name="Steel", quantity_required=15),
            ]
        )
        manager.recipes[1001] = recipe
        
        has_materials, missing = manager.check_materials(1001, inventory)
        assert has_materials
        assert len(missing) == 0
    
    def test_success_rate_calculation(self, data_dir: Path, character_state: dict):
        """Test success rate calculation"""
        manager = CraftingManager(data_dir)
        
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Item",
            materials=[],
            base_success_rate=50.0,
            dex_bonus=0.5,
            luk_bonus=0.2
        )
        manager.recipes[1] = recipe
        
        rate = manager.calculate_success_rate(1, character_state)
        # Base 50 + (90 DEX * 0.5) + (50 LUK * 0.2) = 50 + 45 + 10 = 105, capped at 100
        assert rate == 100.0


class TestForgingManager:
    """Test forging system"""
    
    def test_forging_manager_init(self, data_dir: Path):
        """Test forging manager initialization"""
        crafting = CraftingManager(data_dir)
        manager = ForgingManager(data_dir, crafting)
        assert manager is not None
        assert isinstance(manager.forgeable_weapons, dict)
    
    def test_forge_rate_calculation(self, data_dir: Path, character_state: dict):
        """Test forge success rate calculation"""
        crafting = CraftingManager(data_dir)
        manager = ForgingManager(data_dir, crafting)
        
        weapon = ForgeableWeapon(
            weapon_id=1101,
            weapon_name="Blade",
            weapon_level=3,
            base_materials=[]
        )
        manager.forgeable_weapons[1101] = weapon
        
        # Test base rate
        rate = manager.get_forge_success_rate(1101, character_state)
        assert 0 <= rate <= 100
        
        # Test with element penalty
        rate_fire = manager.get_forge_success_rate(
            1101, character_state, ForgeElement.FIRE
        )
        assert rate_fire < rate
        
        # Test with star crumb penalty
        rate_stars = manager.get_forge_success_rate(
            1101, character_state, star_crumbs=2
        )
        assert rate_stars < rate
    
    def test_element_forging(self, data_dir: Path):
        """Test element application"""
        crafting = CraftingManager(data_dir)
        manager = ForgingManager(data_dir, crafting)
        
        weapon = ForgeableWeapon(
            weapon_id=1101,
            weapon_name="Blade",
            weapon_level=2,
            base_materials=[],
            element_stone=Material(
                item_id=994, item_name="Flame Heart", quantity_required=1
            )
        )
        manager.forgeable_weapons[1101] = weapon
        
        materials = manager.get_required_materials(
            1101, ForgeElement.FIRE
        )
        
        # Should include element stone
        assert any(m.item_id == 994 for m in materials)
    
    def test_fame_tracking(self, data_dir: Path):
        """Test fame point tracking"""
        crafting = CraftingManager(data_dir)
        manager = ForgingManager(data_dir, crafting)
        
        fame = manager.add_fame("TestChar", 10)
        assert fame == 10
        
        fame = manager.add_fame("TestChar", 5)
        assert fame == 15
        
        assert manager.get_fame("TestChar") == 15


class TestBrewingManager:
    """Test brewing system"""
    
    def test_brewing_manager_init(self, data_dir: Path):
        """Test brewing manager initialization"""
        crafting = CraftingManager(data_dir)
        manager = BrewingManager(data_dir, crafting)
        assert manager is not None
        assert isinstance(manager.brewable_items, dict)
    
    def test_brew_rate_calculation(self, data_dir: Path, character_state: dict):
        """Test brewing success rate"""
        crafting = CraftingManager(data_dir)
        manager = BrewingManager(data_dir, crafting)
        
        item = BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[],
            required_skill="Pharmacy",
            required_skill_level=1,
            base_success_rate=50.0
        )
        manager.brewable_items[501] = item
        
        rate = manager.calculate_brew_rate(501, character_state)
        # Should include INT, DEX, LUK, skill level bonuses
        assert rate > 50.0
        assert rate <= 100.0
    
    def test_batch_brew_info(self, data_dir: Path, inventory: dict):
        """Test batch brewing calculations"""
        crafting = CraftingManager(data_dir)
        manager = BrewingManager(data_dir, crafting)
        
        item = BrewableItem(
            item_id=501,
            item_name="Red Potion",
            potion_type=PotionType.HEALING,
            materials=[
                Material(item_id=507, item_name="Red Herb", quantity_required=1),
                Material(item_id=713, item_name="Empty Bottle", quantity_required=1)
            ],
            required_skill="Pharmacy",
            required_skill_level=1,
            base_success_rate=100.0,
            batch_size=3
        )
        manager.brewable_items[501] = item
        
        info = manager.get_batch_brew_info(501, inventory)
        assert info["can_brew"]
        assert info["items_per_batch"] == 3
        assert info["max_batches"] > 0


class TestRefiningManager:
    """Test refining system"""
    
    def test_refining_manager_init(self, data_dir: Path):
        """Test refining manager initialization"""
        crafting = CraftingManager(data_dir)
        manager = RefiningManager(data_dir, crafting)
        assert manager is not None
        # Should have default rates initialized
        assert len(manager.refine_rates) > 0
    
    def test_refine_rates(self, data_dir: Path, character_state: dict):
        """Test refine success rates"""
        crafting = CraftingManager(data_dir)
        manager = RefiningManager(data_dir, crafting)
        
        # Test safe level (+4)
        rate_safe = manager.calculate_refine_rate(
            3, False, RefineOre.ORIDECON, character_state
        )
        assert rate_safe == 100.0
        
        # Test risky level (+5)
        rate_risky = manager.calculate_refine_rate(
            4, False, RefineOre.ORIDECON, character_state
        )
        assert rate_risky < 100.0
    
    def test_safe_limits(self, data_dir: Path):
        """Test safe refine limits"""
        crafting = CraftingManager(data_dir)
        manager = RefiningManager(data_dir, crafting)
        
        # Armor safe limit
        assert manager.get_safe_limit(1, True) == 4
        
        # Weapon safe limits by level
        assert manager.get_safe_limit(1, False) == 7
        assert manager.get_safe_limit(4, False) == 4
    
    def test_expected_cost(self, data_dir: Path):
        """Test expected cost calculation"""
        crafting = CraftingManager(data_dir)
        manager = RefiningManager(data_dir, crafting)
        
        ore_prices = {
            "oridecon": 5000,
            "elunium": 3000,
        }
        
        result = manager.calculate_expected_cost(
            4, 7, False, ore_prices, item_value=1000000
        )
        
        assert "total_ore_cost" in result
        assert "expected_break_cost" in result
        assert "details" in result


class TestEnchantingManager:
    """Test enchanting system"""
    
    def test_enchanting_manager_init(self, data_dir: Path):
        """Test enchanting manager initialization"""
        crafting = CraftingManager(data_dir)
        manager = EnchantingManager(data_dir, crafting)
        assert manager is not None
        assert isinstance(manager.enchant_pools, dict)
    
    def test_enchant_probability(self, data_dir: Path):
        """Test enchant probability calculation"""
        crafting = CraftingManager(data_dir)
        manager = EnchantingManager(data_dir, crafting)
        
        # Create test enchant pool
        from ai_sidecar.crafting.enchanting import EnchantPool
        
        pool = EnchantPool(
            item_id=22000,
            item_name="Temporal Boots",
            enchant_type=EnchantType.TEMPORAL,
            slot=EnchantSlot.SLOT_1,
            possible_enchants=[
                EnchantOption(
                    enchant_id=4950,
                    enchant_name="Expert Archer 1",
                    stat_bonus={"ranged": 5},
                    weight=30,
                    is_desirable=True
                ),
                EnchantOption(
                    enchant_id=4951,
                    enchant_name="Expert Archer 2",
                    stat_bonus={"ranged": 8},
                    weight=15,
                    is_desirable=True
                ),
                EnchantOption(
                    enchant_id=4800,
                    enchant_name="STR +1",
                    stat_bonus={"str": 1},
                    weight=55
                ),
            ],
            cost_zeny=100000
        )
        manager.enchant_pools[(22000, EnchantSlot.SLOT_1)] = pool
        
        # Calculate probabilities
        prob1 = manager.calculate_enchant_probability(4950, 22000, EnchantSlot.SLOT_1)
        prob2 = manager.calculate_enchant_probability(4951, 22000, EnchantSlot.SLOT_1)
        
        assert prob1 == 30.0  # 30 / 100 * 100
        assert prob2 == 15.0  # 15 / 100 * 100
        
        # Test expected attempts
        attempts = manager.get_expected_attempts(4951, 22000, EnchantSlot.SLOT_1)
        assert attempts == 6  # 100 / 15 ≈ 6


class TestCardManager:
    """Test card system"""
    
    def test_card_manager_init(self, data_dir: Path):
        """Test card manager initialization"""
        manager = CardManager(data_dir)
        assert manager is not None
        assert isinstance(manager.cards, dict)
        assert isinstance(manager.combos, dict)
    
    def test_combo_detection(self, data_dir: Path):
        """Test card combo detection"""
        manager = CardManager(data_dir)
        
        # Add test cards and combo
        manager.cards[4058] = Card(
            card_id=4058,
            card_name="Thief Bug Card",
            slot_type=CardSlotType.WEAPON,
            effects={"agi": 1},
            combo_with=[4059, 4060]
        )
        manager.cards[4059] = Card(
            card_id=4059,
            card_name="Female Thief Bug Card",
            slot_type=CardSlotType.SHIELD,
            effects={"agi": 1},
            combo_with=[4058, 4060]
        )
        manager.cards[4060] = Card(
            card_id=4060,
            card_name="Male Thief Bug Card",
            slot_type=CardSlotType.ARMOR,
            effects={"agi": 2},
            combo_with=[4058, 4059]
        )
        
        manager.combos[1] = CardCombo(
            combo_id=1,
            combo_name="Thief Set",
            required_cards=[4058, 4059, 4060],
            combo_effect="+20% Crit, +10 Perfect Dodge"
        )
        
        # Test complete combo
        equipped = [4058, 4059, 4060]
        combos = manager.check_combo(equipped)
        assert len(combos) == 1
        assert combos[0].is_complete
        
        # Test incomplete combo
        equipped = [4058, 4059]
        combos = manager.check_combo(equipped)
        assert len(combos) == 0
    
    def test_missing_combo_cards(self, data_dir: Path):
        """Test missing combo card detection"""
        manager = CardManager(data_dir)
        
        manager.combos[1] = CardCombo(
            combo_id=1,
            combo_name="Test",
            required_cards=[4058, 4059, 4060],
            combo_effect="Test"
        )
        
        equipped = [4058, 4059]
        missing = manager.get_missing_combo_cards(1, equipped)
        assert 4060 in missing
        assert len(missing) == 1
    
    def test_card_removal_risk(self, data_dir: Path):
        """Test card removal risk calculation"""
        manager = CardManager(data_dir)
        
        risk1 = manager.calculate_card_removal_risk(1101, 1)
        assert risk1["success_rate"] == 90.0
        assert risk1["card_destruction_rate"] == 10.0
        
        risk4 = manager.calculate_card_removal_risk(1101, 4)
        assert risk4["success_rate"] == 60.0
        assert risk4["card_destruction_rate"] == 40.0


class TestCraftingCoordinator:
    """Test integrated crafting system"""
    
    @pytest.fixture
    def coordinator(self, data_dir: Path) -> CraftingCoordinator:
        """Create crafting coordinator"""
        return CraftingCoordinator(data_dir)
    
    async def test_crafting_opportunities(
        self,
        coordinator: CraftingCoordinator,
        character_state: dict,
        inventory: dict
    ):
        """Test opportunity detection"""
        opportunities = await coordinator.get_crafting_opportunities(
            character_state, inventory
        )
        
        assert isinstance(opportunities, list)
    
    async def test_profit_calculation(
        self,
        coordinator: CraftingCoordinator,
        character_state: dict,
        inventory: dict
    ):
        """Test profit potential calculation"""
        market_prices = {
            998: 100,   # Iron
            999: 500,   # Steel
            1101: 50000,  # Blade
        }
        
        profitable = coordinator.get_profit_potential(
            CraftingType.FORGE,
            character_state,
            inventory,
            market_prices
        )
        
        assert isinstance(profitable, list)
    
    def test_shopping_list(
        self,
        coordinator: CraftingCoordinator,
        inventory: dict
    ):
        """Test material shopping list generation"""
        # Add a recipe
        recipe = CraftingRecipe(
            recipe_id=1,
            recipe_name="Test",
            crafting_type=CraftingType.FORGE,
            result_item_id=1,
            result_item_name="Item",
            materials=[
                Material(item_id=1, item_name="Mat1", quantity_required=10),
                Material(item_id=2, item_name="Mat2", quantity_required=5),
            ]
        )
        coordinator.crafting.recipes[1] = recipe
        
        shopping = coordinator.get_material_shopping_list([1], {})
        assert len(shopping) == 2
    
    def test_statistics(self, coordinator: CraftingCoordinator):
        """Test statistics aggregation"""
        stats = coordinator.get_statistics()
        
        assert "crafting" in stats
        assert "forging" in stats
        assert "brewing" in stats
        assert "refining" in stats
        assert "enchanting" in stats
        assert "cards" in stats


class TestModels:
    """Test data models"""
    
    def test_material_model(self):
        """Test Material model"""
        material = Material(
            item_id=998,
            item_name="Iron",
            quantity_required=50,
            quantity_owned=75
        )
        
        assert material.is_available
        assert material.quantity_missing == 0
    
    def test_forgeable_weapon_model(self):
        """Test ForgeableWeapon model"""
        weapon = ForgeableWeapon(
            weapon_id=1101,
            weapon_name="Blade",
            weapon_level=3,
            base_materials=[],
            element_stone=Material(
                item_id=994, item_name="Flame Heart", quantity_required=1
            ),
            star_crumb_count=2
        )
        
        assert weapon.requires_element_stone
        assert weapon.is_vvs_weapon
    
    def test_enchant_option_model(self):
        """Test EnchantOption model"""
        enchant = EnchantOption(
            enchant_id=4702,
            enchant_name="STR +3",
            stat_bonus={"str": 3, "atk": 5},
            weight=25,
            is_desirable=True
        )
        
        assert enchant.total_stat_value == 8  # 3 + 5