"""
Job-Specific Special Mechanics.

This package contains managers for special job mechanics like:
- Spirit Spheres (Monk/Champion/Shura)
- Songs/Dances (Bard/Dancer)
- Traps (Hunter/Sniper/Ranger)
- Poisons (Assassin Cross/Guillotine Cross)
- Runes (Rune Knight)
- Magic Circles (Warlock)
- Doram Forms (Summoner/Spirit Handler)
"""

from ai_sidecar.jobs.mechanics.spirit_spheres import SpiritSphereManager
from ai_sidecar.jobs.mechanics.traps import TrapManager, TrapType
from ai_sidecar.jobs.mechanics.poisons import PoisonManager, PoisonType
from ai_sidecar.jobs.mechanics.runes import RuneManager, RuneType
from ai_sidecar.jobs.mechanics.magic_circles import MagicCircleManager, CircleType
from ai_sidecar.jobs.mechanics.doram import DoramManager, DoramBranch, SpiritType, CompanionType

__all__ = [
    "SpiritSphereManager",
    "TrapManager",
    "TrapType",
    "PoisonManager",
    "PoisonType",
    "RuneManager",
    "RuneType",
    "MagicCircleManager",
    "CircleType",
    "DoramManager",
    "DoramBranch",
    "SpiritType",
    "CompanionType",
]