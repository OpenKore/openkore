"""
Tests for guild models and guild manager.

Tests guild management, WoE scheduling, storage operations,
and member permissions.
"""

import pytest
from datetime import datetime

from ai_sidecar.social.guild_models import (
    Guild,
    GuildMember,
    GuildPosition,
    GuildStorage,
    GuildWoESchedule
)
from ai_sidecar.social.guild_manager import GuildManager
from ai_sidecar.core.state import GameState


class TestGuildModels:
    """Test guild data models."""
    
    def test_guild_position(self):
        """Test guild position with permissions."""
        position = GuildPosition(
            position_id=0,
            name="Guild Master",
            can_invite=True,
            can_kick=True,
            can_storage=True,
            can_notice=True,
            tax_rate=0
        )
        
        assert position.can_invite
        assert position.can_storage
    
    def test_guild_member(self):
        """Test guild member creation."""
        position = GuildPosition(
            position_id=1,
            name="Member",
            can_storage=True
        )
        
        member = GuildMember(
            account_id=1001,
            char_id=2001,
            name="TestMember",
            position=position,
            job_class="Knight",
            base_level=85
        )
        
        assert member.name == "TestMember"
        assert member.position.can_storage
    
    def test_guild_creation(self):
        """Test creating a guild."""
        guild = Guild(
            guild_id=5001,
            name="Test Guild",
            master_id=2001,
            master_name="GuildMaster"
        )
        
        assert guild.name == "Test Guild"
        assert guild.member_count == 0
        assert guild.level == 1
    
    def test_guild_with_members(self):
        """Test guild with members."""
        position = GuildPosition(position_id=0, name="Master", can_storage=True)
        
        member = GuildMember(
            account_id=1001,
            char_id=2001,
            name="Master",
            position=position,
            job_class="Lord Knight",
            base_level=99
        )
        
        guild = Guild(
            guild_id=5001,
            name="Test Guild",
            master_id=2001,
            master_name="Master",
            members=[member]
        )
        
        assert len(guild.members) == 1
        assert guild.can_use_storage(2001)
        assert guild.is_master(2001)
    
    def test_guild_storage(self):
        """Test guild storage operations."""
        storage = GuildStorage(max_capacity=100)
        
        assert storage.get_item_count() == 0
        assert not storage.is_full()
        assert storage.has_space(50)
        
        storage.log_access(
            char_id=2001,
            char_name="TestPlayer",
            action="deposit",
            item_id=501,
            amount=10
        )
        
        assert len(storage.access_log) == 1
    
    def test_woe_schedule(self):
        """Test WoE schedule entry."""
        schedule = GuildWoESchedule(
            day_of_week=3,  # Wednesday
            start_hour=20,
            end_hour=22,
            map_name="prtg_cas01",
            castle_name="Kriemhild"
        )
        
        assert schedule.day_of_week == 3
        assert schedule.start_hour == 20


class TestGuildManager:
    """Test guild manager logic."""
    
    @pytest.fixture
    def manager(self):
        """Create guild manager instance."""
        return GuildManager()
    
    @pytest.fixture
    def test_guild(self):
        """Create test guild."""
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        
        return Guild(
            guild_id=5001,
            name="Test Guild",
            master_id=2001,
            master_name="GuildMaster",
            members=[
                GuildMember(
                    account_id=1001,
                    char_id=2001,
                    name="GuildMaster",
                    position=position,
                    job_class="Lord Knight",
                    base_level=99
                )
            ]
        )
    
    def test_set_guild(self, manager, test_guild):
        """Test setting guild."""
        manager.set_guild(test_guild)
        
        assert manager.guild is not None
        assert manager.guild.name == "Test Guild"
    
    def test_check_guild_skill(self, manager, test_guild):
        """Test checking guild skill levels."""
        test_guild.skills = {"GD_EXTENSION": 5, "GD_LEADERSHIP": 3}
        manager.set_guild(test_guild)
        
        assert manager.check_guild_skill("GD_EXTENSION") == 5
        assert manager.check_guild_skill("GD_LEADERSHIP") == 3
        assert manager.check_guild_skill("UNKNOWN") == 0
    
    @pytest.mark.asyncio
    async def test_guild_tick(self, manager, test_guild):
        """Test guild manager tick."""
        manager.set_guild(test_guild)
        game_state = GameState()
        
        actions = await manager.tick(game_state)
        
        # With no WoE and no requests, should return empty
        assert len(actions) == 0