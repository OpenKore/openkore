"""
Job Test Configuration Module.

Contains configurable parameters for job advancement tests,
supporting server-specific variations and customization.
"""

from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class JobTestType(str, Enum):
    """Types of job advancement tests in Ragnarok Online."""
    
    HUNTING_QUEST = "hunting_quest"
    ITEM_QUEST = "item_quest"
    MUSHROOM_QUEST = "mushroom_quest"
    UNDEAD_QUEST = "undead_quest"
    COMBAT_TEST = "combat_test"
    MAGIC_QUIZ = "magic_quiz"
    TRAP_MAZE = "trap_maze"


class HuntingTestConfig(BaseModel):
    """Configuration for hunting-type job tests."""
    
    # Default spawn maps for common monster types
    monster_spawn_maps: dict[str, list[str]] = Field(
        default_factory=lambda: {
            "poring": ["prt_fild01", "prt_fild02", "prt_fild08"],
            "fabre": ["prt_fild01", "prt_fild03", "prt_fild04"],
            "lunatic": ["prt_fild01", "prt_fild02", "prt_fild06"],
            "willow": ["prt_fild01", "prt_fild04", "prt_fild05"],
            "chonchon": ["prt_fild02", "prt_fild03", "mjolnir_01"],
            "roda_frog": ["prt_fild02", "prt_fild04", "prt_fild05"],
            "thief_bug": ["prt_sewb1", "prt_sewb2", "prt_sewb3"],
            "zombie": ["pay_fild08", "pay_fild07", "prt_maze01"],
            "skeleton": ["pay_fild08", "pay_fild07", "moc_pryd01"],
            "spore": ["pay_fild02", "pay_fild03", "pay_fild04"],
            "wolf": ["pay_fild07", "pay_fild04", "mjolnir_02"],
        },
        description="Monster type to spawn map mapping"
    )
    
    # Monster name aliases for fuzzy matching
    monster_aliases: dict[str, str] = Field(
        default_factory=lambda: {
            "poring": "poring",
            "pink_poring": "poring",
            "green_poring": "drops",
            "drops": "drops",
            "zombie": "zombie",
            "undead": "zombie",
            "skeleton": "skeleton",
            "archer_skeleton": "archer_skeleton",
        },
        description="Monster name aliases"
    )
    
    # Maximum hunt range from character position
    max_hunt_range: int = Field(default=15, description="Max cells to hunt from position")
    
    # Minimum kills before returning to NPC
    min_kills_per_trip: int = Field(default=5, description="Min kills before NPC return")


class ItemTestConfig(BaseModel):
    """Configuration for item collection job tests."""
    
    # Item drop sources (item_id -> [monster_ids])
    item_drop_sources: dict[int, list[int]] = Field(
        default_factory=lambda: {
            # Common quest items
            909: [1002],      # Jellopium from Poring
            914: [1002, 1113], # Sticky Mucus from Poring, Drops
            938: [1007],      # Chonchon Wings from Chonchon
            939: [1014],      # Worm Peeling from Fabre
            940: [1049],      # Hornet Sting from Hornet
            941: [1010],      # Willow Bark from Willow
            943: [1011],      # Shell from Thief Bug
            944: [1033],      # Bat Teeth from Familiar
            990: [1016],      # Red Herb (buyable, also drops)
            991: [1016],      # Yellow Herb
        },
        description="Item ID to monster ID drop mapping"
    )
    
    # Item purchase locations (item_id -> npc_map)
    purchasable_items: dict[int, str] = Field(
        default_factory=lambda: {
            501: "prontera",  # Red Potion
            502: "prontera",  # Orange Potion
            503: "prontera",  # Yellow Potion
            601: "prontera",  # Wing of Fly
            602: "prontera",  # Wing of Butterfly
            990: "prontera",  # Red Herb
        },
        description="Item ID to purchasable shop map"
    )
    
    # Max farming iterations before timeout
    max_farm_iterations: int = Field(default=100, description="Max farming attempts")


class MushroomTestConfig(BaseModel):
    """Configuration for Thief mushroom collection test."""
    
    # Mushroom spawn locations in test maze
    mushroom_spawn_points: list[tuple[int, int]] = Field(
        default_factory=lambda: [
            (35, 66), (41, 71), (48, 65), (55, 60),
            (62, 55), (70, 50), (78, 45), (85, 40),
            (92, 35), (99, 30), (106, 25), (113, 20),
        ],
        description="Mushroom spawn coordinates in job_thief1"
    )
    
    # Safe waypoints to navigate maze
    safe_waypoints: list[tuple[int, int]] = Field(
        default_factory=lambda: [
            (30, 60), (45, 65), (60, 55), (75, 45),
            (90, 35), (105, 25), (120, 20),
        ],
        description="Safe navigation waypoints"
    )
    
    # NPC return location
    npc_return_coords: tuple[int, int] = Field(
        default=(25, 55),
        description="Coordinates to return mushrooms to NPC"
    )
    
    # Maze map name
    maze_map: str = Field(default="job_thief1", description="Thief test map")
    
    # Required mushroom count
    required_mushrooms: int = Field(default=6, description="Mushrooms needed")


