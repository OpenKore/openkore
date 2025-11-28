"""
Food Buff Management System.

Provides intelligent food buff optimization based on character builds,
duration tracking, and stacking management for Ragnarok Online.
"""

import json
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class FoodCategory(str, Enum):
    """Categories of food items."""
    
    STAT_FOOD = "stat_food"                       # +STR, +AGI food
    COOKING = "cooking"                           # Player-crafted cooking
    CASH_FOOD = "cash_food"                       # Cash shop food (Gym Pass, etc.)
    EVENT_FOOD = "event_food"                     # Event-limited food
    ELEMENTAL_RESISTANCE = "elemental_resistance"  # Resistance food


class FoodItem(BaseModel):
    """Food item definition."""
    
    item_id: int
    item_name: str
    category: FoodCategory
    stat_bonuses: Dict[str, int] = Field(default_factory=dict)
    duration_seconds: float = 1200.0  # 20 minutes default
    cooldown_group: str = "food"
    stacks_with: List[str] = Field(default_factory=list)
    overrides: List[str] = Field(default_factory=list)
    weight: int = 1
    price: int = 0


class FoodBuff(BaseModel):
    """Active food buff state."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    item_id: int
    item_name: str
    category: FoodCategory
    stat_bonuses: Dict[str, int]
    applied_time: datetime
    duration_seconds: float
    remaining_seconds: float = Field(ge=0)
    
    @property
    def is_expiring_soon(self) -> bool:
        """Check if food buff is expiring soon (< 2 minutes)."""
        return self.remaining_seconds <= 120.0
    
    @property
    def is_expired(self) -> bool:
        """Check if food buff has expired."""
        return self.remaining_seconds <= 0
    
    @property
    def duration_percentage(self) -> float:
        """Get remaining duration as percentage."""
        if self.duration_seconds <= 0:
            return 0.0
        return max(0.0, min(1.0, self.remaining_seconds / self.duration_seconds))


class FoodAction(BaseModel):
    """Action to use food."""
    
    item_id: int
    item_name: str
    reason: str
    priority: int = 5


class FoodManager:
    """
    Intelligent food buff management.
    
    Features:
    - Stat synergy optimization (match food to build)
    - Duration tracking with expiration alerts
    - Stacking optimization (maximize non-conflicting food)
    - Event food usage during limited time
    - Cost-efficient food selection
    """
    
    def __init__(self, data_path: Optional[Path] = None):
        """
        Initialize food manager.
        
        Args:
            data_path: Path to food items JSON file
        """
        self.log = structlog.get_logger(__name__)
        self.food_database: Dict[int, FoodItem] = {}
        self.active_food_buffs: Dict[int, FoodBuff] = {}
        self.inventory: Dict[int, int] = {}
        
        # Load food database
        if data_path:
            self._load_food_database(data_path)
        
        self.log.info("FoodManager initialized")
    
    def _load_food_database(self, data_path: Path) -> None:
        """
        Load food item definitions from JSON file.
        
        Args:
            data_path: Path to food_items.json
        """
        try:
            with open(data_path, "r") as f:
                data = json.load(f)
            
            for item_id_str, item_data in data.items():
                item_id = int(item_id_str) if item_id_str.isdigit() else item_data.get("item_id")
                
                self.food_database[item_id] = FoodItem(**item_data)
            
            self.log.info(
                "Loaded food database",
                food_count=len(self.food_database),
            )
        except Exception as e:
            self.log.error("Failed to load food database", error=str(e))
    
    async def get_optimal_food_set(
        self,
        character_build: str,
    ) -> List[FoodItem]:
        """
        Recommend food based on build.
        
        Build-specific recommendations:
        - Physical DPS: STR/ATK food
        - Caster: INT/MATK food
        - Tank: VIT/DEF food
        - Hybrid: Balanced selection
        
        Args:
            character_build: Character build type
            
        Returns:
            List of recommended food items
        """
        recommendations: List[FoodItem] = []
        
        # Define stat priorities per build
        build_priorities = {
            "melee_dps": ["str", "atk", "agi", "aspd"],
            "magic_dps": ["int", "matk", "dex"],
            "tank": ["vit", "def", "mdef", "max_hp"],
            "support": ["int", "dex", "matk"],
            "hybrid": ["str", "int", "dex"],
        }
        
        priorities = build_priorities.get(character_build, ["str", "agi", "dex"])
        
        # Score each food item
        scored_foods: List[tuple[FoodItem, float]] = []
        
        for food in self.food_database.values():
            score = 0.0
            
            # Score based on stat bonuses matching priorities
            for stat, bonus in food.stat_bonuses.items():
                if stat.lower() in priorities:
                    priority_index = priorities.index(stat.lower())
                    # Higher score for higher priority stats
                    score += bonus * (len(priorities) - priority_index)
            
            if score > 0:
                scored_foods.append((food, score))
        
        # Sort by score and take top foods
        scored_foods.sort(key=lambda x: x[1], reverse=True)
        
        # Select non-conflicting foods
        selected: Set[str] = set()
        for food, _ in scored_foods:
            # Check if conflicts with already selected
            if not any(override in selected for override in food.overrides):
                recommendations.append(food)
                selected.add(food.item_name)
                
                # Limit to reasonable number
                if len(recommendations) >= 5:
                    break
        
        return recommendations
    
    async def track_food_buffs(self) -> List[FoodBuff]:
        """
        Track all active food buffs and durations.
        
        Returns:
            List of active food buffs
        """
        return list(self.active_food_buffs.values())
    
    async def check_food_needs(self) -> List[FoodAction]:
        """
        Determine which food buffs need refreshing.
        
        Returns:
            List of food actions to refresh
        """
        actions: List[FoodAction] = []
        
        for item_id, buff in self.active_food_buffs.items():
            if buff.is_expiring_soon and item_id in self.inventory:
                if self.inventory[item_id] > 0:
                    actions.append(
                        FoodAction(
                            item_id=item_id,
                            item_name=buff.item_name,
                            reason=f"Expiring soon ({buff.remaining_seconds:.0f}s left)",
                            priority=3,
                        )
                    )
        
        return actions
    
    async def update_food_timers(self, elapsed_seconds: float) -> None:
        """
        Update all food buff durations.
        
        Args:
            elapsed_seconds: Time elapsed since last update
        """
        expired: List[int] = []
        
        for item_id, buff in self.active_food_buffs.items():
            buff.remaining_seconds = max(0, buff.remaining_seconds - elapsed_seconds)
            
            if buff.is_expired:
                expired.append(item_id)
                self.log.debug("Food buff expired", food=buff.item_name)
        
        # Remove expired buffs
        for item_id in expired:
            del self.active_food_buffs[item_id]
    
    def apply_food(self, item_id: int) -> bool:
        """
        Apply a food buff.
        
        Args:
            item_id: Food item to use
            
        Returns:
            True if applied successfully
        """
        if item_id not in self.food_database:
            self.log.warning("Unknown food item", item_id=item_id)
            return False
        
        if item_id not in self.inventory or self.inventory[item_id] <= 0:
            self.log.warning("Food not in inventory", item_id=item_id)
            return False
        
        food = self.food_database[item_id]
        
        # Check for conflicting food
        for override in food.overrides:
            # Find and remove overridden food
            for active_id, active_buff in list(self.active_food_buffs.items()):
                if active_buff.item_name == override:
                    del self.active_food_buffs[active_id]
                    self.log.debug(
                        "Food overridden",
                        old=override,
                        new=food.item_name,
                    )
        
        # Apply new food buff
        buff = FoodBuff(
            item_id=item_id,
            item_name=food.item_name,
            category=food.category,
            stat_bonuses=food.stat_bonuses,
            applied_time=datetime.now(),
            duration_seconds=food.duration_seconds,
            remaining_seconds=food.duration_seconds,
        )
        
        self.active_food_buffs[item_id] = buff
        
        # Update inventory
        self.inventory[item_id] -= 1
        
        self.log.info(
            "Food applied",
            food=food.item_name,
            bonuses=food.stat_bonuses,
            duration=food.duration_seconds,
        )
        
        return True
    
    def get_active_stat_bonuses(self) -> Dict[str, int]:
        """
        Get total stat bonuses from all active food.
        
        Returns:
            Dict of stat -> total bonus
        """
        total_bonuses: Dict[str, int] = {}
        
        for buff in self.active_food_buffs.values():
            for stat, bonus in buff.stat_bonuses.items():
                total_bonuses[stat] = total_bonuses.get(stat, 0) + bonus
        
        return total_bonuses
    
    def get_food_summary(self) -> Dict[str, Any]:
        """
        Get summary of active food buffs.
        
        Returns:
            Dict with active food information
        """
        return {
            "total_active": len(self.active_food_buffs),
            "expiring_soon": len([
                b for b in self.active_food_buffs.values()
                if b.is_expiring_soon
            ]),
            "stat_bonuses": self.get_active_stat_bonuses(),
            "active_foods": [
                {
                    "name": buff.item_name,
                    "remaining_seconds": buff.remaining_seconds,
                    "bonuses": buff.stat_bonuses,
                }
                for buff in self.active_food_buffs.values()
            ],
        }
    
    def update_inventory(self, inventory: Dict[int, int]) -> None:
        """
        Update food inventory from game state.
        
        Args:
            inventory: Dict of item_id -> quantity
        """
        # Filter to only food items
        self.inventory = {
            item_id: qty
            for item_id, qty in inventory.items()
            if item_id in self.food_database
        }
    
    def has_food_buff(self, item_name: str) -> bool:
        """
        Check if a specific food buff is active.
        
        Args:
            item_name: Name of food to check
            
        Returns:
            True if food buff is active
        """
        return any(
            buff.item_name == item_name
            for buff in self.active_food_buffs.values()
        )
    
    def get_missing_food(
        self,
        recommended: List[FoodItem],
    ) -> List[FoodItem]:
        """
        Get food from recommendations that isn't active.
        
        Args:
            recommended: List of recommended food items
            
        Returns:
            List of food items not currently active
        """
        return [
            food for food in recommended
            if not self.has_food_buff(food.item_name)
        ]