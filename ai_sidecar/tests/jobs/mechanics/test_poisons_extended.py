"""
Extended test coverage for poisons.py.

Targets uncovered lines to achieve 100% coverage:
- Lines 115-152, 170-181, 207, 217, 220-222, 253-262, 289-292, 302-308, 320-368, 372-400, 423
- Poison loading, coating, EDP mechanics
- Bottle management
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, mock_open

from ai_sidecar.jobs.mechanics.poisons import (
    PoisonManager,
    PoisonType,
    PoisonEffect,
    WeaponCoating,
)


class TestPoisonExtendedCoverage:
    """Extended coverage for poison manager."""
    
    def test_load_poison_effects_file_not_found(self):
        """Test loading poison effects when file doesn't exist."""
        with patch.object(Path, "exists", return_value=False):
            manager = PoisonManager(data_dir=Path("nonexistent"))
            
            assert len(manager.poison_effects) == 0
    
    def test_load_poison_effects_invalid_json(self):
        """Test loading poison effects with invalid JSON."""
        with patch("builtins.open", mock_open(read_data='invalid json{')):
            with patch.object(Path, "exists", return_value=True):
                manager = PoisonManager(data_dir=Path("test_data"))
                
                assert len(manager.poison_effects) == 0
    
    def test_load_poison_effects_with_valid_data(self):
        """Test loading poison effects with valid data."""
        data = {
            "poisons": {
                "poison": {
                    "display_name": "Poison",
                    "damage_per_second": 10,
                    "duration_seconds": 60,
                    "additional_effects": [],
                    "success_rate": 100
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = PoisonManager(data_dir=Path("test_data"))
                
                assert PoisonType.POISON in manager.poison_effects
    
    def test_load_poison_effects_unknown_poison_type(self):
        """Test loading with unknown poison type."""
        data = {
            "poisons": {
                "unknown_poison": {
                    "display_name": "Unknown"
                }
            }
        }
        
        with patch("builtins.open", mock_open(read_data=str(data).replace("'", '"'))):
            with patch.object(Path, "exists", return_value=True):
                manager = PoisonManager(data_dir=Path("test_data"))
                
                # Unknown types should be skipped
                assert len(manager.poison_effects) == 0
    
    def test_apply_coating_not_in_inventory(self):
        """Test applying coating for poison not in inventory."""
        manager = PoisonManager()
        
        result = manager.apply_coating(PoisonType.TOXIN)
        
        assert result is False
        assert manager.current_coating is None
    
    def test_apply_coating_no_bottles_left(self):
        """Test applying coating when no bottles left."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.TOXIN] = 0
        
        result = manager.apply_coating(PoisonType.TOXIN)
        
        assert result is False
    
    def test_apply_coating_replaces_existing(self):
        """Test applying coating replaces old one."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.POISON] = 10
        manager.poison_bottles[PoisonType.TOXIN] = 10
        
        # Apply first coating
        manager.apply_coating(PoisonType.POISON)
        assert manager.current_coating.poison_type == PoisonType.POISON
        
        # Apply second coating - should replace
        manager.apply_coating(PoisonType.TOXIN)
        assert manager.current_coating.poison_type == PoisonType.TOXIN
    
    def test_apply_coating_success(self):
        """Test successful coating application."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.TOXIN] = 5
        
        result = manager.apply_coating(PoisonType.TOXIN, duration=120, charges=50)
        
        assert result is True
        assert manager.current_coating is not None
        assert manager.current_coating.poison_type == PoisonType.TOXIN
        assert manager.current_coating.charges == 50
        assert manager.poison_bottles[PoisonType.TOXIN] == 4
    
    def test_use_coating_charge_no_coating(self):
        """Test using charge when no coating active."""
        manager = PoisonManager()
        
        result = manager.use_coating_charge()
        
        assert result is False
    
    def test_use_coating_charge_expired(self):
        """Test using charge on expired coating."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=1,
            charges=10
        )
        coating.applied_at = datetime.now() - timedelta(seconds=10)
        manager.current_coating = coating
        
        result = manager.use_coating_charge()
        
        assert result is False
        assert manager.current_coating is None
    
    def test_use_coating_charge_success(self):
        """Test successfully using coating charge."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=10
        )
        manager.current_coating = coating
        
        result = manager.use_coating_charge()
        
        assert result is True
        assert manager.current_coating.charges == 9
    
    def test_use_coating_charge_depletes_coating(self):
        """Test coating depletes when last charge used."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=1
        )
        manager.current_coating = coating
        
        result = manager.use_coating_charge()
        
        assert result is True
        assert manager.current_coating is None
    
    def test_get_current_coating_active(self):
        """Test getting active coating."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.TOXIN,
            duration_seconds=60,
            charges=10
        )
        manager.current_coating = coating
        
        result = manager.get_current_coating()
        
        assert result == PoisonType.TOXIN
    
    def test_get_current_coating_expired(self):
        """Test getting expired coating returns None."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=1,
            charges=10
        )
        coating.applied_at = datetime.now() - timedelta(seconds=10)
        manager.current_coating = coating
        
        result = manager.get_current_coating()
        
        assert result is None
        assert manager.current_coating is None
    
    def test_add_poison_bottles(self):
        """Test adding poison bottles to inventory."""
        manager = PoisonManager()
        
        manager.add_poison_bottles(PoisonType.TOXIN, count=5)
        
        assert manager.poison_bottles[PoisonType.TOXIN] == 5
    
    def test_add_poison_bottles_increments(self):
        """Test adding bottles increments existing count."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.TOXIN] = 3
        
        manager.add_poison_bottles(PoisonType.TOXIN, count=2)
        
        assert manager.poison_bottles[PoisonType.TOXIN] == 5
    
    def test_get_poison_count(self):
        """Test getting poison bottle count."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.TOXIN] = 10
        
        count = manager.get_poison_count(PoisonType.TOXIN)
        
        assert count == 10
    
    def test_get_poison_count_not_in_inventory(self):
        """Test getting count for poison not in inventory."""
        manager = PoisonManager()
        
        count = manager.get_poison_count(PoisonType.TOXIN)
        
        assert count == 0
    
    def test_activate_edp(self):
        """Test activating EDP."""
        manager = PoisonManager()
        
        manager.activate_edp(duration=40)
        
        assert manager.edp_active is True
        assert manager.edp_expires_at is not None
    
    def test_deactivate_edp(self):
        """Test deactivating EDP."""
        manager = PoisonManager()
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        manager.deactivate_edp()
        
        assert manager.edp_active is False
        assert manager.edp_expires_at is None
    
    def test_deactivate_edp_already_inactive(self):
        """Test deactivating EDP when already inactive."""
        manager = PoisonManager()
        
        manager.deactivate_edp()
        
        # Should not raise error
        assert manager.edp_active is False
    
    def test_is_edp_active_true(self):
        """Test checking EDP active."""
        manager = PoisonManager()
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        result = manager.is_edp_active()
        
        assert result is True
    
    def test_is_edp_active_false(self):
        """Test checking EDP inactive."""
        manager = PoisonManager()
        
        result = manager.is_edp_active()
        
        assert result is False
    
    def test_is_edp_active_expired(self):
        """Test EDP deactivates when expired."""
        manager = PoisonManager()
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() - timedelta(seconds=10)
        
        result = manager.is_edp_active()
        
        assert result is False
        assert manager.edp_active is False
    
    def test_get_poison_effect(self):
        """Test getting poison effect definition."""
        manager = PoisonManager()
        
        effect = PoisonEffect(
            poison_type=PoisonType.TOXIN,
            display_name="Toxin",
            damage_per_second=15,
            duration_seconds=60,
            success_rate=100
        )
        manager.poison_effects[PoisonType.TOXIN] = effect
        
        result = manager.get_poison_effect(PoisonType.TOXIN)
        
        assert result == effect
    
    def test_get_poison_effect_not_found(self):
        """Test getting effect for unknown poison."""
        manager = PoisonManager()
        
        result = manager.get_poison_effect(PoisonType.TOXIN)
        
        assert result is None
    
    def test_should_reapply_coating_no_coating(self):
        """Test should reapply when no coating."""
        manager = PoisonManager()
        
        result = manager.should_reapply_coating()
        
        assert result is True
    
    def test_should_reapply_coating_expired(self):
        """Test should reapply when coating expired."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=1,
            charges=10
        )
        coating.applied_at = datetime.now() - timedelta(seconds=10)
        manager.current_coating = coating
        
        result = manager.should_reapply_coating()
        
        assert result is True
    
    def test_should_reapply_coating_low_charges(self):
        """Test should reapply when charges low."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=3
        )
        manager.current_coating = coating
        
        result = manager.should_reapply_coating(min_charges=5)
        
        assert result is True
    
    def test_should_reapply_coating_sufficient(self):
        """Test should not reapply when coating sufficient."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=20
        )
        manager.current_coating = coating
        
        result = manager.should_reapply_coating(min_charges=5)
        
        assert result is False
    
    def test_get_recommended_poison_boss_situation(self):
        """Test recommended poison for boss."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.ENCHANT_DEADLY_POISON] = 5
        
        poison = manager.get_recommended_poison("boss")
        
        assert poison == PoisonType.ENCHANT_DEADLY_POISON
    
    def test_get_recommended_poison_farming(self):
        """Test recommended poison for farming."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.TOXIN] = 5
        
        poison = manager.get_recommended_poison("farming")
        
        assert poison == PoisonType.TOXIN
    
    def test_get_recommended_poison_pvp(self):
        """Test recommended poison for PvP."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.PARALYZE] = 5
        
        poison = manager.get_recommended_poison("pvp")
        
        assert poison == PoisonType.PARALYZE
    
    def test_get_recommended_poison_fallback(self):
        """Test fallback to any available poison."""
        manager = PoisonManager()
        manager.poison_bottles[PoisonType.VENOM_DUST] = 5
        
        poison = manager.get_recommended_poison("boss")
        
        # Should fall back to available poison
        assert poison == PoisonType.VENOM_DUST
    
    def test_get_recommended_poison_none_available(self):
        """Test recommended poison with none available."""
        manager = PoisonManager()
        
        poison = manager.get_recommended_poison("boss")
        
        assert poison is None
    
    def test_get_status_with_active_coating(self):
        """Test getting status with active coating."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.TOXIN,
            duration_seconds=60,
            charges=20
        )
        manager.current_coating = coating
        manager.poison_bottles[PoisonType.TOXIN] = 5
        manager.poison_bottles[PoisonType.POISON] = 3
        
        status = manager.get_status()
        
        assert status["coating_active"] is True
        assert "current_coating" in status
        assert status["current_coating"]["poison"] == "toxin"
        assert status["current_coating"]["charges"] == 20
        assert status["poison_inventory"]["toxin"] == 5
    
    def test_get_status_with_edp(self):
        """Test getting status with EDP active."""
        manager = PoisonManager()
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        status = manager.get_status()
        
        assert status["edp_active"] is True
        assert "edp_time_left" in status
        assert status["edp_time_left"] > 0
    
    def test_get_status_coating_expired(self):
        """Test status doesn't show expired coating."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=1,
            charges=10
        )
        coating.applied_at = datetime.now() - timedelta(seconds=10)
        manager.current_coating = coating
        
        status = manager.get_status()
        
        assert "current_coating" not in status
    
    def test_reset(self):
        """Test resetting poison state."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=20
        )
        manager.current_coating = coating
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        manager.reset()
        
        assert manager.current_coating is None
        assert manager.edp_active is False
        assert manager.edp_expires_at is None
    
    def test_clear_coating_with_coating(self):
        """Test clearing active coating."""
        manager = PoisonManager()
        
        coating = WeaponCoating(
            poison_type=PoisonType.TOXIN,
            duration_seconds=60,
            charges=15
        )
        manager.current_coating = coating
        
        manager.clear_coating()
        
        assert manager.current_coating is None
    
    def test_clear_coating_no_coating(self):
        """Test clearing when no coating active."""
        manager = PoisonManager()
        
        manager.clear_coating()
        
        # Should not raise error
        assert manager.current_coating is None


class TestWeaponCoatingModel:
    """Test WeaponCoating model behavior."""
    
    def test_is_expired_time_based(self):
        """Test coating expiry based on time."""
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=1,
            charges=10
        )
        coating.applied_at = datetime.now() - timedelta(seconds=10)
        
        assert coating.is_expired is True
    
    def test_is_expired_charges_based(self):
        """Test coating expiry based on charges."""
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=0
        )
        
        assert coating.is_expired is True
    
    def test_is_not_expired(self):
        """Test coating not expired."""
        coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=10
        )
        
        assert coating.is_expired is False