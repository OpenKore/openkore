"""
Battlegrounds system - Competitive team-based PvP modes.

Supports all battleground modes:
- Tierra Canyon: Capture the Flag (CTF)
- Flavius: Team Deathmatch & CTF
- Krieger von Midgard (KVM): Fast-paced 5v5 domination
- Eye of Storm: Conquest/Control Points
- Conquest: Extended control point warfare
"""

import json
import math
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, Field


class BattlegroundMode(str, Enum):
    """Battleground game modes"""

    TIERRA = "tierra"
    FLAVIUS_TD = "flavius_td"
    FLAVIUS_CTF = "flavius_ctf"
    KVM = "kvm"
    EYE_OF_STORM = "eos"
    CONQUEST = "conquest"


class BGObjective(str, Enum):
    """Battleground objective types"""

    CAPTURE_FLAG = "capture_flag"
    TEAM_DEATHMATCH = "team_deathmatch"
    DOMINATION = "domination"
    CONQUEST = "conquest"


class BGTeam(str, Enum):
    """Battleground teams"""

    GUILLAUME = "guillaume"
    CROIX = "croix"
    NEUTRAL = "neutral"


class BGMatchState(str, Enum):
    """Match state"""

    WAITING = "waiting"
    ACTIVE = "active"
    ENDING = "ending"
    FINISHED = "finished"


class BGPlayer(BaseModel):
    """Player in battleground"""

    player_id: int
    player_name: str
    team: BGTeam
    job_class: str
    kills: int = 0
    deaths: int = 0
    assists: int = 0
    score: int = 0
    has_flag: bool = False
    position: tuple[int, int] = (0, 0)


class ControlPoint(BaseModel):
    """Control point for conquest modes"""

    point_id: str
    position: tuple[int, int]
    name: str
    importance: int = 5
    controlled_by: BGTeam = BGTeam.NEUTRAL
    capture_progress: float = 0.0
    defenders: int = 0


class BGFlag(BaseModel):
    """Flag for CTF modes"""

    flag_id: str
    team: BGTeam
    home_position: tuple[int, int]
    current_position: tuple[int, int]
    carrier_id: int | None = None
    is_at_base: bool = True
    dropped_at: datetime | None = None


class BGMatchConfig(BaseModel):
    """Battleground match configuration"""

    mode_id: str
    full_name: str
    objective: BGObjective
    team_size: int
    duration_minutes: int
    score_to_win: int
    map_name: str
    spawn_positions: dict[str, list[int]]
    flag_positions: dict[str, list[int]] = Field(default_factory=dict)
    control_points: list[dict[str, Any]] = Field(default_factory=list)
    strategic_points: list[dict[str, Any]] = Field(default_factory=list)
    rewards: dict[str, int] = Field(default_factory=dict)


