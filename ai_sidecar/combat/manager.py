"""
Combat Manager - Orchestrates all combat systems.

Coordinates combat AI, skill allocation, and tactical decisions
into a unified combat tick system.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING

from pydantic import BaseModel, Field

from ai_sidecar.combat.combat_ai import CombatAI, CombatAIConfig, CombatState
from ai_sidecar.combat.models import CombatAction, CombatActionType, CombatContext
from ai_sidecar.combat.skills import SkillAllocationSystem, SkillDatabase
from ai_sidecar.combat.tactics import TacticalRole, get_default_role_for_job
from ai_sidecar.core.decision import Action, ActionType

if TYPE_CHECKING:
    from ai_sidecar.core.state import CharacterState, GameState


logger = logging.getLogger(__name__)


class CombatManagerConfig(BaseModel):
    """Configuration for CombatManager."""
    
    model_config = {"frozen": True}
    
    # Enable/disable features
    enable_skill_allocation: bool = Field(default=True)
    enable_combat_ai: bool = Field(default=True)
    enable_emergency_handling: bool = Field(default=True)
    
    # Priority thresholds
    emergency_hp_percent: float = Field(default=0.20, ge=0.0, le=1.0)
    low_hp_percent: float = Field(default=0.35, ge=0.0, le=1.0)
    low_sp_percent: float = Field(default=0.15, ge=0.0, le=1.0)
    
    # Skill allocation settings
    auto_allocate_skills: bool = Field(default=True)
    prioritize_build_skills: bool = Field(default=True)
    
    # Combat settings
    default_tactical_role: TacticalRole | None = Field(default=None)
    auto_detect_role: bool = Field(default=True)
    
    # Performance
    max_actions_per_tick: int = Field(default=5, ge=1)


@dataclass
class EmergencyItem:
    """An emergency item to use."""
    
    item_id: int
    item_name: str
    heal_amount: int
    is_percent: bool = False


class CombatManager:
    """
    Orchestrates combat AI, skill allocation, and tactical decisions.
    
    Main combat tick entry point called from decision engine.
    """
    
    # Common healing item IDs
    HEALING_ITEMS = {
        501: EmergencyItem(501, "Red Potion", 45),
        502: EmergencyItem(502, "Orange Potion", 105),
        503: EmergencyItem(503, "Yellow Potion", 175),
        504: EmergencyItem(504, "White Potion", 325),
        505: EmergencyItem(505, "Blue Potion", 60),  # SP
        547: EmergencyItem(547, "Condensed White Potion", 425),
        645: EmergencyItem(645, "Honey", 70),
        607: EmergencyItem(607, "Yggdrasil Berry", 100, is_percent=True),
        608: EmergencyItem(608, "Yggdrasil Seed", 50, is_percent=True),
    }
    
    def __init__(
        self,
        config: CombatManagerConfig | None = None,
        combat_ai_config: CombatAIConfig | None = None,
    ):
        """
        Initialize CombatManager.
        
        Args:
            config: Manager configuration
            combat_ai_config: Configuration for CombatAI
        """
        self.config = config or CombatManagerConfig()
        
        # Initialize subsystems
        self.skill_system = SkillAllocationSystem()
        self.combat_ai = CombatAI(config=combat_ai_config)
        self.skill_db = SkillDatabase()
        
        # State tracking
        self._last_tick: int = 0
        self._combat_context: CombatContext | None = None
        self._initialized = False
        
        logger.info("CombatManager initialized")
    
    def initialize(self, character: "CharacterState") -> None:
        """
        Initialize manager with character data.
        
        Args:
            character: Initial character state
        """
        # Detect tactical role if enabled
        if self.config.auto_detect_role:
            role = get_default_role_for_job(character.job)
            self.combat_ai.set_role(role)
            logger.info(f"Auto-detected role: {role.value} for job {character.job}")
        elif self.config.default_tactical_role:
            self.combat_ai.set_role(self.config.default_tactical_role)
        
        # Set build type for skill allocation
        build_type = self._detect_build_type(character)
        if build_type:
            self.skill_system.set_build_type(build_type)
            logger.info(f"Detected build type: {build_type}")
        
        self._initialized = True
    
    async def tick(self, game_state: "GameState") -> list[Action]:
        """
        Main combat tick - called from decision engine.
        
        Priority order:
        1. Emergency actions (flee, heal)
        2. Skill point allocation
        3. Combat actions
        
        Args:
            game_state: Current game state
        
        Returns:
            List of actions to execute
        """
        if not self._initialized:
            self.initialize(game_state.character)
        
        actions: list[Action] = []
        self._last_tick = game_state.tick
        
        # Priority 1: Emergency actions (flee, heal)
        if self.config.enable_emergency_handling:
            emergency = await self._check_emergencies(game_state)
            if emergency:
                logger.warning(f"Emergency action triggered: {emergency.type}")
                return [emergency]
        
        # Priority 2: Skill point allocation
        if self.config.enable_skill_allocation:
            skill_action = self._handle_skill_allocation(game_state.character)
            if skill_action:
                actions.append(skill_action)
                logger.info(f"Skill allocation: {skill_action}")
        
        # Priority 3: Combat actions
        if self.config.enable_combat_ai:
            context = await self.combat_ai.evaluate_combat_situation(game_state)
            self._combat_context = context
            
            if context.threat_level > 0 or context.nearby_monsters:
                combat_actions = await self.combat_ai.decide(context)
                
                # Convert CombatAction to Action
                for combat_action in combat_actions[:self.config.max_actions_per_tick]:
                    action = self._convert_combat_action(combat_action)
                    if action:
                        actions.append(action)
        
        return actions
    
    async def _check_emergencies(
        self,
        game_state: "GameState",
    ) -> Action | None:
        """
        Check for emergency conditions.
        
        Emergencies:
        - Critical HP (< 20%)
        - Dangerous debuffs
        - Overwhelming threats
        
        Args:
            game_state: Current game state
        
        Returns:
            Emergency action or None
        """
        character = game_state.character
        
        hp_percent = character.hp / max(character.hp_max, 1)
        sp_percent = character.sp / max(character.sp_max, 1)
        
        # Critical HP - use healing item or flee
        if hp_percent <= self.config.emergency_hp_percent:
            # Try to use healing item first
            heal_item = self._find_best_healing_item(game_state, character)
            if heal_item:
                logger.info(f"Emergency heal: using {heal_item.item_name}")
                return Action(
                    type=ActionType.USE_ITEM,
                    target_id=heal_item.item_id,
                    priority=10,
                )
            
            # No items - flee
            logger.warning("Emergency flee: critical HP, no healing items")
            return Action(
                type=ActionType.MOVE,  # Move away
                priority=10,
            )
        
        # Low HP - use healing item if available
        if hp_percent <= self.config.low_hp_percent:
            heal_item = self._find_best_healing_item(game_state, character)
            if heal_item:
                return Action(
                    type=ActionType.USE_ITEM,
                    target_id=heal_item.item_id,
                    priority=8,
                )
        
        # Low SP - use SP recovery item
        if sp_percent <= self.config.low_sp_percent:
            sp_item = self._find_sp_recovery_item(game_state)
            if sp_item:
                return Action(
                    type=ActionType.USE_ITEM,
                    target_id=sp_item.item_id,
                    priority=6,
                )
        
        return None
    
    def _handle_skill_allocation(
        self,
        character: "CharacterState",
    ) -> Action | None:
        """
        Handle skill point allocation.
        
        Args:
            character: Current character state
        
        Returns:
            Skill allocation action or None
        """
        if not self.config.auto_allocate_skills:
            return None
        
        if character.skill_points <= 0:
            return None
        
        # Use skill allocation system
        skill_action = self.skill_system.allocate_skill_point(character)
        return skill_action
    
    def _convert_combat_action(self, combat_action: CombatAction) -> Action | None:
        """
        Convert CombatAction to protocol Action.
        
        Args:
            combat_action: Combat action from AI
        
        Returns:
            Protocol Action or None
        """
        action_type_map = {
            CombatActionType.SKILL: ActionType.SKILL,
            CombatActionType.ATTACK: ActionType.ATTACK,
            CombatActionType.ITEM: ActionType.USE_ITEM,
            CombatActionType.MOVE: ActionType.MOVE,
            CombatActionType.FLEE: ActionType.MOVE,
        }
        
        action_type = action_type_map.get(combat_action.action_type)
        if action_type is None:
            return None
        
        return Action(
            type=action_type,
            skill_id=combat_action.skill_id,
            target_id=combat_action.target_id,
            priority=combat_action.priority,
        )
    
    def _find_best_healing_item(
        self,
        game_state: "GameState",
        character: "CharacterState",
    ) -> EmergencyItem | None:
        """
        Find the best healing item to use.
        
        Prioritizes percent-based heals when HP is very low,
        otherwise uses efficient fixed heals.
        
        Args:
            game_state: Current game state
            character: Character state
        
        Returns:
            Best healing item or None
        """
        hp_missing = character.hp_max - character.hp
        hp_percent = character.hp / max(character.hp_max, 1)
        
        # Get inventory items
        inventory = self._get_inventory(game_state)
        
        best_item: EmergencyItem | None = None
        best_score = -1.0
        
        for item_id, quantity in inventory.items():
            if quantity <= 0:
                continue
            
            item = self.HEALING_ITEMS.get(item_id)
            if item is None:
                continue
            
            # Skip SP items
            if item.item_id == 505:
                continue
            
            # Calculate effective healing
            if item.is_percent:
                heal = int(character.hp_max * (item.heal_amount / 100))
            else:
                heal = item.heal_amount
            
            # Score based on efficiency
            # Prefer items that heal close to missing HP
            efficiency = min(heal, hp_missing) / max(heal, 1)
            
            # Bonus for percent heals at very low HP
            if item.is_percent and hp_percent < 0.3:
                efficiency *= 1.5
            
            if efficiency > best_score:
                best_score = efficiency
                best_item = item
        
        return best_item
    
    def _find_sp_recovery_item(
        self,
        game_state: "GameState",
    ) -> EmergencyItem | None:
        """Find SP recovery item."""
        inventory = self._get_inventory(game_state)
        
        # Blue Potion
        if inventory.get(505, 0) > 0:
            return self.HEALING_ITEMS[505]
        
        return None
    
    def _get_inventory(self, game_state: "GameState") -> dict[int, int]:
        """
        Get inventory from game state.
        
        Args:
            game_state: Current game state
        
        Returns:
            Dict of item_id -> quantity
        """
        if hasattr(game_state, "inventory"):
            inv = game_state.inventory
            
            # Handle dict directly (most common in tests)
            if isinstance(inv, dict):
                return dict(inv)
            
            # Handle InventoryState object
            if hasattr(inv, "items") and not callable(inv.items):
                # items is an attribute (list), not the dict method
                inventory_dict = {}
                for item in inv.items:
                    item_id = item.item_id if hasattr(item, "item_id") else item.get("item_id", 0)
                    amount = item.amount if hasattr(item, "amount") else item.get("amount", 1)
                    inventory_dict[item_id] = inventory_dict.get(item_id, 0) + amount
                return inventory_dict
        
        if hasattr(game_state.character, "inventory"):
            char_inv = game_state.character.inventory
            if isinstance(char_inv, dict):
                return dict(char_inv)
        
        return {}
    
    def _detect_build_type(self, character: "CharacterState") -> str | None:
        """
        Detect build type from character stats.
        
        Args:
            character: Character state
        
        Returns:
            Build type string or None
        """
        job = character.job.lower()
        
        # Map job to potential build types
        job_builds = {
            "knight": ["knight_bash", "knight_bowling"],
            "lord_knight": ["knight_bash", "knight_bowling"],
            "crusader": ["crusader_shield", "crusader_grand_cross"],
            "paladin": ["crusader_shield", "crusader_grand_cross"],
            "assassin": ["assassin_sonic", "assassin_katar"],
            "assassin_cross": ["assassin_sonic", "assassin_katar"],
            "hunter": ["hunter_trapper", "hunter_ds"],
            "sniper": ["hunter_trapper", "hunter_ds"],
            "wizard": ["wizard_storm_gust", "wizard_safety"],
            "high_wizard": ["wizard_storm_gust", "wizard_safety"],
            "priest": ["priest_full_support", "priest_battle"],
            "high_priest": ["priest_full_support", "priest_battle"],
            "blacksmith": ["blacksmith_forger", "blacksmith_battle"],
            "whitesmith": ["blacksmith_forger", "blacksmith_battle"],
        }
        
        builds = job_builds.get(job)
        if builds:
            # Return first build as default
            # More sophisticated detection would analyze stat distribution
            return builds[0]
        
        return None
    
    # =========================================================================
    # Public API
    # =========================================================================
    
    def set_tactical_role(self, role: TacticalRole | str) -> None:
        """Set the tactical role for combat AI."""
        if isinstance(role, str):
            role = TacticalRole(role.lower())
        self.combat_ai.set_role(role)
        logger.info(f"Tactical role set to: {role.value}")
    
    def set_build_type(self, build_type: str) -> None:
        """Set the build type for skill allocation."""
        self.skill_system.set_build_type(build_type)
        logger.info(f"Build type set to: {build_type}")
    
    @property
    def combat_state(self) -> CombatState:
        """Get current combat state."""
        return self.combat_ai.current_state
    
    @property
    def combat_context(self) -> CombatContext | None:
        """Get last combat context."""
        return self._combat_context
    
    @property
    def metrics(self):
        """Get combat AI metrics."""
        return self.combat_ai.metrics