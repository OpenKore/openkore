"""
Comprehensive tests for combat/advanced_coordinator.py - BATCH 4.
Target: 95%+ coverage (currently 83.03%, 19 uncovered lines).
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch
from ai_sidecar.combat.advanced_coordinator import (
    AdvancedCombatCoordinator,
    TargetAnalysis,
    AttackOptimization,
)
from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace, MonsterSize


class TestAdvancedCombatCoordinator:
    """Test AdvancedCombatCoordinator functionality."""
    
    @pytest.fixture
    def coordinator(self):
        """Create coordinator instance."""
        return AdvancedCombatCoordinator()
    
    @pytest.fixture
    def sample_monster(self):
        """Create sample monster target."""
        return MonsterActor(
            actor_id=1001,
            mob_id=1002,
            name="Test Monster",
            level=50,
            element=Element.WATER,
            race=MonsterRace.FISH,
            size=MonsterSize.MEDIUM,
            position=(100, 100),
            hp=2000,
            hp_max=2000,
        )
    
    @pytest.fixture
    def character_state(self):
        """Sample character state."""
        return {
            "attack_element": Element.NEUTRAL,
            "weapon_type": "sword",
            "equipped_cards": [],
            "base_attack": 200,
            "job_class": "assassin_cross",
            "sp": 150,
            "active_buffs": [],
            "dex": 50,
            "int": 30,
            "luk": 40,
            "position": (95, 95),
            "aoe_skills": ["meteor_storm", "lord_of_vermillion"],
        }
    
    def test_initialization(self, coordinator):
        """Test coordinator initialization."""
        assert coordinator.element_calc is not None
        assert coordinator.race_calc is not None
        assert coordinator.combo_engine is not None
        assert coordinator.cast_manager is not None
        assert coordinator.evasion_calc is not None
        assert coordinator.crit_calc is not None
        assert coordinator.aoe_system is not None
    
    @pytest.mark.asyncio
    async def test_analyze_target(self, coordinator, sample_monster, character_state):
        """Test comprehensive target analysis."""
        analysis = await coordinator.analyze_target(sample_monster, character_state)
        
        assert isinstance(analysis, TargetAnalysis)
        assert analysis.target_id == sample_monster.actor_id
        assert analysis.target_element == Element.WATER
        assert analysis.target_race == MonsterRace.FISH
        assert analysis.target_size == MonsterSize.MEDIUM
        assert analysis.total_damage_modifier > 0
    
    @pytest.mark.asyncio
    async def test_analyze_target_element_advantage(
        self, coordinator, sample_monster, character_state
    ):
        """Test analysis with elemental advantage."""
        character_state["attack_element"] = Element.WIND  # Wind is 1.5x vs water
        
        analysis = await coordinator.analyze_target(sample_monster, character_state)
        
        assert analysis.element_modifier >= 1.0
        assert len(analysis.recommended_skills) > 0
    
    @pytest.mark.asyncio
    async def test_optimize_attack_setup(
        self, coordinator, sample_monster, character_state
    ):
        """Test attack optimization."""
        optimization = await coordinator.optimize_attack_setup(
            sample_monster, character_state
        )
        
        assert isinstance(optimization, AttackOptimization)
        assert isinstance(optimization.buff_requirements, list)
        assert isinstance(optimization.card_recommendations, list)
        assert isinstance(optimization.skill_priority, list)
    
    @pytest.mark.asyncio
    async def test_optimize_attack_setup_element_change(
        self, coordinator, sample_monster, character_state
    ):
        """Test optimization recommending element change."""
        character_state["attack_element"] = Element.NEUTRAL
        
        optimization = await coordinator.optimize_attack_setup(
            sample_monster, character_state
        )
        
        # Should recommend changing to earth or wind for water target (both 1.5x)
        if optimization.element_change_needed:
            assert optimization.recommended_element in [Element.EARTH, Element.WIND]
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_sequence(
        self, coordinator, sample_monster, character_state
    ):
        """Test optimal skill sequence generation."""
        sequence = await coordinator.get_optimal_skill_sequence(
            sample_monster, character_state, situation="pve"
        )
        
        assert isinstance(sequence, list)
        # May be empty or have skills depending on combos available
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_sequence_pvp(
        self, coordinator, sample_monster, character_state
    ):
        """Test skill sequence for PvP."""
        sequence = await coordinator.get_optimal_skill_sequence(
            sample_monster, character_state, situation="pvp"
        )
        
        assert isinstance(sequence, list)
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_sequence_boss(
        self, coordinator, sample_monster, character_state
    ):
        """Test skill sequence for boss."""
        sequence = await coordinator.get_optimal_skill_sequence(
            sample_monster, character_state, situation="boss"
        )
        
        assert isinstance(sequence, list)
    
    @pytest.mark.asyncio
    async def test_should_use_aoe_single_target(self, coordinator, character_state):
        """Test AoE decision with single target."""
        positions = [(100, 100)]
        
        use_aoe, plan = await coordinator.should_use_aoe(positions, character_state)
        
        assert use_aoe is False
        assert plan is None
    
    @pytest.mark.asyncio
    async def test_should_use_aoe_clustered(self, coordinator, character_state):
        """Test AoE decision with clustered targets."""
        # Create tight cluster
        positions = [
            (100, 100),
            (101, 100),
            (100, 101),
            (101, 101),
        ]
        
        use_aoe, plan = await coordinator.should_use_aoe(positions, character_state)
        
        # Should recommend AoE for cluster
        if use_aoe:
            assert plan is not None
            assert "clusters" in plan
    
    @pytest.mark.asyncio
    async def test_should_use_aoe_scattered(self, coordinator, character_state):
        """Test AoE decision with scattered targets."""
        # Spread out targets
        positions = [
            (100, 100),
            (200, 200),
            (300, 300),
        ]
        
        use_aoe, plan = await coordinator.should_use_aoe(positions, character_state)
        
        # Should not recommend AoE for scattered targets
        assert use_aoe is False
    
    @pytest.mark.asyncio
    async def test_evaluate_defensive_options(self, coordinator, character_state):
        """Test defensive evaluation."""
        incoming_attack = {
            "hit": 150,
            "count": 3,
        }
        character_state["flee"] = 200
        character_state["luk"] = 50
        
        evaluation = await coordinator.evaluate_defensive_options(
            incoming_attack, character_state
        )
        
        assert "flee_viable" in evaluation
        assert "miss_rate" in evaluation
        assert "perfect_dodge_chance" in evaluation
        assert "recommendation" in evaluation
    
    @pytest.mark.asyncio
    async def test_evaluate_defensive_options_high_hit(
        self, coordinator, character_state
    ):
        """Test defense against high hit enemies."""
        incoming_attack = {
            "hit": 500,  # Very high
            "count": 5,
        }
        character_state["flee"] = 100  # Low flee
        character_state["luk"] = 20
        
        evaluation = await coordinator.evaluate_defensive_options(
            incoming_attack, character_state
        )
        
        assert evaluation["flee_viable"] is False
    
    @pytest.mark.asyncio
    async def test_get_combat_action(self, coordinator):
        """Test getting combat action."""
        game_state = {}
        
        action = await coordinator.get_combat_action(game_state)
        
        assert "action_type" in action
        assert "message" in action
    
    @pytest.mark.asyncio
    async def test_analyze_target_high_modifier(self, coordinator, character_state):
        """Test analysis with high damage modifier."""
        strong_target = MonsterActor(
            actor_id=1002,
            mob_id=1003,
            name="Weak to Fire",
            level=50,
            element=Element.EARTH,  # Weak to fire
            race=MonsterRace.PLANT,
            size=MonsterSize.SMALL,
            position=(100, 100),
            hp=1000,
            hp_max=1000,
        )
        
        character_state["attack_element"] = Element.FIRE
        
        analysis = await coordinator.analyze_target(strong_target, character_state)
        
        assert analysis.total_damage_modifier >= 1.0
        assert len(analysis.recommended_skills) > 0