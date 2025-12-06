"""
Job Test Data Module.

Contains quiz answer databases, monster databases, and spawn location data
for job advancement tests.
"""

from difflib import SequenceMatcher
from typing import Any


# =============================================================================
# QUIZ ANSWER DATABASES
# =============================================================================

MAGE_QUIZ_ANSWERS: dict[str, str] = {
    # Magic fundamentals
    "what is magic": "The power of nature",
    "magic definition": "The power of nature",
    "define magic": "The power of nature",
    "nature of magic": "The power of nature",
    
    # Element questions
    "fire element": "Fire Ball",
    "fire spell": "Fire Ball",
    "ice element": "Cold Bolt",
    "water element": "Cold Bolt",
    "ice spell": "Cold Bolt",
    "thunder element": "Lightning Bolt",
    "lightning element": "Lightning Bolt",
    "wind element": "Lightning Bolt",
    "earth element": "Earth Spike",
    "ground element": "Earth Spike",
    
    # Stats
    "what does int": "Increases magic damage",
    "intelligence stat": "Increases magic damage",
    "int stat effect": "Increases magic damage",
    "what is sp": "Spell Points for casting",
    "sp meaning": "Spell Points for casting",
    "spell points": "Spell Points for casting",
    
    # Equipment
    "mage weapon": "Staff or Rod",
    "weapon for mage": "Staff or Rod",
    "best weapon": "Staff or Rod",
    
    # Defense
    "magic defense": "Magic Defense (MDEF)",
    "mdef": "Magic Defense (MDEF)",
    
    # Casting
    "cast time": "DEX reduces cast time",
    "reduce cast time": "DEX reduces cast time",
    "faster casting": "DEX reduces cast time",
    "dex casting": "DEX reduces cast time",
}

SAGE_QUIZ_ANSWERS: dict[str, str] = {
    # History
    "history of magic": "Ancient times",
    "magic history": "Ancient times",
    "when did magic": "Ancient times",
    
    # Theory
    "magic theory": "Understanding elements",
    "theoretical magic": "Understanding elements",
    "theory of magic": "Understanding elements",
    
    # Advanced
    "advanced magic": "Multiple elements",
    "higher magic": "Multiple elements",
    "powerful magic": "Multiple elements",
    
    # Role
    "sage role": "Magic researcher",
    "what does sage": "Magic researcher",
    "sage job": "Magic researcher",
    
    # Elements
    "element weakness": "Fire beats Earth",
    "elemental weakness": "Fire beats Earth",
    "fire vs earth": "Fire beats Earth",
    
    # Special
    "magic circles": "Ancient spell formations",
    "spell circles": "Ancient spell formations",
    "rune magic": "Symbol-based casting",
    "rune system": "Symbol-based casting",
    "spell books": "Store magic knowledge",
    "magic books": "Store magic knowledge",
    
    # Locations
    "magic academy": "Juno Academy",
    "juno academy": "Juno Academy",
    "sage academy": "Juno Academy",
    
    # Research
    "magic research": "Understanding magic",
    "research magic": "Understanding magic",
}

PRIEST_QUIZ_ANSWERS: dict[str, str] = {
    # Holy
    "what is holy": "Divine power",
    "holy element": "Divine power",
    "divine magic": "Divine power",
    
    # Healing
    "healing": "Restoration magic",
    "heal magic": "Restoration magic",
    "healing spell": "Restoration magic",
    
    # Support
    "support role": "Assist party members",
    "priest role": "Assist party members",
    "priest job": "Assist party members",
    
    # Enemies
    "demon race": "Vulnerable to holy",
    "demon weakness": "Vulnerable to holy",
    "undead race": "Weak against holy",
    "undead weakness": "Weak against holy",
    
    # Skills
    "blessing": "Increases stats",
    "blessing effect": "Increases stats",
    "resurrection": "Revive dead allies",
    "resurrect": "Revive dead allies",
    "sanctuary": "Holy ground healing",
    "sanctuary effect": "Holy ground healing",
    
    # Faith
    "prayers": "Divine invocation",
    "prayer": "Divine invocation",
    "faith": "Belief in divinity",
    "faith meaning": "Belief in divinity",
}

