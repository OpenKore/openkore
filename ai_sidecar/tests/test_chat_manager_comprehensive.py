"""
Comprehensive tests for chat_manager.py to achieve 90%+ coverage.

Tests all functions, branches, error paths, and edge cases.
"""

import pytest
import uuid
from datetime import datetime
from unittest.mock import Mock, patch

from ai_sidecar.social.chat_manager import ChatManager
from ai_sidecar.social.chat_models import (
    ChatMessage,
    ChatChannel,
    ChatFilter,
    AutoResponse,
    ChatCommand
)
from ai_sidecar.core.state import GameState
from ai_sidecar.core.decision import Action, ActionType


class TestChatManagerInit:
    """Test ChatManager initialization."""
    
    def test_init_creates_default_state(self):
        """Test manager initializes with correct defaults."""
        mgr = ChatManager()
        
        assert mgr.filter is not None
        assert isinstance(mgr.auto_responses, list)
        assert isinstance(mgr.message_history, list)
        assert mgr.max_history == 1000
        assert isinstance(mgr.commands, dict)
        assert mgr.bot_name == ""
        assert isinstance(mgr.authorized_commanders, set)
        assert isinstance(mgr.friend_list, set)
        
    def test_init_registers_default_commands(self):
        """Test default commands are registered."""
        mgr = ChatManager()
        
        # Check some default commands
        assert "follow" in mgr.commands
        assert "attack" in mgr.commands
        assert "heal" in mgr.commands
        assert "status" in mgr.commands
        
    def test_init_registers_auto_responses(self):
        """Test auto-responses are registered from config."""
        with patch('ai_sidecar.social.chat_manager.config') as mock_config:
            mock_config.CHAT_AUTO_RESPONSES = {
                "hello": {
                    "responses": ["Hi there!"],
                    "cooldown": 30,
                    "channels": ["party"]
                }
            }
            mgr = ChatManager()
            # Should have at least one auto-response
            assert len(mgr.auto_responses) > 0


class TestChatManagerTick:
    """Test main tick processing."""
    
    @pytest.fixture
    def manager(self):
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        return mgr
    
    @pytest.mark.asyncio
    async def test_tick_empty_state(self, manager):
        """Test tick with no new messages."""
        state = GameState()
        actions = await manager.tick(state)
        
        assert actions == []
        
    @pytest.mark.asyncio
    async def test_tick_processes_new_messages(self, manager):
        """Test tick processes new messages from game state."""
        state = GameState()
        state.extra = {
            "chat_messages": [
                {
                    "id": "msg_001",
                    "channel": "party",
                    "sender": "Player1",
                    "sender_id": 123,
                    "content": "Hello everyone",
                    "timestamp": datetime.now().timestamp()
                }
            ]
        }
        
        actions = await manager.tick(state)
        
        # Message should be in history
        assert len(manager.message_history) == 1
        assert manager.message_history[0].sender_name == "Player1"
        
    @pytest.mark.asyncio
    async def test_tick_filters_blocked_messages(self, manager):
        """Test tick filters out blocked messages."""
        manager.filter.blocked_players = ["Spammer"]
        
        state = GameState()
        state.extra = {
            "chat_messages": [
                {
                    "id": "msg_002",
                    "channel": "public",
                    "sender": "Spammer",
                    "content": "Buy gold!",
                    "timestamp": datetime.now().timestamp()
                }
            ]
        }
        
        actions = await manager.tick(state)
        
        # Blocked message should not be in history
        assert len(manager.message_history) == 0
        
    @pytest.mark.asyncio
    async def test_tick_handles_commands(self, manager):
        """Test tick processes commands directed at bot."""
        manager.add_authorized_commander("Leader")
        
        state = GameState()
        state.extra = {
            "chat_messages": [
                {
                    "id": "msg_003",
                    "channel": "party",
                    "sender": "Leader",
                    "content": "@TestBot follow",
                    "timestamp": datetime.now().timestamp()
                }
            ]
        }
        
        actions = await manager.tick(state)
        
        # Should generate follow action
        assert len(actions) > 0
        
    @pytest.mark.asyncio
    async def test_tick_trims_history(self, manager):
        """Test history is trimmed when exceeding max."""
        manager.max_history = 5
        
        # Add 10 messages
        for i in range(10):
            state = GameState()
            state.extra = {
                "chat_messages": [{
                    "id": f"msg_{i:03d}",
                    "channel": "public",
                    "sender": f"Player{i}",
                    "content": f"Message {i}",
                    "timestamp": datetime.now().timestamp()
                }]
            }
            await manager.tick(state)
        
        # Only last 5 should remain
        assert len(manager.message_history) == 5


