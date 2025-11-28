"""
PvP tactics engine - Advanced combat tactics and combo execution.

Features:
- Crowd control (CC) chains
- Burst damage timing
- Kiting patterns and positioning
- Combo execution
- Defensive rotations
"""

import json
import math
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, Field


class CrowdControlType(str, Enum):
    """Types of crowd control"""

    STUN = "stun"
    FREEZE = "freeze"
    STONE = "stone"
    SLEEP = "sleep"
    BLIND = "blind"
    SILENCE = "silence"
    IMMOBILIZE = "immobilize"
    SLOW = "slow"
    FEAR = "fear"


class TacticalAction(str, Enum):
    """Tactical actions"""

    BURST = "burst"
    KITE = "kite"
    ENGAGE = "engage"
    DISENGAGE = "disengage"
    DEFEND = "defend"
    CC_CHAIN = "cc_chain"
    POKE = "poke"
    ALL_IN = "all_in"


class ComboChain(BaseModel):
    """Skill combo chain"""

    name: str
    job_class: str
    skills: list[str]
    total_cast_time_ms: int
    total_damage: int
    cc_type: CrowdControlType | None = None
    requirements: dict[str, Any] = Field(default_factory=dict)
    description: str = ""
    combo_type: str = "offensive"  # offensive, defensive, support


class BurstWindow(BaseModel):
    """Burst damage opportunity window"""

    window_id: str
    start_time: datetime
    duration_seconds: float
    target_id: int
    target_vulnerable: bool = False
    cc_active: bool = False
    cooldowns_ready: list[str] = Field(default_factory=list)
    priority: int = 5


class KitingPattern(BaseModel):
    """Kiting movement pattern"""

    pattern_id: str
    current_position: tuple[int, int]
    safe_positions: list[tuple[int, int]]
    threat_positions: list[tuple[int, int]]
    optimal_range: int = 10
    movement_speed: int = 100


