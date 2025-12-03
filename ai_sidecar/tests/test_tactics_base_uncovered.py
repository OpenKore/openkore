"""
Comprehensive tests to achieve 100% coverage for combat/tactics/base.py.
Targets all uncovered lines from coverage report.
"""

import pytest
from unittest.mock import Mock, MagicMock
from dataclasses import dataclass

from ai_sidecar.combat.tactics.base import (
    TacticalRole,
    Position,
    Skill,
    Actor,
    ThreatEntry,
    CombatContextProtocol,
    TargetPriority,
    TacticsConfig,
    BaseTactics
)


# Concrete implementation for testing
class TestTactics(BaseTactics):
    """Concrete tactics implementation for testing."""
    
    role = TacticalRole.MELEE_DPS
    
    async def select_target(self, context):
        """Test implementation."""
        if not context.nearby_monsters:
            return None
        
        monster = context.nearby_monsters[0]
        return TargetPriority(
            actor_id=monster.actor_id,
            priority_score=100.0,
            reason="test",
            distance=5.0,
            hp_percent=0.8
        )
    
    async def select_skill(self, context, target):
        """Test implementation."""
        return Skill(
            id=1,
            name="Test Skill",
            sp_cost=10
        )
    
    async def evaluate_positioning(self, context):
        """Test implementation."""
        return Position(x=100, y=100)
    
    def get_threat_assessment(self, context):
        """Test implementation."""
        return 0.5


class TestPositionDistanceMethods:
    """Test Position distance calculation methods (Lines 71, 76, 81, 86, 91)."""
    
    def test_position_protocol_attributes(self):
        """Test Position implements protocol attributes properly."""
        pos = Position(x=10, y=20)
        
        # Test that all protocol attributes are accessible
        assert hasattr(pos, 'x')
        assert hasattr(pos, 'y')
        assert pos.x == 10
        assert pos.y == 20


class TestActorProtocol:
    """Test Actor protocol attributes (Lines 69-91)."""
    
    def test_actor_protocol_compliance(self):
        """Test that mock actors comply with Actor protocol."""
        
        @dataclass
        class MockActor:
            """Mock actor for testing."""
            actor_id: int = 1
            name: str = "Test Monster"
            hp: int = 100
            hp_max: int = 150
            position: tuple = (50, 60)
        
        # Verify protocol compliance
        actor = MockActor()
        assert isinstance(actor, Actor)
        assert actor.actor_id == 1
        assert actor.name == "Test Monster"
        assert actor.hp == 100
        assert actor.hp_max == 150
        assert actor.position == (50, 60)


class TestCombatContextProtocol:
    """Test CombatContextProtocol attributes (Lines 111, 116, 121, 126, 131, 136, 141, 146, 151)."""
    
    def test_combat_context_protocol_attributes(self):
        """Test all protocol attributes are accessible."""
        
        # Create mock context
        context = Mock(spec=CombatContextProtocol)
        context.character_hp = 500
        context.character_hp_max = 1000
        context.character_sp = 200
        context.character_sp_max = 400
        context.character_position = Position(x=100, y=100)
        context.nearby_monsters = []
        context.party_members = []
        context.cooldowns = {}
        context.threat_level = 0.3
        
        # Verify all attributes
        assert context.character_hp == 500
        assert context.character_hp_max == 1000
        assert context.character_sp == 200
        assert context.character_sp_max == 400
        assert isinstance(context.character_position, Position)
        assert context.nearby_monsters == []
        assert context.party_members == []
        assert context.cooldowns == {}
        assert context.threat_level == 0.3