WIZARD_QUIZ_ANSWERS: dict[str, str] = {
    # AOE
    "area magic": "Storm Gust, Meteor Storm",
    "aoe spells": "Storm Gust, Meteor Storm",
    "area of effect": "Storm Gust, Meteor Storm",
    
    # Elements
    "strongest fire": "Meteor Storm",
    "strongest ice": "Storm Gust",
    "strongest thunder": "Lord of Vermillion",
    "strongest earth": "Heaven's Drive",
    
    # Stats
    "wizard stats": "INT and DEX",
    "important stats": "INT and DEX",
    
    # Safety
    "safety wall": "Blocks physical attacks",
    "protect spell": "Blocks physical attacks",
    
    # Combos
    "freeze combo": "Storm Gust then Jupitel Thunder",
    "magic combo": "Freeze and shatter",
}

HUNTER_QUIZ_ANSWERS: dict[str, str] = {
    # Skills
    "trap skill": "Place traps to catch prey",
    "trapping": "Place traps to catch prey",
    "falcon skill": "Blitz Beat auto-attack",
    "falcon attack": "Blitz Beat auto-attack",
    
    # Stats
    "hunter stats": "DEX and AGI",
    "archer stats": "DEX and AGI",
    
    # Range
    "attack range": "Long range advantage",
    "ranged attack": "Long range advantage",
    
    # Equipment
    "hunter weapon": "Bow and arrows",
    "best bow": "Crossbow or composite",
}

ASSASSIN_QUIZ_ANSWERS: dict[str, str] = {
    # Skills
    "poison skill": "Enchant Poison",
    "poisoning": "Enchant Poison",
    "hide skill": "Become invisible",
    "stealth": "Become invisible",
    
    # Combat
    "critical attack": "High damage on weak point",
    "dual wield": "Two weapons at once",
    "katar": "Special assassin weapon",
    
    # Stats
    "assassin stats": "STR, AGI, and LUK",
    "critical stats": "LUK increases critical",
}

KNIGHT_QUIZ_ANSWERS: dict[str, str] = {
    # Skills
    "cavalry skill": "Mounted combat bonus",
    "peco riding": "Increased movement speed",
    "bowling bash": "Powerful AOE attack",
    "pierce": "Damage based on size",
    
    # Stats
    "knight stats": "STR and VIT",
    "tank stats": "VIT for HP",
    
    # Equipment
    "knight weapon": "Spear or Two-Hand Sword",
    "heavy armor": "Plate armor protection",
}

BLACKSMITH_QUIZ_ANSWERS: dict[str, str] = {
    # Crafting
    "forging": "Create weapons",
    "weapon making": "Create weapons",
    "refining": "Upgrade equipment",
    "upgrade equipment": "Upgrade equipment",
    
    # Skills
    "cart revolution": "AOE with pushcart",
    "mammonite": "Zeny cost attack",
    "pushcart": "Extra storage capacity",
    
    # Materials
    "oridecon": "Weapon refine material",
    "elunium": "Armor refine material",
    "iron": "Basic forging material",
}

CRUSADER_QUIZ_ANSWERS: dict[str, str] = {
    # Faith
    "holy crusade": "Fight for justice",
    "crusader duty": "Protect the weak",
    "faith power": "Holy strength",
    
    # Skills
    "grand cross": "Holy AOE damage",
    "shield boomerang": "Ranged shield attack",
    "devotion": "Take damage for ally",
    
    # Stats
    "crusader stats": "STR, VIT, INT",
    "hybrid stats": "Balance physical and magic",
}

MONK_QUIZ_ANSWERS: dict[str, str] = {
    # Combat
    "combo attack": "Chain multiple hits",
    "spirit spheres": "Power for skills",
    "asura strike": "Ultimate single hit",
    
    # Training
    "monk training": "Physical and spiritual",
    "meditation": "Recover SP quickly",
    
    # Stats
    "monk stats": "STR, AGI, DEX",
    "combo stats": "AGI for attack speed",
}

# Master quiz database combining all types
QUIZ_DATABASES: dict[str, dict[str, str]] = {
    "mage": MAGE_QUIZ_ANSWERS,
    "sage": SAGE_QUIZ_ANSWERS,
    "priest": PRIEST_QUIZ_ANSWERS,
    "wizard": WIZARD_QUIZ_ANSWERS,
    "hunter": HUNTER_QUIZ_ANSWERS,
    "assassin": ASSASSIN_QUIZ_ANSWERS,
    "knight": KNIGHT_QUIZ_ANSWERS,
    "blacksmith": BLACKSMITH_QUIZ_ANSWERS,
    "crusader": CRUSADER_QUIZ_ANSWERS,
    "monk": MONK_QUIZ_ANSWERS,
}


