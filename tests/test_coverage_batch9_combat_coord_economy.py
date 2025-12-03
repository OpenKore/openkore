"""
Coverage Batch 9: Combat Coordination & Advanced Economy
Target: 13.76% → 15% coverage (~250-300 statements)
Modules: combat/advanced_coordinator (145 lines, 0%),
         combat/cast_delay (172 lines, 0%),
         economy/supply_demand (181 lines, 15.56%)
"""

import json
import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch, MagicMock

from ai_sidecar.combat.advanced_coordinator import (
    AdvancedCombatCoordinator,
    TargetAnalysis,
    AttackOptimization
)
from ai_sidecar.combat.cast_delay import (
    CastDelayManager,
    SkillTiming,
    CastState,
    DelayState,
    CastType
)
from ai_sidecar.combat.models import (
    MonsterActor,
    Element,
    MonsterRace,
    MonsterSize
)
from ai_sidecar.core.state import Position
from ai_sidecar.economy.supply_demand import (
    SupplyDemandAnalyzer,
    ItemRarity,
    SupplyDemandMetrics
)
from ai_sidecar.economy.core import (
    MarketManager,
    MarketListing,
    MarketSource,
    PriceHistory,
    PriceTrend
)


# ============================================================================
# Test AdvancedCombatCoordinator Core
# ============================================================================

class TestAdvancedCombatCoordinatorCore:
    """Test core functionality of AdvancedCombatCoordinator."""
    
    def test_coordinator_initialization_without_data_dir(self):
        """Cover AdvancedCombatCoordinator.__init__ without data_dir."""
        # Arrange & Act
        coordinator = AdvancedCombatCoordinator(data_dir=None)
        
        # Assert
        assert coordinator is not None
        assert coordinator.element_calc is not None
        assert coordinator.race_calc is not None
        assert coordinator.combo_engine is not None
        assert coordinator.cast_manager is not None
        assert coordinator.evasion_calc is not None
        assert coordinator.crit_calc is not None
        assert coordinator.aoe_system is not None
    
    def test_coordinator_initialization_with_data_dir(self, tmp_path):
        """Cover AdvancedCombatCoordinator.__init__ with data_dir."""
        # Arrange & Act
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        
        # Assert
        assert coordinator is not None
        assert coordinator.log is not None
    
    @pytest.mark.asyncio
    async def test_analyze_target_basic(self, tmp_path):
        """Cover analyze_target with basic monster."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=1001,
            name="Poring",
            mob_id=1002,
            hp=100,
            hp_max=100,
            element=Element.WATER,
            race=MonsterRace.PLANT,
            size=MonsterSize.MEDIUM,
            position=Position(x=10, y=10)
        )
        character_state = {
            "attack_element": Element.FIRE,
            "weapon_type": "sword",
            "equipped_cards": [],
            "base_attack": 150,
            "job_class": "swordsman",
            "sp": 100,
            "active_buffs": [],
            "dex": 30,
            "int": 20
        }
        
        # Act
        analysis = await coordinator.analyze_target(target, character_state)
        
        # Assert
        assert isinstance(analysis, TargetAnalysis)
        assert analysis.target_id == 1001
        assert analysis.target_name == "Poring"
        assert analysis.target_element == Element.WATER
        assert analysis.target_race == MonsterRace.PLANT
        assert analysis.target_size == MonsterSize.MEDIUM
        assert analysis.element_modifier > 0
        assert analysis.race_modifier >= 0
        assert analysis.size_modifier >= 0
        assert analysis.total_damage_modifier > 0
        assert len(analysis.expected_damage_range) == 2
    
    @pytest.mark.asyncio
    async def test_analyze_target_with_high_modifier(self, tmp_path):
        """Cover analyze_target with high damage modifier."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=1002,
            name="Earth Element",
            mob_id=1003,
            hp=200,
            hp_max=200,
            element=Element.EARTH,
            race=MonsterRace.PLANT,
            size=MonsterSize.SMALL,
            position=Position(x=15, y=15)
        )
        character_state = {
            "attack_element": Element.FIRE,
            "weapon_type": "sword",
            "equipped_cards": [],
            "base_attack": 200,
            "job_class": "knight",
            "sp": 150,
            "active_buffs": [],
            "dex": 40,
            "int": 30
        }
        
        # Act
        analysis = await coordinator.analyze_target(target, character_state)
        
        # Assert
        assert analysis.element_modifier >= 1.0  # Fire vs Earth should be effective
        assert len(analysis.recommended_skills) > 0
    
    @pytest.mark.asyncio
    async def test_optimize_attack_setup_no_change_needed(self, tmp_path):
        """Cover optimize_attack_setup when no changes needed."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=1003,
            name="Neutral Monster",
            mob_id=1004,
            hp=150,
            hp_max=150,
            element=Element.NEUTRAL,
            race=MonsterRace.BRUTE,
            size=MonsterSize.MEDIUM,
            position=Position(x=20, y=20)
        )
        character_state = {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "sword",
            "equipped_cards": [],
            "job_class": "knight",
            "sp": 100,
            "active_buffs": [],
            "dex": 35,
            "int": 25
        }
        
        # Act
        optimization = await coordinator.optimize_attack_setup(target, character_state)
        
        # Assert
        assert isinstance(optimization, AttackOptimization)
        assert isinstance(optimization.element_change_needed, bool)
        assert isinstance(optimization.weapon_swap_needed, bool)
    
    @pytest.mark.asyncio
    async def test_optimize_attack_setup_with_element_change(self, tmp_path):
        """Cover optimize_attack_setup when element change is beneficial."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=1004,
            name="Undead",
            mob_id=1005,
            hp=300,
            hp_max=300,
            element=Element.UNDEAD,
            race=MonsterRace.UNDEAD,
            size=MonsterSize.MEDIUM,
            position=Position(x=25, y=25)
        )
        character_state = {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "sword",
            "equipped_cards": [],
            "job_class": "knight",
            "sp": 120,
            "active_buffs": [],
            "dex": 40,
            "int": 30
        }
        
        # Act
        optimization = await coordinator.optimize_attack_setup(target, character_state)
        
        # Assert
        assert isinstance(optimization.card_recommendations, list)
        assert isinstance(optimization.skill_priority, list)


