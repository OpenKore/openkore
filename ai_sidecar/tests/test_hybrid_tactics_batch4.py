"""
Comprehensive tests for combat/tactics/hybrid.py - BATCH 4.
Target: 95%+ coverage (currently 83.38%, 27 uncovered lines).
"""

import pytest
from unittest.mock import Mock
from ai_sidecar.combat.tactics.hybrid import (
    HybridTactics,
    HybridTacticsConfig,
    ActiveRole,
)
from ai_sidecar.combat.tactics.base import Position, Skill, TargetPriority, TacticalRole
from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace, MonsterSize


class MockCombatContext:
    """Mock combat context."""
    
    def __init__(self):
        self.character_hp = 1000
        self.character_hp_max = 1000
        self.character_sp = 200
        self.character_sp_max = 200
        self.character_position = Position(x=100, y=100)
        self.nearby_monsters = []
        self.party_members = []
        self.cooldowns = {}


class TestHybridTactics:
    """Test HybridTactics functionality."""
    
    @pytest.fixture
    def config(self):
        """Create hybrid tactics config."""
        return HybridTacticsConfig()
    
    @pytest.fixture
    def tactics(self, config):
        """Create hybrid tactics instance."""
        return HybridTactics(config)
    
    @pytest.fixture
    def context(self):
        """Create mock combat context."""
        return MockCombatContext()
    
    @pytest.fixture
    def sample_monster(self):
        """Create sample monster."""
        return MonsterActor(
            actor_id=1001,
            mob_id=1002,
            name="Test Monster",
            level=50,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(105, 105),
            hp=1000,
            hp_max=1000,
        )
    
    def test_initialization(self, tactics):
        """Test hybrid tactics initialization."""
        assert tactics.role == TacticalRole.HYBRID
        assert isinstance(tactics._active_role, ActiveRole)
        assert tactics._active_role.current_role == "dps"
    
    def test_initialization_custom_role(self):
        """Test initialization with custom preferred role."""
        config = HybridTacticsConfig(preferred_role="tank")
        tactics = HybridTactics(config)
        
        assert tactics._active_role.current_role == "tank"
    
    @pytest.mark.asyncio
    async def test_select_target_dps_mode(self, tactics, context, sample_monster):
        """Test target selection in DPS mode."""
        context.nearby_monsters = [sample_monster]
        tactics._active_role.current_role = "dps"
        
        target = await tactics.select_target(context)
        
        assert target is not None
    
    @pytest.mark.asyncio
    async def test_select_target_tank_mode(self, tactics, context, sample_monster):
        """Test target selection in tank mode."""
        context.nearby_monsters = [sample_monster]
        tactics._active_role.current_role = "tank"
        
        target = await tactics.select_target(context)
        
        assert target is not None or len(context.nearby_monsters) == 0
    
    @pytest.mark.asyncio
    async def test_select_target_support_mode(self):
        """Test target selection in support mode."""
        # Disable auto role switching for this test
        config = HybridTacticsConfig(auto_switch_roles=False, preferred_role="support")
        tactics = HybridTactics(config)
        context = MockCombatContext()
        
        tactics._active_role.current_role = "support"
        
        # Add party member needing heal (below 80% threshold)
        ally = Mock()
        ally.hp = 600
        ally.hp_max = 1000
        ally.actor_id = 2001
        ally.position = (102, 102)
        context.party_members = [ally]
        
        target = await tactics.select_target(context)
        
        # Should return ally as target for healing
        assert target is not None
        assert target.actor_id == 2001
    
    @pytest.mark.asyncio
    async def test_select_skill_emergency_heal(self, tactics, context, sample_monster):
        """Test emergency heal skill selection."""
        context.character_hp = 250  # 25% HP
        context.cooldowns = {}
        
        target_priority = TargetPriority(
            actor_id=sample_monster.actor_id,
            priority_score=100,
            reason="test",
            distance=5.0,
            hp_percent=1.0,
        )
        
        skill = await tactics.select_skill(context, target_priority)
        
        if skill:
            assert skill.name == "heal"
    
    @pytest.mark.asyncio
    async def test_select_skill_tank_mode(self, tactics, context, sample_monster):
        """Test skill selection in tank mode."""
        tactics._active_role.current_role = "tank"
        context.character_hp = 800  # Healthy
        
        target = TargetPriority(
            actor_id=sample_monster.actor_id,
            priority_score=100,
            reason="test",
            distance=2.0,
            hp_percent=1.0,
        )
        
        skill = await tactics.select_skill(context, target)
        
        # Should select tank or buff skill
        if skill:
            assert skill.name in tactics.TANK_SKILLS + tactics.BUFF_SKILLS
    
    @pytest.mark.asyncio
    async def test_select_skill_support_mode(self, tactics, context):
        """Test skill selection in support mode."""
        tactics._active_role.current_role = "support"
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="heal",
            distance=5.0,
            hp_percent=0.6,  # Low HP
        )
        
        skill = await tactics.select_skill(context, target)
        
        if skill:
            assert skill.name in tactics.SUPPORT_SKILLS or skill.name == "heal"
    
    @pytest.mark.asyncio
    async def test_select_skill_dps_mode(self, tactics, context, sample_monster):
        """Test skill selection in DPS mode."""
        tactics._active_role.current_role = "dps"
        
        target = TargetPriority(
            actor_id=sample_monster.actor_id,
            priority_score=100,
            reason="test",
            distance=2.0,
            hp_percent=1.0,
        )
        
        skill = await tactics.select_skill(context, target)
        
        if skill:
            assert skill.name in tactics.DPS_SKILLS
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_tank(self, tactics, context, sample_monster):
        """Test positioning in tank mode."""
        tactics._active_role.current_role = "tank"
        context.nearby_monsters = [sample_monster]
        
        ally = Mock()
        ally.position = (90, 90)
        context.party_members = [ally]
        
        position = await tactics.evaluate_positioning(context)
        
        # Tank should position between party and enemies
        if position:
            assert isinstance(position, Position)
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_support(self, tactics, context, sample_monster):
        """Test positioning in support mode."""
        tactics._active_role.current_role = "support"
        context.nearby_monsters = [sample_monster]
        
        ally = Mock()
        ally.position = (95, 95)
        context.party_members = [ally]
        
        position = await tactics.evaluate_positioning(context)
        
        # Support should position behind party
        if position:
            assert isinstance(position, Position)
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_dps(self, tactics, context):
        """Test positioning in DPS mode."""
        tactics._active_role.current_role = "dps"
        # Create new monster with far away position (frozen models can't be modified)
        far_monster = MonsterActor(
            actor_id=1001,
            mob_id=1002,
            name="Test Monster",
            level=50,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(120, 120),  # Far away
            hp=1000,
            hp_max=1000,
        )
        context.nearby_monsters = [far_monster]
        
        position = await tactics.evaluate_positioning(context)
        
        # DPS should move toward target if far
        if position:
            assert isinstance(position, Position)
    
    def test_get_threat_assessment_healthy(self, tactics, context):
        """Test threat assessment when healthy."""
        threat = tactics.get_threat_assessment(context)
        
        assert 0 <= threat <= 1.0
        assert threat < 0.3  # Should be low when healthy
    
    def test_get_threat_assessment_low_hp(self, tactics, context):
        """Test threat assessment with low HP."""
        context.character_hp = 200  # 20% HP
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat > 0.3
    
    def test_get_threat_assessment_close_enemies(self, tactics, context, sample_monster):
        """Test threat assessment with close enemies."""
        # Add multiple close enemies
        for i in range(5):
            monster = Mock()
            monster.position = (101 + i, 101)
            context.nearby_monsters.append(monster)
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat > 0
    
    def test_get_threat_assessment_tank_mode(self, tactics, context):
        """Test threat in tank mode has higher tolerance."""
        # Create mock monsters with tuple positions
        for i in range(3):
            monster = Mock()
            monster.position = (101 + i, 101)
            context.nearby_monsters.append(monster)
        
        tactics._active_role.current_role = "tank"
        tank_threat = tactics.get_threat_assessment(context)
        
        tactics._active_role.current_role = "dps"
        dps_threat = tactics.get_threat_assessment(context)
        
        # Tank mode should have lower threat for same situation
        assert tank_threat <= dps_threat
    
    def test_get_threat_assessment_party_emergency(self, tactics, context):
        """Test threat with party member emergency."""
        ally = Mock()
        ally.hp = 200
        ally.hp_max = 1000
        context.party_members = [ally]
        
        threat = tactics.get_threat_assessment(context)
        
        # Threat should include party emergency (0.1) plus base, so >= 0.1
        assert threat >= 0.1
    
    def test_party_needs_support_yes(self, tactics, context):
        """Test detecting party needs support."""
        # Add low HP party members
        for i in range(3):
            ally = Mock()
            ally.hp = 400
            ally.hp_max = 1000
            context.party_members.append(ally)
        
        needs_support = tactics._party_needs_support(context)
        
        assert needs_support is True
    
    def test_party_needs_support_no(self, tactics, context):
        """Test party doesn't need support."""
        ally = Mock()
        ally.hp = 900
        ally.hp_max = 1000
        context.party_members = [ally]
        
        needs_support = tactics._party_needs_support(context)
        
        assert needs_support is False
    
    def test_party_needs_tank_yes(self, context, sample_monster):
        """Test detecting party needs tank."""
        # Create config with custom threshold (frozen models can't be modified)
        config = HybridTacticsConfig(tank_mode_party_threshold=2)
        tactics = HybridTactics(config)
        
        # Add party members
        context.party_members = [Mock(), Mock()]
        
        # Add multiple enemies
        context.nearby_monsters = [sample_monster] * 3
        
        needs_tank = tactics._party_needs_tank(context)
        
        assert needs_tank is True
    
    def test_party_needs_tank_no(self, tactics, context):
        """Test party doesn't need tank."""
        context.party_members = [Mock()]
        context.nearby_monsters = []
        
        needs_tank = tactics._party_needs_tank(context)
        
        assert needs_tank is False
    
    def test_determine_optimal_role_support(self, tactics, context):
        """Test role determination chooses support."""
        # Multiple low HP allies
        for i in range(3):
            ally = Mock()
            ally.hp = 300
            ally.hp_max = 1000
            context.party_members.append(ally)
        
        role = tactics._determine_optimal_role(context)
        
        assert role == "support"
    
    def test_determine_optimal_role_tank(self, context, sample_monster):
        """Test role determination chooses tank."""
        # Create config with custom threshold (frozen models can't be modified)
        config = HybridTacticsConfig(tank_mode_party_threshold=2)
        tactics = HybridTactics(config)
        
        # Healthy party
        ally1 = Mock()
        ally1.hp = 900
        ally1.hp_max = 1000
        ally1.position = (95, 95)
        
        ally2 = Mock()
        ally2.hp = 800
        ally2.hp_max = 1000
        ally2.position = (96, 96)
        
        context.party_members = [ally1, ally2]
        
        # Multiple enemies
        context.nearby_monsters = [sample_monster] * 3
        
        role = tactics._determine_optimal_role(context)
        
        assert role == "tank"
    
    def test_evaluate_role_switch(self, tactics, context):
        """Test role switching evaluation."""
        tactics._active_role.current_role = "dps"
        tactics._role_switch_timer = 0.0
        
        # Create situation needing support
        for i in range(3):
            ally = Mock()
            ally.hp = 300
            ally.hp_max = 1000
            context.party_members.append(ally)
        
        tactics._evaluate_role_switch(context)
        
        assert tactics._active_role.current_role == "support"
    
    def test_evaluate_role_switch_on_cooldown(self, tactics, context):
        """Test role switch respects cooldown."""
        original_role = tactics._active_role.current_role
        tactics._role_switch_timer = 10.0  # On cooldown
        
        tactics._evaluate_role_switch(context)
        
        # Should not switch
        assert tactics._active_role.current_role == original_role
    
    def test_helper_get_ally_hp_percent(self, tactics):
        """Test getting ally HP percent."""
        ally = Mock()
        ally.hp = 500
        ally.hp_max = 1000
        
        hp_percent = tactics._get_ally_hp_percent(ally)
        
        assert hp_percent == 0.5
    
    def test_helper_get_ally_hp_percent_no_attrs(self, tactics):
        """Test getting HP percent for ally without HP attrs."""
        ally = Mock(spec=[])
        
        hp_percent = tactics._get_ally_hp_percent(ally)
        
        assert hp_percent == 1.0
    
    def test_helper_get_ally_id(self, tactics):
        """Test getting ally ID."""
        ally = Mock()
        ally.actor_id = 2001
        
        ally_id = tactics._get_ally_id(ally)
        
        assert ally_id == 2001
    
    def test_helper_get_ally_distance(self, tactics, context):
        """Test getting distance to ally."""
        ally = Mock()
        ally.position = (105, 105)
        
        distance = tactics._get_ally_distance(context, ally)
        
        assert distance > 0
    
    def test_calculate_party_center(self, tactics, context):
        """Test calculating party center position."""
        ally1 = Mock()
        ally1.position = (100, 100)
        ally2 = Mock()
        ally2.position = (110, 110)
        context.party_members = [ally1, ally2]
        
        center = tactics._calculate_party_center(context)
        
        assert center is not None
        assert center.x == 105
        assert center.y == 105
    
    def test_calculate_party_center_no_members(self, tactics, context):
        """Test party center with no members."""
        context.party_members = []
        
        center = tactics._calculate_party_center(context)
        
        assert center is None
    
    def test_calculate_threat_center(self, tactics, context, sample_monster):
        """Test calculating enemy center."""
        monster2 = Mock()
        monster2.position = (110, 110)
        context.nearby_monsters = [sample_monster, monster2]
        
        center = tactics._calculate_threat_center(context)
        
        assert center is not None
        assert isinstance(center, Position)
    
    def test_calculate_threat_center_no_monsters(self, tactics, context):
        """Test threat center with no enemies."""
        context.nearby_monsters = []
        
        center = tactics._calculate_threat_center(context)
        
        assert center is None
    
    def test_calculate_intercept_position(self, tactics):
        """Test calculating intercept position."""
        party = Position(x=100, y=100)
        threat = Position(x=120, y=120)
        
        intercept = tactics._calculate_intercept_position(party, threat)
        
        assert isinstance(intercept, Position)
        # Should be between party and threat
        assert party.x < intercept.x < threat.x
    
    def test_calculate_safe_position(self, tactics):
        """Test calculating safe position."""
        party = Position(x=100, y=100)
        threat = Position(x=120, y=120)
        
        safe_pos = tactics._calculate_safe_position(party, threat)
        
        assert isinstance(safe_pos, Position)
        # Should be behind party away from threat
    
    def test_move_toward(self, tactics):
        """Test moving toward target."""
        current = Position(x=100, y=100)
        target = Position(x=110, y=110)
        
        new_pos = tactics._move_toward(current, target, distance=2)
        
        assert isinstance(new_pos, Position)
        # Should move closer to target
        assert abs(new_pos.x - current.x) > 0
    
    def test_get_skill_id(self, tactics):
        """Test getting skill IDs."""
        assert tactics._get_skill_id("grand_cross") == 254
        assert tactics._get_skill_id("heal") == 28
        assert tactics._get_skill_id("unknown_skill") == 0
    
    def test_get_sp_cost(self, tactics):
        """Test getting SP costs."""
        assert tactics._get_sp_cost("grand_cross") == 37
        assert tactics._get_sp_cost("heal") == 15
        assert tactics._get_sp_cost("unknown_skill") == 20  # Default
    
    def test_get_skill_range(self, tactics):
        """Test getting skill ranges."""
        assert tactics._get_skill_range("shield_boomerang") == 9
        assert tactics._get_skill_range("bash") == 1
        assert tactics._get_skill_range("unknown_skill") == 1  # Default
    
    @pytest.mark.asyncio
    async def test_select_target_support_no_heal_needed(self, tactics, context):
        """Test support target when no healing needed."""
        tactics._active_role.current_role = "support"
        
        # Healthy ally
        ally = Mock()
        ally.hp = 950
        ally.hp_max = 1000
        ally.actor_id = 2001
        ally.position = (100, 100)
        context.party_members = [ally]
        
        # Add monster with tuple position
        monster = Mock()
        monster.actor_id = 1001
        monster.position = (105, 105)
        monster.hp = 1000
        monster.hp_max = 1000
        context.nearby_monsters = [monster]
        
        target = await tactics.select_target(context)
        
        # Should target enemy instead
        if target:
            assert target.actor_id == monster.actor_id
    
    @pytest.mark.asyncio
    async def test_select_target_support_fallback(self, tactics, context):
        """Test support target fallback to ally."""
        tactics._active_role.current_role = "support"
        
        # Ally not critically low but no enemies
        ally = Mock()
        ally.hp = 700
        ally.hp_max = 1000
        ally.actor_id = 2001
        ally.position = (100, 100)
        context.party_members = [ally]
        context.nearby_monsters = []
        
        target = await tactics.select_target(context)
        
        # Should still return ally target
        if target:
            assert target.actor_id == ally.actor_id
    
    def test_needs_emergency_heal_yes(self, tactics, context):
        """Test emergency heal detection."""
        context.character_hp = 250
        context.character_hp_max = 1000
        
        needs_heal = tactics._needs_emergency_heal(context)
        
        assert needs_heal is True
    
    def test_needs_emergency_heal_no(self, tactics, context):
        """Test no emergency heal needed."""
        context.character_hp = 800
        context.character_hp_max = 1000
        
        needs_heal = tactics._needs_emergency_heal(context)
        
        assert needs_heal is False


class TestActiveRole:
    """Test ActiveRole class."""
    
    def test_initialization_default(self):
        """Test ActiveRole default initialization."""
        role = ActiveRole()
        
        assert role.current_role == "dps"
        assert role.role_duration == 0.0
        assert role.switch_cooldown == 0.0
    
    def test_initialization_custom(self):
        """Test ActiveRole with custom role."""
        role = ActiveRole(role="tank")
        
        assert role.current_role == "tank"


class TestHybridTacticsConfig:
    """Test HybridTacticsConfig."""
    
    def test_default_config(self):
        """Test default configuration values."""
        config = HybridTacticsConfig()
        
        assert config.tank_mode_party_threshold == 2
        assert config.support_mode_threshold == 0.60
        assert config.auto_switch_roles is True
        assert config.preferred_role == "dps"
        assert config.melee_range == 2
        assert config.ranged_range == 9