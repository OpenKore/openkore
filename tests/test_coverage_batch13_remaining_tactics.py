"""
Coverage Batch 13: Remaining Tactical Systems
Target: 10% → 11% coverage (~321 statements)

Modules:
- ai_sidecar/combat/tactics/hybrid.py (265 lines, 22% → 70%)
- ai_sidecar/combat/tactics/support.py (226 lines, 22% → 70%)  
- ai_sidecar/combat/tactics/ranged_dps.py (172 lines, 20% → 70%)

This batch focuses on:
- Hybrid role switching and multi-mode behavior
- Support healing priority and buff management
- Ranged DPS kiting and positioning logic
"""

import pytest
from unittest.mock import Mock, AsyncMock, MagicMock, patch
from ai_sidecar.combat.tactics.hybrid import (
    HybridTactics,
    HybridTacticsConfig,
    ActiveRole
)
from ai_sidecar.combat.tactics.support import (
    SupportTactics,
    SupportTacticsConfig
)
from ai_sidecar.combat.tactics.ranged_dps import (
    RangedDPSTactics,
    RangedDPSTacticsConfig
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TargetPriority,
    TacticalRole
)


# =============================================================================
# Test Fixtures
# =============================================================================

@pytest.fixture
def hybrid_config():
    """Create hybrid tactics configuration."""
    return HybridTacticsConfig(
        tank_mode_party_threshold=2,
        support_mode_threshold=0.60,
        auto_switch_roles=True,
        preferred_role="dps",
        melee_range=2,
        ranged_range=9
    )


@pytest.fixture
def support_config():
    """Create support tactics configuration."""
    return SupportTacticsConfig(
        heal_trigger_threshold=0.80,
        emergency_heal_threshold=0.35,
        maintain_buffs=True,
        self_heal_priority=0.75,
        safe_distance_from_combat=5,
        max_heal_range=9
    )


@pytest.fixture
def ranged_config():
    """Create ranged DPS tactics configuration."""
    return RangedDPSTacticsConfig(
        optimal_range=9,
        min_safe_distance=4,
        kiting_enabled=True,
        use_traps=True,
        trap_placement_distance=3,
        prefer_single_target=True
    )


@pytest.fixture
def mock_context():
    """Create mock combat context."""
    context = Mock()
    context.character_position = Position(x=50, y=50)
    context.character_hp = 500
    context.character_hp_max = 1000
    context.character_sp = 200
    context.character_sp_max = 300
    context.nearby_monsters = []
    context.party_members = []
    context.cooldowns = {}
    context.buffs = {}
    context.character_id = 100
    return context


@pytest.fixture
def mock_monster():
    """Create mock monster."""
    monster = Mock()
    monster.actor_id = 1001
    monster.position = (55, 55)  # Tuple format for ranged_dps compatibility
    monster.hp = 300
    monster.hp_max = 500
    monster.is_mvp = False
    monster.is_boss = False
    return monster


@pytest.fixture
def mock_party_member():
    """Create mock party member."""
    member = Mock()
    member.actor_id = 2001
    member.position = Position(x=48, y=48)
    member.hp = 400
    member.hp_max = 800
    return member


# =============================================================================
# Hybrid Tactics Tests
# =============================================================================

class TestHybridTacticsCore:
    """Test hybrid tactics initialization and core behavior."""
    
    def test_hybrid_tactics_initialization_default(self):
        """Cover HybridTactics initialization with defaults."""
        tactic = HybridTactics()
        
        assert tactic is not None
        assert tactic.role == TacticalRole.HYBRID
        assert tactic._active_role.current_role == "dps"
        assert tactic._role_switch_timer == 0.0
    
    def test_hybrid_tactics_initialization_custom_config(self, hybrid_config):
        """Cover HybridTactics with custom configuration."""
        tactic = HybridTactics(config=hybrid_config)
        
        assert tactic.hybrid_config == hybrid_config
        assert tactic._active_role.current_role == "dps"
        assert tactic.hybrid_config.tank_mode_party_threshold == 2
        assert tactic.hybrid_config.support_mode_threshold == 0.60
    
    def test_active_role_initialization(self):
        """Cover ActiveRole class initialization."""
        role = ActiveRole(role="tank")
        
        assert role.current_role == "tank"
        assert role.role_duration == 0.0
        assert role.switch_cooldown == 0.0
    
    def test_hybrid_skill_constants(self):
        """Cover hybrid skill constant lists."""
        tactic = HybridTactics()
        
        assert "grand_cross" in tactic.TANK_SKILLS
        assert "holy_cross" in tactic.DPS_SKILLS
        assert "heal" in tactic.SUPPORT_SKILLS
        assert "auto_guard" in tactic.BUFF_SKILLS


