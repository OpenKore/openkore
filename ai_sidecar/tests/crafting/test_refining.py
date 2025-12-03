"""
Comprehensive tests for Equipment Refinement system.

Tests cover:
- Refine ore types and selection
- Refine level models
- Success rate calculations
- Safe refine limits
- HD and enriched ore mechanics
- Blacksmith blessing effects
- Expected cost calculations
- Refinement decision logic
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch
import json

from ai_sidecar.crafting.refining import (
    RefineOre,
    RefineLevel,
    RefiningManager
)
from ai_sidecar.crafting.core import CraftingManager


# Fixtures

@pytest.fixture
def mock_crafting_manager():
    """Create mock crafting manager."""
    return Mock(spec=CraftingManager)


@pytest.fixture
def temp_data_dir(tmp_path):
    """Create temporary data directory."""
    data_dir = tmp_path / "refine_data"
    data_dir.mkdir()
    return data_dir


@pytest.fixture
def refining_manager(temp_data_dir, mock_crafting_manager):
    """Create refining manager."""
    return RefiningManager(temp_data_dir, mock_crafting_manager)


@pytest.fixture
def sample_refine_level():
    """Create sample refine level."""
    return RefineLevel(
        level=5,
        success_rate_weapon=60.0,
        success_rate_armor=60.0,
        safe_level=False,
        breaks_on_fail=True,
        can_downgrade=True
    )


# Model Tests

class TestRefineOreEnum:
    """Test RefineOre enum."""
    
    def test_all_ores_defined(self):
        """Test all ore types are defined."""
        assert RefineOre.PHRACON
        assert RefineOre.EMVERETARCON
        assert RefineOre.ORIDECON
        assert RefineOre.ELUNIUM
        assert RefineOre.HD_ORIDECON
        assert RefineOre.HD_ELUNIUM
        assert RefineOre.ENRICHED_ORIDECON
        assert RefineOre.ENRICHED_ELUNIUM
        assert RefineOre.BLACKSMITH_BLESSING
    
    def test_ore_values(self):
        """Test ore string values."""
        assert RefineOre.PHRACON.value == "phracon"
        assert RefineOre.HD_ORIDECON.value == "hd_oridecon"


class TestRefineLevelModel:
    """Test RefineLevel model."""
    
    def test_create_safe_level(self):
        """Test creating safe refine level."""
        level = RefineLevel(
            level=3,
            success_rate_weapon=100.0,
            success_rate_armor=100.0,
            safe_level=True,
            breaks_on_fail=False,
            can_downgrade=False
        )
        
        assert level.level == 3
        assert level.safe_level is True
        assert level.is_risky is False
    
    def test_create_risky_level(self, sample_refine_level):
        """Test creating risky refine level."""
        assert sample_refine_level.safe_level is False
        assert sample_refine_level.breaks_on_fail is True
        assert sample_refine_level.is_risky is True
    
    def test_is_risky_breaks_only(self):
        """Test risky when only breaks_on_fail."""
        level = RefineLevel(
            level=5,
            success_rate_weapon=60.0,
            success_rate_armor=60.0,
            safe_level=False,
            breaks_on_fail=True,
            can_downgrade=False
        )
        
        assert level.is_risky is True
    
    def test_is_risky_downgrade_only(self):
        """Test risky when only can_downgrade."""
        level = RefineLevel(
            level=5,
            success_rate_weapon=60.0,
            success_rate_armor=60.0,
            safe_level=False,
            breaks_on_fail=False,
            can_downgrade=True
        )
        
        assert level.is_risky is True
    
    def test_refine_level_immutable(self, sample_refine_level):
        """Test refine level is frozen."""
        with pytest.raises(Exception):
            sample_refine_level.level = 10


# RefiningManager Tests

class TestRefiningManagerInit:
    """Test refining manager initialization."""
    
    def test_manager_initialization(self, refining_manager):
        """Test manager initializes correctly."""
        assert refining_manager.refine_rates != {}
        assert refining_manager.log is not None
    
    def test_manager_default_rates_loaded(self, refining_manager):
        """Test default rates are loaded."""
        # Should have rates for levels 1-10
        assert len(refining_manager.refine_rates) == 10
        assert 1 in refining_manager.refine_rates
        assert 10 in refining_manager.refine_rates
    
    def test_safe_levels_correct(self, refining_manager):
        """Test safe levels (1-4) are marked correctly."""
        for level in [1, 2, 3, 4]:
            info = refining_manager.refine_rates[level]
            assert info.safe_level is True
            assert info.breaks_on_fail is False
    
    def test_risky_levels_correct(self, refining_manager):
        """Test risky levels (5+) are marked correctly."""
        for level in [5, 6, 7, 8, 9, 10]:
            info = refining_manager.refine_rates[level]
            assert info.safe_level is False
            assert info.breaks_on_fail is True


class TestGetRequiredOre:
    """Test ore selection logic."""
    
    def test_ore_for_armor_normal(self, refining_manager):
        """Test normal armor ore."""
        ore = refining_manager.get_required_ore(
            item_id=2301,
            item_level=0,
            is_armor=True,
            use_hd=False,
            use_enriched=False
        )
        
        assert ore == RefineOre.ELUNIUM
    
    def test_ore_for_armor_hd(self, refining_manager):
        """Test HD armor ore."""
        ore = refining_manager.get_required_ore(
            item_id=2301,
            item_level=0,
            is_armor=True,
            use_hd=True,
            use_enriched=False
        )
        
        assert ore == RefineOre.HD_ELUNIUM
    
    def test_ore_for_armor_enriched(self, refining_manager):
        """Test enriched armor ore."""
        ore = refining_manager.get_required_ore(
            item_id=2301,
            item_level=0,
            is_armor=True,
            use_hd=False,
            use_enriched=True
        )
        
        assert ore == RefineOre.ENRICHED_ELUNIUM
    
    def test_ore_for_weapon_level_1(self, refining_manager):
        """Test ore for level 1 weapon."""
        ore = refining_manager.get_required_ore(
            item_id=1201,
            item_level=1,
            is_armor=False
        )
        
        assert ore == RefineOre.PHRACON
    
    def test_ore_for_weapon_level_2(self, refining_manager):
        """Test ore for level 2 weapon."""
        ore = refining_manager.get_required_ore(
            item_id=1301,
            item_level=2,
            is_armor=False
        )
        
        assert ore == RefineOre.EMVERETARCON
    
    def test_ore_for_weapon_level_3(self, refining_manager):
        """Test ore for level 3 weapon."""
        ore = refining_manager.get_required_ore(
            item_id=1401,
            item_level=3,
            is_armor=False
        )
        
        assert ore == RefineOre.ORIDECON
    
    def test_ore_for_weapon_level_4(self, refining_manager):
        """Test ore for level 4 weapon."""
        ore = refining_manager.get_required_ore(
            item_id=1185,
            item_level=4,
            is_armor=False
        )
        
        assert ore == RefineOre.ORIDECON
    
    def test_ore_for_weapon_hd(self, refining_manager):
        """Test HD weapon ore."""
        ore = refining_manager.get_required_ore(
            item_id=1201,
            item_level=1,
            is_armor=False,
            use_hd=True
        )
        
        assert ore == RefineOre.HD_ORIDECON
    
    def test_ore_for_weapon_enriched(self, refining_manager):
        """Test enriched weapon ore."""
        ore = refining_manager.get_required_ore(
            item_id=1201,
            item_level=3,
            is_armor=False,
            use_enriched=True
        )
        
        assert ore == RefineOre.ENRICHED_ORIDECON


class TestCalculateRefineRate:
    """Test refine success rate calculations."""
    
    def test_refine_rate_safe_level_weapon(self, refining_manager):
        """Test refine rate for safe weapon level."""
        character_state = {"dex": 50, "luk": 30}
        
        rate = refining_manager.calculate_refine_rate(
            current_level=3,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        # Level 4 is safe with 100% base
        assert rate >= 100
    
    def test_refine_rate_risky_level_weapon(self, refining_manager):
        """Test refine rate for risky weapon level."""
        character_state = {"dex": 50, "luk": 30}
        
        rate = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        # Level 5 is risky with 60% base
        assert 50 <= rate <= 100
    
    def test_refine_rate_armor(self, refining_manager):
        """Test refine rate for armor."""
        character_state = {"dex": 50, "luk": 30}
        
        rate = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=True,
            ore_type=RefineOre.ELUNIUM,
            character_state=character_state
        )
        
        assert rate > 0
    
    def test_refine_rate_hd_ore_bonus(self, refining_manager):
        """Test HD ore gives bonus."""
        character_state = {"dex": 50, "luk": 30}
        
        rate_normal = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        rate_hd = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.HD_ORIDECON,
            character_state=character_state
        )
        
        assert rate_hd > rate_normal
        assert rate_hd >= rate_normal + 10
    
    def test_refine_rate_enriched_ore_bonus(self, refining_manager):
        """Test enriched ore gives bonus."""
        character_state = {"dex": 50, "luk": 30}
        
        rate_normal = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        rate_enriched = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ENRICHED_ORIDECON,
            character_state=character_state
        )
        
        assert rate_enriched > rate_normal
    
    def test_refine_rate_blacksmith_bonus(self, refining_manager):
        """Test blacksmith job gives bonus."""
        character_state = {
            "job": "Blacksmith",
            "job_level": 50,
            "dex": 50,
            "luk": 30
        }
        
        rate = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        # Should get job bonus
        assert rate > 60
    
    def test_refine_rate_whitesmith_bonus(self, refining_manager):
        """Test whitesmith job gives bonus."""
        character_state = {
            "job": "Whitesmith",
            "job_level": 70,
            "dex": 50,
            "luk": 30
        }
        
        rate = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        # Should get job bonus
        assert rate > 60
    
    def test_refine_rate_dex_bonus(self, refining_manager):
        """Test high DEX gives bonus."""
        character_state_low = {"dex": 40, "luk": 30}
        character_state_high = {"dex": 99, "luk": 30}
        
        rate_low = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state_low
        )
        
        rate_high = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state_high
        )
        
        assert rate_high > rate_low
    
    def test_refine_rate_luk_bonus(self, refining_manager):
        """Test LUK gives small bonus."""
        character_state_low = {"dex": 50, "luk": 10}
        character_state_high = {"dex": 50, "luk": 99}
        
        rate_low = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state_low
        )
        
        rate_high = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state_high
        )
        
        assert rate_high > rate_low
    
    def test_refine_rate_caps_at_100(self, refining_manager):
        """Test rate caps at 100%."""
        character_state = {
            "job": "Whitesmith",
            "job_level": 70,
            "dex": 150,
            "luk": 150
        }
        
        rate = refining_manager.calculate_refine_rate(
            current_level=1,
            is_armor=False,
            ore_type=RefineOre.HD_ORIDECON,
            character_state=character_state
        )
        
        assert rate <= 100.0
    
    def test_refine_rate_floors_at_zero(self, refining_manager):
        """Test rate floors at 0%."""
        character_state = {"dex": 1, "luk": 1}
        
        rate = refining_manager.calculate_refine_rate(
            current_level=9,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        assert rate >= 0.0
    
    def test_refine_rate_nonexistent_level(self, refining_manager):
        """Test rate for non-existent level."""
        character_state = {"dex": 50}
        
        rate = refining_manager.calculate_refine_rate(
            current_level=20,
            is_armor=False,
            ore_type=RefineOre.ORIDECON,
            character_state=character_state
        )
        
        assert rate == 0.0


class TestGetSafeLimit:
    """Test safe refine limit determination."""
    
    def test_safe_limit_armor(self, refining_manager):
        """Test safe limit for armor."""
        limit = refining_manager.get_safe_limit(0, is_armor=True)
        
        assert limit == 4
    
    def test_safe_limit_weapon_level_1(self, refining_manager):
        """Test safe limit for level 1 weapon."""
        limit = refining_manager.get_safe_limit(1, is_armor=False)
        
        assert limit == 7
    
    def test_safe_limit_weapon_level_2(self, refining_manager):
        """Test safe limit for level 2 weapon."""
        limit = refining_manager.get_safe_limit(2, is_armor=False)
        
        assert limit == 6
    
    def test_safe_limit_weapon_level_3(self, refining_manager):
        """Test safe limit for level 3 weapon."""
        limit = refining_manager.get_safe_limit(3, is_armor=False)
        
        assert limit == 5
    
    def test_safe_limit_weapon_level_4(self, refining_manager):
        """Test safe limit for level 4 weapon."""
        limit = refining_manager.get_safe_limit(4, is_armor=False)
        
        assert limit == 4


class TestExpectedCostCalculation:
    """Test expected cost calculations."""
    
    def test_expected_cost_invalid_target(self, refining_manager):
        """Test cost with invalid target level."""
        ore_prices = {"oridecon": 5000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=5,
            target_level=5,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert "error" in result
    
    def test_expected_cost_safe_refine(self, refining_manager):
        """Test cost for safe refine levels."""
        ore_prices = {"oridecon": 5000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=0,
            target_level=4,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert "error" not in result
        assert result["current_level"] == 0
        assert result["target_level"] == 4
        assert result["total_ore_cost"] > 0
    
    def test_expected_cost_risky_refine(self, refining_manager):
        """Test cost for risky refine levels."""
        ore_prices = {"oridecon": 5000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=4,
            target_level=7,
            is_armor=False,
            ore_prices=ore_prices,
            item_value=1000000
        )
        
        assert "error" not in result
        assert result["total_ore_cost"] > 0
        assert result["expected_break_cost"] > 0
    
    def test_expected_cost_with_hd_ore(self, refining_manager):
        """Test cost calculation with HD ore."""
        ore_prices = {"hd_oridecon": 50000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=4,
            target_level=6,
            is_armor=False,
            ore_prices=ore_prices,
            use_hd=True
        )
        
        assert "error" not in result
        # Break cost should be 0 with HD ore
        assert result["expected_break_cost"] == 0
    
    def test_expected_cost_details(self, refining_manager):
        """Test cost includes level-by-level details."""
        ore_prices = {"oridecon": 5000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=0,
            target_level=3,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert "details" in result
        assert len(result["details"]) == 3  # 0->1, 1->2, 2->3


class TestShouldRefine:
    """Test refinement decision logic."""
    
    def test_should_refine_safe_level(self, refining_manager):
        """Test should refine at safe level."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=0,
            target_level=3,
            inventory={"ore": 10},
            risk_tolerance=0.5
        )
        
        assert should is True
    
    def test_should_not_refine_backwards(self, refining_manager):
        """Test should not refine backwards."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=5,
            target_level=3,
            inventory={"ore": 10}
        )
        
        assert should is False
        assert "higher" in reason.lower()
    
    def test_should_not_refine_above_10(self, refining_manager):
        """Test should not refine above +10."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=10,
            target_level=11,
            inventory={"ore": 10}
        )
        
        assert should is False
        assert "10" in reason
    
    def test_should_not_refine_no_inventory(self, refining_manager):
        """Test should not refine with no inventory."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=0,
            target_level=5,
            inventory={}
        )
        
        assert should is False
        assert "inventory" in reason.lower()
    
    def test_should_not_refine_risky_low_tolerance(self, refining_manager):
        """Test risky refine rejected with low tolerance."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=4,
            target_level=5,
            inventory={"ore": 10},
            risk_tolerance=0.2  # Low tolerance
        )
        
        assert should is False
        assert "risky" in reason.lower()
    
    def test_should_refine_risky_high_tolerance(self, refining_manager):
        """Test risky refine accepted with high tolerance."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=4,
            target_level=5,
            inventory={"ore": 10},
            risk_tolerance=0.8  # High tolerance
        )
        
        assert should is True
    
    def test_should_not_refine_downgrade_medium_tolerance(self, refining_manager):
        """Test downgrade risk rejected with medium tolerance."""
        should, reason = refining_manager.should_refine(
            item_id=1,
            current_level=5,
            target_level=6,
            inventory={"ore": 10},
            risk_tolerance=0.4  # Medium tolerance
        )
        
        assert should is False
        assert "downgrade" in reason.lower()


class TestStatistics:
    """Test statistics generation."""
    
    def test_statistics_with_default_rates(self, refining_manager):
        """Test statistics with default rates."""
        stats = refining_manager.get_statistics()
        
        assert stats["total_refine_levels"] == 10
        assert stats["safe_levels"] == 4  # Levels 1-4
        assert stats["risky_levels"] == 6  # Levels 5-10
    
    def test_statistics_empty_rates(self, temp_data_dir, mock_crafting_manager):
        """Test statistics with no rates loaded."""
        manager = RefiningManager(temp_data_dir, mock_crafting_manager)
        manager.refine_rates.clear()
        
        # Re-initialize defaults
        manager._initialize_default_rates()
        
        stats = manager.get_statistics()
        assert stats["total_refine_levels"] > 0


# Edge Cases

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    def test_refine_with_missing_character_stats(self, refining_manager):
        """Test refining with incomplete character state."""
        character_state = {}  # Missing all stats
        
        # Should use defaults and not crash
        rate = refining_manager.calculate_refine_rate(
            current_level=0,
            is_armor=False,
            ore_type=RefineOre.PHRACON,
            character_state=character_state
        )
        
        assert rate >= 0
    
    def test_calculate_cost_with_zero_prices(self, refining_manager):
        """Test cost calculation with zero ore prices."""
        ore_prices = {"oridecon": 0}
        
        result = refining_manager.calculate_expected_cost(
            current_level=0,
            target_level=3,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert result["total_ore_cost"] == 0
    
    def test_calculate_cost_single_level(self, refining_manager):
        """Test cost for single level increase."""
        ore_prices = {"oridecon": 5000}
        
        result = refining_manager.calculate_expected_cost(
            current_level=0,
            target_level=1,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert "error" not in result
        assert len(result["details"]) == 1
    
    def test_ore_selection_priority(self, refining_manager):
        """Test enriched takes priority over HD."""
        # When both are true, enriched should be chosen
        ore = refining_manager.get_required_ore(
            item_id=1,
            item_level=3,
            is_armor=False,
            use_hd=True,
            use_enriched=True
        )
        
        assert ore == RefineOre.ENRICHED_ORIDECON


# Integration Tests

class TestIntegration:
    """Test integrated workflows."""
    
    def test_full_refine_workflow_safe(self, refining_manager):
        """Test complete safe refine workflow."""
        # Get required ore
        ore = refining_manager.get_required_ore(
            item_id=1201,
            item_level=1,
            is_armor=False
        )
        assert ore == RefineOre.PHRACON
        
        # Get safe limit
        safe_limit = refining_manager.get_safe_limit(1, is_armor=False)
        assert safe_limit == 7
        
        # Calculate success rate for safe levels
        character_state = {"dex": 50, "luk": 30}
        rate = refining_manager.calculate_refine_rate(
            current_level=0,
            is_armor=False,
            ore_type=ore,
            character_state=character_state
        )
        assert rate >= 100
        
        # Decide to refine
        should, reason = refining_manager.should_refine(
            item_id=1201,
            current_level=0,
            target_level=3,
            inventory={"ore": 10}
        )
        assert should is True
    
    def test_full_refine_workflow_risky(self, refining_manager):
        """Test complete risky refine workflow."""
        # Get ore for risky level
        ore = refining_manager.get_required_ore(
            item_id=1185,
            item_level=4,
            is_armor=False,
            use_hd=True  # Use HD for safety
        )
        assert ore == RefineOre.HD_ORIDECON
        
        # Calculate rate with HD ore
        character_state = {
            "job": "Whitesmith",
            "job_level": 70,
            "dex": 99,
            "luk": 50
        }
        rate = refining_manager.calculate_refine_rate(
            current_level=4,
            is_armor=False,
            ore_type=ore,
            character_state=character_state
        )
        
        # HD ore gives +10% bonus
        assert rate > 60
        
        # Calculate expected cost
        ore_prices = {"hd_oridecon": 50000}
        cost_result = refining_manager.calculate_expected_cost(
            current_level=4,
            target_level=7,
            is_armor=False,
            ore_prices=ore_prices,
            item_value=5000000,
            use_hd=True
        )
        
        assert "error" not in cost_result
        assert cost_result["expected_break_cost"] == 0  # HD prevents breaks
    
    def test_armor_refine_workflow(self, refining_manager):
        """Test armor refining workflow."""
        # Get armor ore
        ore = refining_manager.get_required_ore(
            item_id=2301,
            item_level=0,
            is_armor=True
        )
        assert ore == RefineOre.ELUNIUM
        
        # Get safe limit
        safe_limit = refining_manager.get_safe_limit(0, is_armor=True)
        assert safe_limit == 4
        
        # Calculate rate
        character_state = {"dex": 70, "luk": 40}
        rate = refining_manager.calculate_refine_rate(
            current_level=0,
            is_armor=True,
            ore_type=ore,
            character_state=character_state
        )
        assert rate >= 100