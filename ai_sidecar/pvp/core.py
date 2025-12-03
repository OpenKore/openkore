"""
Core PvP engine with threat assessment and target prioritization.

Handles fundamental PvP decision-making including threat evaluation,
target selection, positioning strategy, and engagement decisions.
"""

import json
import math
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, Field


class PvPMode(str, Enum):
    """PvP game modes"""

    OPEN_WORLD = "open_world"
    GVG = "gvg"
    WOE_FE = "woe_fe"
    WOE_SE = "woe_se"
    WOE_TE = "woe_te"
    BATTLEGROUND = "battleground"
    ARENA = "arena"


class ThreatLevel(str, Enum):
    """Threat assessment levels"""

    NONE = "none"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class PlayerThreat(BaseModel):
    """Threat assessment for an enemy player"""

    player_id: int
    player_name: str
    job_class: str
    level: int
    guild_name: str | None = None

    # Threat scoring
    threat_level: ThreatLevel = ThreatLevel.MEDIUM
    threat_score: float = 50.0

    # Combat assessment
    estimated_hp: int = 0
    estimated_damage: int = 0
    is_casting: bool = False
    current_skill: str | None = None

    # Position tracking
    position: tuple[int, int] = (0, 0)
    last_seen: datetime = Field(default_factory=datetime.now)
    movement_direction: str | None = None

    # Historical data
    kills_against_us: int = 0
    deaths_to_us: int = 0
    win_rate: float = 0.5


