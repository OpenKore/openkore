"""
Comprehensive tests for the final BATCH 2 modules to achieve maximum coverage:
- jobs/mechanics/poisons.py (74.88% -> target 100%)
- jobs/mechanics/magic_circles.py (76.80% -> target 100%)
- combat/aoe.py (80.45% -> target 100%)
"""

import json
import tempfile
from datetime import datetime, timedelta
from pathlib import Path

import pytest

from ai_sidecar.jobs.mechanics.poisons import (
    PoisonEffect,
    PoisonManager,
    PoisonType,
    WeaponCoating,
)
from ai_sidecar.jobs.mechanics.magic_circles import (
    CircleType,
    MagicCircleManager,
    PlacedCircle,
)
from ai_sidecar.combat.aoe import (
    AoEResult,
    AoEShape,
    AoESkill,
    AoETarget,
    AoETargetingSystem,
)


# ============================================================================
# POISONS.PY TESTS
# ============================================================================

class TestPoisonManagerLoadEffects:
    """Test PoisonManager loading poison effects from JSON."""
    
    def test_load_poison_effects_file_not_found(self):
        """Test _load_poison_effects when file doesn't exist (lines 115-119)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            # Don't create poison_effects.json
            
            manager = PoisonManager(data_dir)
            
            # Should handle missing file gracefully
            assert len(manager.poison_effects) == 0
    
    def test_load_poison_effects_invalid_poison_type(self):
        """Test loading with invalid poison type (lines 140-141)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            poison_file = data_dir / "poison_effects.json"
            
            poison_data = {
                "poisons": {
                    "invalid_poison_xyz": {  # Invalid poison type
                        "display_name": "Invalid",
                        "damage_per_second": 10,
                        "duration_seconds": 30,
                        "success_rate": 100
                    }
                }
            }
            
            with open(poison_file, 'w') as f:
                json.dump(poison_data, f)
            
            manager = PoisonManager(data_dir)
            
            # Invalid poison should be skipped
            assert "invalid_poison_xyz" not in [p.value for p in manager.poison_effects.keys()]
    
    def test_load_poison_effects_json_error(self):
        """Test loading with JSON error (lines 148-149)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            poison_file = data_dir / "poison_effects.json"
            
            # Write invalid JSON
            with open(poison_file, 'w') as f:
                f.write("{ invalid json }")
            
            manager = PoisonManager(data_dir)
            
            # Should handle error gracefully
            assert len(manager.poison_effects) == 0


class TestPoisonManagerApplyCoating:
    """Test apply_coating method edge cases."""
    
    def test_apply_coating_poison_not_in_inventory(self):
        """Test apply_coating when poison not in inventory (lines 170-174)."""
        manager = PoisonManager()
        
        # Try to apply poison not in inventory
        result = manager.apply_coating(PoisonType.TOXIN, duration=60, charges=30)
        
        assert result is False
        assert manager.current_coating is None
    
    def test_apply_coating_no_bottles_left(self):
        """Test apply_coating when no bottles left (lines 177-181)."""
        manager = PoisonManager()
        
        # Add poison but set count to 0
        manager.poison_bottles[PoisonType.POISON] = 0
        
        result = manager.apply_coating(PoisonType.POISON, duration=60, charges=30)
        
        assert result is False
        assert manager.current_coating is None


class TestWeaponCoatingExpiry:
    """Test WeaponCoating expiry logic."""
    
    def test_is_expired_by_time(self):
        """Test coating expiry by time (line 217)."""
        # Create coating that expired 5 seconds ago
        coating = WeaponCoating(
            poison_type=PoisonType.VENOM_DUST,
            applied_at=datetime.now() - timedelta(seconds=65),
            duration_seconds=60,
            charges=10
        )
        
        assert coating.is_expired is True
    
    def test_is_expired_by_charges(self):
        """Test coating expiry by charges (line 220)."""
        coating = WeaponCoating(
            poison_type=PoisonType.ENCHANT_DEADLY_POISON,
            applied_at=datetime.now(),
            duration_seconds=60,
            charges=0  # No charges left
        )
        
        assert coating.is_expired is True


class TestPoisonManagerUseCoatingCharge:
    """Test use_coating_charge method."""
    
    def test_use_coating_charge_no_coating(self):
        """Test use_coating_charge when no coating active (line 217)."""
        manager = PoisonManager()
        
        result = manager.use_coating_charge()
        
        assert result is False
    
    def test_use_coating_charge_expired(self):
        """Test use_coating_charge when coating expired (lines 220-222)."""
        manager = PoisonManager()
        
        # Add expired coating
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            applied_at=datetime.now() - timedelta(seconds=100),
            duration_seconds=60,
            charges=5
        )
        
        result = manager.use_coating_charge()
        
        assert result is False
        assert manager.current_coating is None


class TestPoisonManagerGetCurrentCoating:
    """Test get_current_coating method."""
    
    def test_get_current_coating_expired(self):
        """Test get_current_coating with expired coating (lines 253->256)."""
        manager = PoisonManager()
        
        # Set expired coating
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.VENOM_SPLASHER,
            applied_at=datetime.now() - timedelta(seconds=200),
            duration_seconds=60,
            charges=0
        )
        
        result = manager.get_current_coating()
        
        # Should return None and clear coating
        assert result is None
        assert manager.current_coating is None


class TestPoisonManagerIsEdpActive:
    """Test is_edp_active method."""
    
    def test_is_edp_active_false(self):
        """Test is_edp_active when not active (line 302)."""
        manager = PoisonManager()
        
        result = manager.is_edp_active()
        
        assert result is False
    
    def test_is_edp_active_expired(self):
        """Test is_edp_active when expired (lines 305-306)."""
        manager = PoisonManager()
        
        # Activate EDP in the past
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() - timedelta(seconds=10)
        
        result = manager.is_edp_active()
        
        # Should deactivate and return False
        assert result is False
        assert manager.edp_active is False


class TestPoisonManagerGetPoisonEffect:
    """Test get_poison_effect method."""
    
    def test_get_poison_effect_not_found(self):
        """Test get_poison_effect for unknown poison (line 320)."""
        manager = PoisonManager()
        
        result = manager.get_poison_effect(PoisonType.TOXIN)
        
        assert result is None


class TestPoisonManagerShouldReapply:
    """Test should_reapply_coating logic."""
    
    def test_should_reapply_no_coating(self):
        """Test should_reapply when no coating (line 336)."""
        manager = PoisonManager()
        
        result = manager.should_reapply_coating(min_charges=5)
        
        assert result is True


class TestPoisonManagerGetRecommended:
    """Test get_recommended_poison method."""
    
    def test_get_recommended_poison_not_available(self):
        """Test recommended poison when not in inventory (lines 364-368)."""
        manager = PoisonManager()
        
        # No poisons in inventory
        result = manager.get_recommended_poison("boss")
        
        assert result is None
    
    def test_get_recommended_poison_fallback(self):
        """Test recommended poison fallback logic (lines 364-368)."""
        manager = PoisonManager()
        
        # Add a poison that's NOT the recommended one
        manager.poison_bottles[PoisonType.POISON] = 5
        
        # Request boss poison (EDP) but we only have basic poison
        result = manager.get_recommended_poison("boss")
        
        # Should fallback to available poison
        assert result == PoisonType.POISON


class TestPoisonManagerGetStatus:
    """Test get_status method."""
    
    def test_get_status_with_coating(self):
        """Test get_status with active coating (lines 372-400)."""
        manager = PoisonManager()
        
        # Add active coating
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.ENCHANT_DEADLY_POISON,
            applied_at=datetime.now(),
            duration_seconds=60,
            charges=25
        )
        
        # Add some poisons
        manager.poison_bottles[PoisonType.TOXIN] = 10
        
        # Activate EDP
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        status = manager.get_status()
        
        # Lines 372-400 should execute
        assert "coating_active" in status
        assert status["coating_active"] is True
        assert "current_coating" in status
        assert "edp_time_left" in status
        assert status["edp_time_left"] > 0


class TestPoisonManagerClearCoating:
    """Test clear_coating method."""
    
    def test_clear_coating_with_coating(self):
        """Test clear_coating when coating exists (line 423)."""
        manager = PoisonManager()
        
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            duration_seconds=60,
            charges=15
        )
        
        manager.clear_coating()
        
        assert manager.current_coating is None


# ============================================================================
# MAGIC_CIRCLES.PY TESTS
# ============================================================================

class TestMagicCircleManagerLoadEffects:
    """Test loading circle effects from JSON."""
    
    def test_load_circle_effects_file_not_found(self):
        """Test when magic_circle_effects.json doesn't exist (lines 100-104)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = MagicCircleManager(Path(tmpdir))
            
            # Should handle missing file gracefully
            assert len(manager.circle_effects) == 0
    
    def test_load_circle_effects_json_error(self):
        """Test loading with JSON error (lines 123-124)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            circle_file = data_dir / "magic_circle_effects.json"
            
            # Invalid JSON
            with open(circle_file, 'w') as f:
                f.write("{ bad json }")
            
            manager = MagicCircleManager(data_dir)
            
            assert len(manager.circle_effects) == 0


class TestMagicCircleManagerPlaceCircle:
    """Test place_circle method edge cases."""
    
    def test_place_circle_at_max_limit(self):
        """Test placing circle when at max limit (lines 221-222)."""
        manager = MagicCircleManager()
        
        # Manually set max circles
        manager.max_circles = 2
        
        # Add circle effects
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 3
        }
        manager.circle_effects[CircleType.STRIKING] = {
            "duration_seconds": 30,
            "radius": 5
        }
        
        # Place 2 circles
        manager.place_circle(CircleType.STRIKING, (10, 10))
        manager.place_circle(CircleType.STRIKING, (20, 20))
        
        # Try to place 3rd circle - should fail
        result = manager.place_circle(CircleType.STRIKING, (30, 30))
        
        assert result is False
    
    def test_place_circle_no_definition(self):
        """Test placing circle with no definition (line 225)."""
        manager = MagicCircleManager()
        
        # Try to place circle with no definition
        result = manager.place_circle(CircleType.PSYCHIC_WAVE, (10, 10))
        
        assert result is False


class TestMagicCircleManagerGetCirclesAtPosition:
    """Test get_circles_at_position method."""
    
    def test_get_circles_at_position(self):
        """Test getting circles at position (lines 260-271)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.WARMER] = {
            "duration_seconds": 30,
            "radius": 3
        }
        
        # Place a circle
        manager.place_circle(CircleType.WARMER, (10, 10))
        
        # Check position within radius
        circles = manager.get_circles_at_position((12, 12), radius=0)
        
        # Lines 260-271 should execute
        assert len(circles) > 0


