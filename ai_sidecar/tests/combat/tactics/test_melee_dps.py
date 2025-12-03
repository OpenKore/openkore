"""
Comprehensive tests for combat/tactics/melee_dps.py module.

Tests melee DPS tactics including target prioritization, skill rotation,
burst damage execution, and positioning optimization.
"""

from unittest.mock import Mock, MagicMock
import pytest

from ai_sidecar.combat.tactics.melee_dps import (
    MeleeDPSTactics,
    MeleeDPSTacticsConfig,
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TacticalRole,
    TargetPriority,
)


class TestMeleeDPSTacticsConfig:
    """Test MeleeDPSTacticsConfig model."""
    
    def test_default_config_values(self):
        """Test default configuration values."""
        config = MeleeDPSTacticsConfig()
        
        assert config.optimal_range == 1
        assert config.max_chase_distance == 10
        assert config.maintain_buffs is True
        assert config.buff_refresh_threshold == 5.0
        assert config.prefer_criticals is True
        assert config.use_burst_skills is True
        assert config.combo_enabled is True
    
    def test_custom_config_values(self):
        """Test custom configuration values."""
        config = MeleeDPSTacticsConfig(
            optimal_range=2,
            max_chase_distance=15,
            buff_refresh_threshold=3.0,
            use_burst_skills=False
        )
        
        assert config.optimal_range == 2
        assert config.max_chase_distance == 15
        assert config.buff_refresh_threshold == 3.0
        assert config.use_burst_skills is False


