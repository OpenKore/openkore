"""
Recovery Item Management System - P0 Critical Component.

Provides intelligent HP/SP recovery with emergency handling, efficient item
selection, and situational threshold adjustments for Ragnarok Online.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class RecoveryType(str, Enum):
    """Types of recovery items."""
    
    HP_INSTANT = "hp_instant"      # Red Potion, White Potion
    HP_PERCENT = "hp_percent"      # Condensed White Potion
    SP_INSTANT = "sp_instant"      # Blue Potion
    SP_PERCENT = "sp_percent"      # Blue Gemstone (SP)
    HP_SP_COMBO = "hp_sp_combo"    # Yggdrasil Seed
    HP_REGEN = "hp_regen"          # Food items with regen
    SP_REGEN = "sp_regen"          # Food items with SP regen
    EMERGENCY = "emergency"        # Yggdrasil Berry (full heal)


class RecoveryItem(BaseModel):
    """Recovery item definition."""
    
    item_id: int
    item_name: str
    recovery_type: RecoveryType
    base_recovery: int = 0
    percentage_recovery: float = Field(default=0.0, ge=0.0, le=1.0)
    weight: int
    price: int
    cooldown_group: str = "potion"
    cooldown_seconds: float = 0.5
    cast_delay: float = 0.0
    
    # Usage restrictions
    usable_in_combat: bool = True
    usable_while_silenced: bool = True


class RecoveryConfig(BaseModel):
    """Configuration for recovery behavior."""
    
    # HP thresholds
    hp_critical_threshold: float = Field(default=0.20, ge=0.0, le=1.0)
    hp_urgent_threshold: float = Field(default=0.40, ge=0.0, le=1.0)
    hp_normal_threshold: float = Field(default=0.70, ge=0.0, le=1.0)
    
    # SP thresholds
    sp_critical_threshold: float = Field(default=0.10, ge=0.0, le=1.0)
    sp_normal_threshold: float = Field(default=0.40, ge=0.0, le=1.0)
    
    # Item efficiency preferences
    prefer_percentage_items: bool = True
    use_emergency_items_only_in_danger: bool = True
    avoid_overhealing: bool = True
    overheal_tolerance: float = Field(default=0.15, ge=0.0, le=0.5)
    
    # Situational overrides
    mvp_hp_threshold: float = Field(default=0.50, ge=0.0, le=1.0)
    woe_hp_threshold: float = Field(default=0.60, ge=0.0, le=1.0)


class RecoveryDecision(BaseModel):
    """Decision to use recovery item."""
    
    item: RecoveryItem
    reason: str
    priority: int
    expected_recovery: int


class RestockRecommendation(BaseModel):
    """Recommendation to restock items."""
    
    item_name: str
    current_quantity: int
    recommended_quantity: int
    urgency: str  # "critical", "high", "normal"
    reason: str


class RecoveryAction(BaseModel):
    """Action to use a recovery item."""
    
    item_id: int
    item_name: str
    recovery_type: RecoveryType
    target_stat: str  # "hp" or "sp"
    priority: int


class RecoveryManager:
    """
    Intelligent recovery item usage.
    
    Features:
    - Weight-aware item selection (light potions for weight-limited)
    - Cost-effectiveness calculations
    - Cooldown tracking across item groups
    - Situational threshold adjustment
    - Emergency detection and instant use
    - Pre-emptive recovery during travel
    """
    
    def __init__(
        self,
        config: Optional[RecoveryConfig] = None,
        data_path: Optional[Path] = None,
    ):
        """
        Initialize recovery manager.
        
        Args:
            config: Recovery configuration
            data_path: Path to recovery items JSON file
        """
        self.log = structlog.get_logger(__name__)
        self.config = config or RecoveryConfig()
        self.items_database: Dict[int, RecoveryItem] = {}
        self.cooldowns: Dict[str, datetime] = {}
        self.usage_history: List[tuple[int, datetime, int]] = []
        self.inventory: Dict[int, int] = {}  # item_id -> quantity
        
        # Load recovery items database
        if data_path:
            self._load_items_database(data_path)
        else:
            # Add default test data
            self._load_default_items()
        
        self.log.info("RecoveryManager initialized")
    
    def _load_default_items(self) -> None:
        """Load default recovery items for testing."""
        default_items = {
            501: RecoveryItem(
                item_id=501, item_name="Red Potion", recovery_type=RecoveryType.HP_INSTANT,
                base_recovery=45, weight=7, price=50, cooldown_group="potion"
            ),
            502: RecoveryItem(
                item_id=502, item_name="Orange Potion", recovery_type=RecoveryType.HP_INSTANT,
                base_recovery=105, weight=10, price=200, cooldown_group="potion"
            ),
            503: RecoveryItem(
                item_id=503, item_name="Yellow Potion", recovery_type=RecoveryType.HP_INSTANT,
                base_recovery=175, weight=13, price=550, cooldown_group="potion"
            ),
            504: RecoveryItem(
                item_id=504, item_name="White Potion", recovery_type=RecoveryType.HP_INSTANT,
                base_recovery=325, weight=15, price=1200, cooldown_group="potion"
            ),
            505: RecoveryItem(
                item_id=505, item_name="Blue Potion", recovery_type=RecoveryType.SP_INSTANT,
                base_recovery=60, weight=15, price=5000, cooldown_group="potion"
            ),
            607: RecoveryItem(
                item_id=607, item_name="Yggdrasil Berry", recovery_type=RecoveryType.EMERGENCY,
                percentage_recovery=1.0, weight=30, price=500000, cooldown_group="yggdrasil"
            ),
            608: RecoveryItem(
                item_id=608, item_name="Yggdrasil Seed", recovery_type=RecoveryType.HP_SP_COMBO,
                percentage_recovery=0.5, weight=20, price=50000, cooldown_group="yggdrasil"
            ),
        }
        self.items_database = default_items
    
    def _load_items_database(self, data_path: Path) -> None:
        """
        Load recovery item definitions from JSON file.
        
        Args:
            data_path: Path to recovery_items.json
        """
        try:
            with open(data_path, "r") as f:
                data = json.load(f)
            
            for item_id_str, item_data in data.items():
                item_id = int(item_id_str) if item_id_str.isdigit() else item_data.get("item_id")
                
                self.items_database[item_id] = RecoveryItem(**item_data)
            
            self.log.info(
                "Loaded recovery items database",
                item_count=len(self.items_database),
            )
        except Exception as e:
            self.log.error("Failed to load recovery database", error=str(e))
    
    async def evaluate_recovery_need(
        self,
        hp_percent: float,
        sp_percent: float,
        situation: str = "normal",
        in_combat: bool = False,
    ) -> Optional[RecoveryDecision]:
        """
        Determine if recovery is needed and what to use.
        
        Considers:
        - Current HP/SP percentages
        - Combat situation (incoming damage)
        - Available items and their efficiency
        - Weight constraints
        
        Args:
            hp_percent: Current HP as percentage (0.0 to 1.0)
            sp_percent: Current SP as percentage (0.0 to 1.0)
            situation: Current situation (normal, mvp, woe, etc.)
            in_combat: Whether currently in combat
            
        Returns:
            Recovery decision or None if no recovery needed
        """
        # Adjust thresholds based on situation
        hp_threshold = self._get_hp_threshold(situation)
        sp_threshold = self.config.sp_normal_threshold
        
        # Check emergency HP
        if hp_percent <= self.config.hp_critical_threshold:
            return await self.emergency_recovery()
        
        # Check HP recovery need
        if hp_percent <= hp_threshold:
            item = await self.select_optimal_item(
                RecoveryType.HP_INSTANT,
                hp_percent,
                situation,
            )
            if item:
                return RecoveryDecision(
                    item=item,
                    reason=f"HP at {hp_percent:.1%}",
                    priority=self._calculate_priority(hp_percent, "hp"),
                    expected_recovery=self._calculate_recovery(item, 1.0),
                )
        
        # Check SP recovery need
        if sp_percent <= sp_threshold:
            item = await self.select_optimal_item(
                RecoveryType.SP_INSTANT,
                sp_percent,
                situation,
            )
            if item:
                return RecoveryDecision(
                    item=item,
                    reason=f"SP at {sp_percent:.1%}",
                    priority=self._calculate_priority(sp_percent, "sp"),
                    expected_recovery=self._calculate_recovery(item, 1.0),
                )
        
        return None
    
    def _get_hp_threshold(self, situation: str) -> float:
        """Get HP threshold based on situation."""
        if situation == "mvp":
            return self.config.mvp_hp_threshold
        elif situation == "woe":
            return self.config.woe_hp_threshold
        else:
            return self.config.hp_normal_threshold
    
    def _calculate_priority(self, percent: float, stat: str) -> int:
        """Calculate priority based on remaining percentage."""
        if stat == "hp":
            if percent <= self.config.hp_critical_threshold:
                return 10
            elif percent <= self.config.hp_urgent_threshold:
                return 8
            else:
                return 5
        else:  # SP
            if percent <= self.config.sp_critical_threshold:
                return 7
            else:
                return 4
    
    def _calculate_recovery(self, item: RecoveryItem, max_value: float) -> int:
        """Calculate expected recovery amount."""
        if item.percentage_recovery > 0:
            return int(max_value * item.percentage_recovery)
        return item.base_recovery
    
    async def select_optimal_item(
        self,
        recovery_type: RecoveryType,
        current_percent: float,
        situation: str = "normal",
    ) -> Optional[RecoveryItem]:
        """
        Select most efficient item for recovery.
        
        Avoids:
        - Overhealing (wasting item value)
        - Using expensive items when cheap ones suffice
        - Using heavy items when weight-limited
        
        Args:
            recovery_type: Type of recovery needed
            current_percent: Current HP/SP percentage
            situation: Current situation
            
        Returns:
            Best recovery item or None
        """
        # Get available items of this type
        available = [
            item for item in self.items_database.values()
            if self._is_type_compatible(item.recovery_type, recovery_type)
            and self._is_available(item.item_id)
            and not self._is_on_cooldown(item.cooldown_group)
        ]
        
        if not available:
            return None
        
        # Calculate efficiency for each item
        scored_items: List[tuple[RecoveryItem, float]] = []
        
        for item in available:
            efficiency = self._calculate_efficiency(
                item,
                current_percent,
                situation,
            )
            scored_items.append((item, efficiency))
        
        # Sort by efficiency (higher is better)
        scored_items.sort(key=lambda x: x[1], reverse=True)
        
        return scored_items[0][0] if scored_items else None
    
    def _is_type_compatible(
        self,
        item_type: RecoveryType,
        needed_type: RecoveryType,
    ) -> bool:
        """Check if item type matches needed recovery."""
        if item_type == needed_type:
            return True
        
        # HP_SP_COMBO works for both
        if item_type == RecoveryType.HP_SP_COMBO:
            return needed_type in (RecoveryType.HP_INSTANT, RecoveryType.SP_INSTANT)
        
        # EMERGENCY works for HP
        if item_type == RecoveryType.EMERGENCY:
            return needed_type == RecoveryType.HP_INSTANT
        
        return False
    
    def _is_available(self, item_id: int) -> bool:
        """Check if item is in inventory."""
        # If not tracking inventory, assume items are available
        if not self.inventory:
            return True
        return self.inventory.get(item_id, 0) > 0
    
    def _is_on_cooldown(self, cooldown_group: str) -> bool:
        """Check if cooldown group is on cooldown."""
        if cooldown_group not in self.cooldowns:
            return False
        
        return datetime.now() < self.cooldowns[cooldown_group]
    
    def _calculate_efficiency(
        self,
        item: RecoveryItem,
        current_percent: float,
        situation: str,
    ) -> float:
        """
        Calculate item efficiency score.
        
        Higher score = better choice.
        """
        score = 0.0
        
        # Base recovery value
        recovery_value = (
            item.percentage_recovery
            if item.percentage_recovery > 0
            else item.base_recovery / 1000.0
        )
        score += recovery_value * 10
        
        # Penalize overhealing
        if self.config.avoid_overhealing:
            needed = 1.0 - current_percent
            if recovery_value > needed + self.config.overheal_tolerance:
                score *= 0.5  # Heavy penalty for overhealing
        
        # Cost efficiency (cheaper is better)
        if item.price > 0:
            score += 1000.0 / item.price
        
        # Weight efficiency (lighter is better)
        if item.weight > 0:
            score += 100.0 / item.weight
        
        return score
    
    async def track_cooldowns(self) -> Dict[str, float]:
        """
        Track cooldowns for all item groups.
        
        Returns:
            Dict of cooldown_group -> remaining seconds
        """
        now = datetime.now()
        remaining: Dict[str, float] = {}
        
        for group, expires_at in self.cooldowns.items():
            if expires_at > now:
                remaining[group] = (expires_at - now).total_seconds()
        
        return remaining
    
    async def manage_inventory_levels(self) -> List[RestockRecommendation]:
        """
        Monitor recovery item inventory.
        
        Recommend restocking based on:
        - Current map/activity
        - Burn rate (usage frequency)
        - Storage availability
        
        Returns:
            List of restock recommendations
        """
        recommendations: List[RestockRecommendation] = []
        
        # Calculate burn rate
        burn_rates = self._calculate_burn_rates()
        
        for item_id, item in self.items_database.items():
            current_qty = self.inventory.get(item_id, 0)
            burn_rate = burn_rates.get(item_id, 0.0)
            
            # Estimate needed quantity (1 hour worth)
            needed_per_hour = int(burn_rate * 60)
            recommended = max(100, needed_per_hour)
            
            if current_qty < recommended * 0.2:  # < 20% of recommended
                recommendations.append(
                    RestockRecommendation(
                        item_name=item.item_name,
                        current_quantity=current_qty,
                        recommended_quantity=recommended,
                        urgency="critical" if current_qty < 10 else "high",
                        reason=f"Burn rate: {burn_rate:.1f}/min",
                    )
                )
        
        return recommendations
    
    def _calculate_burn_rates(self) -> Dict[int, float]:
        """Calculate usage rate per minute for each item."""
        rates: Dict[int, float] = {}
        
        # Look at last hour of history
        cutoff = datetime.now() - timedelta(hours=1)
        recent_uses = [
            (item_id, timestamp)
            for item_id, timestamp, _ in self.usage_history
            if timestamp >= cutoff
        ]
        
        # Count uses per item
        for item_id, _ in recent_uses:
            rates[item_id] = rates.get(item_id, 0.0) + 1.0
        
        # Convert to per-minute rate
        elapsed_minutes = 60.0
        return {item_id: count / elapsed_minutes for item_id, count in rates.items()}
    
    async def emergency_recovery(self) -> Optional[RecoveryDecision]:
        """
        Emergency recovery when about to die.
        
        Use best available regardless of efficiency.
        Consider Yggdrasil Berry/Seed priority.
        
        Returns:
            Recovery decision with emergency item
        """
        # Priority order for emergency
        emergency_types = [
            RecoveryType.EMERGENCY,      # Yggdrasil Berry
            RecoveryType.HP_SP_COMBO,    # Yggdrasil Seed
            RecoveryType.HP_PERCENT,     # Condensed potions
            RecoveryType.HP_INSTANT,     # Regular potions
        ]
        
        for recovery_type in emergency_types:
            available = [
                item for item in self.items_database.values()
                if item.recovery_type == recovery_type
                and self._is_available(item.item_id)
            ]
            
            if available:
                # Use highest recovery item
                best = max(
                    available,
                    key=lambda i: i.percentage_recovery or i.base_recovery,
                )
                
                self.log.warning(
                    "EMERGENCY RECOVERY",
                    item=best.item_name,
                    type=best.recovery_type,
                )
                
                return RecoveryDecision(
                    item=best,
                    reason="EMERGENCY - Critical HP",
                    priority=10,
                    expected_recovery=self._calculate_recovery(best, 1.0),
                )
        
        self.log.critical("NO EMERGENCY ITEMS AVAILABLE")
        return None
    
    def use_item(
        self,
        item_id: int,
        recovery_amount: int,
    ) -> None:
        """
        Record item usage.
        
        Args:
            item_id: Item used
            recovery_amount: Actual recovery amount
        """
        if item_id not in self.items_database:
            return
        
        item = self.items_database[item_id]
        
        # Update inventory
        if item_id in self.inventory:
            self.inventory[item_id] -= 1
        
        # Set cooldown
        cooldown_until = datetime.now() + timedelta(seconds=item.cooldown_seconds)
        self.cooldowns[item.cooldown_group] = cooldown_until
        
        # Record usage
        self.usage_history.append((item_id, datetime.now(), recovery_amount))
        
        # Limit history size
        if len(self.usage_history) > 1000:
            self.usage_history = self.usage_history[-500:]
        
        self.log.debug(
            "Recovery item used",
            item=item.item_name,
            recovery=recovery_amount,
        )
    
    def update_inventory(self, inventory: Dict[int, int]) -> None:
        """
        Update inventory from game state.
        
        Args:
            inventory: Dict of item_id -> quantity
        """
        self.inventory = inventory