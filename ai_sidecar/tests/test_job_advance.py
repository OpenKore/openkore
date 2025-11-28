"""
Unit tests for job advancement system.

Tests:
- Job path validation
- NPC location loading
- Requirements checking
- Job selection logic
- Path continuity validation
"""

import pytest
from pathlib import Path
import tempfile
import json

from ai_sidecar.progression.job_advance import (
    JobAdvancementSystem,
    JobPath,
    JobNPCLocation,
    JobRequirements
)
from ai_sidecar.progression.lifecycle import LifecycleState
from ai_sidecar.core.state import CharacterState, GameState


class TestJobPathLoading:
    """Test job path data loading."""
    
    def test_load_job_paths_from_file(self):
        """Test loading job paths from JSON file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create minimal job paths file
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 0,
                        "job_name": "Novice",
                        "from_job": None,
                        "job_tier": 1,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 1,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Swordman"]
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            # Should have loaded Novice job
            assert "Novice" in system._job_paths
            assert system._job_paths["Novice"].job_id == 0
    
    def test_load_npc_locations_from_file(self):
        """Test loading NPC locations from JSON file."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            npc_data = {
                "Swordman": {
                    "map_name": "izlude",
                    "x": 53,
                    "y": 137,
                    "npc_name": "Swordman Guildsman"
                }
            }
            
            job_paths.write_text('{"jobs": []}', encoding="utf-8")
            job_npcs.write_text(json.dumps(npc_data), encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            assert "Swordman" in system._npc_locations
            assert system._npc_locations["Swordman"].map_name == "izlude"


class TestJobPathQueries:
    """Test job path query methods."""
    
    def test_get_next_job_options(self):
        """Test getting available job advancement options."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Knight", "Crusader"]
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            options = system.get_next_job_options("Swordman")
            assert set(options) == {"Knight", "Crusader"}
    
    def test_get_next_job_options_unknown_class(self):
        """Test query for unknown job returns empty list."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            job_paths.write_text('{"jobs": []}', encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            options = system.get_next_job_options("UnknownJob")
            assert options == []


class TestRequirementsChecking:
    """Test job advancement requirement validation."""
    
    def test_check_requirements_all_met(self):
        """Test requirements check when all conditions met."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": True,
                            "test_type": "combat_test"
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            # Character meets all requirements
            char = CharacterState(
                base_level=50,
                job_level=40,
                zeny=10000
            )
            
            met, missing = system.check_requirements("Knight", char)
            assert met is True
            assert missing == []
    
    def test_check_requirements_level_insufficient(self):
        """Test requirements check when levels too low."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 5000,
                            "test_required": False
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            # Character below requirements
            char = CharacterState(
                base_level=40,  # Need 50
                job_level=30,   # Need 40
                zeny=1000       # Need 5000
            )
            
            met, missing = system.check_requirements("Knight", char)
            assert met is False
            assert len(missing) == 3  # All 3 requirements missing


class TestJobSelection:
    """Test automatic job selection logic."""
    
    def test_select_with_preference(self):
        """Test job selection respects user preferences."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Knight", "Crusader"]
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            # Create system with preference for Crusader
            preferences = {"Swordman": "Crusader"}
            system = JobAdvancementSystem(job_paths, job_npcs, preferred_path=preferences)
            
            char = CharacterState()
            selected = system.select_next_job("Swordman", char)
            
            assert selected == "Crusader"
    
    def test_select_single_option(self):
        """Test selection when only one option available."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Lord Knight"]
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            char = CharacterState()
            selected = system.select_next_job("Knight", char)
            
            assert selected == "Lord Knight"


class TestJobPathValidation:
    """Test job path data validation."""
    
    def test_validate_path_continuity_valid(self):
        """Test validation passes for valid job paths."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 0,
                        "job_name": "Novice",
                        "from_job": None,
                        "job_tier": 1,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 1,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Swordman"]
                    },
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            errors = system.validate_job_path_continuity()
            assert errors == []
    
    def test_validate_path_continuity_broken(self):
        """Test validation detects broken references."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 0,
                        "job_name": "Novice",
                        "from_job": None,
                        "job_tier": 1,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 1,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["NonexistentJob"]  # Invalid reference
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            errors = system.validate_job_path_continuity()
            assert len(errors) > 0
            assert "NonexistentJob" in errors[0]


