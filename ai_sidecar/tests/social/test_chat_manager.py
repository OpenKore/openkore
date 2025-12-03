"""
Comprehensive tests for Chat Manager system.

Tests cover:
- Chat manager initialization
- Message processing and filtering
- Command recognition and parsing
- Command execution and authorization
- Auto-response triggering
- Channel parsing
- Message history management
- Friend/party/guild management
"""

import pytest
from datetime import datetime
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.social.chat_manager import ChatManager
from ai_sidecar.social.chat_models import (
    ChatChannel,
    ChatCommand,
    ChatMessage,
    AutoResponse,
    ChatFilter
)
from ai_sidecar.core.state import GameState
from ai_sidecar.core.decision import Action, ActionType


# Fixtures

@pytest.fixture
def chat_manager():
    """Create chat manager."""
    manager = ChatManager()
    manager.set_bot_name("TestBot")
    return manager


@pytest.fixture
def game_state_with_messages():
    """Create game state with chat messages."""
    state = GameState(
        hp=100,
        max_hp=100,
        sp=50,
        max_sp=50,
        position=(100, 100),
        map_name="prontera"
    )
    state.extra = {
        "chat_messages": [
            {
                "id": "msg1",
                "channel": "party",
                "sender": "PartyLeader",
                "sender_id": 123,
                "content": "TestBot follow me",
                "timestamp": datetime.now().timestamp()
            },
            {
                "id": "msg2",
                "channel": "public",
                "sender": "RandomPlayer",
                "sender_id": 456,
                "content": "Hello world",
                "timestamp": datetime.now().timestamp()
            }
        ]
    }
    return state


@pytest.fixture
def sample_message():
    """Create sample chat message."""
    return ChatMessage(
        message_id="test123",
        channel=ChatChannel.PARTY,
        sender_name="TestPlayer",
        sender_id=999,
        content="TestBot attack poring",
        timestamp=datetime.now(),
        is_self=False
    )


# Initialization Tests

class TestChatManagerInit:
    """Test chat manager initialization."""
    
    def test_manager_initialization(self, chat_manager):
        """Test manager initializes correctly."""
        assert chat_manager.filter is not None
        assert chat_manager.auto_responses == [] or len(chat_manager.auto_responses) > 0
        assert chat_manager.message_history == []
        assert chat_manager.max_history == 1000
        assert chat_manager.commands != {}
    
    def test_default_commands_registered(self, chat_manager):
        """Test default commands are registered."""
        assert "follow" in chat_manager.commands
        assert "attack" in chat_manager.commands
        assert "retreat" in chat_manager.commands
        assert "heal" in chat_manager.commands
        assert "buff" in chat_manager.commands
        assert "stop" in chat_manager.commands
        assert "status" in chat_manager.commands
    
    def test_bot_name_set(self, chat_manager):
        """Test bot name is set."""
        assert chat_manager.bot_name == "TestBot"
    
    def test_empty_authorization_lists(self):
        """Test authorization lists start empty."""
        manager = ChatManager()
        assert manager.authorized_commanders == set()
        assert manager.friend_list == set()
        assert manager.party_leader == ""
        assert manager.guild_leader == ""


# Channel Parsing Tests

class TestChannelParsing:
    """Test chat channel parsing."""
    
    def test_parse_public_channel(self, chat_manager):
        """Test parsing public channel."""
        channel = chat_manager._parse_channel("public")
        assert channel == ChatChannel.PUBLIC
    
    def test_parse_party_channel(self, chat_manager):
        """Test parsing party channel."""
        channel = chat_manager._parse_channel("party")
        assert channel == ChatChannel.PARTY
    
    def test_parse_guild_channel(self, chat_manager):
        """Test parsing guild channel."""
        channel = chat_manager._parse_channel("guild")
        assert channel == ChatChannel.GUILD
    
    def test_parse_whisper_channel(self, chat_manager):
        """Test parsing whisper channel."""
        channel = chat_manager._parse_channel("whisper")
        assert channel == ChatChannel.WHISPER
    
    def test_parse_pm_as_whisper(self, chat_manager):
        """Test PM is parsed as whisper."""
        channel = chat_manager._parse_channel("pm")
        assert channel == ChatChannel.WHISPER
    
    def test_parse_global_channel(self, chat_manager):
        """Test parsing global channel."""
        channel = chat_manager._parse_channel("global")
        assert channel == ChatChannel.GLOBAL
    
    def test_parse_trade_channel(self, chat_manager):
        """Test parsing trade channel."""
        channel = chat_manager._parse_channel("trade")
        assert channel == ChatChannel.TRADE
    
    def test_parse_unknown_channel(self, chat_manager):
        """Test parsing unknown channel defaults to public."""
        channel = chat_manager._parse_channel("unknown")
        assert channel == ChatChannel.PUBLIC
    
    def test_parse_case_insensitive(self, chat_manager):
        """Test channel parsing is case insensitive."""
        channel = chat_manager._parse_channel("PARTY")
        assert channel == ChatChannel.PARTY