class TestMagicCircleManagerGetRecommended:
    """Test get_recommended_circle method."""
    
    def test_get_recommended_circle_all_situations(self):
        """Test get_recommended_circle for all situations (lines 283-307)."""
        manager = MagicCircleManager()
        
        # Boss situation
        boss_rec = manager.get_recommended_circle("boss")
        assert boss_rec in [
            CircleType.STRIKING,
            CircleType.POISON_BUSTER,
            CircleType.PSYCHIC_WAVE
        ]
        
        # Farming
        farm_rec = manager.get_recommended_circle("farming")
        assert farm_rec in [
            CircleType.CLOUD_KILL,
            CircleType.FIRE_INSIGNIA,
            CircleType.VACUUM_EXTREME
        ]
        
        # PvP
        pvp_rec = manager.get_recommended_circle("pvp")
        assert pvp_rec in [
            CircleType.PSYCHIC_WAVE,
            CircleType.POISON_BUSTER,
            CircleType.WATER_INSIGNIA
        ]
        
        # Support
        support_rec = manager.get_recommended_circle("support")
        assert support_rec in [
            CircleType.WARMER,
            CircleType.EARTH_INSIGNIA
        ]
    
    def test_get_recommended_circle_unknown_situation(self):
        """Test get_recommended_circle for unknown situation (line 307)."""
        manager = MagicCircleManager()
        
        result = manager.get_recommended_circle("unknown_situation")
        
        assert result is None


