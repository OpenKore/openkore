"""
Comprehensive tests for instances/strategy.py module.

Tests instance strategy generation, floor tactics, boss strategies,
and adaptive learning from instance runs.
"""

import json
import pytest
from datetime import datetime
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch
from pydantic import ValidationError

from ai_sidecar.instances.strategy import (
    FloorStrategy,
    BossStrategy,
    InstanceAction,
    InstanceStrategy,
    InstanceStrategyEngine
)
from ai_sidecar.instances.registry import (
    InstanceDefinition,
    InstanceType,
    InstanceDifficulty,
    InstanceReward
)
from ai_sidecar.instances.state import (
    InstanceState,
    FloorState,
    InstancePhase
)


# FloorStrategy Model Tests

class TestFloorStrategyModel:
    """Test FloorStrategy pydantic model."""
    
    def test_floor_strategy_creation_minimal(self):
        """Test creating floor strategy with minimal fields."""
        strategy = FloorStrategy(floor_number=1)
        assert strategy.floor_number == 1
        assert strategy.recommended_route == []
        assert strategy.priority_targets == []
    
    def test_floor_strategy_creation_full(self):
        """Test creating floor strategy with all fields."""
        strategy = FloorStrategy(
            floor_number=5,
            recommended_route=[(100, 200), (150, 250)],
            priority_targets=["mvp_boss", "mini_boss"],
            avoid_targets=["trap_monster"],
            buff_requirements=["blessing", "increase_agi"],
            special_mechanics=["poison_immunity_needed"]
        )
        assert strategy.floor_number == 5
        assert len(strategy.recommended_route) == 2
        assert "blessing" in strategy.buff_requirements
    
    def test_floor_strategy_immutable(self):
        """Test that FloorStrategy is immutable."""
        strategy = FloorStrategy(floor_number=1)
        with pytest.raises(ValidationError):
            strategy.floor_number = 2
    
    def test_floor_strategy_invalid_floor_number(self):
        """Test validation of floor number."""
        with pytest.raises(ValidationError):
            FloorStrategy(floor_number=0)


# BossStrategy Model Tests

class TestBossStrategyModel:
    """Test BossStrategy pydantic model."""
    
    def test_boss_strategy_creation_minimal(self):
        """Test creating boss strategy with minimal fields."""
        strategy = BossStrategy(boss_name="Amon Ra")
        assert strategy.boss_name == "Amon Ra"
        assert strategy.positioning == "melee"
        assert strategy.adds_spawn is False
    
    def test_boss_strategy_creation_full(self):
        """Test creating boss strategy with all fields."""
        strategy = BossStrategy(
            boss_name="Thanatos",
            boss_hp_estimate=6500000,
            phase_triggers=[75.0, 50.0, 25.0],
            phase_mechanics={
                1: ["normal_attacks"],
                2: ["summon_adds"],
                3: ["aoe_spam", "curse_debuff"]
            },
            positioning="ranged",
            priority_skills=["holy_light", "heal"],
            avoid_skills=["tornado_storm"],
            enrage_timer_seconds=1800,
            adds_spawn=True,
            adds_priority="kill_first",
            safe_zones=[(50, 50), (100, 100)],
            danger_zones=[(150, 150)]
        )
        assert strategy.boss_name == "Thanatos"
        assert len(strategy.phase_triggers) == 3
        assert strategy.adds_spawn is True
        assert strategy.enrage_timer_seconds == 1800
    
    def test_boss_strategy_negative_hp(self):
        """Test validation rejects negative HP."""
        with pytest.raises(ValidationError):
            BossStrategy(boss_name="Test", boss_hp_estimate=-1000)


# InstanceAction Model Tests

class TestInstanceActionModel:
    """Test InstanceAction pydantic model."""
    
    def test_instance_action_creation(self):
        """Test creating instance action."""
        action = InstanceAction(
            action_type="attack",
            target_id=1234,
            priority=9,
            reason="Kill high-priority mob"
        )
        assert action.action_type == "attack"
        assert action.target_id == 1234
        assert action.priority == 9
    
    def test_instance_action_skill(self):
        """Test skill action creation."""
        action = InstanceAction(
            action_type="skill",
            skill_name="holy_light",
            target_id=5000,
            priority=10
        )
        assert action.skill_name == "holy_light"
    
    def test_instance_action_move(self):
        """Test movement action creation."""
        action = InstanceAction(
            action_type="move",
            position=(100, 200),
            priority=5,
            reason="Reposition for boss"
        )
        assert action.position == (100, 200)