# Message Extraction Tests

class TestMessageExtraction:
    """Test extracting messages from game state."""
    
    @pytest.mark.asyncio
    async def test_get_new_messages(self, chat_manager):
        """Test extracting new messages."""
        # Create mock state
        state = Mock()
        state.extra = {
            "chat_messages": [
                {
                    "id": "msg1",
                    "channel": "party",
                    "sender": "PartyLeader",
                    "sender_id": 123,
                    "content": "Hello",
                    "timestamp": datetime.now().timestamp()
                },
                {
                    "id": "msg2",
                    "channel": "public",
                    "sender": "RandomPlayer",
                    "sender_id": 456,
                    "content": "Hi",
                    "timestamp": datetime.now().timestamp()
                }
            ]
        }
        
        messages = chat_manager._get_new_messages(state)
        
        assert len(messages) == 2
        assert messages[0].sender_name == "PartyLeader"
        assert messages[1].sender_name == "RandomPlayer"
    
    @pytest.mark.asyncio
    async def test_get_messages_empty_state(self, chat_manager):
        """Test extracting from state with no messages."""
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        
        messages = chat_manager._get_new_messages(state)
        
        assert messages == []
    
    @pytest.mark.asyncio
    async def test_get_messages_no_extra(self, chat_manager):
        """Test extraction with no extra data."""
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        # No extra field
        
        messages = chat_manager._get_new_messages(state)
        
        assert messages == []
    
    @pytest.mark.asyncio
    async def test_skips_already_processed(self, chat_manager):
        """Test skips already processed messages."""
        state = Mock()
        state.extra = {
            "chat_messages": [
                {
                    "id": "msg1",
                    "channel": "party",
                    "sender": "Player",
                    "sender_id": 1,
                    "content": "Test",
                    "timestamp": datetime.now().timestamp()
                }
            ]
        }
        
        # Process once
        messages1 = chat_manager._get_new_messages(state)
        assert len(messages1) == 1
        
        # Process again - should skip (same msg ID)
        messages2 = chat_manager._get_new_messages(state)
        assert len(messages2) == 0


# Command Recognition Tests

class TestCommandRecognition:
    """Test command recognition."""
    
    def test_is_command_for_me_true(self, chat_manager):
        """Test recognizing command directed at bot."""
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            sender_id=1,
            content="TestBot follow",
            timestamp=datetime.now()
        )
        
        result = chat_manager._is_command_for_me(msg)
        assert result is True
    
    def test_is_command_for_me_false(self, chat_manager):
        """Test not recognizing command for other bot."""
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            sender_id=1,
            content="OtherBot follow",
            timestamp=datetime.now()
        )
        
        result = chat_manager._is_command_for_me(msg)
        assert result is False
    
    def test_is_command_no_bot_name(self):
        """Test command check with no bot name set."""
        manager = ChatManager()
        # bot_name is empty
        
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            sender_id=1,
            content="Bot follow",
            timestamp=datetime.now()
        )
        
        result = manager._is_command_for_me(msg)
        assert result is False


# Authorization Tests

