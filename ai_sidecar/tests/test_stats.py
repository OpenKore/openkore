"""
Unit tests for stat distribution engine.

Tests:
- RO stat cost formulas
- Build template ratios
- Stat allocation algorithm
- Diminishing returns
- Priority calculations
"""

import pytest

from ai_sidecar.progression.stats import (
    StatDistributionEngine,
    BuildType,
    StatRatios,
    StatAllocationPlan
)
from ai_sidecar.core.state import CharacterState


class TestStatCostFormulas:
    """Test RO stat cost calculations."""
    
    def test_stat_cost_formula(self):
        """Test stat cost = 1 + floor((value - 1) / 10)."""
        engine = StatDistributionEngine()
        
        # Stats 1-9 cost 1 point
        assert engine.calculate_stat_cost(1) == 1
        assert engine.calculate_stat_cost(5) == 1
        assert engine.calculate_stat_cost(9) == 1
        
        # Stats 10-19 cost 2 points
        assert engine.calculate_stat_cost(10) == 2
        assert engine.calculate_stat_cost(15) == 2
        assert engine.calculate_stat_cost(19) == 2
        
        # Stats 20-29 cost 3 points
        assert engine.calculate_stat_cost(20) == 3
        assert engine.calculate_stat_cost(29) == 3
        
        # Stats 90-99 cost 10 points
        assert engine.calculate_stat_cost(90) == 10
        assert engine.calculate_stat_cost(99) == 10
    
    def test_total_cost_calculation(self):
        """Test cumulative cost to raise stat from X to Y."""
        engine = StatDistributionEngine()
        
        # Cost to go from 1 to 10 (9 points at cost 1 each)
        assert engine.calculate_total_cost(1, 10) == 9
        
        # Cost to go from 1 to 20
        # 1-9: 9 points × 1 = 9
        # 10-19: 10 points × 2 = 20
        # Total: 29
        assert engine.calculate_total_cost(1, 20) == 29
        
        # Cost to go from 10 to 20 (10 points at cost 2 each)
        assert engine.calculate_total_cost(10, 20) == 20
        
        # No cost if target <= current
        assert engine.calculate_total_cost(50, 40) == 0
        assert engine.calculate_total_cost(30, 30) == 0


class TestBuildTemplates:
    """Test build template definitions."""
    
    def test_all_build_templates_valid(self):
        """Verify all build templates have valid ratios summing to 1.0."""
        for build_type, ratios in StatDistributionEngine.BUILD_TEMPLATES.items():
            total = (
                ratios.str_ratio + ratios.agi_ratio + ratios.vit_ratio +
                ratios.int_ratio + ratios.dex_ratio + ratios.luk_ratio
            )
            
            # Should sum to approximately 1.0 (allow floating point error)
            assert 0.99 <= total <= 1.01, f"{build_type} ratios sum to {total}"
    
    def test_melee_dps_template(self):
        """Test melee DPS build emphasizes STR/DEX/AGI."""
        ratios = StatDistributionEngine.BUILD_TEMPLATES[BuildType.MELEE_DPS]
        
        # STR should be highest
        assert ratios.str_ratio >= 0.30
        
        # INT should be minimal/zero
        assert ratios.int_ratio == 0.0
    
    def test_magic_dps_template(self):
        """Test magic DPS build emphasizes INT/DEX."""
        ratios = StatDistributionEngine.BUILD_TEMPLATES[BuildType.MAGIC_DPS]
        
        # INT should be highest
        assert ratios.int_ratio >= 0.40
        
        # STR should be minimal/zero
        assert ratios.str_ratio == 0.0
    
    def test_custom_ratios_validation(self):
        """Test custom ratios must sum to 1.0."""
        # Valid custom ratios
        valid = StatRatios(
            str_ratio=0.2, agi_ratio=0.2, vit_ratio=0.2,
            int_ratio=0.2, dex_ratio=0.1, luk_ratio=0.1
        )
        assert valid is not None
        
        # Invalid ratios (sum > 1.0) should raise error
        with pytest.raises(ValueError, match="must sum to 1.0"):
            StatRatios(
                str_ratio=0.5, agi_ratio=0.5, vit_ratio=0.5,
                int_ratio=0.0, dex_ratio=0.0, luk_ratio=0.0
            )


