"""
Comprehensive tests for equipment/valuation.py module
Target: Boost coverage from 43.14% to 90%+
"""

import json
import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.equipment.valuation import (
    ItemValuationEngine,
    BuildWeights,
    RefineAnalysis,
    DEFAULT_BUILD_WEIGHTS,
)
from ai_sidecar.equipment.models import (
    Equipment,
    EquipSlot,
    MarketPrice,
    CardSlot,
    WeaponType,
)


class TestBuildWeights:
    """Test BuildWeights model"""
    
    def test_build_weights_creation(self):
        """Test creating BuildWeights with custom values"""
        weights = BuildWeights(
            atk=1.5,
            matk=0.5,
            str_bonus=1.2,
            refine_weight=1.3
        )
        
        assert weights.atk == 1.5
        assert weights.matk == 0.5
        assert weights.str_bonus == 1.2
        assert weights.refine_weight == 1.3
    
    def test_build_weights_frozen(self):
        """Test that BuildWeights is immutable"""
        weights = BuildWeights(atk=1.0)
        
        with pytest.raises(Exception):  # Pydantic validation error
            weights.atk = 2.0


class TestRefineAnalysis:
    """Test RefineAnalysis model"""
    
    def test_refine_analysis_creation(self):
        """Test creating RefineAnalysis"""
        analysis = RefineAnalysis(
            current_refine=4,
            target_refine=7,
            success_rate=0.75,
            cost_estimate=50000,
            expected_value_gain=100.5,
            risk_score=0.25,
            recommended=True
        )
        
        assert analysis.current_refine == 4
        assert analysis.target_refine == 7
        assert analysis.recommended is True


class TestItemValuationEngineInit:
    """Test ItemValuationEngine initialization"""
    
    def test_init_default(self):
        """Test initialization with defaults"""
        engine = ItemValuationEngine()
        
        assert engine.market_prices == {}
        assert engine.build_weights == DEFAULT_BUILD_WEIGHTS
    
    def test_init_custom_market_prices(self):
        """Test initialization with custom market prices"""
        prices = {
            1001: MarketPrice(item_id=1001, avg_price=1000)
        }
        
        engine = ItemValuationEngine(market_prices=prices)
        
        assert 1001 in engine.market_prices
        assert engine.market_prices[1001].avg_price == 1000
    
    def test_init_custom_build_weights(self):
        """Test initialization with custom build weights"""
        custom_weights = {
            "custom_build": BuildWeights(atk=2.0, defense=0.5)
        }
        
        engine = ItemValuationEngine(build_weights=custom_weights)
        
        assert "custom_build" in engine.build_weights


class TestLoadMarketPrices:
    """Test market price loading"""
    
    def test_load_market_prices_success(self):
        """Test successfully loading market prices from file"""
        engine = ItemValuationEngine()
        
        # Create temp file with market data
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            data = {
                "1001": {
                    "item_id": 1001,
                    "min_price": 800,
                    "avg_price": 1000,
                    "max_price": 1200,
                    "npc_sell_price": 500,
                    "npc_buy_price": 100,
                    "sample_count": 50,
                    "last_updated": 1234567890,
                    "volatility": 0.2
                }
            }
            json.dump(data, f)
            temp_path = f.name
        
        try:
            engine.load_market_prices(temp_path)
            
            assert 1001 in engine.market_prices
            assert engine.market_prices[1001].avg_price == 1000
        finally:
            Path(temp_path).unlink()
    
    def test_load_market_prices_file_not_found(self):
        """Test loading from non-existent file"""
        engine = ItemValuationEngine()
        
        # Should not raise exception, just log warning
        engine.load_market_prices("/nonexistent/path/prices.json")
        
        assert len(engine.market_prices) == 0
    
    def test_load_market_prices_invalid_json(self):
        """Test loading from invalid JSON file"""
        engine = ItemValuationEngine()
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            f.write("{ invalid json }")
            temp_path = f.name
        
        try:
            engine.load_market_prices(temp_path)
            
            # Should handle error gracefully
            assert len(engine.market_prices) == 0
        finally:
            Path(temp_path).unlink()


