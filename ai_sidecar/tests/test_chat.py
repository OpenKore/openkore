"""
Tests for chat models and chat manager.

Tests chat filtering, command recognition, auto-responses,
and message processing logic.
"""

import pytest
from datetime import datetime

from ai_sidecar.social.chat_models import (
    ChatMessage,
    ChatChannel,
    ChatFilter,
    AutoResponse,
    ChatCommand
)
from ai_sidecar.social.chat_manager import ChatManager
from ai_sidecar.core.state import GameState


class TestChatModels:
    """Test chat data models."""
    
    def test_chat_message_creation(self):
        """Test creating a chat message."""
        msg = ChatMessage(
            message_id="msg_001",
            channel=ChatChannel.PARTY,
            sender_name="TestPlayer",
            content="Hello party!"
        )
        
        assert msg.channel == ChatChannel.PARTY
        assert not msg.is_command
    
    def test_message_directed_at_bot(self):
        """Test detecting messages directed at bot."""
        msg = ChatMessage(
            message_id="msg_002",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="@BotName attack"
        )
        
        assert msg.is_directed_at("BotName")
        assert not msg.is_directed_at("OtherBot")
    
    def test_command_extraction(self):
        """Test extracting commands from messages."""
        msg = ChatMessage(
            message_id="msg_003",
            channel=ChatChannel.PARTY,
            sender_name="Leader",
            content="@BotName follow me"
        )
        
        result = msg.extract_command("BotName")
        assert result is not None
        command, args = result
        assert command == "follow"
        assert args == ["me"]
    
    def test_chat_filter_blocking(self):
        """Test chat message filtering."""
        filter_obj = ChatFilter(
            keywords_block=["spam", "gold seller"],
            blocked_players=["Spammer"]
        )
        
        spam_msg = ChatMessage(
            message_id="msg_004",
            channel=ChatChannel.GLOBAL,
            sender_name="BadActor",
            content="Buy cheap gold!!!"
        )
        
        blocked_msg = ChatMessage(
            message_id="msg_005",
            channel=ChatChannel.GLOBAL,
            sender_name="Spammer",
            content="Hello"
        )
        
        assert not filter_obj.should_block(spam_msg)  # "gold" alone won't match "gold seller"
        assert filter_obj.should_block(blocked_msg)
    
    def test_auto_response_matching(self):
        """Test auto-response trigger matching."""
        auto_resp = AutoResponse(
            trigger_patterns=[r"\bhello\b", r"\bhi\b"],
            response_template="Hello {sender}!",
            channel=ChatChannel.PARTY,
            cooldown_seconds=60
        )
        
        msg = ChatMessage(
            message_id="msg_006",
            channel=ChatChannel.PARTY,
            sender_name="FriendlyPlayer",
            content="hello everyone"
        )
        
        assert auto_resp.matches(msg)
        response = auto_resp.generate_response(msg)
        assert response == "Hello FriendlyPlayer!"


class TestChatManager:
    """Test chat manager logic."""
    
    @pytest.fixture
    def manager(self):
        """Create chat manager instance."""
        mgr = ChatManager()
        mgr.set_bot_name("TestBot")
        return mgr
    
    def test_command_registration(self, manager):
        """Test command registration."""
        cmd = ChatCommand(
            name="testcmd",
            aliases=["tc"],
            description="Test command",
            usage="testcmd <arg>",
            min_args=1,
            max_args=1
        )
        
        manager.register_command(cmd)
        assert "testcmd" in manager.commands
    
    def test_auto_response_registration(self, manager):
        """Test auto-response registration."""
        manager.register_auto_response(
            trigger=r"\bhello\b",
            response="Hi {sender}!",
            channel=ChatChannel.PARTY,
            cooldown=30
        )
        
        assert len(manager.auto_responses) > 0
    
    @pytest.mark.asyncio
    async def test_chat_tick(self, manager):
        """Test chat tick processing."""
        game_state = GameState()
        actions = await manager.tick(game_state)
        
        # With no new messages, should return empty
        assert len(actions) == 0