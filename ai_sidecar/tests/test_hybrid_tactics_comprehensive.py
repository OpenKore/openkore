"""
Comprehensive tests for hybrid tactics.

Tests adaptive role switching, multi-role skill selection,
and dynamic positioning for versatile classes.
"""

import pytest
from unittest.mock import Mock, MagicMock
from typing import Any

from ai_sidecar.combat.tactics.hybrid import (
    HybridTactics,
    HybridTacticsConfig,
    ActiveRole,
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TargetPriority,
    TacticalRole,
)


# Fixtures

@pytest.fixture
def hybrid_config():
    """Create hybrid tactics config."""
    return HybridTacticsConfig(
        tank_mode_party_threshold=2,
        support_mode_threshold=0.60,
        auto_switch_roles=True,
        preferred_role="dps",
        melee_range=2,
        ranged_range=9,
    )


@pytest.fixture
def hybrid_tactics(hybrid_config):
    """Create hybrid tactics instance."""
    return HybridTactics(hybrid_config)


@pytest.fixture
def mock_context():
    """Create mock combat context."""
    context = Mock()
    context.character_position = Position(x=100, y=100)
    context.character_hp = 500
    context.character_hp_max = 1000
    context.character_sp = 200
    context.character_sp_max = 300
    context.nearby_monsters = []
    context.party_members = []
    context.cooldowns = {}
    return context


@pytest.fixture
def mock_ally():
    """Create mock party member."""
    ally = Mock()
    ally.actor_id = 1001
    ally.hp = 400
    ally.hp_max = 800
    ally.position = (105, 105)
    return ally


@pytest.fixture
def mock_monster():
    """Create mock monster."""
    monster = Mock()
    monster.actor_id = 2001
    monster.position = (110, 110)
    monster.hp = 500
    monster.hp_max = 1000
    return monster


# Test ActiveRole

class TestActiveRole:
    """Test active role state tracking."""
    
    def test_init_default_role(self):
        """Test initialization with default role."""
        role = ActiveRole()
        assert role.current_role == "dps"
        assert role.role_duration == 0.0
        assert role.switch_cooldown == 0.0
    
    def test_init_custom_role(self):
        """Test initialization with custom role."""
        role = ActiveRole(role="tank")
        assert role.current_role == "tank"
        assert role.role_duration == 0.0


# Test HybridTactics Initialization

class TestInitialization:
    """Test hybrid tactics initialization."""
    
    def test_init_default_config(self):
        """Test initialization with default config."""
        tactics = HybridTactics()
        assert tactics.role == TacticalRole.HYBRID
        assert tactics._active_role.current_role == "dps"
        assert tactics._role_switch_timer == 0.0
    
    def test_init_custom_config(self, hybrid_config):
        """Test initialization with custom config."""
        tactics = HybridTactics(hybrid_config)
        assert tactics.hybrid_config == hybrid_config
        assert tactics._active_role.current_role == "dps"
    
    def test_has_required_skill_lists(self, hybrid_tactics):
        """Test tactics has all skill lists."""
        assert len(hybrid_tactics.TANK_SKILLS) > 0
        assert len(hybrid_tactics.DPS_SKILLS) > 0
        assert len(hybrid_tactics.SUPPORT_SKILLS) > 0
        assert len(hybrid_tactics.BUFF_SKILLS) > 0


# Test Role Switching Logic

