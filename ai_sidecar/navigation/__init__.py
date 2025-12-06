"""
Navigation package for AI Sidecar.

Provides cross-map navigation capabilities including:
- Portal database and graph building
- Dijkstra pathfinding for optimal routes
- Navigation action generation
- Kafra teleport, warp NPC, and item usage support
"""

from ai_sidecar.navigation.models import (
    Portal,
    PortalType,
    KafraDestination,
    WarpNPC,
    NavigationPreference,
    NavigationRoute,
    NavigationStep,
    NavigationState,
)
from ai_sidecar.navigation.portal_database import PortalDatabase
from ai_sidecar.navigation.pathfinder import NavigationPathfinder
from ai_sidecar.navigation.navigator import NavigationService

__all__ = [
    # Models
    "Portal",
    "PortalType",
    "KafraDestination",
    "WarpNPC",
    "NavigationPreference",
    "NavigationRoute",
    "NavigationStep",
    "NavigationState",
    # Services
    "PortalDatabase",
    "NavigationPathfinder",
    "NavigationService",
]