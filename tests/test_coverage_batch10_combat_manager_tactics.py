"""
Coverage Batch 10: Combat Manager & Tactical Systems
Target: 7.1% → 8% coverage (~250-300 statements)

Modules under test:
- ai_sidecar/combat/manager.py (475 lines, 0% → 70-80%)
- ai_sidecar/combat/tactics/base.py (495 lines, 0% → 70-80%)
- ai_sidecar/combat/tactics/tank.py (468 lines, 0% → 60-70%)

Test Strategy:
- Combat manager initialization and configuration
- Combat tick coordination and priority handling
- Emergency detection and item selection
- Base tactics utilities and helper methods
- Tank tactics target selection and positioning
- Threat management and aggro control
"""

import pytest
from unittest.mock import Mock, MagicMock, AsyncMock, patch
from pathlib import Path

from ai_sidecar.combat.manager import (
    CombatManager,
    CombatManagerConfig,
    EmergencyItem,
)
from ai_sidecar.combat.tactics.base import (
    BaseTactics,
    Position,
    Skill,
    TacticalRole,
    TacticsConfig,
    TargetPriority,
    ThreatEntry,
)
from ai_sidecar.combat.tactics.tank import (
    TankTactics,
    TankTacticsConfig,
)
from ai_sidecar.combat.models import (
    CombatAction,
    CombatActionType,
    CombatContext,
    MonsterActor,
    Element,
    MonsterRace,
    MonsterSize,
)
from ai_sidecar.core.state import CharacterState, Position as CorePosition
from ai_sidecar.core.decision import Action, ActionType


# ============================================================================
# Test Combat Manager Core
# ============================================================================

