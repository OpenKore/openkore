"""IPC Protocol definitions for AI Sidecar communication."""

from .messages import (
    BaseMessage,
    StateUpdateMessage,
    DecisionResponseMessage,
    HeartbeatMessage,
    ErrorMessage,
    ActionModel,
    CharacterPayload,
    ActorPayload,
    InventoryItemPayload,
    MapPayload,
    StatePayload,
    generate_state_update_schema,
    generate_decision_response_schema,
    generate_heartbeat_schema,
)

__all__ = [
    "BaseMessage",
    "StateUpdateMessage",
    "DecisionResponseMessage",
    "HeartbeatMessage",
    "ErrorMessage",
    "ActionModel",
    "CharacterPayload",
    "ActorPayload",
    "InventoryItemPayload",
    "MapPayload",
    "StatePayload",
    "generate_state_update_schema",
    "generate_decision_response_schema",
    "generate_heartbeat_schema",
]