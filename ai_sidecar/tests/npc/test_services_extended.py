"""
Extended test coverage for services.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 72, 86, 120-123, 138, 152-157, 260-273, 305-318, 347-355, 396-409, 450-463, 555-617
- Service availability checks, teleport, repair, identify, card removal
"""

import pytest
from unittest.mock import Mock, MagicMock, patch

from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.npc.models import ServiceNPC
from ai_sidecar.core.decision import Action, ActionType


class TestServiceHandlerExtendedCoverage:
    """Extended coverage for service handler."""
    
    def test_should_use_service_disabled(self):
        """Test service check when service disabled."""
        handler = ServiceHandler()
        
        game_state = Mock()
        
        with patch.dict("ai_sidecar.social.config.SERVICE_PREFERENCES", {"storage_enabled": False}):
            should_use, reason = handler.should_use_service("storage", game_state)
            
            assert should_use is False
            assert "disabled" in reason
    
    def test_should_use_service_unknown_type(self):
        """Test should use service for unknown type."""
        handler = ServiceHandler()
        
        game_state = Mock()
        
        should_use, reason = handler.should_use_service("unknown_service", game_state)
        
        assert should_use is True  # Default to available
    
    def test_should_save_point_new_map(self):
        """Test should save point on new map."""
        handler = ServiceHandler()
        handler.auto_save_on_new_map = True
        handler.last_save_map = "payon"
        
        game_state = Mock()
        game_state.map_name = "prontera"
        
        handler._is_safe_map = Mock(return_value=True)
        
        should_use, reason = handler._should_save_point(game_state)
        
        assert should_use is True
        assert "new town" in reason.lower()
    
    def test_should_save_point_unsafe_map(self):
        """Test should not save on unsafe map."""
        handler = ServiceHandler()
        handler.auto_save_on_new_map = True
        handler.last_save_map = ""
        
        game_state = Mock()
        game_state.map_name = "dangerous_dungeon"
        
        handler._is_safe_map = Mock(return_value=False)
        
        should_use, reason = handler._should_save_point(game_state)
        
        assert should_use is False
    
    def test_should_teleport_insufficient_zeny(self):
        """Test should not teleport with insufficient zeny."""
        handler = ServiceHandler()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100
        
        with patch.dict("ai_sidecar.social.config.SERVICE_PREFERENCES", {"min_zeny_for_teleport": 5000}):
            should_use, reason = handler._should_teleport(game_state, {"min_zeny_for_teleport": 5000})
            
            assert should_use is False
            assert "insufficient" in reason.lower()
    
    def test_should_repair_equipment_damaged(self):
        """Test should repair with damaged equipment."""
        handler = ServiceHandler()
        
        item = Mock()
        item.durability = 20
        item.max_durability = 100
        
        game_state = Mock()
        game_state.inventory = [item]
        
        should_use, reason = handler._should_repair(game_state, {"repair_threshold": 0.3})
        
        assert should_use is True
    
    def test_should_repair_no_durability_attribute(self):
        """Test should not repair when items have no durability."""
        handler = ServiceHandler()
        
        item = Mock(spec=[])  # No durability attribute
        
        game_state = Mock()
        game_state.inventory = [item]
        
        should_use, reason = handler._should_repair(game_state, {})
        
        assert should_use is False
    
    def test_should_repair_max_durability_none(self):
        """Test should not repair when max_durability is None."""
        handler = ServiceHandler()
        
        item = Mock()
        item.durability = 50
        item.max_durability = None
        
        game_state = Mock()
        game_state.inventory = [item]
        
        should_use, reason = handler._should_repair(game_state, {})
        
        assert should_use is False
    
    def test_should_repair_max_durability_zero(self):
        """Test should not repair when max_durability is 0."""
        handler = ServiceHandler()
        
        item = Mock()
        item.durability = 0
        item.max_durability = 0
        
        game_state = Mock()
        game_state.inventory = [item]
        
        should_use, reason = handler._should_repair(game_state, {})
        
        assert should_use is False
    
    def test_should_refine_insufficient_zeny(self):
        """Test should not refine with insufficient zeny."""
        handler = ServiceHandler()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 10000
        game_state.inventory = []
        
        should_use, reason = handler._should_refine(game_state, {"min_zeny_for_refine": 50000})
        
        assert should_use is False
    
    def test_should_refine_no_materials(self):
        """Test should not refine without materials."""
        handler = ServiceHandler()
        
        item = Mock()
        item.id = 999  # Not a refinement material
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100000
        game_state.inventory = [item]
        
        should_use, reason = handler._should_refine(game_state, {"min_zeny_for_refine": 50000})
        
        assert should_use is False
    
    def test_should_refine_with_materials(self):
        """Test should refine with materials."""
        handler = ServiceHandler()
        
        item = Mock()
        item.id = 984  # Oridecon
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100000
        game_state.inventory = [item]
        
        should_use, reason = handler._should_refine(game_state, {"min_zeny_for_refine": 50000})
        
        assert should_use is True
    
    @pytest.mark.asyncio
    async def test_use_teleport(self):
        """Test using teleport service."""
        handler = ServiceHandler()
        
        kafra = ServiceNPC(
            npc_id=1,
            service_type="kafra",
            name="Kafra",
            map_name="prontera",
            x=150,
            y=150
        )
        
        handler._find_nearest_service_npc = Mock(return_value=kafra)
        handler._is_near_npc = Mock(return_value=True)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 10000
        
        actions = await handler.use_teleport(game_state, "geffen")
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.TALK_NPC
    
    @pytest.mark.asyncio
    async def test_use_teleport_no_kafra(self):
        """Test teleport when no Kafra found."""
        handler = ServiceHandler()
        handler._find_nearest_service_npc = Mock(return_value=None)
        
        game_state = Mock()
        
        actions = await handler.use_teleport(game_state, "geffen")
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_teleport_insufficient_zeny(self):
        """Test teleport with insufficient zeny."""
        handler = ServiceHandler()
        
        kafra = ServiceNPC(
            npc_id=1,
            service_type="kafra",
            name="Kafra",
            map_name="prontera",
            x=150,
            y=150
        )
        
        handler._find_nearest_service_npc = Mock(return_value=kafra)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100  # Less than 600
        
        actions = await handler.use_teleport(game_state, "geffen")
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_teleport_not_near(self):
        """Test teleport when not near Kafra."""
        handler = ServiceHandler()
        
        kafra = ServiceNPC(
            npc_id=1,
            service_type="kafra",
            name="Kafra",
            map_name="prontera",
            x=150,
            y=150
        )
        
        handler._find_nearest_service_npc = Mock(return_value=kafra)
        handler._is_near_npc = Mock(return_value=False)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 10000
        
        actions = await handler.use_teleport(game_state, "geffen")
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_use_save_point_not_near(self):
        """Test save point when not near Kafra."""
        handler = ServiceHandler()
        
        kafra = ServiceNPC(
            npc_id=1,
            service_type="kafra",
            name="Kafra",
            map_name="prontera",
            x=150,
            y=150
        )
        
        handler._find_nearest_service_npc = Mock(return_value=kafra)
        handler._is_near_npc = Mock(return_value=False)
        
        game_state = Mock()
        game_state.map_name = "prontera"
        
        actions = await handler.use_save_point(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_use_save_point_no_kafra(self):
        """Test save point when no Kafra found."""
        handler = ServiceHandler()
        handler._find_nearest_service_npc = Mock(return_value=None)
        
        game_state = Mock()
        
        actions = await handler.use_save_point(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_repair_no_game_state(self):
        """Test repair in test mode without game state."""
        handler = ServiceHandler()
        
        actions = await handler.use_repair(game_state=None)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_repair_no_npc(self):
        """Test repair when no repair NPC found."""
        handler = ServiceHandler()
        handler._find_nearest_service_npc = Mock(return_value=None)
        
        game_state = Mock()
        
        actions = await handler.use_repair(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_repair_insufficient_zeny(self):
        """Test repair with insufficient zeny."""
        handler = ServiceHandler()
        
        repair_npc = ServiceNPC(
            npc_id=2,
            service_type="repairman",
            name="Repairman",
            map_name="prontera",
            x=160,
            y=160
        )
        
        handler._find_nearest_service_npc = Mock(return_value=repair_npc)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 100
        
        actions = await handler.use_repair(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_repair_not_near(self):
        """Test repair when not near NPC."""
        handler = ServiceHandler()
        
        repair_npc = ServiceNPC(
            npc_id=2,
            service_type="repairman",
            name="Repairman",
            map_name="prontera",
            x=160,
            y=160
        )
        
        handler._find_nearest_service_npc = Mock(return_value=repair_npc)
        handler._is_near_npc = Mock(return_value=False)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 1000
        
        actions = await handler.use_repair(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_use_repair_success(self):
        """Test successful repair interaction."""
        handler = ServiceHandler()
        
        repair_npc = ServiceNPC(
            npc_id=2,
            service_type="repairman",
            name="Repairman",
            map_name="prontera",
            x=160,
            y=160
        )
        
        handler._find_nearest_service_npc = Mock(return_value=repair_npc)
        handler._is_near_npc = Mock(return_value=True)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 1000
        
        actions = await handler.use_repair(game_state, item_indices=[1, 2])
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["item_indices"] == [1, 2]
    
    @pytest.mark.asyncio
    async def test_use_identify_no_game_state(self):
        """Test identify in test mode without game state."""
        handler = ServiceHandler()
        
        actions = await handler.use_identify(game_state=None)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_identify_no_npc(self):
        """Test identify when no identifier found."""
        handler = ServiceHandler()
        handler._find_nearest_service_npc = Mock(return_value=None)
        
        game_state = Mock()
        
        actions = await handler.use_identify(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_identify_insufficient_zeny(self):
        """Test identify with insufficient zeny."""
        handler = ServiceHandler()
        
        identify_npc = ServiceNPC(
            npc_id=3,
            service_type="identifier",
            name="Identifier",
            map_name="prontera",
            x=170,
            y=170
        )
        
        handler._find_nearest_service_npc = Mock(return_value=identify_npc)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 10
        
        actions = await handler.use_identify(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_identify_not_near(self):
        """Test identify when not near NPC."""
        handler = ServiceHandler()
        
        identify_npc = ServiceNPC(
            npc_id=3,
            service_type="identifier",
            name="Identifier",
            map_name="prontera",
            x=170,
            y=170
        )
        
        handler._find_nearest_service_npc = Mock(return_value=identify_npc)
        handler._is_near_npc = Mock(return_value=False)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 1000
        
        actions = await handler.use_identify(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_use_identify_success(self):
        """Test successful identify interaction."""
        handler = ServiceHandler()
        
        identify_npc = ServiceNPC(
            npc_id=3,
            service_type="identifier",
            name="Identifier",
            map_name="prontera",
            x=170,
            y=170
        )
        
        handler._find_nearest_service_npc = Mock(return_value=identify_npc)
        handler._is_near_npc = Mock(return_value=True)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 1000
        
        actions = await handler.use_identify(game_state, item_index=5)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["item_index"] == 5
    
    def test_get_recommended_services(self):
        """Test getting recommended services."""
        handler = ServiceHandler()
        
        item = Mock()
        item.durability = 20
        item.max_durability = 100
        item.id = 1000
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.weight = 800
        game_state.character.weight_max = 1000
        game_state.character.zeny = 10000
        game_state.inventory = [item] * 50
        game_state.map_name = "prontera"
        
        handler.last_save_map = "payon"
        
        recommendations = handler.get_recommended_services(game_state)
        
        # Should include storage (inventory full) and possibly repair
        assert len(recommendations) > 0
        service_types = [s[0] for s in recommendations]
        # Storage should be first (priority 0)
        if len(recommendations) > 0:
            assert recommendations[0][0] == "storage"
    
    @pytest.mark.asyncio
    async def test_use_card_remove_no_game_state(self):
        """Test card removal in test mode."""
        handler = ServiceHandler()
        
        actions = await handler.use_card_remove(game_state=None)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_card_remove_no_npc(self):
        """Test card removal when no NPC found."""
        handler = ServiceHandler()
        handler._find_nearest_service_npc = Mock(return_value=None)
        
        game_state = Mock()
        
        actions = await handler.use_card_remove(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_card_remove_insufficient_zeny(self):
        """Test card removal with insufficient zeny."""
        handler = ServiceHandler()
        
        card_npc = ServiceNPC(
            npc_id=4,
            service_type="card_remover",
            name="Card Remover",
            map_name="prontera",
            x=180,
            y=180
        )
        
        handler._find_nearest_service_npc = Mock(return_value=card_npc)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 1000  # Less than 250000
        
        actions = await handler.use_card_remove(game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_card_remove_not_near(self):
        """Test card removal when not near NPC."""
        handler = ServiceHandler()
        
        card_npc = ServiceNPC(
            npc_id=4,
            service_type="card_remover",
            name="Card Remover",
            map_name="prontera",
            x=180,
            y=180
        )
        
        handler._find_nearest_service_npc = Mock(return_value=card_npc)
        handler._is_near_npc = Mock(return_value=False)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 300000
        
        actions = await handler.use_card_remove(game_state)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_use_card_remove_success(self):
        """Test successful card removal interaction."""
        handler = ServiceHandler()
        
        card_npc = ServiceNPC(
            npc_id=4,
            service_type="card_remover",
            name="Card Remover",
            map_name="prontera",
            x=180,
            y=180
        )
        
        handler._find_nearest_service_npc = Mock(return_value=card_npc)
        handler._is_near_npc = Mock(return_value=True)
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.zeny = 300000
        
        actions = await handler.use_card_remove(game_state, item_index=3)
        
        assert len(actions) == 1
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["item_index"] == 3
    
    def test_set_preferred_destinations(self):
        """Test setting preferred destinations."""
        handler = ServiceHandler()
        
        destinations = ["Prontera", "Geffen", "Payon"]
        handler.set_preferred_destinations(destinations)
        
        assert handler.preferred_destinations == destinations
    
    def test_get_teleport_destinations_all(self):
        """Test getting all teleport destinations."""
        handler = ServiceHandler()
        
        game_state = Mock()
        
        destinations = handler.get_teleport_destinations(game_state)
        
        assert len(destinations) > 0
        assert "Prontera" in destinations
    
    def test_get_teleport_destinations_filtered(self):
        """Test getting filtered teleport destinations."""
        handler = ServiceHandler()
        handler.preferred_destinations = ["Prontera", "Geffen"]
        
        game_state = Mock()
        
        destinations = handler.get_teleport_destinations(game_state)
        
        assert "Prontera" in destinations
        assert "Geffen" in destinations
        # Should only include preferred
        assert len(destinations) == 2