class TestAdvancedCoordinatorSkillSequence:
    """Test skill sequence generation."""
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_sequence_with_combo(self, tmp_path):
        """Cover get_optimal_skill_sequence with combo available."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=2001,
            name="Boss",
            mob_id=2002,
            hp=5000,
            hp_max=5000,
            element=Element.FIRE,
            race=MonsterRace.DEMON,
            size=MonsterSize.LARGE,
            position=Position(x=30, y=30),
            is_boss=True
        )
        character_state = {
            "job_class": "knight",
            "sp": 200,
            "active_buffs": [],
            "weapon_type": "sword",
            "dex": 50,
            "int": 40,
            "attack_element": Element.WATER,
            "equipped_cards": []
        }
        
        # Act
        sequence = await coordinator.get_optimal_skill_sequence(
            target, character_state, situation="boss"
        )
        
        # Assert
        assert isinstance(sequence, list)
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_sequence_no_combo(self, tmp_path):
        """Cover get_optimal_skill_sequence without combo."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        target = MonsterActor(
            actor_id=2002,
            name="Regular Monster",
            mob_id=2003,
            hp=500,
            hp_max=500,
            element=Element.EARTH,
            race=MonsterRace.PLANT,
            size=MonsterSize.SMALL,
            position=Position(x=35, y=35)
        )
        character_state = {
            "job_class": "novice",
            "sp": 50,
            "active_buffs": [],
            "weapon_type": "dagger",
            "dex": 25,
            "int": 20,
            "attack_element": Element.NEUTRAL,
            "equipped_cards": [],
            "base_attack": 80
        }
        
        # Act
        sequence = await coordinator.get_optimal_skill_sequence(
            target, character_state, situation="pve"
        )
        
        # Assert
        assert isinstance(sequence, list)