class TestGetNewMessages:
    """Test _get_new_messages method."""
    
    @pytest.fixture
    def manager(self):
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        return mgr
    
    def test_get_new_messages_no_extra(self, manager):
        """Test with game state without extra field."""
        state = GameState()
        messages = manager._get_new_messages(state)
        
        assert messages == []
        
    def test_get_new_messages_no_chat_messages(self, manager):
        """Test with extra but no chat_messages."""
        state = GameState()
        state.extra = {}
        messages = manager._get_new_messages(state)
        
        assert messages == []
        
    def test_get_new_messages_skips_processed(self, manager):
        """Test skips already processed messages."""
        manager.last_processed_message_id = "msg_005"
        
        state = GameState()
        state.extra = {
            "chat_messages": [
                {"id": "msg_003", "channel": "party", "sender": "P1", "content": "Old"},
                {"id": "msg_006", "channel": "party", "sender": "P2", "content": "New"},
            ]
        }
        
        messages = manager._get_new_messages(state)
        
        # Only msg_006 should be returned (id > last_processed)
        assert len(messages) == 1
        assert messages[0].id == "msg_006"
        
    def test_get_new_messages_generates_uuid(self, manager):
        """Test generates UUID for messages without ID."""
        state = GameState()
        state.extra = {
            "chat_messages": [
                {"channel": "party", "sender": "Player", "content": "Hi"}
            ]
        }
        
        messages = manager._get_new_messages(state)
        
        assert len(messages) == 1
        assert messages[0].id != ""
        
    def test_get_new_messages_handles_parse_error(self, manager):
        """Test handles malformed message gracefully."""
        state = GameState()
        state.extra = {
            "chat_messages": [
                {"channel": "invalid_enum_value", "sender": "P1"},  # Missing content
                {"channel": "party", "sender": "P2", "content": "Good"}
            ]
        }
        
        messages = manager._get_new_messages(state)
        
        # Should still process valid message
        assert len(messages) >= 1
        
    def test_get_new_messages_marks_self_messages(self, manager):
        """Test correctly identifies messages from bot."""
        state = GameState()
        state.extra = {
            "chat_messages": [
                {"id": "1", "channel": "party", "sender": "TestBot", "content": "Self"},
                {"id": "2", "channel": "party", "sender": "Other", "content": "Other"}
            ]
        }
        
        messages = manager._get_new_messages(state)
        
        assert messages[0].is_self is True
        assert messages[1].is_self is False


class TestParseChannel:
    """Test _parse_channel method."""
    
    def test_parse_known_channels(self):
        """Test parsing known channel strings."""
        mgr = ChatManager()
        
        assert mgr._parse_channel("public") == ChatChannel.PUBLIC
        assert mgr._parse_channel("party") == ChatChannel.PARTY
        assert mgr._parse_channel("guild") == ChatChannel.GUILD
        assert mgr._parse_channel("whisper") == ChatChannel.WHISPER
        assert mgr._parse_channel("pm") == ChatChannel.WHISPER
        assert mgr._parse_channel("global") == ChatChannel.GLOBAL
        assert mgr._parse_channel("trade") == ChatChannel.TRADE
        
    def test_parse_case_insensitive(self):
        """Test channel parsing is case-insensitive."""
        mgr = ChatManager()
        
        assert mgr._parse_channel("PARTY") == ChatChannel.PARTY
        assert mgr._parse_channel("Party") == ChatChannel.PARTY
        
    def test_parse_unknown_defaults_to_public(self):
        """Test unknown channel defaults to PUBLIC."""
        mgr = ChatManager()
        
        assert mgr._parse_channel("unknown") == ChatChannel.PUBLIC


