"""
Consumable Coordinator - P0 Critical Unified Manager.

Coordinates all consumable systems with intelligent prioritization,
emergency handling, and situational awareness for Ragnarok Online.
"""

from datetime import datetime
from enum import IntEnum
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.consumables.buffs import (
    BuffManager,
    BuffState,
    RebuffAction,
)
from ai_sidecar.consumables.food import FoodManager, FoodAction
from ai_sidecar.consumables.recovery import (
    RecoveryManager,
    RecoveryConfig,
    RecoveryDecision,
)
from ai_sidecar.consumables.status_effects import (
    StatusEffectManager,
    StatusEffectState,
    CureAction,
    StatusSeverity,
)

logger = structlog.get_logger(__name__)


class ActionPriority(IntEnum):
    """Priority levels for consumable actions."""
    
    EMERGENCY = 10      # About to die
    CRITICAL = 9        # Critical status (Stone, Freeze)
    URGENT = 8          # Urgent recovery or status
    HIGH = 7            # High priority buffs or cure
    NORMAL = 5          # Normal recovery/rebuff
    LOW = 3             # Convenience actions
    OPTIONAL = 1        # Nice to have


class ConsumableAction(BaseModel):
    """Unified consumable action."""
    
    action_type: str  # "recovery", "cure", "rebuff", "food", "immunity"
    priority: ActionPriority
    item_id: Optional[int] = None
    item_name: Optional[str] = None
    skill_name: Optional[str] = None
    target: str = "self"
    reason: str = ""


class GameState(BaseModel):
    """Simplified game state for consumable decisions."""
    
    character: Dict[str, Any] = Field(default_factory=dict)
    hp_percent: float = Field(ge=0.0, le=1.0)
    sp_percent: float = Field(ge=0.0, le=1.0)
    max_hp: int = Field(ge=1)
    max_sp: int = Field(ge=1)
    in_combat: bool = False
    situation: str = "normal"  # normal, mvp, woe, leveling
    map_name: str = ""
    nearby_monsters: List[str] = Field(default_factory=list)
    status_effects: List[str] = Field(default_factory=list)
    inventory: Dict[int, int] = Field(default_factory=dict)


