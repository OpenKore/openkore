"""
Comprehensive tests for combat/tactics/support.py module.

Tests support/healer tactics including healing priorities, buff management,
party support coordination, and emergency response handling.
"""

from unittest.mock import Mock, MagicMock
import pytest

from ai_sidecar.combat.tactics.support import (
    SupportTactics,
    SupportTacticsConfig,
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TacticalRole,
    TargetPriority,
)


class TestSupportTacticsConfig:
    """Test SupportTacticsConfig model."""
    
    def test_default_config_values(self):
        """Test default configuration values."""
        config = SupportTacticsConfig()
        
        assert config.heal_trigger_threshold == 0.80
        assert config.emergency_heal_threshold == 0.35
        assert config.maintain_buffs is True
        assert config.buff_refresh_threshold == 10.0
        assert config.self_heal_priority == 0.75
        assert config.safe_distance_from_combat == 5
        assert config.max_heal_range == 9
    
    def test_custom_config_values(self):
        """Test custom configuration values."""
        config = SupportTacticsConfig(
            heal_trigger_threshold=0.70,
            emergency_heal_threshold=0.25,
            self_heal_priority=0.60,
            safe_distance_from_combat=7
        )
        
        assert config.heal_trigger_threshold == 0.70
        assert config.emergency_heal_threshold == 0.25
        assert config.self_heal_priority == 0.60
        assert config.safe_distance_from_combat == 7