class TestHybridRoleSwitching:
    """Test hybrid role switching logic."""
    
    @pytest.mark.asyncio
    async def test_select_target_with_role_evaluation(self, hybrid_config, mock_context):
        """Cover select_target triggering role evaluation."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "dps"
        
        # Add party members needing support
        low_hp_member = Mock()
        low_hp_member.actor_id = 2001
        low_hp_member.position = Position(x=48, y=48)
        low_hp_member.hp = 200
        low_hp_member.hp_max = 1000
        
        low_hp_member2 = Mock()
        low_hp_member2.actor_id = 2002
        low_hp_member2.position = Position(x=49, y=49)
        low_hp_member2.hp = 250
        low_hp_member2.hp_max = 1000
        
        mock_context.party_members = [low_hp_member, low_hp_member2]
        
        result = await tactic.select_target(mock_context)
        
        # Should switch to support role
        assert tactic._active_role.current_role == "support"
    
    @pytest.mark.asyncio
    async def test_evaluate_role_switch_on_cooldown(self, hybrid_config, mock_context):
        """Cover role switch cooldown prevention."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._role_switch_timer = 3.0
        initial_role = tactic._active_role.current_role
        
        tactic._evaluate_role_switch(mock_context)
        
        # Should not switch while on cooldown
        assert tactic._active_role.current_role == initial_role
    
    def test_determine_optimal_role_support_needed(self, hybrid_config, mock_context):
        """Cover determine_optimal_role selecting support."""
        tactic = HybridTactics(config=hybrid_config)
        
        # Add low HP party members
        member1 = Mock()
        member1.hp = 300
        member1.hp_max = 1000
        
        member2 = Mock()
        member2.hp = 400
        member2.hp_max = 1000
        
        mock_context.party_members = [member1, member2]
        
        role = tactic._determine_optimal_role(mock_context)
        
        assert role == "support"
    
    def test_determine_optimal_role_tank_needed(self, hybrid_config, mock_context):
        """Cover determine_optimal_role selecting tank."""
        tactic = HybridTactics(config=hybrid_config)
        
        # Add party members and multiple enemies
        member1 = Mock()
        member1.hp = 800
        member1.hp_max = 1000
        
        member2 = Mock()
        member2.hp = 900
        member2.hp_max = 1000
        
        mock_context.party_members = [member1, member2]
        mock_context.nearby_monsters = [Mock(), Mock(), Mock()]
        
        role = tactic._determine_optimal_role(mock_context)
        
        assert role == "tank"
    
    def test_party_needs_support_true(self, hybrid_config, mock_context):
        """Cover party_needs_support returning true."""
        tactic = HybridTactics(config=hybrid_config)
        
        member1 = Mock()
        member1.hp = 300
        member1.hp_max = 1000
        
        member2 = Mock()
        member2.hp = 400
        member2.hp_max = 1000
        
        mock_context.party_members = [member1, member2]
        
        result = tactic._party_needs_support(mock_context)
        
        assert result is True
    
    def test_party_needs_support_false(self, hybrid_config, mock_context):
        """Cover party_needs_support returning false."""
        tactic = HybridTactics(config=hybrid_config)
        
        member1 = Mock()
        member1.hp = 800
        member1.hp_max = 1000
        
        mock_context.party_members = [member1]
        
        result = tactic._party_needs_support(mock_context)
        
        assert result is False
    
    def test_party_needs_tank_true(self, hybrid_config, mock_context):
        """Cover party_needs_tank returning true."""
        tactic = HybridTactics(config=hybrid_config)
        
        member1 = Mock()
        member2 = Mock()
        mock_context.party_members = [member1, member2]
        mock_context.nearby_monsters = [Mock(), Mock(), Mock()]
        
        result = tactic._party_needs_tank(mock_context)
        
        assert result is True
    
    def test_party_needs_tank_false_small_party(self, hybrid_config, mock_context):
        """Cover party_needs_tank false for small party."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_context.party_members = [Mock()]  # Below threshold
        
        result = tactic._party_needs_tank(mock_context)
        
        assert result is False


class TestHybridTargetSelection:
    """Test hybrid target selection by role."""
    
    @pytest.mark.asyncio
    async def test_select_target_as_tank(self, mock_context, mock_monster):
        """Cover select_target in tank role."""
        config = HybridTacticsConfig(auto_switch_roles=False)
        tactic = HybridTactics(config=config)
        tactic._active_role.current_role = "tank"
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
        assert result.actor_id == mock_monster.actor_id
    
    @pytest.mark.asyncio
    async def test_select_target_as_support(self, mock_context, mock_party_member):
        """Cover select_target in support role."""
        config = HybridTacticsConfig(auto_switch_roles=False)
        tactic = HybridTactics(config=config)
        tactic._active_role.current_role = "support"
        
        mock_party_member.hp = 300
        mock_party_member.hp_max = 1000
        mock_context.party_members = [mock_party_member]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
        assert result.reason == "heal_target"
    
    @pytest.mark.asyncio
    async def test_select_target_as_dps(self, mock_context, mock_monster):
        """Cover select_target in DPS role."""
        config = HybridTacticsConfig(auto_switch_roles=False)
        tactic = HybridTactics(config=config)
        tactic._active_role.current_role = "dps"
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
    
    def test_select_tank_target_no_monsters(self, hybrid_config, mock_context):
        """Cover _select_tank_target with no monsters."""
        tactic = HybridTactics(config=hybrid_config)
        
        result = tactic._select_tank_target(mock_context)
        
        assert result is None
    
    def test_select_tank_target_ally_target(self, hybrid_config, mock_context, mock_monster):
        """Cover _select_tank_target prioritizing ally target."""
        tactic = HybridTactics(config=hybrid_config)
        
        # Add threat entry for monster targeting ally
        tactic._threat_table[mock_monster.actor_id] = Mock()
        tactic._threat_table[mock_monster.actor_id].is_targeting_self = False
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = tactic._select_tank_target(mock_context)
        
        assert result is not None
        assert result.reason == "ally_target"
    
    def test_select_support_target_healing_needed(self, hybrid_config, mock_context, mock_party_member):
        """Cover _select_support_target with healing needed."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_party_member.hp = 300
        mock_party_member.hp_max = 1000
        mock_context.party_members = [mock_party_member]
        
        result = tactic._select_support_target(mock_context)
        
        assert result is not None
        assert result.hp_percent < 0.8
    
    def test_select_support_target_falls_back_to_enemy(self, hybrid_config, mock_context, mock_monster):
        """Cover _select_support_target falling back to enemies."""
        tactic = HybridTactics(config=hybrid_config)
        
        member = Mock()
        member.hp = 900
        member.hp_max = 1000
        member.actor_id = 2001
        member.position = Position(x=48, y=48)
        
        mock_context.party_members = [member]
        mock_context.nearby_monsters = [mock_monster]
        
        result = tactic._select_support_target(mock_context)
        
        assert result is not None
    
    def test_select_dps_target(self, hybrid_config, mock_context, mock_monster):
        """Cover _select_dps_target."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = tactic._select_dps_target(mock_context)
        
        assert result is not None


class TestHybridSkillSelection:
    """Test hybrid skill selection by role."""
    
    @pytest.mark.asyncio
    async def test_select_skill_emergency_heal(self, hybrid_config, mock_context):
        """Cover select_skill emergency heal check."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "dps"
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=5,
            hp_percent=0.5
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        # Should select heal due to emergency
        assert skill is not None
        assert skill.name == "heal"
    
    @pytest.mark.asyncio
    async def test_select_tank_skill(self, mock_context):
        """Cover select_skill in tank mode."""
        config = HybridTacticsConfig(auto_switch_roles=False)
        tactic = HybridTactics(config=config)
        tactic._active_role.current_role = "tank"
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=2,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
        # _select_tank_skill checks buffs first, then tank skills
        assert skill.name in (tactic.TANK_SKILLS + tactic.BUFF_SKILLS)
    
    @pytest.mark.asyncio
    async def test_select_support_skill(self, hybrid_config, mock_context):
        """Cover select_skill in support mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "support"
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=150,
            reason="heal_target",
            distance=5,
            hp_percent=0.4
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_dps_skill(self, hybrid_config, mock_context):
        """Cover select_skill in DPS mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "dps"
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=2,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
        assert skill.name in tactic.DPS_SKILLS
    
    def test_select_buff_skill(self, hybrid_config, mock_context):
        """Cover _select_buff_skill."""
        tactic = HybridTactics(config=hybrid_config)
        
        skill = tactic._select_buff_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.BUFF_SKILLS
    
    def test_select_heal_skill(self, hybrid_config, mock_context):
        """Cover _select_heal_skill."""
        tactic = HybridTactics(config=hybrid_config)
        
        skill = tactic._select_heal_skill(mock_context)
        
        assert skill is not None
        assert skill.name == "heal"
    
    def test_needs_emergency_heal_true(self, hybrid_config, mock_context):
        """Cover _needs_emergency_heal returning true."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        result = tactic._needs_emergency_heal(mock_context)
        
        assert result is True
    
    def test_needs_emergency_heal_false(self, hybrid_config, mock_context):
        """Cover _needs_emergency_heal returning false."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_context.character_hp = 500
        mock_context.character_hp_max = 1000
        
        result = tactic._needs_emergency_heal(mock_context)
        
        assert result is False


