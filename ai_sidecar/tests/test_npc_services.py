"""
Comprehensive test suite for NPC Service Handler.

Tests service NPC interactions including storage, teleportation,
refining, repair, and identification services.
"""

from unittest.mock import AsyncMock, Mock, patch
from typing import Any, Dict

import pytest

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.npc.models import ServiceNPC, ServiceNPCDatabase
from ai_sidecar.npc.services import ServiceHandler


@pytest.fixture
def service_handler():
    """Create ServiceHandler instance."""
    return ServiceHandler()


@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    state = Mock()
    state.character = Mock()
    state.character.zeny = 10000
    state.character.position = Mock(x=100, y=100)
    state.character.weight = 1000
    state.character.weight_max = 2000
    state.map = Mock()
    state.map.name = "prontera"
    state.map_name = "prontera"
    state.inventory = []
    return state


@pytest.fixture
def mock_kafra_npc():
    """Create mock Kafra NPC."""
    return ServiceNPC(
        npc_id=1001,
        name="Kafra Employee",
        service_type="kafra",
        map_name="prontera",
        x=150,
        y=150
    )


@pytest.fixture
def mock_refiner_npc():
    """Create mock refiner NPC."""
    return ServiceNPC(
        npc_id=2001,
        name="Refiner",
        service_type="refiner",
        map_name="prontera",
        x=160,
        y=160
    )


# ==================== Initialization Tests ====================


class TestServiceHandlerInit:
    """Test ServiceHandler initialization."""
    
    def test_initialization(self, service_handler):
        """Test handler initialization."""
        assert service_handler.service_db is not None
        assert service_handler.last_save_map == ""
        assert service_handler.preferred_destinations == []
        assert service_handler.auto_save_on_new_map is True
        assert service_handler.repair_threshold == 0.3
    
    def test_service_costs(self):
        """Test service cost constants."""
        assert ServiceHandler.SERVICE_COSTS["storage"] == 60
        assert ServiceHandler.SERVICE_COSTS["teleport"] == 600
        assert ServiceHandler.SERVICE_COSTS["save"] == 0
        assert ServiceHandler.SERVICE_COSTS["refine"] == 2000
        assert ServiceHandler.SERVICE_COSTS["identify"] == 40
        assert ServiceHandler.SERVICE_COSTS["repair"] == 500


# ==================== Service Need Evaluation Tests ====================


class TestServiceNeedEvaluation:
    """Test service need evaluation logic."""
    
    def test_should_use_storage_weight_limit(self, service_handler, mock_game_state):
        """Test storage need based on weight."""
        mock_game_state.inventory = [Mock()] * 50
        mock_game_state.character.weight = 1400  # 70%
        mock_game_state.character.weight_max = 2000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'storage_enabled': True,
            'max_weight_percent_before_storage': 70
        }):
            should_use, reason = service_handler.should_use_service('storage', mock_game_state)
            assert should_use is True
            assert "Weight limit" in reason
    
    def test_should_use_storage_inventory_full(self, service_handler, mock_game_state):
        """Test storage need based on inventory count."""
        mock_game_state.inventory = [Mock()] * 85
        mock_game_state.character.weight = 500
        mock_game_state.character.weight_max = 2000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'storage_enabled': True,
            'max_inventory_before_storage': 80
        }):
            should_use, reason = service_handler.should_use_service('storage', mock_game_state)
            assert should_use is True
            assert "Inventory full" in reason
    
    def test_should_not_use_storage(self, service_handler, mock_game_state):
        """Test storage not needed."""
        mock_game_state.inventory = [Mock()] * 30
        mock_game_state.character.weight = 500
        mock_game_state.character.weight_max = 2000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'storage_enabled': True,
            'max_inventory_before_storage': 80,
            'max_weight_percent_before_storage': 70
        }):
            should_use, reason = service_handler.should_use_service('storage', mock_game_state)
            assert should_use is False
    
    def test_should_save_new_map(self, service_handler, mock_game_state):
        """Test save point on new safe map."""
        mock_game_state.map_name = "geffen"
        service_handler.last_save_map = "prontera"
        service_handler.auto_save_on_new_map = True
        
        should_use, reason = service_handler.should_use_service('save', mock_game_state)
        assert should_use is True
        assert "New town map" in reason
    
    def test_should_not_save_same_map(self, service_handler, mock_game_state):
        """Test no save on same map."""
        mock_game_state.map_name = "prontera"
        service_handler.last_save_map = "prontera"
        
        should_use, reason = service_handler.should_use_service('save', mock_game_state)
        assert should_use is False
    
    def test_should_repair_low_durability(self, service_handler, mock_game_state):
        """Test repair need based on durability."""
        item = Mock()
        item.durability = 20
        item.max_durability = 100
        mock_game_state.inventory = [item]
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'repair_enabled': True,
            'repair_threshold': 0.3
        }):
            should_use, reason = service_handler.should_use_service('repair', mock_game_state)
            assert should_use is True
            assert "Equipment needs repair" in reason
    
    def test_should_not_repair_good_durability(self, service_handler, mock_game_state):
        """Test no repair when durability high."""
        item = Mock()
        item.durability = 80
        item.max_durability = 100
        mock_game_state.inventory = [item]
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'repair_enabled': True,
            'repair_threshold': 0.3
        }):
            should_use, reason = service_handler.should_use_service('repair', mock_game_state)
            assert should_use is False
    
    def test_should_refine_with_materials(self, service_handler, mock_game_state):
        """Test refine when materials available."""
        item1 = Mock()
        item1.id = 984  # Oridecon
        mock_game_state.inventory = [item1]
        mock_game_state.character.zeny = 100000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'refine_enabled': True,
            'min_zeny_for_refine': 50000
        }):
            should_use, reason = service_handler.should_use_service('refine', mock_game_state)
            assert should_use is True
    
    def test_should_not_refine_no_materials(self, service_handler, mock_game_state):
        """Test no refine without materials."""
        mock_game_state.inventory = []
        mock_game_state.character.zeny = 100000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'refine_enabled': True,
            'min_zeny_for_refine': 50000
        }):
            should_use, reason = service_handler.should_use_service('refine', mock_game_state)
            assert should_use is False
            assert "No refinement materials" in reason
    
    def test_should_not_refine_no_zeny(self, service_handler, mock_game_state):
        """Test no refine without enough zeny."""
        item1 = Mock()
        item1.id = 984
        mock_game_state.inventory = [item1]
        mock_game_state.character.zeny = 10000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'refine_enabled': True,
            'min_zeny_for_refine': 50000
        }):
            should_use, reason = service_handler.should_use_service('refine', mock_game_state)
            assert should_use is False
            assert "Insufficient zeny" in reason


