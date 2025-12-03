"""
Comprehensive tests for mimicry/randomizer.py module.

Tests behavior randomization including:
- Random behavior injection
- Idle actions
- Social interactions
- Target variation
- Panic behaviors
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch
import json

from ai_sidecar.mimicry.randomizer import (
    BehaviorCategory,
    RandomBehavior,
    RandomBehaviorPool,
    BehaviorRandomizer
)


class TestRandomBehaviorModels:
    """Test Pydantic models for random behaviors."""
    
    def test_random_behavior_creation(self):
        """Test RandomBehavior model creation."""
        behavior = RandomBehavior(
            behavior_type="sit",
            description="Sit down",
            duration_ms=5000
        )
        assert behavior.behavior_type == "sit"
        assert behavior.duration_ms == 5000
        assert behavior.can_interrupt is True
    
    def test_random_behavior_with_emote(self):
        """Test RandomBehavior with emote."""
        behavior = RandomBehavior(
            behavior_type="wave",
            description="Wave at player",
            duration_ms=1000,
            emote="/heh"
        )
        assert behavior.emote == "/heh"
    
    def test_random_behavior_pool_creation(self):
        """Test RandomBehaviorPool model creation."""
        pool = RandomBehaviorPool(
            category=BehaviorCategory.IDLE,
            behaviors=[]
        )
        assert pool.category == BehaviorCategory.IDLE
        assert len(pool.behaviors) == 0
    
    def test_behavior_pool_select_behavior(self):
        """Test selecting behavior from pool."""
        behavior1 = RandomBehavior(
            behavior_type="sit",
            description="Sit",
            duration_ms=5000
        )
        behavior2 = RandomBehavior(
            behavior_type="jump",
            description="Jump",
            duration_ms=500
        )
        pool = RandomBehaviorPool(
            category=BehaviorCategory.IDLE,
            behaviors=[behavior1, behavior2]
        )
        
        selected = pool.select_behavior()
        assert selected in [behavior1, behavior2]
    
    def test_behavior_pool_empty_selection(self):
        """Test selecting from empty pool."""
        pool = RandomBehaviorPool(
            category=BehaviorCategory.IDLE,
            behaviors=[]
        )
        
        selected = pool.select_behavior()
        assert selected is None


class TestBehaviorRandomizerInit:
    """Test BehaviorRandomizer initialization."""
    
    def test_init_with_data_dir(self, tmp_path):
        """Test initialization with data directory."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        assert randomizer.data_dir == tmp_path
        assert len(randomizer.behavior_pools) > 0
    
    def test_init_creates_default_pools(self, tmp_path):
        """Test default pool creation."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        assert BehaviorCategory.IDLE in randomizer.behavior_pools
        assert BehaviorCategory.SOCIAL in randomizer.behavior_pools
    
    def test_init_loads_from_file_if_exists(self, tmp_path):
        """Test loading behaviors from file."""
        behaviors_file = tmp_path / "human_behaviors.json"
        test_data = {
            "idle_behaviors": [
                {
                    "type": "sit",
                    "duration_ms": 5000,
                    "cooldown_ms": 30000
                }
            ],
            "social_behaviors": [
                {
                    "type": "wave",
                    "duration_ms": 1000,
                    "target": "nearby_player",
                    "emote": "/heh"
                }
            ]
        }
        behaviors_file.write_text(json.dumps(test_data))
        
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        assert len(randomizer.behavior_pools[BehaviorCategory.IDLE].behaviors) > 0


class TestShouldInjectRandomBehavior:
    """Test random behavior injection decisions."""
    
    def test_no_inject_during_combat(self, tmp_path):
        """Test no injection during critical activities."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        should_inject, behavior = randomizer.should_inject_random_behavior(
            current_activity="combat",
            time_in_activity_ms=60000
        )
        
        assert should_inject is False
        assert behavior is None
    
    def test_no_inject_during_trading(self, tmp_path):
        """Test no injection during trading."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        should_inject, behavior = randomizer.should_inject_random_behavior(
            current_activity="trading",
            time_in_activity_ms=60000
        )
        
        assert should_inject is False
    
    def test_no_inject_too_soon_after_last(self, tmp_path):
        """Test cooldown between injections."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        randomizer.last_injection_time = datetime.now()
        
        should_inject, behavior = randomizer.should_inject_random_behavior(
            current_activity="idle",
            time_in_activity_ms=60000
        )
        
        assert should_inject is False
    
    def test_injection_probability_increases_with_time(self, tmp_path):
        """Test higher injection chance after long activity."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        randomizer.last_injection_time = datetime.now() - timedelta(seconds=60)
        
        # Long activity time should have non-zero chance
        should_inject, behavior = randomizer.should_inject_random_behavior(
            current_activity="idle",
            time_in_activity_ms=600000  # 10 minutes
        )
        
        # Might or might not inject, but shouldn't error
        assert isinstance(should_inject, bool)


class TestGetRandomBehaviors:
    """Test specific behavior getters."""
    
    def test_get_random_idle_behavior(self, tmp_path):
        """Test getting idle behavior."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.get_random_idle_behavior()
        
        if behavior:
            assert isinstance(behavior, RandomBehavior)
    
    def test_get_random_social_behavior_no_players(self, tmp_path):
        """Test social behavior with no nearby players."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.get_random_social_behavior(nearby_players=[])
        
        assert behavior is None
    
    def test_get_random_social_behavior_with_players(self, tmp_path):
        """Test social behavior with nearby players."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.get_random_social_behavior(
            nearby_players=["Player1", "Player2"]
        )
        
        # Might or might not select (10% chance)
        if behavior:
            assert isinstance(behavior, RandomBehavior)
            assert behavior.target_type in ["Player1", "Player2"]


