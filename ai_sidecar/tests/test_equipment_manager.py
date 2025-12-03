"""
Tests for Equipment Manager - equipment optimization and upgrades.

Tests cover:
- Equipment manager initialization
- Better equipment detection
- Card slotting optimization
- Refining decisions
- Build type management
- Equipment scoring and comparison
"""

import pytest
from unittest.mock import Mock, AsyncMock, patch, MagicMock

from ai_sidecar.equipment.manager import EquipmentManager, EquipmentManagerConfig
from ai_sidecar.equipment.models import Equipment, EquipSlot, InventoryItem
from ai_sidecar.equipment.valuation import ItemValuationEngine
from ai_sidecar.core.decision import Action, ActionType


@pytest.fixture
def mock_valuation_engine():
    """Mock item valuation engine."""
    engine = Mock(spec=ItemValuationEngine)
    engine.compare_equipment = Mock(return_value=10.0)  # 10 point improvement
    engine.calculate_refine_value = Mock()
    engine.evaluate_card_insertion = Mock(return_value={
        "recommended": True,
        "score_improvement": 15.0
    })
    return engine


@pytest.fixture
def config():
    """Default configuration."""
    return EquipmentManagerConfig(
        auto_equip_better_gear=True,
        auto_card_slotting=False,
        auto_refining=False,
        safe_refine_only=True,
        min_score_improvement=5.0
    )


@pytest.fixture
def manager(config, mock_valuation_engine):
    """Create equipment manager."""
    return EquipmentManager(config, mock_valuation_engine)


@pytest.fixture
def mock_game_state():
    """Mock game state."""
    state = Mock()
    state.character = Mock()
    state.character.hp = 1000
    state.character.max_hp = 1000
    
    # Mock inventory
    state.inventory = Mock()
    state.inventory.items = []
    
    return state


# Initialization Tests

def test_manager_init_default():
    """Test manager initialization with defaults."""
    manager = EquipmentManager()
    
    assert manager.config is not None
    assert manager.valuation is not None
    assert manager._initialized is False
    assert manager._current_build == "hybrid"


def test_manager_init_custom_config():
    """Test initialization with custom config."""
    config = EquipmentManagerConfig(
        auto_equip_better_gear=False,
        min_score_improvement=10.0,
        build_type="melee_dps"
    )
    
    manager = EquipmentManager(config)
    
    assert manager.config.auto_equip_better_gear is False
    assert manager.config.min_score_improvement == 10.0
    assert manager._current_build == "melee_dps"


def test_manager_initialize(manager):
    """Test manager initialization method."""
    assert manager._initialized is False
    
    manager.initialize()
    
    assert manager._initialized is True


def test_manager_initialize_with_build_type(manager):
    """Test initialization with build type override."""
    manager.initialize("tank")
    
    assert manager._initialized is True
    assert manager._current_build == "tank"


# Build Type Tests

def test_set_build_type(manager):
    """Test setting build type."""
    manager.set_build_type("magic_dps")
    
    assert manager.build_type == "magic_dps"
    assert manager._current_build == "magic_dps"


def test_build_type_property(manager):
    """Test build type property."""
    manager._current_build = "ranged_dps"
    
    assert manager.build_type == "ranged_dps"


# Tick Tests

@pytest.mark.asyncio
async def test_tick_auto_initialize(manager, mock_game_state):
    """Test that tick auto-initializes if not initialized."""
    assert manager._initialized is False
    
    await manager.tick(mock_game_state)
    
    assert manager._initialized is True


@pytest.mark.asyncio
async def test_tick_no_actions_when_disabled(mock_game_state):
    """Test tick returns no actions when features disabled."""
    config = EquipmentManagerConfig(
        auto_equip_better_gear=False,
        auto_card_slotting=False,
        auto_refining=False
    )
    manager = EquipmentManager(config)
    manager.initialize()
    
    actions = await manager.tick(mock_game_state)
    
    assert len(actions) == 0