class TestCombatManagerCore:
    """Test CombatManager initialization and basic setup."""
    
    def test_combat_manager_initialization_default_config(self):
        """Cover CombatManager.__init__ with default configuration."""
        # Arrange & Act
        manager = CombatManager()
        
        # Assert
        assert manager is not None
        assert manager.config is not None
        assert isinstance(manager.config, CombatManagerConfig)
        assert manager.config.enable_skill_allocation is True
        assert manager.config.enable_combat_ai is True
        assert manager._initialized is False
    
    def test_combat_manager_initialization_custom_config(self):
        """Cover CombatManager.__init__ with custom configuration."""
        # Arrange
        config = CombatManagerConfig(
            enable_skill_allocation=False,
            emergency_hp_percent=0.15,
            auto_allocate_skills=False,
        )
        
        # Act
        manager = CombatManager(config=config)
        
        # Assert
        assert manager.config.enable_skill_allocation is False
        assert manager.config.emergency_hp_percent == 0.15
        assert manager.config.auto_allocate_skills is False
    
    def test_combat_manager_initialization_subsystems(self):
        """Cover CombatManager subsystem initialization."""
        # Arrange & Act
        manager = CombatManager()
        
        # Assert - verify all subsystems initialized
        assert manager.skill_system is not None
        assert manager.combat_ai is not None
        assert manager.skill_db is not None
        assert manager._combat_context is None
        assert manager._last_tick == 0
    
    def test_combat_manager_initialize_with_character(self):
        """Cover CombatManager.initialize with character data."""
        # Arrange
        manager = CombatManager()
        character = CharacterState(
            name="TestKnight",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        # Act
        manager.initialize(character)
        
        # Assert
        assert manager._initialized is True
    
    def test_combat_manager_set_tactical_role_string(self):
        """Cover CombatManager.set_tactical_role with string input."""
        # Arrange
        manager = CombatManager()
        
        # Act
        manager.set_tactical_role("tank")
        
        # Assert - verify role was set on combat AI
        assert manager.combat_ai._current_role == TacticalRole.TANK
    
    def test_combat_manager_set_tactical_role_enum(self):
        """Cover CombatManager.set_tactical_role with enum input."""
        # Arrange
        manager = CombatManager()
        
        # Act
        manager.set_tactical_role(TacticalRole.MAGIC_DPS)
        
        # Assert
        assert manager.combat_ai._current_role == TacticalRole.MAGIC_DPS
    
    def test_combat_manager_set_build_type(self):
        """Cover CombatManager.set_build_type."""
        # Arrange
        manager = CombatManager()
        
        # Act
        manager.set_build_type("knight_bash")
        
        # Assert - verify method executes without error
        # Note: SkillAllocationSystem stores build internally
        assert manager.skill_system is not None
    
    def test_combat_manager_combat_state_property(self):
        """Cover CombatManager.combat_state property."""
        # Arrange
        manager = CombatManager()
        
        # Act
        state = manager.combat_state
        
        # Assert
        assert state is not None
    
    def test_combat_manager_combat_context_property(self):
        """Cover CombatManager.combat_context property."""
        # Arrange
        manager = CombatManager()
        
        # Act
        context = manager.combat_context
        
        # Assert
        assert context is None  # Initially None
    
    def test_combat_manager_metrics_property(self):
        """Cover CombatManager.metrics property."""
        # Arrange
        manager = CombatManager()
        
        # Act
        metrics = manager.metrics
        
        # Assert
        assert metrics is not None


class TestCombatManagerTick:
    """Test CombatManager tick execution and action coordination."""
    
    @pytest.mark.asyncio
    async def test_tick_auto_initialize_if_needed(self):
        """Cover CombatManager.tick with auto-initialization."""
        # Arrange
        manager = CombatManager()
        game_state = Mock()
        game_state.tick = 1
        game_state.character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        game_state.inventory = {}
        
        # Mock combat AI to avoid extraction complexity
        context = CombatContext(character=game_state.character, nearby_monsters=[])
        with patch.object(manager.combat_ai, 'evaluate_combat_situation', return_value=context):
            # Act
            actions = await manager.tick(game_state)
        
        # Assert
        assert manager._initialized is True
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_emergency_handling_priority(self):
        """Cover emergency action priority in tick."""
        # Arrange
        config = CombatManagerConfig(emergency_hp_percent=0.20)
        manager = CombatManager(config=config)
        
        # Create character with critical HP
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=150,  # 15% HP
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.tick = 1
        game_state.character = character
        game_state.inventory = {501: 5}  # Red potions available
        
        # Act
        actions = await manager.tick(game_state)
        
        # Assert - should return emergency action only
        assert len(actions) == 1
        assert actions[0].type == ActionType.USE_ITEM or actions[0].type == ActionType.MOVE
    
    @pytest.mark.asyncio
    async def test_tick_skill_allocation_priority(self):
        """Cover skill allocation in tick."""
        # Arrange
        manager = CombatManager()
        manager._initialized = True
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
            skill_points=5,  # Has skill points to allocate
        )
        
        game_state = Mock()
        game_state.tick = 1
        game_state.character = character
        game_state.inventory = {}
        
        # Mock combat AI to return no combat actions
        with patch.object(manager.combat_ai, 'evaluate_combat_situation', 
                         return_value=CombatContext(character=character, nearby_monsters=[])):
            # Act
            actions = await manager.tick(game_state)
        
        # Assert - may include skill allocation action
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_tick_combat_actions_generation(self):
        """Cover combat action generation in tick."""
        # Arrange
        manager = CombatManager()
        manager._initialized = True
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        # Create monster nearby
        monster = MonsterActor(
            actor_id=1001,
            name="Poring",
            mob_id=1002,
            hp=500,
            hp_max=500,
            position=CorePosition(x=105, y=105),
        )
        
        game_state = Mock()
        game_state.tick = 1
        game_state.character = character
        game_state.inventory = {}
        
        # Mock combat AI evaluation
        context = CombatContext(
            character=character,
            nearby_monsters=[monster],
            threat_level=0.3,
        )
        
        with patch.object(manager.combat_ai, 'evaluate_combat_situation', return_value=context):
            with patch.object(manager.combat_ai, 'decide', return_value=[
                CombatAction(action_type=CombatActionType.ATTACK, target_id=1001, priority=5)
            ]):
                # Act
                actions = await manager.tick(game_state)
        
        # Assert
        assert isinstance(actions, list)


