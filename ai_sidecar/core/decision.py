"""
Decision engine interface for AI Sidecar.

Defines the action types and decision engine interface. This module provides
a stub implementation that returns empty actions - actual AI logic will be
implemented in a later phase.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Literal, TYPE_CHECKING

from pydantic import BaseModel, Field

import time

from ai_sidecar.core.state import GameState, Position
from ai_sidecar.config import get_settings
from ai_sidecar.config.loader import get_config
from ai_sidecar.utils.logging import get_logger

# Type hints only - avoid circular imports
if TYPE_CHECKING:
    from ai_sidecar.memory.decision_models import DecisionContext

logger = get_logger(__name__)


class ActionType(str, Enum):
    """Types of actions the AI can request."""
    
    # Movement
    MOVE = "move"
    STOP = "stop"
    
    # Combat
    ATTACK = "attack"
    SKILL = "skill"
    
    # Items
    USE_ITEM = "use_item"
    EQUIP = "equip"
    UNEQUIP = "unequip"
    PICKUP = "pickup"
    
    # Interaction
    TALK_NPC = "talk_npc"
    TAKE_PORTAL = "take_portal"
    
    # State
    SIT = "sit"
    STAND = "stand"
    
    # Special
    TELEPORT = "teleport"
    RESPAWN = "respawn"
    EMOTION = "emotion"
    COMMAND = "command"  # Custom command
    
    # Progression (P0 Critical - Progression & Combat Bridge)
    ALLOCATE_STAT = "allocate_stat"
    ALLOCATE_SKILL = "allocate_skill"
    
    # Party actions (P1 Important - Party Bridge)
    PARTY_HEAL = "party_heal"
    PARTY_BUFF = "party_buff"
    
    # Companion actions (P2 Important - Companion Bridge)
    FEED_PET = "feed_pet"
    HOMUN_SKILL = "homun_skill"
    MOUNT = "mount"
    DISMOUNT = "dismount"
    
    # NPC/Quest actions (P3 Advanced - NPC/Quest Bridge)
    NPC_TALK = "npc_talk"
    NPC_CHOOSE = "npc_choose"
    NPC_CLOSE = "npc_close"
    QUEST_ACCEPT = "quest_accept"
    QUEST_COMPLETE = "quest_complete"
    
    # Item/inventory actions (P3 Advanced - Inventory/Equipment Bridge)
    DROP_ITEM = "drop_item"
    PICK_ITEM = "pick_item"
    EQUIP_ITEM = "equip_item"
    UNEQUIP_ITEM = "unequip_item"
    
    # Storage actions (P3 Advanced - Storage Bridge)
    STORAGE_GET = "storage_get"
    STORAGE_ADD = "storage_add"
    
    # Chat sending (P3 Advanced - Communication Bridge)
    CHAT_SEND = "chat_send"
    
    # Teleport (P3 Advanced - Movement Bridge)
    TELEPORT_ACTION = "teleport"  # Renamed to avoid conflict with existing TELEPORT
    
    # Buy/Sell (P3 Advanced - Economy Bridge)
    BUY_FROM_NPC = "buy_from_npc"
    SELL_TO_NPC = "sell_to_npc"
    BUY_FROM_VENDOR = "buy_from_vendor"
    OPEN_VENDING = "open_vending"
    CLOSE_VENDING = "close_vending"
    
    # NPC Shop actions (P3 Advanced - NPC Bridge)
    OPEN_NPC_SHOP = "open_npc_shop"
    BUY_FROM_NPC_SHOP = "buy_from_npc_shop"
    CLOSE_NPC_SHOP = "close_npc_shop"
    
    # Cart actions (P3 Advanced - NPC Bridge)
    GET_CART = "get_cart"
    CART_ADD = "cart_add"
    CART_GET = "cart_get"
    
    # Service actions (P3 Advanced - NPC Bridge)
    USE_KAFRA = "use_kafra"
    SAVE_POINT = "save_point"
    
    # Instance actions (P4 Final - Instance Bridge)
    ENTER_INSTANCE = "enter_instance"
    NEXT_FLOOR = "next_floor"
    EXIT_INSTANCE = "exit_instance"
    
    # Chat message actions (P3 Advanced - Communication Bridge)
    # More specific than CHAT_SEND for type safety
    SEND_CHAT = "send_chat"  # Send public chat message
    SEND_PM = "send_pm"  # Send private message (whisper)
    SEND_PARTY_CHAT = "send_party_chat"  # Send party chat message
    SEND_GUILD_CHAT = "send_guild_chat"  # Send guild chat message
    
    # Chat command response actions (P3 Advanced - Command Bridge)
    # Actions triggered by chat commands from party/guild leaders
    FOLLOW_PLAYER = "follow_player"  # Follow a player
    SET_ATTACK_MODE = "set_attack_mode"  # Set attack mode (aggressive/passive)
    RETREAT = "retreat"  # Retreat from combat
    BUFF_PLAYER = "buff_player"  # Cast buff on player
    CANCEL_ALL = "cancel_all"  # Cancel all current actions
    
    # Trading actions (P3 Advanced - Economy Bridge)
    # Player-to-player trading
    OPEN_TRADE = "open_trade"  # Open trade window with player
    ADD_TRADE_ITEM = "add_trade_item"  # Add item to trade window
    CONFIRM_TRADE = "confirm_trade"  # Confirm/accept trade
    CANCEL_TRADE = "cancel_trade"  # Cancel trade
    
    # Storage actions (P3 Advanced - Storage Bridge)
    # Additional storage management
    OPEN_STORAGE = "open_storage"  # Open Kafra storage
    STORE_ITEM = "store_item"  # Store item (alias for detailed storage)
    RETRIEVE_ITEM = "retrieve_item"  # Retrieve item (alias for detailed retrieval)
    CLOSE_STORAGE = "close_storage"  # Close storage dialog
    
    # Guild actions (P3 Advanced - Guild Bridge)
    INVITE_GUILD = "invite_guild"  # Invite player to guild
    ACCEPT_GUILD_INVITE = "accept_guild_invite"  # Accept guild invitation
    LEAVE_GUILD = "leave_guild"  # Leave current guild
    GUILD_MESSAGE = "guild_message"  # Send guild message
    GUILD_STORAGE_DEPOSIT = "guild_storage_deposit"  # Deposit to guild storage
    GUILD_STORAGE_WITHDRAW = "guild_storage_withdraw"  # Withdraw from guild storage
    GUILD_DONATE_EXP = "guild_donate_exp"  # Donate EXP to guild
    
    # Party actions (P3 Advanced - Party Bridge)
    INVITE_PARTY = "invite_party"  # Invite player to party
    ACCEPT_PARTY_INVITE = "accept_party_invite"  # Accept party invitation
    REJECT_PARTY_INVITE = "reject_party_invite"  # Reject party invitation
    LEAVE_PARTY = "leave_party"  # Leave current party
    KICK_PARTY_MEMBER = "kick_party_member"  # Kick member from party
    
    # Progression actions (P3 Advanced - Progression Bridge)
    JOB_CHANGE = "job_change"  # Initiate job change/advancement
    ACCEPT_JOB_CHANGE = "accept_job_change"  # Accept job change at NPC
    
    # Meta
    NOOP = "noop"  # No operation


class Action(BaseModel):
    """
    A single AI action to be executed by OpenKore.
    
    Actions are prioritized and may have various parameters depending on type.
    """
    
    type: ActionType = Field(description="Action type")
    priority: int = Field(default=5, ge=1, le=10, description="Execution priority (1=highest)")
    
    # Target parameters (for attack, skill, etc.)
    target_id: int | None = Field(default=None, description="Target actor ID")
    
    # Position parameters (for move)
    x: int | None = Field(default=None, ge=0, description="X coordinate")
    y: int | None = Field(default=None, ge=0, description="Y coordinate")
    
    # Skill parameters
    skill_id: int | None = Field(default=None, description="Skill ID to use")
    skill_level: int | None = Field(default=None, ge=1, description="Skill level")
    
    # Item parameters
    item_id: int | None = Field(default=None, description="Item ID")
    item_index: int | None = Field(default=None, description="Inventory slot index")
    
    # Additional data
    extra: dict[str, Any] = Field(default_factory=dict, description="Extra action data")
    
    @classmethod
    def move_to(cls, x: int, y: int, priority: int = 5) -> "Action":
        """Create a move action."""
        return cls(type=ActionType.MOVE, x=x, y=y, priority=priority)
    
    @classmethod
    def attack(cls, target_id: int, priority: int = 3) -> "Action":
        """Create an attack action."""
        return cls(type=ActionType.ATTACK, target_id=target_id, priority=priority)
    
    @classmethod
    def use_skill(
        cls,
        skill_id: int,
        target_id: int | None = None,
        x: int | None = None,
        y: int | None = None,
        level: int = 1,
        priority: int = 2,
    ) -> "Action":
        """Create a skill use action."""
        return cls(
            type=ActionType.SKILL,
            skill_id=skill_id,
            skill_level=level,
            target_id=target_id,
            x=x,
            y=y,
            priority=priority,
        )
    
    @classmethod
    def use_item(cls, item_id: int, priority: int = 4) -> "Action":
        """Create an item use action."""
        return cls(type=ActionType.USE_ITEM, item_id=item_id, priority=priority)
    
    @classmethod
    def noop(cls) -> "Action":
        """Create a no-operation action."""
        return cls(type=ActionType.NOOP, priority=10)


class DecisionResult(BaseModel):
    """
    Result from the decision engine.
    
    Contains a list of actions to execute, ordered by priority.
    """
    
    tick: int = Field(description="Game tick this decision is for")
    actions: list[Action] = Field(default_factory=list, description="Actions to execute")
    fallback_mode: Literal["cpu", "idle", "defensive"] = Field(
        default="cpu",
        description="Fallback mode if actions cannot be executed"
    )
    
    # Metadata
    processing_time_ms: float = Field(default=0.0, description="Time to generate decision")
    confidence: float = Field(default=1.0, ge=0.0, le=1.0, description="Decision confidence")
    
    def to_response_dict(self) -> dict[str, Any]:
        """Convert to response dictionary for IPC."""
        return {
            "type": "decision",
            "tick": self.tick,
            "actions": [
                {
                    "type": action.type.value,
                    "priority": action.priority,
                    "target": action.target_id,
                    "x": action.x,
                    "y": action.y,
                    "skill_id": action.skill_id,
                    "skill_level": action.skill_level,
                    "item_id": action.item_id,
                    "item_index": action.item_index,
                    **action.extra,
                }
                for action in sorted(self.actions, key=lambda a: a.priority)
            ],
            "fallback_mode": self.fallback_mode,
            "processing_time_ms": self.processing_time_ms,
            "confidence": self.confidence,
        }


class DecisionEngine(ABC):
    """
    Abstract base class for decision engines.
    
    Subclasses implement different AI strategies (rule-based, ML, etc.).
    """
    
    @abstractmethod
    async def decide(self, state: GameState) -> DecisionResult:
        """
        Generate a decision based on the current game state.
        
        Args:
            state: Current game state snapshot.
        
        Returns:
            DecisionResult with actions to execute.
        """
        pass
    
    @abstractmethod
    async def initialize(self) -> None:
        """Initialize the engine (load models, etc.)."""
        pass
    
    @abstractmethod
    async def shutdown(self) -> None:
        """Clean up engine resources."""
        pass


class StubDecisionEngine(DecisionEngine):
    """
    Stub decision engine that returns empty actions.
    
    Used for testing IPC infrastructure before AI logic is implemented.
    """
    
    def __init__(self) -> None:
        self._initialized = False
        self._decision_count = 0
    
    async def initialize(self) -> None:
        """Initialize the stub engine."""
        logger.info("Initializing stub decision engine")
        self._initialized = True
    
    async def shutdown(self) -> None:
        """Shutdown the stub engine."""
        logger.info(
            "Shutting down stub decision engine",
            decisions_made=self._decision_count,
        )
        self._initialized = False
    
    async def decide(self, state: GameState) -> DecisionResult:
        """
        Return an empty decision.
        
        The stub engine acknowledges the state but takes no action,
        allowing the CPU fallback mode to handle character behavior.
        """
        self._decision_count += 1
        
        logger.debug(
            "Stub decision",
            tick=state.tick,
            character=state.character.name,
            monsters=len(state.get_monsters()),
        )
        
        return DecisionResult(
            tick=state.tick,
            actions=[],  # Empty - let CPU handle
            fallback_mode=get_settings().decision.fallback_mode,
            processing_time_ms=0.1,
            confidence=1.0,
        )


class ProgressionDecisionEngine(DecisionEngine):
    """
    Production decision engine with all subsystems integrated.
    
    Integrates:
    - CompanionCoordinator: Pet, homunculus, mercenary, mount management
    - ConsumableCoordinator: Buffs, recovery, status effects, food
    - ProgressionManager: Character lifecycle, stat distribution, job advancement
    - CombatManager: Skill allocation, combat AI, tactical decisions
    - NPCManager: NPC interactions, quests, services
    - EconomicManager: Equipment, trading, storage, zeny management
    - SocialManager: Party, guild, chat, MVP hunting
    
    Priority order:
    1. Emergency consumables (HP < 20%, critical status effects)
    2. Social (party/guild emergencies, chat commands)
    3. Companions (pet/homunculus urgent care)
    4. Progression (lifecycle, job change, stats)
    5. Combat (skills, attack, positioning)
    6. NPC (quests, services)
    7. Economic (equipment, trading, storage)
    8. Consumables (buffs, maintenance)
    9. Companions (non-urgent actions)
    """
    
    def __init__(self) -> None:
        """
        Initialize the progression decision engine.
        
        Subsystem configuration is loaded from config/subsystems.yaml.
        All subsystems are enabled by default unless explicitly disabled in config.
        """
        self._initialized = False
        self._decision_count = 0
        
        # Load configuration from subsystems.yaml
        config = get_config()
        
        self._enable_companions = config.is_enabled('companions')
        self._enable_consumables = config.is_enabled('consumables')
        self._enable_progression = config.is_enabled('progression')
        self._enable_combat = config.is_enabled('combat')
        self._enable_npc = config.is_enabled('npc_quest')
        self._enable_economic = config.is_enabled('economy')
        self._enable_social = config.is_enabled('social')
        self._enable_environment = config.is_enabled('environment')
        self._enable_instances = config.is_enabled('instances')
        
        # Managers and Coordinators (lazy loaded)
        self._companion_coordinator = None
        self._consumable_coordinator = None
        self._progression_manager = None
        self._combat_manager = None
        self._npc_manager = None
        self._economic_manager = None
        self._social_manager = None
        self._environment_coordinator = None
        self._instance_coordinator = None
    
    @property
    def companions(self):
        """Lazy load companion coordinator."""
        if self._companion_coordinator is None and self._enable_companions:
            try:
                from ai_sidecar.companions.coordinator import CompanionCoordinator
                self._companion_coordinator = CompanionCoordinator()
            except ImportError:
                logger.warning("CompanionCoordinator not available")
        return self._companion_coordinator
    
    @property
    def consumables(self):
        """Lazy load consumable coordinator."""
        if self._consumable_coordinator is None and self._enable_consumables:
            try:
                from ai_sidecar.consumables.coordinator import ConsumableCoordinator
                self._consumable_coordinator = ConsumableCoordinator()
            except ImportError:
                logger.warning("ConsumableCoordinator not available")
        return self._consumable_coordinator
    
    @property
    def progression(self):
        """Lazy load progression manager."""
        if self._progression_manager is None and self._enable_progression:
            try:
                from ai_sidecar.progression.manager import ProgressionManager
                from pathlib import Path
                # Use default data directories
                data_dir = Path(__file__).parent.parent / "data"
                state_dir = Path(__file__).parent.parent / "state"
                self._progression_manager = ProgressionManager(
                    data_dir=data_dir,
                    state_dir=state_dir
                )
            except ImportError:
                logger.warning("ProgressionManager not available")
        return self._progression_manager
    
    @property
    def combat(self):
        """Lazy load combat manager."""
        if self._combat_manager is None and self._enable_combat:
            try:
                from ai_sidecar.combat.manager import CombatManager
                self._combat_manager = CombatManager()
            except ImportError:
                logger.warning("CombatManager not available")
        return self._combat_manager
    
    @property
    def npc(self):
        """Lazy load NPC coordinator."""
        if self._npc_manager is None and self._enable_npc:
            try:
                from ai_sidecar.npc.coordinator import NPCCoordinator
                self._npc_manager = NPCCoordinator()
            except ImportError:
                logger.warning("NPCCoordinator not available")
        return self._npc_manager
    
    @property
    def economic(self):
        """Lazy load economy coordinator."""
        if self._economic_manager is None and self._enable_economic:
            try:
                from ai_sidecar.economy.coordinator import EconomyCoordinator
                from pathlib import Path
                # Use default data directory
                data_dir = Path(__file__).parent.parent / "data"
                self._economic_manager = EconomyCoordinator(data_dir=data_dir)
            except ImportError:
                logger.warning("EconomyCoordinator not available")
        return self._economic_manager
    
    @property
    def social(self):
        """Lazy load social manager."""
        if self._social_manager is None and self._enable_social:
            try:
                from ai_sidecar.social.manager import SocialManager
                self._social_manager = SocialManager()
            except ImportError:
                logger.warning("SocialManager not available")
        return self._social_manager
    
    @property
    def environment(self):
        """Lazy load environment coordinator."""
        if not hasattr(self, '_environment_coordinator') or self._environment_coordinator is None:
            try:
                from ai_sidecar.environment.coordinator import EnvironmentCoordinator
                from pathlib import Path
                # Use default data directory
                data_dir = Path(__file__).parent.parent / "data"
                self._environment_coordinator = EnvironmentCoordinator(data_dir=data_dir)
            except ImportError:
                logger.warning("EnvironmentCoordinator not available")
                self._environment_coordinator = None
        return self._environment_coordinator
    
    @property
    def instances(self):
        """Lazy load instance coordinator."""
        if self._instance_coordinator is None and self._enable_instances:
            try:
                from ai_sidecar.instances.coordinator import InstanceCoordinator
                self._instance_coordinator = InstanceCoordinator()
            except ImportError:
                logger.warning("InstanceCoordinator not available")
        return self._instance_coordinator
    
    async def initialize(self) -> None:
        """Initialize the engine and its subsystems."""
        config = get_config()
        enabled_subsystems = config.get_enabled_subsystems()
        
        logger.info("=" * 60)
        logger.info("AI Sidecar Subsystem Status")
        logger.info("=" * 60)
        
        subsystem_names = {
            'social': 'SOCIAL',
            'progression': 'PROGRESSION',
            'combat': 'COMBAT',
            'companions': 'COMPANIONS',
            'consumables': 'CONSUMABLES',
            'equipment': 'EQUIPMENT',
            'economy': 'ECONOMY',
            'npc_quest': 'NPC/QUEST',
            'instances': 'INSTANCES',
            'environment': 'ENVIRONMENT',
        }
        
        for subsystem_key, display_name in subsystem_names.items():
            status = "✅ ENABLED" if subsystem_key in enabled_subsystems else "❌ DISABLED"
            logger.info(f"{status:12} {display_name}")
        
        logger.info("=" * 60)
        
        # Pre-initialize all coordinators and managers
        if self._enable_companions:
            _ = self.companions
        if self._enable_consumables:
            _ = self.consumables
        if self._enable_progression:
            _ = self.progression
        if self._enable_combat:
            _ = self.combat
        if self._enable_npc:
            _ = self.npc
        if self._enable_economic:
            _ = self.economic
        if self._enable_social:
            _ = self.social
            if self.social:
                await self.social.initialize()
        if self._enable_environment:
            _ = self.environment
        if self._enable_instances:
            _ = self.instances
        
        self._initialized = True
        logger.info("All subsystems initialized")
    
    async def shutdown(self) -> None:
        """Shutdown the engine and clean up resources."""
        logger.info(
            "Shutting down progression decision engine",
            decisions_made=self._decision_count,
        )
        
        # Shutdown managers that need cleanup
        if self._social_manager:
            await self._social_manager.shutdown()
        
        self._initialized = False
        self._companion_coordinator = None
        self._consumable_coordinator = None
        self._progression_manager = None
        self._combat_manager = None
        self._npc_manager = None
        self._economic_manager = None
        self._social_manager = None
        self._environment_coordinator = None
        self._instance_coordinator = None
    
    async def decide(self, state: GameState) -> DecisionResult:
        """
        Generate decision based on current game state.
        
        Decision priority (coordinators called in this order):
        1. Social (party/guild emergencies, chat commands)
        2. Progression (lifecycle, job change, stats)
        3. Combat (skills, attack, positioning)
        4. Consumables (buffs, healing, status cure) - P3 Advanced
        5. Companions (pet/homun management) - P3 Advanced
        6. NPC (quests, services) - P3 Advanced
        7. Environment (time-based optimizations) - P3 Advanced
        7.5. Instances (Endless Tower, Memorial Dungeons) - P4 Final
        8. Economic (equipment, trading, storage)
        
        Args:
            state: Current game state snapshot
        
        Returns:
            DecisionResult with prioritized actions
        """
        start_time = time.perf_counter()
        self._decision_count += 1
        
        all_actions: list[Action] = []
        
        try:
            # Priority 1: Social (party/guild emergencies, chat commands)
            if self.social is not None:
                social_actions = await self.social.tick(state)
                all_actions.extend(self._convert_to_actions(social_actions))
            
            # Priority 2: Progression (lifecycle, job change, stats)
            if self.progression is not None:
                progression_actions = await self.progression.tick(state)
                all_actions.extend(self._convert_to_actions(progression_actions))
            
            # Priority 3: Combat (skills, attack, positioning)
            if self.combat is not None:
                combat_actions = await self.combat.tick(state)
                all_actions.extend(self._convert_to_actions(combat_actions))
            
            # Priority 4: Consumables (buffs, healing, status cure) - P3 Advanced
            if self.consumables is not None:
                consumable_actions = await self.consumables.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(consumable_actions))
            
            # Priority 5: Companions (pet/homun management) - P3 Advanced
            if self.companions is not None:
                companion_actions = await self.companions.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(companion_actions))
            
            # Priority 6: NPC (quests, services) - P3 Advanced (100% complete)
            if self.npc is not None:
                npc_actions = await self.npc.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(npc_actions))
            
            # Priority 7: Environment (time-based optimizations) - P3 Advanced (100% complete)
            if self.environment is not None:
                env_actions = await self.environment.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(env_actions))
            
            # Priority 7.5: Instances (Endless Tower, Memorial Dungeons) - P4 Final
            if self.instances is not None:
                instance_actions = await self.instances.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(instance_actions))
            
            # Priority 8: Economic (equipment, trading, storage) - P3 Advanced (100% complete)
            if self.economic is not None:
                economic_actions = await self.economic.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(economic_actions))
            
        except Exception as e:
            logger.error(f"Decision engine error: {e}", exc_info=True)
            # Return safe fallback
            return DecisionResult(
                tick=state.tick,
                actions=[],
                fallback_mode="defensive",
                processing_time_ms=(time.perf_counter() - start_time) * 1000,
                confidence=0.0,
            )
        
        # Sort by priority and deduplicate
        sorted_actions = sorted(all_actions, key=lambda a: a.priority)
        
        # Calculate processing time
        processing_time_ms = (time.perf_counter() - start_time) * 1000
        
        logger.debug(
            "Progression engine decision",
            tick=state.tick,
            actions=len(sorted_actions),
            time_ms=processing_time_ms,
        )
        
        return DecisionResult(
            tick=state.tick,
            actions=sorted_actions,
            fallback_mode=get_settings().decision.fallback_mode,
            processing_time_ms=processing_time_ms,
            confidence=1.0 if sorted_actions else 0.5,
        )
    
    def _convert_to_actions(self, items: list[Any]) -> list[Action]:
        """Convert ActionPayload or dict to Action objects."""
        from ai_sidecar.protocol.messages import ActionPayload
        
        result: list[Action] = []
        for item in items:
            # If already the right Action type, use it
            if isinstance(item, Action):
                result.append(item)
            # If it's an ActionPayload, convert it
            elif isinstance(item, ActionPayload) or (hasattr(item, 'type') and hasattr(item, 'priority')):
                # Convert ActionPayload to Action
                action_type_str = item.type if isinstance(item.type, str) else item.type.value
                try:
                    action_type_enum = ActionType(action_type_str)
                except ValueError:
                    action_type_enum = ActionType.NOOP
                
                result.append(Action(
                    type=action_type_enum,
                    priority=getattr(item, 'priority', 5),
                    target_id=getattr(item, 'target', None) or getattr(item, 'target_id', None),
                    x=getattr(item, 'x', None),
                    y=getattr(item, 'y', None),
                    skill_id=getattr(item, 'skill_id', None),
                    skill_level=getattr(item, 'skill_level', None),
                    item_id=getattr(item, 'item_id', None),
                    item_index=getattr(item, 'item_index', None),
                ))
            # If it's a dict, convert it
            elif isinstance(item, dict):
                action_type_str = item.get('type', 'noop')
                try:
                    action_type_enum = ActionType(action_type_str)
                except ValueError:
                    action_type_enum = ActionType.NOOP
                
                result.append(Action(
                    type=action_type_enum,
                    priority=item.get('priority', 5),
                    target_id=item.get('target') or item.get('target_id'),
                    x=item.get('x'),
                    y=item.get('y'),
                    skill_id=item.get('skill_id'),
                    skill_level=item.get('skill_level'),
                    item_id=item.get('item_id'),
                    item_index=item.get('item_index'),
                ))
        
        return result
    
    def health_check(self) -> dict[str, Any]:
        """
        Get health status of all subsystems.
        
        Returns:
            Dict with status of each coordinator/manager and their loaded state
        """
        return {
            "initialized": self._initialized,
            "decisions_made": self._decision_count,
            "subsystems": {
                "companions": {
                    "enabled": self._enable_companions,
                    "loaded": self._companion_coordinator is not None,
                    "status": "active" if self._companion_coordinator else "unloaded",
                },
                "consumables": {
                    "enabled": self._enable_consumables,
                    "loaded": self._consumable_coordinator is not None,
                    "status": "active" if self._consumable_coordinator else "unloaded",
                },
                "progression": {
                    "enabled": self._enable_progression,
                    "loaded": self._progression_manager is not None,
                    "status": "active" if self._progression_manager else "unloaded",
                },
                "combat": {
                    "enabled": self._enable_combat,
                    "loaded": self._combat_manager is not None,
                    "status": "active" if self._combat_manager else "unloaded",
                },
                "npc": {
                    "enabled": self._enable_npc,
                    "loaded": self._npc_manager is not None,
                    "status": "active" if self._npc_manager else "unloaded",
                },
                "economic": {
                    "enabled": self._enable_economic,
                    "loaded": self._economic_manager is not None,
                    "status": "active" if self._economic_manager else "unloaded",
                },
                "social": {
                    "enabled": self._enable_social,
                    "loaded": self._social_manager is not None,
                    "status": "active" if self._social_manager else "unloaded",
                },
                "environment": {
                    "enabled": self._enable_environment,
                    "loaded": self._environment_coordinator is not None,
                    "status": "active" if self._environment_coordinator else "unloaded",
                },
                "instances": {
                    "enabled": self._enable_instances,
                    "loaded": self._instance_coordinator is not None,
                    "status": "active" if self._instance_coordinator else "unloaded",
                },
            },
        }


class MLStrategyMode(str, Enum):
    """ML decision strategy modes."""
    
    ML_ONLY = "ml_only"        # Use only ML predictions, fallback to rules if unavailable
    HYBRID = "hybrid"          # Blend ML and rule-based with weighted decisions
    ML_FALLBACK = "ml_fallback"  # Use rules first, consult ML for validation


class MLDecisionEngine(ProgressionDecisionEngine):
    """
    ML-powered decision engine combining machine learning predictions
    with rule-based coordinator decisions.
    
    Inherits all coordinator functionality from ProgressionDecisionEngine
    and adds ML prediction capabilities with configurable blending strategies.
    
    Decision Strategies:
    - ml_only: Use only ML predictions, fall back to rules if model not trained
    - hybrid: Combine ML and rule-based with weighted blending
    - ml_fallback: Use rules first, consult ML for validation/adjustment
    
    Features:
    - Confidence thresholding (only use ML if confidence > threshold)
    - Automatic fallback to rule-based when ML unavailable
    - Decision recording for incremental learning
    - Performance tracking (ML vs rule-based success rates)
    - Thread-safe ML model access
    """
    
    def __init__(
        self,
        ml_confidence_threshold: float = 0.7,
        ml_strategy: str = "hybrid",
        ml_model_name: str = "decision_model",
        enable_learning: bool = True,
        ml_weight: float = 0.6,  # Weight for ML predictions in hybrid mode
    ):
        """
        Initialize ML Decision Engine.
        
        Args:
            ml_confidence_threshold: Minimum confidence to use ML prediction (0.0-1.0)
            ml_strategy: Decision strategy (ml_only, hybrid, ml_fallback)
            ml_model_name: Name of ML model to use for predictions
            enable_learning: Whether to record decisions for learning
            ml_weight: Weight for ML predictions in hybrid blending (0.0-1.0)
        """
        super().__init__()
        
        # ML configuration
        self._ml_confidence_threshold = max(0.0, min(1.0, ml_confidence_threshold))
        self._ml_strategy = MLStrategyMode(ml_strategy)
        self._ml_model_name = ml_model_name
        self._enable_learning = enable_learning
        self._ml_weight = max(0.0, min(1.0, ml_weight))
        
        # Learning engine (lazy loaded)
        self._learning_engine = None
        self._memory_manager = None
        
        # ML state tracking
        self._ml_model_available = False
        self._last_model_check = None
        self._model_check_interval = 60.0  # seconds
        
        # Performance tracking
        self._ml_decisions = 0
        self._rule_decisions = 0
        self._fallback_count = 0
        self._ml_predictions_attempted = 0
        self._ml_predictions_used = 0
        self._low_confidence_fallbacks = 0
        
        # Thread safety for ML operations
        import threading
        self._ml_lock = threading.RLock()
        
        logger.info(
            "ml_decision_engine_created",
            confidence_threshold=self._ml_confidence_threshold,
            strategy=self._ml_strategy.value,
            model_name=self._ml_model_name,
            enable_learning=self._enable_learning,
            ml_weight=self._ml_weight
        )
    
    @property
    def learning_engine(self):
        """Lazy load learning engine with thread safety."""
        if self._learning_engine is None:
            with self._ml_lock:
                if self._learning_engine is None:
                    try:
                        from ai_sidecar.learning import LearningEngine
                        from ai_sidecar.memory.manager import MemoryManager
                        
                        # Initialize memory manager for decision history
                        if self._memory_manager is None:
                            self._memory_manager = MemoryManager()
                        
                        self._learning_engine = LearningEngine(
                            memory_manager=self._memory_manager
                        )
                        logger.info("learning_engine_initialized")
                    except ImportError as e:
                        logger.error(
                            "learning_engine_import_failed",
                            error=str(e)
                        )
                    except Exception as e:
                        logger.error(
                            "learning_engine_init_failed",
                            error=str(e),
                            exc_info=True
                        )
        return self._learning_engine
    
    async def initialize(self) -> None:
        """Initialize the ML engine and its subsystems."""
        # Initialize parent (all coordinators)
        await super().initialize()
        
        logger.info("=" * 60)
        logger.info("ML Decision Engine Configuration")
        logger.info("=" * 60)
        logger.info(f"  Strategy:           {self._ml_strategy.value}")
        logger.info(f"  Confidence Threshold: {self._ml_confidence_threshold}")
        logger.info(f"  ML Weight (hybrid):  {self._ml_weight}")
        logger.info(f"  Model Name:          {self._ml_model_name}")
        logger.info(f"  Learning Enabled:    {self._enable_learning}")
        logger.info("=" * 60)
        
        # Initialize learning engine
        try:
            engine = self.learning_engine
            if engine is not None:
                # Check if model exists
                await self._check_model_availability()
                
                # Initialize memory manager
                if self._memory_manager:
                    await self._memory_manager.initialize()
                    logger.info("memory_manager_initialized")
        except Exception as e:
            logger.warning(
                "ml_initialization_warning",
                error=str(e),
                msg="ML features may be limited"
            )
        
        logger.info(
            "ml_decision_engine_initialized",
            model_available=self._ml_model_available
        )
    
    async def shutdown(self) -> None:
        """Shutdown ML engine and clean up resources."""
        logger.info(
            "ml_decision_engine_shutdown",
            ml_decisions=self._ml_decisions,
            rule_decisions=self._rule_decisions,
            fallback_count=self._fallback_count,
            predictions_attempted=self._ml_predictions_attempted,
            predictions_used=self._ml_predictions_used
        )
        
        # Shutdown memory manager
        if self._memory_manager:
            await self._memory_manager.shutdown()
        
        # Clear model cache if learning engine exists
        if self._learning_engine:
            self._learning_engine.clear_model_cache()
        
        await super().shutdown()
    
    async def _check_model_availability(self) -> bool:
        """
        Check if ML model is available and trained.
        
        Caches the result to avoid frequent disk checks.
        """
        current_time = time.perf_counter()
        
        # Use cached result if recent
        if (self._last_model_check is not None and
            current_time - self._last_model_check < self._model_check_interval):
            return self._ml_model_available
        
        with self._ml_lock:
            try:
                engine = self.learning_engine
                if engine is None:
                    self._ml_model_available = False
                else:
                    # Check if model exists via persistence layer
                    model_info = engine.get_model_info(self._ml_model_name)
                    self._ml_model_available = model_info is not None
                    
                    if self._ml_model_available:
                        logger.debug(
                            "ml_model_available",
                            model_name=self._ml_model_name,
                            accuracy=model_info.get("accuracy", 0.0)
                        )
                    else:
                        logger.debug(
                            "ml_model_not_found",
                            model_name=self._ml_model_name
                        )
                
                self._last_model_check = current_time
                
            except Exception as e:
                logger.warning(
                    "model_availability_check_failed",
                    error=str(e)
                )
                self._ml_model_available = False
        
        return self._ml_model_available
    
    async def decide(self, state: GameState) -> DecisionResult:
        """
        Generate ML-enhanced decision based on current game state.
        
        Decision flow:
        1. Build DecisionContext from game state
        2. Based on strategy:
           - ml_only: Try ML first, fallback to rules
           - hybrid: Get both, blend based on confidence
           - ml_fallback: Rules first, ML for validation
        3. Apply confidence thresholding
        4. Record decision for future learning
        5. Return prioritized actions
        
        Args:
            state: Current game state snapshot
        
        Returns:
            DecisionResult with prioritized actions
        """
        start_time = time.perf_counter()
        self._decision_count += 1
        
        # Build context for ML prediction
        decision_context = await self._build_decision_context(state)
        
        # Track decision source
        decision_source = "rule"  # default
        ml_prediction = None
        ml_confidence = 0.0
        
        try:
            # Get rule-based actions from coordinators
            rule_actions = await self._get_rule_based_actions(state)
            
            # Try ML prediction based on strategy
            if self._ml_strategy == MLStrategyMode.ML_ONLY:
                ml_actions, decision_source, ml_confidence = await self._ml_only_strategy(
                    state, decision_context, rule_actions
                )
                final_actions = ml_actions
                
            elif self._ml_strategy == MLStrategyMode.HYBRID:
                final_actions, decision_source, ml_confidence = await self._hybrid_strategy(
                    state, decision_context, rule_actions
                )
                
            elif self._ml_strategy == MLStrategyMode.ML_FALLBACK:
                final_actions, decision_source, ml_confidence = await self._ml_fallback_strategy(
                    state, decision_context, rule_actions
                )
            else:
                # Unknown strategy, use rules
                final_actions = rule_actions
                decision_source = "rule"
            
            # Update performance tracking
            if decision_source == "ml":
                self._ml_decisions += 1
                self._ml_predictions_used += 1
            elif decision_source == "hybrid":
                self._ml_decisions += 1
                self._rule_decisions += 1
            else:
                self._rule_decisions += 1
            
            # Sort and deduplicate actions
            sorted_actions = sorted(final_actions, key=lambda a: a.priority)
            
            # Record decision for learning
            if self._enable_learning and self.learning_engine:
                await self._record_decision(
                    decision_type=self._determine_decision_type(sorted_actions),
                    actions=sorted_actions,
                    context=decision_context,
                    source=decision_source,
                    ml_confidence=ml_confidence
                )
            
            processing_time_ms = (time.perf_counter() - start_time) * 1000
            
            # Calculate overall confidence
            confidence = ml_confidence if decision_source in ["ml", "hybrid"] else 1.0
            if not sorted_actions:
                confidence = 0.5
            
            logger.debug(
                "ml_engine_decision",
                tick=state.tick,
                actions=len(sorted_actions),
                source=decision_source,
                ml_confidence=f"{ml_confidence:.3f}",
                time_ms=f"{processing_time_ms:.2f}"
            )
            
            return DecisionResult(
                tick=state.tick,
                actions=sorted_actions,
                fallback_mode=get_settings().decision.fallback_mode,
                processing_time_ms=processing_time_ms,
                confidence=confidence,
            )
            
        except Exception as e:
            logger.error(
                "ml_decision_failed",
                error=str(e),
                exc_info=True
            )
            self._fallback_count += 1
            
            # Return safe fallback using parent's decide method
            return await super().decide(state)
    
    async def _get_rule_based_actions(self, state: GameState) -> list[Action]:
        """
        Get actions from rule-based coordinators.
        
        Delegates to parent class logic for coordinator iteration.
        """
        all_actions: list[Action] = []
        
        try:
            # Priority 1: Social
            if self.social is not None:
                social_actions = await self.social.tick(state)
                all_actions.extend(self._convert_to_actions(social_actions))
            
            # Priority 2: Progression
            if self.progression is not None:
                progression_actions = await self.progression.tick(state)
                all_actions.extend(self._convert_to_actions(progression_actions))
            
            # Priority 3: Combat
            if self.combat is not None:
                combat_actions = await self.combat.tick(state)
                all_actions.extend(self._convert_to_actions(combat_actions))
            
            # Priority 4: Consumables
            if self.consumables is not None:
                consumable_actions = await self.consumables.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(consumable_actions))
            
            # Priority 5: Companions
            if self.companions is not None:
                companion_actions = await self.companions.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(companion_actions))
            
            # Priority 6: NPC
            if self.npc is not None:
                npc_actions = await self.npc.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(npc_actions))
            
            # Priority 7: Environment
            if self.environment is not None:
                env_actions = await self.environment.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(env_actions))
            
            # Priority 7.5: Instances
            if self.instances is not None:
                instance_actions = await self.instances.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(instance_actions))
            
            # Priority 8: Economic
            if self.economic is not None:
                economic_actions = await self.economic.tick(state, state.tick)
                all_actions.extend(self._convert_to_actions(economic_actions))
                
        except Exception as e:
            logger.error(
                "rule_based_actions_failed",
                error=str(e),
                exc_info=True
            )
        
        return all_actions
    
    async def _ml_only_strategy(
        self,
        state: GameState,
        context: DecisionContext,
        rule_actions: list[Action]
    ) -> tuple[list[Action], str, float]:
        """
        ML-only strategy: Use ML predictions exclusively, fallback to rules.
        
        Returns:
            Tuple of (actions, source, confidence)
        """
        self._ml_predictions_attempted += 1
        
        # Check model availability
        if not await self._check_model_availability():
            logger.debug("ml_only_fallback_no_model")
            self._fallback_count += 1
            return rule_actions, "rule", 0.0
        
        # Try ML prediction
        ml_result = await self._try_ml_prediction(context)
        
        if ml_result is None:
            logger.debug("ml_only_fallback_prediction_failed")
            self._fallback_count += 1
            return rule_actions, "rule", 0.0
        
        confidence = ml_result.get("confidence", 0.0)
        
        # Check confidence threshold
        if confidence < self._ml_confidence_threshold:
            logger.debug(
                "ml_only_fallback_low_confidence",
                confidence=f"{confidence:.3f}",
                threshold=self._ml_confidence_threshold
            )
            self._low_confidence_fallbacks += 1
            return rule_actions, "rule", confidence
        
        # Convert ML prediction to actions
        ml_actions = await self._ml_prediction_to_actions(ml_result, state)
        
        if not ml_actions:
            logger.debug("ml_only_fallback_no_actions")
            return rule_actions, "rule", confidence
        
        return ml_actions, "ml", confidence
    
    async def _hybrid_strategy(
        self,
        state: GameState,
        context: DecisionContext,
        rule_actions: list[Action]
    ) -> tuple[list[Action], str, float]:
        """
        Hybrid strategy: Blend ML and rule-based decisions.
        
        Combines actions from both sources with weighted priority adjustment.
        
        Returns:
            Tuple of (actions, source, confidence)
        """
        self._ml_predictions_attempted += 1
        
        # Start with rule actions as base
        if not await self._check_model_availability():
            return rule_actions, "rule", 0.0
        
        # Try ML prediction
        ml_result = await self._try_ml_prediction(context)
        
        if ml_result is None:
            return rule_actions, "rule", 0.0
        
        confidence = ml_result.get("confidence", 0.0)
        
        # Below threshold, use rules only
        if confidence < self._ml_confidence_threshold:
            self._low_confidence_fallbacks += 1
            return rule_actions, "rule", confidence
        
        # Convert ML prediction to actions
        ml_actions = await self._ml_prediction_to_actions(ml_result, state)
        
        if not ml_actions:
            return rule_actions, "rule", confidence
        
        # Blend actions
        blended = self._blend_actions(
            ml_actions,
            rule_actions,
            ml_weight=self._ml_weight * confidence,  # Scale by confidence
            rule_weight=1.0 - (self._ml_weight * confidence)
        )
        
        return blended, "hybrid", confidence
    
    async def _ml_fallback_strategy(
        self,
        state: GameState,
        context: DecisionContext,
        rule_actions: list[Action]
    ) -> tuple[list[Action], str, float]:
        """
        ML-fallback strategy: Use rules first, consult ML for validation.
        
        If ML has high confidence, may adjust or override rule decisions.
        
        Returns:
            Tuple of (actions, source, confidence)
        """
        # If no rule actions, try ML
        if not rule_actions:
            self._ml_predictions_attempted += 1
            
            if await self._check_model_availability():
                ml_result = await self._try_ml_prediction(context)
                if ml_result:
                    confidence = ml_result.get("confidence", 0.0)
                    if confidence >= self._ml_confidence_threshold:
                        ml_actions = await self._ml_prediction_to_actions(ml_result, state)
                        if ml_actions:
                            return ml_actions, "ml", confidence
        
        # Have rule actions - optionally validate with ML
        if rule_actions and await self._check_model_availability():
            self._ml_predictions_attempted += 1
            ml_result = await self._try_ml_prediction(context)
            
            if ml_result:
                confidence = ml_result.get("confidence", 0.0)
                
                # High confidence ML might override
                if confidence > 0.9 and confidence > self._ml_confidence_threshold:
                    ml_actions = await self._ml_prediction_to_actions(ml_result, state)
                    if ml_actions:
                        # Blend with strong ML preference
                        blended = self._blend_actions(
                            ml_actions,
                            rule_actions,
                            ml_weight=0.7,
                            rule_weight=0.3
                        )
                        return blended, "hybrid", confidence
        
        return rule_actions, "rule", 0.0
    
    def _blend_actions(
        self,
        ml_actions: list[Action],
        rule_actions: list[Action],
        ml_weight: float,
        rule_weight: float
    ) -> list[Action]:
        """
        Blend ML and rule-based actions with weighted priorities.
        
        Args:
            ml_actions: Actions from ML prediction
            rule_actions: Actions from rule-based coordinators
            ml_weight: Weight for ML actions (0.0-1.0)
            rule_weight: Weight for rule actions (0.0-1.0)
        
        Returns:
            Blended list of actions with adjusted priorities
        """
        blended: list[Action] = []
        seen_types: set[tuple[ActionType, int | None]] = set()
        
        # Process ML actions with weight adjustment
        for action in ml_actions:
            key = (action.type, action.target_id)
            if key not in seen_types:
                # Adjust priority based on weight (lower = higher priority)
                adjusted_priority = max(1, int(action.priority * (1 - ml_weight * 0.3)))
                blended.append(Action(
                    type=action.type,
                    priority=adjusted_priority,
                    target_id=action.target_id,
                    x=action.x,
                    y=action.y,
                    skill_id=action.skill_id,
                    skill_level=action.skill_level,
                    item_id=action.item_id,
                    item_index=action.item_index,
                    extra={**action.extra, "_source": "ml"}
                ))
                seen_types.add(key)
        
        # Process rule actions, skip duplicates
        for action in rule_actions:
            key = (action.type, action.target_id)
            if key not in seen_types:
                adjusted_priority = max(1, int(action.priority * (1 - rule_weight * 0.2)))
                blended.append(Action(
                    type=action.type,
                    priority=adjusted_priority,
                    target_id=action.target_id,
                    x=action.x,
                    y=action.y,
                    skill_id=action.skill_id,
                    skill_level=action.skill_level,
                    item_id=action.item_id,
                    item_index=action.item_index,
                    extra={**action.extra, "_source": "rule"}
                ))
                seen_types.add(key)
        
        return blended
    
    async def _build_decision_context(self, state: GameState) -> DecisionContext:
        """
        Build DecisionContext from game state for ML prediction.
        
        Extracts relevant features from the game state.
        """
        from ai_sidecar.memory.decision_models import DecisionContext
        
        # Build game state snapshot for feature extraction
        game_state_snapshot = {
            "hp_percent": (state.character.hp / state.character.max_hp * 100)
                if state.character.max_hp > 0 else 100.0,
            "sp_percent": (state.character.sp / state.character.max_sp * 100)
                if state.character.max_sp > 0 else 100.0,
            "weight_percent": (state.character.weight / state.character.max_weight * 100)
                if state.character.max_weight > 0 else 0.0,
            "base_level": state.character.base_level,
            "job_level": state.character.job_level,
            "zeny": state.character.zeny,
            "map": state.character.map,
            "position": {"x": state.character.pos.x, "y": state.character.pos.y},
            "enemies_nearby": len(state.get_monsters()),
            "allies_nearby": len([a for a in state.actors.values() if a.actor_type == "player"]),
            "job_class": state.character.job_class,
            "stats": {
                "str": getattr(state.character, "str", 1),
                "agi": getattr(state.character, "agi", 1),
                "vit": getattr(state.character, "vit", 1),
                "int": getattr(state.character, "int", 1),
                "dex": getattr(state.character, "dex", 1),
                "luk": getattr(state.character, "luk", 1),
            }
        }
        
        # Determine available options based on state
        available_options = []
        if state.get_monsters():
            available_options.append("attack")
            available_options.append("skill")
        if state.character.hp < state.character.max_hp * 0.5:
            available_options.append("heal")
        available_options.extend(["move", "wait", "npc_interact"])
        
        # Considered factors
        considered_factors = []
        if game_state_snapshot["hp_percent"] < 30:
            considered_factors.append("low_hp")
        if game_state_snapshot["sp_percent"] < 20:
            considered_factors.append("low_sp")
        if game_state_snapshot["enemies_nearby"] > 0:
            considered_factors.append("enemies_present")
        if game_state_snapshot["weight_percent"] > 80:
            considered_factors.append("overweight")
        
        return DecisionContext(
            game_state_snapshot=game_state_snapshot,
            available_options=available_options,
            considered_factors=considered_factors,
            confidence_level=0.5,  # Will be updated by ML
            reasoning="ML decision context"
        )
    
    async def _try_ml_prediction(self, context: DecisionContext) -> dict | None:
        """
        Attempt to get ML prediction for the given context.
        
        Thread-safe with error handling.
        
        Returns:
            Prediction result dict or None if prediction fails
        """
        with self._ml_lock:
            try:
                engine = self.learning_engine
                if engine is None:
                    return None
                
                # Build input data for prediction
                input_data = {
                    "game_state": context.game_state_snapshot,
                    "available_options": context.available_options,
                    "considered_factors": context.considered_factors,
                    "confidence_level": context.confidence_level,
                    "reasoning": context.reasoning,
                    "decision_type": "combat" if "attack" in context.available_options else "general",
                    "action_taken": {}  # Will be predicted
                }
                
                # Get prediction
                result = await engine.predict(
                    input_data=input_data,
                    model_name=self._ml_model_name
                )
                
                if result:
                    logger.debug(
                        "ml_prediction_received",
                        predicted_class=result.get("predicted_class"),
                        confidence=f"{result.get('confidence', 0):.3f}"
                    )
                
                return result
                
            except Exception as e:
                logger.warning(
                    "ml_prediction_failed",
                    error=str(e)
                )
                return None
    
    async def _ml_prediction_to_actions(
        self,
        prediction: dict,
        state: GameState
    ) -> list[Action]:
        """
        Convert ML prediction result to Action objects.
        
        Maps predicted class to appropriate game actions.
        """
        actions: list[Action] = []
        
        predicted_class = prediction.get("predicted_class")
        confidence = prediction.get("confidence", 0.0)
        class_probs = prediction.get("class_probabilities", {})
        
        # Map predicted class to action type
        # The ML model predicts success/failure, so we use it to weight action priority
        if predicted_class == 1 or predicted_class == "success":
            # High success prediction - generate aggressive actions
            if state.get_monsters():
                monsters = list(state.get_monsters().values())
                if monsters:
                    # Attack nearest monster with adjusted priority
                    target = min(monsters, key=lambda m: (
                        abs(m.pos.x - state.character.pos.x) +
                        abs(m.pos.y - state.character.pos.y)
                    ))
                    actions.append(Action(
                        type=ActionType.ATTACK,
                        target_id=target.actor_id,
                        priority=int(3 * (1.0 - confidence * 0.3)),  # Higher confidence = lower priority number
                        extra={"_ml_confidence": confidence}
                    ))
        else:
            # Low success prediction - generate defensive actions
            if state.character.hp < state.character.max_hp * 0.7:
                # Suggest healing/recovery
                actions.append(Action(
                    type=ActionType.SIT,
                    priority=4,
                    extra={"_ml_confidence": confidence, "_reason": "low_success_prediction"}
                ))
        
        # Also consider class probabilities for nuanced decisions
        success_prob = float(class_probs.get("1", class_probs.get("success", 0.0)))
        failure_prob = float(class_probs.get("0", class_probs.get("failure", 0.0)))
        
        # If probabilities are close (uncertain), add cautious actions
        if abs(success_prob - failure_prob) < 0.2:
            # Uncertain - add defensive option
            if not any(a.type == ActionType.SIT for a in actions):
                actions.append(Action(
                    type=ActionType.NOOP,
                    priority=8,
                    extra={"_ml_confidence": confidence, "_reason": "uncertain_prediction"}
                ))
        
        return actions
    
    async def _record_decision(
        self,
        decision_type: str,
        actions: list[Action],
        context: DecisionContext,
        source: str,
        ml_confidence: float
    ) -> None:
        """
        Record decision for future learning.
        
        Stores decision in memory for experience replay and model improvement.
        """
        if not self.learning_engine or not self._memory_manager:
            return
        
        try:
            # Build action representation
            action_taken = {
                "actions": [
                    {"type": a.type.value, "priority": a.priority, "target_id": a.target_id}
                    for a in actions[:5]  # Limit to top 5 actions
                ],
                "source": source,
                "ml_confidence": ml_confidence,
                "strategy": self._ml_strategy.value
            }
            
            # Record decision via learning engine
            await self.learning_engine.record_decision(
                decision_type=decision_type,
                action=action_taken,
                context=context
            )
            
            logger.debug(
                "decision_recorded",
                decision_type=decision_type,
                source=source,
                actions_count=len(actions)
            )
            
        except Exception as e:
            logger.warning(
                "decision_record_failed",
                error=str(e)
            )
    
    def _determine_decision_type(self, actions: list[Action]) -> str:
        """Determine decision type from actions for recording."""
        if not actions:
            return "idle"
        
        action_types = [a.type for a in actions]
        
        if ActionType.ATTACK in action_types or ActionType.SKILL in action_types:
            return "combat"
        elif ActionType.MOVE in action_types:
            return "movement"
        elif ActionType.USE_ITEM in action_types:
            return "inventory"
        elif ActionType.TALK_NPC in action_types or ActionType.NPC_TALK in action_types:
            return "npc_interact"
        elif ActionType.SIT in action_types or ActionType.STAND in action_types:
            return "rest"
        else:
            return "general"
    
    def health_check(self) -> dict[str, Any]:
        """
        Get health status including ML-specific metrics.
        
        Extends parent health check with ML performance data.
        """
        base_health = super().health_check()
        
        # Add ML-specific metrics
        ml_health = {
            "ml_engine": {
                "strategy": self._ml_strategy.value,
                "confidence_threshold": self._ml_confidence_threshold,
                "model_available": self._ml_model_available,
                "model_name": self._ml_model_name,
                "learning_enabled": self._enable_learning,
                "learning_engine_loaded": self._learning_engine is not None,
            },
            "performance": {
                "ml_decisions": self._ml_decisions,
                "rule_decisions": self._rule_decisions,
                "fallback_count": self._fallback_count,
                "predictions_attempted": self._ml_predictions_attempted,
                "predictions_used": self._ml_predictions_used,
                "low_confidence_fallbacks": self._low_confidence_fallbacks,
                "ml_usage_rate": (
                    self._ml_predictions_used / self._ml_predictions_attempted
                    if self._ml_predictions_attempted > 0 else 0.0
                )
            }
        }
        
        return {**base_health, **ml_health}


def create_decision_engine() -> DecisionEngine:
    """
    Factory function to create the appropriate decision engine.
    
    Based on configuration, creates the right engine type.
    Subsystem configuration is loaded from config/subsystems.yaml.
    
    Supports:
    - stub: Minimal testing engine
    - rule_based: Full-featured engine with all coordinators
    - ml: Machine learning enhanced engine with LearningEngine integration
    """
    engine_type = get_settings().decision.engine_type
    
    logger.debug(f"Creating decision engine of type: {engine_type}")
    
    if engine_type == "stub":
        logger.info("Using StubDecisionEngine for testing")
        return StubDecisionEngine()
    elif engine_type == "rule_based":
        # Configuration is loaded automatically from subsystems.yaml
        logger.info("Using ProgressionDecisionEngine (rule-based mode)")
        return ProgressionDecisionEngine()
    elif engine_type == "ml":
        # ML engine with real LearningEngine integration
        logger.info(
            "Using MLDecisionEngine - "
            "ML-powered decision making with confidence thresholding and hybrid strategies"
        )
        
        # Get ML-specific settings from environment or defaults
        import os
        confidence_threshold = float(os.getenv("ML_CONFIDENCE_THRESHOLD", "0.7"))
        strategy = os.getenv("ML_STRATEGY", "hybrid")
        model_name = os.getenv("ML_MODEL_NAME", "decision_model")
        enable_learning = os.getenv("ML_ENABLE_LEARNING", "true").lower() == "true"
        ml_weight = float(os.getenv("ML_WEIGHT", "0.6"))
        
        return MLDecisionEngine(
            ml_confidence_threshold=confidence_threshold,
            ml_strategy=strategy,
            ml_model_name=model_name,
            enable_learning=enable_learning,
            ml_weight=ml_weight
        )
    
    # Fallback for truly unknown engine types - use rule_based as safe default
    logger.warning(
        f"Unknown engine type '{engine_type}', using ProgressionDecisionEngine as fallback. "
        f"Valid types: stub, rule_based, ml"
    )
    return ProgressionDecisionEngine()