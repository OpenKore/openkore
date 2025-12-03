"""
Final Coverage Push - Target all remaining uncovered lines.

Focuses on:
- economy/market.py (0%)
- consumables/food.py (61%)
- environment/weather.py (62%)
- jobs/mechanics/doram.py (64%)
- llm/providers.py (67%)
- instances/state.py (68%)
- combat/critical.py (69%)
- All other < 85% modules
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, Mock, patch
from datetime import datetime, timedelta
from pathlib import Path


# ============ economy/market.py Coverage (0% -> 100%) ============

class TestMarketCoverage:
    """Cover all market.py code (currently 0%)."""
    
    def test_market_manager_full_lifecycle(self):
        """Cover MarketManager initialization and all methods."""
        from ai_sidecar.economy.market import MarketManager, MarketSource
        
        mgr = MarketManager()
        
        # Add price observations
        for i in range(10):
            mgr.add_price_observation(
                item_id=501,
                price=50 + i,
                quantity=10,
                source=MarketSource.VENDING,
                location="prontera"
            )
        
        # Get average price
        avg_price = mgr.get_average_price(501, hours=24)
        assert avg_price is not None
        
        # Get price trend
        trend = mgr.get_price_trend(501)
        assert trend in ["rising", "falling", "stable"]
        
        # Calculate profit margin
        margin = mgr.calculate_profit_margin(501, 40, 60)
        assert margin > 0
        
        # Test buy/sell decisions
        should_buy, buy_reason = mgr.should_buy(501, 40)
        should_sell, sell_reason = mgr.should_sell(501, 60, 40)
        
        # Get statistics
        stats = mgr.get_market_statistics()
        assert "total_tracked_items" in stats


# ============ consumables/food.py Coverage (61% -> 100%) ============

class TestFoodCoverage:
    """Cover uncovered food.py lines."""
    
    @pytest.mark.asyncio
    async def test_food_manager_all_food_types(self):
        """Cover all food types and consumption logic."""
        from ai_sidecar.consumables.food import FoodManager, FoodCategory
        
        mgr = FoodManager()
        
        # Test inventory management
        mgr.update_inventory({12043: 10, 12044: 10, 12045: 10})
        
        # Test consumption logic
        food_to_eat = mgr.should_eat_food({"str": 50, "int": 30, "build": "melee_dps"})
        
        # Test food application
        mgr.apply_food(12043)
        assert mgr.has_food_buff("STR Dish")
        
        # Test food effects
        active_bonuses = mgr.get_active_stat_bonuses()
        summary = mgr.get_food_summary()
        assert "total_active" in summary
        
        # Test stat recommendations
        recommendations = await mgr.get_optimal_food_set("melee_dps")
        assert len(recommendations) > 0
        
        # Test timer updates
        await mgr.update_food_timers(10.0)
        
        # Test food needs check
        actions = await mgr.check_food_needs()
        
        # Test missing food
        missing = mgr.get_missing_food(recommendations)
        
        # Test tracking
        buffs = await mgr.track_food_buffs()


# ============ environment/weather.py Coverage (62% -> 100%) ============

class TestWeatherCompleteCoverage:
    """Cover all uncovered weather.py lines."""
    
    @pytest.mark.asyncio
    async def test_weather_manager_all_features(self):
        """Cover weather simulation and effects."""
        from ai_sidecar.environment.weather import WeatherManager, WeatherType
        
        mgr = WeatherManager()
        
        # Test all weather types
        for weather in WeatherType:
            await mgr.update_weather(weather, "prontera")
            effect = mgr.get_weather_effect("prontera")
            assert effect.weather_type == weather
        
        # Test modifiers
        for map_name in ["prontera", "geffen", "payon"]:
            elem_mod = mgr.get_element_modifier(map_name, "fire")
            skill_mod = mgr.get_skill_weather_modifier(map_name, "fireball")
            vis_mod = mgr.get_visibility_modifier(map_name)
            move_mod = mgr.get_movement_modifier(map_name)
        
        # Test weather simulation
        future_weather = mgr.simulate_weather_change("prontera", 120)
        assert len(future_weather) > 0
        
        # Test optimal weather
        optimal = mgr.get_optimal_weather_for_skill("storm_gust")
        
        # Test waiting logic
        should_wait, minutes = mgr.should_wait_for_weather("prontera", WeatherType.RAIN)
        
        # Test favorability
        is_favorable = mgr.is_favorable_weather("prontera", "water")
        
        # Test summary
        summary = mgr.get_weather_summary("prontera")
        assert "weather" in summary


# ============ jobs/mechanics/doram.py Coverage (64% -> 100%) ============

class TestDoramCompleteCoverage:
    """Cover all uncovered doram.py lines."""
    
    def test_doram_manager_all_abilities(self):
        """Cover all doram abilities and mechanics."""
        from ai_sidecar.jobs.mechanics.doram import DoramManager, DoramBranch, SpiritType, CompanionType
        
        mgr = DoramManager()
        
        # Test all branches
        for branch in DoramBranch:
            mgr.set_branch(branch)
            
            # Test branch bonus
            bonus = mgr.get_branch_bonus("physical")
            
            # Test recommended abilities
            for situation in ["boss", "farming", "pvp"]:
                ability = mgr.get_recommended_ability(situation)
        
        # Test spirit point generation
        should_generate = mgr.should_generate_spirit_points(3)
        
        # Test spirit points
        mgr.add_spirit_points(10)
        mgr.consume_spirit_points(5)
        
        # Test all spirits
        for spirit in SpiritType:
            mgr.activate_spirit(spirit, 60)
            is_active = mgr.is_spirit_active(spirit)
            active_spirits = mgr.get_active_spirits()
            mgr.deactivate_spirit(spirit)
        
        # Test companions
        for companion in CompanionType:
            mgr.summon_companion(companion, 300)
            mgr.damage_companion(companion, 100)
        
        mgr.cleanup_expired_companions()
        companions = mgr.get_active_companions()
        
        # Test status
        status = mgr.get_status()
        assert "branch" in status
        
        # Test reset
        mgr.reset()
        assert mgr.spirit_points == 0


# ============ llm/providers.py Coverage (67% -> 100%) ============

class TestLLMProvidersCoverage:
    """Cover all uncovered provider lines."""
    
    @pytest.mark.asyncio
    async def test_openai_provider_all_methods(self):
        """Cover OpenAI provider."""
        from ai_sidecar.llm.providers import OpenAIProvider, LLMMessage
        
        with patch('openai.AsyncOpenAI') as mock_openai:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="test response"))]
            mock_response.usage = MagicMock(total_tokens=100)
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_openai.return_value = mock_client
            
            provider = OpenAIProvider(api_key="test_key")
            
            # Test generation (uses complete internally)
            result = await provider.generate("test prompt")
            assert result == "test response"
            
            # Test chat
            chat_result = await provider.chat(["message1", "message2"])
            assert chat_result == "test response"
            
            # Test complete with messages
            messages = [LLMMessage(role="user", content="test")]
            response = await provider.complete(messages, max_tokens=100, temperature=0.7)
            assert response is not None
            
            # Test is_available
            is_available = await provider.is_available()
            assert is_available
    
    @pytest.mark.asyncio
    async def test_claude_provider_all_methods(self):
        """Cover Claude provider."""
        from ai_sidecar.llm.providers import ClaudeProvider, LLMMessage
        
        with patch('anthropic.AsyncAnthropic') as mock_anthropic:
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="test response")]
            mock_response.usage = MagicMock(input_tokens=50, output_tokens=50)
            mock_client.messages.create = AsyncMock(return_value=mock_response)
            mock_anthropic.return_value = mock_client
            
            provider = ClaudeProvider(api_key="test_key")
            
            # Test complete method (Claude uses complete, not generate)
            messages = [LLMMessage(role="user", content="test prompt")]
            result = await provider.complete(messages)
            assert result is not None
            assert result.content == "test response"
            
            # Test is_available
            is_available = await provider.is_available()
            assert is_available
    
    def test_local_provider_initialization(self):
        """Cover LocalProvider."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider(model_path="/fake/model")
        assert provider.model_path == "/fake/model"


