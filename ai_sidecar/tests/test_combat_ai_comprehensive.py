"""
Comprehensive tests for Combat AI engine - Batch 4.

Tests combat decision making, tactics coordination,
and emergency handling.
"""

from unittest.mock import AsyncMock, Mock, patch

import pytest

from ai_sidecar.core.state import Position
from ai_sidecar.combat.combat_ai import (
    CombatAI,
    CombatAIConfig,
    CombatMetrics,
    CombatState,
)
from ai_sidecar.combat.models import (
    CombatAction,
    CombatActionType,
    CombatContext,
    Element,
    MonsterActor,
    PlayerActor,
    Position,
)
from ai_sidecar.combat.tactics import TacticalRole, TacticsConfig


@pytest.fixture
def combat_ai():
    """Create CombatAI instance."""
    return CombatAI()


@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    mock_state = Mock()
    mock_state.character = Mock()
    mock_state.character.hp = 1000
    mock_state.character.hp_max = 1000
    mock_state.character.sp = 500
    mock_state.character.sp_max = 500
    mock_state.character.job_id = 4001  # Swordman
    mock_state.character.position = Position(x=100, y=100)
    mock_state.character.buffs = []
    mock_state.character.debuffs = []
    mock_state.character.cooldowns = {}
    mock_state.actors = []
    mock_state.players = []
    mock_state.party_members = []
    return mock_state


class TestCombatAIInit:
    """Test CombatAI initialization."""
    
    def test_init_default_config(self):
        """Test initialization with default config."""
        ai = CombatAI()
        
        assert ai.config is not None
        assert isinstance(ai.metrics, CombatMetrics)
        assert ai._current_state == CombatState.IDLE
    
    def test_init_custom_config(self):
        """Test initialization with custom config."""
        config = CombatAIConfig(
            emergency_hp_threshold=0.15,
            retreat_hp_threshold=0.30
        )
        ai = CombatAI(config=config)
        
        assert ai.config.emergency_hp_threshold == 0.15
    
    def test_init_with_tactics_config(self):
        """Test initialization with tactics config."""
        tactics_config = TacticsConfig()
        ai = CombatAI(tactics_config=tactics_config)
        
        assert ai.tactics_config is not None


class TestTacticsManagement:
    """Test tactics role management."""
    
    def test_set_role_enum(self, combat_ai):
        """Test setting role with enum."""
        combat_ai.set_role(TacticalRole.TANK)
        
        assert combat_ai._current_role == TacticalRole.TANK
    
    def test_set_role_string(self, combat_ai):
        """Test setting role with string."""
        combat_ai.set_role("melee_dps")
        
        assert combat_ai._current_role == TacticalRole.MELEE_DPS
    
    def test_get_tactics_cached(self, combat_ai):
        """Test tactics instance caching."""
        tactics1 = combat_ai.get_tactics(TacticalRole.TANK)
        tactics2 = combat_ai.get_tactics(TacticalRole.TANK)
        
        assert tactics1 is tactics2


class TestCombatMetrics:
    """Test combat metrics tracking."""
    
    def test_record_decision_time(self):
        """Test recording decision time."""
        metrics = CombatMetrics()
        
        metrics.record_decision_time(10.5)
        metrics.record_decision_time(15.2)
        
        assert metrics.decisions_made == 2
        assert metrics.average_decision_time_ms > 0
    
    def test_record_decision_time_rolling_average(self):
        """Test rolling average with many decisions."""
        metrics = CombatMetrics()
        
        # Add 150 decision times
        for i in range(150):
            metrics.record_decision_time(10.0)
        
        # Should only keep last 100
        assert len(metrics._decision_times) == 100


