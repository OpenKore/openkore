"""
Guild-related data models for social features.

Defines Pydantic v2 models for guild management, member tracking,
WoE coordination, and storage in Ragnarok Online.
"""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class GuildPosition(BaseModel):
    """Guild position with permissions."""
    
    position_id: int = Field(description="Position ID (0-19)")
    name: str = Field(description="Position name")
    can_invite: bool = Field(default=False, description="Can invite members")
    can_kick: bool = Field(default=False, description="Can kick members")
    can_storage: bool = Field(default=False, description="Can use guild storage")
    can_notice: bool = Field(default=False, description="Can change guild notice")
    tax_rate: int = Field(default=0, ge=0, le=100, description="EXP tax percentage")


class GuildMember(BaseModel):
    """Guild member with rank and contributions."""
    
    account_id: int = Field(description="Account ID")
    char_id: int = Field(description="Character ID")
    name: str = Field(description="Character name")
    position: GuildPosition = Field(description="Guild position/rank")
    job_class: str = Field(default="", description="Job class name")
    base_level: int = Field(default=1, ge=1, le=999, description="Base level")
    
    # Contributions
    exp_donated: int = Field(default=0, ge=0, description="Total EXP donated to guild")
    guild_skills_points: int = Field(
        default=0,
        ge=0,
        description="Contribution to guild skill points"
    )
    
    # Status
    is_online: bool = Field(default=False, description="Currently online")
    last_online: datetime | None = Field(
        default=None,
        description="Last online timestamp"
    )
    
    # Relationship tracking (for AI decision-making)
    trust_level: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="AI trust level for this member (0-1)"
    )


class GuildWoESchedule(BaseModel):
    """War of Emperium schedule entry."""
    
    day_of_week: int = Field(ge=0, le=6, description="Day (0=Sunday, 6=Saturday)")
    start_hour: int = Field(ge=0, le=23, description="Start hour (24h format)")
    end_hour: int = Field(ge=0, le=23, description="End hour (24h format)")
    map_name: str = Field(description="WoE map name")
    castle_name: str = Field(description="Castle name")


class Guild(BaseModel):
    """Guild with full management capabilities."""
    
    guild_id: int = Field(description="Unique guild ID")
    name: str = Field(description="Guild name")
    master_id: int = Field(description="Guild master character ID")
    master_name: str = Field(description="Guild master name")
    
    # Stats
    level: int = Field(default=1, ge=1, description="Guild level")
    exp: int = Field(default=0, ge=0, description="Current guild EXP")
    average_level: float = Field(default=0.0, ge=0.0, description="Average member level")
    member_count: int = Field(default=0, ge=0, description="Current member count")
    max_members: int = Field(default=16, ge=16, description="Max member capacity")
    
    # Members
    members: list[GuildMember] = Field(
        default_factory=list,
        description="Guild members"
    )
    positions: list[GuildPosition] = Field(
        default_factory=list,
        description="Guild positions/ranks"
    )
    
    # Guild Skills
    skills: dict[str, int] = Field(
        default_factory=dict,
        description="Guild skills (skill_id -> level)"
    )
    
    # WoE
    owned_castles: list[str] = Field(
        default_factory=list,
        description="Castle names owned by guild"
    )
    woe_schedule: list[GuildWoESchedule] = Field(
        default_factory=list,
        description="WoE schedule entries"
    )
    
    # Diplomacy
    allied_guilds: list[int] = Field(
        default_factory=list,
        description="Allied guild IDs"
    )
    enemy_guilds: list[int] = Field(
        default_factory=list,
        description="Enemy guild IDs"
    )
    
    def get_member_by_id(self, char_id: int) -> GuildMember | None:
        """Get guild member by character ID."""
        for member in self.members:
            if member.char_id == char_id:
                return member
        return None
    
    def get_online_members(self) -> list[GuildMember]:
        """Get list of online members."""
        return [m for m in self.members if m.is_online]
    
    def has_skill(self, skill_id: str) -> bool:
        """Check if guild has a specific skill."""
        return skill_id in self.skills and self.skills[skill_id] > 0
    
    def get_skill_level(self, skill_id: str) -> int:
        """Get level of a guild skill."""
        return self.skills.get(skill_id, 0)
    
    def is_master(self, char_id: int) -> bool:
        """Check if character is guild master."""
        return char_id == self.master_id
    
    def can_use_storage(self, char_id: int) -> bool:
        """Check if member can use guild storage."""
        member = self.get_member_by_id(char_id)
        return member is not None and member.position.can_storage


class GuildStorage(BaseModel):
    """Guild storage access and items."""
    
    max_capacity: int = Field(default=100, ge=1, description="Maximum item slots")
    items: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Items in storage (item dictionaries)"
    )
    access_log: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Storage access history"
    )
    
    def get_item_count(self) -> int:
        """Get current number of items in storage."""
        return len(self.items)
    
    def is_full(self) -> bool:
        """Check if storage is at capacity."""
        return self.get_item_count() >= self.max_capacity
    
    def has_space(self, count: int = 1) -> bool:
        """Check if storage has space for count items."""
        return self.get_item_count() + count <= self.max_capacity
    
    def log_access(
        self,
        char_id: int,
        char_name: str,
        action: str,
        item_id: int | None = None,
        amount: int = 0
    ) -> None:
        """Log a storage access event."""
        self.access_log.append({
            "timestamp": datetime.now().isoformat(),
            "char_id": char_id,
            "char_name": char_name,
            "action": action,
            "item_id": item_id,
            "amount": amount,
        })
        # Keep only last 100 entries
        if len(self.access_log) > 100:
            self.access_log = self.access_log[-100:]