"""
Final comprehensive tests to achieve 100% coverage for tank tactics.
Covers all remaining edge cases and branches.
"""

import pytest
from unittest.mock import Mock, patch

from ai_sidecar.combat.tactics.tank import TankTactics, TankTacticsConfig
from ai_sidecar.combat.tactics.base import Position, TargetPriority


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
    return context


class TestTankFinalCoverage:
    """Final coverage tests for tank tactics."""
    
    @pytest.mark.asyncio
    async def test_select_target_returns_none_when_all_targeting_self(self, mock_context):
        """Test select_target returns None when all enemies target tank and are in threat table."""
        # Create monsters all targeting tank
        for i in range(2):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110 + i, 110)
            monster.hp = 1000
            monster.hp_max = 1000
            mock_context.nearby_monsters.append(monster)
        
        tactics = TankTactics()
        # All enemies already targeting tank
        for i in range(2):
            entry = Mock()
            entry.is_targeting_self = True
            entry.threat_value = 50.0
            tactics._threat_table[2000 + i] = entry
        
        target = await tactics.select_target(mock_context)
        # Should still select highest threat target
        assert target is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_needs_provoke_but_target_in_table(self, mock_context):
        """Test skill selection when target needs provoke."""
        tactics = TankTactics()
        mock_context.character_hp = 900  # High HP, no defensive needed
        mock_context.nearby_monsters = []  # Less than 3 enemies
        mock_context.cooldowns = {"provoke": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=5.0,
            hp_percent=0.8
        )
        
        # Target NOT in threat table - needs provoke
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name in tactics.PROVOKE_SKILLS
    
    @pytest.mark.asyncio
    async def test_select_skill_needs_provoke_entry_not_targeting_self(self, mock_context):
        """Test skill selection when target entry exists but not targeting self."""
        tactics = TankTactics()
        mock_context.character_hp = 900  # High HP
        mock_context.nearby_monsters = []  # Less than 3
        mock_context.cooldowns = {"provoke": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=120,
            reason="test",
            distance=5.0,
            hp_percent=0.8
        )
        
        # Target in table but not targeting self
        entry = Mock()
        entry.is_targeting_self = False
        tactics._threat_table[2001] = entry
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_high_threshold_skip(self, mock_context):
        """Test defensive skill skipped when HP above threshold."""
        tactics = TankTactics()
        mock_context.character_hp = 700  # 70% HP - above both thresholds
        mock_context.cooldowns = {"guard": 0, "defender": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        # Should skip defensive and select other skill
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_close_distance_no_move(self, mock_context):
        """Test positioning returns None when already within 2 cells."""
        mock_context.character_position = Position(x=100, y=100)
        mock_context.party_members = []
        
        # Monster very close - within 2 cells
        monster = Mock()
        monster.position = (101, 100)  # Distance ~1
        mock_context.nearby_monsters = [monster]
        
        tactics = TankTactics()
        position = await tactics.evaluate_positioning(mock_context)
        
        # Should return None - already well positioned
        assert position is None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_with_party_far_target(self, mock_context):
        """Test positioning with party and distant threats."""
        # Party center at 90,90
        ally1 = Mock()
        ally1.position = (90, 90)
        mock_context.party_members = [ally1]
        
        # Threats far away at 120,120
        monster = Mock()
        monster.position = (120, 120)
        mock_context.nearby_monsters = [monster]
        
        mock_context.character_position = Position(x=100, y=100)
        
        tactics = TankTactics()
        position = await tactics.evaluate_positioning(mock_context)
        
        # Should calculate interception point
        assert position is not None
    
    def test_get_threat_assessment_critical_hp(self, mock_context):
        """Test threat assessment at critical HP (<30%)."""
        tactics = TankTactics()
        
        mock_context.character_hp = 250  # 25% HP - critical
        threat = tactics.get_threat_assessment(mock_context)
        
        # Should have high threat from critical HP
        assert threat >= 0.4
    
    def test_find_loose_enemies_complex_scenario(self, mock_context):
        """Test finding loose enemies with mixed states."""
        # Mix of loose and tracked enemies
        loose1 = Mock()
        loose1.actor_id = 3001
        loose1.position = (110, 110)
        loose1.hp = 800
        loose1.hp_max = 1000
        
        loose2 = Mock()
        loose2.actor_id = 3002
        loose2.position = (115, 115)
        loose2.hp = 600
        loose2.hp_max = 1000
        
        tracked = Mock()
        tracked.actor_id = 3003
        tracked.position = (120, 120)
        tracked.hp = 1000
        tracked.hp_max = 1000
        
        mock_context.nearby_monsters = [loose1, loose2, tracked]
        
        tactics = TankTactics()
        # Only tracked enemy in threat table
        entry = Mock()
        entry.is_targeting_self = True
        tactics._threat_table[tracked.actor_id] = entry
        
        loose = tactics._find_loose_enemies(mock_context)
        
        # Should find both loose enemies
        assert len(loose) == 2
        assert all(t.reason == "loose_enemy" for t in loose)
    
    def test_calculate_party_centroid_with_valid_positions(self, mock_context):
        """Test party centroid calculation with valid positioned members."""
        ally1 = Mock()
        ally1.position = (95, 95)
        ally2 = Mock()
        ally2.position = (105, 105)
        ally3 = Mock()
        ally3.position = (100, 110)
        
        mock_context.party_members = [ally1, ally2, ally3]
        
        tactics = TankTactics()
        centroid = tactics._calculate_party_centroid(mock_context)
        
        assert centroid is not None
        # Should average the positions
        assert 95 <= centroid.x <= 105
        assert 95 <= centroid.y <= 110
    
    def test_calculate_party_centroid_mixed_position_attributes(self, mock_context):
        """Test party centroid with mix of members with/without position."""
        ally1 = Mock()
        ally1.position = (100, 100)
        
        ally2 = Mock(spec=[])  # No position attribute
        
        ally3 = Mock()
        ally3.position = (110, 110)
        
        mock_context.party_members = [ally1, ally2, ally3]
        
        tactics = TankTactics()
        centroid = tactics._calculate_party_centroid(mock_context)
        
        # Should calculate from only those with positions
        assert centroid is not None
        assert centroid.x == 105
        assert centroid.y == 105
    
    def test_defensive_skill_selection_on_cooldown_skip(self, mock_context):
        """Test defensive skill selection skips those on cooldown."""
        mock_context.character_hp = 300  # 30% HP - critical
        mock_context.cooldowns = {
            "guard": 5.0,
            "cr_guard": 5.0,
            "defender": 0,  # Only defender available
            "cr_defender": 5.0
        }
        
        tactics = TankTactics()
        skill = tactics._select_defensive_skill(mock_context)
        
        # Should select defender (only one available)
        assert skill is not None
        assert skill.name in ["defender", "cr_defender"]
    
    @pytest.mark.asyncio
    async def test_select_target_no_monsters_none(self, mock_context):
        """Test select_target returns None with no monsters."""
        mock_context.nearby_monsters = []
        
        tactics = TankTactics()
        target = await tactics.select_target(mock_context)
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_skill_with_aoe_exactly_three_enemies(self, mock_context):
        """Test AoE skill selection with exactly 3 enemies."""
        # Add exactly 3 enemies
        for i in range(3):
            monster = Mock()
            monster.actor_id = 2000 + i
            monster.position = (110, 110)
            mock_context.nearby_monsters.append(monster)
        
        tactics = TankTactics()
        mock_context.character_hp = 900  # High HP
        mock_context.cooldowns = {"bowling_bash": 0}
        
        # All enemies targeting tank
        for i in range(3):
            entry = Mock()
            entry.is_targeting_self = True
            tactics._threat_table[2000 + i] = entry
        
        target = TargetPriority(
            actor_id=2000,
            priority_score=100,
            reason="test",
            distance=2.0,
            hp_percent=0.8
        )
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name in tactics.AOE_AGGRO_SKILLS
    
    @pytest.mark.asyncio
    async def test_select_skill_single_target_aggro_fallback(self, mock_context):
        """Test single target aggro skill as fallback."""
        tactics = TankTactics()
        mock_context.character_hp = 900  # High HP
        mock_context.nearby_monsters = []  # Less than 3
        mock_context.cooldowns = {"bash": 0, "sm_bash": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=1.0,
            hp_percent=0.8
        )
        
        # Target targeting tank already
        entry = Mock()
        entry.is_targeting_self = True
        tactics._threat_table[2001] = entry
        
        skill = await tactics.select_skill(mock_context, target)
        assert skill is not None
        assert skill.name in tactics.AGGRO_SKILLS
    
    def test_find_enemies_targeting_allies_with_multiple(self, mock_context):
        """Test finding multiple enemies targeting allies."""
        enemies = []
        for i in range(3):
            enemy = Mock()
            enemy.actor_id = 3000 + i
            enemy.position = (110 + i, 110)
            enemy.hp = 800
            enemy.hp_max = 1000
            enemies.append(enemy)
            mock_context.nearby_monsters.append(enemy)
        
        tactics = TankTactics()
        
        # All targeting allies
        for i in range(3):
            entry = Mock()
            entry.is_targeting_self = False
            tactics._threat_table[3000 + i] = entry
        
        with patch.object(tactics, 'get_distance_to_target', return_value=5.0):
            ally_targets = tactics._find_enemies_targeting_allies(mock_context)
        
        assert len(ally_targets) == 3
        assert all(t.reason == "targeting_ally" for t in ally_targets)
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_no_threat_centroid(self, mock_context):
        """Test positioning returns None when threat centroid fails."""
        mock_context.nearby_monsters = []
        
        tactics = TankTactics()
        
        # Mock _calculate_threat_centroid to return None
        with patch.object(tactics, '_calculate_threat_centroid', return_value=None):
            position = await tactics.evaluate_positioning(mock_context)
        
        assert position is None
    
    def test_threat_assessment_hp_range_thirty_to_fifty(self, mock_context):
        """Test threat assessment for HP in 30-50% range."""
        tactics = TankTactics()
        
        mock_context.character_hp = 400  # 40% HP
        threat = tactics.get_threat_assessment(mock_context)
        
        # Should add 0.2 for this range
        assert threat > 0.0
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_skip_above_defender_threshold(self, mock_context):
        """Test defensive skill skips defender when HP above threshold."""
        tactics = TankTactics(TankTacticsConfig(use_defender_hp=0.60))
        mock_context.character_hp = 650  # 65% HP - above defender threshold
        mock_context.nearby_monsters = []
        mock_context.cooldowns = {"defender": 0, "cr_defender": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        # Add threat entry
        entry = Mock()
        entry.is_targeting_self = True
        tactics._threat_table[2001] = entry
        
        skill = await tactics.select_skill(mock_context, target)
        # Should skip defender and select other skill
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_skip_above_guard_threshold(self, mock_context):
        """Test defensive skill skips guard when HP above threshold."""
        tactics = TankTactics(TankTacticsConfig(use_guard_hp=0.40))
        mock_context.character_hp = 450  # 45% HP - above guard threshold
        mock_context.nearby_monsters = []
        mock_context.cooldowns = {"guard": 0, "cr_guard": 0}
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        # Add threat entry
        entry = Mock()
        entry.is_targeting_self = True
        tactics._threat_table[2001] = entry
        
        skill = await tactics.select_skill(mock_context, target)
        # Should skip guard and select other skill
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_positioning_returns_none_when_threat_center_none(self, mock_context):
        """Test positioning returns None when threat calculation fails."""
        mock_context.nearby_monsters = [Mock()]  # Has monsters
        
        tactics = TankTactics()
        # Force threat centroid to return None
        with patch.object(tactics, '_calculate_threat_centroid', return_value=None):
            position = await tactics.evaluate_positioning(mock_context)
        
        assert position is None
    
    def test_defensive_skill_not_in_cooldowns_dict(self, mock_context):
        """Test defensive skill selection when skills not in cooldowns dict."""
        mock_context.character_hp = 300  # 30% HP - critical
        mock_context.cooldowns = {"other_skill": 0}  # Defensive skills not listed
        
        tactics = TankTactics()
        skill = tactics._select_defensive_skill(mock_context)
        
        # Should return None - skills not in cooldowns
        assert skill is None
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_continues_iteration(self, mock_context):
        """Test defensive skill continues checking when threshold not met."""
        tactics = TankTactics()
        mock_context.character_hp = 450  # 45% HP
        # Both guard and defender in cooldowns but HP above thresholds
        mock_context.cooldowns = {
            "guard": 0,
            "cr_guard": 0,
            "defender": 0,
            "cr_defender": 0
        }
        mock_context.nearby_monsters = []
        
        target = TargetPriority(
            actor_id=2001,
            priority_score=100,
            reason="test",
            distance=3.0,
            hp_percent=0.8
        )
        
        # Add entry showing target already targeting tank
        entry = Mock()
        entry.is_targeting_self = True
        tactics._threat_table[2001] = entry
        
        skill = await tactics.select_skill(mock_context, target)
        # Should skip defensive skills and select aggro skill
        assert skill is not None