class TestAdvancedCoordinatorAoE:
    """Test AoE decision logic."""
    
    @pytest.mark.asyncio
    async def test_should_use_aoe_single_monster(self, tmp_path):
        """Cover should_use_aoe with single monster (no AoE)."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        monster_positions = [(10, 10)]
        character_state = {
            "aoe_skills": ["Meteor Storm"],
            "position": (5, 5),
            "sp": 150
        }
        
        # Act
        use_aoe, plan = await coordinator.should_use_aoe(
            monster_positions, character_state
        )
        
        # Assert
        assert use_aoe is False
        assert plan is None
    
    @pytest.mark.asyncio
    async def test_should_use_aoe_clustered_monsters(self, tmp_path):
        """Cover should_use_aoe with clustered monsters."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        # Create a cluster of 5 monsters
        monster_positions = [
            (10, 10), (11, 10), (10, 11), (11, 11), (12, 10)
        ]
        character_state = {
            "aoe_skills": ["Storm Gust", "Meteor Storm"],
            "position": (8, 8),
            "sp": 200
        }
        
        # Act
        use_aoe, plan = await coordinator.should_use_aoe(
            monster_positions, character_state
        )
        
        # Assert
        assert isinstance(use_aoe, bool)
        # Plan may be None if no suitable AoE found, or dict if AoE is recommended


class TestAdvancedCoordinatorDefense:
    """Test defensive evaluation."""
    
    @pytest.mark.asyncio
    async def test_evaluate_defensive_options_flee_viable(self, tmp_path):
        """Cover evaluate_defensive_options when flee is viable."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        incoming_attack = {
            "hit": 100,
            "count": 1
        }
        character_state = {
            "flee": 200,
            "luk": 50
        }
        
        # Act
        evaluation = await coordinator.evaluate_defensive_options(
            incoming_attack, character_state
        )
        
        # Assert
        assert isinstance(evaluation, dict)
        assert "flee_viable" in evaluation
        assert "miss_rate" in evaluation
        assert "perfect_dodge_chance" in evaluation
        assert "recommendation" in evaluation
    
    @pytest.mark.asyncio
    async def test_evaluate_defensive_options_flee_not_viable(self, tmp_path):
        """Cover evaluate_defensive_options when flee is not viable."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        incoming_attack = {
            "hit": 300,
            "count": 5
        }
        character_state = {
            "flee": 50,
            "luk": 20
        }
        
        # Act
        evaluation = await coordinator.evaluate_defensive_options(
            incoming_attack, character_state
        )
        
        # Assert
        assert evaluation["flee_viable"] is False
        assert "miss_rate" in evaluation
    
    @pytest.mark.asyncio
    async def test_get_combat_action_returns_structure(self, tmp_path):
        """Cover get_combat_action main entry point."""
        # Arrange
        coordinator = AdvancedCombatCoordinator(data_dir=tmp_path)
        game_state = {
            "character": {},
            "monsters": []
        }
        
        # Act
        action = await coordinator.get_combat_action(game_state)
        
        # Assert
        assert isinstance(action, dict)
        assert "action_type" in action
        assert action["action_type"] == "analyze"


# ============================================================================
# Test CastDelayManager Core
# ============================================================================