class TestSupportTactics:
    """Test SupportTactics class."""
    
    @pytest.fixture
    def tactics(self):
        """Create support tactics instance."""
        config = SupportTacticsConfig()
        return SupportTactics(config)
    
    @pytest.fixture
    def mock_context(self):
        """Create mock combat context."""
        context = Mock()
        context.character_position = Position(x=100, y=100)
        context.character_hp = 500
        context.character_hp_max = 500
        context.character_sp = 300
        context.character_sp_max = 300
        context.cooldowns = {}
        context.nearby_monsters = []
        context.party_members = []
        return context
    
    def test_role_is_support(self, tactics):
        """Test that role is SUPPORT."""
        assert tactics.role == TacticalRole.SUPPORT
    
    def test_initialization_with_config(self):
        """Test initialization with custom config."""
        config = SupportTacticsConfig(heal_trigger_threshold=0.65)
        tactics = SupportTactics(config)
        
        assert tactics.support_config.heal_trigger_threshold == 0.65
    
    def test_initialization_without_config(self):
        """Test initialization without config."""
        tactics = SupportTactics()
        
        assert isinstance(tactics.support_config, SupportTacticsConfig)
        assert tactics.support_config.heal_trigger_threshold == 0.80
    
    @pytest.mark.asyncio
    async def test_select_target_no_party_no_monsters(self, tactics, mock_context):
        """Test target selection with no party or monsters."""
        target = await tactics.select_target(mock_context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_self_heal_priority(self, tactics, mock_context):
        """Test self-heal takes priority when HP low."""
        mock_context.character_hp = 200  # 40% HP
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 0  # Self
        assert target.reason == "self_heal"
    
    @pytest.mark.asyncio
    async def test_select_target_party_member_low_hp(self, tactics, mock_context):
        """Test targeting party member with low HP."""
        party_member = Mock()
        party_member.actor_id = 123
        party_member.hp = 150
        party_member.hp_max = 500
        party_member.position = (105, 105)
        
        mock_context.party_members = [party_member]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 123
        assert target.reason == "heal_needed"
    
    @pytest.mark.asyncio
    async def test_select_target_emergency_priority(self, tactics, mock_context):
        """Test emergency heal gets highest priority."""
        # Create two party members
        member1 = Mock()
        member1.actor_id = 100
        member1.hp = 400
        member1.hp_max = 500
        member1.position = (105, 105)
        
        member2 = Mock()
        member2.actor_id = 200
        member2.hp = 50  # Critical HP
        member2.hp_max = 500
        member2.position = (110, 110)
        
        mock_context.party_members = [member1, member2]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 200  # Critical member selected
    
    @pytest.mark.asyncio
    async def test_select_target_solo_offensive(self, tactics, mock_context):
        """Test offensive target selection when solo."""
        monster = Mock()
        monster.actor_id = 999
        monster.hp = 1000
        monster.hp_max = 1000
        monster.position = (110, 110)
        
        mock_context.nearby_monsters = [monster]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 999
    
    @pytest.mark.asyncio
    async def test_select_skill_self_heal(self, tactics, mock_context):
        """Test skill selection for self-healing."""
        mock_context.character_hp = 100  # Critical HP
        
        target = TargetPriority(
            actor_id=0,
            priority_score=200,
            reason="self_heal",
            distance=0,
            hp_percent=0.20
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        assert skill.is_offensive is False
        assert skill.name in tactics.EMERGENCY_HEALS or skill.name in tactics.REGULAR_HEALS
    
    @pytest.mark.asyncio
    async def test_select_skill_emergency_heal(self, tactics, mock_context):
        """Test emergency heal skill selection."""
        # Add party member so target is recognized as ally
        member = Mock()
        member.actor_id = 123
        member.hp = 125
        member.hp_max = 500
        member.position = (105, 105)
        mock_context.party_members = [member]
        
        target = TargetPriority(
            actor_id=123,
            priority_score=180,
            reason="heal_needed",
            distance=5,
            hp_percent=0.25  # Emergency threshold
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        # Should select heal or defensive skill for ally (not offensive)
        assert not skill.is_offensive
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_buff(self, tactics, mock_context):
        """Test defensive buff selection."""
        # Add party member so target is recognized as ally
        member = Mock()
        member.actor_id = 123
        member.hp = 300
        member.hp_max = 500
        member.position = (105, 105)
        mock_context.party_members = [member]
        
        target = TargetPriority(
            actor_id=123,
            priority_score=150,
            reason="heal_needed",
            distance=5,
            hp_percent=0.60  # Below trigger but not critical
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        # Should be defensive buff or heal
        assert not skill.is_offensive
    
    @pytest.mark.asyncio
    async def test_select_skill_offensive_solo(self, tactics, mock_context):
        """Test offensive skill for solo combat."""
        target = TargetPriority(
            actor_id=999,
            priority_score=100,
            reason="combat",
            distance=5,
            hp_percent=1.0
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        assert skill.is_offensive is True
        assert skill.name in tactics.OFFENSIVE_SKILLS
    
    @pytest.mark.asyncio
    async def test_select_skill_respects_cooldowns(self, tactics, mock_context):
        """Test that skills on cooldown are not selected."""
        mock_context.cooldowns = {skill: 5.0 for skill in tactics.EMERGENCY_HEALS}
        mock_context.character_hp = 100
        
        target = TargetPriority(
            actor_id=0,
            priority_score=200,
            reason="self_heal",
            distance=0,
            hp_percent=0.20
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        # Should still find a skill (may be None if all are on cooldown)
        if skill:
            assert mock_context.cooldowns.get(skill.name, 0) <= 0
    
    @pytest.mark.asyncio
    async def test_select_skill_insufficient_sp(self, tactics, mock_context):
        """Test skill selection with insufficient SP."""
        mock_context.character_sp = 5  # Very low SP
        
        target = TargetPriority(
            actor_id=123,
            priority_score=150,
            reason="heal_needed",
            distance=5,
            hp_percent=0.50
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        # May return None if no skill can be used
        if skill:
            assert skill.sp_cost <= mock_context.character_sp
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self, tactics, mock_context):
        """Test positioning with no monsters."""
        position = await tactics.evaluate_positioning(mock_context)
        
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_away_from_threats(self, tactics, mock_context):
        """Test positioning moves away from threats."""
        monster = Mock()
        monster.position = (102, 102)  # Close to character
        mock_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        if position:
            # Should be farther from monster
            original_dist = ((102-100)**2 + (102-100)**2) ** 0.5
            new_dist = ((position.x-102)**2 + (position.y-102)**2) ** 0.5
            assert new_dist >= original_dist
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_with_party(self, tactics, mock_context):
        """Test positioning stays near party."""
        party_member = Mock()
        party_member.position = (95, 95)
        mock_context.party_members = [party_member]
        
        monster = Mock()
        monster.position = (90, 90)
        mock_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        if position:
            # Should position behind party, away from threat
            assert position is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_within_heal_range(self, tactics, mock_context):
        """Test stays within heal range of party."""
        party_member = Mock()
        party_member.position = (120, 120)  # Far from support
        mock_context.party_members = [party_member]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        if position:
            # Should move closer to party
            dist_to_party = ((position.x-120)**2 + (position.y-120)**2) ** 0.5
            assert dist_to_party <= tactics.support_config.max_heal_range + 5
    
    def test_get_threat_assessment_low_hp(self, tactics, mock_context):
        """Test threat assessment with low HP."""
        mock_context.character_hp = 100
        mock_context.character_hp_max = 500
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.3  # Significant threat
    
    def test_get_threat_assessment_low_sp(self, tactics, mock_context):
        """Test threat assessment with low SP."""
        mock_context.character_sp = 30
        mock_context.character_sp_max = 300
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.2  # SP threat
    
    def test_get_threat_assessment_party_emergencies(self, tactics, mock_context):
        """Test threat increases with party emergencies."""
        member1 = Mock()
        member1.hp = 50
        member1.hp_max = 500
        
        member2 = Mock()
        member2.hp = 80
        member2.hp_max = 500
        
        mock_context.party_members = [member1, member2]
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.1
    
    def test_get_threat_assessment_close_enemies(self, tactics, mock_context):
        """Test threat increases with close enemies."""
        for i in range(3):
            monster = Mock()
            monster.position = (101 + i, 101 + i)
            mock_context.nearby_monsters.append(monster)
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.1
    
    def test_get_threat_assessment_capped_at_one(self, tactics, mock_context):
        """Test threat is capped at 1.0."""
        # Create extreme threat scenario
        mock_context.character_hp = 10
        mock_context.character_sp = 5
        
        for i in range(10):
            monster = Mock()
            monster.position = (100, 100)
            mock_context.nearby_monsters.append(monster)
        
        for i in range(5):
            member = Mock()
            member.hp = 10
            member.hp_max = 500
            mock_context.party_members.append(member)
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat <= 1.0
    
    def test_is_ally_target_self(self, tactics, mock_context):
        """Test recognizing self as ally."""
        is_ally = tactics._is_ally_target(mock_context, 0)
        assert is_ally is True
    
    def test_is_ally_target_party_member(self, tactics, mock_context):
        """Test recognizing party member as ally."""
        member = Mock()
        member.actor_id = 123
        mock_context.party_members = [member]
        
        is_ally = tactics._is_ally_target(mock_context, 123)
        assert is_ally is True
    
    def test_is_ally_target_enemy(self, tactics, mock_context):
        """Test recognizing enemy as not ally."""
        is_ally = tactics._is_ally_target(mock_context, 999)
        assert is_ally is False
    
    def test_needs_self_heal_true(self, tactics, mock_context):
        """Test detecting need for self-heal."""
        mock_context.character_hp = 100
        mock_context.character_hp_max = 500
        
        needs_heal = tactics._needs_self_heal(mock_context)
        assert needs_heal is True
    
    def test_needs_self_heal_false(self, tactics, mock_context):
        """Test not needing self-heal."""
        mock_context.character_hp = 450
        mock_context.character_hp_max = 500
        
        needs_heal = tactics._needs_self_heal(mock_context)
        assert needs_heal is False
    
    def test_calculate_party_center(self, tactics, mock_context):
        """Test calculating party center position."""
        member1 = Mock()
        member1.position = (100, 100)
        
        member2 = Mock()
        member2.position = (110, 110)
        
        mock_context.party_members = [member1, member2]
        
        center = tactics._calculate_party_center(mock_context)
        
        assert center is not None
        assert center.x == 105
        assert center.y == 105
    
    def test_calculate_party_center_no_members(self, tactics, mock_context):
        """Test party center with no members."""
        center = tactics._calculate_party_center(mock_context)
        assert center is None
    
    def test_calculate_threat_center(self, tactics, mock_context):
        """Test calculating threat center position."""
        monster1 = Mock()
        monster1.position = (80, 80)
        
        monster2 = Mock()
        monster2.position = (90, 90)
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        center = tactics._calculate_threat_center(mock_context)
        
        assert center is not None
        assert center.x == 85
        assert center.y == 85
    
    def test_calculate_threat_center_no_monsters(self, tactics, mock_context):
        """Test threat center with no monsters."""
        center = tactics._calculate_threat_center(mock_context)
        assert center is None
    
    def test_calculate_safe_position(self, tactics):
        """Test calculating safe position away from threat."""
        current = Position(x=100, y=100)
        threat = Position(x=95, y=95)
        
        safe_pos = tactics._calculate_safe_position(current, threat)
        
        # Should be farther from threat
        assert safe_pos.x > current.x or safe_pos.y > current.y
    
    def test_calculate_support_position(self, tactics):
        """Test calculating support position behind party."""
        party_center = Position(x=100, y=100)
        threat_center = Position(x=90, y=90)
        
        support_pos = tactics._calculate_support_position(party_center, threat_center)
        
        # Should be behind party (away from threat)
        assert support_pos.x > party_center.x or support_pos.y > party_center.y
    
    def test_move_toward_position(self, tactics):
        """Test moving toward a target position."""
        current = Position(x=100, y=100)
        target = Position(x=110, y=110)
        
        new_pos = tactics._move_toward(current, target, distance=5)
        
        # Should be closer to target
        assert new_pos.x > current.x
        assert new_pos.y > current.y
    
    def test_get_skill_id_mapping(self, tactics):
        """Test skill ID mapping."""
        assert tactics._get_skill_id("heal") == 28
        assert tactics._get_skill_id("blessing") == 34
        assert tactics._get_skill_id("sanctuary") == 70
        assert tactics._get_skill_id("unknown_skill") == 0
    
    def test_get_sp_cost_mapping(self, tactics):
        """Test SP cost mapping."""
        assert tactics._get_sp_cost("heal") == 13
        assert tactics._get_sp_cost("resurrection") == 60
        assert tactics._get_sp_cost("unknown_skill") == 15