"""
Pet System Intelligence for AI Sidecar.

Implements intelligent pet management including:
- Intimacy optimization (not just hunger prevention)
- Evolution tracking and recommendations
- Performance-based pet selection
- Accessory management
- Skill usage coordination

RO Pet Mechanics:
- Intimacy: 0-1000 scale (250=awkward, 750=cordial, 910=loyal, 1000=max)
- Hunger: 0-100 scale (decreases over time, feed to restore)
- Optimal feeding: hunger 25-35 for best intimacy gain
- Evolution: Available at 910+ intimacy with specific item
"""

import json
import time
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class PetType(str, Enum):
    """All capturable pet types in Ragnarok Online."""
    
    # Common pets
    PORING = "poring"
    DROPS = "drops"
    POPORING = "poporing"
    LUNATIC = "lunatic"
    PICKY = "picky"
    CHONCHON = "chonchon"
    STEEL_CHONCHON = "steel_chonchon"
    HUNTER_FLY = "hunter_fly"
    ROCKER = "rocker"
    SPORE = "spore"
    POISON_SPORE = "poison_spore"
    
    # Rare/special pets
    YOYO = "yoyo"
    SMOKIE = "smokie"
    SOHEE = "sohee"
    ISIS = "isis"
    PETITE = "petite"
    DEVIRUCHI = "deviruchi"
    BAPHOMET_JR = "baphomet_jr"
    SUCCUBUS = "succubus"
    INCUBUS = "incubus"


class PetState(BaseModel):
    """Current pet state and statistics."""
    
    model_config = ConfigDict(frozen=False)
    
    pet_id: int = Field(description="Unique pet instance ID")
    pet_type: PetType = Field(description="Pet species type")
    name: str = Field(default="", description="Pet name")
    
    # Core stats
    intimacy: int = Field(default=250, ge=0, le=1000, description="Intimacy level")
    hunger: int = Field(default=100, ge=0, le=100, description="Hunger level")
    
    # Status
    is_summoned: bool = Field(default=False, description="Is pet currently out")
    accessory_equipped: bool = Field(default=False, description="Has accessory equipped")
    
    # Evolution
    can_evolve: bool = Field(default=False, description="Meets evolution requirements")
    evolution_target: PetType | None = Field(default=None, description="Evolution target")
    
    # Performance tracking
    loyalty_bonus: dict[str, int] = Field(
        default_factory=dict,
        description="Stat bonuses from intimacy"
    )
    
    # Timestamps
    last_fed: float = Field(default=0.0, description="Last feeding timestamp")
    last_performance_check: float = Field(default=0.0, description="Last perf eval")


class PetConfig(BaseModel):
    """Per-pet configuration."""
    
    model_config = ConfigDict(frozen=True)
    
    target_intimacy: int = Field(
        default=910,
        ge=0, le=1000,
        description="Target intimacy (910 for evolution)"
    )
    feed_threshold: int = Field(
        default=75,
        ge=0, le=100,
        description="Feed when hunger drops below this"
    )
    optimal_feed_hunger: int = Field(
        default=30,
        ge=0, le=100,
        description="Optimal hunger for feeding (best intimacy gain)"
    )
    auto_summon: bool = Field(default=True, description="Auto-summon pet")
    use_skills: bool = Field(default=True, description="Use pet skills")
    skill_cooldown: float = Field(default=5.0, ge=0.0, description="Skill CD in seconds")


class FeedDecision(BaseModel):
    """Decision to feed the pet."""
    
    model_config = ConfigDict(frozen=True)
    
    should_feed: bool = Field(description="Whether to feed now")
    reason: str = Field(description="Reason for decision")
    food_item: str = Field(default="", description="Food item to use")
    expected_intimacy_gain: int = Field(default=0, description="Expected intimacy gain")


class EvolutionDecision(BaseModel):
    """Decision about pet evolution."""
    
    model_config = ConfigDict(frozen=True)
    
    should_evolve: bool = Field(description="Whether to evolve now")
    target: PetType | None = Field(description="Evolution target")
    required_item: str = Field(default="", description="Required evolution item")
    reason: str = Field(description="Reason for decision")


