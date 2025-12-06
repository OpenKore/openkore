"""
Item Category Database - Hierarchical item categorization for RO items.

Features:
- Hierarchical category structure
- RO item ID range mapping
- Efficient O(1) lookups via pre-built index
- Server-specific customization support
- Category relationship tracking
"""

import json
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Dict, FrozenSet, List, Optional, Set, Tuple

import structlog

logger = structlog.get_logger(__name__)


class CategoryType(str, Enum):
    """Main category types"""
    CONSUMABLE = "consumable"
    EQUIPMENT = "equipment"
    MATERIAL = "material"
    CARD = "card"
    AMMUNITION = "ammunition"
    QUEST = "quest"
    MISC = "misc"


@dataclass
class ItemCategory:
    """
    Item category definition with hierarchical support.
    
    Attributes:
        category_id: Unique category identifier
        name: Human-readable category name
        category_type: Main category type
        parent_category: Parent category ID for hierarchy
        item_id_ranges: List of (start, end) tuples for item ID ranges
        item_ids: Explicit set of item IDs in this category
        description: Category description
        tags: Additional classification tags
    """
    category_id: str
    name: str
    category_type: CategoryType
    parent_category: Optional[str] = None
    item_id_ranges: List[Tuple[int, int]] = field(default_factory=list)
    item_ids: Set[int] = field(default_factory=set)
    description: str = ""
    tags: Set[str] = field(default_factory=set)
    
    def contains_item(self, item_id: int) -> bool:
        """Check if item belongs to this category."""
        if item_id in self.item_ids:
            return True
        for start, end in self.item_id_ranges:
            if start <= item_id <= end:
                return True
        return False
    
    def get_all_item_ids(self) -> Set[int]:
        """Get all item IDs in this category (explicit + ranges)."""
        all_ids = self.item_ids.copy()
        for start, end in self.item_id_ranges:
            all_ids.update(range(start, end + 1))
        return all_ids


