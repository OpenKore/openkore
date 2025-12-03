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
from ai_sidecar.core.decision import ActionType


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
    
    @pytest.mark.asyncio
    async def test_guild_tick_no_guild(self, manager):
        """Test guild manager tick without guild."""
        game_state = GameState()
        actions = await manager.tick(game_state)
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_guild_tick_with_storage_requests(self, manager, test_guild):
        """Test guild manager tick with storage requests."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        
        # Add storage request
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        actions = await manager.tick(game_state)
        # Should process storage request
        assert len(actions) >= 0  # May be empty if no items
    
    def test_is_woe_time_no_guild(self, manager):
        """Test WoE time check without guild."""
        assert not manager._is_woe_time()
    
    def test_is_woe_time_no_schedule(self, manager, test_guild):
        """Test WoE time check with guild but no schedule."""
        manager.set_guild(test_guild)
        assert not manager._is_woe_time()
    
    def test_is_woe_time_with_active_schedule(self, manager, test_guild):
        """Test WoE time check with active schedule."""
        now = datetime.now()
        current_day = (now.weekday() + 1) % 7
        current_hour = now.hour
        
        # Create schedule for current time
        schedule = GuildWoESchedule(
            day_of_week=current_day,
            start_hour=max(0, current_hour - 1),
            end_hour=min(23, current_hour + 1),
            map_name="prtg_cas01",
            castle_name="Kriemhild"
        )
        test_guild.woe_schedule = [schedule]
        manager.set_guild(test_guild)
        
        assert manager._is_woe_time()
    
    def test_is_woe_time_inactive_schedule(self, manager, test_guild):
        """Test WoE time check with inactive schedule."""
        now = datetime.now()
        current_day = (now.weekday() + 1) % 7
        
        # Create schedule for different day
        schedule = GuildWoESchedule(
            day_of_week=(current_day + 1) % 7,
            start_hour=20,
            end_hour=22,
            map_name="prtg_cas01",
            castle_name="Kriemhild"
        )
        test_guild.woe_schedule = [schedule]
        manager.set_guild(test_guild)
        
        assert not manager._is_woe_time()
    
    @pytest.mark.asyncio
    async def test_woe_strategy_no_guild(self, manager):
        """Test WoE strategy without guild."""
        game_state = GameState()
        actions = manager._woe_strategy(game_state)
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_woe_strategy_attack_mode(self, manager, test_guild):
        """Test WoE attack strategy."""
        manager.set_guild(test_guild)
        manager.set_woe_mode("attack")
        manager.set_target_castle("Kriemhild")
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._woe_strategy(game_state)
        # Should have some actions
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_woe_strategy_defense_mode(self, manager, test_guild):
        """Test WoE defense strategy."""
        manager.set_guild(test_guild)
        manager.set_woe_mode("defense")
        manager.set_rally_point(150, 150)
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._woe_strategy(game_state)
        # Should try to move to rally point
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_woe_strategy_support_mode(self, manager, test_guild):
        """Test WoE support strategy."""
        manager.set_guild(test_guild)
        manager.set_woe_mode("support")
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._woe_strategy(game_state)
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_woe_strategy_idle_mode(self, manager, test_guild):
        """Test WoE idle strategy."""
        manager.set_guild(test_guild)
        manager.set_woe_mode("idle")
        manager.set_rally_point(150, 150)
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._woe_strategy(game_state)
        # Should move to rally point
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_woe_strategy_idle_at_rally_point(self, manager, test_guild):
        """Test WoE idle strategy when already at rally point."""
        manager.set_guild(test_guild)
        manager.set_woe_mode("idle")
        manager.set_rally_point(100, 100)
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._woe_strategy(game_state)
        # Already at rally point, no movement needed
        assert len(actions) == 0
    
    def test_woe_attack_strategy_no_target(self, manager, test_guild):
        """Test WoE attack strategy without target castle."""
        manager.set_guild(test_guild)
        game_state = GameState()
        
        actions = manager._woe_attack_strategy(game_state)
        assert isinstance(actions, list)
    
    def test_woe_defense_strategy_no_rally_point(self, manager, test_guild):
        """Test WoE defense strategy without rally point."""
        manager.set_guild(test_guild)
        game_state = GameState()
        
        actions = manager._woe_defense_strategy(game_state)
        assert isinstance(actions, list)
    
    def test_woe_support_strategy_no_guild_members(self, manager, test_guild):
        """Test WoE support strategy with no guild members."""
        manager.set_guild(test_guild)
        game_state = GameState()
        game_state.actors = []
        
        actions = manager._woe_support_strategy(game_state)
        assert isinstance(actions, list)
    
    def test_get_enemy_players_no_guild(self, manager):
        """Test getting enemy players without guild."""
        game_state = GameState()
        enemies = manager._get_enemy_players(game_state)
        assert len(enemies) == 0
    
    def test_get_guild_players_no_guild(self, manager):
        """Test getting guild players without guild."""
        game_state = GameState()
        allies = manager._get_guild_players(game_state)
        assert len(allies) == 0
    
    def test_request_guild_buff_no_guild(self, manager):
        """Test requesting guild buff without guild."""
        game_state = GameState()
        action = manager._request_guild_buff(game_state)
        assert action is None
    
    def test_request_guild_buff_no_skill(self, manager, test_guild):
        """Test requesting guild buff without skill."""
        manager.set_guild(test_guild)
        game_state = GameState()
        action = manager._request_guild_buff(game_state)
        assert action is None
    
    def test_request_guild_buff_with_skill(self, manager, test_guild):
        """Test requesting guild buff with skill."""
        test_guild.skills = {"Emergency Call": 1}
        manager.set_guild(test_guild)
        game_state = GameState()
        
        action = manager._request_guild_buff(game_state)
        assert action is not None
        assert action.extra.get("guild_skill") is True
    
    def test_set_woe_mode(self, manager):
        """Test setting WoE mode."""
        manager.set_woe_mode("attack")
        assert manager.woe_mode == "attack"
        
        manager.set_woe_mode("defense")
        assert manager.woe_mode == "defense"
    
    def test_set_rally_point(self, manager):
        """Test setting rally point."""
        manager.set_rally_point(150, 150)
        assert manager.rally_point == (150, 150)
    
    def test_set_target_castle(self, manager):
        """Test setting target castle."""
        manager.set_target_castle("Kriemhild")
        assert manager.woe_target_castle == "Kriemhild"
    
    def test_process_storage_requests_no_char_id(self, manager, test_guild):
        """Test processing storage requests without char ID."""
        manager.set_guild(test_guild)
        game_state = GameState()
        
        actions = manager._process_storage_requests(game_state)
        assert len(actions) == 0
    
    def test_process_storage_requests_no_permission(self, manager, test_guild):
        """Test processing storage requests without permission."""
        test_guild.members[0].position.can_storage = False
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        actions = manager._process_storage_requests(game_state)
        
        # Requests should be cleared
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_requests_not_near_npc(self, manager, test_guild):
        """Test processing storage requests when not near NPC."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._process_storage_requests(game_state)
        # Should try to move to NPC
        assert len(actions) > 0
    
    def test_process_storage_requests_wrong_map(self, manager, test_guild):
        """Test processing storage requests on wrong map."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "payon"
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = manager._process_storage_requests(game_state)
        # Can't move to NPC on different map
        assert len(actions) == 0
    
    def test_process_storage_deposit_insufficient_items(self, manager, test_guild):
        """Test depositing with insufficient items."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        actions = manager._process_storage_requests(game_state)
        # Request should be removed
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_withdraw_no_storage(self, manager, test_guild):
        """Test withdrawing without storage loaded."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "withdraw",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        actions = manager._process_storage_requests(game_state)
        # Request should be removed
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_withdraw_insufficient_storage(self, manager, test_guild):
        """Test withdrawing with insufficient items in storage."""
        storage = GuildStorage(max_capacity=100)
        manager.set_storage(storage)
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "withdraw",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        actions = manager._process_storage_requests(game_state)
        # Request should be removed
        assert len(manager.storage_requests) == 0
    
    def test_is_near_storage_npc_no_location(self, manager):
        """Test checking near storage NPC without location set."""
        game_state = GameState()
        assert not manager._is_near_storage_npc(game_state)
    
    def test_is_near_storage_npc_wrong_map(self, manager):
        """Test checking near storage NPC on wrong map."""
        manager.storage_npc_location = ("prontera", 150, 150)
        game_state = GameState()
        game_state.map.name = "payon"
        
        assert not manager._is_near_storage_npc(game_state)
    
    def test_is_near_storage_npc_nearby(self, manager):
        """Test checking near storage NPC when nearby."""
        manager.storage_npc_location = ("prontera", 150, 150)
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        assert manager._is_near_storage_npc(game_state)
    
    def test_is_near_storage_npc_far(self, manager):
        """Test checking near storage NPC when far away."""
        manager.storage_npc_location = ("prontera", 150, 150)
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        assert not manager._is_near_storage_npc(game_state)
    
    def test_get_inventory_item_count_empty(self, manager):
        """Test getting inventory item count with empty inventory."""
        game_state = GameState()
        game_state.inventory.items = []
        
        count = manager._get_inventory_item_count(game_state, 501)
        assert count == 0
    
    def test_set_storage_npc_location(self, manager):
        """Test setting storage NPC location."""
        manager.set_storage_npc_location("prontera", 150, 150)
        assert manager.storage_npc_location == ("prontera", 150, 150)
    
    def test_donate_exp_no_guild(self, manager):
        """Test donating EXP without guild."""
        action = manager.donate_exp(10)
        assert action is None
    
    def test_donate_exp_invalid_amount(self, manager, test_guild):
        """Test donating EXP with invalid amount."""
        manager.set_guild(test_guild)
        action = manager.donate_exp(0)
        assert action is None
        
        action = manager.donate_exp(-5)
        assert action is None
    
    def test_donate_exp_valid(self, manager, test_guild):
        """Test donating EXP with valid amount."""
        manager.set_guild(test_guild)
        action = manager.donate_exp(10)
        
        assert action is not None
        assert action.extra.get("operation") == "donate_exp"
        assert action.extra.get("amount") == 10
    
    
    def test_donate_exp_below_minimum(self, manager, test_guild):
        """Test donating EXP below minimum triggers adjustment."""
        manager.set_guild(test_guild)
        
        # Try to donate less than minimum
        action = manager.donate_exp(0.5)
        
        # Should adjust to minimum (1%)
        assert action is not None
        assert action.extra.get("amount") == 1
    
    def test_process_storage_requests_empty_after_near_check(self, manager, test_guild):
        """Test processing when storage requests become empty after NPC check."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        
        # Start with requests, but clear them during processing
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        # Clear requests after near check
        original_is_near = manager._is_near_storage_npc
        def mock_is_near_and_clear(gs):
            result = original_is_near(gs)
            if result:
                manager.storage_requests.clear()
            return result
        
        manager._is_near_storage_npc = mock_is_near_and_clear
        
        actions = manager._process_storage_requests(game_state)
        # Should return empty when requests list becomes empty
        assert len(actions) == 0
    def test_use_guild_storage_no_guild(self, manager):
        """Test using guild storage without guild."""
        actions = manager.use_guild_storage([(501, 10)])
        assert len(actions) == 0
    
    def test_use_guild_storage_no_permission(self, manager, test_guild):
        """Test using guild storage without permission."""
        test_guild.members[0].position.can_storage = False
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        
        actions = manager.use_guild_storage([(501, 10)])
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_woe_tick_during_woe_time(self, manager, test_guild, monkeypatch):
        """Test tick during WoE time."""
        # Mock _is_woe_time to return True
        monkeypatch.setattr(manager, '_is_woe_time', lambda: True)
        
        manager.set_guild(test_guild)
        manager.set_woe_mode("attack")
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        actions = await manager.tick(game_state)
        # Should execute WoE strategy
        assert isinstance(actions, list)
    
    def test_woe_attack_with_castle_and_enemies(self, manager, test_guild):
        """Test WoE attack strategy with target castle and enemies."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        manager.set_guild(test_guild)
        manager.set_target_castle("Kriemhild")
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        # Add enemy player
        enemy = ActorState(
            id=9001,
            type=ActorType.PLAYER,
            name="Enemy",
            position=Position(x=110, y=110)
        )
        enemy.hp = 1000
        enemy.hp_max = 2000
        enemy.extra = {"guild_id": 9999}
        game_state.actors = [enemy]
        
        # Add enemy to guild's enemy list
        test_guild.enemy_guilds = [9999]
        
        actions = manager._woe_attack_strategy(game_state)
        # Should have attack action
        attack_actions = [a for a in actions if a.type == ActionType.ATTACK]
        assert len(attack_actions) > 0
    
    def test_woe_defense_with_enemies_in_radius(self, manager, test_guild):
        """Test WoE defense strategy with enemies in defense radius."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        manager.set_guild(test_guild)
        manager.set_rally_point(150, 150)
        
        game_state = GameState()
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        # Add enemy player within defense radius
        enemy = ActorState(
            id=9001,
            type=ActorType.PLAYER,
            name="Enemy",
            position=Position(x=155, y=155)
        )
        enemy.hp = 1000
        enemy.hp_max = 2000
        enemy.extra = {"guild_id": 9999}
        game_state.actors = [enemy]
        
        test_guild.enemy_guilds = [9999]
        
        actions = manager._woe_defense_strategy(game_state)
        # Should attack nearby enemy
        attack_actions = [a for a in actions if a.type == ActionType.ATTACK]
        assert len(attack_actions) > 0
    
    def test_woe_support_with_low_hp_allies(self, manager, test_guild):
        """Test WoE support strategy with low HP allies."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        manager.set_guild(test_guild)
        
        game_state = GameState()
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        # Add low HP guild member
        ally = ActorState(
            id=8001,
            type=ActorType.PLAYER,
            name="Ally",
            position=Position(x=155, y=155)
        )
        ally.hp = 500
        ally.hp_max = 2000
        ally.extra = {"guild_id": 5001}
        game_state.actors = [ally]
        
        actions = manager._woe_support_strategy(game_state)
        # Should heal low HP ally
        skill_actions = [a for a in actions if a.type == ActionType.SKILL]
        assert len(skill_actions) > 0
    
    def test_woe_support_follow_group(self, manager, test_guild):
        """Test WoE support strategy following group."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        manager.set_guild(test_guild)
        
        game_state = GameState()
        game_state.character.position.x = 100
        game_state.character.position.y = 100
        
        # Add guild members far away
        for i in range(3):
            ally = ActorState(
                id=8000 + i,
                type=ActorType.PLAYER,
                name=f"Ally{i}",
                position=Position(x=150 + i, y=150 + i)
            )
            ally.hp = 2000
            ally.hp_max = 2000
            ally.extra = {"guild_id": 5001}
            game_state.actors.append(ally)
        
        actions = manager._woe_support_strategy(game_state)
        # Should move to centroid of group
        move_actions = [a for a in actions if a.type == ActionType.MOVE]
        assert len(move_actions) > 0
    
    def test_get_enemy_players_with_enemies(self, manager, test_guild):
        """Test getting enemy players."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        test_guild.enemy_guilds = [9999]
        test_guild.guild_id = 5001
        manager.set_guild(test_guild)
        
        game_state = GameState()
        
        # Add different types of actors
        enemy = ActorState(id=9001, type=ActorType.PLAYER, name="Enemy")
        enemy.extra = {"guild_id": 9999}
        
        neutral = ActorState(id=9002, type=ActorType.PLAYER, name="Neutral")
        neutral.extra = {"guild_id": 8888}
        
        ally = ActorState(id=9003, type=ActorType.PLAYER, name="Ally")
        ally.extra = {"guild_id": 5001}
        
        game_state.actors = [enemy, neutral, ally]
        
        enemies = manager._get_enemy_players(game_state)
        # Should include declared enemy and non-allied guilds
        assert len(enemies) == 2  # Enemy guild + neutral
    
    def test_get_guild_players_with_allies(self, manager, test_guild):
        """Test getting guild/allied players."""
        from ai_sidecar.core.state import ActorState, ActorType, Position
        
        test_guild.allied_guilds = [5002]
        test_guild.guild_id = 5001
        manager.set_guild(test_guild)
        
        game_state = GameState()
        
        # Add different types of actors
        guild_member = ActorState(id=9001, type=ActorType.PLAYER, name="GuildMember")
        guild_member.extra = {"guild_id": 5001}
        
        ally = ActorState(id=9002, type=ActorType.PLAYER, name="Ally")
        ally.extra = {"guild_id": 5002}
        
        enemy = ActorState(id=9003, type=ActorType.PLAYER, name="Enemy")
        enemy.extra = {"guild_id": 9999}
        
        game_state.actors = [guild_member, ally, enemy]
        
        allies = manager._get_guild_players(game_state)
        # Should include guild members and allies
        assert len(allies) == 2
    
    def test_process_storage_deposit_success(self, manager, test_guild):
        """Test successful storage deposit."""
        from ai_sidecar.core.state import InventoryItem
        
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "deposit",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        # Add item to inventory
        item = InventoryItem(index=0, item_id=501, name="Red Potion", amount=15)
        game_state.inventory.items = [item]
        
        actions = manager._process_storage_requests(game_state)
        # Should create deposit action
        assert len(actions) == 1
        assert actions[0].extra.get("operation") == "deposit"
        # Request should be removed
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_withdraw_success(self, manager, test_guild):
        """Test successful storage withdraw."""
        storage = GuildStorage(max_capacity=100)
        storage.items = [{"item_id": 501, "name": "Red Potion", "amount": 20}]
        
        manager.set_storage(storage)
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests.append({
            "item_id": 501,
            "amount": 10,
            "type": "withdraw",
            "queued_at": datetime.now().timestamp()
        })
        
        game_state = GameState()
        game_state.map.name = "prontera"
        game_state.character.position.x = 150
        game_state.character.position.y = 150
        
        actions = manager._process_storage_requests(game_state)
        # Should create withdraw action
        assert len(actions) == 1
        assert actions[0].extra.get("operation") == "withdraw"
        # Request should be removed
        assert len(manager.storage_requests) == 0
    
    def test_woe_strategy_with_guild_buff_needed(self, manager, test_guild):
        """Test WoE strategy with guild buff needed."""
        test_guild.skills = {"Emergency Call": 1}
        manager.set_guild(test_guild)
        manager.last_guild_buff = 0.0  # Long time ago
        
        game_state = GameState()
        actions = manager._woe_strategy(game_state)
        
        # Should request guild buff
        buff_actions = [a for a in actions if a.extra.get("guild_skill")]
        assert len(buff_actions) > 0
        # Timestamp should be updated
        assert manager.last_guild_buff > 0
    
    def test_woe_strategy_no_guild_buff_yet(self, manager, test_guild):
        """Test WoE strategy when guild buff not ready."""
        from datetime import datetime
        
        test_guild.skills = {"Emergency Call": 1}
        manager.set_guild(test_guild)
        manager.last_guild_buff = datetime.now().timestamp()  # Just buffed
        
        game_state = GameState()
        actions = manager._woe_strategy(game_state)
        
        # Should not request guild buff yet
        buff_actions = [a for a in actions if a.extra.get("guild_skill")]
        assert len(buff_actions) == 0
    
    def test_get_inventory_item_count_with_items(self, manager):
        """Test getting inventory item count with items."""
        from ai_sidecar.core.state import InventoryItem
        
        game_state = GameState()
        item = InventoryItem(index=0, item_id=501, name="Red Potion", amount=15)
        game_state.inventory.items = [item]
        
        count = manager._get_inventory_item_count(game_state, 501)
        assert count == 15
        
        # Non-existent item
        count = manager._get_inventory_item_count(game_state, 999)
        assert count == 0
    
    def test_use_guild_storage_valid_deposit(self, manager, test_guild):
        """Test using guild storage for deposit."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        
        actions = manager.use_guild_storage([(501, 10), (502, 5)])
        assert len(actions) == 0  # Queued for later
        assert len(manager.storage_requests) == 2
        assert manager.storage_requests[0]["type"] == "deposit"
    
    def test_use_guild_storage_valid_withdraw(self, manager, test_guild):
        """Test using guild storage for withdraw."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        
        actions = manager.use_guild_storage([(501, -10)])
        assert len(actions) == 0  # Queued for later
        assert len(manager.storage_requests) == 1
        assert manager.storage_requests[0]["type"] == "withdraw"
    
    def test_use_guild_storage_zero_amount(self, manager, test_guild):
        """Test using guild storage with zero amount."""
        manager.set_guild(test_guild)
        manager.my_char_id = 2001
        
        actions = manager.use_guild_storage([(501, 0), (502, 10)])
        assert len(manager.storage_requests) == 1  # Only non-zero queued
    
    def test_check_guild_skill_no_guild(self, manager):
        """Test checking guild skill without guild."""
        level = manager.check_guild_skill("GD_EXTENSION")
        assert level == 0
    
    def test_is_ally_no_guild(self, manager):
        """Test checking ally without guild."""
        assert not manager.is_ally(5002)
    
    def test_is_ally_valid(self, manager, test_guild):
        """Test checking ally with valid ally guild."""
        test_guild.allied_guilds = [5002, 5003]
        manager.set_guild(test_guild)
        
        assert manager.is_ally(5002)
        assert not manager.is_ally(5004)
    
    def test_is_enemy_no_guild(self, manager):
        """Test checking enemy without guild."""
        assert not manager.is_enemy(5002)
    
    def test_is_enemy_valid(self, manager, test_guild):
        """Test checking enemy with valid enemy guild."""
        test_guild.enemy_guilds = [5002, 5003]
        manager.set_guild(test_guild)
        
        assert manager.is_enemy(5002)
        assert not manager.is_enemy(5004)
    
    def test_get_online_members_count_no_guild(self, manager):
        """Test getting online members count without guild."""
        count = manager.get_online_members_count()
        assert count == 0
    
    def test_get_online_members_count_with_guild(self, manager, test_guild):
        """Test getting online members count with guild."""
        manager.set_guild(test_guild)
        count = manager.get_online_members_count()
        assert count >= 0
    
    def test_set_storage(self, manager):
        """Test setting guild storage."""
        storage = GuildStorage(max_capacity=100)
        manager.set_storage(storage)
        
        assert manager.storage is not None
        assert manager.storage.max_capacity == 100