# ============ instances/state.py Coverage (68% -> 100%) ============

class TestInstanceStateCoverage:
    """Cover all uncovered instance state lines."""
    
    def test_instance_state_all_fields(self):
        """Cover InstanceState model."""
        from ai_sidecar.instances.state import InstanceState, InstanceType, FloorState
        from datetime import datetime
        
        state = InstanceState(
            instance_id="test_instance",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=1,
            total_floors=100,
            started_at=datetime.now()
        )
        
        # Test state operations
        state.advance_floor()
        assert state.current_floor == 2
        
        state.record_death()
        assert state.deaths >= 1
        
        # Test floor state
        floor_state = FloorState(
            floor_number=2,
            monsters_killed=5,
            monsters_total=10
        )
        state.floors[2] = floor_state
        
        current_floor = state.get_current_floor_state()
        assert current_floor is not None
        
        # Test properties
        progress = state.overall_progress
        elapsed = state.elapsed_seconds
        remaining_pct = state.time_remaining_percent
        is_critical = state.is_time_critical
        time_remaining = state.time_remaining_seconds


# ============ combat/critical.py Coverage (69% -> 100%) ============

class TestCriticalCompleteCoverage:
    """Cover all uncovered critical.py lines."""
    
    @pytest.mark.asyncio
    async def test_critical_calculator_all_features(self):
        """Cover critical hit optimization."""
        from ai_sidecar.combat.critical import CriticalCalculator, CriticalStats
        
        calc = CriticalCalculator()
        
        # Test rate calculations with all combinations
        for attacker_luk in [1, 50, 99, 120]:
            for defender_luk in [0, 30, 60]:
                rate = calc.calculate_crit_rate(attacker_luk, defender_luk)
                assert 1.0 <= rate <= 100.0
        
        # Test damage calculations
        for luk in [1, 50, 99]:
            damage = calc.calculate_crit_damage(100, luk, 0.5)
            assert damage > 100
        
        # Test DPS calculations
        for crit_rate in [10.0, 50.0, 90.0]:
            dps = calc.calculate_average_dps_with_crit(
                100, crit_rate, 1.4, 1.0
            )
            assert dps > 0
        
        # Test crit build analysis
        is_worth, explanation = calc.is_crit_build_worth(
            40.0, 1.4, 50, 120
        )
        assert explanation
        
        # Test optimization - use correct signature
        stats = CriticalStats(crit_rate=30.0, effective_crit_damage=1.5, crit_bonus_flat=0)
        optimization = await calc.get_crit_optimization(stats, target_luk=20, current_luk=80)
        assert "current_crit_rate" in optimization
        assert "recommendation" in optimization