class TestHybridPositioning:
    """Test hybrid positioning by role."""
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_as_tank(self, hybrid_config, mock_context, mock_monster):
        """Cover evaluate_positioning in tank mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "tank"
        
        member = Mock()
        member.position = Position(x=45, y=45)
        mock_context.party_members = [member]
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
        assert isinstance(result, Position)
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_as_support(self, hybrid_config, mock_context, mock_monster):
        """Cover evaluate_positioning in support mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "support"
        
        member = Mock()
        member.position = Position(x=45, y=45)
        mock_context.party_members = [member]
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_as_dps(self, hybrid_config, mock_context, mock_monster):
        """Cover evaluate_positioning in DPS mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "dps"
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    def test_evaluate_tank_positioning_no_monsters(self, hybrid_config, mock_context):
        """Cover _evaluate_tank_positioning with no monsters."""
        tactic = HybridTactics(config=hybrid_config)
        
        result = tactic._evaluate_tank_positioning(mock_context)
        
        assert result is None
    
    def test_evaluate_support_positioning(self, hybrid_config, mock_context, mock_monster):
        """Cover _evaluate_support_positioning."""
        tactic = HybridTactics(config=hybrid_config)
        
        member = Mock()
        member.position = Position(x=45, y=45)
        mock_context.party_members = [member]
        mock_context.nearby_monsters = [mock_monster]
        
        result = tactic._evaluate_support_positioning(mock_context)
        
        assert result is not None
    
    def test_evaluate_dps_positioning_move_toward(self, hybrid_config, mock_context):
        """Cover _evaluate_dps_positioning moving toward target."""
        tactic = HybridTactics(config=hybrid_config)
        
        monster = Mock()
        monster.position = Position(x=60, y=60)
        mock_context.nearby_monsters = [monster]
        
        result = tactic._evaluate_dps_positioning(mock_context)
        
        assert result is not None
    
    def test_calculate_party_center(self, hybrid_config, mock_context):
        """Cover _calculate_party_center."""
        tactic = HybridTactics(config=hybrid_config)
        
        member1 = Mock()
        member1.position = Position(x=40, y=40)
        member2 = Mock()
        member2.position = Position(x=60, y=60)
        
        mock_context.party_members = [member1, member2]
        
        result = tactic._calculate_party_center(mock_context)
        
        assert result is not None
        assert result.x == 50
        assert result.y == 50
    
    def test_calculate_threat_center(self, hybrid_config, mock_context):
        """Cover _calculate_threat_center."""
        tactic = HybridTactics(config=hybrid_config)
        
        monster1 = Mock()
        monster1.position = Position(x=40, y=40)
        monster2 = Mock()
        monster2.position = Position(x=60, y=60)
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        result = tactic._calculate_threat_center(mock_context)
        
        assert result is not None
        assert result.x == 50
        assert result.y == 50


class TestHybridThreatAssessment:
    """Test hybrid threat assessment."""
    
    def test_get_threat_assessment_tank_mode(self, hybrid_config, mock_context, mock_monster):
        """Cover get_threat_assessment in tank mode."""
        tactic = HybridTactics(config=hybrid_config)
        tactic._active_role.current_role = "tank"
        
        mock_context.character_hp = 300
        mock_context.character_hp_max = 1000
        mock_monster.position = Position(x=52, y=52)
        mock_context.nearby_monsters = [mock_monster]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert 0.0 <= threat <= 1.0
    
    def test_get_threat_assessment_low_hp(self, hybrid_config, mock_context):
        """Cover threat assessment at low HP."""
        tactic = HybridTactics(config=hybrid_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.3
    
    def test_get_threat_assessment_party_emergency(self, hybrid_config, mock_context):
        """Cover threat assessment with party emergency."""
        tactic = HybridTactics(config=hybrid_config)
        
        member = Mock()
        member.hp = 200
        member.hp_max = 1000
        mock_context.party_members = [member]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.0


class TestHybridHelpers:
    """Test hybrid helper methods."""
    
    def test_get_position_x_from_position_object(self, hybrid_config):
        """Cover _get_position_x with Position object."""
        tactic = HybridTactics(config=hybrid_config)
        
        pos = Position(x=100, y=200)
        
        result = tactic._get_position_x(pos)
        
        assert result == 100
    
    def test_get_position_x_from_tuple(self, hybrid_config):
        """Cover _get_position_x with tuple."""
        tactic = HybridTactics(config=hybrid_config)
        
        result = tactic._get_position_x((100, 200))
        
        assert result == 100
    
    def test_get_position_y_from_position_object(self, hybrid_config):
        """Cover _get_position_y with Position object."""
        tactic = HybridTactics(config=hybrid_config)
        
        pos = Position(x=100, y=200)
        
        result = tactic._get_position_y(pos)
        
        assert result == 200
    
    def test_get_ally_hp_percent(self, hybrid_config):
        """Cover _get_ally_hp_percent."""
        tactic = HybridTactics(config=hybrid_config)
        
        ally = Mock()
        ally.hp = 500
        ally.hp_max = 1000
        
        result = tactic._get_ally_hp_percent(ally)
        
        assert result == 0.5
    
    def test_get_ally_id(self, hybrid_config):
        """Cover _get_ally_id."""
        tactic = HybridTactics(config=hybrid_config)
        
        ally = Mock()
        ally.actor_id = 2001
        
        result = tactic._get_ally_id(ally)
        
        assert result == 2001
    
    def test_get_ally_distance(self, hybrid_config, mock_context):
        """Cover _get_ally_distance."""
        tactic = HybridTactics(config=hybrid_config)
        
        ally = Mock()
        ally.position = Position(x=55, y=55)
        
        result = tactic._get_ally_distance(mock_context, ally)
        
        assert result > 0
    
    def test_calculate_intercept_position(self, hybrid_config):
        """Cover _calculate_intercept_position."""
        tactic = HybridTactics(config=hybrid_config)
        
        party = Position(x=40, y=40)
        threat = Position(x=60, y=60)
        
        result = tactic._calculate_intercept_position(party, threat)
        
        assert result is not None
        assert isinstance(result, Position)
    
    def test_calculate_safe_position(self, hybrid_config):
        """Cover _calculate_safe_position."""
        tactic = HybridTactics(config=hybrid_config)
        
        party = Position(x=50, y=50)
        threat = Position(x=60, y=60)
        
        result = tactic._calculate_safe_position(party, threat)
        
        assert result is not None
    
    def test_move_toward(self, hybrid_config):
        """Cover _move_toward."""
        tactic = HybridTactics(config=hybrid_config)
        
        current = Position(x=50, y=50)
        target = Position(x=60, y=60)
        
        result = tactic._move_toward(current, target, 5)
        
        assert result is not None
        assert isinstance(result, Position)
    
    def test_get_skill_id(self, hybrid_config):
        """Cover _get_skill_id."""
        tactic = HybridTactics(config=hybrid_config)
        
        skill_id = tactic._get_skill_id("grand_cross")
        
        assert skill_id == 254
    
    def test_get_sp_cost(self, hybrid_config):
        """Cover _get_sp_cost."""
        tactic = HybridTactics(config=hybrid_config)
        
        cost = tactic._get_sp_cost("grand_cross")
        
        assert cost == 37
    
    def test_get_skill_range(self, hybrid_config):
        """Cover _get_skill_range."""
        tactic = HybridTactics(config=hybrid_config)
        
        range_val = tactic._get_skill_range("grand_cross")
        
        assert range_val == 3


# =============================================================================
# Support Tactics Tests
# =============================================================================

class TestSupportTacticsCore:
    """Test support tactics initialization and core behavior."""
    
    def test_support_tactics_initialization_default(self):
        """Cover SupportTactics initialization with defaults."""
        tactic = SupportTactics()
        
        assert tactic is not None
        assert tactic.role == TacticalRole.SUPPORT
        assert tactic._buff_timers == {}
        assert tactic._heal_priority_queue == []
    
    def test_support_tactics_initialization_custom_config(self, support_config):
        """Cover SupportTactics with custom configuration."""
        tactic = SupportTactics(config=support_config)
        
        assert tactic.support_config == support_config
        assert tactic.support_config.heal_trigger_threshold == 0.80
        assert tactic.support_config.emergency_heal_threshold == 0.35
    
    def test_support_skill_constants(self):
        """Cover support skill constant lists."""
        tactic = SupportTactics()
        
        assert "heal" in tactic.REGULAR_HEALS
        assert "sanctuary" in tactic.EMERGENCY_HEALS
        assert "blessing" in tactic.PARTY_BUFFS
        assert "kyrie_eleison" in tactic.DEFENSIVE_BUFFS


class TestSupportTargetSelection:
    """Test support target selection."""
    
    @pytest.mark.asyncio
    async def test_select_target_healing_priority(self, support_config, mock_context, mock_party_member):
        """Cover select_target prioritizing healing."""
        tactic = SupportTactics(config=support_config)
        
        mock_party_member.hp = 300
        mock_party_member.hp_max = 1000
        mock_context.party_members = [mock_party_member]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
        assert result.reason == "heal_needed"
    
    @pytest.mark.asyncio
    async def test_select_target_buff_priority(self, support_config, mock_context, mock_party_member):
        """Cover select_target for buffing."""
        tactic = SupportTactics(config=support_config)
        
        mock_party_member.hp = 900
        mock_party_member.hp_max = 1000
        mock_context.party_members = [mock_party_member]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_select_target_offensive_solo(self, support_config, mock_context, mock_monster):
        """Cover select_target for offensive in solo mode."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.nearby_monsters = [mock_monster]
        mock_context.party_members = []
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
    
    def test_find_healing_target_self(self, support_config, mock_context):
        """Cover _find_healing_target prioritizing self."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_hp = 500
        mock_context.character_hp_max = 1000
        
        result = tactic._find_healing_target(mock_context)
        
        assert result is not None
        assert result.reason == "self_heal"
    
    def test_find_healing_target_emergency(self, support_config, mock_context):
        """Cover _find_healing_target with emergency."""
        tactic = SupportTactics(config=support_config)
        
        member = Mock()
        member.actor_id = 2001
        member.hp = 200
        member.hp_max = 1000
        member.position = Position(x=48, y=48)
        
        mock_context.party_members = [member]
        
        result = tactic._find_healing_target(mock_context)
        
        assert result is not None
        assert result.priority_score > 100
    
    def test_find_buff_target(self, support_config, mock_context, mock_party_member):
        """Cover _find_buff_target."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.party_members = [mock_party_member]
        
        result = tactic._find_buff_target(mock_context)
        
        assert result is not None
        assert result.reason == "buff_needed"
    
    def test_find_offensive_target(self, support_config, mock_context, mock_monster):
        """Cover _find_offensive_target."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = tactic._find_offensive_target(mock_context)
        
        assert result is not None
    
    def test_is_ally_target_self(self, support_config, mock_context):
        """Cover _is_ally_target for self."""
        tactic = SupportTactics(config=support_config)
        
        result = tactic._is_ally_target(mock_context, 0)
        
        assert result is True
    
    def test_is_ally_target_party_member(self, support_config, mock_context, mock_party_member):
        """Cover _is_ally_target for party member."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.party_members = [mock_party_member]
        
        result = tactic._is_ally_target(mock_context, mock_party_member.actor_id)
        
        assert result is True


