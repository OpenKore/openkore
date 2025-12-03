"""
Comprehensive test suite for Ranged DPS Tactics.

Tests ranged combat tactics including kiting, trap deployment,
target selection, positioning, and skill selection.
"""

from unittest.mock import Mock, patch

import pytest

from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TacticalRole,
    TargetPriority,
)
from ai_sidecar.combat.tactics.ranged_dps import (
    RangedDPSTactics,
    RangedDPSTacticsConfig,
)


@pytest.fixture
def ranged_config():
    """Create ranged DPS tactics config."""
    return RangedDPSTacticsConfig(
        optimal_range=9,
        min_safe_distance=4,
        kiting_enabled=True,
        use_traps=True,
        element_matching=True,
        prefer_single_target=True
    )


@pytest.fixture
def ranged_tactics(ranged_config):
    """Create ranged DPS tactics instance."""
    return RangedDPSTactics(ranged_config)


@pytest.fixture
def mock_combat_context():
    """Create mock combat context."""
    context = Mock()
    context.character_hp = 5000
    context.character_hp_max = 8000
    context.character_sp = 300
    context.character_sp_max = 500
    context.character_position = Position(x=100, y=100)
    context.nearby_monsters = []
    context.cooldowns = {}
    return context


@pytest.fixture
def mock_monster():
    """Create mock monster."""
    monster = Mock()
    monster.actor_id = 1001
    monster.position = (110, 110)
    monster.hp = 1000
    monster.hp_max = 2000
    monster.is_mvp = False
    monster.is_boss = False
    return monster


# ==================== Configuration Tests ====================


class TestRangedDPSTacticsConfig:
    """Test ranged DPS tactics configuration."""
    
    def test_default_config(self):
        """Test default configuration values."""
        config = RangedDPSTacticsConfig()
        
        assert config.optimal_range == 9
        assert config.min_safe_distance == 4
        assert config.kiting_enabled is True
        assert config.use_traps is True
        assert config.element_matching is True
        assert config.prefer_single_target is True
    
    def test_custom_config(self):
        """Test custom configuration."""
        config = RangedDPSTacticsConfig(
            optimal_range=7,
            min_safe_distance=3,
            kiting_enabled=False,
            use_traps=False
        )
        
        assert config.optimal_range == 7
        assert config.min_safe_distance == 3
        assert config.kiting_enabled is False
        assert config.use_traps is False


# ==================== Initialization Tests ====================


class TestRangedDPSTacticsInit:
    """Test ranged DPS tactics initialization."""
    
    def test_initialization(self, ranged_tactics):
        """Test tactics initialization."""
        assert ranged_tactics.role == TacticalRole.RANGED_DPS
        assert ranged_tactics.ranged_config is not None
        assert ranged_tactics._deployed_traps == []
        assert ranged_tactics._kiting_direction == (0, 0)
    
    def test_skill_lists(self, ranged_tactics):
        """Test skill list constants."""
        assert len(ranged_tactics.PRIMARY_SKILLS) > 0
        assert len(ranged_tactics.SINGLE_TARGET_SKILLS) > 0
        assert len(ranged_tactics.AOE_SKILLS) > 0
        assert len(ranged_tactics.TRAP_SKILLS) > 0
        assert len(ranged_tactics.BUFF_SKILLS) > 0
    
    def test_initialization_without_config(self):
        """Test initialization without config."""
        tactics = RangedDPSTactics()
        
        assert tactics.ranged_config is not None
        assert isinstance(tactics.ranged_config, RangedDPSTacticsConfig)


# ==================== Target Selection Tests ====================


