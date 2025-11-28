"""
War of Emperium system - Castle siege management and strategy.

Supports all WoE editions:
- First Edition (FE): Classic castle defense with Emperium
- Second Edition (SE): Guardian stones and barricades
- Training Edition (TE): Limited participants
"""

import json
from datetime import datetime, time
from enum import Enum
from pathlib import Path
from typing import Any

import structlog
from pydantic import BaseModel, Field


class WoEEdition(str, Enum):
    """WoE Editions"""

    FIRST_EDITION = "fe"
    SECOND_EDITION = "se"
    TRAINING_EDITION = "te"


class CastleOwnership(str, Enum):
    """Castle ownership status"""

    UNOWNED = "unowned"
    OWNED_BY_US = "owned_by_us"
    OWNED_BY_ALLY = "owned_by_ally"
    OWNED_BY_ENEMY = "owned_by_enemy"


class WoERole(str, Enum):
    """Roles in WoE"""

    EMPERIUM_BREAKER = "emp_breaker"
    DEFENDER = "defender"
    LINKER = "linker"
    TANK = "tank"
    HEALER = "healer"
    DPS = "dps"
    SCOUT = "scout"


class GuardianStone(BaseModel):
    """Guardian Stone status (WoE SE)"""

    stone_id: int
    position: tuple[int, int]
    is_destroyed: bool = False
    destroyed_at: datetime | None = None
    current_hp: int = 0
    max_hp: int = 50000


class Barricade(BaseModel):
    """Barricade status (WoE SE)"""

    barricade_id: int
    position: tuple[int, int]
    is_destroyed: bool = False
    current_hp: int = 0
    max_hp: int = 150000


class Castle(BaseModel):
    """Castle information"""

    castle_id: str
    castle_name: str
    map_name: str
    realm: str
    edition: WoEEdition = WoEEdition.FIRST_EDITION

    # Ownership
    owning_guild: str | None = None
    ownership_status: CastleOwnership = CastleOwnership.UNOWNED

    # Defenses (SE)
    guardian_stones: list[GuardianStone] = Field(default_factory=list)
    barricades: list[Barricade] = Field(default_factory=list)

    # Emperium/spawn
    emperium_position: tuple[int, int] = (0, 0)
    spawn_position: tuple[int, int] = (0, 0)
    emperium_room_accessible: bool = True

    # Metadata
    difficulty: int = 5
    treasure_spawn_rate: float = 0.25


class WoESchedule(BaseModel):
    """WoE schedule"""

    day_of_week: int  # 0=Monday, 6=Sunday
    start_hour: int
    start_minute: int
    duration_minutes: int
    edition: WoEEdition
    castles: list[str]
    description: str = ""