class TestSupportSkillSelection:
    """Test support skill selection."""
    
    @pytest.mark.asyncio
    async def test_select_skill_self_heal_priority(self, support_config, mock_context):
        """Cover select_skill prioritizing self heal."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="target",
            distance=5,
            hp_percent=0.5
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
        assert skill.name in tactic.EMERGENCY_HEALS
    
    @pytest.mark.asyncio
    async def test_select_skill_emergency_heal(self, support_config, mock_context):
        """Cover select_skill emergency heal for ally."""
        tactic = SupportTactics(config=support_config)
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=150,
            reason="heal_needed",
            distance=5,
            hp_percent=0.3
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_buff(self, support_config, mock_context):
        """Cover select_skill defensive buff."""
        tactic = SupportTactics(config=support_config)
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="heal_needed",
            distance=5,
            hp_percent=0.6
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_offensive(self, support_config, mock_context):
        """Cover select_skill offensive for enemy."""
        tactic = SupportTactics(config=support_config)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=50,
            reason="target",
            distance=7,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    def test_select_emergency_heal(self, support_config, mock_context):
        """Cover _select_emergency_heal."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_emergency_heal(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.EMERGENCY_HEALS
    
    def test_select_heal_skill_emergency(self, support_config, mock_context):
        """Cover _select_heal_skill with emergency flag."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_heal_skill(mock_context, is_emergency=True)
        
        assert skill is not None
        assert skill.level == 10
    
    def test_select_heal_skill_regular(self, support_config, mock_context):
        """Cover _select_heal_skill regular."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_heal_skill(mock_context, is_emergency=False)
        
        assert skill is not None
        assert skill.level == 6
    
    def test_select_defensive_buff(self, support_config, mock_context):
        """Cover _select_defensive_buff."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_defensive_buff(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.DEFENSIVE_BUFFS
    
    def test_select_party_buff(self, support_config, mock_context):
        """Cover _select_party_buff."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_party_buff(mock_context, 2001)
        
        assert skill is not None
        assert skill.name in tactic.PARTY_BUFFS
    
    def test_select_offensive_skill(self, support_config, mock_context):
        """Cover _select_offensive_skill."""
        tactic = SupportTactics(config=support_config)
        
        skill = tactic._select_offensive_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.OFFENSIVE_SKILLS
        assert skill.is_offensive is True
    
    def test_needs_self_heal_true(self, support_config, mock_context):
        """Cover _needs_self_heal returning true."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        result = tactic._needs_self_heal(mock_context)
        
        assert result is True
    
    def test_needs_self_heal_false(self, support_config, mock_context):
        """Cover _needs_self_heal returning false."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_hp = 500
        mock_context.character_hp_max = 1000
        
        result = tactic._needs_self_heal(mock_context)
        
        assert result is False