# ==================== Storage Service Tests ====================


class TestStorageService:
    """Test storage service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_storage_success(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test successful storage access."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.position.x = 148
        mock_game_state.character.position.y = 148
        
        actions = await service_handler.use_storage(mock_game_state)
        
        assert len(actions) > 0
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].target_id == 1001
    
    @pytest.mark.asyncio
    async def test_use_storage_move_required(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test storage with movement needed."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.position.x = 100
        mock_game_state.character.position.y = 100
        
        actions = await service_handler.use_storage(mock_game_state)
        
        assert len(actions) > 0
        # Should return move action first
        assert any(action.type == ActionType.MOVE for action in actions)
    
    @pytest.mark.asyncio
    async def test_use_storage_insufficient_zeny(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test storage with insufficient zeny."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.zeny = 50  # Less than 60
        
        actions = await service_handler.use_storage(mock_game_state)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_use_storage_no_kafra(self, service_handler, mock_game_state):
        """Test storage when no Kafra nearby."""
        actions = await service_handler.use_storage(mock_game_state)
        assert len(actions) == 0


# ==================== Refine Service Tests ====================


class TestRefineService:
    """Test refine service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_refine_success(self, service_handler, mock_game_state, mock_refiner_npc):
        """Test successful refine."""
        service_handler.service_db.add_service_npc(mock_refiner_npc)
        mock_game_state.character.position.x = 158
        mock_game_state.character.position.y = 158
        mock_game_state.character.zeny = 5000
        
        actions = await service_handler.use_refine(mock_game_state, item_index=0)
        
        assert len(actions) > 0
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["item_index"] == 0
    
    @pytest.mark.asyncio
    async def test_use_refine_insufficient_zeny(self, service_handler, mock_game_state, mock_refiner_npc):
        """Test refine with insufficient zeny."""
        service_handler.service_db.add_service_npc(mock_refiner_npc)
        mock_game_state.character.zeny = 100
        
        actions = await service_handler.use_refine(mock_game_state, item_index=0)
        
        assert len(actions) == 0


# ==================== Teleport Service Tests ====================