class ItemCategoryDatabase:
    """
    Database of item categories with efficient lookup.
    
    Features:
    - Pre-built index for O(1) item-to-category lookup
    - Hierarchical category navigation
    - Server-specific customization
    - Category relationship queries
    """
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize item category database.
        
        Args:
            data_dir: Optional directory for custom category data
        """
        self.log = logger.bind(system="item_categories")
        self.data_dir = data_dir
        
        # Category storage
        self.categories: Dict[str, ItemCategory] = {}
        
        # Pre-built index: item_id -> category_id
        self._item_to_category: Dict[int, str] = {}
        
        # Child categories index: parent_id -> [child_ids]
        self._children: Dict[str, List[str]] = {}
        
        # Initialize with default RO categories
        self._init_default_categories()
        
        # Load custom categories if available
        if data_dir:
            self._load_custom_categories(data_dir)
        
        # Build lookup index
        self._build_index()
        
        self.log.info(
            "item_categories_initialized",
            category_count=len(self.categories),
            indexed_items=len(self._item_to_category)
        )
    
    def get_category(self, item_id: int) -> Optional[ItemCategory]:
        """
        Get category for an item.
        
        Args:
            item_id: Item ID to look up
            
        Returns:
            ItemCategory or None if not found
        """
        category_id = self._item_to_category.get(item_id)
        if category_id:
            return self.categories.get(category_id)
        
        # Fallback: scan ranges (slower)
        for category in self.categories.values():
            if category.contains_item(item_id):
                # Cache for future lookups
                self._item_to_category[item_id] = category.category_id
                return category
        
        return None
    
    def get_category_id(self, item_id: int) -> Optional[str]:
        """Get category ID for an item."""
        if item_id in self._item_to_category:
            return self._item_to_category[item_id]
        
        category = self.get_category(item_id)
        return category.category_id if category else None
    
    def get_items_in_category(self, category_id: str) -> Set[int]:
        """
        Get all item IDs in a category.
        
        Args:
            category_id: Category identifier
            
        Returns:
            Set of item IDs
        """
        category = self.categories.get(category_id)
        if not category:
            return set()
        return category.get_all_item_ids()
    
    def get_items_in_category_tree(self, category_id: str) -> Set[int]:
        """
        Get all item IDs in a category and its children.
        
        Args:
            category_id: Category identifier
            
        Returns:
            Set of item IDs including subcategories
        """
        items = self.get_items_in_category(category_id)
        
        # Include children
        for child_id in self._children.get(category_id, []):
            items.update(self.get_items_in_category_tree(child_id))
        
        return items
    
    def get_sibling_items(self, item_id: int) -> Set[int]:
        """
        Get items in the same category as the given item.
        
        Args:
            item_id: Item ID
            
        Returns:
            Set of related item IDs (excluding the input item)
        """
        category_id = self.get_category_id(item_id)
        if not category_id:
            return set()
        
        siblings = self.get_items_in_category(category_id)
        siblings.discard(item_id)
        return siblings
    
    def get_parent_category(self, category_id: str) -> Optional[ItemCategory]:
        """Get parent category."""
        category = self.categories.get(category_id)
        if category and category.parent_category:
            return self.categories.get(category.parent_category)
        return None
    
    def get_child_categories(self, category_id: str) -> List[ItemCategory]:
        """Get child categories."""
        child_ids = self._children.get(category_id, [])
        return [self.categories[cid] for cid in child_ids if cid in self.categories]
    
    def get_category_type(self, item_id: int) -> Optional[CategoryType]:
        """Get main category type for an item."""
        category = self.get_category(item_id)
        return category.category_type if category else None
    
    def is_consumable(self, item_id: int) -> bool:
        """Check if item is consumable."""
        return self.get_category_type(item_id) == CategoryType.CONSUMABLE
    
    def is_equipment(self, item_id: int) -> bool:
        """Check if item is equipment."""
        return self.get_category_type(item_id) == CategoryType.EQUIPMENT
    
    def is_material(self, item_id: int) -> bool:
        """Check if item is a material."""
        return self.get_category_type(item_id) == CategoryType.MATERIAL
    
    def is_card(self, item_id: int) -> bool:
        """Check if item is a card."""
        return self.get_category_type(item_id) == CategoryType.CARD
    
    def add_custom_category(self, category: ItemCategory) -> None:
        """
        Add a custom category.
        
        Args:
            category: Category to add
        """
        self.categories[category.category_id] = category
        
        # Update parent-child index
        if category.parent_category:
            if category.parent_category not in self._children:
                self._children[category.parent_category] = []
            self._children[category.parent_category].append(category.category_id)
        
        # Update item index
        for item_id in category.item_ids:
            self._item_to_category[item_id] = category.category_id
        for start, end in category.item_id_ranges:
            for item_id in range(start, end + 1):
                self._item_to_category[item_id] = category.category_id
        
        self.log.debug(
            "custom_category_added",
            category_id=category.category_id,
            name=category.name
        )
    
    def _init_default_categories(self) -> None:
        """Initialize default RO item categories with real ID ranges."""
        
        # ========== CONSUMABLES ==========
        
        # HP Recovery Items
        self._add_category(ItemCategory(
            category_id="consumable_hp",
            name="HP Recovery Items",
            category_type=CategoryType.CONSUMABLE,
            parent_category="consumable",
            item_id_ranges=[
                (501, 512),   # Red Potions, Orange, Yellow, White, Blue
                (545, 549),   # Condensed Potions
                (11500, 11520),  # Renewal HP items
            ],
            item_ids={
                501,   # Red Potion
                502,   # Orange Potion
                503,   # Yellow Potion
                504,   # White Potion
                505,   # Blue Potion
                506,   # Green Potion
                545,   # Condensed Red Potion
                546,   # Condensed Yellow Potion
                547,   # Condensed White Potion
                607,   # Yggdrasil Berry
                608,   # Yggdrasil Seed
                12192, # Mastela Fruit
            },
            description="Items that restore HP",
            tags={"healing", "recovery", "hp"}
        ))
        
        # SP Recovery Items
        self._add_category(ItemCategory(
            category_id="consumable_sp",
            name="SP Recovery Items",
            category_type=CategoryType.CONSUMABLE,
            parent_category="consumable",
            item_ids={
                505,   # Blue Potion
                645,   # Honey
                12016, # Speed Potion
                678,   # Grape Juice
                12192, # Royal Jelly
            },
            description="Items that restore SP",
            tags={"healing", "recovery", "sp"}
        ))
        
        # Status Recovery Items
        self._add_category(ItemCategory(
            category_id="consumable_status",
            name="Status Recovery Items",
            category_type=CategoryType.CONSUMABLE,
            parent_category="consumable",
            item_ids={
                506,   # Green Potion
                525,   # Panacea
                526,   # Royal Jelly
                528,   # Monster's Feed
                605,   # Anodyne
                606,   # Aloevera
            },
            description="Items that cure status effects",
            tags={"cure", "status", "recovery"}
        ))
        
        # Buff Items
        self._add_category(ItemCategory(
            category_id="consumable_buff",
            name="Buff Items",
            category_type=CategoryType.CONSUMABLE,
            parent_category="consumable",
            item_id_ranges=[
                (12000, 12100),  # Various buff foods
            ],
            item_ids={
                656,   # Authoritative Badge
                657,   # Berserk Potion
                7135,  # Speed Potion
                12016, # Speed Potion
                12028, # Str Dish
                12029, # Agi Dish
                12030, # Int Dish
                12031, # Dex Dish
                12032, # Luk Dish
                12033, # Vit Dish
            },
            description="Items that provide temporary buffs",
            tags={"buff", "stat", "temporary"}
        ))
        
        # Cooking/Food Items
        self._add_category(ItemCategory(
            category_id="consumable_food",
            name="Cooking/Food Items",
            category_type=CategoryType.CONSUMABLE,
            parent_category="consumable",
            item_id_ranges=[
                (12040, 12090),  # Cooked foods
                (12200, 12250),  # Special foods
            ],
            item_ids={
                517,   # Meat
                518,   # Honey
                519,   # Milk
                520,   # Grape
                521,   # Apple
                522,   # Banana
                523,   # Carrot
                528,   # Monster's Feed
                529,   # Pet Food
                12040, # Str Dish A
            },
            description="Food items that can be eaten",
            tags={"food", "cooking", "eat"}
        ))
        
        # Root category for consumables
        self._add_category(ItemCategory(
            category_id="consumable",
            name="Consumables",
            category_type=CategoryType.CONSUMABLE,
            item_id_ranges=[
                (501, 700),    # Basic consumables
                (11500, 12500),  # Renewal consumables
            ],
            description="All consumable items",
            tags={"consumable", "use"}
        ))
        
        # ========== EQUIPMENT ==========
        
        # Weapons - Swords
        self._add_category(ItemCategory(
            category_id="weapon_sword",
            name="Swords",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1101, 1200),  # One-handed swords
                (1151, 1199),  # Two-handed swords
            ],
            item_ids={
                1101,  # Sword
                1104,  # Falchion
                1107,  # Blade
                1108,  # Ring Pommel Saber
                1109,  # Haedonggum
                1116,  # Cutlus
                1117,  # Solar Sword
                1119,  # Byeollungum
                1151,  # Slayer
                1152,  # Bastard Sword
                1153,  # Two-handed Sword
            },
            description="Sword-type weapons",
            tags={"weapon", "sword", "melee"}
        ))
        
        # Weapons - Daggers
        self._add_category(ItemCategory(
            category_id="weapon_dagger",
            name="Daggers",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1201, 1299),  # Daggers
            ],
            item_ids={
                1201,  # Knife
                1202,  # Cutter
                1204,  # Main Gauche
                1205,  # Dirk
                1207,  # Stiletto
                1208,  # Gladius
                1209,  # Damascus
                1210,  # Fortune Sword
                1211,  # Sword Breaker
            },
            description="Dagger-type weapons",
            tags={"weapon", "dagger", "melee", "assassin", "thief"}
        ))
        
        # Weapons - Axes
        self._add_category(ItemCategory(
            category_id="weapon_axe",
            name="Axes",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1301, 1399),  # One-handed axes
                (1351, 1399),  # Two-handed axes
            ],
            item_ids={
                1301,  # Axe
                1302,  # Battle Axe
                1351,  # Two-handed Axe
                1352,  # Buster
                1354,  # Great Axe
            },
            description="Axe-type weapons",
            tags={"weapon", "axe", "melee", "merchant", "blacksmith"}
        ))
        
        # Weapons - Spears
        self._add_category(ItemCategory(
            category_id="weapon_spear",
            name="Spears",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1401, 1499),  # Spears
            ],
            item_ids={
                1401,  # Javelin
                1402,  # Spear
                1403,  # Pike
                1404,  # Guisarme
                1405,  # Glaive
                1406,  # Partizan
                1407,  # Trident
                1408,  # Halberd
                1409,  # Lance
            },
            description="Spear-type weapons",
            tags={"weapon", "spear", "melee", "knight", "crusader"}
        ))
        
        # Weapons - Maces
        self._add_category(ItemCategory(
            category_id="weapon_mace",
            name="Maces",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1501, 1599),  # Maces
            ],
            item_ids={
                1501,  # Club
                1502,  # Mace
                1503,  # Smasher
                1504,  # Flail
                1505,  # Morning Star
                1506,  # Sword Mace
                1510,  # Grand Cross
            },
            description="Mace-type weapons",
            tags={"weapon", "mace", "melee", "acolyte", "priest"}
        ))
        
        # Weapons - Staves
        self._add_category(ItemCategory(
            category_id="weapon_staff",
            name="Staves",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1601, 1699),  # Staves/Rods
            ],
            item_ids={
                1601,  # Rod
                1602,  # Wand
                1603,  # Staff
                1604,  # Arc Wand
                1605,  # Mighty Staff
                1606,  # Soul Staff
                1607,  # Wizardry Staff
                1613,  # Lich's Bone Wand
            },
            description="Staff-type weapons",
            tags={"weapon", "staff", "magic", "mage", "wizard"}
        ))
        
        # Weapons - Bows
        self._add_category(ItemCategory(
            category_id="weapon_bow",
            name="Bows",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1701, 1799),  # Bows
            ],
            item_ids={
                1701,  # Bow
                1702,  # Composite Bow
                1703,  # Great Bow
                1704,  # Crossbow
                1705,  # Arbalest
                1706,  # Kakkung
                1708,  # Hunter Bow
                1709,  # Gakkung
            },
            description="Bow-type weapons",
            tags={"weapon", "bow", "ranged", "archer", "hunter"}
        ))
        
        # Weapons - Katars
        self._add_category(ItemCategory(
            category_id="weapon_katar",
            name="Katars",
            category_type=CategoryType.EQUIPMENT,
            parent_category="weapon",
            item_id_ranges=[
                (1250, 1299),  # Katars
            ],
            item_ids={
                1250,  # Jur
                1251,  # Katar
                1252,  # Jamadhar
                1253,  # Infiltrator
                1254,  # Sharpened Legbone
                1255,  # Bloody Roar
            },
            description="Katar-type weapons",
            tags={"weapon", "katar", "melee", "assassin"}
        ))
        
        # Root category for weapons
        self._add_category(ItemCategory(
            category_id="weapon",
            name="Weapons",
            category_type=CategoryType.EQUIPMENT,
            parent_category="equipment",
            item_id_ranges=[
                (1101, 1999),  # All weapon IDs
            ],
            description="All weapon items",
            tags={"weapon", "equipment"}
        ))
        
        # Armor - Headgear
        self._add_category(ItemCategory(
            category_id="armor_headgear",
            name="Headgear",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2201, 2500),  # Headgear upper/mid
                (5001, 5500),  # Headgear lower/costumes
            ],
            item_ids={
                2201,  # Cap
                2202,  # Goggles
                2203,  # Biretta
                2206,  # Helmet
                2210,  # Mask
                2211,  # Monk Hat
                2214,  # Hat
                2215,  # Circlet
                2220,  # Crown
                2228,  # Beret
            },
            description="Head equipment",
            tags={"armor", "headgear", "head"}
        ))
        
        # Armor - Body Armor
        self._add_category(ItemCategory(
            category_id="armor_body",
            name="Body Armor",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2301, 2400),  # Body armor
            ],
            item_ids={
                2301,  # Cotton Shirt
                2302,  # Leather Jacket
                2303,  # Adventure Suit
                2304,  # Mantle
                2305,  # Coat
                2306,  # Mink Coat
                2307,  # Padded Armor
                2308,  # Chain Mail
                2309,  # Plate Armor
                2310,  # Clothes of the Lord
                2312,  # Tights
                2313,  # Silver Robe
                2314,  # Mage Coat
                2315,  # Thief Clothes
                2317,  # Full Plate
                2318,  # Formal Suit
            },
            description="Body armor equipment",
            tags={"armor", "body", "chest"}
        ))
        
        # Armor - Shield
        self._add_category(ItemCategory(
            category_id="armor_shield",
            name="Shields",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2101, 2200),  # Shields
            ],
            item_ids={
                2101,  # Guard
                2102,  # Buckler
                2103,  # Shield
                2104,  # Mirror Shield
                2105,  # Memorize Book
                2106,  # Holy Guard
                2107,  # Herald of GOD
                2108,  # Novice Shield
                2109,  # Stone Buckler
            },
            description="Shield equipment",
            tags={"armor", "shield", "defense"}
        ))
        
        # Armor - Footgear
        self._add_category(ItemCategory(
            category_id="armor_footgear",
            name="Footgear",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2401, 2500),  # Footgear
            ],
            item_ids={
                2401,  # Sandals
                2402,  # Shoes
                2403,  # Boots
                2404,  # Chrystal Pumps
                2405,  # Cuffs
                2406,  # Spiky Heels
                2407,  # Greaves
                2408,  # Safety Shoes
                2409,  # High Heels
            },
            description="Foot equipment",
            tags={"armor", "footgear", "feet", "shoes"}
        ))
        
        # Armor - Garment
        self._add_category(ItemCategory(
            category_id="armor_garment",
            name="Garments",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2501, 2600),  # Garments
            ],
            item_ids={
                2501,  # Hood
                2502,  # Muffler
                2503,  # Manteau
                2504,  # Cape of Ancient Lord
                2505,  # Ragamuffin Manteau
                2506,  # Clack of Survival
                2507,  # Novice Manteau
                2508,  # Skeleton Manteau
                2509,  # Undershirt
                2510,  # Gangster Scarf
            },
            description="Garment/cloak equipment",
            tags={"armor", "garment", "cloak", "cape"}
        ))
        
        # Accessories
        self._add_category(ItemCategory(
            category_id="armor_accessory",
            name="Accessories",
            category_type=CategoryType.EQUIPMENT,
            parent_category="armor",
            item_id_ranges=[
                (2601, 2800),  # Accessories
            ],
            item_ids={
                2601,  # Ring
                2602,  # Earring
                2603,  # Necklace
                2604,  # Gloves
                2605,  # Brooch
                2607,  # Clip
                2608,  # Rosary
                2609,  # Skull Ring
                2610,  # Gold Ring
                2611,  # Silver Ring
                2612,  # Flower Ring
                2613,  # Diamond Ring
                2614,  # Critical Ring
                2615,  # Belt
            },
            description="Accessory equipment",
            tags={"armor", "accessory", "jewelry"}
        ))
        
        # Root category for armor
        self._add_category(ItemCategory(
            category_id="armor",
            name="Armor",
            category_type=CategoryType.EQUIPMENT,
            parent_category="equipment",
            item_id_ranges=[
                (2101, 2800),  # All armor IDs
                (5001, 5500),  # Headgear costumes
            ],
            description="All armor items",
            tags={"armor", "equipment", "defense"}
        ))
        
        # Root category for equipment
        self._add_category(ItemCategory(
            category_id="equipment",
            name="Equipment",
            category_type=CategoryType.EQUIPMENT,
            item_id_ranges=[
                (1101, 2999),  # Weapons and armor
                (5001, 5999),  # Additional equipment
            ],
            description="All equipment items",
            tags={"equipment"}
        ))
        
        # ========== MATERIALS ==========
        
        # Crafting Materials - Ores
        self._add_category(ItemCategory(
            category_id="material_ore",
            name="Ores",
            category_type=CategoryType.MATERIAL,
            parent_category="material",
            item_ids={
                756,   # Rough Oridecon
                757,   # Rough Elunium
                984,   # Oridecon
                985,   # Elunium
                1010,  # Mithril
                1011,  # Steel
                999,   # Iron
                1000,  # Coal
                1001,  # Phracon
                1002,  # Emveretarcon
                7049,  # Iron Ore
                7050,  # Coal
            },
            description="Ore materials for forging",
            tags={"material", "ore", "forging", "blacksmith"}
        ))
        
        # Crafting Materials - Potions/Pharmacy
        self._add_category(ItemCategory(
            category_id="material_pharmacy",
            name="Pharmacy Materials",
            category_type=CategoryType.MATERIAL,
            parent_category="material",
            item_ids={
                506,   # Green Potion (ingredient)
                508,   # Red Herb
                509,   # Yellow Herb
                510,   # White Herb
                511,   # Blue Herb
                512,   # Green Herb
                520,   # Empty Bottle
                713,   # Empty Potion Bottle
                716,   # Glass Tube
                717,   # Medicine Bowl
                7033,  # Alcohol
                7134,  # Empty Potion Bottle
                1054,  # Fabric
            },
            description="Materials for potion crafting",
            tags={"material", "pharmacy", "alchemist", "potion"}
        ))
        
        # Crafting Materials - Cooking
        self._add_category(ItemCategory(
            category_id="material_cooking",
            name="Cooking Ingredients",
            category_type=CategoryType.MATERIAL,
            parent_category="material",
            item_ids={
                517,   # Meat
                528,   # Monster's Feed
                568,   # Cheese
                569,   # Piece of Cake
                570,   # Candy
                571,   # Well-Baked Cookie
                578,   # Squid Ink
                579,   # Fine Grit
                580,   # Salt
                901,   # Bear's Footskin
                1060,  # Pot
            },
            description="Ingredients for cooking",
            tags={"material", "cooking", "chef", "food"}
        ))
        
        # Monster Drops - Generic
        self._add_category(ItemCategory(
            category_id="material_monster_drop",
            name="Monster Drops",
            category_type=CategoryType.MATERIAL,
            parent_category="material",
            item_id_ranges=[
                (901, 1100),   # Monster drops
                (7001, 7500),  # More monster drops
            ],
            item_ids={
                901,   # Bear's Footskin
                902,   # Spider Web
                903,   # Bear Claw
                904,   # Wolf Claw
                905,   # Raccoon Leaf
                906,   # Acorn
                907,   # Bill of Birds
                908,   # Heart of Mermaid
                909,   # Jellopy
                910,   # Garlet
                911,   # Scell
                912,   # Zargon
                913,   # Tooth of Bat
                914,   # Fluff
                915,   # Chrysalis
                916,   # Feather of Birds
                917,   # Talon
                918,   # Sticky Mucus
                919,   # Decayed Nail
                920,   # Horrendous Mouth
                921,   # Powder of Butterfly
                922,   # Bill of Bird
                923,   # Claw of Wolves
                924,   # Mushroom Spore
                925,   # Orc's Fang
                926,   # Evil Horn
                928,   # Scorpion Tail
                929,   # Shell
                930,   # Scale Shell
                931,   # Venom Canine
            },
            description="Materials dropped by monsters",
            tags={"material", "drop", "monster", "loot"}
        ))
        
        # Root category for materials
        self._add_category(ItemCategory(
            category_id="material",
            name="Materials",
            category_type=CategoryType.MATERIAL,
            item_id_ranges=[
                (901, 1100),
                (7001, 7999),
            ],
            description="All crafting and quest materials",
            tags={"material", "crafting"}
        ))
        
        # ========== CARDS ==========
        
        # Cards - Weapon
        self._add_category(ItemCategory(
            category_id="card_weapon",
            name="Weapon Cards",
            category_type=CategoryType.CARD,
            parent_category="card",
            item_ids={
                4001,  # Poring Card
                4002,  # Fabre Card
                4003,  # Pupa Card
                4004,  # Condor Card
                4005,  # Thief Bug Egg Card
                4009,  # Mandragora Card
                4012,  # Pecopeco Egg Card
                4014,  # Andre Egg Card
                4015,  # Roda Frog Card
                4019,  # Picky Card
                4021,  # Chonchon Card
                4025,  # Familiar Card
                4027,  # Rocker Card
                4029,  # Spore Card
                4031,  # Desert Wolf Card
                4035,  # Vadon Card
                4038,  # Marina Card
                4040,  # Cornutus Card
                4047,  # Mummy Card
                4050,  # Drainliar Card
            },
            description="Cards for weapon slots",
            tags={"card", "weapon", "slot"}
        ))
        
        # Cards - Armor
        self._add_category(ItemCategory(
            category_id="card_armor",
            name="Armor Cards",
            category_type=CategoryType.CARD,
            parent_category="card",
            item_ids={
                4007,  # Steel Chonchon Card
                4008,  # Thief Bug Card
                4010,  # Kukre Card
                4011,  # Tarou Card
                4013,  # Thief Bug Female Card
                4016,  # Ambernite Card
                4018,  # Poison Spore Card
                4020,  # Willow Card
                4022,  # Roda Frog Card
                4023,  # Condor Card
                4032,  # Deviruchi Card
                4033,  # Argos Card
                4039,  # Giearth Card
                4041,  # Cornutus Card
                4044,  # Eggyra Card
                4048,  # Verit Card
                4049,  # Merman Card
                4052,  # Megalodon Card
            },
            description="Cards for armor slots",
            tags={"card", "armor", "slot"}
        ))
        
        # Cards - Boss/MVP
        self._add_category(ItemCategory(
            category_id="card_mvp",
            name="MVP Cards",
            category_type=CategoryType.CARD,
            parent_category="card",
            item_ids={
                4121,  # Orc Hero Card
                4123,  # Orc Lord Card
                4128,  # Golden Thief Bug Card
                4131,  # Maya Card
                4132,  # Mistress Card
                4134,  # Osiris Card
                4135,  # Pharaoh Card
                4137,  # Eddga Card
                4142,  # Doppelganger Card
                4143,  # Baphomet Card
                4144,  # Dracula Card
                4145,  # Dark Lord Card
                4146,  # Stormy Knight Card
                4147,  # Hatii Card
                4148,  # Moonlight Flower Card
                4163,  # Lord of Death Card
                4168,  # Ktullanux Card
                4174,  # Detardeurus Card
                4302,  # Tao Gunka Card
                4305,  # Thanatos Card
            },
            description="Rare MVP boss cards",
            tags={"card", "mvp", "boss", "rare"}
        ))
        
        # Root category for cards
        self._add_category(ItemCategory(
            category_id="card",
            name="Cards",
            category_type=CategoryType.CARD,
            item_id_ranges=[
                (4001, 4999),  # Card ID range
            ],
            description="All monster cards",
            tags={"card", "slot"}
        ))
        
        # ========== AMMUNITION ==========
        
        # Arrows
        self._add_category(ItemCategory(
            category_id="ammo_arrow",
            name="Arrows",
            category_type=CategoryType.AMMUNITION,
            parent_category="ammunition",
            item_ids={
                1750,  # Arrow
                1751,  # Silver Arrow
                1752,  # Fire Arrow
                1753,  # Steel Arrow
                1754,  # Crystal Arrow
                1755,  # Arrow of Wind
                1756,  # Stone Arrow
                1757,  # Immaterial Arrow
                1758,  # Stun Arrow
                1759,  # Cursed Arrow
                1760,  # Rusty Arrow
                1761,  # Poison Arrow
                1762,  # Holy Arrow
                1763,  # Flash Arrow
                1764,  # Freezing Arrow
                1765,  # Hunting Arrow
            },
            description="Arrow ammunition",
            tags={"ammo", "arrow", "archer", "hunter"}
        ))
        
        # Bullets
        self._add_category(ItemCategory(
            category_id="ammo_bullet",
            name="Bullets",
            category_type=CategoryType.AMMUNITION,
            parent_category="ammunition",
            item_ids={
                13200, # Bullet
                13201, # Silver Bullet
                13202, # Shell
                13203, # Blood Bullet
                13204, # Flare Bullet
                13205, # Lightning Bullet
                13206, # Ice Bullet
                13207, # Poison Bullet
                13208, # Blind Bullet
                13209, # Full Metal Jacket
                13210, # AP Ammo
                13211, # Grenade
            },
            description="Bullet ammunition",
            tags={"ammo", "bullet", "gunslinger"}
        ))
        
        # Root category for ammunition
        self._add_category(ItemCategory(
            category_id="ammunition",
            name="Ammunition",
            category_type=CategoryType.AMMUNITION,
            item_id_ranges=[
                (1750, 1799),   # Arrows
                (13200, 13300), # Bullets
            ],
            description="All ammunition items",
            tags={"ammo", "ammunition", "ranged"}
        ))
        
        # ========== QUEST ITEMS ==========
        
        self._add_category(ItemCategory(
            category_id="quest",
            name="Quest Items",
            category_type=CategoryType.QUEST,
            item_id_ranges=[
                (6000, 6500),  # Quest items
                (7500, 7999),  # More quest items
            ],
            item_ids={
                6001,  # Voucher
                6002,  # Memorandum
                6011,  # Key
                6012,  # Bloody Key
                6050,  # Ancient Tooth
                7001,  # Skel-Bone
                7002,  # Lantern
                7031,  # Peco Peco Feather
            },
            description="Quest-related items",
            tags={"quest", "mission"}
        ))
        
        # ========== MISC ITEMS ==========
        
        # Pet Items
        self._add_category(ItemCategory(
            category_id="misc_pet",
            name="Pet Items",
            category_type=CategoryType.MISC,
            parent_category="misc",
            item_id_ranges=[
                (9001, 9100),  # Pet eggs
                (10000, 10100),  # Pet equipment
            ],
            item_ids={
                529,   # Pet Food
                537,   # Pet Incubator
                640,   # Lunatic Pet
            },
            description="Pet-related items",
            tags={"pet", "taming"}
        ))
        
        # Gemstones/Catalysts
        self._add_category(ItemCategory(
            category_id="misc_catalyst",
            name="Spell Catalysts",
            category_type=CategoryType.MISC,
            parent_category="misc",
            item_ids={
                715,   # Yellow Gemstone
                716,   # Red Gemstone
                717,   # Blue Gemstone
                718,   # Cursed Ruby
                719,   # Sparkling Crystal
                720,   # Cursed Water
            },
            description="Catalysts for skills and spells",
            tags={"catalyst", "gemstone", "skill"}
        ))
        
        # Root category for misc
        self._add_category(ItemCategory(
            category_id="misc",
            name="Miscellaneous",
            category_type=CategoryType.MISC,
            item_id_ranges=[
                (700, 900),    # Misc items
                (9001, 10999), # Pet items
            ],
            description="Miscellaneous items",
            tags={"misc"}
        ))
    
    def _add_category(self, category: ItemCategory) -> None:
        """Add a category to the database."""
        self.categories[category.category_id] = category
        
        # Update parent-child index
        if category.parent_category:
            if category.parent_category not in self._children:
                self._children[category.parent_category] = []
            if category.category_id not in self._children[category.parent_category]:
                self._children[category.parent_category].append(category.category_id)
    
    def _build_index(self) -> None:
        """Build item-to-category lookup index."""
        # Index explicit item IDs first (more specific)
        for category in self.categories.values():
            for item_id in category.item_ids:
                # Don't override more specific categories
                if item_id not in self._item_to_category:
                    self._item_to_category[item_id] = category.category_id
        
        # Don't index ranges - let get_category handle them dynamically
        # This prevents memory bloat from large ranges
        
        self.log.debug(
            "index_built",
            explicit_items=len(self._item_to_category)
        )
    
    def _load_custom_categories(self, data_dir: Path) -> None:
        """Load custom category definitions from JSON."""
        custom_file = data_dir / "item_categories.json"
        
        if not custom_file.exists():
            self.log.debug("no_custom_categories", path=str(custom_file))
            return
        
        try:
            with open(custom_file, 'r') as f:
                data = json.load(f)
            
            for cat_data in data.get("categories", []):
                category = ItemCategory(
                    category_id=cat_data["category_id"],
                    name=cat_data["name"],
                    category_type=CategoryType(cat_data["category_type"]),
                    parent_category=cat_data.get("parent_category"),
                    item_id_ranges=[
                        tuple(r) for r in cat_data.get("item_id_ranges", [])
                    ],
                    item_ids=set(cat_data.get("item_ids", [])),
                    description=cat_data.get("description", ""),
                    tags=set(cat_data.get("tags", []))
                )
                self._add_category(category)
            
            self.log.info(
                "custom_categories_loaded",
                count=len(data.get("categories", []))
            )
        
        except Exception as e:
            self.log.error("custom_categories_load_failed", error=str(e))
    
    def save_categories(self, filepath: Path) -> None:
        """Save current categories to JSON file."""
        data = {
            "categories": [
                {
                    "category_id": cat.category_id,
                    "name": cat.name,
                    "category_type": cat.category_type.value,
                    "parent_category": cat.parent_category,
                    "item_id_ranges": list(cat.item_id_ranges),
                    "item_ids": list(cat.item_ids),
                    "description": cat.description,
                    "tags": list(cat.tags)
                }
                for cat in self.categories.values()
            ]
        }
        
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
        
        self.log.info("categories_saved", path=str(filepath))