class TestSupportPositioning:
    """Test support positioning logic."""
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_with_party_and_threats(self, support_config, mock_context, mock_monster):
        """Cover evaluate_positioning with party and threats."""
        tactic = SupportTactics(config=support_config)
        
        member = Mock()
        member.position = Position(x=45, y=45)
        mock_context.party_members = [member]
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_solo_with_threats(self, support_config, mock_context, mock_monster):
        """Cover evaluate_positioning solo mode."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_move_to_party(self, support_config, mock_context):
        """Cover evaluate_positioning moving toward party."""
        tactic = SupportTactics(config=support_config)
        
        member = Mock()
        member.position = Position(x=100, y=100)
        mock_context.party_members = [member]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    def test_calculate_party_center(self, support_config, mock_context):
        """Cover _calculate_party_center."""
        tactic = SupportTactics(config=support_config)
        
        member1 = Mock()
        member1.position = Position(x=40, y=40)
        member2 = Mock()
        member2.position = Position(x=60, y=60)
        
        mock_context.party_members = [member1, member2]
        
        result = tactic._calculate_party_center(mock_context)
        
        assert result is not None
        assert result.x == 50
        assert result.y == 50
    
    def test_calculate_threat_center(self, support_config, mock_context):
        """Cover _calculate_threat_center."""
        tactic = SupportTactics(config=support_config)
        
        monster1 = Mock()
        monster1.position = Position(x=40, y=40)
        monster2 = Mock()
        monster2.position = Position(x=60, y=60)
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        result = tactic._calculate_threat_center(mock_context)
        
        assert result is not None
    
    def test_calculate_safe_position(self, support_config):
        """Cover _calculate_safe_position."""
        tactic = SupportTactics(config=support_config)
        
        current = Position(x=50, y=50)
        threat = Position(x=60, y=60)
        
        result = tactic._calculate_safe_position(current, threat)
        
        assert result is not None
    
    def test_calculate_support_position(self, support_config):
        """Cover _calculate_support_position."""
        tactic = SupportTactics(config=support_config)
        
        party_center = Position(x=50, y=50)
        threat_center = Position(x=60, y=60)
        
        result = tactic._calculate_support_position(party_center, threat_center)
        
        assert result is not None
    
    def test_move_toward(self, support_config):
        """Cover _move_toward."""
        tactic = SupportTactics(config=support_config)
        
        current = Position(x=50, y=50)
        target = Position(x=60, y=60)
        
        result = tactic._move_toward(current, target, 5)
        
        assert result is not None


class TestSupportThreatAssessment:
    """Test support threat assessment."""
    
    def test_get_threat_assessment_low_hp(self, support_config, mock_context):
        """Cover threat assessment at low HP."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.3
    
    def test_get_threat_assessment_low_sp(self, support_config, mock_context):
        """Cover threat assessment at low SP."""
        tactic = SupportTactics(config=support_config)
        
        mock_context.character_sp = 30
        mock_context.character_sp_max = 300
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.2
    
    def test_get_threat_assessment_party_emergency(self, support_config, mock_context):
        """Cover threat assessment with party emergencies."""
        tactic = SupportTactics(config=support_config)
        
        member1 = Mock()
        member1.hp = 200
        member1.hp_max = 1000
        
        member2 = Mock()
        member2.hp = 250
        member2.hp_max = 1000
        
        mock_context.party_members = [member1, member2]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.1
    
    def test_get_threat_assessment_close_enemies(self, support_config, mock_context):
        """Cover threat assessment with close enemies."""
        tactic = SupportTactics(config=support_config)
        
        monster = Mock()
        monster.position = Position(x=52, y=52)
        mock_context.nearby_monsters = [monster]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.0


