"""
Extended test coverage for magic_dps.py tactics.

Targets uncovered lines to achieve 100% coverage:
- Lines 163, 187-195, 199-203, 208-210, 238-255, 277, 291-297, 314-330, 344-357, 366-402, 410-426, 434-453, 469-497, 509
- Element matching, utility skills, AoE decisions
- Positioning and retreat logic
"""

import pytest
from unittest.mock import Mock, MagicMock

from ai_sidecar.combat.tactics.magic_dps import (
    MagicDPSTactics,
    MagicDPSTacticsConfig,
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TargetPriority,
    TacticalRole,
)


class TestMagicDPSExtendedCoverage:
    """Extended coverage for magic DPS tactics."""
    
    @pytest.mark.asyncio
    async def test_select_target_with_element_weakness(self):
        """Test target selection with element weakness bonus."""
        config = MagicDPSTacticsConfig(element_matching=True)
        tactics = MagicDPSTactics(config)
        
        # Monster with fire element
        monster = Mock()
        monster.actor_id = 100
        monster.position = (150, 150)
        monster.hp = 500
        monster.hp_max = 1000
        monster.element = "fire"
        monster.is_mvp = False
        monster.is_boss = False
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        target = await tactics.select_target(context)
        
        assert target is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_conserve_sp_mode(self):
        """Test skill selection in SP conservation mode."""
        config = MagicDPSTacticsConfig(sp_conservation_threshold=0.5)
        tactics = MagicDPSTactics(config)
        
        monster = Mock()
        monster.actor_id = 100
        monster.position = (150, 150)
        monster.element = "neutral"
        monster.is_boss = False
        monster.is_mvp = False
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_sp = 20
        context.character_sp_max = 100  # 20% SP
        context.character_position = Position(x=100, y=100)
        context.cooldowns = {}
        
        target = TargetPriority(actor_id=100, priority_score=100.0)
        
        skill = await tactics.select_skill(context, target)
        
        # Should select bolt spell for SP conservation
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_with_buff_needed(self):
        """Test skill selection prioritizes buffs when SP available."""
        config = MagicDPSTacticsConfig(sp_conservation_threshold=0.3)
        tactics = MagicDPSTactics(config)
        
        monster = Mock()
        monster.actor_id = 100
        monster.position = (150, 150)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_sp = 80
        context.character_sp_max = 100  # 80% SP - not conserving
        context.character_position = Position(x=100, y=100)
        context.cooldowns = {}
        
        target = TargetPriority(actor_id=100, priority_score=100.0)
        
        skill = await tactics.select_skill(context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_utility_for_dangerous_target(self):
        """Test utility skill selection for dangerous targets."""
        config = MagicDPSTacticsConfig()
        tactics = MagicDPSTactics(config)
        
        # Dangerous MVP monster
        monster = Mock()
        monster.actor_id = 100
        monster.position = (150, 150)
        monster.element = "neutral"
        monster.is_boss = True
        monster.is_mvp = True
        monster.hp = 50000
        monster.hp_max = 50000
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_sp = 80
        context.character_sp_max = 100
        context.character_position = Position(x=100, y=100)
        context.cooldowns = {}
        
        target = TargetPriority(actor_id=100, priority_score=150.0)
        
        skill = await tactics.select_skill(context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_for_clustered_enemies(self):
        """Test AoE skill selection for clustered enemies."""
        config = MagicDPSTacticsConfig(use_aoe_threshold=3)
        tactics = MagicDPSTactics(config)
        
        # Multiple clustered monsters
        monsters = []
        for i in range(5):
            m = Mock()
            m.actor_id = 100 + i
            m.position = (150 + i, 150 + i)  # Close together
            m.element = "neutral"
            m.is_boss = False
            m.is_mvp = False
            monsters.append(m)
        
        context = Mock()
        context.nearby_monsters = monsters
        context.character_sp = 80
        context.character_sp_max = 100
        context.character_position = Position(x=100, y=100)
        context.cooldowns = {}
        
        target = TargetPriority(actor_id=100, priority_score=100.0)
        
        skill = await tactics.select_skill(context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_element_matched(self):
        """Test element-matched skill selection."""
        config = MagicDPSTacticsConfig(element_matching=True)
        tactics = MagicDPSTactics(config)
        
        # Fire monster - should use water/earth spells
        monster = Mock()
        monster.actor_id = 100
        monster.position = (150, 150)
        monster.element = "fire"
        monster.is_boss = False
        monster.is_mvp = False
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_sp = 80
        context.character_sp_max = 100
        context.character_position = Position(x=100, y=100)
        context.cooldowns = {}
        
        target = TargetPriority(actor_id=100, priority_score=100.0)
        
        skill = await tactics.select_skill(context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_too_close_retreat(self):
        """Test positioning retreats when enemy too close."""
        config = MagicDPSTacticsConfig(safe_cast_distance=8)
        tactics = MagicDPSTactics(config)
        
        # Monster very close
        monster = Mock()
        monster.actor_id = 100
        monster.position = (103, 103)  # Distance ~4 from (100, 100)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        tactics.get_distance_to_target = Mock(return_value=4.0)
        
        position = await tactics.evaluate_positioning(context)
        
        assert position is not None
        # Should retreat away from monster
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_safe_distance(self):
        """Test positioning returns None at safe distance."""
        config = MagicDPSTacticsConfig(safe_cast_distance=8)
        tactics = MagicDPSTactics(config)
        
        # Monster at safe distance
        monster = Mock()
        monster.actor_id = 100
        monster.position = (110, 110)  # Distance ~14 from (100, 100)
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        tactics.get_distance_to_target = Mock(return_value=10.0)
        
        position = await tactics.evaluate_positioning(context)
        
        assert position is None  # No repositioning needed
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_closest_monster(self):
        """Test positioning with no valid monsters."""
        config = MagicDPSTacticsConfig()
        tactics = MagicDPSTactics(config)
        
        context = Mock()
        context.nearby_monsters = []
        context.character_position = Position(x=100, y=100)
        
        position = await tactics.evaluate_positioning(context)
        
        assert position is None
    
    def test_get_threat_assessment_low_hp(self):
        """Test threat increases with low HP."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.character_hp = 20
        context.character_hp_max = 100  # 20% HP
        context.character_sp = 50
        context.character_sp_max = 100
        context.nearby_monsters = []
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat > 0.4  # High threat due to low HP
    
    def test_get_threat_assessment_low_sp(self):
        """Test threat increases with low SP."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        context.character_sp = 5
        context.character_sp_max = 100  # 5% SP
        context.nearby_monsters = []
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat > 0.2  # Threat due to low SP
    
    def test_get_threat_assessment_enemies_close(self):
        """Test threat increases with close enemies."""
        tactics = MagicDPSTactics()
        tactics.magic_config = MagicDPSTacticsConfig(safe_cast_distance=8)
        
        # Very close monster
        monster = Mock()
        monster.position = (102, 102)
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        context.character_sp = 100
        context.character_sp_max = 100
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        tactics.get_distance_to_target = Mock(return_value=2.0)
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat > 0.1  # Threat from close enemy
    
    def test_get_threat_assessment_currently_casting(self):
        """Test threat increases while casting."""
        tactics = MagicDPSTactics()
        tactics._current_cast = "storm_gust"
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        context.character_sp = 100
        context.character_sp_max = 100
        context.nearby_monsters = []
        
        threat = tactics.get_threat_assessment(context)
        
        assert threat >= 0.1  # Threat from casting vulnerability
    
    def test_magic_target_score_element_weakness(self):
        """Test scoring with element weakness."""
        tactics = MagicDPSTactics()
        tactics.magic_config = MagicDPSTacticsConfig(element_matching=True)
        
        # Fire monster - weak to earth/water
        target = Mock()
        target.element = "fire"
        target.is_mvp = False
        target.is_boss = False
        
        score = tactics._magic_target_score(target, hp_percent=0.8, distance=10.0)
        
        # Should have bonus for element weakness
        assert score > 100
    
    def test_magic_target_score_mvp_bonus(self):
        """Test scoring with MVP bonus."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.element = "neutral"
        target.is_mvp = True
        target.is_boss = False
        
        score = tactics._magic_target_score(target, hp_percent=0.8, distance=10.0)
        
        assert score > 130  # MVP bonus
    
    def test_magic_target_score_boss_bonus(self):
        """Test scoring with boss bonus."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.element = "neutral"
        target.is_mvp = False
        target.is_boss = True
        
        score = tactics._magic_target_score(target, hp_percent=0.8, distance=10.0)
        
        assert score > 110  # Boss bonus
    
    def test_magic_target_score_too_close_penalty(self):
        """Test penalty for targets too close."""
        tactics = MagicDPSTactics()
        tactics.magic_config = MagicDPSTacticsConfig(safe_cast_distance=8)
        
        target = Mock()
        target.element = "neutral"
        target.is_mvp = False
        target.is_boss = False
        
        score = tactics._magic_target_score(target, hp_percent=0.5, distance=5.0)
        
        # Should have penalty for being too close
        assert score < 100
    
    def test_has_element_spell(self):
        """Test checking for element spells."""
        tactics = MagicDPSTactics()
        
        assert tactics._has_element_spell("fire") is True
        assert tactics._has_element_spell("water") is True
        assert tactics._has_element_spell("invalid") is False
    
    def test_get_target_weakness_none_target(self):
        """Test getting weakness for None target."""
        tactics = MagicDPSTactics()
        
        weakness = tactics._get_target_weakness(None)
        assert weakness is None
    
    def test_get_target_weakness_no_element_attr(self):
        """Test getting weakness for target without element."""
        tactics = MagicDPSTactics()
        
        target = Mock(spec=[])  # No element attribute
        
        weakness = tactics._get_target_weakness(target)
        assert weakness is None
    
    def test_get_target_weakness_fire_element(self):
        """Test getting weakness for fire monster."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.element = "fire"
        
        weakness = tactics._get_target_weakness(target)
        assert weakness == "earth"
    
    def test_is_dangerous_target_boss(self):
        """Test identifying boss as dangerous."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.is_boss = True
        target.is_mvp = False
        
        result = tactics._is_dangerous_target(target)
        assert result is True
    
    def test_is_dangerous_target_mvp(self):
        """Test identifying MVP as dangerous."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.is_boss = False
        target.is_mvp = True
        
        result = tactics._is_dangerous_target(target)
        assert result is True
    
    def test_is_dangerous_target_aggressive_high_hp(self):
        """Test identifying aggressive high HP target as dangerous."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.is_boss = False
        target.is_mvp = False
        target.is_aggressive = True
        target.hp = 850
        target.hp_max = 1000  # 85% HP
        
        result = tactics._is_dangerous_target(target)
        assert result is True
    
    def test_is_dangerous_target_not_dangerous(self):
        """Test normal target not identified as dangerous."""
        tactics = MagicDPSTactics()
        
        target = Mock()
        target.is_boss = False
        target.is_mvp = False
        target.is_aggressive = False
        
        result = tactics._is_dangerous_target(target)
        assert result is False
    
    def test_select_buff_skill(self):
        """Test selecting buff skill."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 50
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_buff_skill(context)
        
        assert skill is not None
        assert skill.is_offensive is False
    
    def test_select_buff_skill_on_cooldown(self):
        """Test buff skill on cooldown returns None."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {s: 10 for s in tactics.BUFF_SKILLS}
        
        skill = tactics._select_buff_skill(context)
        
        assert skill is None
    
    def test_select_utility_skill(self):
        """Test selecting utility skill."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 50
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_utility_skill(context)
        
        assert skill is not None
        assert skill.is_offensive is True
    
    def test_select_aoe_skill(self):
        """Test selecting AoE skill."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 100
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_aoe_skill(context, None)
        
        assert skill is not None
        assert skill.is_offensive is True
    
    def test_select_elemental_skill(self):
        """Test selecting elemental skill."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 50
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_elemental_skill(context, "fire")
        
        assert skill is not None
        assert skill.element == "fire"
    
    def test_select_elemental_skill_unknown_element(self):
        """Test selecting elemental skill for unknown element."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        
        skill = tactics._select_elemental_skill(context, "invalid")
        
        assert skill is None
    
    def test_select_bolt_spell_normal(self):
        """Test selecting bolt spell normally."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 50
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_bolt_spell(context, conserve_sp=False)
        
        assert skill is not None
        assert skill.is_offensive is True
    
    def test_select_bolt_spell_conserve_sp(self):
        """Test selecting bolt spell in conservation mode."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.cooldowns = {}
        context.character_sp = 20
        
        tactics.can_use_skill = Mock(return_value=True)
        
        skill = tactics._select_bolt_spell(context, conserve_sp=True)
        
        assert skill is not None
        assert skill.level == 5  # Lower level for conservation
    
    def test_count_clustered_enemies_none_found(self):
        """Test counting clustered enemies with target not found."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.nearby_monsters = []
        
        target = TargetPriority(actor_id=999, priority_score=100.0)
        
        count = tactics._count_clustered_enemies(context, target)
        
        assert count == 0
    
    def test_count_clustered_enemies_with_cluster(self):
        """Test counting clustered enemies."""
        tactics = MagicDPSTactics()
        
        # Target monster
        monster1 = Mock()
        monster1.actor_id = 100
        monster1.position = (150, 150)
        
        # Nearby monsters in cluster
        monster2 = Mock()
        monster2.actor_id = 101
        monster2.position = (152, 152)
        
        monster3 = Mock()
        monster3.actor_id = 102
        monster3.position = (148, 148)
        
        context = Mock()
        context.nearby_monsters = [monster1, monster2, monster3]
        
        target = TargetPriority(actor_id=100, priority_score=100.0)
        
        count = tactics._count_clustered_enemies(context, target)
        
        assert count >= 2  # At least target + nearby
    
    def test_find_monster_by_id_found(self):
        """Test finding monster by ID."""
        tactics = MagicDPSTactics()
        
        monster = Mock()
        monster.actor_id = 100
        
        context = Mock()
        context.nearby_monsters = [monster]
        
        found = tactics._find_monster_by_id(context, 100)
        
        assert found is not None
        assert found.actor_id == 100
    
    def test_find_monster_by_id_not_found(self):
        """Test finding non-existent monster."""
        tactics = MagicDPSTactics()
        
        context = Mock()
        context.nearby_monsters = []
        
        found = tactics._find_monster_by_id(context, 999)
        
        assert found is None
    
    def test_calculate_retreat_position(self):
        """Test calculating retreat position."""
        tactics = MagicDPSTactics()
        
        current = Position(x=100, y=100)
        threat = Position(x=105, y=105)
        
        retreat = tactics._calculate_retreat_position(current, threat)
        
        assert retreat.x < current.x  # Move away from threat
        assert retreat.y < current.y
    
    def test_get_skill_id_various_skills(self):
        """Test skill ID mapping."""
        tactics = MagicDPSTactics()
        
        assert tactics._get_skill_id("fire_bolt") == 19
        assert tactics._get_skill_id("storm_gust") == 89
        assert tactics._get_skill_id("unknown") == 0
    
    def test_get_sp_cost_various_skills(self):
        """Test SP cost mapping."""
        tactics = MagicDPSTactics()
        
        assert tactics._get_sp_cost("fire_bolt") == 12
        assert tactics._get_sp_cost("storm_gust") == 78
        assert tactics._get_sp_cost("unknown") == 15  # Default
    
    def test_get_cast_time_various_skills(self):
        """Test cast time mapping."""
        tactics = MagicDPSTactics()
        
        assert tactics._get_cast_time("fire_bolt") == 0.7
        assert tactics._get_cast_time("meteor_storm") == 15.0
        assert tactics._get_cast_time("unknown") == 1.0  # Default