class BattlegroundManager:
    """
    Manage battleground matches and strategies.

    Features:
    - Join queue and match management
    - Objective prioritization
    - Flag routes for CTF
    - Control point strategies
    - Attack/defense decisions
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.configs: dict[BattlegroundMode, BGMatchConfig] = {}
        self.current_match: BGMatchConfig | None = None
        self.current_mode: BattlegroundMode | None = None
        self.match_state: BGMatchState = BGMatchState.WAITING
        self.own_team: BGTeam = BGTeam.GUILLAUME
        self.players: dict[int, BGPlayer] = {}
        self.flags: dict[str, BGFlag] = {}
        self.control_points: dict[str, ControlPoint] = {}
        self.team_scores: dict[BGTeam, int] = {
            BGTeam.GUILLAUME: 0,
            BGTeam.CROIX: 0,
        }
        self.match_start_time: datetime | None = None

        self._load_configs(data_dir)

    def _load_configs(self, data_dir: Path) -> None:
        """Load battleground configurations"""
        config_file = data_dir / "battleground_configs.json"

        try:
            with open(config_file, encoding="utf-8") as f:
                data = json.load(f)

            for mode_key, mode_data in data.get("modes", {}).items():
                try:
                    mode = BattlegroundMode(mode_key)
                    config = BGMatchConfig(
                        mode_id=mode_data.get("mode_id", mode_key),
                        full_name=mode_data.get("full_name", mode_key),
                        objective=BGObjective(mode_data.get("objective", "team_deathmatch")),
                        team_size=mode_data.get("team_size", 10),
                        duration_minutes=mode_data.get("duration_minutes", 20),
                        score_to_win=mode_data.get("score_to_win", 100),
                        map_name=mode_data.get("map", "bat_a01"),
                        spawn_positions=mode_data.get("spawn_positions", {}),
                        flag_positions=mode_data.get("flag_positions", {}),
                        control_points=mode_data.get("control_points", []),
                        strategic_points=mode_data.get("strategic_points", []),
                        rewards=mode_data.get("rewards", {}),
                    )
                    self.configs[mode] = config
                except (ValueError, KeyError) as e:
                    self.log.warning("Invalid BG mode config", mode=mode_key, error=str(e))

            self.log.info("Battleground configs loaded", count=len(self.configs))

        except Exception as e:
            self.log.error("Failed to load BG configs", error=str(e))

    async def join_battleground(self, mode: BattlegroundMode, team: BGTeam) -> bool:
        """Join a battleground queue"""
        if mode not in self.configs:
            self.log.error("Unknown BG mode", mode=mode.value)
            return False

        self.current_mode = mode
        self.current_match = self.configs[mode]
        self.own_team = team
        self.match_state = BGMatchState.WAITING

        self.log.info(
            "Joined BG queue",
            mode=mode.value,
            team=team.value,
            config=self.current_match.full_name,
        )

        return True

    async def start_match(self, player_id: int, player_name: str, job_class: str) -> None:
        """Handle match start"""
        if not self.current_match:
            return

        self.match_state = BGMatchState.ACTIVE
        self.match_start_time = datetime.now()
        self.team_scores = {BGTeam.GUILLAUME: 0, BGTeam.CROIX: 0}

        # Add self as player
        self.players[player_id] = BGPlayer(
            player_id=player_id,
            player_name=player_name,
            team=self.own_team,
            job_class=job_class,
        )

        # Initialize flags for CTF modes
        if self.current_match.objective == BGObjective.CAPTURE_FLAG:
            for team_name, pos in self.current_match.flag_positions.items():
                team = BGTeam(team_name)
                flag = BGFlag(
                    flag_id=f"flag_{team_name}",
                    team=team,
                    home_position=tuple(pos),
                    current_position=tuple(pos),
                )
                self.flags[flag.flag_id] = flag

        # Initialize control points for conquest modes
        if self.current_match.objective in [BGObjective.DOMINATION, BGObjective.CONQUEST]:
            for i, cp_data in enumerate(self.current_match.control_points):
                cp = ControlPoint(
                    point_id=f"cp_{i}",
                    position=tuple(cp_data.get("position", [0, 0])),
                    name=cp_data.get("name", f"Point {i+1}"),
                    importance=cp_data.get("importance", 5),
                )
                self.control_points[cp.point_id] = cp

        self.log.info("BG match started", mode=self.current_mode, team=self.own_team)

    async def get_current_objective(
        self, own_position: tuple[int, int], own_state: dict[str, Any]
    ) -> dict[str, Any]:
        """Get current primary objective based on match state"""
        if not self.current_match or self.match_state != BGMatchState.ACTIVE:
            return {"action": "wait", "priority": 0}

        objective_type = self.current_match.objective

        if objective_type == BGObjective.CAPTURE_FLAG:
            return await self._get_ctf_objective(own_position, own_state)
        elif objective_type == BGObjective.TEAM_DEATHMATCH:
            return await self._get_tdm_objective(own_position)
        elif objective_type in [BGObjective.DOMINATION, BGObjective.CONQUEST]:
            return await self._get_conquest_objective(own_position)

        return {"action": "move_to_center", "priority": 5}

    async def _get_ctf_objective(
        self, own_position: tuple[int, int], own_state: dict[str, Any]
    ) -> dict[str, Any]:
        """Get CTF-specific objective"""
        # Check if we have flag
        player_id = own_state.get("player_id", 0)
        if player_id in self.players and self.players[player_id].has_flag:
            # Return flag to base
            base_pos = self.current_match.spawn_positions.get(self.own_team.value, [0, 0])
            return {
                "action": "return_flag",
                "target_position": tuple(base_pos),
                "priority": 10,
            }

        # Find enemy flag
        enemy_team = BGTeam.CROIX if self.own_team == BGTeam.GUILLAUME else BGTeam.GUILLAUME
        enemy_flag = self.flags.get(f"flag_{enemy_team.value}")

        if enemy_flag:
            if enemy_flag.carrier_id and enemy_flag.carrier_id in self.players:
                # Chase flag carrier
                carrier = self.players[enemy_flag.carrier_id]
                return {
                    "action": "chase_carrier",
                    "target_player_id": enemy_flag.carrier_id,
                    "target_position": carrier.position,
                    "priority": 9,
                }
            elif not enemy_flag.is_at_base:
                # Pick up dropped flag
                return {
                    "action": "pickup_flag",
                    "target_position": enemy_flag.current_position,
                    "priority": 8,
                }
            else:
                # Capture enemy flag
                return {
                    "action": "capture_flag",
                    "target_position": enemy_flag.current_position,
                    "priority": 7,
                }

        return {"action": "defend_flag", "priority": 6}

    async def _get_tdm_objective(self, own_position: tuple[int, int]) -> dict[str, Any]:
        """Get Team Deathmatch objective"""
        # Find nearest enemy
        enemies = [p for p in self.players.values() if p.team != self.own_team]

        if enemies:
            nearest = min(
                enemies,
                key=lambda e: self._calculate_distance(own_position, e.position)
            )
            return {
                "action": "engage_enemy",
                "target_player_id": nearest.player_id,
                "target_position": nearest.position,
                "priority": 8,
            }

        # Move to strategic position
        if self.current_match.strategic_points:
            center = self.current_match.strategic_points[0]
            return {
                "action": "move_to_strategic",
                "target_position": tuple(center.get("position", [0, 0])),
                "priority": 5,
            }

        return {"action": "patrol", "priority": 3}

    async def _get_conquest_objective(self, own_position: tuple[int, int]) -> dict[str, Any]:
        """Get conquest/domination objective"""
        # Find best control point to capture
        priority_cp = await self.calculate_objective_priority(own_position)

        if priority_cp:
            cp = self.control_points[priority_cp]
            return {
                "action": "capture_point",
                "target_control_point": priority_cp,
                "target_position": cp.position,
                "priority": 8,
            }

        return {"action": "defend_points", "priority": 6}

    async def calculate_objective_priority(
        self, own_position: tuple[int, int]
    ) -> str | None:
        """Calculate which objective has highest priority"""
        if not self.control_points:
            return None

        scored_points = []
        for cp_id, cp in self.control_points.items():
            score = 0.0

            # Base importance
            score += cp.importance * 10.0

            # Prefer neutral or enemy points
            if cp.controlled_by == BGTeam.NEUTRAL:
                score += 30.0
            elif cp.controlled_by != self.own_team:
                score += 20.0
            else:
                score += 5.0  # Defend owned points

            # Distance penalty
            distance = self._calculate_distance(own_position, cp.position)
            score -= distance * 0.5

            # Fewer defenders = easier to cap
            if cp.defenders < 2:
                score += 15.0

            scored_points.append((cp_id, score))

        if scored_points:
            return max(scored_points, key=lambda x: x[1])[0]

        return None

    async def get_flag_route(
        self, from_position: tuple[int, int], to_position: tuple[int, int]
    ) -> list[tuple[int, int]]:
        """Calculate optimal flag carry route"""
        # Simple pathfinding: direct path with strategic waypoints
        route = [from_position]

        # Add strategic waypoints if available
        if self.current_match and self.current_match.strategic_points:
            for point in self.current_match.strategic_points:
                point_pos = tuple(point.get("position", [0, 0]))
                # Add point if it's roughly on the way
                if self._is_on_path(from_position, to_position, point_pos):
                    route.append(point_pos)

        route.append(to_position)
        return route

    def _is_on_path(
        self, start: tuple[int, int], end: tuple[int, int], point: tuple[int, int]
    ) -> bool:
        """Check if point is roughly on path between start and end"""
        # Calculate distances
        total_dist = self._calculate_distance(start, end)
        dist_to_point = self._calculate_distance(start, point)
        dist_from_point = self._calculate_distance(point, end)

        # Point is on path if detour is less than 30% of direct route
        detour = (dist_to_point + dist_from_point) - total_dist
        return detour < (total_dist * 0.3)

    async def should_defend_or_attack(
        self, own_state: dict[str, Any], team_composition: dict[str, int]
    ) -> str:
        """Decide whether to defend or attack"""
        if not self.current_match:
            return "attack"

        # Score differential
        own_score = self.team_scores.get(self.own_team, 0)
        enemy_team = BGTeam.CROIX if self.own_team == BGTeam.GUILLAUME else BGTeam.GUILLAUME
        enemy_score = self.team_scores.get(enemy_team, 0)
        score_diff = own_score - enemy_score

        # Job class consideration
        job_class = own_state.get("job_class", "").lower()
        is_defensive_class = any(
            role in job_class for role in ["priest", "archbishop", "tank", "royal_guard"]
        )

        # Winning and defensive class -> defend
        if score_diff > 10 and is_defensive_class:
            return "defend"

        # Losing badly -> all-out attack
        if score_diff < -20:
            return "attack"

        # CTF specific
        if self.current_match.objective == BGObjective.CAPTURE_FLAG:
            # Defend if enemy has our flag
            own_flag = self.flags.get(f"flag_{self.own_team.value}")
            if own_flag and not own_flag.is_at_base:
                return "defend"

        # Default based on class
        return "defend" if is_defensive_class else "attack"

    def update_player_position(
        self, player_id: int, position: tuple[int, int]
    ) -> None:
        """Update player position"""
        if player_id in self.players:
            self.players[player_id].position = position

    def update_flag_status(
        self,
        flag_id: str,
        position: tuple[int, int],
        carrier_id: int | None = None,
        is_at_base: bool = False,
    ) -> None:
        """Update flag status"""
        if flag_id in self.flags:
            flag = self.flags[flag_id]
            flag.current_position = position
            flag.carrier_id = carrier_id
            flag.is_at_base = is_at_base

            # Update player flag status
            for player in self.players.values():
                player.has_flag = player.player_id == carrier_id

    def update_control_point(
        self, point_id: str, controlled_by: BGTeam, defenders: int = 0
    ) -> None:
        """Update control point status"""
        if point_id in self.control_points:
            cp = self.control_points[point_id]
            cp.controlled_by = controlled_by
            cp.defenders = defenders

    def update_score(self, team: BGTeam, points: int) -> None:
        """Update team score"""
        self.team_scores[team] = points

    def add_player(self, player_data: dict[str, Any]) -> None:
        """Add player to match"""
        player_id = player_data.get("player_id", 0)
        self.players[player_id] = BGPlayer(
            player_id=player_id,
            player_name=player_data.get("name", "Unknown"),
            team=BGTeam(player_data.get("team", "guillaume")),
            job_class=player_data.get("job_class", "unknown"),
            position=tuple(player_data.get("position", [0, 0])),
        )

    def remove_player(self, player_id: int) -> None:
        """Remove player from match"""
        if player_id in self.players:
            del self.players[player_id]

    def _calculate_distance(
        self, pos1: tuple[int, int], pos2: tuple[int, int]
    ) -> float:
        """Calculate Euclidean distance"""
        return math.sqrt((pos1[0] - pos2[0]) ** 2 + (pos1[1] - pos2[1]) ** 2)

    async def end_match(self, winner: BGTeam) -> dict[str, Any]:
        """Handle match end"""
        self.match_state = BGMatchState.FINISHED

        rewards = {}
        if self.current_match:
            if winner == self.own_team:
                rewards = {
                    "badges": self.current_match.rewards.get("winner_badges", 0),
                    "result": "victory",
                }
            else:
                rewards = {
                    "badges": self.current_match.rewards.get("loser_badges", 0),
                    "result": "defeat",
                }

        self.log.info("BG match ended", winner=winner.value, rewards=rewards)

        # Reset state
        self.players.clear()
        self.flags.clear()
        self.control_points.clear()
        self.current_match = None
        self.current_mode = None

        return rewards

    def get_match_status(self) -> dict[str, Any]:
        """Get current match status"""
        return {
            "mode": self.current_mode.value if self.current_mode else None,
            "state": self.match_state.value,
            "team": self.own_team.value,
            "scores": {
                team.value: score for team, score in self.team_scores.items()
            },
            "players": len(self.players),
            "time_elapsed": (
                (datetime.now() - self.match_start_time).total_seconds()
                if self.match_start_time
                else 0
            ),
        }