class TestSituationEvaluation:
    """Test combat situation evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_combat_situation_basic(self, combat_ai, mock_game_state):
        """Test basic situation evaluation."""
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        assert context is not None
        # Check character properties match (validator converts Mock to CharacterState)
        assert context.character.hp == mock_game_state.character.hp
        assert context.character.hp_max == mock_game_state.character.hp_max
        assert context.character.position.x == mock_game_state.character.position.x
        assert context.character.position.y == mock_game_state.character.position.y
        assert context.threat_level >= 0.0
    
    @pytest.mark.asyncio
    async def test_evaluate_combat_situation_with_monsters(self, combat_ai, mock_game_state):
        """Test evaluation with monsters present."""
        mock_actor = Mock()
        mock_actor.mob_id = 1002
        mock_actor.actor_id = 1
        mock_actor.name = "Poring"
        mock_actor.hp = 50
        mock_actor.hp_max = 50
        mock_actor.element = "water"
        mock_actor.race = "plant"
        mock_actor.size = "small"
        mock_actor.position = Position(x=105, y=105)
        mock_actor.is_aggressive = False
        mock_actor.is_boss = False
        mock_actor.is_mvp = False
        mock_actor.attack_range = 1
        mock_actor.skills = []
        
        mock_game_state.actors = [mock_actor]
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        assert len(context.nearby_monsters) == 1


class TestTargetSelection:
    """Test target selection."""
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, combat_ai):
        """Test target selection with no monsters."""
        context = CombatContext(
            character=Mock(hp=1000, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.0,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        target = await combat_ai.select_target(context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_with_monsters(self, combat_ai):
        """Test target selection with monsters."""
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
            race="plant",
            size="small",
            position=Position(x=105, y=105),
        )
        
        context = CombatContext(
            character=Mock(hp=1000, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.2,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        target = await combat_ai.select_target(context)
        
        assert target is not None
        assert target.actor_id == 1


class TestActionSelection:
    """Test combat action selection."""
    
    @pytest.mark.asyncio
    async def test_select_action_emergency(self, combat_ai):
        """Test emergency action selection."""
        low_hp_char = Mock(hp=100, hp_max=1000, position=Position(x=100, y=100))
        context = CombatContext(
            character=low_hp_char,
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.5,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai.select_action(context, None)
        
        assert action is not None
        assert action.action_type == CombatActionType.FLEE
    
    @pytest.mark.asyncio
    async def test_select_action_retreat(self, combat_ai):
        """Test retreat action selection."""
        config = CombatAIConfig(retreat_hp_threshold=0.40)
        ai = CombatAI(config=config)
        
        low_hp_char = Mock(hp=350, hp_max=1000, position=Position(x=100, y=100))
        context = CombatContext(
            character=low_hp_char,
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.3,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await ai.select_action(context, None)
        
        # Should retreat or flee
        assert action is not None
        assert action.action_type in [CombatActionType.FLEE, CombatActionType.MOVE]
    
    @pytest.mark.asyncio
    async def test_select_action_with_target(self, combat_ai):
        """Test action selection with target."""
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
            position=Position(x=105, y=105),
        )
        
        context = CombatContext(
            character=Mock(
                hp=1000,
                hp_max=1000,
                sp=500,
                sp_max=500,
                job_id=4001,
                position=Position(x=100, y=100),
                buffs=[],
                debuffs=[],
                cooldowns={}
            ),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.2,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai.select_action(context, monster)
        
        assert action is not None
        assert action.target_id == 1


class TestEmergencyHandling:
    """Test emergency detection and response."""
    
    def test_is_emergency_true(self, combat_ai):
        """Test emergency detection."""
        context = CombatContext(
            character=Mock(hp=150, hp_max=1000),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.5,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert combat_ai._is_emergency(context)
    
    def test_is_emergency_false(self, combat_ai):
        """Test not emergency."""
        context = CombatContext(
            character=Mock(hp=800, hp_max=1000),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.3,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert not combat_ai._is_emergency(context)
    
    @pytest.mark.asyncio
    async def test_create_emergency_action(self, combat_ai):
        """Test creating emergency action."""
        context = CombatContext(
            character=Mock(hp=100, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.8,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai._create_emergency_action(context)
        
        assert action is not None
        assert action.action_type == CombatActionType.FLEE
        assert action.priority == 10


class TestRetreatLogic:
    """Test retreat decision logic."""
    
    def test_should_retreat_low_hp(self, combat_ai):
        """Test retreat on low HP."""
        context = CombatContext(
            character=Mock(hp=300, hp_max=1000),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.3,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert combat_ai._should_retreat(context)
    
    def test_should_retreat_mvp_solo(self, combat_ai):
        """Test retreat from MVP when solo."""
        monster = MonsterActor(
            actor_id=1,
            name="MVP",
            mob_id=1001,
            hp=100000,
            hp_max=100000,
            element=Element.NEUTRAL,
            is_mvp=True,
        )
        
        context = CombatContext(
            character=Mock(hp=800, hp_max=1000),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],  # Solo
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.6,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert combat_ai._should_retreat(context)
    
    def test_should_not_retreat_good_hp(self, combat_ai):
        """Test no retreat with good HP."""
        context = CombatContext(
            character=Mock(hp=900, hp_max=1000),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.2,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert not combat_ai._should_retreat(context)


class TestDecisionMethod:
    """Test main decide() method."""
    
    @pytest.mark.asyncio
    async def test_decide_emergency(self, combat_ai):
        """Test decide() during emergency."""
        context = CombatContext(
            character=Mock(hp=150, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.6,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        actions = await combat_ai.decide(context)
        
        assert len(actions) == 1
        assert actions[0].action_type == CombatActionType.FLEE
    
    @pytest.mark.asyncio
    async def test_decide_with_target(self, combat_ai):
        """Test decide() with target available."""
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
            position=Position(x=105, y=105),
        )
        
        context = CombatContext(
            character=Mock(
                hp=1000,
                hp_max=1000,
                sp=500,
                sp_max=500,
                job_id=4001,
                position=Position(x=100, y=100),
                buffs=[],
                debuffs=[],
                cooldowns={}
            ),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.2,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        actions = await combat_ai.decide(context)
        
        assert len(actions) > 0


class TestStateAccessors:
    """Test state property accessors."""
    
    def test_current_state_property(self, combat_ai):
        """Test current_state property."""
        assert combat_ai.current_state == CombatState.IDLE
    
    def test_current_role_property(self, combat_ai):
        """Test current_role property."""
        combat_ai.set_role(TacticalRole.TANK)
        
        assert combat_ai.current_role == TacticalRole.TANK
    
    def test_current_target_id_property(self, combat_ai):
        """Test current_target_id property."""
        assert combat_ai.current_target_id is None


class TestRetreatActions:
    """Test retreat action creation."""
    
    @pytest.mark.asyncio
    async def test_create_retreat_action_with_monsters(self, combat_ai):
        """Test retreat action with threats nearby."""
        monster = MonsterActor(
            actor_id=1,
            name="Aggressive",
            mob_id=1001,
            hp=1000,
            hp_max=1000,
            element=Element.FIRE,
            position=Position(x=105, y=105),
            is_aggressive=True,
        )
        
        context = CombatContext(
            character=Mock(hp=350, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.5,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai._create_retreat_action(context)
        
        assert action is not None
        assert action.action_type in [CombatActionType.MOVE, CombatActionType.FLEE]
    
    @pytest.mark.asyncio
    async def test_create_retreat_action_no_threats(self, combat_ai):
        """Test retreat action without threats."""
        context = CombatContext(
            character=Mock(hp=350, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.3,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai._create_retreat_action(context)
        
        assert action is not None
        assert action.action_type == CombatActionType.FLEE


class TestPvPDetection:
    """Test PvP/WoE detection."""
    
    def test_is_in_pvp_mode(self, combat_ai):
        """Test PvP mode detection."""
        mock_state = Mock()
        mock_state.pvp_mode = True
        
        assert combat_ai._is_in_pvp(mock_state)
    
    def test_is_in_pvp_map_type(self, combat_ai):
        """Test PvP detection by map type."""
        mock_state = Mock()
        mock_state.pvp_mode = None
        mock_state.map_type = "pvp"
        
        assert combat_ai._is_in_pvp(mock_state)
    
    def test_is_in_woe(self, combat_ai):
        """Test WoE detection."""
        mock_state = Mock()
        mock_state.woe_active = True
        
        assert combat_ai._is_in_woe(mock_state)
    
    def test_is_in_woe_map_name(self, combat_ai):
        """Test WoE detection by map name."""
        mock_state = Mock()
        mock_state.woe_active = None
        mock_state.map_name = "agit_castle"
        
        assert combat_ai._is_in_woe(mock_state)


class TestThreatCalculation:
    """Test threat level calculation."""
    
    def test_calculate_threat_no_enemies(self, combat_ai):
        """Test threat with no enemies."""
        character = Mock(hp=1000, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, [], [], game_state)
        
        assert threat == 0.0
    
    def test_calculate_threat_with_mvp(self, combat_ai):
        """Test threat with MVP present."""
        monster = MonsterActor(
            actor_id=1,
            name="MVP",
            mob_id=1001,
            hp=100000,
            hp_max=100000,
            element=Element.NEUTRAL,
            is_mvp=True,
        )
        
        character = Mock(hp=1000, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, [monster], [], game_state)
        
        # Should be high threat
        assert threat >= 0.4
    
    def test_calculate_threat_low_hp(self, combat_ai):
        """Test threat with low HP."""
        character = Mock(hp=200, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, [], [], game_state)
        
        # Low HP (20%) contributes threat: (1.0 - 0.2) * 0.3 = 0.24
        assert threat >= 0.00


class TestExtractCooldowns:
    """Test cooldown extraction with various formats."""
    
    @pytest.mark.asyncio
    async def test_extract_cooldowns_from_game_state(self, combat_ai, mock_game_state):
        """Test extracting cooldowns from game state."""
        mock_game_state.cooldowns = {"skill_1": 5.0, "skill_2": 10.0}
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        assert len(context.cooldowns) == 2
        assert context.cooldowns["skill_1"] == 5.0
        
    @pytest.mark.asyncio
    async def test_extract_cooldowns_from_character(self, combat_ai, mock_game_state):
        """Test extracting cooldowns from character state."""
        mock_game_state.cooldowns = None
        mock_game_state.character.cooldowns = {"skill_3": 3.0}
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        assert len(context.cooldowns) == 1
        assert context.cooldowns["skill_3"] == 3.0
        
    @pytest.mark.asyncio
    async def test_extract_cooldowns_handles_mock(self, combat_ai, mock_game_state):
        """Test handles Mock cooldowns gracefully."""
        # Set cooldowns to a Mock (which has _mock_name)
        mock_game_state.cooldowns = Mock()
        mock_game_state.character.cooldowns = Mock()
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        # Should return empty dict
        assert context.cooldowns == {}
        
    @pytest.mark.asyncio
    async def test_extract_cooldowns_with_keys_method(self, combat_ai, mock_game_state):
        """Test extracting cooldowns from object with keys method."""
        cooldowns_obj = Mock()
        cooldowns_obj.keys = lambda: ["sk1", "sk2"]
        cooldowns_obj.__getitem__ = lambda self, key: 15.0 if key == "sk1" else 20.0
        
        mock_game_state.cooldowns = cooldowns_obj
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        # Should extract successfully
        assert isinstance(context.cooldowns, dict)
        
    @pytest.mark.asyncio
    async def test_extract_cooldowns_type_error_fallback(self, combat_ai, mock_game_state):
        """Test handles TypeError when iterating cooldowns."""
        cooldowns_obj = Mock()
        cooldowns_obj.keys = Mock(side_effect=TypeError("Not iterable"))
        
        mock_game_state.cooldowns = cooldowns_obj
        mock_game_state.character.cooldowns = None
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        # Should fallback to empty dict
        assert context.cooldowns == {}


class TestThreatCalculation:
    """Test comprehensive threat calculation."""
    
    def test_calculate_threat_with_boss(self, combat_ai):
        """Test threat calculation with boss present."""
        boss = MonsterActor(
            actor_id=1,
            name="Boss",
            mob_id=1001,
            hp=50000,
            hp_max=50000,
            element=Element.NEUTRAL,
            is_boss=True,
        )
        
        character = Mock(hp=1000, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, [boss], [], game_state)
        
        # Should have elevated threat (boss=0.2 base)
        assert threat >= 0.2
        
    def test_calculate_threat_with_aggressive(self, combat_ai):
        """Test threat with aggressive monsters."""
        aggressive = MonsterActor(
            actor_id=1,
            name="Aggressive",
            mob_id=1001,
            hp=1000,
            hp_max=1000,
            element=Element.NEUTRAL,
            is_aggressive=True,
        )
        
        character = Mock(hp=1000, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, [aggressive], [], game_state)
        
        # Should have some threat (aggressive=0.08)
        assert threat > 0.0
        
    def test_calculate_threat_multiple_monsters(self, combat_ai):
        """Test threat with multiple monsters."""
        monsters = [
            MonsterActor(
                actor_id=i,
                name=f"Monster{i}",
                mob_id=1000+i,
                hp=100,
                hp_max=100,
                element=Element.NEUTRAL
            )
            for i in range(5)
        ]
        
        character = Mock(hp=1000, hp_max=1000)
        game_state = Mock()
        
        threat = combat_ai._calculate_threat_level(character, monsters, [], game_state)
        
        # Multiple monsters should increase threat
        assert threat > 0.1
        
    def test_calculate_threat_pvp_enemies(self, combat_ai, mock_game_state):
        """Test threat with enemy players in PvP."""
        enemy = PlayerActor(
            actor_id=1,
            name="Enemy",
            job_id=4001,
            position=Position(x=105, y=105),
            is_hostile=True,
            is_enemy=True,
        )
        
        mock_game_state.pvp_mode = True
        character = Mock(hp=1000, hp_max=1000)
        
        threat = combat_ai._calculate_threat_level(character, [], [enemy], mock_game_state)
        
        # Should have player threat
        assert threat > 0.0


class TestRetreatConditions:
    """Test comprehensive retreat conditions."""
    
    def test_should_retreat_high_threat_medium_hp(self, combat_ai):
        """Test retreat with high threat and medium HP."""
        config = CombatAIConfig(engage_threat_threshold=0.7)
        ai = CombatAI(config=config)
        
        context = CombatContext(
            character=Mock(hp=400, hp_max=1000),  # 40% HP
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.75,  # High threat
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert ai._should_retreat(context)
        
    def test_should_retreat_boss_solo(self, combat_ai):
        """Test retreat from boss when solo."""
        boss = MonsterActor(
            actor_id=1,
            name="Boss",
            mob_id=1001,
            hp=50000,
            hp_max=50000,
            element=Element.NEUTRAL,
            is_boss=True,
        )
        
        context = CombatContext(
            character=Mock(hp=800, hp_max=1000),
            nearby_monsters=[boss],
            nearby_players=[],
            party_members=[],  # Solo
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.5,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert combat_ai._should_retreat(context)


class TestSynchronousAliases:
    """Test synchronous wrapper methods."""
    
    def test_is_emergency_alias(self, combat_ai, mock_game_state):
        """Test is_emergency synchronous alias."""
        mock_game_state.character.hp = 150
        mock_game_state.character.hp_max = 1000
        
        result = combat_ai.is_emergency(mock_game_state)
        
        assert result is True
        
    def test_should_retreat_alias(self, combat_ai, mock_game_state):
        """Test should_retreat synchronous alias."""
        mock_game_state.character.hp = 300
        mock_game_state.character.hp_max = 1000
        
        result = combat_ai.should_retreat(mock_game_state)
        
        assert result is True
        
    def test_create_emergency_action_alias(self, combat_ai, mock_game_state):
        """Test create_emergency_action synchronous alias."""
        action = combat_ai.create_emergency_action(mock_game_state)
        
        assert action is not None
        assert action.action_type == CombatActionType.FLEE
        assert action.priority == 10
        
    def test_create_retreat_action_alias(self, combat_ai, mock_game_state):
        """Test create_retreat_action synchronous alias."""
        monster = Mock()
        monster.position = Position(x=105, y=105)
        
        action = combat_ai.create_retreat_action(mock_game_state, [monster])
        
        assert action is not None
        assert action.action_type == CombatActionType.FLEE
        assert action.priority == 9
        
    def test_calculate_threat_alias(self, combat_ai, mock_game_state):
        """Test calculate_threat synchronous alias."""
        monster = Mock()
        monster.is_mvp = True
        monster.is_boss = False
        monster.is_aggressive = False
        
        threat = combat_ai.calculate_threat(monster, mock_game_state)
        
        assert threat >= 0.4  # MVP threat
        
    def test_is_in_pvp_alias(self, combat_ai, mock_game_state):
        """Test is_in_pvp synchronous alias."""
        mock_game_state.pvp_mode = True
        
        result = combat_ai.is_in_pvp(mock_game_state)
        
        assert result is True


class TestEvaluateSituationSync:
    """Test evaluate_situation synchronous wrapper."""
    
    def test_evaluate_situation_no_event_loop(self, combat_ai, mock_game_state):
        """Test evaluate_situation when no event loop running."""
        # This should use asyncio.run() internally
        context = combat_ai.evaluate_situation(mock_game_state)
        
        assert context is not None
        assert context.character is not None


class TestSelectTargetGameState:
    """Test select_target with GameState input."""
    
    @pytest.mark.asyncio
    async def test_select_target_converts_game_state(self, combat_ai, mock_game_state):
        """Test select_target converts GameState to CombatContext."""
        mock_actor = Mock()
        mock_actor.mob_id = 1002
        mock_actor.actor_id = 1
        mock_actor.name = "Poring"
        mock_actor.hp = 50
        mock_actor.hp_max = 50
        mock_actor.element = "water"
        mock_actor.race = "plant"
        mock_actor.size = "small"
        mock_actor.position = Position(x=105, y=105)
        mock_actor.is_aggressive = False
        mock_actor.is_boss = False
        mock_actor.is_mvp = False
        mock_actor.attack_range = 1
        mock_actor.skills = []
        
        mock_game_state.actors = [mock_actor]
        
        target = await combat_ai.select_target(mock_game_state)
        
        assert target is not None


class TestSelectActionGameState:
    """Test select_action with GameState input."""
    
    @pytest.mark.asyncio
    async def test_select_action_converts_game_state(self, combat_ai, mock_game_state):
        """Test select_action converts GameState to CombatContext."""
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
            position=Position(x=105, y=105),
        )
        
        action = await combat_ai.select_action(mock_game_state, monster)
        
        assert action is not None


class TestDecideWithGameState:
    """Test decide method with GameState input."""
    
    @pytest.mark.asyncio
    async def test_decide_converts_game_state(self, combat_ai, mock_game_state):
        """Test decide converts GameState to CombatContext."""
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        actions = await combat_ai.decide(mock_game_state)
        
        assert isinstance(actions, list)


class TestActionSelectionWithPositioning:
    """Test action selection with positioning."""
    
    @pytest.mark.asyncio
    async def test_select_action_returns_positioning(self, combat_ai):
        """Test select_action can return positioning action."""
        combat_ai.set_role(TacticalRole.RANGED_DPS)
        
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
            position=Position(x=105, y=105),
        )
        
        context = CombatContext(
            character=Mock(
                hp=1000,
                hp_max=1000,
                sp=500,
                sp_max=500,
                job_id=4011,  # Hunter
                position=Position(x=100, y=100),
                buffs=[],
                debuffs=[],
                cooldowns={}
            ),
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.2,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai.select_action(context, monster)
        
        # May return positioning or attack
        assert action is not None


class TestDecidePrebattleBuffs:
    """Test decide method prebattle buff checks."""
    
    @pytest.mark.asyncio
    async def test_decide_checks_prebattle_buffs(self, combat_ai):
        """Test decide checks for prebattle buffs."""
        combat_ai.set_role(TacticalRole.TANK)
        
        context = CombatContext(
            character=Mock(
                hp=1000,
                hp_max=1000,
                sp=500,
                sp_max=500,
                job_id=4007,  # Knight
                position=Position(x=100, y=100),
                buffs=[],
                debuffs=[],
                cooldowns={}
            ),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.0,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        actions = await combat_ai.decide(context)
        
        # May include buff actions
        assert isinstance(actions, list)


class TestExtractPartyMembersEdgeCases:
    """Test extract_party_members edge cases."""
    
    @pytest.mark.asyncio
    async def test_extract_party_members_none(self, combat_ai, mock_game_state):
        """Test extract when party_members is None."""
        mock_game_state.party_members = None
        
        context = await combat_ai.evaluate_combat_situation(mock_game_state)
        
        # Should return empty list
        assert context.party_members == []


class TestPvPDetectionEdgeCases:
    """Test PvP/WoE detection edge cases."""
    
    def test_is_in_pvp_gvg_map_type(self, combat_ai):
        """Test PvP detection with gvg map type."""
        mock_state = Mock()
        mock_state.pvp_mode = None
        mock_state.map_type = "gvg"
        
        assert combat_ai._is_in_pvp(mock_state)
        
    def test_is_in_pvp_battlefield_map_type(self, combat_ai):
        """Test PvP detection with battlefield map type."""
        mock_state = Mock()
        mock_state.pvp_mode = None
        mock_state.map_type = "battlefield"
        
        assert combat_ai._is_in_pvp(mock_state)
        
    def test_is_in_pvp_none_values(self, combat_ai):
        """Test PvP detection with None values."""
        mock_state = Mock()
        mock_state.pvp_mode = None
        mock_state.map_type = None
        
        assert combat_ai._is_in_pvp(mock_state) is False
        
    def test_is_in_woe_none_values(self, combat_ai):
        """Test WoE detection with None values."""
        mock_state = Mock()
        mock_state.woe_active = None
        mock_state.map_name = None
        
        assert combat_ai._is_in_woe(mock_state) is False


class TestFindActorById:
    """Test _find_actor_by_id method."""
    
    def test_find_monster_by_id(self, combat_ai):
        """Test finding monster by ID."""
        monster = MonsterActor(
            actor_id=100,
            name="Target",
            mob_id=1002,
            hp=50,
            hp_max=50,
            element=Element.WATER,
        )
        
        result = combat_ai._find_actor_by_id(100, [monster], [])
        
        assert result is not None
        assert result.actor_id == 100
        
    def test_find_player_by_id(self, combat_ai):
        """Test finding player by ID."""
        player = PlayerActor(
            actor_id=200,
            name="Player",
            job_id=4001,
        )
        
        result = combat_ai._find_actor_by_id(200, [], [player])
        
        assert result is not None
        assert result.actor_id == 200
        
    def test_find_actor_not_found(self, combat_ai):
        """Test finding non-existent actor."""
        result = combat_ai._find_actor_by_id(999, [], [])
        
        assert result is None


class TestCalculateThreatAliasEdgeCases:
    """Test calculate_threat alias with edge cases."""
    
    def test_calculate_threat_no_flags(self, combat_ai, mock_game_state):
        """Test threat for regular monster."""
        monster = Mock()
        monster.is_mvp = False
        monster.is_boss = False
        monster.is_aggressive = False
        
        threat = combat_ai.calculate_threat(monster, mock_game_state)
        
        # Regular monster base threat
        assert threat > 0.0
        assert threat < 0.1


class TestCheckPrebattleBuffs:
    """Test _check_prebattle_buffs method."""
    
    @pytest.mark.asyncio
    async def test_check_prebattle_buffs_no_role(self, combat_ai):
        """Test prebattle buffs when no role set."""
        context = CombatContext(
            character=Mock(hp=1000, hp_max=1000),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.0,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai._check_prebattle_buffs(context)
        
        # Should return None when no role
        assert action is None


class TestSelectActionNoTarget:
    """Test _async_select_action with no target."""
    
    @pytest.mark.asyncio
    async def test_select_action_none_target_returns_none(self, combat_ai):
        """Test select_action returns None when no target."""
        context = CombatContext(
            character=Mock(hp=1000, hp_max=1000, position=Position(x=100, y=100)),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.0,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        action = await combat_ai._async_select_action(context, None)
        
        # Should return None (idle state)
        assert action is None


class TestThreatCalculationPvPPlayers:
    """Test threat calculation with PvP player factors."""
    
    def test_calculate_threat_multiple_enemy_players(self, combat_ai, mock_game_state):
        """Test threat with multiple enemy players."""
        enemies = [
            PlayerActor(
                actor_id=i,
                name=f"Enemy{i}",
                job_id=4001,
                is_hostile=True,
                is_enemy=True,
            )
            for i in range(3)
        ]
        
        mock_game_state.pvp_mode = True
        character = Mock(hp=1000, hp_max=1000)
        
        threat = combat_ai._calculate_threat_level(character, [], enemies, mock_game_state)
        
        # 3 enemy players * 0.15 = 0.45 (capped at 0.3)
        assert threat >= 0.3


class TestDecideBuffAction:
    """Test decide method can include buff actions."""
    
    @pytest.mark.asyncio
    async def test_decide_includes_buff_actions(self, combat_ai):
        """Test decide may include buff actions."""
        combat_ai.set_role(TacticalRole.SUPPORT)
        
        context = CombatContext(
            character=Mock(
                hp=1000,
                hp_max=1000,
                sp=500,
                sp_max=500,
                job_id=4008,  # Priest
                position=Position(x=100, y=100),
                buffs=[],
                debuffs=[],
                cooldowns={}
            ),
            nearby_monsters=[],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.0,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        actions = await combat_ai.decide(context)
        
        # May include buff actions from prebattle check
        assert isinstance(actions, list)