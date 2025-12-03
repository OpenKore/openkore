"""
Comprehensive tests for magic DPS tactics to achieve 100% coverage.
"""

import pytest
from unittest.mock import Mock, patch

from ai_sidecar.combat.tactics.magic_dps import MagicDPSTactics, MagicDPSTacticsConfig
from ai_sidecar.combat.tactics.base import Position, Skill, TargetPriority, TacticalRole


@pytest.fixture
def mock_context():
    """Create mock combat context."""
    context = Mock()
    context.character_position = Position(x=100, y=100)
    context.character_hp = 800
    context.character_hp_max = 1000
    context.character_sp = 200
    context.character_sp_max = 300
    context.nearby_monsters = []
    context.party_members = []
    context.cooldowns = {}
    context.active_buffs = {}
    return context


class TestMagicDPSComplete:
    """Complete coverage tests for magic DPS tactics."""
    
    def test_initialization(self):
        """Test magic DPS initialization."""
        tactics = MagicDPSTactics()
        assert tactics.role == TacticalRole.MAGIC_DPS
        assert isinstance(tactics.magic_config, MagicDPSTacticsConfig)
    
    def test_initialization_with_config(self):
        """Test initialization with custom config."""
        config = MagicDPSTacticsConfig(safe_cast_distance=10)
        tactics = MagicDPSTactics(config)
        assert tactics.magic_config.safe_cast_distance == 10
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, mock_context):
        """Test select target with no monsters."""
        tactics = MagicDPSTactics()
        target = await tactics.select_target(mock_context)
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_with_monsters(self, mock_context):
        """Test target selection with monsters."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (110, 110)
        monster.hp = 800
        monster.hp_max = 1000
        monster.is_boss = False
        monster.is_mvp = False
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        with patch.object(tactics, 'prioritize_targets', return_value=[
            TargetPriority(
                actor_id=2001,
                priority_score=100,
                reason="magic_target",
                distance=8.0,
                hp_percent=0.8
            )
        ]):
            target = await tactics.select_target(mock_context)
        
        assert target is not None
    
    @pytest.mark.asyncio
    async def test_select_target_prioritize_returns_empty(self, mock_context):
        """Test when prioritize_targets returns empty list."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (110, 110)
        monster.hp = 800
        monster.hp_max = 1000
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        with patch.object(tactics, 'prioritize_targets', return_value=[]):
            target = await tactics.select_target(mock_context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_skill_conserve_sp_low(self, mock_context):
        """Test skill selection when SP is low (conserve mode)."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 50  # 16.7% SP - below 30% threshold
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_buff_when_not_conserving(self, mock_context):
        """Test selects buff when SP is adequate."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 200  # 66% SP
        mock_context.cooldowns = {}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_utility_for_dangerous_target(self, mock_context):
        """Test utility skill for dangerous target."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 200
        mock_context.cooldowns = {}
        
        boss = Mock()
        boss.actor_id = 2001
        boss.is_boss = True
        boss.is_mvp = False
        boss.position = (110, 110)
        boss.hp = 5000
        boss.hp_max = 5000
        mock_context.nearby_monsters = [boss]
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=150,
            reason="dangerous",
            distance=8.0,
            hp_percent=1.0
        )
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_for_clusters(self, mock_context):
        """Test AoE skill for clustered enemies."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 250  # High SP
        mock_context.cooldowns = {}
        
        # Add target monster
        target_monster = Mock()
        target_monster.actor_id = 2001
        target_monster.position = (110, 110)
        target_monster.hp = 500
        target_monster.hp_max = 1000
        target_monster.is_boss = False
        
        # Add clustered enemies
        for i in range(3):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110 + i, 110)
            mock_context.nearby_monsters.append(monster)
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="clustered",
            distance=8.0,
            hp_percent=0.5
        )
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_elemental_matching(self, mock_context):
        """Test elemental skill selection."""
        tactics = MagicDPSTactics(MagicDPSTacticsConfig(element_matching=True))
        mock_context.character_sp = 250
        mock_context.cooldowns = {}
        
        target_monster = Mock()
        target_monster.actor_id = 2001
        target_monster.position = (110, 110)
        target_monster.hp = 500
        target_monster.hp_max = 1000
        target_monster.element = "fire"  # Weak to water
        target_monster.is_boss = False
        mock_context.nearby_monsters = [target_monster]
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="elemental",
            distance=8.0,
            hp_percent=0.5
        )
        
        with patch.object(tactics, '_count_clustered_enemies', return_value=1):
            with patch.object(tactics, 'can_use_skill', return_value=True):
                skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_fallback_to_bolt(self, mock_context):
        """Test fallback to bolt spell."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 250
        mock_context.cooldowns = {}
        mock_context.nearby_monsters = []
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self, mock_context):
        """Test positioning with no monsters."""
        tactics = MagicDPSTactics()
        position = await tactics.evaluate_positioning(mock_context)
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_retreat_when_close(self, mock_context):
        """Test positioning retreats when enemy too close."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (103, 103)  # Very close
        monster.hp = 500
        monster.hp_max = 1000
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        with patch.object(tactics, 'get_distance_to_target', return_value=3.0):
            position = await tactics.evaluate_positioning(mock_context)
        
        # Should calculate retreat
        assert position is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_retreat_at_safe_distance(self, mock_context):
        """Test no positioning needed at safe distance."""
        monster = Mock()
        monster.actor_id = 2001
        monster.position = (110, 110)
        monster.hp = 500
        monster.hp_max = 1000
        mock_context.nearby_monsters = [monster]
        
        tactics = MagicDPSTactics()
        with patch.object(tactics, 'get_distance_to_target', return_value=9.0):
            position = await tactics.evaluate_positioning(mock_context)
        
        # At safe distance, no need to move
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_closest_monster_none(self, mock_context):
        """Test positioning when no closest monster found."""
        mock_context.nearby_monsters = [Mock()]
        
        tactics = MagicDPSTactics()
        
        # Force closest_monster to be None by making all distances infinite
        with patch.object(tactics, 'get_distance_to_target', return_value=float('inf')):
            # After the loop, closest_monster will still be None
            position = await tactics.evaluate_positioning(mock_context)
        
        # Should return None when no valid closest monster
        assert position is None
    
    def test_get_threat_assessment_critical_hp(self, mock_context):
        """Test threat with critical HP (<25%)."""
        tactics = MagicDPSTactics()
        mock_context.character_hp = 200  # 20% HP
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat >= 0.5
    
    def test_get_threat_assessment_moderate_hp(self, mock_context):
        """Test threat with moderate HP (25-50%)."""
        tactics = MagicDPSTactics()
        mock_context.character_hp = 400  # 40% HP
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat >= 0.25
    
    def test_get_threat_assessment_critical_sp(self, mock_context):
        """Test threat with critical SP (<10%)."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 25  # 8.3% SP
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat >= 0.3
    
    def test_get_threat_assessment_low_sp(self, mock_context):
        """Test threat with low SP (10-20%)."""
        tactics = MagicDPSTactics()
        mock_context.character_sp = 50  # 16.7% SP
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat >= 0.15
    
    def test_get_threat_assessment_very_close_enemies(self, mock_context):
        """Test threat with very close enemies (<3 cells)."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.position = (102, 102)
        mock_context.nearby_monsters = [monster]
        
        with patch.object(tactics, 'get_distance_to_target', return_value=2.0):
            threat = tactics.get_threat_assessment(mock_context)
        
        assert threat >= 0.2
    
    def test_get_threat_assessment_close_enemies(self, mock_context):
        """Test threat with close enemies (3-8 cells)."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.position = (105, 105)
        mock_context.nearby_monsters = [monster]
        
        with patch.object(tactics, 'get_distance_to_target', return_value=5.0):
            threat = tactics.get_threat_assessment(mock_context)
        
        assert threat >= 0.1
    
    def test_get_threat_assessment_while_casting(self, mock_context):
        """Test threat increases while casting."""
        tactics = MagicDPSTactics()
        tactics._current_cast = "fire_bolt"
        
        threat = tactics.get_threat_assessment(mock_context)
        assert threat >= 0.1
    
    def test_magic_target_score_safe_distance(self):
        """Test target scoring at safe distance."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.is_boss = False
        monster.is_mvp = False
        
        score = tactics._magic_target_score(monster, 0.8, 9.0)
        assert score > 100  # Safe distance bonus
    
    def test_magic_target_score_too_close_penalty(self):
        """Test target scoring penalty for close distance."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.is_boss = False
        monster.is_mvp = False
        
        score = tactics._magic_target_score(monster, 0.8, 3.0)
        assert score < 100  # Penalty for too close
    
    def test_magic_target_score_with_element_weakness(self):
        """Test target scoring with element weakness."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.element = "fire"  # Weak to water
        monster.is_boss = False
        monster.is_mvp = False
        
        with patch.object(tactics, '_has_element_spell', return_value=True):
            score = tactics._magic_target_score(monster, 0.8, 9.0)
        
        assert score > 120  # Element bonus
    
    def test_magic_target_score_mvp(self):
        """Test target scoring for MVP."""
        tactics = MagicDPSTactics()
        
        mvp = Mock()
        mvp.is_mvp = True
        mvp.is_boss = False
        
        score = tactics._magic_target_score(mvp, 0.8, 9.0)
        assert score > 130  # MVP bonus
    
    def test_magic_target_score_boss(self):
        """Test target scoring for boss."""
        tactics = MagicDPSTactics()
        
        boss = Mock()
        boss.is_boss = True
        boss.is_mvp = False
        
        score = tactics._magic_target_score(boss, 0.8, 9.0)
        assert score > 110  # Boss bonus
    
    def test_has_element_spell_exists(self):
        """Test checking for element spell that exists."""
        tactics = MagicDPSTactics()
        assert tactics._has_element_spell("fire") is True
        assert tactics._has_element_spell("water") is True
    
    def test_has_element_spell_not_exists(self):
        """Test checking for element spell that doesn't exist."""
        tactics = MagicDPSTactics()
        assert tactics._has_element_spell("poison") is False
    
    def test_get_target_weakness_none(self):
        """Test getting weakness for None target."""
        tactics = MagicDPSTactics()
        assert tactics._get_target_weakness(None) is None
    
    def test_get_target_weakness_no_element(self):
        """Test getting weakness for target without element."""
        tactics = MagicDPSTactics()
        target = Mock(spec=[])  # No element attribute
        assert tactics._get_target_weakness(target) is None
    
    def test_get_target_weakness_fire(self):
        """Test getting weakness for fire element."""
        tactics = MagicDPSTactics()
        target = Mock()
        target.element = "fire"
        
        weakness = tactics._get_target_weakness(target)
        assert weakness == "earth"
    
    def test_get_target_weakness_unknown_element(self):
        """Test getting weakness for unknown element."""
        tactics = MagicDPSTactics()
        target = Mock()
        target.element = "unknown"
        
        weakness = tactics._get_target_weakness(target)
        assert weakness is None
    
    def test_is_dangerous_target_boss(self):
        """Test dangerous check for boss."""
        tactics = MagicDPSTactics()
        
        boss = Mock()
        boss.is_boss = True
        boss.is_mvp = False
        
        assert tactics._is_dangerous_target(boss) is True
    
    def test_is_dangerous_target_mvp(self):
        """Test dangerous check for MVP."""
        tactics = MagicDPSTactics()
        
        mvp = Mock()
        mvp.is_mvp = True
        mvp.is_boss = False
        
        assert tactics._is_dangerous_target(mvp) is True
    
    def test_is_dangerous_target_aggressive_high_hp(self):
        """Test dangerous check for aggressive high HP monster."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.is_boss = False
        monster.is_mvp = False
        monster.is_aggressive = True
        monster.hp = 900
        monster.hp_max = 1000
        
        assert tactics._is_dangerous_target(monster) is True
    
    def test_is_dangerous_target_aggressive_low_hp(self):
        """Test not dangerous for aggressive low HP monster."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.is_boss = False
        monster.is_mvp = False
        monster.is_aggressive = True
        monster.hp = 300
        monster.hp_max = 1000
        
        assert tactics._is_dangerous_target(monster) is False
    
    def test_is_dangerous_target_normal(self):
        """Test not dangerous for normal monster."""
        tactics = MagicDPSTactics()
        
        monster = Mock(spec=['is_boss', 'is_mvp'])  # Only has these attributes
        monster.is_boss = False
        monster.is_mvp = False
        
        assert tactics._is_dangerous_target(monster) is False
    
    def test_select_buff_skill_available(self, mock_context):
        """Test buff skill selection."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_buff_skill(mock_context)
        
        assert skill is not None
        assert skill.name in tactics.BUFF_SKILLS
    
    def test_select_buff_skill_all_on_cooldown(self, mock_context):
        """Test buff selection when all on cooldown."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {s: 5.0 for s in tactics.BUFF_SKILLS}
        
        skill = tactics._select_buff_skill(mock_context)
        assert skill is None
    
    def test_select_buff_skill_cannot_use(self, mock_context):
        """Test buff selection when can't use skill."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=False):
            skill = tactics._select_buff_skill(mock_context)
        
        assert skill is None
    
    def test_select_utility_skill_available(self, mock_context):
        """Test utility skill selection."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_utility_skill(mock_context)
        
        assert skill is not None
    
    def test_select_utility_skill_all_on_cooldown(self, mock_context):
        """Test utility selection when all on cooldown."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {s: 5.0 for s in tactics.UTILITY_SKILLS}
        
        skill = tactics._select_utility_skill(mock_context)
        assert skill is None
    
    def test_select_aoe_skill_available(self, mock_context):
        """Test AoE skill selection."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_aoe_skill(mock_context, None)
        
        assert skill is not None
    
    def test_select_aoe_skill_all_on_cooldown(self, mock_context):
        """Test AoE selection when all on cooldown."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {s: 5.0 for s in tactics.AOE_SKILLS}
        
        skill = tactics._select_aoe_skill(mock_context, None)
        assert skill is None
    
    def test_select_elemental_skill_fire(self, mock_context):
        """Test elemental skill selection for fire."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_elemental_skill(mock_context, "fire")
        
        assert skill is not None
        assert skill.element == "fire"
    
    def test_select_elemental_skill_unknown_element(self, mock_context):
        """Test elemental skill for unknown element."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        skill = tactics._select_elemental_skill(mock_context, "poison")
        assert skill is None
    
    def test_select_bolt_spell_normal(self, mock_context):
        """Test bolt spell selection when not conserving."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_bolt_spell(mock_context, conserve_sp=False)
        
        assert skill is not None
        assert skill.name in tactics.SINGLE_TARGET_SKILLS
    
    def test_select_bolt_spell_conserve(self, mock_context):
        """Test bolt spell selection when conserving SP."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {}
        
        with patch.object(tactics, 'can_use_skill', return_value=True):
            skill = tactics._select_bolt_spell(mock_context, conserve_sp=True)
        
        assert skill is not None
        assert skill.level == 5  # Lower level when conserving
    
    def test_select_bolt_spell_all_on_cooldown(self, mock_context):
        """Test bolt spell when all on cooldown."""
        tactics = MagicDPSTactics()
        mock_context.cooldowns = {s: 5.0 for s in tactics.SINGLE_TARGET_SKILLS}
        
        skill = tactics._select_bolt_spell(mock_context, conserve_sp=False)
        assert skill is None
    
    def test_count_clustered_enemies_none(self, mock_context):
        """Test cluster count with no target found."""
        tactics = MagicDPSTactics()
        mock_context.nearby_monsters = []
        
        target = TargetPriority(
            actor_id=9999,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        count = tactics._count_clustered_enemies(mock_context, target)
        assert count == 0
    
    def test_count_clustered_enemies_grouped(self, mock_context):
        """Test cluster count with grouped enemies."""
        # Add target and nearby enemies
        for i in range(4):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110, 110 + i)
            mock_context.nearby_monsters.append(monster)
        
        tactics = MagicDPSTactics()
        target = TargetPriority(
            actor_id=2000,
            priority_score=100,
            reason="test",
            distance=8.0,
            hp_percent=0.8
        )
        
        count = tactics._count_clustered_enemies(mock_context, target)
        assert count >= 3
    
    def test_find_monster_by_id_found(self, mock_context):
        """Test finding monster by ID."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.actor_id = 2001
        mock_context.nearby_monsters = [monster]
        
        result = tactics._find_monster_by_id(mock_context, 2001)
        assert result == monster
    
    def test_find_monster_by_id_not_found(self, mock_context):
        """Test not finding monster by ID."""
        tactics = MagicDPSTactics()
        mock_context.nearby_monsters = []
        
        result = tactics._find_monster_by_id(mock_context, 9999)
        assert result is None
    
    def test_calculate_retreat_position(self):
        """Test retreat position calculation."""
        tactics = MagicDPSTactics()
        
        current = Position(x=100, y=100)
        threat = Position(x=105, y=105)
        
        retreat = tactics._calculate_retreat_position(current, threat)
        
        assert retreat is not None
        # Should be further from threat
        assert retreat.distance_to(threat) > current.distance_to(threat)
    
    def test_get_skill_id_known(self):
        """Test skill ID lookup for known skills."""
        tactics = MagicDPSTactics()
        assert tactics._get_skill_id("fire_bolt") == 19
        assert tactics._get_skill_id("cold_bolt") == 14
    
    def test_get_skill_id_unknown(self):
        """Test skill ID lookup for unknown skill."""
        tactics = MagicDPSTactics()
        assert tactics._get_skill_id("unknown_spell") == 0
    
    def test_get_sp_cost_known(self):
        """Test SP cost lookup for known skills."""
        tactics = MagicDPSTactics()
        assert tactics._get_sp_cost("fire_bolt") == 12
        assert tactics._get_sp_cost("meteor_storm") == 64
    
    def test_get_sp_cost_unknown(self):
        """Test SP cost lookup for unknown skill."""
        tactics = MagicDPSTactics()
        assert tactics._get_sp_cost("unknown") == 15
    
    def test_get_cast_time_known(self):
        """Test cast time lookup for known skills."""
        tactics = MagicDPSTactics()
        assert tactics._get_cast_time("fire_bolt") == 0.7
        assert tactics._get_cast_time("meteor_storm") == 15.0
    
    def test_get_cast_time_unknown(self):
        """Test cast time lookup for unknown skill."""
        tactics = MagicDPSTactics()
        assert tactics._get_cast_time("unknown") == 1.0