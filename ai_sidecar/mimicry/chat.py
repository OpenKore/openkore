"""
Chat humanization for anti-detection.

Generates human-like chat behavior including response timing,
typing delays, occasional typos, abbreviations, and emoticons
to prevent detection through chat pattern analysis.
"""

import json
import random
import re
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class ChatStyle(str, Enum):
    """Chat personality styles."""
    TALKATIVE = "talkative"
    QUIET = "quiet"
    HELPFUL = "helpful"
    CASUAL = "casual"
    FORMAL = "formal"


class ChatContext(BaseModel):
    """Context for chat interactions."""
    
    model_config = ConfigDict(frozen=False)
    
    recent_messages: list[str] = Field(default_factory=list, description="Recent chat messages")
    nearby_players: list[str] = Field(default_factory=list, description="Players in range")
    current_activity: str = Field(default="idle", description="What player is doing")
    time_since_last_message_seconds: float = Field(default=0.0, ge=0.0, description="Time since last message")


class ChatResponse(BaseModel):
    """Generated chat response."""
    
    model_config = ConfigDict(frozen=False)
    
    message: str = Field(description="The message to send")
    typing_delay_ms: int = Field(ge=0, description="Delay before sending")
    should_include_typo: bool = Field(default=False, description="Whether typo was added")
    typo_position: Optional[int] = Field(default=None, description="Where typo occurred")