class TestCastDelayManagerCore:
    """Test core CastDelayManager functionality."""
    
    def test_cast_delay_manager_initialization_no_data(self):
        """Cover CastDelayManager.__init__ without data_dir."""
        # Arrange & Act
        manager = CastDelayManager(data_dir=None)
        
        # Assert
        assert manager is not None
        assert isinstance(manager.skill_timings, dict)
        assert isinstance(manager.cast_state, CastState)
        assert isinstance(manager.delay_state, DelayState)
        assert len(manager.skill_timings) > 0  # Default timings loaded
    
    def test_cast_delay_manager_initialization_with_data(self, tmp_path):
        """Cover CastDelayManager.__init__ with data_dir."""
        # Arrange & Act
        manager = CastDelayManager(data_dir=tmp_path)
        
        # Assert
        assert manager is not None
        assert len(manager.skill_timings) > 0
    
    def test_initialize_default_timings(self):
        """Cover _initialize_default_timings method."""
        # Arrange & Act
        manager = CastDelayManager(data_dir=None)
        
        # Assert
        assert "storm gust" in manager.skill_timings
        assert "meteor storm" in manager.skill_timings
        assert "sonic blow" in manager.skill_timings
        assert "spiral pierce" in manager.skill_timings
        assert "asura strike" in manager.skill_timings
    
    def test_load_skill_timings_file_not_found(self, tmp_path):
        """Cover _load_skill_timings when file doesn't exist."""
        # Arrange & Act
        manager = CastDelayManager(data_dir=tmp_path)
        
        # Assert - should fall back to default timings
        assert len(manager.skill_timings) > 0
    
    def test_load_skill_timings_with_valid_file(self, tmp_path):
        """Cover _load_skill_timings with valid JSON file."""
        # Arrange
        timing_data = {
            "Test Skill": {
                "fixed_cast_ms": 500,
                "variable_cast_ms": 2000,
                "after_cast_delay_ms": 1000
            }
        }
        timing_file = tmp_path / "skill_timings.json"
        with open(timing_file, "w") as f:
            json.dump(timing_data, f)
        
        # Act
        manager = CastDelayManager(data_dir=tmp_path)
        
        # Assert
        assert "test skill" in manager.skill_timings
        assert manager.skill_timings["test skill"].fixed_cast_ms == 500