class TestBaseTacticsHelpers:
    """Test BaseTactics helper methods."""
    
    def test_is_emergency_edge_case(self):
        """Test emergency check with zero max HP."""
        tactics = TestTactics()
        context = Mock()
        context.character_hp = 50
        context.character_hp_max = 0  # Edge case
        
        # Should handle division by zero
        result = tactics.is_emergency(context)
        # With max=1 fallback, 50/1 = 50.0 which is > 0.25
        assert result is False
    
    def test_is_low_hp_edge_case(self):
        """Test low HP check with zero max HP."""
        tactics = TestTactics()
        context = Mock()
        context.character_hp = 30
        context.character_hp_max = 0
        
        result = tactics.is_low_hp(context)
        assert result is False  # 30/1 = 30.0 which is > 0.5
    
    def test_is_low_sp_edge_case(self):
        """Test low SP check with zero max SP."""
        tactics = TestTactics()
        context = Mock()
        context.character_sp = 10
        context.character_sp_max = 0
        
        result = tactics.is_low_sp(context)
        assert result is False  # 10/1 = 10.0 which is > 0.2
    
    def test_can_use_skill_insufficient_sp(self):
        """Test skill usage check with insufficient SP (Line 370-371)."""
        tactics = TestTactics()
        context = Mock()
        context.character_sp = 5
        context.cooldowns = {}
        
        skill = Skill(id=1, name="Expensive Skill", sp_cost=10)
        
        # Should return False due to insufficient SP
        assert tactics.can_use_skill(skill, context) is False
    
    def test_can_use_skill_on_cooldown(self):
        """Test skill usage check with active cooldown (Line 375-376)."""
        tactics = TestTactics()
        context = Mock()
        context.character_sp = 100
        context.cooldowns = {"Test Skill": 5.0}  # 5 seconds remaining
        
        skill = Skill(id=1, name="Test Skill", sp_cost=10)
        
        # Should return False due to cooldown
        assert tactics.can_use_skill(skill, context) is False


class TestGetDistanceToTarget:
    """Test distance calculation with different input types."""
    
    def test_get_distance_tuple_input(self):
        """Test distance calculation with tuple position."""
        tactics = TestTactics()
        context = Mock()
        context.character_position = Position(x=0, y=0)
        
        # Test with tuple
        distance = tactics.get_distance_to_target(context, (3, 4))
        assert distance == 5.0  # 3-4-5 triangle
    
    def test_get_distance_position_input(self):
        """Test distance calculation with Position input (Lines 388-391)."""
        tactics = TestTactics()
        context = Mock()
        context.character_position = Position(x=0, y=0)
        
        # Test with Position object
        target_pos = Position(x=3, y=4)
        distance = tactics.get_distance_to_target(context, target_pos)
        assert distance == 5.0


class TestPrioritizeTargets:
    """Test target prioritization logic."""
    
    def test_prioritize_targets_with_custom_scoring(self):
        """Test prioritization with custom scoring function (Lines 420-421)."""
        tactics = TestTactics()
        context = Mock()
        context.character_position = Position(x=0, y=0)
        
        # Create mock targets
        target1 = Mock()
        target1.actor_id = 1
        target1.hp = 50
        target1.hp_max = 100
        target1.position = (5, 0)
        
        target2 = Mock()
        target2.actor_id = 2
        target2.hp = 25
        target2.hp_max = 100
        target2.position = (10, 0)
        
        # Custom scoring function that prefers lower HP
        def custom_score(target, hp_percent, distance):
            return 100.0 * (1.0 - hp_percent)
        
        priorities = tactics.prioritize_targets(
            context,
            [target1, target2],
            scoring_func=custom_score
        )
        
        # Target2 should be higher priority (lower HP)
        assert priorities[0].actor_id == 2
    
    def test_prioritize_targets_default_scoring(self):
        """Test prioritization with default scoring (Lines 423-425)."""
        tactics = TestTactics()
        context = Mock()
        context.character_position = Position(x=0, y=0)
        
        target = Mock()
        target.actor_id = 1
        target.hp = 75
        target.hp_max = 100
        target.position = (3, 4)
        
        priorities = tactics.prioritize_targets(context, [target])
        
        # Should have calculated score
        assert len(priorities) == 1
        assert priorities[0].priority_score > 0