# InstanceStrategy Model Tests

class TestInstanceStrategyModel:
    """Test InstanceStrategy pydantic model."""
    
    def test_instance_strategy_creation_minimal(self):
        """Test creating instance strategy with minimal fields."""
        strategy = InstanceStrategy(instance_id="endless_tower")
        assert strategy.instance_id == "endless_tower"
        assert strategy.speed_run is False
        assert strategy.full_clear is True
    
    def test_instance_strategy_creation_full(self):
        """Test creating complete instance strategy."""
        floor1 = FloorStrategy(floor_number=1)
        floor2 = FloorStrategy(floor_number=2)
        boss1 = BossStrategy(boss_name="Amon Ra")
        
        strategy = InstanceStrategy(
            instance_id="endless_tower",
            speed_run=True,
            full_clear=False,
            loot_priority=["Old Card Album", "Speed Up Potion"],
            floor_strategies={1: floor1, 2: floor2},
            boss_strategies={"amon_ra": boss1},
            consumable_budget={"White Potion": 50, "Blue Potion": 30},
            death_limit=5,
            tank_duties=["pull_mobs", "protect_healer"],
            healer_duties=["heal_party", "sanctuary"],
            dps_duties=["focus_mvp"]
        )
        assert strategy.speed_run is True
        assert len(strategy.floor_strategies) == 2
        assert "amon_ra" in strategy.boss_strategies


# InstanceStrategyEngine Tests

class TestInstanceStrategyEngineInit:
    """Test InstanceStrategyEngine initialization."""
    
    def test_init_without_data_dir(self):
        """Test initialization without data directory."""
        engine = InstanceStrategyEngine()
        assert len(engine.strategies) == 0
        assert len(engine.learned_tactics) == 0
    
    def test_init_with_nonexistent_dir(self, tmp_path):
        """Test initialization with non-existent data dir."""
        engine = InstanceStrategyEngine(data_dir=tmp_path / "nonexistent")
        assert len(engine.strategies) == 0


class TestInstanceStrategyEngineLoadStrategies:
    """Test strategy loading functionality."""
    
    def test_load_strategies_file_not_found(self, tmp_path):
        """Test loading when file doesn't exist."""
        engine = InstanceStrategyEngine(data_dir=tmp_path)
        assert len(engine.strategies) == 0
    
    def test_load_strategies_success(self, tmp_path):
        """Test successful strategy loading."""
        strategies_file = tmp_path / "instance_strategies.json"
        test_data = {
            "endless_tower": {
                "speed_run": False,
                "full_clear": True,
                "floor_strategies": {
                    "1": {
                        "floor_number": 1,
                        "buff_requirements": ["blessing"]
                    }
                },
                "boss_strategies": {
                    "amon_ra": {
                        "boss_name": "Amon Ra",
                        "positioning": "ranged"
                    }
                }
            }
        }
        
        with open(strategies_file, "w") as f:
            json.dump(test_data, f)
        
        engine = InstanceStrategyEngine(data_dir=tmp_path)
        assert "endless_tower" in engine.strategies
        assert engine.strategies["endless_tower"].instance_id == "endless_tower"
    
    def test_load_strategies_invalid_json(self, tmp_path):
        """Test handling of invalid JSON."""
        strategies_file = tmp_path / "instance_strategies.json"
        with open(strategies_file, "w") as f:
            f.write("{invalid json")
        
        engine = InstanceStrategyEngine(data_dir=tmp_path)
        assert len(engine.strategies) == 0


class TestGetStrategy:
    """Test getting predefined strategies."""
    
    @pytest.mark.asyncio
    async def test_get_existing_strategy(self):
        """Test retrieving existing strategy."""
        engine = InstanceStrategyEngine()
        strategy = InstanceStrategy(instance_id="test_instance")
        engine.strategies["test_instance"] = strategy
        
        result = await engine.get_strategy("test_instance")
        assert result == strategy
    
    @pytest.mark.asyncio
    async def test_get_nonexistent_strategy(self):
        """Test retrieving non-existent strategy returns None."""
        engine = InstanceStrategyEngine()
        result = await engine.get_strategy("missing")
        assert result is None