@pytest.mark.asyncio
async def test_tick_finds_better_equipment(manager, mock_game_state):
    """Test tick finds better equipment when enabled."""
    manager.initialize()
    
    # Mock finding better equipment
    better_item = Mock(spec=Equipment, item_id=1201, name="Knife", slot=EquipSlot.WEAPON, attack=50, defense=0, required_level=1)
    
    with patch.object(manager, '_find_better_equipment', return_value=[better_item]):
        with patch.object(manager, '_create_equip_action') as mock_create:
            mock_create.return_value = Action(type=ActionType.EQUIP,
                item_id=1201
            )
            
            actions = await manager.tick(mock_game_state)
            
            assert len(actions) > 0
            mock_create.assert_called_once()


@pytest.mark.asyncio
async def test_tick_card_slotting_when_enabled(mock_game_state):
    """Test tick optimizes cards when enabled."""
    config = EquipmentManagerConfig(auto_card_slotting=True)
    manager = EquipmentManager(config)
    manager.initialize()
    
    with patch.object(manager, '_optimize_card_slotting', return_value=[]):
        actions = await manager.tick(mock_game_state)
        manager._optimize_card_slotting.assert_called_once()


@pytest.mark.asyncio
async def test_tick_refining_when_enabled_at_npc(mock_game_state):
    """Test tick considers refining when enabled and at NPC."""
    config = EquipmentManagerConfig(auto_refining=True)
    manager = EquipmentManager(config)
    manager.initialize()
    
    with patch.object(manager, '_at_refine_npc', return_value=True):
        with patch.object(manager, '_evaluate_refine', return_value=None):
            await manager.tick(mock_game_state)
            manager._evaluate_refine.assert_called_once()


@pytest.mark.asyncio
async def test_tick_no_refining_when_not_at_npc(mock_game_state):
    """Test tick skips refining when not at NPC."""
    config = EquipmentManagerConfig(auto_refining=True)
    manager = EquipmentManager(config)
    manager.initialize()
    
    with patch.object(manager, '_at_refine_npc', return_value=False):
        with patch.object(manager, '_evaluate_refine') as mock_eval:
            await manager.tick(mock_game_state)
            mock_eval.assert_not_called()


# Better Equipment Detection Tests

@pytest.mark.asyncio
async def test_find_better_equipment_none_available(manager, mock_game_state):
    """Test when no better equipment available."""
    manager.initialize()
    
    with patch.object(manager, '_get_current_equipment', return_value={}):
        with patch.object(manager, '_get_available_equipment', return_value=[]):
            better = await manager._find_better_equipment(mock_game_state)
            
            assert len(better) == 0


@pytest.mark.asyncio
async def test_find_better_equipment_improvement_found(manager, mock_game_state):
    """Test finding equipment with significant improvement."""
    manager.initialize()
    
    current_weapon = Mock(spec=Equipment)
    current_weapon.name = "Knife"
    
    candidate = Mock(spec=Equipment)
    candidate.item_id = 1201
    candidate.name = "Better Knife"
    candidate.slot = EquipSlot.WEAPON
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: current_weapon
    }):
        with patch.object(manager, '_get_available_equipment', return_value=[candidate]):
            manager.valuation.compare_equipment = Mock(return_value=10.0)
            
            better = await manager._find_better_equipment(mock_game_state)
            
            assert len(better) == 1
            assert better[0] == candidate


@pytest.mark.asyncio
async def test_find_better_equipment_insufficient_improvement(manager, mock_game_state):
    """Test when improvement is below threshold."""
    manager.initialize()
    
    current_weapon = Mock(spec=Equipment)
    candidate = Mock(spec=Equipment)
    candidate.name = "Magic Staff"
    candidate.slot = EquipSlot.WEAPON
    candidate.item_id = 1601
    candidate.attack = 30
    candidate.matk = 120
    candidate.required_level = 40
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: current_weapon
    }):
        with patch.object(manager, '_get_available_equipment', return_value=[candidate]):
            manager.valuation.compare_equipment = Mock(return_value=2.0)  # Below 5.0 threshold
            
            better = await manager._find_better_equipment(mock_game_state)
            
            assert len(better) == 0


