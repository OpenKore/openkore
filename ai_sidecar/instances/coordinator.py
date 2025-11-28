"""
Instance Coordinator.

Unified instance management coordinator that brings together all instance
systems for selection, execution, and completion.
"""

from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, Field

from ai_sidecar.instances.cooldowns import CooldownManager
from ai_sidecar.instances.endless_tower import EndlessTowerHandler
from ai_sidecar.instances.navigator import InstanceNavigator
from ai_sidecar.instances.registry import InstanceDefinition, InstanceRegistry
from ai_sidecar.instances.state import InstancePhase, InstanceState, InstanceStateManager
from ai_sidecar.instances.strategy import InstanceAction, InstanceStrategyEngine

logger = structlog.get_logger(__name__)


class PlannedInstance(BaseModel):
    """Planned instance run for daily schedule."""
    
    instance_id: str
    instance_name: str
    scheduled_time: datetime
    estimated_duration_minutes: int
    priority: int = Field(default=5, ge=1, le=10)


class InstanceRunReport(BaseModel):
    """Report generated after instance completion."""
    
    instance_id: str
    instance_name: str
    success: bool
    duration_seconds: float
    floors_cleared: int
    total_floors: int
    deaths: int
    loot_collected: List[str]
    loot_value_estimate: int
    experience_gained: int = 0
    completion_percent: float