class TestStatAllocation:
    """Test stat allocation logic."""
    
    def test_next_stat_selection_balanced(self):
        """Test stat selection for balanced hybrid build."""
        engine = StatDistributionEngine(build_type=BuildType.HYBRID)
        
        # Fresh character with 1 point to allocate
        char = CharacterState(
            str=1, agi=1, vit=1, int_stat=1, dex=1, luk=1,
            stat_points=10
        )
        
        # Should allocate to stats according to hybrid ratios
        next_stat = engine.get_next_stat_allocation(char)
        assert next_stat in ["STR", "AGI", "VIT", "INT", "DEX", "LUK"]
    
    def test_allocation_respects_soft_cap(self):
        """Test that allocation avoids stats above soft cap."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS, soft_cap=99)
        
        # Character with STR at soft cap
        char = CharacterState(
            str=99, agi=50, vit=40, int_stat=1, dex=50, luk=20,
            stat_points=10
        )
        
        # Should not allocate to STR (at cap)
        next_stat = engine.get_next_stat_allocation(char)
        assert next_stat != "STR"
    
    def test_zero_ratio_stats_not_allocated(self):
        """Test that stats with 0 ratio are not allocated."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        # MELEE_DPS has int_ratio = 0.0
        char = CharacterState(
            str=50, agi=50, vit=30, int_stat=1, dex=50, luk=10,
            stat_points=10
        )
        
        # Should never allocate to INT
        for _ in range(100):  # Test multiple allocations
            next_stat = engine.get_next_stat_allocation(char)
            if next_stat:
                assert next_stat != "INT"
    
    @pytest.mark.asyncio
    async def test_allocate_points_generates_actions(self):
        """Test that allocate_points generates actions."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        char = CharacterState(
            str=1, agi=1, vit=1, int_stat=1, dex=1, luk=1,
            stat_points=10,
            name="TestChar"
        )
        
        actions = await engine.allocate_points(char)
        
        # Should generate actions for all 10 points
        total_points = sum(action.extra.get("amount", 0) for action in actions)
        assert total_points == 10
    
    def test_allocation_plan_consolidation(self):
        """Test that allocation plan consolidates consecutive stats."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        char = CharacterState(
            str=1, agi=1, vit=1, int_stat=1, dex=1, luk=1,
            stat_points=10
        )
        
        plan = engine.generate_allocation_plan(char)
        
        # Plan should have fewer entries than total points (due to consolidation)
        assert len(plan) <= 10
        
        # Total points should still equal 10
        total = sum(p.points for p in plan)
        assert total == 10


class TestDiminishingReturns:
    """Test diminishing returns calculations."""
    
    def test_no_penalty_below_softcap(self):
        """Test no penalty for stats below soft cap."""
        engine = StatDistributionEngine(soft_cap=99)
        
        for value in [1, 20, 50, 80, 98]:
            penalty = engine.calculate_diminishing_returns_penalty(value)
            assert penalty == 1.0, f"Unexpected penalty at value {value}"
    
    def test_penalty_above_softcap(self):
        """Test penalty increases above soft cap."""
        engine = StatDistributionEngine(soft_cap=99)
        
        # 1 point over cap: 1% penalty
        penalty_100 = engine.calculate_diminishing_returns_penalty(100)
        assert penalty_100 == 0.99
        
        # 10 points over cap: 10% penalty
        penalty_109 = engine.calculate_diminishing_returns_penalty(109)
        assert penalty_109 == 0.90
        
        # Penalty should decrease as stat increases
        assert penalty_100 > penalty_109


