"""
Dialogue parsing and analysis for NPC interactions.

Uses regex patterns to extract meaningful information from NPC dialogue,
identify dialogue types, and suggest appropriate responses.
"""

import re
from typing import Literal

from pydantic import BaseModel, Field

from ai_sidecar.npc.models import DialogueState, NPCType, NPCDatabase
from ai_sidecar.npc.quest_models import Quest, QuestObjective, QuestObjectiveType, QuestReward
from ai_sidecar.social import config
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


# Item name to ID mapping (common RO items)
ITEM_NAME_TO_ID = {
    # Healing items
    "red potion": 501,
    "orange potion": 502,
    "yellow potion": 503,
    "white potion": 504,
    "blue potion": 505,
    "green potion": 506,
    "grape juice": 514,
    "royal jelly": 526,
    "honey": 518,
    "milk": 519,
    "apple": 512,
    "meat": 517,
    # Quest items
    "jellopy": 909,
    "fluff": 914,
    "clover": 706,
    "four leaf clover": 706,
    "sticky mucus": 938,
    "shell": 935,
    "trunk": 1019,
    "feather": 916,
    "iron ore": 1002,
    "coal": 1003,
    "steel": 999,
    "phracon": 1010,
    "emveretarcon": 1011,
    "oridecon": 984,
    "elunium": 985,
    "zargon": 912,
    "empty bottle": 713,
    "witched starsand": 1061,
    # Materials
    "worn out page": 7111,
    "empty test tube": 7134,
    "alcohol": 970,
    "detrimindexta": 971,
    "karvodailnirol": 972,
}

# Monster name to ID mapping (common RO monsters)
MONSTER_NAME_TO_ID = {
    # Low level
    "poring": 1002,
    "lunatic": 1063,
    "fabre": 1007,
    "pupa": 1008,
    "condor": 1009,
    "willow": 1010,
    "chonchon": 1011,
    "roda frog": 1012,
    "spore": 1014,
    "hornet": 1004,
    "drops": 1113,
    "poporing": 1031,
    "thief bug": 1051,
    "thief bug egg": 1048,
    "rocker": 1052,
    "creamy": 1018,
    # Mid level
    "poison spore": 1077,
    "wolf": 1013,
    "desert wolf": 1106,
    "savage": 1166,
    "elder willow": 1033,
    "metaller": 1058,
    "mantis": 1139,
    "orc warrior": 1023,
    "orc skeleton": 1152,
    "skeleton": 1076,
    "zombie": 1015,
    "mummy": 1041,
    "archer skeleton": 1016,
    "soldier skeleton": 1028,
    "pirate skeleton": 1199,
    # High level
    "raydric": 1163,
    "khalitzburg": 1132,
    "abysmal knight": 1219,
    "dark lord": 1272,
    "baphomet": 1039,
    "moonlight flower": 1150,
    "eddga": 1115,
    "osiris": 1038,
    "doppelganger": 1046,
}


class DialogueAnalysis(BaseModel):
    """Result of dialogue analysis with extracted information."""

    dialogue_type: Literal[
        "quest_offer",
        "quest_progress",
        "quest_complete",
        "shop",
        "service",
        "information",
        "unknown",
    ] = Field(description="Type of dialogue")

    # Quest information
    quest_info: Quest | None = Field(default=None, description="Extracted quest data")
    item_requirements: list[tuple[int, int]] = Field(
        default_factory=list, description="(item_id, quantity) requirements"
    )
    monster_requirements: list[tuple[int, int]] = Field(
        default_factory=list, description="(monster_id, count) requirements"
    )

    # NPCs and locations mentioned
    npc_mentions: list[str] = Field(
        default_factory=list, description="NPC names mentioned"
    )
    location_mentions: list[str] = Field(
        default_factory=list, description="Locations/maps mentioned"
    )

    # Response suggestion
    suggested_choice: int | None = Field(
        default=None, description="Suggested dialogue choice index"
    )
    confidence: float = Field(default=0.0, ge=0.0, le=1.0, description="Analysis confidence")


