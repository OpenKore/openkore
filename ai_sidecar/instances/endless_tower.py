"""
Endless Tower Specialized Handler.

Handles the unique 100-floor Endless Tower instance with MVP boss floors
and checkpoint system.
"""

import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.instances.state import InstanceState
from ai_sidecar.instances.strategy import FloorStrategy, InstanceAction

logger = structlog.get_logger(__name__)


class ETFloorData(BaseModel):
    """Data for a specific Endless Tower floor."""
    
    model_config = ConfigDict(frozen=True)
    
    floor_number: int = Field(ge=1, le=100)
    monster_types: List[str] = Field(default_factory=list)
    monster_count: int = Field(default=0, ge=0)
    boss_name: Optional[str] = None
    mvp_floor: bool = False
    recommended_level: int = Field(default=1, ge=1, le=999)
    danger_rating: int = Field(default=1, ge=1, le=10)


class EndlessTowerHandler:
    """
    Specialized handler for Endless Tower (100 floors).
    
    Features:
    - Floor-specific monster data
    - MVP floor handling (25, 50, 75, 100)
    - Progress checkpointing
    - Party coordination for clears
    - Optimal stopping point detection
    """
    
    # MVP Floors with their bosses
    MVP_FLOORS = {
        25: "Amon Ra",
        50: "Drake",
        75: "Osiris",
        100: "Naght Sieger"
    }
    
    # Can restart from these floors
    CHECKPOINT_FLOORS = {26, 51, 77}
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize Endless Tower handler.
        
        Args:
            data_dir: Directory containing floor data files
        """
        self.log = structlog.get_logger(__name__)
        self.floor_data: Dict[int, ETFloorData] = {}
        
        if data_dir:
            self._load_floor_data(data_dir)
        else:
            self._generate_default_data()
        
        self.log.info("EndlessTowerHandler initialized", floors=len(self.floor_data))
    
    def _load_floor_data(self, data_dir: Path) -> None:
        """
        Load floor data from JSON file.
        
        Args:
            data_dir: Directory containing endless_tower_floors.json
        """
        floors_file = data_dir / "endless_tower_floors.json"
        
        if not floors_file.exists():
            self.log.warning(
                "ET floors data file not found",
                path=str(floors_file)
            )
            self._generate_default_data()
            return
        
        try:
            with open(floors_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            for floor_str, floor_data in data.items():
                floor_num = int(floor_str)
                self.floor_data[floor_num] = ETFloorData(
                    floor_number=floor_num,
                    **floor_data
                )
            
            self.log.info(
                "Loaded ET floor data",
                floors=len(self.floor_data)
            )
            
        except Exception as e:
            self.log.error(
                "Failed to load ET floors",
                error=str(e),
                path=str(floors_file)
            )
            self._generate_default_data()
    
    def _generate_default_data(self) -> None:
        """Generate default floor data for all 100 floors."""
        for floor_num in range(1, 101):
            is_mvp = floor_num in self.MVP_FLOORS
            
            if is_mvp:
                # MVP floor
                self.floor_data[floor_num] = ETFloorData(
                    floor_number=floor_num,
                    monster_types=[],
                    monster_count=0,
                    boss_name=self.MVP_FLOORS[floor_num],
                    mvp_floor=True,
                    recommended_level=min(99, 60 + (floor_num // 25) * 10),
                    danger_rating=7 + (floor_num // 25)
                )
            else:
                # Regular floor
                monster_count = min(20, 5 + floor_num // 10)
                self.floor_data[floor_num] = ETFloorData(
                    floor_number=floor_num,
                    monster_types=["Mixed"],
                    monster_count=monster_count,
                    mvp_floor=False,
                    recommended_level=min(99, 50 + floor_num // 10),
                    danger_rating=min(10, 1 + floor_num // 15)
                )
    
    async def get_floor_strategy(
        self,
        floor: int,
        character_state: Dict[str, Any]
    ) -> FloorStrategy:
        """
        Get strategy for specific floor.
        
        Args:
            floor: Floor number
            character_state: Character state dict
            
        Returns:
            Floor strategy
        """
        floor_data = self.floor_data.get(floor)
        if not floor_data:
            # Default strategy
            return FloorStrategy(floor_number=floor)
        
        # Determine if this is an MVP floor
        if floor_data.mvp_floor:
            return FloorStrategy(
                floor_number=floor,
                buff_requirements=["Assumptio", "Bless", "Increase AGI"],
                special_mechanics=[
                    f"MVP: {floor_data.boss_name}",
                    "Use Yggdrasil Leaf for safety",
                    "Position for ranged if solo"
                ]
            )
        
        # Regular floor
        return FloorStrategy(
            floor_number=floor,
            buff_requirements=["Bless", "Increase AGI"] if floor == 1 else [],
            special_mechanics=["Clear all monsters to proceed"]
        )
    
    async def can_handle_floor(
        self,
        floor: int,
        character_state: Dict[str, Any]
    ) -> Tuple[bool, str]:
        """
        Check if character can handle a floor.
        
        Args:
            floor: Floor number
            character_state: Character state dict
            
        Returns:
            Tuple of (can_handle, reason_if_not)
        """
        floor_data = self.floor_data.get(floor)
        if not floor_data:
            return True, ""
        
        char_level = character_state.get("base_level", 1)
        gear_score = character_state.get("gear_score", 0)
        party_size = character_state.get("party_size", 1)
        
        # Check level requirement
        if char_level < floor_data.recommended_level - 10:
            return False, f"Level too low (recommended {floor_data.recommended_level})"
        
        # MVP floor checks
        if floor_data.mvp_floor:
            # Solo MVP requires high gear
            if party_size == 1 and gear_score < 5000:
                return False, f"Solo MVP {floor_data.boss_name} requires better gear"
            
            # Check consumables
            consumables = character_state.get("consumables", {})
            if "Yggdrasil Leaf" not in consumables:
                return False, "Need Yggdrasil Leaf for MVP safety"
        
        # Danger rating check
        if floor_data.danger_rating >= 8:
            if party_size == 1 and gear_score < 4000:
                return False, f"Floor danger rating {floor_data.danger_rating}/10 too high for solo"
        
        return True, ""
    
    async def get_stopping_point(
        self,
        character_state: Dict[str, Any],
        current_floor: int
    ) -> int:
        """
        Determine optimal floor to stop at.
        
        Consider:
        - Character power level
        - Time remaining
        - MVP difficulty
        - Loot expectations
        
        Args:
            character_state: Character state dict
            current_floor: Current floor number
            
        Returns:
            Recommended stopping floor
        """
        char_level = character_state.get("base_level", 1)
        gear_score = character_state.get("gear_score", 0)
        party_size = character_state.get("party_size", 1)
        time_remaining = character_state.get("time_remaining_minutes", 240)
        
        # Calculate maximum achievable floor
        max_floor = current_floor
        
        # Check each floor ahead
        for floor in range(current_floor + 1, 101):
            can_handle, reason = await self.can_handle_floor(floor, character_state)
            
            if not can_handle:
                self.log.info(
                    "Cannot proceed past floor",
                    floor=floor - 1,
                    reason=reason
                )
                break
            
            max_floor = floor
            
            # Stop at checkpoints if time is limited
            if floor in self.CHECKPOINT_FLOORS and time_remaining < 60:
                self.log.info(
                    "Stopping at checkpoint due to time",
                    floor=floor,
                    time_remaining=time_remaining
                )
                break
        
        # Recommend stopping before next MVP if underprepared
        next_mvp = min((f for f in self.MVP_FLOORS.keys() if f > current_floor), default=100)
        
        if next_mvp <= max_floor:
            floor_before_mvp = next_mvp - 1
            
            # Check if should stop before MVP
            if party_size == 1 and gear_score < 6000:
                if floor_before_mvp >= current_floor:
                    self.log.info(
                        "Recommending stop before MVP",
                        stop_floor=floor_before_mvp,
                        mvp_floor=next_mvp,
                        reason="Underprepared for solo MVP"
                    )
                    return floor_before_mvp
        
        return max_floor
    
    async def handle_mvp_floor(
        self,
        floor: int,
        state: InstanceState
    ) -> List[InstanceAction]:
        """
        Special handling for MVP floors.
        
        Args:
            floor: Floor number
            state: Current instance state
            
        Returns:
            List of recommended actions
        """
        actions: List[InstanceAction] = []
        
        if floor not in self.MVP_FLOORS:
            return actions
        
        boss_name = self.MVP_FLOORS[floor]
        
        # Pre-MVP buffs
        actions.append(InstanceAction(
            action_type="buff",
            skill_name="Assumptio",
            priority=10,
            reason=f"Pre-MVP buff for {boss_name}"
        ))
        
        # Safety item check
        actions.append(InstanceAction(
            action_type="wait",
            priority=9,
            reason="Verify Yggdrasil Leaf ready"
        ))
        
        # Position strategy
        actions.append(InstanceAction(
            action_type="move",
            priority=8,
            reason="Position for MVP fight"
        ))
        
        self.log.info(
            "MVP floor handling",
            floor=floor,
            boss=boss_name,
            actions=len(actions)
        )
        
        return actions
    
    async def should_continue_past_mvp(
        self,
        floor: int,
        character_state: Dict[str, Any],
        state: InstanceState
    ) -> bool:
        """
        Determine if should continue after MVP floor.
        
        Consider:
        - Resource status
        - Time remaining
        - Next MVP difficulty
        
        Args:
            floor: Current (just completed) MVP floor
            character_state: Character state dict
            state: Instance state
            
        Returns:
            True if should continue
        """
        if floor not in self.MVP_FLOORS:
            return True
        
        # Check resources
        consumables = character_state.get("consumables", {})
        if consumables.get("White Potion", 0) < 20:
            self.log.info(
                "Low on resources after MVP",
                floor=floor,
                reason="< 20 White Potions"
            )
            return False
        
        # Check time
        if state.time_remaining_percent < 30:
            self.log.info(
                "Low on time after MVP",
                floor=floor,
                time_percent=state.time_remaining_percent
            )
            return False
        
        # Check deaths
        if state.deaths >= 2:
            self.log.info(
                "Too many deaths",
                floor=floor,
                deaths=state.deaths
            )
            return False
        
        # Check if can handle next section
        next_mvp = min(
            (f for f in self.MVP_FLOORS.keys() if f > floor),
            default=100
        )
        
        can_handle, reason = await self.can_handle_floor(next_mvp, character_state)
        if not can_handle:
            self.log.info(
                "Cannot handle next MVP",
                current_floor=floor,
                next_mvp=next_mvp,
                reason=reason
            )
            return False
        
        return True
    
    def is_mvp_floor(self, floor: int) -> bool:
        """Check if floor is an MVP floor."""
        return floor in self.MVP_FLOORS
    
    def is_checkpoint_floor(self, floor: int) -> bool:
        """Check if floor is a checkpoint."""
        return floor in self.CHECKPOINT_FLOORS
    
    def get_next_checkpoint(self, current_floor: int) -> Optional[int]:
        """Get next checkpoint floor."""
        checkpoints = sorted([f for f in self.CHECKPOINT_FLOORS if f > current_floor])
        return checkpoints[0] if checkpoints else None
    
    def get_floor_info(self, floor: int) -> Optional[ETFloorData]:
        """Get floor data."""
        return self.floor_data.get(floor)