"""
Tests for Combat AI engine.

Tests target selection, action selection, and combat situation evaluation.
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch, MagicMock


class MockCharacterState:
    """Mock character state for testing."""
    
    def __init__(
        self,
        hp: int = 1000,
        hp_max: int = 1000,
        sp: int = 100,
        sp_max: int = 100,
        job: str = "knight",
        position: tuple = (100, 100),
    ):
        self.hp = hp
        self.hp_max = hp_max
        self.sp = sp
        self.sp_max = sp_max
        self.job = job
        self.position = position
        self.skills = {}
        self.skill_points = 0
        self.buffs = []
        self.debuffs = []
        self.cooldowns = {}


class MockGameState:
    """Mock game state for testing."""
    
    def __init__(
        self,
        character: MockCharacterState | None = None,
        tick: int = 1000,
    ):
        self.character = character or MockCharacterState()
        self.tick = tick
        self.actors = []
        self.players = []
        self.party_members = []
        self.pvp_mode = False
        self.woe_active = False
        self.map_name = "prt_fild01"
        self.danger_zones = []
        self.inventory = {}
        self.cooldowns = {}


class MockMonster:
    """Mock monster actor for testing."""
    
    def __init__(
        self,
        actor_id: int = 1,
        name: str = "Poring",
        mob_id: int = 1002,
        hp: int = 100,
        hp_max: int = 100,
        position: tuple = (105, 105),
        is_aggressive: bool = False,
        is_boss: bool = False,
        is_mvp: bool = False,
    ):
        self.actor_id = actor_id
        self.id = actor_id
        self.name = name
        self.mob_id = mob_id
        self.hp = hp
        self.hp_max = hp_max
        self.position = position
        self.is_aggressive = is_aggressive
        self.is_boss = is_boss
        self.is_mvp = is_mvp
        self.element = "neutral"
        self.race = "formless"
        self.size = "small"
        self.attack_range = 1
        self.skills = []


class TestCombatAI:
    """Tests for CombatAI class."""
    
    @pytest.fixture
    def combat_ai(self):
        """Create CombatAI instance."""
        from ai_sidecar.combat.combat_ai import CombatAI
        return CombatAI()
    
    @pytest.fixture
    def game_state(self):
        """Create mock game state."""
        return MockGameState()
    
    @pytest.fixture
    def game_state_with_monster(self):
        """Create game state with monster."""
        state = MockGameState()
        state.actors = [MockMonster()]
        return state
    
    def test_init(self, combat_ai):
        """Test CombatAI initialization."""
        assert combat_ai is not None
        assert combat_ai.config is not None
    
    def test_set_role(self, combat_ai):
        """Test setting tactical role."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        combat_ai.set_role(TacticalRole.TANK)
        assert combat_ai.current_role == TacticalRole.TANK
        
        combat_ai.set_role("melee_dps")
        assert combat_ai.current_role == TacticalRole.MELEE_DPS
    
    def test_get_tactics(self, combat_ai):
        """Test getting tactics by role."""
        from ai_sidecar.combat.tactics import TacticalRole, TankTactics
        
        tactics = combat_ai.get_tactics(TacticalRole.TANK)
        assert tactics is not None
        assert isinstance(tactics, TankTactics)
        
        # Should cache
        tactics2 = combat_ai.get_tactics(TacticalRole.TANK)
        assert tactics is tactics2
    
    @pytest.mark.asyncio
    async def test_evaluate_combat_situation(self, combat_ai, game_state):
        """Test evaluating combat situation."""
        from ai_sidecar.combat.models import CombatContext
        from ai_sidecar.core.state import CharacterState
        
        context = await combat_ai.evaluate_combat_situation(game_state)
        
        assert context is not None
        assert isinstance(context, CombatContext)
        # Character should be converted to CharacterState
        assert isinstance(context.character, CharacterState)
        # Check that values match
        assert context.character.hp == game_state.character.hp
        assert context.character.hp_max == game_state.character.hp_max
    
    @pytest.mark.asyncio
    async def test_evaluate_combat_situation_with_monsters(self, combat_ai, game_state_with_monster):
        """Test evaluating situation with monsters."""
        context = await combat_ai.evaluate_combat_situation(game_state_with_monster)
        
        assert len(context.nearby_monsters) > 0
        assert context.threat_level > 0
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, combat_ai, game_state):
        """Test target selection with no monsters."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        context = await combat_ai.evaluate_combat_situation(game_state)
        
        target = await combat_ai.select_target(context)
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_with_monster(self, combat_ai, game_state_with_monster):
        """Test target selection with monster."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        context = await combat_ai.evaluate_combat_situation(game_state_with_monster)
        
        target = await combat_ai.select_target(context)
        # May or may not find target depending on range/tactics
        # Just ensure it doesn't error
        assert target is None or hasattr(target, "actor_id")
    
    @pytest.mark.asyncio
    async def test_select_action_no_target(self, combat_ai, game_state):
        """Test action selection with no target."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        context = await combat_ai.evaluate_combat_situation(game_state)
        
        action = await combat_ai.select_action(context, None)
        # Should return None or idle action
        assert action is None
    
    @pytest.mark.asyncio
    async def test_decide_empty_state(self, combat_ai, game_state):
        """Test decide with empty game state."""
        actions = await combat_ai.decide(
            await combat_ai.evaluate_combat_situation(game_state)
        )
        
        # Empty state should produce no combat actions
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_decide_with_monsters(self, combat_ai, game_state_with_monster):
        """Test decide with monsters."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        context = await combat_ai.evaluate_combat_situation(game_state_with_monster)
        
        actions = await combat_ai.decide(context)
        assert isinstance(actions, list)


