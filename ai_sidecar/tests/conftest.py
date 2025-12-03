"""
Pytest configuration and shared fixtures for AI Sidecar tests.

Provides common fixtures for testing including mock game state,
memory managers, IPC bridges, and test data factories.
"""

import asyncio
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List
from unittest.mock import AsyncMock, MagicMock, Mock

import pytest
import pytest_asyncio

# Ensure proper PYTHONPATH for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))
os.environ['PYTHONPATH'] = str(Path(__file__).parent.parent.parent)


# ============================================================================
# Pytest Configuration
# ============================================================================

def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers",
        "asyncio: mark test as async test"
    )
    config.addinivalue_line(
        "markers", 
        "integration: mark test as integration test"
    )
    config.addinivalue_line(
        "markers",
        "unit: mark test as unit test"
    )


# ============================================================================
# Event Loop Fixtures
# ============================================================================

@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


# ============================================================================
# Mock Game State Fixtures
# ============================================================================

@pytest.fixture
def mock_character_state() -> Dict[str, Any]:
    """Mock character state data."""
    return {
        "name": "TestChar",
        "job": "Knight",
        "base_level": 99,
        "job_level": 50,
        "hp": 8500,
        "hp_max": 10000,
        "sp": 350,
        "sp_max": 500,
        "str": 99,
        "agi": 70,
        "vit": 80,
        "int": 30,
        "dex": 50,
        "luk": 40,
        "zeny": 1000000,
        "weight": 1500,
        "weight_max": 2000,
        "skill_points": 5,
        "stat_points": 0,
        "position": {"x": 100, "y": 150, "map": "prontera"},
        "status_effects": [],
        "inventory": {},
    }


@pytest.fixture
def mock_game_state(mock_character_state) -> Mock:
    """Mock GameState object."""
    state = Mock()
    state.tick = 1000
    state.character = Mock(**mock_character_state)
    state.monsters = []
    state.npcs = []
    state.players = []
    state.items = []
    state.map_name = "prontera"
    state.is_in_combat = False
    
    # Add helper methods
    state.get_monsters = Mock(return_value=[])
    state.get_npcs = Mock(return_value=[])
    state.get_nearby_players = Mock(return_value=[])
    
    return state


@pytest.fixture
def mock_monster() -> Dict[str, Any]:
    """Mock monster data."""
    return {
        "id": 1001,
        "name": "Poring",
        "type": "MONSTER",
        "level": 5,
        "hp": 100,
        "hp_max": 100,
        "position": {"x": 110, "y": 160},
        "distance": 15,
        "is_aggressive": False,
        "element": "neutral",
    }


@pytest.fixture
def mock_npc() -> Dict[str, Any]:
    """Mock NPC data."""
    return {
        "id": 2001,
        "name": "Kafra Employee",
        "type": "NPC",
        "position": {"x": 150, "y": 180},
        "distance": 25,
        "services": ["storage", "teleport", "cart"],
    }


# ============================================================================
# Mock Memory Manager Fixtures
# ============================================================================

@pytest.fixture
def mock_memory_manager() -> Mock:
    """Mock Memory Manager."""
    manager = Mock()
    manager.store = AsyncMock(return_value={"success": True})
    manager.retrieve = AsyncMock(return_value=[])
    manager.search = AsyncMock(return_value=[])
    manager.get_recent_events = AsyncMock(return_value=[])
    manager.get_context = AsyncMock(return_value={"context": "test"})
    return manager


# ============================================================================
# Mock IPC Bridge Fixtures
# ============================================================================

@pytest.fixture
def mock_ipc_bridge() -> Mock:
    """Mock IPC Bridge for communication with OpenKore."""
    bridge = Mock()
    bridge.send_command = AsyncMock(return_value={"success": True})
    bridge.send_action = AsyncMock(return_value={"success": True})
    bridge.get_game_state = AsyncMock(return_value={})
    bridge.is_connected = Mock(return_value=True)
    bridge.connect = AsyncMock(return_value=True)
    bridge.disconnect = AsyncMock(return_value=True)
    return bridge


# ============================================================================
# Test Data Factories
# ============================================================================

@pytest.fixture
def create_test_action():
    """Factory for creating test Action objects."""
    def _create(
        action_type: str = "move",
        priority: int = 5,
        **kwargs
    ):
        from ai_sidecar.core.decision import Action, ActionType
        return Action(
            type=ActionType(action_type),
            priority=priority,
            **kwargs
        )
    return _create


@pytest.fixture
def create_test_decision_result():
    """Factory for creating test DecisionResult objects."""
    def _create(
        tick: int = 1000,
        actions: List = None,
        fallback_mode: str = "cpu",
        **kwargs
    ):
        from ai_sidecar.core.decision import DecisionResult
        return DecisionResult(
            tick=tick,
            actions=actions or [],
            fallback_mode=fallback_mode,
            **kwargs
        )
    return _create


