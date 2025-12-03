"""IPC Protocol definitions for AI Sidecar communication."""

from .messages import (
    # Base
    BaseMessage,
    MessageType,
    # Messages
    StateUpdateMessage,
    DecisionResponseMessage,
    HeartbeatMessage,
    HeartbeatAckMessage,
    ErrorMessage,
    # Payloads
    ActionPayload,
    ActionModel,  # Alias for ActionPayload
    Action,  # Legacy alias
    ActionType,  # Legacy enum
    CharacterPayload,
    ActorPayload,
    InventoryItemPayload,
    MapPayload,
    StatePayload,
    ErrorPayload,
    # Schema generators
    get_state_update_schema,
    get_decision_response_schema,
    get_heartbeat_schema,
    # Aliases
    generate_state_update_schema,
    generate_decision_response_schema,
    generate_heartbeat_schema,
)

__all__ = [
    # Base
    "BaseMessage",
    "MessageType",
    # Messages
    "StateUpdateMessage",
    "DecisionResponseMessage",
    "HeartbeatMessage",
    "HeartbeatAckMessage",
    "ErrorMessage",
    # Payloads
    "ActionPayload",
    "ActionModel",
    "Action",  # Legacy alias
    "ActionType",  # Legacy enum
    "CharacterPayload",
    "ActorPayload",
    "InventoryItemPayload",
    "MapPayload",
    "StatePayload",
    "ErrorPayload",
    # Schema generators
    "get_state_update_schema",
    "get_decision_response_schema",
    "get_heartbeat_schema",
    "generate_state_update_schema",
    "generate_decision_response_schema",
    "generate_heartbeat_schema",
]