class TestCalculateEquipmentScore:
    """Test equipment scoring"""
    
    def test_score_basic_weapon(self):
        """Test scoring a basic weapon"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            str_bonus=5,
            refine=0,
            slots=0
        )
        
        engine = ItemValuationEngine()
        score = engine.calculate_equipment_score(weapon, build="melee_dps")
        
        # melee_dps weights: atk=1.5, str_bonus=1.2
        # score = 100*1.5 + 5*1.2 = 150 + 6 = 156
        assert score > 0
    
    def test_score_refined_weapon(self):
        """Test that refine level increases score"""
        weapon_low = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        weapon_high = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=10,
            slots=0
        )
        
        engine = ItemValuationEngine()
        score_low = engine.calculate_equipment_score(weapon_low, "melee_dps")
        score_high = engine.calculate_equipment_score(weapon_high, "melee_dps")
        
        assert score_high > score_low
    
    def test_score_with_empty_slots(self):
        """Test that empty card slots add value"""
        weapon_no_slots = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            slots=0,
            cards=[],
            refine=0
        )
        
        weapon_with_slots = Equipment(
            item_id=1102,
            name="Slotted Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            slots=2,
            cards=[],
            refine=0
        )
        
        engine = ItemValuationEngine()
        score_no_slots = engine.calculate_equipment_score(weapon_no_slots, "hybrid")
        score_with_slots = engine.calculate_equipment_score(weapon_with_slots, "hybrid")
        
        # Empty slots add value
        assert score_with_slots > score_no_slots
    
    def test_score_with_special_effects(self):
        """Test that special effects add value"""
        weapon_basic = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            effects=[],
            slots=0,
            refine=0
        )
        
        weapon_special = Equipment(
            item_id=1102,
            name="Elemental Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            effects=["Fire damage +20%", "Fire resistance +10%"],
            slots=0,
            refine=0
        )
        
        engine = ItemValuationEngine()
        score_basic = engine.calculate_equipment_score(weapon_basic, "hybrid")
        score_special = engine.calculate_equipment_score(weapon_special, "hybrid")
        
        # Special effects add 10.0 per effect
        assert score_special > score_basic
    
    def test_score_different_builds(self):
        """Test that build affects scoring"""
        armor = Equipment(
            item_id=2301,
            name="Heavy Armor",
            slot=EquipSlot.ARMOR,
            defense=100,
            vit_bonus=10,
            slots=0,
            refine=0
        )
        
        engine = ItemValuationEngine()
        tank_score = engine.calculate_equipment_score(armor, "tank")
        mage_score = engine.calculate_equipment_score(armor, "magic_dps")
        
        # Tank build values defense more
        assert tank_score > mage_score


class TestEstimateMarketValue:
    """Test market value estimation"""
    
    def test_estimate_with_market_data(self):
        """Test estimation using market price data"""
        prices = {
            1101: MarketPrice(
                item_id=1101,
                min_price=8000,
                avg_price=10000,
                max_price=12000
            )
        }
        
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            cards=[],
            enchants=[],
            slots=0
        )
        
        engine = ItemValuationEngine(market_prices=prices)
        min_val, avg_val, max_val = engine.estimate_market_value(weapon)
        
        assert min_val == 8000
        assert avg_val == 10000
        assert max_val == 12000
    
    def test_estimate_without_market_data(self):
        """Test estimation fallback when no market data"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            cards=[],
            enchants=[],
            slots=0
        )
        
        engine = ItemValuationEngine()
        min_val, avg_val, max_val = engine.estimate_market_value(weapon)
        
        # Fallback: base_avg = item_id * 100 = 110100
        assert avg_val == 110100
        assert min_val == int(110100 * 0.7)
        assert max_val == int(110100 * 1.5)
    
    def test_estimate_refined_item_multiplier(self):
        """Test that refine level increases value"""
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000)
        }
        
        weapon_base = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            cards=[],
            enchants=[],
            slots=0
        )
        
        weapon_refined = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=10,
            cards=[],
            enchants=[],
            slots=0
        )
        
        engine = ItemValuationEngine(market_prices=prices)
        _, avg_base, _ = engine.estimate_market_value(weapon_base)
        _, avg_refined, _ = engine.estimate_market_value(weapon_refined)
        
        # Refine multiplier = 1.0 + (10 * 0.2) + (10^2 * 0.05) = 1 + 2 + 5 = 8.0
        assert avg_refined > avg_base
    
    def test_estimate_with_cards(self):
        """Test value calculation includes card prices"""
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000),
            4001: MarketPrice(item_id=4001, avg_price=50000)  # Card price
        }
        
        weapon = Equipment(
            item_id=1101,
            name="Carded Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            cards=[CardSlot(slot_index=0, card_id=4001, card_name="Poring Card")],
            enchants=[],
            slots=1
        )
        
        engine = ItemValuationEngine(market_prices=prices)
        _, avg_val, _ = engine.estimate_market_value(weapon)
        
        # Should include card value
        assert avg_val > 10000
    
    def test_estimate_with_enchants(self):
        """Test value calculation includes enchant value"""
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000)
        }
        
        weapon = Equipment(
            item_id=1101,
            name="Enchanted Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            cards=[],
            enchants=[1, 2],  # 2 enchants
            slots=0
        )
        
        engine = ItemValuationEngine(market_prices=prices)
        _, avg_val, _ = engine.estimate_market_value(weapon)
        
        # Each enchant adds 100000
        assert avg_val == 10000 + (2 * 100000)


