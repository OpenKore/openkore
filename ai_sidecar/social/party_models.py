"""
Party-related data models for social features.

Defines Pydantic v2 models for party coordination, member tracking,
and role assignment in Ragnarok Online.
"""

from datetime import datetime
from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


class PartyRole(str, Enum):
    """Roles within a party."""
    
    LEADER = "leader"
    TANK = "tank"
    HEALER = "healer"
    DPS_MELEE = "dps_melee"
    DPS_RANGED = "dps_ranged"
    DPS_MAGIC = "dps_magic"
    SUPPORT = "support"
    FLEX = "flex"


class PartyMember(BaseModel):
    """Party member with role and status."""
    
    account_id: int = Field(description="Account ID")
    char_id: int = Field(description="Character ID")
    name: str = Field(description="Character name")
    job_class: str = Field(description="Job class name")
    base_level: int = Field(ge=1, le=999, description="Base level")
    
    # Status
    hp: int = Field(default=0, ge=0, description="Current HP")
    hp_max: int = Field(default=1, ge=1, description="Maximum HP")
    sp: int = Field(default=0, ge=0, description="Current SP")
    sp_max: int = Field(default=1, ge=1, description="Maximum SP")
    map_name: str = Field(default="", description="Current map")
    x: int = Field(default=0, ge=0, description="X coordinate")
    y: int = Field(default=0, ge=0, description="Y coordinate")
    is_online: bool = Field(default=True, description="Is currently online")
    
    # Role assignment
    assigned_role: PartyRole = Field(
        default=PartyRole.FLEX,
        description="Assigned party role"
    )
    is_leader: bool = Field(default=False, description="Is party leader")
    
    @property
    def hp_percent(self) -> float:
        """Calculate HP percentage."""
        return (self.hp / self.hp_max * 100) if self.hp_max > 0 else 0.0
    
    @property
    def sp_percent(self) -> float:
        """Calculate SP percentage."""
        return (self.sp / self.sp_max * 100) if self.sp_max > 0 else 0.0
    
    @property
    def needs_healing(self) -> bool:
        """Check if member needs healing (< 70% HP)."""
        return self.hp_percent < 70.0


class PartySettings(BaseModel):
    """Party configuration settings."""
    
    exp_share_type: Literal["equal", "each_take"] = Field(
        default="equal",
        description="EXP distribution method"
    )
    item_share_type: Literal["equal", "each_take"] = Field(
        default="each_take",
        description="Item distribution method"
    )
    auto_accept_invites: bool = Field(
        default=False,
        description="Automatically accept party invites"
    )
    follow_leader: bool = Field(
        default=True,
        description="Follow party leader automatically"
    )
    protect_leader: bool = Field(
        default=True,
        description="Prioritize protecting leader"
    )
    share_buff_priority: list[str] = Field(
        default_factory=lambda: ["healer", "support", "dps"],
        description="Priority order for sharing buffs"
    )


class Party(BaseModel):
    """Party with members and coordination state."""
    
    party_id: int = Field(description="Unique party ID")
    name: str = Field(description="Party name")
    leader_id: int = Field(description="Leader character ID")
    members: list[PartyMember] = Field(
        default_factory=list,
        description="Party members"
    )
    settings: PartySettings = Field(
        default_factory=PartySettings,
        description="Party settings"
    )
    
    # State
    created_at: datetime = Field(
        default_factory=datetime.now,
        description="Party creation timestamp"
    )
    is_in_dungeon: bool = Field(
        default=False,
        description="Currently in a dungeon"
    )
    current_activity: Literal[
        "grinding", "mvp_hunting", "dungeon", "questing", "idle"
    ] = Field(
        default="idle",
        description="Current party activity"
    )
    
    @property
    def member_count(self) -> int:
        """Get total member count."""
        return len(self.members)
    
    @property
    def online_members(self) -> list[PartyMember]:
        """Get list of online members."""
        return [m for m in self.members if m.is_online]
    
    def get_member_by_role(self, role: PartyRole) -> list[PartyMember]:
        """Get all members with a specific role."""
        return [m for m in self.members if m.assigned_role == role]
    
    def get_healers(self) -> list[PartyMember]:
        """Get all healer members."""
        return self.get_member_by_role(PartyRole.HEALER)
    
    def get_tanks(self) -> list[PartyMember]:
        """Get all tank members."""
        return self.get_member_by_role(PartyRole.TANK)
    
    def get_leader(self) -> PartyMember | None:
        """Get the party leader."""
        for member in self.members:
            if member.char_id == self.leader_id:
                return member
        return None
    
    def get_member_by_id(self, char_id: int) -> PartyMember | None:
        """Get member by character ID."""
        for member in self.members:
            if member.char_id == char_id:
                return member
        return None
    
    def has_role(self, role: PartyRole) -> bool:
        """Check if party has at least one member with specified role."""
        return len(self.get_member_by_role(role)) > 0