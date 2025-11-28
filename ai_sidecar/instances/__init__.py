"""
Instance/Memorial Dungeon Systems.

Comprehensive instance management system for OpenKore AI providing:
- Instance definitions and registry
- Real-time state tracking
- Strategic planning and execution
- Navigation and pathing
- Cooldown management
- Endless Tower specialized handling
"""

from ai_sidecar.instances.coordinator import InstanceCoordinator
from ai_sidecar.instances.cooldowns import CooldownEntry, CooldownManager
from ai_sidecar.instances.endless_tower import EndlessTowerHandler, ETFloorData
from ai_sidecar.instances.navigator import InstanceNavigator
from ai_sidecar.instances.registry import (
    InstanceDefinition,
    InstanceDifficulty,
    InstanceRegistry,
    InstanceRequirement,
    InstanceReward,
    InstanceType,
)
from ai_sidecar.instances.state import (
    FloorState,
    InstancePhase,
    InstanceState,
    InstanceStateManager,
)
from ai_sidecar.instances.strategy import (
    BossStrategy,
    FloorStrategy,
    InstanceStrategy,
    InstanceStrategyEngine,
)

__all__ = [
    # Registry
    "InstanceType",
    "InstanceDifficulty",
    "InstanceRequirement",
    "InstanceReward",
    "InstanceDefinition",
    "InstanceRegistry",
    # State
    "InstancePhase",
    "FloorState",
    "InstanceState",
    "InstanceStateManager",
    # Strategy
    "FloorStrategy",
    "BossStrategy",
    "InstanceStrategy",
    "InstanceStrategyEngine",
    # Navigation
    "InstanceNavigator",
    # Cooldowns
    "CooldownEntry",
    "CooldownManager",
    # Endless Tower
    "ETFloorData",
    "EndlessTowerHandler",
    # Coordinator
    "InstanceCoordinator",
]