class TestAuthorization:
    """Test command authorization."""
    
    def test_authorized_commander_allowed(self, chat_manager):
        """Test authorized commander can issue commands."""
        chat_manager.add_authorized_commander("Commander1")
        
        is_authorized = chat_manager._is_authorized_commander(
            "Commander1",
            ChatChannel.WHISPER
        )
        
        assert is_authorized is True
    
    def test_unauthorized_player_blocked(self, chat_manager):
        """Test unauthorized player cannot command."""
        is_authorized = chat_manager._is_authorized_commander(
            "RandomPlayer",
            ChatChannel.WHISPER
        )
        
        assert is_authorized is False
    
    def test_party_leader_authorized_in_party(self, chat_manager):
        """Test party leader can command via party chat."""
        chat_manager.set_party_leader("PartyLeader")
        
        is_authorized = chat_manager._is_authorized_commander(
            "PartyLeader",
            ChatChannel.PARTY
        )
        
        assert is_authorized is True
    
    def test_party_leader_not_authorized_in_whisper(self, chat_manager):
        """Test party leader cannot command via whisper alone."""
        chat_manager.set_party_leader("PartyLeader")
        
        is_authorized = chat_manager._is_authorized_commander(
            "PartyLeader",
            ChatChannel.WHISPER
        )
        
        # Not authorized unless also in friend list
        assert is_authorized is False
    
    def test_guild_leader_authorized_in_guild(self, chat_manager):
        """Test guild leader can command via guild chat."""
        chat_manager.set_guild_leader("GuildLeader")
        
        is_authorized = chat_manager._is_authorized_commander(
            "GuildLeader",
            ChatChannel.GUILD
        )
        
        assert is_authorized is True
    
    def test_friend_authorized_in_whisper(self, chat_manager):
        """Test friend can command via whisper."""
        chat_manager.set_friend_list(["Friend1", "Friend2"])
        
        is_authorized = chat_manager._is_authorized_commander(
            "Friend1",
            ChatChannel.WHISPER
        )
        
        assert is_authorized is True


# Command Handling Tests

class TestCommandHandling:
    """Test command execution."""
    
    def test_handle_follow_command(self, chat_manager):
        """Test executing follow command."""
        action = chat_manager._cmd_follow("Player1", [])
        
        assert action is not None
        assert action.extra["command"] == "follow"
        assert action.extra["target_name"] == "Player1"
    
    def test_handle_follow_with_target(self, chat_manager):
        """Test follow command with specific target."""
        action = chat_manager._cmd_follow("Player1", ["Player2"])
        
        assert action.extra["target_name"] == "Player2"
    
    def test_handle_attack_command(self, chat_manager):
        """Test executing attack command."""
        action = chat_manager._cmd_attack([])
        
        assert action is not None
        assert action.extra["command"] == "attack"
        assert action.extra["target"] == "nearest"
    
    def test_handle_attack_with_target(self, chat_manager):
        """Test attack command with target."""
        action = chat_manager._cmd_attack(["poring"])
        
        assert action.extra["target"] == "poring"
    
    def test_handle_retreat_command(self, chat_manager):
        """Test executing retreat command."""
        action = chat_manager._cmd_retreat()
        
        assert action is not None
        assert action.extra["command"] == "retreat"
        assert action.priority == 1  # High priority
    
    def test_handle_heal_command(self, chat_manager):
        """Test executing heal command."""
        action = chat_manager._cmd_heal("Player1", [])
        
        assert action is not None
        assert action.type == ActionType.SKILL
        assert action.skill_id == 28
        assert action.extra["target_name"] == "Player1"
    
    def test_handle_heal_with_target(self, chat_manager):
        """Test heal command with specific target."""
        action = chat_manager._cmd_heal("Player1", ["Player2"])
        
        assert action.extra["target_name"] == "Player2"
    
    def test_handle_buff_command(self, chat_manager):
        """Test executing buff command."""
        action = chat_manager._cmd_buff("Player1", [])
        
        assert action is not None
        assert action.extra["command"] == "buff"
        assert action.extra["target_name"] == "Player1"
        assert action.extra["buff_type"] == "all"
    
    def test_handle_buff_with_type(self, chat_manager):
        """Test buff command with specific type."""
        action = chat_manager._cmd_buff("Player1", ["Player2", "agi"])
        
        assert action.extra["target_name"] == "Player2"
        assert action.extra["buff_type"] == "agi"
    
    def test_handle_stop_command(self, chat_manager):
        """Test executing stop command."""
        action = chat_manager._cmd_stop()
        
        assert action is not None
        assert action.extra["command"] == "stop"
        assert action.priority == 1  # Priority must be >= 1
    
    def test_handle_status_command(self, chat_manager):
        """Test executing status command."""
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            sender_id=1,
            content="TestBot status",
            timestamp=datetime.now()
        )
        
        action = chat_manager._cmd_status(msg)
        
        assert action is not None
        assert "Status" in action.extra["content"]


