"""
Comprehensive tests for Instance Navigator system.

Tests cover:
- Floor map loading and management
- Pathfinding algorithms (A*)
- Boss arena positioning
- Monster clearing routes
- Loot collection optimization
- Emergency exit routing
"""

import pytest
from unittest.mock import Mock, patch, AsyncMock
from typing import Tuple

from ai_sidecar.instances.navigator import (
    InstanceNavigator,
    FloorMap,
    MonsterPosition
)
from ai_sidecar.instances.strategy import BossStrategy


# Fixtures

@pytest.fixture
def navigator():
    """Create instance navigator."""
    return InstanceNavigator()


@pytest.fixture
def basic_floor_map():
    """Create basic floor map for testing."""
    return FloorMap(
        width=50,
        height=50,
        walkable_tiles=set((x, y) for x in range(10, 40) for y in range(10, 40)),
        boss_spawn_point=(25, 25),
        exit_portal=(15, 15),
        safe_zones=[(10, 10), (35, 35)],
        danger_zones=[(25, 30), (30, 25)]
    )


@pytest.fixture
def complex_floor_map():
    """Create complex floor map with obstacles."""
    walkable = set()
    # Create L-shaped walkable area
    for x in range(10, 30):
        for y in range(10, 20):
            walkable.add((x, y))
    for x in range(10, 20):
        for y in range(20, 40):
            walkable.add((x, y))
    
    return FloorMap(
        width=50,
        height=50,
        walkable_tiles=walkable,
        boss_spawn_point=(15, 35),
        exit_portal=(25, 15)
    )


@pytest.fixture
def sample_monsters():
    """Create sample monster positions."""
    return [
        MonsterPosition(
            monster_id=1,
            monster_name="Poring",
            position=(20, 20),
            is_boss=False,
            is_aggressive=False
        ),
        MonsterPosition(
            monster_id=2,
            monster_name="Drops",
            position=(22, 22),
            is_boss=False,
            is_aggressive=True
        ),
        MonsterPosition(
            monster_id=3,
            monster_name="Lunatic",
            position=(18, 24),
            is_boss=False,
            is_aggressive=False
        ),
        MonsterPosition(
            monster_id=4,
            monster_name="Boss",
            position=(25, 25),
            is_boss=True,
            is_aggressive=True
        )
    ]


# FloorMap Model Tests

class TestFloorMapModel:
    """Test FloorMap model."""
    
    def test_create_basic_floor_map(self):
        """Test creating basic floor map."""
        floor_map = FloorMap(
            width=100,
            height=100,
            walkable_tiles=set([(10, 10), (11, 10)]),
            boss_spawn_point=(50, 50)
        )
        
        assert floor_map.width == 100
        assert floor_map.height == 100
        assert (10, 10) in floor_map.walkable_tiles
        assert floor_map.boss_spawn_point == (50, 50)
    
    def test_floor_map_default_values(self):
        """Test floor map default values."""
        floor_map = FloorMap(width=50, height=50)
        
        assert floor_map.walkable_tiles == set()
        assert floor_map.boss_spawn_point is None
        assert floor_map.exit_portal is None
        assert floor_map.safe_zones == []
        assert floor_map.danger_zones == []
    
    def test_floor_map_with_safe_zones(self, basic_floor_map):
        """Test floor map with safe zones."""
        assert len(basic_floor_map.safe_zones) == 2
        assert (10, 10) in basic_floor_map.safe_zones
        assert (35, 35) in basic_floor_map.safe_zones
    
    def test_floor_map_width_validation(self):
        """Test floor map width must be positive."""
        with pytest.raises(Exception):
            FloorMap(width=0, height=50)
    
    def test_floor_map_height_validation(self):
        """Test floor map height must be positive."""
        with pytest.raises(Exception):
            FloorMap(width=50, height=0)


# MonsterPosition Model Tests

