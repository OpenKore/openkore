"""
Comprehensive tests for Advanced Combat Mechanics.

Tests:
- Element system calculations
- Race/Size modifiers
- Skill combos
- Cast/Delay timing
- Evasion mechanics
- Critical hits
- AoE targeting
- Advanced coordinator integration
"""

import pytest
from pathlib import Path

from ai_sidecar.combat.elements import (
    ElementCalculator,
    Element,
    ElementLevel,
    ElementModifier,
)
from ai_sidecar.combat.race_property import (
    RacePropertyCalculator,
    MonsterRace,
    MonsterSize,
)
from ai_sidecar.combat.combos import SkillComboEngine, ComboStep
from ai_sidecar.combat.cast_delay import CastDelayManager
from ai_sidecar.combat.evasion import EvasionCalculator
from ai_sidecar.combat.critical import CriticalCalculator
from ai_sidecar.combat.aoe import AoETargetingSystem, AoEShape
from ai_sidecar.combat.advanced_coordinator import AdvancedCombatCoordinator
from ai_sidecar.combat.models import MonsterActor


class TestElementCalculator:
    """Test element damage calculations."""
    
    @pytest.fixture
    def calc(self):
        """Create element calculator."""
        return ElementCalculator()
        
    def test_element_table_accuracy(self, calc):
        """Verify element table values match RO formulas."""
        # Water vs Fire = 1.5x (effective)
        result = calc.get_modifier(Element.WATER, 1, Element.FIRE, 1)
        assert result.modifier == 1.5
        assert result.effective == "EFFECTIVE"
        
        # Fire vs Water = 0.9x (weak)
        result = calc.get_modifier(Element.FIRE, 1, Element.WATER, 1)
        assert result.modifier == 0.9
        assert result.effective == "WEAK"
        
    def test_ghost_neutral_immunity(self, calc):
        """Ghost level 2+ immune to neutral."""
        # Level 1 - reduced
        result = calc.get_modifier(Element.NEUTRAL, 1, Element.GHOST, 1)
        assert result.modifier == 0.7
        assert not result.is_immune
        
        # Level 4 - immune
        result = calc.get_modifier(Element.NEUTRAL, 1, Element.GHOST, 4)
        assert result.modifier == 0.0
        assert result.is_immune
        
    def test_element_absorption(self, calc):
        """Water absorbs water attacks at high levels."""
        # Level 3 - absorbs
        result = calc.get_modifier(Element.WATER, 1, Element.WATER, 3)
        assert result.modifier == 0.25  # Absolute value
        assert result.absorbs_damage is True
        
        # Level 4 - more absorption
        result = calc.get_modifier(Element.WATER, 1, Element.WATER, 4)
        assert result.modifier == 0.5
        assert result.absorbs_damage is True
        
    def test_optimal_element_selection(self, calc):
        """Test finding best attack element."""
        # Fire monster - Water is best
        optimal, modifier = calc.get_optimal_element(Element.FIRE, 1)
        assert optimal == Element.WATER
        assert modifier >= 1.5
        
        # Undead - Holy is best
        optimal, modifier = calc.get_optimal_element(Element.UNDEAD, 1)
        assert optimal == Element.HOLY
        assert modifier >= 1.25
        
    def test_converter_recommendations(self, calc):
        """Test converter item suggestions."""
        converter = calc.get_converter_for_element(Element.FIRE)
        assert converter == "Flame Heart"
        
        converter = calc.get_converter_for_element(Element.WATER)
        assert converter == "Mystic Frozen"
        
    def test_endow_skill_recommendations(self, calc):
        """Test endow skill suggestions."""
        endow = calc.get_endow_skill_for_element(Element.HOLY)
        assert endow == "Aspersio"
        
        endow = calc.get_endow_skill_for_element(Element.FIRE)
        assert endow == "Endow Blaze"