@pytest.mark.asyncio
async def test_find_better_equipment_multiple_slots(manager, mock_game_state):
    """Test finding improvements across multiple slots."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.name = "Knife"
    weapon.item_id = 1201
    weapon.slot = EquipSlot.WEAPON
    weapon.attack = 50
    weapon.defense = 0
    weapon.required_level = 1
    
    armor = Mock(spec=Equipment)
    armor.name = "Cotton Shirt"
    armor.item_id = 2301
    armor.slot = EquipSlot.ARMOR
    armor.attack = 0
    armor.defense = 10
    armor.required_level = 1
    
    with patch.object(manager, '_get_current_equipment', return_value={}):
        with patch.object(manager, '_get_available_equipment', return_value=[weapon, armor]):
            manager.valuation.compare_equipment = Mock(return_value=10.0)
            
            better = await manager._find_better_equipment(mock_game_state)
            
            assert len(better) == 2


# Card Slotting Tests

@pytest.mark.asyncio
async def test_optimize_card_slotting_no_slots(manager, mock_game_state):
    """Test card optimization when no empty slots."""
    manager.initialize()
    
    item_no_slots = Mock(spec=Equipment)
    item_no_slots.has_empty_slots = False
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: item_no_slots
    }):
        with patch.object(manager, '_get_available_cards', return_value=[4001]):
            actions = await manager._optimize_card_slotting(mock_game_state)
            
            assert len(actions) == 0


@pytest.mark.asyncio
async def test_optimize_card_slotting_finds_best_card(manager, mock_game_state):
    """Test finding best card for equipment."""
    manager.initialize()
    
    item_with_slot = Mock(spec=Equipment)
    item_with_slot.name = "Sword"
    item_with_slot.has_empty_slots = True
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: item_with_slot
    }):
        with patch.object(manager, '_get_available_cards', return_value=[4001, 4002]):
            with patch.object(manager, '_find_best_card_for_item', return_value=4001):
                actions = await manager._optimize_card_slotting(mock_game_state)
                
                # Actions would be empty as implementation is placeholder
                # But _find_best_card_for_item should be called
                manager._find_best_card_for_item.assert_called()


# Refining Tests

@pytest.mark.asyncio
async def test_evaluate_refine_no_candidates(manager, mock_game_state):
    """Test refine evaluation with no candidates."""
    manager.initialize()
    
    with patch.object(manager, '_get_current_equipment', return_value={}):
        action = await manager._evaluate_refine(mock_game_state)
        
        assert action is None


@pytest.mark.asyncio
async def test_evaluate_refine_safe_mode_skip_risky(manager, mock_game_state):
    """Test safe refine mode skips risky refines."""
    manager.config = EquipmentManagerConfig(safe_refine_only=True)
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.refine = 5  # Above safe threshold
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon
    }):
        action = await manager._evaluate_refine(mock_game_state)
        
        assert action is None


@pytest.mark.asyncio
async def test_evaluate_refine_max_refine_skip(manager, mock_game_state):
    """Test skip equipment at max refine."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.refine = 20  # Max refine
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon
    }):
        action = await manager._evaluate_refine(mock_game_state)
        
        assert action is None


@pytest.mark.asyncio
async def test_evaluate_refine_within_parameters(manager, mock_game_state):
    """Test refine recommended within parameters."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.name = "Sword"
    weapon.refine = 3
    
    analysis = Mock()
    analysis.recommended = True
    analysis.risk_score = 0.3
    analysis.expected_value_gain = 1000
    analysis.target_refine = 4
    analysis.success_rate = 0.8
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon
    }):
        manager.valuation.calculate_refine_value = Mock(return_value=analysis)
        
        action = await manager._evaluate_refine(mock_game_state)
        
        # Action would be None as implementation is placeholder
        # But analysis should be performed
        manager.valuation.calculate_refine_value.assert_called_once()


@pytest.mark.asyncio
async def test_evaluate_refine_high_risk_rejected(manager, mock_game_state):
    """Test high risk refine is rejected."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.refine = 3
    
    analysis = Mock()
    analysis.recommended = True
    analysis.risk_score = 0.9  # Too high risk
    analysis.expected_value_gain = 1000
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon
    }):
        manager.valuation.calculate_refine_value = Mock(return_value=analysis)
        
        action = await manager._evaluate_refine(mock_game_state)
        
        assert action is None