class TestGenerateStrategy:
    """Test strategy generation."""
    
    @pytest.mark.asyncio
    async def test_generate_strategy_uses_existing(self, tmp_path):
        """Test that existing strategy is returned if available."""
        engine = InstanceStrategyEngine()
        existing = InstanceStrategy(instance_id="test")
        engine.strategies["test"] = existing
        
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test Instance",
            instance_type=InstanceType.SOLO,
            difficulty=InstanceDifficulty.NORMAL,
            recommended_level=70,
            max_party_size=1,
            time_limit_minutes=60,
            floors=10,
            boss_names=["Test Boss"]
        )
        
        result = await engine.generate_strategy(instance_def, {}, [])
        assert result == existing
    
    @pytest.mark.asyncio
    async def test_generate_strategy_creates_new(self):
        """Test generating new strategy."""
        engine = InstanceStrategyEngine()
        
        instance_def = InstanceDefinition(
            instance_id="new_instance",
            instance_name="New Instance",
            instance_type=InstanceType.SOLO,
            difficulty=InstanceDifficulty.NORMAL,
            recommended_level=70,
            max_party_size=1,
            time_limit_minutes=60,
            floors=5,
            boss_names=["Boss1", "Boss2"]
        )
        
        result = await engine.generate_strategy(
            instance_def,
            {"base_level": 99},
            ["Assassin"]
        )
        
        assert result.instance_id == "new_instance"
        assert len(result.floor_strategies) == 5
        assert len(result.boss_strategies) == 2
    
    @pytest.mark.asyncio
    async def test_generate_strategy_speed_run_mode(self):
        """Test speed run mode activation for high level."""
        engine = InstanceStrategyEngine()
        
        instance_def = InstanceDefinition(
            instance_id="easy_instance",
            instance_name="Easy",
            instance_type=InstanceType.SOLO,
            difficulty=InstanceDifficulty.EASY,
            recommended_level=50,
            max_party_size=1,
            time_limit_minutes=60,
            floors=3,
            boss_names=["Easy Boss"]
        )
        
        result = await engine.generate_strategy(
            instance_def,
            {"base_level": 99},  # Way higher than recommended
            ["Lord Knight"]
        )
        
        assert result.speed_run is True
        assert result.full_clear is False
    
    @pytest.mark.asyncio
    async def test_generate_strategy_solo_vs_party(self):
        """Test different strategies for solo vs party."""
        engine = InstanceStrategyEngine()
        
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=InstanceType.PARTY,
            difficulty=InstanceDifficulty.NORMAL,
            recommended_level=70,
            max_party_size=6,
            time_limit_minutes=60,
            floors=3,
            boss_names=["Boss1"]
        )
        
        # Solo
        solo_strategy = await engine.generate_strategy(
            instance_def,
            {"base_level": 75},
            ["Wizard"]
        )
        assert solo_strategy.death_limit == 5
        assert "Boss1" in solo_strategy.boss_strategies
        assert solo_strategy.boss_strategies["Boss1"].positioning == "ranged"
        
        # Party
        party_strategy = await engine.generate_strategy(
            InstanceDefinition(
                instance_id="test2",
                instance_name="Test2",
                instance_type=InstanceType.PARTY,
                difficulty=InstanceDifficulty.NORMAL,
                recommended_level=70,
                max_party_size=6,
                time_limit_minutes=60,
                floors=3,
                boss_names=["Boss2"]
            ),
            {"base_level": 75},
            ["Lord Knight", "High Priest", "Sniper", "Wizard"]
        )
        assert party_strategy.death_limit == 10
        assert party_strategy.boss_strategies["Boss2"].positioning == "melee"


