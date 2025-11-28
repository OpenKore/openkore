"""
AoE Targeting System for Advanced Combat Mechanics.

Implements optimal AoE skill positioning, multi-target prioritization,
mob grouping detection, and efficient farming patterns.

Reference: https://irowiki.org/wiki/Skills
"""

from __future__ import annotations

import json
import math
from enum import Enum
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict


class AoEShape(str, Enum):
    """Area of Effect shapes."""
    CIRCLE = "circle"
    SELF_CIRCLE = "self_circle"
    LINE = "line"
    CONE = "cone"
    CROSS = "cross"
    RECTANGLE = "rectangle"


class AoESkill(BaseModel):
    """AoE skill definition."""
    
    model_config = ConfigDict(frozen=False)
    
    skill_name: str = Field(description="Skill name")
    shape: AoEShape = Field(description="AoE shape")
    range: int = Field(ge=0, description="Radius/distance in cells")
    cast_range: int = Field(ge=0, description="How far can cast")
    cells_affected: int = Field(ge=1, description="Total cells affected")
    hits_per_target: int = Field(default=1, ge=1, description="Hits per target")
    damage_falloff: bool = Field(default=False, description="Reduced damage at edges")
    sp_cost: int = Field(default=0, ge=0, description="SP cost")


class AoETarget(BaseModel):
    """Target within AoE."""
    
    model_config = ConfigDict(frozen=True)
    
    entity_id: str = Field(description="Entity identifier")
    entity_name: str = Field(default="", description="Entity name")
    position: Tuple[int, int] = Field(description="Position (x, y)")
    distance_from_center: float = Field(ge=0.0, description="Distance from AoE center")
    expected_damage_percent: float = Field(default=1.0, ge=0.0, le=1.0, description="Damage modifier")


class AoEResult(BaseModel):
    """Result of AoE calculation."""
    
    model_config = ConfigDict(frozen=False)
    
    skill_name: str = Field(description="Skill used")
    center_position: Tuple[int, int] = Field(description="AoE center position")
    targets_hit: List[AoETarget] = Field(description="Targets hit by AoE")
    total_targets: int = Field(ge=0, description="Number of targets")
    total_damage_estimate: int = Field(default=0, ge=0, description="Estimated total damage")
    efficiency_score: float = Field(default=0.0, ge=0.0, description="Efficiency metric")


