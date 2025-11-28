"""
Chat-related data models for social features.

Defines Pydantic v2 models for chat processing, filtering, auto-responses,
and command recognition in Ragnarok Online.
"""

import re
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class ChatChannel(str, Enum):
    """Chat channels in Ragnarok Online."""
    
    GLOBAL = "global"
    PARTY = "party"
    GUILD = "guild"
    WHISPER = "whisper"
    SHOUT = "shout"
    LOCAL = "local"


class ChatMessage(BaseModel):
    """Individual chat message."""
    
    message_id: str = Field(description="Unique message ID")
    channel: ChatChannel = Field(description="Chat channel")
    sender_name: str = Field(description="Sender character name")
    sender_id: int | None = Field(default=None, description="Sender character ID")
    content: str = Field(description="Message content")
    timestamp: datetime = Field(
        default_factory=datetime.now,
        description="Message timestamp"
    )
    is_command: bool = Field(default=False, description="Is this a command")
    target_name: str | None = Field(
        default=None,
        description="Target name for whispers"
    )
    
    def is_directed_at(self, bot_name: str) -> bool:
        """Check if message is directed at the bot."""
        bot_name_lower = bot_name.lower()
        content_lower = self.content.lower()
        
        # Check for @mention
        if f"@{bot_name_lower}" in content_lower:
            return True
        
        # Check for name at start
        if content_lower.startswith(bot_name_lower):
            return True
        
        # Whispers are always directed at us
        if self.channel == ChatChannel.WHISPER:
            return True
        
        return False
    
    def extract_command(self, bot_name: str) -> tuple[str, list[str]] | None:
        """
        Extract command and arguments from message.
        
        Returns:
            Tuple of (command, args) or None if not a command
        
        Examples:
            "botname attack" -> ("attack", [])
            "@bot follow me" -> ("follow", ["me"])
            "!heal" -> ("heal", [])
        """
        content = self.content.strip()
        bot_name_lower = bot_name.lower()
        
        # Remove bot name prefix if present
        for prefix in [f"@{bot_name_lower}", bot_name_lower]:
            if content.lower().startswith(prefix):
                content = content[len(prefix):].strip()
                break
        
        # Check for command prefix (! or /)
        if content.startswith(("!", "/")):
            content = content[1:].strip()
        
        # Split into parts
        parts = content.split()
        if not parts:
            return None
        
        command = parts[0].lower()
        args = parts[1:] if len(parts) > 1 else []
        
        return (command, args)


class ChatFilter(BaseModel):
    """Chat filtering rules."""
    
    keywords_block: list[str] = Field(
        default_factory=list,
        description="Keywords that trigger message blocking"
    )
    keywords_highlight: list[str] = Field(
        default_factory=list,
        description="Keywords that trigger message highlighting"
    )
    blocked_players: list[str] = Field(
        default_factory=list,
        description="Player names to block messages from"
    )
    muted_channels: list[ChatChannel] = Field(
        default_factory=list,
        description="Channels to ignore"
    )
    
    def should_block(self, message: ChatMessage) -> bool:
        """Check if message should be blocked."""
        # Check if channel is muted
        if message.channel in self.muted_channels:
            return True
        
        # Check if sender is blocked
        if message.sender_name.lower() in [p.lower() for p in self.blocked_players]:
            return True
        
        # Check for blocked keywords
        content_lower = message.content.lower()
        for keyword in self.keywords_block:
            if keyword.lower() in content_lower:
                return True
        
        return False
    
    def should_highlight(self, message: ChatMessage) -> bool:
        """Check if message should be highlighted."""
        content_lower = message.content.lower()
        for keyword in self.keywords_highlight:
            if keyword.lower() in content_lower:
                return True
        return False


class AutoResponse(BaseModel):
    """Automatic chat response rule."""
    
    trigger_patterns: list[str] = Field(
        description="Regex patterns that trigger this response"
    )
    response_template: str = Field(
        description="Response template (can include {sender} placeholder)"
    )
    channel: ChatChannel = Field(
        description="Channel to respond in"
    )
    cooldown_seconds: int = Field(
        default=60,
        ge=0,
        description="Cooldown before responding again"
    )
    last_triggered: datetime | None = Field(
        default=None,
        description="Last time this response was triggered"
    )
    enabled: bool = Field(
        default=True,
        description="Is this auto-response enabled"
    )
    
    def matches(self, message: ChatMessage) -> bool:
        """Check if message matches trigger patterns."""
        if not self.enabled:
            return False
        
        # Check cooldown
        if self.last_triggered is not None:
            elapsed = (datetime.now() - self.last_triggered).total_seconds()
            if elapsed < self.cooldown_seconds:
                return False
        
        # Check patterns
        content = message.content
        for pattern in self.trigger_patterns:
            try:
                if re.search(pattern, content, re.IGNORECASE):
                    return True
            except re.error:
                # Invalid regex, skip
                continue
        
        return False
    
    def generate_response(self, message: ChatMessage) -> str:
        """Generate response text for the message."""
        response = self.response_template
        response = response.replace("{sender}", message.sender_name)
        return response
    
    def mark_triggered(self) -> None:
        """Mark this auto-response as triggered (update cooldown)."""
        self.last_triggered = datetime.now()


class ChatCommand(BaseModel):
    """Recognized chat command definition."""
    
    name: str = Field(description="Command name")
    aliases: list[str] = Field(
        default_factory=list,
        description="Alternative command names"
    )
    description: str = Field(description="Command description")
    usage: str = Field(description="Usage example")
    required_role: str | None = Field(
        default=None,
        description="Required role (leader, officer, etc.)"
    )
    min_args: int = Field(default=0, ge=0, description="Minimum arguments")
    max_args: int = Field(default=10, ge=0, description="Maximum arguments")
    
    def matches(self, command: str) -> bool:
        """Check if command name matches this definition."""
        command_lower = command.lower()
        if command_lower == self.name.lower():
            return True
        return command_lower in [a.lower() for a in self.aliases]
    
    def validate_args(self, args: list[str]) -> bool:
        """Validate argument count."""
        arg_count = len(args)
        return self.min_args <= arg_count <= self.max_args