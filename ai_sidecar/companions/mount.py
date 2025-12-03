"""
Mount System Intelligence for AI Sidecar.

Implements intelligent mount management including:
- Auto-mount/dismount for speed optimization
- Skill availability tracking (some skills require dismount)
- Peco rental management
- Cart weight optimization (merchant classes)
- Mado Gear fuel management (Mechanic)

RO Mount Mechanics:
- Peco Peco: Knights, Crusaders (+25% movement speed, limits some skills)
- Dragon: Rune Knights (+25% movement speed, special skills)
- Gryphon: Royal Guards (+25% movement speed, special skills)
- Wolf/Warg: Rangers (+25% movement speed, special skills)
- Mado Gear: Mechanics (requires fuel, special skills)
- Cart: Merchants (+weight capacity, -speed penalty)
"""

from enum import Enum
from typing import Literal

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class MountType(str, Enum):
    """Mount types by class."""
    
    PECO_PECO = "peco_peco"  # Knight, Crusader, Lord Knight
    DRAGON = "dragon"  # Rune Knight
    GRYPHON = "gryphon"  # Royal Guard
    WOLF = "wolf"  # Ranger (basic)
    WARG = "warg"  # Ranger (advanced)
    MADO_GEAR = "mado_gear"  # Mechanic


class MountState(BaseModel):
    """Current mount state."""
    
    model_config = ConfigDict(frozen=False)
    
    is_mounted: bool = Field(default=False, description="Currently mounted")
    mount_type: MountType | None = Field(default=None, description="Type of mount")
    
    # Mado Gear specific
    fuel: int | None = Field(default=None, ge=0, description="Mado Gear fuel")
    fuel_max: int | None = Field(default=None, ge=0, description="Max fuel capacity")
    
    # Cart specific (merchants)
    has_cart: bool = Field(default=False, description="Has cart equipped")
    cart_weight: int = Field(default=0, ge=0, description="Current cart weight")
    cart_max_weight: int = Field(default=8000, ge=0, description="Max cart weight")
    
    # Rental info
    is_rental: bool = Field(default=False, description="Is rented mount")
    rental_expires: float = Field(default=0.0, description="Rental expiry timestamp")


class MountConfig(BaseModel):
    """Mount system configuration."""
    
    model_config = ConfigDict(frozen=True)
    
    auto_mount: bool = Field(default=True, description="Auto-mount when appropriate")
    auto_dismount_for_skills: bool = Field(
        default=True,
        description="Auto-dismount to use restricted skills"
    )
    min_travel_distance: int = Field(
        default=10,
        ge=0,
        description="Min distance to mount for travel"
    )
    refuel_threshold: int = Field(
        default=20,
        ge=0,
        description="Refuel Mado Gear when fuel below this %"
    )
    cart_weight_target: float = Field(
        default=0.8,
        ge=0.0, le=1.0,
        description="Target cart weight (0.0-1.0)"
    )


class MountDecision(BaseModel):
    """Mount/dismount decision."""
    
    model_config = ConfigDict(frozen=True)
    
    should_mount: bool = Field(description="Whether to mount")
    reason: str = Field(description="Decision reasoning")


class RefuelAction(BaseModel):
    """Mado Gear refuel action."""
    
    model_config = ConfigDict(frozen=True)
    
    should_refuel: bool = Field(description="Whether to refuel")
    fuel_needed: int = Field(default=0, ge=0, description="Fuel amount needed")
    reason: str = Field(description="Refuel reasoning")


class CartOptimization(BaseModel):
    """Cart weight optimization recommendation."""
    
    model_config = ConfigDict(frozen=True)
    
    action: Literal["lighten", "maintain", "fill"] = Field(
        description="Recommended action"
    )
    current_ratio: float = Field(description="Current weight/max ratio")
    target_ratio: float = Field(description="Target weight/max ratio")
    reason: str = Field(description="Optimization reasoning")


