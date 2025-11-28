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
        text = dialogue.current_text.lower()

        # Determine dialogue type
        dialogue_type = self._identify_dialogue_type(dialogue)

        # Extract quest information if applicable
        quest_info = None
        if dialogue_type in ["quest_offer", "quest_progress"]:
            quest_info = self.extract_quest_info(dialogue.history + [dialogue.current_text])

        # Extract requirements
        item_reqs = self.extract_item_requirements(text)
        monster_reqs = self.extract_monster_requirements(text)

        # Extract mentions
        npc_mentions = self._extract_npc_mentions(text)
        location_mentions = self._extract_location_mentions(text)

        # Suggest response
        suggested_choice = self.suggest_response(dialogue, dialogue_type)

        # Calculate confidence
        confidence = self._calculate_confidence(dialogue, dialogue_type)

        return DialogueAnalysis(
            dialogue_type=dialogue_type,
            quest_info=quest_info,
            item_requirements=item_reqs,
            monster_requirements=monster_reqs,
            npc_mentions=npc_mentions,
            location_mentions=location_mentions,
            suggested_choice=suggested_choice,
            confidence=confidence,
        )

    def _identify_dialogue_type(self, dialogue: DialogueState) -> str:
        """Identify the type of dialogue."""
        text = dialogue.current_text.lower()

        # Check for quest keywords
        if self._quest_pattern.search(text):
            if any(
                word in text for word in ["accept", "take", "start", "begin"]
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

        for pattern in self._item_patterns:
            matches = pattern.findall(text)
            for match in matches:
                try:
                    # Different patterns return different tuple formats
                    if len(match) == 2:
                        if match[0].isdigit():
                            quantity = int(match[0])
                            # Would need item name -> ID lookup
                            item_id = 0  # Placeholder
                        else:
                            quantity = int(match[1]) if match[1] else 1
                            item_id = 0  # Placeholder
                        requirements.append((item_id, quantity))
                except (ValueError, IndexError):
                    continue

        return requirements

    def extract_monster_requirements(self, text: str) -> list[tuple[int, int]]:
        """
        Extract (monster_id, count) requirements from text.

        Args:
            text: Dialogue text

        Returns:
            List of (monster_id, count) tuples
        """
        requirements = []

        for pattern in self._kill_patterns:
            matches = pattern.findall(text)
            for match in matches:
                try:
                    if len(match) == 2:
                        count = int(match[0])
                        # Would need monster name -> ID lookup
                        monster_id = 0  # Placeholder
                        requirements.append((monster_id, count))
                except (ValueError, IndexError):
                    continue

        return requirements

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
        Suggest the best dialogue choice.

        Args:
            dialogue: Current dialogue state
            dialogue_type: Identified dialogue type

        Returns:
            Suggested choice index or None
        """
        if not dialogue.choices:
            return None

        # Quest offer - accept the quest
        if dialogue_type == "quest_offer":
            for i, choice in enumerate(dialogue.choices):
                if any(
                    word in choice.text.lower()
                    for word in ["yes", "accept", "sure", "ok"]
                ):
                    return i

        # Quest complete - turn in
        if dialogue_type == "quest_complete":
            for i, choice in enumerate(dialogue.choices):
                if any(
                    word in choice.text.lower()
                    for word in ["complete", "done", "finish", "turn"]
                ):
                    return i

        # Service - select the service
        if dialogue_type == "service":
            for i, choice in enumerate(dialogue.choices):
                if any(
                    word in choice.text.lower()
                    for word in ["storage", "save", "teleport"]
                ):
                    return i

        # Default: first non-exit choice
        for i, choice in enumerate(dialogue.choices):
            if not choice.is_exit:
                return i

        return 0  # Fallback to first choice

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