class TestCommandHandling:
    """Test command recognition and execution."""
    
    @pytest.fixture
    def manager(self):
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        mgr.add_authorized_commander("Commander")
        return mgr
    
    def test_is_command_for_me_no_bot_name(self):
        """Test returns False when bot name not set."""
        mgr = ChatManager()
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="@Bot attack"
        )
        
        assert mgr._is_command_for_me(msg) is False
        
    def test_handle_command_no_bot_name(self, manager):
        """Test returns None when bot name not set."""
        manager.bot_name = ""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="attack"
        )
        
        result = manager._handle_command(msg)
        assert result is None
        
    def test_handle_command_no_match(self, manager):
        """Test returns None when command not recognized."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Commander",
            content="@TestBot unknowncommand"
        )
        
        result = manager._handle_command(msg)
        assert result is None
        
    def test_handle_command_by_alias(self, manager):
        """Test command recognized by alias."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Commander",
            content="@TestBot f"  # alias for follow
        )
        
        result = manager._handle_command(msg)
        assert result is not None
        assert result.extra["command"] == "follow"
        
    def test_handle_command_invalid_args(self, manager):
        """Test returns usage message for invalid args."""
        # retreat command requires 0 args
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Commander",
            content="@TestBot retreat now immediately"  # Too many args
        )
        
        result = manager._handle_command(msg)
        # Should return usage message
        assert result is not None
        assert "Usage:" in result.extra["content"]


class TestCommandExecution:
    """Test individual command implementations."""
    
    @pytest.fixture
    def manager(self):
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        mgr.add_authorized_commander("Leader")
        return mgr
    
    def test_cmd_follow_default_sender(self, manager):
        """Test follow command defaults to sender."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot follow"
        )
        cmd = manager.commands["follow"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert action.extra["command"] == "follow"
        assert action.extra["target_name"] == "Leader"
        
    def test_cmd_follow_with_target(self, manager):
        """Test follow command with specific target."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot follow Tank"
        )
        cmd = manager.commands["follow"]
        
        action = manager._execute_command(cmd, ["Tank"], msg)
        
        assert action.extra["target_name"] == "Tank"
        
    def test_cmd_attack(self, manager):
        """Test attack command."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot attack"
        )
        cmd = manager.commands["attack"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert action.extra["command"] == "attack"
        assert action.extra["target"] == "nearest"
        
    def test_cmd_retreat(self, manager):
        """Test retreat command."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot retreat"
        )
        cmd = manager.commands["retreat"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert action.extra["command"] == "retreat"
        assert action.priority == 1
        
    def test_cmd_heal_default_sender(self, manager):
        """Test heal command defaults to sender."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot heal"
        )
        cmd = manager.commands["heal"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert action.type == ActionType.SKILL
        assert action.skill_id == 28
        assert action.extra["target_name"] == "Leader"
        
    def test_cmd_buff_with_args(self, manager):
        """Test buff command with target and type."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot buff Tank agi"
        )
        cmd = manager.commands["buff"]
        
        action = manager._execute_command(cmd, ["Tank", "agi"], msg)
        
        assert action.extra["target_name"] == "Tank"
        assert action.extra["buff_type"] == "agi"
        
    def test_cmd_stop(self, manager):
        """Test stop command."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@TestBot stop"
        )
        cmd = manager.commands["stop"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert action.extra["command"] == "stop"
        assert action.priority == 1  # Highest priority (min valid value)
        
    def test_cmd_status(self, manager):
        """Test status command."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.WHISPER,
            sender_name="Leader",
            content="@TestBot status"
        )
        cmd = manager.commands["status"]
        
        action = manager._execute_command(cmd, [], msg)
        
        assert "Status:" in action.extra["content"]
        assert action.extra["target"] == "Leader"