class TestCompareEquipment:
    """Test equipment comparison"""
    
    def test_compare_vs_empty_slot(self):
        """Test comparing new equipment vs empty slot"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        engine = ItemValuationEngine()
        improvement = engine.compare_equipment(None, weapon, "melee_dps")
        
        # Any equipment is better than empty
        assert improvement > 0
    
    def test_compare_upgrade(self):
        """Test comparing upgrade equipment"""
        current = Equipment(
            item_id=1101,
            name="Basic Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        upgrade = Equipment(
            item_id=1102,
            name="Better Sword",
            slot=EquipSlot.WEAPON,
            atk=150,
            refine=0,
            slots=0
        )
        
        engine = ItemValuationEngine()
        improvement = engine.compare_equipment(current, upgrade, "melee_dps")
        
        # Upgrade has more ATK
        assert improvement > 0
    
    def test_compare_downgrade(self):
        """Test comparing downgrade equipment"""
        current = Equipment(
            item_id=1102,
            name="Good Sword",
            slot=EquipSlot.WEAPON,
            atk=150,
            refine=10,
            slots=0
        )
        
        downgrade = Equipment(
            item_id=1101,
            name="Basic Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        engine = ItemValuationEngine()
        improvement = engine.compare_equipment(current, downgrade, "melee_dps")
        
        # Downgrade is worse
        assert improvement < 0


class TestCalculateRefineValue:
    """Test refine value calculation"""
    
    def test_refine_already_at_target(self):
        """Test when item is already at target refine"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=7,
            slots=0
        )
        
        engine = ItemValuationEngine()
        analysis = engine.calculate_refine_value(weapon, target_refine=7, build="melee_dps")
        
        assert analysis.success_rate == 1.0
        assert analysis.cost_estimate == 0
        assert analysis.recommended is False
    
    def test_refine_safe_levels(self):
        """Test refining at safe levels (high success rate)"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=100000)  # Higher value for cost ratio
        }
        
        engine = ItemValuationEngine(market_prices=prices)
        analysis = engine.calculate_refine_value(weapon, target_refine=4, build="melee_dps")
        
        # Safe refines have 100% success rate, cost 8000 < 30000 (30% of 100000)
        assert analysis.success_rate == 1.0
        assert analysis.risk_score == 0.0
        assert analysis.cost_estimate == 8000
        assert analysis.recommended is True
    
    def test_refine_risky_levels(self):
        """Test refining at risky levels"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=10,
            slots=0
        )
        
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=1000000)
        }
        
        engine = ItemValuationEngine(market_prices=prices)
        analysis = engine.calculate_refine_value(weapon, target_refine=15, build="melee_dps")
        
        # High refines have low success rate
        assert analysis.success_rate < 0.5
        assert analysis.risk_score > 0.5


