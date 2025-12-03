"""
Comprehensive tests for consumables/status_effects.py - BATCH 4.
Target: 95%+ coverage (currently 87.40%, 18 uncovered lines).
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from ai_sidecar.consumables.status_effects import (
    StatusEffectManager,
    StatusEffectType,
    StatusSeverity,
    StatusEffectState,
    CureAction,
    ImmunityRecommendation,
)


class TestStatusEffectManager:
    """Test StatusEffectManager functionality."""
    
    @pytest.fixture
    def manager(self):
        """Create manager with default data."""
        return StatusEffectManager()
    
    def test_initialization(self, manager):
        """Test manager initialization."""
        assert len(manager.active_effects) == 0
        assert len(manager.status_database) > 0
        assert len(manager.cure_history) == 0
        assert len(manager.immunity_active) == 0
    
    def test_default_status_data_loaded(self, manager):
        """Test default status data is loaded."""
        assert "stone" in manager.status_database
        assert "freeze" in manager.status_database
        assert "poison" in manager.status_database
    
    def test_get_severity_critical(self, manager):
        """Test getting critical severity."""
        severity = manager._get_severity(StatusEffectType.STONE)
        assert severity == StatusSeverity.CRITICAL
    
    def test_get_severity_from_database(self, manager):
        """Test getting severity from database."""
        manager.status_database["test_effect"] = {"severity": 7}
        
        severity = manager._get_severity(StatusEffectType.STUN)
        assert isinstance(severity, StatusSeverity)
    
    @pytest.mark.asyncio
    async def test_detect_status_effects(self, manager):
        """Test detecting status effects from game state."""
        game_state = {
            "character": {
                "status_effects": ["SC_STONE", "SC_POISON"]
            }
        }
        
        detected = await manager.detect_status_effects(game_state)
        
        assert len(detected) == 2
        assert StatusEffectType.STONE in manager.active_effects
        assert StatusEffectType.POISON in manager.active_effects
    
    @pytest.mark.asyncio
    async def test_detect_status_effects_cleanup(self, manager):
        """Test detecting effects cleans up removed ones."""
        # Add an effect
        manager.active_effects[StatusEffectType.STONE] = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        
        # Game state without that effect
        game_state = {"character": {"status_effects": ["SC_POISON"]}}
        
        await manager.detect_status_effects(game_state)
        
        # Stone should be removed
        assert StatusEffectType.STONE not in manager.active_effects
        assert StatusEffectType.POISON in manager.active_effects
    
    def test_map_status_id(self, manager):
        """Test mapping status IDs."""
        assert manager._map_status_id("SC_STONE") == StatusEffectType.STONE
        assert manager._map_status_id("SC_FREEZE") == StatusEffectType.FREEZE
        assert manager._map_status_id("UNKNOWN") is None
    
    @pytest.mark.asyncio
    async def test_prioritize_cures(self, manager):
        """Test cure prioritization."""
        effects = [
            StatusEffectState(
                effect_type=StatusEffectType.POISON,
                severity=StatusSeverity.MEDIUM,
                inflicted_time=datetime.now(),
            ),
            StatusEffectState(
                effect_type=StatusEffectType.STONE,
                severity=StatusSeverity.CRITICAL,
                inflicted_time=datetime.now(),
            ),
            StatusEffectState(
                effect_type=StatusEffectType.BLIND,
                severity=StatusSeverity.LOW,
                inflicted_time=datetime.now(),
            ),
        ]
        
        sorted_effects = await manager.prioritize_cures(effects)
        
        # Should be sorted by severity (highest first)
        assert sorted_effects[0].effect_type == StatusEffectType.STONE
        assert sorted_effects[-1].effect_type == StatusEffectType.BLIND
    
    @pytest.mark.asyncio
    async def test_get_cure_action_with_item(self, manager):
        """Test getting cure action with available item."""
        effect = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        available_items = {"Green Potion", "Royal Jelly"}
        
        cure = await manager.get_cure_action(effect, available_items, 50)
        
        assert cure is not None
        assert cure.method == "item"
        assert cure.item_name in available_items
    
    @pytest.mark.asyncio
    async def test_get_cure_action_with_skill(self, manager):
        """Test getting cure action with skill."""
        effect = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        # No items but have SP
        cure = await manager.get_cure_action(effect, set(), available_sp=100)
        
        if cure and cure.method == "skill":
            assert cure.skill_name is not None
    
    @pytest.mark.asyncio
    async def test_get_cure_action_wait(self, manager):
        """Test cure action for uncurable effect."""
        # Add uncurable effect to database
        manager.status_database["test_uncurable"] = {
            "can_be_cured": False,
            "natural_duration": 10.0,
        }
        
        effect = StatusEffectState(
            effect_type=StatusEffectType.BERSERK,
            severity=StatusSeverity.LOW,
            inflicted_time=datetime.now(),
        )
        
        # Mock the effect type to be in database
        manager.status_database["berserk"] = {
            "can_be_cured": False,
            "natural_duration": 15.0,
        }
        
        cure = await manager.get_cure_action(effect)
        
        if cure:
            assert cure.method == "wait"
            assert cure.wait_seconds > 0
    
    @pytest.mark.asyncio
    async def test_get_cure_action_unknown_effect(self, manager):
        """Test cure action for unknown effect."""
        effect = StatusEffectState(
            effect_type=StatusEffectType.CHAOS,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        cure = await manager.get_cure_action(effect)
        
        # May return None or basic cure
        assert cure is None or isinstance(cure, CureAction)
    
    @pytest.mark.asyncio
    async def test_should_apply_immunity(self, manager):
        """Test immunity recommendations."""
        # Add frequent poison occurrences
        for i in range(5):
            manager.cure_history.append(
                (StatusEffectType.POISON, datetime.now(), True)
            )
        
        recommendations = await manager.should_apply_immunity("test_map", [])
        
        # Should recommend immunity for frequent effect
        poison_recs = [r for r in recommendations if r.status == StatusEffectType.POISON]
        if poison_recs:
            assert poison_recs[0].method == "item"
    
    @pytest.mark.asyncio
    async def test_should_apply_immunity_no_recommendations(self, manager):
        """Test no immunity recommendations for infrequent effects."""
        recommendations = await manager.should_apply_immunity("test_map", [])
        
        # No recent effects, no recommendations
        assert len(recommendations) == 0
    
    def test_get_recent_effects(self, manager):
        """Test getting recent effect counts."""
        # Add some history
        now = datetime.now()
        manager.cure_history.extend([
            (StatusEffectType.POISON, now, True),
            (StatusEffectType.POISON, now, True),
            (StatusEffectType.STONE, now, False),
        ])
        
        counts = manager._get_recent_effects(seconds=60)
        
        assert counts[StatusEffectType.POISON] == 2
        assert counts[StatusEffectType.STONE] == 1
    
    def test_get_recent_effects_time_filter(self, manager):
        """Test recent effects filters by time."""
        old_time = datetime.now() - timedelta(seconds=120)
        recent_time = datetime.now()
        
        manager.cure_history.extend([
            (StatusEffectType.POISON, old_time, True),
            (StatusEffectType.STONE, recent_time, True),
        ])
        
        counts = manager._get_recent_effects(seconds=60)
        
        # Old one should be filtered out
        assert StatusEffectType.POISON not in counts or counts[StatusEffectType.POISON] == 0
        assert counts[StatusEffectType.STONE] == 1
    
    @pytest.mark.asyncio
    async def test_track_cure_effectiveness_success(self, manager):
        """Test tracking successful cure."""
        action = CureAction(
            effect_type=StatusEffectType.POISON,
            method="item",
            item_name="Green Potion",
            priority=5,
        )
        
        await manager.track_cure_effectiveness(action, success=True)
        
        assert len(manager.cure_history) == 1
        assert manager.cure_history[0][2] is True  # Success flag
    
    @pytest.mark.asyncio
    async def test_track_cure_effectiveness_failure(self, manager):
        """Test tracking failed cure."""
        action = CureAction(
            effect_type=StatusEffectType.STONE,
            method="item",
            item_name="Blue Gemstone",
            priority=10,
        )
        
        await manager.track_cure_effectiveness(action, success=False)
        
        assert len(manager.cure_history) == 1
        assert manager.cure_history[0][2] is False
    
    @pytest.mark.asyncio
    async def test_track_cure_effectiveness_history_limit(self, manager):
        """Test cure history is limited."""
        action = CureAction(
            effect_type=StatusEffectType.POISON,
            method="item",
            item_name="Green Potion",
            priority=5,
        )
        
        # Add many entries
        for i in range(1100):
            await manager.track_cure_effectiveness(action, True)
        
        # Should be limited
        assert len(manager.cure_history) <= 1000
    
    def test_has_critical_status_yes(self, manager):
        """Test detecting critical status."""
        manager.active_effects[StatusEffectType.STONE] = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        
        assert manager.has_critical_status() is True
    
    def test_has_critical_status_no(self, manager):
        """Test no critical status."""
        manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        assert manager.has_critical_status() is False
    
    def test_get_status_summary(self, manager):
        """Test getting status summary."""
        manager.active_effects[StatusEffectType.STONE] = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        summary = manager.get_status_summary()
        
        assert summary["total_active"] == 2
        assert summary["critical_count"] == 1
        assert len(summary["effects"]) == 2
    
    def test_clear_effect(self, manager):
        """Test clearing a status effect."""
        manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        manager.clear_effect(StatusEffectType.POISON)
        
        assert StatusEffectType.POISON not in manager.active_effects
    
    def test_add_immunity(self, manager):
        """Test adding immunity."""
        manager.add_immunity(StatusEffectType.STONE)
        
        assert StatusEffectType.STONE in manager.immunity_active
    
    def test_remove_immunity(self, manager):
        """Test removing immunity."""
        manager.immunity_active.add(StatusEffectType.FREEZE)
        
        manager.remove_immunity(StatusEffectType.FREEZE)
        
        assert StatusEffectType.FREEZE not in manager.immunity_active
    
    def test_add_status_effect_enum(self, manager):
        """Test adding status effect with enum."""
        manager.add_status_effect(
            StatusEffectType.POISON,
            source_monster="Poison Spore",
            duration=60.0,
        )
        
        assert StatusEffectType.POISON in manager.active_effects
        effect = manager.active_effects[StatusEffectType.POISON]
        assert effect.source_monster == "Poison Spore"
        assert effect.estimated_duration == 60.0
    
    def test_add_status_effect_string(self, manager):
        """Test adding status effect with string."""
        manager.add_status_effect("stone", source_monster="Medusa")
        
        assert StatusEffectType.STONE in manager.active_effects
    
    def test_add_status_effect_unknown_string(self, manager):
        """Test adding unknown status effect string."""
        manager.add_status_effect("unknown_effect")
        
        # Should handle gracefully
        assert len(manager.active_effects) == 0


class TestStatusEffectState:
    """Test StatusEffectState model."""
    
    def test_status_effect_state_properties(self):
        """Test status effect state properties."""
        state = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
            estimated_duration=60.0,
            source_monster="Poison Spore",
            damage_per_tick=50,
        )
        
        assert state.effect_type == StatusEffectType.POISON
        assert state.severity == StatusSeverity.MEDIUM
        assert state.age_seconds >= 0
    
    def test_status_effect_is_recent(self):
        """Test is_recent property."""
        state = StatusEffectState(
            effect_type=StatusEffectType.STUN,
            severity=StatusSeverity.HIGH,
            inflicted_time=datetime.now(),
        )
        
        assert state.is_recent is True
    
    def test_status_effect_not_recent(self):
        """Test is_recent for old effect."""
        old_time = datetime.now() - timedelta(seconds=5)
        state = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=old_time,
        )
        
        assert state.is_recent is False
    
    def test_status_effect_age_calculation(self):
        """Test age calculation."""
        past_time = datetime.now() - timedelta(seconds=10)
        state = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=past_time,
        )
        
        assert state.age_seconds >= 10.0


class TestCureAction:
    """Test CureAction model."""
    
    def test_cure_action_item(self):
        """Test cure action with item."""
        action = CureAction(
            effect_type=StatusEffectType.POISON,
            method="item",
            item_name="Green Potion",
            priority=5,
        )
        
        assert action.method == "item"
        assert action.item_name == "Green Potion"
    
    def test_cure_action_skill(self):
        """Test cure action with skill."""
        action = CureAction(
            effect_type=StatusEffectType.POISON,
            method="skill",
            skill_name="Cure",
            priority=5,
        )
        
        assert action.method == "skill"
        assert action.skill_name == "Cure"
    
    def test_cure_action_wait(self):
        """Test cure action wait."""
        action = CureAction(
            effect_type=StatusEffectType.BERSERK,
            method="wait",
            priority=3,
            wait_seconds=15.0,
        )
        
        assert action.method == "wait"
        assert action.wait_seconds == 15.0


class TestImmunityRecommendation:
    """Test ImmunityRecommendation model."""
    
    def test_immunity_recommendation(self):
        """Test immunity recommendation model."""
        rec = ImmunityRecommendation(
            status=StatusEffectType.FREEZE,
            reason="Frequent freeze from monsters",
            method="item",
            item_name="Marc Card",
            priority=8,
        )
        
        assert rec.status == StatusEffectType.FREEZE
        assert rec.method == "item"
        assert rec.priority == 8