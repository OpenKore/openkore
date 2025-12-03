"""
Configuration for social and NPC interaction decision-making.

Defines criteria for party invitations, guild activities,
chat responses, and NPC interactions.
"""

from typing import Literal


# ==========================================
# PARTY CONFIGURATION
# ==========================================

PARTY_ACCEPT_CRITERIA = {
    "guild_member": {
        "auto_accept": True,
        "reason": "Same guild member",
        "priority": 1
    },
    "friend": {
        "auto_accept": True,
        "reason": "Friend",
        "priority": 2
    },
    "friend_list": {
        "auto_accept": True,
        "reason": "On friend list",
        "priority": 2
    },
    "party_history": {
        "auto_accept": True,
        "reason": "Previously partied together",
        "priority": 3
    },
    "known_player": {
        "auto_accept": False,
        "ask": True,
        "reason": "Known player - needs confirmation",
        "priority": 4
    },
    "stranger": {
        "auto_accept": False,
        "reason": "Unknown player",
        "priority": 5
    },
    "blacklist": {
        "auto_accept": False,
        "reason": "Player is blacklisted",
        "priority": 0
    }
}

# Party coordination settings
PARTY_FOLLOW_DISTANCE = 5  # Stay within this range of leader
PARTY_HEAL_THRESHOLD = 70  # Heal party members below this HP%
PARTY_EMERGENCY_THRESHOLD = 30  # Emergency healing priority below this HP%


# ==========================================
# GUILD CONFIGURATION
# ==========================================

# WoE/GvG Settings
WOE_PARTICIPATION_ENABLED = True
WOE_ROLE_PREFERENCES = {
    "offense": ["assassin", "wizard", "hunter"],
    "defense": ["knight", "crusader", "priest"],
    "support": ["priest", "sage", "bard", "dancer"]
}

WOE_SETTINGS = {
    "guild_buff_interval": 300,  # seconds between guild buffs
    "castle_positions": {
        "Kriemhild": (150, 150),
        "Swanhild": (120, 120),
        "Fadhgridh": (180, 180)
    },
    "engage_distance": 10,  # cells
    "defense_radius": 15,  # cells for defense perimeter
    "heal_threshold": 70,  # HP% to heal allies
    "min_exp_donation": 1  # minimum % EXP donation
}

# Guild storage settings
GUILD_STORAGE_AUTO_DEPOSIT = True
GUILD_STORAGE_WEIGHT_THRESHOLD = 70  # Deposit when weight > this %
GUILD_STORAGE_ITEM_WHITELIST = [
    # Item IDs that should be deposited
    # Example: consumables, materials
]

# Guild EXP donation settings
GUILD_EXP_DONATION_ENABLED = False
GUILD_EXP_DONATION_PERCENT = 10  # % of gained EXP to donate


# ==========================================
# CHAT CONFIGURATION
# ==========================================

# Chat response settings
CHAT_AUTO_RESPONSE_ENABLED = True
CHAT_COMMAND_PREFIX = "!"
CHAT_ALLOWED_COMMANDERS = [
    "party_leader",
    "guild_master",
    "friend_list"
]

# Chat auto-responses (trigger -> response templates)
CHAT_AUTO_RESPONSES = {
    "hello": {
        "responses": ["Hi!", "Hello!", "Hey there!"],
        "cooldown": 60,
        "channels": ["whisper", "party"]
    },
    "thanks": {
        "responses": ["You're welcome!", "No problem!", "Anytime!"],
        "cooldown": 60,
        "channels": ["whisper", "party", "guild"]
    },
    "loot": {
        "responses": ["Checking drops...", "Got some good loot!"],
        "cooldown": 120,
        "channels": ["party"]
    }
}

# Command aliases
CHAT_COMMAND_ALIASES = {
    "f": "follow",
    "atk": "attack",
    "a": "attack",
    "h": "heal",
    "b": "buff",
    "back": "retreat",
    "run": "retreat"
}


# ==========================================
# NPC INTERACTION CONFIGURATION
# ==========================================

# NPC Response patterns
NPC_RESPONSE_PATTERNS = {
    "yes_no": {
        "positive": ["yes", "accept", "agree", "ok", "sure"],
        "negative": ["no", "decline", "cancel", "refuse"]
    },
    "quantity": {
        "pattern": r"(?i)how\s+many|quantity|amount",
        "default": 1
    },
    "selection": {
        "pattern": r"\[.*?\]",
        "preference": "first_non_exit"
    },
    "quest_accept": {
        "keywords": ["quest", "mission", "task", "help"],
        "auto_accept": True
    }
}

# Quest priority weights
QUEST_PRIORITIES = {
    "main_story": 100,
    "daily": 80,
    "repeatable": 60,
    "side_quest": 40,
    "collection": 20,
    "ready_to_turn_in": 150  # Highest priority
}

# Service NPC preferences
SERVICE_PREFERENCES = {
    "storage": {
        "auto_use_on_weight": 80,  # % weight
        "auto_use_on_items": 90  # % inventory slots
    },
    "save_point": {
        "auto_save_on_map_change": True,
        "auto_save_interval": 3600  # seconds
    },
    "refine": {
        "max_zeny_per_attempt": 50000,
        "stop_at_refine_level": 7,
        "only_safe_refine": True
    },
    "repair": {
        "auto_repair_threshold": 20  # % durability
    }
}

# NPC interaction timeouts
NPC_DIALOGUE_TIMEOUT = 30  # seconds before auto-closing dialogue
NPC_TRAVEL_TIMEOUT = 120  # seconds before abandoning NPC travel


# ==========================================
# RELATIONSHIP TRACKING
# ==========================================

class RelationshipType:
    """Player relationship types."""
    BLACKLIST = "blacklist"
    STRANGER = "stranger"
    KNOWN_PLAYER = "known_player"
    FRIEND = "friend_list"
    GUILD_MEMBER = "guild_member"
    PARTY_HISTORY = "party_history"


# Relationship progression thresholds
RELATIONSHIP_THRESHOLDS = {
    "party_count_for_known": 3,  # Parties together to become "known"
    "interaction_count_for_friend": 10,  # Interactions to suggest friend
    "negative_count_for_blacklist": 5  # Negative interactions to blacklist
}


# ==========================================
# BLACKLIST CONFIGURATION
# ==========================================

# Automatic blacklist reasons
AUTO_BLACKLIST_REASONS = [
    "kill_stealing",
    "loot_stealing",
    "harassment",
    "excessive_pvp",
    "scamming"
]

# Blacklist expiry (in days, None = permanent)
BLACKLIST_EXPIRY_DAYS = {
    "kill_stealing": 7,
    "loot_stealing": 7,
    "harassment": 30,
    "excessive_pvp": 14,
    "scamming": None  # Permanent
}


# ==========================================
# MIMICRY & ANTI-DETECTION
# ==========================================

# Response delays (to appear human)
CHAT_RESPONSE_DELAY = {
    "min": 0.5,  # seconds
    "max": 2.0
}

NPC_INTERACTION_DELAY = {
    "min": 0.3,
    "max": 1.5
}

# Variation in behavior
BEHAVIOR_RANDOMIZATION = {
    "party_accept_delay": (1, 5),  # seconds
    "chat_typo_chance": 0.02,  # 2% chance of typo
    "response_variety": True  # Use different responses
}