class TestMonsterPositionModel:
    """Test MonsterPosition model."""
    
    def test_create_basic_monster(self):
        """Test creating basic monster position."""
        monster = MonsterPosition(
            monster_id=1,
            monster_name="Poring",
            position=(10, 15)
        )
        
        assert monster.monster_id == 1
        assert monster.monster_name == "Poring"
        assert monster.position == (10, 15)
        assert monster.is_boss is False
        assert monster.is_aggressive is False
    
    def test_create_boss_monster(self):
        """Test creating boss monster."""
        boss = MonsterPosition(
            monster_id=100,
            monster_name="Baphomet",
            position=(50, 50),
            is_boss=True,
            is_aggressive=True
        )
        
        assert boss.is_boss is True
        assert boss.is_aggressive is True
    
    def test_create_aggressive_monster(self):
        """Test creating aggressive monster."""
        monster = MonsterPosition(
            monster_id=50,
            monster_name="Orc Warrior",
            position=(30, 30),
            is_aggressive=True
        )
        
        assert monster.is_aggressive is True
        assert monster.is_boss is False


# InstanceNavigator Tests

class TestInstanceNavigatorInit:
    """Test navigator initialization."""
    
    def test_navigator_initialization(self, navigator):
        """Test navigator initializes correctly."""
        assert navigator.floor_maps == {}
        assert navigator.path_cache == {}
    
    def test_navigator_has_logger(self, navigator):
        """Test navigator has logger."""
        assert navigator.log is not None


class TestLoadFloorMap:
    """Test floor map loading."""
    
    @pytest.mark.asyncio
    async def test_load_floor_map_creates_new(self, navigator):
        """Test loading creates new floor map."""
        floor_map = await navigator.load_floor_map("tower_1", 1)
        
        assert floor_map is not None
        assert floor_map.width == 100
        assert floor_map.height == 100
        assert floor_map.boss_spawn_point == (50, 50)
    
    @pytest.mark.asyncio
    async def test_load_floor_map_caches(self, navigator):
        """Test floor map is cached."""
        map1 = await navigator.load_floor_map("tower_1", 1)
        map2 = await navigator.load_floor_map("tower_1", 1)
        
        assert map1 is map2
    
    @pytest.mark.asyncio
    async def test_load_different_floors(self, navigator):
        """Test loading different floors."""
        map1 = await navigator.load_floor_map("tower_1", 1)
        map2 = await navigator.load_floor_map("tower_1", 2)
        
        assert map1 is not map2
    
    @pytest.mark.asyncio
    async def test_load_different_instances(self, navigator):
        """Test loading different instances."""
        map1 = await navigator.load_floor_map("tower_1", 1)
        map2 = await navigator.load_floor_map("tower_2", 1)
        
        assert "tower_1" in navigator.floor_maps
        assert "tower_2" in navigator.floor_maps


class TestGetRouteToBoss:
    """Test route to boss calculation."""
    
    @pytest.mark.asyncio
    async def test_route_to_boss_direct(self, navigator, basic_floor_map):
        """Test direct route to boss."""
        route = await navigator.get_route_to_boss(
            (15, 15),
            basic_floor_map
        )
        
        assert len(route) > 0
        assert route[-1] == basic_floor_map.boss_spawn_point
    
    @pytest.mark.asyncio
    async def test_route_to_boss_no_spawn(self, navigator):
        """Test route with no boss spawn point."""
        floor_map = FloorMap(width=50, height=50)
        route = await navigator.get_route_to_boss((15, 15), floor_map)
        
        assert route == []
    
    @pytest.mark.asyncio
    async def test_route_to_boss_from_adjacent(self, navigator, basic_floor_map):
        """Test route from adjacent position."""
        route = await navigator.get_route_to_boss(
            (24, 25),
            basic_floor_map
        )
        
        assert len(route) >= 1


