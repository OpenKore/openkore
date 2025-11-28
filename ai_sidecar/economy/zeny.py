"""
Zeny (currency) management system for AI Sidecar.

Optimizes zeny accumulation and spending through:
- Budget allocation across categories
- Income/expense tracking
- Spending decisions based on priorities
"""

import logging
import time
from typing import Literal

from pydantic import BaseModel, Field, ConfigDict

logger = logging.getLogger(__name__)


class BudgetAllocation(BaseModel):
    """Budget allocation for a spending category."""
    
    model_config = ConfigDict(frozen=False)
    
    category: str = Field(description="Budget category name")
    percentage: float = Field(
        ge=0.0,
        le=100.0,
        description="Percentage of total zeny"
    )
    min_reserve: int = Field(
        default=0,
        ge=0,
        description="Minimum zeny to keep for this category"
    )
    max_spend_per_transaction: int = Field(
        default=0,
        description="Max single transaction (0 = unlimited)"
    )


class Transaction(BaseModel):
    """A zeny transaction (income or expense)."""
    
    model_config = ConfigDict(frozen=False)
    
    amount: int = Field(description="Transaction amount (positive or negative)")
    category: str = Field(default="misc", description="Transaction category")
    source: str = Field(default="", description="Transaction source/reason")
    timestamp: float = Field(
        default_factory=time.time,
        description="Transaction timestamp"
    )
    transaction_type: Literal["income", "expense"] = Field(
        description="Transaction type"
    )


class FinancialSummary(BaseModel):
    """Financial statistics and summary."""
    
    model_config = ConfigDict(frozen=False)
    
    # Current state
    current_zeny: int = Field(default=0, description="Current zeny balance")
    
    # Income breakdown
    total_income: int = Field(default=0, description="Total income earned")
    income_by_source: dict[str, int] = Field(
        default_factory=dict,
        description="Income by source category"
    )
    
    # Expense breakdown
    total_expenses: int = Field(default=0, description="Total expenses")
    expenses_by_category: dict[str, int] = Field(
        default_factory=dict,
        description="Expenses by category"
    )
    
    # Statistics
    net_income: int = Field(default=0, description="Total income - expenses")
    transaction_count: int = Field(default=0, description="Total transactions")
    
    # Time period
    period_start: float = Field(
        default_factory=time.time,
        description="Statistics period start"
    )
    period_end: float | None = Field(default=None, description="Statistics period end")
    
    @property
    def period_duration_hours(self) -> float:
        """Calculate period duration in hours."""
        end = self.period_end or time.time()
        return (end - self.period_start) / 3600
    
    @property
    def zeny_per_hour(self) -> float:
        """Calculate average zeny per hour."""
        duration = self.period_duration_hours
        if duration > 0:
            return self.net_income / duration
        return 0.0


class ZenyManagerConfig(BaseModel):
    """Configuration for zeny manager."""
    
    model_config = ConfigDict(frozen=True)
    
    # Budget allocations
    equipment_budget_pct: float = Field(default=50.0, ge=0.0, le=100.0)
    consumables_budget_pct: float = Field(default=30.0, ge=0.0, le=100.0)
    savings_budget_pct: float = Field(default=20.0, ge=0.0, le=100.0)
    
    # Reserves
    emergency_reserve: int = Field(
        default=100000,
        description="Always keep this much as emergency fund"
    )
    
    # Tracking
    enable_tracking: bool = Field(
        default=True,
        description="Track income and expenses"
    )
    max_transaction_history: int = Field(
        default=1000,
        description="Max transactions to keep in memory"
    )


