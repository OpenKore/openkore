"""
Crafting Recipe Database - Comprehensive recipe system for RO crafting.

Features:
- Blacksmith weapon forging
- Alchemist potion crafting
- Cooking system
- Arrow crafting
- Equipment upgrade paths
- Material requirement lookups
- Profitability calculations
"""

import json
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Set, Tuple

import structlog

logger = structlog.get_logger(__name__)


class CraftingType(str, Enum):
    """Crafting system types"""
    FORGING = "forging"           # Blacksmith weapon forging
    PHARMACY = "pharmacy"         # Alchemist potion making
    COOKING = "cooking"           # Chef cooking
    ARROW_CRAFTING = "arrow"      # Arrow crafting
    COMBINATION = "combination"   # Item combinations
    UPGRADE = "upgrade"           # Equipment upgrading
    REFINING = "refining"         # Equipment refining


class JobClass(str, Enum):
    """Job classes for crafting requirements"""
    NONE = "none"
    BLACKSMITH = "blacksmith"
    WHITESMITH = "whitesmith"
    ALCHEMIST = "alchemist"
    BIOCHEMIST = "biochemist"
    SUPER_NOVICE = "super_novice"
    CHEF = "chef"
    ARCHER = "archer"
    HUNTER = "hunter"
    SNIPER = "sniper"


@dataclass
class RecipeMaterial:
    """
    Material required for a recipe.
    
    Attributes:
        item_id: Material item ID
        item_name: Material name for reference
        quantity: Amount required
        consumed: Whether material is consumed on success/failure
    """
    item_id: int
    item_name: str
    quantity: int
    consumed: bool = True


@dataclass
class CraftingRecipe:
    """
    Crafting recipe definition.
    
    Attributes:
        recipe_id: Unique recipe identifier
        name: Recipe name
        crafting_type: Type of crafting system
        product_id: Resulting item ID
        product_name: Resulting item name
        product_count: Number of items produced
        materials: List of required materials
        base_success_rate: Base success rate (0.0-1.0)
        required_job: Job class required
        required_level: Minimum base level
        required_skills: Dict of skill_name -> level required
        npc_required: Whether NPC interaction is needed
        npc_name: Name of required NPC (if any)
        catalyst_id: Optional catalyst item ID
        notes: Additional notes about the recipe
    """
    recipe_id: str
    name: str
    crafting_type: CraftingType
    product_id: int
    product_name: str
    product_count: int
    materials: List[RecipeMaterial]
    base_success_rate: float = 1.0
    required_job: JobClass = JobClass.NONE
    required_level: int = 1
    required_skills: Dict[str, int] = field(default_factory=dict)
    npc_required: bool = False
    npc_name: str = ""
    catalyst_id: Optional[int] = None
    notes: str = ""
    
    def get_material_ids(self) -> Set[int]:
        """Get all material item IDs."""
        return {m.item_id for m in self.materials}
    
    def get_total_materials(self) -> Dict[int, int]:
        """Get dict of item_id -> total quantity needed."""
        totals: Dict[int, int] = {}
        for mat in self.materials:
            totals[mat.item_id] = totals.get(mat.item_id, 0) + mat.quantity
        return totals