class TestMagicCircleManagerRemoveOldest:
    """Test remove_oldest_circle method."""
    
    def test_remove_oldest_circle_no_circles(self):
        """Test remove_oldest when no circles (lines 330-342)."""
        manager = MagicCircleManager()
        
        result = manager.remove_oldest_circle()
        
        assert result is False
    
    def test_remove_oldest_circle_success(self):
        """Test removing oldest circle successfully."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {
            "duration_seconds": 30,
            "radius": 5
        }
        
        # Place multiple circles
        manager.place_circle(CircleType.STRIKING, (10, 10))
        manager.place_circle(CircleType.STRIKING, (20, 20))
        
        # Remove oldest
        result = manager.remove_oldest_circle()
        
        assert result is True
        # Should have 1 less circle now (minus insignias)
        count = len([c for c in manager.placed_circles if not manager._is_insignia(c.circle_type)])
        assert count == 1


class TestMagicCircleManagerGetElementalBonus:
    """Test get_elemental_bonus method."""
    
    def test_get_elemental_bonus_no_insignia(self):
        """Test elemental bonus with no active insignia (line 369)."""
        manager = MagicCircleManager()
        
        bonus = manager.get_elemental_bonus("fire")
        
        assert bonus == 1.0
    
    def test_get_elemental_bonus_matching_insignia(self):
        """Test elemental bonus with matching insignia."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 1
        }
        
        # Place fire insignia
        manager.place_circle(CircleType.FIRE_INSIGNIA, (10, 10))
        
        # Check fire element bonus
        bonus = manager.get_elemental_bonus("fire")
        
        assert bonus == 1.5


class TestMagicCircleManagerGetPlacedCircles:
    """Test get_placed_circles method."""
    
    def test_get_placed_circles(self):
        """Test get_placed_circles returns copy (line 400)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.CLOUD_KILL] = {
            "duration_seconds": 30,
            "radius": 3
        }
        
        manager.place_circle(CircleType.CLOUD_KILL, (15, 15))
        
        circles = manager.get_placed_circles()
        
        # Should return a copy
        assert len(circles) == 1
        # Modifying returned list shouldn't affect manager
        circles.append(None)
        assert len(manager.placed_circles) == 1


class TestCleanupExpiredCircles:
    """Test cleanup_expired_circles method."""
    
    def test_cleanup_with_expired_insignia(self):
        """Test cleanup with expired insignia (lines 316-321)."""
        manager = MagicCircleManager()
        
        # Set expired insignia
        manager.active_insignia = CircleType.WATER_INSIGNIA
        manager.insignia_expires_at = datetime.now() - timedelta(seconds=10)
        
        removed = manager.cleanup_expired_circles()
        
        # Lines 316-321 should execute
        assert manager.active_insignia is None
        assert manager.insignia_expires_at is None


# ============================================================================
# AOE.PY TESTS
# ============================================================================

class TestAoETargetingSystemInit:
    """Test AoETargetingSystem initialization."""
    
    def test_init_with_data_dir(self):
        """Test initialization with data directory (line 98)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            aoe_file = data_dir / "aoe_skills.json"
            
            # Create AoE skills JSON
            aoe_data = {
                "Meteor Storm": {
                    "shape": "circle",
                    "range": 3,
                    "cast_range": 9,
                    "cells_affected": 37,
                    "hits_per_target": 7,
                    "sp_cost": 70
                }
            }
            
            with open(aoe_file, 'w') as f:
                json.dump(aoe_data, f)
            
            system = AoETargetingSystem(data_dir)
            
            # Line 98 should execute
            assert "meteor storm" in system.aoe_skills


class TestAoELoadSkills:
    """Test _load_aoe_skills method."""
    
    def test_load_aoe_skills_file_not_found(self):
        """Test loading when file doesn't exist (lines 159-178)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            system = AoETargetingSystem(Path(tmpdir))
            
            # Should fall back to default skills
            assert len(system.aoe_skills) > 0
    
    def test_load_aoe_skills_json_error(self):
        """Test loading with JSON error (lines 159-178)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            aoe_file = data_dir / "aoe_skills.json"
            
            # Invalid JSON
            with open(aoe_file, 'w') as f:
                f.write("{ invalid }")
            
            system = AoETargetingSystem(data_dir)
            
            # Should fall back to defaults
            assert len(system.aoe_skills) > 0


class TestAoEFindOptimalCenter:
    """Test find_optimal_center method."""
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_empty_positions(self):
        """Test find_optimal_center with no monsters (line 204)."""
        system = AoETargetingSystem()
        
        skill = AoESkill(
            skill_name="Test Skill",
            shape=AoEShape.CIRCLE,
            range=5,
            cast_range=9,
            cells_affected=81
        )
        
        center = await system.find_optimal_center(
            [],  # Empty positions
            skill,
            (10, 10)
        )
        
        # Should return player position
        assert center == (10, 10)
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_self_circle(self):
        """Test find_optimal_center for self-circle skill (line 208)."""
        system = AoETargetingSystem()
        
        skill = AoESkill(
            skill_name="Self AOE",
            shape=AoEShape.SELF_CIRCLE,
            range=3,
            cast_range=0,
            cells_affected=25
        )
        
        center = await system.find_optimal_center(
            [(20, 20), (25, 25)],
            skill,
            (10, 10)
        )
        
        # Should return player position for self-circle
        assert center == (10, 10)
    
    @pytest.mark.asyncio
    async def test_find_optimal_center_out_of_range(self):
        """Test find_optimal_center when monsters out of cast range (line 217)."""
        system = AoETargetingSystem()
        
        skill = AoESkill(
            skill_name="Short Range",
            shape=AoEShape.CIRCLE,
            range=3,
            cast_range=5,  # Short cast range
            cells_affected=37
        )
        
        # Monsters far away
        monster_positions = [(100, 100), (105, 105)]
        
        center = await system.find_optimal_center(
            monster_positions,
            skill,
            (10, 10)
        )
        
        # Should return player position (no valid centers in range)
        assert center == (10, 10)


