"""
Comprehensive tests for pvp/coordination.py - BATCH 4.
Target: 95%+ coverage (currently 84.73%, 23 uncovered lines).
"""

import pytest
from datetime import datetime, timedelta
from ai_sidecar.pvp.coordination import (
    GuildCoordinator,
    FormationType,
    GuildCommand,
    CommandPriority,
    GuildMember,
    CoordinationCommand,
    FormationPosition,
)


class TestGuildCoordinator:
    """Test GuildCoordinator functionality."""
    
    @pytest.fixture
    def coordinator(self):
        """Create coordinator instance."""
        return GuildCoordinator()
    
    @pytest.fixture
    def sample_member_data(self):
        """Sample member data."""
        return {
            "player_id": 1001,
            "name": "TestPlayer",
            "job_class": "lord_knight",
            "role": "tank",
            "position": [100, 200],
            "hp_percent": 85.0,
            "sp_percent": 70.0,
            "is_leader": False,
        }
    
    def test_initialization(self, coordinator):
        """Test coordinator initialization."""
        assert len(coordinator.members) == 0
        assert len(coordinator.active_commands) == 0
        assert coordinator.current_formation == FormationType.SCATTER
        assert coordinator.formation_center == (0, 0)
        assert FormationType.WEDGE in coordinator.formation_positions
        assert FormationType.LINE in coordinator.formation_positions
    
    def test_add_member(self, coordinator, sample_member_data):
        """Test adding guild member."""
        coordinator.add_member(sample_member_data)
        
        assert 1001 in coordinator.members
        member = coordinator.members[1001]
        assert member.player_name == "TestPlayer"
        assert member.job_class == "lord_knight"
        assert member.role == "tank"
        assert member.position == (100, 200)
    
    def test_add_leader_member(self, coordinator):
        """Test adding leader sets formation center."""
        leader_data = {
            "player_id": 1,
            "name": "Leader",
            "job_class": "paladin",
            "role": "tank",
            "position": [50, 60],
            "is_leader": True,
        }
        coordinator.add_member(leader_data)
        
        assert coordinator.formation_leader_id == 1
        assert coordinator.formation_center == (50, 60)
    
    def test_update_member_position(self, coordinator, sample_member_data):
        """Test updating member position."""
        coordinator.add_member(sample_member_data)
        
        new_pos = (150, 250)
        coordinator.update_member_position(1001, new_pos)
        
        assert coordinator.members[1001].position == new_pos
    
    def test_update_leader_position_updates_center(self, coordinator):
        """Test updating leader position updates formation center."""
        leader_data = {
            "player_id": 1,
            "name": "Leader",
            "is_leader": True,
            "position": [100, 100],
        }
        coordinator.add_member(leader_data)
        
        new_pos = (200, 200)
        coordinator.update_member_position(1, new_pos)
        
        assert coordinator.formation_center == new_pos
    
    def test_update_member_status(self, coordinator, sample_member_data):
        """Test updating member HP/SP."""
        coordinator.add_member(sample_member_data)
        
        coordinator.update_member_status(1001, 50.0, 30.0)
        
        member = coordinator.members[1001]
        assert member.hp_percent == 50.0
        assert member.sp_percent == 30.0
    
    def test_remove_member(self, coordinator, sample_member_data):
        """Test removing member."""
        coordinator.add_member(sample_member_data)
        assert 1001 in coordinator.members
        
        coordinator.remove_member(1001)
        assert 1001 not in coordinator.members
    
    @pytest.mark.asyncio
    async def test_execute_formation(self, coordinator, sample_member_data):
        """Test formation execution."""
        coordinator.add_member(sample_member_data)
        
        await coordinator.execute_formation(FormationType.WEDGE)
        
        assert coordinator.current_formation == FormationType.WEDGE
    
    @pytest.mark.asyncio
    async def test_call_target(self, coordinator, sample_member_data):
        """Test target calling."""
        coordinator.add_member(sample_member_data)
        
        target_id = 5000
        await coordinator.call_target(target_id, 1001, duration_seconds=10.0)
        
        assert coordinator.called_target_id == target_id
        assert coordinator.called_target_expires is not None
    
    def test_get_called_target_valid(self, coordinator):
        """Test getting valid called target."""
        coordinator.called_target_id = 5000
        coordinator.called_target_expires = datetime.now() + timedelta(seconds=10)
        
        target = coordinator.get_called_target()
        assert target == 5000
    
    def test_get_called_target_expired(self, coordinator):
        """Test getting expired called target returns None."""
        coordinator.called_target_id = 5000
        coordinator.called_target_expires = datetime.now() - timedelta(seconds=1)
        
        target = coordinator.get_called_target()
        assert target is None
        assert coordinator.called_target_id is None
    
    @pytest.mark.asyncio
    async def test_request_support(self, coordinator, sample_member_data):
        """Test support request."""
        coordinator.add_member(sample_member_data)
        
        await coordinator.request_support(1001, "heal", CommandPriority.HIGH)
        
        assert len(coordinator.active_commands) > 0
        cmd = coordinator.active_commands[0]
        assert cmd.command_type == GuildCommand.REQUEST_HEAL
        assert cmd.priority == CommandPriority.HIGH
    
    @pytest.mark.asyncio
    async def test_sync_buffs(self, coordinator, sample_member_data):
        """Test buff synchronization."""
        coordinator.add_member(sample_member_data)
        
        buffs = ["blessing", "increase_agi"]
        result = await coordinator.sync_buffs(buffs)
        
        assert "blessing" in result
        assert "increase_agi" in result
        assert 1001 in result["blessing"]
    
    def test_get_formation_position(self, coordinator, sample_member_data):
        """Test getting formation position."""
        coordinator.add_member(sample_member_data)
        coordinator.formation_center = (100, 100)
        coordinator.current_formation = FormationType.WEDGE
        
        # Assign formation slot
        coordinator.members[1001].formation_slot = 0
        
        position = coordinator.get_formation_position(1001)
        assert position is not None
        assert isinstance(position, tuple)
    
    def test_get_formation_position_no_member(self, coordinator):
        """Test getting position for non-existent member."""
        position = coordinator.get_formation_position(9999)
        assert position is None
    
    def test_get_members_needing_support_heal(self, coordinator):
        """Test getting members needing healing."""
        member1 = {"player_id": 1, "name": "P1", "hp_percent": 40.0}
        member2 = {"player_id": 2, "name": "P2", "hp_percent": 90.0}
        
        coordinator.add_member(member1)
        coordinator.add_member(member2)
        
        needy = coordinator.get_members_needing_support("heal", hp_threshold=50.0)
        assert len(needy) == 1
        assert needy[0].player_id == 1
    
    def test_get_members_needing_support_sp(self, coordinator):
        """Test getting members needing SP."""
        member = {"player_id": 1, "name": "P1", "sp_percent": 20.0}
        coordinator.add_member(member)
        
        needy = coordinator.get_members_needing_support("sp")
        assert len(needy) == 1
    
    def test_get_nearest_ally(self, coordinator):
        """Test getting nearest ally."""
        member1 = {"player_id": 1, "name": "P1", "position": [100, 100], "role": "tank"}
        member2 = {"player_id": 2, "name": "P2", "position": [200, 200], "role": "healer"}
        
        coordinator.add_member(member1)
        coordinator.add_member(member2)
        
        nearest = coordinator.get_nearest_ally((110, 110))
        assert nearest is not None
        assert nearest.player_id == 1
    
    def test_get_nearest_ally_by_role(self, coordinator):
        """Test getting nearest ally filtered by role."""
        member1 = {"player_id": 1, "name": "P1", "position": [100, 100], "role": "tank"}
        member2 = {"player_id": 2, "name": "P2", "position": [110, 110], "role": "healer"}
        
        coordinator.add_member(member1)
        coordinator.add_member(member2)
        
        nearest = coordinator.get_nearest_ally((105, 105), role="healer")
        assert nearest is not None
        assert nearest.player_id == 2
        assert nearest.role == "healer"
    
    def test_get_active_commands(self, coordinator):
        """Test getting active commands."""
        cmd1 = CoordinationCommand(
            command_id="cmd1",
            command_type=GuildCommand.PUSH,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.HIGH,
            expires_at=datetime.now() + timedelta(seconds=30),
        )
        coordinator.active_commands.append(cmd1)
        
        commands = coordinator.get_active_commands()
        assert len(commands) == 1
    
    def test_get_active_commands_filters_expired(self, coordinator):
        """Test that expired commands are filtered out."""
        expired_cmd = CoordinationCommand(
            command_id="cmd1",
            command_type=GuildCommand.PUSH,
            issuer_id=1,
            issuer_name="Leader",
            expires_at=datetime.now() - timedelta(seconds=10),
        )
        coordinator.active_commands.append(expired_cmd)
        
        commands = coordinator.get_active_commands()
        assert len(commands) == 0
    
    def test_get_active_commands_by_priority(self, coordinator):
        """Test filtering commands by priority."""
        cmd1 = CoordinationCommand(
            command_id="cmd1",
            command_type=GuildCommand.PUSH,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.HIGH,
        )
        cmd2 = CoordinationCommand(
            command_id="cmd2",
            command_type=GuildCommand.HOLD_POSITION,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.LOW,
        )
        coordinator.active_commands.extend([cmd1, cmd2])
        
        high_priority = coordinator.get_active_commands(priority=CommandPriority.HIGH)
        assert len(high_priority) == 1
        assert high_priority[0].priority == CommandPriority.HIGH
    
    def test_issue_command(self, coordinator, sample_member_data):
        """Test issuing a command."""
        coordinator.add_member(sample_member_data)
        
        cmd = coordinator.issue_command(
            command_type=GuildCommand.FOCUS_FIRE,
            issuer_id=1001,
            priority=CommandPriority.CRITICAL,
            target_id=5000,
            duration_seconds=15.0,
        )
        
        assert cmd.command_type == GuildCommand.FOCUS_FIRE
        assert cmd.issuer_id == 1001
        assert cmd.priority == CommandPriority.CRITICAL
        assert cmd.target_id == 5000
        assert len(coordinator.active_commands) == 1
    
    def test_get_coordination_status(self, coordinator, sample_member_data):
        """Test getting coordination status."""
        coordinator.add_member(sample_member_data)
        coordinator.current_formation = FormationType.LINE
        coordinator.called_target_id = 5000
        
        status = coordinator.get_coordination_status()
        
        assert status["formation"] == "line"
        assert status["member_count"] == 1
        assert status["called_target"] == 5000
        assert "members_low_hp" in status
    
    @pytest.mark.asyncio
    async def test_should_regroup_spread_out(self, coordinator):
        """Test regroup check when members spread out."""
        member1 = {"player_id": 1, "name": "P1", "position": [0, 0]}
        member2 = {"player_id": 2, "name": "P2", "position": [100, 100]}
        
        coordinator.add_member(member1)
        coordinator.add_member(member2)
        
        should_regroup = await coordinator.should_regroup()
        assert should_regroup is True
    
    @pytest.mark.asyncio
    async def test_should_regroup_tight_formation(self, coordinator):
        """Test regroup check when members are close."""
        member1 = {"player_id": 1, "name": "P1", "position": [100, 100]}
        member2 = {"player_id": 2, "name": "P2", "position": [105, 105]}
        
        coordinator.add_member(member1)
        coordinator.add_member(member2)
        
        should_regroup = await coordinator.should_regroup()
        assert should_regroup is False
    
    def test_clear_expired_commands(self, coordinator):
        """Test clearing expired commands."""
        expired = CoordinationCommand(
            command_id="cmd1",
            command_type=GuildCommand.PUSH,
            issuer_id=1,
            issuer_name="Leader",
            expires_at=datetime.now() - timedelta(seconds=10),
        )
        active = CoordinationCommand(
            command_id="cmd2",
            command_type=GuildCommand.HOLD_POSITION,
            issuer_id=1,
            issuer_name="Leader",
            expires_at=datetime.now() + timedelta(seconds=30),
        )
        coordinator.active_commands.extend([expired, active])
        
        coordinator.clear_expired_commands()
        
        assert len(coordinator.active_commands) == 1
        assert coordinator.active_commands[0].command_id == "cmd2"
    
    @pytest.mark.asyncio
    async def test_coordinate_team_attack(self, coordinator):
        """Test team attack coordination."""
        team = [
            {"player_id": 1, "name": "P1"},
            {"player_id": 2, "name": "P2"},
        ]
        
        class MockEnemy:
            def __init__(self, id):
                self.id = id
        
        enemies = [MockEnemy(5001), MockEnemy(5002)]
        
        result = await coordinator.coordinate_team_attack(team, enemies)
        
        assert result["strategy"] == "focus_fire"
        assert result["called_target"] == 5001
        assert len(result["assignments"]) == 2
    
    @pytest.mark.asyncio
    async def test_coordinate_team_attack_empty(self, coordinator):
        """Test team attack with empty inputs."""
        result = await coordinator.coordinate_team_attack([], [])
        assert result["strategy"] == "none"
    
    @pytest.mark.asyncio
    async def test_assign_roles(self, coordinator):
        """Test role assignment."""
        team = [
            {"player_id": 1, "class": "knight", "role": ""},
            {"player_id": 2, "class": "priest", "role": ""},
            {"player_id": 3, "class": "wizard", "role": ""},
        ]
        
        assignments = await coordinator.assign_roles(team)
        
        assert 1 in assignments["tank"]
        assert 2 in assignments["healer"]
        assert 3 in assignments["dps"]
    
    @pytest.mark.asyncio
    async def test_assign_roles_provided_role(self, coordinator):
        """Test role assignment with provided roles."""
        team = [{"player_id": 1, "class": "unknown", "role": "support"}]
        
        assignments = await coordinator.assign_roles(team)
        
        assert 1 in assignments["support"]
    
    @pytest.mark.asyncio
    async def test_assign_roles_empty_team(self, coordinator):
        """Test role assignment with empty team."""
        assignments = await coordinator.assign_roles([])
        
        assert len(assignments["tank"]) == 0
        assert len(assignments["healer"]) == 0
    
    @pytest.mark.asyncio
    async def test_receive_command(self, coordinator, sample_member_data):
        """Test receiving a command."""
        coordinator.add_member(sample_member_data)
        
        cmd = CoordinationCommand(
            command_id="cmd1",
            command_type=GuildCommand.REGROUP,
            issuer_id=1001,
            issuer_name="TestPlayer",
            priority=CommandPriority.MEDIUM,
            target_position=(100, 100),
        )
        
        await coordinator.receive_command(cmd)
        
        assert len(coordinator.active_commands) == 1
    
    @pytest.mark.asyncio
    async def test_receive_critical_retreat_command(self, coordinator):
        """Test receiving critical retreat command."""
        cmd = CoordinationCommand(
            command_id="retreat",
            command_type=GuildCommand.RETREAT,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.CRITICAL,
        )
        
        await coordinator.receive_command(cmd)
        
        # Should switch to scatter formation
        assert coordinator.current_formation == FormationType.SCATTER
    
    @pytest.mark.asyncio
    async def test_receive_critical_regroup_command(self, coordinator):
        """Test receiving critical regroup command."""
        cmd = CoordinationCommand(
            command_id="regroup",
            command_type=GuildCommand.REGROUP,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.CRITICAL,
            target_position=(200, 200),
        )
        
        await coordinator.receive_command(cmd)
        
        assert coordinator.formation_center == (200, 200)
    
    @pytest.mark.asyncio
    async def test_receive_critical_call_target_command(self, coordinator):
        """Test receiving critical call target command."""
        cmd = CoordinationCommand(
            command_id="call",
            command_type=GuildCommand.CALL_TARGET,
            issuer_id=1,
            issuer_name="Leader",
            priority=CommandPriority.CRITICAL,
            target_id=5000,
            parameters={"duration": 20.0},
        )
        
        await coordinator.receive_command(cmd)
        
        assert coordinator.called_target_id == 5000