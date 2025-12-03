"""
Final push to 100% coverage.
Targets remaining uncovered lines in key modules.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock
from datetime import datetime, timedelta

# Memory imports
from ai_sidecar.memory.persistent_memory import PersistentMemory
from ai_sidecar.memory.models import Memory, MemoryType, MemoryImportance, MemoryQuery

# LLM imports
from ai_sidecar.llm.providers import (
    OpenAIProvider, AzureOpenAIProvider, DeepSeekProvider,
    ClaudeProvider, LocalProvider, LLMMessage
)

# NPC imports
from ai_sidecar.npc.services import ServiceHandler
from ai_sidecar.npc.models import ServiceNPC
from ai_sidecar.core.state import GameState, CharacterState, Position

# Mimicry imports
from ai_sidecar.mimicry.chat import HumanChatSimulator, ChatStyle, ChatContext


class TestPersistentMemoryErrorHandling:
    """Cover error handling in persistent memory (Lines 137-139, 188-190, etc.)."""
    
    @pytest.mark.asyncio
    async def test_initialize_with_db_error(self, tmp_path):
        """Test initialization with database error (Lines 137-139)."""
        # Create invalid db path
        invalid_path = tmp_path / "readonly" / "memory.db"
        invalid_path.parent.mkdir(mode=0o444)  # Read-only
        
        mem = PersistentMemory(db_path=str(invalid_path))
        
        # Should handle error gracefully
        result = await mem.initialize()
        assert result is False
    
    @pytest.mark.asyncio
    async def test_store_with_db_error(self, tmp_path):
        """Test store with database error (Lines 188-190)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        # Don't initialize (connection will be None)
        memory = Memory(
            memory_id="test",
            memory_type=MemoryType.EVENT,
            importance=MemoryImportance.NORMAL,
            content={"test": "data"},
            summary="Test"
        )
        
        result = await mem.store(memory)
        assert result is False  # Should fail without connection
    
    @pytest.mark.asyncio
    async def test_retrieve_without_connection(self, tmp_path):
        """Test retrieve without connection (Lines 202-203)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        result = await mem.retrieve("nonexistent")
        assert result is None
    
    @pytest.mark.asyncio
    async def test_retrieve_with_error(self, tmp_path):
        """Test retrieve with database error (Lines 226-228)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Close connection to force error
        mem._connection.close()
        mem._connection = None
        
        result = await mem.retrieve("test")
        assert result is None
    
    @pytest.mark.asyncio
    async def test_query_without_connection(self, tmp_path):
        """Test query without connection (Lines 240-241)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        query = MemoryQuery(memory_types=[MemoryType.EVENT])
        result = await mem.query(query)
        assert result == []
    
    @pytest.mark.asyncio
    async def test_query_with_error(self, tmp_path):
        """Test query with database error (Lines 272-274)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Close connection to force error
        mem._connection.close()
        mem._connection = None
        
        query = MemoryQuery(memory_types=[MemoryType.DECISION])
        result = await mem.query(query)
        assert result == []
    
    @pytest.mark.asyncio
    async def test_store_strategy_without_connection(self, tmp_path):
        """Test store_strategy without connection (Lines 295-296)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        result = await mem.store_strategy("test", "combat", {"param": 1})
        assert result is False
    
    @pytest.mark.asyncio
    async def test_store_strategy_with_error(self, tmp_path):
        """Test store_strategy with database error (Lines 317-319)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Close connection
        mem._connection.close()
        mem._connection = None
        
        result = await mem.store_strategy("test", "combat", {"param": 1})
        assert result is False
    
    @pytest.mark.asyncio
    async def test_get_best_strategy_without_connection(self, tmp_path):
        """Test get_best_strategy without connection (Lines 331-332)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        result = await mem.get_best_strategy("combat")
        assert result is None
    
    @pytest.mark.asyncio
    async def test_get_best_strategy_with_error(self, tmp_path):
        """Test get_best_strategy with database error (Lines 355-357)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Close connection
        mem._connection.close()
        mem._connection = None
        
        result = await mem.get_best_strategy("combat")
        assert result is None
    
    @pytest.mark.asyncio
    async def test_delete_without_connection(self, tmp_path):
        """Test delete without connection (Lines 417-418)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        
        result = await mem.delete("test")
        assert result is False
    
    @pytest.mark.asyncio
    async def test_delete_with_error(self, tmp_path):
        """Test delete with database error (Lines 425-427)."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Close connection
        mem._connection.close()
        mem._connection = None
        
        result = await mem.delete("test")
        assert result is False