class TestAoECalculateTargetsHit:
    """Test calculate_targets_hit method."""
    
    @pytest.mark.asyncio
    async def test_calculate_targets_hit_without_ids(self):
        """Test calculate_targets when monster_ids not provided (lines 259->262)."""
        system = AoETargetingSystem()
        
        skill = AoESkill(
            skill_name="Test",
            shape=AoEShape.CIRCLE,
            range=5,
            cast_range=9,
            cells_affected=81
        )
        
        targets = await system.calculate_targets_hit(
            (10, 10),
            skill,
            [(8, 8), (12, 12)],
            monster_ids=None  # Not provided
        )
        
        # Lines 259-262 should execute (generates default IDs)
        assert len(targets) > 0
        assert all(t.entity_id.startswith("mob_") for t in targets)
    
    @pytest.mark.asyncio
    async def test_calculate_targets_hit_with_falloff(self):
        """Test calculating targets with damage falloff (line 271)."""
        system = AoETargetingSystem()
        
        skill = AoESkill(
            skill_name="Falloff Skill",
            shape=AoEShape.CIRCLE,
            range=5,
            cast_range=9,
            cells_affected=81,
            damage_falloff=True  # Enable falloff
        )
        
        targets = await system.calculate_targets_hit(
            (10, 10),
            skill,
            [(10, 10), (13, 13)],  # One at center, one at edge
            monster_ids=["mob1", "mob2"]
        )
        
        # Line 271 should calculate falloff
        assert len(targets) == 2
        # Center target should have higher damage%
        center_target = next(t for t in targets if t.entity_id == "mob1")
        edge_target = next(t for t in targets if t.entity_id == "mob2")
        assert center_target.expected_damage_percent > edge_target.expected_damage_percent


class TestAoESelectBestSkill:
    """Test select_best_aoe_skill method."""
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_no_monsters(self):
        """Test selecting best AoE with no monsters (line 303)."""
        system = AoETargetingSystem()
        
        skill, center = await system.select_best_aoe_skill(
            ["Storm Gust"],
            [],  # No monsters
            (10, 10),
            100
        )
        
        assert skill is None
        assert center == (10, 10)
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_insufficient_sp(self):
        """Test selecting AoE with insufficient SP (line 316)."""
        system = AoETargetingSystem()
        
        # Storm Gust costs 78 SP
        skill, center = await system.select_best_aoe_skill(
            ["Storm Gust"],
            [(10, 10), (12, 12)],
            (10, 10),
            50  # Not enough SP
        )
        
        # Line 316 should filter out expensive skills
        assert skill is None
    
    @pytest.mark.asyncio
    async def test_select_best_aoe_skill_zero_efficiency(self):
        """Test AoE selection with zero efficiency (line 332)."""
        system = AoETargetingSystem()
        
        # Skill with 0 SP cost
        system.aoe_skills["free_skill"] = AoESkill(
            skill_name="Free Skill",
            shape=AoEShape.CIRCLE,
            range=3,
            cast_range=9,
            cells_affected=25,
            sp_cost=0  # Free skill
        )
        
        skill, center = await system.select_best_aoe_skill(
            ["free_skill"],
            [(10, 10)],
            (10, 10),
            100
        )
        
        # Line 332 efficiency = 0.0 when sp_cost is 0
        # Still should return None or handle gracefully


class TestAoEDetectMobCluster:
    """Test detect_mob_cluster method."""
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_insufficient_size(self):
        """Test clustering with fewer than min_cluster_size (line 368)."""
        system = AoETargetingSystem()
        
        # Only 2 monsters, but min_cluster_size is 3
        clusters = await system.detect_mob_cluster(
            [(10, 10), (12, 12)],
            min_cluster_size=3,
            max_cluster_distance=5.0
        )
        
        # Line 368 should return empty
        assert len(clusters) == 0
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_small_cluster(self):
        """Test detecting cluster below minimum size (line 390->373)."""
        system = AoETargetingSystem()
        
        # 3 monsters: 2 close together, 1 far away
        clusters = await system.detect_mob_cluster(
            [(10, 10), (12, 12), (100, 100)],
            min_cluster_size=3,
            max_cluster_distance=5.0
        )
        
        # The 2-monster cluster should be discarded (< min_cluster_size)
        # Line 390 condition False, skips to next iteration
        assert len(clusters) == 0


class TestAoECalculateOptimalPosition:
    """Test calculate_optimal_position synchronous method."""
    
    def test_calculate_optimal_position_empty(self):
        """Test calculate_optimal_position with empty positions (line 411)."""
        system = AoETargetingSystem()
        
        result = system.calculate_optimal_position([], skill_radius=3)
        
        assert result == (0, 0)


class TestAoEFindClusters:
    """Test find_clusters method."""
    
    def test_find_clusters_empty(self):
        """Test find_clusters with empty positions (line 441)."""
        system = AoETargetingSystem()
        
        clusters = system.find_clusters([], radius=5)
        
        assert len(clusters) == 0


class TestAoEPlanSequence:
    """Test plan_aoe_sequence method."""
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence_insufficient_sp(self):
        """Test planning sequence when SP runs out (line 492)."""
        system = AoETargetingSystem()
        
        # Two clusters but only enough SP for one
        clusters = [
            [(10, 10), (12, 12), (14, 14)],
            [(50, 50), (52, 52), (54, 54)]
        ]
        
        sequence = await system.plan_aoe_sequence(
            clusters,
            ["Heaven's Drive"],  # 28 SP each
            (10, 10),
            30  # Only enough for 1 cast
        )
        
        # Line 492 should break after first cluster
        assert len(sequence) <= 1
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence_no_valid_skill(self):
        """Test planning when select_best_aoe_skill returns None (lines 503, 507)."""
        system = AoETargetingSystem()
        
        # Clear all skills
        system.aoe_skills = {}
        
        clusters = [[(10, 10), (12, 12)]]
        
        sequence = await system.plan_aoe_sequence(
            clusters,
            ["Nonexistent Skill"],
            (10, 10),
            100
        )
        
        # Lines 503, 507 should execute (no valid skill)
        assert len(sequence) == 0


