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


class TestNPCManager:
    """Test NPC Manager orchestration."""
    
    @pytest.fixture
    def manager(self):
        """Create NPC manager instance."""
        from ai_sidecar.npc.manager import NPCManager
        return NPCManager()
    
    @pytest.fixture
    def game_state(self):
        """Create test game state."""
        from ai_sidecar.core.state import GameState
        return GameState()
    
    @pytest.mark.asyncio
    async def test_tick_no_dialogue_no_quests_no_services(self, manager, game_state):
        """Test tick with no activity needed."""
        actions = await manager.tick(game_state)
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_in_dialogue(self, manager, game_state, monkeypatch):
        """Test tick when in dialogue."""
        # Mock _is_in_dialogue to return True
        monkeypatch.setattr(manager, '_is_in_dialogue', lambda gs: True)
        
        actions = await manager.tick(game_state)
        # Should return dialogue actions only
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_with_quest_actions(self, manager, game_state, monkeypatch):
        """Test tick with quest actions."""
        from ai_sidecar.core.decision import Action
        
        # Mock quest_manager.tick to return actions
        async def mock_quest_tick(gs):
            return [Action.move_to(100, 100)]
        
        monkeypatch.setattr(manager.quest_manager, 'tick', mock_quest_tick)
        
        actions = await manager.tick(game_state)
        # Should return quest actions
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_tick_with_service_needs(self, manager, game_state, monkeypatch):
        """Test tick when services are needed."""
        from ai_sidecar.core.decision import Action
        
        # Mock no quest actions
        async def mock_quest_tick(gs):
            return []
        
        # Mock service needs
        async def mock_service_storage(gs):
            return [Action.move_to(150, 180)]
        
        monkeypatch.setattr(manager.quest_manager, 'tick', mock_quest_tick)
        monkeypatch.setattr(manager.service_handler, 'use_storage', mock_service_storage)
        
        # Set high weight to trigger storage need
        game_state.character.weight = 2000
        game_state.character.weight_max = 2000
        
        actions = await manager.tick(game_state)
        # Should return service actions
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_tick_error_handling(self, manager, game_state, monkeypatch):
        """Test tick error handling."""
        # Mock quest tick to raise exception
        async def mock_quest_tick_error(gs):
            raise ValueError("Test error")
        
        monkeypatch.setattr(manager.quest_manager, 'tick', mock_quest_tick_error)
        
        actions = await manager.tick(game_state)
        # Should return empty list on error
        assert isinstance(actions, list)
    
    def test_is_in_dialogue_true(self, manager):
        """Test dialogue check when in dialogue."""
        # Create mock game state with in_dialogue
        class MockGameState:
            in_dialogue = True
        
        assert manager._is_in_dialogue(MockGameState()) is True
    
    def test_is_in_dialogue_false(self, manager, game_state):
        """Test dialogue check when not in dialogue."""
        assert manager._is_in_dialogue(game_state) is False
    
    def test_is_in_dialogue_no_attribute(self, manager, game_state):
        """Test dialogue check without attribute."""
        # GameState without in_dialogue attribute
        assert manager._is_in_dialogue(game_state) is False
    
    @pytest.mark.asyncio
    async def test_check_service_needs_not_needed(self, manager, game_state):
        """Test service check when not needed."""
        game_state.character.weight = 100
        game_state.character.weight_max = 2000
        
        actions = await manager._check_service_needs(game_state)
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_check_service_needs_required(self, manager, game_state, monkeypatch):
        """Test service check when storage needed."""
        from ai_sidecar.core.decision import Action
        
        # Mock service handler
        async def mock_use_storage(gs):
            return [Action.move_to(150, 180)]
        
        monkeypatch.setattr(manager.service_handler, 'use_storage', mock_use_storage)
        
        # Set high weight
        game_state.character.weight = 1900
        game_state.character.weight_max = 2000
        
        actions = await manager._check_service_needs(game_state)
        assert len(actions) > 0
    
    def test_needs_storage_high_weight(self, manager, game_state):
        """Test storage need detection by weight."""
        game_state.character.weight = 1900
        game_state.character.weight_max = 2000
        
        assert manager._needs_storage(game_state) is True
    
    def test_needs_storage_normal_weight(self, manager, game_state):
        """Test storage not needed with normal weight."""
        game_state.character.weight = 1000
        game_state.character.weight_max = 2000
        
        assert manager._needs_storage(game_state) is False
    
    def test_needs_storage_many_items(self, manager, game_state):
        """Test storage need detection by item count."""
        from ai_sidecar.core.state import InventoryItem
        
        game_state.character.weight = 100
        game_state.character.weight_max = 2000
        
        # Add many items
        game_state.inventory.items = [
            InventoryItem(index=i, item_id=500+i, name=f"Item{i}", amount=1)
            for i in range(85)
        ]
        
        assert manager._needs_storage(game_state) is True
    
    def test_needs_storage_few_items(self, manager, game_state):
        """Test storage not needed with few items."""
        from ai_sidecar.core.state import InventoryItem
        
        game_state.character.weight = 100
        game_state.character.weight_max = 2000
        
        # Add few items
        game_state.inventory.items = [
            InventoryItem(index=i, item_id=500+i, name=f"Item{i}", amount=1)
            for i in range(10)
        ]
        
        assert manager._needs_storage(game_state) is False
    
    def test_on_npc_spotted_new(self, manager):
        """Test spotting a new NPC."""
        npc = NPC(
            npc_id=1001,
            name="New NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180
        )
        
        manager.on_npc_spotted(npc)
        
        # Should be in database
        assert manager.npc_db.get_npc(1001) is not None
    
    def test_on_npc_spotted_existing(self, manager):
        """Test spotting an already known NPC."""
        npc = NPC(
            npc_id=1001,
            name="Known NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180
        )
        
        # Add it first
        manager.npc_db.add_npc(npc)
        initial_count = manager.npc_db.count()
        
        # Spot it again
        manager.on_npc_spotted(npc)
        
        # Count should not change
        assert manager.npc_db.count() == initial_count
    
    def test_register_event_handlers_with_event_bus(self, manager):
        """Test registering event handlers with event bus."""
        class MockEventBus:
            def __init__(self):
                self.handlers = {}
            
            def on(self, event_name, handler):
                self.handlers[event_name] = handler
        
        event_bus = MockEventBus()
        manager.register_event_handlers(event_bus)
        
        # Should register all handlers
        assert "monster_killed" in event_bus.handlers
        assert "item_obtained" in event_bus.handlers
        assert "npc_talked" in event_bus.handlers
        assert "npc_spotted" in event_bus.handlers
    
    def test_register_event_handlers_no_on_method(self, manager):
        """Test registering event handlers without on method."""
        class MockEventBusNoOn:
            pass
        
        event_bus = MockEventBusNoOn()
        
        # Should not raise error
        manager.register_event_handlers(event_bus)
    
    def test_get_active_quest_count(self, manager):
        """Test getting active quest count."""
        count = manager.get_active_quest_count()
        assert count == 0
    
    def test_get_completed_quest_count(self, manager):
        """Test getting completed quest count."""
        count = manager.get_completed_quest_count()
        assert count == 0
    
    def test_get_npc_count(self, manager):
        """Test getting NPC count."""
        assert manager.get_npc_count() == 0
        
        # Add an NPC
        npc = NPC(
            npc_id=1001,
            name="Test NPC",
            npc_type=NPCType.QUEST,
            map_name="prontera",
            x=150,
            y=180
        )
        manager.npc_db.add_npc(npc)
        
        assert manager.get_npc_count() == 1
    
    def test_load_npc_data_success(self, manager):
        """Test loading NPC data successfully."""
        npc_data = {
            "npcs": [
                {
                    "npc_id": 1001,
                    "name": "Quest NPC",
                    "npc_type": "quest",
                    "map_name": "prontera",
                    "x": 150,
                    "y": 180
                },
                {
                    "npc_id": 1002,
                    "name": "Shop NPC",
                    "npc_type": "shop",
                    "map_name": "geffen",
                    "x": 120,
                    "y": 60
                }
            ]
        }
        
        manager.load_npc_data(npc_data)
        
        assert manager.get_npc_count() == 2
    
    def test_load_npc_data_empty(self, manager):
        """Test loading empty NPC data."""
        manager.load_npc_data({})
        assert manager.get_npc_count() == 0
    
    def test_load_npc_data_error(self, manager):
        """Test loading invalid NPC data."""
        npc_data = {
            "npcs": [
                {
                    "invalid": "data"
                    # Missing required fields
                }
            ]
        }
        
        # Should not raise error, just log it
        manager.load_npc_data(npc_data)
    
    def test_load_quest_data_success(self, manager):
        """Test loading quest data successfully."""
        quest_data = {
            "quests": []
        }
        
        # Should not raise error
        manager.load_quest_data(quest_data)
    
    def test_load_quest_data_error(self, manager, monkeypatch):
        """Test loading quest data with error."""
        # Mock quest_manager.load_quest_database to raise error
        def mock_load_error(data):
            raise ValueError("Test error")
        
        monkeypatch.setattr(manager.quest_manager, 'load_quest_database', mock_load_error)
        
        # Should not raise error, just log it
        manager.load_quest_data({"quests": []})
    
    def test_load_service_data_success(self, manager):
        """Test loading service data successfully."""
        service_data = {
            "kafra": {
                "prontera": [
                    {
                        "npc_id": 2001,
                        "name": "Kafra Employee",
                        "x": 150,
                        "y": 180
                    }
                ]
            },
            "storage": {
                "geffen": [
                    {
                        "npc_id": 2002,
                        "name": "Storage Keeper",
                        "x": 120,
                        "y": 60
                    }
                ]
            }
        }
        
        manager.load_service_data(service_data)
        
        # Should have loaded service NPCs
        kafra_npcs = manager.service_handler.service_db.get_service_npcs("kafra", "prontera")
        assert len(kafra_npcs) > 0
    
    def test_load_service_data_empty(self, manager):
        """Test loading empty service data."""
        manager.load_service_data({})
        # Should not raise error
    
    def test_load_service_data_error(self, manager):
        """Test loading invalid service data."""
        service_data = {
            "invalid": "structure"
        }
        
        # Should not raise error, just log it
        manager.load_service_data(service_data)
    
    def test_load_service_data_with_invalid_npc(self, manager):
        """Test loading service data with invalid NPC."""
        service_data = {
            "kafra": {
                "prontera": [
                    {
                        # Missing required fields
                        "name": "Incomplete"
                    }
                ]
            }
        }
        
        # Should not raise error, just log it
        manager.load_service_data(service_data)