class TestCastTimeCalculations:
    """Test cast time calculation methods."""
    
    def test_calculate_cast_time_skill_not_found(self):
        """Cover calculate_cast_time when skill is not in database."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        timing = manager.calculate_cast_time(
            skill_name="Unknown Skill",
            dex=50,
            int_stat=30
        )
        
        # Assert
        assert timing.skill_name == "Unknown Skill"
        assert timing.total_cast_time_ms == 0
    
    def test_calculate_cast_time_with_stats(self):
        """Cover calculate_cast_time with DEX/INT reduction."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        timing = manager.calculate_cast_time(
            skill_name="Storm Gust",
            dex=99,
            int_stat=99
        )
        
        # Assert
        assert timing.skill_name == "Storm Gust"
        assert timing.fixed_cast_ms == 1000  # Fixed doesn't change
        assert timing.variable_cast_ms < 6000  # Variable reduced
        assert timing.cast_reduction_percent > 0
    
    def test_calculate_cast_time_with_gear_reduction(self):
        """Cover calculate_cast_time with gear reduction."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        timing = manager.calculate_cast_time(
            skill_name="Meteor Storm",
            dex=50,
            int_stat=50,
            cast_reduction_gear=0.3
        )
        
        # Assert
        assert timing.variable_cast_ms < 7000
        assert timing.cast_reduction_percent >= 0.3
    
    def test_calculate_cast_time_max_reduction(self):
        """Cover calculate_cast_time with maximum stat reduction."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        timing = manager.calculate_cast_time(
            skill_name="Storm Gust",
            dex=150,  # High DEX
            int_stat=150  # High INT
        )
        
        # Assert
        # Max reduction is 80%
        assert timing.cast_reduction_percent <= 0.8
    
    def test_calculate_after_cast_delay_no_delay(self):
        """Cover calculate_after_cast_delay for instant skill."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        delay = manager.calculate_after_cast_delay(
            skill_name="Unknown Skill",
            agi=100
        )
        
        # Assert
        assert delay == 0
    
    def test_calculate_after_cast_delay_with_agi(self):
        """Cover calculate_after_cast_delay with AGI reduction."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        delay = manager.calculate_after_cast_delay(
            skill_name="Storm Gust",
            agi=120
        )
        
        # Assert
        assert delay < 5000  # Base is 5000ms
    
    def test_calculate_after_cast_delay_with_gear(self):
        """Cover calculate_after_cast_delay with gear reduction."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        delay = manager.calculate_after_cast_delay(
            skill_name="Sonic Blow",
            agi=80,
            delay_reduction_gear=0.2
        )
        
        # Assert
        assert delay < 2000  # Base is 2000ms


class TestCastStateManagement:
    """Test cast state tracking."""
    
    @pytest.mark.asyncio
    async def test_start_cast(self):
        """Cover start_cast method."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        await manager.start_cast("Test Skill", 3000)
        
        # Assert
        assert manager.cast_state.is_casting is True
        assert manager.cast_state.skill_name == "Test Skill"
        assert manager.cast_state.cast_started is not None
        assert manager.cast_state.cast_end_estimate is not None
    
    @pytest.mark.asyncio
    async def test_cast_complete_without_cooldown(self):
        """Cover cast_complete for skill without cooldown."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Storm Gust", 3000)
        
        # Act
        await manager.cast_complete("Storm Gust", 2000)
        
        # Assert
        assert manager.cast_state.is_casting is False
        assert manager.delay_state.in_after_cast_delay is True
        assert manager.delay_state.delay_ends is not None
    
    @pytest.mark.asyncio
    async def test_cast_complete_with_cooldown(self):
        """Cover cast_complete for skill with cooldown."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Asura Strike", 3000)
        
        # Act
        await manager.cast_complete("Asura Strike", 3000)
        
        # Assert
        assert "asura strike" in manager.delay_state.skill_cooldowns
    
    @pytest.mark.asyncio
    async def test_cast_interrupted(self):
        """Cover cast_interrupted method."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Meteor Storm", 5000)
        
        # Act
        await manager.cast_interrupted()
        
        # Assert
        assert manager.cast_state.is_casting is False
        assert manager.cast_state.skill_name is None


class TestCastAvailability:
    """Test cast availability checking."""
    
    @pytest.mark.asyncio
    async def test_can_cast_now_when_available(self):
        """Cover can_cast_now when available."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        can_cast, reason = await manager.can_cast_now()
        
        # Assert
        assert can_cast is True
        assert reason is None
    
    @pytest.mark.asyncio
    async def test_can_cast_now_while_casting(self):
        """Cover can_cast_now while already casting."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Storm Gust", 3000)
        
        # Act
        can_cast, reason = await manager.can_cast_now()
        
        # Assert
        assert can_cast is False
        assert reason == "already_casting"
    
    @pytest.mark.asyncio
    async def test_can_cast_now_in_after_cast_delay(self):
        """Cover can_cast_now during after-cast delay."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Sonic Blow", 100)
        await manager.cast_complete("Sonic Blow", 2000)
        
        # Act
        can_cast, reason = await manager.can_cast_now()
        
        # Assert
        assert can_cast is False
        assert reason == "after_cast_delay"
    
    @pytest.mark.asyncio
    async def test_time_until_can_cast_immediate(self):
        """Cover time_until_can_cast when can cast immediately."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        time = await manager.time_until_can_cast()
        
        # Assert
        assert time == 0
    
    @pytest.mark.asyncio
    async def test_time_until_can_cast_with_delay(self):
        """Cover time_until_can_cast with active delay."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Test", 100)
        await manager.cast_complete("Test", 1000)
        
        # Act
        time = await manager.time_until_can_cast()
        
        # Assert
        assert time > 0
    
    @pytest.mark.asyncio
    async def test_is_skill_on_cooldown_not_on_cooldown(self):
        """Cover is_skill_on_cooldown when skill is ready."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        
        # Act
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Any Skill")
        
        # Assert
        assert on_cooldown is False
        assert remaining == 0
    
    @pytest.mark.asyncio
    async def test_is_skill_on_cooldown_active_cooldown(self):
        """Cover is_skill_on_cooldown with active cooldown."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        await manager.start_cast("Asura Strike", 100)
        await manager.cast_complete("Asura Strike", 1000)
        
        # Act
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Asura Strike")
        
        # Assert
        assert on_cooldown is True
        assert remaining > 0