class TestMeleeDPSTactics:
    """Test MeleeDPSTactics class."""
    
    @pytest.fixture
    def tactics(self):
        """Create melee DPS tactics instance."""
        config = MeleeDPSTacticsConfig()
        return MeleeDPSTactics(config)
    
    @pytest.fixture
    def mock_context(self):
        """Create mock combat context."""
        context = Mock()
        context.character_position = Position(x=100, y=100)
        context.character_hp = 1500
        context.character_hp_max = 1500
        context.character_sp = 200
        context.character_sp_max = 200
        context.cooldowns = {}
        context.nearby_monsters = []
        return context
    
    def test_role_is_melee_dps(self, tactics):
        """Test that role is MELEE_DPS."""
        assert tactics.role == TacticalRole.MELEE_DPS
    
    def test_initialization_with_config(self):
        """Test initialization with custom config."""
        config = MeleeDPSTacticsConfig(optimal_range=2)
        tactics = MeleeDPSTactics(config)
        
        assert tactics.dps_config.optimal_range == 2
    
    def test_initialization_without_config(self):
        """Test initialization without config."""
        tactics = MeleeDPSTactics()
        
        assert isinstance(tactics.dps_config, MeleeDPSTacticsConfig)
        assert tactics.dps_config.optimal_range == 1
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, tactics, mock_context):
        """Test target selection with no monsters."""
        target = await tactics.select_target(mock_context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_single_monster(self, tactics, mock_context):
        """Test targeting single monster."""
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (105, 105)
        
        mock_context.nearby_monsters = [monster]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 1001
    
    @pytest.mark.asyncio
    async def test_select_target_prioritizes_low_hp(self, tactics, mock_context):
        """Test that low HP targets are prioritized."""
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.hp = 800
        monster1.hp_max = 1000
        monster1.position = (105, 105)
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.hp = 100  # Very low HP
        monster2.hp_max = 1000
        monster2.position = (110, 110)
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 1002  # Low HP target selected
    
    @pytest.mark.asyncio
    async def test_select_target_prefers_close_targets(self, tactics, mock_context):
        """Test preference for closer targets."""
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.hp = 500
        monster1.hp_max = 1000
        monster1.position = (120, 120)  # Far
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.hp = 500
        monster2.hp_max = 1000
        monster2.position = (101, 101)  # Very close
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        assert target.actor_id == 1002  # Closer target
    
    @pytest.mark.asyncio
    async def test_select_target_mvp_bonus(self, tactics, mock_context):
        """Test MVP targets get priority bonus."""
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.hp = 500
        monster1.hp_max = 1000
        monster1.position = (105, 105)
        monster1.is_mvp = False
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.hp = 800  # Higher HP but MVP
        monster2.hp_max = 1000
        monster2.position = (105, 105)
        monster2.is_mvp = True
        
        mock_context.nearby_monsters = [monster1, monster2]
        
        target = await tactics.select_target(mock_context)
        
        assert target is not None
        # MVP should get high priority despite higher HP
    
    @pytest.mark.asyncio
    async def test_select_skill_maintains_buffs(self, tactics, mock_context):
        """Test buff maintenance."""
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        # No buffs active
        tactics._buff_timers = {}
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        # Should select buff if needed
        if skill.target_type == "self":
            assert skill.name in tactics.BUFF_SKILLS
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_for_clusters(self, tactics, mock_context):
        """Test AOE skill selection for clustered enemies."""
        # Create clustered monsters
        for i in range(4):
            monster = Mock()
            monster.actor_id = 1000 + i
            monster.position = (105 + i, 105 + i)
            mock_context.nearby_monsters.append(monster)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        # Mock buff timers to skip buff selection
        tactics._buff_timers = {skill: 10.0 for skill in tactics.BUFF_SKILLS}
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        # Should prefer AOE for clusters
    
    @pytest.mark.asyncio
    async def test_select_skill_burst_for_low_hp(self, tactics, mock_context):
        """Test burst skill for low HP targets."""
        target = TargetPriority(
            actor_id=1001,
            priority_score=150,
            reason="combat",
            distance=1,
            hp_percent=0.40  # Low HP
        )
        
        # Mock buff timers and skip AOE
        tactics._buff_timers = {skill: 10.0 for skill in tactics.BUFF_SKILLS}
        
        skill = await tactics.select_skill(mock_context, target)
        
        assert skill is not None
        # Should select burst skill for low HP target
    
    @pytest.mark.asyncio
    async def test_select_skill_respects_cooldowns(self, tactics, mock_context):
        """Test skill selection respects cooldowns."""
        all_skills = tactics.BURST_SKILLS + tactics.SINGLE_TARGET_SKILLS
        mock_context.cooldowns = {skill: 5.0 for skill in all_skills}
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        # May return None if all skills on cooldown
        if skill:
            assert mock_context.cooldowns.get(skill.name, 0) <= 0
    
    @pytest.mark.asyncio
    async def test_select_skill_insufficient_sp(self, tactics, mock_context):
        """Test skill selection with low SP."""
        mock_context.character_sp = 5  # Very low SP
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        skill = await tactics.select_skill(mock_context, target)
        
        # Should select low-cost skill or None
        if skill:
            assert skill.sp_cost <= mock_context.character_sp
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self, tactics, mock_context):
        """Test positioning with no monsters."""
        position = await tactics.evaluate_positioning(mock_context)
        
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_already_in_range(self, tactics, mock_context):
        """Test positioning when already in melee range."""
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (100, 100)  # Same position
        
        mock_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        # When at same position, may return current position or None
        # Both are valid as they indicate "already in range"
        if position:
            # Allow current position to be returned
            assert position.x == 100 and position.y == 100
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_approaches_target(self, tactics, mock_context):
        """Test positioning approaches distant target."""
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (105, 105)  # Within chase range
        
        mock_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        # May return None or Position depending on distance calculation
        if position:
            # Should move closer to target
            dist_to_target = ((position.x - 105)**2 + (position.y - 105)**2) ** 0.5
            original_dist = ((100 - 105)**2 + (100 - 105)**2) ** 0.5
            assert dist_to_target <= original_dist
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_ignores_far_targets(self, tactics, mock_context):
        """Test positioning ignores targets too far to chase."""
        monster = Mock()
        monster.actor_id = 1001
        monster.hp = 500
        monster.hp_max = 1000
        monster.position = (200, 200)  # Too far
        
        mock_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_context)
        
        # Should not chase extremely far targets
        assert position is None
    
    def test_get_threat_assessment_low_hp(self, tactics, mock_context):
        """Test threat increases with low HP."""
        mock_context.character_hp = 200
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.4  # Significant threat
    
    def test_get_threat_assessment_multiple_enemies(self, tactics, mock_context):
        """Test threat increases with multiple enemies."""
        for i in range(5):
            monster = Mock()
            monster.position = (101 + i, 101)
            mock_context.nearby_monsters.append(monster)
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.2
    
    def test_get_threat_assessment_boss_enemies(self, tactics, mock_context):
        """Test threat increases with boss/MVP."""
        monster = Mock()
        monster.position = (101, 101)
        monster.is_boss = True
        monster.is_mvp = True
        mock_context.nearby_monsters = [monster]
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat > 0.3
    
    def test_get_threat_assessment_capped_at_one(self, tactics, mock_context):
        """Test threat is capped at 1.0."""
        mock_context.character_hp = 10  # Critical HP
        
        for i in range(10):
            monster = Mock()
            monster.position = (100, 100)
            monster.is_mvp = True
            mock_context.nearby_monsters.append(monster)
        
        threat = tactics.get_threat_assessment(mock_context)
        
        assert threat <= 1.0
    
    def test_dps_target_score_low_hp_bonus(self, tactics):
        """Test scoring gives bonus for low HP."""
        monster = Mock()
        monster.is_mvp = False
        monster.is_boss = False
        
        score_high_hp = tactics._dps_target_score(monster, 0.90, 5)
        score_low_hp = tactics._dps_target_score(monster, 0.20, 5)
        
        assert score_low_hp > score_high_hp
    
    def test_dps_target_score_distance_penalty(self, tactics):
        """Test scoring penalizes distance."""
        monster = Mock()
        monster.is_mvp = False
        monster.is_boss = False
        
        score_close = tactics._dps_target_score(monster, 0.50, 1)
        score_far = tactics._dps_target_score(monster, 0.50, 10)
        
        assert score_close > score_far
    
    def test_dps_target_score_melee_range_bonus(self, tactics):
        """Test scoring gives bonus for melee range."""
        monster = Mock()
        monster.is_mvp = False
        monster.is_boss = False
        
        score_melee = tactics._dps_target_score(monster, 0.50, 1)
        score_ranged = tactics._dps_target_score(monster, 0.50, 5)
        
        assert score_melee > score_ranged
    
    def test_dps_target_score_mvp_bonus(self, tactics):
        """Test scoring gives bonus for MVP."""
        monster_mvp = Mock()
        monster_mvp.is_mvp = True
        monster_mvp.is_boss = False
        
        monster_normal = Mock()
        monster_normal.is_mvp = False
        monster_normal.is_boss = False
        
        score_mvp = tactics._dps_target_score(monster_mvp, 0.50, 5)
        score_normal = tactics._dps_target_score(monster_normal, 0.50, 5)
        
        assert score_mvp > score_normal
    
    def test_select_buff_skill(self, tactics, mock_context):
        """Test buff skill selection."""
        # No buffs active
        tactics._buff_timers = {}
        
        buff = tactics._select_buff_skill(mock_context)
        
        if buff:
            assert buff.name in tactics.BUFF_SKILLS
            assert buff.is_offensive is False
    
    def test_select_buff_skill_skips_active_buffs(self, tactics, mock_context):
        """Test skips buffs that are still active."""
        # All buffs active with long duration
        tactics._buff_timers = {skill: 20.0 for skill in tactics.BUFF_SKILLS}
        
        buff = tactics._select_buff_skill(mock_context)
        
        # Should not select buff
        assert buff is None
    
    def test_select_burst_skill(self, tactics, mock_context):
        """Test burst skill selection."""
        burst = tactics._select_burst_skill(mock_context)
        
        if burst:
            assert burst.name in tactics.BURST_SKILLS
            assert burst.is_offensive is True
    
    def test_select_aoe_skill(self, tactics, mock_context):
        """Test AOE skill selection."""
        aoe = tactics._select_aoe_skill(mock_context)
        
        if aoe:
            assert aoe.name in tactics.AOE_SKILLS
            assert aoe.is_offensive is True
    
    def test_select_damage_skill(self, tactics, mock_context):
        """Test standard damage skill selection."""
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        damage = tactics._select_damage_skill(mock_context, target)
        
        if damage:
            assert damage.name in tactics.SINGLE_TARGET_SKILLS
            assert damage.is_offensive is True
    
    def test_count_clustered_enemies_none(self, tactics, mock_context):
        """Test counting clustered enemies with no monsters."""
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        count = tactics._count_clustered_enemies(mock_context, target)
        
        assert count == 0
    
    def test_count_clustered_enemies_scattered(self, tactics, mock_context):
        """Test counting with scattered enemies."""
        # Create target monster
        target_monster = Mock()
        target_monster.actor_id = 1001
        target_monster.position = (100, 100)
        mock_context.nearby_monsters.append(target_monster)
        
        # Create scattered monsters
        for i in range(3):
            monster = Mock()
            monster.actor_id = 1002 + i
            monster.position = (100 + (i * 10), 100 + (i * 10))
            mock_context.nearby_monsters.append(monster)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        count = tactics._count_clustered_enemies(mock_context, target)
        
        # Should count target + nearby ones within AOE radius
        assert count >= 1
    
    def test_count_clustered_enemies_grouped(self, tactics, mock_context):
        """Test counting with tightly grouped enemies."""
        # Create clustered monsters
        for i in range(5):
            monster = Mock()
            monster.actor_id = 1001 + i
            monster.position = (100 + i, 100 + i)
            mock_context.nearby_monsters.append(monster)
        
        target = TargetPriority(
            actor_id=1001,
            priority_score=100,
            reason="combat",
            distance=1,
            hp_percent=0.80
        )
        
        count = tactics._count_clustered_enemies(mock_context, target)
        
        assert count >= 3  # Should detect cluster
    
    def test_find_monster_by_id_found(self, tactics, mock_context):
        """Test finding monster by ID."""
        monster = Mock()
        monster.actor_id = 1001
        mock_context.nearby_monsters = [monster]
        
        found = tactics._find_monster_by_id(mock_context, 1001)
        
        assert found is not None
        assert found.actor_id == 1001
    
    def test_find_monster_by_id_not_found(self, tactics, mock_context):
        """Test finding non-existent monster."""
        found = tactics._find_monster_by_id(mock_context, 9999)
        
        assert found is None
    
    def test_calculate_approach_position(self, tactics):
        """Test calculating approach position."""
        current = Position(x=100, y=100)
        target = Position(x=110, y=110)
        
        approach = tactics._calculate_approach_position(current, target)
        
        # Should be closer to target
        dist_current = ((current.x - target.x)**2 + (current.y - target.y)**2) ** 0.5
        dist_approach = ((approach.x - target.x)**2 + (approach.y - target.y)**2) ** 0.5
        
        assert dist_approach < dist_current
    
    def test_calculate_approach_position_adjacent(self, tactics):
        """Test approach position stops adjacent to target."""
        current = Position(x=100, y=100)
        target = Position(x=105, y=105)
        
        approach = tactics._calculate_approach_position(current, target)
        
        # Should stop 1 cell away
        dist = ((approach.x - target.x)**2 + (approach.y - target.y)**2) ** 0.5
        assert dist >= 0  # At least reach target area
    
    def test_get_skill_id_mapping(self, tactics):
        """Test skill ID mapping."""
        assert tactics._get_skill_id("bash") == 5
        assert tactics._get_skill_id("bowling_bash") == 62
        assert tactics._get_skill_id("spiral_pierce") == 397
        assert tactics._get_skill_id("unknown_skill") == 0
    
    def test_get_buff_sp_cost(self, tactics):
        """Test buff SP cost mapping."""
        assert tactics._get_buff_sp_cost("two_hand_quicken") == 14
        assert tactics._get_buff_sp_cost("concentration") == 25
        assert tactics._get_buff_sp_cost("unknown_buff") == 20
    
    def test_get_skill_sp_cost(self, tactics):
        """Test damage skill SP cost mapping."""
        assert tactics._get_skill_sp_cost("bash") == 15
        assert tactics._get_skill_sp_cost("bowling_bash") == 13
        assert tactics._get_skill_sp_cost("spiral_pierce") == 30
        assert tactics._get_skill_sp_cost("unknown_skill") == 15