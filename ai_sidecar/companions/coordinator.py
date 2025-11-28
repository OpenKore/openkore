"""
Unified Companion Coordinator for AI Sidecar.

Coordinates all companion systems:
- Pet management
- Homunculus AI
- Mercenary control
- Mount system

Handles conflicts and priorities between companions.
Priority order typically:
1. Emergency actions (heal, escape)
2. Combat skills
3. Positioning
4. Feeding/maintenance
"""

from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

from ai_sidecar.companions.homunculus import (
    HomunculusManager,
    HomunculusState,
)
from ai_sidecar.companions.mercenary import (
    MercenaryManager,
    MercenaryState,
)
from ai_sidecar.companions.mount import MountManager, MountState
from ai_sidecar.companions.pet import PetManager, PetState

logger = structlog.get_logger(__name__)


class CompanionAction(BaseModel):
    """Generic companion action."""
    
    model_config = ConfigDict(frozen=True)
    
    companion_type: str = Field(description="Type: pet, homunculus, mercenary, mount")
    action_type: str = Field(description="Action type: feed, skill, move, etc.")
    priority: int = Field(default=5, ge=1, le=10, description="Priority 1-10")
    data: dict[str, Any] = Field(
        default_factory=dict,
        description="Action-specific data"
    )
    reason: str = Field(description="Action reasoning")


class GameState(BaseModel):
    """Simplified game state for coordinator."""
    
    model_config = ConfigDict(frozen=False)
    
    # Player state
    player_hp_percent: float = Field(default=1.0, ge=0.0, le=1.0)
    player_sp_percent: float = Field(default=1.0, ge=0.0, le=1.0)
    player_position: tuple[int, int] = Field(default=(0, 0))
    player_class: str = Field(default="")
    
    # Combat state
    in_combat: bool = Field(default=False)
    enemies_nearby: int = Field(default=0)
    is_boss_fight: bool = Field(default=False)
    
    # Companions
    pet_state: PetState | None = None
    homun_state: HomunculusState | None = None
    merc_state: MercenaryState | None = None
    mount_state: MountState | None = None
    
    # Travel
    distance_to_destination: int = Field(default=0, ge=0)
    skill_to_use: str | None = None