class TestSupportHelpers:
    """Test support helper methods."""
    
    def test_get_ally_hp_percent(self, support_config):
        """Cover _get_ally_hp_percent."""
        tactic = SupportTactics(config=support_config)
        
        ally = Mock()
        ally.hp = 500
        ally.hp_max = 1000
        
        result = tactic._get_ally_hp_percent(ally)
        
        assert result == 0.5
    
    def test_get_ally_id(self, support_config):
        """Cover _get_ally_id."""
        tactic = SupportTactics(config=support_config)
        
        ally = Mock()
        ally.actor_id = 2001
        
        result = tactic._get_ally_id(ally)
        
        assert result == 2001
    
    def test_get_ally_distance(self, support_config, mock_context):
        """Cover _get_ally_distance."""
        tactic = SupportTactics(config=support_config)
        
        ally = Mock()
        ally.position = Position(x=55, y=55)
        
        result = tactic._get_ally_distance(mock_context, ally)
        
        assert result > 0
    
    def test_needs_buff(self, support_config):
        """Cover _needs_buff."""
        tactic = SupportTactics(config=support_config)
        
        result = tactic._needs_buff(2001)
        
        assert result is True
    
    def test_get_skill_id(self, support_config):
        """Cover _get_skill_id."""
        tactic = SupportTactics(config=support_config)
        
        skill_id = tactic._get_skill_id("heal")
        
        assert skill_id == 28
    
    def test_get_sp_cost(self, support_config):
        """Cover _get_sp_cost."""
        tactic = SupportTactics(config=support_config)
        
        cost = tactic._get_sp_cost("heal")
        
        assert cost == 13