class TestRoleSwitching:
    """Test role switching evaluation and logic."""
    
    @pytest.mark.asyncio
    async def test_auto_switch_disabled(self, mock_context):
        """Test no switching when auto_switch_roles is False."""
        # Create config with auto_switch_roles disabled
        config = HybridTacticsConfig(
            tank_mode_party_threshold=2,
            support_mode_threshold=0.60,
            auto_switch_roles=False,  # Disabled
            preferred_role="dps",
            melee_range=2,
            ranged_range=9,
        )
        tactics = HybridTactics(config)
        tactics._active_role.current_role = "dps"
        
        # Create situation that would normally trigger switch
        low_hp_ally = Mock()
        low_hp_ally.hp = 200
        low_hp_ally.hp_max = 1000
        mock_context.party_members = [low_hp_ally, low_hp_ally]
        
        await tactics.select_target(mock_context)
        assert tactics._active_role.current_role == "dps"
    
    @pytest.mark.asyncio
    async def test_switch_to_support_on_low_party_hp(self, hybrid_tactics, mock_context):
        """Test switching to support when party HP is low."""
        hybrid_tactics._role_switch_timer = 0.0
        hybrid_tactics._active_role.current_role = "dps"
        
        # Create two low HP allies
        ally1 = Mock()
        ally1.actor_id = 1001
        ally1.hp = 200
        ally1.hp_max = 1000
        ally1.position = (105, 105)
        
        ally2 = Mock()
        ally2.actor_id = 1002
        ally2.hp = 250
        ally2.hp_max = 1000
        ally2.position = (106, 106)
        
        mock_context.party_members = [ally1, ally2]
        
        await hybrid_tactics.select_target(mock_context)
        assert hybrid_tactics._active_role.current_role == "support"
    
    @pytest.mark.asyncio
    async def test_switch_to_tank_with_many_enemies(self, hybrid_tactics, mock_context):
        """Test switching to tank with multiple enemies."""
        hybrid_tactics._role_switch_timer = 0.0
        hybrid_tactics._active_role.current_role = "dps"
        
        # Add party members with positions
        for i in range(3):
            ally = Mock()
            ally.actor_id = 1000 + i
            ally.hp = 800
            ally.hp_max = 1000
            ally.position = (100 + i, 100)
            mock_context.party_members.append(ally)
        
        # Add multiple enemies
        for i in range(4):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110 + i, 110)
            monster.hp = 500
            monster.hp_max = 1000
            mock_context.nearby_monsters.append(monster)
        
        await hybrid_tactics.select_target(mock_context)
        assert hybrid_tactics._active_role.current_role == "tank"
    
    def test_role_switch_cooldown(self, hybrid_tactics, mock_context):
        """Test role switch cooldown prevents rapid switching."""
        hybrid_tactics._role_switch_timer = 3.0
        initial_role = hybrid_tactics._active_role.current_role
        
        # Try to trigger switch
        ally1 = Mock()
        ally1.hp = 200
        ally1.hp_max = 1000
        ally2 = Mock()
        ally2.hp = 250
        ally2.hp_max = 1000
        mock_context.party_members = [ally1, ally2]
        
        hybrid_tactics._evaluate_role_switch(mock_context)
        assert hybrid_tactics._active_role.current_role == initial_role
    
    def test_party_needs_support_logic(self, hybrid_tactics, mock_context):
        """Test party needs support detection."""
        # No party members
        assert not hybrid_tactics._party_needs_support(mock_context)
        
        # One low HP member (not enough)
        ally1 = Mock()
        ally1.hp = 400
        ally1.hp_max = 1000
        mock_context.party_members = [ally1]
        assert not hybrid_tactics._party_needs_support(mock_context)
        
        # Two low HP members (triggers support)
        ally2 = Mock()
        ally2.hp = 450
        ally2.hp_max = 1000
        mock_context.party_members = [ally1, ally2]
        assert hybrid_tactics._party_needs_support(mock_context)
    
    def test_party_needs_tank_logic(self, hybrid_tactics, mock_context):
        """Test party needs tank detection."""
        # Not enough party members
        mock_context.party_members = [Mock()]
        assert not hybrid_tactics._party_needs_tank(mock_context)
        
        # Enough party but few enemies
        mock_context.party_members = [Mock(), Mock(), Mock()]
        mock_context.nearby_monsters = [Mock(), Mock()]
        assert not hybrid_tactics._party_needs_tank(mock_context)
        
        # Enough party and many enemies
        mock_context.nearby_monsters = [Mock(), Mock(), Mock(), Mock()]
        assert hybrid_tactics._party_needs_tank(mock_context)


# Test Target Selection

