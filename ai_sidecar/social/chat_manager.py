"""
Chat processing manager for social features.

Handles chat message processing, filtering, auto-responses,
and command recognition in Ragnarok Online.
"""

import uuid

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.chat_models import (
    AutoResponse,
    ChatChannel,
    ChatCommand,
    ChatFilter,
    ChatMessage,
)
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class ChatManager:
    """Manages chat processing and responses."""
    
    def __init__(self) -> None:
        self.filter = ChatFilter()
        self.auto_responses: list[AutoResponse] = []
        self.message_history: list[ChatMessage] = []
        self.max_history: int = 1000
        self.commands: dict[str, ChatCommand] = {}
        self.bot_name: str = ""
        
        # Register default commands
        self._register_default_commands()
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """Process incoming chat messages."""
        actions: list[Action] = []
        
        # Get new messages from game state (placeholder)
        new_messages = self._get_new_messages(game_state)
        
        for msg in new_messages:
            # Filter and store
            if not self.filter.should_block(msg):
                self.message_history.append(msg)
                
                # Trim history if needed
                if len(self.message_history) > self.max_history:
                    self.message_history = self.message_history[-self.max_history:]
                
                # Check for commands directed at us
                if self._is_command_for_me(msg):
                    response = self._handle_command(msg)
                    if response:
                        actions.append(response)
                
                # Check auto-responses
                auto_resp = self._check_auto_responses(msg)
                if auto_resp:
                    actions.append(auto_resp)
        
        return actions
    
    def _get_new_messages(self, game_state: GameState) -> list[ChatMessage]:
        """Extract new chat messages from game state."""
        # Placeholder - would parse from game_state.extra or similar
        return []
    
    def _is_command_for_me(self, msg: ChatMessage) -> bool:
        """Check if message contains a command for this bot."""
        if not self.bot_name:
            return False
        
        return msg.is_directed_at(self.bot_name)
    
    def _handle_command(self, msg: ChatMessage) -> Action | None:
        """Handle chat commands from party/guild leaders."""
        if not self.bot_name:
            return None
        
        # Extract command and args
        result = msg.extract_command(self.bot_name)
        if not result:
            return None
        
        command_name, args = result
        
        # Find matching command
        cmd = self.commands.get(command_name)
        if not cmd:
            # Check aliases
            for cmd_obj in self.commands.values():
                if cmd_obj.matches(command_name):
                    cmd = cmd_obj
                    break
        
        if not cmd:
            logger.debug(f"Unknown command: {command_name}")
            return None
        
        # Validate args
        if not cmd.validate_args(args):
            logger.warning(f"Invalid args for command {command_name}: {args}")
            return self.send_message(
                msg.channel,
                f"Usage: {cmd.usage}",
                target=msg.sender_name if msg.channel == ChatChannel.WHISPER else None
            )
        
        # Execute command
        return self._execute_command(cmd, args, msg)
    
    def _execute_command(
        self,
        cmd: ChatCommand,
        args: list[str],
        msg: ChatMessage
    ) -> Action | None:
        """Execute a recognized command."""
        command_name = cmd.name
        
        # Basic command implementations
        if command_name == "follow":
            # Return follow action (placeholder)
            logger.info(f"Following {msg.sender_name}")
            return None
        
        elif command_name == "attack":
            # Return attack action (placeholder)
            logger.info("Attacking on command")
            return None
        
        elif command_name == "retreat":
            # Return retreat action (placeholder)
            logger.info("Retreating on command")
            return None
        
        elif command_name == "heal":
            # Return heal action (placeholder)
            logger.info("Healing on command")
            return None
        
        elif command_name == "buff":
            # Return buff action (placeholder)
            logger.info("Buffing on command")
            return None
        
        return None
    
    def _check_auto_responses(self, msg: ChatMessage) -> Action | None:
        """Check if message triggers auto-responses."""
        for auto_resp in self.auto_responses:
            if auto_resp.matches(msg):
                response_text = auto_resp.generate_response(msg)
                auto_resp.mark_triggered()
                
                return self.send_message(
                    auto_resp.channel,
                    response_text,
                    target=msg.sender_name if auto_resp.channel == ChatChannel.WHISPER else None
                )
        
        return None
    
    def send_message(
        self,
        channel: ChatChannel,
        content: str,
        target: str | None = None
    ) -> Action:
        """Create action to send a chat message."""
        # Create chat message action
        # Implementation depends on protocol
        action = Action(
            type=ActionType.NOOP,  # Would be custom chat action
            priority=7,
            extra={
                "chat_channel": channel.value,
                "content": content,
                "target": target
            }
        )
        
        logger.debug(f"Sending message to {channel.value}: {content}")
        return action
    
    def register_auto_response(
        self,
        trigger: str,
        response: str,
        channel: ChatChannel,
        cooldown: int = 60
    ) -> None:
        """Register an automatic response rule."""
        auto_resp = AutoResponse(
            trigger_patterns=[trigger],
            response_template=response,
            channel=channel,
            cooldown_seconds=cooldown
        )
        self.auto_responses.append(auto_resp)
        logger.info(f"Registered auto-response for pattern: {trigger}")
    
    def register_command(self, command: ChatCommand) -> None:
        """Register a chat command."""
        self.commands[command.name] = command
        logger.info(f"Registered command: {command.name}")
    
    def _register_default_commands(self) -> None:
        """Register default chat commands."""
        commands = [
            ChatCommand(
                name="follow",
                aliases=["f"],
                description="Follow the command sender",
                usage="follow",
                min_args=0,
                max_args=0
            ),
            ChatCommand(
                name="attack",
                aliases=["atk", "a"],
                description="Attack nearest enemy",
                usage="attack [target]",
                min_args=0,
                max_args=1
            ),
            ChatCommand(
                name="retreat",
                aliases=["back", "run"],
                description="Retreat from combat",
                usage="retreat",
                min_args=0,
                max_args=0
            ),
            ChatCommand(
                name="heal",
                aliases=["h"],
                description="Heal the sender or target",
                usage="heal [target]",
                min_args=0,
                max_args=1
            ),
            ChatCommand(
                name="buff",
                aliases=["b"],
                description="Buff party members",
                usage="buff",
                min_args=0,
                max_args=0
            ),
        ]
        
        for cmd in commands:
            self.register_command(cmd)
    
    def set_bot_name(self, name: str) -> None:
        """Set the bot's character name for command recognition."""
        self.bot_name = name
        logger.info(f"Bot name set to: {name}")