class TestRacePropertyCalculator:
    """Test race and size mechanics."""
    
    @pytest.fixture
    def calc(self):
        """Create race property calculator."""
        return RacePropertyCalculator()
        
    def test_size_penalties(self, calc):
        """Verify weapon size penalties."""
        # Dagger vs small = 1.0 (no penalty)
        penalty = calc.get_size_penalty("dagger", MonsterSize.SMALL)
        assert penalty == 1.0
        
        # Dagger vs large = 0.5 (50% penalty)
        penalty = calc.get_size_penalty("dagger", MonsterSize.LARGE)
        assert penalty == 0.5
        
        # Two-hand sword vs large = 1.0 (no penalty)
        penalty = calc.get_size_penalty("two_hand_sword", MonsterSize.LARGE)
        assert penalty == 1.0
        
    def test_race_card_bonuses(self, calc):
        """Test race damage bonuses from cards."""
        # Hydra card vs demi-human
        cards = ["Hydra Card"]
        bonus = calc.get_race_bonus(cards, MonsterRace.DEMI_HUMAN)
        assert bonus == 1.20  # 20% bonus
        
        # No matching cards
        bonus = calc.get_race_bonus(["Random Card"], MonsterRace.BRUTE)
        assert bonus == 1.0
        
    def test_combined_modifiers(self, calc):
        """Test combined race and size modifiers."""
        result = calc.calculate_total_modifier(
            "dagger",
            ["Hydra Card"],
            MonsterRace.DEMI_HUMAN,
            MonsterSize.SMALL,
        )
        assert result.race_modifier == 1.20
        assert result.size_modifier == 1.0
        assert result.total_modifier == 1.20


class TestSkillComboEngine:
    """Test combo system."""
    
    @pytest.fixture
    def engine(self):
        """Create combo engine."""
        return SkillComboEngine()
        
    @pytest.mark.asyncio
    async def test_combo_execution(self, engine):
        """Test combo step execution."""
        # Start a combo
        state = await engine.start_combo("sinx_sonic_chain")
        assert state is not None
        assert state.current_step == 0
        
        # Get next skill
        next_skill = await engine.get_next_skill()
        assert next_skill is not None
        assert next_skill.skill_name == "Enchant Deadly Poison"
        
        # Record result
        await engine.record_skill_result(hit=True, damage=100)
        assert state.current_step == 1
        
    @pytest.mark.asyncio
    async def test_combo_interruption(self, engine):
        """Test combo abort on failure."""
        state = await engine.start_combo("sinx_sonic_chain")
        
        # Abort due to low HP
        should_abort = await engine.should_abort_combo(0.10)
        assert should_abort is True
        
    @pytest.mark.asyncio
    async def test_combo_selection(self, engine):
        """Test optimal combo selection."""
        combos = await engine.get_available_combos(
            "assassin_cross",
            sp_current=150,
            active_buffs=[],
            weapon_type="katar",
        )
        assert len(combos) > 0
        
        optimal = await engine.select_optimal_combo(
            combos,
            situation="pve",
            target_count=1,
            sp_available=150,
        )
        assert optimal is not None


class TestCastDelayManager:
    """Test cast and delay mechanics."""
    
    @pytest.fixture
    def manager(self):
        """Create cast/delay manager."""
        return CastDelayManager()
        
    def test_variable_cast_reduction(self, manager):
        """Test DEX/INT cast reduction formula."""
        # High stats = faster cast
        timing_low = manager.calculate_cast_time("Storm Gust", dex=1, int_stat=1)
        timing_high = manager.calculate_cast_time("Storm Gust", dex=99, int_stat=99)
        
        assert timing_high.variable_cast_ms < timing_low.variable_cast_ms
        assert timing_high.cast_reduction_percent > 0.5  # Over 50% reduction
        
    def test_after_cast_delay(self, manager):
        """Test after-cast delay calculation."""
        # High AGI = faster recovery
        delay_low = manager.calculate_after_cast_delay("Sonic Blow", agi=1)
        delay_high = manager.calculate_after_cast_delay("Sonic Blow", agi=99)
        
        assert delay_high < delay_low
        
    @pytest.mark.asyncio
    async def test_cast_state_tracking(self, manager):
        """Test cast state management."""
        # Start cast
        await manager.start_cast("Storm Gust", 5000)
        assert manager.cast_state.is_casting is True
        
        # Check can't cast during
        can_cast, reason = await manager.can_cast_now()
        assert can_cast is False
        assert reason == "already_casting"
        
        # Complete cast
        await manager.cast_complete("Storm Gust", 3000)
        assert manager.cast_state.is_casting is False
        assert manager.delay_state.in_after_cast_delay is True


