"""
PvP/WoE/Battlegrounds System for OpenKore AI Sidecar.

This package provides comprehensive PvP support including:
- Threat assessment and target prioritization
- War of Emperium (FE/SE/TE) management
- Battlegrounds modes (Tierra, Flavius, KVM, etc.)
- PvP tactics and combo execution
- Guild coordination
"""

from ai_sidecar.pvp.coordinator import PvPCoordinator
from ai_sidecar.pvp.core import (
    PvPCoreEngine,
    PvPMode,
    PlayerThreat,
    ThreatAssessor,
    ThreatLevel,
)
from ai_sidecar.pvp.woe import (
    Castle,
    CastleOwnership,
    WoEEdition,
    WoEManager,
    WoERole,
)
from ai_sidecar.pvp.battlegrounds import (
    BattlegroundManager,
    BattlegroundMode,
    BGMatchState,
    BGObjective,
    BGTeam,
)
from ai_sidecar.pvp.tactics import (
    ComboChain,
    CrowdControlType,
    PvPTacticsEngine,
    TacticalAction,
)
from ai_sidecar.pvp.coordination import (
    FormationType,
    GuildCommand,
    GuildCoordinator,
)

__all__ = [
    # Main coordinator
    "PvPCoordinator",
    # Core PvP
    "PvPCoreEngine",
    "PvPMode",
    "PlayerThreat",
    "ThreatAssessor",
    "ThreatLevel",
    # WoE
    "Castle",
    "CastleOwnership",
    "WoEEdition",
    "WoEManager",
    "WoERole",
    # Battlegrounds
    "BattlegroundManager",
    "BattlegroundMode",
    "BGMatchState",
    "BGObjective",
    "BGTeam",
    # Tactics
    "ComboChain",
    "CrowdControlType",
    "PvPTacticsEngine",
    "TacticalAction",
    # Coordination
    "FormationType",
    "GuildCommand",
    "GuildCoordinator",
]

__version__ = "1.0.0"