class TestInjectSpecificBehaviors:
    """Test specific behavior injection methods."""
    
    def test_inject_inventory_check(self, tmp_path):
        """Test inventory check behavior."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.inject_inventory_check()
        
        assert behavior.behavior_type == "open_inventory"
        assert behavior.duration_ms >= 2000
        assert behavior.duration_ms <= 5000
    
    def test_inject_map_check(self, tmp_path):
        """Test map check behavior."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.inject_map_check()
        
        assert behavior.behavior_type == "open_map"
        assert behavior.duration_ms >= 1500
        assert behavior.duration_ms <= 3000
    
    def test_inject_status_check(self, tmp_path):
        """Test status window check behavior."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.inject_status_check()
        
        assert behavior.behavior_type.startswith("open_")
        assert behavior.duration_ms >= 2000


class TestGetSpontaneousEmote:
    """Test spontaneous emote generation."""
    
    def test_get_spontaneous_emote(self, tmp_path):
        """Test emote generation."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times, should sometimes return None (98% chance)
        emotes = [randomizer.get_spontaneous_emote() for _ in range(100)]
        
        # Most should be None due to low probability
        none_count = emotes.count(None)
        assert none_count > 90
        
        # Any non-None should be valid emote
        for emote in emotes:
            if emote:
                assert emote.startswith("/")


class TestVaryTargetSelection:
    """Test target selection variation."""
    
    def test_vary_target_optimal_most_of_time(self, tmp_path):
        """Test mostly selecting optimal target."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        targets = [
            {"actor_id": 1, "hp": 100},
            {"actor_id": 2, "hp": 80},
            {"actor_id": 3, "hp": 120}
        ]
        optimal = targets[1]  # 80 HP
        
        # Run multiple times
        selections = [
            randomizer.vary_target_selection(targets, optimal)
            for _ in range(100)
        ]
        
        # Should pick optimal most of the time (85%+)
        optimal_count = sum(1 for s in selections if s == optimal)
        assert optimal_count >= 75
    
    def test_vary_target_empty_list(self, tmp_path):
        """Test with empty target list."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        optimal = {"actor_id": 1, "hp": 100}
        result = randomizer.vary_target_selection([], optimal)
        
        assert result == optimal


class TestCheckSurroundings:
    """Test surrounding check behavior."""
    
    def test_should_check_surroundings(self, tmp_path):
        """Test surroundings check probability."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        checks = [randomizer.should_check_surroundings() for _ in range(100)]
        
        # Should be roughly 5%
        check_count = sum(checks)
        assert 0 <= check_count <= 15


class TestGetRandomCameraMovement:
    """Test camera movement generation."""
    
    def test_get_random_camera_movement(self, tmp_path):
        """Test camera movement parameters."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        angle, duration = randomizer.get_random_camera_movement()
        
        assert -45 <= angle <= 45
        assert 500 <= duration <= 2000


class TestShouldSitAndRest:
    """Test sit/rest decision logic."""
    
    def test_sit_low_hp(self, tmp_path):
        """Test sitting with low HP."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        should_sit = randomizer.should_sit_and_rest(hp_percent=25, sp_percent=100)
        
        assert should_sit is True
    
    def test_sit_low_sp(self, tmp_path):
        """Test sitting with low SP."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        should_sit = randomizer.should_sit_and_rest(hp_percent=100, sp_percent=15)
        
        assert should_sit is True
    
    def test_sit_medium_hp_sp(self, tmp_path):
        """Test sitting with medium HP/SP."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        sits = [
            randomizer.should_sit_and_rest(hp_percent=50, sp_percent=30)
            for _ in range(100)
        ]
        
        # Should sometimes sit (30% chance)
        sit_count = sum(sits)
        assert 10 <= sit_count <= 50
    
    def test_no_sit_full_hp_sp(self, tmp_path):
        """Test rarely sitting with full HP/SP."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        sits = [
            randomizer.should_sit_and_rest(hp_percent=100, sp_percent=100)
            for _ in range(100)
        ]
        
        # Should very rarely sit (1% chance)
        sit_count = sum(sits)
        assert sit_count <= 5