class TestTargetSelection:
    """Test target selection logic."""
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters(self, ranged_tactics, mock_combat_context):
        """Test target selection with no monsters."""
        target = await ranged_tactics.select_target(mock_combat_context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_single_monster(self, ranged_tactics, mock_combat_context, mock_monster):
        """Test target selection with single monster."""
        mock_combat_context.nearby_monsters = [mock_monster]
        
        with patch.object(ranged_tactics, 'prioritize_targets') as mock_prioritize:
            mock_target = TargetPriority(
                actor_id=1001,
                priority_score=100.0,
                distance=10.0,
                hp_percent=0.5
            )
            mock_prioritize.return_value = [mock_target]
            
            target = await ranged_tactics.select_target(mock_combat_context)
            
            assert target is not None
            assert target.actor_id == 1001
    
    @pytest.mark.asyncio
    async def test_select_target_multiple_monsters(self, ranged_tactics, mock_combat_context):
        """Test target selection with multiple monsters."""
        monster1 = Mock()
        monster1.actor_id = 1001
        monster1.position = (105, 105)
        monster1.hp = 500
        monster1.hp_max = 1000
        
        monster2 = Mock()
        monster2.actor_id = 1002
        monster2.position = (120, 120)
        monster2.hp = 1500
        monster2.hp_max = 2000
        
        mock_combat_context.nearby_monsters = [monster1, monster2]
        
        with patch.object(ranged_tactics, 'prioritize_targets') as mock_prioritize:
            targets = [
                TargetPriority(actor_id=1001, priority_score=150.0, distance=7.0, hp_percent=0.5),
                TargetPriority(actor_id=1002, priority_score=120.0, distance=25.0, hp_percent=0.75)
            ]
            mock_prioritize.return_value = targets
            
            target = await ranged_tactics.select_target(mock_combat_context)
            
            assert target is not None
            assert target.actor_id == 1001  # Closest with lower HP
    
    def test_ranged_target_score_optimal_range(self, ranged_tactics, mock_monster):
        """Test target scoring at optimal range."""
        score = ranged_tactics._ranged_target_score(mock_monster, hp_percent=0.5, distance=7.0)
        
        # Should get optimal range bonus
        assert score > 100
    
    def test_ranged_target_score_too_close(self, ranged_tactics, mock_monster):
        """Test target scoring too close."""
        score = ranged_tactics._ranged_target_score(mock_monster, hp_percent=0.5, distance=2.0)
        
        # Should get penalty for being too close
        assert score < 100
    
    def test_ranged_target_score_too_far(self, ranged_tactics, mock_monster):
        """Test target scoring too far."""
        score = ranged_tactics._ranged_target_score(mock_monster, hp_percent=0.5, distance=15.0)
        
        # Should get penalty for being too far
        assert score < 100
    
    def test_ranged_target_score_low_hp(self, ranged_tactics, mock_monster):
        """Test target scoring with low HP."""
        score_high_hp = ranged_tactics._ranged_target_score(mock_monster, hp_percent=0.9, distance=7.0)
        score_low_hp = ranged_tactics._ranged_target_score(mock_monster, hp_percent=0.1, distance=7.0)
        
        # Lower HP should score higher
        assert score_low_hp > score_high_hp
    
    def test_ranged_target_score_mvp_bonus(self, ranged_tactics):
        """Test target scoring with MVP bonus."""
        mvp_monster = Mock()
        mvp_monster.is_mvp = True
        mvp_monster.is_boss = False
        
        normal_monster = Mock()
        normal_monster.is_mvp = False
        normal_monster.is_boss = False
        
        normal_score = ranged_tactics._ranged_target_score(normal_monster, hp_percent=0.5, distance=7.0)
        mvp_score = ranged_tactics._ranged_target_score(mvp_monster, hp_percent=0.5, distance=7.0)
        
        # MVP should score higher
        assert mvp_score > normal_score
    
    def test_ranged_target_score_boss_bonus(self, ranged_tactics):
        """Test target scoring with boss bonus."""
        boss_monster = Mock()
        boss_monster.is_mvp = False
        boss_monster.is_boss = True
        
        normal_monster = Mock()
        normal_monster.is_mvp = False
        normal_monster.is_boss = False
        
        normal_score = ranged_tactics._ranged_target_score(normal_monster, hp_percent=0.5, distance=7.0)
        boss_score = ranged_tactics._ranged_target_score(boss_monster, hp_percent=0.5, distance=7.0)
        
        # Boss should score higher
        assert boss_score > normal_score


# ==================== Skill Selection Tests ====================


class TestSkillSelection:
    """Test skill selection logic."""
    
    @pytest.mark.asyncio
    async def test_select_skill_buff_needed(self, ranged_tactics, mock_combat_context):
        """Test skill selection when buff needed."""
        target = TargetPriority(actor_id=1001, priority_score=100.0, distance=7.0, hp_percent=0.5)
        
        with patch.object(ranged_tactics, '_select_buff_skill') as mock_buff:
            mock_buff.return_value = Skill(
                id=45,
                name="improve_concentration",
                level=10,
                sp_cost=40,
                cooldown=0,
                range=0,
                target_type="self",
                is_offensive=False
            )
            
            skill = await ranged_tactics.select_skill(mock_combat_context, target)
            
            assert skill is not None
            assert skill.name == "improve_concentration"
    
    @pytest.mark.asyncio
    async def test_select_skill_trap_enemy_close(self, ranged_tactics, mock_combat_context):
        """Test skill selection deploys trap when enemy close."""
        target = TargetPriority(actor_id=1001, priority_score=100.0, distance=3.0, hp_percent=0.5)
        
        with patch.object(ranged_tactics, '_select_buff_skill', return_value=None):
            with patch.object(ranged_tactics, '_select_trap_skill') as mock_trap:
                mock_trap.return_value = Skill(
                    id=116,
                    name="ankle_snare",
                    level=5,
                    sp_cost=12,
                    cooldown=0,
                    range=3,
                    target_type="ground",
                    is_offensive=True
                )
                
                skill = await ranged_tactics.select_skill(mock_combat_context, target)
                
                assert skill is not None
                assert skill.name == "ankle_snare"
    
    @pytest.mark.asyncio
    async def test_select_skill_aoe_clustered(self, mock_combat_context):
        """Test skill selection uses AoE for clustered enemies."""
        # Create new config with AoE preference
        aoe_config = RangedDPSTacticsConfig(prefer_single_target=False)
        tactics = RangedDPSTactics(aoe_config)
        
        target = TargetPriority(actor_id=1001, priority_score=100.0, distance=7.0, hp_percent=0.5)
        
        with patch.object(tactics, '_select_buff_skill', return_value=None):
            with patch.object(tactics, '_count_clustered_enemies', return_value=5):
                with patch.object(tactics, '_select_aoe_skill') as mock_aoe:
                    mock_aoe.return_value = Skill(
                        id=47,
                        name="arrow_shower",
                        level=10,
                        sp_cost=15,
                        cooldown=0,
                        range=9,
                        target_type="ground",
                        is_offensive=True
                    )
                    
                    skill = await tactics.select_skill(mock_combat_context, target)
                    
                    assert skill is not None
                    assert skill.name == "arrow_shower"
    
    @pytest.mark.asyncio
    async def test_select_skill_single_target(self, ranged_tactics, mock_combat_context):
        """Test skill selection uses single target damage."""
        target = TargetPriority(actor_id=1001, priority_score=100.0, distance=7.0, hp_percent=0.5)
        
        with patch.object(ranged_tactics, '_select_buff_skill', return_value=None):
            with patch.object(ranged_tactics, '_count_clustered_enemies', return_value=1):
                with patch.object(ranged_tactics, '_select_damage_skill') as mock_damage:
                    mock_damage.return_value = Skill(
                        id=46,
                        name="double_strafe",
                        level=10,
                        sp_cost=12,
                        cooldown=0,
                        range=9,
                        target_type="single",
                        is_offensive=True
                    )
                    
                    skill = await ranged_tactics.select_skill(mock_combat_context, target)
                    
                    assert skill is not None
                    assert skill.name == "double_strafe"
    
    def test_select_buff_skill(self, ranged_tactics, mock_combat_context):
        """Test buff skill selection."""
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
            buff = ranged_tactics._select_buff_skill(mock_combat_context)
            
            assert buff is not None
            assert buff.name in ranged_tactics.BUFF_SKILLS
    
    def test_select_trap_skill(self, ranged_tactics, mock_combat_context):
        """Test trap skill selection."""
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
            trap = ranged_tactics._select_trap_skill(mock_combat_context)
            
            assert trap is not None
            assert trap.name in ranged_tactics.TRAP_SKILLS
    
    def test_select_trap_skill_disabled(self, mock_combat_context):
        """Test trap skill selection when traps disabled."""
        # Create new config with traps disabled
        no_trap_config = RangedDPSTacticsConfig(use_traps=False)
        tactics = RangedDPSTactics(no_trap_config)
        
        trap = tactics._select_trap_skill(mock_combat_context)
        
        assert trap is None
    
    def test_select_aoe_skill(self, ranged_tactics, mock_combat_context):
        """Test AoE skill selection."""
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
            aoe = ranged_tactics._select_aoe_skill(mock_combat_context)
            
            assert aoe is not None
            assert aoe.name in ranged_tactics.AOE_SKILLS
    
    def test_select_damage_skill(self, ranged_tactics, mock_combat_context):
        """Test damage skill selection."""
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
            damage = ranged_tactics._select_damage_skill(mock_combat_context)
            
            assert damage is not None
            assert damage.name in ranged_tactics.SINGLE_TARGET_SKILLS


# ==================== Positioning Tests ====================


class TestPositioning:
    """Test positioning logic."""
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_monsters(self, ranged_tactics, mock_combat_context):
        """Test positioning with no monsters."""
        position = await ranged_tactics.evaluate_positioning(mock_combat_context)
        
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_enemy_too_close(self, ranged_tactics, mock_combat_context, mock_monster):
        """Test positioning kites when enemy too close."""
        mock_monster.position = (102, 102)  # Very close
        mock_combat_context.nearby_monsters = [mock_monster]
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=2.8):
            position = await ranged_tactics.evaluate_positioning(mock_combat_context)
            
            assert position is not None
            # Should move away
            assert position.x != 100 or position.y != 100
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_enemy_too_far(self, ranged_tactics, mock_combat_context, mock_monster):
        """Test positioning approaches when enemy too far."""
        mock_monster.position = (130, 130)  # Far away
        mock_combat_context.nearby_monsters = [mock_monster]
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=42.4):
            position = await ranged_tactics.evaluate_positioning(mock_combat_context)
            
            assert position is not None
            # Should move closer
            assert position.x != 100 or position.y != 100
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_optimal_range(self, ranged_tactics, mock_combat_context, mock_monster):
        """Test positioning stays at optimal range."""
        mock_monster.position = (107, 107)  # Good range
        mock_combat_context.nearby_monsters = [mock_monster]
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=7.0):
            position = await ranged_tactics.evaluate_positioning(mock_combat_context)
            
            # No repositioning needed
            assert position is None
    
    def test_calculate_kite_position(self, ranged_tactics):
        """Test kite position calculation."""
        current = Position(x=100, y=100)
        threat = Position(x=105, y=105)
        
        new_pos = ranged_tactics._calculate_kite_position(current, threat)
        
        # Should move away from threat
        assert new_pos.x < current.x or new_pos.y < current.y
        
        # Calculate distance moved
        dist = ((new_pos.x - current.x)**2 + (new_pos.y - current.y)**2)**0.5
        assert dist > 0
    
    def test_calculate_approach_position(self, ranged_tactics):
        """Test approach position calculation."""
        current = Position(x=100, y=100)
        target = Position(x=120, y=120)
        
        new_pos = ranged_tactics._calculate_approach_position(current, target)
        
        # Should move closer to target
        assert new_pos.x > current.x or new_pos.y > current.y
    
    def test_calculate_approach_already_close(self, ranged_tactics):
        """Test approach when already close enough."""
        current = Position(x=100, y=100)
        target = Position(x=108, y=108)
        
        new_pos = ranged_tactics._calculate_approach_position(current, target)
        
        # Should move slightly closer to optimal range
        # Distance is ~11.3, which is beyond optimal (9), so it will approach
        assert new_pos.x >= current.x and new_pos.y >= current.y


