"""
Mercenary Tactical Control for AI Sidecar.

Implements intelligent mercenary management including:
- Type selection based on situation
- Contract time tracking and auto-renewal
- Skill coordination with main character
- Faith point tracking and optimization
- Tactical positioning commands
- Guild rank progression

RO Mercenary Mechanics:
- Contract duration: 30-60 minutes depending on type
- Faith points: Earned through kills, affects stats
- Guild ranks: Unlock higher tier mercenaries
- Mercenary types: Swordsman, Archer, Lancer (levels 1-10)
"""

import time
from enum import Enum
from typing import Literal

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class MercenaryType(str, Enum):
    """Mercenary types by combat role and level."""
    
    # Swordsman types (tank/melee)
    SWORD_LV1 = "sword_1"
    SWORD_LV2 = "sword_2"
    SWORD_LV3 = "sword_3"
    SWORD_LV4 = "sword_4"
    SWORD_LV5 = "sword_5"
    SWORD_LV6 = "sword_6"
    SWORD_LV7 = "sword_7"
    SWORD_LV8 = "sword_8"
    SWORD_LV9 = "sword_9"
    SWORD_LV10 = "sword_10"
    
    # Archer types (ranged DPS)
    ARCHER_LV1 = "archer_1"
    ARCHER_LV2 = "archer_2"
    ARCHER_LV3 = "archer_3"
    ARCHER_LV4 = "archer_4"
    ARCHER_LV5 = "archer_5"
    ARCHER_LV6 = "archer_6"
    ARCHER_LV7 = "archer_7"
    ARCHER_LV8 = "archer_8"
    ARCHER_LV9 = "archer_9"
    ARCHER_LV10 = "archer_10"
    
    # Lancer types (high DPS)
    LANCER_LV1 = "lancer_1"
    LANCER_LV2 = "lancer_2"
    LANCER_LV3 = "lancer_3"
    LANCER_LV4 = "lancer_4"
    LANCER_LV5 = "lancer_5"
    LANCER_LV6 = "lancer_6"
    LANCER_LV7 = "lancer_7"
    LANCER_LV8 = "lancer_8"
    LANCER_LV9 = "lancer_9"
    LANCER_LV10 = "lancer_10"


