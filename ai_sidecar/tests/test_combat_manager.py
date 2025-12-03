"""
Tests for combat/manager.py - Combat orchestration system.

Covers:
- CombatManager initialization and configuration  
- Emergency handling (critical HP, low HP/SP)
- Skill point allocation coordination
- Combat action conversion
- Inventory management
- Build type detection
- Tactical role management
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.combat.manager import (
    CombatManager,
    CombatManagerConfig,
    EmergencyItem,
)
from ai_sidecar.combat.models import CombatAction, CombatActionType, CombatContext
from ai_sidecar.combat.tactics import TacticalRole
from ai_sidecar.combat.combat_ai import CombatAIConfig, CombatState
from ai_sidecar.core.decision import Action, ActionType


# =============================================================================
# Fixtures
# =============================================================================

@pytest.fixture
def mock_character():
    """Create mock character state."""
    from ai_sidecar.core.state import Position
    char = Mock()
    char.job = "Knight"
    char.name = "TestCharacter"
    char.hp = 1000
    char.hp_max = 2000
    char.sp = 200
    char.sp_max = 500
    char.skill_points = 10
    char.stat_points = 0
    char.inventory = {501: 5, 502: 3, 505: 2}  # Red, Orange, Blue potions
    char.position = Position(x=100, y=100)  # Required for CombatContext
    # Stats required by CharacterState
    char.str = 40
    char.agi = 30
    char.vit = 35
    char.int = 25
    char.dex = 30
    char.luk = 20
    return char


@pytest.fixture
def mock_game_state(mock_character):
    """Create mock game state."""
    state = Mock()
    state.character = mock_character
    state.tick = 100
    state.monsters = []
    state.inventory = mock_character.inventory
    return state


@pytest.fixture
def combat_manager():
    """Create CombatManager with default config."""
    return CombatManager()


@pytest.fixture
def combat_manager_custom():
    """Create CombatManager with custom config."""
    config = CombatManagerConfig(
        enable_skill_allocation=False,
        enable_emergency_handling=True,
        emergency_hp_percent=0.15,
        low_hp_percent=0.30,
        auto_detect_role=False,
    )
    return CombatManager(config=config)


# =============================================================================
# Initialization Tests
# =============================================================================

def test_combat_manager_init_default():
    """Test CombatManager initialization with defaults."""
    manager = CombatManager()
    
    assert manager.config is not None
    assert manager.config.enable_skill_allocation is True
    assert manager.config.enable_combat_ai is True
    assert manager.config.enable_emergency_handling is True
    assert manager.skill_system is not None
    assert manager.combat_ai is not None
    assert manager.skill_db is not None
    assert not manager._initialized


def test_combat_manager_init_custom_config():
    """Test CombatManager initialization with custom config."""
    config = CombatManagerConfig(
        enable_skill_allocation=False,
        emergency_hp_percent=0.15,
        low_hp_percent=0.30,
        max_actions_per_tick=3,
    )
    
    manager = CombatManager(config=config)
    
    assert manager.config.enable_skill_allocation is False
    assert manager.config.emergency_hp_percent == 0.15
    assert manager.config.low_hp_percent == 0.30
    assert manager.config.max_actions_per_tick == 3


def test_combat_manager_init_with_combat_ai_config():
    """Test CombatManager initialization with CombatAI config."""
    combat_ai_config = CombatAIConfig(
        aggression_level=0.7,
        default_role=TacticalRole.MELEE_DPS,
    )
    
    manager = CombatManager(combat_ai_config=combat_ai_config)
    
    assert manager.combat_ai is not None


def test_emergency_item_dataclass():
    """Test EmergencyItem dataclass."""
    item = EmergencyItem(
        item_id=501,
        item_name="Red Potion",
        heal_amount=45,
        is_percent=False,
    )
    
    assert item.item_id == 501
    assert item.item_name == "Red Potion"
    assert item.heal_amount == 45
    assert not item.is_percent


# =============================================================================
# Initialization Tests
# =============================================================================

def test_initialize_auto_detect_role(combat_manager, mock_character):
    """Test initialization with auto role detection."""
    mock_character.job = "Wizard"
    
    with patch.object(combat_manager.combat_ai, 'set_role') as mock_set_role:
        combat_manager.initialize(mock_character)
        
        assert combat_manager._initialized
        mock_set_role.assert_called_once()


def test_initialize_with_default_role(combat_manager_custom, mock_character):
    """Test initialization with manual role setting."""
    # Set default role in config
    combat_manager_custom.config = CombatManagerConfig(
        auto_detect_role=False,
        default_tactical_role=TacticalRole.TANK,
    )
    
    with patch.object(combat_manager_custom.combat_ai, 'set_role') as mock_set_role:
        combat_manager_custom.initialize(mock_character)
        
        assert combat_manager_custom._initialized
        mock_set_role.assert_called_with(TacticalRole.TANK)


def test_initialize_detect_build_type(combat_manager, mock_character):
    """Test build type detection during initialization."""
    mock_character.job = "Knight"
    
    with patch.object(combat_manager.skill_system, 'set_build_type') as mock_set_build:
        combat_manager.initialize(mock_character)
        
        assert combat_manager._initialized
        mock_set_build.assert_called_once()


# =============================================================================
# Tick Function Tests
# =============================================================================

@pytest.mark.asyncio
async def test_tick_not_initialized(combat_manager, mock_game_state, mock_character):
    """Test tick auto-initializes if not initialized."""
    with patch.object(combat_manager, 'initialize') as mock_init, \
         patch.object(combat_manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock) as mock_eval:
        
        mock_eval.return_value = CombatContext(
            character=mock_character,
            nearby_monsters=[],
            threat_level=0.0,
        )
        
        await combat_manager.tick(mock_game_state)
        
        mock_init.assert_called_once_with(mock_game_state.character)


@pytest.mark.asyncio
async def test_tick_emergency_takes_priority(combat_manager, mock_game_state, mock_character):
    """Test emergency actions take priority over all others."""
    combat_manager._initialized = True
    
    # Critical HP
    mock_character.hp = 100
    mock_character.hp_max = 1000
    mock_character.inventory = {501: 5}
    mock_game_state.inventory = {501: 5}  # Update game state inventory too
    
    actions = await combat_manager.tick(mock_game_state)
    
    assert len(actions) == 1
    assert actions[0].type == ActionType.USE_ITEM
    assert actions[0].target_id == 501  # Red potion
    assert actions[0].priority == 10


@pytest.mark.asyncio
async def test_tick_skill_allocation(combat_manager, mock_game_state, mock_character):
    """Test skill allocation during tick."""
    combat_manager._initialized = True
    
    # Normal HP (no emergency)
    mock_character.hp = 1500
    mock_character.hp_max = 2000
    mock_character.skill_points = 5
    
    # Mock skill allocation
    skill_action = Action(
        type=ActionType.SKILL,
        skill_id=1,
        priority=5,
    )
    
    with patch.object(combat_manager.skill_system, 'allocate_skill_point', return_value=skill_action), \
         patch.object(combat_manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock) as mock_eval:
        
        mock_eval.return_value = CombatContext(
            character=mock_character,
            nearby_monsters=[],
            threat_level=0.0,
        )
        
        actions = await combat_manager.tick(mock_game_state)
        
        assert any(a.type == ActionType.SKILL for a in actions)


@pytest.mark.asyncio
async def test_tick_combat_actions(combat_manager, mock_game_state, mock_character):
    """Test combat actions during tick."""
    combat_manager._initialized = True
    
    # Normal HP
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.skill_points = 0
    
    # Mock combat
    combat_action = CombatAction(
        action_type=CombatActionType.ATTACK,
        target_id=1001,
        priority=7,
    )
    
    context = CombatContext(
        character=mock_character,
        nearby_monsters=[],  # Simplified for testing
        threat_level=0.5,
    )
    
    with patch.object(combat_manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock, return_value=context), \
         patch.object(combat_manager.combat_ai, 'decide', new_callable=AsyncMock, return_value=[combat_action]):
        
        actions = await combat_manager.tick(mock_game_state)
        
        assert len(actions) > 0
        assert any(a.type == ActionType.ATTACK for a in actions)


@pytest.mark.asyncio
async def test_tick_max_actions_limit(combat_manager, mock_game_state, mock_character):
    """Test max actions per tick limit."""
    combat_manager._initialized = True
    combat_manager.config = CombatManagerConfig(max_actions_per_tick=2)
    
    # Normal HP
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.skill_points = 0
    
    # Return many combat actions
    combat_actions = [
        CombatAction(action_type=CombatActionType.ATTACK, target_id=i, priority=5)
        for i in range(10)
    ]
    
    context = CombatContext(
        character=mock_character,
        nearby_monsters=[],
        threat_level=0.8,
    )
    
    with patch.object(combat_manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock, return_value=context), \
         patch.object(combat_manager.combat_ai, 'decide', new_callable=AsyncMock, return_value=combat_actions):
        
        actions = await combat_manager.tick(mock_game_state)
        
        # Should be limited to max_actions_per_tick
        assert len(actions) <= 2


@pytest.mark.asyncio
async def test_tick_features_disabled(mock_game_state, mock_character):
    """Test tick with all features disabled."""
    config = CombatManagerConfig(
        enable_skill_allocation=False,
        enable_combat_ai=False,
        enable_emergency_handling=False,
    )
    manager = CombatManager(config=config)
    manager._initialized = True
    
    # High HP
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    
    actions = await manager.tick(mock_game_state)
    
    assert len(actions) == 0


# =============================================================================
# Emergency Handling Tests
# =============================================================================

@pytest.mark.asyncio
async def test_check_emergencies_critical_hp_with_item(combat_manager, mock_game_state, mock_character):
    """Test emergency handling at critical HP with healing item."""
    # Critical HP: 10%
    mock_character.hp = 200
    mock_character.hp_max = 2000
    mock_character.inventory = {501: 5}
    
    action = await combat_manager._check_emergencies(mock_game_state)
    
    assert action is not None
    assert action.type == ActionType.USE_ITEM
    assert action.target_id == 501
    assert action.priority == 10


@pytest.mark.asyncio
async def test_check_emergencies_critical_hp_no_items(combat_manager, mock_game_state, mock_character):
    """Test emergency handling at critical HP without items."""
    # Critical HP: 10%
    mock_character.hp = 200
    mock_character.hp_max = 2000
    mock_character.inventory = {}
    mock_game_state.inventory = {}  # Update game state inventory too
    
    action = await combat_manager._check_emergencies(mock_game_state)
    
    assert action is not None
    assert action.type == ActionType.MOVE  # Flee
    assert action.priority == 10


@pytest.mark.asyncio
async def test_check_emergencies_low_hp(combat_manager, mock_game_state, mock_character):
    """Test emergency handling at low HP."""
    # Low HP: 30%
    mock_character.hp = 600
    mock_character.hp_max = 2000
    mock_character.inventory = {502: 3}  # Orange potion
    
    action = await combat_manager._check_emergencies(mock_game_state)
    
    assert action is not None
    assert action.type == ActionType.USE_ITEM
    assert action.priority == 8


@pytest.mark.asyncio
async def test_check_emergencies_low_sp(combat_manager, mock_game_state, mock_character):
    """Test emergency handling at low SP."""
    # Normal HP, low SP
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.sp = 50
    mock_character.sp_max = 500
    mock_character.inventory = {505: 3}  # Blue potion
    
    action = await combat_manager._check_emergencies(mock_game_state)
    
    assert action is not None
    assert action.type == ActionType.USE_ITEM
    assert action.target_id == 505
    assert action.priority == 6


@pytest.mark.asyncio
async def test_check_emergencies_healthy(combat_manager, mock_game_state, mock_character):
    """Test no emergency when healthy."""
    # Healthy
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.sp = 400
    mock_character.sp_max = 500
    
    action = await combat_manager._check_emergencies(mock_game_state)
    
    assert action is None


# =============================================================================
# Skill Allocation Tests
# =============================================================================

def test_handle_skill_allocation_enabled(combat_manager, mock_character):
    """Test skill allocation when enabled."""
    mock_character.skill_points = 5
    
    skill_action = Action(
        type=ActionType.SKILL,
        skill_id=10,
        priority=5,
    )
    
    with patch.object(combat_manager.skill_system, 'allocate_skill_point', return_value=skill_action):
        action = combat_manager._handle_skill_allocation(mock_character)
        
        assert action is not None
        assert action.skill_id == 10


def test_handle_skill_allocation_disabled(combat_manager_custom, mock_character):
    """Test skill allocation when disabled."""
    combat_manager_custom.config = CombatManagerConfig(auto_allocate_skills=False)
    mock_character.skill_points = 5
    
    action = combat_manager_custom._handle_skill_allocation(mock_character)
    
    assert action is None


def test_handle_skill_allocation_no_points(combat_manager, mock_character):
    """Test skill allocation with no skill points."""
    mock_character.skill_points = 0
    
    action = combat_manager._handle_skill_allocation(mock_character)
    
    assert action is None


# =============================================================================
# Combat Action Conversion Tests
# =============================================================================

def test_convert_combat_action_skill(combat_manager):
    """Test converting SKILL combat action."""
    combat_action = CombatAction(
        action_type=CombatActionType.SKILL,
        skill_id=142,
        target_id=1001,
        priority=7,
    )
    
    action = combat_manager._convert_combat_action(combat_action)
    
    assert action is not None
    assert action.type == ActionType.SKILL
    assert action.skill_id == 142
    assert action.target_id == 1001
    assert action.priority == 7


def test_convert_combat_action_attack(combat_manager):
    """Test converting ATTACK combat action."""
    combat_action = CombatAction(
        action_type=CombatActionType.ATTACK,
        target_id=1001,
        priority=5,
    )
    
    action = combat_manager._convert_combat_action(combat_action)
    
    assert action is not None
    assert action.type == ActionType.ATTACK
    assert action.target_id == 1001


def test_convert_combat_action_item(combat_manager):
    """Test converting ITEM combat action."""
    combat_action = CombatAction(
        action_type=CombatActionType.ITEM,
        skill_id=501,  # Item ID
        priority=6,
    )
    
    action = combat_manager._convert_combat_action(combat_action)
    
    assert action is not None
    assert action.type == ActionType.USE_ITEM


def test_convert_combat_action_move(combat_manager):
    """Test converting MOVE combat action."""
    combat_action = CombatAction(
        action_type=CombatActionType.MOVE,
        priority=3,
    )
    
    action = combat_manager._convert_combat_action(combat_action)
    
    assert action is not None
    assert action.type == ActionType.MOVE


def test_convert_combat_action_flee(combat_manager):
    """Test converting FLEE combat action."""
    combat_action = CombatAction(
        action_type=CombatActionType.FLEE,
        priority=9,
    )
    
    action = combat_manager._convert_combat_action(combat_action)
    
    assert action is not None
    assert action.type == ActionType.MOVE
    assert action.priority == 9


# =============================================================================
# Healing Item Selection Tests
# =============================================================================

def test_find_best_healing_item_percent_at_low_hp(combat_manager, mock_game_state, mock_character):
    """Test percent-based heal gets efficiency bonus at very low HP."""
    mock_character.hp = 200
    mock_character.hp_max = 2000
    mock_character.inventory = {607: 1, 501: 10}  # Yggdrasil Berry + Red Potions
    mock_game_state.inventory = {607: 1, 501: 10}  # Update game state inventory too
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
    
    assert item is not None
    # With efficiency bonus at low HP (<30%), Yggdrasil Berry (100% heal) should win
    assert item.item_id == 607


def test_find_best_healing_item_efficient_selection(combat_manager, mock_game_state, mock_character):
    """Test efficient healing item selection."""
    mock_character.hp = 1900
    mock_character.hp_max = 2000
    mock_character.inventory = {501: 5, 502: 3, 504: 1}  # Red, Orange, White
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
    
    assert item is not None
    # All items available, should select based on efficiency


def test_find_best_healing_item_no_hp_items(combat_manager, mock_game_state, mock_character):
    """Test finding healing item when only SP items available."""
    mock_character.hp = 500
    mock_character.hp_max = 2000
    mock_character.inventory = {505: 3}  # Only Blue Potion (SP item)
    mock_game_state.inventory = {505: 3}  # Update game state inventory too
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
    
    # Should return None when no HP items available
    assert item is None


def test_find_best_healing_item_skip_sp_items(combat_manager, mock_game_state, mock_character):
    """Test that SP items are skipped when finding HP healing items."""
    mock_character.hp = 1000
    mock_character.hp_max = 2000
    mock_character.inventory = {505: 5, 501: 3}  # Blue potion (SP) + Red
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
    
    assert item is not None
    assert item.item_id == 501  # Should return Red, not Blue


def test_find_best_healing_item_zero_quantity(combat_manager, mock_game_state, mock_character):
    """Test items with zero quantity are skipped."""
    mock_character.hp = 1000
    mock_character.hp_max = 2000
    mock_character.inventory = {501: 0, 502: 3}  # Red (0), Orange (3)
    mock_game_state.inventory = {501: 0, 502: 3}  # Update game state inventory too
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
    
    assert item is not None
    assert item.item_id == 502  # Should skip Red with 0 quantity


# =============================================================================
# SP Recovery Tests
# =============================================================================

def test_find_sp_recovery_item_available(combat_manager, mock_game_state):
    """Test finding SP recovery item when available."""
    mock_game_state.inventory = {505: 3}
    
    item = combat_manager._find_sp_recovery_item(mock_game_state)
    
    assert item is not None
    assert item.item_id == 505
    assert item.item_name == "Blue Potion"


def test_find_sp_recovery_item_not_available(combat_manager, mock_game_state):
    """Test finding SP recovery item when not available."""
    mock_game_state.inventory = {501: 5}
    
    item = combat_manager._find_sp_recovery_item(mock_game_state)
    
    assert item is None


# =============================================================================
# Inventory Access Tests
# =============================================================================

def test_get_inventory_from_game_state(combat_manager):
    """Test getting inventory from game state."""
    game_state = Mock()
    game_state.inventory = {501: 5, 502: 3}
    
    inventory = combat_manager._get_inventory(game_state)
    
    assert inventory == {501: 5, 502: 3}


def test_get_inventory_from_character(combat_manager):
    """Test getting inventory from character."""
    game_state = Mock(spec=['character'])
    game_state.character = Mock()
    game_state.character.inventory = {503: 2}
    
    inventory = combat_manager._get_inventory(game_state)
    
    assert inventory == {503: 2}


def test_get_inventory_not_available(combat_manager):
    """Test getting inventory when not available."""
    game_state = Mock(spec=[])  # No inventory attribute
    game_state.character = Mock(spec=[])  # No inventory on character either
    
    inventory = combat_manager._get_inventory(game_state)
    
    assert inventory == {}


# =============================================================================
# Build Type Detection Tests
# =============================================================================

def test_detect_build_type_knight(combat_manager):
    """Test build type detection for Knight."""
    character = Mock()
    character.job = "Knight"
    
    build = combat_manager._detect_build_type(character)
    
    assert build is not None
    assert "knight" in build.lower()


def test_detect_build_type_wizard(combat_manager):
    """Test build type detection for Wizard."""
    character = Mock()
    character.job = "Wizard"
    
    build = combat_manager._detect_build_type(character)
    
    assert build is not None
    assert "wizard" in build.lower()


def test_detect_build_type_priest(combat_manager):
    """Test build type detection for Priest."""
    character = Mock()
    character.job = "Priest"
    
    build = combat_manager._detect_build_type(character)
    
    assert build is not None
    assert "priest" in build.lower()


def test_detect_build_type_unknown_job(combat_manager):
    """Test build type detection for unknown job."""
    character = Mock()
    character.job = "Unknown_Job"
    
    build = combat_manager._detect_build_type(character)
    
    assert build is None


def test_detect_build_type_case_insensitive(combat_manager):
    """Test build type detection is case-insensitive."""
    character = Mock()
    character.job = "WIZARD"
    
    build = combat_manager._detect_build_type(character)
    
    assert build is not None


def test_detect_build_type_all_jobs(combat_manager):
    """Test build type detection for all supported jobs."""
    jobs = [
        "knight", "lord_knight", "crusader", "paladin",
        "assassin", "assassin_cross", "hunter", "sniper",
        "wizard", "high_wizard", "priest", "high_priest",
        "blacksmith", "whitesmith",
    ]
    
    for job in jobs:
        character = Mock()
        character.job = job
        
        build = combat_manager._detect_build_type(character)
        
        assert build is not None, f"No build detected for {job}"


# =============================================================================
# Public API Tests
# =============================================================================

def test_set_tactical_role_enum(combat_manager):
    """Test setting tactical role with enum."""
    with patch.object(combat_manager.combat_ai, 'set_role') as mock_set:
        combat_manager.set_tactical_role(TacticalRole.TANK)
        
        mock_set.assert_called_with(TacticalRole.TANK)


def test_set_tactical_role_string(combat_manager):
    """Test setting tactical role with string."""
    with patch.object(combat_manager.combat_ai, 'set_role') as mock_set:
        combat_manager.set_tactical_role("melee_dps")
        
        mock_set.assert_called_once()


def test_set_build_type(combat_manager):
    """Test setting build type."""
    with patch.object(combat_manager.skill_system, 'set_build_type') as mock_set:
        combat_manager.set_build_type("wizard_storm_gust")
        
        mock_set.assert_called_with("wizard_storm_gust")


def test_combat_state_property(combat_manager):
    """Test combat_state property."""
    # CombatAI.current_state is a read-only property
    state = combat_manager.combat_state
    
    assert state is not None
    assert isinstance(state, CombatState)


def test_combat_context_property(combat_manager, mock_character):
    """Test combat_context property."""
    context = CombatContext(
        character=mock_character,
        nearby_monsters=[],
        threat_level=0.5,
    )
    combat_manager._combat_context = context
    
    assert combat_manager.combat_context == context


def test_combat_context_property_none(combat_manager):
    """Test combat_context property when None."""
    combat_manager._combat_context = None
    
    assert combat_manager.combat_context is None


def test_metrics_property(combat_manager):
    """Test metrics property."""
    # Metrics is a property of combat_ai
    metrics = combat_manager.metrics
    
    assert metrics is not None


# =============================================================================
# Integration Tests
# =============================================================================

@pytest.mark.asyncio
async def test_full_combat_cycle(mock_game_state, mock_character):
    """Test complete combat cycle from initialization to action."""
    manager = CombatManager()
    
    # Setup character
    mock_character.job = "Knight"
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.sp = 400
    mock_character.sp_max = 500
    mock_character.skill_points = 0
    
    combat_action = CombatAction(
        action_type=CombatActionType.ATTACK,
        target_id=1001,
        priority=5,
    )
    
    context = CombatContext(
        character=mock_character,
        nearby_monsters=[],
        threat_level=0.3,
    )
    
    with patch.object(manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock, return_value=context), \
         patch.object(manager.combat_ai, 'decide', new_callable=AsyncMock, return_value=[combat_action]):
        
        actions = await manager.tick(mock_game_state)
        
        assert len(actions) > 0
        assert manager._initialized


@pytest.mark.asyncio
async def test_emergency_overrides_combat(mock_game_state, mock_character):
    """Test emergency actions override normal combat."""
    manager = CombatManager()
    manager._initialized = True
    
    # Critical HP
    mock_character.hp = 100
    mock_character.hp_max = 2000
    mock_character.inventory = {501: 5}  # Red Potion
    mock_game_state.inventory = {501: 5}  # Update game state inventory too
    
    actions = await manager.tick(mock_game_state)
    
    # Should only return emergency action
    assert len(actions) == 1
    assert actions[0].type == ActionType.USE_ITEM
    assert actions[0].target_id == 501


# =============================================================================
# Configuration Tests
# =============================================================================

def test_combat_manager_config_frozen():
    """Test CombatManagerConfig is frozen."""
    config = CombatManagerConfig()
    
    with pytest.raises(Exception):  # Pydantic ValidationError
        config.enable_combat_ai = False


def test_combat_manager_config_validation():
    """Test CombatManagerConfig validation."""
    config = CombatManagerConfig(
        emergency_hp_percent=0.20,
        low_hp_percent=0.35,
        max_actions_per_tick=5,
    )
    
    assert config.emergency_hp_percent == 0.20
    assert config.low_hp_percent == 0.35
    assert config.max_actions_per_tick == 5


# =============================================================================
# Additional Coverage Tests
# =============================================================================

def test_initialize_no_role_detection(mock_character):
    """Test initialize when role detection is disabled and no default role."""
    config = CombatManagerConfig(
        auto_detect_role=False,
        default_tactical_role=None,
    )
    manager = CombatManager(config=config)
    
    # Should not crash, just not set a role
    manager.initialize(mock_character)
    
    assert manager._initialized


def test_initialize_no_build_detected(mock_character):
    """Test initialize when build type cannot be detected."""
    mock_character.job = "Unknown_Class"
    manager = CombatManager()
    
    # Should not crash when build is None
    manager.initialize(mock_character)
    
    assert manager._initialized


@pytest.mark.asyncio
async def test_tick_no_combat_needed(mock_game_state, mock_character):
    """Test tick when threat level is 0 and no monsters."""
    manager = CombatManager()
    manager._initialized = True
    
    # Healthy character
    mock_character.hp = 1800
    mock_character.hp_max = 2000
    mock_character.skill_points = 0
    
    # No threat
    context = CombatContext(
        character=mock_character,
        nearby_monsters=[],
        threat_level=0.0,
    )
    
    with patch.object(manager.combat_ai, 'evaluate_combat_situation', new_callable=AsyncMock, return_value=context), \
         patch.object(manager.combat_ai, 'decide', new_callable=AsyncMock) as mock_decide:
        
        actions = await manager.tick(mock_game_state)
        
        # decide() should not be called when threat_level is 0 and no monsters
        assert not mock_decide.called or len(actions) == 0


def test_convert_combat_action_unknown_type(combat_manager):
    """Test converting unknown combat action type."""
    # Create a mock combat action with an unknown type
    combat_action = Mock()
    combat_action.action_type = "unknown_action"
    combat_action.skill_id = None
    combat_action.target_id = None
    combat_action.priority = 5
    
    action = combat_manager._convert_combat_action(combat_action)
    
    # Should return None for unknown action types
    assert action is None


def test_find_best_healing_item_with_non_healing_items(combat_manager, mock_game_state, mock_character):
    """Test finding healing item when inventory has non-healing items."""
    mock_character.hp = 1000
    mock_character.hp_max = 2000
    # Items not in HEALING_ITEMS dict
    mock_character.inventory = {999: 5, 1000: 3}
    mock_game_state.inventory = {999: 5, 1000: 3}
    
    item = combat_manager._find_best_healing_item(mock_game_state, mock_character)