class WoEManager:
    """
    Manage War of Emperium strategies and coordination.

    Features:
    - Castle target selection
    - Route planning to emperium
    - Defense coordination
    - Guardian stone management (SE)
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.castles: dict[str, Castle] = {}
        self.schedule: list[WoESchedule] = []
        self.current_role: WoERole = WoERole.DPS
        self.target_castle: str | None = None
        self.woe_active: bool = False
        self.current_edition: WoEEdition | None = None

        self._load_castle_data(data_dir)
        self._load_schedule(data_dir)

    def _load_castle_data(self, data_dir: Path) -> None:
        """Load castle data from config"""
        castle_file = data_dir / "castles.json"

        try:
            with open(castle_file, encoding="utf-8") as f:
                data = json.load(f)

            # Load FE castles
            for realm, castles in data.get("first_edition", {}).items():
                for castle_name, castle_data in castles.items():
                    castle = Castle(
                        castle_id=f"fe_{realm}_{castle_name}",
                        castle_name=castle_name,
                        map_name=castle_data.get("map", ""),
                        realm=castle_data.get("realm", realm),
                        edition=WoEEdition.FIRST_EDITION,
                        emperium_position=tuple(castle_data.get("emperium", [0, 0])),
                        spawn_position=tuple(castle_data.get("spawn", [0, 0])),
                        difficulty=castle_data.get("difficulty", 5),
                    )
                    self.castles[castle.castle_id] = castle

            # Load SE castles
            for realm, castles in data.get("second_edition", {}).items():
                for castle_name, castle_data in castles.items():
                    stones = [
                        GuardianStone(
                            stone_id=s.get("id", i),
                            position=tuple(s.get("position", [0, 0])),
                            max_hp=s.get("max_hp", 50000),
                        )
                        for i, s in enumerate(castle_data.get("stones", []))
                    ]

                    barricades = [
                        Barricade(
                            barricade_id=b.get("id", i),
                            position=tuple(b.get("position", [0, 0])),
                            max_hp=b.get("max_hp", 150000),
                        )
                        for i, b in enumerate(castle_data.get("barricades", []))
                    ]

                    castle = Castle(
                        castle_id=f"se_{realm}_{castle_name}",
                        castle_name=castle_name,
                        map_name=castle_data.get("map", ""),
                        realm=castle_data.get("realm", realm),
                        edition=WoEEdition.SECOND_EDITION,
                        spawn_position=tuple(castle_data.get("spawn", [0, 0])),
                        guardian_stones=stones,
                        barricades=barricades,
                        difficulty=castle_data.get("difficulty", 8),
                    )
                    self.castles[castle.castle_id] = castle

            # Load TE castles
            for castle_name, castle_data in data.get("training_edition", {}).items():
                castle = Castle(
                    castle_id=f"te_{castle_name}",
                    castle_name=castle_name,
                    map_name=castle_data.get("map", ""),
                    realm=castle_data.get("realm", "training"),
                    edition=WoEEdition.TRAINING_EDITION,
                    emperium_position=tuple(castle_data.get("emperium", [0, 0])),
                    spawn_position=tuple(castle_data.get("spawn", [0, 0])),
                    difficulty=castle_data.get("difficulty", 5),
                )
                self.castles[castle.castle_id] = castle

            self.log.info("Castle data loaded", castle_count=len(self.castles))

        except Exception as e:
            self.log.error("Failed to load castle data", error=str(e))

    def _load_schedule(self, data_dir: Path) -> None:
        """Load WoE schedule from config"""
        schedule_file = data_dir / "woe_schedule.json"

        try:
            with open(schedule_file, encoding="utf-8") as f:
                data = json.load(f)

            for sched_data in data.get("schedules", []):
                schedule = WoESchedule(
                    day_of_week=sched_data.get("day_of_week", 0),
                    start_hour=sched_data.get("start_hour", 20),
                    start_minute=sched_data.get("start_minute", 0),
                    duration_minutes=sched_data.get("duration_minutes", 120),
                    edition=WoEEdition(sched_data.get("edition", "fe")),
                    castles=sched_data.get("castles", []),
                    description=sched_data.get("description", ""),
                )
                self.schedule.append(schedule)

            self.log.info("WoE schedule loaded", schedule_count=len(self.schedule))

        except Exception as e:
            self.log.error("Failed to load WoE schedule", error=str(e))

    def get_woe_schedule(self, day: int) -> list[WoESchedule]:
        """Get WoE schedule for a specific day"""
        return [s for s in self.schedule if s.day_of_week == day]

    def is_woe_active(self) -> tuple[bool, WoEEdition | None]:
        """Check if WoE is currently active"""
        now = datetime.now()
        current_time = time(now.hour, now.minute)
        day_of_week = now.weekday()

        for schedule in self.get_woe_schedule(day_of_week):
            start = time(schedule.start_hour, schedule.start_minute)
            end_minutes = (
                schedule.start_hour * 60
                + schedule.start_minute
                + schedule.duration_minutes
            )
            end = time(end_minutes // 60, end_minutes % 60)

            if start <= current_time <= end:
                return True, schedule.edition

        return False, None

    async def select_target_castle(
        self, guild_members: list[dict[str, Any]], enemy_guilds: list[dict[str, Any]]
    ) -> str | None:
        """Select which castle to attack based on guild strength and strategic value"""
        if not self.woe_active or not self.current_edition:
            return None

        # Get castles for current edition
        available_castles = [
            c
            for c in self.castles.values()
            if c.edition == self.current_edition
            and c.ownership_status != CastleOwnership.OWNED_BY_US
        ]

        if not available_castles:
            return None

        # Score castles
        scored_castles = []
        for castle in available_castles:
            score = self._score_castle_target(castle, guild_members, enemy_guilds)
            scored_castles.append((castle, score))

        # Return highest scored castle
        if scored_castles:
            best_castle = max(scored_castles, key=lambda x: x[1])[0]
            self.target_castle = best_castle.castle_id
            return best_castle.castle_id

        return None

    def _score_castle_target(
        self,
        castle: Castle,
        guild_members: list[dict[str, Any]],
        enemy_guilds: list[dict[str, Any]],
    ) -> float:
        """Score castle as attack target"""
        score = 100.0

        # Prefer unowned castles
        if castle.ownership_status == CastleOwnership.UNOWNED:
            score += 30.0
        elif castle.ownership_status == CastleOwnership.OWNED_BY_ENEMY:
            score += 10.0

        # Prefer easier castles
        score -= castle.difficulty * 5.0

        # Consider guild strength
        member_count = len(guild_members)
        if member_count < 10 and castle.difficulty > 7:
            score -= 50.0  # Avoid hard castles with small guild

        return score

    async def calculate_attack_route(
        self, castle: Castle, current_position: tuple[int, int]
    ) -> list[tuple[int, int]]:
        """Calculate optimal route to emperium"""
        # Simple pathfinding: direct line for now
        # Full implementation would use A* with map data
        if castle.edition == WoEEdition.SECOND_EDITION:
            # SE: route through guardian stones first
            route = []
            for stone in castle.guardian_stones:
                if not stone.is_destroyed:
                    route.append(stone.position)
            # Then to spawn (emperium room in SE)
            route.append(castle.spawn_position)
            return route
        else:
            # FE/TE: direct to emperium
            return [castle.emperium_position]

    async def get_defense_positions(
        self, castle: Castle, role: WoERole
    ) -> list[tuple[int, int]]:
        """Get defensive positions based on role"""
        if castle.edition == WoEEdition.SECOND_EDITION:
            # SE defense: around guardian stones
            if role == WoERole.DEFENDER:
                return [s.position for s in castle.guardian_stones if not s.is_destroyed]
        else:
            # FE/TE defense: around emperium
            emp_x, emp_y = castle.emperium_position
            if role == WoERole.DEFENDER or role == WoERole.TANK:
                # Front line positions
                return [(emp_x - 3, emp_y), (emp_x + 3, emp_y), (emp_x, emp_y - 3)]
            elif role == WoERole.HEALER:
                # Back line position
                return [(emp_x, emp_y + 5)]

        return [castle.emperium_position]

    async def should_attack_guardian_stone(
        self, stone: GuardianStone, enemies_nearby: int
    ) -> bool:
        """Determine if we should attack a guardian stone"""
        if stone.is_destroyed:
            return False

        # Don't attack stones if heavily defended
        if enemies_nearby > 5:
            return False

        # Attack if accessible
        return True

    async def get_emperium_break_strategy(
        self, castle: Castle, own_state: dict[str, Any]
    ) -> dict[str, Any]:
        """Get strategy for breaking emperium"""
        job_class = own_state.get("job_class", "").lower()

        strategy = {
            "target": "emperium",
            "position": castle.emperium_position,
            "skills": [],
            "items": [],
        }

        # Job-specific emp break strategies
        if "champion" in job_class:
            strategy["skills"] = ["Asura Strike"]
        elif "guillotine" in job_class or "assassin" in job_class:
            strategy["skills"] = ["Soul Destroyer", "Sonic Blow"]
        elif "lord_knight" in job_class or "rune_knight" in job_class:
            strategy["skills"] = ["Bowling Bash", "Hundred Spear"]
        else:
            strategy["skills"] = ["Attack"]

        # Consumables
        strategy["items"] = ["Awakening Potion", "Berserk Potion"]

        return strategy

    async def coordinate_with_guild(self, action: str, data: dict[str, Any]) -> None:
        """Coordinate actions with guild members"""
        self.log.info("Guild coordination", action=action, data=data)
        # Implementation would send commands via guild chat or coordination system

    def get_castle_status(self, castle_name: str) -> Castle | None:
        """Get current castle status"""
        return self.castles.get(castle_name)

    async def handle_woe_start(self, edition: WoEEdition) -> None:
        """Handle WoE start event"""
        self.woe_active = True
        self.current_edition = edition
        self.log.info("WoE started", edition=edition.value)

        # Reset castle defenses
        for castle in self.castles.values():
            if castle.edition == edition:
                for stone in castle.guardian_stones:
                    stone.is_destroyed = False
                    stone.current_hp = stone.max_hp
                for barricade in castle.barricades:
                    barricade.is_destroyed = False
                    barricade.current_hp = barricade.max_hp

    async def handle_woe_end(self) -> None:
        """Handle WoE end event"""
        self.woe_active = False
        self.current_edition = None
        self.target_castle = None
        self.log.info("WoE ended")

    def update_castle_ownership(
        self, castle_id: str, owning_guild: str | None, our_guild: str | None
    ) -> None:
        """Update castle ownership"""
        if castle_id not in self.castles:
            return

        castle = self.castles[castle_id]
        castle.owning_guild = owning_guild

        if owning_guild is None:
            castle.ownership_status = CastleOwnership.UNOWNED
        elif owning_guild == our_guild:
            castle.ownership_status = CastleOwnership.OWNED_BY_US
        else:
            castle.ownership_status = CastleOwnership.OWNED_BY_ENEMY

    def update_guardian_stone(
        self, castle_id: str, stone_id: int, is_destroyed: bool
    ) -> None:
        """Update guardian stone status"""
        if castle_id not in self.castles:
            return

        castle = self.castles[castle_id]
        for stone in castle.guardian_stones:
            if stone.stone_id == stone_id:
                stone.is_destroyed = is_destroyed
                if is_destroyed:
                    stone.destroyed_at = datetime.now()
                    stone.current_hp = 0
                break

    def set_role(self, role: WoERole) -> None:
        """Set our WoE role"""
        self.current_role = role
        self.log.info("WoE role set", role=role.value)

    def get_woe_status(self) -> dict[str, Any]:
        """Get current WoE status"""
        return {
            "active": self.woe_active,
            "edition": self.current_edition.value if self.current_edition else None,
            "role": self.current_role.value,
            "target_castle": self.target_castle,
            "owned_castles": [
                c.castle_name
                for c in self.castles.values()
                if c.ownership_status == CastleOwnership.OWNED_BY_US
            ],
        }