class TestEvaluateCardInsertion:
    """Test card insertion evaluation"""
    
    def test_card_insertion_no_slots(self):
        """Test card insertion when no empty slots"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            slots=2,
            cards=[
                CardSlot(slot_index=0, card_id=4001),
                CardSlot(slot_index=1, card_id=4002)
            ],
            refine=0
        )
        
        engine = ItemValuationEngine()
        result = engine.evaluate_card_insertion(weapon, card_id=4003, build="melee_dps")
        
        assert result["recommended"] is False
        assert "No empty card slots" in result["reason"]
    
    def test_card_insertion_with_empty_slot(self):
        """Test card insertion when slots available"""
        weapon = Equipment(
            item_id=1101,
            name="Slotted Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            slots=2,
            cards=[CardSlot(slot_index=0, card_id=None)],
            refine=0
        )
        
        prices = {
            4001: MarketPrice(item_id=4001, avg_price=50000)
        }
        
        engine = ItemValuationEngine(market_prices=prices)
        result = engine.evaluate_card_insertion(weapon, card_id=4001, build="melee_dps")
        
        assert "score_improvement" in result
        assert "card_cost" in result
        assert result["card_cost"] == 50000
    
    def test_card_insertion_adds_slot_if_none(self):
        """Test card insertion when no existing card slots"""
        weapon = Equipment(
            item_id=1101,
            name="Slotted Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            slots=1,
            cards=[],  # Empty list, has potential
            refine=0
        )
        
        engine = ItemValuationEngine()
        result = engine.evaluate_card_insertion(weapon, card_id=4001, build="melee_dps")
        
        # Should succeed and return results
        assert "score_improvement" in result


class TestPrioritizeEquipmentUpgrades:
    """Test equipment upgrade prioritization"""
    
    def test_prioritize_single_upgrade(self):
        """Test prioritizing when one clear upgrade exists"""
        current_weapon = Equipment(
            item_id=1101,
            name="Basic Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        upgrade_weapon = Equipment(
            item_id=1102,
            name="Better Sword",
            slot=EquipSlot.WEAPON,
            atk=150,
            refine=0,
            slots=0
        )
        
        current_equipment = {EquipSlot.WEAPON: current_weapon}
        available = [upgrade_weapon]
        
        engine = ItemValuationEngine()
        recommendations = engine.prioritize_equipment_upgrades(
            current_equipment,
            available,
            build="melee_dps",
            max_recommendations=5
        )
        
        assert len(recommendations) == 1
        assert recommendations[0]["slot"] == EquipSlot.WEAPON
        assert recommendations[0]["score_improvement"] > 0
    
    def test_prioritize_multiple_upgrades(self):
        """Test prioritizing multiple upgrades"""
        current_equipment = {
            EquipSlot.WEAPON: Equipment(
                item_id=1101, name="Basic Sword", slot=EquipSlot.WEAPON,
                atk=100, refine=0, slots=0
            ),
            EquipSlot.ARMOR: Equipment(
                item_id=2301, name="Basic Armor", slot=EquipSlot.ARMOR,
                defense=50, refine=0, slots=0
            )
        }
        
        available = [
            Equipment(
                item_id=1102, name="Better Sword", slot=EquipSlot.WEAPON,
                atk=150, refine=0, slots=0
            ),
            Equipment(
                item_id=2302, name="Better Armor", slot=EquipSlot.ARMOR,
                defense=100, refine=0, slots=0
            )
        ]
        
        engine = ItemValuationEngine()
        recommendations = engine.prioritize_equipment_upgrades(
            current_equipment,
            available,
            build="tank",
            max_recommendations=5
        )
        
        assert len(recommendations) == 2
        # Should be sorted by improvement
        assert recommendations[0]["score_improvement"] >= recommendations[1]["score_improvement"]
    
    def test_prioritize_respects_max_limit(self):
        """Test that max_recommendations is respected"""
        current_equipment = {}
        available = [
            Equipment(
                item_id=1100 + i,
                name=f"Weapon {i}",
                slot=EquipSlot.WEAPON,
                atk=100 + i * 10,
                refine=0,
                slots=0
            ) for i in range(10)
        ]
        
        engine = ItemValuationEngine()
        recommendations = engine.prioritize_equipment_upgrades(
            current_equipment,
            available,
            build="melee_dps",
            max_recommendations=3
        )
        
        assert len(recommendations) <= 3


class TestGenerateUpgradeReason:
    """Test upgrade reason generation"""
    
    def test_reason_empty_slot(self):
        """Test reason for equipping into empty slot"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(None, weapon)
        
        assert "empty slot" in reason.lower()
        assert "Sword" in reason
    
    def test_reason_atk_improvement(self):
        """Test reason includes ATK improvement"""
        current = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, refine=0, slots=0
        )
        
        upgrade = Equipment(
            item_id=1102, name="Better Sword", slot=EquipSlot.WEAPON,
            atk=150, refine=0, slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        assert "ATK" in reason
    
    def test_reason_defense_improvement(self):
        """Test reason includes DEF improvement"""
        current = Equipment(
            item_id=2301, name="Armor", slot=EquipSlot.ARMOR,
            defense=50, refine=0, slots=0
        )
        
        upgrade = Equipment(
            item_id=2302, name="Better Armor", slot=EquipSlot.ARMOR,
            defense=100, refine=0, slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        assert "DEF" in reason
    
    def test_reason_higher_refine(self):
        """Test reason includes refine level"""
        current = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, refine=5, slots=0
        )
        
        upgrade = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, refine=10, slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        assert "refine" in reason.lower()
    
    def test_reason_more_slots(self):
        """Test reason includes slot count"""
        current = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, slots=0, refine=0
        )
        
        upgrade = Equipment(
            item_id=1102, name="Slotted Sword", slot=EquipSlot.WEAPON,
            atk=100, slots=2, refine=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        assert "slots" in reason.lower()
    
    def test_reason_stat_bonuses(self):
        """Test reason includes stat bonuses"""
        current = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, str_bonus=0, refine=0, slots=0
        )
        
        upgrade = Equipment(
            item_id=1102, name="STR Sword", slot=EquipSlot.WEAPON,
            atk=100, str_bonus=10, refine=0, slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        assert "STR" in reason
    
    def test_reason_limits_to_3(self):
        """Test reason limits to top 3 improvements"""
        current = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, str_bonus=0, agi_bonus=0, dex_bonus=0, vit_bonus=0,
            refine=0, slots=0
        )
        
        upgrade = Equipment(
            item_id=1102, name="Super Sword", slot=EquipSlot.WEAPON,
            atk=150, str_bonus=10, agi_bonus=10, dex_bonus=10, vit_bonus=10,
            refine=0, slots=0
        )
        
        engine = ItemValuationEngine()
        reason = engine._generate_upgrade_reason(current, upgrade)
        
        # Should have at most 3 reasons
        reason_count = len(reason.split(","))
        assert reason_count <= 3


