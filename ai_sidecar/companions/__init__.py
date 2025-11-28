"""
Companion Systems Module for AI Sidecar.

Provides intelligent management for all companion types in Ragnarok Online:
- Pets: Intimacy optimization, evolution tracking, performance-based selection
- Homunculus: Stat/skill builds, S-evolution paths, tactical AI
- Mercenaries: Type selection, skill coordination, faith management
- Mounts: Auto-mount/dismount, fuel management, cart optimization

All modules use Pydantic v2 models with async/await patterns.
"""

from ai_sidecar.companions.coordinator import CompanionCoordinator
from ai_sidecar.companions.homunculus import (
    HomunculusManager,
    HomunculusState,
    HomunculusType,
)
from ai_sidecar.companions.mercenary import (
    MercenaryManager,
    MercenaryState,
    MercenaryType,
)
from ai_sidecar.companions.mount import MountManager, MountState, MountType
from ai_sidecar.companions.pet import PetManager, PetState, PetType

__all__ = [
    # Coordinator
    "CompanionCoordinator",
    # Pet
    "PetManager",
    "PetState",
    "PetType",
    # Homunculus
    "HomunculusManager",
    "HomunculusState",
    "HomunculusType",
    # Mercenary
    "MercenaryManager",
    "MercenaryState",
    "MercenaryType",
    # Mount
    "MountManager",
    "MountState",
    "MountType",
]