class TestTeleportService:
    """Test teleport service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_teleport_success(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test successful teleport."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.position.x = 148
        mock_game_state.character.position.y = 148
        mock_game_state.character.zeny = 1000
        
        actions = await service_handler.use_teleport(mock_game_state, "Geffen")
        
        assert len(actions) > 0
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["teleport_destination"] == "Geffen"
    
    @pytest.mark.asyncio
    async def test_use_teleport_insufficient_zeny(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test teleport with insufficient zeny."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.zeny = 100
        
        actions = await service_handler.use_teleport(mock_game_state, "Geffen")
        
        assert len(actions) == 0


# ==================== Save Point Service Tests ====================


class TestSavePointService:
    """Test save point service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_save_point_success(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test successful save point."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        mock_game_state.character.position.x = 148
        mock_game_state.character.position.y = 148
        
        actions = await service_handler.use_save_point(mock_game_state)
        
        assert len(actions) > 0
        assert actions[0].type == ActionType.TALK_NPC
        assert actions[0].extra["service"] == "save"
        assert service_handler.last_save_map == "prontera"


# ==================== Repair Service Tests ====================


class TestRepairService:
    """Test repair service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_repair_all_items(self, service_handler, mock_game_state):
        """Test repair all items."""
        repair_npc = ServiceNPC(
            npc_id=3001,
            name="Repair NPC",
            service_type="repairman",
            map_name="prontera",
            x=170,
            y=170
        )
        service_handler.service_db.add_service_npc(repair_npc)
        mock_game_state.character.position.x = 168
        mock_game_state.character.position.y = 168
        
        actions = await service_handler.use_repair(mock_game_state)
        
        assert len(actions) > 0
        assert actions[0].extra["item_indices"] == "all"
    
    @pytest.mark.asyncio
    async def test_use_repair_specific_items(self, service_handler, mock_game_state):
        """Test repair specific items."""
        repair_npc = ServiceNPC(
            npc_id=3001,
            name="Repair NPC",
            service_type="repairman",
            map_name="prontera",
            x=170,
            y=170
        )
        service_handler.service_db.add_service_npc(repair_npc)
        mock_game_state.character.position.x = 168
        mock_game_state.character.position.y = 168
        
        actions = await service_handler.use_repair(mock_game_state, item_indices=[0, 1, 2])
        
        assert len(actions) > 0
        assert actions[0].extra["item_indices"] == [0, 1, 2]


# ==================== Identify Service Tests ====================


class TestIdentifyService:
    """Test identify service interactions."""
    
    @pytest.mark.asyncio
    async def test_use_identify_success(self, service_handler, mock_game_state):
        """Test successful item identification."""
        identify_npc = ServiceNPC(
            npc_id=4001,
            name="Identifier",
            service_type="identifier",
            map_name="prontera",
            x=180,
            y=180
        )
        service_handler.service_db.add_service_npc(identify_npc)
        mock_game_state.character.position.x = 178
        mock_game_state.character.position.y = 178
        
        actions = await service_handler.use_identify(mock_game_state, item_index=5)
        
        assert len(actions) > 0
        assert actions[0].extra["item_index"] == 5


# ==================== Helper Method Tests ====================


class TestServiceHelperMethods:
    """Test service handler helper methods."""
    
    def test_find_nearest_service(self, service_handler, mock_game_state, mock_kafra_npc):
        """Test finding nearest service NPC."""
        service_handler.service_db.add_service_npc(mock_kafra_npc)
        
        nearest = service_handler.find_nearest_service("kafra", mock_game_state)
        
        assert nearest is not None
        assert nearest.npc_id == 1001
    
    def test_estimate_service_cost_base(self, service_handler):
        """Test base service cost estimation."""
        cost = service_handler.estimate_service_cost("storage")
        assert cost == 60
    
    def test_estimate_service_cost_refine_scaling(self, service_handler):
        """Test refine cost scaling."""
        base_cost = service_handler.estimate_service_cost("refine", current_refine=0)
        higher_cost = service_handler.estimate_service_cost("refine", current_refine=5)
        
        assert higher_cost > base_cost
    
    def test_is_safe_map_town(self, service_handler):
        """Test safe map detection for towns."""
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'safe_maps': ['prontera', 'geffen']
        }):
            assert service_handler._is_safe_map("prontera") is True
            assert service_handler._is_safe_map("geffen_in") is True
            assert service_handler._is_safe_map("gef_dun01") is False
    
    def test_get_recommended_services(self, service_handler, mock_game_state):
        """Test getting recommended services."""
        # Create items with proper attribute handling
        items = []
        for i in range(85):
            item = Mock()
            # Make hasattr work properly
            item.durability = 100 if i == 0 else None
            item.max_durability = 100 if i == 0 else None
            items.append(item)
        
        # Add one item that needs repair
        repair_item = Mock()
        repair_item.durability = 20
        repair_item.max_durability = 100
        items.append(repair_item)
        
        mock_game_state.inventory = items
        mock_game_state.character.weight = 1500
        mock_game_state.character.weight_max = 2000
        
        with patch('ai_sidecar.social.config.SERVICE_PREFERENCES', {
            'storage_enabled': True,
            'repair_enabled': True,
            'max_inventory_before_storage': 80,
            'max_weight_percent_before_storage': 70,
            'repair_threshold': 0.3
        }):
            recommendations = service_handler.get_recommended_services(mock_game_state)
            
            assert len(recommendations) > 0
            # Storage should be first priority
            assert recommendations[0][0] == "storage"
    
    def test_set_preferred_destinations(self, service_handler):
        """Test setting preferred teleport destinations."""
        destinations = ["Prontera", "Geffen", "Payon"]
        service_handler.set_preferred_destinations(destinations)
        
        assert service_handler.preferred_destinations == destinations
    
    def test_get_teleport_destinations_filtered(self, service_handler, mock_game_state):
        """Test getting filtered teleport destinations."""
        service_handler.set_preferred_destinations(["Prontera", "Geffen"])
        
        destinations = service_handler.get_teleport_destinations(mock_game_state)
        
        assert "Prontera" in destinations
        assert "Geffen" in destinations
        assert "Comodo" not in destinations
    
    def test_get_teleport_destinations_all(self, service_handler, mock_game_state):
        """Test getting all teleport destinations."""
        destinations = service_handler.get_teleport_destinations(mock_game_state)
        
        assert len(destinations) > 0
        assert "Prontera" in destinations