"""
Tests for service NPC interactions.
"""

import pytest

from ai_sidecar.core.state import GameState, CharacterState, Position, MapState
from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.npc.models import ServiceNPC, ServiceNPCDatabase


class TestServiceHandler:
    """Test service handler functionality."""

    def setup_method(self):
        """Set up test fixtures."""
        self.handler = ServiceHandler()

    def test_estimate_service_cost(self):
        """Test service cost estimation."""
        # Base storage cost
        cost = self.handler.estimate_service_cost("storage")
        assert cost == 60

        # Base teleport cost
        cost = self.handler.estimate_service_cost("teleport")
        assert cost == 600

        # Save is free
        cost = self.handler.estimate_service_cost("save")
        assert cost == 0

    def test_estimate_refine_cost(self):
        """Test refine cost estimation with scaling."""
        # Low level refine
        cost = self.handler.estimate_service_cost("refine", current_refine=0)
        assert cost == 2000

        # Higher level refine (should scale up)
        cost = self.handler.estimate_service_cost("refine", current_refine=5)
        assert cost == 4000  # 2000 * 2^(5//5) = 2000 * 2

        cost = self.handler.estimate_service_cost("refine", current_refine=10)
        assert cost == 8000  # 2000 * 2^(10//5) = 2000 * 4

    @pytest.mark.asyncio
    async def test_use_storage_no_kafra(self):
        """Test storage usage when no Kafra is available."""
        game_state = GameState(
            character=CharacterState(
                name="Test",
                job_id=0,
                position=Position(x=150, y=180),
            ),
            map=MapState(name="prontera"),
        )

        actions = await self.handler.use_storage(game_state)
        assert len(actions) == 0  # No Kafra found

    @pytest.mark.asyncio
    async def test_use_storage_insufficient_zeny(self):
        """Test storage usage with insufficient zeny."""
        # Add Kafra to database
        kafra = ServiceNPC(
            npc_id=2001,
            name="Kafra Employee",
            service_type="kafra",
            map_name="prontera",
            x=150,
            y=180,
        )
        self.handler.service_db.add_service_npc(kafra)

        game_state = GameState(
            character=CharacterState(
                name="Test",
                job_id=0,
                position=Position(x=150, y=180),
                zeny=50,  # Not enough for storage
            ),
            map=MapState(name="prontera"),
        )

        actions = await self.handler.use_storage(game_state)
        assert len(actions) == 0  # Insufficient zeny


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

    def test_get_service_npcs_all_maps(self):
        """Test getting service NPCs across all maps."""
        db = ServiceNPCDatabase()

        kafra1 = ServiceNPC(
            npc_id=2001,
            name="Kafra Prontera",
            service_type="kafra",
            map_name="prontera",
            x=150,
            y=180,
        )
        kafra2 = ServiceNPC(
            npc_id=2002,
            name="Kafra Geffen",
            service_type="kafra",
            map_name="geffen",
            x=120,
            y=60,
        )

        db.add_service_npc(kafra1)
        db.add_service_npc(kafra2)

        # Get all Kafras
        all_kafras = db.get_service_npcs("kafra")
        assert len(all_kafras) == 2

        # Get Kafras on specific map
        prontera_kafras = db.get_service_npcs("kafra", "prontera")
        assert len(prontera_kafras) == 1
        assert prontera_kafras[0].name == "Kafra Prontera"

    def test_find_nearest_service(self):
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

        # Find nearest from position (145, 175) - should be Kafra 1
        nearest = db.find_nearest("kafra", "prontera", 145, 175)
        assert nearest is not None
        assert nearest.name == "Kafra 1"

        # Find nearest from position (205, 205) - should be Kafra 2
        nearest = db.find_nearest("kafra", "prontera", 205, 205)
        assert nearest is not None
        assert nearest.name == "Kafra 2"

    def test_find_nearest_no_service(self):
        """Test finding service when none exist."""
        db = ServiceNPCDatabase()

        nearest = db.find_nearest("kafra", "prontera", 150, 180)
        assert nearest is None