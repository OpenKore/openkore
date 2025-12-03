"""
Instance Strategy System.

Provides strategic planning and execution for instance runs including
floor-specific tactics, boss fight strategies, and adaptive decision making.
"""

import json
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.instances.registry import InstanceDefinition
from ai_sidecar.instances.state import InstanceState, InstanceType

logger = structlog.get_logger(__name__)


class FloorStrategy(BaseModel):
    """Strategy for a specific floor."""
    
    model_config = ConfigDict(frozen=True)
    
    floor_number: int = Field(ge=1)
    recommended_route: List[tuple[int, int]] = Field(default_factory=list)
    priority_targets: List[str] = Field(default_factory=list)
    avoid_targets: List[str] = Field(default_factory=list)
    buff_requirements: List[str] = Field(default_factory=list)
    special_mechanics: List[str] = Field(default_factory=list)


class BossStrategy(BaseModel):
    """Strategy for a boss encounter."""
    
    model_config = ConfigDict(frozen=True)
    
    boss_name: str
    boss_hp_estimate: int = Field(default=0, ge=0)
    
    # Phases
    phase_triggers: List[float] = Field(default_factory=list)
    phase_mechanics: Dict[int, List[str]] = Field(default_factory=dict)
    
    # Tactics
    positioning: str = Field(default="melee")
    priority_skills: List[str] = Field(default_factory=list)
    avoid_skills: List[str] = Field(default_factory=list)
    
    # Special
    enrage_timer_seconds: Optional[int] = None
    adds_spawn: bool = False
    adds_priority: str = Field(default="ignore")
    
    # Safety
    safe_zones: List[tuple[int, int]] = Field(default_factory=list)
    danger_zones: List[tuple[int, int]] = Field(default_factory=list)


class InstanceAction(BaseModel):
    """Action to perform during instance."""
    
    action_type: str  # move, attack, skill, buff, loot, wait
    target_id: Optional[int] = None
    skill_name: Optional[str] = None
    position: Optional[tuple[int, int]] = None
    priority: int = Field(default=5, ge=1, le=10)
    reason: str = ""


class InstanceStrategy(BaseModel):
    """Complete strategy for an instance."""
    
    model_config = ConfigDict(frozen=True)
    
    instance_id: str
    
    # Overall approach
    speed_run: bool = False
    full_clear: bool = True
    loot_priority: List[str] = Field(default_factory=list)
    
    # Per-floor strategies
    floor_strategies: Dict[int, FloorStrategy] = Field(default_factory=dict)
    
    # Boss strategies
    boss_strategies: Dict[str, BossStrategy] = Field(default_factory=dict)
    
    # Resource management
    consumable_budget: Dict[str, int] = Field(default_factory=dict)
    death_limit: int = Field(default=3, ge=1)
    
    # Party roles
    tank_duties: List[str] = Field(default_factory=list)
    healer_duties: List[str] = Field(default_factory=list)
    dps_duties: List[str] = Field(default_factory=list)


