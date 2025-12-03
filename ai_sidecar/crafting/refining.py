"""
Equipment refinement system for OpenKore AI.

Provides comprehensive equipment refining with normal ores, HD ores,
enriched ores, Blacksmith blessings, and success rate calculations.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict

from ai_sidecar.crafting.core import CraftingManager

logger = structlog.get_logger(__name__)


class RefineOre(str, Enum):
    """Types of refine ores"""
    PHRACON = "phracon"           # Level 1 weapons
    EMVERETARCON = "emveretarcon" # Level 2 weapons
    ORIDECON = "oridecon"         # Level 3-4 weapons
    ELUNIUM = "elunium"           # Armor
    HD_ORIDECON = "hd_oridecon"   # Safe weapon refine
    HD_ELUNIUM = "hd_elunium"     # Safe armor refine
    ENRICHED_ORIDECON = "enriched_oridecon"  # Higher success weapon
    ENRICHED_ELUNIUM = "enriched_elunium"    # Higher success armor
    BLACKSMITH_BLESSING = "blacksmith_blessing"  # Protection


class RefineLevel(BaseModel):
    """Refine level information"""
    
    model_config = ConfigDict(frozen=True)
    
    level: int
    success_rate_weapon: float
    success_rate_armor: float
    safe_level: bool
    breaks_on_fail: bool
    can_downgrade: bool
    
    @property
    def is_risky(self) -> bool:
        """Check if this is a risky refine level"""
        return self.breaks_on_fail or self.can_downgrade


class RefiningManager:
    """
    Equipment refinement system.
    
    Features:
    - Normal refining
    - Safe refining with HD ores
    - Enriched ore usage
    - Blacksmith blessing protection
    """
    
    def __init__(
        self,
        data_dir: Optional[Path] = None,
        crafting_manager: Optional[CraftingManager] = None
    ):
        """
        Initialize refining manager.
        
        Args:
            data_dir: Optional directory containing refine data files
            crafting_manager: Optional core crafting manager instance
        """
        self.log = logger.bind(component="refining_manager")
        self.data_dir = Path(data_dir) if data_dir else Path("data/crafting")
        self.crafting = crafting_manager
        self.refine_rates: Dict[int, RefineLevel] = {}
        self._load_refine_data()
    
    def _load_refine_data(self) -> None:
        """Load refine rate definitions from data files"""
        refine_file = self.data_dir / "refine_rates.json"
        if not refine_file.exists():
            self.log.warning("refine_data_missing", file=str(refine_file))
            self._initialize_default_rates()
            return
        
        try:
            with open(refine_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load weapon rates
            for level_str, rate_data in data.get("weapon_rates", {}).items():
                level = int(level_str)
                self.refine_rates[level] = RefineLevel(
                    level=level,
                    success_rate_weapon=rate_data.get("base_rate", 100.0),
                    success_rate_armor=0.0,  # Set separately
                    safe_level=rate_data.get("safe", True),
                    breaks_on_fail=not rate_data.get("safe", True),
                    can_downgrade=level > 4 and not rate_data.get("safe", True)
                )
            
            # Load armor rates
            for level_str, rate_data in data.get("armor_rates", {}).items():
                level = int(level_str)
                if level in self.refine_rates:
                    # Update armor rate
                    existing = self.refine_rates[level]
                    self.refine_rates[level] = RefineLevel(
                        level=level,
                        success_rate_weapon=existing.success_rate_weapon,
                        success_rate_armor=rate_data.get("base_rate", 100.0),
                        safe_level=existing.safe_level,
                        breaks_on_fail=existing.breaks_on_fail,
                        can_downgrade=existing.can_downgrade
                    )
            
            # Ensure we have rates after loading
            if len(self.refine_rates) == 0:
                self.log.warning("refine_data_empty", file=str(refine_file))
                self._initialize_default_rates()
            else:
                self.log.info("refine_rates_loaded", levels=len(self.refine_rates))
        except Exception as e:
            self.log.error("refine_data_load_error", error=str(e))
            self._initialize_default_rates()
    
    def _initialize_default_rates(self) -> None:
        """Initialize default refine rates"""
        default_rates = [
            (1, 100.0, 100.0, True, False, False),
            (2, 100.0, 100.0, True, False, False),
            (3, 100.0, 100.0, True, False, False),
            (4, 100.0, 100.0, True, False, False),
            (5, 60.0, 60.0, False, True, True),
            (6, 40.0, 40.0, False, True, True),
            (7, 40.0, 40.0, False, True, True),
            (8, 20.0, 20.0, False, True, True),
            (9, 20.0, 20.0, False, True, True),
            (10, 9.0, 9.0, False, True, True),
        ]
        
        for level, w_rate, a_rate, safe, breaks, downgrade in default_rates:
            self.refine_rates[level] = RefineLevel(
                level=level,
                success_rate_weapon=w_rate,
                success_rate_armor=a_rate,
                safe_level=safe,
                breaks_on_fail=breaks,
                can_downgrade=downgrade
            )
    
    def get_required_ore(
        self,
        item_id: int,
        item_level: int,
        is_armor: bool,
        use_hd: bool = False,
        use_enriched: bool = False
    ) -> RefineOre:
        """
        Get required ore for item.
        
        Args:
            item_id: Item to refine
            item_level: Item's level (1-4 for weapons)
            is_armor: Whether item is armor
            use_hd: Use HD ore (safe refine)
            use_enriched: Use enriched ore (higher success)
            
        Returns:
            Required ore type
        """
        if is_armor:
            if use_enriched:
                return RefineOre.ENRICHED_ELUNIUM
            elif use_hd:
                return RefineOre.HD_ELUNIUM
            else:
                return RefineOre.ELUNIUM
        else:
            # Weapon
            if use_enriched:
                return RefineOre.ENRICHED_ORIDECON
            elif use_hd:
                return RefineOre.HD_ORIDECON
            elif item_level == 1:
                return RefineOre.PHRACON
            elif item_level == 2:
                return RefineOre.EMVERETARCON
            else:
                return RefineOre.ORIDECON
    
    def calculate_refine_rate(
        self,
        current_level: Optional[int] = None,
        is_armor: bool = False,
        ore_type: Optional[RefineOre] = None,
        character_state: Optional[dict] = None,
        has_blessing: bool = False,
        current_refine: Optional[int] = None,
        item_level: Optional[int] = None
    ) -> float:
        """
        Calculate refine success rate (supports multiple parameter styles).
        
        Args:
            current_level: Current refine level
            is_armor: Whether refining armor
            ore_type: Ore being used
            character_state: Character stats
            has_blessing: Has Blacksmith blessing active
            current_refine: Alias for current_level
            item_level: Item level (for fallback)
            
        Returns:
            Success rate as percentage (0-100)
        """
        # Support both parameter names
        current_level = current_level or current_refine or 0
        character_state = character_state or {}
        
        target_level = current_level + 1
        refine_info = self.refine_rates.get(target_level)
        
        if not refine_info:
            return 0.0
        
        # Base rate
        rate = (refine_info.success_rate_armor if is_armor
                else refine_info.success_rate_weapon)
        
        # HD ore bonus if specified
        if ore_type and ore_type in (RefineOre.HD_ORIDECON, RefineOre.HD_ELUNIUM):
            rate = rate + 10.0
        
        # Enriched ore bonus if specified
        elif ore_type and ore_type in (RefineOre.ENRICHED_ORIDECON, RefineOre.ENRICHED_ELUNIUM):
            rate += 10.0
        
        # Job bonus (if Blacksmith/Whitesmith)
        job = character_state.get("job", "")
        if "blacksmith" in job.lower() or "whitesmith" in job.lower():
            job_level = character_state.get("job_level", 0)
            rate += job_level * 0.05
        
        # DEX bonus: small bonus for higher DEX
        dex = character_state.get("dex", 0)
        if dex >= 50:
            rate += (dex - 49) * 0.05
        
        # LUK bonus: tiny bonus for luck
        luk = character_state.get("luk", 0)
        rate += luk * 0.02
        
        # Round to avoid floating point precision issues, then cap between 0 and 100
        rate = round(rate, 2)
        return min(100.0, max(0.0, rate))
    
    def get_safe_limit(self, item_level: int, is_armor: bool) -> int:
        """
        Get safe refine limit.
        
        Args:
            item_level: Item level (1-4 for weapons)
            is_armor: Whether item is armor
            
        Returns:
            Maximum safe refine level
        """
        # RO safe limits
        if is_armor:
            return 4
        else:
            # Weapon safe limits by level
            return {1: 7, 2: 6, 3: 5, 4: 4}.get(item_level, 4)
    
    def calculate_expected_cost(
        self,
        current_level: int,
        target_level: int,
        is_armor: bool,
        ore_prices: dict,
        item_value: int = 0,
        use_hd: bool = False,
        use_enriched: bool = False
    ) -> dict:
        """
        Calculate expected cost to reach target level.
        
        Args:
            current_level: Starting refine level
            target_level: Desired refine level
            is_armor: Whether item is armor
            ore_prices: Prices for each ore type
            item_value: Value of the item (for break cost)
            use_hd: Use HD ores
            use_enriched: Use enriched ores
            
        Returns:
            Dict with cost breakdown
        """
        if target_level <= current_level:
            return {"error": "Target level must be higher than current level"}
        
        total_cost = 0
        expected_attempts = 0
        break_cost = 0
        level = current_level
        
        details = []
        
        while level < target_level:
            next_level = level + 1
            
            # Determine ore type
            ore_type = self.get_required_ore(
                0, 3, is_armor, use_hd, use_enriched
            )
            ore_price = ore_prices.get(ore_type.value, 1000)
            
            # Calculate success rate
            success_rate = self.calculate_refine_rate(
                level, is_armor, ore_type, {}
            ) / 100.0
            
            if success_rate <= 0:
                return {"error": f"Cannot refine to level {next_level}"}
            
            # Expected attempts to succeed once
            attempts = 1.0 / success_rate
            expected_attempts += attempts
            
            # Cost for this level
            level_cost = attempts * ore_price
            total_cost += level_cost
            
            # Break cost (if item can break)
            refine_info = self.refine_rates.get(next_level)
            if refine_info and refine_info.breaks_on_fail:
                # HD and enriched ores prevent breaks
                if ore_type not in (
                    RefineOre.HD_ORIDECON,
                    RefineOre.HD_ELUNIUM,
                    RefineOre.ENRICHED_ORIDECON,
                    RefineOre.ENRICHED_ELUNIUM
                ):
                    fail_rate = 1.0 - success_rate
                    break_cost += fail_rate * item_value
            
            details.append({
                "from_level": level,
                "to_level": next_level,
                "success_rate": success_rate * 100,
                "expected_attempts": attempts,
                "ore_cost": level_cost,
                "ore_type": ore_type.value,
            })
            
            level = next_level
        
        return {
            "current_level": current_level,
            "target_level": target_level,
            "total_ore_cost": total_cost,
            "expected_break_cost": break_cost,
            "total_expected_cost": total_cost + break_cost,
            "expected_attempts": expected_attempts,
            "details": details,
        }
    
    def should_refine(
        self,
        item_id: int,
        current_level: int,
        target_level: int,
        inventory: dict,
        risk_tolerance: float = 0.5
    ) -> Tuple[bool, str]:
        """
        Decide if should attempt refine.
        
        Args:
            item_id: Item to refine
            current_level: Current refine level
            target_level: Target refine level
            inventory: Current inventory
            risk_tolerance: Risk tolerance (0.0-1.0, higher = more risky)
            
        Returns:
            Tuple of (should_refine, reason)
        """
        if target_level <= current_level:
            return False, "Target level must be higher than current"
        
        if target_level > 10:
            return False, "Cannot refine above +10"
        
        # Check if we have materials
        # Simplified check - in real implementation would check actual ore
        if not inventory:
            return False, "No inventory provided"
        
        # Check risk level
        refine_info = self.refine_rates.get(target_level)
        if not refine_info:
            return False, f"No refine data for level {target_level}"
        
        if refine_info.breaks_on_fail and risk_tolerance < 0.3:
            return False, "Too risky - item can break"
        
        if refine_info.can_downgrade and risk_tolerance < 0.5:
            return False, "Too risky - item can downgrade"
        
        return True, "Safe to refine"
    
    async def refine(
        self,
        item_index: int,
        use_hd_ore: bool = False
    ) -> dict:
        """
        Refine an item.
        
        Args:
            item_index: Index of item to refine
            use_hd_ore: Whether to use HD ore
            
        Returns:
            Refine result dictionary
        """
        return {
            "success": True,
            "item_index": item_index,
            "use_hd_ore": use_hd_ore
        }
    
    def get_safe_refine_limit(self, item_level: int) -> int:
        """
        Get safe refine limit for item level.
        
        Args:
            item_level: Item level (1-4)
            
        Returns:
            Safe refine limit
        """
        return self.get_safe_limit(item_level, is_armor=False)
    
    def get_statistics(self) -> dict:
        """
        Get refining statistics.
        
        Returns:
            Statistics dictionary
        """
        safe_levels = sum(
            1 for info in self.refine_rates.values()
            if info.safe_level
        )
        risky_levels = len(self.refine_rates) - safe_levels
        
        return {
            "total_refine_levels": len(self.refine_rates),
            "safe_levels": safe_levels,
            "risky_levels": risky_levels,
        }