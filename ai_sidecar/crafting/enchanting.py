"""
Equipment enchanting system for OpenKore AI.

Provides comprehensive enchanting for multiple systems including Mora,
Malangdo, Temporal boots, Instance, and other enchanting types.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.crafting.core import CraftingManager, Material

logger = structlog.get_logger(__name__)


class EnchantType(str, Enum):
    """Types of enchants"""
    MORA = "mora"
    MALANGDO = "malangdo"
    TEMPORAL = "temporal"
    INSTANCE = "instance"
    EDEN = "eden"
    COSTUME = "costume"
    SHADOW = "shadow"


class EnchantSlot(str, Enum):
    """Enchant slot positions"""
    SLOT_1 = "slot_1"
    SLOT_2 = "slot_2"
    SLOT_3 = "slot_3"
    SLOT_4 = "slot_4"


class EnchantOption(BaseModel):
    """Single enchant option"""
    
    model_config = ConfigDict(frozen=True)
    
    enchant_id: int
    enchant_name: str
    stat_bonus: Dict[str, int] = Field(default_factory=dict)  # {"str": 5, "atk": 10}
    weight: int  # Probability weight
    is_desirable: bool = False  # AI preference
    min_refine: int = 0  # Minimum refine required
    
    @property
    def total_stat_value(self) -> int:
        """Calculate total stat value"""
        return sum(abs(v) for v in self.stat_bonus.values())


class EnchantPool(BaseModel):
    """Pool of possible enchants for an item"""
    
    model_config = ConfigDict(frozen=True)
    
    item_id: int
    item_name: str
    enchant_type: EnchantType
    slot: EnchantSlot
    possible_enchants: List[EnchantOption]
    cost_zeny: int = 0
    cost_items: List[Material] = Field(default_factory=list)
    can_reset: bool = True
    reset_cost_zeny: int = 0
    
    @property
    def total_weight(self) -> int:
        """Calculate total weight of all enchants"""
        return sum(e.weight for e in self.possible_enchants)
    
    @property
    def has_desirable_enchants(self) -> bool:
        """Check if pool has any desirable enchants"""
        return any(e.is_desirable for e in self.possible_enchants)


class EnchantingManager:
    """
    Equipment enchanting system.
    
    Features:
    - Multiple enchant systems
    - Slot management
    - Probability tracking
    - Reset functionality
    """
    
    def __init__(self, data_dir: Path, crafting_manager: CraftingManager):
        """
        Initialize enchanting manager.
        
        Args:
            data_dir: Directory containing enchant data files
            crafting_manager: Core crafting manager instance
        """
        self.log = logger.bind(component="enchanting_manager")
        self.data_dir = Path(data_dir)
        self.crafting = crafting_manager
        self.enchant_pools: Dict[Tuple[int, EnchantSlot], EnchantPool] = {}
        self._load_enchant_data()
    
    def _load_enchant_data(self) -> None:
        """Load enchant definitions from data files"""
        enchant_file = self.data_dir / "enchants.json"
        if not enchant_file.exists():
            self.log.warning("enchant_data_missing", file=str(enchant_file))
            return
        
        try:
            with open(enchant_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load different enchant systems
            for system_name, system_data in data.items():
                if not isinstance(system_data, dict):
                    continue
                
                enchant_type = self._parse_enchant_type(system_name)
                if not enchant_type:
                    continue
                
                for item_key, item_data in system_data.items():
                    if not isinstance(item_data, dict):
                        continue
                    
                    self._parse_item_enchants(
                        item_data, enchant_type
                    )
            
            self.log.info("enchant_pools_loaded", count=len(self.enchant_pools))
        except Exception as e:
            self.log.error("enchant_data_load_error", error=str(e))
    
    def _parse_enchant_type(self, name: str) -> Optional[EnchantType]:
        """Parse enchant type from system name"""
        name_lower = name.lower()
        for enchant_type in EnchantType:
            if enchant_type.value in name_lower:
                return enchant_type
        return None
    
    def _parse_item_enchants(
        self,
        data: dict,
        enchant_type: EnchantType
    ) -> None:
        """Parse enchants for a specific item"""
        item_id = data.get("item_id", 0)
        item_name = data.get("item_name", "Unknown")
        
        for slot_name, slot_data in data.get("slots", {}).items():
            slot = EnchantSlot(slot_name)
            
            enchants = [
                EnchantOption(**e) for e in slot_data.get("enchants", [])
            ]
            
            cost_items = [
                Material(**m) for m in slot_data.get("cost_items", [])
            ]
            
            pool = EnchantPool(
                item_id=item_id,
                item_name=item_name,
                enchant_type=enchant_type,
                slot=slot,
                possible_enchants=enchants,
                cost_zeny=slot_data.get("cost_zeny", 0),
                cost_items=cost_items,
                can_reset=slot_data.get("can_reset", True),
                reset_cost_zeny=slot_data.get("reset_cost_zeny", 0),
            )
            
            self.enchant_pools[(item_id, slot)] = pool
    
    def get_enchant_options(
        self,
        item_id: int,
        slot: EnchantSlot
    ) -> List[EnchantOption]:
        """
        Get possible enchants for item slot.
        
        Args:
            item_id: Item identifier
            slot: Enchant slot
            
        Returns:
            List of possible enchants
        """
        pool = self.enchant_pools.get((item_id, slot))
        return pool.possible_enchants if pool else []
    
    def calculate_enchant_probability(
        self,
        enchant_id: int,
        item_id: int,
        slot: EnchantSlot
    ) -> float:
        """
        Calculate probability of getting specific enchant.
        
        Args:
            enchant_id: Target enchant ID
            item_id: Item to enchant
            slot: Enchant slot
            
        Returns:
            Probability as percentage (0-100)
        """
        pool = self.enchant_pools.get((item_id, slot))
        if not pool:
            return 0.0
        
        # Find target enchant
        target_enchant = None
        for enchant in pool.possible_enchants:
            if enchant.enchant_id == enchant_id:
                target_enchant = enchant
                break
        
        if not target_enchant:
            return 0.0
        
        # Calculate probability based on weight
        if pool.total_weight == 0:
            return 0.0
        
        probability = (target_enchant.weight / pool.total_weight) * 100
        return probability
    
    def get_expected_attempts(
        self,
        target_enchant_id: int,
        item_id: int,
        slot: EnchantSlot
    ) -> int:
        """
        Calculate expected attempts for target enchant.
        
        Args:
            target_enchant_id: Target enchant ID
            item_id: Item to enchant
            slot: Enchant slot
            
        Returns:
            Expected number of attempts
        """
        probability = self.calculate_enchant_probability(
            target_enchant_id, item_id, slot
        )
        
        if probability <= 0:
            return 0
        
        # Expected attempts = 1 / probability
        return int(100 / probability) if probability > 0 else 0
    
    def get_enchant_cost(
        self,
        item_id: int,
        slot: EnchantSlot
    ) -> dict:
        """
        Get cost for single enchant attempt.
        
        Args:
            item_id: Item to enchant
            slot: Enchant slot
            
        Returns:
            Cost breakdown dict
        """
        pool = self.enchant_pools.get((item_id, slot))
        if not pool:
            return {"error": "Enchant pool not found"}
        
        return {
            "zeny": pool.cost_zeny,
            "items": [
                {
                    "item_id": m.item_id,
                    "item_name": m.item_name,
                    "quantity": m.quantity_required,
                }
                for m in pool.cost_items
            ],
            "can_reset": pool.can_reset,
            "reset_cost": pool.reset_cost_zeny,
        }
    
    def should_reset_enchant(
        self,
        current_enchants: List[int],
        target_enchants: List[int],
        item_id: int
    ) -> bool:
        """
        Decide if should reset enchants.
        
        Args:
            current_enchants: Current enchant IDs
            target_enchants: Target enchant IDs
            item_id: Item identifier
            
        Returns:
            True if should reset
        """
        # Check if any current enchants match targets
        matches = set(current_enchants) & set(target_enchants)
        
        # If we have some matches, evaluate if we should keep trying
        if matches:
            match_ratio = len(matches) / len(target_enchants)
            # Keep if we have >50% of target enchants
            return match_ratio < 0.5
        
        # No matches, should reset if we have undesirable enchants
        return True
    
    def get_optimal_enchant_strategy(
        self,
        item_id: int,
        character_state: dict,
        budget: int
    ) -> dict:
        """
        Get optimal enchanting strategy.
        
        Args:
            item_id: Item to enchant
            character_state: Character stats and build
            budget: Zeny budget
            
        Returns:
            Strategy dict with recommendations
        """
        # Find all slots for this item
        item_pools = [
            pool for (iid, slot), pool in self.enchant_pools.items()
            if iid == item_id
        ]
        
        if not item_pools:
            return {"error": "No enchant pools found for item"}
        
        recommendations = []
        total_cost = 0
        
        for pool in item_pools:
            # Find most desirable enchant in this slot
            desirable = [e for e in pool.possible_enchants if e.is_desirable]
            
            if not desirable:
                # Pick highest stat value enchant
                best_enchant = max(
                    pool.possible_enchants,
                    key=lambda e: e.total_stat_value,
                    default=None
                )
            else:
                # Pick desirable with best stats
                best_enchant = max(
                    desirable,
                    key=lambda e: e.total_stat_value
                )
            
            if not best_enchant:
                continue
            
            # Calculate expected cost
            expected_attempts = self.get_expected_attempts(
                best_enchant.enchant_id, item_id, pool.slot
            )
            
            slot_cost = expected_attempts * pool.cost_zeny
            total_cost += slot_cost
            
            recommendations.append({
                "slot": pool.slot.value,
                "target_enchant": best_enchant.enchant_name,
                "enchant_id": best_enchant.enchant_id,
                "probability": self.calculate_enchant_probability(
                    best_enchant.enchant_id, item_id, pool.slot
                ),
                "expected_attempts": expected_attempts,
                "cost_per_attempt": pool.cost_zeny,
                "expected_cost": slot_cost,
                "stat_bonus": best_enchant.stat_bonus,
            })
        
        affordable = total_cost <= budget
        
        return {
            "item_id": item_id,
            "total_expected_cost": total_cost,
            "budget": budget,
            "affordable": affordable,
            "recommendations": recommendations,
        }
    
    def get_statistics(self) -> dict:
        """
        Get enchanting statistics.
        
        Returns:
            Statistics dictionary
        """
        type_counts = {}
        resetable = 0
        total_enchants = 0
        
        for pool in self.enchant_pools.values():
            type_counts[pool.enchant_type] = type_counts.get(
                pool.enchant_type, 0
            ) + 1
            if pool.can_reset:
                resetable += 1
            total_enchants += len(pool.possible_enchants)
        
        return {
            "total_pools": len(self.enchant_pools),
            "by_enchant_type": type_counts,
            "resetable_pools": resetable,
            "total_enchant_options": total_enchants,
        }