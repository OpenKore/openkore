"""
Comprehensive tests for status effect management - Batch 4.

Tests status detection, cure prioritization, and immunity.
"""

from datetime import datetime, timedelta
from unittest.mock import Mock

import pytest

from ai_sidecar.consumables.status_effects import (
    CureAction,
    ImmunityRecommendation,
    StatusEffectManager,
    StatusEffectState,
    StatusEffectType,
    StatusSeverity,
)


@pytest.fixture
def status_manager():
    """Create StatusEffectManager with defaults."""
    return StatusEffectManager()


class TestStatusManagerInit:
    """Test StatusEffectManager initialization."""
    
    def test_init_default_data(self):
        """Test initialization with default data."""
        manager = StatusEffectManager()
        
        assert len(manager.status_database) > 0
        assert "stone" in manager.status_database
        assert "poison" in manager.status_database
    
    def test_init_empty_state(self):
        """Test initial state is empty."""
        manager = StatusEffectManager()
        
        assert len(manager.active_effects) == 0
        assert len(manager.immunity_active) == 0


class TestStatusEffectStateModel:
    """Test StatusEffectState model."""
    
    def test_status_effect_state_creation(self):
        """Test creating status effect state."""
        state = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        assert state.effect_type == StatusEffectType.POISON
        assert state.severity == StatusSeverity.MEDIUM
    
    def test_status_effect_age_seconds(self):
        """Test age calculation."""
        state = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now() - timedelta(seconds=5),
        )
        
        age = state.age_seconds
        
        assert age >= 4.9  # Allow for slight timing variance
    
    def test_status_effect_is_recent(self):
        """Test recent status check."""
        recent = StatusEffectState(
            effect_type=StatusEffectType.STUN,
            severity=StatusSeverity.HIGH,
            inflicted_time=datetime.now(),
        )
        
        old = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now() - timedelta(seconds=5),
        )
        
        assert recent.is_recent
        assert not old.is_recent


class TestStatusDetection:
    """Test status effect detection."""
    
    @pytest.mark.asyncio
    async def test_detect_status_effects_new(self, status_manager):
        """Test detecting new status effect."""
        game_state = {
            "character": {
                "status_effects": ["SC_POISON"]
            }
        }
        
        detected = await status_manager.detect_status_effects(game_state)
        
        assert len(detected) == 1
        assert detected[0].effect_type == StatusEffectType.POISON
    
    @pytest.mark.asyncio
    async def test_detect_status_effects_existing(self, status_manager):
        """Test detecting existing status effect."""
        # Add existing effect
        existing = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now() - timedelta(seconds=3),
        )
        status_manager.active_effects[StatusEffectType.POISON] = existing
        
        game_state = {
            "character": {
                "status_effects": ["SC_POISON"]
            }
        }
        
        detected = await status_manager.detect_status_effects(game_state)
        
        assert len(detected) == 1
        # Should be same instance
        assert detected[0] is existing
    
    @pytest.mark.asyncio
    async def test_detect_status_effects_cleared(self, status_manager):
        """Test detecting cleared status effects."""
        # Add effect
        status_manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        # Game state without poison
        game_state = {
            "character": {
                "status_effects": []
            }
        }
        
        await status_manager.detect_status_effects(game_state)
        
        # Should be cleared
        assert StatusEffectType.POISON not in status_manager.active_effects


class TestSeverityMapping:
    """Test severity determination."""
    
    def test_get_severity_critical(self, status_manager):
        """Test critical severity."""
        severity = status_manager._get_severity(StatusEffectType.STONE)
        
        assert severity == StatusSeverity.CRITICAL
    
    def test_get_severity_high(self, status_manager):
        """Test high severity."""
        severity = status_manager._get_severity(StatusEffectType.STUN)
        
        assert severity == StatusSeverity.HIGH
    
    def test_get_severity_from_database(self, status_manager):
        """Test severity from database."""
        severity = status_manager._get_severity(StatusEffectType.POISON)
        
        # From default database
        assert severity == StatusSeverity.MEDIUM


class TestCurePrioritization:
    """Test cure prioritization."""
    
    @pytest.mark.asyncio
    async def test_prioritize_cures(self, status_manager):
        """Test sorting by priority."""
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
                severity=StatusSeverity.MEDIUM,
                inflicted_time=datetime.now(),
            ),
        ]
        
        prioritized = await status_manager.prioritize_cures(effects)
        
        # Should be sorted by severity
        assert prioritized[0].effect_type == StatusEffectType.STONE
        assert prioritized[0].severity == StatusSeverity.CRITICAL


class TestCureActions:
    """Test cure action generation."""
    
    @pytest.mark.asyncio
    async def test_get_cure_action_with_item(self, status_manager):
        """Test getting cure action with available item."""
        effect = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        available_items = {"Green Potion", "Royal Jelly"}
        
        action = await status_manager.get_cure_action(
            effect,
            available_items=available_items,
            available_sp=0,
        )
        
        assert action is not None
        assert action.method == "item"
        assert action.item_name in ["Green Potion", "Royal Jelly"]
    
    @pytest.mark.asyncio
    async def test_get_cure_action_with_skill(self, status_manager):
        """Test getting cure action with skill."""
        effect = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        action = await status_manager.get_cure_action(
            effect,
            available_items=set(),
            available_sp=100,
        )
        
        # Should try skill
        assert action is not None
        assert action.method == "skill"
    
    @pytest.mark.asyncio
    async def test_get_cure_action_uncurable(self, status_manager):
        """Test cure action for uncurable effect."""
        # Use a real status type and mark it as uncurable
        status_manager.status_database["stone"] = {
            "can_be_cured": False,
            "natural_duration": 10.0,
            "cure_items": [],
            "cure_skills": [],
        }
        
        effect = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        
        action = await status_manager.get_cure_action(effect)
        
        assert action.method == "wait"
        assert action.wait_seconds == 10.0