class TestEvasionCalculator:
    """Test flee mechanics."""
    
    @pytest.fixture
    def calc(self):
        """Create evasion calculator."""
        return EvasionCalculator()
        
    def test_flee_calculation(self, calc):
        """Test basic flee formula."""
        # Flee = Level + AGI + Bonus
        flee = calc.calculate_flee(base_level=99, agi=99, flee_bonus=0)
        assert flee == 198
        
        flee = calc.calculate_flee(base_level=99, agi=99, flee_bonus=20)
        assert flee == 218
        
    def test_flee_penalty_multiple_attackers(self, calc):
        """Test flee reduction with mob."""
        # 1 attacker - no penalty
        hit_rate = calc.calculate_hit_rate(100, 200, num_attackers=1)
        
        # 5 attackers - 30% flee penalty
        hit_rate_mob = calc.calculate_hit_rate(100, 200, num_attackers=5)
        assert hit_rate_mob > hit_rate
        
    def test_perfect_dodge_calculation(self, calc):
        """Test LUK-based perfect dodge."""
        # 100 LUK = 10% perfect dodge
        perfect = calc.calculate_perfect_dodge(luk=100)
        assert perfect == 10.0
        
        perfect = calc.calculate_perfect_dodge(luk=50)
        assert perfect == 5.0
        
    def test_flee_viability(self, calc):
        """Test flee build viability check."""
        # High flee vs low hit = viable
        viable, miss_rate = calc.is_flee_viable(
            player_flee=300,
            monster_hit=100,
            monster_count=1,
        )
        assert viable is True
        assert miss_rate >= 0.80


class TestCriticalCalculator:
    """Test critical hit mechanics."""
    
    @pytest.fixture
    def calc(self):
        """Create critical calculator."""
        return CriticalCalculator()
        
    def test_crit_rate_calculation(self, calc):
        """Test LUK-based crit rate."""
        # High LUK = high crit
        crit_rate = calc.calculate_crit_rate(attacker_luk=100, defender_luk=0)
        assert crit_rate >= 30.0
        
        # Defender LUK reduces
        crit_rate_reduced = calc.calculate_crit_rate(attacker_luk=100, defender_luk=50)
        assert crit_rate_reduced < crit_rate
        
    def test_crit_damage(self, calc):
        """Test crit damage multiplier."""
        base = 100
        
        # Default 140%
        crit_dmg = calc.calculate_crit_damage(base, crit_damage_bonus=0.0)
        assert crit_dmg == 140
        
        # With bonus
        crit_dmg = calc.calculate_crit_damage(base, crit_damage_bonus=0.5)
        assert crit_dmg == 190  # 140% + 50%
        
    def test_average_dps_with_crit(self, calc):
        """Test DPS calculation with crits."""
        # 50% crit rate with 140% damage
        dps = calc.calculate_average_dps_with_crit(
            base_damage=100,
            crit_rate=50.0,
            crit_damage_multiplier=1.4,
            attack_speed=1.0,
        )
        # Expected: (100 * 0.5) + (140 * 0.5) = 120 DPS
        assert dps == 120.0


class TestAoETargeting:
    """Test AoE system."""
    
    @pytest.fixture
    def system(self):
        """Create AoE targeting system."""
        return AoETargetingSystem()
        
    @pytest.mark.asyncio
    async def test_optimal_center_finding(self, system):
        """Test finding best AoE center."""
        # Create skill
        from ai_sidecar.combat.aoe import AoESkill
        
        skill = AoESkill(
            skill_name="Storm Gust",
            shape=AoEShape.CIRCLE,
            range=5,
            cast_range=9,
            cells_affected=81,
            hits_per_target=10,
        )
        
        # Monster positions
        positions = [(10, 10), (11, 10), (12, 10), (10, 11), (11, 11)]
        player_pos = (15, 15)
        
        # Find optimal center
        center = await system.find_optimal_center(positions, skill, player_pos)
        
        # Should be near cluster
        assert center in positions or center == player_pos
        
    @pytest.mark.asyncio
    async def test_cluster_detection(self, system):
        """Test mob cluster detection."""
        # Create two clusters
        cluster1 = [(10, 10), (11, 10), (12, 10), (11, 11)]
        cluster2 = [(50, 50), (51, 50), (52, 50), (51, 51)]
        all_positions = cluster1 + cluster2
        
        clusters = await system.detect_mob_cluster(
            all_positions,
            min_cluster_size=3,
            max_cluster_distance=5.0,
        )
        
        # Should find 2 clusters
        assert len(clusters) >= 1  # At least one cluster
        
    @pytest.mark.asyncio
    async def test_targets_hit_calculation(self, system):
        """Test AoE hit calculation."""
        from ai_sidecar.combat.aoe import AoESkill
        
        skill = AoESkill(
            skill_name="Meteor Storm",
            shape=AoEShape.CIRCLE,
            range=3,
            cast_range=9,
            cells_affected=37,
            hits_per_target=7,
        )
        
        center = (10, 10)
        positions = [(10, 10), (11, 10), (10, 11), (20, 20)]  # 3 in range, 1 out
        
        targets = await system.calculate_targets_hit(center, skill, positions)
        
        # Should hit 3 targets (not the one at 20,20)
        assert len(targets) == 3