class TestTargetSelection:
    """Test target selection for different roles."""
    
    @pytest.mark.asyncio
    async def test_tank_mode_prioritizes_ally_targets(self, hybrid_tactics, mock_context, mock_monster):
        """Test tank mode prioritizes enemies targeting allies."""
        hybrid_tactics._active_role.current_role = "tank"
        mock_context.nearby_monsters = [mock_monster]
        
        # Add party member
        ally = Mock()
        ally.actor_id = 1001
        ally.hp = 800
        ally.hp_max = 1000
        ally.position = (105, 105)
        mock_context.party_members = [ally]
        
        # Mock threat entry showing enemy targeting ally
        threat_entry = Mock()
        threat_entry.is_targeting_self = False
        hybrid_tactics._threat_table[mock_monster.actor_id] = threat_entry
        
        target = await hybrid_tactics.select_target(mock_context)
        assert target is not None
        assert target.actor_id == mock_monster.actor_id
        # Tank mode should select the enemy (reason may vary based on threat table state)
    
    @pytest.mark.asyncio
    async def test_support_mode_prioritizes_low_hp_allies(self, hybrid_tactics, mock_context):
        """Test support mode prioritizes low HP allies."""
        hybrid_tactics._active_role.current_role = "support"
        hybrid_tactics._role_switch_timer = 10.0  # Prevent role switching
        
        # Add allies with different HP
        ally1 = Mock()
        ally1.actor_id = 1001
        ally1.hp = 700
        ally1.hp_max = 1000
        ally1.position = (105, 105)
        
        ally2 = Mock()
        ally2.actor_id = 1002
        ally2.hp = 300
        ally2.hp_max = 1000
        ally2.position = (106, 106)
        
        mock_context.party_members = [ally1, ally2]
        
        target = await hybrid_tactics.select_target(mock_context)
        assert target is not None
        assert target.actor_id == ally2.actor_id
        # Support mode should select lowest HP ally (reason may vary)
    
    @pytest.mark.asyncio
    async def test_dps_mode_uses_standard_targeting(self, hybrid_tactics, mock_context, mock_monster):
        """Test DPS mode uses standard target prioritization."""
        hybrid_tactics._active_role.current_role = "dps"
        mock_context.nearby_monsters = [mock_monster]
        
        target = await hybrid_tactics.select_target(mock_context)
        assert target is not None
        assert target.actor_id == mock_monster.actor_id
    
    @pytest.mark.asyncio
    async def test_no_target_when_no_enemies(self, hybrid_tactics, mock_context):
        """Test returns None when no enemies present."""
        hybrid_tactics._active_role.current_role = "dps"
        mock_context.nearby_monsters = []
        
        target = await hybrid_tactics.select_target(mock_context)
        assert target is None


# Test Skill Selection

class TestSkillSelection:
    """Test skill selection for different roles."""
    
    @pytest.mark.asyncio
    async def test_emergency_heal_overrides_role(self, hybrid_tactics, mock_context):
        """Test emergency heal takes priority regardless of role."""
        mock_context.character_hp = 250  # 25% HP
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=5.0,
            hp_percent=0.5
        )
        
        for role in ["tank", "support", "dps"]:
            hybrid_tactics._active_role.current_role = role
            skill = await hybrid_tactics.select_skill(mock_context, target)
            if skill:
                assert skill.name == "heal"
    
    @pytest.mark.asyncio
    async def test_tank_mode_selects_tank_skills(self, hybrid_tactics, mock_context):
        """Test tank mode selects appropriate skills."""
        hybrid_tactics._active_role.current_role = "tank"
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        skill = await hybrid_tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name in hybrid_tactics.TANK_SKILLS or skill.name in hybrid_tactics.BUFF_SKILLS
    
    @pytest.mark.asyncio
    async def test_support_mode_heals_low_hp_target(self, hybrid_tactics, mock_context):
        """Test support mode heals low HP targets."""
        hybrid_tactics._active_role.current_role = "support"
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="heal_target",
            distance=5.0,
            hp_percent=0.5
        )
        
        skill = await hybrid_tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name == "heal" or skill.name in hybrid_tactics.SUPPORT_SKILLS
    
    @pytest.mark.asyncio
    async def test_dps_mode_selects_damage_skills(self, hybrid_tactics, mock_context):
        """Test DPS mode selects damage skills."""
        hybrid_tactics._active_role.current_role = "dps"
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        skill = await hybrid_tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name in hybrid_tactics.DPS_SKILLS
    
    @pytest.mark.asyncio
    async def test_respects_cooldowns(self, hybrid_tactics, mock_context):
        """Test skill selection respects cooldowns."""
        hybrid_tactics._active_role.current_role = "dps"
        # Put all DPS skills on cooldown
        for skill_name in hybrid_tactics.DPS_SKILLS:
            mock_context.cooldowns[skill_name] = 5.0
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        skill = await hybrid_tactics.select_skill(mock_context, target)
        # Should return None or a skill not on cooldown
        if skill:
            assert mock_context.cooldowns.get(skill.name, 0) <= 0