class DialogueParser:
    """
    Parses NPC dialogue and extracts meaningful information.

    Uses regex patterns to identify quest information, requirements,
    rewards, and other actionable data from dialogue text.
    """

    # Pattern categories
    QUEST_KEYWORDS = [
        r"\bquest\b",
        r"\btask\b",
        r"\bmission\b",
        r"\bhelp\s+me\b",
        r"\bneed.*help\b",
        r"\bbring\s+me\b",
        r"\bcollect\b",
        r"\bhunt\b",
        r"\bkill\b",
        r"\bdefeat\b",
        r"\bdeliver\b",
        r"\bfind\b",
        r"\bretrieve\b",
        r"\breport\s+to\b",
    ]

    # Item patterns
    ITEM_PATTERNS = [
        r"(\d+)\s*(?:x\s+)?([A-Z][a-zA-Z\s]+)",  # "5x Red Potion" or "5 Red Potion"
        r"([A-Z][a-zA-Z\s]+)\s*x\s*(\d+)",  # "Red Potion x5"
        r"\[([^\]]+)\]\s*(?:x\s*)?(\d+)?",  # "[Red Potion] x5"
        r"bring\s+me\s+(\d+)\s+([a-zA-Z\s]+)",  # "bring me 5 apples"
    ]

    # Monster/kill patterns
    KILL_PATTERNS = [
        r"kill\s+(\d+)\s+([A-Z][a-zA-Z\s]+)",  # "kill 10 Porings"
        r"defeat\s+(\d+)\s+([A-Z][a-zA-Z\s]+)",  # "defeat 5 Lunatics"
        r"hunt\s+(\d+)\s+([A-Z][a-zA-Z\s]+)",  # "hunt 20 Willows"
        r"(\d+)\s+([A-Z][a-zA-Z\s]+)\s+(?:killed|slain)",  # "10 Porings killed"
    ]

    # Reward patterns
    REWARD_PATTERNS = [
        r"reward.*?(\d+).*?zeny",  # "reward you 1000 zeny"
        r"(\d+)\s+zeny",  # "1000 zeny"
        r"(\d+)\s+(?:base\s+)?exp(?:erience)?",  # "500 base experience"
        r"(\d+)\s+job\s+exp(?:erience)?",  # "250 job exp"
        r"receive.*?\[([^\]]+)\]",  # "receive [Red Potion]"
    ]

    # Service keywords
    SERVICE_KEYWORDS = {
        "storage": [r"storage", r"deposit", r"withdraw", r"items"],
        "teleport": [r"warp", r"teleport", r"transport", r"travel"],
        "save": [r"save", r"respawn", r"resurrection"],
        "refine": [r"upgrade", r"refine", r"enhance", r"strengthen"],
        "identify": [r"identify", r"appraise"],
        "repair": [r"repair", r"fix"],
    }

    # Location patterns
    LOCATION_PATTERNS = [
        r"\b(prontera|geffen|payon|morocc|alberta|izlude|aldebaran|juno|comodo|umbala|niflheim|louyang|ayothaya|einbroch|lighthalzen|rachel|veins)\b",
    ]

    def __init__(self) -> None:
        """Initialize dialogue parser with compiled patterns."""
        self.npc_db = NPCDatabase()
        self._compile_patterns()
        
        # Build reverse lookup maps for faster searching
        self._item_lookup = {
            name.lower(): item_id
            for name, item_id in ITEM_NAME_TO_ID.items()
        }
        self._monster_lookup = {
            name.lower(): monster_id
            for name, monster_id in MONSTER_NAME_TO_ID.items()
        }

    def _compile_patterns(self) -> None:
        """Compile regex patterns for performance."""
        # Quest keywords
        self._quest_pattern = re.compile(
            "|".join(self.QUEST_KEYWORDS), re.IGNORECASE
        )

        # Item patterns
        self._item_patterns = [
            re.compile(pattern, re.IGNORECASE) for pattern in self.ITEM_PATTERNS
        ]

        # Monster patterns
        self._kill_patterns = [
            re.compile(pattern, re.IGNORECASE) for pattern in self.KILL_PATTERNS
        ]

        # Reward patterns
        self._reward_patterns = [
            re.compile(pattern, re.IGNORECASE) for pattern in self.REWARD_PATTERNS
        ]

        # Location patterns
        self._location_patterns = [
            re.compile(pattern, re.IGNORECASE) for pattern in self.LOCATION_PATTERNS
        ]

    def parse_dialogue(self, dialogue: DialogueState) -> DialogueAnalysis:
        """
        Analyze dialogue and extract actionable information.

        Args:
            dialogue: Current dialogue state

        Returns:
            DialogueAnalysis with extracted information
        """
        # Identify dialogue type
        dialogue_type = self._identify_dialogue_type(dialogue)
        
        # Extract requirements
        item_reqs = self.extract_item_requirements(dialogue.current_text)
        monster_reqs = self.extract_monster_requirements(dialogue.current_text)
        
        # Extract mentions
        npc_mentions = self._extract_npc_mentions(dialogue.current_text)
        location_mentions = self._extract_location_mentions(dialogue.current_text)
        
        # Suggest response
        suggested_choice = self.suggest_response(dialogue, dialogue_type)
        
        # Calculate confidence
        confidence = self._calculate_confidence(dialogue, dialogue_type)
        
        # Extract quest info if applicable
        quest_info = None
        if dialogue_type in ["quest_offer", "quest_progress", "quest_complete"]:
            quest_info = self.extract_quest_info(dialogue.history + [dialogue.current_text])
        
        return DialogueAnalysis(
            dialogue_type=dialogue_type,
            quest_info=quest_info,
            item_requirements=item_reqs,
            monster_requirements=monster_reqs,
            npc_mentions=npc_mentions,
            location_mentions=location_mentions,
            suggested_choice=suggested_choice,
            confidence=confidence
        )

    def _identify_dialogue_type(self, dialogue: DialogueState) -> str:
        """Identify the type of dialogue."""
        text = dialogue.current_text.lower()

        # Check for quest keywords
        if self._quest_pattern.search(text):
            # Quest offer indicators (NPC offering a quest)
            if any(
                phrase in text for phrase in [
                    "have a quest", "have a task", "have a mission",
                    "would you help", "can you help", "will you help",
                    "need your help", "need you to",
                    "looking for someone", "accept this quest",
                    "accept this task", "take this quest"
                ]
            ):
                return "quest_offer"
            elif any(word in text for word in ["complete", "done", "finished"]):
                return "quest_complete"
            else:
                return "quest_progress"

        # Check for shop keywords
        if any(word in text for word in ["buy", "sell", "shop", "store", "item"]):
            return "shop"

        # Check for service keywords
        for service_type, keywords in self.SERVICE_KEYWORDS.items():
            if any(re.search(kw, text, re.IGNORECASE) for kw in keywords):
                return "service"

        # Default to information
        return "information"

    def extract_quest_info(self, dialogue_history: list[str]) -> Quest | None:
        """
        Extract quest information from dialogue history.

        Args:
            dialogue_history: List of dialogue texts

        Returns:
            Quest object or None
        """
        # Combine all dialogue text
        full_text = " ".join(dialogue_history)

        # Extract requirements
        item_reqs = self.extract_item_requirements(full_text)
        monster_reqs = self.extract_monster_requirements(full_text)

        # If no requirements found, not a quest
        if not item_reqs and not monster_reqs:
            return None

        # Create objectives
        objectives: list[QuestObjective] = []

        # Add item collection objectives
        for item_id, quantity in item_reqs:
            objectives.append(
                QuestObjective(
                    objective_id=f"collect_{item_id}",
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_id=item_id,
                    target_name=f"Item {item_id}",
                    required_count=quantity,
                )
            )

        # Add monster kill objectives
        for monster_id, count in monster_reqs:
            objectives.append(
                QuestObjective(
                    objective_id=f"kill_{monster_id}",
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_id=monster_id,
                    target_name=f"Monster {monster_id}",
                    required_count=count,
                )
            )

        # Extract rewards
        rewards = self._extract_rewards(full_text)

        # Create quest stub (will be filled in by quest manager)
        return Quest(
            quest_id=0,  # Will be set by manager
            name="Unknown Quest",
            description=dialogue_history[0] if dialogue_history else "",
            npc_id=0,  # Will be set by manager
            npc_name="Unknown NPC",
            objectives=objectives,
            rewards=rewards,
        )

    def extract_item_requirements(self, text: str) -> list[tuple[int, int]]:
        """
        Extract (item_id, quantity) requirements from text.

        Args:
            text: Dialogue text

        Returns:
            List of (item_id, quantity) tuples
        """
        requirements = []
        text_lower = text.lower()

        for pattern in self._item_patterns:
            matches = pattern.findall(text_lower)
            for match in matches:
                try:
                    # Different patterns return different tuple formats
                    if len(match) == 2:
                        if match[0].isdigit():
                            quantity = int(match[0])
                            item_name = match[1].strip().lower()
                        else:
                            item_name = match[0].strip().lower()
                            quantity = int(match[1]) if match[1] else 1
                        
                        # Look up item ID from name
                        item_id = self._lookup_item_id(item_name)
                        if item_id > 0:
                            requirements.append((item_id, quantity))
                            logger.debug(f"Found item requirement: {item_name} x{quantity} (ID: {item_id})")
                except (ValueError, IndexError) as e:
                    logger.debug(f"Failed to parse item match: {match} - {e}")
                    continue

        return requirements
    
    def _lookup_item_id(self, item_name: str) -> int:
        """
        Look up item ID from item name.
        
        Args:
            item_name: Item name (case-insensitive)
            
        Returns:
            Item ID or 0 if not found
        """
        item_name = item_name.strip().lower()
        
        # Direct lookup
        if item_name in self._item_lookup:
            return self._item_lookup[item_name]
        
        # Fuzzy match - check if item name contains known item
        for known_name, item_id in self._item_lookup.items():
            if known_name in item_name or item_name in known_name:
                return item_id
        
        # Check plural forms
        if item_name.endswith('s'):
            singular = item_name[:-1]
            if singular in self._item_lookup:
                return self._item_lookup[singular]
        
        logger.debug(f"Unknown item: {item_name}")
        return 0

    def extract_monster_requirements(self, text: str) -> list[tuple[int, int]]:
        """
        Extract (monster_id, count) requirements from text.

        Args:
            text: Dialogue text

        Returns:
            List of (monster_id, count) tuples
        """
        requirements = []
        text_lower = text.lower()

        for pattern in self._kill_patterns:
            matches = pattern.findall(text_lower)
            for match in matches:
                try:
                    if len(match) == 2:
                        count = int(match[0])
                        monster_name = match[1].strip().lower()
                        
                        # Look up monster ID from name
                        monster_id = self._lookup_monster_id(monster_name)
                        if monster_id > 0:
                            requirements.append((monster_id, count))
                            logger.debug(f"Found monster requirement: {monster_name} x{count} (ID: {monster_id})")
                except (ValueError, IndexError) as e:
                    logger.debug(f"Failed to parse monster match: {match} - {e}")
                    continue

        return requirements
    
    def _lookup_monster_id(self, monster_name: str) -> int:
        """
        Look up monster ID from monster name.
        
        Args:
            monster_name: Monster name (case-insensitive)
            
        Returns:
            Monster ID or 0 if not found
        """
        monster_name = monster_name.strip().lower()
        
        # Direct lookup
        if monster_name in self._monster_lookup:
            return self._monster_lookup[monster_name]
        
        # Fuzzy match - check if monster name contains known monster
        for known_name, monster_id in self._monster_lookup.items():
            if known_name in monster_name or monster_name in known_name:
                return monster_id
        
        # Check plural forms (remove 's' from end)
        if monster_name.endswith('s'):
            singular = monster_name[:-1]
            if singular in self._monster_lookup:
                return self._monster_lookup[singular]
        
        logger.debug(f"Unknown monster: {monster_name}")
        return 0

    def _extract_rewards(self, text: str) -> list[QuestReward]:
        """Extract quest rewards from text."""
        rewards = []

        for pattern in self._reward_patterns:
            matches = pattern.findall(text)
            for match in matches:
                if "zeny" in text[pattern.search(text).start():pattern.search(text).end()].lower():
                    rewards.append(
                        QuestReward(reward_type="zeny", amount=int(match))
                    )
                elif "exp" in text[pattern.search(text).start():pattern.search(text).end()].lower():
                    if "job" in text:
                        rewards.append(
                            QuestReward(reward_type="exp_job", amount=int(match))
                        )
                    else:
                        rewards.append(
                            QuestReward(reward_type="exp_base", amount=int(match))
                        )

        return rewards

    def _extract_npc_mentions(self, text: str) -> list[str]:
        """Extract mentioned NPC names."""
        # Simple pattern for capitalized names
        pattern = r"\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)\b"
        matches = re.findall(pattern, text)
        return list(set(matches))

    def _extract_location_mentions(self, text: str) -> list[str]:
        """Extract mentioned locations."""
        locations = []
        for pattern in self._location_patterns:
            matches = pattern.findall(text)
            locations.extend(matches)
        return list(set(locations))

    def suggest_response(
        self, dialogue: DialogueState, dialogue_type: str
    ) -> int | None:
        """
        Suggest the best dialogue choice using config patterns.

        Args:
            dialogue: Current dialogue state
            dialogue_type: Identified dialogue type

        Returns:
            Suggested choice index or None
        """
        if not dialogue.choices:
            return None
        
        # Get response patterns from config
        response_patterns = config.NPC_RESPONSE_PATTERNS

        # Quest offer - check config for accept keywords
        if dialogue_type == "quest_offer":
            quest_config = response_patterns.get("quest_accept", {})
            accept_keywords = quest_config.get("keywords", ["quest", "mission", "task"])
            positive_words = response_patterns.get("yes_no", {}).get(
                "positive", ["Yes", "Accept", "Agree"]
            )
            
            for i, choice in enumerate(dialogue.choices):
                choice_lower = choice.text.lower()
                if any(word.lower() in choice_lower for word in positive_words):
                    return i

        # Quest complete - turn in
        if dialogue_type == "quest_complete":
            positive_words = response_patterns.get("yes_no", {}).get(
                "positive", ["Yes", "Accept", "Agree"]
            )
            
            for i, choice in enumerate(dialogue.choices):
                choice_lower = choice.text.lower()
                if any(
                    word in choice_lower
                    for word in ["complete", "done", "finish", "turn", "claim"]
                ):
                    return i
                if any(word.lower() in choice_lower for word in positive_words):
                    return i

        # Shop - handle buy/sell
        if dialogue_type == "shop":
            for i, choice in enumerate(dialogue.choices):
                choice_lower = choice.text.lower()
                # Prefer "buy" for restocking, can be configured
                if "buy" in choice_lower:
                    return i

        # Service - select the desired service
        if dialogue_type == "service":
            service_prefs = config.SERVICE_PREFERENCES
            preferred_services = ["storage", "save", "teleport"]
            
            for service in preferred_services:
                for i, choice in enumerate(dialogue.choices):
                    if service in choice.text.lower():
                        return i

        # Selection pattern - evaluate options
        selection_config = response_patterns.get("selection", {})
        if selection_config.get("response") == "evaluate_options":
            return self._evaluate_selection_options(dialogue.choices)

        # Default: first non-exit choice
        for i, choice in enumerate(dialogue.choices):
            if not choice.is_exit:
                return i

        return 0  # Fallback to first choice
    
    def _evaluate_selection_options(self, choices: list) -> int | None:
        """
        Evaluate selection options and pick the best one.
        
        Args:
            choices: List of dialogue choices
            
        Returns:
            Best choice index or None
        """
        if not choices:
            return None
        
        # Score each choice
        scores = []
        for i, choice in enumerate(choices):
            score = 0
            choice_lower = choice.text.lower()
            
            # Positive indicators
            if any(word in choice_lower for word in ["reward", "bonus", "extra"]):
                score += 10
            if any(word in choice_lower for word in ["yes", "accept", "agree"]):
                score += 5
            if any(word in choice_lower for word in ["continue", "next", "proceed"]):
                score += 3
            
            # Negative indicators
            if any(word in choice_lower for word in ["no", "cancel", "exit", "leave"]):
                score -= 5
            if choice.is_exit:
                score -= 10
            
            scores.append((i, score))
        
        # Return highest scoring choice
        scores.sort(key=lambda x: x[1], reverse=True)
        return scores[0][0] if scores else 0

    def _calculate_confidence(
        self, dialogue: DialogueState, dialogue_type: str
    ) -> float:
        """Calculate confidence in the analysis."""
        confidence = 0.5  # Base confidence

        # Higher confidence for clear dialogue types
        if dialogue_type in ["quest_offer", "shop", "service"]:
            confidence += 0.3

        # Increase confidence if we have choices
        if dialogue.choices:
            confidence += 0.1

        # Decrease confidence for unknown type
        if dialogue_type == "unknown":
            confidence -= 0.2

        return min(1.0, max(0.0, confidence))

    def identify_quest_offer(self, text: str) -> dict:
        """Identify if dialogue offers a quest."""
        keywords = ["quest", "help", "need", "request", "mission", "task"]
        text_lower = text.lower()
        found_keywords = [k for k in keywords if k in text_lower]
        has_keyword = len(found_keywords) > 0
        
        return {
            "is_quest_offer": has_keyword,
            "confidence": 0.8 if has_keyword else 0.2,
            "keywords_found": found_keywords
        }
    
    def identify_quest_progress(self, text: str) -> dict:
        """Identify if dialogue is about quest progress."""
        keywords = ["progress", "how is", "going", "collected", "killed"]
        text_lower = text.lower()
        found_keywords = [k for k in keywords if k in text_lower]
        has_keyword = len(found_keywords) > 0
        
        return {
            "is_quest_progress": has_keyword,
            "confidence": 0.7 if has_keyword else 0.3,
            "keywords_found": found_keywords
        }
    
    def identify_quest_complete(self, text: str) -> dict:
        """Identify if dialogue indicates quest completion."""
        keywords = ["complete", "done", "finished", "congratulations", "great"]
        text_lower = text.lower()
        found_keywords = [k for k in keywords if k in text_lower]
        has_keyword = len(found_keywords) > 0
        
        return {
            "is_quest_complete": has_keyword,
            "confidence": 0.8 if has_keyword else 0.2,
            "keywords_found": found_keywords
        }
    
    def identify_shop(self, text: str) -> dict:
        """Identify if dialogue is from a shop."""
        keywords = ["shop", "buy", "sell", "store", "item", "merchandise"]
        text_lower = text.lower()
        found_keywords = [k for k in keywords if k in text_lower]
        has_keyword = len(found_keywords) > 0
        
        return {
            "is_shop": has_keyword,
            "confidence": 0.8 if has_keyword else 0.2,
            "keywords_found": found_keywords
        }
    
    def identify_service(self, text: str) -> dict:
        """Identify if dialogue offers a service."""
        keywords = ["storage", "teleport", "warp", "save", "kafra", "refine"]
        text_lower = text.lower()
        found_keywords = [k for k in keywords if k in text_lower]
        has_keyword = len(found_keywords) > 0
        
        return {
            "is_service": has_keyword,
            "confidence": 0.8 if has_keyword else 0.2,
            "keywords_found": found_keywords
        }
    
    def identify_information(self, text: str) -> dict:
        """Identify if dialogue is informational."""
        # Information dialogue is default when no other type matches
        # Check if it's NOT one of the other types
        is_other = (
            self.identify_quest_offer(text)["is_quest_offer"] or
            self.identify_shop(text)["is_shop"] or
            self.identify_service(text)["is_service"]
        )
        
        return {
            "is_information": not is_other,
            "confidence": 0.5 if not is_other else 0.3,
            "keywords_found": []
        }
    
    def calculate_confidence(self, dialogue_type: str, indicators: list) -> float:
        """
        Calculate confidence score for dialogue type.
        
        Args:
            dialogue_type: The identified dialogue type
            indicators: List of indicators/keywords found
            
        Returns:
            Confidence score between 0.0 and 1.0
        """
        if not indicators:
            return 0.1
        
        # Base confidence from number of indicators
        base = min(0.9, len(indicators) * 0.2 + 0.3)
        
        # Boost for certain types
        if dialogue_type in ["quest_offer", "shop", "service"]:
            base += 0.1
        
        return min(1.0, base)
    
    def identify_npc_type(self, npc_name: str, dialogue: str) -> NPCType:
        """
        Identify NPC type from name and dialogue.

        Args:
            npc_name: NPC name
            dialogue: Dialogue text

        Returns:
            Identified NPCType
        """
        dialogue_lower = dialogue.lower()
        name_lower = npc_name.lower()

        # Check for service NPCs
        if "kafra" in name_lower:
            return NPCType.SERVICE

        # Check for shop keywords
        if any(word in dialogue_lower for word in ["buy", "sell", "shop"]):
            return NPCType.SHOP

        # Check for warp keywords
        if any(word in dialogue_lower for word in ["warp", "teleport", "portal"]):
            return NPCType.WARP

        # Check for quest keywords
        if self._quest_pattern.search(dialogue_lower):
            return NPCType.QUEST

        # Check for guild keywords
        if any(word in dialogue_lower for word in ["guild", "clan"]):
            return NPCType.GUILD

        # Default to generic
        return NPCType.GENERIC