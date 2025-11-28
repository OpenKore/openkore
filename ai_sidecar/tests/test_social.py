"""
Integration tests for social manager.

Tests the complete social system integration including
party, guild, chat, and MVP coordination.
"""

import pytest

from ai_sidecar.social.manager import SocialManager
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole
from ai_sidecar.social.guild_models import Guild
from ai_sidecar.core.state import GameState, CharacterState


class TestSocialManager:
    """Test social manager integration."""
    
    @pytest.fixture
    def manager(self):
        """Create social manager instance."""
        return SocialManager()
    
    @pytest.mark.asyncio
    async def test_initialization(self, manager):
        """Test social manager initialization."""
        await manager.initialize()
        
        assert manager._initialized
        assert manager.party_manager is not None
        assert manager.guild_manager is not None
        assert manager.chat_manager is not None
        assert manager.mvp_manager is not None
    
    @pytest.mark.asyncio
    async def test_tick_empty_state(self, manager):
        """Test tick with empty game state."""
        await manager.initialize()
        game_state = GameState()
        
        actions = await manager.tick(game_state)
        
        # With no party/guild/mvp, should return minimal actions
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_with_party(self, manager):
        """Test tick with active party."""
        await manager.initialize()
        
        party = Party(
            party_id=100,
            name="Test Party",
            leader_id=2001,
            members=[
                PartyMember(
                    account_id=1001,
                    char_id=2001,
                    name="TestChar",
                    job_class="Priest",
                    base_level=85,
                    hp=5000,
                    hp_max=6000
                )
            ]
        )
        
        manager.party_manager.party = party
        
        game_state = GameState(
            character=CharacterState(name="TestChar")
        )
        
        actions = await manager.tick(game_state)
        
        assert isinstance(actions, list)
    
    def test_set_bot_name(self, manager):
        """Test setting bot name."""
        manager.set_bot_name("TestBot")
        
        assert manager.chat_manager.bot_name == "TestBot"
    
    def test_load_mvp_database(self, manager):
        """Test loading MVP database."""
        test_data = {
            "1038": {
                "name": "Osiris",
                "base_level": 78,
                "hp": 415600,
                "spawn_maps": ["moc_pryd04"],
                "spawn_time_min": 60,
                "spawn_time_max": 70
            }
        }
        
        manager.load_mvp_database(test_data)
        
        mvp = manager.mvp_manager.mvp_db.get(1038)
        assert mvp is not None
        assert mvp.name == "Osiris"
    
    @pytest.mark.asyncio
    async def test_shutdown(self, manager):
        """Test social manager shutdown."""
        await manager.initialize()
        await manager.shutdown()
        
        assert not manager._initialized