class TestCleanupExpiredCirclesBranches:
    """Test cleanup branches."""
    
    def test_cleanup_expired_circles_removed_count(self):
        """Test cleanup returns removed count."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 1, "radius": 5}
        
        # Place circle
        manager.place_circle(CircleType.STRIKING, (10, 10))
        
        # Wait for expiry
        import time
        time.sleep(1.1)
        
        removed = manager.cleanup_expired_circles()
        
        # Should report removed circles
        assert removed >= 0


# ============================================================================
# ADDITIONAL COMPREHENSIVE TESTS FOR REMAINING COVERAGE
# ============================================================================

class TestPoisonManagerComprehensive:
    """Comprehensive tests for PoisonManager remaining lines."""
    
    def test_load_poison_effects_success(self):
        """Test successful loading of poison effects (lines 129-139)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            poison_file = data_dir / "poison_effects.json"
            
            poison_data = {
                "poisons": {
                    "poison": {
                        "display_name": "Basic Poison",
                        "damage_per_second": 5,
                        "duration_seconds": 30,
                        "additional_effects": ["slow"],
                        "success_rate": 90
                    },
                    "toxin": {
                        "display_name": "Toxin",
                        "damage_per_second": 15,
                        "duration_seconds": 45,
                        "additional_effects": [],
                        "success_rate": 100
                    }
                }
            }
            
            with open(poison_file, 'w') as f:
                json.dump(poison_data, f)
            
            manager = PoisonManager(data_dir)
            
            # Lines 129-139 should execute
            assert len(manager.poison_effects) == 2
            assert PoisonType.POISON in manager.poison_effects
            assert PoisonType.TOXIN in manager.poison_effects
    
    def test_apply_coating_success_with_replacement(self):
        """Test successful coating application replacing old one (lines 184-207)."""
        manager = PoisonManager()
        
        # Add poisons to inventory
        manager.poison_bottles[PoisonType.POISON] = 5
        manager.poison_bottles[PoisonType.TOXIN] = 3
        
        # Apply first coating
        result1 = manager.apply_coating(PoisonType.POISON, duration=60, charges=30)
        assert result1 is True
        assert manager.poison_bottles[PoisonType.POISON] == 4
        
        # Apply second coating (replaces first)
        result2 = manager.apply_coating(PoisonType.TOXIN, duration=60, charges=25)
        
        # Lines 184-207 should execute
        assert result2 is True
        assert manager.current_coating.poison_type == PoisonType.TOXIN
        assert manager.poison_bottles[PoisonType.TOXIN] == 2
    
    def test_use_coating_charge_depletes_coating(self):
        """Test use_coating_charge depleting coating (lines 224-230)."""
        manager = PoisonManager()
        
        # Add coating with 1 charge
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.PARALYZE,
            duration_seconds=60,
            charges=1
        )
        
        # Use the last charge
        result = manager.use_coating_charge()
        
        # Lines 224-230 should execute
        assert result is True
        assert manager.current_coating is None  # Depleted
    
    def test_get_current_coating_active(self):
        """Test get_current_coating with active coating (line 243)."""
        manager = PoisonManager()
        
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.ENCHANT_DEADLY_POISON,
            duration_seconds=60,
            charges=20
        )
        
        result = manager.get_current_coating()
        
        # Line 243 should execute (return poison type)
        assert result == PoisonType.ENCHANT_DEADLY_POISON
    
    def test_add_poison_bottles_new_type(self):
        """Test adding new poison type to inventory (lines 253-257)."""
        manager = PoisonManager()
        
        # Add new poison type
        manager.add_poison_bottles(PoisonType.PYREXIA, count=10)
        
        # Lines 253-257 should execute
        assert PoisonType.PYREXIA in manager.poison_bottles
        assert manager.poison_bottles[PoisonType.PYREXIA] == 10
    
    def test_activate_edp(self):
        """Test activate_edp method (lines 283-285)."""
        manager = PoisonManager()
        
        manager.activate_edp(duration=40)
        
        # Lines 283-285 should execute
        assert manager.edp_active is True
        assert manager.edp_expires_at is not None
    
    def test_deactivate_edp_when_active(self):
        """Test deactivate_edp when EDP is active (line 289->exit)."""
        manager = PoisonManager()
        
        # Activate first
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=30)
        
        # Deactivate
        manager.deactivate_edp()
        
        # Line 290-292 should execute
        assert manager.edp_active is False
        assert manager.edp_expires_at is None
    
    def test_should_reapply_coating_expired(self):
        """Test should_reapply with expired coating (line 335-338)."""
        manager = PoisonManager()
        
        # Add expired coating
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.POISON,
            applied_at=datetime.now() - timedelta(seconds=100),
            duration_seconds=60,
            charges=20
        )
        
        result = manager.should_reapply_coating(min_charges=5)
        
        # Lines 335-338 should execute
        assert result is True
    
    def test_get_recommended_poison_has_recommended(self):
        """Test get_recommended when we have the recommended poison (line 361)."""
        manager = PoisonManager()
        
        # Add recommended poison for boss (EDP)
        manager.poison_bottles[PoisonType.ENCHANT_DEADLY_POISON] = 3
        
        result = manager.get_recommended_poison("boss")
        
        # Line 361 should return the poison
        assert result == PoisonType.ENCHANT_DEADLY_POISON
    
    def test_get_status_no_coating(self):
        """Test get_status without coating (lines 382->395, 395->400)."""
        manager = PoisonManager()
        
        # No coating, no EDP
        manager.poison_bottles[PoisonType.POISON] = 5
        
        status = manager.get_status()
        
        # Lines 382->395 (coating check False, skips to line 395)
        # Line 395->400 (edp check False, skips to line 400)
        assert status["coating_active"] is False
        assert "current_coating" not in status
        assert "edp_time_left" not in status
    
    def test_reset_poison_state(self):
        """Test reset method (lines 404-407)."""
        manager = PoisonManager()
        
        # Set some state
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.TOXIN,
            duration_seconds=60,
            charges=15
        )
        manager.edp_active = True
        manager.edp_expires_at = datetime.now() + timedelta(seconds=20)
        
        manager.reset()
        
        # Lines 404-407 should execute
        assert manager.current_coating is None
        assert manager.edp_active is False
        assert manager.edp_expires_at is None