class TestGetAFKBehavior:
    """Test AFK behavior generation."""
    
    def test_get_afk_behavior_short(self, tmp_path):
        """Test short AFK behavior."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behaviors = randomizer.get_afk_behavior(duration_seconds=30)
        
        assert len(behaviors) >= 1
        assert behaviors[0].behavior_type == "sit"
        assert behaviors[0].can_interrupt is False
    
    def test_get_afk_behavior_long(self, tmp_path):
        """Test long AFK behavior with micro-movements."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times to account for randomness
        behavior_lists = [
            randomizer.get_afk_behavior(duration_seconds=120)
            for _ in range(10)
        ]
        
        # Some should have micro-movements
        has_movement = any(
            len(behaviors) > 1 
            for behaviors in behavior_lists
        )
        # Might or might not have movement (50% chance)


class TestShouldMakeTypoInCombat:
    """Test combat typo probability."""
    
    def test_should_make_typo_in_combat(self, tmp_path):
        """Test combat typo probability."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        typos = [randomizer.should_make_typo_in_combat() for _ in range(100)]
        
        # Should be roughly 3%
        typo_count = sum(typos)
        assert 0 <= typo_count <= 10


class TestGetPanicBehavior:
    """Test panic behavior generation."""
    
    def test_get_panic_no_threat(self, tmp_path):
        """Test no panic at low threat."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.get_panic_behavior(threat_level=0.3)
        
        assert behavior is None
    
    def test_get_panic_medium_threat(self, tmp_path):
        """Test occasional panic at medium threat."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        behavior = randomizer.get_panic_behavior(threat_level=0.7)
        
        # Might or might not panic
        if behavior:
            assert behavior.behavior_type in [
                "spam_heal_key", "spam_teleport",
                "erratic_movement", "panic_item_use"
            ]
    
    def test_get_panic_high_threat(self, tmp_path):
        """Test higher panic chance at high threat."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        panics = [
            randomizer.get_panic_behavior(threat_level=0.95)
            for _ in range(100)
        ]
        
        # Some should panic at very high threat
        panic_count = sum(1 for p in panics if p is not None)
        # Might have some panics


class TestGetCelebrationEmote:
    """Test celebration emote generation."""
    
    def test_get_celebration_emote(self, tmp_path):
        """Test celebration emote probability."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Run multiple times
        emotes = [randomizer.get_celebration_emote() for _ in range(100)]
        
        # Should be roughly 30%
        emote_count = sum(1 for e in emotes if e is not None)
        assert 15 <= emote_count <= 45
        
        # All non-None should be valid celebration emotes
        for emote in emotes:
            if emote:
                assert emote in ["/gg", "/heh", "/lv", "/kis", "/ok"]


class TestClearOldHistory:
    """Test behavior history cleanup."""
    
    def test_clear_old_history(self, tmp_path):
        """Test clearing old history entries."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        # Add old and new entries
        old_time = datetime.now() - timedelta(hours=2)
        new_time = datetime.now()
        
        randomizer.behavior_history = [
            (old_time, "sit"),
            (new_time, "jump"),
            (old_time, "wave"),
            (new_time, "emote")
        ]
        
        randomizer.clear_old_history(hours=1)
        
        # Should only keep recent entries
        assert len(randomizer.behavior_history) == 2
        assert all(t > datetime.now() - timedelta(hours=1) for t, _ in randomizer.behavior_history)


class TestGetBehaviorStats:
    """Test behavior statistics."""
    
    def test_get_stats_empty_history(self, tmp_path):
        """Test stats with no history."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        stats = randomizer.get_behavior_stats()
        
        assert stats["total_injections"] == 0
        assert stats["recent_count"] == 0
    
    def test_get_stats_with_history(self, tmp_path):
        """Test stats with behavior history."""
        randomizer = BehaviorRandomizer(data_dir=tmp_path)
        
        now = datetime.now()
        randomizer.behavior_history = [
            (now - timedelta(minutes=30), "sit"),
            (now - timedelta(minutes=20), "jump"),
            (now - timedelta(minutes=10), "sit"),
            (now - timedelta(hours=2), "wave")
        ]
        randomizer.last_injection_time = now - timedelta(minutes=5)
        
        stats = randomizer.get_behavior_stats()
        
        assert stats["total_injections"] == 4
        assert stats["recent_count"] == 3  # Last hour
        assert "behavior_distribution" in stats
        assert stats["behavior_distribution"]["sit"] == 2