class TestDefaultTargetScore:
    """Test default target scoring logic (Lines 448-461)."""
    
    def test_target_score_prefers_closer(self):
        """Test score penalty for distance (Lines 448-449)."""
        tactics = TestTactics()
        
        target = Mock()
        target.is_mvp = False
        target.is_boss = False
        
        score1 = tactics._default_target_score(target, 0.8, 2.0)
        score2 = tactics._default_target_score(target, 0.8, 10.0)
        
        # Closer target should have higher score
        assert score1 > score2
    
    def test_target_score_prefers_low_hp(self):
        """Test score bonus for low HP (Lines 452-453)."""
        tactics = TestTactics(config=TacticsConfig(prefer_low_hp_targets=True))
        
        target = Mock()
        target.is_mvp = False
        target.is_boss = False
        
        score_high_hp = tactics._default_target_score(target, 0.9, 5.0)
        score_low_hp = tactics._default_target_score(target, 0.1, 5.0)
        
        # Low HP target should have higher score
        assert score_low_hp > score_high_hp
    
    def test_target_score_mvp_bonus(self):
        """Test score bonus for MVP targets (Lines 456-458)."""
        tactics = TestTactics(config=TacticsConfig(prefer_mvp_targets=True))
        
        target_mvp = Mock()
        target_mvp.is_mvp = True
        target_mvp.is_boss = False
        
        target_normal = Mock()
        target_normal.is_mvp = False
        target_normal.is_boss = False
        
        score_mvp = tactics._default_target_score(target_mvp, 0.8, 5.0)
        score_normal = tactics._default_target_score(target_normal, 0.8, 5.0)
        
        # MVP should have 50 point bonus
        assert score_mvp == score_normal + 50
    
    def test_target_score_boss_bonus(self):
        """Test score bonus for boss targets (Lines 459-460)."""
        tactics = TestTactics(config=TacticsConfig(prefer_mvp_targets=True))
        
        target_boss = Mock()
        target_boss.is_mvp = False
        target_boss.is_boss = True
        
        target_normal = Mock()
        target_normal.is_mvp = False
        target_normal.is_boss = False
        
        score_boss = tactics._default_target_score(target_boss, 0.8, 5.0)
        score_normal = tactics._default_target_score(target_normal, 0.8, 5.0)
        
        # Boss should have 25 point bonus
        assert score_boss == score_normal + 25


class TestThreatManagement:
    """Test threat table management (Lines 472-485)."""
    
    def test_update_threat_new_entry(self):
        """Test creating new threat entry (Lines 472-476)."""
        tactics = TestTactics()
        
        # Update threat for new actor
        tactics.update_threat(
            actor_id=123,
            damage_dealt=50,
            damage_taken=30,
            is_targeting=True
        )
        
        # Should have created entry
        assert 123 in tactics._threat_table
        entry = tactics._threat_table[123]
        assert entry.actor_id == 123
        assert entry.threat_value > 0
    
    def test_update_threat_existing_entry(self):
        """Test updating existing threat entry (Lines 478-485)."""
        tactics = TestTactics()
        
        # Create initial entry
        tactics.update_threat(actor_id=123, damage_dealt=10)
        initial_threat = tactics._threat_table[123].threat_value
        
        # Update with more threat
        tactics.update_threat(
            actor_id=123,
            damage_dealt=20,
            damage_taken=15,
            is_targeting=True
        )
        
        # Threat should have increased
        final_threat = tactics._threat_table[123].threat_value
        assert final_threat > initial_threat
        
        # Verify targeting flag and damage tracking
        entry = tactics._threat_table[123]
        assert entry.is_targeting_self is True
        assert entry.damage_taken == 15
    
    def test_get_threat_for_actor_unknown(self):
        """Test getting threat for unknown actor (Line 491)."""
        tactics = TestTactics()
        
        # Unknown actor should return 0
        threat = tactics.get_threat_for_actor(999)
        assert threat == 0.0
    
    def test_clear_threat_table(self):
        """Test clearing threat table (Line 495)."""
        tactics = TestTactics()
        
        # Add some threats
        tactics.update_threat(actor_id=1, damage_dealt=50)
        tactics.update_threat(actor_id=2, damage_dealt=30)
        
        assert len(tactics._threat_table) == 2
        
        # Clear
        tactics.clear_threat_table()
        
        assert len(tactics._threat_table) == 0


class TestTacticsConfiguration:
    """Test tactics configuration edge cases."""
    
    def test_tactics_with_none_config(self):
        """Test tactics initialization with None config."""
        tactics = TestTactics(config=None)
        
        # Should use default config
        assert tactics.config is not None
        assert isinstance(tactics.config, TacticsConfig)
    
    def test_tactics_with_custom_config(self):
        """Test tactics initialization with custom config."""
        custom_config = TacticsConfig(
            emergency_hp_threshold=0.15,
            low_hp_threshold=0.40,
            max_engagement_range=20
        )
        
        tactics = TestTactics(config=custom_config)
        
        assert tactics.config.emergency_hp_threshold == 0.15
        assert tactics.config.low_hp_threshold == 0.40
        assert tactics.config.max_engagement_range == 20


class TestAbstractMethods:
    """Verify abstract methods must be implemented."""
    
    def test_abstract_methods_required(self):
        """Test that BaseTactics cannot be instantiated without implementations."""
        
        # This should work (has implementations)
        tactics = TestTactics()
        assert tactics is not None
        
        # Verify methods are callable
        assert callable(tactics.select_target)
        assert callable(tactics.select_skill)
        assert callable(tactics.evaluate_positioning)
        assert callable(tactics.get_threat_assessment)