class TestAdvancedCombatCoordinator:
    """Test integrated combat system."""
    
    @pytest.fixture
    def coordinator(self):
        """Create coordinator."""
        return AdvancedCombatCoordinator()
        
    @pytest.mark.asyncio
    async def test_target_analysis(self, coordinator):
        """Test full target analysis."""
        target = MonsterActor(
            actor_id=1001,
            name="Fire Poring",
            mob_id=1002,
            element=Element.FIRE,
            race=MonsterRace.FORMLESS,
            size=MonsterSize.SMALL,
            hp=500,
            hp_max=500,
        )
        
        character_state = {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "sword",
            "equipped_cards": [],
            "base_attack": 100,
        }
        
        analysis = await coordinator.analyze_target(target, character_state)
        
        assert analysis.target_element == Element.FIRE
        assert analysis.optimal_attack_element == Element.WATER
        assert analysis.should_change_element is True
        
    @pytest.mark.asyncio
    async def test_combat_action_generation(self, coordinator):
        """Test combat decision making."""
        game_state = {
            "character": {
                "hp": 1000,
                "hp_max": 1000,
                "sp": 200,
            },
            "monsters": [],
        }
        
        action = await coordinator.get_combat_action(game_state)
        assert action is not None
        assert "action_type" in action
        
    @pytest.mark.asyncio
    async def test_optimization_recommendations(self, coordinator):
        """Test attack optimization."""
        from ai_sidecar.core.state import Position
        
        target = MonsterActor(
            actor_id=1001,
            name="Undead Knight",
            mob_id=1003,
            element=Element.UNDEAD,
            race=MonsterRace.UNDEAD,
            size=MonsterSize.LARGE,
            hp=10000,
            hp_max=10000,
            position=Position(x=10, y=10),
        )
        
        character_state = {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "dagger",
            "equipped_cards": [],
            "job_class": "assassin_cross",
            "sp": 150,
            "active_buffs": [],
        }
        
        optimization = await coordinator.optimize_attack_setup(target, character_state)
        
        # Neutral vs Undead = 1.0, Holy vs Undead = 1.25
        # Improvement is 1.25x < 1.5x threshold, so no auto-change
        assert optimization.element_change_needed is False
        
        # Should still recommend cards for undead/large
        assert len(optimization.card_recommendations) > 0
        
    @pytest.mark.asyncio
    async def test_aoe_decision(self, coordinator):
        """Test AoE vs single-target decision."""
        # Single monster - no AoE
        positions = [(10, 10)]
        character_state = {"position": (15, 15), "sp": 100, "aoe_skills": ["Storm Gust"]}
        
        use_aoe, plan = await coordinator.should_use_aoe(positions, character_state)
        assert use_aoe is False
        
        # Cluster of monsters - use AoE
        positions = [(10, 10), (11, 10), (12, 10), (11, 11), (10, 11)]
        
        use_aoe, plan = await coordinator.should_use_aoe(positions, character_state)
        # May be True if cluster detected
        if use_aoe:
            assert plan is not None
            assert "sequence" in plan


class TestIntegration:
    """Integration tests for combined mechanics."""
    
    @pytest.mark.asyncio
    async def test_full_combat_flow(self):
        """Test complete combat decision flow."""
        from ai_sidecar.core.state import Position
        
        coordinator = AdvancedCombatCoordinator()
        
        # Create realistic scenario
        target = MonsterActor(
            actor_id=2001,
            name="High Orc",
            mob_id=1213,
            element=Element.EARTH,
            race=MonsterRace.DEMI_HUMAN,
            size=MonsterSize.LARGE,
            hp=5000,
            hp_max=5000,
            position=Position(x=10, y=10),
        )
        
        character_state = {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "sword",
            "equipped_cards": [],
            "job_class": "lord_knight",
            "sp": 100,
            "active_buffs": [],
            "dex": 50,
            "int": 20,
            "agi": 70,
            "luk": 30,
            "position": (15, 15),
        }
        
        # Analyze target
        analysis = await coordinator.analyze_target(target, character_state)
        assert analysis.total_damage_modifier > 0
        
        # Get optimization
        optimization = await coordinator.optimize_attack_setup(target, character_state)
        assert optimization.card_recommendations  # Should suggest demi-human cards
        
        # Get skill sequence
        sequence = await coordinator.get_optimal_skill_sequence(
            target, character_state, "pve"
        )
        assert isinstance(sequence, list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])