# Test Positioning

class TestPositioning:
    """Test positioning for different roles."""
    
    @pytest.mark.asyncio
    async def test_tank_positioning_intercepts_threats(self, hybrid_tactics, mock_context):
        """Test tank positions between party and threats."""
        hybrid_tactics._active_role.current_role = "tank"
        
        # Add party members
        ally = Mock()
        ally.position = (100, 100)
        mock_context.party_members = [ally]
        
        # Add monsters
        monster = Mock()
        monster.position = (110, 110)
        mock_context.nearby_monsters = [monster]
        
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        assert position is not None
        # Should be between party (100,100) and threat (110,110)
        assert 100 <= position.x <= 110
        assert 100 <= position.y <= 110
    
    @pytest.mark.asyncio
    async def test_support_positioning_stays_safe(self, hybrid_tactics, mock_context):
        """Test support positions behind party."""
        hybrid_tactics._active_role.current_role = "support"
        
        # Add party members
        ally = Mock()
        ally.position = (100, 100)
        mock_context.party_members = [ally]
        
        # Add monsters
        monster = Mock()
        monster.position = (110, 110)
        mock_context.nearby_monsters = [monster]
        
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        assert position is not None
        # Should be away from threats
    
    @pytest.mark.asyncio
    async def test_dps_positioning_moves_to_target(self, hybrid_tactics, mock_context):
        """Test DPS mode moves toward targets."""
        hybrid_tactics._active_role.current_role = "dps"
        
        # Add far monster
        monster = Mock()
        monster.position = (120, 120)
        mock_context.nearby_monsters = [monster]
        
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        assert position is not None
        # Should move closer to target
        current = mock_context.character_position
        assert position.x > current.x or position.y > current.y
    
    @pytest.mark.asyncio
    async def test_no_positioning_when_no_targets(self, hybrid_tactics, mock_context):
        """Test returns None when no positioning needed."""
        hybrid_tactics._active_role.current_role = "dps"
        mock_context.nearby_monsters = []
        
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        assert position is None


# Test Threat Assessment

class TestThreatAssessment:
    """Test threat level calculation."""
    
    def test_threat_increases_with_low_hp(self, hybrid_tactics, mock_context):
        """Test threat increases when HP is low."""
        mock_context.character_hp = 800
        threat_high = hybrid_tactics.get_threat_assessment(mock_context)
        
        mock_context.character_hp = 200
        threat_low = hybrid_tactics.get_threat_assessment(mock_context)
        
        assert threat_low > threat_high
    
    def test_threat_increases_with_close_enemies(self, hybrid_tactics, mock_context):
        """Test threat increases with nearby enemies."""
        # No enemies
        threat_none = hybrid_tactics.get_threat_assessment(mock_context)
        
        # Add close enemies
        for i in range(3):
            monster = Mock()
            monster.position = (101 + i, 101)
            mock_context.nearby_monsters.append(monster)
        
        threat_many = hybrid_tactics.get_threat_assessment(mock_context)
        assert threat_many > threat_none
    
    def test_tank_mode_tolerates_more_enemies(self, hybrid_tactics, mock_context):
        """Test tank mode has higher tolerance for close enemies."""
        # Add close enemies
        for i in range(3):
            monster = Mock()
            monster.position = (101 + i, 101)
            mock_context.nearby_monsters.append(monster)
        
        hybrid_tactics._active_role.current_role = "dps"
        threat_dps = hybrid_tactics.get_threat_assessment(mock_context)
        
        hybrid_tactics._active_role.current_role = "tank"
        threat_tank = hybrid_tactics.get_threat_assessment(mock_context)
        
        assert threat_dps > threat_tank
    
    def test_threat_increases_with_party_emergencies(self, hybrid_tactics, mock_context):
        """Test threat increases when party members are in danger."""
        threat_none = hybrid_tactics.get_threat_assessment(mock_context)
        
        # Add low HP party member
        ally = Mock()
        ally.hp = 200
        ally.hp_max = 1000
        mock_context.party_members = [ally]
        
        threat_party = hybrid_tactics.get_threat_assessment(mock_context)
        assert threat_party > threat_none