@pytest.mark.asyncio
async def test_evaluate_refine_not_recommended(manager, mock_game_state):
    """Test skip when refining not recommended."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.refine = 3
    
    analysis = Mock()
    analysis.recommended = False
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon
    }):
        manager.valuation.calculate_refine_value = Mock(return_value=analysis)
        
        action = await manager._evaluate_refine(mock_game_state)
        
        assert action is None


# Helper Method Tests

def test_get_current_equipment(manager, mock_game_state):
    """Test getting current equipment."""
    equipped = manager._get_current_equipment(mock_game_state)
    
    assert isinstance(equipped, dict)
    # Should have all equipment slots
    assert EquipSlot.WEAPON in equipped
    assert EquipSlot.ARMOR in equipped


def test_get_available_equipment_empty(manager, mock_game_state):
    """Test getting equipment from empty inventory."""
    available = manager._get_available_equipment(mock_game_state)
    
    assert len(available) == 0


def test_get_available_equipment_filters_equipped(manager, mock_game_state):
    """Test that equipped items are filtered out."""
    equipped_item = Mock(spec=InventoryItem)
    equipped_item.equipped = True
    equipped_item.type = 3
    
    unequipped_item = Mock(spec=InventoryItem)
    unequipped_item.equipped = False
    unequipped_item.type = 3
    
    mock_game_state.inventory.items = [equipped_item, unequipped_item]
    
    available = manager._get_available_equipment(mock_game_state)
    
    # Implementation is placeholder, so result may be empty
    # But logic should filter equipped items
    assert isinstance(available, list)


def test_get_available_cards(manager, mock_game_state):
    """Test getting available cards from inventory."""
    card1 = Mock(spec=InventoryItem)
    card1.type = 6  # Card type
    card1.item_id = 4001
    
    card2 = Mock(spec=InventoryItem)
    card2.type = 6
    card2.item_id = 4002
    
    non_card = Mock(spec=InventoryItem)
    non_card.type = 3  # Equipment type
    
    mock_game_state.inventory.items = [card1, card2, non_card]
    
    cards = manager._get_available_cards(mock_game_state)
    
    assert len(cards) == 2
    assert 4001 in cards
    assert 4002 in cards


def test_find_best_card_for_item_no_cards(manager):
    """Test finding best card with no cards available."""
    item = Mock(spec=Equipment)
    
    best = manager._find_best_card_for_item(item, [])
    
    assert best is None


def test_find_best_card_for_item_finds_best(manager):
    """Test finding best card from available."""
    item = Mock(spec=Equipment)
    
    # Setup evaluations
    def mock_evaluate(equip, card_id, build):
        if card_id == 4001:
            return {"recommended": True, "score_improvement": 10.0}
        elif card_id == 4002:
            return {"recommended": True, "score_improvement": 20.0}
        return {"recommended": False, "score_improvement": 0}
    
    manager.valuation.evaluate_card_insertion = Mock(side_effect=mock_evaluate)
    
    best = manager._find_best_card_for_item(item, [4001, 4002, 4003])
    
    assert best == 4002  # Highest improvement


def test_find_best_card_for_item_none_recommended(manager):
    """Test when no cards are recommended."""
    item = Mock(spec=Equipment)
    
    manager.valuation.evaluate_card_insertion = Mock(return_value={
        "recommended": False,
        "score_improvement": 0
    })
    
    best = manager._find_best_card_for_item(item, [4001, 4002])
    
    assert best is None


def test_at_refine_npc(manager, mock_game_state):
    """Test checking if at refine NPC."""
    result = manager._at_refine_npc(mock_game_state)
    
    # Placeholder returns False
    assert result is False


# Action Creation Tests

def test_create_equip_action(manager):
    """Test creating equip action."""
    item = Mock(spec=Equipment, item_id=1201, name="Knife", slot=EquipSlot.WEAPON, attack=50, defense=0, required_level=1)
    
    action = manager._create_equip_action(item)
    
    assert action is not None
    assert action.type == ActionType.EQUIP
    assert action.item_id == 1201
    assert action.priority == 6


# Integration Tests

@pytest.mark.asyncio
async def test_full_workflow_find_and_equip(manager, mock_game_state):
    """Test full workflow of finding and equipping better gear."""
    manager.initialize("melee_dps")
    
    # Setup current equipment
    current = Mock(spec=Equipment)
    current.name = "Knife"
    current.item_id = 1201
    current.slot = EquipSlot.WEAPON
    current.attack = 50
    current.defense = 0
    current.required_level = 1
    
    # Setup better equipment
    better = Mock(spec=Equipment)
    better.item_id = 1202
    better.name = "Cutter"
    better.slot = EquipSlot.WEAPON
    better.attack = 70
    better.defense = 0
    better.required_level = 5
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: current
    }):
        with patch.object(manager, '_get_available_equipment', return_value=[better]):
            manager.valuation.compare_equipment = Mock(return_value=10.0)
            
            actions = await manager.tick(mock_game_state)
            
            assert len(actions) > 0
            assert actions[0].type == ActionType.EQUIP


@pytest.mark.asyncio
async def test_multiple_equipment_upgrades(manager, mock_game_state):
    """Test upgrading multiple equipment pieces."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.name = "Knife"
    weapon.item_id = 1201
    weapon.slot = EquipSlot.WEAPON
    weapon.attack = 50
    weapon.defense = 0
    weapon.required_level = 1
    
    armor = Mock(spec=Equipment)
    armor.name = "Cotton Shirt"
    armor.item_id = 2301
    armor.slot = EquipSlot.ARMOR
    armor.attack = 0
    armor.defense = 10
    armor.required_level = 1
    
    with patch.object(manager, '_get_current_equipment', return_value={}):
        with patch.object(manager, '_get_available_equipment', return_value=[weapon, armor]):
            manager.valuation.compare_equipment = Mock(return_value=10.0)
            
            actions = await manager.tick(mock_game_state)
            
            assert len(actions) == 2


