"""
Social features module for AI Sidecar.

Provides party coordination, guild management, chat processing,
and MVP hunting capabilities for Ragnarok Online.
"""

from ai_sidecar.social.chat_manager import ChatManager
from ai_sidecar.social.chat_models import (
    AutoResponse,
    ChatChannel,
    ChatCommand,
    ChatFilter,
    ChatMessage,
)
from ai_sidecar.social.guild_manager import GuildManager
from ai_sidecar.social.guild_models import (
    Guild,
    GuildMember,
    GuildPosition,
    GuildStorage,
    GuildWoESchedule,
)
from ai_sidecar.social.manager import SocialManager
from ai_sidecar.social.mvp_manager import MVPManager
from ai_sidecar.social.mvp_models import (
    MVPBoss,
    MVPDatabase,
    MVPHuntingStrategy,
    MVPSpawnRecord,
    MVPTracker,
)
from ai_sidecar.social.party_manager import PartyManager
from ai_sidecar.social.party_models import (
    Party,
    PartyMember,
    PartyRole,
    PartySettings,
)

__all__ = [
    # Main manager
    "SocialManager",
    # Managers
    "PartyManager",
    "GuildManager",
    "ChatManager",
    "MVPManager",
    # Party models
    "Party",
    "PartyMember",
    "PartyRole",
    "PartySettings",
    # Guild models
    "Guild",
    "GuildMember",
    "GuildPosition",
    "GuildStorage",
    "GuildWoESchedule",
    # Chat models
    "ChatMessage",
    "ChatChannel",
    "ChatFilter",
    "AutoResponse",
    "ChatCommand",
    # MVP models
    "MVPBoss",
    "MVPTracker",
    "MVPSpawnRecord",
    "MVPHuntingStrategy",
    "MVPDatabase",
]