@pytest.fixture
def create_test_buff():
    """Factory for creating test BuffState objects."""
    def _create(
        buff_id: str = "blessing",
        buff_name: str = "Blessing",
        duration: float = 120.0,
        **kwargs
    ):
        from ai_sidecar.consumables.buffs import BuffState, BuffCategory, BuffSource, BuffPriority
        return BuffState(
            buff_id=buff_id,
            buff_name=buff_name,
            category=kwargs.get("category", BuffCategory.OFFENSIVE),
            source=kwargs.get("source", BuffSource.SELF_SKILL),
            priority=kwargs.get("priority", BuffPriority.HIGH),
            start_time=kwargs.get("start_time", datetime.now()),
            base_duration_seconds=duration,
            remaining_seconds=kwargs.get("remaining_seconds", duration),
            **{k: v for k, v in kwargs.items() if k not in ["category", "source", "priority", "start_time", "remaining_seconds"]}
        )
    return _create


@pytest.fixture
def create_test_status_effect():
    """Factory for creating test StatusEffectState objects."""
    def _create(
        effect_type: str = "poison",
        severity: int = 5,
        **kwargs
    ):
        from ai_sidecar.consumables.status_effects import StatusEffectState, StatusEffectType, StatusSeverity
        return StatusEffectState(
            effect_type=StatusEffectType(effect_type),
            severity=StatusSeverity(severity),
            inflicted_time=kwargs.get("inflicted_time", datetime.now()),
            **{k: v for k, v in kwargs.items() if k not in ["inflicted_time"]}
        )
    return _create


@pytest.fixture
def create_test_recovery_item():
    """Factory for creating test RecoveryItem objects."""
    def _create(
        item_id: int = 501,
        item_name: str = "Red Potion",
        recovery_type: str = "hp_instant",
        base_recovery: int = 45,
        **kwargs
    ):
        from ai_sidecar.consumables.recovery import RecoveryItem, RecoveryType
        return RecoveryItem(
            item_id=item_id,
            item_name=item_name,
            recovery_type=RecoveryType(recovery_type),
            base_recovery=base_recovery,
            weight=kwargs.get("weight", 7),
            price=kwargs.get("price", 50),
            **{k: v for k, v in kwargs.items() if k not in ["weight", "price"]}
        )
    return _create


# ============================================================================
# Async Test Setup/Teardown
# ============================================================================

@pytest_asyncio.fixture
async def async_test_setup():
    """Setup for async tests."""
    # Setup code here
    yield
    # Teardown code here
    await asyncio.sleep(0)  # Allow pending tasks to complete


@pytest.fixture
def temp_test_dir(tmp_path) -> Path:
    """Create a temporary directory for test files."""
    test_dir = tmp_path / "test_data"
    test_dir.mkdir()
    return test_dir


@pytest.fixture
def mock_config() -> Dict[str, Any]:
    """Mock configuration data."""
    return {
        "decision": {
            "engine_type": "stub",
            "fallback_mode": "cpu",
        },
        "ipc": {
            "host": "localhost",
            "port": 8888,
            "timeout": 5.0,
        },
        "logging": {
            "level": "INFO",
            "format": "json",
        },
    }


# ============================================================================
# Mock Component Fixtures
# ============================================================================

@pytest.fixture
def mock_buff_manager() -> Mock:
    """Mock BuffManager."""
    manager = Mock()
    manager.active_buffs = {}
    manager.update_buff_timers = AsyncMock()
    manager.check_rebuff_needs = AsyncMock(return_value=[])
    manager.get_rebuff_action = AsyncMock(return_value=None)
    manager.add_buff = Mock()
    manager.remove_buff = Mock()
    return manager


@pytest.fixture
def mock_status_manager() -> Mock:
    """Mock StatusEffectManager."""
    manager = Mock()
    manager.active_effects = {}
    manager.detect_status_effects = AsyncMock(return_value=[])
    manager.prioritize_cures = AsyncMock(return_value=[])
    manager.get_cure_action = AsyncMock(return_value=None)
    manager.has_critical_status = Mock(return_value=False)
    return manager


@pytest.fixture
def mock_recovery_manager() -> Mock:
    """Mock RecoveryManager."""
    manager = Mock()
    manager.inventory = {}
    manager.evaluate_recovery_need = AsyncMock(return_value=None)
    manager.emergency_recovery = AsyncMock(return_value=None)
    manager.select_optimal_item = AsyncMock(return_value=None)
    manager.update_inventory = Mock()
    return manager


@pytest.fixture
def mock_food_manager() -> Mock:
    """Mock FoodManager."""
    manager = Mock()
    manager.active_food_buffs = {}
    manager.update_food_timers = AsyncMock()
    manager.check_food_needs = AsyncMock(return_value=[])
    manager.get_optimal_food_set = AsyncMock(return_value=[])
    manager.apply_food = Mock(return_value=True)
    return manager