class MercenaryState(BaseModel):
    """Current mercenary state and statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    merc_id: int = Field(description="Unique mercenary instance ID")
    type: MercenaryType = Field(description="Mercenary type")
    level: int = Field(default=1, ge=1, le=99, description="Mercenary level")
    
    # Contract info
    contract_remaining: int = Field(
        default=0,
        ge=0,
        description="Contract time remaining in seconds"
    )
    contract_max: int = Field(
        default=3600,
        ge=0,
        description="Maximum contract duration in seconds"
    )
    
    # Stats
    hp: int = Field(default=0, ge=0, description="Current HP")
    max_hp: int = Field(default=0, ge=0, description="Maximum HP")
    sp: int = Field(default=0, ge=0, description="Current SP")
    max_sp: int = Field(default=0, ge=0, description="Maximum SP")
    
    # Performance
    kills: int = Field(default=0, ge=0, description="Total kills")
    faith: int = Field(default=0, ge=0, le=100, description="Faith points (0-100)")
    
    # Skills
    skills: dict[str, int] = Field(
        default_factory=dict,
        description="Skill name -> level mapping"
    )


class MercenaryConfig(BaseModel):
    """Mercenary usage configuration."""
    
    model_config = ConfigDict(frozen=True)
    
    auto_renew: bool = Field(default=True, description="Auto-renew contracts")
    renew_threshold: int = Field(
        default=300,
        ge=0,
        description="Renew when less than this many seconds remain"
    )
    preferred_type: MercenaryType | None = Field(
        default=None,
        description="Preferred mercenary type"
    )
    faith_threshold: int = Field(
        default=50,
        ge=0, le=100,
        description="Minimum faith before considering switch"
    )
    positioning: Literal["front", "back", "flank"] = Field(
        default="front",
        description="Positioning strategy"
    )


class ContractAction(BaseModel):
    """Contract management action."""
    
    model_config = ConfigDict(frozen=True)
    
    action: Literal["renew", "hire", "dismiss"] = Field(description="Action to take")
    merc_type: MercenaryType | None = Field(description="Mercenary type for hire")
    reason: str = Field(description="Action reasoning")


class Position(BaseModel):
    """Position on the map."""
    
    model_config = ConfigDict(frozen=True)
    
    x: int = Field(description="X coordinate")
    y: int = Field(description="Y coordinate")


class MercenaryManager:
    """
    Tactical mercenary control system.
    
    Features:
    - Contract time monitoring and auto-renewal
    - Situation-based type selection
    - Skill coordination with player
    - Faith point optimization
    - Tactical positioning
    """
    
    def __init__(self, config: MercenaryConfig | None = None):
        """
        Initialize mercenary manager.
        
        Args:
            config: Configuration parameters
        """
        self.config = config or MercenaryConfig()
        self.current_state: MercenaryState | None = None
        self._guild_rank: int = 1  # 1-10, unlocks mercenary tiers
    
    async def update_state(self, state: MercenaryState) -> None:
        """
        Update current mercenary state.
        
        Args:
            state: New state from game
        """
        self.current_state = state
        
        # Log contract expiration warning
        if state.contract_remaining < 300 and state.contract_remaining > 0:
            logger.warning(
                "mercenary_contract_expiring",
                remaining_sec=state.contract_remaining,
                merc_type=state.type
            )
    
    def set_guild_rank(self, rank: int) -> None:
        """
        Set guild rank (unlocks higher tier mercenaries).
        
        Args:
            rank: Guild rank 1-10
        """
        self._guild_rank = max(1, min(10, rank))
        logger.info("guild_rank_set", rank=self._guild_rank)
    
    async def select_mercenary_type(
        self,
        situation: str,
        player_class: str = "generic",
        enemies_expected: int = 1
    ) -> MercenaryType:
        """
        Select appropriate mercenary for situation.
        
        Selection logic:
        - Swordsman: Tank/frontline when player is squishy
        - Archer: Ranged support for melee classes
        - Lancer: High DPS for boss fights or when player is tanky
        
        Args:
            situation: Situation type (farming, mvp, quest, etc.)
            player_class: Player's class name
            enemies_expected: Expected enemy count
        
        Returns:
            Recommended mercenary type
        """
        # Determine role based on situation
        if situation == "mvp" or situation == "boss":
            role = "lancer"  # High DPS for boss fights
        elif situation == "farming" and enemies_expected > 3:
            role = "archer"  # AoE for farming multiple mobs
        elif player_class in ["mage", "priest", "sage", "professor"]:
            role = "sword"  # Tank for squishy classes
        elif player_class in ["knight", "crusader", "lord_knight"]:
            role = "archer"  # Ranged DPS for tanky classes
        else:
            # Use preferred type if set
            if self.config.preferred_type:
                return self.config.preferred_type
            role = "archer"  # Default to archer
        
        # Select highest available tier for role
        level = min(self._guild_rank, 10)
        merc_type_str = f"{role}_{level}"
        
        try:
            merc_type = MercenaryType(merc_type_str)
            logger.info(
                "mercenary_selected",
                role=role,
                level=level,
                situation=situation
            )
            return merc_type
        except ValueError:
            # Fallback to level 1
            return MercenaryType(f"{role}_1")
    
    async def manage_contract(self) -> ContractAction | None:
        """
        Manage contract renewal and hiring.
        
        Returns:
            Contract action if needed
        """
        if not self.current_state:
            # No mercenary hired
            if self.config.auto_renew:
                # Hire preferred or default type
                merc_type = self.config.preferred_type or MercenaryType.ARCHER_LV1
                return ContractAction(
                    action="hire",
                    merc_type=merc_type,
                    reason="no_mercenary_active"
                )
            return None
        
        state = self.current_state
        
        # Check if contract needs renewal
        if state.contract_remaining < self.config.renew_threshold:
            if self.config.auto_renew:
                # Check faith level before renewal
                if state.faith < self.config.faith_threshold:
                    logger.info(
                        "mercenary_low_faith",
                        faith=state.faith,
                        threshold=self.config.faith_threshold
                    )
                    # Consider hiring different mercenary
                    return ContractAction(
                        action="dismiss",
                        merc_type=None,
                        reason=f"low_faith_{state.faith}"
                    )
                
                return ContractAction(
                    action="renew",
                    merc_type=state.type,
                    reason="contract_expiring"
                )
        
        return None
    
    async def coordinate_skills(
        self,
        combat_active: bool,
        player_hp_percent: float,
        enemies_nearby: int,
        is_boss_fight: bool = False
    ) -> SkillAction | None:
        """
        Coordinate mercenary skills with player.
        
        Args:
            combat_active: Whether in combat
            player_hp_percent: Player HP percentage
            enemies_nearby: Number of nearby enemies
            is_boss_fight: Whether fighting boss/MVP
        
        Returns:
            Skill action if should use skill
        """
        if not self.current_state or not combat_active:
            return None
        
        state = self.current_state
        
        # Get mercenary role
        role = self._get_mercenary_role(state.type)
        
        # Role-specific skill usage
        if role == "sword":
            # Tank skills: Provoke, Defense buff
            if enemies_nearby > 2 and "Provoke" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Provoke",
                    target_id=None,
                    reason="aggro_management_multiple_enemies"
                )
            if player_hp_percent < 0.5 and "Guard" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Guard",
                    target_id=None,
                    reason="defensive_player_low_hp"
                )
        
        elif role == "archer":
            # Archer skills: Double Strafe, Arrow Shower
            if enemies_nearby > 3 and "Arrow Shower" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Arrow Shower",
                    target_id=None,
                    reason="aoe_multiple_enemies"
                )
            if is_boss_fight and "Sharp Shooting" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Sharp Shooting",
                    target_id=None,
                    reason="high_damage_boss"
                )
        
        elif role == "lancer":
            # Lancer skills: Pierce, Spiral Pierce
            if is_boss_fight and "Spiral Pierce" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Spiral Pierce",
                    target_id=None,
                    reason="burst_damage_boss"
                )
            if state.sp > 30 and "Pierce" in state.skills:
                from ai_sidecar.companions.pet import SkillAction
                return SkillAction(
                    skill_name="Pierce",
                    target_id=None,
                    reason="sp_available_dps"
                )
        
        return None
    
    async def position_mercenary(
        self,
        player_pos: Position,
        enemy_positions: list[Position],
        ally_positions: list[Position] | None = None
    ) -> Position:
        """
        Calculate optimal mercenary position.
        
        Args:
            player_pos: Player position
            enemy_positions: List of enemy positions
            ally_positions: Optional list of ally positions
        
        Returns:
            Target position for mercenary
        """
        if not self.current_state or not enemy_positions:
            return player_pos
        
        role = self._get_mercenary_role(self.current_state.type)
        
        # Calculate average enemy position
        avg_enemy_x = sum(pos.x for pos in enemy_positions) / len(enemy_positions)
        avg_enemy_y = sum(pos.y for pos in enemy_positions) / len(enemy_positions)
        
        # Positioning strategy based on role and config
        if role == "sword" or self.config.positioning == "front":
            # Position between player and enemies (tank)
            target_x = int((player_pos.x + avg_enemy_x) / 2)
            target_y = int((player_pos.y + avg_enemy_y) / 2)
        
        elif role == "archer" or self.config.positioning == "back":
            # Position behind player (ranged)
            dx = avg_enemy_x - player_pos.x
            dy = avg_enemy_y - player_pos.y
            # Move 3 cells opposite to enemy direction
            target_x = player_pos.x - int(dx / (abs(dx) + 1) * 3)
            target_y = player_pos.y - int(dy / (abs(dy) + 1) * 3)
        
        elif self.config.positioning == "flank":
            # Position to the side of player (flank)
            target_x = player_pos.x + 3
            target_y = player_pos.y
        
        else:
            # Default: stay near player
            target_x = player_pos.x + 1
            target_y = player_pos.y + 1
        
        return Position(x=target_x, y=target_y)
    
    def _get_mercenary_role(self, merc_type: MercenaryType) -> str:
        """Get role (sword/archer/lancer) from mercenary type."""
        type_str = merc_type.value
        if type_str.startswith("sword"):
            return "sword"
        elif type_str.startswith("archer"):
            return "archer"
        elif type_str.startswith("lancer"):
            return "lancer"
        return "archer"  # Default
    
    def get_faith_multiplier(self) -> float:
        """
        Get stat multiplier based on faith level.
        
        Faith affects mercenary performance:
        - 0-25: 0.8x stats (poor performance)
        - 26-50: 0.9x stats
        - 51-75: 1.0x stats (normal)
        - 76-100: 1.1x stats (excellent)
        
        Returns:
            Stat multiplier
        """
        if not self.current_state:
            return 1.0
        
        faith = self.current_state.faith
        
        if faith <= 25:
            return 0.8
        elif faith <= 50:
            return 0.9
        elif faith <= 75:
            return 1.0
        else:
            return 1.1