class TestAuthorization:
    """Test command authorization logic."""
    
    @pytest.fixture
    def manager(self):
        return ChatManager()
    
    def test_authorized_commander_allowed(self, manager):
        """Test explicit authorized commander is allowed."""
        manager.add_authorized_commander("Admin")
        
        assert manager._is_authorized_commander("Admin", ChatChannel.PARTY) is True
        
    def test_party_leader_in_party_chat(self, manager):
        """Test party leader can command via party chat."""
        manager.set_party_leader("Leader")
        
        assert manager._is_authorized_commander("Leader", ChatChannel.PARTY) is True
        assert manager._is_authorized_commander("Leader", ChatChannel.WHISPER) is False
        
    def test_guild_leader_in_guild_chat(self, manager):
        """Test guild leader can command via guild chat."""
        manager.set_guild_leader("GuildMaster")
        
        assert manager._is_authorized_commander("GuildMaster", ChatChannel.GUILD) is True
        assert manager._is_authorized_commander("GuildMaster", ChatChannel.PARTY) is False
        
    def test_friend_in_whisper(self, manager):
        """Test friend can command via whisper."""
        manager.set_friend_list(["Friend1", "Friend2"])
        
        assert manager._is_authorized_commander("Friend1", ChatChannel.WHISPER) is True
        assert manager._is_authorized_commander("Friend1", ChatChannel.PARTY) is False
        
    def test_unauthorized_stranger(self, manager):
        """Test stranger cannot command."""
        assert manager._is_authorized_commander("Stranger", ChatChannel.PARTY) is False