class InstanceStrategyEngine:
    """
    Generates and executes instance strategies.
    
    Features:
    - Dynamic strategy generation
    - Boss mechanic handling
    - Floor-specific tactics
    - Adaptive difficulty response
    - Learning from previous runs
    """
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize strategy engine.
        
        Args:
            data_dir: Directory containing strategy data files
        """
        self.log = structlog.get_logger(__name__)
        self.strategies: Dict[str, InstanceStrategy] = {}
        self.learned_tactics: Dict[str, List[str]] = {}
        
        if data_dir:
            self._load_strategies(data_dir)
        
        self.log.info("InstanceStrategyEngine initialized")
    
    def _load_strategies(self, data_dir: Path) -> None:
        """
        Load predefined strategies from JSON file.
        
        Args:
            data_dir: Directory containing instance_strategies.json
        """
        strategies_file = data_dir / "instance_strategies.json"
        
        if not strategies_file.exists():
            self.log.warning(
                "Strategies file not found",
                path=str(strategies_file)
            )
            return
        
        try:
            with open(strategies_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            for instance_id, strategy_data in data.items():
                # Parse nested objects
                if "floor_strategies" in strategy_data:
                    floor_strats = {}
                    for floor_num, floor_data in strategy_data["floor_strategies"].items():
                        floor_strats[int(floor_num)] = FloorStrategy(**floor_data)
                    strategy_data["floor_strategies"] = floor_strats
                
                if "boss_strategies" in strategy_data:
                    boss_strats = {}
                    for boss_name, boss_data in strategy_data["boss_strategies"].items():
                        boss_strats[boss_name] = BossStrategy(**boss_data)
                    strategy_data["boss_strategies"] = boss_strats
                
                strategy = InstanceStrategy(
                    instance_id=instance_id,
                    **strategy_data
                )
                self.strategies[instance_id] = strategy
            
            self.log.info(
                "Loaded strategies",
                count=len(self.strategies)
            )
            
        except Exception as e:
            self.log.error(
                "Failed to load strategies",
                error=str(e),
                path=str(strategies_file)
            )
    
    async def get_strategy(
        self,
        instance_id: str
    ) -> Optional[InstanceStrategy]:
        """
        Get predefined strategy for instance.
        
        Args:
            instance_id: Instance identifier
            
        Returns:
            Instance strategy or None
        """
        return self.strategies.get(instance_id)
    
    async def generate_strategy(
        self,
        instance_def: InstanceDefinition,
        character_state: dict,
        party_composition: Optional[list] = None
    ) -> InstanceStrategy:
        """
        Generate strategy based on instance definition and party.
        
        Args:
            instance_def: Instance definition
            character_state: Character state dict
            party_composition: Optional list of party member job classes
            
        Returns:
            Generated InstanceStrategy object
        """
        # Check if strategy already exists
        if instance_def.instance_id in self.strategies:
            return self.strategies[instance_def.instance_id]
        
        party_composition = party_composition or []
        char_level = character_state.get("base_level", 1)
        
        # Determine party composition type
        is_solo = len(party_composition) <= 1
        has_healer = any(job in str(party_composition).lower() for job in ['priest', 'high priest', 'archbishop'])
        has_tank = any(job in str(party_composition).lower() for job in ['swordsman', 'knight', 'crusader', 'royal guard'])
        
        # Determine approach
        level_diff = char_level - instance_def.recommended_level
        speed_run = level_diff >= 20  # High level enables speed run
        full_clear = not speed_run
        
        # Generate floor strategies
        floor_strategies = {}
        for floor in range(1, instance_def.floors + 1):
            floor_strategies[floor] = FloorStrategy(
                floor_number=floor,
                buff_requirements=["blessing", "increase_agi"] if floor == 1 else []
            )
        
        # Generate boss strategies
        boss_strategies = {}
        for boss_name in instance_def.boss_names:
            # Determine positioning based on party
            if is_solo or not has_tank:
                positioning = "ranged"
            else:
                positioning = "melee"
            
            boss_strategies[boss_name] = BossStrategy(
                boss_name=boss_name,
                positioning=positioning
            )
        
        strategy = InstanceStrategy(
            instance_id=instance_def.instance_id,
            speed_run=speed_run,
            full_clear=full_clear,
            floor_strategies=floor_strategies,
            boss_strategies=boss_strategies,
            death_limit=5 if is_solo else 10
        )
        
        self.strategies[instance_def.instance_id] = strategy
        
        self.log.info(
            "Generated strategy",
            instance=instance_def.instance_name,
            floors=instance_def.floors,
            party_size=len(party_composition),
            speed_run=speed_run
        )
        
        return strategy
    
    def get_strategy_history(self, instance_name: str) -> list:
        """
        Get strategy history for an instance.
        
        Args:
            instance_name: Name of instance
            
        Returns:
            List of learned tactics
        """
        return self.learned_tactics.get(instance_name, [])
    
    async def get_floor_actions(
        self,
        floor: int,
        state: InstanceState
    ) -> List[InstanceAction]:
        """
        Get actions for current floor state.
        
        Args:
            floor: Floor number
            state: Current instance state
            
        Returns:
            List of recommended actions
        """
        actions: List[InstanceAction] = []
        
        strategy = await self.get_strategy(state.instance_id)
        if not strategy:
            return actions
        
        floor_strategy = strategy.floor_strategies.get(floor)
        if not floor_strategy:
            return actions
        
        floor_state = state.floors.get(floor)
        if not floor_state:
            return actions
        
        # Check if should apply buffs
        if floor_strategy.buff_requirements and not floor_state.monsters_killed:
            for buff in floor_strategy.buff_requirements:
                actions.append(InstanceAction(
                    action_type="buff",
                    skill_name=buff,
                    priority=8,
                    reason="Pre-floor buff"
                ))
        
        # Check if should move to specific location
        if floor_strategy.recommended_route and not floor_state.boss_spawned:
            if floor_strategy.recommended_route:
                next_pos = floor_strategy.recommended_route[0]
                actions.append(InstanceAction(
                    action_type="move",
                    position=next_pos,
                    priority=6,
                    reason="Follow floor route"
                ))
        
        return actions
    
    async def get_boss_actions(
        self,
        boss_name: str,
        boss_hp_percent: float,
        state: InstanceState
    ) -> List[InstanceAction]:
        """
        Get actions for boss fight.
        
        Args:
            boss_name: Name of boss
            boss_hp_percent: Boss HP percentage (0-100)
            state: Current instance state
            
        Returns:
            List of recommended actions
        """
        actions: List[InstanceAction] = []
        
        strategy = await self.get_strategy(state.instance_id)
        if not strategy:
            return actions
        
        boss_strategy = strategy.boss_strategies.get(boss_name)
        if not boss_strategy:
            return actions
        
        # Check phase transitions
        current_phase = self._get_boss_phase(boss_hp_percent, boss_strategy)
        
        # Get phase-specific mechanics
        phase_mechanics = boss_strategy.phase_mechanics.get(current_phase, [])
        for mechanic in phase_mechanics:
            self.log.info(
                "Boss phase mechanic",
                boss=boss_name,
                phase=current_phase,
                mechanic=mechanic
            )
        
        # Positioning
        if boss_strategy.positioning == "ranged":
            actions.append(InstanceAction(
                action_type="move",
                priority=7,
                reason="Maintain ranged distance"
            ))
        
        # Priority skills
        if boss_strategy.priority_skills:
            for skill in boss_strategy.priority_skills[:2]:  # Top 2 skills
                actions.append(InstanceAction(
                    action_type="skill",
                    skill_name=skill,
                    priority=9,
                    reason=f"Boss priority skill"
                ))
        
        # Handle adds
        if boss_strategy.adds_spawn and boss_strategy.adds_priority == "kill_first":
            actions.append(InstanceAction(
                action_type="attack",
                priority=10,
                reason="Kill adds first"
            ))
        
        return actions
    
    def _get_boss_phase(
        self,
        boss_hp_percent: float,
        boss_strategy: BossStrategy
    ) -> int:
        """
        Determine current boss phase based on HP.
        
        Args:
            boss_hp_percent: Boss HP percentage
            boss_strategy: Boss strategy
            
        Returns:
            Phase number (1-based)
        """
        if not boss_strategy.phase_triggers:
            return 1
        
        phase = 1
        for trigger_hp in sorted(boss_strategy.phase_triggers, reverse=True):
            if boss_hp_percent <= trigger_hp:
                phase += 1
        
        return phase
    
    async def adapt_strategy(
        self,
        event: str,
        state: InstanceState
    ) -> None:
        """
        Adapt strategy based on events.
        
        Args:
            event: Event type
            state: Current instance state
        """
        self.log.info(
            "Adapting strategy",
            event_type=event,
            floor=state.current_floor,
            progress=f"{state.overall_progress:.1f}%"
        )
        
        # Record learned tactics
        instance_tactics = self.learned_tactics.get(state.instance_id, [])
        
        if event == "party_member_died":
            instance_tactics.append("increase_caution")
        elif event == "time_running_low":
            instance_tactics.append("prioritize_speed")
        elif event == "unexpected_adds":
            instance_tactics.append("aoe_clear_needed")
        
        self.learned_tactics[state.instance_id] = instance_tactics[-10:]
    
    async def learn_from_run(
        self,
        state: InstanceState
    ) -> None:
        """
        Learn from completed instance run.
        
        Args:
            state: Final instance state after completion/failure
        """
        from ai_sidecar.instances.state import InstancePhase
        
        instance_id = state.instance_id
        success = state.phase == InstancePhase.COMPLETED
        
        self.log.info(
            "Learning from instance run",
            instance=instance_id,
            success=success,
            floor=state.current_floor
        )
        
        # Record in learned tactics
        tactics = self.learned_tactics.get(instance_id, [])
        if success:
            tactics.append("successful_completion")
        else:
            tactics.append(f"failed_at_floor_{state.current_floor}")
        
        self.learned_tactics[instance_id] = tactics[-20:]


# Alias for backward compatibility
StrategyEngine = InstanceStrategyEngine