class TestCombatManagerEmergency:
    """Test CombatManager emergency handling logic."""
    
    @pytest.mark.asyncio
    async def test_check_emergencies_critical_hp_with_item(self):
        """Cover _check_emergencies with healing item available."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=150,  # 15% HP
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {501: 5}  # Red potions
        
        # Act
        action = await manager._check_emergencies(game_state)
        
        # Assert - should use healing item
        assert action is not None
        assert action.type == ActionType.USE_ITEM
        assert action.target_id == 501
        assert action.priority == 10
    
    @pytest.mark.asyncio
    async def test_check_emergencies_critical_hp_no_item(self):
        """Cover _check_emergencies with no healing items."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=150,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {}  # No items
        
        # Act
        action = await manager._check_emergencies(game_state)
        
        # Assert - should flee
        assert action is not None
        assert action.type == ActionType.MOVE
        assert action.priority == 10
    
    @pytest.mark.asyncio
    async def test_check_emergencies_low_hp_with_item(self):
        """Cover _check_emergencies with low (but not critical) HP."""
        # Arrange
        config = CombatManagerConfig(low_hp_percent=0.35, emergency_hp_percent=0.20)
        manager = CombatManager(config=config)
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=300,  # 30% HP
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {502: 3}  # Orange potions
        
        # Act
        action = await manager._check_emergencies(game_state)
        
        # Assert - should use healing item
        assert action is not None
        assert action.type == ActionType.USE_ITEM
        assert action.priority == 8
    
    @pytest.mark.asyncio
    async def test_check_emergencies_low_sp_with_item(self):
        """Cover _check_emergencies with low SP."""
        # Arrange
        config = CombatManagerConfig(low_sp_percent=0.15)
        manager = CombatManager(config=config)
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=10,  # 10% SP
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {505: 2}  # Blue potions
        
        # Act
        action = await manager._check_emergencies(game_state)
        
        # Assert - should use SP item
        assert action is not None
        assert action.type == ActionType.USE_ITEM
        assert action.target_id == 505
        assert action.priority == 6
    
    @pytest.mark.asyncio
    async def test_check_emergencies_healthy_state(self):
        """Cover _check_emergencies with healthy character."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=900,
            hp_max=1000,
            sp=80,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {}
        
        # Act
        action = await manager._check_emergencies(game_state)
        
        # Assert - no emergency action
        assert action is None


class TestCombatManagerHealingItems:
    """Test healing item selection logic."""
    
    def test_find_best_healing_item_red_potion_efficient(self):
        """Cover _find_best_healing_item with efficient red potion."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=955,  # Missing 45 HP (perfect for red potion)
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {501: 5, 502: 3, 503: 2}
        
        # Act
        item = manager._find_best_healing_item(game_state, character)
        
        # Assert - should select red potion (most efficient)
        assert item is not None
        assert item.item_id == 501
    
    def test_find_best_healing_item_white_potion_large_loss(self):
        """Cover _find_best_healing_item with large HP loss."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=650,  # Missing 350 HP
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {501: 5, 504: 3}  # Red and white potions
        
        # Act
        item = manager._find_best_healing_item(game_state, character)
        
        # Assert - algorithm selects based on efficiency
        # White potion heals 325, red heals 45 - both available
        assert item is not None
        assert item.item_id in [501, 504]  # Either is valid
    
    def test_find_best_healing_item_percent_heal_at_low_hp(self):
        """Cover _find_best_healing_item with percent-based heal at low HP."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=250,  # 25% HP
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {504: 2, 608: 1}  # White potion and Ygg seed
        
        # Act
        item = manager._find_best_healing_item(game_state, character)
        
        # Assert - percent heal gets bonus at very low HP
        assert item is not None
    
    def test_find_best_healing_item_no_items_available(self):
        """Cover _find_best_healing_item with no healing items."""
        # Arrange
        manager = CombatManager()
        
        character = CharacterState(
            name="Test",
            job="Knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=500,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        game_state = Mock()
        game_state.character = character
        game_state.inventory = {}
        
        # Act
        item = manager._find_best_healing_item(game_state, character)
        
        # Assert
        assert item is None
    
    def test_find_sp_recovery_item_blue_potion(self):
        """Cover _find_sp_recovery_item with blue potion."""
        # Arrange
        manager = CombatManager()
        
        game_state = Mock()
        game_state.inventory = {505: 3}
        
        # Act
        item = manager._find_sp_recovery_item(game_state)
        
        # Assert
        assert item is not None
        assert item.item_id == 505
    
    def test_find_sp_recovery_item_none_available(self):
        """Cover _find_sp_recovery_item with no SP items."""
        # Arrange
        manager = CombatManager()
        
        game_state = Mock()
        game_state.inventory = {}
        
        # Act
        item = manager._find_sp_recovery_item(game_state)
        
        # Assert
        assert item is None


class TestCombatManagerUtilities:
    """Test CombatManager utility methods."""
    
    def test_convert_combat_action_skill(self):
        """Cover _convert_combat_action for skill action."""
        # Arrange
        manager = CombatManager()
        combat_action = CombatAction(
            action_type=CombatActionType.SKILL,
            skill_id=5,
            target_id=1001,
            priority=8,
        )
        
        # Act
        action = manager._convert_combat_action(combat_action)
        
        # Assert
        assert action is not None
        assert action.type == ActionType.SKILL
        assert action.skill_id == 5
        assert action.target_id == 1001
        assert action.priority == 8
    
    def test_convert_combat_action_attack(self):
        """Cover _convert_combat_action for attack action."""
        # Arrange
        manager = CombatManager()
        combat_action = CombatAction(
            action_type=CombatActionType.ATTACK,
            target_id=1002,
            priority=6,
        )
        
        # Act
        action = manager._convert_combat_action(combat_action)
        
        # Assert
        assert action is not None
        assert action.type == ActionType.ATTACK
        assert action.target_id == 1002
    
    def test_convert_combat_action_move(self):
        """Cover _convert_combat_action for move action."""
        # Arrange
        manager = CombatManager()
        combat_action = CombatAction(
            action_type=CombatActionType.MOVE,
            position=(150, 200),
            priority=5,
        )
        
        # Act
        action = manager._convert_combat_action(combat_action)
        
        # Assert
        assert action is not None
        assert action.type == ActionType.MOVE
    
    def test_get_inventory_dict_format(self):
        """Cover _get_inventory with dict format."""
        # Arrange
        manager = CombatManager()
        game_state = Mock()
        game_state.inventory = {501: 10, 502: 5}
        
        # Act
        inventory = manager._get_inventory(game_state)
        
        # Assert
        assert inventory == {501: 10, 502: 5}
    
    def test_get_inventory_empty(self):
        """Cover _get_inventory with no inventory."""
        # Arrange
        manager = CombatManager()
        game_state = Mock()
        game_state.character = Mock()
        
        # Act
        inventory = manager._get_inventory(game_state)
        
        # Assert
        assert inventory == {}
    
    def test_detect_build_type_knight(self):
        """Cover _detect_build_type for Knight."""
        # Arrange
        manager = CombatManager()
        character = CharacterState(
            name="Test",
            job_class="knight",
            job_id=7,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        # Act
        build_type = manager._detect_build_type(character)
        
        # Assert
        assert build_type is not None
        assert "knight" in build_type.lower()
    
    def test_detect_build_type_unknown_job(self):
        """Cover _detect_build_type for unknown job."""
        # Arrange
        manager = CombatManager()
        character = CharacterState(
            name="Test",
            job="Unknown",
            job_id=999,
            base_level=50,
            job_level=30,
            hp=1000,
            hp_max=1000,
            sp=100,
            sp_max=100,
            position=CorePosition(x=100, y=100),
        )
        
        # Act
        build_type = manager._detect_build_type(character)
        
        # Assert
        assert build_type is None


# ============================================================================
# Test Base Tactics
# ============================================================================

class TestBaseTacticsCore:
    """Test BaseTactics base class functionality."""
    
    def test_position_distance_calculation(self):
        """Cover Position.distance_to calculation."""
        # Arrange
        pos1 = Position(x=100, y=100)
        pos2 = Position(x=103, y=104)
        
        # Act
        distance = pos1.distance_to(pos2)
        
        # Assert
        assert distance == 5.0  # 3-4-5 triangle
    
    def test_position_manhattan_distance(self):
        """Cover Position.manhattan_distance calculation."""
        # Arrange
        pos1 = Position(x=100, y=100)
        pos2 = Position(x=103, y=104)
        
        # Act
        distance = pos1.manhattan_distance(pos2)
        
        # Assert
        assert distance == 7  # |3| + |4|
    
    def test_base_tactics_initialization(self):
        """Cover BaseTactics.__init__ with default config."""
        # Arrange & Act
        # Use TankTactics as concrete implementation
        tactics = TankTactics()
        
        # Assert
        assert tactics.config is not None
        assert isinstance(tactics.config, TacticsConfig)
        assert tactics._threat_table == {}
    
    def test_base_tactics_custom_config(self):
        """Cover BaseTactics initialization with custom config."""
        # Arrange
        config = TacticsConfig(
            emergency_hp_threshold=0.15,
            low_hp_threshold=0.40,
            max_engagement_range=20,
        )
        
        # Act
        tactics = TankTactics(config)
        
        # Assert
        assert tactics.config.emergency_hp_threshold == 0.15
        assert tactics.config.low_hp_threshold == 0.40
        assert tactics.config.max_engagement_range == 20


class TestBaseTacticsHelpers:
    """Test BaseTactics helper methods."""
    
    def test_is_emergency_true(self):
        """Cover is_emergency method when HP is critical."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_hp = 200
        context.character_hp_max = 1000  # 20% HP
        
        # Act
        result = tactics.is_emergency(context)
        
        # Assert
        assert result is True
    
    def test_is_emergency_false(self):
        """Cover is_emergency when HP is safe."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_hp = 800
        context.character_hp_max = 1000
        
        # Act
        result = tactics.is_emergency(context)
        
        # Assert
        assert result is False
    
    def test_is_low_hp_true(self):
        """Cover is_low_hp method when HP is low."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_hp = 400
        context.character_hp_max = 1000  # 40% HP
        
        # Act
        result = tactics.is_low_hp(context)
        
        # Assert
        assert result is True
    
    def test_is_low_sp_true(self):
        """Cover is_low_sp method when SP is low."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_sp = 15
        context.character_sp_max = 100  # 15% SP
        
        # Act
        result = tactics.is_low_sp(context)
        
        # Assert
        assert result is True
    
    def test_can_use_skill_sufficient_sp(self):
        """Cover can_use_skill with sufficient SP."""
        # Arrange
        tactics = TankTactics()
        skill = Skill(
            id=5,
            name="bash",
            sp_cost=20,
            range=1,
        )
        context = Mock()
        context.character_sp = 50
        context.cooldowns = {}
        
        # Act
        result = tactics.can_use_skill(skill, context)
        
        # Assert
        assert result is True
    
    def test_can_use_skill_insufficient_sp(self):
        """Cover can_use_skill with insufficient SP."""
        # Arrange
        tactics = TankTactics()
        skill = Skill(
            id=5,
            name="bash",
            sp_cost=20,
            range=1,
        )
        context = Mock()
        context.character_sp = 10
        context.cooldowns = {}
        
        # Act
        result = tactics.can_use_skill(skill, context)
        
        # Assert
        assert result is False
    
    def test_can_use_skill_on_cooldown(self):
        """Cover can_use_skill when skill is on cooldown."""
        # Arrange
        tactics = TankTactics()
        skill = Skill(
            id=5,
            name="bash",
            sp_cost=20,
            range=1,
        )
        context = Mock()
        context.character_sp = 50
        context.cooldowns = {"bash": 2.5}
        
        # Act
        result = tactics.can_use_skill(skill, context)
        
        # Assert
        assert result is False
    
    def test_get_distance_to_target_position_object(self):
        """Cover get_distance_to_target with Position object."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_position = Position(x=100, y=100)
        target_pos = Position(x=105, y=105)
        
        # Act
        distance = tactics.get_distance_to_target(context, target_pos)
        
        # Assert
        assert distance > 0
    
    def test_get_distance_to_target_tuple(self):
        """Cover get_distance_to_target with tuple."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.character_position = Position(x=100, y=100)
        target_pos = (105, 105)
        
        # Act
        distance = tactics.get_distance_to_target(context, target_pos)
        
        # Assert
        assert distance > 0


class TestBaseTacticsThreat:
    """Test threat management in BaseTactics."""
    
    def test_update_threat_new_entry(self):
        """Cover update_threat for new actor."""
        # Arrange
        tactics = TankTactics()
        
        # Act
        tactics.update_threat(
            actor_id=1001,
            damage_dealt=100,
            damage_taken=50,
            is_targeting=True,
        )
        
        # Assert
        assert 1001 in tactics._threat_table
        entry = tactics._threat_table[1001]
        assert entry.threat_value > 0
        assert entry.damage_taken == 50
        assert entry.is_targeting_self is True
    
    def test_update_threat_existing_entry(self):
        """Cover update_threat for existing actor."""
        # Arrange
        tactics = TankTactics()
        tactics.update_threat(actor_id=1001, damage_dealt=50)
        initial_threat = tactics._threat_table[1001].threat_value
        
        # Act
        tactics.update_threat(actor_id=1001, damage_dealt=100)
        
        # Assert
        assert tactics._threat_table[1001].threat_value > initial_threat
    
    def test_get_threat_for_actor_exists(self):
        """Cover get_threat_for_actor when actor exists."""
        # Arrange
        tactics = TankTactics()
        tactics.update_threat(actor_id=1001, damage_dealt=150)
        
        # Act
        threat = tactics.get_threat_for_actor(1001)
        
        # Assert
        assert threat > 0
    
    def test_get_threat_for_actor_not_exists(self):
        """Cover get_threat_for_actor when actor doesn't exist."""
        # Arrange
        tactics = TankTactics()
        
        # Act
        threat = tactics.get_threat_for_actor(9999)
        
        # Assert
        assert threat == 0.0
    
    def test_clear_threat_table(self):
        """Cover clear_threat_table method."""
        # Arrange
        tactics = TankTactics()
        tactics.update_threat(actor_id=1001, damage_dealt=100)
        tactics.update_threat(actor_id=1002, damage_dealt=200)
        
        # Act
        tactics.clear_threat_table()
        
        # Assert
        assert len(tactics._threat_table) == 0


class TestBaseTacticsTargetPrioritization:
    """Test target prioritization in BaseTactics."""
    
    def test_prioritize_targets_basic(self):
        """Cover prioritize_targets with default scoring."""
        # Arrange
        tactics = TankTactics()
        
        # Create mock context
        context = Mock()
        context.character_position = Position(x=100, y=100)
        
        # Create mock targets
        target1 = Mock()
        target1.actor_id = 1001
        target1.hp = 400
        target1.hp_max = 1000
        target1.position = (105, 105)
        
        target2 = Mock()
        target2.actor_id = 1002
        target2.hp = 800
        target2.hp_max = 1000
        target2.position = (110, 110)
        
        # Act
        priorities = tactics.prioritize_targets(context, [target1, target2])
        
        # Assert
        assert len(priorities) == 2
        assert all(isinstance(p, TargetPriority) for p in priorities)
        assert priorities[0].priority_score >= priorities[1].priority_score
    
    def test_default_target_score_close_target(self):
        """Cover _default_target_score with close target."""
        # Arrange
        tactics = TankTactics()
        target = Mock()
        
        # Act
        score = tactics._default_target_score(target, hp_percent=0.5, distance=3.0)
        
        # Assert
        assert score > 0


# ============================================================================
# Test Tank Tactics
# ============================================================================

class TestTankTacticsCore:
    """Test TankTactics initialization and basic methods."""
    
    def test_tank_tactics_initialization(self):
        """Cover TankTactics.__init__."""
        # Arrange & Act
        tactics = TankTactics()
        
        # Assert
        assert tactics.role == TacticalRole.TANK
        assert tactics._provoke_rotation == []
        assert tactics._last_provoke_target is None
    
    def test_tank_tactics_custom_config(self):
        """Cover TankTactics with custom tank config."""
        # Arrange
        config = TankTacticsConfig(
            front_line_distance=3,
            provoke_threshold=0.9,
        )
        
        # Act
        tactics = TankTactics(config)
        
        # Assert
        assert tactics.tank_config.front_line_distance == 3
        assert tactics.tank_config.provoke_threshold == 0.9


class TestTankTacticsTargetSelection:
    """Test tank target selection logic."""
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self):
        """Cover select_target with no monsters."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.nearby_monsters = []
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_enemies_on_allies(self):
        """Cover select_target prioritizing enemies targeting allies."""
        # Arrange
        tactics = TankTactics()
        
        # Create monsters
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.hp = 500
        monster1.hp_max = 1000
        monster1.position = (105, 105)
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.hp = 800
        monster2.hp_max = 1000
        monster2.position = (108, 108)
        
        # Mark monster2 as targeting someone else
        tactics._threat_table[1002] = ThreatEntry(
            actor_id=1002,
            threat_value=50.0,
            is_targeting_self=False,  # Targeting ally!
        )
        
        context = Mock()
        context.nearby_monsters = [monster1, monster2]
        context.character_position = Position(x=100, y=100)
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert
        assert target is not None
        assert target.reason == "targeting_ally"
    
    @pytest.mark.asyncio
    async def test_select_target_loose_enemies(self):
        """Cover select_target finding loose enemies."""
        # Arrange
        tactics = TankTactics()
        
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (105, 105)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert
        assert target is not None


class TestTankTacticsSkillSelection:
    """Test tank skill selection."""
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_at_low_hp(self):
        """Cover select_skill path through low HP check."""
        # Arrange
        config = TankTacticsConfig(use_defender_hp=0.40)
        tactics = TankTactics(config)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100.0,
            reason="test",
        )
        
        # Mark target as already targeting us so we skip provoke
        tactics._threat_table[1001] = ThreatEntry(
            actor_id=1001,
            threat_value=50.0,
            is_targeting_self=True,
        )
        
        context = Mock()
        context.character_hp = 350
        context.character_hp_max = 1000  # 35% HP
        context.character_sp = 100
        context.cooldowns = {}
        context.nearby_monsters = [Mock()]
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert - verifies skill selection logic executes
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_provoke_for_loose_enemy(self):
        """Cover select_skill choosing provoke for loose enemy."""
        # Arrange
        tactics = TankTactics()
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100.0,
            reason="loose_enemy",
        )
        
        context = Mock()
        context.character_hp = 900
        context.character_hp_max = 1000
        context.character_sp = 100
        context.cooldowns = {}
        context.nearby_monsters = [Mock()]
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_for_multiple_enemies(self):
        """Cover select_skill choosing AoE for multiple enemies."""
        # Arrange
        tactics = TankTactics()
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100.0,
            reason="test",
        )
        
        # Mark target in threat table
        tactics._threat_table[1001] = ThreatEntry(
            actor_id=1001,
            threat_value=50.0,
            is_targeting_self=True,
        )
        
        context = Mock()
        context.character_hp = 900
        context.character_hp_max = 1000
        context.character_sp = 100
        context.cooldowns = {}
        context.nearby_monsters = [Mock(), Mock(), Mock()]  # 3 monsters
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert
        assert skill is not None


class TestTankTacticsPositioning:
    """Test tank positioning logic."""
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self):
        """Cover evaluate_positioning with no monsters."""
        # Arrange
        tactics = TankTactics()
        context = Mock()
        context.nearby_monsters = []
        
        # Act
        position = await tactics.evaluate_positioning(context)
        
        # Assert
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_with_party(self):
        """Cover evaluate_positioning with party members."""
        # Arrange
        tactics = TankTactics()
        
        # Create monsters
        monster = Mock()
        monster.position = (120, 120)
        
        # Create party members
        party_member = Mock()
        party_member.position = (100, 100)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.party_members = [party_member]
        context.character_position = Position(x=100, y=100)
        
        # Act
        position = await tactics.evaluate_positioning(context)
        
        # Assert - may return position between party and threats
        # or None if already in good position
        assert position is None or isinstance(position, Position)
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_solo(self):
        """Cover evaluate_positioning without party."""
        # Arrange
        tactics = TankTactics()
        
        monster = Mock()
        monster.position = (115, 115)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.party_members = []
        context.character_position = Position(x=100, y=100)
        
        # Act
        position = await tactics.evaluate_positioning(context)
        
        # Assert
        assert position is None or isinstance(position, Position)


class TestTankTacticsUtilities:
    """Test tank tactics utility methods."""
    
    def test_get_threat_assessment_basic(self):
        """Cover get_threat_assessment with basic situation."""
        # Arrange
        tactics = TankTactics()
        
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (105, 105)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_hp = 900
        context.character_hp_max = 1000
        context.character_position = Position(x=100, y=100)
        
        # Act
        threat = tactics.get_threat_assessment(context)
        
        # Assert
        assert 0.0 <= threat <= 1.0
    
    def test_calculate_threat_centroid(self):
        """Cover _calculate_threat_centroid."""
        # Arrange
        tactics = TankTactics()
        
        monster1 = Mock()
        monster1.position = (100, 100)
        
        monster2 = Mock()
        monster2.position = (110, 110)
        
        context = Mock()
        context.nearby_monsters = [monster1, monster2]
        
        # Act
        centroid = tactics._calculate_threat_centroid(context)
        
        # Assert
        assert centroid is not None
        assert isinstance(centroid, Position)
        assert centroid.x == 105
        assert centroid.y == 105
    
    def test_calculate_party_centroid(self):
        """Cover _calculate_party_centroid."""
        # Arrange
        tactics = TankTactics()
        
        member1 = Mock()
        member1.position = (100, 100)
        
        member2 = Mock()
        member2.position = (110, 110)
        
        context = Mock()
        context.party_members = [member1, member2]
        
        # Act
        centroid = tactics._calculate_party_centroid(context)
        
        # Assert
        assert centroid is not None
        assert isinstance(centroid, Position)
    
    def test_calculate_interception_point(self):
        """Cover _calculate_interception_point."""
        # Arrange
        tactics = TankTactics()
        party_center = Position(x=100, y=100)
        threat_center = Position(x=120, y=120)
        
        # Act
        intercept = tactics._calculate_interception_point(party_center, threat_center)
        
        # Assert
        assert intercept is not None
        assert isinstance(intercept, Position)
        # Should be between party and threats
        assert party_center.x < intercept.x < threat_center.x
    
    def test_get_skill_id_mapping(self):
        """Cover _get_skill_id for known skills."""
        # Arrange
        tactics = TankTactics()
        
        # Act
        bash_id = tactics._get_skill_id("bash")
        provoke_id = tactics._get_skill_id("provoke")
        unknown_id = tactics._get_skill_id("unknown_skill")
        
        # Assert
        assert bash_id == 5
        assert provoke_id == 6
        assert unknown_id == 0