class SkillAction(BaseModel):
    """Pet skill usage action."""
    
    model_config = ConfigDict(frozen=True)
    
    skill_name: str = Field(description="Skill to use")
    target_id: int | None = Field(default=None, description="Target actor ID")
    reason: str = Field(description="Reason for using skill")


class PetManager:
    """
    Intelligent pet management system.
    
    Features:
    - Intimacy optimization through strategic feeding
    - Evolution eligibility tracking
    - Performance-based pet selection
    - Skill coordination with combat
    """
    
    def __init__(self, data_path: Path | None = None):
        """
        Initialize pet manager.
        
        Args:
            data_path: Path to pet database JSON file
        """
        self.config = PetConfig()
        self.current_state: PetState | None = None
        self._pet_database: dict[str, dict[str, Any]] = {}
        self._last_skill_use: float = 0.0
        
        # Load pet database
        if data_path is None:
            data_path = Path(__file__).parent.parent / "data" / "pets.json"
        
        if data_path.exists():
            with open(data_path, "r") as f:
                self._pet_database = json.load(f)
            logger.info("pet_database_loaded", pet_count=len(self._pet_database))
        else:
            logger.warning("pet_database_not_found", path=str(data_path))
    
    async def update_state(self, state: PetState) -> None:
        """
        Update current pet state.
        
        Args:
            state: New pet state from game
        """
        self.current_state = state
        
        # Check evolution eligibility
        if state.intimacy >= 910 and not state.can_evolve:
            evolution_info = self._get_evolution_info(state.pet_type)
            if evolution_info:
                state.can_evolve = True
                state.evolution_target = PetType(evolution_info["target"])
                logger.info(
                    "pet_evolution_ready",
                    pet_type=state.pet_type,
                    target=state.evolution_target
                )
    
    async def decide_feed_timing(self) -> FeedDecision | None:
        """
        Calculate optimal feeding decision.
        
        Algorithm:
        - Emergency: Feed if hunger < 10 (prevent running away)
        - Optimal: Feed at hunger 25-35 for best intimacy gain
        - Avoid: Don't feed at high hunger (wasted food, poor gain)
        
        Returns:
            Feed decision with reasoning, or None if pet not available
        """
        if not self.current_state or not self.current_state.is_summoned:
            return None
        
        state = self.current_state
        hunger = state.hunger
        intimacy = state.intimacy
        
        # Get pet data
        pet_data = self._pet_database.get(state.pet_type.value, {})
        food = pet_data.get("food", "Unknown Food")
        
        # Emergency feeding (prevent pet from leaving)
        if hunger < 10:
            return FeedDecision(
                should_feed=True,
                reason="emergency_low_hunger",
                food_item=food,
                expected_intimacy_gain=1
            )
        
        # Already at max intimacy
        if intimacy >= 1000:
            # Still feed to maintain, but less urgently
            if hunger < 50:
                return FeedDecision(
                    should_feed=True,
                    reason="maintenance_feeding",
                    food_item=food,
                    expected_intimacy_gain=0
                )
            return FeedDecision(
                should_feed=False,
                reason="max_intimacy_high_hunger",
                food_item=food
            )
        
        # Optimal feeding window (25-35 hunger)
        if 25 <= hunger <= 35:
            # Calculate expected gain based on hunger
            base_gain = 10
            hunger_multiplier = 1.0 + ((35 - hunger) / 10)  # Lower hunger = more gain
            expected_gain = int(base_gain * hunger_multiplier)
            
            return FeedDecision(
                should_feed=True,
                reason="optimal_intimacy_window",
                food_item=food,
                expected_intimacy_gain=min(expected_gain, 1000 - intimacy)
            )
        
        # Standard feeding threshold
        if hunger < self.config.feed_threshold:
            return FeedDecision(
                should_feed=True,
                reason="hunger_below_threshold",
                food_item=food,
                expected_intimacy_gain=5
            )
        
        # Don't feed yet
        return FeedDecision(
            should_feed=False,
            reason=f"hunger_ok_at_{hunger}",
            food_item=food
        )
    
    async def evaluate_evolution(self) -> EvolutionDecision | None:
        """
        Evaluate whether pet should evolve.
        
        Considers:
        - Intimacy requirement (910+)
        - Evolution path availability
        - Evolution item possession
        - Strategic value of evolved form
        
        Returns:
            Evolution decision with reasoning
        """
        if not self.current_state:
            return None
        
        state = self.current_state
        
        # Check evolution path first
        evolution_info = self._get_evolution_info(state.pet_type)
        if not evolution_info:
            return EvolutionDecision(
                should_evolve=False,
                target=None,
                reason="no_evolution_path"
            )
        
        # Check intimacy requirement
        if state.intimacy < 910:
            return EvolutionDecision(
                should_evolve=False,
                target=None,
                reason=f"intimacy_too_low_{state.intimacy}"
            )
        
        target = PetType(evolution_info["target"])
        required_item = evolution_info["item"]
        
        # Default: recommend evolution (player decides based on inventory)
        return EvolutionDecision(
            should_evolve=True,
            target=target,
            required_item=required_item,
            reason="meets_all_requirements"
        )
    
    async def select_optimal_pet(self, situation: str) -> PetType | None:
        """
        Select best pet for current situation.
        
        Args:
            situation: Current situation (farming, mvp, pvp, etc.)
        
        Returns:
            Recommended pet type
        """
        if not self._pet_database:
            return None
        
        # Situation-specific pet recommendations
        recommendations = {
            "farming": [PetType.DROPS, PetType.YOYO],  # Loot bonuses
            "mvp": [PetType.BAPHOMET_JR, PetType.DEVIRUCHI],  # Combat stats
            "support": [PetType.SOHEE],  # SP recovery
            "tanking": [PetType.PETITE],  # Defense bonuses
        }
        
        preferred = recommendations.get(situation, [])
        if preferred:
            # Return first available from preferences
            for pet_type in preferred:
                if pet_type.value in self._pet_database:
                    logger.info(
                        "pet_selected",
                        situation=situation,
                        pet_type=pet_type
                    )
                    return pet_type
        
        # Default to Poring if no specific recommendation
        return PetType.PORING
    
    async def coordinate_pet_skills(
        self,
        combat_active: bool,
        player_hp_percent: float,
        enemies_nearby: int
    ) -> SkillAction | None:
        """
        Coordinate pet skill usage with player actions.
        
        Args:
            combat_active: Whether player is in combat
            player_hp_percent: Player HP percentage (0.0-1.0)
            enemies_nearby: Number of nearby enemies
        
        Returns:
            Skill action if pet should use skill
        """
        if not self.current_state or not self.current_state.is_summoned:
            return None
        
        if not self.config.use_skills:
            return None
        
        # Check cooldown
        now = time.time()
        if now - self._last_skill_use < self.config.skill_cooldown:
            return None
        
        # Get pet skills
        pet_data = self._pet_database.get(self.current_state.pet_type.value, {})
        skills = pet_data.get("skills", [])
        
        if not skills:
            return None
        
        # Skill usage logic based on pet type and situation
        # (This is simplified - real implementation would be more complex)
        
        # Healing pets (e.g., specific types could have heal skills)
        if "Heal" in skills and player_hp_percent < 0.5:
            self._last_skill_use = now
            return SkillAction(
                skill_name="Heal",
                target_id=None,
                reason="player_hp_low"
            )
        
        # Offensive skills in combat
        if combat_active and enemies_nearby > 0:
            offensive_skills = [s for s in skills if s not in ["Heal"]]
            if offensive_skills:
                self._last_skill_use = now
                return SkillAction(
                    skill_name=offensive_skills[0],
                    target_id=None,
                    reason="combat_support"
                )
        
        return None
    
    def _get_evolution_info(self, pet_type: PetType) -> dict[str, str] | None:
        """Get evolution information for a pet type."""
        pet_data = self._pet_database.get(pet_type.value, {})
        return pet_data.get("evolution")
    
    def get_pet_bonus(self, pet_type: PetType) -> dict[str, int]:
        """
        Get stat bonuses for a pet type at high intimacy.
        
        Args:
            pet_type: Pet type to query
        
        Returns:
            Dict of stat bonuses
        """
        pet_data = self._pet_database.get(pet_type.value, {})
        return pet_data.get("stat_bonus", {})