# =============================================================================
# MONSTER DATABASE
# =============================================================================

MONSTER_INFO: dict[int, dict[str, Any]] = {
    # Novice area monsters
    1002: {"name": "Poring", "race": "plant", "element": "water", "level": 1},
    1007: {"name": "Fabre", "race": "insect", "element": "earth", "level": 2},
    1008: {"name": "Chonchon", "race": "insect", "element": "wind", "level": 4},
    1010: {"name": "Willow", "race": "plant", "element": "earth", "level": 4},
    1011: {"name": "Thief Bug", "race": "insect", "element": "neutral", "level": 1},
    1014: {"name": "Lunatic", "race": "brute", "element": "neutral", "level": 3},
    1016: {"name": "Roda Frog", "race": "fish", "element": "water", "level": 6},
    
    # Undead monsters
    1015: {"name": "Zombie", "race": "undead", "element": "undead", "level": 13},
    1028: {"name": "Skeleton", "race": "undead", "element": "undead", "level": 16},
    1029: {"name": "Skeleton Soldier", "race": "undead", "element": "undead", "level": 29},
    1030: {"name": "Archer Skeleton", "race": "undead", "element": "undead", "level": 31},
    1036: {"name": "Ghoul", "race": "undead", "element": "undead", "level": 40},
    1041: {"name": "Mummy", "race": "undead", "element": "undead", "level": 43},
    1060: {"name": "Wraith", "race": "undead", "element": "undead", "level": 55},
    1076: {"name": "Skeleton Worker", "race": "undead", "element": "undead", "level": 35},
    
    # Common training monsters
    1033: {"name": "Familiar", "race": "brute", "element": "dark", "level": 8},
    1049: {"name": "Hornet", "race": "insect", "element": "wind", "level": 8},
    1052: {"name": "Rocker", "race": "insect", "element": "earth", "level": 9},
    1063: {"name": "Lunatic", "race": "brute", "element": "neutral", "level": 3},
    1084: {"name": "Wolf", "race": "brute", "element": "earth", "level": 25},
    1113: {"name": "Drops", "race": "plant", "element": "fire", "level": 3},
    
    # Demon monsters (for holy testing)
    1101: {"name": "Baphomet Jr.", "race": "demon", "element": "dark", "level": 50},
    1102: {"name": "Whisper", "race": "demon", "element": "ghost", "level": 34},
    1109: {"name": "Deviruchi", "race": "demon", "element": "dark", "level": 46},
}

# Monster name to ID mapping
MONSTER_NAME_TO_ID: dict[str, int] = {
    info["name"].lower(): mob_id
    for mob_id, info in MONSTER_INFO.items()
}

# Also add common aliases
MONSTER_NAME_TO_ID.update({
    "poring": 1002,
    "fabre": 1007,
    "chonchon": 1008,
    "willow": 1010,
    "thief bug": 1011,
    "lunatic": 1014,
    "roda frog": 1016,
    "zombie": 1015,
    "skeleton": 1028,
    "skeleton soldier": 1029,
    "archer skeleton": 1030,
    "ghoul": 1036,
    "mummy": 1041,
    "wraith": 1060,
    "wolf": 1084,
    "drops": 1113,
    "poporing": 1031,
})


# =============================================================================
# SPAWN MAP DATABASE
# =============================================================================

