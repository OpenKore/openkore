"""
IPC Protocol message definitions.

Pydantic models for validating and serializing IPC messages between
OpenKore and the AI Sidecar.
"""

from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator, model_validator


class BaseMessage(BaseModel):
    """Base class for all IPC messages."""
    
    type: str = Field(description="Message type identifier")
    timestamp: int = Field(description="Unix timestamp in milliseconds")


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


class PartyMemberPayload(BaseModel):
    """Party member information (P1 Important - Party Bridge)."""
    char_id: int
    name: str
    hp: int = 0
    hp_max: int = 0
    sp: int = 0
    sp_max: int = 0
    job_class: int = 0
    online: bool = True
    is_leader: bool = False


class PartyPayload(BaseModel):
    """Party information (P1 Important - Party Bridge)."""
    party_id: str = ""
    name: str = ""
    members: list[PartyMemberPayload] = []
    member_count: int = 0


class GuildPayload(BaseModel):
    """Guild information (P1 Important - Guild Bridge)."""
    guild_id: int = 0
    name: str = ""
    level: int = 1
    member_count: int = 0
    max_members: int = 0
    average_level: int = 0
    exp: int = 0
    exp_max: int = 0


class BuffPayload(BaseModel):
    """Active buff information (P1 Important - Buff Bridge)."""
    buff_id: int
    name: str
    expires_at: int = 0
    duration: int = 0


class PetPayload(BaseModel):
    """Pet information (P2 Important - Companion Bridge)."""
    pet_id: int = 0
    name: str = ""
    intimacy: int = 0  # 0-1000
    hunger: int = 0    # 0-100
    is_summoned: bool = False


class HomunculusPayload(BaseModel):
    """Homunculus information (P2 Important - Companion Bridge)."""
    type: str = ""
    level: int = 1
    hp: int = 0
    hp_max: int = 0
    sp: int = 0
    sp_max: int = 0
    intimacy: int = 0
    hunger: int = 0
    skill_points: int = 0
    stats: dict[str, int] = Field(default_factory=dict)


class MercenaryPayload(BaseModel):
    """Mercenary information (P2 Important - Companion Bridge)."""
    type: str = ""
    level: int = 1
    hp: int = 0
    hp_max: int = 0
    sp: int = 0
    sp_max: int = 0
    contract_remaining: int = 0
    faith: int = 0


class MountPayload(BaseModel):
    """Mount and cart information (P2 Important - Companion Bridge)."""
    is_mounted: bool = False
    mount_type: int = 0
    has_cart: bool = False
    cart_weight: int = 0
    cart_weight_max: int = 0
    cart_items_count: int = 0


class EquippedItemPayload(BaseModel):
    """Equipped item information (P2 Important - Equipment Bridge)."""
    item_id: int
    name: str
    refine_level: int = 0
    broken: bool = False
    identified: bool = True


class DialogueChoicePayload(BaseModel):
    """NPC dialogue choice (P3 Advanced - NPC Bridge)."""
    index: int
    text: str


class NPCDialoguePayload(BaseModel):
    """NPC dialogue state (P3 Advanced - NPC Bridge)."""
    npc_id: int
    npc_name: str
    in_dialogue: bool
    has_choices: bool = False
    choices: list[DialogueChoicePayload] = []
    current_text: str = ""


class QuestObjectivePayload(BaseModel):
    """Quest objective (mob or item) (P3 Advanced - Quest Bridge)."""
    type: str  # "mob" or "item"
    target_id: int
    count_current: int = 0
    count_required: int = 0


class QuestPayload(BaseModel):
    """Active quest information (P3 Advanced - Quest Bridge)."""
    quest_id: int
    name: str
    time_limit: int = 0
    mob_objectives: list = []
    item_objectives: list = []
    is_complete: bool = False


class QuestStatePayload(BaseModel):
    """All quest information (P3 Advanced - Quest Bridge)."""
    active_quests: list[QuestPayload] = []
    quest_count: int = 0


class VendorItemPayload(BaseModel):
    """Item in vendor shop (P3 Advanced - Economy Bridge)."""
    item_id: int
    name: str
    price: int
    amount: int


class VendorPayload(BaseModel):
    """Player vendor shop (P3 Advanced - Economy Bridge)."""
    vendor_id: int
    vendor_name: str
    position: dict[str, int] = Field(default_factory=lambda: {"x": 0, "y": 0})
    items: list[VendorItemPayload] = []