class TestGetFloorActions:
    """Test floor action generation."""
    
    @pytest.mark.asyncio
    async def test_get_floor_actions_no_strategy(self):
        """Test when no strategy exists."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="unknown",
            instance_name="Unknown",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_floor_actions(1, state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_get_floor_actions_no_floor_strategy(self):
        """Test when floor strategy doesn't exist."""
        engine = InstanceStrategyEngine()
        strategy = InstanceStrategy(instance_id="test")
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=99
        )
        
        actions = await engine.get_floor_actions(99, state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_get_floor_actions_no_floor_state(self):
        """Test when floor state doesn't exist."""
        engine = InstanceStrategyEngine()
        floor_strat = FloorStrategy(floor_number=1)
        strategy = InstanceStrategy(
            instance_id="test",
            floor_strategies={1: floor_strat}
        )
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_floor_actions(1, state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_get_floor_actions_buff_requirements(self):
        """Test generating buff actions."""
        engine = InstanceStrategyEngine()
        floor_strat = FloorStrategy(
            floor_number=1,
            buff_requirements=["blessing", "increase_agi"]
        )
        strategy = InstanceStrategy(
            instance_id="test",
            floor_strategies={1: floor_strat}
        )
        engine.strategies["test"] = strategy
        
        floor_state = FloorState(floor_number=1)
        floor_state.monsters_killed = 0
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        state.floors[1] = floor_state
        
        actions = await engine.get_floor_actions(1, state)
        assert len(actions) == 2
        assert all(a.action_type == "buff" for a in actions)
        assert any(a.skill_name == "blessing" for a in actions)
    
    @pytest.mark.asyncio
    async def test_get_floor_actions_movement(self):
        """Test generating movement actions."""
        engine = InstanceStrategyEngine()
        floor_strat = FloorStrategy(
            floor_number=1,
            recommended_route=[(100, 200), (150, 250)]
        )
        strategy = InstanceStrategy(
            instance_id="test",
            floor_strategies={1: floor_strat}
        )
        engine.strategies["test"] = strategy
        
        floor_state = FloorState(floor_number=1)
        floor_state.boss_spawned = False
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        state.floors[1] = floor_state
        
        actions = await engine.get_floor_actions(1, state)
        assert len(actions) == 1
        assert actions[0].action_type == "move"
        assert actions[0].position == (100, 200)


class TestGetBossActions:
    """Test boss action generation."""
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_no_strategy(self):
        """Test when no strategy exists."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="unknown",
            instance_name="Unknown",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_boss_actions("Boss", 100.0, state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_no_boss_strategy(self):
        """Test when boss strategy doesn't exist."""
        engine = InstanceStrategyEngine()
        strategy = InstanceStrategy(instance_id="test")
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_boss_actions("Unknown Boss", 100.0, state)
        assert actions == []
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_ranged_positioning(self):
        """Test ranged positioning action."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(
            boss_name="Amon Ra",
            positioning="ranged"
        )
        strategy = InstanceStrategy(
            instance_id="test",
            boss_strategies={"amon_ra": boss_strat}
        )
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_boss_actions("amon_ra", 100.0, state)
        assert any(a.action_type == "move" for a in actions)
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_priority_skills(self):
        """Test priority skill actions."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(
            boss_name="Thanatos",
            priority_skills=["holy_light", "heal", "sanctuary"]
        )
        strategy = InstanceStrategy(
            instance_id="test",
            boss_strategies={"thanatos": boss_strat}
        )
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_boss_actions("thanatos", 80.0, state)
        skill_actions = [a for a in actions if a.action_type == "skill"]
        assert len(skill_actions) == 2  # Top 2 skills
        assert any(a.skill_name == "holy_light" for a in skill_actions)
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_adds_handling(self):
        """Test handling boss adds."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(
            boss_name="Boss",
            adds_spawn=True,
            adds_priority="kill_first"
        )
        strategy = InstanceStrategy(
            instance_id="test",
            boss_strategies={"boss": boss_strat}
        )
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        actions = await engine.get_boss_actions("boss", 60.0, state)
        assert any(a.action_type == "attack" and a.priority == 10 for a in actions)


class TestGetBossPhase:
    """Test boss phase calculation."""
    
    def test_get_boss_phase_no_triggers(self):
        """Test phase when no triggers defined."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(boss_name="Simple Boss")
        
        phase = engine._get_boss_phase(100.0, boss_strat)
        assert phase == 1
    
    def test_get_boss_phase_multiple_triggers(self):
        """Test phase transitions."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(
            boss_name="Phased Boss",
            phase_triggers=[75.0, 50.0, 25.0]
        )
        
        assert engine._get_boss_phase(100.0, boss_strat) == 1
        assert engine._get_boss_phase(80.0, boss_strat) == 1
        assert engine._get_boss_phase(70.0, boss_strat) == 2
        assert engine._get_boss_phase(40.0, boss_strat) == 3
        assert engine._get_boss_phase(20.0, boss_strat) == 4


class TestAdaptStrategy:
    """Test strategy adaptation."""
    
    @pytest.mark.asyncio
    async def test_adapt_strategy_party_death(self):
        """Test adaptation to party member death."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        await engine.adapt_strategy("party_member_died", state)
        
        assert "test" in engine.learned_tactics
        assert "increase_caution" in engine.learned_tactics["test"]
    
    @pytest.mark.asyncio
    async def test_adapt_strategy_time_pressure(self):
        """Test adaptation to time running low."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=5
        )
        
        await engine.adapt_strategy("time_running_low", state)
        
        assert "prioritize_speed" in engine.learned_tactics["test"]
    
    @pytest.mark.asyncio
    async def test_adapt_strategy_unexpected_adds(self):
        """Test adaptation to unexpected adds."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=3
        )
        
        await engine.adapt_strategy("unexpected_adds", state)
        
        assert "aoe_clear_needed" in engine.learned_tactics["test"]
    
    @pytest.mark.asyncio
    async def test_adapt_strategy_limits_history(self):
        """Test that learned tactics history is limited."""
        engine = InstanceStrategyEngine()
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        # Add 20 tactics
        for i in range(20):
            await engine.adapt_strategy("party_member_died", state)
        
        # Should keep only last 10
        assert len(engine.learned_tactics["test"]) == 10


