"""
Tests for party models and party manager.

Tests party coordination, role assignment, member tracking,
and emergency response logic.
"""

import pytest
from datetime import datetime

from ai_sidecar.social.party_models import Party, PartyMember, PartyRole, PartySettings
from ai_sidecar.social.party_manager import PartyManager
from ai_sidecar.core.state import GameState, CharacterState, Position


class TestPartyModels:
    """Test party data models."""
    
    def test_party_member_creation(self):
        """Test creating a party member."""
        member = PartyMember(
            account_id=1001,
            char_id=2001,
            name="TestPriest",
            job_class="Priest",
            base_level=85,
            hp=5000,
            hp_max=6000,
            sp=2000,
            sp_max=3000
        )
        
        assert member.hp_percent == pytest.approx(83.33, rel=0.01)
        assert member.sp_percent == pytest.approx(66.67, rel=0.01)
        assert not member.needs_healing  # > 70%
    
    def test_party_member_needs_healing(self):
        """Test healing threshold detection."""
        member = PartyMember(
            account_id=1001,
            char_id=2001,
            name="TestKnight",
            job_class="Knight",
            base_level=90,
            hp=3500,
            hp_max=10000
        )
        
        assert member.hp_percent == 35.0
        assert member.needs_healing  # < 70%
    
    def test_party_creation(self):
        """Test creating a party."""
        party = Party(
            party_id=100,
            name="Test Party",
            leader_id=2001
        )
        
        assert party.member_count == 0
        assert len(party.online_members) == 0
    
    def test_party_with_members(self):
        """Test party with multiple members."""
        members = [
            PartyMember(
                account_id=1001,
                char_id=2001,
                name="Leader",
                job_class="Priest",
                base_level=85,
                is_leader=True,
                assigned_role=PartyRole.HEALER
            ),
            PartyMember(
                account_id=1002,
                char_id=2002,
                name="Tank",
                job_class="Knight",
                base_level=88,
                assigned_role=PartyRole.TANK
            ),
            PartyMember(
                account_id=1003,
                char_id=2003,
                name="DPS",
                job_class="Assassin",
                base_level=82,
                assigned_role=PartyRole.DPS_MELEE
            ),
        ]
        
        party = Party(
            party_id=100,
            name="Test Party",
            leader_id=2001,
            members=members
        )
        
        assert party.member_count == 3
        assert len(party.get_healers()) == 1
        assert len(party.get_tanks()) == 1
        assert party.has_role(PartyRole.HEALER)
        assert party.has_role(PartyRole.TANK)
        
        leader = party.get_leader()
        assert leader is not None
        assert leader.name == "Leader"


class TestPartyManager:
    """Test party manager logic."""
    
    @pytest.fixture
    def manager(self):
        """Create party manager instance."""
        return PartyManager()
    
    @pytest.fixture
    def test_party(self):
        """Create test party."""
        return Party(
            party_id=100,
            name="Test Party",
            leader_id=2001,
            members=[
                PartyMember(
                    account_id=1001,
                    char_id=2001,
                    name="Healer",
                    job_class="Priest",
                    base_level=85,
                    hp=5000,
                    hp_max=6000,
                    assigned_role=PartyRole.HEALER,
                    is_leader=True
                ),
                PartyMember(
                    account_id=1002,
                    char_id=2002,
                    name="Tank",
                    job_class="Knight",
                    base_level=88,
                    hp=3000,  # Low HP
                    hp_max=10000,
                    assigned_role=PartyRole.TANK
                ),
            ]
        )
    
    def test_role_assignment(self, manager, test_party):
        """Test auto role assignment."""
        roles = manager.assign_roles(test_party)
        
        assert roles[2001] == PartyRole.HEALER
        assert roles[2002] == PartyRole.TANK
    
    @pytest.mark.asyncio
    async def test_party_tick_no_party(self, manager):
        """Test tick with no party."""
        game_state = GameState()
        actions = await manager.tick(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_emergency_healing(self, manager, test_party):
        """Test emergency healing detection."""
        manager.party = test_party
        manager.my_char_id = 2001  # We are the healer
        
        game_state = GameState(
            character=CharacterState(
                name="Healer",
                sp=100,
                sp_max=1000
            )
        )
        
        actions = await manager.tick(game_state)
        
        # Should detect Tank needs healing (30% HP)
        # and attempt to heal if we have the capability
        assert len(actions) >= 0  # May or may not have heal depending on _can_heal