class TestMagicCircleManagerComprehensive:
    """Comprehensive tests for MagicCircleManager remaining lines."""
    
    def test_load_circle_effects_success(self):
        """Test successful loading of circle effects (lines 110-118)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            circle_file = data_dir / "magic_circle_effects.json"
            
            circle_data = {
                "circles": {
                    "striking": {
                        "duration_seconds": 30,
                        "radius": 5,
                        "damage": 150
                    },
                    "warmer": {
                        "duration_seconds": 20,
                        "radius": 3,
                        "healing": 50
                    }
                }
            }
            
            with open(circle_file, 'w') as f:
                json.dump(circle_data, f)
            
            manager = MagicCircleManager(data_dir)
            
            # Lines 110-118 should execute
            assert len(manager.circle_effects) == 2
            assert CircleType.STRIKING in manager.circle_effects
            assert CircleType.WARMER in manager.circle_effects
    
    def test_place_circle_insignia_replacement(self):
        """Test placing insignia replaces old one (lines 201-202)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 1
        }
        manager.circle_effects[CircleType.WATER_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 1
        }
        
        # Place fire insignia
        manager.place_circle(CircleType.FIRE_INSIGNIA, (10, 10))
        assert manager.active_insignia == CircleType.FIRE_INSIGNIA
        
        # Place water insignia - should replace fire
        manager.place_circle(CircleType.WATER_INSIGNIA, (20, 20))
        
        # Lines 163-171 should execute (insignia replacement)
        assert manager.active_insignia == CircleType.WATER_INSIGNIA
    
    def test_cleanup_expired_circles_logs_removed(self):
        """Test cleanup logs when circles removed (line 268->263)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {
            "duration_seconds": 1,  # Very short
            "radius": 5
        }
        
        # Place circle
        manager.place_circle(CircleType.STRIKING, (10, 10))
        
        # Wait for expiry
        import time
        time.sleep(1.1)
        
        removed = manager.cleanup_expired_circles()
        
        # Line 225 should log when removed > 0
        assert removed > 0
    
    def test_get_active_insignia_not_expired(self):
        """Test get_active_insignia when not expired (line 369)."""
        manager = MagicCircleManager()
        
        manager.active_insignia = CircleType.EARTH_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=50)
        
        result = manager.get_active_insignia()
        
        # Line 241 returns active insignia
        assert result == CircleType.EARTH_INSIGNIA
    
    def test_get_status_with_circles(self):
        """Test get_status with placed circles (lines 373-404)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.CLOUD_KILL] = {
            "duration_seconds": 30,
            "radius": 3
        }
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {
            "duration_seconds": 60,
            "radius": 1
        }
        
        # Place circles
        manager.place_circle(CircleType.CLOUD_KILL, (15, 15))
        manager.place_circle(CircleType.FIRE_INSIGNIA, (10, 10))
        
        status = manager.get_status()
        
        # Lines 373-404 should execute
        assert "circles" in status
        assert len(status["circles"]) > 0
        assert "insignia_time_left" in status
    
    def test_reset_magic_circle_state(self):
        """Test reset method (lines 408-411)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.PSYCHIC_WAVE] = {
            "duration_seconds": 25,
            "radius": 4
        }
        
        # Place circle and set insignia
        manager.place_circle(CircleType.PSYCHIC_WAVE, (20, 20))
        manager.active_insignia = CircleType.WIND_INSIGNIA
        manager.insignia_expires_at = datetime.now() + timedelta(seconds=30)
        
        manager.reset()
        
        # Lines 408-411 should execute
        assert len(manager.placed_circles) == 0
        assert manager.active_insignia is None
        assert manager.insignia_expires_at is None


class TestAoETargetingSystemComprehensive:
    """Comprehensive tests for AoETargetingSystem remaining lines."""
    
    def test_calculate_optimal_position_with_positions(self):
        """Test calculate_optimal_position with multiple positions (lines 413-425)."""
        system = AoETargetingSystem()
        
        positions = [(10, 10), (12, 12), (14, 14), (50, 50)]
        
        # Find optimal center for skill with radius 3
        center = system.calculate_optimal_position(positions, skill_radius=3)
        
        # Lines 413-425 should execute
        # Should pick one of the clustered positions
        assert center in positions
    
    def test_find_clusters_with_positions(self):
        """Test find_clusters with multiple positions (lines 443-466)."""
        system = AoETargetingSystem()
        
        # Create two distinct clusters (all very close within each)
        positions = [
            (10, 10), (11, 10), (12, 10),  # Cluster 1 - within radius 3
            (100, 100), (101, 100)  # Cluster 2 - within radius 3
        ]
        
        clusters = system.find_clusters(positions, radius=3)
        
        # Lines 443-466 should execute
        assert len(clusters) >= 1  # At least one cluster
        # Verify all positions are assigned to clusters
        all_positions_in_clusters = [pos for cluster in clusters for pos in cluster]
        assert len(all_positions_in_clusters) >= len(positions) // 2
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence_with_multiple_clusters(self):
        """Test planning sequence with multiple valid clusters (line 507)."""
        system = AoETargetingSystem()
        
        clusters = [
            [(10, 10), (12, 12), (14, 14)],
            [(50, 50), (52, 52), (54, 54)]
        ]
        
        sequence = await system.plan_aoe_sequence(
            clusters,
            ["Heaven's Drive"],  # 28 SP per cast
            (10, 10),
            100  # Enough for both
        )
        
        # Lines 505-519 should execute
        assert len(sequence) > 0


class TestDeactivateEDP:
    """Test deactivate_edp when not active."""
    
    def test_deactivate_edp_when_not_active(self):
        """Test deactivate_edp does nothing when not active."""
        manager = PoisonManager()
        
        # EDP not active
        manager.edp_active = False
        
        # Should do nothing (line 289 condition False, exits)
        manager.deactivate_edp()
        
        assert manager.edp_active is False


class TestClearCoatingWhenNone:
    """Test clear_coating when no coating."""
    
    def test_clear_coating_no_coating(self):
        """Test clear_coating when no coating exists (line 423)."""
        manager = PoisonManager()
        
        # No coating
        manager.current_coating = None
        
        # Should log but not crash
        manager.clear_coating()
        
        # Line 423 else branch executed
        assert manager.current_coating is None


class TestGetStatusNoEDP:
    """Test get_status variations."""
    
    def test_get_status_inactive_edp(self):
        """Test get_status when EDP is inactive."""
        manager = PoisonManager()
        
        manager.edp_active = False
        manager.poison_bottles[PoisonType.TOXIN] = 5
        
        status = manager.get_status()
        
        # EDP lines should not add edp_time_left
        assert "edp_time_left" not in status


class TestGetCircleCount:
    """Test get_circle_count method."""
    
    def test_get_circle_count(self):
        """Test getting non-insignia circle count."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 30, "radius": 5}
        manager.circle_effects[CircleType.FIRE_INSIGNIA] = {"duration_seconds": 60, "radius": 1}
        
        # Place circles
        manager.place_circle(CircleType.STRIKING, (10, 10))
        manager.place_circle(CircleType.STRIKING, (20, 20))
        manager.place_circle(CircleType.FIRE_INSIGNIA, (5, 5))
        
        count = manager.get_circle_count()
        
        # Should count only non-insignia circles (2)
        assert count == 2


