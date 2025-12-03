"""
Comprehensive tests for jobs/mechanics/traps.py - BATCH 4.
Target: 95%+ coverage (currently 82.35%, 18 uncovered lines).
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from ai_sidecar.jobs.mechanics.traps import (
    TrapManager,
    TrapType,
    PlacedTrap,
)


class TestTrapManager:
    """Test TrapManager functionality."""
    
    @pytest.fixture
    def manager(self):
        """Create trap manager."""
        return TrapManager()
    
    @pytest.fixture
    def temp_data_dir(self, tmp_path):
        """Create temp data directory with trap definitions."""
        data_dir = tmp_path / "data"
        data_dir.mkdir()
        
        import json
        trap_data = {
            "traps": {
                "blast_mine": {
                    "duration_seconds": 25,
                    "damage": 500,
                },
                "ankle_snare": {
                    "duration_seconds": 250,
                    "immobilize": True,
                },
            },
            "max_traps_by_level": {
                "1": 1,
                "5": 3,
                "10": 5,
            }
        }
        
        trap_file = data_dir / "trap_definitions.json"
        with open(trap_file, "w") as f:
            json.dump(trap_data, f)
        
        return data_dir
    
    def test_initialization(self, manager):
        """Test manager initialization."""
        assert len(manager.placed_traps) == 0
        assert manager.max_traps == 3
        assert isinstance(manager.trap_definitions, dict)
    
    def test_initialization_with_data(self, temp_data_dir):
        """Test initialization with data file."""
        manager = TrapManager(data_dir=temp_data_dir)
        
        assert TrapType.BLAST_MINE in manager.trap_definitions
        assert manager.max_traps == 5  # Max from level 10
    
    def test_place_trap_success(self, manager):
        """Test placing a trap."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {
            "duration_seconds": 20
        }
        
        success = manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        
        assert success is True
        assert len(manager.placed_traps) == 1
        assert manager.placed_traps[0].trap_type == TrapType.BLAST_MINE
    
    def test_place_trap_at_limit(self, manager):
        """Test placing trap at max limit."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {"duration_seconds": 20}
        manager.max_traps = 2
        
        # Place max traps
        manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        manager.place_trap(TrapType.BLAST_MINE, (101, 101))
        
        # Try to place one more
        success = manager.place_trap(TrapType.BLAST_MINE, (102, 102))
        
        assert success is False
        assert len(manager.placed_traps) == 2
    
    def test_place_trap_no_definition(self, manager):
        """Test placing trap without definition."""
        success = manager.place_trap(TrapType.CLUSTER_BOMB, (100, 100))
        
        assert success is False
    
    def test_get_trap_count(self, manager):
        """Test getting trap count."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {"duration_seconds": 20}
        
        manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        manager.place_trap(TrapType.BLAST_MINE, (101, 101))
        
        count = manager.get_trap_count()
        
        assert count == 2
    
    def test_cleanup_expired_traps(self, manager):
        """Test cleanup of expired traps."""
        # Create expired trap
        old_trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now() - timedelta(seconds=100),
            duration_seconds=20,
        )
        manager.placed_traps.append(old_trap)
        
        # Create active trap
        active_trap = PlacedTrap(
            trap_type=TrapType.ANKLE_SNARE,
            position=(101, 101),
            placed_at=datetime.now(),
            duration_seconds=250,
        )
        manager.placed_traps.append(active_trap)
        
        removed = manager.cleanup_expired_traps()
        
        assert removed == 1
        assert len(manager.placed_traps) == 1
        assert manager.placed_traps[0].trap_type == TrapType.ANKLE_SNARE
    
    def test_find_optimal_trap_position(self, manager):
        """Test finding optimal trap position."""
        enemy_positions = [(110, 110), (120, 120), (115, 115)]
        own_position = (100, 100)
        
        optimal = manager.find_optimal_trap_position(enemy_positions, own_position)
        
        assert isinstance(optimal, tuple)
        # Should be between player and enemies
        assert optimal[0] > own_position[0]
    
    def test_find_optimal_trap_position_no_enemies(self, manager):
        """Test optimal position with no enemies."""
        optimal = manager.find_optimal_trap_position([], (100, 100))
        
        assert optimal == (100, 100)
    
    def test_should_use_detonator_yes(self, manager):
        """Test detonator recommendation with explosive traps."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=20,
            is_triggered=False,
        )
        manager.placed_traps.append(trap)
        
        should_use = manager.should_use_detonator()
        
        assert should_use is True
    
    def test_should_use_detonator_no(self, manager):
        """Test detonator with non-explosive traps."""
        trap = PlacedTrap(
            trap_type=TrapType.ANKLE_SNARE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=250,
        )
        manager.placed_traps.append(trap)
        
        should_use = manager.should_use_detonator()
        
        assert should_use is False
    
    def test_should_use_detonator_already_triggered(self, manager):
        """Test detonator with already triggered traps."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=20,
            is_triggered=True,  # Already triggered
        )
        manager.placed_traps.append(trap)
        
        should_use = manager.should_use_detonator()
        
        assert should_use is False
    
    def test_trigger_trap(self, manager):
        """Test triggering a trap."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=20,
        )
        manager.placed_traps.append(trap)
        
        triggered = manager.trigger_trap((100, 100))
        
        assert triggered is not None
        assert triggered.is_triggered is True
    
    def test_trigger_trap_not_found(self, manager):
        """Test triggering at position with no trap."""
        triggered = manager.trigger_trap((200, 200))
        
        assert triggered is None
    
    def test_trigger_trap_already_triggered(self, manager):
        """Test triggering already triggered trap."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=20,
            is_triggered=True,
        )
        manager.placed_traps.append(trap)
        
        triggered = manager.trigger_trap((100, 100))
        
        assert triggered is None
    
    def test_get_trap_layout_strategy_boss(self, manager):
        """Test trap layout for boss."""
        layout = manager.get_trap_layout_strategy("boss")
        
        assert len(layout) > 0
        assert all(isinstance(trap_type, TrapType) for trap_type, _ in layout)
    
    def test_get_trap_layout_strategy_farming(self, manager):
        """Test trap layout for farming."""
        layout = manager.get_trap_layout_strategy("farming")
        
        assert len(layout) > 0
    
    def test_get_trap_layout_strategy_pvp(self, manager):
        """Test trap layout for PvP."""
        layout = manager.get_trap_layout_strategy("pvp")
        
        assert len(layout) > 0
    
    def test_get_trap_layout_strategy_unknown(self, manager):
        """Test trap layout for unknown situation."""
        layout = manager.get_trap_layout_strategy("unknown")
        
        assert len(layout) == 0
    
    def test_get_status(self, manager):
        """Test getting trap status."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {"duration_seconds": 20}
        manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        
        status = manager.get_status()
        
        assert status["active_traps"] == 1
        assert status["max_traps"] == 3
        assert len(status["traps"]) == 1
        assert status["traps"][0]["type"] == "blast_mine"
    
    def test_reset(self, manager):
        """Test resetting trap state."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {"duration_seconds": 20}
        manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        
        manager.reset()
        
        assert len(manager.placed_traps) == 0
    
    def test_get_placed_traps(self, manager):
        """Test getting placed traps."""
        manager.trap_definitions[TrapType.BLAST_MINE] = {"duration_seconds": 20}
        manager.place_trap(TrapType.BLAST_MINE, (100, 100))
        
        traps = manager.get_placed_traps()
        
        assert len(traps) == 1
        assert isinstance(traps[0], PlacedTrap)


class TestPlacedTrap:
    """Test PlacedTrap model."""
    
    def test_placed_trap_properties(self):
        """Test trap properties."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=20,
        )
        
        assert trap.trap_type == TrapType.BLAST_MINE
        assert trap.position == (100, 100)
        assert trap.is_triggered is False
    
    def test_is_expired_no(self):
        """Test trap not expired."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now(),
            duration_seconds=60,
        )
        
        assert trap.is_expired is False
    
    def test_is_expired_yes(self):
        """Test trap is expired."""
        trap = PlacedTrap(
            trap_type=TrapType.BLAST_MINE,
            position=(100, 100),
            placed_at=datetime.now() - timedelta(seconds=100),
            duration_seconds=20,
        )
        
        assert trap.is_expired is True