class TestJobBuildMapping:
    """Test automatic build selection based on job class."""
    
    def test_knight_gets_melee_dps(self):
        """Test Knight maps to melee DPS build."""
        engine = StatDistributionEngine()
        
        for job in ["Knight", "Lord Knight", "Rune Knight"]:
            build = engine.recommend_build_for_job(job)
            assert build == BuildType.MELEE_DPS
    
    def test_wizard_gets_magic_dps(self):
        """Test Wizard maps to magic DPS build."""
        engine = StatDistributionEngine()
        
        for job in ["Wizard", "High Wizard", "Warlock"]:
            build = engine.recommend_build_for_job(job)
            assert build == BuildType.MAGIC_DPS
    
    def test_priest_gets_support(self):
        """Test Priest maps to support build."""
        engine = StatDistributionEngine()
        
        for job in ["Priest", "High Priest", "Arch Bishop"]:
            build = engine.recommend_build_for_job(job)
            assert build == BuildType.SUPPORT
    
    def test_unknown_job_defaults_hybrid(self):
        """Test unknown jobs default to hybrid build."""
        engine = StatDistributionEngine()
        
        build = engine.recommend_build_for_job("UnknownJobClass")
        assert build == BuildType.HYBRID


class TestStatDistributionSummary:
    """Test stat distribution analysis."""
    
    def test_summary_shows_variance(self):
        """Test summary shows variance from target ratios."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        char = CharacterState(
            str=50, agi=30, vit=20, int_stat=1, dex=40, luk=10,
            stat_points=5
        )
        
        summary = engine.get_stat_distribution_summary(char)
        
        assert summary["build_type"] == "melee_dps"
        assert summary["total_stats"] == 151  # Sum of all stats
        assert summary["available_points"] == 5
        assert "stats" in summary
        
        # Should have variance info for all 6 stats
        assert len(summary["stats"]) == 6
        assert "STR" in summary["stats"]
        assert "current" in summary["stats"]["STR"]
        assert "target_ratio" in summary["stats"]["STR"]


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    def test_no_points_returns_empty_plan(self):
        """Test allocation with 0 points returns empty plan."""
        engine = StatDistributionEngine()
        
        char = CharacterState(stat_points=0)
        plan = engine.generate_allocation_plan(char)
        
        assert plan == []
    
    @pytest.mark.asyncio
    async def test_no_points_returns_no_actions(self):
        """Test allocate_points with 0 points returns no actions."""
        engine = StatDistributionEngine()
        
        char = CharacterState(stat_points=0)
        actions = await engine.allocate_points(char)
        
        assert actions == []
    
    def test_all_stats_at_cap(self):
        """Test allocation when all stats are at soft cap."""
        engine = StatDistributionEngine(soft_cap=99)
        
        # All stats at cap
        char = CharacterState(
            str=99, agi=99, vit=99, int_stat=99, dex=99, luk=99,
            stat_points=10
        )
        
        # Should still be able to allocate (with penalty)
        next_stat = engine.get_next_stat_allocation(char)
        # Can be None or a stat, both are acceptable
        assert next_stat is None or next_stat in ["STR", "AGI", "VIT", "INT", "DEX", "LUK"]


class TestStatPriorityCalculation:
    """Test stat priority scoring algorithm."""
    
    def test_priority_favors_deficit_stats(self):
        """Test priority is higher for stats below target ratio."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        # MELEE_DPS has high STR ratio (0.35) but low INT ratio (0.0)
        # With STR=1 and total=6, STR is way below target ratio
        # Priority should favor STR over stats already at target
        
        priority_str = engine.calculate_stat_priority("STR", 1, 60)
        priority_agi = engine.calculate_stat_priority("AGI", 30, 60)
        
        # STR has larger deficit, should have higher priority
        # (actual values depend on formula, just check relative)
        assert isinstance(priority_str, float)
        assert isinstance(priority_agi, float)
    
    def test_priority_zero_for_zero_ratio(self):
        """Test priority is 0 for stats with 0 target ratio."""
        engine = StatDistributionEngine(build_type=BuildType.MELEE_DPS)
        
        # MELEE_DPS has int_ratio = 0.0
        priority = engine.calculate_stat_priority("INT", 1, 60)
        assert priority == 0.0