@pytest.fixture
def mock_combat_manager() -> Mock:
    """Mock CombatManager."""
    manager = Mock()
    manager.tick = AsyncMock(return_value=[])
    manager.initialize = Mock()
    manager.set_tactical_role = Mock()
    manager.set_build_type = Mock()
    return manager


@pytest.fixture
def mock_equipment_manager() -> Mock:
    """Mock EquipmentManager."""
    manager = Mock()
    manager.tick = AsyncMock(return_value=[])
    manager.initialize = Mock()
    manager.set_build_type = Mock()
    return manager


# ============================================================================
# Integration Test Fixtures
# ============================================================================

@pytest.fixture
def integration_test_config() -> Dict[str, Any]:
    """Configuration for integration tests."""
    return {
        "use_real_ipc": False,
        "use_real_memory": False,
        "timeout": 10.0,
    }


@pytest.fixture
def sample_inventory() -> Dict[int, int]:
    """Sample inventory for testing."""
    return {
        501: 50,   # Red Potion x50
        502: 30,   # Orange Potion x30
        503: 20,   # Yellow Potion x20
        504: 10,   # White Potion x10
        505: 25,   # Blue Potion x25
    }


# ============================================================================
# Settings and Configuration Fixtures
# ============================================================================

@pytest.fixture
def settings():
    """Provide test settings."""
    from ai_sidecar.config import get_settings
    return get_settings()


@pytest.fixture
def mock_zmq_context() -> Mock:
    """Mock ZMQ context for IPC tests."""
    context = Mock()
    socket = Mock()
    socket.bind = Mock()
    socket.connect = Mock()
    socket.send_json = Mock()
    socket.recv_json = Mock(return_value={})
    socket.close = Mock()
    context.socket = Mock(return_value=socket)
    context.term = Mock()
    return context


@pytest.fixture
def sample_game_state() -> Dict[str, Any]:
    """Provide sample game state for testing."""
    return {
        "tick": 1000,
        "character": {
            "name": "TestChar",
            "job": "Knight",
            "base_level": 99,
            "job_level": 50,
            "hp": 8500,
            "hp_max": 10000,
            "sp": 350,
            "sp_max": 500,
            "position": {"x": 100, "y": 150, "map": "prontera"},
        },
        "monsters": [],
        "npcs": [],
        "players": [],
        "items": [],
    }


@pytest.fixture
def mock_llm_client() -> Mock:
    """Mock LLM client that returns predictable responses."""
    client = Mock()
    client.generate = AsyncMock(return_value={
        "decision": "attack",
        "reasoning": "Test reasoning",
        "confidence": 0.85
    })
    client.is_connected = Mock(return_value=True)
    return client


# ============================================================================
# Auto-use Fixtures for Test Isolation
# ============================================================================

@pytest.fixture(autouse=True)
def reset_singletons():
    """Reset singleton instances between tests."""
    # Clear any cached singletons
    yield
    # Cleanup after test
    import gc
    gc.collect()


@pytest.fixture(autouse=True)
def isolate_asyncio():
    """Ensure asyncio isolation between tests."""
    # Get fresh event loop for each test
    yield
    # Close any pending tasks
    try:
        loop = asyncio.get_event_loop()
        pending = asyncio.all_tasks(loop)
        for task in pending:
            task.cancel()
    except RuntimeError:
        pass


@pytest.fixture(autouse=True)
def cleanup_logging_context():
    """Clean up logging context between tests to prevent pollution."""
    # Clean up before each test
    try:
        from ai_sidecar.utils.logging import clear_context
        clear_context()
    except Exception:
        pass  # Ignore if module doesn't exist
    
    yield
    
    # Clean up after each test
    try:
        from ai_sidecar.utils.logging import clear_context
        clear_context()
    except Exception:
        pass  # Ignore if module doesn't exist


# ============================================================================
# IPC Test Fixtures
# ============================================================================

@pytest_asyncio.fixture
async def client():
    """Provide IPC test client for integration tests."""
    import sys
    from pathlib import Path
    
    # Add tests directory to path to import test_ipc
    tests_dir = Path(__file__).parent
    if str(tests_dir) not in sys.path:
        sys.path.insert(0, str(tests_dir))
    
    from test_ipc import IPCTestClient
    
    # Create client but don't connect (tests are unit tests, not integration)
    # If tests need real connection, they should be marked as integration tests
    test_client = IPCTestClient()
    
    # Mock the connection for unit tests
    test_client.socket = Mock()
    test_client.context = Mock()
    test_client.socket.send_string = AsyncMock()
    test_client.socket.recv_string = AsyncMock(return_value='{"type": "heartbeat", "status": "ok"}')
    
    yield test_client
    
    # Cleanup
    test_client.socket = None
    test_client.context = None