# ==================== Threat Assessment Tests ====================


class TestThreatAssessment:
    """Test threat assessment logic."""
    
    def test_threat_assessment_high_hp(self, ranged_tactics, mock_combat_context):
        """Test threat assessment with high HP."""
        mock_combat_context.character_hp = 7000
        mock_combat_context.character_hp_max = 8000
        
        threat = ranged_tactics.get_threat_assessment(mock_combat_context)
        
        # High HP = low threat
        assert threat < 0.3
    
    def test_threat_assessment_low_hp(self, ranged_tactics, mock_combat_context):
        """Test threat assessment with low HP."""
        mock_combat_context.character_hp = 1500
        mock_combat_context.character_hp_max = 8000
        
        threat = ranged_tactics.get_threat_assessment(mock_combat_context)
        
        # Low HP = high threat
        assert threat > 0.4
    
    def test_threat_assessment_enemies_close(self, ranged_tactics, mock_combat_context):
        """Test threat assessment with enemies close."""
        mock_combat_context.character_hp = 6000
        mock_combat_context.character_hp_max = 8000
        
        monsters = []
        for i in range(3):
            m = Mock()
            m.position = (102 + i, 102 + i)
            monsters.append(m)
        
        mock_combat_context.nearby_monsters = monsters
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=3.0):
            threat = ranged_tactics.get_threat_assessment(mock_combat_context)
            
            # Multiple close enemies = higher threat
            assert threat > 0.3
    
    def test_threat_assessment_surrounded(self, ranged_tactics, mock_combat_context):
        """Test threat assessment when surrounded."""
        mock_combat_context.character_hp = 2000  # Low HP for higher threat
        mock_combat_context.character_hp_max = 8000
        
        # Place enemies in all quadrants
        monsters = [
            Mock(position=(105, 105)),  # NE
            Mock(position=(105, 95)),   # SE
            Mock(position=(95, 95)),    # SW
            Mock(position=(95, 105)),   # NW
        ]
        mock_combat_context.nearby_monsters = monsters
        
        with patch.object(ranged_tactics, '_is_surrounded', return_value=True):
            with patch.object(ranged_tactics, 'get_distance_to_target', return_value=5.0):
                threat = ranged_tactics.get_threat_assessment(mock_combat_context)
                
                # Surrounded with low HP increases threat
                assert threat > 0.2  # Base HP threat (0.75) * 0.3 + surrounded bonus
    
    def test_is_surrounded_quadrants(self, ranged_tactics, mock_combat_context):
        """Test surrounded detection."""
        # Place enemies in 3 quadrants
        monsters = [
            Mock(position=(105, 105)),  # NE
            Mock(position=(105, 95)),   # SE
            Mock(position=(95, 95)),    # SW
        ]
        mock_combat_context.nearby_monsters = monsters
        
        with patch.object(ranged_tactics, 'get_distance_to_target', side_effect=[3.0, 3.0, 3.0]):
            surrounded = ranged_tactics._is_surrounded(mock_combat_context)
            
            assert surrounded is True
    
    def test_is_not_surrounded(self, ranged_tactics, mock_combat_context):
        """Test not surrounded."""
        # Only enemies on one side
        monsters = [
            Mock(position=(105, 105)),  # NE
            Mock(position=(106, 106)),  # NE
        ]
        mock_combat_context.nearby_monsters = monsters
        
        with patch.object(ranged_tactics, 'get_distance_to_target', side_effect=[3.0, 3.0]):
            surrounded = ranged_tactics._is_surrounded(mock_combat_context)
            
            assert surrounded is False