class HumanChatSimulator:
    """
    Generate human-like chat behavior.
    
    Features:
    - Response timing (not instant)
    - Occasional typos
    - Short responses (humans are lazy typers)
    - Appropriate silence (not responding to everything)
    - Personality consistency
    - Context awareness
    """
    
    def __init__(self, style: ChatStyle = ChatStyle.CASUAL, data_dir: Optional[Path] = None):
        self.log = structlog.get_logger()
        self.style = style
        self.message_history: list[tuple[datetime, str]] = []
        
        # Load abbreviations and typo patterns
        self.abbreviations = self._load_abbreviations(data_dir)
        self.typo_patterns = self._load_typo_patterns(data_dir)
        
        # Typing speed (words per minute)
        self.base_wpm = random.randint(40, 80)
        
        self.log.info("chat_simulator_initialized", style=style.value, wpm=self.base_wpm)
        
    def _load_abbreviations(self, data_dir: Optional[Path]) -> dict:
        """Load gaming abbreviations from config."""
        if data_dir:
            behaviors_file = data_dir / "human_behaviors.json"
            if behaviors_file.exists():
                try:
                    with open(behaviors_file, "r") as f:
                        data = json.load(f)
                        return data.get("gaming_abbreviations", {})
                except Exception as e:
                    self.log.error("failed_to_load_abbreviations", error=str(e))
        
        # Default abbreviations
        return {
            "please": "pls", "thanks": "thx", "okay": "ok", "because": "cuz",
            "you": "u", "are": "r", "before": "b4", "later": "l8r",
            "tonight": "2nite", "tomorrow": "tmrw", "awesome": "awesom",
            "nothing": "nothin", "something": "somethin"
        }
    
    def _load_typo_patterns(self, data_dir: Optional[Path]) -> dict:
        """Load typo patterns from config."""
        if data_dir:
            behaviors_file = data_dir / "human_behaviors.json"
            if behaviors_file.exists():
                try:
                    with open(behaviors_file, "r") as f:
                        data = json.load(f)
                        return data.get("typo_patterns", {})
                except Exception as e:
                    self.log.error("failed_to_load_typo_patterns", error=str(e))
        
        # Default typo patterns
        return {
            "adjacent_keys": {
                "a": ["s", "q", "w", "z"], "s": ["a", "d", "w", "x", "z"],
                "d": ["s", "f", "e", "r", "c", "x"], "e": ["w", "r", "d", "f"],
                "r": ["e", "t", "f", "g"], "t": ["r", "y", "g", "h"],
                "o": ["i", "p", "k", "l"], "p": ["o", "l"]
            },
            "common_typos": {
                "the": ["teh", "hte"], "and": ["adn", "nad"],
                "that": ["taht", "htat"], "what": ["waht", "hwat"]
            }
        }
    
    def should_respond(self, context: ChatContext, message: str) -> tuple[bool, float]:
        """
        Determine if we should respond.
        Returns (should_respond, probability)
        Not responding is human behavior too!
        """
        # Don't respond too frequently
        if context.time_since_last_message_seconds < 5:
            return False, 0.0
        
        # Check if message is directed at us (contains player name, direct question)
        is_directed = self._is_message_directed(message, context)
        
        # Response probability based on style and context
        if is_directed:
            prob = 0.8  # High chance if directed
        else:
            # Base probabilities by style
            style_probs = {
                ChatStyle.TALKATIVE: 0.4,
                ChatStyle.QUIET: 0.1,
                ChatStyle.HELPFUL: 0.3,
                ChatStyle.CASUAL: 0.25,
                ChatStyle.FORMAL: 0.2
            }
            prob = style_probs.get(self.style, 0.2)
        
        # Reduce probability if busy
        if context.current_activity in ["combat", "boss_fight", "trading"]:
            prob *= 0.3
        
        should_respond = random.random() < prob
        
        self.log.debug(
            "chat_response_decision",
            should_respond=should_respond,
            probability=prob,
            directed=is_directed
        )
        
        return should_respond, prob
    
    def _is_message_directed(self, message: str, context: ChatContext) -> bool:
        """Check if message is directed at us."""
        message_lower = message.lower()
        
        # Check for question marks
        if "?" in message:
            return True
        
        # Check for common greetings/questions
        directed_words = ["hi", "hello", "hey", "anyone", "help", "question"]
        return any(word in message_lower for word in directed_words)
    
    def generate_typing_pattern(self, message: str) -> list[int]:
        """
        Generate realistic typing delays per character.
        Considers:
        - Character difficulty (shift keys slower)
        - Word boundaries (pause between words)
        - Thinking pauses
        """
        delays = []
        chars_per_second = (self.base_wpm * 5) / 60.0
        base_delay_ms = int(1000 / chars_per_second)
        
        for i, char in enumerate(message):
            delay = base_delay_ms
            
            # Capital letters (shift key)
            if char.isupper():
                delay = int(delay * 1.3)
            
            # Punctuation (thinking pause)
            if char in ".,!?":
                delay += random.randint(100, 300)
            
            # Space (word boundary)
            if char == " ":
                delay += random.randint(50, 150)
            
            # Random variation
            delay = int(delay * random.uniform(0.8, 1.2))
            
            delays.append(delay)
        
        return delays
    
    def add_typo(self, message: str, typo_rate: float = 0.02) -> tuple[str, bool]:
        """
        Add realistic typos.
        Types: adjacent key, double letter, missing letter, transposed
        """
        if len(message) < 3 or random.random() > typo_rate:
            return message, False
        
        # Select random position (not first or last character)
        pos = random.randint(1, len(message) - 2)
        char = message[pos].lower()
        
        # Choose typo type
        typo_type = random.choice(["adjacent", "double", "missing", "transpose"])
        
        chars = list(message)
        
        if typo_type == "adjacent" and char in self.typo_patterns["adjacent_keys"]:
            # Adjacent key typo
            adjacent = self.typo_patterns["adjacent_keys"][char]
            chars[pos] = random.choice(adjacent)
        
        elif typo_type == "double":
            # Double letter
            chars.insert(pos, chars[pos])
        
        elif typo_type == "missing":
            # Missing letter
            chars.pop(pos)
        
        elif typo_type == "transpose" and pos < len(message) - 1:
            # Transpose two letters (only if they're different)
            if chars[pos] != chars[pos + 1]:
                chars[pos], chars[pos + 1] = chars[pos + 1], chars[pos]
            else:
                # If same character, use double instead
                chars.insert(pos, chars[pos])
        
        typo_message = "".join(chars)
        
        self.log.debug("typo_added", original=message, typo=typo_message, type=typo_type)
        
        return typo_message, True
    
    def abbreviate_message(self, message: str) -> str:
        """
        Apply gaming abbreviations.
        "please" -> "pls", "thanks" -> "thx", etc.
        """
        words = message.split()
        abbreviated = []
        
        for word in words:
            # Check if word (lowercase) has abbreviation
            word_lower = word.lower().strip(".,!?")
            if word_lower in self.abbreviations:
                # Apply abbreviation, preserve capitalization
                abbrev = self.abbreviations[word_lower]
                if word[0].isupper():
                    abbrev = abbrev.capitalize()
                
                # Preserve punctuation
                punct = "".join(c for c in word if c in ".,!?")
                abbreviated.append(abbrev + punct)
            else:
                abbreviated.append(word)
        
        return " ".join(abbreviated)
    
    def add_emotion_indicators(self, message: str, emotion: str) -> str:
        """
        Add emoticons/reactions.
        "ok" -> "ok :)", "thanks" -> "thx <3"
        """
        emoticons = {
            "happy": [":)", "^^", ":D", "=)"],
            "sad": [":(", "T_T", ";_;"],
            "laugh": ["lol", "haha", "xD", "rofl"],
            "love": ["<3", "♥"],
            "confused": ["???", "?", "o.O"],
            "surprised": ["!", "!!", "o_o", "O_O"],
            "angry": [">:(", "DX"],
            "neutral": [".", "..."]
        }
        
        if emotion in emoticons and random.random() < 0.4:  # 40% chance
            emoticon = random.choice(emoticons[emotion])
            
            # Don't add emoticon if message already has one
            if not any(e in message for e in [":", ";", "^", "D", "T", "x", "o", "O", "<3", "♥"]):
                message = f"{message} {emoticon}"
        
        return message
    
    async def get_response_timing(self, message_length: int, requires_thinking: bool) -> int:
        """
        Get realistic response delay.
        Longer for complex questions.
        """
        # Base thinking time
        thinking_time_s = random.uniform(1.0, 3.0)
        
        if requires_thinking:
            thinking_time_s += random.uniform(2.0, 5.0)
        
        # Typing time
        chars_per_second = (self.base_wpm * 5) / 60.0
        typing_time_s = message_length / chars_per_second
        
        # Add pauses for punctuation/words
        words = message_length / 5  # Assume avg 5 chars per word
        pause_time_s = words * random.uniform(0.1, 0.3)
        
        total_ms = int((thinking_time_s + typing_time_s + pause_time_s) * 1000)
        
        return total_ms
    
    def generate_short_response(self, context: str) -> str:
        """
        Generate short, human responses.
        Humans are lazy typers in games.
        """
        short_responses = {
            "greeting": ["hi", "hey", "yo", "hello"],
            "thanks": ["thx", "thanks", "ty", "tysm"],
            "agreement": ["ok", "sure", "ye", "yeah", "yup", "k"],
            "disagreement": ["no", "nope", "nah"],
            "help": ["need help?", "what's up?", "sup"],
            "busy": ["busy atm", "in combat", "sec"],
            "farewell": ["bye", "cya", "later", "gtg"]
        }
        
        responses = short_responses.get(context, ["ok"])
        return random.choice(responses)
    
    def humanize_response(
        self,
        message: str,
        emotion: str = "neutral",
        typo_chance: float = 0.02
    ) -> ChatResponse:
        """
        Apply all humanization to a chat message.
        
        Args:
            message: Original message
            emotion: Emotion to express
            typo_chance: Probability of typo
            
        Returns:
            Humanized ChatResponse
        """
        # Apply abbreviations
        message = self.abbreviate_message(message)
        
        # Sometimes make message all lowercase (casual)
        if self.style == ChatStyle.CASUAL and random.random() < 0.6:
            message = message.lower()
        
        # Add typos
        message, has_typo = self.add_typo(message, typo_chance)
        
        # Add emotion indicators
        message = self.add_emotion_indicators(message, emotion)
        
        # Calculate typing delay
        typing_delay = sum(self.generate_typing_pattern(message))
        
        # Add thinking time
        thinking_delay = random.randint(1000, 3000)
        total_delay = typing_delay + thinking_delay
        
        response = ChatResponse(
            message=message,
            typing_delay_ms=total_delay,
            should_include_typo=has_typo
        )
        
        # Record in history
        self.message_history.append((datetime.now(), message))
        if len(self.message_history) > 50:
            self.message_history.pop(0)
        
        self.log.debug(
            "chat_response_generated",
            message=message,
            delay_ms=total_delay,
            has_typo=has_typo
        )
        
        return response
    
    def should_use_emote_instead(self, context: str) -> Optional[str]:
        """
        Sometimes use emote instead of text response.
        
        Args:
            context: Context of interaction
            
        Returns:
            Emote command or None
        """
        if random.random() < 0.15:  # 15% chance
            emote_map = {
                "greeting": ["/hi", "/wave"],
                "thanks": ["/thx", "/lv"],
                "agreement": ["/ok", "/no1"],
                "laugh": ["/heh", "/gg"],
                "farewell": ["/bye"]
            }
            
            emotes = emote_map.get(context, [])
            if emotes:
                return random.choice(emotes)
        
        return None
    
    def get_chat_stats(self) -> dict:
        """Get chat statistics."""
        if not self.message_history:
            return {"total_messages": 0}
        
        recent_count = len([m for t, m in self.message_history if (datetime.now() - t).total_seconds() < 3600])
        avg_length = sum(len(m) for _, m in self.message_history) / len(self.message_history)
        
        return {
            "total_messages": len(self.message_history),
            "recent_hour_count": recent_count,
            "avg_message_length": round(avg_length, 1),
            "style": self.style.value,
            "base_wpm": self.base_wpm
        }


# Alias for backward compatibility
ChatHumanizer = HumanChatSimulator