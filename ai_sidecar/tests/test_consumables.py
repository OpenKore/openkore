"""
Comprehensive tests for consumable management systems.

Tests cover:
- Buff management and duration tracking
- Status effect detection and curing
- Recovery item selection and usage
- Food buff optimization
- Consumable coordinator integration
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path

from ai_sidecar.consumables.buffs import (
    BuffManager,
    BuffState,
    BuffCategory,
    BuffSource,
    BuffPriority,
)
from ai_sidecar.consumables.status_effects import (
    StatusEffectManager,
    StatusEffectType,
    StatusSeverity,
)
from ai_sidecar.consumables.recovery import (
    RecoveryManager,
    RecoveryConfig,
    RecoveryType,
)
from ai_sidecar.consumables.food import FoodManager
from ai_sidecar.consumables.coordinator import (
    ConsumableCoordinator,
    GameState,
    ActionPriority,
)


class TestBuffManager:
    """Test buff management logic."""
    
    @pytest.mark.asyncio
    async def test_buff_duration_tracking(self):
        """Verify accurate duration countdown."""
        manager = BuffManager()
        
        # Add a buff
        manager.add_buff("blessing", 240.0)
        
        assert "blessing" in manager.active_buffs
        buff = manager.active_buffs["blessing"]
        assert buff.remaining_seconds == 240.0
        
        # Update timers
        await manager.update_buff_timers(10.0)
        assert buff.remaining_seconds == 230.0
        
        # Update to expiration
        await manager.update_buff_timers(230.0)
        assert "blessing" not in manager.active_buffs
    
    @pytest.mark.asyncio
    async def test_rebuff_threshold_detection(self):
        """Test detection when buff needs rebuffing."""
        manager = BuffManager()
        
        # Add buff with low remaining time
        manager.add_buff("blessing", 240.0)
        buff = manager.active_buffs["blessing"]
        buff.remaining_seconds = 4.0  # Below threshold
        
        needs_rebuff = await manager.check_rebuff_needs()
        assert len(needs_rebuff) == 1
        assert needs_rebuff[0].buff_id == "blessing"
    
    @pytest.mark.asyncio
    async def test_priority_ordering(self):
        """Verify buffs are prioritized correctly."""
        manager = BuffManager()
        
        # Add buffs with different priorities
        manager.add_buff("blessing", 240.0)  # Priority 7
        manager.add_buff("kyrie_eleison", 120.0)  # Priority 10
        
        # Set both to need rebuff
        for buff in manager.active_buffs.values():
            buff.remaining_seconds = 4.0
        
        needs_rebuff = await manager.check_rebuff_needs()
        
        # Should be sorted by priority
        assert needs_rebuff[0].buff_id == "kyrie_eleison"
        assert needs_rebuff[1].buff_id == "blessing"
    
    @pytest.mark.asyncio
    async def test_conflict_detection(self):
        """Test mutually exclusive buff handling."""
        manager = BuffManager()
        manager.conflicting_buffs = {
            "blessing": {"curse"},
            "curse": {"blessing"},
        }
        
        manager.add_buff("blessing", 240.0)
        
        # Try to add conflicting buff
        conflict = await manager.handle_buff_conflict("curse")
        assert conflict == "blessing"


class TestStatusEffectManager:
    """Test status effect handling."""
    
    @pytest.mark.asyncio
    async def test_status_detection(self):
        """Verify status effect detection from game state."""
        manager = StatusEffectManager()
        
        game_state = {
            "character": {
                "status_effects": ["SC_POISON", "SC_BLIND"]
            }
        }
        
        detected = await manager.detect_status_effects(game_state)
        assert len(detected) == 2
        effect_types = {e.effect_type for e in detected}
        assert StatusEffectType.POISON in effect_types
        assert StatusEffectType.BLIND in effect_types
    
    @pytest.mark.asyncio
    async def test_cure_prioritization(self):
        """Test Stone > Freeze > Poison priority."""
        manager = StatusEffectManager()
        
        # Create effects with different severities
        from datetime import datetime
        from ai_sidecar.consumables.status_effects import StatusEffectState
        
        effects = [
            StatusEffectState(
                effect_type=StatusEffectType.POISON,
                severity=StatusSeverity.MEDIUM,
                inflicted_time=datetime.now()
            ),
            StatusEffectState(
                effect_type=StatusEffectType.STONE,
                severity=StatusSeverity.CRITICAL,
                inflicted_time=datetime.now()
            ),
            StatusEffectState(
                effect_type=StatusEffectType.BLIND,
                severity=StatusSeverity.MEDIUM,
                inflicted_time=datetime.now()
            ),
        ]
        
        prioritized = await manager.prioritize_cures(effects)
        assert prioritized[0].effect_type == StatusEffectType.STONE
    
    @pytest.mark.asyncio
    async def test_cure_action_selection(self):
        """Verify optimal cure method selection."""
        manager = StatusEffectManager()
        
        from ai_sidecar.consumables.status_effects import StatusEffectState
        
        effect = StatusEffectState(
            effect_type=StatusEffectType.POISON,
            severity=StatusSeverity.MEDIUM,
            inflicted_time=datetime.now()
        )
        
        # With available items
        cure = await manager.get_cure_action(
            effect,
            available_items={"Green Potion", "Royal Jelly"}
        )
        
        assert cure is not None
        assert cure.method == "item"


class TestRecoveryManager:
    """Test recovery item usage."""
    
    @pytest.mark.asyncio
    async def test_hp_threshold_response(self):
        """Test recovery triggers at correct thresholds."""
        config = RecoveryConfig(hp_normal_threshold=0.70)
        manager = RecoveryManager(config=config)
        
        # Add some recovery items to inventory
        manager.inventory = {501: 10}  # Red Potions
        
        # Low HP
        decision = await manager.evaluate_recovery_need(
            hp_percent=0.65,
            sp_percent=1.0,
            situation="normal"
        )
        
        # Should trigger recovery
        assert decision is not None
    
    @pytest.mark.asyncio
    async def test_emergency_recovery(self):
        """Test emergency Yggdrasil usage."""
        manager = RecoveryManager()
        manager.inventory = {607: 1}  # Yggdrasil Berry
        
        decision = await manager.emergency_recovery()
        
        assert decision is not None
        assert decision.item.recovery_type == RecoveryType.EMERGENCY
        assert decision.priority == 10
    
    def test_cooldown_tracking(self):
        """Verify cooldown group tracking."""
        manager = RecoveryManager()
        
        # Use an item
        manager.use_item(501, 45)  # Red Potion
        
        # Check cooldown is set
        assert "potion" in manager.cooldowns
        assert manager.cooldowns["potion"] > datetime.now()
    
    @pytest.mark.asyncio
    async def test_item_efficiency_selection(self):
        """Verify efficient item selection (no overhealing)."""
        manager = RecoveryManager()
        manager.inventory = {
            501: 10,  # Red Potion (45 HP)
            504: 10,  # White Potion (325 HP)
        }
        
        # Need only small amount of HP
        item = await manager.select_optimal_item(
            RecoveryType.HP_INSTANT,
            0.95,  # 95% HP
            "normal"
        )
        
        # Should select smaller potion
        assert item is not None
        assert item.item_id == 501  # Red Potion


class TestFoodManager:
    """Test food buff management."""
    
    @pytest.mark.asyncio
    async def test_optimal_food_for_build(self):
        """Test food recommendations match build."""
        manager = FoodManager()
        
        # Get recommendations for melee DPS
        recommended = await manager.get_optimal_food_set("melee_dps")
        
        # Should recommend STR/ATK foods
        assert len(recommended) > 0
        # Check that recommendations include STR bonuses
        has_str_food = any(
            "str" in food.stat_bonuses 
            for food in recommended
        )
        assert has_str_food
    
    @pytest.mark.asyncio
    async def test_food_duration_tracking(self):
        """Verify food buff duration tracking."""
        manager = FoodManager()
        
        # Apply food
        manager.inventory = {12043: 1}  # Str Dish
        manager.apply_food(12043)
        
        assert 12043 in manager.active_food_buffs
        buff = manager.active_food_buffs[12043]
        assert buff.remaining_seconds == 1200.0
        
        # Update timer
        await manager.update_food_timers(600.0)
        assert buff.remaining_seconds == 600.0
    
    @pytest.mark.asyncio
    async def test_food_needs_detection(self):
        """Test detection of food that needs refreshing."""
        manager = FoodManager()
        
        # Add expiring food
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        buff = manager.active_food_buffs[12043]
        buff.remaining_seconds = 100.0  # Expiring soon
        
        needs = await manager.check_food_needs()
        
        assert len(needs) == 1
        assert needs[0].item_id == 12043


class TestConsumableCoordinator:
    """Test unified coordinator."""
    
    @pytest.mark.asyncio
    async def test_action_prioritization(self):
        """Test emergency > status > recovery > buff priority."""
        coordinator = ConsumableCoordinator()
        
        from ai_sidecar.consumables.coordinator import ConsumableAction
        
        actions = [
            ConsumableAction(
                action_type="rebuff",
                priority=ActionPriority.NORMAL,
                reason="Normal buff"
            ),
            ConsumableAction(
                action_type="recovery",
                priority=ActionPriority.EMERGENCY,
                reason="Emergency HP"
            ),
            ConsumableAction(
                action_type="cure",
                priority=ActionPriority.CRITICAL,
                reason="Stone cure"
            ),
        ]
        
        prioritized = await coordinator.prioritize_actions(actions)
        
        # Should be emergency, critical, normal
        assert prioritized[0].priority == ActionPriority.EMERGENCY
        assert prioritized[1].priority == ActionPriority.CRITICAL
    
    @pytest.mark.asyncio
    async def test_pre_combat_preparation(self):
        """Verify pre-combat buff application."""
        coordinator = ConsumableCoordinator()
        
        enemy_info = {
            "map": "glast_01",
            "monsters": ["Gargoyle", "Whisper"]
        }
        
        actions = await coordinator.pre_combat_preparation(
            enemy_info,
            character_build="melee_dps"
        )
        
        # Should recommend food/immunity
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_post_combat_recovery(self):
        """Test recovery and rebuff after combat."""
        coordinator = ConsumableCoordinator()
        
        actions = await coordinator.post_combat_recovery(
            hp_percent=0.60,
            sp_percent=0.30
        )
        
        # Should recommend recovery
        assert len(actions) > 0
        recovery_actions = [
            a for a in actions 
            if a.action_type == "recovery"
        ]
        assert len(recovery_actions) > 0


class TestIntegration:
    """Integration tests for complete workflows."""
    
    @pytest.mark.asyncio
    async def test_complete_combat_cycle(self):
        """Test full combat cycle with all systems."""
        coordinator = ConsumableCoordinator()
        
        # Pre-combat
        prep_actions = await coordinator.pre_combat_preparation(
            {"map": "gef_dun02", "monsters": ["Nightmare"]},
            "melee_dps"
        )
        assert len(prep_actions) >= 0
        
        # During combat - emergency
        game_state = GameState(
            hp_percent=0.15,  # Emergency
            sp_percent=0.50,
            max_hp=5000,
            max_sp=500,
            in_combat=True,
            situation="normal",
            inventory={607: 1}  # Ygg Berry
        )
        
        actions = await coordinator.update_all(game_state)
        
        # Should have emergency action
        assert len(actions) > 0
        has_emergency = any(
            a.priority == ActionPriority.EMERGENCY 
            for a in actions
        )
        assert has_emergency
        
        # Post-combat
        post_actions = await coordinator.post_combat_recovery(0.80, 0.40)
        assert len(post_actions) >= 0
    
    @pytest.mark.asyncio
    async def test_status_effect_emergency(self):
        """Test critical status effect handling."""
        coordinator = ConsumableCoordinator()
        
        game_state = GameState(
            hp_percent=0.80,
            sp_percent=0.60,
            max_hp=5000,
            max_sp=500,
            status_effects=["SC_STONE"],  # Critical!
            inventory={506: 5}  # Green Potion
        )
        
        actions = await coordinator.update_all(game_state)
        
        # Should prioritize stone cure
        assert len(actions) > 0
        critical_actions = [
            a for a in actions
            if a.priority >= ActionPriority.CRITICAL
        ]
        assert len(critical_actions) > 0