class TestImmunityRecommendations:
    """Test immunity recommendation system."""
    
    @pytest.mark.asyncio
    async def test_should_apply_immunity(self, status_manager):
        """Test immunity recommendation for frequent effects."""
        # Add frequent poison cures to history
        now = datetime.now()
        for i in range(5):
            status_manager.cure_history.append(
                (StatusEffectType.POISON, now - timedelta(seconds=i*10), True)
            )
        
        recommendations = await status_manager.should_apply_immunity(
            map_name="test_map",
            monsters=["Poison Spore"],
        )
        
        # Should recommend poison immunity
        assert len(recommendations) > 0
        assert any(r.status == StatusEffectType.POISON for r in recommendations)


class TestCriticalStatusCheck:
    """Test critical status checking."""
    
    def test_has_critical_status_true(self, status_manager):
        """Test detecting critical status."""
        status_manager.active_effects[StatusEffectType.STONE] = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        
        assert status_manager.has_critical_status()
    
    def test_has_critical_status_false(self, status_manager):
        """Test no critical status."""
        status_manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        assert not status_manager.has_critical_status()


class TestStatusSummary:
    """Test status summary generation."""
    
    def test_get_status_summary(self, status_manager):
        """Test getting status summary."""
        # Add mixed effects
        status_manager.active_effects[StatusEffectType.STONE] = StatusEffectState(
            effect_type=StatusEffectType.STONE,
            severity=StatusSeverity.CRITICAL,
            inflicted_time=datetime.now(),
        )
        status_manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        summary = status_manager.get_status_summary()
        
        assert summary["total_active"] == 2
        assert summary["critical_count"] == 1
        assert len(summary["effects"]) == 2


class TestEffectManagement:
    """Test effect lifecycle management."""
    
    def test_clear_effect(self, status_manager):
        """Test clearing a status effect."""
        status_manager.active_effects[StatusEffectType.POISON] = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now(),
        )
        
        status_manager.clear_effect(StatusEffectType.POISON)
        
        assert StatusEffectType.POISON not in status_manager.active_effects
    
    def test_add_immunity(self, status_manager):
        """Test adding immunity."""
        status_manager.add_immunity(StatusEffectType.FREEZE)
        
        assert StatusEffectType.FREEZE in status_manager.immunity_active
    
    def test_remove_immunity(self, status_manager):
        """Test removing immunity."""
        status_manager.immunity_active.add(StatusEffectType.FREEZE)
        
        status_manager.remove_immunity(StatusEffectType.FREEZE)
        
        assert StatusEffectType.FREEZE not in status_manager.immunity_active


class TestCureEffectiveness:
    """Test cure effectiveness tracking."""
    
    @pytest.mark.asyncio
    async def test_track_cure_effectiveness_success(self, status_manager):
        """Test tracking successful cure."""
        action = CureAction(
            effect_type=StatusEffectType.POISON,
            method="item",
            item_name="Green Potion",
            priority=5,
        )
        
        await status_manager.track_cure_effectiveness(action, success=True)
        
        assert len(status_manager.cure_history) == 1
        assert status_manager.cure_history[0][2] is True
    
    @pytest.mark.asyncio
    async def test_track_cure_effectiveness_failure(self, status_manager):
        """Test tracking failed cure."""
        action = CureAction(
            effect_type=StatusEffectType.STONE,
            method="skill",
            skill_name="Resurrection",
            priority=10,
        )
        
        await status_manager.track_cure_effectiveness(action, success=False)
        
        assert len(status_manager.cure_history) == 1
        assert status_manager.cure_history[0][2] is False


class TestRecentEffects:
    """Test recent effect tracking."""
    
    def test_get_recent_effects(self, status_manager):
        """Test getting recent effects count."""
        # Add cure history
        now = datetime.now()
        for i in range(5):
            status_manager.cure_history.append(
                (StatusEffectType.POISON, now - timedelta(seconds=i*10), True)
            )
        for i in range(2):
            status_manager.cure_history.append(
                (StatusEffectType.BLIND, now - timedelta(seconds=i*15), True)
            )
        
        recent = status_manager._get_recent_effects(seconds=60)
        
        assert recent[StatusEffectType.POISON] == 5
        assert recent[StatusEffectType.BLIND] == 2


class TestStatusMapping:
    """Test status ID mapping."""
    
    def test_map_status_id_known(self, status_manager):
        """Test mapping known status ID."""
        effect_type = status_manager._map_status_id("SC_POISON")
        
        assert effect_type == StatusEffectType.POISON
    
    def test_map_status_id_unknown(self, status_manager):
        """Test mapping unknown status ID."""
        effect_type = status_manager._map_status_id("SC_UNKNOWN")
        
        assert effect_type is None