class PvPTacticsEngine:
    """
    Advanced PvP tactics and combat execution.

    Features:
    - Smart combo execution
    - Burst damage timing
    - Kiting and positioning
    - CC chain optimization
    - Defensive skill usage
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.combos: dict[str, list[ComboChain]] = {}
        self.defensive_combos: dict[str, list[ComboChain]] = {}
        self.support_combos: dict[str, list[ComboChain]] = {}
        self.last_combo_time: datetime | None = None
        self.last_cc_time: datetime | None = None
        self.active_burst_window: BurstWindow | None = None
        self.cooldowns: dict[str, datetime] = {}
        self.cc_immunity_until: datetime | None = None

        self._load_combos(data_dir)

    def _load_combos(self, data_dir: Path) -> None:
        """Load combo data from config"""
        combo_file = data_dir / "pvp_combos.json"

        try:
            with open(combo_file, encoding="utf-8") as f:
                data = json.load(f)

            # Load offensive combos
            for job_class, combos in data.get("combos", {}).items():
                self.combos[job_class] = [
                    ComboChain(
                        name=combo.get("name", "unknown"),
                        job_class=job_class,
                        skills=combo.get("skills", []),
                        total_cast_time_ms=combo.get("total_cast_time_ms", 1000),
                        total_damage=combo.get("total_damage", 0),
                        cc_type=CrowdControlType(combo["cc_type"]) if combo.get("cc_type") else None,
                        requirements=combo.get("requirements", {}),
                        description=combo.get("description", ""),
                        combo_type="offensive",
                    )
                    for combo in combos
                ]

            # Load defensive combos
            for job_class, combos in data.get("defensive_combos", {}).items():
                self.defensive_combos[job_class] = [
                    ComboChain(
                        name=combo.get("name", "unknown"),
                        job_class=job_class,
                        skills=combo.get("skills", []),
                        total_cast_time_ms=combo.get("total_cast_time_ms", 1000),
                        total_damage=0,
                        description=combo.get("description", ""),
                        combo_type="defensive",
                    )
                    for combo in combos
                ]

            # Load support combos
            for job_class, combos in data.get("support_combos", {}).items():
                self.support_combos[job_class] = [
                    ComboChain(
                        name=combo.get("name", "unknown"),
                        job_class=job_class,
                        skills=combo.get("skills", []),
                        total_cast_time_ms=combo.get("total_cast_time_ms", 1000),
                        total_damage=0,
                        description=combo.get("description", ""),
                        combo_type="support",
                    )
                    for combo in combos
                ]

            total = sum(len(c) for c in self.combos.values())
            self.log.info("PvP combos loaded", combo_count=total)

        except Exception as e:
            self.log.error("Failed to load combos", error=str(e))

    async def get_tactical_action(
        self,
        own_state: dict[str, Any],
        target: dict[str, Any],
        allies_nearby: int,
        enemies_nearby: int,
    ) -> TacticalAction:
        """Determine optimal tactical action"""
        own_hp_percent = own_state.get("hp_percent", 100.0)
        own_sp_percent = own_state.get("sp_percent", 100.0)
        job_class = own_state.get("job_class", "").lower()

        # Critical HP - disengage
        if own_hp_percent < 25:
            return TacticalAction.DISENGAGE

        # Outnumbered significantly - kite
        if enemies_nearby > allies_nearby + 2:
            return TacticalAction.KITE

        # Target is low HP and we have resources - all-in
        target_hp_percent = target.get("hp_percent", 100.0)
        if target_hp_percent < 30 and own_sp_percent > 40:
            return TacticalAction.ALL_IN

        # Target is vulnerable (CC'd) - burst
        if target.get("is_stunned") or target.get("is_frozen"):
            return TacticalAction.BURST

        # Good HP/SP and close combat - engage
        if own_hp_percent > 60 and own_sp_percent > 50:
            return TacticalAction.ENGAGE

        # Ranged class with enemies approaching - kite
        is_ranged = any(
            role in job_class for role in ["ranger", "warlock", "wizard", "gunslinger"]
        )
        if is_ranged and enemies_nearby > 0:
            distance = self._calculate_distance(
                own_state.get("position", (0, 0)),
                target.get("position", (0, 0))
            )
            if distance < 5:
                return TacticalAction.KITE

        # Default: engage
        return TacticalAction.ENGAGE

    async def get_optimal_combo(
        self, job_class: str, target: dict[str, Any], own_state: dict[str, Any]
    ) -> ComboChain | None:
        """Get optimal combo for current situation"""
        job_key = job_class.lower().replace(" ", "_")

        # Check if we have combos for this job
        if job_key not in self.combos:
            # Try partial match
            for key in self.combos.keys():
                if key in job_key or job_key in key:
                    job_key = key
                    break
            else:
                return None

        available_combos = self.combos.get(job_key, [])
        if not available_combos:
            return None

        # Filter by requirements
        valid_combos = []
        for combo in available_combos:
            if self._check_combo_requirements(combo, own_state):
                valid_combos.append(combo)

        if not valid_combos:
            return None

        # Score combos
        scored = []
        for combo in valid_combos:
            score = self._score_combo(combo, target, own_state)
            scored.append((combo, score))

        # Return highest scored combo
        if scored:
            return max(scored, key=lambda x: x[1])[0]

        return None

    def _check_combo_requirements(
        self, combo: ComboChain, own_state: dict[str, Any]
    ) -> bool:
        """Check if combo requirements are met"""
        for req_key, req_value in combo.requirements.items():
            state_value = own_state.get(req_key)

            # Handle different requirement types
            if isinstance(req_value, bool):
                if state_value != req_value:
                    return False
            elif isinstance(req_value, int):
                if state_value is None or state_value < req_value:
                    return False
            elif isinstance(req_value, str):
                if state_value != req_value:
                    return False

        # Check cooldowns
        for skill in combo.skills:
            if skill in self.cooldowns:
                if datetime.now() < self.cooldowns[skill]:
                    return False

        return True

    def _score_combo(
        self, combo: ComboChain, target: dict[str, Any], own_state: dict[str, Any]
    ) -> float:
        """Score combo for current situation"""
        score = 0.0

        # Base damage score
        score += combo.total_damage / 1000.0

        # CC bonus
        if combo.cc_type:
            score += 20.0

        # Target HP consideration
        target_hp_percent = target.get("hp_percent", 100.0)
        if target_hp_percent < 50:
            score += 15.0
        if target_hp_percent < 30:
            score += 25.0

        # SP efficiency
        own_sp_percent = own_state.get("sp_percent", 100.0)
        if own_sp_percent < 40:
            # Penalty for expensive combos when low SP
            score -= 20.0

        # Cast time penalty
        if combo.total_cast_time_ms > 4000:
            score -= 10.0

        return score

    async def calculate_burst_window(
        self, target: dict[str, Any], own_state: dict[str, Any]
    ) -> BurstWindow | None:
        """Calculate if burst window is available"""
        # Check if target is vulnerable
        target_vulnerable = (
            target.get("is_stunned", False)
            or target.get("is_frozen", False)
            or target.get("is_sleeping", False)
        )

        # Check cooldowns
        job_class = own_state.get("job_class", "").lower()
        key_cooldowns = self._get_key_skills(job_class)
        cooldowns_ready = [
            skill for skill in key_cooldowns
            if skill not in self.cooldowns or datetime.now() >= self.cooldowns[skill]
        ]

        # Burst window if:
        # 1. Target is vulnerable
        # 2. We have key cooldowns ready
        # 3. We have enough SP
        own_sp_percent = own_state.get("sp_percent", 100.0)

        if target_vulnerable or (len(cooldowns_ready) >= 2 and own_sp_percent > 50):
            window = BurstWindow(
                window_id=f"burst_{target['player_id']}_{datetime.now().timestamp()}",
                start_time=datetime.now(),
                duration_seconds=3.0 if target_vulnerable else 2.0,
                target_id=target.get("player_id", 0),
                target_vulnerable=target_vulnerable,
                cc_active=target_vulnerable,
                cooldowns_ready=cooldowns_ready,
                priority=10 if target_vulnerable else 7,
            )
            self.active_burst_window = window
            return window

        return None

    def _get_key_skills(self, job_class: str) -> list[str]:
        """Get key burst skills for job class"""
        key_skills_map = {
            "champion": ["Asura Strike", "Raging Quadruple Blow"],
            "assassin_cross": ["Soul Destroyer", "Sonic Blow"],
            "warlock": ["Comet", "Tetra Vortex"],
            "ranger": ["Arrow Storm", "Warg Strike"],
            "rune_knight": ["Hundred Spear", "Ignition Break"],
        }

        for job_key, skills in key_skills_map.items():
            if job_key in job_class:
                return skills

        return []

    async def get_kiting_path(
        self,
        own_position: tuple[int, int],
        enemy_position: tuple[int, int],
        optimal_range: int = 10,
        map_bounds: tuple[int, int, int, int] = (0, 0, 400, 400),
    ) -> list[tuple[int, int]]:
        """Calculate kiting path to maintain optimal range"""
        # Calculate direction away from enemy
        dx = own_position[0] - enemy_position[0]
        dy = own_position[1] - enemy_position[1]
        distance = math.sqrt(dx * dx + dy * dy)

        if distance == 0:
            # We're at same position, move in random safe direction
            dx, dy = 1, 0

        # Normalize direction
        dx = dx / distance if distance > 0 else 1
        dy = dy / distance if distance > 0 else 0

        # Calculate ideal position at optimal range
        target_x = enemy_position[0] + dx * optimal_range
        target_y = enemy_position[1] + dy * optimal_range

        # Clamp to map bounds
        min_x, min_y, max_x, max_y = map_bounds
        target_x = max(min_x, min(max_x, target_x))
        target_y = max(min_y, min(max_y, target_y))

        # Create path with intermediate waypoints
        path = [own_position]

        # Add waypoint halfway
        mid_x = (own_position[0] + target_x) / 2
        mid_y = (own_position[1] + target_y) / 2
        path.append((int(mid_x), int(mid_y)))

        # Add final position
        path.append((int(target_x), int(target_y)))

        return path

    async def should_use_cc(
        self, target: dict[str, Any], own_state: dict[str, Any]
    ) -> tuple[bool, CrowdControlType | None]:
        """Determine if we should use crowd control"""
        # Don't CC if target is immune
        if target.get("cc_immune", False):
            return False, None

        # Don't CC if we used CC recently (avoid immunity stacking)
        if self.last_cc_time:
            time_since_cc = (datetime.now() - self.last_cc_time).total_seconds()
            if time_since_cc < 5.0:
                return False, None

        # Priority targets for CC
        target_job = target.get("job_class", "").lower()
        high_priority = any(
            role in target_job
            for role in ["priest", "archbishop", "warlock", "wizard"]
        )

        # Use CC if:
        # 1. Target is high priority
        # 2. Target is casting
        # 3. We need to escape
        target_casting = target.get("is_casting", False)
        own_hp_percent = own_state.get("hp_percent", 100.0)
        need_escape = own_hp_percent < 30

        if high_priority or target_casting or need_escape:
            # Determine CC type based on job
            job_class = own_state.get("job_class", "").lower()
            cc_type = self._get_preferred_cc(job_class)
            return True, cc_type

        return False, None

    def _get_preferred_cc(self, job_class: str) -> CrowdControlType:
        """Get preferred CC type for job"""
        cc_map = {
            "champion": CrowdControlType.STUN,
            "warlock": CrowdControlType.FREEZE,
            "wizard": CrowdControlType.FREEZE,
            "archbishop": CrowdControlType.SILENCE,
            "rune_knight": CrowdControlType.STUN,
            "royal_guard": CrowdControlType.STUN,
        }

        for job_key, cc_type in cc_map.items():
            if job_key in job_class:
                return cc_type

        return CrowdControlType.STUN

    async def get_defensive_rotation(
        self, job_class: str, threat_level: str
    ) -> list[str]:
        """Get defensive skill rotation"""
        job_key = job_class.lower().replace(" ", "_")

        # Check defensive combos
        if job_key in self.defensive_combos:
            combos = self.defensive_combos[job_key]
            if combos:
                # Return first available defensive combo
                return combos[0].skills

        # Fallback defensive skills by job
        defensive_skills = {
            "champion": ["Dodge", "Root", "Snap"],
            "assassin_cross": ["Cloaking", "Backslide"],
            "archbishop": ["Sanctuary", "Safety Wall", "Heal"],
            "warlock": ["Teleport", "Stone Curse"],
            "ranger": ["Camouflage", "Ankle Snare"],
        }

        for job_key, skills in defensive_skills.items():
            if job_key in job_class:
                return skills

        return ["Teleport"]

    def mark_skill_used(self, skill_name: str, cooldown_seconds: float) -> None:
        """Mark skill as used and on cooldown"""
        self.cooldowns[skill_name] = datetime.now() + timedelta(seconds=cooldown_seconds)

    def mark_combo_used(self, combo: ComboChain) -> None:
        """Mark combo as used"""
        self.last_combo_time = datetime.now()

        # Mark all skills in combo on cooldown
        for skill in combo.skills:
            # Estimate 2-second cooldown per skill
            self.mark_skill_used(skill, 2.0)

    def mark_cc_used(self) -> None:
        """Mark CC as used"""
        self.last_cc_time = datetime.now()

    def is_skill_ready(self, skill_name: str) -> bool:
        """Check if skill is off cooldown"""
        if skill_name not in self.cooldowns:
            return True

        return datetime.now() >= self.cooldowns[skill_name]

    def _calculate_distance(
        self, pos1: tuple[int, int], pos2: tuple[int, int]
    ) -> float:
        """Calculate Euclidean distance"""
        return math.sqrt((pos1[0] - pos2[0]) ** 2 + (pos1[1] - pos2[1]) ** 2)

    async def get_combo_for_situation(
        self,
        job_class: str,
        situation: str,
        own_state: dict[str, Any],
    ) -> ComboChain | None:
        """Get combo for specific situation"""
        job_key = job_class.lower().replace(" ", "_")

        # Match job key
        if job_key not in self.combos:
            for key in self.combos.keys():
                if key in job_key or job_key in key:
                    job_key = key
                    break

        if situation == "burst":
            # Find highest damage combo
            combos = self.combos.get(job_key, [])
            valid = [c for c in combos if self._check_combo_requirements(c, own_state)]
            if valid:
                return max(valid, key=lambda c: c.total_damage)

        elif situation == "cc":
            # Find CC combo
            combos = self.combos.get(job_key, [])
            cc_combos = [
                c for c in combos
                if c.cc_type and self._check_combo_requirements(c, own_state)
            ]
            if cc_combos:
                return cc_combos[0]

        elif situation == "defensive":
            # Return defensive combo
            combos = self.defensive_combos.get(job_key, [])
            if combos:
                return combos[0]

        elif situation == "escape":
            # Quick escape combo
            combos = self.defensive_combos.get(job_key, [])
            if combos:
                # Prefer fast combos for escape
                fast = [c for c in combos if c.total_cast_time_ms < 2000]
                if fast:
                    return fast[0]
                return combos[0]

        return None

    def clear_expired_cooldowns(self) -> None:
        """Remove expired cooldowns"""
        now = datetime.now()
        expired = [skill for skill, expiry in self.cooldowns.items() if now >= expiry]

        for skill in expired:
            del self.cooldowns[skill]

    def get_tactics_status(self) -> dict[str, Any]:
        """Get current tactics status"""
        return {
            "active_burst_window": (
                self.active_burst_window.window_id
                if self.active_burst_window
                else None
            ),
            "cooldowns_count": len(self.cooldowns),
            "last_combo": (
                self.last_combo_time.isoformat()
                if self.last_combo_time
                else None
            ),
            "last_cc": (
                self.last_cc_time.isoformat()
                if self.last_cc_time
                else None
            ),
        }