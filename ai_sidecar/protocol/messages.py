"""
IPC Protocol message definitions.

Pydantic models for validating and serializing IPC messages between
OpenKore and the AI Sidecar.
"""

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field


class MessageType(str, Enum):
    """Types of IPC messages."""
    
    # From OpenKore to Sidecar
    STATE_UPDATE = "state_update"
    HEARTBEAT = "heartbeat"
    
    # From Sidecar to OpenKore
    DECISION = "decision"
    HEARTBEAT_ACK = "heartbeat_ack"
    ERROR = "error"
    ACK = "ack"


class CharacterPayload(BaseModel):
    """Character data in state update."""
    
    name: str = ""
    job_id: int = 0
    base_level: int = 1
    job_level: int = 1
    hp: int = 0
    hp_max: int = 1
    sp: int = 0
    sp_max: int = 1
    position: dict[str, int] = Field(default_factory=lambda: {"x": 0, "y": 0})
    moving: bool = False
    sitting: bool = False
    attacking: bool = False
    target_id: int | None = None
    status_effects: list[int] = Field(default_factory=list)


class ActorPayload(BaseModel):
    """Single actor in state update."""
    
    id: int
    type: int = 0
    name: str = ""
    position: dict[str, int] = Field(default_factory=lambda: {"x": 0, "y": 0})
    hp: int | None = None
    hp_max: int | None = None
    moving: bool = False
    attacking: bool = False
    target_id: int | None = None
    mob_id: int | None = None


class InventoryItemPayload(BaseModel):
    """Single inventory item."""
    
    index: int
    item_id: int
    name: str = ""
    amount: int = 1
    equipped: bool = False


class MapPayload(BaseModel):
    """Map data in state update."""
    
    name: str = ""
    width: int = 0
    height: int = 0


class StatePayload(BaseModel):
    """Full state payload from OpenKore."""
    
    character: CharacterPayload = Field(default_factory=CharacterPayload)
    actors: list[ActorPayload] = Field(default_factory=list)
    inventory: list[InventoryItemPayload] = Field(default_factory=list)
    map: MapPayload = Field(default_factory=MapPayload)
    ai_mode: int = 1


class StateUpdateMessage(BaseModel):
    """
    State update message from OpenKore.
    
    Sent on each AI tick with current game state.
    """
    
    type: Literal["state_update"] = "state_update"
    timestamp: int = Field(description="Unix timestamp in milliseconds")
    tick: int = Field(ge=0, description="Server tick number")
    payload: StatePayload = Field(default_factory=StatePayload)
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "StateUpdateMessage":
        """Parse from raw dictionary."""
        return cls.model_validate(data)


class ActionPayload(BaseModel):
    """Single action in decision response."""
    
    type: str = Field(description="Action type")
    priority: int = Field(default=5, ge=1, le=10)
    target: int | None = Field(default=None, description="Target actor ID")
    x: int | None = Field(default=None, description="X coordinate")
    y: int | None = Field(default=None, description="Y coordinate")
    skill_id: int | None = Field(default=None)
    skill_level: int | None = Field(default=None)
    item_id: int | None = Field(default=None)
    item_index: int | None = Field(default=None)


class DecisionResponseMessage(BaseModel):
    """
    Decision response message from AI Sidecar.
    
    Contains actions for OpenKore to execute.
    """
    
    type: Literal["decision"] = "decision"
    timestamp: int = Field(description="Unix timestamp in milliseconds")
    tick: int = Field(ge=0, description="Corresponding game tick")
    actions: list[ActionPayload] = Field(default_factory=list)
    fallback_mode: Literal["cpu", "idle", "defensive"] = "cpu"
    processing_time_ms: float = Field(default=0.0)
    confidence: float = Field(default=1.0, ge=0.0, le=1.0)
    
    def to_json_dict(self) -> dict[str, Any]:
        """Convert to JSON-serializable dictionary."""
        return self.model_dump()


class HeartbeatMessage(BaseModel):
    """
    Heartbeat message from OpenKore.
    
    Used for connection health checking.
    """
    
    type: Literal["heartbeat"] = "heartbeat"
    timestamp: int = Field(description="Unix timestamp in milliseconds")
    tick: int = Field(default=0, ge=0)
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "HeartbeatMessage":
        """Parse from raw dictionary."""
        return cls.model_validate(data)


class HeartbeatAckMessage(BaseModel):
    """
    Heartbeat acknowledgment from AI Sidecar.
    """
    
    type: Literal["heartbeat_ack"] = "heartbeat_ack"
    timestamp: int = Field(description="Unix timestamp in milliseconds")
    client_tick: int = Field(default=0)
    messages_processed: int = Field(default=0)
    errors: int = Field(default=0)
    status: Literal["healthy", "degraded", "unhealthy"] = "healthy"


class ErrorPayload(BaseModel):
    """Error details."""
    
    type: str = Field(description="Error type identifier")
    message: str = Field(description="Human-readable error message")
    code: int | None = Field(default=None, description="Optional error code")


class ErrorMessage(BaseModel):
    """
    Error response from AI Sidecar.
    """
    
    type: Literal["error"] = "error"
    timestamp: int = Field(description="Unix timestamp in milliseconds")
    error: ErrorPayload
    fallback_mode: Literal["cpu", "idle", "defensive"] = "cpu"


# Schema exports for JSON Schema generation
def get_state_update_schema() -> dict[str, Any]:
    """Get JSON Schema for state update message."""
    return StateUpdateMessage.model_json_schema()


def get_decision_response_schema() -> dict[str, Any]:
    """Get JSON Schema for decision response message."""
    return DecisionResponseMessage.model_json_schema()


def get_heartbeat_schema() -> dict[str, Any]:
    """Get JSON Schema for heartbeat message."""
    return HeartbeatMessage.model_json_schema()