class MarketStatePayload(BaseModel):
    """Market/vendor information (P3 Advanced - Economy Bridge)."""
    vendors: list[VendorPayload] = []
    vendor_count: int = 0


class EnvironmentPayload(BaseModel):
    """Environment/time state (P3 Advanced - Environment Bridge)."""
    server_time: int
    is_night: bool = False
    weather_type: int = 0


class GroundItemPayload(BaseModel):
    """Item on ground (P3 Advanced - Ground Items Bridge)."""
    id: int
    item_id: int
    name: str
    amount: int = 1
    position: dict[str, int] = Field(default_factory=lambda: {"x": 0, "y": 0})


class InstancePayload(BaseModel):
    """Instance/dungeon state (P4 Final - Instance Bridge)."""
    in_instance: bool = False
    instance_name: str = ""
    current_floor: int = 0
    time_limit: int = 0


class StatusEffectPayload(BaseModel):
    """Status effect (buff or debuff) (P1 Important - Combat Bridge)."""
    effect_id: int
    name: str
    is_negative: bool = False
    duration: int = 0


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
    
    # Enhanced status effects (P1 Important - Combat Bridge)
    status_effects: list[StatusEffectPayload] = Field(default_factory=list)
    
    # Active buffs (P1 Important - Buff Bridge)
    buffs: list[BuffPayload] = Field(default_factory=list)
    
    # Character Stats (P0 Critical - Progression Bridge)
    stat_str: int = Field(default=0, alias="str")  # 'str' is reserved keyword
    agi: int = 0
    vit: int = 0
    int_stat: int = Field(default=0, alias="int")  # 'int' is reserved keyword
    dex: int = 0
    luk: int = 0
    
    # Experience (P0 Critical - Progression Bridge)
    base_exp: int = 0
    base_exp_max: int = 0
    job_exp: int = 0
    job_exp_max: int = 0
    
    # Points (P0 Critical - Progression Bridge)
    stat_points: int = 0
    skill_points: int = 0
    
    # Skills (P0 Critical - Combat Bridge)
    learned_skills: dict[str, dict[str, int]] = Field(default_factory=dict)


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
    
    # P1 bridges
    party: PartyPayload | None = None
    guild: GuildPayload | None = None
    
    # P2 bridges
    pet: PetPayload | None = None
    homunculus: HomunculusPayload | None = None
    mercenary: MercenaryPayload | None = None
    mount: MountPayload = Field(default_factory=MountPayload)
    equipment: dict[str, EquippedItemPayload] = Field(default_factory=dict)
    
    # P3 bridges (NEW)
    npc_dialogue: NPCDialoguePayload | None = None
    quests: QuestStatePayload = Field(default_factory=QuestStatePayload)
    market: MarketStatePayload = Field(default_factory=MarketStatePayload)
    environment: EnvironmentPayload = Field(default_factory=lambda: EnvironmentPayload(server_time=0))
    ground_items: list[GroundItemPayload] = Field(default_factory=list)
    
    # P4 Final bridge - Instance
    instance: InstancePayload = Field(default_factory=InstancePayload)
    
    extra: dict = Field(default_factory=dict)


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
    extra: dict[str, Any] = Field(default_factory=dict, description="Extra action data")
    
    @model_validator(mode='before')
    @classmethod
    def convert_action_type_field(cls, data: Any) -> Any:
        """Convert action_type to type for backwards compatibility."""
        if isinstance(data, dict):
            data = data.copy()
            if 'action_type' in data and 'type' not in data:
                action_type = data.pop('action_type')
                # Convert enum to string if needed
                if hasattr(action_type, 'value'):
                    data['type'] = action_type.value
                else:
                    data['type'] = str(action_type)
        return data


# Aliases for backwards compatibility
ActionModel = ActionPayload
Action = ActionPayload  # Legacy alias


class ActionType(str, Enum):
    """Action types for backwards compatibility."""
    NOOP = "noop"
    MOVE = "move"
    ATTACK = "attack"
    SKILL = "skill"
    ITEM = "item"
    SIT = "sit"
    STAND = "stand"


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


# Aliases for backwards compatibility with generate_* naming
generate_state_update_schema = get_state_update_schema
generate_decision_response_schema = get_decision_response_schema
generate_heartbeat_schema = get_heartbeat_schema