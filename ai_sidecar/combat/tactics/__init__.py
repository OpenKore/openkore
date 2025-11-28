"""
Tactics Module for Combat AI.

Provides role-specific tactical behaviors for different combat styles.
Each tactics implementation specializes in a particular combat role.

Available Tactics:
- TankTactics: Aggro management, party protection
- MeleeDPSTactics: Burst damage, combo chains
- RangedDPSTactics: Kiting, distance management
- MagicDPSTactics: Cast timing, element matching
- SupportTactics: Healing, buff management
- HybridTactics: Adaptive role switching
"""

from ai_sidecar.combat.tactics.base import (
    BaseTactics,
    CombatContextProtocol,
    Position,
    Skill,
    TacticalRole,
    TacticsConfig,
    TargetPriority,
    ThreatEntry,
)
from ai_sidecar.combat.tactics.tank import TankTactics, TankTacticsConfig
from ai_sidecar.combat.tactics.melee_dps import MeleeDPSTactics, MeleeDPSTacticsConfig
from ai_sidecar.combat.tactics.ranged_dps import RangedDPSTactics, RangedDPSTacticsConfig
from ai_sidecar.combat.tactics.magic_dps import MagicDPSTactics, MagicDPSTacticsConfig
from ai_sidecar.combat.tactics.support import SupportTactics, SupportTacticsConfig
from ai_sidecar.combat.tactics.hybrid import HybridTactics, HybridTacticsConfig

__all__ = [
    # Base classes
    "BaseTactics",
    "CombatContextProtocol",
    "Position",
    "Skill",
    "TacticalRole",
    "TacticsConfig",
    "TargetPriority",
    "ThreatEntry",
    # Tank
    "TankTactics",
    "TankTacticsConfig",
    # Melee DPS
    "MeleeDPSTactics",
    "MeleeDPSTacticsConfig",
    # Ranged DPS
    "RangedDPSTactics",
    "RangedDPSTacticsConfig",
    # Magic DPS
    "MagicDPSTactics",
    "MagicDPSTacticsConfig",
    # Support
    "SupportTactics",
    "SupportTacticsConfig",
    # Hybrid
    "HybridTactics",
    "HybridTacticsConfig",
]


# Factory for creating tactics by role
TACTICS_REGISTRY: dict[TacticalRole, type[BaseTactics]] = {
    TacticalRole.TANK: TankTactics,
    TacticalRole.MELEE_DPS: MeleeDPSTactics,
    TacticalRole.RANGED_DPS: RangedDPSTactics,
    TacticalRole.MAGIC_DPS: MagicDPSTactics,
    TacticalRole.SUPPORT: SupportTactics,
    TacticalRole.HYBRID: HybridTactics,
}


def create_tactics(role: TacticalRole | str, config: TacticsConfig | None = None) -> BaseTactics:
    """
    Factory function to create tactics instance by role.
    
    Args:
        role: TacticalRole enum or string name
        config: Optional configuration (uses role default if None)
    
    Returns:
        BaseTactics instance for the specified role
    
    Raises:
        ValueError: If role is not recognized
    """
    if isinstance(role, str):
        try:
            role = TacticalRole(role.lower())
        except ValueError:
            raise ValueError(f"Unknown tactical role: {role}")
    
    tactics_class = TACTICS_REGISTRY.get(role)
    if tactics_class is None:
        raise ValueError(f"No tactics implementation for role: {role}")
    
    return tactics_class(config)


def get_available_roles() -> list[str]:
    """Get list of available tactical roles."""
    return [role.value for role in TacticalRole]


def get_default_role_for_job(job_class: str) -> TacticalRole:
    """
    Get default tactical role for a job class.
    
    Args:
        job_class: Job class name (knight, priest, etc.)
    
    Returns:
        Recommended tactical role
    """
    job_role_mapping = {
        # Tank roles
        "knight": TacticalRole.MELEE_DPS,
        "lord_knight": TacticalRole.MELEE_DPS,
        "crusader": TacticalRole.HYBRID,
        "paladin": TacticalRole.HYBRID,
        
        # Melee DPS roles
        "swordsman": TacticalRole.MELEE_DPS,
        "assassin": TacticalRole.MELEE_DPS,
        "assassin_cross": TacticalRole.MELEE_DPS,
        "rogue": TacticalRole.MELEE_DPS,
        "stalker": TacticalRole.MELEE_DPS,
        
        # Ranged DPS roles
        "archer": TacticalRole.RANGED_DPS,
        "hunter": TacticalRole.RANGED_DPS,
        "sniper": TacticalRole.RANGED_DPS,
        "bard": TacticalRole.HYBRID,
        "dancer": TacticalRole.HYBRID,
        "clown": TacticalRole.HYBRID,
        "gypsy": TacticalRole.HYBRID,
        
        # Magic DPS roles
        "mage": TacticalRole.MAGIC_DPS,
        "wizard": TacticalRole.MAGIC_DPS,
        "high_wizard": TacticalRole.MAGIC_DPS,
        "sage": TacticalRole.HYBRID,
        "professor": TacticalRole.HYBRID,
        
        # Support roles
        "acolyte": TacticalRole.SUPPORT,
        "priest": TacticalRole.SUPPORT,
        "high_priest": TacticalRole.SUPPORT,
        "monk": TacticalRole.MELEE_DPS,
        "champion": TacticalRole.MELEE_DPS,
        
        # Merchant roles
        "merchant": TacticalRole.MELEE_DPS,
        "blacksmith": TacticalRole.MELEE_DPS,
        "whitesmith": TacticalRole.MELEE_DPS,
        "alchemist": TacticalRole.HYBRID,
        "biochemist": TacticalRole.HYBRID,
        
        # Thief roles
        "thief": TacticalRole.MELEE_DPS,
        
        # Default
        "novice": TacticalRole.MELEE_DPS,
    }
    
    return job_role_mapping.get(job_class.lower(), TacticalRole.MELEE_DPS)