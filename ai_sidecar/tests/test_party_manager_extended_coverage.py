"""
Extended test coverage for party_manager.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 112, 119-138, 147, 149, 158, 170-171, 173-182, 191-197, 206, 214-241
- Edge cases for Mock object handling
- Emergency response paths
- Coordination modes
"""

import pytest
from unittest.mock import Mock, MagicMock, patch
from datetime import datetime, timedelta

from ai_sidecar.social.party_manager import PartyManager
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole, PartySettings
from ai_sidecar.core.state import GameState, CharacterState, Position
from ai_sidecar.core.decision import Action, ActionType


class TestPartyManagerEdgeCases:
    """Test edge cases and uncovered paths in PartyManager."""
    
    def test_check_emergencies_with_mock_hp_percent(self):
        """Test emergency check handles Mock hp_percent gracefully."""
        manager = PartyManager()
        
        # Create party with Mock member
        member = Mock()
        member.hp_percent = Mock()  # Mock object instead of float
        member.is_online = True
        member.char_id = 1
        
        party = Mock()
        party.members = [member]
        manager.party = party
        
        # Should handle Mock gracefully (TypeError/AttributeError)
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.character.status_effects = []
        
        actions = manager._check_party_emergencies(game_state)
        assert isinstance(actions, list)
    
    def test_check_emergencies_member_needs_heal(self):
        """Test emergency heal for member with low HP."""
        manager = PartyManager()
        
        # Create party with low HP member  
        member = PartyMember(
            char_id=1,
            name="LowHPMember",
            job_class="Knight",
            base_level=50,
            hp=30,
            hp_max=100,
            x=100,
            y=100,
            is_online=True
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=2,
            members=[member]
        )
        manager.party = party
        
        # Game state with heal ability
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.character.status_effects = []
        
        actions = manager._check_party_emergencies(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.SKILL
        assert actions[0].skill_id == 28  # Heal
        assert actions[0].target_id == 1
        assert actions[0].priority == 1
    
    def test_healer_duties_with_online_members_low_hp(self):
        """Test healer duties find lowest HP online member."""
        manager = PartyManager()
        
        # Multiple members with varying HP
        members = [
            PartyMember(
                char_id=1, name="Member1", job_class="Knight",
                base_level=50, hp=90, hp_max=100, x=100, y=100, is_online=True
            ),
            PartyMember(
                char_id=2, name="Member2", job_class="Wizard",
                base_level=50, hp=40, hp_max=100, x=100, y=100, is_online=True
            ),
            PartyMember(
                char_id=3, name="Member3", job_class="Archer",
                base_level=50, hp=60, hp_max=100, x=100, y=100, is_online=True
            ),
        ]
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=members
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        
        actions = manager._healer_duties(game_state)
        
        assert len(actions) == 1
        assert actions[0].skill_id == 28
        assert actions[0].target_id == 2  # Member2 has lowest HP
    
    def test_healer_duties_with_mock_objects(self):
        """Test healer duties handles Mock hp_percent gracefully."""
        manager = PartyManager()
        
        member = Mock()
        member.hp_percent = Mock()  # Mock instead of float
        member.is_online = True
        
        party = Mock()
        party.online_members = [member]
        manager.party = party
        
        game_state = Mock()
        actions = manager._healer_duties(game_state)
        
        assert isinstance(actions, list)
    
    def test_healer_duties_no_party(self):
        """Test healer duties with no party."""
        manager = PartyManager()
        
        game_state = Mock()
        actions = manager._healer_duties(game_state)
        
        assert len(actions) == 0
    
    def test_tank_duties_with_monsters(self):
        """Test tank duties attack nearest monster."""
        manager = PartyManager()
        manager.party = Mock()
        
        # Create game state with monsters
        monster1 = Mock()
        monster1.id = 100
        monster1.position = Mock()
        monster1.position.distance_to = Mock(return_value=10.0)
        
        monster2 = Mock()
        monster2.id = 101
        monster2.position = Mock()
        monster2.position.distance_to = Mock(return_value=5.0)
        
        game_state = Mock()
        game_state.get_monsters = Mock(return_value=[monster1, monster2])
        game_state.character = Mock()
        game_state.character.position = Mock()
        
        actions = manager._tank_duties(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.ATTACK
        assert actions[0].target_id == 101  # Nearest monster
    
    def test_support_duties_buff_unbuffed_members(self):
        """Test support duties buff members without essential buffs."""
        manager = PartyManager()
        
        # Members without buffs (HP < 95% so heuristic fails)
        members = [
            PartyMember(
                char_id=1, name="Member1", job_class="Knight",
                base_level=50, hp=80, hp_max=100, sp=80, sp_max=100,
                x=100, y=100, is_online=True
            ),
        ]
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=members
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.get_monsters = Mock(return_value=[])
        
        actions = manager._support_duties(game_state)
        
        # Should buff member
        assert len(actions) > 0
        assert actions[0].type == ActionType.SKILL
    
    def test_support_duties_debuff_monsters(self):
        """Test support duties apply debuffs to monsters."""
        manager = PartyManager()
        
        # All members have buffs
        member = PartyMember(
            char_id=1, name="Member1", job_class="Knight",
            base_level=50, hp=100, hp_max=100, sp=100, sp_max=100,
            x=100, y=100, is_online=True
        )
        
        # Track that member has buffs
        import time
        manager.member_buffs[1] = {34}  # Blessing
        manager.buff_expiry[1] = {34: time.time() + 100}
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        # Monsters without debuffs
        monster = Mock()
        monster.id = 100
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.get_monsters = Mock(return_value=[monster])
        
        actions = manager._support_duties(game_state)
        
        # Should debuff monster
        assert len(actions) > 0
        assert actions[0].type == ActionType.SKILL
        assert actions[0].target_id == 100
    
    def test_support_duties_no_party(self):
        """Test support duties with no party."""
        manager = PartyManager()
        
        game_state = Mock()
        actions = manager._support_duties(game_state)
        
        assert len(actions) == 0
    
    def test_dps_duties_targets_lowest_hp_monster(self):
        """Test DPS duties target lowest HP monster."""
        manager = PartyManager()
        manager.party = Mock()
        
        monster1 = Mock()
        monster1.id = 100
        monster1.hp = 500
        
        monster2 = Mock()
        monster2.id = 101
        monster2.hp = 200
        
        game_state = Mock()
        game_state.get_monsters = Mock(return_value=[monster1, monster2])
        
        actions = manager._dps_duties(game_state)
        
        assert len(actions) == 1
        assert actions[0].target_id == 101  # Lower HP
    
    def test_maintain_coordination_follow_leader_far_away(self):
        """Test follow coordination when leader is far."""
        manager = PartyManager()
        manager.coordination_mode = "follow"
        manager.my_char_id = 2
        
        leader = PartyMember(
            char_id=1, name="Leader", job_class="Knight",
            base_level=50, x=200, y=200, is_online=True
        )
        
        me = PartyMember(
            char_id=2, name="Me", job_class="Priest",
            base_level=50, x=100, y=100, is_online=True
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[leader, me],
            settings=PartySettings(follow_leader=True)
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.position = Position(x=100, y=100)
        
        actions = manager._maintain_coordination(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
        assert actions[0].x == 200
        assert actions[0].y == 200
        assert actions[0].priority == 6
    
    def test_maintain_coordination_free_mode(self):
        """Test free coordination mode returns no actions."""
        manager = PartyManager()
        manager.coordination_mode = "free"
        manager.party = Mock()
        
        game_state = Mock()
        actions = manager._maintain_coordination(game_state)
        
        assert len(actions) == 0
    
    def test_can_heal_job_cannot_heal(self):
        """Test _can_heal returns False for non-healing jobs."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Blacksmith"
        game_state.character.sp = 50
        
        result = manager._can_heal(game_state)
        assert result is False
    
    def test_can_heal_insufficient_sp(self):
        """Test _can_heal returns False when SP too low."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 10  # Below minimum
        
        result = manager._can_heal(game_state)
        assert result is False
    
    def test_can_heal_silenced(self):
        """Test _can_heal returns False when silenced."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.character.status_effects = [7]  # Silenced
        
        result = manager._can_heal(game_state)
        assert result is False
    
    def test_can_heal_success(self):
        """Test _can_heal returns True when conditions met."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.character.status_effects = []
        
        result = manager._can_heal(game_state)
        assert result is True
    
    def test_has_essential_buffs_with_tracking(self):
        """Test buff tracking with expiry."""
        manager = PartyManager()
        
        member = PartyMember(
            char_id=1, name="Member", job_class="Knight",
            base_level=50, is_online=True
        )
        
        # Add buffs with future expiry
        import time
        manager.member_buffs[1] = {34, 29}
        manager.buff_expiry[1] = {
            34: time.time() + 100,
            29: time.time() + 100
        }
        
        result = manager._has_essential_buffs(member)
        assert result is True
    
    def test_has_essential_buffs_expired(self):
        """Test expired buffs are cleaned up."""
        manager = PartyManager()
        
        member = PartyMember(
            char_id=1, name="Member", job_class="Knight",
            base_level=50, is_online=True
        )
        
        # Add expired buff
        import time
        manager.member_buffs[1] = {34}
        manager.buff_expiry[1] = {
            34: time.time() - 10  # Expired
        }
        
        result = manager._has_essential_buffs(member)
        assert result is False
        assert 34 not in manager.member_buffs.get(1, set())
    
    def test_has_essential_buffs_fallback_heuristic(self):
        """Test fallback heuristic for buffed detection."""
        manager = PartyManager()
        
        member = PartyMember(
            char_id=1, name="Member", job_class="Knight",
            base_level=50, hp=100, hp_max=100, sp=95, sp_max=100,
            is_online=True
        )
        
        # No tracking data, should use heuristic
        result = manager._has_essential_buffs(member)
        assert result is True  # HP >= 95% and SP >= 90%
    
    def test_has_essential_buffs_mock_fallback(self):
        """Test fallback handles Mock objects."""
        manager = PartyManager()
        
        member = Mock()
        member.char_id = 1
        member.hp_percent = Mock()  # Mock
        member.sp_percent = Mock()  # Mock
        
        result = manager._has_essential_buffs(member)
        assert result is False
    
    def test_get_support_buff_skill_priest(self):
        """Test support buff skill for priest."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "High Priest"
        
        skill_id = manager._get_support_buff_skill(game_state)
        assert skill_id == 34  # Blessing
    
    def test_get_support_buff_skill_sage(self):
        """Test support buff skill for sage."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Sage"
        
        skill_id = manager._get_support_buff_skill(game_state)
        assert skill_id == 157  # Endow
    
    def test_get_support_buff_skill_bard(self):
        """Test support buff skill for bard returns None."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Bard"
        
        skill_id = manager._get_support_buff_skill(game_state)
        assert skill_id is None
    
    def test_get_support_debuff_skill_sage(self):
        """Test support debuff skill for sage."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Sage"
        
        skill_id = manager._get_support_debuff_skill(game_state)
        assert skill_id == 19  # Earth Spike
    
    def test_get_support_debuff_skill_priest(self):
        """Test support debuff skill for priest."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        
        skill_id = manager._get_support_debuff_skill(game_state)
        assert skill_id == 71  # Decrease AGI
    
    def test_get_support_debuff_skill_other(self):
        """Test support debuff skill for other job."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Knight"
        
        skill_id = manager._get_support_debuff_skill(game_state)
        assert skill_id is None
    
    @pytest.mark.asyncio
    async def test_leave_party_success(self):
        """Test leaving party."""
        manager = PartyManager()
        manager.party = Mock()
        
        result = await manager.leave_party()
        assert result is True
        assert manager.party is None
    
    @pytest.mark.asyncio
    async def test_leave_party_no_party(self):
        """Test leaving when not in party."""
        manager = PartyManager()
        
        result = await manager.leave_party()
        assert result is False
    
    @pytest.mark.asyncio
    async def test_kick_member_success(self):
        """Test kicking member as leader."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member1 = PartyMember(
            char_id=1, name="Leader", job_class="Knight", base_level=50
        )
        member2 = PartyMember(
            char_id=2, name="KickMe", job_class="Wizard", base_level=50
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member1, member2]
        )
        manager.party = party
        
        result = await manager.kick_member("KickMe")
        assert result is True
        assert len(party.members) == 1
    
    @pytest.mark.asyncio
    async def test_kick_member_not_leader(self):
        """Test kicking fails when not leader."""
        manager = PartyManager()
        manager.my_char_id = 2
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[]
        )
        manager.party = party
        
        result = await manager.kick_member("SomeMember")
        assert result is False
    
    @pytest.mark.asyncio
    async def test_kick_member_not_found(self):
        """Test kicking non-existent member."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[]
        )
        manager.party = party
        
        result = await manager.kick_member("NonExistent")
        assert result is False
    
    def test_add_to_friend_list(self):
        """Test adding player to friend list."""
        manager = PartyManager()
        
        manager.add_to_friend_list("FriendPlayer")
        
        assert "FriendPlayer" in manager.friend_list
    
    def test_set_role_not_in_party(self):
        """Test setting role when not in party."""
        manager = PartyManager()
        
        # Should not raise error
        manager.set_role(PartyRole.HEALER)
    
    def test_set_role_char_id_not_set(self):
        """Test setting role when character ID not set."""
        manager = PartyManager()
        manager.party = Mock()
        
        manager.set_role(PartyRole.HEALER)
    
    def test_set_role_member_not_found(self):
        """Test setting role when member not in party."""
        manager = PartyManager()
        manager.my_char_id = 999
        
        party = Mock()
        party.get_member_by_id = Mock(return_value=None)
        manager.party = party
        
        manager.set_role(PartyRole.HEALER)
    
    def test_set_role_success(self):
        """Test setting role successfully."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member = PartyMember(
            char_id=1, name="Me", job_class="Priest", base_level=50
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        manager.set_role(PartyRole.HEALER)
        assert member.assigned_role == PartyRole.HEALER
    
    def test_set_role_string_conversion(self):
        """Test setting role with string input."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member = PartyMember(
            char_id=1, name="Me", job_class="Priest", base_level=50
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        manager.set_role("healer")
        assert member.assigned_role == PartyRole.HEALER


class TestPartyCoordinationModes:
    """Test different party coordination modes."""
    
    @pytest.mark.asyncio
    async def test_full_emergency_priority_flow(self):
        """Test emergency responses take priority over normal actions."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        # Low HP member
        member = PartyMember(
            char_id=2, name="LowHP", job_class="Knight",
            base_level=50, hp=20, hp_max=100, x=100, y=100, is_online=True
        )
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 50
        game_state.character.status_effects = []
        game_state.actors = []
        
        actions = await manager.tick(game_state)
        
        # Should only return emergency heal
        assert len(actions) > 0
        assert actions[0].skill_id == 28


class TestBuffAndDebuffTracking:
    """Test buff and debuff tracking system."""
    
    def test_add_buff_creates_entries(self):
        """Test adding buff creates tracking entries."""
        manager = PartyManager()
        
        manager.add_buff(1, 34, 120.0)
        
        assert 1 in manager.member_buffs
        assert 34 in manager.member_buffs[1]
        assert 1 in manager.buff_expiry
        assert 34 in manager.buff_expiry[1]
    
    def test_add_debuff_to_monster(self):
        """Test adding debuff to monster."""
        manager = PartyManager()
        
        manager.add_debuff(100, 71)
        
        assert 100 in manager.monster_debuffs
        assert 71 in manager.monster_debuffs[100]
    
    def test_clear_monster_debuffs(self):
        """Test clearing monster debuffs."""
        manager = PartyManager()
        manager.monster_debuffs[100] = {71, 79}
        
        manager.clear_monster_debuffs(100)
        
        assert 100 not in manager.monster_debuffs
    
    def test_clear_monster_debuffs_not_exists(self):
        """Test clearing debuffs for non-existent monster."""
        manager = PartyManager()
        
        # Should not raise error
        manager.clear_monster_debuffs(999)
    
    def test_has_debuff_monster_without_id(self):
        """Test has_debuff with monster without id attribute."""
        manager = PartyManager()
        
        monster = object()  # No id attribute
        
        result = manager._has_debuff(monster)
        assert result is False
    
    def test_has_debuff_monster_with_debuffs(self):
        """Test has_debuff returns True when debuffed."""
        manager = PartyManager()
        
        monster = Mock()
        monster.id = 100
        manager.monster_debuffs[100] = {71}
        
        result = manager._has_debuff(monster)
        assert result is True


class TestRoleExecution:
    """Test role-based duty execution."""
    
    def test_execute_role_duties_healer(self):
        """Test healer role execution."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member = PartyMember(
            char_id=1, name="Me", job_class="Priest", base_level=50
        )
        member.assigned_role = PartyRole.HEALER
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        game_state = Mock()
        actions = manager._execute_role_duties(game_state)
        
        assert isinstance(actions, list)
    
    def test_execute_role_duties_tank(self):
        """Test tank role execution."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member = PartyMember(
            char_id=1, name="Me", job_class="Knight", base_level=50
        )
        member.assigned_role = PartyRole.TANK
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"  # Add job class string
        game_state.character.sp = 50
        game_state.get_monsters = Mock(return_value=[])
        
        actions = manager._execute_role_duties(game_state)
        
        assert isinstance(actions, list)
    
    def test_execute_role_duties_support(self):
        """Test support role execution."""
        manager = PartyManager()
        manager.my_char_id = 1
        
        member = PartyMember(
            char_id=1, name="Me", job_class="Priest", base_level=50
        )
        member.assigned_role = PartyRole.SUPPORT
        
        party = Party(
            party_id=1,
            name="TestParty",
            leader_id=1,
            members=[member]
        )
        manager.party = party
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"  # Need job class string
        game_state.character.sp = 50
        game_state.get_monsters = Mock(return_value=[])
        
        actions = manager._execute_role_duties(game_state)
        
        assert isinstance(actions, list)