class TestCalculateSlotPriority:
    """Test slot priority calculation"""
    
    def test_weapon_highest_priority(self):
        """Test that weapon slot has highest base priority"""
        engine = ItemValuationEngine()
        
        weapon_priority = engine.calculate_slot_priority(EquipSlot.WEAPON, "hybrid")
        armor_priority = engine.calculate_slot_priority(EquipSlot.ARMOR, "hybrid")
        
        assert weapon_priority >= armor_priority
    
    def test_tank_build_armor_priority(self):
        """Test tank build increases armor/shield priority"""
        engine = ItemValuationEngine()
        
        armor_tank = engine.calculate_slot_priority(EquipSlot.ARMOR, "tank")
        armor_dps = engine.calculate_slot_priority(EquipSlot.ARMOR, "melee_dps")
        
        # Tank values armor more
        assert armor_tank > armor_dps
    
    def test_tank_build_weapon_deprioritized(self):
        """Test tank build reduces weapon priority"""
        engine = ItemValuationEngine()
        
        weapon_tank = engine.calculate_slot_priority(EquipSlot.WEAPON, "tank")
        weapon_dps = engine.calculate_slot_priority(EquipSlot.WEAPON, "melee_dps")
        
        # Tank values weapon less
        assert weapon_tank < weapon_dps
    
    def test_mage_build_shield_deprioritized(self):
        """Test mage build reduces shield priority"""
        engine = ItemValuationEngine()
        
        shield_mage = engine.calculate_slot_priority(EquipSlot.SHIELD, "magic_dps")
        shield_tank = engine.calculate_slot_priority(EquipSlot.SHIELD, "tank")
        
        # Mage values shield less
        assert shield_mage < shield_tank
    
    def test_dps_build_accessory_priority(self):
        """Test DPS builds increase accessory priority"""
        engine = ItemValuationEngine()
        
        acc_dps = engine.calculate_slot_priority(EquipSlot.ACCESSORY1, "melee_dps")
        acc_support = engine.calculate_slot_priority(EquipSlot.ACCESSORY1, "support")
        
        # DPS values accessories more
        assert acc_dps > acc_support
    
    def test_priority_never_exceeds_one(self):
        """Test priority is capped at 1.0"""
        engine = ItemValuationEngine()
        
        for build in ["melee_dps", "tank", "magic_dps", "support"]:
            for slot in EquipSlot:
                priority = engine.calculate_slot_priority(slot, build)
                assert priority <= 1.0