class CraftingRecipeDatabase:
    """
    Database of crafting recipes with lookup capabilities.
    
    Features:
    - Recipe lookup by product ID
    - Material requirement queries
    - Recipe-product relationships
    - Crafting profitability support
    """
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize crafting recipe database.
        
        Args:
            data_dir: Optional directory for custom recipe data
        """
        self.log = logger.bind(system="crafting_recipes")
        self.data_dir = data_dir
        
        # Recipe storage
        self.recipes: Dict[str, CraftingRecipe] = {}
        
        # Indexes for efficient lookup
        self._product_to_recipes: Dict[int, List[str]] = {}  # product_id -> [recipe_ids]
        self._material_to_recipes: Dict[int, List[str]] = {}  # material_id -> [recipe_ids]
        self._type_to_recipes: Dict[CraftingType, List[str]] = {}  # type -> [recipe_ids]
        
        # Initialize default RO recipes
        self._init_forging_recipes()
        self._init_pharmacy_recipes()
        self._init_cooking_recipes()
        self._init_arrow_recipes()
        self._init_upgrade_recipes()
        
        # Load custom recipes if available
        if data_dir:
            self._load_custom_recipes(data_dir)
        
        # Build indexes
        self._build_indexes()
        
        self.log.info(
            "crafting_recipes_initialized",
            recipe_count=len(self.recipes)
        )
    
    def get_recipe(self, recipe_id: str) -> Optional[CraftingRecipe]:
        """Get recipe by ID."""
        return self.recipes.get(recipe_id)
    
    def get_recipes_for_product(self, product_id: int) -> List[CraftingRecipe]:
        """
        Get all recipes that produce an item.
        
        Args:
            product_id: Product item ID
            
        Returns:
            List of recipes that create this item
        """
        recipe_ids = self._product_to_recipes.get(product_id, [])
        return [self.recipes[rid] for rid in recipe_ids if rid in self.recipes]
    
    def get_recipes_using_material(self, material_id: int) -> List[CraftingRecipe]:
        """
        Get all recipes that use a material.
        
        Args:
            material_id: Material item ID
            
        Returns:
            List of recipes using this material
        """
        recipe_ids = self._material_to_recipes.get(material_id, [])
        return [self.recipes[rid] for rid in recipe_ids if rid in self.recipes]
    
    def get_recipes_by_type(self, crafting_type: CraftingType) -> List[CraftingRecipe]:
        """Get all recipes of a specific type."""
        recipe_ids = self._type_to_recipes.get(crafting_type, [])
        return [self.recipes[rid] for rid in recipe_ids if rid in self.recipes]
    
    def is_craftable(self, item_id: int) -> bool:
        """Check if an item can be crafted."""
        return item_id in self._product_to_recipes
    
    def is_crafting_material(self, item_id: int) -> bool:
        """Check if an item is used in any recipe."""
        return item_id in self._material_to_recipes
    
    def get_materials_for_product(self, product_id: int) -> List[RecipeMaterial]:
        """
        Get materials needed to craft a product.
        
        Args:
            product_id: Product item ID
            
        Returns:
            List of materials from first matching recipe
        """
        recipes = self.get_recipes_for_product(product_id)
        if not recipes:
            return []
        # Return materials from first recipe (most common case)
        return recipes[0].materials
    
    def get_all_materials_for_product(
        self,
        product_id: int
    ) -> Dict[str, List[RecipeMaterial]]:
        """
        Get all possible material sets for a product.
        
        Args:
            product_id: Product item ID
            
        Returns:
            Dict of recipe_id -> materials
        """
        recipes = self.get_recipes_for_product(product_id)
        return {r.recipe_id: r.materials for r in recipes}
    
    def get_products_from_material(self, material_id: int) -> Set[int]:
        """
        Get all products that can be made from a material.
        
        Args:
            material_id: Material item ID
            
        Returns:
            Set of product item IDs
        """
        recipes = self.get_recipes_using_material(material_id)
        return {r.product_id for r in recipes}
    
    def get_crafting_chain(
        self,
        product_id: int,
        max_depth: int = 3
    ) -> Dict[int, List[int]]:
        """
        Get crafting chain showing material dependencies.
        
        Args:
            product_id: Target product
            max_depth: Maximum recursion depth
            
        Returns:
            Dict of item_id -> [required_material_ids]
        """
        chain: Dict[int, List[int]] = {}
        self._build_chain_recursive(product_id, chain, 0, max_depth)
        return chain
    
    def _build_chain_recursive(
        self,
        item_id: int,
        chain: Dict[int, List[int]],
        depth: int,
        max_depth: int
    ) -> None:
        """Recursively build crafting chain."""
        if depth >= max_depth or item_id in chain:
            return
        
        recipes = self.get_recipes_for_product(item_id)
        if not recipes:
            return
        
        # Use first recipe's materials
        materials = [m.item_id for m in recipes[0].materials]
        chain[item_id] = materials
        
        # Recurse for each material
        for mat_id in materials:
            self._build_chain_recursive(mat_id, chain, depth + 1, max_depth)
    
    def add_recipe(self, recipe: CraftingRecipe) -> None:
        """
        Add a recipe to the database.
        
        Args:
            recipe: Recipe to add
        """
        self.recipes[recipe.recipe_id] = recipe
        
        # Update indexes
        if recipe.product_id not in self._product_to_recipes:
            self._product_to_recipes[recipe.product_id] = []
        self._product_to_recipes[recipe.product_id].append(recipe.recipe_id)
        
        for mat in recipe.materials:
            if mat.item_id not in self._material_to_recipes:
                self._material_to_recipes[mat.item_id] = []
            self._material_to_recipes[mat.item_id].append(recipe.recipe_id)
        
        if recipe.crafting_type not in self._type_to_recipes:
            self._type_to_recipes[recipe.crafting_type] = []
        self._type_to_recipes[recipe.crafting_type].append(recipe.recipe_id)
        
        self.log.debug(
            "recipe_added",
            recipe_id=recipe.recipe_id,
            product=recipe.product_name
        )
    
    def _init_forging_recipes(self) -> None:
        """Initialize blacksmith forging recipes."""
        
        # ========== SWORDS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_sword",
            name="Forge Sword",
            crafting_type=CraftingType.FORGING,
            product_id=1101,
            product_name="Sword",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 10),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Sword": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_falchion",
            name="Forge Falchion",
            crafting_type=CraftingType.FORGING,
            product_id=1104,
            product_name="Falchion",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 20),
                RecipeMaterial(1001, "Phracon", 2),
            ],
            base_success_rate=0.55,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Sword": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_blade",
            name="Forge Blade",
            crafting_type=CraftingType.FORGING,
            product_id=1107,
            product_name="Blade",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 30),
                RecipeMaterial(1002, "Emveretarcon", 2),
            ],
            base_success_rate=0.50,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 2, "Smith Sword": 3}
        ))
        
        # ========== DAGGERS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_knife",
            name="Forge Knife",
            crafting_type=CraftingType.FORGING,
            product_id=1201,
            product_name="Knife",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 5),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.70,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Dagger": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_cutter",
            name="Forge Cutter",
            crafting_type=CraftingType.FORGING,
            product_id=1202,
            product_name="Cutter",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 15),
                RecipeMaterial(1001, "Phracon", 2),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Dagger": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_main_gauche",
            name="Forge Main Gauche",
            crafting_type=CraftingType.FORGING,
            product_id=1204,
            product_name="Main Gauche",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 25),
                RecipeMaterial(1002, "Emveretarcon", 1),
            ],
            base_success_rate=0.55,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 2, "Smith Dagger": 3}
        ))
        
        # ========== AXES ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_axe",
            name="Forge Axe",
            crafting_type=CraftingType.FORGING,
            product_id=1301,
            product_name="Axe",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 15),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Axe": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_battle_axe",
            name="Forge Battle Axe",
            crafting_type=CraftingType.FORGING,
            product_id=1302,
            product_name="Battle Axe",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 25),
                RecipeMaterial(1001, "Phracon", 3),
            ],
            base_success_rate=0.55,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Axe": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_two_handed_axe",
            name="Forge Two-handed Axe",
            crafting_type=CraftingType.FORGING,
            product_id=1351,
            product_name="Two-handed Axe",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 35),
                RecipeMaterial(1002, "Emveretarcon", 2),
            ],
            base_success_rate=0.50,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 2, "Smith Axe": 3}
        ))
        
        # ========== MACES ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_club",
            name="Forge Club",
            crafting_type=CraftingType.FORGING,
            product_id=1501,
            product_name="Club",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 8),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.65,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Mace": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_mace",
            name="Forge Mace",
            crafting_type=CraftingType.FORGING,
            product_id=1502,
            product_name="Mace",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 20),
                RecipeMaterial(1001, "Phracon", 2),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Mace": 2}
        ))
        
        # ========== SPEARS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_javelin",
            name="Forge Javelin",
            crafting_type=CraftingType.FORGING,
            product_id=1401,
            product_name="Javelin",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 8),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.65,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Spear": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_spear",
            name="Forge Spear",
            crafting_type=CraftingType.FORGING,
            product_id=1402,
            product_name="Spear",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 18),
                RecipeMaterial(1001, "Phracon", 2),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Spear": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_pike",
            name="Forge Pike",
            crafting_type=CraftingType.FORGING,
            product_id=1403,
            product_name="Pike",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 28),
                RecipeMaterial(1002, "Emveretarcon", 1),
            ],
            base_success_rate=0.55,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 2, "Smith Spear": 3}
        ))
        
        # ========== KNUCKLES ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_waghnak",
            name="Forge Waghnak",
            crafting_type=CraftingType.FORGING,
            product_id=1801,
            product_name="Waghnak",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 12),
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=0.60,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Knuckle": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="forge_knuckle_duster",
            name="Forge Knuckle Duster",
            crafting_type=CraftingType.FORGING,
            product_id=1802,
            product_name="Knuckle Duster",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 22),
                RecipeMaterial(1001, "Phracon", 2),
            ],
            base_success_rate=0.55,
            required_job=JobClass.BLACKSMITH,
            required_skills={"Weaponry Research": 1, "Smith Knuckle": 2}
        ))
    
    def _init_pharmacy_recipes(self) -> None:
        """Initialize alchemist pharmacy recipes."""
        
        # ========== POTIONS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_red_potion",
            name="Brew Red Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=501,
            product_name="Red Potion",
            product_count=1,
            materials=[
                RecipeMaterial(508, "Red Herb", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.80,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_orange_potion",
            name="Brew Orange Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=502,
            product_name="Orange Potion",
            product_count=1,
            materials=[
                RecipeMaterial(508, "Red Herb", 1),
                RecipeMaterial(509, "Yellow Herb", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.70,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_yellow_potion",
            name="Brew Yellow Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=503,
            product_name="Yellow Potion",
            product_count=1,
            materials=[
                RecipeMaterial(509, "Yellow Herb", 2),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.65,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 3}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_white_potion",
            name="Brew White Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=504,
            product_name="White Potion",
            product_count=1,
            materials=[
                RecipeMaterial(510, "White Herb", 2),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.55,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 5}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_blue_potion",
            name="Brew Blue Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=505,
            product_name="Blue Potion",
            product_count=1,
            materials=[
                RecipeMaterial(511, "Blue Herb", 1),
                RecipeMaterial(512, "Green Herb", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.50,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 5}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_green_potion",
            name="Brew Green Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=506,
            product_name="Green Potion",
            product_count=1,
            materials=[
                RecipeMaterial(512, "Green Herb", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.75,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 1}
        ))
        
        # ========== CONDENSED POTIONS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_condensed_red",
            name="Brew Condensed Red Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=545,
            product_name="Condensed Red Potion",
            product_count=1,
            materials=[
                RecipeMaterial(501, "Red Potion", 1),
                RecipeMaterial(7134, "Empty Test Tube", 1),
            ],
            base_success_rate=0.60,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 3, "Prepare Potion": 3}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_condensed_yellow",
            name="Brew Condensed Yellow Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=546,
            product_name="Condensed Yellow Potion",
            product_count=1,
            materials=[
                RecipeMaterial(503, "Yellow Potion", 1),
                RecipeMaterial(7134, "Empty Test Tube", 1),
            ],
            base_success_rate=0.50,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 5, "Prepare Potion": 5}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="brew_condensed_white",
            name="Brew Condensed White Potion",
            crafting_type=CraftingType.PHARMACY,
            product_id=547,
            product_name="Condensed White Potion",
            product_count=1,
            materials=[
                RecipeMaterial(504, "White Potion", 1),
                RecipeMaterial(7134, "Empty Test Tube", 1),
            ],
            base_success_rate=0.40,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 7, "Prepare Potion": 7}
        ))
        
        # ========== ALCOHOL & CATALYSTS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_alcohol",
            name="Make Alcohol",
            crafting_type=CraftingType.PHARMACY,
            product_id=7033,
            product_name="Alcohol",
            product_count=1,
            materials=[
                RecipeMaterial(920, "Embers", 5),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.70,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_fire_bottle",
            name="Make Fire Bottle",
            crafting_type=CraftingType.PHARMACY,
            product_id=7135,
            product_name="Bottle Grenade",
            product_count=1,
            materials=[
                RecipeMaterial(7033, "Alcohol", 1),
                RecipeMaterial(910, "Garlet", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.50,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 3}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_acid_bottle",
            name="Make Acid Bottle",
            crafting_type=CraftingType.PHARMACY,
            product_id=7136,
            product_name="Acid Bottle",
            product_count=1,
            materials=[
                RecipeMaterial(7033, "Alcohol", 1),
                RecipeMaterial(918, "Sticky Mucus", 1),
                RecipeMaterial(713, "Empty Potion Bottle", 1),
            ],
            base_success_rate=0.50,
            required_job=JobClass.ALCHEMIST,
            required_skills={"Pharmacy": 3}
        ))
    
    def _init_cooking_recipes(self) -> None:
        """Initialize cooking recipes."""
        
        # ========== STAT FOODS ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_str_dish_a",
            name="STR Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12040,
            product_name="Fried Grasshopper Legs",
            product_count=1,
            materials=[
                RecipeMaterial(517, "Meat", 1),
                RecipeMaterial(945, "Stem", 5),
                RecipeMaterial(919, "Grasshopper's Leg", 5),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="STR +1 for 20 minutes"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_agi_dish_a",
            name="AGI Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12041,
            product_name="Grape Juice Herbal Tea",
            product_count=1,
            materials=[
                RecipeMaterial(678, "Grape", 2),
                RecipeMaterial(510, "White Herb", 3),
                RecipeMaterial(645, "Honey", 1),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="AGI +1 for 20 minutes"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_vit_dish_a",
            name="VIT Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12042,
            product_name="Fried Sweet Potato",
            product_count=1,
            materials=[
                RecipeMaterial(517, "Meat", 1),
                RecipeMaterial(568, "Sweet Potato", 5),
                RecipeMaterial(1024, "Cooking Oil", 1),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="VIT +1 for 20 minutes"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_int_dish_a",
            name="INT Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12043,
            product_name="Steamed Tongue",
            product_count=1,
            materials=[
                RecipeMaterial(578, "Tongue", 1),
                RecipeMaterial(917, "Flask", 1),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="INT +1 for 20 minutes"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_dex_dish_a",
            name="DEX Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12044,
            product_name="Fruit Mix",
            product_count=1,
            materials=[
                RecipeMaterial(521, "Apple", 3),
                RecipeMaterial(522, "Banana", 3),
                RecipeMaterial(678, "Grape", 3),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="DEX +1 for 20 minutes"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="cook_luk_dish_a",
            name="LUK Dish Grade A",
            crafting_type=CraftingType.COOKING,
            product_id=12045,
            product_name="Fried Monkey Tail",
            product_count=1,
            materials=[
                RecipeMaterial(517, "Meat", 1),
                RecipeMaterial(923, "Yoyo Tail", 5),
                RecipeMaterial(1024, "Cooking Oil", 1),
            ],
            base_success_rate=0.70,
            required_level=10,
            npc_required=True,
            npc_name="Chef",
            notes="LUK +1 for 20 minutes"
        ))
    
    def _init_arrow_recipes(self) -> None:
        """Initialize arrow crafting recipes."""
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_arrow",
            name="Make Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1750,
            product_name="Arrow",
            product_count=150,
            materials=[
                RecipeMaterial(1019, "Trunk", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.ARCHER,
            required_skills={"Arrow Crafting": 1}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_silver_arrow",
            name="Make Silver Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1751,
            product_name="Silver Arrow",
            product_count=100,
            materials=[
                RecipeMaterial(1019, "Trunk", 1),
                RecipeMaterial(969, "Silver Robe", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_fire_arrow",
            name="Make Fire Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1752,
            product_name="Fire Arrow",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(990, "Red Blood", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_steel_arrow",
            name="Make Steel Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1753,
            product_name="Steel Arrow",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(999, "Iron", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_crystal_arrow",
            name="Make Crystal Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1754,
            product_name="Crystal Arrow",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(991, "Crystal Blue", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_wind_arrow",
            name="Make Arrow of Wind",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1755,
            product_name="Arrow of Wind",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(992, "Wind of Verdure", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_stone_arrow",
            name="Make Stone Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1756,
            product_name="Stone Arrow",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(993, "Green Live", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 2}
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_holy_arrow",
            name="Make Holy Arrow",
            crafting_type=CraftingType.ARROW_CRAFTING,
            product_id=1762,
            product_name="Holy Arrow",
            product_count=50,
            materials=[
                RecipeMaterial(1750, "Arrow", 100),
                RecipeMaterial(1039, "Cardinal Jewel", 1),
            ],
            base_success_rate=1.0,
            required_job=JobClass.HUNTER,
            required_skills={"Arrow Crafting": 3}
        ))
    
    def _init_upgrade_recipes(self) -> None:
        """Initialize equipment upgrade recipes."""
        
        # ========== WEAPON UPGRADES (LEVEL 1-4) ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="refine_weapon_lv1",
            name="Refine Level 1 Weapon",
            crafting_type=CraftingType.REFINING,
            product_id=0,  # Product is the same item refined
            product_name="Refined Weapon +1",
            product_count=1,
            materials=[
                RecipeMaterial(1001, "Phracon", 1),
            ],
            base_success_rate=1.0,  # 100% up to +7
            npc_required=True,
            npc_name="Holgren",
            notes="Level 1 weapons, 100% up to +7"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="refine_weapon_lv2",
            name="Refine Level 2 Weapon",
            crafting_type=CraftingType.REFINING,
            product_id=0,
            product_name="Refined Weapon +1",
            product_count=1,
            materials=[
                RecipeMaterial(1002, "Emveretarcon", 1),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Holgren",
            notes="Level 2 weapons, 100% up to +7"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="refine_weapon_lv3",
            name="Refine Level 3 Weapon",
            crafting_type=CraftingType.REFINING,
            product_id=0,
            product_name="Refined Weapon +1",
            product_count=1,
            materials=[
                RecipeMaterial(984, "Oridecon", 1),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Holgren",
            notes="Level 3 weapons, 100% up to +7, decreasing after"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="refine_weapon_lv4",
            name="Refine Level 4 Weapon",
            crafting_type=CraftingType.REFINING,
            product_id=0,
            product_name="Refined Weapon +1",
            product_count=1,
            materials=[
                RecipeMaterial(984, "Oridecon", 1),
            ],
            base_success_rate=0.90,  # Starts lower for lv4
            npc_required=True,
            npc_name="Holgren",
            notes="Level 4 weapons, higher risk"
        ))
        
        # ========== ARMOR UPGRADES ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="refine_armor",
            name="Refine Armor",
            crafting_type=CraftingType.REFINING,
            product_id=0,
            product_name="Refined Armor +1",
            product_count=1,
            materials=[
                RecipeMaterial(985, "Elunium", 1),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Holgren",
            notes="All armor types, 100% up to +4"
        ))
        
        # ========== RAW ORE PROCESSING ==========
        
        self._add_recipe(CraftingRecipe(
            recipe_id="process_oridecon",
            name="Process Oridecon",
            crafting_type=CraftingType.COMBINATION,
            product_id=984,
            product_name="Oridecon",
            product_count=1,
            materials=[
                RecipeMaterial(756, "Rough Oridecon", 5),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Blacksmith NPC"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="process_elunium",
            name="Process Elunium",
            crafting_type=CraftingType.COMBINATION,
            product_id=985,
            product_name="Elunium",
            product_count=1,
            materials=[
                RecipeMaterial(757, "Rough Elunium", 5),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Blacksmith NPC"
        ))
        
        self._add_recipe(CraftingRecipe(
            recipe_id="make_steel",
            name="Make Steel",
            crafting_type=CraftingType.COMBINATION,
            product_id=1011,
            product_name="Steel",
            product_count=1,
            materials=[
                RecipeMaterial(999, "Iron", 5),
                RecipeMaterial(1000, "Coal", 1),
            ],
            base_success_rate=1.0,
            npc_required=True,
            npc_name="Blacksmith NPC"
        ))
    
    def _add_recipe(self, recipe: CraftingRecipe) -> None:
        """Add a recipe to the database."""
        self.recipes[recipe.recipe_id] = recipe
    
    def _build_indexes(self) -> None:
        """Build lookup indexes."""
        for recipe_id, recipe in self.recipes.items():
            # Product index
            if recipe.product_id not in self._product_to_recipes:
                self._product_to_recipes[recipe.product_id] = []
            self._product_to_recipes[recipe.product_id].append(recipe_id)
            
            # Material index
            for mat in recipe.materials:
                if mat.item_id not in self._material_to_recipes:
                    self._material_to_recipes[mat.item_id] = []
                self._material_to_recipes[mat.item_id].append(recipe_id)
            
            # Type index
            if recipe.crafting_type not in self._type_to_recipes:
                self._type_to_recipes[recipe.crafting_type] = []
            self._type_to_recipes[recipe.crafting_type].append(recipe_id)
        
        self.log.debug(
            "indexes_built",
            products=len(self._product_to_recipes),
            materials=len(self._material_to_recipes),
            types=len(self._type_to_recipes)
        )
    
    def _load_custom_recipes(self, data_dir: Path) -> None:
        """Load custom recipe definitions from JSON."""
        custom_file = data_dir / "crafting_recipes.json"
        
        if not custom_file.exists():
            self.log.debug("no_custom_recipes", path=str(custom_file))
            return
        
        try:
            with open(custom_file, 'r') as f:
                data = json.load(f)
            
            for recipe_data in data.get("recipes", []):
                materials = [
                    RecipeMaterial(
                        item_id=m["item_id"],
                        item_name=m["item_name"],
                        quantity=m["quantity"],
                        consumed=m.get("consumed", True)
                    )
                    for m in recipe_data.get("materials", [])
                ]
                
                recipe = CraftingRecipe(
                    recipe_id=recipe_data["recipe_id"],
                    name=recipe_data["name"],
                    crafting_type=CraftingType(recipe_data["crafting_type"]),
                    product_id=recipe_data["product_id"],
                    product_name=recipe_data["product_name"],
                    product_count=recipe_data.get("product_count", 1),
                    materials=materials,
                    base_success_rate=recipe_data.get("base_success_rate", 1.0),
                    required_job=JobClass(recipe_data.get("required_job", "none")),
                    required_level=recipe_data.get("required_level", 1),
                    required_skills=recipe_data.get("required_skills", {}),
                    npc_required=recipe_data.get("npc_required", False),
                    npc_name=recipe_data.get("npc_name", ""),
                    catalyst_id=recipe_data.get("catalyst_id"),
                    notes=recipe_data.get("notes", "")
                )
                self._add_recipe(recipe)
            
            self.log.info(
                "custom_recipes_loaded",
                count=len(data.get("recipes", []))
            )
        
        except Exception as e:
            self.log.error("custom_recipes_load_failed", error=str(e))
    
    def save_recipes(self, filepath: Path) -> None:
        """Save current recipes to JSON file."""
        data = {
            "recipes": [
                {
                    "recipe_id": r.recipe_id,
                    "name": r.name,
                    "crafting_type": r.crafting_type.value,
                    "product_id": r.product_id,
                    "product_name": r.product_name,
                    "product_count": r.product_count,
                    "materials": [
                        {
                            "item_id": m.item_id,
                            "item_name": m.item_name,
                            "quantity": m.quantity,
                            "consumed": m.consumed
                        }
                        for m in r.materials
                    ],
                    "base_success_rate": r.base_success_rate,
                    "required_job": r.required_job.value,
                    "required_level": r.required_level,
                    "required_skills": r.required_skills,
                    "npc_required": r.npc_required,
                    "npc_name": r.npc_name,
                    "catalyst_id": r.catalyst_id,
                    "notes": r.notes
                }
                for r in self.recipes.values()
            ]
        }
        
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        
        self.log.info("recipes_saved", path=str(filepath))