# ==================== Helper Method Tests ====================


class TestHelperMethods:
    """Test helper methods."""
    
    def test_count_clustered_enemies(self, ranged_tactics, mock_combat_context):
        """Test counting clustered enemies."""
        target = TargetPriority(actor_id=1001, priority_score=100.0, distance=7.0, hp_percent=0.5)
        
        # Create monster at target position
        target_monster = Mock()
        target_monster.actor_id = 1001
        target_monster.position = (110, 110)
        
        # Create nearby monsters
        nearby1 = Mock()
        nearby1.actor_id = 1002
        nearby1.position = (111, 111)  # Distance ~1.4
        
        nearby2 = Mock()
        nearby2.actor_id = 1003
        nearby2.position = (112, 112)  # Distance ~2.8
        
        far = Mock()
        far.actor_id = 1004
        far.position = (120, 120)  # Distance ~14
        
        mock_combat_context.nearby_monsters = [target_monster, nearby1, nearby2, far]
        
        count = ranged_tactics._count_clustered_enemies(mock_combat_context, target)
        
        # Should count target + 2 nearby (not far one)
        assert count == 3
    
    def test_count_clustered_target_not_found(self, ranged_tactics, mock_combat_context):
        """Test counting when target not found."""
        target = TargetPriority(actor_id=9999, priority_score=100.0, distance=7.0, hp_percent=0.5)
        
        count = ranged_tactics._count_clustered_enemies(mock_combat_context, target)
        
        assert count == 0
    
    def test_get_skill_id(self, ranged_tactics):
        """Test getting skill IDs."""
        assert ranged_tactics._get_skill_id("double_strafe") == 46
        assert ranged_tactics._get_skill_id("arrow_shower") == 47
        assert ranged_tactics._get_skill_id("blitz_beat") == 129
        assert ranged_tactics._get_skill_id("unknown_skill") == 0
    
    def test_get_sp_cost(self, ranged_tactics):
        """Test getting skill SP costs."""
        assert ranged_tactics._get_sp_cost("double_strafe") == 12
        assert ranged_tactics._get_sp_cost("arrow_shower") == 15
        assert ranged_tactics._get_sp_cost("improve_concentration") == 40
        assert ranged_tactics._get_sp_cost("unknown_skill") == 15  # Default