class ConsumableCoordinator:
    """
    Unified consumable management.
    
    Coordinates all consumable systems:
    - Buff management
    - Status effect handling
    - Recovery items
    - Food buffs
    
    Priority: Emergency > Status Cure > Recovery > Buffs > Food
    """
    
    def __init__(
        self,
        data_dir: Optional[Path] = None,
        recovery_config: Optional[RecoveryConfig] = None,
    ):
        """
        Initialize consumable coordinator.
        
        Args:
            data_dir: Directory containing data JSON files
            recovery_config: Recovery configuration
        """
        self.log = structlog.get_logger(__name__)
        
        # Initialize subsystems
        self.buff_manager = BuffManager(
            data_path=data_dir / "buffs.json" if data_dir else None
        )
        self.status_manager = StatusEffectManager(
            data_path=data_dir / "status_effects.json" if data_dir else None
        )
        self.recovery_manager = RecoveryManager(
            config=recovery_config,
            data_path=data_dir / "recovery_items.json" if data_dir else None,
        )
        self.food_manager = FoodManager(
            data_path=data_dir / "food_items.json" if data_dir else None
        )
        
        # State tracking
        self.last_update: Optional[datetime] = None
        self.last_emergency: Optional[datetime] = None
        self.action_history: List[tuple[str, datetime]] = []
        
        self.log.info("ConsumableCoordinator initialized")
    
    async def update_all(
        self,
        game_state: GameState,
    ) -> List[ConsumableAction]:
        """
        Update all systems and get prioritized actions.
        
        Args:
            game_state: Current game state
            
        Returns:
            List of prioritized consumable actions
        """
        now = datetime.now()
        elapsed = 0.0
        
        if self.last_update:
            elapsed = (now - self.last_update).total_seconds()
        
        self.last_update = now
        
        # Update all timers
        await self.buff_manager.update_buff_timers(elapsed)
        await self.food_manager.update_food_timers(elapsed)
        
        # Update inventories
        self.recovery_manager.update_inventory(game_state.inventory)
        self.food_manager.update_inventory(game_state.inventory)
        
        # Detect status effects
        await self.status_manager.detect_status_effects(
            {"character": {"status_effects": game_state.status_effects}}
        )
        
        # Get all possible actions
        all_actions: List[ConsumableAction] = []
        
        # 1. Emergency recovery (P10)
        if game_state.hp_percent <= 0.20:
            emergency = await self._handle_emergency_recovery(game_state)
            if emergency:
                all_actions.append(emergency)
        
        # 2. Critical status effects (P9)
        critical_status = await self._handle_critical_status(game_state)
        all_actions.extend(critical_status)
        
        # 3. Urgent recovery (P8)
        if game_state.hp_percent <= 0.40:
            urgent_recovery = await self._handle_urgent_recovery(game_state)
            if urgent_recovery:
                all_actions.append(urgent_recovery)
        
        # 4. Status cure (P7)
        status_cures = await self._handle_status_cure(game_state)
        all_actions.extend(status_cures)
        
        # 5. Normal recovery (P5)
        normal_recovery = await self._handle_normal_recovery(game_state)
        if normal_recovery:
            all_actions.append(normal_recovery)
        
        # 6. Buff rebuffing (P3-7 depending on priority)
        rebuffs = await self._handle_rebuffing(game_state)
        all_actions.extend(rebuffs)
        
        # 7. Food maintenance (P3)
        food_actions = await self._handle_food_maintenance(game_state)
        all_actions.extend(food_actions)
        
        return await self.prioritize_actions(all_actions)
    
    async def _handle_emergency_recovery(
        self,
        game_state: GameState,
    ) -> Optional[ConsumableAction]:
        """Handle emergency HP recovery."""
        decision = await self.recovery_manager.emergency_recovery()
        
        if decision:
            self.last_emergency = datetime.now()
            
            return ConsumableAction(
                action_type="recovery",
                priority=ActionPriority.EMERGENCY,
                item_id=decision.item.item_id,
                item_name=decision.item.item_name,
                reason=decision.reason,
            )
        
        return None
    
    async def _handle_critical_status(
        self,
        game_state: GameState,
    ) -> List[ConsumableAction]:
        """Handle critical status effects (Stone, Freeze)."""
        actions: List[ConsumableAction] = []
        
        if not self.status_manager.active_effects:
            return actions
        
        # Get critical status effects
        critical = [
            effect for effect in self.status_manager.active_effects.values()
            if effect.severity == StatusSeverity.CRITICAL
        ]
        
        for effect in critical:
            cure = await self.status_manager.get_cure_action(effect)
            
            if cure:
                actions.append(
                    ConsumableAction(
                        action_type="cure",
                        priority=ActionPriority.CRITICAL,
                        item_name=cure.item_name,
                        skill_name=cure.skill_name,
                        reason=f"Critical status: {effect.effect_type.value}",
                    )
                )
        
        return actions
    
    async def _handle_urgent_recovery(
        self,
        game_state: GameState,
    ) -> Optional[ConsumableAction]:
        """Handle urgent HP recovery."""
        decision = await self.recovery_manager.evaluate_recovery_need(
            hp_percent=game_state.hp_percent,
            sp_percent=game_state.sp_percent,
            situation=game_state.situation,
            in_combat=game_state.in_combat,
        )
        
        if decision and game_state.hp_percent <= 0.40:
            return ConsumableAction(
                action_type="recovery",
                priority=ActionPriority.URGENT,
                item_id=decision.item.item_id,
                item_name=decision.item.item_name,
                reason=decision.reason,
            )
        
        return None
    
    async def _handle_status_cure(
        self,
        game_state: GameState,
    ) -> List[ConsumableAction]:
        """Handle non-critical status effect curing."""
        actions: List[ConsumableAction] = []
        
        if not self.status_manager.active_effects:
            return actions
        
        # Get non-critical effects
        effects = [
            e for e in self.status_manager.active_effects.values()
            if e.severity != StatusSeverity.CRITICAL
        ]
        
        # Prioritize them
        prioritized = await self.status_manager.prioritize_cures(effects)
        
        for effect in prioritized[:3]:  # Top 3 non-critical
            cure = await self.status_manager.get_cure_action(effect)
            
            if cure:
                priority = (
                    ActionPriority.HIGH if effect.severity >= StatusSeverity.HIGH
                    else ActionPriority.NORMAL
                )
                
                actions.append(
                    ConsumableAction(
                        action_type="cure",
                        priority=priority,
                        item_name=cure.item_name,
                        skill_name=cure.skill_name,
                        reason=f"Cure {effect.effect_type.value}",
                    )
                )
        
        return actions
    
    async def _handle_normal_recovery(
        self,
        game_state: GameState,
    ) -> Optional[ConsumableAction]:
        """Handle normal HP/SP recovery."""
        decision = await self.recovery_manager.evaluate_recovery_need(
            hp_percent=game_state.hp_percent,
            sp_percent=game_state.sp_percent,
            situation=game_state.situation,
            in_combat=game_state.in_combat,
        )
        
        if decision:
            return ConsumableAction(
                action_type="recovery",
                priority=ActionPriority.NORMAL,
                item_id=decision.item.item_id,
                item_name=decision.item.item_name,
                reason=decision.reason,
            )
        
        return None
    
    async def _handle_rebuffing(
        self,
        game_state: GameState,
    ) -> List[ConsumableAction]:
        """Handle buff rebuffing."""
        actions: List[ConsumableAction] = []
        
        buffs_to_rebuff = await self.buff_manager.check_rebuff_needs(
            available_sp=int(game_state.max_sp * game_state.sp_percent),
            in_combat=game_state.in_combat,
        )
        
        for buff in buffs_to_rebuff[:3]:  # Top 3 buffs
            rebuff = await self.buff_manager.get_rebuff_action(buff)
            
            if rebuff:
                # Map buff priority to action priority
                priority = ActionPriority(min(buff.priority, 7))
                
                actions.append(
                    ConsumableAction(
                        action_type="rebuff",
                        priority=priority,
                        item_name=rebuff.item_name,
                        skill_name=rebuff.skill_name,
                        reason=f"Rebuff {buff.buff_name}",
                    )
                )
        
        return actions
    
    async def _handle_food_maintenance(
        self,
        game_state: GameState,
    ) -> List[ConsumableAction]:
        """Handle food buff maintenance."""
        actions: List[ConsumableAction] = []
        
        food_needs = await self.food_manager.check_food_needs()
        
        for food_action in food_needs[:2]:  # Top 2 food
            actions.append(
                ConsumableAction(
                    action_type="food",
                    priority=ActionPriority.LOW,
                    item_id=food_action.item_id,
                    item_name=food_action.item_name,
                    reason=food_action.reason,
                )
            )
        
        return actions
    
    async def prioritize_actions(
        self,
        actions: List[ConsumableAction],
    ) -> List[ConsumableAction]:
        """
        Prioritize consumable actions.
        
        Priority order:
        1. Emergency recovery (dying)
        2. Critical status cure (Stone, Freeze)
        3. Urgent recovery (HP < 40%)
        4. Status cure (other debuffs)
        5. Normal recovery
        6. Buff rebuffing
        7. Food maintenance
        
        Args:
            actions: All possible actions
            
        Returns:
            Sorted list (highest priority first)
        """
        # Sort by priority (highest first)
        sorted_actions = sorted(
            actions,
            key=lambda a: a.priority,
            reverse=True,
        )
        
        # Limit to top 3 actions per tick
        return sorted_actions[:3]
    
    async def pre_combat_preparation(
        self,
        enemy_info: Dict[str, Any],
        character_build: str = "melee_dps",
    ) -> List[ConsumableAction]:
        """
        Prepare for combat.
        
        Actions:
        - Apply appropriate buffs
        - Ensure recovery items ready
        - Apply immunity for expected status effects
        
        Args:
            enemy_info: Information about upcoming enemy
            character_build: Character build type
            
        Returns:
            List of preparation actions
        """
        actions: List[ConsumableAction] = []
        
        # Check food buffs
        recommended_food = await self.food_manager.get_optimal_food_set(
            character_build
        )
        missing_food = self.food_manager.get_missing_food(recommended_food)
        
        for food in missing_food[:2]:  # Top 2
            actions.append(
                ConsumableAction(
                    action_type="food",
                    priority=ActionPriority.NORMAL,
                    item_id=food.item_id,
                    item_name=food.item_name,
                    reason="Pre-combat food buff",
                )
            )
        
        # Check immunity needs
        map_name = enemy_info.get("map", "")
        monsters = enemy_info.get("monsters", [])
        
        immunity_recs = await self.status_manager.should_apply_immunity(
            map_name,
            monsters,
        )
        
        for rec in immunity_recs[:1]:  # Top 1 immunity
            actions.append(
                ConsumableAction(
                    action_type="immunity",
                    priority=ActionPriority.HIGH,
                    item_name=rec.item_name,
                    reason=rec.reason,
                )
            )
        
        return actions
    
    async def post_combat_recovery(
        self,
        hp_percent: float,
        sp_percent: float,
    ) -> List[ConsumableAction]:
        """
        After combat recovery and maintenance.
        
        Actions:
        - Full recovery if needed
        - Rebuff if safe
        - Restock check
        
        Args:
            hp_percent: Current HP percentage
            sp_percent: Current SP percentage
            
        Returns:
            List of recovery actions
        """
        actions: List[ConsumableAction] = []
        
        # Full recovery if low
        if hp_percent < 0.80 or sp_percent < 0.40:
            decision = await self.recovery_manager.evaluate_recovery_need(
                hp_percent=hp_percent,
                sp_percent=sp_percent,
                situation="post_combat",
                in_combat=False,
            )
            
            if decision:
                actions.append(
                    ConsumableAction(
                        action_type="recovery",
                        priority=ActionPriority.NORMAL,
                        item_id=decision.item.item_id,
                        item_name=decision.item.item_name,
                        reason="Post-combat recovery",
                    )
                )
        
        # Rebuff critical/high priority buffs
        buffs_to_rebuff = await self.buff_manager.check_rebuff_needs(
            available_sp=int(1000 * sp_percent),  # Assume some SP
            in_combat=False,
        )
        
        for buff in buffs_to_rebuff[:3]:
            rebuff = await self.buff_manager.get_rebuff_action(buff)
            
            if rebuff:
                actions.append(
                    ConsumableAction(
                        action_type="rebuff",
                        priority=ActionPriority.NORMAL,
                        item_name=rebuff.item_name,
                        skill_name=rebuff.skill_name,
                        reason="Post-combat rebuff",
                    )
                )
        
        return actions
    
    def get_system_summary(self) -> Dict[str, Any]:
        """
        Get comprehensive summary of all consumable systems.
        
        Returns:
            Dict with status of all systems
        """
        return {
            "buffs": self.buff_manager.get_active_buffs_summary(),
            "status_effects": self.status_manager.get_status_summary(),
            "food": self.food_manager.get_food_summary(),
            "last_update": self.last_update.isoformat() if self.last_update else None,
            "last_emergency": (
                self.last_emergency.isoformat() if self.last_emergency else None
            ),
        }