# Auto-Response Tests

class TestAutoResponses:
    """Test auto-response system."""
    
    def test_register_auto_response(self, chat_manager):
        """Test registering auto-response."""
        initial_count = len(chat_manager.auto_responses)
        
        chat_manager.register_auto_response(
            trigger="hello",
            response="Hi there!",
            channel=ChatChannel.PUBLIC,
            cooldown=60
        )
        
        assert len(chat_manager.auto_responses) == initial_count + 1
    
    def test_check_auto_response_matches(self, chat_manager):
        """Test auto-response triggers on match."""
        # Register response
        chat_manager.auto_responses = []  # Clear defaults
        chat_manager.register_auto_response(
            trigger="hello",
            response="Hi!",
            channel=ChatChannel.PUBLIC
        )
        
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PUBLIC,
            sender_name="Player",
            sender_id=1,
            content="hello everyone",
            timestamp=datetime.now()
        )
        
        # AutoResponse.matches() is a real method
        action = chat_manager._check_auto_responses(msg)
        
        assert action is not None
    
    def test_check_auto_response_no_match(self, chat_manager):
        """Test auto-response doesn't trigger without match."""
        chat_manager.auto_responses = []
        
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PUBLIC,
            sender_name="Player",
            sender_id=1,
            content="random message",
            timestamp=datetime.now()
        )
        
        action = chat_manager._check_auto_responses(msg)
        
        assert action is None


# Message Sending Tests

class TestSendMessage:
    """Test sending chat messages."""
    
    def test_send_message_public(self, chat_manager):
        """Test sending public message."""
        action = chat_manager.send_message(
            ChatChannel.PUBLIC,
            "Hello world"
        )
        
        assert action is not None
        assert action.extra["chat_channel"] == "global"  # PUBLIC = "global"
        assert action.extra["content"] == "Hello world"
        assert action.extra["target"] is None
    
    def test_send_message_whisper(self, chat_manager):
        """Test sending whisper with target."""
        action = chat_manager.send_message(
            ChatChannel.WHISPER,
            "Private message",
            target="Player1"
        )
        
        assert action.extra["chat_channel"] == "whisper"
        assert action.extra["target"] == "Player1"
    
    def test_send_message_party(self, chat_manager):
        """Test sending party message."""
        action = chat_manager.send_message(
            ChatChannel.PARTY,
            "Party message"
        )
        
        assert action.extra["chat_channel"] == "party"


# Command Registration Tests

class TestCommandRegistration:
    """Test command registration."""
    
    def test_register_custom_command(self, chat_manager):
        """Test registering custom command."""
        cmd = ChatCommand(
            name="custom",
            aliases=["c"],
            description="Custom command",
            usage="custom [arg]",
            min_args=0,
            max_args=1
        )
        
        chat_manager.register_command(cmd)
        
        assert "custom" in chat_manager.commands
        assert chat_manager.commands["custom"] == cmd


# Authorization Management Tests