# ==================== Integration Tests ====================


class TestRangedDPSIntegration:
    """Test integration scenarios."""
    
    @pytest.mark.asyncio
    async def test_complete_combat_cycle_kiting(self, ranged_tactics, mock_combat_context):
        """Test complete combat cycle with kiting."""
        # Enemy approaches
        enemy = Mock()
        enemy.actor_id = 1001
        enemy.position = (102, 102)
        enemy.hp = 1000
        enemy.hp_max = 2000
        enemy.is_mvp = False
        enemy.is_boss = False
        
        mock_combat_context.nearby_monsters = [enemy]
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=2.8):
            # Should kite
            position = await ranged_tactics.evaluate_positioning(mock_combat_context)
            assert position is not None
            
            # Select target
            with patch.object(ranged_tactics, 'prioritize_targets') as mock_prioritize:
                mock_prioritize.return_value = [
                    TargetPriority(actor_id=1001, priority_score=100.0, distance=2.8, hp_percent=0.5)
                ]
                target = await ranged_tactics.select_target(mock_combat_context)
                assert target is not None
                
                # Select skill (should use trap)
                with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
                    skill = await ranged_tactics.select_skill(mock_combat_context, target)
                    assert skill is not None
    
    @pytest.mark.asyncio
    async def test_complete_combat_cycle_optimal_range(self, ranged_tactics, mock_combat_context):
        """Test complete combat cycle at optimal range."""
        # Enemy at good range
        enemy = Mock()
        enemy.actor_id = 1001
        enemy.position = (107, 107)
        enemy.hp = 500
        enemy.hp_max = 2000
        enemy.is_mvp = False
        enemy.is_boss = False
        
        mock_combat_context.nearby_monsters = [enemy]
        mock_combat_context.cooldowns = {}
        
        with patch.object(ranged_tactics, 'get_distance_to_target', return_value=7.0):
            # Should not reposition
            position = await ranged_tactics.evaluate_positioning(mock_combat_context)
            assert position is None
            
            # Select target
            with patch.object(ranged_tactics, 'prioritize_targets') as mock_prioritize:
                mock_prioritize.return_value = [
                    TargetPriority(actor_id=1001, priority_score=150.0, distance=7.0, hp_percent=0.25)
                ]
                target = await ranged_tactics.select_target(mock_combat_context)
                assert target is not None
                
                # Select skill (should use damage skill)
                with patch.object(ranged_tactics, '_select_buff_skill', return_value=None):
                    with patch.object(ranged_tactics, 'can_use_skill', return_value=True):
                        with patch.object(ranged_tactics, '_count_clustered_enemies', return_value=1):
                            skill = await ranged_tactics.select_skill(mock_combat_context, target)
                            assert skill is not None
                            assert skill.name in ranged_tactics.SINGLE_TARGET_SKILLS
    
    @pytest.mark.asyncio
    async def test_complete_combat_cycle_aoe_group(self, mock_combat_context):
        """Test complete combat cycle with enemy group."""
        # Create config with AoE preference
        aoe_config = RangedDPSTacticsConfig(prefer_single_target=False)
        tactics = RangedDPSTactics(aoe_config)
        
        # Multiple clustered enemies
        enemies = []
        for i in range(5):
            enemy = Mock()
            enemy.actor_id = 1001 + i
            enemy.position = (107 + i, 107 + i)
            enemy.hp = 1000
            enemy.hp_max = 2000
            enemy.is_mvp = False
            enemy.is_boss = False
            enemies.append(enemy)
        
        mock_combat_context.nearby_monsters = enemies
        mock_combat_context.cooldowns = {}
        
        with patch.object(tactics, 'get_distance_to_target', return_value=7.0):
            # Select target
            with patch.object(tactics, 'prioritize_targets') as mock_prioritize:
                mock_prioritize.return_value = [
                    TargetPriority(actor_id=1001, priority_score=150.0, distance=7.0, hp_percent=0.5)
                ]
                target = await tactics.select_target(mock_combat_context)
                assert target is not None
                
                # Select skill (should use AoE)
                with patch.object(tactics, '_select_buff_skill', return_value=None):
                    with patch.object(tactics, 'can_use_skill', return_value=True):
                        with patch.object(tactics, '_count_clustered_enemies', return_value=5):
                            skill = await tactics.select_skill(mock_combat_context, target)
                            assert skill is not None
                            assert skill.name in tactics.AOE_SKILLS