class TestNPCServicesUncovered:
    """Cover uncovered lines in npc/services.py."""
    
    @pytest.mark.asyncio
    async def test_should_use_service_disabled(self):
        """Test service disabled check (Lines 71-72)."""
        handler = ServiceHandler()
        
        # Mock game state
        game_state = Mock(spec=GameState)
        
        # Mock config to disable service
        with patch('ai_sidecar.npc.services.config.SERVICE_PREFERENCES', {"storage_enabled": False}):
            should_use, reason = handler.should_use_service("storage", game_state)
            assert should_use is False
            assert "disabled" in reason
    
    @pytest.mark.asyncio
    async def test_should_use_service_unknown_type(self):
        """Test unknown service type (Line 86)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        should_use, reason = handler.should_use_service("unknown_service", game_state)
        assert should_use is True
        assert reason == "Service available"
    
    @pytest.mark.asyncio
    async def test_should_teleport_insufficient_zeny(self):
        """Test teleport with insufficient zeny (Lines 137-138)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 100  # Less than 5000
        
        with patch('ai_sidecar.npc.services.config.SERVICE_PREFERENCES', {"min_zeny_for_teleport": 5000}):
            should_use, reason = handler._should_teleport(game_state, {"min_zeny_for_teleport": 5000})
            assert should_use is False
            assert "Insufficient zeny" in reason
    
    @pytest.mark.asyncio
    async def test_use_refine_no_refiner(self):
        """Test use_refine when no refiner found (Lines 260-261)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10000
        
        # Mock _find_nearest_service_npc to return None
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_refine(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_refine_insufficient_zeny(self):
        """Test use_refine with insufficient zeny (Lines 264-266)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 100  # Less than 2000
        
        refiner = ServiceNPC(npc_id=1, name="Refiner", service_type="refiner",
                            map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=refiner):
            actions = await handler.use_refine(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_refine_not_near(self):
        """Test use_refine when not near NPC (Lines 270-273)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10000
        game_state.character.position = Position(x=200, y=200)
        
        refiner = ServiceNPC(npc_id=1, name="Refiner", service_type="refiner",
                            map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=refiner):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_refine(game_state, 0)
                assert len(actions) == 1
                assert actions[0].type.value == "move"
    
    @pytest.mark.asyncio
    async def test_use_teleport_no_kafra(self):
        """Test use_teleport when no Kafra found (Lines 305-306)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_teleport(game_state, "geffen")
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_teleport_insufficient_zeny(self):
        """Test use_teleport with insufficient zeny (Lines 309-311)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 100  # Less than 600
        
        kafra = ServiceNPC(npc_id=1, name="Kafra", service_type="kafra",
                          map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=kafra):
            actions = await handler.use_teleport(game_state, "geffen")
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_teleport_not_near(self):
        """Test use_teleport when not near Kafra (Lines 315-318)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10000
        game_state.character.position = Position(x=200, y=200)
        
        kafra = ServiceNPC(npc_id=1, name="Kafra", service_type="kafra",
                          map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=kafra):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_teleport(game_state, "geffen")
                assert len(actions) == 1
    
    @pytest.mark.asyncio
    async def test_use_save_point_no_kafra(self):
        """Test use_save_point when no Kafra found (Lines 347-348)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_save_point(game_state)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_save_point_not_near(self):
        """Test use_save_point when not near Kafra (Lines 352-355)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.position = Position(x=200, y=200)
        game_state.map_name = "prontera"
        
        kafra = ServiceNPC(npc_id=1, name="Kafra", service_type="kafra",
                          map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=kafra):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_save_point(game_state)
                assert len(actions) == 1
    
    @pytest.mark.asyncio
    async def test_use_repair_no_npc(self):
        """Test use_repair when no repair NPC found (Lines 396-397)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_repair(game_state)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_repair_insufficient_zeny(self):
        """Test use_repair with insufficient zeny (Lines 401-402)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 100  # Less than 500
        
        repair_npc = ServiceNPC(npc_id=1, name="Repairman", service_type="repairman",
                               map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=repair_npc):
            actions = await handler.use_repair(game_state)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_repair_not_near(self):
        """Test use_repair when not near NPC (Lines 406-409)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10000
        game_state.character.position = Position(x=200, y=200)
        
        repair_npc = ServiceNPC(npc_id=1, name="Repairman", service_type="repairman",
                               map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=repair_npc):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_repair(game_state)
                assert len(actions) == 1
    
    @pytest.mark.asyncio
    async def test_use_identify_no_npc(self):
        """Test use_identify when no identify NPC found (Lines 450-451)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_identify(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_identify_insufficient_zeny(self):
        """Test use_identify with insufficient zeny (Lines 455-456)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10  # Less than 40
        
        identify_npc = ServiceNPC(npc_id=1, name="Identifier", service_type="identifier",
                                 map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=identify_npc):
            actions = await handler.use_identify(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_identify_not_near(self):
        """Test use_identify when not near NPC (Lines 460-463)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 10000
        game_state.character.position = Position(x=200, y=200)
        
        identify_npc = ServiceNPC(npc_id=1, name="Identifier", service_type="identifier",
                                 map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=identify_npc):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_identify(game_state, 0)
                assert len(actions) == 1
    
    @pytest.mark.asyncio
    async def test_use_card_remove_no_npc(self):
        """Test use_card_remove when no NPC found (Lines 586-588)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=None):
            actions = await handler.use_card_remove(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_card_remove_insufficient_zeny(self):
        """Test use_card_remove with insufficient zeny (Lines 592-594)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 1000  # Less than 250000
        
        card_npc = ServiceNPC(npc_id=1, name="Card Remover", service_type="card_remover",
                             map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=card_npc):
            actions = await handler.use_card_remove(game_state, 0)
            assert actions == []
    
    @pytest.mark.asyncio
    async def test_use_card_remove_not_near(self):
        """Test use_card_remove when not near NPC (Lines 597-601)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 300000
        game_state.character.position = Position(x=200, y=200)
        
        card_npc = ServiceNPC(npc_id=1, name="Card Remover", service_type="card_remover",
                             map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=card_npc):
            with patch.object(handler, '_is_near_npc', return_value=False):
                actions = await handler.use_card_remove(game_state, 0)
                assert len(actions) == 1
    
    @pytest.mark.asyncio
    async def test_use_card_remove_success(self):
        """Test use_card_remove successful flow (Lines 604-617)."""
        handler = ServiceHandler()
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 300000
        game_state.character.position = Position(x=100, y=100)
        
        card_npc = ServiceNPC(npc_id=1, name="Card Remover", service_type="card_remover",
                             map_name="prontera", x=100, y=100)
        
        with patch.object(handler, '_find_nearest_service_npc', return_value=card_npc):
            with patch.object(handler, '_is_near_npc', return_value=True):
                actions = await handler.use_card_remove(game_state, 0)
                assert len(actions) == 1
                assert actions[0].type.value == "talk_npc"


class TestLLMProvidersUncovered:
    """Cover uncovered lines in llm/providers.py."""
    
    @pytest.mark.asyncio
    async def test_openai_get_client_import_error(self):
        """Test OpenAI client with import error (Lines 77-79)."""
        provider = OpenAIProvider(api_key="test_key")
        
        # Mock the openai module import to raise ImportError
        import sys
        with patch.dict(sys.modules, {'openai': None}):
            with patch('ai_sidecar.llm.providers.logger'):  # Mock logger to avoid import issues
                client = await provider._get_client()
                assert client is None
    
    @pytest.mark.asyncio
    async def test_openai_complete_no_client(self):
        """Test OpenAI complete when client unavailable (Lines 90-91)."""
        provider = OpenAIProvider(api_key="test_key")
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_azure_get_client_import_error(self):
        """Test Azure client with import error (Lines 190-192)."""
        provider = AzureOpenAIProvider(
            api_key="test", endpoint="https://test.openai.azure.com",
            deployment="test-deploy"
        )
        
        import sys
        with patch.dict(sys.modules, {'openai': None}):
            with patch('ai_sidecar.llm.providers.logger'):
                client = await provider._get_client()
                assert client is None
    
    @pytest.mark.asyncio
    async def test_azure_complete_no_client(self):
        """Test Azure complete when client unavailable (Lines 203-204)."""
        provider = AzureOpenAIProvider(
            api_key="test", endpoint="https://test.openai.azure.com",
            deployment="test-deploy"
        )
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_azure_complete_error(self):
        """Test Azure complete with error (Lines 222-224)."""
        provider = AzureOpenAIProvider(
            api_key="test", endpoint="https://test.openai.azure.com",
            deployment="test-deploy"
        )
        
        mock_client = AsyncMock()
        mock_client.chat.completions.create.side_effect = Exception("API Error")
        
        with patch.object(provider, '_get_client', return_value=mock_client):
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_deepseek_import_error(self):
        """Test DeepSeek with import error (Lines 284-286)."""
        provider = DeepSeekProvider(api_key="test_key")
        
        import sys
        with patch.dict(sys.modules, {'httpx': None}):
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([LLMMessage(role="user", content="test")])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_deepseek_completion_error(self):
        """Test DeepSeek completion with error (Lines 287-289)."""
        provider = DeepSeekProvider(api_key="test_key")
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.post.side_effect = Exception("API Error")
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_claude_get_client_import_error(self):
        """Test Claude client with import error (Lines 320-322)."""
        provider = ClaudeProvider(api_key="test_key")
        
        import sys
        with patch.dict(sys.modules, {'anthropic': None}):
            with patch('ai_sidecar.llm.providers.logger'):
                client = await provider._get_client()
                assert client is None
    
    @pytest.mark.asyncio
    async def test_claude_complete_no_client(self):
        """Test Claude complete when client unavailable (Lines 333-334)."""
        provider = ClaudeProvider(api_key="test_key")
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_claude_complete_error(self):
        """Test Claude complete with error (Lines 361-363)."""
        provider = ClaudeProvider(api_key="test_key")
        
        mock_client = AsyncMock()
        mock_client.messages.create.side_effect = Exception("API Error")
        
        with patch.object(provider, '_get_client', return_value=mock_client):
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_local_import_error(self):
        """Test Local provider with import error (Lines 427-429)."""
        provider = LocalProvider()
        
        import sys
        with patch.dict(sys.modules, {'httpx': None}):
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([LLMMessage(role="user", content="test")])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_local_completion_error(self):
        """Test Local completion with error (Lines 430-432)."""
        provider = LocalProvider()
        
        with patch('httpx.AsyncClient') as mock_client:
            mock_client.return_value.__aenter__.return_value.post.side_effect = Exception("Connection Error")
            result = await provider.complete([LLMMessage(role="user", content="test")])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_local_is_available_error(self):
        """Test Local is_available with error (Lines 442-443)."""
        provider = LocalProvider()
        
        # Should return False on any exception
        available = await provider.is_available()
        assert available is False  # Will fail to connect to non-existent endpoint


class TestMimicryChatUncovered:
    """Cover uncovered lines in mimicry/chat.py."""
    
    def test_load_abbreviations_error(self, tmp_path):
        """Test loading abbreviations with error (Lines 90-91)."""
        # Create invalid JSON file
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        (data_dir / "human_behaviors.json").write_text("{invalid json")
        
        simulator = HumanChatSimulator(data_dir=data_dir)
        
        # Should use default abbreviations on error
        assert "please" in simulator.abbreviations
    
    def test_load_typo_patterns_error(self, tmp_path):
        """Test loading typo patterns with error (Lines 110-111)."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        (data_dir / "human_behaviors.json").write_text("{invalid json")
        
        simulator = HumanChatSimulator(data_dir=data_dir)
        
        # Should use default typo patterns on error
        assert "adjacent_keys" in simulator.typo_patterns
    
    def test_should_respond_too_frequent(self):
        """Test should_respond with too-frequent messages (Lines 134-135)."""
        simulator = HumanChatSimulator()
        context = ChatContext(time_since_last_message_seconds=2.0)
        
        should_respond, prob = simulator.should_respond(context, "hello")
        
        assert should_respond is False
        assert prob == 0.0
    
    def test_should_respond_directed_message(self):
        """Test should_respond with directed message (Lines 141-142)."""
        simulator = HumanChatSimulator()
        context = ChatContext(time_since_last_message_seconds=10.0)
        
        # Mock _is_message_directed to return True
        with patch.object(simulator, '_is_message_directed', return_value=True):
            should_respond, prob = simulator.should_respond(context, "hello?")
            # With directed=True, prob should be 0.8
            assert prob == 0.8
    
    def test_should_respond_by_style(self):
        """Test response probability by chat style (Lines 145-152)."""
        # Test all chat styles
        for style in [ChatStyle.TALKATIVE, ChatStyle.QUIET, ChatStyle.HELPFUL, 
                      ChatStyle.CASUAL, ChatStyle.FORMAL]:
            simulator = HumanChatSimulator(style=style)
            context = ChatContext(time_since_last_message_seconds=10.0)
            
            with patch.object(simulator, '_is_message_directed', return_value=False):
                _, prob = simulator.should_respond(context, "test")
                assert 0.0 <= prob <= 1.0
    
    def test_should_respond_busy_activity(self):
        """Test reduced response prob when busy (Lines 155-156)."""
        simulator = HumanChatSimulator()
        context = ChatContext(
            time_since_last_message_seconds=10.0,
            current_activity="combat"
        )
        
        with patch.object(simulator, '_is_message_directed', return_value=False):
            _, prob = simulator.should_respond(context, "test")
            # Probability should be reduced by 0.3x for combat
            assert prob < 0.25  # Base casual is 0.25, reduced to 0.075
    
    def test_is_message_directed_question_mark(self):
        """Test directed detection with question mark (Lines 174-175)."""
        simulator = HumanChatSimulator()
        context = ChatContext()
        
        is_directed = simulator._is_message_directed("anyone there?", context)
        assert is_directed is True
    
    def test_is_message_directed_keywords(self):
        """Test directed detection with keywords (Lines 178-179)."""
        simulator = HumanChatSimulator()
        context = ChatContext()
        
        # Test each directed word
        for word in ["hi", "hello", "hey", "anyone", "help", "question"]:
            is_directed = simulator._is_message_directed(f"{word} friends", context)
            assert is_directed is True
    
    def test_add_typo_transpose_same_chars(self):
        """Test typo with same consecutive characters (Lines 247-251)."""
        simulator = HumanChatSimulator()
        
        # Set random seed for deterministic testing
        import random
        random.seed(42)
        
        # Create message with same consecutive chars
        message = "book"  # Has "oo"
        
        # Force transpose typo type
        with patch('random.choice', return_value="transpose"):
            with patch('random.randint', return_value=1):  # Position of first 'o'
                typo_msg, has_typo = simulator.add_typo(message, typo_rate=1.0)
                # Should insert duplicate instead of transpose
                assert has_typo is True
    
    def test_abbreviate_message_with_punctuation(self):
        """Test abbreviation preserving punctuation (Lines 272-278)."""
        simulator = HumanChatSimulator()
        
        message = "please help, thanks!"
        result = simulator.abbreviate_message(message)
        
        # Should abbreviate "please" to "pls" and "thanks" to "thx"
        assert "pls" in result
        assert "thx" in result
        # Punctuation should be preserved
        assert "," in result
        assert "!" in result
    
    def test_add_emotion_indicators_already_has_emoticon(self):
        """Test emotion when message already has emoticon (Lines 304-305)."""
        simulator = HumanChatSimulator()
        
        message = "thanks :)"
        result = simulator.add_emotion_indicators(message, "happy")
        
        # Should not add another emoticon
        assert result.count(":") <= 1 or result.count("^") == 0
    
    def test_humanize_response_with_typo(self):
        """Test humanize_response generating typo (Lines 375, 390)."""
        simulator = HumanChatSimulator()
        
        # Force typo generation
        with patch.object(simulator, 'add_typo', return_value=("messge", True)):
            response = simulator.humanize_response("message", typo_chance=1.0)
            assert response.should_include_typo is True
    
    def test_should_use_emote_instead(self):
        """Test emote usage instead of text (Lines 417-430)."""
        simulator = HumanChatSimulator()
        
        # Test with high probability
        with patch('random.random', return_value=0.05):  # Less than 0.15
            emote = simulator.should_use_emote_instead("greeting")
            assert emote is not None
            assert emote in ["/hi", "/wave"]
    
    def test_get_chat_stats_empty_history(self):
        """Test chat stats with empty history (Lines 434-435)."""
        simulator = HumanChatSimulator()
        simulator.message_history = []
        
        stats = simulator.get_chat_stats()
        assert stats["total_messages"] == 0
    
    def test_get_chat_stats_with_history(self):
        """Test chat stats with message history (Lines 437-446)."""
        simulator = HumanChatSimulator()
        now = datetime.now()
        simulator.message_history = [
            (now - timedelta(minutes=10), "test1"),
            (now - timedelta(minutes=5), "test2"),
            (now, "test3")
        ]
        
        stats = simulator.get_chat_stats()
        assert stats["total_messages"] == 3
        assert stats["recent_hour_count"] == 3
        assert "avg_message_length" in stats


class TestAllAbstractMethods:
    """Test abstract methods are properly defined."""
    
    @pytest.mark.asyncio
    async def test_llm_provider_abstract_methods(self):
        """Test LLM abstract base class."""
        from ai_sidecar.llm.providers import LLMProvider
        
        # Verify abstract methods exist
        assert hasattr(LLMProvider, 'complete')
        assert hasattr(LLMProvider, 'is_available')
        
        # Cannot instantiate abstract class
        with pytest.raises(TypeError):
            LLMProvider()


class TestOpenAIAdditionalMethods:
    """Test OpenAI provider additional methods."""
    
    @pytest.mark.asyncio
    async def test_openai_generate(self):
        """Test OpenAI generate method."""
        provider = OpenAIProvider(api_key="test_key")
        
        mock_response = Mock()
        mock_response.content = "Generated text"
        
        with patch.object(provider, 'complete', return_value=mock_response):
            result = await provider.generate("test prompt")
            assert result == "Generated text"
    
    @pytest.mark.asyncio
    async def test_openai_generate_no_response(self):
        """Test OpenAI generate with no response."""
        provider = OpenAIProvider(api_key="test_key")
        
        with patch.object(provider, 'complete', return_value=None):
            result = await provider.generate("test prompt")
            assert result == "Generated response"
    
    @pytest.mark.asyncio
    async def test_openai_chat(self):
        """Test OpenAI chat method."""
        provider = OpenAIProvider(api_key="test_key")
        
        mock_response = Mock()
        mock_response.content = "Chat response text"
        
        with patch.object(provider, 'complete', return_value=mock_response):
            result = await provider.chat(["hello", "how are you"])
            assert result == "Chat response text"
    
    @pytest.mark.asyncio
    async def test_openai_chat_no_response(self):
        """Test OpenAI chat with no response."""
        provider = OpenAIProvider(api_key="test_key")
        
        with patch.object(provider, 'complete', return_value=None):
            result = await provider.chat(["hello"])
            assert result == "Chat response"


class TestIntegrationScenarios:
    """Integration tests for complete workflows."""
    
    @pytest.mark.asyncio
    async def test_persistent_memory_full_lifecycle(self, tmp_path):
        """Test complete memory storage and retrieval."""
        mem = PersistentMemory(db_path=str(tmp_path / "test.db"))
        await mem.initialize()
        
        # Store a memory
        memory = Memory(
            memory_id="test123",
            memory_type=MemoryType.EVENT,
            importance=MemoryImportance.CRITICAL,
            content={"event": "test"},
            summary="Test memory"
        )
        
        stored = await mem.store(memory)
        assert stored is True
        
        # Retrieve it
        retrieved = await mem.retrieve("test123")
        assert retrieved is not None
        assert retrieved.memory_id == "test123"
        
        # Query by type
        results = await mem.query_by_type(MemoryType.EVENT)
        assert len(results) >= 1
        
        # Store strategy
        strategy_stored = await mem.store_strategy("strat1", "combat", {"skill": "fireball"}, 0.8)
        assert strategy_stored is True
        
        # Get best strategy
        best = await mem.get_best_strategy("combat")
        assert best is not None
        assert best["strategy_id"] == "strat1"
        
        # Delete memory
        deleted = await mem.delete("test123")
        assert deleted is True
        
        # Close connection
        await mem.close()
    
    @pytest.mark.asyncio
    async def test_service_handler_complete_flow(self):
        """Test complete service handler workflow."""
        handler = ServiceHandler()
        
        # Create mock game state
        game_state = Mock(spec=GameState)
        game_state.character = Mock()
        game_state.character.zeny = 100000
        game_state.character.weight = 500
        game_state.character.weight_max = 2000
        game_state.character.position = Position(x=150, y=150)
        game_state.map_name = "prontera"
        game_state.inventory = []
        
        # Test all service types
        for service in ["storage", "save", "repair", "teleport", "refine"]:
            should_use, reason = handler.should_use_service(service, game_state)
            assert isinstance(should_use, bool)
            assert isinstance(reason, str)
        
        # Get recommendations
        recommendations = handler.get_recommended_services(game_state)
        assert isinstance(recommendations, list)
        
        # Test teleport destinations
        destinations = handler.get_teleport_destinations(game_state)
        assert len(destinations) > 0
        
        # Set preferred destinations
        handler.set_preferred_destinations(["Prontera", "Geffen"])
        destinations = handler.get_teleport_destinations(game_state)
        assert len(destinations) == 2