class TestAutoResponses:
    """Test auto-response system."""
    
    @pytest.fixture
    def manager(self):
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        return mgr
    
    def test_check_auto_responses_no_match(self, manager):
        """Test returns None when no auto-response matches."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="random text"
        )
        
        result = manager._check_auto_responses(msg)
        assert result is None
        
    def test_check_auto_responses_match(self, manager):
        """Test returns action when auto-response matches."""
        # Clear existing auto-responses to avoid conflicts
        manager.auto_responses = []
        
        manager.register_auto_response(
            trigger=r"\bhello\b",
            response="Hi {sender}!",
            channel=ChatChannel.PARTY,
            cooldown=30
        )
        
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="hello everyone"
        )
        
        result = manager._check_auto_responses(msg)
        
        assert result is not None
        assert "Player" in result.extra["content"]
        
    def test_check_auto_responses_marks_triggered(self, manager):
        """Test auto-response is marked as triggered."""
        # Clear existing auto-responses to avoid conflicts
        manager.auto_responses = []
        
        auto_resp = AutoResponse(
            trigger_patterns=[r"\bhello\b"],
            response_template="Hi!",
            channel=ChatChannel.PARTY,
            cooldown_seconds=60
        )
        manager.auto_responses.append(auto_resp)
        
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="hello"
        )
        
        assert auto_resp.last_triggered is None
        manager._check_auto_responses(msg)
        assert auto_resp.last_triggered is not None


class TestSendMessage:
    """Test message sending."""
    
    def test_send_message_party(self):
        """Test sending to party channel."""
        mgr = ChatManager()
        
        action = mgr.send_message(ChatChannel.PARTY, "Hello party!")
        
        assert action.extra["chat_channel"] == "party"
        assert action.extra["content"] == "Hello party!"
        assert action.extra["target"] is None
        
    def test_send_message_whisper_with_target(self):
        """Test sending whisper with target."""
        mgr = ChatManager()
        
        action = mgr.send_message(ChatChannel.WHISPER, "Secret", target="Friend")
        
        assert action.extra["chat_channel"] == "whisper"
        assert action.extra["target"] == "Friend"


class TestConfigMethods:
    """Test configuration setter methods."""
    
    def test_set_bot_name(self):
        """Test setting bot name."""
        mgr = ChatManager()
        mgr.set_bot_name("MyBot")
        
        assert mgr.bot_name == "MyBot"
        
    def test_set_party_leader(self):
        """Test setting party leader."""
        mgr = ChatManager()
        mgr.set_party_leader("Leader")
        
        assert mgr.party_leader == "Leader"
        
    def test_set_guild_leader(self):
        """Test setting guild leader."""
        mgr = ChatManager()
        mgr.set_guild_leader("GuildMaster")
        
        assert mgr.guild_leader == "GuildMaster"
        
    def test_add_authorized_commander(self):
        """Test adding authorized commander."""
        mgr = ChatManager()
        mgr.add_authorized_commander("Admin")
        
        assert "Admin" in mgr.authorized_commanders
        
    def test_remove_authorized_commander(self):
        """Test removing authorized commander."""
        mgr = ChatManager()
        mgr.add_authorized_commander("Admin")
        mgr.remove_authorized_commander("Admin")
        
        assert "Admin" not in mgr.authorized_commanders
        
    def test_set_friend_list(self):
        """Test setting friend list."""
        mgr = ChatManager()
        mgr.set_friend_list(["Friend1", "Friend2"])
        
        assert len(mgr.friend_list) == 2
        assert "Friend1" in mgr.friend_list


class TestQueryMethods:
    """Test query/retrieval methods."""
    
    def test_get_recent_messages_all(self):
        """Test getting recent messages without filter."""
        mgr = ChatManager()
        mgr.message_history = [
            ChatMessage(
                message_id=f"msg_{i}",
                channel=ChatChannel.PARTY,
                sender_name=f"Player{i}",
                content=f"Message {i}"
            )
            for i in range(20)
        ]
        
        recent = mgr.get_recent_messages(count=10)
        
        assert len(recent) == 10
        assert recent[-1].message_id == "msg_19"  # Last message
        
    def test_get_recent_messages_by_channel(self):
        """Test getting recent messages filtered by channel."""
        mgr = ChatManager()
        mgr.message_history = [
            ChatMessage(message_id="1", channel=ChatChannel.PARTY, sender_name="P1", content="A"),
            ChatMessage(message_id="2", channel=ChatChannel.GUILD, sender_name="P2", content="B"),
            ChatMessage(message_id="3", channel=ChatChannel.PARTY, sender_name="P3", content="C"),
        ]
        
        party_msgs = mgr.get_recent_messages(channel=ChatChannel.PARTY, count=10)
        
        assert len(party_msgs) == 2
        assert all(m.channel == ChatChannel.PARTY for m in party_msgs)
        
    def test_find_player_in_chat(self):
        """Test finding messages from specific player."""
        mgr = ChatManager()
        mgr.message_history = [
            ChatMessage(message_id="1", channel=ChatChannel.PARTY, sender_name="Alice", content="A"),
            ChatMessage(message_id="2", channel=ChatChannel.PARTY, sender_name="Bob", content="B"),
            ChatMessage(message_id="3", channel=ChatChannel.PARTY, sender_name="Alice", content="C"),
        ]
        
        alice_msgs = mgr.find_player_in_chat("Alice")
        
        assert len(alice_msgs) == 2
        assert all(m.sender_name == "Alice" for m in alice_msgs)


class TestCommandRegistration:
    """Test command registration."""
    
    def test_register_command(self):
        """Test registering custom command."""
        mgr = ChatManager()
        
        cmd = ChatCommand(
            name="custom",
            aliases=["c"],
            description="Custom command",
            usage="custom <arg>",
            min_args=1,
            max_args=1
        )
        
        mgr.register_command(cmd)
        
        assert "custom" in mgr.commands
        
    def test_register_auto_response(self):
        """Test registering auto-response."""
        mgr = ChatManager()
        initial_count = len(mgr.auto_responses)
        
        mgr.register_auto_response(
            trigger=r"\btest\b",
            response="Test response",
            channel=ChatChannel.PARTY,
            cooldown=60
        )
        
        assert len(mgr.auto_responses) == initial_count + 1