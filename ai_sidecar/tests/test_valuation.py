"""
Unit tests for item valuation engine.

Tests item scoring, market value estimation, equipment comparison,
and refine analysis.
"""

import pytest

from ai_sidecar.equipment.models import Equipment, EquipSlot, MarketPrice
from ai_sidecar.equipment.valuation import (
    BuildWeights,
    ItemValuationEngine,
    DEFAULT_BUILD_WEIGHTS,
)


class TestItemValuation:
    """Test item valuation engine."""
    
    @pytest.fixture
    def engine(self):
        """Create valuation engine for testing."""
        market_prices = {
            1101: MarketPrice(
                item_id=1101,
                min_price=200,
                avg_price=500,
                max_price=1000,
                npc_sell_price=250,
                npc_buy_price=100,
            ),
        }
        return ItemValuationEngine(market_prices=market_prices)
    
    def test_equipment_scoring_melee_dps(self, engine):
        """Test equipment scoring for melee DPS build."""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
            str_bonus=5,
            agi_bonus=3,
        )
        
        score = engine.calculate_equipment_score(weapon, "melee_dps")
        
        # Should value ATK and STR highly for melee DPS
        assert score > 0
    
    def test_equipment_comparison(self, engine):
        """Test comparing two equipment pieces."""
        current = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
        )
        
        better = Equipment(
            item_id=1116,
            name="Katana",
            slot=EquipSlot.WEAPON,
            atk=60,
        )
        
        improvement = engine.compare_equipment(current, better, "melee_dps")
        
        # Better weapon should have positive improvement
        assert improvement > 0
    
    def test_empty_slot_comparison(self, engine):
        """Test comparing equipment against empty slot."""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
        )
        
        improvement = engine.compare_equipment(None, weapon, "hybrid")
        
        # Any equipment is better than empty slot
        assert improvement > 0
    
    def test_market_value_estimation(self, engine):
        """Test market value estimation."""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
            refine=7,
        )
        
        min_val, avg_val, max_val = engine.estimate_market_value(weapon)
        
        assert min_val < avg_val < max_val
        assert avg_val > 500  # Higher than base due to refine
    
    def test_refine_value_calculation(self, engine):
        """Test refine risk/reward analysis."""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
            refine=7,
        )
        
        analysis = engine.calculate_refine_value(weapon, 8, "melee_dps")
        
        assert analysis.current_refine == 7
        assert analysis.target_refine == 8
        assert 0.0 <= analysis.success_rate <= 1.0
        assert analysis.cost_estimate >= 0
    
    def test_build_weights(self):
        """Test default build weights."""
        assert "melee_dps" in DEFAULT_BUILD_WEIGHTS
        assert "tank" in DEFAULT_BUILD_WEIGHTS
        assert "magic_dps" in DEFAULT_BUILD_WEIGHTS
        
        melee_weights = DEFAULT_BUILD_WEIGHTS["melee_dps"]
        assert melee_weights.atk > melee_weights.defense
        
        tank_weights = DEFAULT_BUILD_WEIGHTS["tank"]
        assert tank_weights.defense > tank_weights.atk


class TestBuildWeights:
    """Test build-specific stat weighting."""
    
    def test_melee_dps_priorities(self):
        """Test melee DPS weights prioritize ATK."""
        weights = DEFAULT_BUILD_WEIGHTS["melee_dps"]
        
        assert weights.atk == 1.5
        assert weights.str_bonus == 1.2
        assert weights.defense < weights.atk
    
    def test_tank_priorities(self):
        """Test tank weights prioritize defense."""
        weights = DEFAULT_BUILD_WEIGHTS["tank"]
        
        assert weights.defense == 1.5
        assert weights.vit_bonus == 1.3
        assert weights.atk < weights.defense
    
    def test_magic_dps_priorities(self):
        """Test magic DPS weights prioritize MATK."""
        weights = DEFAULT_BUILD_WEIGHTS["magic_dps"]
        
        assert weights.matk == 1.5
        assert weights.int_bonus == 1.3
        assert weights.dex_bonus == 1.2


if __name__ == "__main__":
    pytest.main([__file__, "-v"])