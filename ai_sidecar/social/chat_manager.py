"""
Chat processing manager for social features.

Handles chat message processing, filtering, auto-responses,
and command recognition in Ragnarok Online.
"""

import re
import uuid
from datetime import datetime
from typing import Any

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.chat_models import (
    AutoResponse,
    ChatChannel,
    ChatCommand,
    ChatFilter,
    ChatMessage,
)
from ai_sidecar.social import config
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
        self.last_processed_message_id: str = ""
        self.authorized_commanders: set[str] = set()  # Players who can issue commands
        self.friend_list: set[str] = set()
        self.party_leader: str = ""
        self.guild_leader: str = ""
        
        # Register default commands
        self._register_default_commands()
        self._register_auto_responses()
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """Process incoming chat messages."""
        actions: list[Action] = []
        
        # Get new messages from game state (placeholder)
        new_messages = self._get_new_messages(game_state)
        
        for msg in new_messages:
            # Filter and store
            if not self.filter.should_block(msg):
                self._add_to_history(msg)
                
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
        messages: list[ChatMessage] = []
        
        # Extract from game_state.extra if available
        if not hasattr(game_state, 'extra') or not game_state.extra:
            return messages
        
        raw_messages = game_state.extra.get("chat_messages", [])
        
        for raw_msg in raw_messages:
            # Skip already processed messages
            msg_id = raw_msg.get("id", "")
            if msg_id and msg_id <= self.last_processed_message_id:
                continue
            
            try:
                # Parse channel
                channel_str = raw_msg.get("channel", "public")
                channel = self._parse_channel(channel_str)
                
                # Create ChatMessage
                msg = ChatMessage(
                    message_id=msg_id or str(uuid.uuid4()),
                    channel=channel,
                    sender_name=raw_msg.get("sender", "Unknown"),
                    sender_id=raw_msg.get("sender_id", 0),
                    content=raw_msg.get("content", ""),
                    timestamp=datetime.fromtimestamp(
                        raw_msg.get("timestamp", datetime.now().timestamp())
                    ),
                    is_self=False
                )
                msg.is_self = raw_msg.get("sender", "") == self.bot_name
                
                messages.append(msg)
                
                # Update last processed
                if msg_id:
                    self.last_processed_message_id = msg_id
                    
            except Exception as e:
                logger.error(f"Error parsing chat message: {e}")
                continue
        
        return messages
    
    def _parse_channel(self, channel_str: str) -> ChatChannel:
        """Parse channel string to ChatChannel enum."""
        channel_map = {
            "public": ChatChannel.PUBLIC,
            "party": ChatChannel.PARTY,
            "guild": ChatChannel.GUILD,
            "whisper": ChatChannel.WHISPER,
            "pm": ChatChannel.WHISPER,
            "global": ChatChannel.GLOBAL,
            "trade": ChatChannel.TRADE,
        }
        return channel_map.get(channel_str.lower(), ChatChannel.PUBLIC)
    
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
        
        # Check authorization
        if not self._is_authorized_commander(msg.sender_name, msg.channel):
            logger.warning(f"Unauthorized command from {msg.sender_name}: {command_name}")
            return self.send_message(
                ChatChannel.WHISPER,
                "You are not authorized to issue commands.",
                target=msg.sender_name
            )
        
        logger.info(f"Executing command '{command_name}' from {msg.sender_name}")
        
        # Command implementations
        if command_name == "follow":
            return self._cmd_follow(msg.sender_name, args)
        
        elif command_name == "attack":
            return self._cmd_attack(args)
        
        elif command_name == "retreat":
            return self._cmd_retreat()
        
        elif command_name == "heal":
            return self._cmd_heal(msg.sender_name, args)
        
        elif command_name == "buff":
            return self._cmd_buff(msg.sender_name, args)
        
        elif command_name == "stop":
            return self._cmd_stop()
        
        elif command_name == "status":
            return self._cmd_status(msg)
        
        return None
    
    def _is_authorized_commander(self, sender: str, channel: ChatChannel) -> bool:
        """Check if sender is authorized to issue commands."""
        # Explicit authorized commanders always allowed
        if sender in self.authorized_commanders:
            return True
        
        # Party leader can command via party chat
        if channel == ChatChannel.PARTY and sender == self.party_leader:
            return True
        
        # Guild leader can command via guild chat
        if channel == ChatChannel.GUILD and sender == self.guild_leader:
            return True
        
        # Friends can issue limited commands via whisper
        if channel == ChatChannel.WHISPER and sender in self.friend_list:
            return True
        
        return False
    
    def _cmd_follow(self, sender: str, args: list[str]) -> Action:
        """Execute follow command."""
        # Target defaults to command sender
        target = args[0] if args else sender
        
        return Action(
            type=ActionType.FOLLOW_PLAYER,
            priority=3,
            extra={
                "command": "follow",
                "target_name": target,
                "behavior": "follow"
            }
        )
    
    def _cmd_attack(self, args: list[str]) -> Action:
        """Execute attack command."""
        target_spec = args[0] if args else "nearest"
        
        return Action(
            type=ActionType.SET_ATTACK_MODE,
            priority=2,
            extra={
                "command": "attack",
                "target": target_spec,
                "mode": "aggressive"
            }
        )
    
    def _cmd_retreat(self) -> Action:
        """Execute retreat command."""
        return Action(
            type=ActionType.RETREAT,
            priority=1,  # High priority
            extra={
                "command": "retreat",
                "behavior": "flee_combat"
            }
        )
    
    def _cmd_heal(self, sender: str, args: list[str]) -> Action:
        """Execute heal command."""
        # Target defaults to command sender
        target = args[0] if args else sender
        
        return Action(
            type=ActionType.SKILL,
            skill_id=28,  # Heal skill ID
            priority=1,
            extra={
                "command": "heal",
                "target_name": target
            }
        )
    
    def _cmd_buff(self, sender: str, args: list[str]) -> Action:
        """Execute buff command."""
        # Target defaults to command sender
        target = args[0] if args else sender
        buff_type = args[1] if len(args) > 1 else "all"
        
        return Action(
            type=ActionType.BUFF_PLAYER,
            priority=3,
            extra={
                "command": "buff",
                "target_name": target,
                "buff_type": buff_type
            }
        )
    
    def _cmd_stop(self) -> Action:
        """Execute stop command - cancel all actions."""
        return Action(
            type=ActionType.CANCEL_ALL,
            priority=1,  # Highest priority (min valid value)
            extra={
                "command": "stop",
                "behavior": "idle"
            }
        )
    
    def _cmd_status(self, msg: ChatMessage) -> Action:
        """Execute status command - report current state."""
        return self.send_message(
            ChatChannel.WHISPER if msg.channel == ChatChannel.WHISPER else msg.channel,
            "Status: Active | HP: OK | SP: OK | Mode: Normal",
            target=msg.sender_name if msg.channel == ChatChannel.WHISPER else None
        )
    
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
        # Determine appropriate action type based on channel
        channel_to_action = {
            ChatChannel.PUBLIC: ActionType.SEND_CHAT,
            ChatChannel.WHISPER: ActionType.SEND_PM,
            ChatChannel.PARTY: ActionType.SEND_PARTY_CHAT,
            ChatChannel.GUILD: ActionType.SEND_GUILD_CHAT,
            ChatChannel.GLOBAL: ActionType.SEND_CHAT,
            ChatChannel.TRADE: ActionType.SEND_CHAT,
        }
        action_type = channel_to_action.get(channel, ActionType.SEND_CHAT)
        
        action = Action(
            type=action_type,
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
                description="Follow the command sender or target",
                usage="follow [target]",
                min_args=0,
                max_args=1
            ),
            ChatCommand(
                name="attack",
                aliases=["atk", "a"],
                description="Attack nearest enemy or specified target",
                usage="attack [target]",
                min_args=0,
                max_args=1
            ),
            ChatCommand(
                name="retreat",
                aliases=["back", "run", "flee"],
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
                description="Buff party members or target",
                usage="buff [target] [type]",
                min_args=0,
                max_args=2
            ),
            ChatCommand(
                name="stop",
                aliases=["s", "halt", "wait"],
                description="Stop all actions",
                usage="stop",
                min_args=0,
                max_args=0
            ),
            ChatCommand(
                name="status",
                aliases=["stat", "hp"],
                description="Report current status",
                usage="status",
                min_args=0,
                max_args=0
            ),
        ]
        
        for cmd in commands:
            self.register_command(cmd)
    
    def _register_auto_responses(self) -> None:
        """Register default auto-responses from config."""
        import random
        
        for trigger, response_config in config.CHAT_AUTO_RESPONSES.items():
            # Extract response list and pick one (or use first)
            responses = response_config.get("responses", [])
            if not responses:
                continue
            
            # Use first response (could randomize later)
            response_text = responses[0]
            
            # Extract cooldown
            cooldown = response_config.get("cooldown", 30)
            
            # Extract channels and create one AutoResponse per channel
            channels = response_config.get("channels", ["public"])
            for channel_name in channels:
                # Parse channel name to ChatChannel enum
                channel = self._parse_channel(channel_name)
                
                self.register_auto_response(
                    trigger=trigger,
                    response=response_text,
                    channel=channel,
                    cooldown=cooldown
                )
    
    def set_bot_name(self, name: str) -> None:
        """Set the bot's character name for command recognition."""
        self.bot_name = name
        logger.info(f"Bot name set to: {name}")
    
    def set_party_leader(self, leader_name: str) -> None:
        """Set party leader for command authorization."""
        self.party_leader = leader_name
        logger.debug(f"Party leader set to: {leader_name}")
    
    def set_guild_leader(self, leader_name: str) -> None:
        """Set guild leader for command authorization."""
        self.guild_leader = leader_name
        logger.debug(f"Guild leader set to: {leader_name}")
    
    def add_authorized_commander(self, name: str) -> None:
        """Add player to authorized commanders list."""
        self.authorized_commanders.add(name)
        logger.info(f"Added authorized commander: {name}")
    
    def remove_authorized_commander(self, name: str) -> None:
        """Remove player from authorized commanders list."""
        self.authorized_commanders.discard(name)
        logger.info(f"Removed authorized commander: {name}")
    
    def set_friend_list(self, friends: list[str]) -> None:
        """Set friend list for whisper command authorization."""
        self.friend_list = set(friends)
        logger.debug(f"Friend list updated: {len(friends)} friends")
    
    def get_recent_messages(
        self,
        channel: ChatChannel | None = None,
        count: int = 10
    ) -> list[ChatMessage]:
        """Get recent messages, optionally filtered by channel."""
        messages = self.message_history
        if channel:
            messages = [m for m in messages if m.channel == channel]
        return messages[-count:]
    
    def _add_to_history(self, msg: ChatMessage) -> None:
        """Add message to history with automatic trimming."""
        self.message_history.append(msg)
        if len(self.message_history) > self.max_history:
            self.message_history = self.message_history[-self.max_history:]
    
    def find_player_in_chat(self, player_name: str) -> list[ChatMessage]:
        """Find messages from a specific player."""
        return [m for m in self.message_history if m.sender_name == player_name]