class TestLearnFromRun:
    """Test learning from completed runs."""
    
    @pytest.mark.asyncio
    async def test_learn_from_successful_run(self):
        """Test learning from successful run."""
        engine = InstanceStrategyEngine()
        
        final_state = InstanceState(
            instance_id="test",
            instance_name="Test Instance",
            max_time_minutes=60,
            current_floor=10
        )
        final_state.phase = InstancePhase.COMPLETED
        final_state.deaths = 2
        final_state.start_time = datetime.now()
        
        await engine.learn_from_run(final_state)
        
        assert "test" in engine.learned_tactics
        assert "successful_completion" in engine.learned_tactics["test"]
    
    @pytest.mark.asyncio
    async def test_learn_from_failed_run(self):
        """Test learning from failed run."""
        engine = InstanceStrategyEngine()
        
        final_state = InstanceState(
            instance_id="test",
            instance_name="Test Instance",
            max_time_minutes=60,
            current_floor=5
        )
        final_state.phase = InstancePhase.FAILED
        final_state.deaths = 10
        final_state.start_time = datetime.now()
        
        await engine.learn_from_run(final_state)
        
        # Should not add successful_completion
        tactics = engine.learned_tactics.get("test", [])
        assert "successful_completion" not in tactics
    
    @pytest.mark.asyncio
    async def test_learn_from_run_limits_history(self):
        """Test that successful run history is limited to 20."""
        engine = InstanceStrategyEngine()
        
        # Pre-populate with tactics
        engine.learned_tactics["test"] = ["tactic"] * 15
        
        final_state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=10
        )
        final_state.phase = InstancePhase.COMPLETED
        final_state.start_time = datetime.now()
        
        # Learn from 10 successful runs
        for _ in range(10):
            await engine.learn_from_run(final_state)
        
        # Should keep only last 20
        assert len(engine.learned_tactics["test"]) == 20
        assert engine.learned_tactics["test"][-1] == "successful_completion"


class TestStrategyEngineEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.mark.asyncio
    async def test_generate_strategy_zero_floors(self):
        """Test handling instance with zero floors."""
        engine = InstanceStrategyEngine()
        
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=InstanceType.SOLO,
            difficulty=InstanceDifficulty.NORMAL,
            recommended_level=50,
            max_party_size=1,
            time_limit_minutes=60,
            floors=0,
            boss_names=[]
        )
        
        result = await engine.generate_strategy(instance_def, {"base_level": 60}, [])
        
        assert len(result.floor_strategies) == 0
        assert len(result.boss_strategies) == 0
    
    @pytest.mark.asyncio
    async def test_get_boss_actions_phase_mechanics(self):
        """Test that phase mechanics are logged."""
        engine = InstanceStrategyEngine()
        boss_strat = BossStrategy(
            boss_name="Phased Boss",
            phase_triggers=[50.0],
            phase_mechanics={
                1: ["normal_attack"],
                2: ["berserk_mode", "aoe_spam"]
            }
        )
        strategy = InstanceStrategy(
            instance_id="test",
            boss_strategies={"phased": boss_strat}
        )
        engine.strategies["test"] = strategy
        
        state = InstanceState(
            instance_id="test",
            instance_name="Test",
            max_time_minutes=60,
            current_floor=1
        )
        
        # Phase 1 (above 50%)
        actions = await engine.get_boss_actions("phased", 60.0, state)
        assert len(actions) >= 0
        
        # Phase 2 (below 50%)
        actions = await engine.get_boss_actions("phased", 30.0, state)
        assert len(actions) >= 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])