"""
Unit tests for zeny management and economic manager.

Tests budget allocation, spending decisions, transaction tracking,
and economic manager integration.
"""

import pytest

from ai_sidecar.core.state import GameState
from ai_sidecar.economy.manager import EconomicManager, EconomicManagerConfig
from ai_sidecar.economy.zeny import (
    BudgetAllocation,
    ZenyManager,
    ZenyManagerConfig,
    Transaction,
)


class TestZenyManager:
    """Test zeny management functionality."""
    
    @pytest.fixture
    def manager(self):
        """Create zeny manager for testing."""
        config = ZenyManagerConfig(
            equipment_budget_pct=50.0,
            consumables_budget_pct=30.0,
            savings_budget_pct=20.0,
            emergency_reserve=100000,
        )
        return ZenyManager(config=config)
    
    def test_manager_initialization(self, manager):
        """Test manager initializes with correct budgets."""
        assert "equipment" in manager.budgets
        assert "consumables" in manager.budgets
        assert "savings" in manager.budgets
    
    def test_budget_calculation(self, manager):
        """Test budget allocation calculation."""
        total_zeny = 1000000
        
        equipment_budget = manager.get_budget("equipment", total_zeny)
        consumables_budget = manager.get_budget("consumables", total_zeny)
        
        # Equipment gets 50%
        assert equipment_budget == 500000
        
        # Consumables get 30%
        assert consumables_budget == 300000
    
    def test_spending_within_budget(self, manager):
        """Test spending approval within budget."""
        total_zeny = 1000000
        
        # 200k purchase for equipment (within 500k budget)
        should_spend = manager.should_spend(
            amount=200000,
            category="equipment",
            priority=5,
            total_zeny=total_zeny,
        )
        
        assert should_spend
    
    def test_spending_exceeds_budget(self, manager):
        """Test spending rejection when exceeding budget."""
        total_zeny = 1000000
        
        # 600k purchase for equipment (exceeds 500k budget)
        should_spend = manager.should_spend(
            amount=600000,
            category="equipment",
            priority=5,
            total_zeny=total_zeny,
        )
        
        assert not should_spend
    
    def test_high_priority_override(self, manager):
        """Test high priority can slightly exceed budget."""
        total_zeny = 1000000
        
        # 550k purchase (10% over 500k budget) but high priority
        should_spend = manager.should_spend(
            amount=550000,
            category="equipment",
            priority=9,  # High priority
            total_zeny=total_zeny,
        )
        
        assert should_spend
    
    def test_emergency_reserve_protection(self, manager):
        """Test emergency reserve is protected."""
        total_zeny = 150000
        
        # 100k purchase would leave only 50k (below 100k reserve)
        should_spend = manager.should_spend(
            amount=100000,
            category="equipment",
            priority=10,
            total_zeny=total_zeny,
        )
        
        assert not should_spend
    
    def test_income_tracking(self, manager):
        """Test income tracking."""
        manager.track_income("monster_drops", 5000)
        manager.track_income("quest_reward", 10000)
        
        summary = manager.get_financial_summary()
        
        assert summary.total_income == 15000
        assert summary.income_by_source["monster_drops"] == 5000
        assert summary.income_by_source["quest_reward"] == 10000
    
    def test_expense_tracking(self, manager):
        """Test expense tracking."""
        manager.track_expense("equipment", 50000)
        manager.track_expense("consumables", 10000)
        
        summary = manager.get_financial_summary()
        
        assert summary.total_expenses == 60000
        assert summary.expenses_by_category["equipment"] == 50000
    
    def test_net_income_calculation(self, manager):
        """Test net income calculation."""
        manager.track_income("farming", 100000)
        manager.track_expense("equipment", 30000)
        
        summary = manager.get_financial_summary()
        
        assert summary.net_income == 70000


class TestEconomicManager:
    """Test economic manager integration."""
    
    @pytest.fixture
    def manager(self):
        """Create economic manager for testing."""
        config = EconomicManagerConfig(
            enable_equipment=True,
            enable_trading=True,
            enable_storage=True,
            max_actions_per_tick=3,
        )
        return EconomicManager(config=config)
    
    def test_manager_initialization(self, manager):
        """Test manager initializes all subsystems."""
        assert manager.equipment is not None
        assert manager.trading is not None
        assert manager.storage is not None
        assert manager.zeny is not None
    
    def test_set_build_type(self, manager):
        """Test setting build type propagates."""
        manager.set_build_type("melee_dps")
        
        assert manager.current_build == "melee_dps"
    
    @pytest.mark.asyncio
    async def test_tick_returns_actions(self, manager):
        """Test that economic tick returns actions."""
        game_state = GameState()
        
        actions = await manager.tick(game_state)
        
        assert isinstance(actions, list)
        assert len(actions) <= manager.config.max_actions_per_tick
    
    def test_financial_summary(self, manager):
        """Test getting financial summary."""
        summary = manager.get_financial_summary()
        
        assert "current_zeny" in summary
        assert "total_income" in summary
        assert "total_expenses" in summary
        assert "budgets" in summary


if __name__ == "__main__":
    pytest.main([__file__, "-v"])