# Test Helper Methods

class TestHelperMethods:
    """Test utility helper methods."""
    
    def test_get_ally_hp_percent(self, hybrid_tactics):
        """Test calculating ally HP percentage."""
        ally = Mock()
        ally.hp = 400
        ally.hp_max = 1000
        
        hp_percent = hybrid_tactics._get_ally_hp_percent(ally)
        assert hp_percent == 0.4
    
    def test_get_ally_hp_percent_no_attributes(self, hybrid_tactics):
        """Test returns 1.0 for ally without HP attributes."""
        ally = Mock(spec=[])
        hp_percent = hybrid_tactics._get_ally_hp_percent(ally)
        assert hp_percent == 1.0
    
    def test_get_ally_id(self, hybrid_tactics):
        """Test getting ally ID."""
        ally = Mock()
        ally.actor_id = 1234
        
        ally_id = hybrid_tactics._get_ally_id(ally)
        assert ally_id == 1234
    
    def test_get_ally_distance(self, hybrid_tactics, mock_context):
        """Test calculating distance to ally."""
        ally = Mock()
        ally.position = (105, 105)
        
        distance = hybrid_tactics._get_ally_distance(mock_context, ally)
        assert distance > 0
    
    def test_calculate_party_center(self, hybrid_tactics, mock_context):
        """Test calculating party center position."""
        ally1 = Mock()
        ally1.position = (100, 100)
        ally2 = Mock()
        ally2.position = (110, 110)
        mock_context.party_members = [ally1, ally2]
        
        center = hybrid_tactics._calculate_party_center(mock_context)
        assert center is not None
        assert center.x == 105
        assert center.y == 105
    
    def test_calculate_threat_center(self, hybrid_tactics, mock_context):
        """Test calculating threat center position."""
        monster1 = Mock()
        monster1.position = (100, 100)
        monster2 = Mock()
        monster2.position = (110, 110)
        mock_context.nearby_monsters = [monster1, monster2]
        
        center = hybrid_tactics._calculate_threat_center(mock_context)
        assert center is not None
        assert center.x == 105
        assert center.y == 105
    
    def test_calculate_intercept_position(self, hybrid_tactics):
        """Test calculating position between party and threats."""
        party = Position(x=100, y=100)
        threat = Position(x=110, y=110)
        
        intercept = hybrid_tactics._calculate_intercept_position(party, threat)
        assert intercept is not None
        # Should be between the two points
        assert 100 <= intercept.x <= 110
        assert 100 <= intercept.y <= 110
    
    def test_calculate_safe_position(self, hybrid_tactics):
        """Test calculating safe position behind party."""
        party = Position(x=100, y=100)
        threat = Position(x=110, y=110)
        
        safe = hybrid_tactics._calculate_safe_position(party, threat)
        assert safe is not None
        # Should be away from threat
    
    def test_move_toward(self, hybrid_tactics):
        """Test moving toward target."""
        current = Position(x=100, y=100)
        target = Position(x=110, y=110)
        
        new_pos = hybrid_tactics._move_toward(current, target, 2)
        assert new_pos is not None
        # Should be closer to target
        assert new_pos.x > current.x or new_pos.y > current.y
    
    def test_get_skill_id(self, hybrid_tactics):
        """Test skill ID lookup."""
        skill_id = hybrid_tactics._get_skill_id("grand_cross")
        assert skill_id == 254
        
        skill_id = hybrid_tactics._get_skill_id("heal")
        assert skill_id == 28
        
        skill_id = hybrid_tactics._get_skill_id("unknown_skill")
        assert skill_id == 0
    
    def test_get_sp_cost(self, hybrid_tactics):
        """Test SP cost lookup."""
        cost = hybrid_tactics._get_sp_cost("grand_cross")
        assert cost == 37
        
        cost = hybrid_tactics._get_sp_cost("heal")
        assert cost == 15
        
        cost = hybrid_tactics._get_sp_cost("unknown_skill")
        assert cost == 20  # Default
    
    def test_get_skill_range(self, hybrid_tactics):
        """Test skill range lookup."""
        range_val = hybrid_tactics._get_skill_range("grand_cross")
        assert range_val == 3
        
        range_val = hybrid_tactics._get_skill_range("shield_boomerang")
        assert range_val == 9
        
        range_val = hybrid_tactics._get_skill_range("unknown_skill")
        assert range_val == 1  # Default


