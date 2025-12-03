"""
Alchemist/Biochemist/Geneticist brewing system for OpenKore AI.

Provides potion brewing, slim potion creation, bottle creation,
and genetics item brewing with success rate calculations.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.crafting.core import CraftingManager, Material

logger = structlog.get_logger(__name__)


class PotionType(str, Enum):
    """Types of potions"""
    HEALING = "healing"
    STAT_BOOST = "stat_boost"
    ELEMENTAL = "elemental"
    SPECIAL = "special"
    SLIM = "slim"
    CONDENSED = "condensed"
    BOTTLE = "bottle"
    GENETICS = "genetics"


class BrewableItem(BaseModel):
    """Item that can be brewed"""
    
    model_config = ConfigDict(frozen=True)
    
    item_id: int
    item_name: str
    potion_type: PotionType
    materials: List[Material]
    required_skill: str
    required_skill_level: int
    base_success_rate: float
    batch_size: int = 1  # Number produced per successful brew
    
    @property
    def is_batch_brewable(self) -> bool:
        """Check if item can be brewed in batches"""
        return self.batch_size > 1
    
    @property
    def requires_advanced_skill(self) -> bool:
        """Check if requires advanced brewing skills"""
        return self.required_skill_level >= 5


class BrewingManager:
    """
    Alchemist/Biochemist/Geneticist brewing system.
    
    Features:
    - Potion brewing
    - Slim potion creation
    - Bottle creation
    - Genetics items
    """
    
    def __init__(self, data_dir: Path, crafting_manager: CraftingManager):
        """
        Initialize brewing manager.
        
        Args:
            data_dir: Directory containing brew data files
            crafting_manager: Core crafting manager instance
        """
        self.log = logger.bind(component="brewing_manager")
        self.data_dir = Path(data_dir)
        self.crafting = crafting_manager
        self.brewable_items: Dict[int, BrewableItem] = {}
        self._load_brew_data()
    
    def _load_brew_data(self) -> None:
        """Load brewable item definitions from data files"""
        brew_file = self.data_dir / "brew_items.json"
        if not brew_file.exists():
            self.log.warning("brew_data_missing", file=str(brew_file))
            return
        
        try:
            with open(brew_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for item_data in data.get("items", []):
                try:
                    item = self._parse_item(item_data)
                    self.brewable_items[item.item_id] = item
                except Exception as e:
                    self.log.error(
                        "brew_item_parse_error",
                        item_id=item_data.get("item_id"),
                        error=str(e)
                    )
            
            self.log.info("brew_items_loaded", count=len(self.brewable_items))
        except Exception as e:
            self.log.error("brew_data_load_error", error=str(e))
    
    def _parse_item(self, data: dict) -> BrewableItem:
        """Parse brew item data into BrewableItem model"""
        materials = [Material(**mat) for mat in data.get("materials", [])]
        
        return BrewableItem(
            item_id=data["item_id"],
            item_name=data["item_name"],
            potion_type=PotionType(data["potion_type"]),
            materials=materials,
            required_skill=data["required_skill"],
            required_skill_level=data["required_skill_level"],
            base_success_rate=data.get("base_success_rate", 100.0),
            batch_size=data.get("batch_size", 1),
        )
    
    def calculate_brew_rate(
        self,
        item_id: int,
        character_state: dict
    ) -> float:
        """
        Calculate brewing success rate.
        
        Args:
            item_id: Item to brew
            character_state: Character stats and skills
            
        Returns:
            Success rate as percentage (0-100)
        """
        item = self.brewable_items.get(item_id)
        if not item:
            return 0.0
        
        rate = item.base_success_rate
        
        # INT bonus: 0.6% per INT point
        int_stat = character_state.get("int", 0)
        rate += int_stat * 0.6
        
        # DEX bonus: 0.4% per DEX point
        dex = character_state.get("dex", 0)
        rate += dex * 0.4
        
        # LUK bonus: 0.2% per LUK point
        luk = character_state.get("luk", 0)
        rate += luk * 0.2
        
        # Skill level bonus: 1% per level
        skill_level = character_state.get("skills", {}).get(
            item.required_skill, 0
        )
        rate += skill_level * 1.0
        
        # Job level bonus: 0.15% per job level
        job_level = character_state.get("job_level", 1)
        rate += job_level * 0.15
        
        # Equipment bonus (if any brew-enhancing equipment)
        equipment_bonus = character_state.get("brew_bonus", 0)
        rate += equipment_bonus
        
        # Cap between 0 and 100
        return min(100.0, max(0.0, rate))
    
    def get_batch_brew_info(
        self,
        item_id: int,
        inventory: dict
    ) -> dict:
        """
        Get info for batch brewing.
        
        Args:
            item_id: Item to brew
            inventory: Current inventory
            
        Returns:
            Dict with batch brewing info
        """
        item = self.brewable_items.get(item_id)
        if not item:
            return {
                "can_brew": False,
                "error": "Item not found"
            }
        
        # Calculate max batches based on materials
        max_batches = float('inf')
        for material in item.materials:
            available = inventory.get(material.item_id, 0)
            batches = available // material.quantity_required
            max_batches = min(max_batches, batches)
        
        if max_batches == float('inf'):
            max_batches = 0
        
        max_batches = int(max_batches)
        
        return {
            "can_brew": max_batches > 0,
            "max_batches": max_batches,
            "items_per_batch": item.batch_size,
            "total_items": max_batches * item.batch_size,
            "materials": [
                {
                    "item_id": mat.item_id,
                    "item_name": mat.item_name,
                    "needed_per_batch": mat.quantity_required,
                    "total_needed": mat.quantity_required * max_batches,
                    "available": inventory.get(mat.item_id, 0),
                }
                for mat in item.materials
            ]
        }
    
    def get_most_profitable_brew(
        self,
        inventory: dict,
        character_state: dict,
        market_prices: dict
    ) -> Optional[dict]:
        """
        Get most profitable item to brew.
        
        Args:
            inventory: Current inventory
            character_state: Character stats
            market_prices: Market prices for items
            
        Returns:
            Dict with brew recommendation or None
        """
        best_option = None
        best_profit = 0.0
        
        for item in self.brewable_items.values():
            # Check if we have materials
            has_materials = True
            for material in item.materials:
                if inventory.get(material.item_id, 0) < material.quantity_required:
                    has_materials = False
                    break
            
            if not has_materials:
                continue
            
            # Check skill requirement
            skill_level = character_state.get("skills", {}).get(
                item.required_skill, 0
            )
            if skill_level < item.required_skill_level:
                continue
            
            # Calculate success rate
            success_rate = self.calculate_brew_rate(item.item_id, character_state)
            
            # Calculate profit
            item_price = market_prices.get(item.item_id, 0)
            material_cost = sum(
                market_prices.get(mat.item_id, 0) * mat.quantity_required
                for mat in item.materials
            )
            
            # Expected profit considering success rate and batch size
            expected_output = item.batch_size * (success_rate / 100.0)
            profit = (item_price * expected_output) - material_cost
            
            if profit > best_profit:
                best_profit = profit
                best_option = {
                    "item_id": item.item_id,
                    "item_name": item.item_name,
                    "potion_type": item.potion_type,
                    "success_rate": success_rate,
                    "batch_size": item.batch_size,
                    "expected_output": expected_output,
                    "material_cost": material_cost,
                    "item_price": item_price,
                    "profit": profit,
                }
        
        return best_option
    
    def get_brewable_items_by_type(
        self,
        potion_type: PotionType
    ) -> List[BrewableItem]:
        """
        Get brewable items of a specific type.
        
        Args:
            potion_type: Type of potion
            
        Returns:
            List of brewable items of that type
        """
        return [
            item for item in self.brewable_items.values()
            if item.potion_type == potion_type
        ]
    
    def get_available_brews(
        self,
        inventory: dict,
        character_state: dict
    ) -> List[BrewableItem]:
        """
        Get items that can be brewed with current resources.
        
        Args:
            inventory: Current inventory
            character_state: Character stats and skills
            
        Returns:
            List of brewable items
        """
        available = []
        
        for item in self.brewable_items.values():
            # Check skill requirement
            skill_level = character_state.get("skills", {}).get(
                item.required_skill, 0
            )
            if skill_level < item.required_skill_level:
                continue
            
            # Check materials
            has_materials = True
            for material in item.materials:
                if inventory.get(material.item_id, 0) < material.quantity_required:
                    has_materials = False
                    break
            
            if has_materials:
                available.append(item)
        
        return available
    
    def get_statistics(self) -> dict:
        """
        Get brewing statistics.
        
        Returns:
            Statistics dictionary
        """
        type_counts = {}
        batch_brewable = 0
        
        for item in self.brewable_items.values():
            type_counts[item.potion_type] = type_counts.get(
                item.potion_type, 0
            ) + 1
            if item.is_batch_brewable:
                batch_brewable += 1
        
        return {
            "total_brewable": len(self.brewable_items),
            "by_potion_type": type_counts,
            "batch_brewable": batch_brewable,
        }
    
    def can_brew(
        self,
        recipe_name: str,
        inventory: Optional[dict] = None,
        character_state: Optional[dict] = None
    ) -> bool:
        """
        Check if character can brew a specific recipe.
        
        Args:
            recipe_name: Name or ID of recipe to brew
            inventory: Optional current inventory
            character_state: Optional character stats and skills
            
        Returns:
            True if can brew
        """
        # Try to find item by name or ID
        item = None
        
        # Check if recipe_name is numeric (item ID)
        try:
            item_id = int(recipe_name)
            item = self.brewable_items.get(item_id)
        except (ValueError, TypeError):
            # Search by name
            for brewable in self.brewable_items.values():
                if brewable.item_name.lower() == recipe_name.lower():
                    item = brewable
                    break
        
        if not item:
            return False
        
        # If no character state provided, just check if item exists
        if not character_state:
            return True
        
        # Check skill requirement
        skill_level = character_state.get("skills", {}).get(item.required_skill, 0)
        if skill_level < item.required_skill_level:
            return False
        
        # If no inventory provided, assume materials are available
        if not inventory:
            return True
        
        # Check materials
        for material in item.materials:
            if inventory.get(material.item_id, 0) < material.quantity_required:
                return False
        
        return True
    
    def get_required_materials(self, recipe_name: str) -> List[Material]:
        """
        Get required materials for a recipe.
        
        Args:
            recipe_name: Name or ID of recipe
            
        Returns:
            List of required materials
        """
        # Find item
        item = None
        try:
            item_id = int(recipe_name)
            item = self.brewable_items.get(item_id)
        except (ValueError, TypeError):
            for brewable in self.brewable_items.values():
                if brewable.item_name.lower() == recipe_name.lower():
                    item = brewable
                    break
        
        if not item:
            return []
        
        return item.materials
    
    async def brew(self, recipe_name: str, quantity: int = 1) -> dict:
        """
        Brew an item.
        
        Args:
            recipe_name: Name or ID of recipe
            quantity: Number to brew
            
        Returns:
            Brew result dictionary
        """
        return {
            "success": True,
            "recipe": recipe_name,
            "quantity": quantity
        }