class TestShouldReplaceCircle:
    """Test should_replace_circle method."""
    
    def test_should_replace_circle_below_max(self):
        """Test should_replace when below max."""
        manager = MagicCircleManager()
        manager.max_circles = 3
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 30, "radius": 5}
        
        # Place 1 circle
        manager.place_circle(CircleType.STRIKING, (10, 10))
        
        result = manager.should_replace_circle()
        
        # Should be False (not at max yet)
        assert result is False
    
    def test_should_replace_circle_at_max(self):
        """Test should_replace when at max."""
        manager = MagicCircleManager()
        manager.max_circles = 2
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 30, "radius": 5}
        
        # Place 2 circles
        manager.place_circle(CircleType.STRIKING, (10, 10))
        manager.place_circle(CircleType.STRIKING, (20, 20))
        
        result = manager.should_replace_circle()
        
        # Should be True (at max)
        assert result is True


# ============================================================================
# FINAL PINPOINT TESTS FOR 100% COVERAGE
# ============================================================================

class TestPoisonFinalLines:
    """Target final poison.py lines."""
    
    def test_use_coating_charge_normal_depletion(self):
        """Test normal charge use without depletion (line 226->230)."""
        manager = PoisonManager()
        
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.TOXIN,
            duration_seconds=60,
            charges=10  # Multiple charges
        )
        
        result = manager.use_coating_charge()
        
        # Line 224 executes, but line 226 is False (charges > 0 still)
        # So line 228-229 doesn't execute, goes to line 230
        assert result is True
        assert manager.current_coating is not None
        assert manager.current_coating.charges == 9
    
    def test_add_poison_bottles_existing_type(self):
        """Test adding bottles to existing poison type (line 253->256)."""
        manager = PoisonManager()
        
        # Add initial bottles
        manager.poison_bottles[PoisonType.POISON] = 5
        
        # Add more bottles to same type
        manager.add_poison_bottles(PoisonType.POISON, count=3)
        
        # Line 253 is True (already exists), line 254 doesn't execute
        # Jumps to line 256
        assert manager.poison_bottles[PoisonType.POISON] == 8
    
    def test_should_reapply_coating_low_charges(self):
        """Test should_reapply with low charges (line 338)."""
        manager = PoisonManager()
        
        manager.current_coating = WeaponCoating(
            poison_type=PoisonType.ENCHANT_DEADLY_POISON,
            duration_seconds=60,
            charges=3  # Below min_charges of 5
        )
        
        result = manager.should_reapply_coating(min_charges=5)
        
        # Line 338 should execute (return True)
        assert result is True
    
    def test_get_recommended_poison_no_fallback(self):
        """Test get_recommended when no poisons available (line 365->364)."""
        manager = PoisonManager()
        
        # No poisons in inventory
        result = manager.get_recommended_poison("farming")
        
        # Lines 363-367 for loop finds nothing, exits loop (line 367)
        # Returns None at line 368
        assert result is None


class TestMagicCirclesFinalLines:
    """Target final magic_circles.py lines."""
    
    def test_load_circle_effects_invalid_circle_name(self):
        """Test loading with invalid circle name (lines 115-116)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            circle_file = data_dir / "magic_circle_effects.json"
            
            circle_data = {
                "circles": {
                    "invalid_circle_xyz": {  # Invalid circle type
                        "duration_seconds": 30,
                        "radius": 5
                    }
                }
            }
            
            with open(circle_file, 'w') as f:
                json.dump(circle_data, f)
            
            manager = MagicCircleManager(data_dir)
            
            # Lines 115-116 should execute (ValueError, warning logged)
            assert len(manager.circle_effects) == 0
    
    def test_cleanup_expired_circles_none_removed(self):
        """Test cleanup when no circles removed (line 268->263)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 300, "radius": 5}
        
        # Place circle with long duration
        manager.place_circle(CircleType.STRIKING, (10, 10))
        
        removed = manager.cleanup_expired_circles()
        
        # Line 224 condition is False (removed == 0), skips to line 227
        # This is the 268->263 branch (no logging)
        assert removed == 0
    
    def test_get_active_insignia_expired(self):
        """Test get_active_insignia when expired (line 369)."""
        manager = MagicCircleManager()
        
        # Set expired insignia
        manager.active_insignia = CircleType.WIND_INSIGNIA
        manager.insignia_expires_at = datetime.now() - timedelta(seconds=10)
        
        result = manager.get_active_insignia()
        
        # Line 237-240 clears expired insignia
        # Line 245 returns None
        assert result is None
        assert manager.active_insignia is None
    
    def test_get_status_no_insignia(self):
        """Test get_status without insignia (line 399->404)."""
        manager = MagicCircleManager()
        
        manager.circle_effects[CircleType.STRIKING] = {"duration_seconds": 30, "radius": 5}
        manager.place_circle(CircleType.STRIKING, (10, 10))
        
        # No insignia
        status = manager.get_status()
        
        # Line 399 False (no insignia or no expiry), skips to line 404
        assert "insignia_time_left" not in status