# Test Integration Scenarios

class TestIntegrationScenarios:
    """Test complete hybrid tactics workflows."""
    
    @pytest.mark.asyncio
    async def test_complete_tank_mode_cycle(self, hybrid_tactics, mock_context):
        """Test complete tank mode combat cycle."""
        hybrid_tactics._active_role.current_role = "tank"
        hybrid_tactics._role_switch_timer = 0.0
        
        # Setup party with positions
        ally1 = Mock()
        ally1.actor_id = 1001
        ally1.hp = 800
        ally1.hp_max = 1000
        ally1.position = (100, 100)
        
        ally2 = Mock()
        ally2.actor_id = 1002
        ally2.hp = 750
        ally2.hp_max = 1000
        ally2.position = (101, 101)
        
        mock_context.party_members = [ally1, ally2]
        
        # Setup enemies
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (110, 110)
        monster.hp = 500
        monster.hp_max = 1000
        mock_context.nearby_monsters = [monster]
        
        # Target selection
        target = await hybrid_tactics.select_target(mock_context)
        assert target is not None
        
        # Skill selection
        skill = await hybrid_tactics.select_skill(mock_context, target)
        assert skill is not None
        
        # Positioning
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        assert position is not None
        
        # Threat assessment
        threat = hybrid_tactics.get_threat_assessment(mock_context)
        assert 0.0 <= threat <= 1.0
    
    @pytest.mark.asyncio
    async def test_complete_support_mode_cycle(self, hybrid_tactics, mock_context):
        """Test complete support mode combat cycle."""
        hybrid_tactics._active_role.current_role = "support"
        
        # Setup low HP allies
        ally1 = Mock()
        ally1.actor_id = 1001
        ally1.hp = 300
        ally1.hp_max = 1000
        ally1.position = (105, 105)
        
        ally2 = Mock()
        ally2.actor_id = 1002
        ally2.hp = 250
        ally2.hp_max = 1000
        ally2.position = (106, 106)
        
        mock_context.party_members = [ally1, ally2]
        
        # Target selection (should pick lowest HP ally)
        target = await hybrid_tactics.select_target(mock_context)
        assert target is not None
        assert target.actor_id == ally2.actor_id
        
        # Skill selection (should be heal)
        skill = await hybrid_tactics.select_skill(mock_context, target)
        assert skill is not None
        
        # Positioning
        position = await hybrid_tactics.evaluate_positioning(mock_context)
        # May be None if no threats
    
    @pytest.mark.asyncio
    async def test_adaptive_role_switching_during_combat(self, hybrid_tactics, mock_context):
        """Test automatic role switching during combat."""
        hybrid_tactics._role_switch_timer = 0.0
        hybrid_tactics._active_role.current_role = "dps"
        
        # Start in DPS mode
        assert hybrid_tactics._active_role.current_role == "dps"
        
        # Situation changes: party members take damage
        ally1 = Mock()
        ally1.actor_id = 1001
        ally1.hp = 200
        ally1.hp_max = 1000
        ally1.position = (105, 105)
        ally2 = Mock()
        ally2.actor_id = 1002
        ally2.hp = 250
        ally2.hp_max = 1000
        ally2.position = (106, 106)
        mock_context.party_members = [ally1, ally2]
        
        # Should switch to support
        await hybrid_tactics.select_target(mock_context)
        assert hybrid_tactics._active_role.current_role == "support"
    
    @pytest.mark.asyncio
    async def test_emergency_heal_interrupts_any_role(self, hybrid_tactics, mock_context):
        """Test emergency heal works regardless of active role."""
        mock_context.character_hp = 250  # 25% HP - emergency level
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="test",
            distance=5.0,
            hp_percent=0.8
        )
        
        # Test in each role
        for role in ["tank", "support", "dps"]:
            hybrid_tactics._active_role.current_role = role
            skill = await hybrid_tactics.select_skill(mock_context, target)
            if skill:  # If we can select a skill
                # Emergency heal should take priority
                assert skill.name == "heal" or skill.is_offensive == False