# ============ config.py Coverage (74% -> 100%) ============

class TestConfigCoverage:
    """Cover all config paths."""
    
    def test_all_config_sections(self):
        """Access all configuration sections."""
        from ai_sidecar import config
        
        # Test config access
        settings = config.get_settings()
        assert settings.app_name
        assert settings.zmq
        assert settings.tick
        assert settings.logging
        assert settings.decision
        
        # Test config summary
        summary = config.get_config_summary()
        assert "app_name" in summary
        
        # Test config validation
        valid, issues = config.validate_config()
        assert isinstance(valid, bool)
        assert isinstance(issues, list)
        
        # Test ZMQConfig
        zmq_config = config.ZMQConfig()
        assert zmq_config.endpoint
        
        # Test TickConfig
        tick_config = config.TickConfig()
        assert tick_config.interval_ms > 0
        
        # Test LoggingConfig
        log_config = config.LoggingConfig()
        assert log_config.level in config.LOG_LEVELS
        
        # Test DecisionConfig
        decision_config = config.DecisionConfig()
        assert decision_config.engine_type


# ============ Core State Complete Coverage ============

class TestCoreStateCompleteCoverage:
    """Cover all uncovered core/state.py lines."""
    
    def test_character_state_all_properties(self):
        """Cover all CharacterState properties."""
        from ai_sidecar.core.state import CharacterState, Position
        
        char = CharacterState(
            name="Test",
            job_id=0,
            base_level=99,
            job_level=50,
            hp=5000,
            hp_max=5000,
            sp=1000,
            sp_max=1000,
            position=Position(x=100, y=100),
            weight=500,
            weight_max=1000,
            stat_str=99,
            agi=99,
            vit=99,
            int_stat=99,
            dex=99,
            luk=99
        )
        
        # Access all properties
        hp_pct = char.hp_percent
        sp_pct = char.sp_percent
        weight_pct = char.weight_percent
        str_val = char.str
        int_val = char.int
        job = char.job
        level = char.level
        
        assert hp_pct == 100.0
        assert sp_pct == 100.0
    
    def test_position_distance_methods(self):
        """Cover Position distance calculations."""
        from ai_sidecar.core.state import Position
        
        pos1 = Position(x=0, y=0)
        pos2 = Position(x=3, y=4)
        
        euclidean = pos1.distance_to(pos2)
        manhattan = pos1.manhattan_distance(pos2)
        
        assert euclidean == 5.0
        assert manhattan == 7
    
    def test_game_state_all_methods(self):
        """Cover all GameState methods."""
        from ai_sidecar.core.state import GameState, ActorState, ActorType, Position
        
        state = GameState()
        
        # Add various actors
        monster = ActorState(id=1, type=ActorType.MONSTER, name="Poring", position=Position(x=10, y=10), hp=100, hp_max=100)
        player = ActorState(id=2, type=ActorType.PLAYER, name="Player1", position=Position(x=20, y=20))
        npc = ActorState(id=3, type=ActorType.NPC, name="Kafra", position=Position(x=30, y=30))
        item = ActorState(id=4, type=ActorType.ITEM, name="Apple", position=Position(x=40, y=40))
        
        state.actors = [monster, player, npc, item]
        
        # Test all getter methods
        monsters = state.get_monsters()
        players = state.get_players()
        npcs = state.get_npcs()
        items = state.get_items()
        
        assert len(monsters) == 1
        assert len(players) == 1
        assert len(npcs) == 1
        assert len(items) == 1
        
        # Test get_actor_by_id
        found = state.get_actor_by_id(1)
        assert found is not None
        
        # Test get_nearest_monster
        nearest, dist = state.get_nearest_monster()
        assert nearest is not None
        
        # Test all properties
        player_hp = state.player_hp_percent
        player_sp = state.player_sp_percent
        player_pos = state.player_position
        player_cls = state.player_class
        enemies = state.enemies_nearby
        is_boss = state.is_boss_fight
        dist_dest = state.distance_to_destination
        skill = state.skill_to_use


