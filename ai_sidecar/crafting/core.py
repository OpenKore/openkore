"""
Core crafting management system for OpenKore AI.

Provides comprehensive crafting recipe management, material tracking,
success rate calculation, and craft automation for all crafting types.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class CraftingType(str, Enum):
    """Types of crafting in RO"""
    FORGE = "forge"           # Blacksmith weapon forging
    BREW = "brew"             # Alchemist brewing
    COOK = "cook"             # Cooking/Chef crafting
    REFINE = "refine"         # Equipment refinement
    ENCHANT = "enchant"       # Enchanting
    CARD_SLOT = "card_slot"   # Card slotting
    COSTUME = "costume"       # Costume enchanting
    SHADOW = "shadow"         # Shadow equipment
    RUNE = "rune"             # Rune creation


class CraftingResult(str, Enum):
    """Crafting result outcomes"""
    SUCCESS = "success"
    FAILURE = "failure"
    BREAK = "break"           # Item destroyed
    DOWNGRADE = "downgrade"   # Level reduced


class Material(BaseModel):
    """Material required for crafting"""
    
    model_config = ConfigDict(frozen=False)
    
    item_id: int
    item_name: str
    quantity_required: int
    quantity_owned: int = 0
    is_consumed: bool = True
    
    @property
    def is_available(self) -> bool:
        """Check if sufficient quantity is available"""
        return self.quantity_owned >= self.quantity_required
    
    @property
    def quantity_missing(self) -> int:
        """Get missing quantity"""
        return max(0, self.quantity_required - self.quantity_owned)


class CraftingRecipe(BaseModel):
    """Recipe for crafting"""
    
    model_config = ConfigDict(frozen=True)
    
    recipe_id: int
    recipe_name: str
    crafting_type: CraftingType
    result_item_id: int
    result_item_name: str
    result_quantity: int = 1
    
    # Requirements
    materials: List[Material]
    required_skill: Optional[str] = None
    required_skill_level: int = 0
    required_job: Optional[str] = None
    required_base_level: int = 1
    required_zeny: int = 0
    
    # Success rates
    base_success_rate: float = 100.0
    dex_bonus: float = 0.0  # Per DEX point
    luk_bonus: float = 0.0  # Per LUK point
    skill_bonus: float = 0.0  # Per skill level
    
    # Location
    npc_name: Optional[str] = None
    npc_map: Optional[str] = None
    npc_coordinates: Optional[Tuple[int, int]] = None
    
    @property
    def has_level_requirement(self) -> bool:
        """Check if recipe has level requirement"""
        return self.required_base_level > 1
    
    @property
    def has_skill_requirement(self) -> bool:
        """Check if recipe requires specific skill"""
        return self.required_skill is not None and self.required_skill_level > 0


class CraftingManager:
    """
    Core crafting management system.
    
    Features:
    - Recipe management
    - Material tracking
    - Success rate calculation
    - Craft automation
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize crafting manager.
        
        Args:
            data_dir: Directory containing crafting data files
        """
        self.log = logger.bind(component="crafting_manager")
        self.data_dir = Path(data_dir)
        self.recipes: Dict[int, CraftingRecipe] = {}
        self._load_recipe_data()
    
    def _load_recipe_data(self) -> None:
        """Load recipe definitions from data files"""
        recipe_file = self.data_dir / "crafting_recipes.json"
        if not recipe_file.exists():
            self.log.warning("recipe_data_missing", file=str(recipe_file))
            return
        
        try:
            with open(recipe_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            for recipe_data in data.get("recipes", []):
                try:
                    recipe = self._parse_recipe(recipe_data)
                    self.recipes[recipe.recipe_id] = recipe
                except Exception as e:
                    self.log.error(
                        "recipe_parse_error",
                        recipe_id=recipe_data.get("recipe_id"),
                        error=str(e)
                    )
            
            self.log.info("recipes_loaded", count=len(self.recipes))
        except Exception as e:
            self.log.error("recipe_data_load_error", error=str(e))
    
    def _parse_recipe(self, data: dict) -> CraftingRecipe:
        """Parse recipe data into CraftingRecipe model"""
        materials = [Material(**mat) for mat in data.get("materials", [])]
        
        return CraftingRecipe(
            recipe_id=data["recipe_id"],
            recipe_name=data["recipe_name"],
            crafting_type=CraftingType(data["crafting_type"]),
            result_item_id=data["result_item_id"],
            result_item_name=data["result_item_name"],
            result_quantity=data.get("result_quantity", 1),
            materials=materials,
            required_skill=data.get("required_skill"),
            required_skill_level=data.get("required_skill_level", 0),
            required_job=data.get("required_job"),
            required_base_level=data.get("required_base_level", 1),
            required_zeny=data.get("required_zeny", 0),
            base_success_rate=data.get("base_success_rate", 100.0),
            dex_bonus=data.get("dex_bonus", 0.0),
            luk_bonus=data.get("luk_bonus", 0.0),
            skill_bonus=data.get("skill_bonus", 0.0),
            npc_name=data.get("npc_name"),
            npc_map=data.get("npc_map"),
            npc_coordinates=data.get("npc_coordinates"),
        )
    
    def get_recipe(self, recipe_id: int) -> Optional[CraftingRecipe]:
        """
        Get recipe by ID.
        
        Args:
            recipe_id: Recipe identifier
            
        Returns:
            Recipe if found, None otherwise
        """
        return self.recipes.get(recipe_id)
    
    def get_recipes_by_type(self, crafting_type: CraftingType) -> List[CraftingRecipe]:
        """
        Get all recipes of a specific type.
        
        Args:
            crafting_type: Type of crafting
            
        Returns:
            List of recipes of that type
        """
        return [
            recipe for recipe in self.recipes.values()
            if recipe.crafting_type == crafting_type
        ]
    
    def check_materials(
        self,
        recipe_id: int,
        inventory: dict
    ) -> Tuple[bool, List[str]]:
        """
        Check if materials are available for a recipe.
        
        Args:
            recipe_id: Recipe to check
            inventory: Current inventory {item_id: quantity}
            
        Returns:
            Tuple of (all_available, missing_materials)
        """
        recipe = self.recipes.get(recipe_id)
        if not recipe:
            return False, ["Recipe not found"]
        
        missing = []
        for material in recipe.materials:
            owned = inventory.get(material.item_id, 0)
            if owned < material.quantity_required:
                missing.append(
                    f"{material.item_name}: {material.quantity_required - owned} needed"
                )
        
        return len(missing) == 0, missing
    
    def calculate_success_rate(
        self,
        recipe_id: int,
        character_state: dict
    ) -> float:
        """
        Calculate success rate for a recipe based on character stats.
        
        Args:
            recipe_id: Recipe to calculate for
            character_state: Character stats and skills
            
        Returns:
            Success rate as percentage (0-100)
        """
        recipe = self.recipes.get(recipe_id)
        if not recipe:
            return 0.0
        
        rate = recipe.base_success_rate
        
        # Add DEX bonus
        dex = character_state.get("dex", 0)
        rate += dex * recipe.dex_bonus
        
        # Add LUK bonus
        luk = character_state.get("luk", 0)
        rate += luk * recipe.luk_bonus
        
        # Add skill level bonus
        if recipe.required_skill:
            skill_level = character_state.get("skills", {}).get(
                recipe.required_skill, 0
            )
            rate += skill_level * recipe.skill_bonus
        
        # Cap at 100%
        return min(100.0, max(0.0, rate))
    
    def get_missing_materials(
        self,
        recipe_id: int,
        inventory: dict
    ) -> List[Material]:
        """
        Get list of missing materials for a recipe.
        
        Args:
            recipe_id: Recipe to check
            inventory: Current inventory
            
        Returns:
            List of materials with missing quantities
        """
        recipe = self.recipes.get(recipe_id)
        if not recipe:
            return []
        
        missing = []
        for material in recipe.materials:
            owned = inventory.get(material.item_id, 0)
            if owned < material.quantity_required:
                mat_copy = Material(
                    item_id=material.item_id,
                    item_name=material.item_name,
                    quantity_required=material.quantity_required - owned,
                    quantity_owned=0,
                    is_consumed=material.is_consumed
                )
                missing.append(mat_copy)
        
        return missing
    
    def get_craftable_recipes(
        self,
        inventory: dict,
        character_state: dict
    ) -> List[CraftingRecipe]:
        """
        Get recipes that can be crafted with current resources.
        
        Args:
            inventory: Current inventory
            character_state: Character stats and skills
            
        Returns:
            List of craftable recipes
        """
        craftable = []
        level = character_state.get("level", 1)
        job = character_state.get("job", "Novice")
        zeny = character_state.get("zeny", 0)
        
        for recipe in self.recipes.values():
            # Check level requirement
            if level < recipe.required_base_level:
                continue
            
            # Check job requirement
            if recipe.required_job and job != recipe.required_job:
                continue
            
            # Check zeny requirement
            if zeny < recipe.required_zeny:
                continue
            
            # Check skill requirement
            if recipe.required_skill:
                skill_level = character_state.get("skills", {}).get(
                    recipe.required_skill, 0
                )
                if skill_level < recipe.required_skill_level:
                    continue
            
            # Check materials
            has_materials, _ = self.check_materials(recipe.recipe_id, inventory)
            if has_materials:
                craftable.append(recipe)
        
        return craftable
    
    def get_statistics(self) -> dict:
        """
        Get crafting statistics.
        
        Returns:
            Statistics dictionary
        """
        type_counts = {}
        for recipe in self.recipes.values():
            type_counts[recipe.crafting_type] = type_counts.get(
                recipe.crafting_type, 0
            ) + 1
        
        return {
            "total_recipes": len(self.recipes),
            "recipes_by_type": type_counts,
        }