# =============================================================================
# Ranged DPS Tactics Tests
# =============================================================================

class TestRangedDPSTacticsCore:
    """Test ranged DPS tactics initialization and core behavior."""
    
    def test_ranged_dps_tactics_initialization_default(self):
        """Cover RangedDPSTactics initialization with defaults."""
        tactic = RangedDPSTactics()
        
        assert tactic is not None
        assert tactic.role == TacticalRole.RANGED_DPS
        assert tactic._deployed_traps == []
        assert tactic._kiting_direction == (0, 0)
    
    def test_ranged_dps_tactics_initialization_custom_config(self, ranged_config):
        """Cover RangedDPSTactics with custom configuration."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        assert tactic.ranged_config == ranged_config
        assert tactic.ranged_config.optimal_range == 9
        assert tactic.ranged_config.min_safe_distance == 4
    
    def test_ranged_skill_constants(self):
        """Cover ranged skill constant lists."""
        tactic = RangedDPSTactics()
        
        assert "double_strafe" in tactic.PRIMARY_SKILLS
        assert "double_strafe" in tactic.SINGLE_TARGET_SKILLS
        assert "arrow_shower" in tactic.AOE_SKILLS
        assert "ankle_snare" in tactic.TRAP_SKILLS


class TestRangedTargetSelection:
    """Test ranged target selection."""
    
    @pytest.mark.asyncio
    async def test_select_target_optimal_range(self, ranged_config, mock_context, mock_monster):
        """Cover select_target prioritizing optimal range."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        mock_monster.position = Position(x=56, y=56)
        mock_context.nearby_monsters = [mock_monster]
        
        result = await tactic.select_target(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, ranged_config, mock_context):
        """Cover select_target with no monsters."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        result = await tactic.select_target(mock_context)
        
        assert result is None
    
    def test_ranged_target_score_optimal_range(self, ranged_config):
        """Cover _ranged_target_score at optimal range."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = Mock()
        target.is_mvp = False
        target.is_boss = False
        
        score = tactic._ranged_target_score(target, 0.5, 7)
        
        assert score > 100
    
    def test_ranged_target_score_too_close(self, ranged_config):
        """Cover _ranged_target_score penalty for close range."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = Mock()
        target.is_mvp = False
        target.is_boss = False
        
        score = tactic._ranged_target_score(target, 0.5, 2)
        
        assert score < 100
    
    def test_ranged_target_score_mvp_bonus(self, ranged_config):
        """Cover _ranged_target_score MVP bonus."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = Mock()
        target.is_mvp = True
        target.is_boss = False
        
        score = tactic._ranged_target_score(target, 0.8, 7)
        
        assert score > 140