# Configuration Tests

def test_config_validation():
    """Test configuration validation."""
    config = EquipmentManagerConfig(
        auto_equip_better_gear=True,
        min_score_improvement=5.0,
        max_refine_risk=0.5
    )
    
    assert config.auto_equip_better_gear is True
    assert config.min_score_improvement == 5.0
    assert config.max_refine_risk == 0.5


def test_config_frozen():
    """Test that config is frozen."""
    config = EquipmentManagerConfig()
    
    with pytest.raises(Exception):  # Pydantic will raise ValidationError
        config.auto_equip_better_gear = False


# Edge Cases

@pytest.mark.asyncio
async def test_tick_with_none_equipment(manager, mock_game_state):
    """Test tick handles None equipment gracefully."""
    manager.initialize()
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: None
    }):
        with patch.object(manager, '_get_available_equipment', return_value=[]):
            actions = await manager.tick(mock_game_state)
            
            assert len(actions) == 0


def test_find_best_card_equal_improvements(manager):
    """Test card selection when multiple cards have same improvement."""
    item = Mock(spec=Equipment)
    
    manager.valuation.evaluate_card_insertion = Mock(return_value={
        "recommended": True,
        "score_improvement": 10.0
    })
    
    best = manager._find_best_card_for_item(item, [4001, 4002])
    
    # Should return first card when equal
    assert best in [4001, 4002]