class TestGetClearingRoute:
    """Test monster clearing route optimization."""
    
    @pytest.mark.asyncio
    async def test_clearing_route_empty(self, navigator, basic_floor_map):
        """Test clearing route with no monsters."""
        route = await navigator.get_clearing_route(
            (15, 15),
            basic_floor_map,
            []
        )
        
        assert route == []
    
    @pytest.mark.asyncio
    async def test_clearing_route_single_monster(self, navigator, basic_floor_map):
        """Test clearing route with single monster."""
        monsters = [
            MonsterPosition(
                monster_id=1,
                monster_name="Poring",
                position=(20, 20)
            )
        ]
        
        route = await navigator.get_clearing_route(
            (15, 15),
            basic_floor_map,
            monsters
        )
        
        assert len(route) == 1
        assert route[0] == (20, 20)
    
    @pytest.mark.asyncio
    async def test_clearing_route_multiple_monsters(self, navigator, basic_floor_map, sample_monsters):
        """Test clearing route with multiple monsters."""
        # Remove boss from list
        monsters = [m for m in sample_monsters if not m.is_boss]
        
        route = await navigator.get_clearing_route(
            (15, 15),
            basic_floor_map,
            monsters
        )
        
        assert len(route) == len(monsters)
        # Should visit all monster positions
        for monster in monsters:
            assert monster.position in route
    
    @pytest.mark.asyncio
    async def test_clearing_route_nearest_neighbor(self, navigator, basic_floor_map):
        """Test clearing uses nearest neighbor algorithm."""
        monsters = [
            MonsterPosition(monster_id=1, monster_name="M1", position=(20, 20)),
            MonsterPosition(monster_id=2, monster_name="M2", position=(21, 20)),
            MonsterPosition(monster_id=3, monster_name="M3", position=(30, 30))
        ]
        
        route = await navigator.get_clearing_route(
            (19, 20),
            basic_floor_map,
            monsters
        )
        
        # Should visit nearest first
        assert route[0] in [(20, 20), (21, 20)]


class TestGetSafePosition:
    """Test safe positioning during boss fights."""
    
    @pytest.mark.asyncio
    async def test_safe_position_melee(self, navigator):
        """Test safe position for melee strategy."""
        strategy = BossStrategy(
            boss_name="TestBoss",
            positioning="melee",
            safe_zones=[]
        )
        
        pos = await navigator.get_safe_position((25, 25), strategy)
        
        # Should be close to boss (distance 2)
        assert pos == (25, 27)
    
    @pytest.mark.asyncio
    async def test_safe_position_ranged(self, navigator):
        """Test safe position for ranged strategy."""
        strategy = BossStrategy(
            boss_name="TestBoss",
            positioning="ranged",
            safe_zones=[]
        )
        
        pos = await navigator.get_safe_position((25, 25), strategy)
        
        # Should be at range (distance 6)
        assert pos == (25, 31)
    
    @pytest.mark.asyncio
    async def test_safe_position_kite(self, navigator):
        """Test safe position for kiting strategy."""
        strategy = BossStrategy(
            boss_name="TestBoss",
            positioning="kite",
            safe_zones=[]
        )
        
        pos = await navigator.get_safe_position((25, 25), strategy)
        
        # Should be far (distance 9)
        assert pos == (25, 34)
    
    @pytest.mark.asyncio
    async def test_safe_position_predefined_zones(self, navigator):
        """Test with predefined safe zones."""
        strategy = BossStrategy(
            boss_name="TestBoss",
            positioning="melee",
            safe_zones=[(20, 20), (30, 30), (15, 15)]
        )
        
        pos = await navigator.get_safe_position((25, 25), strategy)
        
        # Should pick closest safe zone
        assert pos in strategy.safe_zones


class TestGetLootRoute:
    """Test loot collection route optimization."""
    
    @pytest.mark.asyncio
    async def test_loot_route_empty(self, navigator):
        """Test loot route with no items."""
        route = await navigator.get_loot_route((20, 20), [])
        
        assert route == []
    
    @pytest.mark.asyncio
    async def test_loot_route_single_item(self, navigator):
        """Test loot route with single item."""
        route = await navigator.get_loot_route((20, 20), [(25, 25)])
        
        assert len(route) == 1
        assert route[0] == (25, 25)
    
    @pytest.mark.asyncio
    async def test_loot_route_multiple_items(self, navigator):
        """Test loot route with multiple items."""
        loot_positions = [(20, 20), (25, 25), (30, 30)]
        route = await navigator.get_loot_route((18, 18), loot_positions)
        
        assert len(route) == 3
        # All loot positions should be visited
        for pos in loot_positions:
            assert pos in route
    
    @pytest.mark.asyncio
    async def test_loot_route_nearest_first(self, navigator):
        """Test loot route picks nearest first."""
        loot_positions = [(25, 25), (20, 20), (30, 30)]
        route = await navigator.get_loot_route((19, 19), loot_positions)
        
        # Nearest should be first
        assert route[0] == (20, 20)


