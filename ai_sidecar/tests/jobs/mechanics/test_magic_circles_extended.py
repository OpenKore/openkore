"""
Extended test coverage for magic_circles.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 100-128, 221-227, 260-307, 316-342, 369, 400
- Circle placement edge cases
- Insignia management
- Position-based queries
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open

from ai_sidecar.jobs.mechanics.magic_circles import (
    MagicCircleManager,
    CircleType,
    PlacedCircle,
)


class TestMagicCircleExtendedCoverage:
    """Extended coverage for magic circle manager."""
    
    def test_init_with_data_dir(self):
        """Test initialization with data directory."""
        with patch("builtins.open", mock_open(read_data='{"circles": {}}')):
            with patch.object(Path, "exists", return_value=True):
                manager = MagicCircleManager(data_dir=Path("test_data"))
                
                assert manager is not None
    
    def test_load_circle_effects_file_not_found(self):
        """Test loading circle effects when file doesn't exist."""
        with patch.object(Path, "exists", return_value=False):
            manager = MagicCircleManager(data_dir=Path("nonexistent"))
            
            assert len(manager.circle_effects) == 0
    
    def test_load_circle_effects_invalid_json(self):
        """Test loading circle effects with invalid JSON."""
        with patch("builtins.open", mock_open(read_data='invalid json{')):
            with patch.object(Path, "exists", return_value=True):
                manager = MagicCircleManager(data_dir=Path("test_data"))
                
                assert len(manager.circle_effects) == 0
    
    def test_load_circle_effects_with_valid_data(self):
        """Test loading circle effects with valid data."""
        data = {
            "circles": {
                "fire_insignia": {
                    "duration_seconds": 60,
                    "radius": 5
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = MagicCircleManager(data_dir=Path("test_data"))
                
                assert CircleType.FIRE_INSIGNIA in manager.circle_effects
    
    def test_load_circle_effects_unknown_circle_type(self):
        """Test loading with unknown circle type."""
        data = {
            "circles": {
                "unknown_circle": {
                    "duration_seconds": 60
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = MagicCircleManager(data_dir=Path("test_data"))
                
                # Unknown types should be skipped
                assert len(manager.circle_effects) == 0
    
    def test_place_circle_at_limit(self):
        """Test placing circle when at max limit."""
        manager = MagicCircleManager()
        manager.max_circles = 2
        manager.circle_effects[CircleType.STRIKING] = {
            "duration_seconds": 30,
            "radius": 3
        }
        
        # Place two circles
        manager.place_circle(CircleType.STRIKING, (100, 100))
        manager.place_circle(CircleType.STRIKING, (110, 110))
        
        # Third should fail
        result = manager.place_circle(CircleType.STRIKING, (120, 120))
        
        assert result is False
    
    def test_place_circle_no_definition(self):
        """Test placing circle without definition."""
        manager = MagicCircleManager()
        
        result = manager.place_circle(CircleType.STRIKING, (100, 100))
        
        assert result is False
    
    def test_place_insignia_replaces_old(self):
        """Test placing insignia replaces old one."""
        manager = MagicCircleManager()
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 5
        }
        manager.circle_effects[CircleType.WATER_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 5
        }
        
        # Place fire insignia
        manager.place_circle(CircleType.FIRE_INSIGNIA, (100, 100))
        assert manager.active_insignia == CircleType.FIRE_INSIGNIA
        
        # Place water insignia - should replace
        manager.place_circle(CircleType.WATER_INSIGNIA, (110, 110))
        assert manager.active_insignia == CircleType.WATER_INSIGNIA
        
        # Should only have one insignia
        insignias = [c for c in manager.placed_circles if manager._is_insignia(c.circle_type)]
        assert len(insignias) == 1
    
    def test_cleanup_expired_circles(self):
        """Test cleaning up expired circles."""
        manager = MagicCircleManager()
        
        # Create expired circle
        expired_circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=1,
            radius=3
        )
        expired_circle.placed_at = datetime.now() - timedelta(seconds=10)
        
        manager.placed_circles.append(expired_circle)
        
        removed = manager.cleanup_expired_circles()
        
        assert removed == 1
        assert len(manager.placed_circles) == 0
    
    def test_cleanup_expired_insignia(self):
        """Test cleaning up expired insignia."""
        manager = MagicCircleManager()
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() - timedelta(seconds=10)
        
        manager.cleanup_expired_circles()
        
        assert manager.active_insignia is None
        assert manager.insignia_expires_at is None
    
    def test_get_active_insignia_expired(self):
        """Test get active insignia when expired."""
        manager = MagicCircleManager()
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() - timedelta(seconds=10)
        
        result = manager.get_active_insignia()
        
        assert result is None
        assert manager.active_insignia is None
    
    def test_get_active_insignia_active(self):
        """Test get active insignia when still active."""
        manager = MagicCircleManager()
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=30)
        
        result = manager.get_active_insignia()
        
        assert result == CircleType.FIRE_INSIGNIA
    
    def test_get_circles_at_position_in_range(self):
        """Test getting circles affecting a position."""
        manager = MagicCircleManager()
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=5
        )
        manager.placed_circles.append(circle)
        
        # Position within radius
        affecting = manager.get_circles_at_position((103, 103), radius=0)
        
        assert len(affecting) == 1
    
    def test_get_circles_at_position_out_of_range(self):
        """Test getting circles when position out of range."""
        manager = MagicCircleManager()
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=5
        )
        manager.placed_circles.append(circle)
        
        # Position far away
        affecting = manager.get_circles_at_position((200, 200), radius=0)
        
        assert len(affecting) == 0
    
    def test_get_recommended_circle_boss_situation(self):
        """Test recommended circle for boss situation."""
        manager = MagicCircleManager()
        
        circle = manager.get_recommended_circle("boss")
        
        assert circle in [
            CircleType.STRIKING,
            CircleType.POISON_BUSTER,
            CircleType.PSYCHIC_WAVE
        ]
    
    def test_get_recommended_circle_farming_situation(self):
        """Test recommended circle for farming."""
        manager = MagicCircleManager()
        
        circle = manager.get_recommended_circle("farming")
        
        assert circle in [
            CircleType.CLOUD_KILL,
            CircleType.FIRE_INSIGNIA,
            CircleType.VACUUM_EXTREME
        ]
    
    def test_get_recommended_circle_pvp_situation(self):
        """Test recommended circle for PvP."""
        manager = MagicCircleManager()
        
        circle = manager.get_recommended_circle("pvp")
        
        assert circle in [
            CircleType.PSYCHIC_WAVE,
            CircleType.POISON_BUSTER,
            CircleType.WATER_INSIGNIA
        ]
    
    def test_get_recommended_circle_support_situation(self):
        """Test recommended circle for support."""
        manager = MagicCircleManager()
        
        circle = manager.get_recommended_circle("support")
        
        assert circle in [CircleType.WARMER, CircleType.EARTH_INSIGNIA]
    
    def test_get_recommended_circle_unknown_situation(self):
        """Test recommended circle for unknown situation."""
        manager = MagicCircleManager()
        
        circle = manager.get_recommended_circle("unknown")
        
        assert circle is None
    
    def test_should_replace_circle_at_max(self):
        """Test should replace when at max circles."""
        manager = MagicCircleManager()
        manager.max_circles = 2
        
        # Add 2 non-insignia circles
        for i in range(2):
            circle = PlacedCircle(
                circle_type=CircleType.STRIKING,
                position=(100 + i*10, 100),
                duration_seconds=30,
                radius=3
            )
            manager.placed_circles.append(circle)
        
        result = manager.should_replace_circle()
        
        assert result is True
    
    def test_should_replace_circle_not_at_max(self):
        """Test should not replace when under limit."""
        manager = MagicCircleManager()
        manager.max_circles = 3
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=3
        )
        manager.placed_circles.append(circle)
        
        result = manager.should_replace_circle()
        
        assert result is False
    
    def test_remove_oldest_circle(self):
        """Test removing oldest circle."""
        manager = MagicCircleManager()
        
        # Add circles at different times
        old_circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=3
        )
        old_circle.placed_at = datetime.now() - timedelta(seconds=20)
        
        new_circle = PlacedCircle(
            circle_type=CircleType.POISON_BUSTER,
            position=(110, 110),
            duration_seconds=30,
            radius=3
        )
        new_circle.placed_at = datetime.now() - timedelta(seconds=5)
        
        manager.placed_circles.extend([old_circle, new_circle])
        
        result = manager.remove_oldest_circle()
        
        assert result is True
        assert len(manager.placed_circles) == 1
        assert manager.placed_circles[0].circle_type == CircleType.POISON_BUSTER
    
    def test_remove_oldest_circle_none_available(self):
        """Test removing oldest when no non-insignia circles."""
        manager = MagicCircleManager()
        
        result = manager.remove_oldest_circle()
        
        assert result is False
    
    def test_get_elemental_bonus_matching(self):
        """Test elemental bonus with matching insignia."""
        manager = MagicCircleManager()
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=30)
        
        bonus = manager.get_elemental_bonus("fire")
        
        assert bonus == 1.5
    
    def test_get_elemental_bonus_not_matching(self):
        """Test elemental bonus with non-matching insignia."""
        manager = MagicCircleManager()
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=30)
        
        bonus = manager.get_elemental_bonus("water")
        
        assert bonus == 1.0
    
    def test_get_elemental_bonus_no_insignia(self):
        """Test elemental bonus with no active insignia."""
        manager = MagicCircleManager()
        
        bonus = manager.get_elemental_bonus("fire")
        
        assert bonus == 1.0
    
    def test_get_status_with_circles(self):
        """Test getting status with active circles."""
        manager = MagicCircleManager()
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=3
        )
        manager.placed_circles.append(circle)
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=45)
        
        status = manager.get_status()
        
        assert status["active_circles"] == 1
        assert status["max_circles"] == 2
        assert status["active_insignia"] == "fire_insignia"
        assert "insignia_time_left" in status
        assert len(status["circles"]) == 1
    
    def test_get_status_empty(self):
        """Test getting status with no circles."""
        manager = MagicCircleManager()
        
        status = manager.get_status()
        
        assert status["active_circles"] == 0
        assert status["active_insignia"] is None
    
    def test_reset(self):
        """Test resetting magic circle state."""
        manager = MagicCircleManager()
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=3
        )
        manager.placed_circles.append(circle)
        manager.active_insignia = CircleType.FIRE_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=30)
        
        manager.reset()
        
        assert len(manager.placed_circles) == 0
        assert manager.active_insignia is None
        assert manager.insignia_expires_at is None
    
    def test_get_placed_circles(self):
        """Test getting copy of placed circles list."""
        manager = MagicCircleManager()
        
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=30,
            radius=3
        )
        manager.placed_circles.append(circle)
        
        circles = manager.get_placed_circles()
        
        assert len(circles) == 1
        # Should be a copy
        circles.clear()
        assert len(manager.placed_circles) == 1