class TestRangedSkillSelection:
    """Test ranged skill selection."""
    
    @pytest.mark.asyncio
    async def test_select_skill_buff_priority(self, ranged_config, mock_context):
        """Cover select_skill prioritizing buffs."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=7,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_trap_for_close_enemy(self, ranged_config, mock_context):
        """Cover select_skill deploying trap for close enemy."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=2,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_for_clusters(self, mock_context):
        """Cover select_skill using AoE for clusters."""
        config = RangedDPSTacticsConfig(prefer_single_target=False)
        tactic = RangedDPSTactics(config=config)
        
        # Create clustered monsters with tuple positions
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.position = (55, 55)
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.position = (56, 56)
        
        monster3 = Mock()
        monster3.actor_id = 1003
        monster3.position = (57, 57)
        
        mock_context.nearby_monsters = [monster1, monster2, monster3]
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=7,
            hp_percent=0.8
        )
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_single_target_damage(self, ranged_config, mock_context):
        """Cover select_skill single target damage."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=7,
            hp_percent=0.8
        )
        
        # Clear buffs to skip buff selection
        tactic.BUFF_SKILLS = []
        
        skill = await tactic.select_skill(mock_context, target)
        
        assert skill is not None
    
    def test_select_buff_skill(self, ranged_config, mock_context):
        """Cover _select_buff_skill."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        skill = tactic._select_buff_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.BUFF_SKILLS
    
    def test_select_trap_skill(self, ranged_config, mock_context):
        """Cover _select_trap_skill."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        skill = tactic._select_trap_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.TRAP_SKILLS
    
    def test_select_trap_skill_disabled(self, mock_context):
        """Cover _select_trap_skill when traps disabled."""
        config = RangedDPSTacticsConfig(use_traps=False)
        tactic = RangedDPSTactics(config=config)
        
        skill = tactic._select_trap_skill(mock_context)
        
        assert skill is None
    
    def test_select_aoe_skill(self, ranged_config, mock_context):
        """Cover _select_aoe_skill."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        skill = tactic._select_aoe_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.AOE_SKILLS
    
    def test_select_damage_skill(self, ranged_config, mock_context):
        """Cover _select_damage_skill."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        skill = tactic._select_damage_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactic.SINGLE_TARGET_SKILLS
    
    def test_count_clustered_enemies(self, ranged_config, mock_context):
        """Cover _count_clustered_enemies."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.position = (55, 55)
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.position = (56, 56)
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="target",
            distance=5,
            hp_percent=0.8
        )
        
        count = tactic._count_clustered_enemies(mock_context, target)
        
        assert count >= 1


class TestRangedPositioning:
    """Test ranged positioning and kiting logic."""
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_kite_away(self, ranged_config, mock_context):
        """Cover evaluate_positioning kiting away."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        monster = Mock()
        monster.position = (52, 52)
        mock_context.nearby_monsters = [monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_move_closer(self, ranged_config, mock_context):
        """Cover evaluate_positioning moving closer."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        monster = Mock()
        monster.position = (70, 70)
        mock_context.nearby_monsters = [monster]
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self, ranged_config, mock_context):
        """Cover evaluate_positioning with no monsters."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        result = await tactic.evaluate_positioning(mock_context)
        
        assert result is None
    
    def test_calculate_kite_position(self, ranged_config):
        """Cover _calculate_kite_position."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        current = Position(x=50, y=50)
        threat = Position(x=55, y=55)
        
        result = tactic._calculate_kite_position(current, threat)
        
        assert result is not None
        # Should move away from threat
        assert result.x < 50 or result.y < 50
    
    def test_calculate_approach_position(self, ranged_config):
        """Cover _calculate_approach_position."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        current = Position(x=50, y=50)
        target = Position(x=70, y=70)
        
        result = tactic._calculate_approach_position(current, target)
        
        assert result is not None
    
    def test_is_surrounded_true(self, ranged_config, mock_context):
        """Cover _is_surrounded returning true."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        # Create enemies in different quadrants
        monster1 = Mock()
        monster1.position = (52, 52)
        
        monster2 = Mock()
        monster2.position = (52, 48)
        
        monster3 = Mock()
        monster3.position = (48, 48)
        
        mock_context.nearby_monsters = [monster1, monster2, monster3]
        
        result = tactic._is_surrounded(mock_context)
        
        assert result is True
    
    def test_is_surrounded_false(self, ranged_config, mock_context):
        """Cover _is_surrounded returning false."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        monster = Mock()
        monster.position = (52, 52)
        
        mock_context.nearby_monsters = [monster]
        
        result = tactic._is_surrounded(mock_context)
        
        assert result is False


class TestRangedThreatAssessment:
    """Test ranged threat assessment."""
    
    def test_get_threat_assessment_low_hp(self, ranged_config, mock_context):
        """Cover threat assessment at low HP."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        mock_context.character_hp = 200
        mock_context.character_hp_max = 1000
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.4
    
    def test_get_threat_assessment_too_close(self, ranged_config, mock_context):
        """Cover threat assessment with enemies too close."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        monster = Mock()
        monster.position = (52, 52)
        mock_context.nearby_monsters = [monster]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.0
    
    def test_get_threat_assessment_surrounded(self, ranged_config, mock_context):
        """Cover threat assessment when surrounded."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        # Create surrounding enemies
        monster1 = Mock()
        monster1.position = (52, 52)
        
        monster2 = Mock()
        monster2.position = (52, 48)
        
        monster3 = Mock()
        monster3.position = (48, 48)
        
        mock_context.nearby_monsters = [monster1, monster2, monster3]
        
        threat = tactic.get_threat_assessment(mock_context)
        
        assert threat > 0.5


class TestRangedHelpers:
    """Test ranged DPS helper methods."""
    
    def test_get_skill_id(self, ranged_config):
        """Cover _get_skill_id."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        skill_id = tactic._get_skill_id("double_strafe")
        
        assert skill_id == 46
    
    def test_get_sp_cost(self, ranged_config):
        """Cover _get_sp_cost."""
        tactic = RangedDPSTactics(config=ranged_config)
        
        cost = tactic._get_sp_cost("double_strafe")
        
        assert cost == 12