class ThreatAssessor:
    """
    Assess and prioritize enemy threats.

    Evaluates players based on job class, HP/SP status, buffs,
    historical performance, and current activity.
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.threats: dict[int, PlayerThreat] = {}
        self.job_danger_ratings: dict[str, float] = {}
        self.modifiers: dict[str, float] = {}
        self._load_danger_ratings(data_dir)

    def _load_danger_ratings(self, data_dir: Path) -> None:
        """Load job danger ratings from config"""
        ratings_file = data_dir / "job_danger_ratings.json"

        try:
            with open(ratings_file, encoding="utf-8") as f:
                data = json.load(f)
                self.job_danger_ratings = data.get("ratings", {})
                self.modifiers = data.get("modifiers", {})

            self.log.info("Job danger ratings loaded", count=len(self.job_danger_ratings))
        except Exception as e:
            self.log.error("Failed to load danger ratings", error=str(e))
            # Set default ratings
            self.job_danger_ratings = {"default": 5.0}
            self.modifiers = {}

    def assess_threat(self, player_data: dict[str, Any]) -> PlayerThreat:
        """Assess threat level for a player"""
        player_id = player_data.get("player_id", 0)

        # Get existing threat or create new
        threat = self.threats.get(player_id)
        if not threat:
            threat = PlayerThreat(
                player_id=player_id,
                player_name=player_data.get("name", "Unknown"),
                job_class=player_data.get("job_class", "unknown"),
                level=player_data.get("level", 1),
                guild_name=player_data.get("guild", None),
            )

        # Update dynamic data
        threat.position = player_data.get("position", (0, 0))
        threat.is_casting = player_data.get("is_casting", False)
        threat.current_skill = player_data.get("current_skill", None)
        threat.estimated_hp = player_data.get("hp", 0)
        threat.last_seen = datetime.now()

        # Calculate threat score
        threat.threat_score = self.calculate_threat_score(threat)
        threat.threat_level = self._score_to_level(threat.threat_score)

        self.threats[player_id] = threat
        return threat

    def calculate_threat_score(self, player: PlayerThreat) -> float:
        """Calculate overall threat score"""
        # Base job danger rating
        base_score = self.job_danger_ratings.get(
            player.job_class.lower(), self.job_danger_ratings.get("default", 5.0)
        )

        # Apply modifiers
        score = base_score

        if player.is_casting:
            score *= self.modifiers.get("is_casting", 1.5)

        # HP modifier
        if player.estimated_hp > 0:
            hp_percent = player.estimated_hp / max(player.level * 100, 1)
            if hp_percent < 0.3:
                score *= self.modifiers.get("low_hp_percent", 0.5)
            elif hp_percent > 0.8:
                score *= self.modifiers.get("high_hp_percent", 1.2)

        # Historical performance
        if player.deaths_to_us > 0:
            score *= max(0.5, 1.0 - (player.deaths_to_us * 0.1))
        if player.kills_against_us > 0:
            score *= 1.0 + (player.kills_against_us * 0.15)

        # Guild leader bonus
        if player.guild_name and "leader" in player.player_name.lower():
            score *= self.modifiers.get("is_guild_leader", 1.5)

        return min(100.0, max(0.0, score * 10.0))

    def _score_to_level(self, score: float) -> ThreatLevel:
        """Convert numeric score to threat level"""
        if score < 20:
            return ThreatLevel.LOW
        elif score < 40:
            return ThreatLevel.MEDIUM
        elif score < 70:
            return ThreatLevel.HIGH
        else:
            return ThreatLevel.CRITICAL

    def get_priority_targets(self, limit: int = 5) -> list[PlayerThreat]:
        """Get top priority targets to focus"""
        sorted_threats = sorted(
            self.threats.values(), key=lambda t: t.threat_score, reverse=True
        )
        return sorted_threats[:limit]

    def update_threat(self, player_id: int, event: str, data: dict[str, Any]) -> None:
        """Update threat based on observed event"""
        if player_id not in self.threats:
            # Create new threat entry from event data
            threat = PlayerThreat(
                player_id=player_id,
                player_name=data.get("name", f"Player{player_id}"),
                job_class=data.get("job_class", "unknown"),
                level=data.get("level", 1),
                guild_name=data.get("guild", None),
            )
            self.threats[player_id] = threat
        
        threat = self.threats[player_id]

        if event == "killed_us":
            threat.kills_against_us += 1
        elif event == "killed_by_us":
            threat.deaths_to_us += 1
        elif event == "skill_cast":
            threat.is_casting = True
            threat.current_skill = data.get("skill_name")
        elif event == "skill_end":
            threat.is_casting = False
            threat.current_skill = None

        # Recalculate
        threat.threat_score = self.calculate_threat_score(threat)
        threat.threat_level = self._score_to_level(threat.threat_score)

    def get_threat_in_range(
        self, position: tuple[int, int], range_cells: int
    ) -> list[PlayerThreat]:
        """Get threats within range of position"""
        in_range: list[PlayerThreat] = []

        for threat in self.threats.values():
            distance = self._calculate_distance(position, threat.position)
            if distance <= range_cells:
                in_range.append(threat)

        return sorted(in_range, key=lambda t: t.threat_score, reverse=True)

    def _calculate_distance(
        self, pos1: tuple[int, int], pos2: tuple[int, int]
    ) -> float:
        """Calculate Euclidean distance between positions"""
        return math.sqrt((pos1[0] - pos2[0]) ** 2 + (pos1[1] - pos2[1]) ** 2)

    def should_flee(self, own_state: dict[str, Any]) -> bool:
        """Determine if we should flee based on threat assessment"""
        own_hp_percent = own_state.get("hp_percent", 100.0)
        nearby_range = 10

        nearby_threats = self.get_threat_in_range(
            own_state.get("position", (0, 0)), nearby_range
        )

        # Count high/critical threats nearby
        dangerous_count = sum(
            1
            for t in nearby_threats
            if t.threat_level in [ThreatLevel.HIGH, ThreatLevel.CRITICAL]
        )

        # Flee conditions
        if own_hp_percent < 30 and dangerous_count >= 1:
            return True
        if own_hp_percent < 50 and dangerous_count >= 2:
            return True
        if dangerous_count >= 3:
            return True

        return False

    def clear_old_threats(self, max_age_seconds: int = 300) -> None:
        """Remove threats not seen recently"""
        now = datetime.now()
        to_remove = [
            pid
            for pid, threat in self.threats.items()
            if (now - threat.last_seen).total_seconds() > max_age_seconds
        ]

        for pid in to_remove:
            del self.threats[pid]

        if to_remove:
            self.log.debug("Cleared old threats", count=len(to_remove))


class PvPCoreEngine:
    """
    Core PvP decision engine.

    Handles target selection, positioning, skill timing,
    and engagement decisions.
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.threat_assessor = ThreatAssessor(data_dir)
        self.current_mode: PvPMode = PvPMode.OPEN_WORLD
        self.target_priorities: dict[str, float] = {}

    async def set_pvp_mode(self, mode: PvPMode) -> None:
        """Set current PvP mode and adjust strategies"""
        self.current_mode = mode
        self.log.info("PvP mode changed", mode=mode.value)

        # Adjust priorities based on mode
        if mode == PvPMode.WOE_FE or mode == PvPMode.WOE_SE:
            self.target_priorities = {"emp_breaker": 10.0, "healer": 8.0, "dps": 6.0}
        elif mode == PvPMode.BATTLEGROUND:
            self.target_priorities = {"flag_carrier": 10.0, "healer": 7.0, "dps": 5.0}
        else:
            self.target_priorities = {"high_threat": 8.0, "healer": 7.0, "dps": 6.0}

    async def select_target(
        self,
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
        own_state: dict[str, Any],
    ) -> int | None:
        """
        Select optimal target based on threat, vulnerability,
        and strategic value.
        """
        if not enemies:
            return None

        # Assess all enemies
        threats = [self.threat_assessor.assess_threat(enemy) for enemy in enemies]

        # Filter to attackable range
        own_pos = own_state.get("position", (0, 0))
        attack_range = own_state.get("attack_range", 10)

        in_range = self.threat_assessor.get_threat_in_range(own_pos, attack_range)

        if not in_range:
            # Return closest high-threat target to move toward
            if threats:
                return max(threats, key=lambda t: t.threat_score).player_id
            return None

        # Prioritize based on mode
        if self.current_mode in [PvPMode.WOE_FE, PvPMode.WOE_SE]:
            # Focus healers and emp breakers in WoE
            priority_jobs = ["high_priest", "archbishop", "champion", "guillotine_cross"]
            priority_targets = [
                t for t in in_range if t.job_class.lower() in priority_jobs
            ]
            if priority_targets:
                return max(priority_targets, key=lambda t: t.threat_score).player_id

        # Default: highest threat in range
        return max(in_range, key=lambda t: t.threat_score).player_id

    async def get_optimal_position(
        self,
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
        own_state: dict[str, Any],
        map_layout: dict[str, Any],
    ) -> tuple[int, int]:
        """Calculate optimal positioning"""
        own_pos = own_state.get("position", (0, 0))
        job_class = own_state.get("job_class", "").lower()

        # Different strategies based on job
        if "priest" in job_class or "arch" in job_class:
            # Healers: stay behind frontline
            return await self._healer_position(own_pos, allies)
        elif "wizard" in job_class or "warlock" in job_class:
            # Casters: max range, safe position
            return await self._caster_position(own_pos, enemies, allies)
        else:
            # Melee/Ranged DPS: aggressive positioning
            return await self._dps_position(own_pos, enemies, allies)

    async def _healer_position(
        self, own_pos: tuple[int, int], allies: list[dict[str, Any]]
    ) -> tuple[int, int]:
        """Calculate healer positioning (behind allies)"""
        if not allies:
            return own_pos

        # Find center of allies
        avg_x = sum(a.get("position", (0, 0))[0] for a in allies) / len(allies)
        avg_y = sum(a.get("position", (0, 0))[1] for a in allies) / len(allies)

        # Position slightly behind
        return (int(avg_x), int(avg_y) + 3)

    async def _caster_position(
        self,
        own_pos: tuple[int, int],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
    ) -> tuple[int, int]:
        """Calculate caster positioning (max range)"""
        if not enemies:
            return own_pos

        # Stay at max range from nearest enemy
        nearest_enemy_pos = min(
            enemies,
            key=lambda e: self.threat_assessor._calculate_distance(
                own_pos, e.get("position", (0, 0))
            ),
        ).get("position", own_pos)

        # Move to range 14 (max magic range typically)
        return self._position_at_range(own_pos, nearest_enemy_pos, 14)

    async def _dps_position(
        self,
        own_pos: tuple[int, int],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
    ) -> tuple[int, int]:
        """Calculate DPS positioning (aggressive)"""
        if not enemies:
            return own_pos

        # Move toward highest threat enemy
        target = max(
            enemies, key=lambda e: self.threat_assessor.calculate_threat_score(
                self.threat_assessor.assess_threat(e)
            )
        )

        return target.get("position", own_pos)

    def _position_at_range(
        self, own_pos: tuple[int, int], target_pos: tuple[int, int], desired_range: int
    ) -> tuple[int, int]:
        """Calculate position at specific range from target"""
        dx = own_pos[0] - target_pos[0]
        dy = own_pos[1] - target_pos[1]
        distance = math.sqrt(dx * dx + dy * dy)

        if distance == 0:
            return own_pos

        # Normalize and scale to desired range
        ratio = desired_range / distance
        new_x = int(target_pos[0] + dx * ratio)
        new_y = int(target_pos[1] + dy * ratio)

        return (new_x, new_y)

    async def should_engage(
        self, enemy: dict[str, Any], own_state: dict[str, Any], allies_nearby: int
    ) -> bool:
        """Determine if we should engage this enemy"""
        threat = self.threat_assessor.assess_threat(enemy)

        own_hp_percent = own_state.get("hp_percent", 100.0)
        own_sp_percent = own_state.get("sp_percent", 100.0)

        # Don't engage if critically low resources
        if own_hp_percent < 20 or own_sp_percent < 10:
            return False

        # Engage if threat is manageable
        if threat.threat_level in [ThreatLevel.LOW, ThreatLevel.MEDIUM]:
            return True

        # High threats: need backup
        if threat.threat_level == ThreatLevel.HIGH and allies_nearby >= 1:
            return True

        # Critical threats: need multiple allies
        if threat.threat_level == ThreatLevel.CRITICAL and allies_nearby >= 2:
            return True

        return False

    async def calculate_kill_potential(
        self, target: dict[str, Any], own_state: dict[str, Any]
    ) -> float:
        """Calculate probability of killing target (0.0-1.0)"""
        target_hp = target.get("hp", 1000)
        own_damage = own_state.get("avg_damage", 100)

        # Estimate hits to kill
        hits_to_kill = max(1, target_hp / own_damage)

        # Factor in target's threat level
        threat = self.threat_assessor.assess_threat(target)

        # Higher threat = lower kill potential
        threat_penalty = {
            ThreatLevel.LOW: 0.0,
            ThreatLevel.MEDIUM: 0.1,
            ThreatLevel.HIGH: 0.3,
            ThreatLevel.CRITICAL: 0.5,
        }.get(threat.threat_level, 0.2)

        base_potential = 1.0 / hits_to_kill
        adjusted_potential = max(0.0, base_potential - threat_penalty)

        return min(1.0, adjusted_potential)

    async def get_pvp_skill_rotation(
        self, target: dict[str, Any], own_state: dict[str, Any], situation: str
    ) -> list[str]:
        """Get PvP-optimized skill rotation"""
        job_class = own_state.get("job_class", "").lower()

        # Return job-specific burst rotations
        # This is a simplified version; full implementation would load from combos
        rotations = {
            "champion": ["Snap", "Zen", "Asura Strike"],
            "assassin_cross": ["Soul Destroyer", "Soul Destroyer", "Soul Destroyer"],
            "warlock": ["Tetra Vortex", "Comet"],
            "ranger": ["Aimed Bolt", "Double Strafe"],
        }

        for job_key, rotation in rotations.items():
            if job_key in job_class:
                return rotation

        return ["Attack"]