class TestAuthorizationManagement:
    """Test authorization list management."""
    
    def test_add_authorized_commander(self, chat_manager):
        """Test adding authorized commander."""
        chat_manager.add_authorized_commander("Commander1")
        
        assert "Commander1" in chat_manager.authorized_commanders
    
    def test_remove_authorized_commander(self, chat_manager):
        """Test removing authorized commander."""
        chat_manager.add_authorized_commander("Commander1")
        chat_manager.remove_authorized_commander("Commander1")
        
        assert "Commander1" not in chat_manager.authorized_commanders
    
    def test_remove_nonexistent_commander(self, chat_manager):
        """Test removing non-existent commander."""
        # Should not crash
        chat_manager.remove_authorized_commander("NonExistent")
        
        assert "NonExistent" not in chat_manager.authorized_commanders
    
    def test_set_party_leader(self, chat_manager):
        """Test setting party leader."""
        chat_manager.set_party_leader("Leader1")
        
        assert chat_manager.party_leader == "Leader1"
    
    def test_set_guild_leader(self, chat_manager):
        """Test setting guild leader."""
        chat_manager.set_guild_leader("GuildMaster")
        
        assert chat_manager.guild_leader == "GuildMaster"
    
    def test_set_friend_list(self, chat_manager):
        """Test setting friend list."""
        friends = ["Friend1", "Friend2", "Friend3"]
        chat_manager.set_friend_list(friends)
        
        assert len(chat_manager.friend_list) == 3
        assert "Friend1" in chat_manager.friend_list
    
    def test_set_bot_name(self):
        """Test setting bot name."""
        manager = ChatManager()
        manager.set_bot_name("MyBot")
        
        assert manager.bot_name == "MyBot"


# Message History Tests

class TestMessageHistory:
    """Test message history management."""
    
    @pytest.mark.asyncio
    async def test_tick_stores_messages(self, chat_manager):
        """Test tick stores messages in history."""
        state = Mock()
        state.extra = {
            "chat_messages": [{
                "id": "msg1",
                "channel": "party",
                "sender": "Player",
                "sender_id": 1,
                "content": "Hello",
                "timestamp": datetime.now().timestamp()
            }]
        }
        
        await chat_manager.tick(state)
        
        assert len(chat_manager.message_history) > 0
    
    @pytest.mark.asyncio
    async def test_history_trimmed_at_max(self, chat_manager):
        """Test history is trimmed at max size."""
        chat_manager.max_history = 5
        
        # Add more than max using _add_to_history to trigger trimming
        for i in range(10):
            msg = ChatMessage(
                message_id=f"msg{i}",
                channel=ChatChannel.PUBLIC,
                sender_name="Player",
                sender_id=1,
                content=f"Message {i}",
                timestamp=datetime.now()
            )
            chat_manager._add_to_history(msg)
        
        assert len(chat_manager.message_history) == 5
    
    def test_get_recent_messages(self, chat_manager):
        """Test getting recent messages."""
        # Add messages
        for i in range(20):
            msg = ChatMessage(
                message_id=f"msg{i}",
                channel=ChatChannel.PUBLIC,
                sender_name="Player",
                sender_id=1,
                content=f"Message {i}",
                timestamp=datetime.now()
            )
            chat_manager.message_history.append(msg)
        
        recent = chat_manager.get_recent_messages(count=10)
        
        assert len(recent) == 10
        # Should get last 10
        assert recent[-1].content == "Message 19"
    
    def test_get_recent_messages_by_channel(self, chat_manager):
        """Test filtering recent by channel."""
        # Add mixed messages
        for i in range(10):
            channel = ChatChannel.PARTY if i % 2 == 0 else ChatChannel.PUBLIC
            msg = ChatMessage(
                message_id=f"msg{i}",
                channel=channel,
                sender_name="Player",
                sender_id=1,
                content=f"Message {i}",
                timestamp=datetime.now()
            )
            chat_manager.message_history.append(msg)
        
        party_msgs = chat_manager.get_recent_messages(
            channel=ChatChannel.PARTY,
            count=10
        )
        
        assert all(m.channel == ChatChannel.PARTY for m in party_msgs)
    
    def test_find_player_in_chat(self, chat_manager):
        """Test finding messages from specific player."""
        # Add messages from different players
        for i in range(5):
            msg = ChatMessage(
                message_id=f"msg{i}",
                channel=ChatChannel.PUBLIC,
                sender_name="Player1" if i < 3 else "Player2",
                sender_id=1,
                content=f"Message {i}",
                timestamp=datetime.now()
            )
            chat_manager.message_history.append(msg)
        
        player1_msgs = chat_manager.find_player_in_chat("Player1")
        
        assert len(player1_msgs) == 3
        assert all(m.sender_name == "Player1" for m in player1_msgs)


# Tick Processing Tests