class MountManager:
    """
    Mount system intelligence.
    
    Features:
    - Speed optimization through smart mounting
    - Skill-aware dismounting
    - Mado Gear fuel management
    - Cart weight optimization for merchants
    """
    
    # Skills that require dismounting (can't use while mounted)
    DISMOUNT_REQUIRED_SKILLS = {
        "Bowling Bash",
        "Charge Attack",
        "Magnum Break",
        "Holy Cross",
        "Grand Cross",
        "Shield Boomerang",
        "Shield Chain",
    }
    
    def __init__(self, config: MountConfig | None = None):
        """
        Initialize mount manager.
        
        Args:
            config: Configuration parameters
        """
        self.config = config or MountConfig()
        self.current_state: MountState | None = None
        self._player_class: str = "generic"
        self._available_mount: MountType | None = None
    
    async def update_state(self, state: MountState) -> None:
        """
        Update current mount state.
        
        Args:
            state: New state from game
        """
        self.current_state = state
        
        # Log fuel warnings for Mado Gear
        if state.mount_type == MountType.MADO_GEAR and state.fuel is not None:
            fuel_percent = (state.fuel / max(state.fuel_max or 1, 1)) * 100
            if fuel_percent < self.config.refuel_threshold:
                logger.warning(
                    "mado_gear_low_fuel",
                    fuel=state.fuel,
                    fuel_max=state.fuel_max,
                    percent=fuel_percent
                )
    
    def set_player_class(self, player_class: str) -> None:
        """
        Set player class to determine available mount.
        
        Args:
            player_class: Player's class name
        """
        self._player_class = player_class.lower()
        
        # Determine available mount based on class
        if "rune_knight" in self._player_class:
            self._available_mount = MountType.DRAGON
        elif "royal_guard" in self._player_class:
            self._available_mount = MountType.GRYPHON
        elif "ranger" in self._player_class:
            self._available_mount = MountType.WARG
        elif "mechanic" in self._player_class:
            self._available_mount = MountType.MADO_GEAR
        elif any(c in self._player_class for c in ["knight", "lord_knight", "crusader", "paladin"]):
            self._available_mount = MountType.PECO_PECO
        else:
            self._available_mount = None
        
        logger.info(
            "player_class_set",
            player_class=player_class,
            available_mount=self._available_mount
        )
    
    async def should_mount(
        self,
        distance_to_destination: int = 0,
        in_combat: bool = False,
        skill_to_use: str | None = None
    ) -> MountDecision:
        """
        Decide whether to mount or dismount.
        
        Considers:
        - Travel distance (mount for long distances)
        - Combat engagement (some skills need dismount)
        - Speed requirements
        - Fuel availability (Mado Gear)
        
        Args:
            distance_to_destination: Distance to travel
            in_combat: Whether currently in combat
            skill_to_use: Skill player wants to use
        
        Returns:
            Mount decision with reasoning
        """
        if not self.current_state:
            return MountDecision(
                should_mount=False,
                reason="no_state_available"
            )
        
        state = self.current_state
        
        # If no mount available for class
        if not self._available_mount:
            return MountDecision(
                should_mount=False,
                reason="no_mount_available_for_class"
            )
        
        # Check if skill requires dismount
        if skill_to_use and skill_to_use in self.DISMOUNT_REQUIRED_SKILLS:
            if state.is_mounted and self.config.auto_dismount_for_skills:
                return MountDecision(
                    should_mount=False,
                    reason=f"dismount_for_skill_{skill_to_use}"
                )
        
        # Check Mado Gear fuel
        if self._available_mount == MountType.MADO_GEAR:
            if state.fuel is not None and state.fuel <= 0:
                return MountDecision(
                    should_mount=False,
                    reason="mado_gear_no_fuel"
                )
        
        # Already mounted - stay mounted unless reason to dismount
        if state.is_mounted:
            # Dismount if in heavy combat and using restricted skills
            if in_combat and skill_to_use in self.DISMOUNT_REQUIRED_SKILLS:
                return MountDecision(
                    should_mount=False,
                    reason="combat_requires_dismount"
                )
            # Stay mounted
            return MountDecision(
                should_mount=True,
                reason="already_mounted"
            )
        
        # Not mounted - decide if should mount
        if not self.config.auto_mount:
            return MountDecision(
                should_mount=False,
                reason="auto_mount_disabled"
            )
        
        # Don't mount in combat
        if in_combat:
            return MountDecision(
                should_mount=False,
                reason="in_combat"
            )
        
        # Mount for long distance travel
        if distance_to_destination >= self.config.min_travel_distance:
            return MountDecision(
                should_mount=True,
                reason=f"long_distance_travel_{distance_to_destination}_cells"
            )
        
        # Don't mount for short distances
        if distance_to_destination < self.config.min_travel_distance:
            return MountDecision(
                should_mount=False,
                reason="short_distance_or_combat"
            )
        
        # Default: stay unmounted
        return MountDecision(
            should_mount=False,
            reason="no_reason_to_mount"
        )
    
    async def manage_mado_fuel(self) -> RefuelAction | None:
        """
        Track and manage Mado Gear fuel.
        
        Returns:
            Refuel action if needed
        """
        if not self.current_state:
            return None
        
        state = self.current_state
        
        # Only for Mado Gear
        if state.mount_type != MountType.MADO_GEAR:
            return None
        
        if state.fuel is None or state.fuel_max is None:
            return None
        
        # Calculate fuel percentage
        fuel_percent = (state.fuel / state.fuel_max) * 100
        
        # Check if refuel needed
        if fuel_percent < self.config.refuel_threshold:
            fuel_needed = state.fuel_max - state.fuel
            
            return RefuelAction(
                should_refuel=True,
                fuel_needed=fuel_needed,
                reason=f"fuel_at_{fuel_percent:.1f}%"
            )
        
        return RefuelAction(
            should_refuel=False,
            fuel_needed=0,
            reason=f"fuel_ok_at_{fuel_percent:.1f}%"
        )
    
    async def optimize_cart_weight(
        self,
        items_to_pickup: int = 0,
        vending_mode: bool = False
    ) -> CartOptimization:
        """
        Optimize cart weight for merchant classes.
        
        Balances between:
        - Weight capacity for looting
        - Movement speed (higher weight = slower)
        - Vending stock
        
        Args:
            items_to_pickup: Expected items to pick up
            vending_mode: Whether preparing for vending
        
        Returns:
            Cart optimization recommendation
        """
        if not self.current_state or not self.current_state.has_cart:
            return CartOptimization(
                action="maintain",
                current_ratio=0.0,
                target_ratio=0.0,
                reason="no_cart"
            )
        
        state = self.current_state
        
        # Calculate current weight ratio
        current_ratio = state.cart_weight / max(state.cart_max_weight, 1)
        target_ratio = self.config.cart_weight_target
        
        # Vending mode: aim for fuller cart
        if vending_mode:
            target_ratio = 0.9
            if current_ratio < target_ratio:
                return CartOptimization(
                    action="fill",
                    current_ratio=current_ratio,
                    target_ratio=target_ratio,
                    reason="vending_mode_fill_cart"
                )
        
        # Looting mode: maintain capacity for pickups
        if items_to_pickup > 0:
            # Need at least 10% capacity for pickups
            if current_ratio > 0.9:
                return CartOptimization(
                    action="lighten",
                    current_ratio=current_ratio,
                    target_ratio=0.8,
                    reason="cart_full_cant_loot"
                )
        
        # Check if significantly over target
        if current_ratio > target_ratio + 0.1:
            return CartOptimization(
                action="lighten",
                current_ratio=current_ratio,
                target_ratio=target_ratio,
                reason="over_target_weight"
            )
        
        # Check if significantly under target (wasted capacity)
        if current_ratio < target_ratio - 0.2 and not vending_mode:
            return CartOptimization(
                action="fill",
                current_ratio=current_ratio,
                target_ratio=target_ratio,
                reason="underutilized_capacity"
            )
        
        # Weight is acceptable
        return CartOptimization(
            action="maintain",
            current_ratio=current_ratio,
            target_ratio=target_ratio,
            reason="weight_optimal"
        )
    
    def get_speed_bonus(self) -> float:
        """
        Get movement speed bonus from mount.
        
        Returns:
            Speed multiplier (1.25 for most mounts, 1.0 for none)
        """
        if not self.current_state:
            return 1.0
        
        # Start with base speed
        base_speed = 1.0
        
        # Apply mount bonus if mounted
        if self.current_state.is_mounted:
            base_speed = 1.25
        
        # Apply cart penalty if has cart (regardless of mount status)
        if self.current_state.has_cart:
            cart_ratio = self.current_state.cart_weight / max(
                self.current_state.cart_max_weight, 1
            )
            # Speed penalty increases with cart weight (up to 10% slower when full)
            penalty = 0.1 * cart_ratio
            base_speed *= (1.0 - penalty)
        
        return base_speed