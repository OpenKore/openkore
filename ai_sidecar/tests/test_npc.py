"""
Tests for NPC models and database operations.
"""

import pytest
from datetime import datetime

from ai_sidecar.npc.models import (
    NPC,
    NPCType,
    NPCDatabase,
    ServiceNPC,
    ServiceNPCDatabase,
    DialogueState,
    DialogueChoice,
)


class TestNPCModels:
    """Test NPC model functionality."""

    def test_npc_creation(self):
        """Test creating an NPC."""
        npc = NPC(
            npc_id=1001,
            name="Test NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180,
            quests=[1, 2, 3],
        )

        assert npc.npc_id == 1001
        assert npc.name == "Test NPC"
        assert npc.npc_type == NPCType.QUEST
        assert npc.quests == [1, 2, 3]

    def test_npc_distance_calculation(self):
        """Test distance calculation."""
        npc = NPC(
            npc_id=1001,
            name="Test NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180,
        )

        # Same position
        assert npc.distance_to(150, 180) == 0.0

        # Distance of 5
        assert npc.distance_to(150, 185) == 5.0

        # Diagonal distance
        assert npc.distance_to(153, 184) == 5.0

    def test_npc_is_near(self):
        """Test proximity check."""
        npc = NPC(
            npc_id=1001,
            name="Test NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180,
        )

        assert npc.is_near(150, 180, threshold=5) is True
        assert npc.is_near(150, 185, threshold=5) is True
        assert npc.is_near(150, 186, threshold=5) is False


class TestDialogueState:
    """Test dialogue state management."""

    def test_dialogue_state_creation(self):
        """Test creating dialogue state."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Test NPC",
            current_text="Hello, adventurer!",
            waiting_for_input=True,
            input_type="choice",
        )

        assert dialogue.npc_id == 1001
        assert dialogue.npc_name == "Test NPC"
        assert dialogue.waiting_for_input is True
        assert dialogue.input_type == "choice"

    def test_dialogue_history(self):
        """Test dialogue history management."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Test NPC",
            current_text="Hello!",
        )

        dialogue.add_to_history("First message")
        dialogue.add_to_history("Second message")

        assert len(dialogue.history) == 2
        assert dialogue.history[0] == "First message"

    def test_dialogue_history_limit(self):
        """Test dialogue history size limit."""
        dialogue = DialogueState(
            npc_id=1001,
            npc_name="Test NPC",
            current_text="Hello!",
        )

        # Add 25 messages (should keep only last 20)
        for i in range(25):
            dialogue.add_to_history(f"Message {i}")

        assert len(dialogue.history) == 20
        assert dialogue.history[0] == "Message 5"
        assert dialogue.history[-1] == "Message 24"


class TestNPCDatabase:
    """Test NPC database operations."""

    def test_add_and_get_npc(self):
        """Test adding and retrieving NPCs."""
        db = NPCDatabase()

        npc = NPC(
            npc_id=1001,
            name="Test NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180,
        )

        db.add_npc(npc)

        retrieved = db.get_npc(1001)
        assert retrieved is not None
        assert retrieved.name == "Test NPC"

    def test_get_npcs_by_map(self):
        """Test retrieving NPCs by map."""
        db = NPCDatabase()

        npc1 = NPC(
            npc_id=1001,
            name="Prontera NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180,
        )
        npc2 = NPC(
            npc_id=1002,
            name="Geffen NPC",
            npc_type=NPCType.SHOP,
            map_name="geffen",
            x=120,
            y=60,
        )

        db.add_npc(npc1)
        db.add_npc(npc2)

        prontera_npcs = db.get_npcs_on_map("prontera")
        assert len(prontera_npcs) == 1
        assert prontera_npcs[0].name == "Prontera NPC"

    def test_find_nearest_service(self):
        """Test finding nearest service NPC."""
        db = NPCDatabase()

        service1 = ServiceNPC(
            npc_id=2001,
            name="Kafra 1",
            service_type="kafra",
            map_name="prontera",
            x=150,
            y=180,
        )
        service2 = ServiceNPC(
            npc_id=2002,
            name="Kafra 2",
            service_type="kafra",
            map_name="prontera",
            x=200,
            y=200,
        )

        db.add_service_npc(service1)
        db.add_service_npc(service2)

        # Closer to first Kafra
        nearest = db.find_nearest_service("kafra", "prontera", 150, 180)
        assert nearest is not None
        assert nearest.name == "Kafra 1"

        # Closer to second Kafra
        nearest = db.find_nearest_service("kafra", "prontera", 200, 200)
        assert nearest is not None
        assert nearest.name == "Kafra 2"


class TestServiceNPCDatabase:
    """Test service NPC database operations."""

    def test_add_service_npc(self):
        """Test adding service NPCs."""
        db = ServiceNPCDatabase()

        kafra = ServiceNPC(
            npc_id=2001,
            name="Kafra Employee",
            service_type="kafra",
            map_name="prontera",
            x=150,
            y=180,
        )

        db.add_service_npc(kafra)

        npcs = db.get_service_npcs("kafra", "prontera")
        assert len(npcs) == 1
        assert npcs[0].name == "Kafra Employee"

    def test_find_nearest_service_npc(self):
        """Test finding nearest service NPC."""
        db = ServiceNPCDatabase()

        kafra1 = ServiceNPC(
            npc_id=2001,
            name="Kafra 1",
            service_type="kafra",
            map_name="prontera",
            x=150,
            y=180,
        )
        kafra2 = ServiceNPC(
            npc_id=2002,
            name="Kafra 2",
            service_type="kafra",
            map_name="prontera",
            x=200,
            y=200,
        )

        db.add_service_npc(kafra1)
        db.add_service_npc(kafra2)

        nearest = db.find_nearest("kafra", "prontera", 145, 175)
        assert nearest is not None
        assert nearest.name == "Kafra 1"