class TestCalculateTotalEquipmentValue:
    """Test total equipment value calculation"""
    
    def test_empty_equipment_set(self):
        """Test value of empty equipment set"""
        equipment_set = {}
        
        engine = ItemValuationEngine()
        total = engine.calculate_total_equipment_value(equipment_set)
        
        assert total == 0
    
    def test_single_item_value(self):
        """Test value with single equipped item"""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=100,
            refine=0,
            slots=0,
            cards=[],
            enchants=[]
        )
        
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000)
        }
        
        equipment_set = {EquipSlot.WEAPON: weapon}
        
        engine = ItemValuationEngine(market_prices=prices)
        total = engine.calculate_total_equipment_value(equipment_set)
        
        assert total == 10000
    
    def test_multiple_items_value(self):
        """Test value with multiple equipped items"""
        weapon = Equipment(
            item_id=1101, name="Sword", slot=EquipSlot.WEAPON,
            atk=100, refine=0, slots=0, cards=[], enchants=[]
        )
        
        armor = Equipment(
            item_id=2301, name="Armor", slot=EquipSlot.ARMOR,
            defense=50, refine=0, slots=0, cards=[], enchants=[]
        )
        
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000),
            2301: MarketPrice(item_id=2301, avg_price=5000)
        }
        
        equipment_set = {
            EquipSlot.WEAPON: weapon,
            EquipSlot.ARMOR: armor
        }
        
        engine = ItemValuationEngine(market_prices=prices)
        total = engine.calculate_total_equipment_value(equipment_set)
        
        assert total == 15000


class TestDefaultBuildWeights:
    """Test default build weight configurations"""
    
    def test_all_builds_present(self):
        """Test all expected builds have weights"""
        expected_builds = [
            "melee_dps", "tank", "magic_dps", "support", "ranged_dps", "hybrid"
        ]
        
        for build in expected_builds:
            assert build in DEFAULT_BUILD_WEIGHTS
    
    def test_melee_dps_weights(self):
        """Test melee DPS build weights are configured correctly"""
        weights = DEFAULT_BUILD_WEIGHTS["melee_dps"]
        
        # Melee DPS should prioritize ATK, STR, ASPD, CRIT
        assert weights.atk > 1.0
        assert weights.str_bonus > 1.0
        assert weights.aspd_bonus > 1.0
        assert weights.crit_bonus > 1.0
    
    def test_tank_weights(self):
        """Test tank build weights are configured correctly"""
        weights = DEFAULT_BUILD_WEIGHTS["tank"]
        
        # Tank should prioritize DEF, VIT, HP
        assert weights.defense > 1.0
        assert weights.vit_bonus > 1.0
        assert weights.hp_bonus > 1.0
    
    def test_magic_dps_weights(self):
        """Test magic DPS build weights are configured correctly"""
        weights = DEFAULT_BUILD_WEIGHTS["magic_dps"]
        
        # Magic DPS should prioritize MATK, INT, SP
        assert weights.matk > 1.0
        assert weights.int_bonus > 1.0
        assert weights.sp_bonus > 1.0


class TestIntegrationScenarios:
    """Test complete integration scenarios"""
    
    def test_complete_equipment_evaluation_workflow(self):
        """Test complete workflow: score → value → compare → recommend"""
        prices = {
            1101: MarketPrice(item_id=1101, avg_price=10000),
            1102: MarketPrice(item_id=1102, avg_price=50000)
        }
        
        current = Equipment(
            item_id=1101, name="Basic Sword", slot=EquipSlot.WEAPON,
            atk=100, refine=4, slots=0
        )
        
        candidate = Equipment(
            item_id=1102, name="Premium Sword", slot=EquipSlot.WEAPON,
            atk=150, refine=7, slots=2
        )
        
        engine = ItemValuationEngine(market_prices=prices)
        
        # Score both items
        current_score = engine.calculate_equipment_score(current, "melee_dps")
        candidate_score = engine.calculate_equipment_score(candidate, "melee_dps")
        
        # Compare
        improvement = engine.compare_equipment(current, candidate, "melee_dps")
        
        # Value estimate
        _, current_value, _ = engine.estimate_market_value(current)
        _, candidate_value, _ = engine.estimate_market_value(candidate)
        
        assert candidate_score > current_score
        assert improvement > 0
        assert candidate_value > current_value