class TestJobAdvancementExecution:
    """Test job advancement action generation."""
    
    @pytest.mark.asyncio
    async def test_check_advancement_ready(self):
        """Test advancement check when character is ready."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            # Swordman can advance to Knight
            data = {
                "jobs": [
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Knight"]
                    },
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            npc_data = {
                "Knight": {
                    "map_name": "prt_in",
                    "x": 88,
                    "y": 101,
                    "npc_name": "Knight Guildsman"
                }
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text(json.dumps(npc_data), encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            # Character ready for Knight
            char = CharacterState(
                job_class="Swordman",
                base_level=50,
                job_level=40,
                zeny=10000
            )
            
            actions = await system.check_advancement(char, LifecycleState.FIRST_JOB)
            
            # Should generate action for job advancement
            assert len(actions) > 0
            assert actions[0].extra["action_subtype"] == "job_advancement"
            assert actions[0].extra["target_job"] == "Knight"
    
    @pytest.mark.asyncio
    async def test_check_advancement_not_ready(self):
        """Test advancement check when character not ready."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Knight"]
                    },
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            # Character NOT ready (low levels)
            char = CharacterState(
                job_class="Swordman",
                base_level=30,  # Need 50
                job_level=25,   # Need 40
                zeny=0
            )
            
            actions = await system.check_advancement(char, LifecycleState.FIRST_JOB)
            
            # Should not generate actions
            assert len(actions) == 0


class TestJobSummary:
    """Test job path summary generation."""
    
    def test_get_job_path_summary(self):
        """Test getting summary of job progression options."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            data = {
                "jobs": [
                    {
                        "job_id": 1,
                        "job_name": "Swordman",
                        "from_job": "Novice",
                        "job_tier": 2,
                        "requirements": {
                            "base_level": 1,
                            "job_level": 10,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": ["Knight", "Crusader"]
                    },
                    {
                        "job_id": 7,
                        "job_name": "Knight",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": []
                    },
                    {
                        "job_id": 8,
                        "job_name": "Crusader",
                        "from_job": "Swordman",
                        "job_tier": 3,
                        "requirements": {
                            "base_level": 50,
                            "job_level": 40,
                            "zeny_cost": 0,
                            "test_required": False
                        },
                        "next_jobs": []
                    }
                ]
            }
            
            job_paths.write_text(json.dumps(data), encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            summary = system.get_job_path_summary("Swordman")
            
            assert summary["current_job"] == "Swordman"
            assert summary["job_tier"] == 2
            assert len(summary["next_jobs"]) == 2


class TestJobTestPlaceholders:
    """Test job test placeholder implementations."""
    
    @pytest.mark.asyncio
    async def test_hunting_test_placeholder(self):
        """Test hunting test returns placeholder result."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            job_paths.write_text('{"jobs": []}', encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            params = {"monster": "Poring", "count": 50}
            game_state = GameState()
            
            # Should return False (placeholder)
            result = await system.complete_job_test("hunting_quest", params, game_state)
            assert result is False
    
    @pytest.mark.asyncio
    async def test_unknown_test_type(self):
        """Test unknown test type returns False."""
        with tempfile.TemporaryDirectory() as tmpdir:
            job_paths = Path(tmpdir) / "job_paths.json"
            job_npcs = Path(tmpdir) / "job_npcs.json"
            
            job_paths.write_text('{"jobs": []}', encoding="utf-8")
            job_npcs.write_text("{}", encoding="utf-8")
            
            system = JobAdvancementSystem(job_paths, job_npcs)
            
            game_state = GameState()
            result = await system.complete_job_test("unknown_test", {}, game_state)
            
            assert result is False