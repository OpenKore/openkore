"""
Blacksmith/Whitesmith forging system for OpenKore AI.

Provides weapon forging with element application, star crumb usage,
fame tracking, and forge success rate calculations.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.crafting.core import CraftingManager, Material

logger = structlog.get_logger(__name__)


class ForgeElement(str, Enum):
    """Element for forging"""
    NONE = "none"
    FIRE = "fire"
    ICE = "ice"
    WIND = "wind"
    EARTH = "earth"
    VERY_STRONG_FIRE = "very_strong_fire"
    VERY_STRONG_ICE = "very_strong_ice"
    VERY_STRONG_WIND = "very_strong_wind"
    VERY_STRONG_EARTH = "very_strong_earth"


class ForgeableWeapon(BaseModel):
    """Weapon that can be forged"""
    
    model_config = ConfigDict(frozen=True)
    
    weapon_id: int
    weapon_name: str
    weapon_level: int  # 1-4
    base_materials: List[Material]
    element_stone: Optional[Material] = None
    star_crumb_count: int = 0  # 0-3 for VVS/VVs
    base_success_rate: float = 100.0
    
    @property
    def requires_element_stone(self) -> bool:
        """Check if weapon requires element stone"""
        return self.element_stone is not None
    
    @property
    def is_vvs_weapon(self) -> bool:
        """Check if this is a Very Very Strong weapon"""
        return self.star_crumb_count > 0


class ForgeResult(BaseModel):
    """Result of a forge attempt"""
    
    model_config = ConfigDict(frozen=False)
    
    success: bool
    weapon_id: Optional[int] = None
    weapon_name: Optional[str] = None
    element: ForgeElement = ForgeElement.NONE
    star_count: int = 0
    crafter_name: str = ""
    fame_gained: int = 0
    materials_lost: List[Material] = Field(default_factory=list)


class ForgingManager:
    """
    Blacksmith/Whitesmith forging system.
    
    Features:
    - Weapon forging
    - Element application
    - Star crumb usage
    - Fame tracking
    """
    
    def __init__(self, data_dir: Path, crafting_manager: CraftingManager):
        """
        Initialize forging manager.
        
        Args:
            data_dir: Directory containing forge data files
            crafting_manager: Core crafting manager instance
        """
        self.log = logger.bind(component="forging_manager")
        self.data_dir = Path(data_dir)
        self.crafting = crafting_manager
        self.forgeable_weapons: Dict[int, ForgeableWeapon] = {}
        self.fame_records: Dict[str, int] = {}  # {character_name: fame_points}
        self._load_forge_data()
    
    def _load_forge_data(self) -> None:
        """Load forge weapon definitions from data files"""
        forge_file = self.data_dir / "forge_weapons.json"
        if not forge_file.exists():
            self.log.warning("forge_data_missing", file=str(forge_file))
            return
        
        try:
            with open(forge_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for weapon_data in data.get("weapons", []):
                try:
                    weapon = self._parse_weapon(weapon_data)
                    self.forgeable_weapons[weapon.weapon_id] = weapon
                except Exception as e:
                    self.log.error(
                        "weapon_parse_error",
                        weapon_id=weapon_data.get("weapon_id"),
                        error=str(e)
                    )
            
            self.log.info("forge_weapons_loaded", count=len(self.forgeable_weapons))
        except Exception as e:
            self.log.error("forge_data_load_error", error=str(e))
    
    def _parse_weapon(self, data: dict) -> ForgeableWeapon:
        """Parse weapon data into ForgeableWeapon model"""
        materials = [Material(**mat) for mat in data.get("base_materials", [])]
        element_stone = None
        if "element_stone" in data:
            element_stone = Material(**data["element_stone"])
        
        return ForgeableWeapon(
            weapon_id=data["weapon_id"],
            weapon_name=data["weapon_name"],
            weapon_level=data["weapon_level"],
            base_materials=materials,
            element_stone=element_stone,
            star_crumb_count=data.get("star_crumb_count", 0),
            base_success_rate=data.get("base_success_rate", 100.0),
        )
    
    def get_forge_success_rate(
        self,
        weapon_id: int,
        character_state: dict,
        element: ForgeElement = ForgeElement.NONE,
        star_crumbs: int = 0
    ) -> float:
        """
        Calculate forge success rate.
        
        Args:
            weapon_id: Weapon to forge
            character_state: Character stats and skills
            element: Element to apply
            star_crumbs: Number of star crumbs to use
            
        Returns:
            Success rate as percentage (0-100)
        """
        weapon = self.forgeable_weapons.get(weapon_id)
        if not weapon:
            return 0.0
        
        # Base rate depends on weapon level
        weapon_level = weapon.weapon_level
        base_rates = {1: 100.0, 2: 85.0, 3: 70.0, 4: 55.0}
        rate = base_rates.get(weapon_level, 50.0)
        
        # DEX bonus: 0.5% per DEX point
        dex = character_state.get("dex", 0)
        rate += dex * 0.5
        
        # LUK bonus: 0.2% per LUK point
        luk = character_state.get("luk", 0)
        rate += luk * 0.2
        
        # Job level bonus: 0.1% per job level
        job_level = character_state.get("job_level", 1)
        rate += job_level * 0.1
        
        # Element penalty: -5% for normal elements, -10% for very strong
        if element != ForgeElement.NONE:
            if "very_strong" in element.value:
                rate -= 10.0
            else:
                rate -= 5.0
        
        # Star crumb penalty: -3% per crumb
        rate -= star_crumbs * 3.0
        
        # Cap between 0 and 100
        return min(100.0, max(0.0, rate))
    
    def get_required_materials(
        self,
        weapon_id: int,
        element: ForgeElement = ForgeElement.NONE,
        star_crumbs: int = 0
    ) -> List[Material]:
        """
        Get materials needed for forge.
        
        Args:
            weapon_id: Weapon to forge
            element: Element to apply
            star_crumbs: Number of star crumbs
            
        Returns:
            List of required materials
        """
        weapon = self.forgeable_weapons.get(weapon_id)
        if not weapon:
            return []
        
        materials = list(weapon.base_materials)
        
        # Add element stone if element requested
        if element != ForgeElement.NONE and weapon.element_stone:
            element_mat = Material(
                item_id=weapon.element_stone.item_id,
                item_name=weapon.element_stone.item_name,
                quantity_required=1,
                is_consumed=True
            )
            materials.append(element_mat)
        
        # Add star crumbs if requested
        if star_crumbs > 0:
            star_crumb_mat = Material(
                item_id=1000,  # Star Crumb item ID
                item_name="Star Crumb",
                quantity_required=star_crumbs,
                is_consumed=True
            )
            materials.append(star_crumb_mat)
        
        return materials
    
    def get_fame_value(
        self,
        weapon_level: int,
        element: ForgeElement = ForgeElement.NONE,
        star_crumbs: int = 0
    ) -> int:
        """
        Calculate fame points from successful forge.
        
        Args:
            weapon_level: Level of weapon forged
            element: Element applied
            star_crumbs: Star crumbs used
            
        Returns:
            Fame points gained
        """
        # Base fame by weapon level
        base_fame = {1: 1, 2: 5, 3: 10, 4: 15}
        fame = base_fame.get(weapon_level, 0)
        
        # Element bonus: +2 for normal, +5 for very strong
        if element != ForgeElement.NONE:
            if "very_strong" in element.value:
                fame += 5
            else:
                fame += 2
        
        # Star crumb bonus: +3 per crumb
        fame += star_crumbs * 3
        
        return fame
    
    def get_optimal_forge_target(
        self,
        inventory: dict,
        character_state: dict,
        market_prices: Optional[dict] = None
    ) -> Optional[dict]:
        """
        Get optimal weapon to forge for profit/fame.
        
        Args:
            inventory: Current inventory
            character_state: Character stats
            market_prices: Market prices for items
            
        Returns:
            Dict with forge recommendation or None
        """
        best_option = None
        best_score = 0.0
        
        for weapon in self.forgeable_weapons.values():
            # Check if we have materials
            has_materials = True
            for material in weapon.base_materials:
                if inventory.get(material.item_id, 0) < material.quantity_required:
                    has_materials = False
                    break
            
            if not has_materials:
                continue
            
            # Calculate success rate
            success_rate = self.get_forge_success_rate(
                weapon.weapon_id,
                character_state
            )
            
            # Calculate fame value
            fame = self.get_fame_value(weapon.weapon_level)
            
            # Calculate profit if market prices available
            profit = 0
            if market_prices:
                weapon_price = market_prices.get(weapon.weapon_id, 0)
                material_cost = sum(
                    market_prices.get(mat.item_id, 0) * mat.quantity_required
                    for mat in weapon.base_materials
                )
                profit = weapon_price - material_cost
            
            # Score: weighted combination of success rate, fame, and profit
            score = (success_rate * 0.4) + (fame * 10) + (profit * 0.001)
            
            if score > best_score:
                best_score = score
                best_option = {
                    "weapon_id": weapon.weapon_id,
                    "weapon_name": weapon.weapon_name,
                    "success_rate": success_rate,
                    "fame_gain": fame,
                    "estimated_profit": profit,
                    "score": score,
                }
        
        return best_option
    
    def add_fame(self, character_name: str, fame_points: int) -> int:
        """
        Add fame points to character.
        
        Args:
            character_name: Character name
            fame_points: Fame to add
            
        Returns:
            Total fame points
        """
        current = self.fame_records.get(character_name, 0)
        new_total = current + fame_points
        self.fame_records[character_name] = new_total
        
        self.log.info(
            "fame_gained",
            character=character_name,
            points=fame_points,
            total=new_total
        )
        
        return new_total
    
    def get_fame(self, character_name: str) -> int:
        """Get current fame points for character"""
        return self.fame_records.get(character_name, 0)
    
    def get_statistics(self) -> dict:
        """
        Get forging statistics.
        
        Returns:
            Statistics dictionary
        """
        weapon_levels = {}
        for weapon in self.forgeable_weapons.values():
            level = weapon.weapon_level
            weapon_levels[level] = weapon_levels.get(level, 0) + 1
        
        return {
            "total_forgeable": len(self.forgeable_weapons),
            "by_weapon_level": weapon_levels,
            "total_fame_tracked": sum(self.fame_records.values()),
            "characters_with_fame": len(self.fame_records),
        }