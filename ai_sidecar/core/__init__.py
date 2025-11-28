"""
Core package for AI Sidecar.

Contains the game state representation, decision engine interface,
and tick processor for the AI decision loop.
"""

from ai_sidecar.core.state import GameState, CharacterState, ActorState, MapState
from ai_sidecar.core.decision import DecisionEngine, Action, DecisionResult
from ai_sidecar.core.tick import TickProcessor

__all__ = [
    "GameState",
    "CharacterState",
    "ActorState",
    "MapState",
    "DecisionEngine",
    "Action",
    "DecisionResult",
    "TickProcessor",
]