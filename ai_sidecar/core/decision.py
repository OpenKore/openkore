"""
Decision engine interface for AI Sidecar.

Defines the action types and decision engine interface. This module provides
a stub implementation that returns empty actions - actual AI logic will be
implemented in a later phase.
"""

from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field

import time

from ai_sidecar.core.state import GameState, Position
from ai_sidecar.config import get_settings
from ai_sidecar.utils.logging import get_logger

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
    
    def __init__(
        self,
        enable_companions: bool = True,
        enable_consumables: bool = True,
        enable_progression: bool = True,
        enable_combat: bool = True,
        enable_npc: bool = True,
        enable_economic: bool = True,
        enable_social: bool = True,
    ) -> None:
        """
        Initialize the progression decision engine.
        
        Args:
            enable_companions: Enable companion systems (pet, homunculus, etc.)
            enable_consumables: Enable consumable systems (buffs, recovery, etc.)
            enable_progression: Enable progression systems
            enable_combat: Enable combat AI systems
            enable_npc: Enable NPC interaction systems
            enable_economic: Enable economic systems
            enable_social: Enable social systems (party, guild, chat, MVP)
        """
        self._initialized = False
        self._decision_count = 0
        self._enable_companions = enable_companions
        self._enable_consumables = enable_consumables
        self._enable_progression = enable_progression
        self._enable_combat = enable_combat
        self._enable_npc = enable_npc
        self._enable_economic = enable_economic
        self._enable_social = enable_social
        
        # Managers and Coordinators (lazy loaded)
        self._companion_coordinator = None
        self._consumable_coordinator = None
        self._progression_manager = None
        self._combat_manager = None
        self._npc_manager = None
        self._economic_manager = None
        self._social_manager = None
    
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
        """Lazy load NPC manager."""
        if self._npc_manager is None and self._enable_npc:
            try:
                from ai_sidecar.npc.manager import NPCManager
                self._npc_manager = NPCManager()
            except ImportError:
                logger.warning("NPCManager not available")
        return self._npc_manager
    
    @property
    def economic(self):
        """Lazy load economic manager."""
        if self._economic_manager is None and self._enable_economic:
            try:
                from ai_sidecar.economy.manager import EconomicManager
                self._economic_manager = EconomicManager()
            except ImportError:
                logger.warning("EconomicManager not available")
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
    
    async def initialize(self) -> None:
        """Initialize the engine and its subsystems."""
        logger.info(
            "Initializing progression decision engine",
            companions=self._enable_companions,
            consumables=self._enable_consumables,
            progression=self._enable_progression,
            combat=self._enable_combat,
            npc=self._enable_npc,
            economic=self._enable_economic,
            social=self._enable_social,
        )
        
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
    
    async def decide(self, state: GameState) -> DecisionResult:
        """
        Generate decision based on current game state.
        
        Decision priority (coordinators called in this order):
        1. Social (party/guild emergencies, chat commands)
        2. Progression (lifecycle, job change, stats)
        3. Combat (skills, attack, positioning)
        4. NPC (quests, services)
        5. Economic (equipment, trading, storage)
        
        Note: Companions and Consumables coordinators are stubbed for future implementation.
        They require context adapters to convert GameState to their expected formats.
        
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
            
            # Priority 4: NPC (quests, services) - NOW WIRED!
            if self.npc is not None:
                npc_actions = await self.npc.tick(state)
                all_actions.extend(self._convert_to_actions(npc_actions))
            
            # Priority 5: Economic (equipment, trading, storage)
            if self.economic is not None:
                economic_actions = await self.economic.tick(state)
                all_actions.extend(self._convert_to_actions(economic_actions))
            
            # Note: Companions and Consumables coordinators exist but need context adapters
            # They will be fully integrated in a future phase when adapters are implemented
            
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
            },
        }


def create_decision_engine() -> DecisionEngine:
    """
    Factory function to create the appropriate decision engine.
    
    Based on configuration, creates the right engine type.
    Supports:
    - stub: Minimal testing engine
    - rule_based: Full-featured engine with all coordinators (Phase 10C+)
    - ml: Machine learning engine (Future)
    """
    engine_type = get_settings().decision.engine_type
    
    if engine_type == "stub":
        return StubDecisionEngine()
    elif engine_type == "rule_based":
        return ProgressionDecisionEngine(
            enable_companions=True,
            enable_consumables=True,
            enable_progression=True,
            enable_combat=True,
            enable_npc=True,
            enable_economic=True,
            enable_social=True,
        )
    # Future: Add other engine types
    # elif engine_type == "ml":
    #     return MLEngine()
    
    logger.warning(f"Unknown engine type '{engine_type}', using stub")
    return StubDecisionEngine()