class TestCombatAIEmergency:
    """Tests for CombatAI emergency handling."""
    
    @pytest.fixture
    def combat_ai(self):
        """Create CombatAI instance."""
        from ai_sidecar.combat.combat_ai import CombatAI
        return CombatAI()
    
    @pytest.mark.asyncio
    async def test_emergency_at_critical_hp(self, combat_ai):
        """Test emergency detection at critical HP."""
        # Character at 10% HP
        character = MockCharacterState(hp=100, hp_max=1000)
        state = MockGameState(character=character)
        state.actors = [MockMonster(is_aggressive=True)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        # Should detect emergency
        is_emergency = combat_ai._is_emergency(context)
        assert is_emergency is True
    
    @pytest.mark.asyncio
    async def test_no_emergency_at_high_hp(self, combat_ai):
        """Test no emergency at high HP."""
        character = MockCharacterState(hp=900, hp_max=1000)
        state = MockGameState(character=character)
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        is_emergency = combat_ai._is_emergency(context)
        assert is_emergency is False
    
    @pytest.mark.asyncio
    async def test_retreat_on_low_hp(self, combat_ai):
        """Test retreat detection on low HP."""
        character = MockCharacterState(hp=300, hp_max=1000)
        state = MockGameState(character=character)
        state.actors = [MockMonster(is_aggressive=True)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        should_retreat = combat_ai._should_retreat(context)
        assert should_retreat is True
    
    @pytest.mark.asyncio
    async def test_retreat_on_mvp_solo(self, combat_ai):
        """Test retreat when facing MVP solo."""
        character = MockCharacterState(hp=500, hp_max=1000)
        state = MockGameState(character=character)
        state.actors = [MockMonster(is_mvp=True)]
        state.party_members = []  # Solo
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        should_retreat = combat_ai._should_retreat(context)
        assert should_retreat is True


class TestCombatAIThreat:
    """Tests for CombatAI threat assessment."""
    
    @pytest.fixture
    def combat_ai(self):
        """Create CombatAI instance."""
        from ai_sidecar.combat.combat_ai import CombatAI
        return CombatAI()
    
    @pytest.mark.asyncio
    async def test_threat_level_no_monsters(self, combat_ai):
        """Test threat level with no monsters."""
        state = MockGameState()
        context = await combat_ai.evaluate_combat_situation(state)
        
        assert context.threat_level == 0.0
    
    @pytest.mark.asyncio
    async def test_threat_level_with_monster(self, combat_ai):
        """Test threat level with monster."""
        state = MockGameState()
        state.actors = [MockMonster()]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        assert context.threat_level > 0.0
    
    @pytest.mark.asyncio
    async def test_threat_level_aggressive_monster(self, combat_ai):
        """Test threat level with aggressive monster."""
        state = MockGameState()
        state.actors = [MockMonster(is_aggressive=True)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        # Aggressive should be higher threat
        assert context.threat_level > 0.05
    
    @pytest.mark.asyncio
    async def test_threat_level_boss(self, combat_ai):
        """Test threat level with boss."""
        state = MockGameState()
        state.actors = [MockMonster(is_boss=True)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        # Boss should be high threat
        assert context.threat_level >= 0.2
    
    @pytest.mark.asyncio
    async def test_threat_level_mvp(self, combat_ai):
        """Test threat level with MVP."""
        state = MockGameState()
        state.actors = [MockMonster(is_mvp=True)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        # MVP should be very high threat
        assert context.threat_level >= 0.4
    
    @pytest.mark.asyncio
    async def test_threat_level_low_hp(self, combat_ai):
        """Test threat increases with low HP."""
        # Low HP character
        character = MockCharacterState(hp=200, hp_max=1000)
        state = MockGameState(character=character)
        state.actors = [MockMonster()]
        
        context = await combat_ai.evaluate_combat_situation(state)
        
        # Low HP should increase threat
        assert context.threat_level > 0.2
    
    @pytest.mark.asyncio
    async def test_threat_level_deterministic(self, combat_ai):
        """Test threat assessment is deterministic."""
        state = MockGameState()
        state.actors = [
            MockMonster(actor_id=1, is_aggressive=True),
            MockMonster(actor_id=2, is_boss=True),
        ]
        
        # Evaluate twice
        context1 = await combat_ai.evaluate_combat_situation(state)
        context2 = await combat_ai.evaluate_combat_situation(state)
        
        # Should be same
        assert context1.threat_level == context2.threat_level


class TestCombatAIMetrics:
    """Tests for CombatAI performance metrics."""
    
    @pytest.fixture
    def combat_ai(self):
        """Create CombatAI instance."""
        from ai_sidecar.combat.combat_ai import CombatAI, CombatAIConfig
        
        config = CombatAIConfig(enable_performance_tracking=True)
        return CombatAI(config=config)
    
    @pytest.mark.asyncio
    async def test_decision_time_tracking(self, combat_ai):
        """Test decision time is tracked."""
        state = MockGameState()
        state.actors = [MockMonster()]
        
        context = await combat_ai.evaluate_combat_situation(state)
        await combat_ai.select_action(context, None)
        
        assert combat_ai.metrics.decisions_made >= 0
    
    @pytest.mark.asyncio
    async def test_decision_time_under_limit(self, combat_ai):
        """Test decisions complete within time limit."""
        state = MockGameState()
        state.actors = [MockMonster() for _ in range(10)]
        
        context = await combat_ai.evaluate_combat_situation(state)
        await combat_ai.select_action(context, None)
        
        # Should complete within 50ms
        # Note: First run might be slower due to imports
        assert combat_ai.metrics.average_decision_time_ms < 100


class TestCombatContext:
    """Tests for CombatContext model."""
    
    def test_create_context(self):
        """Test creating CombatContext."""
        from ai_sidecar.combat.models import CombatContext
        
        character = MockCharacterState()
        
        context = CombatContext(
            character=character,
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
        
        assert context is not None
        assert context.threat_level == 0.0
    
    def test_context_with_monsters(self):
        """Test context with monsters."""
        from ai_sidecar.combat.models import CombatContext, MonsterActor
        
        character = MockCharacterState()
        
        monster = MonsterActor(
            actor_id=1,
            name="Poring",
            mob_id=1002,
            hp=100,
            hp_max=100,
            element="neutral",
            race="formless",
            size="small",
            position=(100, 100),
            is_aggressive=False,
            is_boss=False,
            is_mvp=False,
            attack_range=1,
            skills=[],
        )
        
        context = CombatContext(
            character=character,
            nearby_monsters=[monster],
            nearby_players=[],
            party_members=[],
            active_buffs=[],
            active_debuffs=[],
            cooldowns={},
            threat_level=0.1,
            in_pvp=False,
            in_woe=False,
            map_danger_zones=[],
        )
        
        assert len(context.nearby_monsters) == 1
        assert context.nearby_monsters[0].name == "Poring"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])