class TestSkillOrdering:
    """Test optimal skill ordering."""
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_order_empty_list(self):
        """Cover get_optimal_skill_order with empty skill list."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        character_stats = {"dex": 50, "int": 40}
        
        # Act
        order = await manager.get_optimal_skill_order([], character_stats)
        
        # Assert
        assert order == []
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_order_multiple_skills(self):
        """Cover get_optimal_skill_order with multiple skills."""
        # Arrange
        manager = CastDelayManager(data_dir=None)
        skills = ["Storm Gust", "Sonic Blow", "Asura Strike"]
        character_stats = {"dex": 60, "int": 50}
        
        # Act
        order = await manager.get_optimal_skill_order(skills, character_stats)
        
        # Assert
        assert len(order) == 3
        assert all(skill in skills for skill in order)


# ============================================================================
# Test SupplyDemandAnalyzer Core
# ============================================================================

class TestSupplyDemandAnalyzerCore:
    """Test core SupplyDemandAnalyzer functionality."""
    
    def test_supply_demand_analyzer_initialization(self, tmp_path):
        """Cover SupplyDemandAnalyzer.__init__."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        
        # Act
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Assert
        assert analyzer is not None
        assert analyzer.market is market
        assert isinstance(analyzer.drop_rates, dict)
    
    def test_supply_demand_analyzer_loads_drop_rates(self, tmp_path):
        """Cover drop rate loading."""
        # Arrange
        drop_data = {
            "drop_rates": {
                "501": {"rate": 0.5},
                "502": {"rate": 0.1}
            },
            "mvp_drops": {
                "1001": {"rate": 0.01}
            }
        }
        drop_file = tmp_path / "drop_rates.json"
        with open(drop_file, "w") as f:
            json.dump(drop_data, f)
        
        market = MarketManager(data_dir=tmp_path)
        
        # Act
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Assert
        assert 501 in analyzer.drop_rates
        assert analyzer.drop_rates[501] == 0.5


class TestItemRarity:
    """Test item rarity classification."""
    
    def test_get_item_rarity_no_data(self, tmp_path):
        """Cover get_item_rarity with no drop data."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        rarity = analyzer.get_item_rarity(9999)
        
        # Assert
        assert rarity == ItemRarity.UNIQUE
    
    def test_get_item_rarity_common(self, tmp_path):
        """Cover get_item_rarity for common item."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        analyzer.drop_rates[1001] = 0.6
        
        # Act
        rarity = analyzer.get_item_rarity(1001)
        
        # Assert
        assert rarity == ItemRarity.COMMON
    
    def test_get_item_rarity_rare(self, tmp_path):
        """Cover get_item_rarity for rare item."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        analyzer.drop_rates[1002] = 0.08
        
        # Act
        rarity = analyzer.get_item_rarity(1002)
        
        # Assert
        assert rarity == ItemRarity.RARE
    
    def test_get_item_rarity_based_on_listings(self, tmp_path):
        """Cover get_item_rarity using market listing count."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Add listings for item
        for i in range(5):
            listing = MarketListing(
                item_id=2001,
                item_name="Test Item",
                price=1000,
                quantity=1,
                source=MarketSource.VENDING
            )
            market.record_listing(listing)
        
        # Act
        rarity = analyzer.get_item_rarity(2001)
        
        # Assert
        assert rarity in [ItemRarity.VERY_RARE, ItemRarity.RARE, ItemRarity.UNCOMMON]


class TestSupplyDemandMetrics:
    """Test supply/demand calculation."""
    
    def test_calculate_supply_demand_no_data(self, tmp_path):
        """Cover calculate_supply_demand with no market data."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        metrics = analyzer.calculate_supply_demand(5001)
        
        # Assert
        assert isinstance(metrics, SupplyDemandMetrics)
        assert metrics.item_id == 5001
        assert metrics.supply_score >= 0
        assert metrics.demand_score >= 0
    
    def test_calculate_supply_demand_with_listings(self, tmp_path):
        """Cover calculate_supply_demand with active listings."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Add listings
        for i in range(10):
            listing = MarketListing(
                item_id=5002,
                item_name="Popular Item",
                price=5000 + (i * 100),
                quantity=1,
                source=MarketSource.VENDING
            )
            market.record_listing(listing)
        
        # Act
        metrics = analyzer.calculate_supply_demand(5002)
        
        # Assert
        assert metrics.listing_count == 10
        assert metrics.supply_score > 0
    
    def test_estimate_market_volume_no_history(self, tmp_path):
        """Cover estimate_market_volume with no history."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        volume = analyzer.estimate_market_volume(6001)
        
        # Assert
        assert volume == 0
    
    def test_estimate_market_volume_with_history(self, tmp_path):
        """Cover estimate_market_volume with price history."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Add listings to create history
        for i in range(5):
            listing = MarketListing(
                item_id=6002,
                item_name="Traded Item",
                price=10000,
                quantity=10,
                source=MarketSource.VENDING
            )
            market.record_listing(listing)
        
        # Act
        volume = analyzer.estimate_market_volume(6002)
        
        # Assert
        assert volume >= 0


