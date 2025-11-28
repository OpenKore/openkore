"""
Social manager orchestrator.

Coordinates all social features: party, guild, chat, and MVP hunting.
Integrates with the decision engine to provide social AI capabilities.
"""

from ai_sidecar.core.decision import Action
from ai_sidecar.core.state import GameState
from ai_sidecar.social.chat_manager import ChatManager
from ai_sidecar.social.guild_manager import GuildManager
from ai_sidecar.social.mvp_manager import MVPManager
from ai_sidecar.social.party_manager import PartyManager
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class SocialManager:
    """Orchestrates all social features."""
    
    def __init__(self) -> None:
        self.party_manager = PartyManager()
        self.guild_manager = GuildManager()
        self.chat_manager = ChatManager()
        self.mvp_manager = MVPManager()
        self._initialized = False
    
    async def initialize(self) -> None:
        """Initialize social systems."""
        logger.info("Initializing SocialManager")
        self._initialized = True
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """
        Main social tick - coordinate all social features.
        
        Priority order:
        1. Chat processing (including commands)
        2. Party coordination
        3. Guild activities
        4. MVP hunting (if not in party emergency)
        """
        if not self._initialized:
            await self.initialize()
        
        actions: list[Action] = []
        
        try:
            # Priority 1: Chat processing (includes commands that might override other actions)
            chat_actions = await self.chat_manager.tick(game_state)
            actions.extend(chat_actions)
            
            # Priority 2: Party coordination
            party_actions = await self.party_manager.tick(game_state)
            actions.extend(party_actions)
            
            # Priority 3: Guild activities
            guild_actions = await self.guild_manager.tick(game_state)
            actions.extend(guild_actions)
            
            # Priority 4: MVP hunting (if not in party emergency)
            if not self._has_party_emergency(game_state):
                mvp_actions = await self.mvp_manager.tick(game_state)
                actions.extend(mvp_actions)
        
        except Exception as e:
            logger.error(f"Error in SocialManager tick: {e}", exc_info=True)
        
        return actions
    
    def _has_party_emergency(self, game_state: GameState) -> bool:
        """Check if party has emergency situation."""
        if not self.party_manager.party:
            return False
        
        # Check if any party member needs urgent healing
        for member in self.party_manager.party.members:
            if member.is_online and member.hp_percent < 30:
                return True
        
        return False
    
    def register_event_handlers(self, event_bus) -> None:
        """Register for social events (if event bus is available)."""
        # Register event handlers for social events
        # This would be called during initialization if an event bus is provided
        logger.info("Event handlers registered for social features")
    
    # Convenience methods for external access
    
    def set_bot_name(self, name: str) -> None:
        """Set the bot's character name for chat recognition."""
        self.chat_manager.set_bot_name(name)
        logger.info(f"Bot name set for social features: {name}")
    
    def load_mvp_database(self, data: dict) -> None:
        """Load MVP database."""
        self.mvp_manager.load_mvp_database(data)
    
    async def shutdown(self) -> None:
        """Shutdown social systems."""
        logger.info("Shutting down SocialManager")
        self._initialized = False