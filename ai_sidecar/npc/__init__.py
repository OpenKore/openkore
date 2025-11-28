"""
NPC Interaction and Quest Handling System.

This module provides comprehensive NPC interaction capabilities including:
- Dialogue parsing and response selection
- Quest tracking and completion
- Service NPC handling (Kafra, refiner, etc.)
- Intelligent interaction orchestration

Integrates with the decision engine to provide autonomous NPC interactions.
"""

from ai_sidecar.npc.manager import NPCManager
from ai_sidecar.npc.models import (
    DialogueChoice,
    DialogueState,
    NPC,
    NPCDatabase,
    NPCType,
    ServiceNPC,
    ServiceNPCDatabase,
)
from ai_sidecar.npc.quest_models import (
    Quest,
    QuestDatabase,
    QuestLog,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
)

__all__ = [
    # Manager
    "NPCManager",
    # NPC Models
    "NPC",
    "NPCType",
    "NPCDatabase",
    "ServiceNPC",
    "ServiceNPCDatabase",
    "DialogueState",
    "DialogueChoice",
    # Quest Models
    "Quest",
    "QuestObjective",
    "QuestObjectiveType",
    "QuestReward",
    "QuestLog",
    "QuestDatabase",
]