class InstanceCoordinator:
    """
    Unified instance management coordinator.
    
    Coordinates:
    - Instance selection
    - Entry/exit handling
    - Progress tracking
    - Strategy execution
    - Party coordination
    - Cooldown management
    """
    
    def __init__(self, data_dir: Optional[Path] = None):
        """
        Initialize coordinator.
        
        Args:
            data_dir: Directory containing instance data files
        """
        self.log = structlog.get_logger(__name__)
        
        # Initialize all subsystems
        self.registry = InstanceRegistry(data_dir)
        self.state_manager = InstanceStateManager()
        self.strategy_engine = InstanceStrategyEngine(data_dir)
        self.navigator = InstanceNavigator()
        self.cooldown_manager = CooldownManager()
        self.et_handler = EndlessTowerHandler(data_dir)
        
        self.log.info("InstanceCoordinator initialized")
    
    async def select_instance(
        self,
        character_state: Dict[str, Any],
        preferences: Optional[Dict[str, Any]] = None
    ) -> Optional[str]:
        """
        Select best instance to run.
        
        Consider:
        - Character capabilities
        - Available cooldowns
        - Time available
        - Party availability
        - Loot preferences
        
        Args:
            character_state: Character state dict
            preferences: User preferences dict
            
        Returns:
            Instance ID or None
        """
        preferences = preferences or {}
        char_name = character_state.get("name", "Unknown")
        
        # Get available instances (not on cooldown)
        available = await self.cooldown_manager.get_available_instances(
            char_name,
            self.registry
        )
        
        if not available:
            self.log.info("No instances available (all on cooldown)")
            return None
        
        # Get cooldown status for recommendation system
        cooldown_status = {
            inst_id: False for inst_id in available
        }
        
        # Get recommendations
        recommended = await self.registry.get_recommended_instances(
            character_state,
            cooldown_status
        )
        
        if not recommended:
            self.log.info("No recommended instances found")
            return None
        
        # Apply preferences
        if preferences.get("prefer_solo"):
            recommended = [
                inst for inst in recommended
                if inst.requirements.max_party_size == 1
            ]
        
        if preferences.get("prefer_short"):
            recommended.sort(key=lambda i: i.estimated_clear_time_minutes)
        
        selected = recommended[0] if recommended else None
        
        if selected:
            self.log.info(
                "Instance selected",
                instance=selected.instance_name,
                estimated_time=selected.estimated_clear_time_minutes
            )
        
        return selected.instance_id if selected else None
    
    async def start_instance_run(
        self,
        instance_id: str,
        character_state: Dict[str, Any]
    ) -> InstanceState:
        """
        Initialize an instance run.
        
        Args:
            instance_id: Instance to run
            character_state: Character state dict
            
        Returns:
            Initial instance state
        """
        instance_def = await self.registry.get_instance(instance_id)
        if not instance_def:
            raise ValueError(f"Unknown instance: {instance_id}")
        
        # Check requirements
        can_enter, missing = await self.registry.check_requirements(
            instance_id,
            character_state
        )
        
        if not can_enter:
            raise ValueError(
                f"Cannot enter instance: {', '.join(missing)}"
            )
        
        # Get party members
        party_members = character_state.get("party_members", [])
        
        # Start instance
        state = await self.state_manager.start_instance(
            instance_def,
            party_members
        )
        
        self.log.info(
            "Instance run started",
            instance=instance_def.instance_name,
            character=character_state.get("name"),
            party_size=len(party_members)
        )
        
        return state
    
    async def get_next_action(
        self,
        game_state: Dict[str, Any]
    ) -> Optional[InstanceAction]:
        """
        Get next action during instance.
        
        Considers current phase, floor, and objectives.
        
        Args:
            game_state: Current game state
            
        Returns:
            Next action or None
        """
        state = self.state_manager.get_current_state()
        if not state:
            return None
        
        # Check if should abort
        should_abort, reason = await self.state_manager.should_abort()
        if should_abort:
            self.log.warning("Aborting instance", reason=reason)
            return InstanceAction(
                action_type="exit",
                priority=10,
                reason=f"Abort: {reason}"
            )
        
        # Get strategy
        strategy = await self.strategy_engine.get_strategy(state.instance_id)
        if not strategy:
            strategy = await self.strategy_engine.generate_strategy(
                await self.registry.get_instance(state.instance_id),
                game_state,
                state.party_members
            )
        
        # Phase-specific actions
        if state.phase == InstancePhase.IN_PROGRESS:
            # Get floor actions
            actions = await self.strategy_engine.get_floor_actions(
                state.current_floor,
                state
            )
            return actions[0] if actions else None
        
        elif state.phase == InstancePhase.BOSS_FIGHT:
            # Get boss actions
            boss_hp = game_state.get("boss_hp_percent", 100.0)
            boss_name = game_state.get("boss_name", "Unknown")
            
            actions = await self.strategy_engine.get_boss_actions(
                boss_name,
                boss_hp,
                state
            )
            return actions[0] if actions else None
        
        elif state.phase == InstancePhase.LOOTING:
            # Collect loot
            return InstanceAction(
                action_type="loot",
                priority=7,
                reason="Collect floor loot"
            )
        
        return None
    
    async def handle_event(
        self,
        event_type: str,
        event_data: Dict[str, Any]
    ) -> None:
        """
        Handle instance events.
        
        Args:
            event_type: Event type
            event_data: Event data dict
        """
        state = self.state_manager.get_current_state()
        if not state:
            return
        
        if event_type == "monster_killed":
            await self.state_manager.update_floor_progress(
                monsters_killed=event_data.get("count", 1)
            )
        
        elif event_type == "boss_killed":
            await self.state_manager.update_floor_progress(
                boss_killed=True
            )
            
            # Check if should advance floor
            if state.current_floor < state.total_floors:
                await self.state_manager.advance_floor()
        
        elif event_type == "death":
            member_name = event_data.get("member_name")
            await self.state_manager.record_death(member_name)
            await self.strategy_engine.adapt_strategy("party_member_died", state)
        
        elif event_type == "loot_dropped":
            items = event_data.get("items", [])
            await self.state_manager.record_loot(items)
        
        elif event_type == "time_warning":
            await self.strategy_engine.adapt_strategy("time_running_low", state)
        
        self.log.debug(
            "Event handled",
            event=event_type,
            floor=state.current_floor
        )
    
    async def complete_run(self) -> InstanceRunReport:
        """
        Complete current run and generate report.
        
        Returns:
            Instance run report
        """
        state = self.state_manager.get_current_state()
        if not state:
            raise ValueError("No active instance to complete")
        
        # Determine success
        success = state.phase == InstancePhase.COMPLETED
        
        # Complete state management
        final_state = await self.state_manager.complete_instance(success)
        
        # Record cooldown
        instance_def = await self.registry.get_instance(state.instance_id)
        if instance_def:
            char_name = final_state.party_members[0] if final_state.party_members else "Unknown"
            await self.cooldown_manager.record_completion(
                state.instance_id,
                char_name,
                instance_def.cooldown_hours
            )
        
        # Learn from run
        await self.strategy_engine.learn_from_run(final_state)
        
        # Generate report
        report = InstanceRunReport(
            instance_id=final_state.instance_id,
            instance_name=final_state.instance_name,
            success=success,
            duration_seconds=final_state.elapsed_seconds,
            floors_cleared=sum(1 for f in final_state.floors.values() if f.is_cleared),
            total_floors=final_state.total_floors,
            deaths=final_state.deaths,
            loot_collected=final_state.total_loot,
            loot_value_estimate=final_state.loot_value_estimate,
            completion_percent=final_state.overall_progress
        )
        
        self.log.info(
            "Instance run completed",
            instance=report.instance_name,
            success=success,
            duration=f"{report.duration_seconds:.1f}s",
            floors=f"{report.floors_cleared}/{report.total_floors}",
            loot_items=len(report.loot_collected)
        )
        
        return report
    
    async def get_daily_plan(
        self,
        character_state: Dict[str, Any]
    ) -> List[PlannedInstance]:
        """
        Plan instances for the day.
        
        Optimize for:
        - Cooldown efficiency
        - Time management
        - Reward maximization
        
        Args:
            character_state: Character state dict
            
        Returns:
            List of planned instances
        """
        char_name = character_state.get("name", "Unknown")
        
        # Get all possible instances
        all_instances = self.registry.get_all_instances()
        
        # Filter by character capability
        capable_instances = []
        for instance in all_instances:
            can_enter, _ = await self.registry.check_requirements(
                instance.instance_id,
                character_state
            )
            if can_enter:
                capable_instances.append(instance)
        
        # Get optimal schedule
        instance_ids = [inst.instance_id for inst in capable_instances]
        schedule = await self.cooldown_manager.get_optimal_schedule(
            char_name,
            instance_ids
        )
        
        # Create planned instances
        planned: List[PlannedInstance] = []
        for instance in capable_instances:
            if instance.instance_id in schedule:
                planned.append(PlannedInstance(
                    instance_id=instance.instance_id,
                    instance_name=instance.instance_name,
                    scheduled_time=schedule[instance.instance_id],
                    estimated_duration_minutes=instance.estimated_clear_time_minutes,
                    priority=8 if instance.instance_type.value == "endless_tower" else 5
                ))
        
        # Sort by scheduled time
        planned.sort(key=lambda p: p.scheduled_time)
        
        self.log.info(
            "Daily plan generated",
            character=char_name,
            instances=len(planned)
        )
        
        return planned
    
    def get_current_state(self) -> Optional[InstanceState]:
        """Get current instance state."""
        return self.state_manager.get_current_state()
    
    def get_cooldown_summary(self, character_name: str) -> Dict[str, Any]:
        """Get cooldown summary for character."""
        return self.cooldown_manager.get_cooldown_summary(character_name)