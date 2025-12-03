"""
Economic Manager - Orchestrates all economic systems.

Coordinates equipment management, trading, storage, and zeny decisions
into a unified economic tick system.
"""

import logging
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.economy.storage import StorageManager, StorageManagerConfig
from ai_sidecar.economy.trading import TradingSystem, TradingSystemConfig
from ai_sidecar.economy.zeny import ZenyManager, ZenyManagerConfig
from ai_sidecar.equipment.manager import EquipmentManager, EquipmentManagerConfig
from ai_sidecar.core.decision import Action

if TYPE_CHECKING:
    from ai_sidecar.core.state import GameState

logger = logging.getLogger(__name__)


class EconomicManagerConfig(BaseModel):
    """Configuration for economic manager."""
    
    model_config = ConfigDict(frozen=True)
    
    # Enable/disable subsystems
    enable_equipment: bool = Field(default=True)
    enable_trading: bool = Field(default=True)
    enable_storage: bool = Field(default=True)
    enable_zeny_tracking: bool = Field(default=True)
    
    # Performance
    max_actions_per_tick: int = Field(default=3, ge=1, le=10)
    
    # Subsystem configs
    equipment: EquipmentManagerConfig = Field(
        default_factory=EquipmentManagerConfig
    )
    trading: TradingSystemConfig = Field(default_factory=TradingSystemConfig)
    storage: StorageManagerConfig = Field(default_factory=StorageManagerConfig)
    zeny: ZenyManagerConfig = Field(default_factory=ZenyManagerConfig)


class EconomicManager:
    """
    Orchestrates equipment and economic decisions.
    
    Main economic tick entry point called from decision engine.
    Coordinates:
    - Equipment optimization
    - Trading decisions
    - Storage management
    - Zeny budgeting
    """
    
    def __init__(self, config: EconomicManagerConfig | None = None):
        """
        Initialize economic manager.
        
        Args:
            config: Economic manager configuration
        """
        self.config = config or EconomicManagerConfig()
        
        # Initialize subsystems
        self.equipment = EquipmentManager(self.config.equipment)
        self.trading = TradingSystem(self.config.trading)
        self.storage = StorageManager(self.config.storage)
        self.zeny = ZenyManager(self.config.zeny)
        
        # State
        self._initialized = False
        self._last_tick: int = 0
        
        logger.info("EconomicManager initialized")
    
    def initialize(self, build_type: str | None = None) -> None:
        """
        Initialize manager with character data.
        
        Args:
            build_type: Character build type for equipment optimization
        """
        if build_type:
            self.equipment.initialize(build_type)
        
        self._initialized = True
        logger.info("EconomicManager fully initialized")
    
    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main economic tick.
        
        Priority order:
        1. Equipment optimization (equip better gear)
        2. Storage management (prevent inventory overflow)
        3. Trading decisions (buy/sell automation)
        
        Args:
            game_state: Current game state
            
        Returns:
            List of economic actions
        """
        if not self._initialized:
            self.initialize()
        
        self._last_tick = game_state.tick
        
        all_actions: list[Action] = []
        
        try:
            # Priority 1: Equipment optimization
            if self.config.enable_equipment:
                equipment_actions = await self.equipment.tick(game_state)
                all_actions.extend(equipment_actions)
            
            # Priority 2: Storage management
            if self.config.enable_storage:
                storage_actions = await self.storage.tick(game_state)
                all_actions.extend(storage_actions)
            
            # Priority 3: Trading decisions
            if self.config.enable_trading:
                trading_actions = await self.trading.tick(game_state)
                all_actions.extend(trading_actions)
            
            # Track zeny changes (passive tracking)
            if self.config.enable_zeny_tracking:
                self._update_zeny_tracking(game_state)
        
        except Exception as e:
            logger.error(f"Economic manager error: {e}", exc_info=True)
            return []
        
        # Sort by priority and limit actions
        all_actions.sort(key=lambda a: a.priority)
        limited_actions = all_actions[: self.config.max_actions_per_tick]
        
        if limited_actions:
            logger.debug(
                f"Economic tick: {len(limited_actions)} actions (tick={game_state.tick})"
            )
        
        return limited_actions
    
    def _update_zeny_tracking(self, game_state: "GameState") -> None:
        """
        Update zeny tracking based on changes.
        
        Args:
            game_state: Current game state
        """
        # Update current zeny in statistics
        self.zeny.stats.current_zeny = game_state.character.zeny
    
    # =========================================================================
    # Public API for subsystems
    # =========================================================================
    
    def set_build_type(self, build_type: str) -> None:
        """
        Set character build type for equipment optimization.
        
        Args:
            build_type: Build type (melee_dps, tank, magic_dps, etc.)
        """
        self.equipment.set_build_type(build_type)
        logger.info(f"Economic manager build type: {build_type}")
    
    def add_shopping_item(
        self,
        item_id: int,
        name: str,
        max_price: int,
        quantity: int,
        priority: int = 5,
    ) -> None:
        """
        Add item to shopping list.
        
        Args:
            item_id: Item database ID
            name: Item name
            max_price: Maximum price to pay
            quantity: Desired quantity
            priority: Purchase priority (1-10)
        """
        self.trading.add_shopping_item(item_id, name, max_price, quantity, priority)
    
    def add_sell_rule(
        self,
        pattern: str,
        sell_to: str = "npc",
        keep_quantity: int = 0,
    ) -> None:
        """
        Add automatic sell rule.
        
        Args:
            pattern: Item name pattern
            sell_to: Sell destination (npc, vend, storage)
            keep_quantity: Minimum to keep in inventory
        """
        from ai_sidecar.economy.trading import SellRule
        
        self.trading.sell_rules.append(
            SellRule(
                item_pattern=pattern,
                sell_to=sell_to,  # type: ignore
                keep_quantity=keep_quantity,
            )
        )
    
    def get_financial_summary(self) -> dict:
        """
        Get comprehensive financial summary.
        
        Returns:
            Dict with zeny stats, budgets, and recommendations
        """
        summary = self.zeny.get_financial_summary()
        
        return {
            "current_zeny": summary.current_zeny,
            "total_income": summary.total_income,
            "total_expenses": summary.total_expenses,
            "net_income": summary.net_income,
            "zeny_per_hour": summary.zeny_per_hour,
            "income_by_source": summary.income_by_source,
            "expenses_by_category": summary.expenses_by_category,
            "budgets": self.zeny.get_spending_recommendations(summary.current_zeny),
        }
    
    @property
    def current_build(self) -> str:
        """Get current build type."""
        return self.equipment.build_type
    
    @property
    def zeny_stats(self):
        """Get zeny statistics."""
        return self.zeny.stats