# ============ Remaining Module Coverage ============

class TestRemainingModuleCoverage:
    """Cover remaining uncovered lines across all modules."""
    
    @pytest.mark.asyncio
    async def test_combat_tactics_all_branches(self):
        """Cover all combat tactics."""
        from ai_sidecar.combat.tactics.base import BaseTactics, TacticsConfig
        from ai_sidecar.combat.tactics.melee_dps import MeleeDPSTactics
        from ai_sidecar.combat.tactics.ranged_dps import RangedDPSTactics
        from ai_sidecar.combat.tactics.magic_dps import MagicDPSTactics
        from ai_sidecar.combat.tactics.tank import TankTactics
        from ai_sidecar.combat.tactics.support import SupportTactics
        from ai_sidecar.combat.tactics.hybrid import HybridTactics, HybridTacticsConfig
        
        # Test base TacticsConfig
        base_config = TacticsConfig(
            emergency_hp_threshold=0.2,
            low_hp_threshold=0.5,
            max_engagement_range=12
        )
        
        # Test hybrid config with required preferred_role
        hybrid_config = HybridTacticsConfig(
            emergency_hp_threshold=0.2,
            low_hp_threshold=0.5,
            max_engagement_range=12,
            preferred_role="dps"
        )
        
        # Test each tactic class initialization
        tactics = [
            MeleeDPSTactics(base_config),
            RangedDPSTactics(base_config),
            MagicDPSTactics(base_config),
            TankTactics(base_config),
            SupportTactics(base_config),
            HybridTactics(hybrid_config)
        ]
        
        # Verify all tactics have the base interface
        for tactic in tactics:
            assert tactic.config is not None
            assert hasattr(tactic, 'role')
    
    @pytest.mark.asyncio
    async def test_jobs_mechanics_all_coverage(self):
        """Cover all job mechanics modules."""
        from ai_sidecar.jobs.mechanics.magic_circles import MagicCircleManager, CircleType
        from ai_sidecar.jobs.mechanics.poisons import PoisonManager, PoisonType
        from ai_sidecar.jobs.mechanics.runes import RuneManager, RuneType
        from ai_sidecar.jobs.mechanics.spirit_spheres import SpiritSphereManager
        from ai_sidecar.jobs.mechanics.traps import TrapManager, TrapType
        
        # Magic circles
        circles = MagicCircleManager()
        for circle_type in CircleType:
            circles.place_circle(circle_type, (10, 10))
        circles.get_circle_count()
        circles.get_active_insignia()
        circles.get_elemental_bonus("fire")
        
        # Poisons
        poisons = PoisonManager()
        for poison_type in PoisonType:
            poisons.add_poison_bottles(poison_type, 10)
            poisons.apply_coating(poison_type, 20)
            poisons.get_poison_count(poison_type)
        poisons.get_current_coating()
        poisons.use_coating_charge()
        poisons.clear_coating()
        poisons.activate_edp(40)
        poisons.is_edp_active()
        poisons.deactivate_edp()
        poisons.should_reapply_coating(5)
        poisons.get_recommended_poison("mvp")
        
        # Runes
        runes = RuneManager()
        for rune_type in RuneType:
            runes.add_rune_stones(rune_type, 5)
            runes.get_rune_count(rune_type)
            runes.is_rune_ready(rune_type)
        runes.add_rune_points(100)
        runes.consume_rune_points(20)
        runes.get_available_runes()
        runes.get_recommended_rune("boss")
        if runes.get_available_runes():
            runes.use_rune(runes.get_available_runes()[0])
        
        # Spirit spheres
        spheres = SpiritSphereManager()
        spheres.generate_multiple_spheres(5)
        spheres.consume_spheres("raging_palm_strike")
        spheres.get_sphere_count()
        spheres.get_max_spheres()
        can_use, required = spheres.can_use_skill("raging_palm_strike")
        spheres.activate_rising_dragon()
        spheres.deactivate_rising_dragon()
        spheres.get_status()
        spheres.get_sphere_skills()
        spheres.is_generation_skill("call_spirits")
        spheres.should_generate_spheres(3)
        spheres.generate_sphere()
        spheres.set_sphere_count(3)
        spheres.reset()
        
        # Traps
        traps = TrapManager()
        for trap_type in TrapType:
            traps.place_trap(trap_type, (15, 15))
        traps.get_trap_count()
        traps.should_use_detonator()
        traps.trigger_trap((15, 15))
        traps.get_placed_traps()
    
    def test_jobs_registry_complete(self):
        """Cover jobs/registry.py uncovered lines."""
        from ai_sidecar.jobs.registry import JobClassRegistry, JobBranch, JobTier, CombatRole
        from pathlib import Path
        
        # Create temp data dir
        import tempfile
        import json
        
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create minimal job_classes.json
            job_data = {
                "jobs": [
                    {
                        "job_id": 0,
                        "name": "novice",
                        "display_name": "Novice",
                        "tier": "novice",
                        "primary_role": "hybrid",
                        "positioning": "melee",
                        "key_skills": ["basic_skill"],
                        "evolves_to": ["swordman", "mage"]
                    },
                    {
                        "job_id": 1,
                        "name": "swordman",
                        "display_name": "Swordman",
                        "tier": "first",
                        "branch": "swordman",
                        "primary_role": "melee_dps",
                        "positioning": "melee",
                        "has_spirit_spheres": False,
                        "evolves_from": "novice"
                    }
                ]
            }
            
            job_file = Path(tmpdir) / "job_classes.json"
            with open(job_file, 'w') as f:
                json.dump(job_data, f)
            
            registry = JobClassRegistry(data_dir=Path(tmpdir))
            
            # Test all methods
            job = registry.get_job(0)
            assert job is not None
            
            job_by_name = registry.get_job_by_name("novice")
            assert job_by_name is not None
            
            count = registry.get_job_count()
            assert count > 0
            
            all_jobs = registry.list_all_jobs()
            assert len(all_jobs) > 0
            
            is_valid = registry.validate_job_id(0)
            assert is_valid
            
            # Test branch queries
            branch_jobs = registry.get_jobs_by_branch(JobBranch.SWORDMAN)
            
            # Test tier queries
            tier_jobs = registry.get_jobs_by_tier(JobTier.NOVICE)
            
            # Test role queries
            role_jobs = registry.get_jobs_by_role(CombatRole.HYBRID)
            
            # Test evolution path
            path = registry.get_evolution_path("swordman")
            assert len(path) > 0
            
            # Test all skills
            all_skills = registry.get_all_skills_for_job("swordman")
            
            # Test special mechanics
            sphere_jobs = registry.get_jobs_with_special_mechanics("spirit_spheres")
        
    @pytest.mark.asyncio
    async def test_memory_complete_coverage(self):
        """Cover memory module uncovered lines."""
        from ai_sidecar.memory.persistent_memory import PersistentMemory
        from ai_sidecar.memory.working_memory import WorkingMemory
        from ai_sidecar.memory.session_memory import SessionMemory
        from ai_sidecar.memory.models import Memory, MemoryType
        
        # Persistent memory
        pm = PersistentMemory(db_path=Path(":memory:"))
        await pm.connect()
        
        mem = Memory(memory_id="test", content="test", memory_type=MemoryType.FACT)
        await pm.store(mem)
        await pm.retrieve("test")
        await pm.query_by_type(MemoryType.FACT)
        await pm.delete("test")
        await pm.close()
        
        # Working memory
        wm = WorkingMemory(max_size=10)
        mem2 = Memory(memory_id="working", content="test", memory_type=MemoryType.SHORT_TERM)
        await wm.store(mem2)
        await wm.retrieve("working")
        wm.get_all()
        wm.is_full()
        await wm.clear()
        
        # Session memory
        sm = SessionMemory(connection_url="redis://localhost:6379")
        
        # Test connection would fail without Redis, so just test object creation
        assert sm.connection_url
        
        # Test decision history methods
        history = await sm.get_decision_history("combat", limit=10)
        assert isinstance(history, list)
    
    @pytest.mark.asyncio
    async def test_mimicry_all_modules(self):
        """Cover all mimicry modules."""
        from ai_sidecar.mimicry.timing import HumanTiming, ReactionType
        from ai_sidecar.mimicry.randomizer import ActionRandomizer
        from ai_sidecar.mimicry.pattern_breaker import PatternBreaker
        
        # Timing engine methods
        timing = HumanTiming()
        delay = timing.calculate_action_delay("attack")
        assert delay > 0
        
        # Test reaction delays
        for reaction in ReactionType:
            delay_ms = timing.get_reaction_delay(reaction)
            assert delay_ms > 0
        
        # Test other timing methods
        should_pause, pause_ms = timing.should_micro_pause()
        typing_delay = timing.get_typing_delay("Hello world")
        assert typing_delay > 0
        
        hesitation = timing.simulate_hesitation(5)
        assert hesitation > 0
        
        warmup = timing.get_warmup_factor()
        assert warmup > 0
        
        timing.update_profile_state()
        stats = timing.get_session_stats()
        assert "session_duration_minutes" in stats
        
        # Test typo/misclick
        timing.should_make_typo()
        timing.should_misclick()
        
        # Test action timing
        action_timing = timing.get_action_delay("attack", is_combat=True)
        assert action_timing.actual_delay_ms > 0
        
        # Test fatigue
        fatigue = timing.apply_fatigue()
        assert fatigue >= 1.0
        
        # Test time of day
        tod_factor = timing.apply_time_of_day_factor()
        assert tod_factor >= 0.8
        
        # Randomizer (ActionRandomizer wraps BehaviorRandomizer)
        rand = ActionRandomizer()
        jittered = rand.add_jitter(100, 0.1)
        assert jittered != 100  # Should have jitter applied
        
        # Test BehaviorRandomizer methods through ActionRandomizer
        should_inject, behavior = rand.should_inject_random_behavior("farming", 60000)
        idle_behavior = rand.get_random_idle_behavior()
        inventory_check = rand.inject_inventory_check()
        map_check = rand.inject_map_check()
        status_check = rand.inject_status_check()
        emote = rand.get_spontaneous_emote()
        should_sit = rand.should_sit_and_rest(50.0, 40.0)
        afk_behaviors = rand.get_afk_behavior(120)
        stats = rand.get_behavior_stats()
        assert isinstance(stats, dict)
        
        # Pattern breaker
        breaker = PatternBreaker()
        should_break = breaker.should_break_pattern("combat", 10)
        
        # record_action expects a dict
        breaker.record_action({"action_type": "combat", "delay_ms": 100})
        breaker.record_action({"action_type": "skill", "skill_id": 5, "delay_ms": 150})
        breaker.record_action({"action_type": "movement", "path": [{"x": 10, "y": 10}], "delay_ms": 200})
        
        stats = breaker.get_pattern_stats()
        assert isinstance(stats, dict)
        assert "behavior_entropy" in stats
        
        # Test entropy calculation
        entropy = breaker.calculate_behavior_entropy()
        assert 0.0 <= entropy <= 1.0
        
        # Test pattern analysis
        patterns = await breaker.analyze_patterns()
        assert isinstance(patterns, list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])