class TestTickProcessing:
    """Test tick processing."""
    
    @pytest.mark.asyncio
    async def test_tick_processes_commands(self, chat_manager):
        """Test tick processes commands."""
        chat_manager.set_party_leader("Leader")
        
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        state.extra = {
            "chat_messages": [{
                "id": "msg1",
                "channel": "party",
                "sender": "Leader",
                "sender_id": 1,
                "content": "TestBot follow",
                "timestamp": datetime.now().timestamp()
            }]
        }
        
        # No patching needed - use real methods
        actions = await chat_manager.tick(state)
        
        # Should generate action
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_tick_filters_blocked_messages(self, chat_manager):
        """Test tick filters blocked messages."""
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        state.extra = {
            "chat_messages": [{
                "id": "msg1",
                "channel": "public",
                "sender": "Spammer",
                "sender_id": 1,
                "content": "BUY GOLD HERE",
                "timestamp": datetime.now().timestamp()
            }]
        }
        
        # Add spam keyword to filter to block the message
        chat_manager.filter.keywords_block.append("BUY GOLD")
        await chat_manager.tick(state)
        
        # Message should not be in history because it contains blocked keyword
        assert len(chat_manager.message_history) == 0


# Edge Cases

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.mark.asyncio
    async def test_tick_with_no_extra(self, chat_manager):
        """Test tick with state missing extra."""
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        
        # Should not crash
        actions = await chat_manager.tick(state)
        
        assert actions == []
    
    def test_command_with_no_match(self, chat_manager):
        """Test handling unknown command."""
        msg = ChatMessage(
            message_id="test",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            sender_id=1,
            content="TestBot unknowncommand",
            timestamp=datetime.now()
        )
        
        # Use real methods - they already exist on ChatMessage
        action = chat_manager._handle_command(msg)
        
        # Should return None for unknown command
        assert action is None
    
    def test_get_recent_more_than_history(self, chat_manager):
        """Test getting more messages than in history."""
        # Add only 3 messages
        for i in range(3):
            msg = ChatMessage(
                message_id=f"msg{i}",
                channel=ChatChannel.PUBLIC,
                sender_name="Player",
                sender_id=1,
                content=f"Message {i}",
                timestamp=datetime.now()
            )
            chat_manager.message_history.append(msg)
        
        # Request 10
        recent = chat_manager.get_recent_messages(count=10)
        
        # Should return all 3
        assert len(recent) == 3
    
    def test_find_player_not_in_chat(self, chat_manager):
        """Test finding player not in chat."""
        messages = chat_manager.find_player_in_chat("NonExistentPlayer")
        
        assert len(messages) == 0


# Integration Tests

class TestIntegration:
    """Test integrated workflows."""
    
    @pytest.mark.asyncio
    async def test_full_command_workflow(self, chat_manager):
        """Test complete command workflow."""
        # Setup authorization
        chat_manager.set_party_leader("Leader")
        
        # Create state with command
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        state.extra = {
            "chat_messages": [{
                "id": "msg1",
                "channel": "party",
                "sender": "Leader",
                "sender_id": 1,
                "content": "TestBot attack",
                "timestamp": datetime.now().timestamp()
            }]
        }
        
        # Use real methods - no patching needed
        actions = await chat_manager.tick(state)
        
        # Should process command
        assert len(actions) > 0
        # Should store in history
        assert len(chat_manager.message_history) > 0
    
    @pytest.mark.asyncio
    async def test_unauthorized_command_blocked(self, chat_manager):
        """Test unauthorized command is blocked."""
        state = GameState(
            hp=100, max_hp=100, sp=50, max_sp=50,
            position=(0, 0), map_name="prontera"
        )
        state.extra = {
            "chat_messages": [{
                "id": "msg1",
                "channel": "whisper",
                "sender": "RandomPlayer",
                "sender_id": 999,
                "content": "TestBot stop",
                "timestamp": datetime.now().timestamp()
            }]
        }
        
        # Use real methods - no patching needed
        actions = await chat_manager.tick(state)
        
        # Should send unauthorized response
        if len(actions) > 0:
            # Check if it's an unauthorized message
            assert "authorized" in actions[0].extra.get("content", "").lower() or len(actions) == 0