class CompanionCoordinator:
    """
    Unified companion management.
    
    Coordinates all companion systems and resolves conflicts
    between different companion needs.
    """
    
    def __init__(self):
        """Initialize all companion managers."""
        self.pet_manager = PetManager()
        self.homun_manager = HomunculusManager()
        self.merc_manager = MercenaryManager()
        self.mount_manager = MountManager()
        
        self._last_action_time: dict[str, float] = {}
        self._action_cooldowns: dict[str, float] = {
            "pet_feed": 5.0,
            "pet_skill": 5.0,
            "homun_skill": 3.0,
            "merc_skill": 3.0,
            "mount_toggle": 2.0,
        }
    
    async def update_all(self, game_state: GameState) -> list[CompanionAction]:
        """
        Update all companion systems and get pending actions.
        
        Args:
            game_state: Current game state
        
        Returns:
            List of companion actions, sorted by priority
        """
        actions: list[CompanionAction] = []
        
        # Update all managers with current state
        if game_state.pet_state:
            await self.pet_manager.update_state(game_state.pet_state)
        
        if game_state.homun_state:
            await self.homun_manager.update_state(game_state.homun_state)
        
        if game_state.merc_state:
            await self.merc_manager.update_state(game_state.merc_state)
        
        if game_state.mount_state:
            await self.mount_manager.update_state(game_state.mount_state)
            self.mount_manager.set_player_class(game_state.player_class)
        
        # Collect actions from each manager
        
        # 1. Pet actions
        if game_state.pet_state and game_state.pet_state.is_summoned:
            # Check feeding
            feed_decision = await self.pet_manager.decide_feed_timing()
            if feed_decision and feed_decision.should_feed:
                actions.append(CompanionAction(
                    companion_type="pet",
                    action_type="feed",
                    priority=self._get_feed_priority(feed_decision.reason),
                    data={"food": feed_decision.food_item},
                    reason=feed_decision.reason
                ))
            
            # Check skills
            pet_skill = await self.pet_manager.coordinate_pet_skills(
                combat_active=game_state.in_combat,
                player_hp_percent=game_state.player_hp_percent,
                enemies_nearby=game_state.enemies_nearby
            )
            if pet_skill:
                actions.append(CompanionAction(
                    companion_type="pet",
                    action_type="skill",
                    priority=7,
                    data={"skill": pet_skill.skill_name},
                    reason=pet_skill.reason
                ))
        
        # 2. Homunculus actions
        if game_state.homun_state:
            # Tactical skills (high priority for healing)
            homun_skill = await self.homun_manager.tactical_skill_usage(
                combat_active=game_state.in_combat,
                player_hp_percent=game_state.player_hp_percent,
                player_sp_percent=game_state.player_sp_percent,
                enemies_nearby=game_state.enemies_nearby,
                ally_count=1
            )
            if homun_skill:
                priority = 10 if "heal" in homun_skill.skill_name.lower() else 7
                actions.append(CompanionAction(
                    companion_type="homunculus",
                    action_type="skill",
                    priority=priority,
                    data={"skill": homun_skill.skill_name},
                    reason=homun_skill.reason
                ))
            
            # Stat allocation (low priority, maintenance)
            if game_state.homun_state.skill_points > 0:
                stat_allocation = await self.homun_manager.calculate_stat_distribution()
                if stat_allocation:
                    actions.append(CompanionAction(
                        companion_type="homunculus",
                        action_type="allocate_stat",
                        priority=2,
                        data={"stat": stat_allocation.stat_name},
                        reason=stat_allocation.reason
                    ))
        
        # 3. Mercenary actions
        if game_state.merc_state:
            # Contract management
            contract_action = await self.merc_manager.manage_contract()
            if contract_action:
                priority = 8 if contract_action.action == "renew" else 4
                actions.append(CompanionAction(
                    companion_type="mercenary",
                    action_type="contract",
                    priority=priority,
                    data={
                        "action": contract_action.action,
                        "merc_type": contract_action.merc_type
                    },
                    reason=contract_action.reason
                ))
            
            # Skill usage
            merc_skill = await self.merc_manager.coordinate_skills(
                combat_active=game_state.in_combat,
                player_hp_percent=game_state.player_hp_percent,
                enemies_nearby=game_state.enemies_nearby,
                is_boss_fight=game_state.is_boss_fight
            )
            if merc_skill:
                actions.append(CompanionAction(
                    companion_type="mercenary",
                    action_type="skill",
                    priority=6,
                    data={"skill": merc_skill.skill_name},
                    reason=merc_skill.reason
                ))
        
        # 4. Mount actions
        if game_state.mount_state:
            # Mount/dismount decision
            mount_decision = await self.mount_manager.should_mount(
                distance_to_destination=game_state.distance_to_destination,
                in_combat=game_state.in_combat,
                skill_to_use=game_state.skill_to_use
            )
            if mount_decision.should_mount != game_state.mount_state.is_mounted:
                actions.append(CompanionAction(
                    companion_type="mount",
                    action_type="toggle",
                    priority=5,
                    data={"mount": mount_decision.should_mount},
                    reason=mount_decision.reason
                ))
            
            # Mado Gear fuel
            refuel_action = await self.mount_manager.manage_mado_fuel()
            if refuel_action and refuel_action.should_refuel:
                actions.append(CompanionAction(
                    companion_type="mount",
                    action_type="refuel",
                    priority=6,
                    data={"fuel_needed": refuel_action.fuel_needed},
                    reason=refuel_action.reason
                ))
        
        # Sort by priority (highest first)
        actions.sort(key=lambda a: a.priority, reverse=True)
        
        return actions
    
    async def prioritize_actions(
        self,
        actions: list[CompanionAction]
    ) -> CompanionAction | None:
        """
        Select highest priority action that's not on cooldown.
        
        Priority order:
        1. Emergency healing (Homun Lif) - priority 10
        2. Combat skills - priority 7
        3. Contract renewal - priority 8
        4. Positioning/mounting - priority 5
        5. Feeding/maintenance - priority 1-4
        
        Args:
            actions: List of possible actions
        
        Returns:
            Highest priority action, or None
        """
        import time
        
        if not actions:
            return None
        
        now = time.time()
        
        # Find first action not on cooldown
        for action in actions:
            action_key = f"{action.companion_type}_{action.action_type}"
            cooldown = self._action_cooldowns.get(action_key, 1.0)
            last_time = self._last_action_time.get(action_key, 0.0)
            
            if now - last_time >= cooldown:
                # Update last action time
                self._last_action_time[action_key] = now
                
                logger.info(
                    "companion_action_selected",
                    companion=action.companion_type,
                    action=action.action_type,
                    priority=action.priority,
                    reason=action.reason
                )
                
                return action
        
        # All actions on cooldown
        return None
    
    def _get_feed_priority(self, reason: str) -> int:
        """Get priority for feeding action based on reason."""
        if "emergency" in reason:
            return 9  # Very high priority
        if "optimal" in reason:
            return 4  # Medium priority
        return 2  # Low priority
    
    async def get_status_summary(self) -> dict[str, Any]:
        """
        Get status summary of all companions.
        
        Returns:
            Dictionary with status of each companion type
        """
        summary: dict[str, Any] = {
            "pet": None,
            "homunculus": None,
            "mercenary": None,
            "mount": None,
        }
        
        if self.pet_manager.current_state:
            pet = self.pet_manager.current_state
            summary["pet"] = {
                "type": pet.pet_type,
                "summoned": pet.is_summoned,
                "intimacy": pet.intimacy,
                "hunger": pet.hunger,
            }
        
        if self.homun_manager.current_state:
            homun = self.homun_manager.current_state
            summary["homunculus"] = {
                "type": homun.type,
                "level": homun.level,
                "intimacy": homun.intimacy,
                "hp_percent": homun.hp / max(homun.max_hp, 1),
            }
        
        if self.merc_manager.current_state:
            merc = self.merc_manager.current_state
            summary["mercenary"] = {
                "type": merc.type,
                "level": merc.level,
                "contract_remaining": merc.contract_remaining,
                "faith": merc.faith,
            }
        
        if self.mount_manager.current_state:
            mount = self.mount_manager.current_state
            summary["mount"] = {
                "mounted": mount.is_mounted,
                "type": mount.mount_type,
                "has_cart": mount.has_cart,
            }
        
        return summary