class UndeadTestConfig(BaseModel):
    """Configuration for Acolyte undead elimination test."""
    
    # Undead monster IDs by race
    undead_monster_ids: list[int] = Field(
        default_factory=lambda: [
            1015,  # Zombie
            1028,  # Skeleton
            1029,  # Skeleton Soldier
            1030,  # Poison Spore (undead element)
            1035,  # Hunter Fly
            1036,  # Zombie Prisoner
            1041,  # Mummy
            1042,  # Skeleton Prisoner
            1060,  # Ghoul
            1076,  # Skeleton Worker
        ],
        description="Monster IDs classified as undead"
    )
    
    # Best hunting maps for undead
    undead_hunting_maps: list[str] = Field(
        default_factory=lambda: [
            "pay_fild08",
            "pay_fild07",
            "prt_maze01",
            "moc_pryd01",
            "moc_pryd02",
            "gef_dun00",
            "gef_dun01",
        ],
        description="Maps with undead spawns"
    )
    
    # Default kill requirement
    default_kill_count: int = Field(default=10, description="Default undead kills needed")
    
    # Holy element skill IDs
    holy_skill_ids: list[int] = Field(
        default_factory=lambda: [
            28,   # Heal (can damage undead)
            30,   # Holy Light
            66,   # Turn Undead
            67,   # Magnus Exorcismus
            79,   # Gloria
            156,  # Sanctuary
        ],
        description="Holy element skill IDs"
    )


class CombatTestConfig(BaseModel):
    """Configuration for combat skill tests (Knight, etc.)."""
    
    # Instance map configurations
    instance_maps: dict[str, dict[str, Any]] = Field(
        default_factory=lambda: {
            "job_knight": {
                "stages": 3,
                "time_limit": 300,
                "spawn_waves": [
                    {"monster_id": 1015, "count": 5},
                    {"monster_id": 1028, "count": 5},
                    {"monster_id": 1029, "count": 3},
                ],
            },
            "job_crusader": {
                "stages": 3,
                "time_limit": 300,
                "spawn_waves": [
                    {"monster_id": 1015, "count": 5},
                    {"monster_id": 1041, "count": 3},
                    {"monster_id": 1060, "count": 2},
                ],
            },
            "job_assassin": {
                "stages": 3,
                "time_limit": 180,
                "spawn_waves": [
                    {"monster_id": 1002, "count": 10},
                    {"monster_id": 1007, "count": 8},
                    {"monster_id": 1033, "count": 5},
                ],
            },
        },
        description="Instance configuration by job"
    )
    
    # HP threshold for using consumables
    consumable_hp_threshold: float = Field(
        default=0.4,
        description="HP % threshold to use potions"
    )
    
    # Max retry attempts
    max_retries: int = Field(default=3, description="Max test retry attempts")


class QuizTestConfig(BaseModel):
    """Configuration for magic/knowledge quiz tests."""
    
    # Fuzzy match threshold (0-1)
    match_threshold: float = Field(
        default=0.7,
        description="Minimum similarity for fuzzy matching"
    )
    
    # Default answer when no match found
    default_answer_index: int = Field(
        default=0,
        description="Default choice index when unsure"
    )
    
    # Quiz type to database mapping is in job_test_data.py


class MazeTestConfig(BaseModel):
    """Configuration for trap/maze navigation tests."""
    
    # Maze configurations by job
    maze_configs: dict[str, dict[str, Any]] = Field(
        default_factory=lambda: {
            "job_hunter": {
                "width": 100,
                "height": 100,
                "entry": (10, 10),
                "goal": (90, 90),
                "trap_tiles": [(45, 45), (50, 50), (55, 55), (60, 60)],
                "warp_tiles": [(30, 30), (70, 70)],
            },
            "job_dancer": {
                "width": 80,
                "height": 80,
                "entry": (5, 5),
                "goal": (75, 75),
                "trap_tiles": [(40, 40), (50, 40), (40, 50)],
                "warp_tiles": [],
            },
            "job_bard": {
                "width": 80,
                "height": 80,
                "entry": (5, 5),
                "goal": (75, 75),
                "trap_tiles": [(40, 40), (50, 40), (40, 50)],
                "warp_tiles": [],
            },
        },
        description="Maze configuration by job type"
    )
    
    # Movement speed in maze (slower = safer)
    maze_move_delay: float = Field(
        default=0.5,
        description="Delay between movements in seconds"
    )
    
    # Goal proximity threshold
    goal_threshold: int = Field(
        default=3,
        description="Cells from goal to consider complete"
    )


class JobTestConfiguration(BaseModel):
    """Master configuration for all job tests."""
    
    hunting: HuntingTestConfig = Field(default_factory=HuntingTestConfig)
    item: ItemTestConfig = Field(default_factory=ItemTestConfig)
    mushroom: MushroomTestConfig = Field(default_factory=MushroomTestConfig)
    undead: UndeadTestConfig = Field(default_factory=UndeadTestConfig)
    combat: CombatTestConfig = Field(default_factory=CombatTestConfig)
    quiz: QuizTestConfig = Field(default_factory=QuizTestConfig)
    maze: MazeTestConfig = Field(default_factory=MazeTestConfig)
    
    # Global settings
    verbose_logging: bool = Field(
        default=True,
        description="Enable verbose test logging"
    )
    
    # Server-specific overrides
    server_name: str = Field(
        default="default",
        description="Server name for specific configs"
    )


# Singleton configuration instance
_config: JobTestConfiguration | None = None


def get_job_test_config() -> JobTestConfiguration:
    """Get or create job test configuration singleton."""
    global _config
    if _config is None:
        _config = JobTestConfiguration()
    return _config


def set_job_test_config(config: JobTestConfiguration) -> None:
    """Set job test configuration."""
    global _config
    _config = config