class TestPlacedCircleModel:
    """Test PlacedCircle model behavior."""
    
    def test_is_expired_property_true(self):
        """Test is_expired when circle has expired."""
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=1,
            radius=3
        )
        circle.placed_at = datetime.now() - timedelta(seconds=10)
        
        assert circle.is_expired is True
    
    def test_is_expired_property_false(self):
        """Test is_expired when circle still active."""
        circle = PlacedCircle(
            circle_type=CircleType.STRIKING,
            position=(100, 100),
            duration_seconds=60,
            radius=3
        )
        
        assert circle.is_expired is False


class TestInsigniaManagement:
    """Test elemental insignia placement and tracking."""
    
    def test_place_insignia_sets_active(self):
        """Test placing insignia sets it as active."""
        manager = MagicCircleManager()
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 5
        }
        
        result = manager.place_circle(CircleType.FIRE_INSIGNIA, (100, 100))
        
        assert result is True
        assert manager.active_insignia == CircleType.FIRE_INSIGNIA
        assert manager.insignia_expires_at is not None
    
    def test_insignia_does_not_count_toward_limit(self):
        """Test insignias don't count toward circle limit."""
        manager = MagicCircleManager()
        manager.max_circles = 2
        
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 5
        }
        manager.circle_effects[CircleType.STRIKING] = {
            "duration_seconds": 30,
            "radius": 3
        }
        
        # Place insignia
        manager.place_circle(CircleType.FIRE_INSIGNIA, (100, 100))
        
        # Should still be able to place 2 regular circles
        result1 = manager.place_circle(CircleType.STRIKING, (110, 110))
        result2 = manager.place_circle(CircleType.STRIKING, (120, 120))
        
        assert result1 is True
        assert result2 is True
    
    def test_is_insignia_check(self):
        """Test _is_insignia helper method."""
        manager = MagicCircleManager()
        
        assert manager._is_insignia(CircleType.FIRE_INSIGNIA) is True
        assert manager._is_insignia(CircleType.WATER_INSIGNIA) is True
        assert manager._is_insignia(CircleType.WIND_INSIGNIA) is True
        assert manager._is_insignia(CircleType.EARTH_INSIGNIA) is True
        assert manager._is_insignia(CircleType.STRIKING) is False
        assert manager._is_insignia(CircleType.POISON_BUSTER) is False