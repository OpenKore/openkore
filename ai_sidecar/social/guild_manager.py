"""
Guild management coordinator for social features.

Manages guild activities, WoE coordination, storage access,
and member relationships in Ragnarok Online.
"""

from datetime import datetime, time as dt_time

from ai_sidecar.core.decision import Action
from ai_sidecar.core.state import GameState
from ai_sidecar.social.guild_models import Guild, GuildStorage
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class GuildManager:
    """Manages guild coordination and activities."""
    
    def __init__(self) -> None:
        self.guild: Guild | None = None
        self.storage: GuildStorage | None = None
        self.storage_requests: list[dict] = []
        self.my_char_id: int | None = None
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """Main guild tick - process guild activities."""
        actions: list[Action] = []
        
        if not self.guild:
            return actions
        
        # Check for WoE timing
        if self._is_woe_time():
            actions.extend(self._woe_strategy(game_state))
            return actions
        
        # Process any pending storage requests
        if self.storage_requests:
            storage_actions = self._process_storage_requests(game_state)
            actions.extend(storage_actions)
        
        return actions
    
    def _is_woe_time(self) -> bool:
        """Check if WoE is currently active."""
        if not self.guild or not self.guild.woe_schedule:
            return False
        
        now = datetime.now()
        current_day = now.weekday()  # 0=Monday
        # Convert to RO format (0=Sunday)
        current_day = (current_day + 1) % 7
        current_hour = now.hour
        
        for schedule in self.guild.woe_schedule:
            if schedule.day_of_week == current_day:
                if schedule.start_hour <= current_hour < schedule.end_hour:
                    return True
        
        return False
    
    def _woe_strategy(self, game_state: GameState) -> list[Action]:
        """Execute WoE strategy (attack/defense)."""
        actions: list[Action] = []
        
        # Placeholder for WoE logic
        # Would involve:
        # - Moving to castle/guild hall
        # - Coordinating with guild members
        # - Attacking/defending objectives
        
        logger.info("WoE is active - executing guild strategy")
        return actions
    
    def _process_storage_requests(self, game_state: GameState) -> list[Action]:
        """Process pending storage access requests."""
        actions: list[Action] = []
        
        # Check if we can access storage
        if not self.my_char_id or not self.guild:
            return actions
        
        if not self.guild.can_use_storage(self.my_char_id):
            logger.warning("Character does not have guild storage permission")
            self.storage_requests.clear()
            return actions
        
        # Process requests (placeholder)
        # Would involve opening storage, depositing/withdrawing items
        self.storage_requests.clear()
        
        return actions
    
    def donate_exp(self, amount: int) -> Action | None:
        """Create action to donate EXP to guild."""
        if not self.guild:
            return None
        
        logger.info(f"Donating {amount} EXP to guild {self.guild.name}")
        # Return appropriate action (implementation depends on protocol)
        return None
    
    def use_guild_storage(
        self,
        items: list[tuple[int, int]]
    ) -> list[Action]:
        """
        Queue items for storage operations.
        
        Args:
            items: List of (item_id, amount) tuples.
                   Positive amount = deposit, negative = withdraw
        """
        if not self.storage:
            logger.warning("Guild storage not initialized")
            return []
        
        for item_id, amount in items:
            self.storage_requests.append({
                "item_id": item_id,
                "amount": amount,
                "type": "deposit" if amount > 0 else "withdraw"
            })
        
        return []
    
    def check_guild_skill(self, skill_name: str) -> int:
        """Check guild skill level."""
        if not self.guild:
            return 0
        
        return self.guild.get_skill_level(skill_name)
    
    def is_ally(self, guild_id: int) -> bool:
        """Check if a guild is an ally."""
        if not self.guild:
            return False
        return guild_id in self.guild.allied_guilds
    
    def is_enemy(self, guild_id: int) -> bool:
        """Check if a guild is an enemy."""
        if not self.guild:
            return False
        return guild_id in self.guild.enemy_guilds
    
    def get_online_members_count(self) -> int:
        """Get count of online guild members."""
        if not self.guild:
            return 0
        return len(self.guild.get_online_members())
    
    def set_guild(self, guild: Guild) -> None:
        """Set the current guild."""
        self.guild = guild
        logger.info(f"Guild set: {guild.name} (Level {guild.level})")
    
    def set_storage(self, storage: GuildStorage) -> None:
        """Set the guild storage."""
        self.storage = storage
        logger.info(f"Guild storage initialized: {storage.get_item_count()}/{storage.max_capacity} items")