class TestGetEmergencyExit:
    """Test emergency exit routing."""
    
    @pytest.mark.asyncio
    async def test_emergency_exit_path(self, navigator, basic_floor_map):
        """Test emergency exit finds path."""
        path = await navigator.get_emergency_exit((25, 25), basic_floor_map)
        
        assert len(path) > 0
        assert path[-1] == basic_floor_map.exit_portal
    
    @pytest.mark.asyncio
    async def test_emergency_exit_no_portal(self, navigator):
        """Test emergency exit with no exit portal."""
        floor_map = FloorMap(width=50, height=50)
        path = await navigator.get_emergency_exit((25, 25), floor_map)
        
        assert path == []
    
    @pytest.mark.asyncio
    async def test_emergency_exit_from_exit(self, navigator, basic_floor_map):
        """Test exit path from exit position."""
        path = await navigator.get_emergency_exit(
            basic_floor_map.exit_portal,
            basic_floor_map
        )
        
        # Should have trivial path
        assert len(path) >= 1


class TestPathfinding:
    """Test A* pathfinding algorithm."""
    
    @pytest.mark.asyncio
    async def test_find_path_direct(self, navigator, basic_floor_map):
        """Test finding direct path."""
        path = await navigator._find_path(
            (15, 15),
            (20, 20),
            basic_floor_map
        )
        
        assert len(path) > 0
        assert path[0] == (15, 15)
        assert path[-1] == (20, 20)
    
    @pytest.mark.asyncio
    async def test_find_path_cached(self, navigator, basic_floor_map):
        """Test path caching."""
        path1 = await navigator._find_path((15, 15), (20, 20), basic_floor_map)
        path2 = await navigator._find_path((15, 15), (20, 20), basic_floor_map)
        
        assert path1 == path2
        assert len(navigator.path_cache) > 0
    
    @pytest.mark.asyncio
    async def test_find_path_with_obstacles(self, navigator, complex_floor_map):
        """Test pathfinding around obstacles."""
        path = await navigator._find_path(
            (15, 15),
            (15, 35),
            complex_floor_map
        )
        
        assert len(path) > 0
        assert path[0] == (15, 15)
        assert path[-1] == (15, 35)
        
        # All positions should be walkable
        for pos in path:
            assert pos in complex_floor_map.walkable_tiles
    
    @pytest.mark.asyncio
    async def test_find_path_impossible(self, navigator):
        """Test pathfinding with impossible path."""
        floor_map = FloorMap(
            width=50,
            height=50,
            walkable_tiles=set([(10, 10), (30, 30)])  # Disconnected tiles
        )
        
        path = await navigator._find_path((10, 10), (30, 30), floor_map)
        
        assert path == []