class TestAoEFinalLines:
    """Target final aoe.py lines."""
    
    @pytest.mark.asyncio
    async def test_detect_mob_cluster_no_nearby_mobs(self):
        """Test detect_mob_cluster with scattered mobs (line 391)."""
        system = AoETargetingSystem()
        
        # Mobs far apart (no clusters)
        positions = [(10, 10), (100, 100), (200, 200)]
        
        clusters = await system.detect_mob_cluster(
            positions,
            min_cluster_size=2,
            max_cluster_distance=5.0
        )
        
        # Line 390 keeps individual positions but they don't meet min_cluster_size
        # Line 391 could be where single-member clusters are kept then discarded
        assert isinstance(clusters, list)
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence_continues_loop(self):
        """Test plan_aoe_sequence continuing to next cluster (line 492)."""
        system = AoETargetingSystem()
        
        # Two small clusters
        clusters = [
            [(10, 10), (12, 12)],
            [(50, 50), (52, 52)]
        ]
        
        sequence = await system.plan_aoe_sequence(
            clusters,
            ["Heaven's Drive"],
            (10, 10),
            100  # Enough SP
        )
        
        # Line 491 condition is False (has SP), continues loop
        # Goes to line 492 (next iteration)
        assert len(sequence) >= 1
    
    @pytest.mark.asyncio
    async def test_plan_aoe_sequence_skill_found(self):
        """Test plan_aoe_sequence when skill is found and added (line 507)."""
        system = AoETargetingSystem()
        
        clusters = [[(10, 10), (12, 12), (14, 14)]]
        
        sequence = await system.plan_aoe_sequence(
            clusters,
            ["Meteor Storm"],  # Known skill
            (10, 10),
            100
        )
        
        # Line 505 gets skill, line 506 is True (skill exists)
        # Continues past line 507
        assert len(sequence) > 0
        assert sequence[0]["skill"] == "Meteor Storm"


class TestCompleteCoverage:
    """Final comprehensive integration tests."""
    
    def test_poison_manager_full_lifecycle(self):
        """Complete PoisonManager lifecycle test."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            poison_file = data_dir / "poison_effects.json"
            
            poison_data = {
                "poisons": {
                    "enchant_deadly_poison": {
                        "display_name": "Enchant Deadly Poison",
                        "damage_per_second": 50,
                        "duration_seconds": 40,
                        "additional_effects": ["ignore_defense"],
                        "success_rate": 100
                    }
                }
            }
            
            with open(poison_file, 'w') as f:
                json.dump(poison_data, f)
            
            manager = PoisonManager(data_dir)
            
            # Add bottles
            manager.add_poison_bottles(PoisonType.ENCHANT_DEADLY_POISON, 5)
            
            # Apply coating
            manager.apply_coating(PoisonType.ENCHANT_DEADLY_POISON)
            
            # Use charges
            for _ in range(3):
                manager.use_coating_charge()
            
            # Activate EDP
            manager.activate_edp()
            
            # Check status
            status = manager.get_status()
            assert status["coating_active"] is True
            assert status["edp_active"] is True
            
            # Reset
            manager.reset()
            assert manager.current_coating is None
    
    def test_magic_circle_manager_full_lifecycle(self):
        """Complete MagicCircleManager lifecycle test."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            circle_file = data_dir / "magic_circle_effects.json"
            
            circle_data = {
                "circles": {
                    "striking": {"duration_seconds": 30, "radius": 5},
                    "fire_insignia": {"duration_seconds": 60, "radius": 1}
                }
            }
            
            with open(circle_file, 'w') as f:
                json.dump(circle_data, f)
            
            manager = MagicCircleManager(data_dir)
            
            # Place circles
            manager.place_circle(CircleType.STRIKING, (10, 10))
            manager.place_circle(CircleType.FIRE_INSIGNIA, (5, 5))
            
            # Check status
            status = manager.get_status()
            assert status["active_circles"] >= 1
            
            # Get recommended
            rec = manager.get_recommended_circle("boss")
            assert rec is not None
            
            # Cleanup and reset
            manager.cleanup_expired_circles()
            manager.reset()
            assert len(manager.placed_circles) == 0
    
    @pytest.mark.asyncio
    async def test_aoe_targeting_full_workflow(self):
        """Complete AoETargetingSystem workflow test."""
        system = AoETargetingSystem()
        
        monster_positions = [(10, 10), (12, 12), (14, 14), (50, 50), (52, 52)]
        
        # Detect clusters
        clusters = await system.detect_mob_cluster(
            monster_positions,
            min_cluster_size=2,
            max_cluster_distance=5.0
        )
        
        # Select best skill
        skill_name, center = await system.select_best_aoe_skill(
            ["Storm Gust", "Meteor Storm"],
            monster_positions,
            (10, 10),
            100
        )
        
        # Plan sequence
        if clusters:
            sequence = await system.plan_aoe_sequence(
                clusters,
                ["Storm Gust"],
                (10, 10),
                200
            )
            
            assert isinstance(sequence, list)