MONSTER_SPAWN_MAPS: dict[str, list[str]] = {
    # By monster name (lowercase)
    "poring": ["prt_fild01", "prt_fild02", "prt_fild08"],
    "fabre": ["prt_fild01", "prt_fild03", "prt_fild04"],
    "lunatic": ["prt_fild01", "prt_fild02", "prt_fild06"],
    "willow": ["prt_fild01", "prt_fild04", "prt_fild05"],
    "chonchon": ["prt_fild02", "prt_fild03", "mjolnir_01"],
    "roda frog": ["prt_fild02", "prt_fild04", "prt_fild05"],
    "thief bug": ["prt_sewb1", "prt_sewb2", "prt_sewb3"],
    "zombie": ["pay_fild08", "pay_fild07", "prt_maze01"],
    "skeleton": ["pay_fild08", "pay_fild07", "moc_pryd01"],
    "skeleton soldier": ["moc_pryd02", "moc_pryd03", "gef_dun01"],
    "archer skeleton": ["moc_pryd02", "moc_pryd03", "pay_dun03"],
    "ghoul": ["pay_dun02", "pay_dun03", "gef_dun02"],
    "mummy": ["moc_pryd02", "moc_pryd03", "moc_pryd04"],
    "wraith": ["gef_dun02", "gl_prison", "niflheim"],
    "wolf": ["pay_fild07", "pay_fild04", "mjolnir_02"],
    "drops": ["prt_fild01", "moc_fild01", "moc_fild02"],
    "poporing": ["pay_fild02", "pay_fild03", "pay_fild04"],
    "familiar": ["prt_fild02", "mjolnir_01", "mjolnir_02"],
    "hornet": ["mjolnir_01", "mjolnir_02", "mjolnir_03"],
}


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def get_quiz_answers(quiz_type: str) -> dict[str, str]:
    """
    Get quiz answer database for given quiz type.
    
    Args:
        quiz_type: Type of quiz (mage, sage, priest, etc.)
        
    Returns:
        Dictionary mapping question keywords to answers
    """
    return QUIZ_DATABASES.get(quiz_type.lower(), {})


def match_quiz_answer(
    question: str,
    quiz_type: str,
    threshold: float = 0.6
) -> str | None:
    """
    Match quiz question to answer using fuzzy matching.
    
    Args:
        question: Question text from NPC
        quiz_type: Type of quiz
        threshold: Minimum similarity score (0-1)
        
    Returns:
        Answer string or None if no match found
    """
    if not question:
        return None
    
    answers_db = get_quiz_answers(quiz_type)
    if not answers_db:
        return None
    
    question_lower = question.lower()
    
    # First try exact keyword matching
    for keyword, answer in answers_db.items():
        if keyword in question_lower:
            return answer
    
    # Fall back to fuzzy matching
    best_match = None
    best_score = 0.0
    
    for keyword, answer in answers_db.items():
        score = SequenceMatcher(None, question_lower, keyword).ratio()
        if score > best_score and score >= threshold:
            best_score = score
            best_match = answer
    
    return best_match


def get_monster_id(monster_name: str) -> int | None:
    """
    Get monster ID from name using fuzzy matching.
    
    Args:
        monster_name: Monster name to look up
        
    Returns:
        Monster ID or None if not found
    """
    name_lower = monster_name.lower().strip()
    
    # Direct match
    if name_lower in MONSTER_NAME_TO_ID:
        return MONSTER_NAME_TO_ID[name_lower]
    
    # Fuzzy match
    best_match = None
    best_score = 0.0
    
    for name, mob_id in MONSTER_NAME_TO_ID.items():
        score = SequenceMatcher(None, name_lower, name).ratio()
        if score > best_score and score >= 0.7:
            best_score = score
            best_match = mob_id
    
    return best_match


def get_monster_info(monster_id: int) -> dict[str, Any] | None:
    """Get monster info by ID."""
    return MONSTER_INFO.get(monster_id)


def get_spawn_maps(monster_name: str) -> list[str]:
    """
    Get spawn maps for a monster.
    
    Args:
        monster_name: Monster name
        
    Returns:
        List of map names where monster spawns
    """
    name_lower = monster_name.lower().strip()
    return MONSTER_SPAWN_MAPS.get(name_lower, [])


def is_undead_monster(monster_id: int) -> bool:
    """Check if monster is undead race/element."""
    info = MONSTER_INFO.get(monster_id)
    if not info:
        return False
    return info.get("race") == "undead" or info.get("element") == "undead"


def get_undead_monster_ids() -> list[int]:
    """Get all undead monster IDs."""
    return [
        mob_id for mob_id, info in MONSTER_INFO.items()
        if info.get("race") == "undead" or info.get("element") == "undead"
    ]


def get_demon_monster_ids() -> list[int]:
    """Get all demon monster IDs."""
    return [
        mob_id for mob_id, info in MONSTER_INFO.items()
        if info.get("race") == "demon"
    ]