class TestHelperMethods:
    """Test helper methods."""
    
    def test_manhattan_distance(self, navigator):
        """Test Manhattan distance calculation."""
        dist = navigator._manhattan_distance((0, 0), (3, 4))
        assert dist == 7
    
    def test_manhattan_distance_same_point(self, navigator):
        """Test Manhattan distance for same point."""
        dist = navigator._manhattan_distance((5, 5), (5, 5))
        assert dist == 0
    
    def test_manhattan_distance_negative(self, navigator):
        """Test Manhattan distance with negative coords."""
        dist = navigator._manhattan_distance((0, 0), (-3, -4))
        assert dist == 7
    
    def test_euclidean_distance(self, navigator):
        """Test Euclidean distance calculation."""
        dist = navigator._euclidean_distance((0, 0), (3, 4))
        assert dist == 5.0
    
    def test_euclidean_distance_same_point(self, navigator):
        """Test Euclidean distance for same point."""
        dist = navigator._euclidean_distance((5, 5), (5, 5))
        assert dist == 0.0
    
    def test_get_neighbors(self, navigator, basic_floor_map):
        """Test getting valid neighbors."""
        neighbors = navigator._get_neighbors((20, 20), basic_floor_map)
        
        assert len(neighbors) > 0
        assert len(neighbors) <= 4
        
        # All neighbors should be walkable
        for neighbor in neighbors:
            assert neighbor in basic_floor_map.walkable_tiles
    
    def test_get_neighbors_edge(self, navigator, basic_floor_map):
        """Test neighbors at edge of walkable area."""
        neighbors = navigator._get_neighbors((10, 10), basic_floor_map)
        
        # Should only have valid neighbors within bounds
        for neighbor in neighbors:
            x, y = neighbor
            assert 0 <= x < basic_floor_map.width
            assert 0 <= y < basic_floor_map.height
    
    def test_get_neighbors_corner(self, navigator):
        """Test neighbors at map corner."""
        floor_map = FloorMap(
            width=50,
            height=50,
            walkable_tiles=set([(0, 0), (1, 0), (0, 1)])
        )
        
        neighbors = navigator._get_neighbors((0, 0), floor_map)
        
        assert len(neighbors) == 2
        assert (1, 0) in neighbors
        assert (0, 1) in neighbors
    
    def test_get_adjacent_position(self, navigator):
        """Test getting adjacent position."""
        pos = navigator._get_adjacent_position((20, 20), 5)
        
        assert pos == (20, 25)
    
    def test_get_adjacent_position_zero_distance(self, navigator):
        """Test adjacent position with zero distance."""
        pos = navigator._get_adjacent_position((20, 20), 0)
        
        assert pos == (20, 20)
    
    def test_reconstruct_path(self, navigator):
        """Test path reconstruction."""
        came_from = {
            (1, 1): (0, 0),
            (2, 1): (1, 1),
            (3, 1): (2, 1)
        }
        
        path = navigator._reconstruct_path(came_from, (3, 1))
        
        assert path[0] == (0, 0)
        assert path[-1] == (3, 1)
        assert len(path) == 4
    
    def test_reconstruct_path_single_step(self, navigator):
        """Test reconstructing single-step path."""
        came_from = {(1, 0): (0, 0)}
        path = navigator._reconstruct_path(came_from, (1, 0))
        
        assert len(path) == 2
        assert path[0] == (0, 0)
        assert path[1] == (1, 0)


class TestCacheManagement:
    """Test path cache management."""
    
    def test_clear_cache(self, navigator):
        """Test clearing path cache."""
        navigator.path_cache[(0, 0), (1, 1), 123] = [(0, 0), (1, 1)]
        
        assert len(navigator.path_cache) > 0
        navigator.clear_cache()
        assert len(navigator.path_cache) == 0
    
    @pytest.mark.asyncio
    async def test_cache_persists_across_calls(self, navigator, basic_floor_map):
        """Test cache persists across multiple calls."""
        await navigator._find_path((15, 15), (20, 20), basic_floor_map)
        cache_size_1 = len(navigator.path_cache)
        
        await navigator._find_path((15, 15), (20, 20), basic_floor_map)
        cache_size_2 = len(navigator.path_cache)
        
        assert cache_size_1 == cache_size_2
        assert cache_size_1 > 0


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.mark.asyncio
    async def test_path_to_self(self, navigator, basic_floor_map):
        """Test pathfinding to same position."""
        path = await navigator._find_path((20, 20), (20, 20), basic_floor_map)
        
        assert len(path) >= 1
    
    @pytest.mark.asyncio
    async def test_large_distance_path(self, navigator, basic_floor_map):
        """Test pathfinding over large distance."""
        path = await navigator._find_path((10, 10), (39, 39), basic_floor_map)
        
        assert len(path) > 0
        assert path[0] == (10, 10)
        assert path[-1] == (39, 39)
    
    def test_distance_with_floats(self, navigator):
        """Test distance calculations don't break with float coords."""
        # Manhattan should work with tuples
        dist = navigator._manhattan_distance((10, 10), (15, 15))
        assert dist == 10
    
    @pytest.mark.asyncio
    async def test_clearing_route_duplicate_positions(self, navigator, basic_floor_map):
        """Test clearing route with monsters at same position."""
        monsters = [
            MonsterPosition(monster_id=1, monster_name="M1", position=(20, 20)),
            MonsterPosition(monster_id=2, monster_name="M2", position=(20, 20))
        ]
        
        route = await navigator.get_clearing_route(
            (15, 15),
            basic_floor_map,
            monsters
        )
        
        # Should handle duplicates
        assert len(route) == 2