class AoETargetingSystem:
    """
    Optimize AoE skill targeting.
    
    Features:
    - Optimal center point calculation
    - Multi-target prioritization
    - Mob grouping detection
    - AoE skill selection
    - Efficient farming patterns
    """
    
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        """
        Initialize AoE targeting system.
        
        Args:
            data_dir: Directory containing AoE skill data
        """
        self.log = structlog.get_logger(__name__)
        
        # AoE skill database
        self.aoe_skills: Dict[str, AoESkill] = {}
        
        # Load skill data
        if data_dir:
            self._load_aoe_skills(data_dir)
        else:
            self._initialize_default_skills()
            
    def _initialize_default_skills(self) -> None:
        """Initialize with common AoE skills."""
        default_skills = [
            AoESkill(
                skill_name="Storm Gust",
                shape=AoEShape.CIRCLE,
                range=5,
                cast_range=9,
                cells_affected=81,
                hits_per_target=10,
                sp_cost=78,
            ),
            AoESkill(
                skill_name="Meteor Storm",
                shape=AoEShape.CIRCLE,
                range=3,
                cast_range=9,
                cells_affected=37,
                hits_per_target=7,
                sp_cost=70,
            ),
            AoESkill(
                skill_name="Magnus Exorcismus",
                shape=AoEShape.CROSS,
                range=3,
                cast_range=9,
                cells_affected=25,
                hits_per_target=10,
                sp_cost=80,
            ),
            AoESkill(
                skill_name="Lord of Vermillion",
                shape=AoEShape.CIRCLE,
                range=5,
                cast_range=9,
                cells_affected=81,
                hits_per_target=8,
                sp_cost=60,
            ),
            AoESkill(
                skill_name="Heaven's Drive",
                shape=AoEShape.CIRCLE,
                range=2,
                cast_range=9,
                cells_affected=25,
                hits_per_target=5,
                sp_cost=28,
            ),
        ]
        
        for skill in default_skills:
            self.aoe_skills[skill.skill_name.lower()] = skill
            
        self.log.info("initialized_default_aoe_skills", count=len(default_skills))
        
    def _load_aoe_skills(self, data_dir: Path) -> None:
        """Load AoE skill data from JSON."""
        skill_file = data_dir / "aoe_skills.json"
        
        if not skill_file.exists():
            self.log.warning("aoe_data_not_found", path=str(skill_file))
            self._initialize_default_skills()
            return
            
        try:
            with open(skill_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                
            for skill_name, skill_data in data.items():
                skill = AoESkill(skill_name=skill_name, **skill_data)
                self.aoe_skills[skill_name.lower()] = skill
                
            self.log.info("loaded_aoe_data", path=str(skill_file), skills=len(self.aoe_skills))
            
        except Exception as e:
            self.log.error("failed_to_load_aoe_data", path=str(skill_file), error=str(e))
            self._initialize_default_skills()
            
    def _distance(self, pos1: Tuple[int, int], pos2: Tuple[int, int]) -> float:
        """Calculate Euclidean distance between positions."""
        dx = pos1[0] - pos2[0]
        dy = pos1[1] - pos2[1]
        return math.sqrt(dx * dx + dy * dy)
        
    async def find_optimal_center(
        self,
        monster_positions: List[Tuple[int, int]],
        aoe_skill: AoESkill,
        player_position: Tuple[int, int],
    ) -> Tuple[int, int]:
        """
        Find best center point to hit most monsters.
        
        Args:
            monster_positions: List of monster positions
            aoe_skill: AoE skill to use
            player_position: Player's current position
            
        Returns:
            Optimal center position
        """
        if not monster_positions:
            return player_position
            
        # For self-centered skills, return player position
        if aoe_skill.shape == AoEShape.SELF_CIRCLE:
            return player_position
            
        best_center = player_position
        max_hits = 0
        
        # Try each monster as potential center
        for candidate in monster_positions:
            # Check if within cast range
            if self._distance(player_position, candidate) > aoe_skill.cast_range:
                continue
                
            # Count how many would be hit
            hits = sum(
                1 for pos in monster_positions
                if self._distance(candidate, pos) <= aoe_skill.range
            )
            
            if hits > max_hits:
                max_hits = hits
                best_center = candidate
                
        self.log.debug(
            "optimal_center_found",
            skill=aoe_skill.skill_name,
            center=best_center,
            hits=max_hits,
        )
        
        return best_center
        
    async def calculate_targets_hit(
        self,
        center: Tuple[int, int],
        aoe_skill: AoESkill,
        monster_positions: List[Tuple[int, int]],
        monster_ids: Optional[List[str]] = None,
    ) -> List[AoETarget]:
        """
        Calculate which monsters would be hit.
        
        Args:
            center: AoE center position
            aoe_skill: AoE skill
            monster_positions: Monster positions
            monster_ids: Optional monster IDs
            
        Returns:
            List of targets hit
        """
        targets: List[AoETarget] = []
        
        if not monster_ids:
            monster_ids = [f"mob_{i}" for i in range(len(monster_positions))]
            
        for i, pos in enumerate(monster_positions):
            distance = self._distance(center, pos)
            
            # Check if within range
            if distance <= aoe_skill.range:
                # Calculate damage falloff if applicable
                damage_percent = 1.0
                if aoe_skill.damage_falloff and aoe_skill.range > 0:
                    # Linear falloff: 100% at center, decreasing to edges
                    damage_percent = 1.0 - (distance / aoe_skill.range) * 0.5
                    
                target = AoETarget(
                    entity_id=monster_ids[i],
                    position=pos,
                    distance_from_center=distance,
                    expected_damage_percent=damage_percent,
                )
                targets.append(target)
                
        return targets
        
    async def select_best_aoe_skill(
        self,
        available_skills: List[str],
        monster_positions: List[Tuple[int, int]],
        player_position: Tuple[int, int],
        sp_available: int,
    ) -> Tuple[Optional[str], Tuple[int, int]]:
        """
        Select best AoE skill and position.
        
        Args:
            available_skills: Available AoE skills
            monster_positions: Monster positions
            player_position: Player position
            sp_available: Available SP
            
        Returns:
            Tuple of (skill_name, optimal_position) or (None, player_position)
        """
        if not monster_positions:
            return None, player_position
            
        best_skill = None
        best_center = player_position
        best_efficiency = 0.0
        
        for skill_name in available_skills:
            skill = self.aoe_skills.get(skill_name.lower())
            if not skill:
                continue
                
            # Check SP
            if skill.sp_cost > sp_available:
                continue
                
            # Find optimal center
            center = await self.find_optimal_center(
                monster_positions, skill, player_position
            )
            
            # Calculate targets
            targets = await self.calculate_targets_hit(
                center, skill, monster_positions
            )
            
            # Calculate efficiency (targets * hits / SP)
            if len(targets) > 0 and skill.sp_cost > 0:
                efficiency = (len(targets) * skill.hits_per_target) / skill.sp_cost
            else:
                efficiency = 0.0
                
            if efficiency > best_efficiency:
                best_efficiency = efficiency
                best_skill = skill_name
                best_center = center
                
        self.log.info(
            "best_aoe_selected",
            skill=best_skill,
            center=best_center,
            efficiency=best_efficiency,
        )
        
        return best_skill, best_center
        
    async def detect_mob_cluster(
        self,
        monster_positions: List[Tuple[int, int]],
        min_cluster_size: int = 3,
        max_cluster_distance: float = 5.0,
    ) -> List[List[Tuple[int, int]]]:
        """
        Detect clusters of monsters for AoE.
        
        Simple clustering: group monsters within max_distance of each other
        
        Args:
            monster_positions: All monster positions
            min_cluster_size: Minimum cluster size
            max_cluster_distance: Maximum distance between cluster members
            
        Returns:
            List of clusters (each cluster is list of positions)
        """
        if len(monster_positions) < min_cluster_size:
            return []
            
        clusters: List[List[Tuple[int, int]]] = []
        unassigned = list(monster_positions)
        
        while unassigned:
            # Start new cluster with first unassigned
            seed = unassigned.pop(0)
            cluster = [seed]
            
            # Find all within distance
            i = 0
            while i < len(unassigned):
                pos = unassigned[i]
                # Check if close to any in cluster
                if any(self._distance(pos, c) <= max_cluster_distance for c in cluster):
                    cluster.append(pos)
                    unassigned.pop(i)
                else:
                    i += 1
                    
            # Only keep if meets minimum size
            if len(cluster) >= min_cluster_size:
                clusters.append(cluster)
                
        self.log.debug("clusters_detected", count=len(clusters))
        
        return clusters
        
    async def plan_aoe_sequence(
        self,
        clusters: List[List[Tuple[int, int]]],
        available_skills: List[str],
        player_position: Tuple[int, int],
        sp_available: int,
    ) -> List[dict]:
        """
        Plan sequence of AoE skills for multiple clusters.
        
        Args:
            clusters: Detected mob clusters
            available_skills: Available AoE skills
            player_position: Player position
            sp_available: Available SP
            
        Returns:
            List of planned actions (skill, center, targets)
        """
        sequence = []
        remaining_sp = sp_available
        
        for cluster in clusters:
            if remaining_sp <= 0:
                break
                
            # Select best skill for this cluster
            skill_name, center = await self.select_best_aoe_skill(
                available_skills,
                cluster,
                player_position,
                remaining_sp,
            )
            
            if not skill_name:
                continue
                
            skill = self.aoe_skills.get(skill_name.lower())
            if not skill:
                continue
                
            # Calculate targets
            targets = await self.calculate_targets_hit(center, skill, cluster)
            
            action = {
                "skill": skill_name,
                "center": center,
                "targets": len(targets),
                "sp_cost": skill.sp_cost,
            }
            sequence.append(action)
            remaining_sp -= skill.sp_cost
            
        self.log.info("aoe_sequence_planned", actions=len(sequence))
        
        return sequence