class ZenyManager:
    """
    Optimizes zeny accumulation and spending.
    
    Features:
    - Budget allocation across categories
    - Income/expense tracking
    - Spending approval based on budget
    - Financial statistics
    """
    
    def __init__(self, config: ZenyManagerConfig | None = None):
        """
        Initialize zeny manager.
        
        Args:
            config: Zeny manager configuration
        """
        self.config = config or ZenyManagerConfig()
        
        # Budget allocations
        self.budgets = self._initialize_budgets()
        
        # Transaction history
        self.transactions: list[Transaction] = []
        
        # Statistics
        self.stats = FinancialSummary()
        
        logger.info("ZenyManager initialized")
    
    def _initialize_budgets(self) -> dict[str, BudgetAllocation]:
        """Initialize budget allocations from config."""
        return {
            "equipment": BudgetAllocation(
                category="equipment",
                percentage=self.config.equipment_budget_pct,
                min_reserve=50000,
            ),
            "consumables": BudgetAllocation(
                category="consumables",
                percentage=self.config.consumables_budget_pct,
                min_reserve=20000,
            ),
            "savings": BudgetAllocation(
                category="savings",
                percentage=self.config.savings_budget_pct,
                min_reserve=self.config.emergency_reserve,
            ),
        }
    
    def get_budget(self, category: str, total_zeny: int) -> int:
        """
        Get available budget for a category.
        
        Args:
            category: Budget category
            total_zeny: Current total zeny
            
        Returns:
            Available budget for this category
        """
        budget_config = self.budgets.get(category)
        if not budget_config:
            # Unknown category, use 10% of total
            return int(total_zeny * 0.1)
        
        # Calculate budget based on percentage
        allocated = int(total_zeny * (budget_config.percentage / 100))
        
        # Ensure minimum reserve
        if allocated < budget_config.min_reserve:
            return 0
        
        return allocated
    
    def should_spend(
        self,
        amount: int,
        category: str,
        priority: int,
        total_zeny: int,
    ) -> bool:
        """
        Determine if spending is within budget and acceptable.
        
        Args:
            amount: Amount to spend
            category: Spending category
            priority: Purchase priority (1-10, higher = more important)
            total_zeny: Current total zeny
            
        Returns:
            True if spending is approved
        """
        # Always keep emergency reserve
        if total_zeny - amount < self.config.emergency_reserve:
            logger.warning(
                f"Spending {amount}z would breach emergency reserve"
            )
            return False
        
        # Get available budget for category
        available_budget = self.get_budget(category, total_zeny)
        
        # Check if within budget
        if amount > available_budget:
            # High priority items can exceed budget slightly
            if priority >= 8:
                excess = amount - available_budget
                if excess < available_budget * 0.2:  # 20% overrun allowed
                    logger.info(
                        f"Approving high-priority purchase "
                        f"{amount}z (exceeds budget by {excess}z)"
                    )
                    return True
            
            logger.info(
                f"Spending {amount}z exceeds {category} budget "
                f"({available_budget}z available)"
            )
            return False
        
        # Check per-transaction limit
        budget_config = self.budgets.get(category)
        if budget_config and budget_config.max_spend_per_transaction > 0:
            if amount > budget_config.max_spend_per_transaction:
                logger.warning(
                    f"Spending {amount}z exceeds per-transaction limit "
                    f"({budget_config.max_spend_per_transaction}z)"
                )
                return False
        
        return True
    
    def track_income(self, source: str, amount: int) -> None:
        """
        Track zeny income.
        
        Args:
            source: Income source (e.g., "monster_drops", "quest_reward")
            amount: Amount earned
        """
        if not self.config.enable_tracking:
            return
        
        transaction = Transaction(
            amount=amount,
            category=source,
            source=source,
            transaction_type="income",
        )
        
        self.transactions.append(transaction)
        
        # Update statistics
        self.stats.total_income += amount
        self.stats.income_by_source[source] = (
            self.stats.income_by_source.get(source, 0) + amount
        )
        self.stats.transaction_count += 1
        self.stats.net_income = self.stats.total_income - self.stats.total_expenses
        
        # Trim transaction history if needed
        if len(self.transactions) > self.config.max_transaction_history:
            self.transactions = self.transactions[-self.config.max_transaction_history:]
        
        logger.debug(f"Income: +{amount}z from {source}")
    
    def track_expense(self, category: str, amount: int) -> None:
        """
        Track zeny expense.
        
        Args:
            category: Expense category (e.g., "equipment", "consumables")
            amount: Amount spent
        """
        if not self.config.enable_tracking:
            return
        
        transaction = Transaction(
            amount=-amount,  # Negative for expenses
            category=category,
            source=f"Purchase: {category}",
            transaction_type="expense",
        )
        
        self.transactions.append(transaction)
        
        # Update statistics
        self.stats.total_expenses += amount
        self.stats.expenses_by_category[category] = (
            self.stats.expenses_by_category.get(category, 0) + amount
        )
        self.stats.transaction_count += 1
        self.stats.net_income = self.stats.total_income - self.stats.total_expenses
        
        # Trim transaction history if needed
        if len(self.transactions) > self.config.max_transaction_history:
            self.transactions = self.transactions[-self.config.max_transaction_history:]
        
        logger.debug(f"Expense: -{amount}z for {category}")
    
    def get_financial_summary(self) -> FinancialSummary:
        """
        Get comprehensive financial summary.
        
        Returns:
            Financial summary with income/expense breakdown
        """
        # Update period end time
        self.stats.period_end = time.time()
        
        return self.stats
    
    def reset_statistics(self) -> None:
        """Reset financial statistics."""
        self.stats = FinancialSummary()
        self.transactions.clear()
        logger.info("Financial statistics reset")
    
    def set_budget_allocation(
        self,
        category: str,
        percentage: float,
        min_reserve: int = 0,
    ) -> None:
        """
        Set budget allocation for a category.
        
        Args:
            category: Budget category
            percentage: Percentage of total zeny (0-100)
            min_reserve: Minimum reserve for this category
        """
        self.budgets[category] = BudgetAllocation(
            category=category,
            percentage=percentage,
            min_reserve=min_reserve,
        )
        logger.info(f"Budget set: {category} = {percentage}%")
    
    def get_spending_recommendations(
        self,
        total_zeny: int,
    ) -> dict[str, dict[str, int]]:
        """
        Get spending recommendations based on current budget.
        
        Args:
            total_zeny: Current total zeny
            
        Returns:
            Dict of category -> {allocated, spent, available}
        """
        recommendations = {}
        
        for category, budget in self.budgets.items():
            allocated = self.get_budget(category, total_zeny)
            
            # Calculate spent in this category
            spent = self.stats.expenses_by_category.get(category, 0)
            
            # Available = allocated - already spent
            available = max(0, allocated - spent)
            
            recommendations[category] = {
                "allocated": allocated,
                "spent": spent,
                "available": available,
            }
        
        return recommendations