"""
Advanced Combat Coordinator for integrating all combat mechanics.

Coordinates:
- Element optimization
- Race/Size modifiers  
- Skill combos
- Cast timing
- Evasion tactics
- Critical optimization
- AoE targeting
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.combat.elements import ElementCalculator
from ai_sidecar.combat.race_property import RacePropertyCalculator
from ai_sidecar.combat.combos import SkillComboEngine
from ai_sidecar.combat.cast_delay import CastDelayManager
from ai_sidecar.combat.evasion import EvasionCalculator
from ai_sidecar.combat.critical import CriticalCalculator
from ai_sidecar.combat.aoe import AoETargetingSystem
from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace, MonsterSize


class TargetAnalysis(BaseModel):
    """Comprehensive target analysis result."""
    
    model_config = ConfigDict(frozen=False)
    
    target_id: int = Field(description="Target actor ID")
    target_name: str = Field(default="", description="Target name")
    
    # Element analysis
    target_element: Element = Field(description="Target element")
    target_element_level: int = Field(default=1, ge=1, le=4, description="Element level")
    optimal_attack_element: Element = Field(description="Best attack element")
    element_modifier: float = Field(description="Damage modifier")
    should_change_element: bool = Field(default=False, description="Should change element")
    
    # Race/Size analysis
    target_race: MonsterRace = Field(description="Target race")
    target_size: MonsterSize = Field(description="Target size")
    race_modifier: float = Field(default=1.0, description="Race damage bonus")
    size_modifier: float = Field(default=1.0, description="Size penalty")
    
    # Combined modifiers
    total_damage_modifier: float = Field(default=1.0, description="Total damage multiplier")
    
    # Recommendations
    recommended_skills: List[str] = Field(default_factory=list, description="Skill recommendations")
    expected_damage_range: Tuple[int, int] = Field(default=(0, 0), description="Min/max damage")


class AttackOptimization(BaseModel):
    """Optimal attack configuration."""
    
    model_config = ConfigDict(frozen=False)
    
    element_change_needed: bool = Field(default=False, description="Need to change element")
    recommended_element: Optional[Element] = Field(default=None, description="Element to use")
    converter_item: Optional[str] = Field(default=None, description="Converter item name")
    endow_skill: Optional[str] = Field(default=None, description="Endow skill name")
    
    weapon_swap_needed: bool = Field(default=False, description="Need to swap weapon")
    recommended_weapon_type: Optional[str] = Field(default=None, description="Weapon type")
    
    buff_requirements: List[str] = Field(default_factory=list, description="Required buffs")
    card_recommendations: List[str] = Field(default_factory=list, description="Recommended cards")
    
    skill_priority: List[str] = Field(default_factory=list, description="Skill order")


class AdvancedCombatCoordinator:
    """
    Enhanced combat coordinator integrating all advanced mechanics.
    
    Coordinates:
    - Element optimization
    - Race/Size modifiers
    - Skill combos
    - Cast timing
    - Evasion tactics
    - Critical optimization
    - AoE targeting
    """
    
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        """
        Initialize advanced combat coordinator.
        
        Args:
            data_dir: Directory containing combat data files
        """
        self.log = structlog.get_logger(__name__)
        
        # Initialize sub-systems
        self.element_calc = ElementCalculator()
        self.race_calc = RacePropertyCalculator(data_dir)
        self.combo_engine = SkillComboEngine(data_dir)
        self.cast_manager = CastDelayManager(data_dir)
        self.evasion_calc = EvasionCalculator()
        self.crit_calc = CriticalCalculator()
        self.aoe_system = AoETargetingSystem(data_dir)
        
        self.log.info("advanced_combat_coordinator_initialized")
        
    async def analyze_target(self, target: MonsterActor, character_state: dict) -> TargetAnalysis:
        """
        Full target analysis with all combat mechanics.
        
        Args:
            target: Target monster
            character_state: Character state dict
            
        Returns:
            Comprehensive target analysis
        """
        # Element analysis
        current_element = character_state.get("attack_element", Element.NEUTRAL)
        element_result = self.element_calc.get_modifier(
            current_element, 1, target.element, 1
        )
        
        optimal_elem, optimal_mod = self.element_calc.get_optimal_element(
            target.element, 1
        )
        
        should_change, recommended_elem = self.element_calc.should_change_element(
            current_element, target.element, 1
        )
        
        # Race/Size analysis
        weapon_type = character_state.get("weapon_type", "sword")
        equipped_cards = character_state.get("equipped_cards", [])
        
        race_size_result = self.race_calc.calculate_total_modifier(
            weapon_type, equipped_cards, target.race, target.size
        )
        
        # Combined modifier
        total_modifier = (
            element_result.modifier
            * race_size_result.race_modifier
            * race_size_result.size_modifier
        )
        
        # Skill recommendations based on modifiers
        recommended_skills = await self._get_skill_recommendations(
            target, character_state, total_modifier
        )
        
        # Damage estimation
        base_damage = character_state.get("base_attack", 100)
        min_dmg = int(base_damage * total_modifier * 0.8)
        max_dmg = int(base_damage * total_modifier * 1.2)
        
        analysis = TargetAnalysis(
            target_id=target.actor_id,
            target_name=target.name,
            target_element=target.element,
            target_element_level=1,
            optimal_attack_element=optimal_elem,
            element_modifier=element_result.modifier,
            should_change_element=should_change,
            target_race=target.race,
            target_size=target.size,
            race_modifier=race_size_result.race_modifier,
            size_modifier=race_size_result.size_modifier,
            total_damage_modifier=total_modifier,
            recommended_skills=recommended_skills,
            expected_damage_range=(min_dmg, max_dmg),
        )
        
        self.log.info(
            "target_analyzed",
            target=target.name,
            element_mod=element_result.modifier,
            total_mod=total_modifier,
        )
        
        return analysis
        
    async def optimize_attack_setup(
        self,
        target: MonsterActor,
        character_state: dict,
    ) -> AttackOptimization:
        """
        Get optimal attack configuration for target.
        
        Args:
            target: Target monster
            character_state: Character state dict
            
        Returns:
            Attack optimization configuration
        """
        analysis = await self.analyze_target(target, character_state)
        
        # Element optimization
        element_change_needed = analysis.should_change_element
        converter = None
        endow = None
        
        if element_change_needed and analysis.optimal_attack_element:
            converter = self.element_calc.get_converter_for_element(
                analysis.optimal_attack_element
            )
            endow = self.element_calc.get_endow_skill_for_element(
                analysis.optimal_attack_element
            )
            
        # Weapon optimization
        weapon_type = character_state.get("weapon_type", "sword")
        optimal_weapon = self.race_calc.get_optimal_weapon_type(
            target.size, [{"type": weapon_type}]
        )
        weapon_swap = optimal_weapon and optimal_weapon != weapon_type
        
        # Card recommendations
        card_suggestions = self.race_calc.suggest_cards_for_target(
            target.race, target.size, max_suggestions=3
        )
        card_names = [c.card_name for c in card_suggestions]
        
        # Buff requirements (from combos if applicable)
        buffs = []
        job_class = character_state.get("job_class", "novice")
        available_combos = await self.combo_engine.get_available_combos(
            job_class,
            character_state.get("sp", 100),
            character_state.get("active_buffs", []),
            weapon_type,
        )
        
        if available_combos:
            # Get buffs from best combo
            best_combo = available_combos[0]
            buffs = best_combo.required_buffs
            
        optimization = AttackOptimization(
            element_change_needed=element_change_needed,
            recommended_element=analysis.optimal_attack_element if element_change_needed else None,
            converter_item=converter,
            endow_skill=endow,
            weapon_swap_needed=weapon_swap,
            recommended_weapon_type=optimal_weapon if weapon_swap else None,
            buff_requirements=buffs,
            card_recommendations=card_names,
            skill_priority=analysis.recommended_skills,
        )
        
        self.log.info(
            "attack_optimized",
            element_change=element_change_needed,
            weapon_swap=weapon_swap,
            buffs=len(buffs),
        )
        
        return optimization
        
    async def get_optimal_skill_sequence(
        self,
        target: MonsterActor,
        character_state: dict,
        situation: str = "pve",
    ) -> List[dict]:
        """
        Generate optimal skill sequence considering all mechanics.
        
        Args:
            target: Target monster
            character_state: Character state dict
            situation: Combat situation (pve/pvp/boss)
            
        Returns:
            List of skill actions with timing
        """
        job_class = character_state.get("job_class", "novice")
        sp_current = character_state.get("sp", 100)
        active_buffs = character_state.get("active_buffs", [])
        weapon_type = character_state.get("weapon_type", "sword")
        
        # Get available combos
        available_combos = await self.combo_engine.get_available_combos(
            job_class, sp_current, active_buffs, weapon_type
        )
        
        # Select best combo for situation
        best_combo = await self.combo_engine.select_optimal_combo(
            available_combos, situation, 1, sp_current
        )
        
        sequence = []
        
        if best_combo:
            # Execute combo
            await self.combo_engine.start_combo(best_combo.combo_id)
            
            for step in best_combo.steps:
                # Calculate timing
                timing = self.cast_manager.calculate_cast_time(
                    step.skill_name,
                    character_state.get("dex", 1),
                    character_state.get("int", 1),
                )
                
                action = {
                    "skill": step.skill_name,
                    "level": step.skill_level,
                    "cast_time_ms": timing.total_cast_time_ms,
                    "delay_ms": timing.after_cast_delay_ms,
                    "sp_cost": step.sp_cost,
                }
                sequence.append(action)
        else:
            # Single skill recommendation
            analysis = await self.analyze_target(target, character_state)
            if analysis.recommended_skills:
                skill = analysis.recommended_skills[0]
                timing = self.cast_manager.calculate_cast_time(
                    skill,
                    character_state.get("dex", 1),
                    character_state.get("int", 1),
                )
                
                action = {
                    "skill": skill,
                    "cast_time_ms": timing.total_cast_time_ms,
                    "delay_ms": timing.after_cast_delay_ms,
                }
                sequence.append(action)
                
        self.log.info("skill_sequence_generated", actions=len(sequence))
        
        return sequence
        
    async def should_use_aoe(
        self,
        monster_positions: List[Tuple[int, int]],
        character_state: dict,
    ) -> Tuple[bool, Optional[dict]]:
        """
        Decide if AoE is more efficient than single-target.
        
        Args:
            monster_positions: Monster positions
            character_state: Character state dict
            
        Returns:
            Tuple of (use_aoe, aoe_plan)
        """
        if len(monster_positions) < 2:
            return False, None
            
        # Detect clusters
        clusters = await self.aoe_system.detect_mob_cluster(
            monster_positions, min_cluster_size=3
        )
        
        if not clusters:
            return False, None
            
        # Plan AoE sequence
        available_skills = character_state.get("aoe_skills", [])
        player_pos = character_state.get("position", (0, 0))
        sp_available = character_state.get("sp", 100)
        
        sequence = await self.aoe_system.plan_aoe_sequence(
            clusters, available_skills, player_pos, sp_available
        )
        
        if sequence:
            plan = {
                "use_aoe": True,
                "clusters": len(clusters),
                "sequence": sequence,
            }
            self.log.info("aoe_recommended", clusters=len(clusters), actions=len(sequence))
            return True, plan
            
        return False, None
        
    async def evaluate_defensive_options(
        self,
        incoming_attack: dict,
        character_state: dict,
    ) -> dict:
        """
        Evaluate defense options against incoming attack.
        
        Args:
            incoming_attack: Attack info dict
            character_state: Character state dict
            
        Returns:
            Defensive evaluation
        """
        monster_hit = incoming_attack.get("hit", 100)
        monster_count = incoming_attack.get("count", 1)
        
        # Flee viability
        player_flee = character_state.get("flee", 1)
        flee_viable, miss_rate = self.evasion_calc.is_flee_viable(
            player_flee, monster_hit, monster_count
        )
        
        # Perfect dodge chance
        player_luk = character_state.get("luk", 1)
        perfect_dodge_chance = self.evasion_calc.calculate_perfect_dodge(player_luk)
        
        evaluation = {
            "flee_viable": flee_viable,
            "miss_rate": miss_rate,
            "perfect_dodge_chance": perfect_dodge_chance / 100.0,
            "recommendation": (
                "Flee viable" if flee_viable
                else f"Flee not viable (miss rate: {miss_rate:.1%})"
            ),
        }
        
        return evaluation
        
    async def get_combat_action(self, game_state: dict) -> dict:
        """
        Main entry point - get next combat action.
        Integrates all sub-systems for optimal decision.
        
        Args:
            game_state: Complete game state
            
        Returns:
            Combat action decision
        """
        # This would integrate with the main combat AI
        # For now, return structure
        return {
            "action_type": "analyze",
            "message": "Advanced combat coordinator ready",
        }
        
    async def _get_skill_recommendations(
        self,
        target: MonsterActor,
        character_state: dict,
        damage_modifier: float,
    ) -> List[str]:
        """Get skill recommendations based on modifiers."""
        # Simplified: return generic recommendations
        # Full implementation would check job skills, SP, cooldowns
        skills = []
        
        if damage_modifier >= 1.5:
            skills.append("high_damage_skill")
        elif damage_modifier >= 1.0:
            skills.append("standard_skill")
        else:
            skills.append("basic_attack")
            
        return skills