"""
Coverage Batch 2: Equipment & Economy Systems
Target: ~92% → ~96% coverage (~150-180 lines)

Modules tested:
- ai_sidecar.equipment.models (540 lines, target uncovered lines)
- ai_sidecar.equipment.valuation (703 lines, target uncovered lines)  
- ai_sidecar.consumables.coordinator (582 lines, target uncovered lines)
- ai_sidecar.economy.storage (405 lines, target uncovered lines)
- ai_sidecar.economy.buying (454 lines, target uncovered lines)

Test Strategy: Target edge cases, boundary conditions, error paths,
and integration scenarios to maximize coverage.
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from pathlib import Path

# Equipment models imports
from ai_sidecar.equipment.models import (
    Equipment,
    EquipSlot,
    EquipmentType,
    WeaponType,
    CardSlot,
    EquipmentLoadout,
    EquipmentSet,
    InventoryItem,
    StorageItem,
    MarketPrice,
    get_refine_success_rate,
    calculate_refine_cost,
)

# Equipment valuation imports
from ai_sidecar.equipment.valuation import (
    BuildWeights,
    RefineAnalysis,
    ItemValuationEngine,
    EquipmentEvaluator,
    DEFAULT_BUILD_WEIGHTS,
)

# Consumables coordinator imports
from ai_sidecar.consumables.coordinator import (
    ConsumableCoordinator,
    ConsumableContext,
    ConsumableAction,
    ActionPriority,
)
from ai_sidecar.consumables.recovery import RecoveryConfig

# Economy imports
from ai_sidecar.economy.storage import (
    StorageManager,
    StorageManagerConfig,
    ItemPriority,
)
from ai_sidecar.economy.buying import (
    BuyingManager,
    PurchaseTarget,
    PurchasePriority,
)
from ai_sidecar.economy.core import MarketListing, MarketSource, PriceTrend, MarketManager
from ai_sidecar.economy.price_analysis import PriceAnalyzer
from ai_sidecar.core.state import InventoryItem as CoreInventoryItem


# ============================================================================
# EQUIPMENT MODELS TESTS (12-15 tests)
# ============================================================================

class TestEquipmentModelsComplete:
    """Comprehensive tests for equipment models edge cases."""
    
    def test_card_slot_boundary_validation_max_slots(self):
        """
        Cover equipment.py: CardSlot validation with slot_index at max boundary.
        Tests validation of card slot index at upper limit (3).
        """
        # Arrange & Act
        card_slot = CardSlot(slot_index=3, card_id=4001, card_name="Poring Card")
        
        # Assert
        assert card_slot.slot_index == 3
        assert card_slot.card_id == 4001
    
    def test_equipment_total_atk_non_weapon_slot(self):
        """
        Cover equipment.py line 181-183: total_atk property for non-weapon slots.
        Ensures ATK calculation doesn't add refine bonus for armor.
        """
        # Arrange
        armor = Equipment(
            item_id=2301,
            name="Cotton Shirt",
            slot=EquipSlot.ARMOR,
            refine=10,
            atk=5,
        )
        
        # Act
        total = armor.total_atk
        
        # Assert
        assert total == 5  # No refine bonus for armor ATK
    
    def test_equipment_total_defense_non_armor_slot(self):
        """
        Cover equipment.py line 189-191: total_defense property for non-armor slots.
        Ensures DEF calculation doesn't add refine bonus for weapons.
        """
        # Arrange
        weapon = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            refine=10,
            defense=2,
        )
        
        # Act
        total = weapon.total_defense
        
        # Assert
        assert total == 2  # No refine bonus for weapon DEF
    
    def test_equipment_card_count_with_none_cards(self):
        """
        Cover equipment.py line 195-196: card_count property with mixed None cards.
        Tests counting only inserted cards, ignoring empty slots.
        """
        # Arrange
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=4,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=None),
                CardSlot(slot_index=2, card_id=4002),
                CardSlot(slot_index=3, card_id=None),
            ]
        )
        
        # Act
        count = equipment.card_count
        
        # Assert
        assert count == 2
    
    def test_equipment_is_fully_carded_exactly_filled(self):
        """
        Cover equipment.py line 200-201: is_fully_carded when card_count == slots.
        Tests edge case where all slots are exactly filled.
        """
        # Arrange
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=2,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=4002),
            ]
        )
        
        # Act
        is_full = equipment.is_fully_carded
        
        # Assert
        assert is_full is True
    
    def test_equipment_has_empty_slots_all_filled(self):
        """
        Cover equipment.py line 205-206: has_empty_slots when all slots filled.
        Tests negative case where no empty slots remain.
        """
        # Arrange
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=2,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=4002),
            ]
        )
        
        # Act
        has_empty = equipment.has_empty_slots
        
        # Assert
        assert has_empty is False
    
    def test_equipment_is_armor_shield_slot(self):
        """
        Cover equipment.py line 213-214: is_armor method for SHIELD slot.
        Tests armor classification for shield equipment.
        """
        # Arrange
        shield = Equipment(
            item_id=2101,
            name="Guard",
            slot=EquipSlot.SHIELD,
        )
        
        # Act & Assert
        assert shield.is_armor() is True
    
    def test_equipment_is_armor_garment_slot(self):
        """
        Cover equipment.py line 213-214: is_armor method for GARMENT slot.
        Tests armor classification for garment equipment.
        """
        # Arrange
        garment = Equipment(
            item_id=2501,
            name="Hood",
            slot=EquipSlot.GARMENT,
        )
        
        # Act & Assert
        assert garment.is_armor() is True
    
    def test_equipment_set_get_active_bonuses_multiple_tiers(self):
        """
        Cover equipment.py line 248-252: EquipmentSet.get_active_bonuses with multiple tiers.
        Tests bonus aggregation across multiple equipment count thresholds.
        """
        # Arrange
        equipment_set = EquipmentSet(
            set_id=1,
            name="Valkyrie Set",
            pieces=[2357, 2421, 2524],
            bonuses={
                2: ["MDEF +5", "Max HP +500"],
                3: ["MDEF +5", "Max SP +50", "Def +5"],
            }
        )
        
        # Act
        bonuses = equipment_set.get_active_bonuses(3)
        
        # Assert
        assert len(bonuses) == 5  # All bonuses from 2-piece and 3-piece
        assert "MDEF +5" in bonuses
        assert "Max HP +500" in bonuses
        assert "Max SP +50" in bonuses
    
    def test_inventory_item_total_weight_with_quantity(self):
        """
        Cover equipment.py line 296-298: InventoryItem.total_weight calculation.
        Tests weight calculation for stacked equipment items.
        """
        # Arrange
        equipment = Equipment(
            item_id=501,
            name="Red Potion",
            slot=EquipSlot.WEAPON,
            weight=7,
        )
        item = InventoryItem(
            item_id=501,
            name="Red Potion",
            quantity=10,
            item_type="equipment",
            equipment=equipment,
        )
        
        # Act
        total = item.total_weight
        
        # Assert
        assert total == 70  # 7 * 10
    
    def test_equipment_loadout_set_equipment_for_all_slots(self):
        """
        Cover equipment.py line 424-425: EquipmentLoadout.set_equipment for all slots.
        Tests setting equipment in each possible slot.
        """
        # Arrange
        loadout = EquipmentLoadout(name="Test Loadout")
        weapon = Equipment(item_id=1201, name="Knife", slot=EquipSlot.WEAPON)
        
        # Act
        loadout.set_equipment(EquipSlot.WEAPON, weapon)
        
        # Assert
        assert loadout.weapon == weapon
        assert loadout.get_equipment_by_slot(EquipSlot.WEAPON) == weapon
    
    def test_equipment_loadout_equipped_set_pieces_multiple_sets(self):
        """
        Cover equipment.py line 456-461: EquipmentLoadout.equipped_set_pieces with multiple sets.
        Tests counting pieces across different equipment sets.
        """
        # Arrange
        loadout = EquipmentLoadout(name="Multi-Set")
        loadout.weapon = Equipment(
            item_id=1201, name="Sword", slot=EquipSlot.WEAPON, set_id=1
        )
        loadout.armor = Equipment(
            item_id=2301, name="Armor", slot=EquipSlot.ARMOR, set_id=1
        )
        loadout.shield = Equipment(
            item_id=2101, name="Shield", slot=EquipSlot.SHIELD, set_id=2
        )
        
        # Act
        set_counts = loadout.equipped_set_pieces
        
        # Assert
        assert set_counts[1] == 2
        assert set_counts[2] == 1
    
    def test_get_refine_success_rate_target_equals_current(self):
        """
        Cover equipment.py line 500-501: get_refine_success_rate when target <= current.
        Tests 100% success rate for non-upgrade scenarios.
        """
        # Arrange & Act
        rate = get_refine_success_rate(EquipSlot.WEAPON, current_refine=10, target_refine=10)
        
        # Assert
        assert rate == 1.0
    
    def test_calculate_refine_cost_target_equals_current(self):
        """
        Cover equipment.py line 531-532: calculate_refine_cost when target <= current.
        Tests zero cost for non-upgrade scenarios.
        """
        # Arrange & Act
        cost = calculate_refine_cost(current_refine=10, target_refine=10)
        
        # Assert
        assert cost == 0


# ============================================================================
# EQUIPMENT VALUATION TESTS (10-15 tests)
# ============================================================================

class TestEquipmentValuationComplete:
    """Comprehensive tests for equipment valuation edge cases."""
    
    def test_item_valuation_engine_load_market_prices_file_not_found(self):
        """
        Cover valuation.py line 178-179: load_market_prices with missing file.
        Tests graceful handling of missing market prices file.
        """
        # Arrange
        engine = ItemValuationEngine()
        
        # Act (should not raise exception)
        engine.load_market_prices("/nonexistent/path/prices.json")
        
        # Assert
        assert len(engine.market_prices) == 0
    
    def test_calculate_equipment_score_with_empty_card_slots(self):
        """
        Cover valuation.py line 230-231: calculate_equipment_score with empty slots.
        Tests scoring bonus for equipment with unfilled card slots.
        """
        # Arrange
        engine = ItemValuationEngine()
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=4,
            cards=[CardSlot(slot_index=0, card_id=4001)],  # Only 1 of 4 filled
        )
        
        # Act
        score = engine.calculate_equipment_score(equipment, "melee_dps")
        
        # Assert
        assert score > 0  # Empty slots add value (3 empty * 5.0)
    
    def test_calculate_equipment_score_with_special_effects(self):
        """
        Cover valuation.py line 234: calculate_equipment_score with effects.
        Tests scoring for equipment with special effect descriptions.
        """
        # Arrange
        engine = ItemValuationEngine()
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            effects=["Auto-cast Level 1 Heal", "Indestructible"],
        )
        
        # Act
        score = engine.calculate_equipment_score(equipment, "support")
        
        # Assert
        assert score > 0  # Effects add 10.0 per effect
    
    def test_estimate_market_value_no_market_data(self):
        """
        Cover valuation.py line 261-264: estimate_market_value fallback pricing.
        Tests fallback pricing when market data unavailable.
        """
        # Arrange
        engine = ItemValuationEngine(market_prices={})
        equipment = Equipment(
            item_id=9999,  # Unknown item
            name="Rare Item",
            slot=EquipSlot.WEAPON,
        )
        
        # Act
        min_price, avg_price, max_price = engine.estimate_market_value(equipment)
        
        # Assert
        assert avg_price == 9999 * 100  # Fallback formula
        assert min_price < avg_price < max_price
    
    def test_estimate_market_value_with_cards(self):
        """
        Cover valuation.py line 272-278: estimate_market_value with inserted cards.
        Tests market value calculation including card values.
        """
        # Arrange
        card_market = MarketPrice(
            item_id=4001,
            min_price=10000,
            avg_price=50000,
            max_price=100000,
        )
        engine = ItemValuationEngine(market_prices={4001: card_market})
        
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=4001),
            ],
        )
        
        # Act
        min_price, avg_price, max_price = engine.estimate_market_value(equipment)
        
        # Assert
        assert avg_price > 100000  # Base + 2 cards
    
    def test_compare_equipment_empty_current_slot(self):
        """
        Cover valuation.py line 309-311: compare_equipment with None current.
        Tests comparison when slot is empty (any equipment is better).
        """
        # Arrange
        engine = ItemValuationEngine()
        candidate = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            atk=15,
        )
        
        # Act
        score_diff = engine.compare_equipment(None, candidate, "melee_dps")
        
        # Assert
        assert score_diff > 0  # Candidate score (empty slot = candidate better)
    
    def test_calculate_refine_value_target_below_current(self):
        """
        Cover valuation.py line 336-345: calculate_refine_value when target <= current.
        Tests refine analysis when no upgrade needed.
        """
        # Arrange
        engine = ItemValuationEngine()
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            refine=10,
        )
        
        # Act
        analysis = engine.calculate_refine_value(equipment, target_refine=5, build="melee_dps")
        
        # Assert
        assert analysis.success_rate == 1.0
        assert analysis.cost_estimate == 0
        assert analysis.expected_value_gain == 0.0
        assert analysis.recommended is False
    
    def test_evaluate_card_insertion_no_empty_slots(self):
        """
        Cover valuation.py line 410-415: evaluate_card_insertion with full slots.
        Tests card insertion evaluation when no empty slots available.
        """
        # Arrange
        engine = ItemValuationEngine()
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=2,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=4002),
            ],
        )
        
        # Act
        result = engine.evaluate_card_insertion(equipment, card_id=4003, build="melee_dps")
        
        # Assert
        assert result["recommended"] is False
        assert result["reason"] == "No empty card slots"
    
    def test_evaluate_card_insertion_creates_new_card_slot(self):
        """
        Cover valuation.py line 428-433: evaluate_card_insertion adding new slot.
        Tests card insertion when needing to add a new CardSlot object.
        """
        # Arrange
        engine = ItemValuationEngine()
        equipment = Equipment(
            item_id=1201,
            name="Knife",
            slot=EquipSlot.WEAPON,
            slots=4,
            cards=[],  # No existing card slots
        )
        
        # Act
        result = engine.evaluate_card_insertion(equipment, card_id=4001, build="melee_dps")
        
        # Assert
        assert "score_improvement" in result
        assert "recommended" in result
    
    def test_prioritize_equipment_upgrades_max_recommendations(self):
        """
        Cover valuation.py line 495-497: prioritize_equipment_upgrades limiting results.
        Tests that recommendations are limited to max_recommendations.
        """
        # Arrange
        engine = ItemValuationEngine()
        current_equipment = {
            EquipSlot.WEAPON: Equipment(item_id=1101, name="Old Sword", slot=EquipSlot.WEAPON, atk=10)
        }
        available_items = [
            Equipment(item_id=1201, name="Knife", slot=EquipSlot.WEAPON, atk=15),
            Equipment(item_id=1202, name="Stiletto", slot=EquipSlot.WEAPON, atk=20),
            Equipment(item_id=1203, name="Gladius", slot=EquipSlot.WEAPON, atk=25),
            Equipment(item_id=1204, name="Damascus", slot=EquipSlot.WEAPON, atk=30),
        ]
        
        # Act
        recommendations = engine.prioritize_equipment_upgrades(
            current_equipment,
            available_items,
            build="melee_dps",
            max_recommendations=2,
        )
        
        # Assert
        assert len(recommendations) == 2  # Limited to 2
    
    def test_generate_upgrade_reason_no_reasons_found(self):
        """
        Cover valuation.py line 533-534: _generate_upgrade_reason fallback.
        Tests default reason when no specific improvements detected.
        """
        # Arrange
        engine = ItemValuationEngine()
        current = Equipment(item_id=1201, name="Knife", slot=EquipSlot.WEAPON, atk=15)
        candidate = Equipment(item_id=1202, name="Knife+", slot=EquipSlot.WEAPON, atk=15)
        
        # Act
        reason = engine._generate_upgrade_reason(current, candidate)
        
        # Assert
        assert reason == "Overall better stats"
    
    def test_calculate_slot_priority_tank_build_adjustments(self):
        """
        Cover valuation.py line 573-577: calculate_slot_priority for tank build.
        Tests priority adjustments for tank-specific slots.
        """
        # Arrange
        engine = ItemValuationEngine()
        
        # Act
        armor_priority = engine.calculate_slot_priority(EquipSlot.ARMOR, "tank")
        shield_priority = engine.calculate_slot_priority(EquipSlot.SHIELD, "tank")
        weapon_priority = engine.calculate_slot_priority(EquipSlot.WEAPON, "tank")
        
        # Assert - capped at 1.0 by min(priority, 1.0) on line 589
        assert armor_priority == 1.0  # Capped at max
        assert shield_priority > 0.9  # Boosted for tank
        assert weapon_priority == 0.8  # Reduced for tank (1.0 * 0.8)
    
    def test_calculate_slot_priority_caster_build_adjustments(self):
        """
        Cover valuation.py line 578-582: calculate_slot_priority for magic builds.
        Tests priority adjustments for magic DPS slots.
        """
        # Arrange
        engine = ItemValuationEngine()
        
        # Act
        weapon_priority = engine.calculate_slot_priority(EquipSlot.WEAPON, "magic_dps")
        shield_priority = engine.calculate_slot_priority(EquipSlot.SHIELD, "magic_dps")
        
        # Assert - capped at 1.0 by min(priority, 1.0) on line 589
        assert weapon_priority == 1.0  # Capped at max (1.0 * 1.2 = 1.2, capped to 1.0)
        assert shield_priority == 0.35  # Reduced for casters (0.7 * 0.5)
    
    def test_equipment_evaluator_calculate_score_with_dict(self):
        """
        Cover valuation.py line 633-640: EquipmentEvaluator.calculate_score with dict.
        Tests scoring system with dictionary input instead of Equipment object.
        """
        # Arrange
        evaluator = EquipmentEvaluator()
        equipment_dict = {
            "atk": 50,
            "matk": 10,
            "defense": 20,
            "refine": 7,
        }
        
        # Act
        score = evaluator.calculate_score(equipment_dict, "melee_dps")
        
        # Assert
        assert score > 0
        assert score == 50 * 1.0 + 10 * 1.0 + 20 * 0.5 + 7 * 5.0
    
    def test_equipment_evaluator_evaluate_upgrade_none_current(self):
        """
        Cover valuation.py line 656-657: EquipmentEvaluator.evaluate_upgrade with None.
        Tests upgrade evaluation for empty slot.
        """
        # Arrange
        evaluator = EquipmentEvaluator()
        candidate_dict = {"atk": 30, "matk": 5, "defense": 10, "refine": 0}
        
        # Act
        value = evaluator.evaluate_upgrade(None, candidate_dict)
        
        # Assert
        assert value > 0  # Candidate score returned


# ============================================================================
# CONSUMABLE COORDINATOR TESTS (10-12 tests)
# ============================================================================

class TestConsumableCoordinatorComplete:
    """Comprehensive tests for consumable coordinator edge cases."""
    
    @pytest.mark.asyncio
    async def test_update_all_emergency_recovery_path(self):
        """
        Cover coordinator.py line 171-174: _handle_emergency_recovery execution.
        Tests emergency recovery when HP critically low.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.15,  # Emergency threshold
            sp_percent=0.50,
            max_hp=1000,
            max_sp=500,
            inventory={501: 10},  # Red potions
        )
        
        # Mock recovery manager
        coordinator.recovery_manager.emergency_recovery = AsyncMock(return_value=None)
        
        # Act
        actions = await coordinator.update_all(game_state)
        
        # Assert
        # Assert - emergency_recovery is called multiple times during update
        assert coordinator.recovery_manager.emergency_recovery.called
    
    @pytest.mark.asyncio
    async def test_handle_critical_status_with_empty_active_effects(self):
        """
        Cover coordinator.py line 232: _handle_critical_status early return.
        Tests critical status handling when no active effects present.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.80,
            sp_percent=0.50,
            max_hp=1000,
            max_sp=500,
        )
        coordinator.status_manager.active_effects = {}
        
        # Act
        actions = await coordinator._handle_critical_status(game_state)
        
        # Assert
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_handle_urgent_recovery_threshold_check(self):
        """
        Cover coordinator.py line 284: _handle_urgent_recovery HP check.
        Tests urgent recovery only triggers below 40% HP.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.45,  # Above urgent threshold
            sp_percent=0.50,
            max_hp=1000,
            max_sp=500,
        )
        
        # Mock decision but HP too high
        mock_decision = Mock()
        coordinator.recovery_manager.evaluate_recovery_need = AsyncMock(
            return_value=mock_decision
        )
        
        # Act
        action = await coordinator._handle_urgent_recovery(game_state)
        
        # Assert
        assert action is None  # HP not low enough for urgent
    
    @pytest.mark.asyncio
    async def test_handle_status_cure_prioritization(self):
        """
        Cover coordinator.py line 312: _handle_status_cure prioritization logic.
        Tests priority-based status cure selection.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.80,
            sp_percent=0.50,
            max_hp=1000,
            max_sp=500,
        )
        
        # Mock multiple non-critical effects
        from ai_sidecar.consumables.status_effects import StatusSeverity
        mock_effects = [
            Mock(severity=StatusSeverity.HIGH, effect_type=Mock(value="Poison")),
            Mock(severity=StatusSeverity.MEDIUM, effect_type=Mock(value="Curse")),
        ]
        coordinator.status_manager.active_effects = {
            "poison": mock_effects[0],
            "curse": mock_effects[1],
        }
        coordinator.status_manager.prioritize_cures = AsyncMock(return_value=mock_effects)
        coordinator.status_manager.get_cure_action = AsyncMock(return_value=None)
        
        # Act
        actions = await coordinator._handle_status_cure(game_state)
        
        # Assert
        coordinator.status_manager.prioritize_cures.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_rebuffing_limit_to_top_3(self):
        """
        Cover coordinator.py line 370: _handle_rebuffing limiting to top 3 buffs.
        Tests that only top 3 priority buffs are rebuffed per tick.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.80,
            sp_percent=0.80,
            max_hp=1000,
            max_sp=500,
        )
        
        # Mock 5 buffs needing rebuff
        mock_buffs = [Mock(priority=i, buff_name=f"Buff{i}") for i in range(5)]
        coordinator.buff_manager.check_rebuff_needs = AsyncMock(return_value=mock_buffs)
        coordinator.buff_manager.get_rebuff_action = AsyncMock(return_value=None)
        
        # Act
        actions = await coordinator._handle_rebuffing(game_state)
        
        # Assert
        assert coordinator.buff_manager.get_rebuff_action.call_count <= 3
    
    @pytest.mark.asyncio
    async def test_handle_food_maintenance_limit_to_top_2(self):
        """
        Cover coordinator.py line 398: _handle_food_maintenance limiting to top 2.
        Tests that only top 2 food actions are queued per tick.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        game_state = ConsumableContext(
            hp_percent=0.80,
            sp_percent=0.80,
            max_hp=1000,
            max_sp=500,
        )
        
        # Mock 4 food needs
        from ai_sidecar.consumables.food import FoodAction
        mock_food = [
            FoodAction(item_id=i, item_name=f"Food{i}", reason="Buff")
            for i in range(4)
        ]
        coordinator.food_manager.check_food_needs = AsyncMock(return_value=mock_food)
        
        # Act
        actions = await coordinator._handle_food_maintenance(game_state)
        
        # Assert
        assert len(actions) <= 2
    
    @pytest.mark.asyncio
    async def test_prioritize_actions_limits_to_top_3(self):
        """
        Cover coordinator.py line 440-441: prioritize_actions limiting to 3.
        Tests action prioritization caps at 3 actions per tick.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        # Use valid ActionPriority values: EMERGENCY=10, CRITICAL=9, URGENT=8, HIGH=7, NORMAL=5, LOW=3, OPTIONAL=1
        priorities = [ActionPriority.EMERGENCY, ActionPriority.CRITICAL, ActionPriority.URGENT, 
                     ActionPriority.HIGH, ActionPriority.NORMAL, ActionPriority.NORMAL,
                     ActionPriority.LOW, ActionPriority.LOW, ActionPriority.OPTIONAL, ActionPriority.OPTIONAL]
        actions = [
            ConsumableAction(
                action_type="recovery",
                priority=priorities[i],
                item_name=f"Item{i}",
                reason="Test",
            )
            for i in range(10)
        ]
        
        # Act
        prioritized = await coordinator.prioritize_actions(actions)
        
        # Assert
        assert len(prioritized) == 3
        assert all(prioritized[i].priority >= prioritized[i + 1].priority for i in range(2))
    
    @pytest.mark.asyncio
    async def test_pre_combat_preparation_immunity_recommendations(self):
        """
        Cover coordinator.py line 486-499: pre_combat_preparation immunity logic.
        Tests immunity recommendation for expected enemy status effects.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        enemy_info = {
            "map": "gef_dun02",
            "monsters": ["Nightmare", "Ghoul"],
        }
        
        # Mock immunity recommendations
        mock_rec = Mock(item_name="Green Potion", reason="Immunity to Curse")
        coordinator.status_manager.should_apply_immunity = AsyncMock(
            return_value=[mock_rec]
        )
        coordinator.food_manager.get_optimal_food_set = AsyncMock(return_value=[])
        coordinator.food_manager.get_missing_food = Mock(return_value=[])
        
        # Act
        actions = await coordinator.pre_combat_preparation(enemy_info, "melee_dps")
        
        # Assert
        assert any(action.action_type == "immunity" for action in actions)
    
    @pytest.mark.asyncio
    async def test_post_combat_recovery_low_hp_sp(self):
        """
        Cover coordinator.py line 526-543: post_combat_recovery recovery path.
        Tests post-combat recovery when HP/SP are low.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        
        # Mock recovery decision
        mock_decision = Mock(item=Mock(item_id=501, item_name="Red Potion"), reason="Low HP")
        coordinator.recovery_manager.evaluate_recovery_need = AsyncMock(
            return_value=mock_decision
        )
        coordinator.buff_manager.check_rebuff_needs = AsyncMock(return_value=[])
        
        # Act
        actions = await coordinator.post_combat_recovery(hp_percent=0.60, sp_percent=0.30)
        
        # Assert
        assert len(actions) > 0
        assert actions[0].action_type == "recovery"
    
    @pytest.mark.asyncio
    async def test_post_combat_recovery_rebuff_limit(self):
        """
        Cover coordinator.py line 551: post_combat_recovery rebuff iteration.
        Tests rebuffing up to 3 buffs post-combat.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        coordinator.recovery_manager.evaluate_recovery_need = AsyncMock(return_value=None)
        
        # Mock 5 buffs
        mock_buffs = [Mock(buff_name=f"Buff{i}") for i in range(5)]
        coordinator.buff_manager.check_rebuff_needs = AsyncMock(return_value=mock_buffs)
        coordinator.buff_manager.get_rebuff_action = AsyncMock(
            return_value=Mock(item_name="Potion", skill_name="Blessing")
        )
        
        # Act
        actions = await coordinator.post_combat_recovery(hp_percent=0.90, sp_percent=0.90)
        
        # Assert
        assert len(actions) <= 3
    
    def test_get_system_summary_with_timestamps(self):
        """
        Cover coordinator.py line 578-581: get_system_summary timestamp formatting.
        Tests summary generation with last_update and last_emergency timestamps.
        """
        # Arrange
        coordinator = ConsumableCoordinator()
        coordinator.last_update = datetime(2024, 1, 1, 12, 0, 0)
        coordinator.last_emergency = datetime(2024, 1, 1, 11, 50, 0)
        
        # Mock subsystem summaries
        coordinator.buff_manager.get_active_buffs_summary = Mock(return_value={})
        coordinator.status_manager.get_status_summary = Mock(return_value={})
        coordinator.food_manager.get_food_summary = Mock(return_value={})
        
        # Act
        summary = coordinator.get_system_summary()
        
        # Assert
        assert "last_update" in summary
        assert "last_emergency" in summary
        assert summary["last_update"] is not None


# ============================================================================
# STORAGE MANAGER TESTS (12-15 tests)
# ============================================================================

class TestStorageManagerComplete:
    """Comprehensive tests for storage manager edge cases."""
    
    @pytest.mark.asyncio
    async def test_tick_inventory_full_weight_threshold(self):
        """
        Cover storage.py line 162-163: _inventory_full weight threshold check.
        Tests storage triggering when weight limit exceeded.
        """
        # Arrange
        config = StorageManagerConfig(weight_limit_threshold=0.70)
        manager = StorageManager(config=config)
        
        # Mock game state with high weight
        game_state = Mock()
        game_state.character = Mock(weight_percent=75)  # 75% weight
        game_state.inventory = Mock(items=[], get_item_count=Mock(return_value=100))
        
        # Act
        actions = await manager.tick(game_state)
        
        # Assert
        # Should trigger storage check
        assert manager._inventory_full(game_state) is True
    
    @pytest.mark.asyncio
    async def test_tick_inventory_full_item_count_threshold(self):
        """
        Cover storage.py line 166-169: _inventory_full item count threshold check.
        Tests storage triggering when item slots nearly full.
        """
        # Arrange
        config = StorageManagerConfig(inventory_full_threshold=0.80)
        manager = StorageManager(config=config)
        
        # Mock game state with many items
        game_state = Mock()
        game_state.character = Mock(weight_percent=50)
        mock_items = [Mock() for _ in range(85)]  # 85/100 slots = 85%
        game_state.inventory = Mock(items=mock_items)
        
        # Act
        is_full = manager._inventory_full(game_state)
        
        # Assert
        assert is_full is True
    
    @pytest.mark.asyncio
    async def test_prioritize_storage_weight_max_type_conversion(self):
        """
        Cover storage.py line 206-210: _prioritize_storage weight_max type handling.
        Tests safe type conversion of weight_max for mock objects.
        """
        # Arrange
        manager = StorageManager()
        
        # Mock game state with Mock weight_max (not a number)
        game_state = Mock()
        game_state.character = Mock(weight=15000, weight_max=Mock())  # Mock object
        game_state.inventory = Mock(items=[])
        
        # Act
        actions = await manager._prioritize_storage(game_state)
        
        # Assert
        # Should not raise exception, uses fallback
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_prioritize_storage_skip_always_keep_items(self):
        """
        Cover storage.py line 219-220: _prioritize_storage skipping always-keep items.
        Tests that configured always-keep items are never stored.
        """
        # Arrange
        config = StorageManagerConfig(always_keep_items=[501, 502])
        manager = StorageManager(config=config)
        
        # Mock game state
        game_state = Mock()
        game_state.character = Mock(weight=15000, weight_max=10000)
        
        keep_item = CoreInventoryItem(index=0, item_id=501, name="Red Potion", amount=10, item_type="consumable", equipped=False)
        store_item = CoreInventoryItem(index=1, item_id=601, name="Fly Wing", amount=50, item_type="etc", equipped=False)
        game_state.inventory = Mock(items=[keep_item, store_item])
        
        # Act
        actions = await manager._prioritize_storage(game_state)
        
        # Assert
        # Only store_item should be in actions
        stored_ids = [action.item_id for action in actions]
        assert 501 not in stored_ids
        assert 601 in stored_ids
    
    @pytest.mark.asyncio
    async def test_prioritize_storage_skip_equipped_items(self):
        """
        Cover storage.py line 223-224: _prioritize_storage skipping equipped items.
        Tests that equipped items are never considered for storage.
        """
        # Arrange
        manager = StorageManager()
        
        # Mock game state
        game_state = Mock()
        game_state.character = Mock(weight=15000, weight_max=10000)
        
        equipped_item = CoreInventoryItem(index=0, item_id=1201, name="Knife", amount=1, item_type="equipment", equipped=True)
        unequipped_item = CoreInventoryItem(index=1, item_id=601, name="Fly Wing", amount=50, item_type="etc", equipped=False)
        game_state.inventory = Mock(items=[equipped_item, unequipped_item])
        
        # Act
        actions = await manager._prioritize_storage(game_state)
        
        # Assert
        stored_ids = [action.item_id for action in actions]
        assert 1201 not in stored_ids  # Equipped not stored
    
    @pytest.mark.asyncio
    async def test_retrieve_needed_consumable_threshold(self):
        """
        Cover storage.py line 273-287: _retrieve_needed consumable check.
        Tests automatic retrieval when consumable stock is low.
        """
        # Arrange
        config = StorageManagerConfig(auto_retrieve=True)
        manager = StorageManager(config=config)
        
        # Mock game state with low potion count
        game_state = Mock()
        game_state.inventory = Mock()
        game_state.inventory.get_item_count = Mock(return_value=30)  # Below 50 threshold
        
        # Act
        actions = await manager._retrieve_needed(game_state)
        
        # Assert
        assert len(actions) > 0
        assert actions[0].extra["action"] == "retrieve_item"
    
    @pytest.mark.asyncio
    async def test_retrieve_needed_sufficient_stock(self):
        """
        Cover storage.py line 273: _retrieve_needed when stock sufficient.
        Tests no retrieval when consumable stock is adequate.
        """
        # Arrange
        config = StorageManagerConfig(auto_retrieve=True)
        manager = StorageManager(config=config)
        
        # Mock game state with good potion count
        game_state = Mock()
        game_state.inventory = Mock()
        game_state.inventory.get_item_count = Mock(return_value=100)  # Above 50 threshold
        
        # Act
        actions = await manager._retrieve_needed(game_state)
        
        # Assert
        # Should still check but not retrieve (already have enough)
        # For items 501, 502, 503 - all have 100 > 50
        assert all(action.extra.get("quantity", 0) == 0 for action in actions) or len(actions) == 0
    
    def test_calculate_inventory_priority_always_keep_items(self):
        """
        Cover storage.py line 327-328: calculate_inventory_priority always-keep check.
        Tests highest priority for always-keep items.
        """
        # Arrange
        config = StorageManagerConfig(always_keep_items=[501])
        manager = StorageManager(config=config)
        
        item = CoreInventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=10,
            item_type="consumable",
            equipped=False,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 100.0
    
    def test_calculate_inventory_priority_always_store_items(self):
        """
        Cover storage.py line 330-332: calculate_inventory_priority always-store check.
        Tests lowest priority for always-store items.
        """
        # Arrange
        config = StorageManagerConfig(always_store_items=[601])
        manager = StorageManager(config=config)
        
        item = CoreInventoryItem(
            index=0,
            item_id=601,
            name="Fly Wing",
            amount=50,
            item_type="etc",
            equipped=False,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 0.0
    
    def test_calculate_inventory_priority_equipped_items(self):
        """
        Cover storage.py line 334-336: calculate_inventory_priority equipped check.
        Tests highest priority for equipped items.
        """
        # Arrange
        manager = StorageManager()
        
        item = CoreInventoryItem(
            index=0,
            item_id=1201,
            name="Knife",
            amount=1,
            item_type="equipment",
            equipped=True,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 100.0
    
    def test_calculate_inventory_priority_card_type(self):
        """
        Cover storage.py line 343-344: calculate_inventory_priority card bonus.
        Tests medium-high priority for card items.
        """
        # Arrange
        manager = StorageManager()
        
        item = CoreInventoryItem(
            index=0,
            item_id=4001,
            name="Poring Card",
            amount=1,
            item_type="card",
            equipped=False,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 70.0  # 50 base + 20 card bonus
    
    def test_calculate_inventory_priority_equipment_type(self):
        """
        Cover storage.py line 347-348: calculate_inventory_priority equipment penalty.
        Tests lower priority for unequipped equipment.
        """
        # Arrange
        manager = StorageManager()
        
        item = CoreInventoryItem(
            index=0,
            item_id=2301,
            name="Cotton Shirt",
            amount=1,
            item_type="equipment",
            equipped=False,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 40.0  # 50 base - 10 unequipped equipment
    
    def test_calculate_inventory_priority_etc_type(self):
        """
        Cover storage.py line 351-352: calculate_inventory_priority etc penalty.
        Tests lowest priority for misc items.
        """
        # Arrange
        manager = StorageManager()
        
        item = CoreInventoryItem(
            index=0,
            item_id=909,
            name="Jellopy",
            amount=100,
            item_type="etc",
            equipped=False,
        )
        
        # Act
        priority = manager.calculate_inventory_priority(item)
        
        # Assert
        assert priority == 30.0  # 50 base - 20 etc
    
    def test_get_storage_recommendations_low_priority_items(self):
        """
        Cover storage.py line 398-400: get_storage_recommendations filtering.
        Tests recommendation filtering by priority threshold.
        """
        # Arrange
        manager = StorageManager()
        
        # Mock game state with mixed priority items
        game_state = Mock()
        high_priority = CoreInventoryItem(
            index=0,
            item_id=501, name="Red Potion", amount=10, item_type="consumable", equipped=False
        )
        low_priority = CoreInventoryItem(
            index=1,
            item_id=909, name="Jellopy", amount=100, item_type="etc", equipped=False
        )
        game_state.inventory = Mock(items=[high_priority, low_priority])
        
        # Act
        recommendations = manager.get_storage_recommendations(game_state)
        
        # Assert
        assert "store" in recommendations
        assert "retrieve" in recommendations
        # Jellopy has priority 30.0 (50 - 20 for etc), exactly at threshold
        # Threshold is < 30.0, so Jellopy should NOT be stored (boundary test)
        stored_names = [item.name for item in recommendations["store"]]
        # Red Potion has priority 50.0, also not < 30.0
        assert len(stored_names) == 0  # Neither item meets < 30.0 threshold


# ============================================================================
# BUYING MANAGER TESTS (15-20 tests)
# ============================================================================

class TestBuyingManagerComplete:
    """Comprehensive tests for buying manager edge cases."""
    
    def test_calculate_buy_price_no_price_data(self, tmp_path):
        """
        Cover buying.py line 123-125: calculate_buy_price with no price data.
        Tests fallback when fair price is zero (no data).
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Mock analyzer to return 0
        analyzer.calculate_fair_price = Mock(return_value=0)
        
        # Act
        max_price = manager.calculate_buy_price(item_id=9999, urgency=0.5)
        
        # Assert
        assert max_price == 0
    
    def test_calculate_buy_price_high_urgency(self, tmp_path):
        """
        Cover buying.py line 128-130: calculate_buy_price with high urgency.
        Tests price multiplier increase for urgent purchases.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        analyzer.calculate_fair_price = Mock(return_value=10000)
        
        # Act
        max_price = manager.calculate_buy_price(item_id=501, urgency=0.9)
        
        # Assert
        # Multiplier = 1.0 + (0.9 - 0.7) * 0.5 = 1.1
        expected = int(10000 * 1.1)
        assert max_price == expected
    
    def test_calculate_buy_price_low_urgency(self, tmp_path):
        """
        Cover buying.py line 131-133: calculate_buy_price with low urgency.
        Tests price multiplier decrease for patient purchases.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        analyzer.calculate_fair_price = Mock(return_value=10000)
        
        # Act
        max_price = manager.calculate_buy_price(item_id=501, urgency=0.1)
        
        # Assert
        # Multiplier = 0.80 - (0.3 - 0.1) * 0.2 = 0.76
        expected = int(10000 * 0.76)
        assert max_price == expected
    
    def test_evaluate_listing_not_on_purchase_list(self, tmp_path):
        """
        Cover buying.py line 168-169: evaluate_listing item not wanted.
        Tests rejection when item not on purchase list.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            quantity=10,
            price=500,
            seller_name="Merchant",
            source=MarketSource.VENDING,
        )
        
        # Act
        should_buy, reason = manager.evaluate_listing(listing)
        
        # Assert
        assert should_buy is False
        assert reason == "not_on_purchase_list"
    
    def test_evaluate_listing_already_have_enough(self, tmp_path):
        """
        Cover buying.py line 172-173: evaluate_listing sufficient quantity.
        Tests rejection when already have enough of item.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=150,  # Already have more than needed
        )
        manager.add_purchase_target(target)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            quantity=10,
            price=500,
            seller_name="Merchant",
            source=MarketSource.VENDING,
        )
        
        # Act
        should_buy, reason = manager.evaluate_listing(listing)
        
        # Assert
        assert should_buy is False
        assert reason == "already_have_enough"
    
    def test_evaluate_listing_price_too_high(self, tmp_path):
        """
        Cover buying.py line 176-177: evaluate_listing price rejection.
        Tests rejection when listing price exceeds max price.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=500,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
        )
        manager.add_purchase_target(target)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            quantity=10,
            price=1000,  # Too expensive
            seller_name="Merchant",
            source=MarketSource.VENDING,
        )
        
        # Act
        should_buy, reason = manager.evaluate_listing(listing)
        
        # Assert
        assert should_buy is False
        assert reason == "price_too_high"
    
    def test_evaluate_listing_suspicious_price(self, tmp_path):
        """
        Cover buying.py line 185-187: evaluate_listing scam detection.
        Tests rejection when price is suspiciously low (potential scam).
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
        )
        manager.add_purchase_target(target)
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            quantity=10,
            price=10,  # Suspiciously cheap
            seller_name="Merchant",
            source=MarketSource.VENDING,
        )
        
        # Mock anomaly detection
        analyzer.detect_price_anomaly = Mock(return_value=(True, "price_too_low"))
        
        # Act
        should_buy, reason = manager.evaluate_listing(listing)
        
        # Assert
        assert should_buy is False
        assert reason == "suspicious_price"
    
    def test_get_purchase_recommendations_budget_exhausted(self, tmp_path):
        """
        Cover buying.py line 218-219: get_purchase_recommendations budget check.
        Tests recommendation generation stops when budget exhausted.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Add multiple targets
        for i in range(5):
            target = PurchaseTarget(
                item_id=500 + i,
                item_name=f"Item{i}",
                max_price=10000,
                priority=PurchasePriority.NORMAL,
                quantity_needed=10,
                quantity_owned=0,
            )
            manager.add_purchase_target(target)
        
        # Act with small budget
        recommendations = manager.get_purchase_recommendations(budget=5000)
        
        # Assert
        # Should stop when budget runs out
        total_cost = sum(rec["total_cost"] for rec in recommendations)
        assert total_cost <= 5000
    
    def test_get_purchase_recommendations_no_sellers(self, tmp_path):
        """
        Cover buying.py line 227-228: get_purchase_recommendations no sellers.
        Tests skipping items when no sellers found.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
        )
        manager.add_purchase_target(target)
        
        # Mock find_best_sellers to return empty
        manager.find_best_sellers = Mock(return_value=[])
        
        # Act
        recommendations = manager.get_purchase_recommendations(budget=100000)
        
        # Assert
        assert len(recommendations) == 0
    
    def test_bulk_buy_strategy_no_sellers(self, tmp_path):
        """
        Cover buying.py line 314-318: bulk_buy_strategy no sellers available.
        Tests bulk buy strategy when no sellers exist.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Act
        strategy = manager.bulk_buy_strategy(
            item_id=9999,  # No sellers
            quantity=100,
            max_total=100000,
        )
        
        # Assert
        assert strategy["feasible"] is False
        assert strategy["reason"] == "no_sellers"
        assert len(strategy["plan"]) == 0
    
    def test_bulk_buy_strategy_insufficient_budget(self, tmp_path):
        """
        Cover buying.py line 340-355: bulk_buy_strategy budget limitation.
        Tests bulk buying stops when budget exhausted mid-purchase.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Add listings
        market.listings[501] = [
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                quantity=50,
                price=500,
                seller_name="Seller1",
                source=MarketSource.VENDING,
            ),
            MarketListing(
                item_id=501,
                item_name="Red Potion",
                quantity=50,
                price=600,
                seller_name="Seller2",
                source=MarketSource.VENDING,
            ),
        ]
        
        # Act - not enough budget for full quantity
        strategy = manager.bulk_buy_strategy(
            item_id=501,
            quantity=100,
            max_total=30000,  # Can only afford 50-60 items
        )
        
        # Assert
        assert strategy["total_cost"] <= 30000
        assert strategy["total_quantity"] < 100
    
    def test_should_wait_falling_trend(self, tmp_path):
        """
        Cover buying.py line 401-402: should_wait with falling price trend.
        Tests recommendation to wait when prices are falling.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Mock trend
        market.get_trend = Mock(return_value=PriceTrend.FALLING)
        
        # Act
        should_wait, reason = manager.should_wait(
            item_id=501,
            current_price=1000,
            days_to_wait=3,
        )
        
        # Assert
        assert should_wait is True
        assert reason == "price_falling_trend"
    
    def test_should_wait_predicted_price_drop(self, tmp_path):
        """
        Cover buying.py line 410-411: should_wait with price drop prediction.
        Tests recommendation to wait based on price prediction.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Mock stable trend but predicted drop
        market.get_trend = Mock(return_value=PriceTrend.STABLE)
        analyzer.predict_price = Mock(return_value=(900, 0.7))  # Predicted drop, high confidence
        
        # Act
        should_wait, reason = manager.should_wait(
            item_id=501,
            current_price=1000,
            days_to_wait=3,
        )
        
        # Assert
        assert should_wait is True
        assert reason == "predicted_price_drop"
    
    def test_should_wait_price_above_market(self, tmp_path):
        """
        Cover buying.py line 416-417: should_wait when price above market.
        Tests recommendation to wait when current price above fair market value.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Mock stable trend, no predicted drop, but above market
        market.get_trend = Mock(return_value=PriceTrend.STABLE)
        analyzer.predict_price = Mock(return_value=(1000, 0.5))  # Low confidence
        analyzer.compare_to_market = Mock(
            return_value={"recommendation": "above_market"}
        )
        
        # Act
        should_wait, reason = manager.should_wait(
            item_id=501,
            current_price=1000,
            days_to_wait=3,
        )
        
        # Assert
        assert should_wait is True
        assert reason == "price_above_market"
    
    def test_should_wait_buy_now(self, tmp_path):
        """
        Cover buying.py line 420: should_wait buy now recommendation.
        Tests recommendation to buy immediately when conditions favorable.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        # Mock favorable conditions
        market.get_trend = Mock(return_value=PriceTrend.STABLE)
        analyzer.predict_price = Mock(return_value=(1000, 0.5))
        analyzer.compare_to_market = Mock(
            return_value={"recommendation": "fair"}
        )
        
        # Act
        should_wait, reason = manager.should_wait(
            item_id=501,
            current_price=1000,
            days_to_wait=3,
        )
        
        # Assert
        assert should_wait is False
        assert reason == "buy_now"
    
    def test_priority_score_deadline_approaching_1_day(self, tmp_path):
        """
        Cover buying.py line 447-448: _priority_score with deadline < 1 day.
        Tests priority boost when deadline very close.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
            deadline=datetime.utcnow() + timedelta(hours=12),  # 0.5 days
        )
        
        # Act
        score = manager._priority_score(target)
        
        # Assert
        base_score = 50.0
        expected = base_score * 2.0  # 2x multiplier for < 1 day
        assert score == expected
    
    def test_priority_score_deadline_approaching_3_days(self, tmp_path):
        """
        Cover buying.py line 449-450: _priority_score with deadline < 3 days.
        Tests priority boost when deadline approaching.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
            deadline=datetime.utcnow() + timedelta(days=2),  # 2 days
        )
        
        # Act
        score = manager._priority_score(target)
        
        # Assert
        base_score = 50.0
        expected = base_score * 1.5  # 1.5x multiplier for < 3 days
        assert score == expected
    
    def test_priority_score_deadline_approaching_7_days(self, tmp_path):
        """
        Cover buying.py line 451-452: _priority_score with deadline < 7 days.
        Tests priority boost when deadline within a week.
        """
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = PriceAnalyzer(market)
        manager = BuyingManager(market, analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=1000,
            priority=PurchasePriority.NORMAL,
            quantity_needed=100,
            quantity_owned=0,
            deadline=datetime.utcnow() + timedelta(days=5),  # 5 days
        )
        
        # Act
        score = manager._priority_score(target)
        
        # Assert
        base_score = 50.0
        expected = base_score * 1.2  # 1.2x multiplier for < 7 days
        assert score == expected