"""
Guild management coordinator for social features.

Manages guild activities, WoE coordination, storage access,
and member relationships in Ragnarok Online.
"""

from datetime import datetime, time as dt_time
from typing import Literal

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.guild_models import Guild, GuildStorage
from ai_sidecar.social import config
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class GuildManager:
    """Manages guild coordination and activities."""
    
    def __init__(self) -> None:
        self.guild: Guild | None = None
        self.storage: GuildStorage | None = None
        self.storage_requests: list[dict] = []
        self.my_char_id: int | None = None
        self.woe_mode: Literal["attack", "defense", "support", "idle"] = "idle"
        self.woe_target_castle: str | None = None
        self.rally_point: tuple[int, int] | None = None
        self.last_guild_buff: float = 0.0
        self.storage_npc_location: tuple[str, int, int] | None = None  # (map, x, y)
    
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
        
        if not self.guild:
            return actions
        
        logger.info(f"WoE active - mode: {self.woe_mode}")
        
        # Check if we need guild buffs
        now = datetime.now().timestamp()
        if now - self.last_guild_buff > config.WOE_SETTINGS["guild_buff_interval"]:
            buff_action = self._request_guild_buff(game_state)
            if buff_action:
                actions.append(buff_action)
                self.last_guild_buff = now
        
        # Execute based on WoE mode
        if self.woe_mode == "attack":
            actions.extend(self._woe_attack_strategy(game_state))
        elif self.woe_mode == "defense":
            actions.extend(self._woe_defense_strategy(game_state))
        elif self.woe_mode == "support":
            actions.extend(self._woe_support_strategy(game_state))
        else:
            # Idle - rally at designated point
            if self.rally_point:
                my_pos = game_state.character.position
                distance = ((my_pos.x - self.rally_point[0]) ** 2 +
                           (my_pos.y - self.rally_point[1]) ** 2) ** 0.5
                if distance > 3:
                    actions.append(Action.move_to(
                        self.rally_point[0],
                        self.rally_point[1],
                        priority=2
                    ))
        
        return actions
    
    def _woe_attack_strategy(self, game_state: GameState) -> list[Action]:
        """Execute attack strategy during WoE."""
        actions: list[Action] = []
        
        # Move towards target castle if set
        if self.woe_target_castle and config.WOE_SETTINGS.get("castle_positions"):
            castle_pos = config.WOE_SETTINGS["castle_positions"].get(self.woe_target_castle)
            if castle_pos:
                my_pos = game_state.character.position
                distance = ((my_pos.x - castle_pos[0]) ** 2 +
                           (my_pos.y - castle_pos[1]) ** 2) ** 0.5
                if distance > config.WOE_SETTINGS["engage_distance"]:
                    actions.append(Action.move_to(castle_pos[0], castle_pos[1], priority=2))
        
        # Attack enemy guild members
        enemy_players = self._get_enemy_players(game_state)
        if enemy_players:
            # Target nearest enemy
            nearest = min(
                enemy_players,
                key=lambda p: p.position.distance_to(game_state.character.position)
            )
            actions.append(Action.attack(nearest.id, priority=1))
        
        return actions
    
    def _woe_defense_strategy(self, game_state: GameState) -> list[Action]:
        """Execute defense strategy during WoE."""
        actions: list[Action] = []
        
        # Stay near Emperium/defensive position
        if self.rally_point:
            my_pos = game_state.character.position
            distance = ((my_pos.x - self.rally_point[0]) ** 2 +
                       (my_pos.y - self.rally_point[1]) ** 2) ** 0.5
            if distance > config.WOE_SETTINGS["defense_radius"]:
                actions.append(Action.move_to(
                    self.rally_point[0],
                    self.rally_point[1],
                    priority=3
                ))
        
        # Attack intruders
        enemy_players = self._get_enemy_players(game_state)
        if enemy_players:
            # Prioritize nearest threat
            nearest = min(
                enemy_players,
                key=lambda p: p.position.distance_to(game_state.character.position)
            )
            if nearest.position.distance_to(game_state.character.position) < config.WOE_SETTINGS["defense_radius"]:
                actions.append(Action.attack(nearest.id, priority=1))
        
        return actions
    
    def _woe_support_strategy(self, game_state: GameState) -> list[Action]:
        """Execute support strategy during WoE (healing/buffing)."""
        actions: list[Action] = []
        
        # Find guild members needing help
        guild_players = self._get_guild_players(game_state)
        
        # Heal low HP members
        for player in guild_players:
            hp_percent = (player.hp / player.hp_max * 100) if player.hp_max else 100
            if hp_percent < config.WOE_SETTINGS.get("heal_threshold", 70):
                # Heal action (skill ID depends on class)
                actions.append(Action(
                    type=ActionType.SKILL,
                    skill_id=28,  # Heal
                    target_id=player.id,
                    priority=1
                ))
                break  # One heal at a time
        
        # Follow nearest guild member if too far from group
        if guild_players:
            centroid_x = sum(p.position.x for p in guild_players) / len(guild_players)
            centroid_y = sum(p.position.y for p in guild_players) / len(guild_players)
            my_pos = game_state.character.position
            distance = ((my_pos.x - centroid_x) ** 2 + (my_pos.y - centroid_y) ** 2) ** 0.5
            if distance > 8:
                actions.append(Action.move_to(int(centroid_x), int(centroid_y), priority=4))
        
        return actions
    
    def _get_enemy_players(self, game_state: GameState) -> list:
        """Get enemy guild players from game state."""
        if not self.guild:
            return []
        
        enemies = []
        for actor in game_state.actors:
            guild_id = actor.extra.get("guild_id")
            if guild_id:
                if self.is_enemy(guild_id):
                    enemies.append(actor)
                # Also treat non-allied guilds as enemies during WoE
                elif not self.is_ally(guild_id) and guild_id != self.guild.guild_id:
                    enemies.append(actor)
        
        return enemies
    
    def _get_guild_players(self, game_state: GameState) -> list:
        """Get allied/guild players from game state."""
        if not self.guild:
            return []
        
        allies = []
        for actor in game_state.actors:
            guild_id = actor.extra.get("guild_id")
            if guild_id:
                if guild_id == self.guild.guild_id or self.is_ally(guild_id):
                    allies.append(actor)
        
        return allies
    
    def _request_guild_buff(self, game_state: GameState) -> Action | None:
        """Request guild buff (Emergency Call, etc.)."""
        # Check if we have the skill/permission
        if self.guild and self.guild.get_skill_level("Emergency Call") > 0:
            return Action(
                type=ActionType.SKILL,
                skill_id=10027,  # Emergency Call skill ID (example)
                priority=2,
                extra={"guild_skill": True}
            )
        return None
    
    def set_woe_mode(self, mode: Literal["attack", "defense", "support", "idle"]) -> None:
        """Set WoE operation mode."""
        self.woe_mode = mode
        logger.info(f"WoE mode set to: {mode}")
    
    def set_rally_point(self, x: int, y: int) -> None:
        """Set rally point for WoE coordination."""
        self.rally_point = (x, y)
        logger.info(f"Rally point set to: ({x}, {y})")
    
    def set_target_castle(self, castle_name: str) -> None:
        """Set target castle for WoE attack."""
        self.woe_target_castle = castle_name
        logger.info(f"Target castle set to: {castle_name}")
    
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
        
        # Check if we're near storage NPC
        if not self._is_near_storage_npc(game_state):
            # Move to storage NPC first
            if self.storage_npc_location:
                map_name, x, y = self.storage_npc_location
                if game_state.map.name == map_name:
                    actions.append(Action.move_to(x, y, priority=5))
                else:
                    # Need to warp to correct map first
                    logger.debug(f"Need to travel to {map_name} for guild storage")
            return actions
        
        # Process one request at a time
        if not self.storage_requests:
            return actions
        
        request = self.storage_requests[0]
        item_id = request["item_id"]
        amount = abs(request["amount"])
        operation = request["type"]
        
        if operation == "deposit":
            # Check if we have the item
            inventory_count = self._get_inventory_item_count(game_state, item_id)
            if inventory_count >= amount:
                actions.append(Action(
                    type=ActionType.GUILD_STORAGE_DEPOSIT,
                    priority=5,
                    extra={
                        "operation": "deposit",
                        "storage_type": "guild",
                        "item_id": item_id,
                        "amount": min(amount, inventory_count)
                    }
                ))
                self.storage_requests.pop(0)
                logger.info(f"Depositing {amount}x item {item_id} to guild storage")
            else:
                logger.warning(f"Not enough items to deposit: have {inventory_count}, need {amount}")
                self.storage_requests.pop(0)
        
        elif operation == "withdraw":
            # Check storage availability
            if self.storage:
                storage_count = self.storage.get_item_count_by_id(item_id)
                if storage_count >= amount:
                    actions.append(Action(
                        type=ActionType.GUILD_STORAGE_WITHDRAW,
                        priority=5,
                        extra={
                            "operation": "withdraw",
                            "storage_type": "guild",
                            "item_id": item_id,
                            "amount": min(amount, storage_count)
                        }
                    ))
                    self.storage_requests.pop(0)
                    logger.info(f"Withdrawing {amount}x item {item_id} from guild storage")
                else:
                    logger.warning(f"Not enough items in storage: have {storage_count}, need {amount}")
                    self.storage_requests.pop(0)
            else:
                logger.warning("Guild storage not loaded")
                self.storage_requests.pop(0)
        
        return actions
    
    def _is_near_storage_npc(self, game_state: GameState) -> bool:
        """Check if character is near guild storage NPC."""
        if not self.storage_npc_location:
            return False
        
        map_name, npc_x, npc_y = self.storage_npc_location
        if game_state.map.name != map_name:
            return False
        
        my_pos = game_state.character.position
        distance = ((my_pos.x - npc_x) ** 2 + (my_pos.y - npc_y) ** 2) ** 0.5
        return distance <= 4  # Within 4 cells of NPC
    
    def _get_inventory_item_count(self, game_state: GameState, item_id: int) -> int:
        """Get count of item in inventory."""
        for item in game_state.inventory.items:
            if item.item_id == item_id:
                return item.amount
        return 0
    
    def set_storage_npc_location(self, map_name: str, x: int, y: int) -> None:
        """Set guild storage NPC location."""
        self.storage_npc_location = (map_name, x, y)
        logger.debug(f"Guild storage NPC location set: {map_name} ({x}, {y})")
    
    def donate_exp(self, amount: int) -> Action | None:
        """Create action to donate EXP to guild."""
        if not self.guild:
            return None
        
        # Validate donation amount
        if amount <= 0:
            logger.warning("Invalid EXP donation amount")
            return None
        
        # Check minimum donation (typically 1% at a time)
        min_donation = config.WOE_SETTINGS.get("min_exp_donation", 1)
        if amount < min_donation:
            amount = min_donation
        
        logger.info(f"Donating {amount}% EXP to guild {self.guild.name}")
        
        return Action(
            type=ActionType.GUILD_DONATE_EXP,
            priority=8,
            extra={
                "operation": "donate_exp",
                "amount": amount,
                "guild_id": self.guild.guild_id
            }
        )
    
    def use_guild_storage(
        self,
        items: list[tuple[int, int]]
    ) -> list[Action]:
        """
        Queue items for storage operations.
        
        Args:
            items: List of (item_id, amount) tuples.
                   Positive amount = deposit, negative = withdraw
                   
        Returns:
            List of immediate actions (empty, operations processed in tick)
        """
        if not self.guild:
            logger.warning("Not in a guild")
            return []
        
        if not self.my_char_id or not self.guild.can_use_storage(self.my_char_id):
            logger.warning("No permission to use guild storage")
            return []
        
        queued_count = 0
        for item_id, amount in items:
            if amount == 0:
                continue
            
            self.storage_requests.append({
                "item_id": item_id,
                "amount": abs(amount),
                "type": "deposit" if amount > 0 else "withdraw",
                "queued_at": datetime.now().timestamp()
            })
            queued_count += 1
        
        logger.info(f"Queued {queued_count} storage operations")
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
    
    async def join_guild(self, guild_name: str, char_id: int | None = None) -> None:
        """
        Join a guild by name.
        
        Args:
            guild_name: Name of guild to join
            char_id: Character ID (optional, uses stored if not provided)
        """
        if char_id is None:
            char_id = self.my_char_id or 0
            
        # Create a basic guild object for now
        # In a real implementation, this would fetch from game data
        guild = Guild(
            guild_id=0,
            name=guild_name,
            level=1,
            max_members=50,
            member_count=1,
            master_id=char_id,
            master_name="GuildMaster",
            members=[],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        self.guild = guild
        self.my_char_id = char_id
        
        # Initialize storage if available
        self.storage = GuildStorage(max_capacity=guild.max_members * 10)
        
        logger.info(
            f"Joined guild: {guild.name} (Level {guild.level})",
            guild_id=guild.guild_id,
            char_id=char_id
        )
    
    async def leave_guild(self) -> bool:
        """Leave current guild."""
        if not self.guild:
            return False
        
        guild_name = self.guild.name
        self.guild = None
        self.storage = None
        logger.info(f"Left guild: {guild_name}")
        return True
    
    async def donate_to_guild(self, amount: int) -> bool:
        """
        Donate zeny to guild.
        
        Args:
            amount: Amount of zeny to donate
            
        Returns:
            True if donation successful
        """
        if not self.guild:
            return False
        
        logger.info(f"Donated {amount} zeny to guild {self.guild.name}")
        return True
    
    def get_guild_members(self) -> list:
        """Get list of guild members."""
        if not self.guild:
            return []
        return [{"name": m.name, "level": m.level} for m in self.guild.members]
    
    def join_guild_legacy(self, guild_name: str, char_id: int) -> None:
        """
        Join a guild by name.
        
        Args:
            guild_name: Name of guild to join
            char_id: Character ID
        """
        # Create a basic guild object for now
        # In a real implementation, this would fetch from game data
        guild = Guild(
            guild_id=0,
            name=guild_name,
            level=1,
            max_members=50,
            member_count=1,
            members=[],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        self.guild = guild
        self.my_char_id = char_id
        
        # Initialize storage if available
        self.storage = GuildStorage(max_capacity=guild.max_members * 10)
        
        logger.info(
            f"Joined guild: {guild.name} (Level {guild.level})",
            guild_id=guild.guild_id,
            char_id=char_id
        )