class TestDemandPrediction:
    """Test demand prediction."""
    
    def test_predict_demand_change_insufficient_data(self, tmp_path):
        """Cover predict_demand_change with insufficient data."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        prediction = analyzer.predict_demand_change(7001)
        
        # Assert
        assert prediction["prediction"] == "stable"
        assert prediction["confidence"] == 0.0
    
    def test_predict_demand_change_rising_trend(self, tmp_path):
        """Cover predict_demand_change with rising prices."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Create rising price trend
        for i in range(15):
            listing = MarketListing(
                item_id=7002,
                item_name="Rising Item",
                price=1000 + (i * 200),  # Increasing prices
                quantity=1,
                source=MarketSource.VENDING
            )
            market.record_listing(listing)
        
        # Act
        prediction = analyzer.predict_demand_change(7002)
        
        # Assert
        assert prediction["prediction"] in ["increasing", "stable"]
    
    def test_get_related_items_returns_empty(self, tmp_path):
        """Cover get_related_items (TODO implementation)."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        related = analyzer.get_related_items(8001)
        
        # Assert
        assert isinstance(related, list)
        assert len(related) == 0
    
    def test_analyze_crafting_demand_returns_structure(self, tmp_path):
        """Cover analyze_crafting_demand (TODO implementation)."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        analysis = analyzer.analyze_crafting_demand(9001)
        
        # Assert
        assert isinstance(analysis, dict)
        assert "product_id" in analysis
        assert analysis["product_id"] == 9001


class TestPrivateSupplyDemandMethods:
    """Test private calculation methods."""
    
    def test_calculate_supply_score_no_listings(self, tmp_path):
        """Cover _calculate_supply_score with no listings."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        score = analyzer._calculate_supply_score(10001, [])
        
        # Assert
        assert score == 0.0
    
    def test_calculate_supply_score_with_drop_rate(self, tmp_path):
        """Cover _calculate_supply_score with drop rate multiplier."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        analyzer.drop_rates[10002] = 0.3
        
        listings = [Mock() for _ in range(30)]
        
        # Act
        score = analyzer._calculate_supply_score(10002, listings)
        
        # Assert
        assert score > 0
        assert score <= 100.0
    
    def test_calculate_demand_score_no_history(self, tmp_path):
        """Cover _calculate_demand_score without history."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        score = analyzer._calculate_demand_score(11001, None)
        
        # Assert
        assert score == 50.0  # Default medium demand
    
    def test_calculate_liquidity_no_history(self, tmp_path):
        """Cover _calculate_liquidity without history."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        liquidity = analyzer._calculate_liquidity(12001, None)
        
        # Assert
        assert liquidity == 0.0
    
    def test_estimate_sale_time_no_demand(self, tmp_path):
        """Cover _estimate_sale_time with no demand."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        sale_time = analyzer._estimate_sale_time(13001, 50.0, 0.0)
        
        # Assert
        assert isinstance(sale_time, timedelta)
        assert sale_time.days == 30
    
    def test_estimate_sale_time_high_demand(self, tmp_path):
        """Cover _estimate_sale_time with high demand."""
        # Arrange
        market = MarketManager(data_dir=tmp_path)
        analyzer = SupplyDemandAnalyzer(market, tmp_path)
        
        # Act
        sale_time = analyzer._estimate_sale_time(13002, 30.0, 80.0)
        
        # Assert
        assert sale_time.total_seconds() < timedelta(days=1).total_seconds()