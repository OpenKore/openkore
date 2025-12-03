"""
Comprehensive tests for combat/targeting.py - BATCH 4.
Target: 95%+ coverage (currently 83.07%, 21 uncovered lines).
"""

import pytest
from unittest.mock import Mock
from ai_sidecar.combat.targeting import (
    TargetingSystem,
    TargetPriorityType,
    TargetScore,
    TARGET_WEIGHTS,
    create_default_targeting_system,
)
from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace, MonsterSize


class MockPosition:
    """Mock position class."""
    def __init__(self, x, y):
        self.x = x
        self.y = y


class MockCharacterState:
    """Mock character state."""
    def __init__(self, level=50, x=100, y=100):
        self.level = level
        self.position = MockPosition(x, y)


class TestTargetingSystem:
    """Test TargetingSystem functionality."""
    
    @pytest.fixture
    def targeting_system(self):
        """Create targeting system."""
        return TargetingSystem()
    
    @pytest.fixture
    def character(self):
        """Create mock character."""
        return MockCharacterState()
    
    @pytest.fixture
    def sample_monster(self):
        """Create sample monster."""
        return MonsterActor(
            actor_id=1001,
            mob_id=1002,
            name="Poring",
            level=5,
            element=Element.WATER,
            race=MonsterRace.PLANT,
            size=MonsterSize.MEDIUM,
            position=(105, 105),
            hp=500,
            hp_max=500,
            is_aggressive=False,
            is_boss=False,
            is_mvp=False,
        )
    
    def test_initialization(self, targeting_system):
        """Test targeting system initialization."""
        assert len(targeting_system.quest_targets) == 0
        assert targeting_system._last_target_id is None
    
    def test_initialization_with_quest_targets(self):
        """Test initialization with quest targets."""
        quest_targets = {1001, 1002, 1003}
        system = TargetingSystem(quest_targets=quest_targets)
        
        assert len(system.quest_targets) == 3
        assert 1001 in system.quest_targets
    
    def test_select_target_no_monsters(self, targeting_system, character):
        """Test target selection with no monsters."""
        result = targeting_system.select_target(character, [])
        assert result is None
    
    def test_select_target_basic(self, targeting_system, character, sample_monster):
        """Test basic target selection."""
        target = targeting_system.select_target(character, [sample_monster])
        
        assert target is not None
        assert target.actor_id == sample_monster.actor_id
    
    def test_select_target_mvp_priority(self, targeting_system, character, sample_monster):
        """Test MVP gets highest priority."""
        mvp = MonsterActor(
            actor_id=2001,
            mob_id=1002,
            name="Baphomet",
            level=81,
            element=Element.DARK,
            race=MonsterRace.DEMON,
            size=MonsterSize.LARGE,
            position=(110, 110),
            hp=10000,
            hp_max=10000,
            is_mvp=True,
        )
        
        target = targeting_system.select_target(character, [sample_monster, mvp])
        
        assert target.actor_id == mvp.actor_id
    
    def test_select_target_boss_priority(self, targeting_system, character, sample_monster):
        """Test boss priority."""
        boss = MonsterActor(
            actor_id=2002,
            mob_id=1003,
            name="Mini Boss",
            level=60,
            element=Element.FIRE,
            race=MonsterRace.BRUTE,
            size=MonsterSize.LARGE,
            position=(108, 108),
            hp=5000,
            hp_max=5000,
            is_boss=True,
        )
        
        target = targeting_system.select_target(character, [sample_monster, boss])
        
        assert target.actor_id == boss.actor_id
    
    def test_select_target_aggressive_priority(self, targeting_system, character, sample_monster):
        """Test aggressive monster priority."""
        aggressive = MonsterActor(
            actor_id=2003,
            mob_id=1004,
            name="Orc Warrior",
            level=44,
            element=Element.EARTH,
            race=MonsterRace.DEMI_HUMAN,
            size=MonsterSize.MEDIUM,
            position=(102, 102),
            hp=2000,
            hp_max=2000,
            is_aggressive=True,
            is_targeting_player=True,
        )
        
        target = targeting_system.select_target(character, [sample_monster, aggressive])
        
        assert target.actor_id == aggressive.actor_id
    
    def test_select_target_quest_priority(self, targeting_system, character, sample_monster):
        """Test quest target priority."""
        quest_mob = MonsterActor(
            actor_id=2004,
            mob_id=1005,
            name="Quest Target",
            level=40,
            element=Element.NEUTRAL,
            race=MonsterRace.INSECT,
            size=MonsterSize.SMALL,
            position=(115, 115),
            hp=1000,
            hp_max=1000,
        )
        
        targeting_system.quest_targets.add(1005)
        
        target = targeting_system.select_target(character, [sample_monster, quest_mob])
        
        assert target.actor_id == quest_mob.actor_id
    
    def test_select_target_low_hp_priority(self, targeting_system, character, sample_monster):
        """Test low HP target priority."""
        low_hp = MonsterActor(
            actor_id=2005,
            mob_id=1006,
            name="Wounded",
            level=40,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(103, 103),
            hp=50,  # 10% HP
            hp_max=500,
        )
        
        target = targeting_system.select_target(
            character,
            [sample_monster, low_hp],
            prefer_finish_low_hp=True
        )
        
        assert target.actor_id == low_hp.actor_id
    
    def test_select_target_elemental_advantage(self, targeting_system, character):
        """Test elemental advantage in targeting."""
        weak_to_fire = MonsterActor(
            actor_id=2006,
            mob_id=1007,
            name="Ice Monster",
            level=50,
            element=Element.WATER,  # Weak to fire
            race=MonsterRace.FORMLESS,
            size=MonsterSize.MEDIUM,
            position=(105, 105),
            hp=1000,
            hp_max=1000,
        )
        
        target = targeting_system.select_target(
            character,
            [weak_to_fire],
            current_weapon_element=Element.FIRE
        )
        
        assert target is not None
    
    def test_select_target_distance_penalty(self, targeting_system, character):
        """Test distance affects priority."""
        close = MonsterActor(
            actor_id=3001,
            mob_id=1008,
            name="Close",
            level=50,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(102, 102),  # Close
            hp=1000,
            hp_max=1000,
        )
        
        far = MonsterActor(
            actor_id=3002,
            mob_id=1009,
            name="Far",
            level=50,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(200, 200),  # Far
            hp=1000,
            hp_max=1000,
        )
        
        target = targeting_system.select_target(character, [close, far])
        
        # Should prefer closer target
        assert target.actor_id == close.actor_id
    
    def test_add_quest_target(self, targeting_system):
        """Test adding quest target."""
        targeting_system.add_quest_target(1001)
        
        assert 1001 in targeting_system.quest_targets
    
    def test_remove_quest_target(self, targeting_system):
        """Test removing quest target."""
        targeting_system.quest_targets.add(1001)
        targeting_system.remove_quest_target(1001)
        
        assert 1001 not in targeting_system.quest_targets
    
    def test_clear_quest_targets(self, targeting_system):
        """Test clearing all quest targets."""
        targeting_system.quest_targets.update({1001, 1002, 1003})
        targeting_system.clear_quest_targets()
        
        assert len(targeting_system.quest_targets) == 0
    
    def test_should_switch_target_dead(self, targeting_system, character, sample_monster):
        """Test switch when current target is not in list."""
        should_switch = targeting_system.should_switch_target(
            current_target=sample_monster,
            nearby_monsters=[],  # Current target not present
            character=character,
        )
        
        assert should_switch is True
    
    def test_should_switch_target_better_available(
        self, targeting_system, character, sample_monster
    ):
        """Test switch when much better target appears."""
        mvp = MonsterActor(
            actor_id=2001,
            mob_id=1002,
            name="MVP",
            level=80,
            element=Element.DARK,
            race=MonsterRace.DEMON,
            size=MonsterSize.LARGE,
            position=(105, 105),
            hp=10000,
            hp_max=10000,
            is_mvp=True,
        )
        
        should_switch = targeting_system.should_switch_target(
            current_target=sample_monster,
            nearby_monsters=[sample_monster, mvp],
            character=character,
        )
        
        assert should_switch is True
    
    def test_should_switch_target_stay(self, targeting_system, character, sample_monster):
        """Test not switching when current target is good."""
        similar = MonsterActor(
            actor_id=2007,
            mob_id=1010,
            name="Similar",
            level=5,
            element=Element.WATER,
            race=MonsterRace.PLANT,
            size=MonsterSize.MEDIUM,
            position=(110, 110),
            hp=500,
            hp_max=500,
        )
        
        should_switch = targeting_system.should_switch_target(
            current_target=sample_monster,
            nearby_monsters=[sample_monster, similar],
            character=character,
        )
        
        assert should_switch is False
    
    def test_get_priority_summary(self, targeting_system, character):
        """Test getting priority summary."""
        summary = targeting_system.get_priority_summary(character)
        
        assert "mvp_weight" in summary
        assert "boss_weight" in summary
        assert "aggressive_weight" in summary
        assert "quest_targets" in summary
        assert summary["mvp_weight"] == TARGET_WEIGHTS[TargetPriorityType.MVP]
    
    def test_create_default_targeting_system(self):
        """Test factory function."""
        system = create_default_targeting_system()
        
        assert isinstance(system, TargetingSystem)
        assert len(system.quest_targets) == 0
    
    def test_target_score_reason_summary(self, sample_monster):
        """Test TargetScore reason summary."""
        score = TargetScore(
            monster=sample_monster,
            total_score=150.0,
            priority_reasons=[
                (TargetPriorityType.QUEST_TARGET, 100),
                (TargetPriorityType.NEARBY, 50),
            ],
            distance=5.0,
        )
        
        summary = score.get_reason_summary()
        
        assert "quest_target" in summary
        assert "100" in summary
    
    def test_target_score_reason_summary_empty(self, sample_monster):
        """Test reason summary with no reasons."""
        score = TargetScore(
            monster=sample_monster,
            total_score=50.0,
            priority_reasons=[],
            distance=5.0,
        )
        
        assert score.get_reason_summary() == "default"
    
    def test_select_targets_function(self):
        """Test standalone select_targets function."""
        from ai_sidecar.combat.targeting import select_targets
        
        system = TargetingSystem()
        monsters = [Mock(), Mock(), Mock()]
        
        # Single target
        result = select_targets(system, monsters, target_type="single")
        assert len(result) == 1
        
        # AoE target
        result = select_targets(system, monsters, target_type="aoe")
        assert len(result) == 3
    
    def test_select_targets_empty(self):
        """Test select_targets with no monsters."""
        from ai_sidecar.combat.targeting import select_targets
        
        system = TargetingSystem()
        result = select_targets(system, [])
        assert len(result) == 0
    
    def test_optimal_level_bonus(self, targeting_system, character):
        """Test optimal level targeting bonus."""
        optimal_level = MonsterActor(
            actor_id=3003,
            mob_id=1011,
            name="Optimal Level",
            level=48,  # Within 5 levels of character (50)
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=(105, 105),
            hp=1000,
            hp_max=1000,
        )
        
        target = targeting_system.select_target(character, [optimal_level])
        
        assert target is not None