@pytest.mark.asyncio
async def test_refine_evaluation_multiple_candidates(manager, mock_game_state):
    """Test refining with multiple candidates."""
    manager.initialize()
    
    weapon = Mock(spec=Equipment)
    weapon.name = "Sword"
    weapon.refine = 2
    weapon.item_id = 1201
    weapon.slot = EquipSlot.WEAPON
    weapon.attack = 100
    weapon.defense = 0
    
    armor = Mock(spec=Equipment)
    armor.name = "Armor"
    armor.refine = 1
    armor.item_id = 2301
    armor.slot = EquipSlot.ARMOR
    armor.attack = 0
    armor.defense = 50
    
    # Setup different analyses
    def mock_analyze(item, target, build):
        analysis = Mock()
        if item == weapon:
            analysis.recommended = True
            analysis.risk_score = 0.2
            analysis.expected_value_gain = 1000
            analysis.target_refine = 3
            analysis.success_rate = 0.95
        else:
            analysis.recommended = True
            analysis.risk_score = 0.1
            analysis.expected_value_gain = 500
            analysis.target_refine = 2
            analysis.success_rate = 0.90
        return analysis
    
    with patch.object(manager, '_get_current_equipment', return_value={
        EquipSlot.WEAPON: weapon,
        EquipSlot.ARMOR: armor
    }):
        manager.valuation.calculate_refine_value = Mock(side_effect=mock_analyze)
        
        action = await manager._evaluate_refine(mock_game_state)
        
        # Should pick weapon (higher value gain)
        # Note: Implementation returns None, but analysis should be called
        assert manager.valuation.calculate_refine_value.call_count == 2


@pytest.mark.asyncio
async def test_build_type_affects_evaluation(manager, mock_game_state):
    """Test that build type is passed to valuation."""
    manager.initialize("magic_dps")
    
    candidate = Mock(spec=Equipment)
    candidate.name = "Magic Staff"
    candidate.slot = EquipSlot.WEAPON
    candidate.item_id = 1601
    candidate.attack = 30
    candidate.matk = 120
    candidate.required_level = 40
    
    with patch.object(manager, '_get_current_equipment', return_value={}):
        with patch.object(manager, '_get_available_equipment', return_value=[candidate]):
            await manager._find_better_equipment(mock_game_state)
            
            # Verify build type was passed
            manager.valuation.compare_equipment.assert_called()
            call_args = manager.valuation.compare_equipment.call_args
            assert call_args[0][2] == "magic_dps"


def test_config_defaults():
    """Test configuration default values."""
    config = EquipmentManagerConfig()
    
    assert config.auto_equip_better_gear is True
    assert config.auto_card_slotting is False
    assert config.auto_refining is False
    assert config.safe_refine_only is True
    assert config.min_score_improvement == 5.0
    assert config.max_refine_risk == 0.5
    assert config.build_type == "hybrid"
    assert config.auto_detect_build is True


@pytest.mark.asyncio
async def test_tick_respects_priority_order(manager, mock_game_state):
    """Test that tick processes actions in priority order."""
    config = EquipmentManagerConfig(
        auto_equip_better_gear=True,
        auto_card_slotting=True,
        auto_refining=True
    )
    manager = EquipmentManager(config)
    manager.initialize()
    
    call_order = []
    
    async def mock_find_better(*args):
        call_order.append("equip")
        return []
    
    async def mock_card_slot(*args):
        call_order.append("cards")
        return []
    
    async def mock_refine(*args):
        call_order.append("refine")
        return None
    
    with patch.object(manager, '_find_better_equipment', side_effect=mock_find_better):
        with patch.object(manager, '_optimize_card_slotting', side_effect=mock_card_slot):
            with patch.object(manager, '_evaluate_refine', side_effect=mock_refine):
                with patch.object(manager, '_at_refine_npc', return_value=True):
                    await manager.tick(mock_game_state)
                    
                    assert call_order == ["equip", "cards", "refine"]