"""
Tests for progression/manager.py - Progression orchestration.

Covers:
- ProgressionManager initialization  
- Lifecycle tick integration
- Job advancement integration
- Stat allocation integration
- Build type updates
- Progression status reporting
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock, PropertyMock
import tempfile

from ai_sidecar.progression.manager import ProgressionManager
from ai_sidecar.progression.lifecycle import LifecycleState
from ai_sidecar.progression.stats import BuildType
from ai_sidecar.core.decision import Action, ActionType


@pytest.fixture
def temp_dirs():
    """Create temporary directories for testing."""
    with tempfile.TemporaryDirectory() as data_dir, \
         tempfile.TemporaryDirectory() as state_dir:
        yield Path(data_dir), Path(state_dir)


@pytest.fixture
def mock_character():
    """Create mock character state."""
    char = Mock()
    char.name = "TestChar"
    char.job_class = "Knight"
    char.base_level = 50
    char.job_level = 40
    char.stat_points = 10
    char.skill_points = 5
    return char


@pytest.fixture  
def mock_game_state(mock_character):
    """Create mock game state."""
    state = Mock()
    state.character = mock_character
    state.tick = 100
    return state


@pytest.fixture
def manager(temp_dirs):
    """Create ProgressionManager with temp directories."""
    data_dir, state_dir = temp_dirs
    return ProgressionManager(
        data_dir=data_dir,
        state_dir=state_dir,
        build_type=BuildType.HYBRID,
        soft_cap=99,
    )


# =============================================================================
# Initialization Tests
# =============================================================================

def test_progression_manager_init(temp_dirs):
    """Test ProgressionManager initialization."""
    data_dir, state_dir = temp_dirs
    
    manager = ProgressionManager(
        data_dir=data_dir,
        state_dir=state_dir,
        build_type=BuildType.MELEE_DPS,
        soft_cap=99,
        preferred_jobs={"first": "Knight"}
    )
    
    assert manager.data_dir == data_dir
    assert manager.state_dir == state_dir
    assert manager.lifecycle is not None
    assert manager.stat_engine is not None
    assert manager.job_system is not None
    assert not manager._initialized


def test_progression_manager_creates_directories(temp_dirs):
    """Test that manager creates required directories."""
    data_dir, state_dir = temp_dirs
    
    # Remove directories
    data_dir.rmdir()
    state_dir.rmdir()
    
    manager = ProgressionManager(
        data_dir=data_dir,
        state_dir=state_dir,
    )
    
    # Should recreate them
    assert data_dir.exists()
    assert state_dir.exists()


@pytest.mark.asyncio
async def test_initialize(manager):
    """Test async initialization."""
    with patch.object(manager.job_system, 'validate_job_path_continuity', return_value=[]):
        await manager.initialize()
        
        assert manager._initialized


@pytest.mark.asyncio
async def test_initialize_with_validation_errors(manager):
    """Test initialization with job path validation errors."""
    errors = ["Error 1", "Error 2", "Error 3"]
    
    with patch.object(manager.job_system, 'validate_job_path_continuity', return_value=errors):
        await manager.initialize()
        
        # Should still initialize despite errors
        assert manager._initialized


@pytest.mark.asyncio
async def test_initialize_idempotent(manager):
    """Test initialize is idempotent."""
    with patch.object(manager.job_system, 'validate_job_path_continuity', return_value=[]):
        await manager.initialize()
        await manager.initialize()  # Second call
        
        assert manager._initialized


# =============================================================================
# Tick Function Tests
# =============================================================================

@pytest.mark.asyncio
async def test_tick_auto_initializes(manager, mock_game_state):
    """Test tick auto-initializes if not initialized."""
    with patch.object(manager, 'initialize', new_callable=AsyncMock) as mock_init, \
         patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[]):
        
        await manager.tick(mock_game_state)
        
        mock_init.assert_called_once()


@pytest.mark.asyncio
async def test_tick_lifecycle_actions(manager, mock_game_state, mock_character):
    """Test tick returns lifecycle actions."""
    manager._initialized = True
    
    lifecycle_action = Action(type=ActionType.MOVE, priority=8)
    
    with patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[lifecycle_action]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[]):
        
        actions = await manager.tick(mock_game_state)
        
        assert len(actions) >= 1
        assert lifecycle_action in actions


@pytest.mark.asyncio
async def test_tick_job_advancement_actions(manager, mock_game_state, mock_character):
    """Test tick returns job advancement actions."""
    manager._initialized = True
    
    job_action = Action(type=ActionType.TALK_NPC, priority=7)
    
    with patch.object(type(manager.lifecycle), 'current_state', new_callable=PropertyMock, return_value=LifecycleState.NOVICE), \
         patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[job_action]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[]):
        
        actions = await manager.tick(mock_game_state)
        
        assert len(actions) >= 1
        assert job_action in actions


@pytest.mark.asyncio
async def test_tick_stat_allocation_actions(manager, mock_game_state, mock_character):
    """Test tick returns stat allocation actions."""
    manager._initialized = True
    mock_character.stat_points = 10
    
    stat_action = Action(type=ActionType.COMMAND, priority=6)
    
    with patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[stat_action]):
        
        actions = await manager.tick(mock_game_state)
        
        assert len(actions) >= 1
        assert stat_action in actions


@pytest.mark.asyncio
async def test_tick_no_stat_points(manager, mock_game_state, mock_character):
    """Test tick when no stat points available."""
    manager._initialized = True
    mock_character.stat_points = 0
    
    with patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock) as mock_stat:
        
        actions = await manager.tick(mock_game_state)
        
        # Stat engine should not be called
        assert not mock_stat.called


@pytest.mark.asyncio
async def test_tick_all_systems(manager, mock_game_state, mock_character):
    """Test tick with all systems returning actions."""
    manager._initialized = True
    mock_character.stat_points = 5
    
    lifecycle_action = Action(type=ActionType.MOVE, priority=8)
    job_action = Action(type=ActionType.TALK_NPC, priority=7)
    stat_action = Action(type=ActionType.COMMAND, priority=6)
    
    with patch.object(type(manager.lifecycle), 'current_state', new_callable=PropertyMock, return_value=LifecycleState.FIRST_JOB), \
         patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[lifecycle_action]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[job_action]), \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[stat_action]):
        
        actions = await manager.tick(mock_game_state)
        
        assert len(actions) == 3
        assert lifecycle_action in actions
        assert job_action in actions
        assert stat_action in actions


@pytest.mark.asyncio
async def test_tick_job_advancement_only_relevant_states(manager, mock_game_state, mock_character):
    """Test job advancement only checked in relevant lifecycle states."""
    manager._initialized = True
    
    # Test all relevant states
    relevant_states = [
        LifecycleState.NOVICE,
        LifecycleState.FIRST_JOB,
        LifecycleState.SECOND_JOB,
        LifecycleState.REBIRTH,
    ]
    
    for state in relevant_states:
        with patch.object(type(manager.lifecycle), 'current_state', new_callable=PropertyMock, return_value=state), \
             patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
             patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock, return_value=[]) as mock_job, \
             patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[]):
            
            await manager.tick(mock_game_state)
            
            assert mock_job.called


@pytest.mark.asyncio
async def test_tick_job_advancement_skipped_in_endgame(manager, mock_game_state, mock_character):
    """Test job advancement skipped in ENDGAME state."""
    manager._initialized = True
    
    with patch.object(type(manager.lifecycle), 'current_state', new_callable=PropertyMock, return_value=LifecycleState.ENDGAME), \
         patch.object(manager.lifecycle, 'tick', new_callable=AsyncMock, return_value=[]), \
         patch.object(manager.job_system, 'check_advancement', new_callable=AsyncMock) as mock_job, \
         patch.object(manager.stat_engine, 'allocate_points', new_callable=AsyncMock, return_value=[]):
        
        await manager.tick(mock_game_state)
        
        # Should not check job advancement in ENDGAME
        assert not mock_job.called


# =============================================================================
# Build Type Management Tests
# =============================================================================

def test_update_build_type(manager):
    """Test updating build type."""
    original_soft_cap = manager.stat_engine.soft_cap
    
    manager.update_build_type(BuildType.TANK)
    
    assert manager.stat_engine.build_type == BuildType.TANK
    assert manager.stat_engine.soft_cap == original_soft_cap


def test_auto_detect_build(manager, mock_character):
    """Test auto-detecting build from job class."""
    mock_character.job_class = "Wizard"
    
    with patch.object(manager.stat_engine, 'recommend_build_for_job', return_value=BuildType.MAGIC_DPS):
        build = manager.auto_detect_build(mock_character)
        
        assert build == BuildType.MAGIC_DPS


# =============================================================================
# Status Reporting Tests
# =============================================================================

def test_get_progression_status(manager, mock_character):
    """Test getting comprehensive progression status."""
    transition_progress = {"level_progress": 75}
    goals = ["Reach level 50"]
    stat_summary = {"str": 40, "agi": 30}
    job_summary = {"current_job": "Knight"}
    
    with patch.object(manager.lifecycle, 'get_transition_progress', return_value=transition_progress), \
         patch.object(manager.lifecycle, 'get_state_goals', return_value=goals), \
         patch.object(manager.stat_engine, 'get_stat_distribution_summary', return_value=stat_summary), \
         patch.object(manager.job_system, 'get_job_path_summary', return_value=job_summary):
        
        status = manager.get_progression_status(mock_character)
        
        assert "lifecycle" in status
        assert "stats" in status
        assert "job" in status
        assert "character" in status
        assert status["lifecycle"]["current_state"] == manager.lifecycle.current_state.value
        assert status["lifecycle"]["transition_progress"] == transition_progress
        assert status["lifecycle"]["goals"] == goals
        assert status["stats"] == stat_summary
        assert status["job"] == job_summary
        assert status["character"]["name"] == "TestChar"


# =============================================================================
# Lifecycle State Management Tests
# =============================================================================

def test_force_lifecycle_state(manager):
    """Test forcing lifecycle state."""
    with patch.object(manager.lifecycle, 'force_state') as mock_force:
        manager.force_lifecycle_state(LifecycleState.SECOND_JOB)
        
        mock_force.assert_called_with(LifecycleState.SECOND_JOB)


# =============================================================================
# Shutdown Tests
# =============================================================================

@pytest.mark.asyncio
async def test_shutdown(manager):
    """Test manager shutdown."""
    manager._initialized = True
    
    await manager.shutdown()
    
    assert not manager._initialized