"""
Comprehensive tests for progression/job_advance.py module
Target: Boost coverage from 49.46% to 90%+
"""

import json
import pytest
import tempfile
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.progression.job_advance import (
    JobAdvancementSystem,
    JobNPCLocation,
    JobRequirements,
    JobPath,
)
from ai_sidecar.core.state import CharacterState, GameState
from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.progression.lifecycle import LifecycleState


@pytest.fixture
def temp_job_paths_file():
    """Create temporary job paths file"""
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
                    "zeny_cost": 0
                },
                "next_jobs": ["Swordman", "Mage", "Thief"]
            },
            {
                "job_id": 1,
                "job_name": "Swordman",
                "from_job": "Novice",
                "job_tier": 2,
                "requirements": {
                    "base_level": 10,
                    "job_level": 10,
                    "zeny_cost": 0,
                    "test_required": False
                },
                "npc_location": {
                    "map_name": "izlude",
                    "x": 74,
                    "y": 172,
                    "npc_name": "Swordman Guildsman"
                },
                "next_jobs": ["Knight", "Crusader"]
            },
            {
                "job_id": 7,
                "job_name": "Knight",
                "from_job": "Swordman",
                "job_tier": 3,
                "requirements": {
                    "base_level": 40,
                    "job_level": 40,
                    "zeny_cost": 0,
                    "test_required": True,
                    "test_type": "combat_test"
                },
                "npc_location": {
                    "map_name": "prt_in",
                    "x": 88,
                    "y": 101,
                    "npc_name": "Knight Master"
                },
                "next_jobs": []
            }
        ]
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(data, f)
        temp_path = f.name
    
    yield Path(temp_path)
    
    try:
        Path(temp_path).unlink()
    except:
        pass


@pytest.fixture
def temp_npc_locations_file():
    """Create temporary NPC locations file"""
    data = {
        "Swordman": {
            "map_name": "izlude",
            "x": 74,
            "y": 172,
            "npc_name": "Swordman Guildsman"
        },
        "Mage": {
            "map_name": "geffen",
            "x": 66,
            "y": 175,
            "npc_name": "Mage Guildsman"
        }
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(data, f)
        temp_path = f.name
    
    yield Path(temp_path)
    
    try:
        Path(temp_path).unlink()
    except:
        pass


class TestJobAdvancementSystemInit:
    """Test JobAdvancementSystem initialization"""
    
    def test_init_loads_job_paths(self, temp_job_paths_file, temp_npc_locations_file):
        """Test initialization loads job paths successfully"""
        system = JobAdvancementSystem(
            temp_job_paths_file,
            temp_npc_locations_file
        )
        
        assert "Novice" in system._job_paths
        assert "Swordman" in system._job_paths
        assert "Knight" in system._job_paths
    
    def test_init_loads_npc_locations(self, temp_job_paths_file, temp_npc_locations_file):
        """Test initialization loads NPC locations"""
        system = JobAdvancementSystem(
            temp_job_paths_file,
            temp_npc_locations_file
        )
        
        assert "Swordman" in system._npc_locations
        assert "Mage" in system._npc_locations
    
    def test_init_with_preferred_path(self, temp_job_paths_file, temp_npc_locations_file):
        """Test initialization with preferred job path"""
        preferred = {"Novice": "Swordman", "Swordman": "Knight"}
        
        system = JobAdvancementSystem(
            temp_job_paths_file,
            temp_npc_locations_file,
            preferred_path=preferred
        )
        
        assert system.preferred_path == preferred
    
    def test_init_missing_files(self):
        """Test initialization with missing files"""
        system = JobAdvancementSystem(
            Path("/nonexistent/paths.json"),
            Path("/nonexistent/npcs.json")
        )
        
        # Should initialize with empty data, not crash
        assert len(system._job_paths) == 0
        assert len(system._npc_locations) == 0


class TestJobPathQueries:
    """Test job path query methods"""
    
    def test_get_current_job_path(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting current job path info"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        path = system.get_current_job_path("Swordman")
        
        assert path is not None
        assert path.job_name == "Swordman"
        assert path.job_tier == 2
    
    def test_get_current_job_path_unknown(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting path for unknown job"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        path = system.get_current_job_path("UnknownJob")
        
        assert path is None
    
    def test_get_next_job_options(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting next job options"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        options = system.get_next_job_options("Novice")
        
        assert len(options) == 3
        assert "Swordman" in options
        assert "Mage" in options
        assert "Thief" in options
    
    def test_get_next_job_options_terminal(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting next job options for terminal job"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        options = system.get_next_job_options("Knight")
        
        assert len(options) == 0


class TestSelectNextJob:
    """Test job selection logic"""
    
    def test_select_with_preference(self, temp_job_paths_file, temp_npc_locations_file):
        """Test selection uses user preference when available"""
        preferred = {"Novice": "Mage"}
        system = JobAdvancementSystem(
            temp_job_paths_file,
            temp_npc_locations_file,
            preferred_path=preferred
        )
        
        character = CharacterState(
            name="Test",
            base_level=10,
            job_level=10,
            job_class="Novice",
            str=10, agi=10, vit=10, int_stat=50, dex=10, luk=10
        )
        
        selected = system.select_next_job("Novice", character)
        
        assert selected == "Mage"
    
    def test_select_single_option(self, temp_job_paths_file, temp_npc_locations_file):
        """Test selection when only one option available"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=40,
            job_level=40,
            job_class="Swordman",
            str=50, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        # Manually set to single option for test
        system._job_paths["Swordman"].next_jobs = ["Knight"]
        
        selected = system.select_next_job("Swordman", character)
        
        assert selected == "Knight"
    
    def test_select_no_options(self, temp_job_paths_file, temp_npc_locations_file):
        """Test selection when no advancement available"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=99,
            job_level=70,
            job_class="Knight",
            str=50, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        selected = system.select_next_job("Knight", character)
        
        assert selected is None


class TestCheckRequirements:
    """Test requirement checking"""
    
    def test_check_requirements_all_met(self, temp_job_paths_file, temp_npc_locations_file):
        """Test when all requirements are met"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=15,
            job_level=15,
            job_class="Novice",
            zeny=1000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        met, missing = system.check_requirements("Swordman", character)
        
        assert met is True
        assert len(missing) == 0
    
    def test_check_requirements_low_base_level(self, temp_job_paths_file, temp_npc_locations_file):
        """Test when base level requirement not met"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=5,  # Need 10
            job_level=15,
            job_class="Novice",
            zeny=1000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        met, missing = system.check_requirements("Swordman", character)
        
        assert met is False
        assert any("Base level" in msg for msg in missing)
    
    def test_check_requirements_low_job_level(self, temp_job_paths_file, temp_npc_locations_file):
        """Test when job level requirement not met"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=15,
            job_level=5,  # Need 10
            job_class="Novice",
            zeny=1000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        met, missing = system.check_requirements("Swordman", character)
        
        assert met is False
        assert any("Job level" in msg for msg in missing)
    
    def test_check_requirements_insufficient_zeny(self, temp_job_paths_file, temp_npc_locations_file):
        """Test when zeny requirement not met"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        # Add zeny cost to Swordman job
        system._job_paths["Swordman"].requirements.zeny_cost = 10000
        
        character = CharacterState(
            name="Test",
            base_level=15,
            job_level=15,
            job_class="Novice",
            zeny=500,  # Not enough
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        met, missing = system.check_requirements("Swordman", character)
        
        assert met is False
        assert any("Zeny" in msg for msg in missing)
    
    def test_check_requirements_unknown_job(self, temp_job_paths_file, temp_npc_locations_file):
        """Test checking requirements for unknown job"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=99,
            job_level=70,
            job_class="Novice",
            zeny=100000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        met, missing = system.check_requirements("FakeJob", character)
        
        assert met is False
        assert any("Unknown job" in msg for msg in missing)


class TestCheckAdvancement:
    """Test async check_advancement method"""
    
    @pytest.mark.asyncio
    async def test_check_advancement_eligible(self, temp_job_paths_file, temp_npc_locations_file):
        """Test check when character is eligible for advancement"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=15,
            job_level=15,
            job_class="Novice",
            zeny=1000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        actions = await system.check_advancement(character, LifecycleState.NOVICE)
        
        assert len(actions) > 0
        action = actions[0]
        assert action.type == ActionType.NOOP
        assert action.extra["action_subtype"] == "job_advancement"
    
    @pytest.mark.asyncio
    async def test_check_advancement_not_eligible(self, temp_job_paths_file, temp_npc_locations_file):
        """Test check when character not eligible"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=5,  # Too low
            job_level=5,   # Too low
            job_class="Novice",
            zeny=0,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        actions = await system.check_advancement(character, LifecycleState.NOVICE)
        
        assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_check_advancement_wrong_state(self, temp_job_paths_file, temp_npc_locations_file):
        """Test check returns nothing in wrong lifecycle state"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="Test",
            base_level=99,
            job_level=70,
            job_class="Knight",
            zeny=100000,
            str=10, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        actions = await system.check_advancement(character, LifecycleState.THIRD_JOB)
        
        assert len(actions) == 0


class TestJobTestHandlers:
    """Test various job test handlers"""
    
    @pytest.mark.asyncio
    async def test_handle_hunting_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test hunting test when complete"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "monster": "Poring",
            "count": 10,
            "current_count": 10  # Complete!
        }
        
        game_state = Mock(spec=GameState)
        
        result = await system._handle_hunting_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_hunting_test_in_progress(self, temp_job_paths_file, temp_npc_locations_file):
        """Test hunting test when still in progress"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "monster": "Poring",
            "count": 10,
            "current_count": 5  # Still need 5 more
        }
        
        game_state = Mock(spec=GameState)
        game_state.combat_manager = Mock()
        
        result = await system._handle_hunting_test(params, game_state)
        
        assert result is False
        game_state.combat_manager.set_hunt_target.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_item_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test item collection test when complete"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "items": [
                {"item_id": 909, "quantity": 10},
                {"item_id": 914, "quantity": 5}
            ]
        }
        
        character = Mock(spec=CharacterState)
        character.inventory = [
            {"id": 909, "amount": 10},
            {"id": 914, "amount": 5}
        ]
        
        game_state = Mock(spec=GameState)
        game_state.character = character
        
        result = await system._handle_item_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_item_test_missing_items(self, temp_job_paths_file, temp_npc_locations_file):
        """Test item test when items missing"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "items": [
                {"item_id": 909, "quantity": 10}
            ]
        }
        
        character = Mock(spec=CharacterState)
        character.inventory = [
            {"id": 909, "amount": 3}  # Only 3/10
        ]
        
        game_state = Mock(spec=GameState)
        game_state.character = character
        game_state.farming_manager = Mock()
        
        result = await system._handle_item_test(params, game_state)
        
        assert result is False
        game_state.farming_manager.add_farm_target.assert_called()
    
    @pytest.mark.asyncio
    async def test_handle_mushroom_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test mushroom test when complete"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "mushroom_count": 6,
            "current_mushrooms": 6  # Complete!
        }
        
        game_state = Mock(spec=GameState)
        
        result = await system._handle_mushroom_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_mushroom_test_in_progress(self, temp_job_paths_file, temp_npc_locations_file):
        """Test mushroom test when still collecting"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "mushroom_count": 6,
            "current_mushrooms": 3,  # Need 3 more
            "maze_map": "job_thief1"
        }
        
        game_state = Mock(spec=GameState)
        game_state.navigation_manager = Mock()
        
        result = await system._handle_mushroom_test(params, game_state)
        
        assert result is False
        game_state.navigation_manager.execute_maze_navigation.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_undead_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test undead test when complete"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "undead_kills": 10,
            "current_kills": 10,  # Complete!
            "undead_type": "Zombie"
        }
        
        game_state = Mock(spec=GameState)
        
        result = await system._handle_undead_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_undead_test_in_progress(self, temp_job_paths_file, temp_npc_locations_file):
        """Test undead test when still hunting"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "undead_kills": 10,
            "current_kills": 4,  # Need 6 more
            "undead_type": "Zombie",
            "hunt_map": "pay_fild08"
        }
        
        game_state = Mock(spec=GameState)
        game_state.combat_manager = Mock()
        
        result = await system._handle_undead_test(params, game_state)
        
        assert result is False
        game_state.combat_manager.set_hunt_target.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_combat_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test combat test when complete"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "instance_map": "job_knight",
            "test_stage": 4,
            "max_stages": 3  # Past max
        }
        
        game_state = Mock(spec=GameState)
        
        result = await system._handle_combat_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_combat_test_in_progress(self, temp_job_paths_file, temp_npc_locations_file):
        """Test combat test when still in progress"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "instance_map": "job_knight",
            "test_stage": 2,
            "max_stages": 3,
            "strategy": "aggressive",
            "time_limit": 300
        }
        
        game_state = Mock(spec=GameState)
        game_state.combat_manager = Mock()
        
        result = await system._handle_combat_test(params, game_state)
        
        assert result is False
        game_state.combat_manager.enter_instance_combat.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_quiz_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test quiz test when all questions answered"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "question_number": 11,  # Past total
            "total_questions": 10
        }
        
        game_state = Mock(spec=GameState)
        
        result = await system._handle_quiz_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_quiz_test_answer_found(self, temp_job_paths_file, temp_npc_locations_file):
        """Test quiz test with known answer"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "question_number": 5,
            "total_questions": 10,
            "quiz_type": "mage",
            "question_text": "What does INT increase for mages?"
        }
        
        game_state = Mock(spec=GameState)
        game_state.dialogue_manager = Mock()
        
        result = await system._handle_quiz_test(params, game_state)
        
        assert result is False  # Quiz in progress
        game_state.dialogue_manager.select_option.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_handle_quiz_test_answer_not_found(self, temp_job_paths_file, temp_npc_locations_file):
        """Test quiz test with unknown question"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "question_number": 5,
            "total_questions": 10,
            "quiz_type": "mage",
            "question_text": "Unknown question that isn't in database"
        }
        
        game_state = Mock(spec=GameState)
        game_state.dialogue_manager = Mock()
        
        result = await system._handle_quiz_test(params, game_state)
        
        assert result is False
        # Should not call select_option since no answer found
        game_state.dialogue_manager.select_option.assert_not_called()
    
    @pytest.mark.asyncio
    async def test_handle_maze_test_complete(self, temp_job_paths_file, temp_npc_locations_file):
        """Test maze test when goal reached"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "maze_map": "job_hunter",
            "goal": {"x": 100, "y": 100}
        }
        
        character = Mock(spec=CharacterState)
        character.x = 100
        character.y = 101  # Close enough (distance <= 2)
        
        game_state = Mock(spec=GameState)
        game_state.character = character
        
        result = await system._handle_maze_test(params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_handle_maze_test_in_progress(self, temp_job_paths_file, temp_npc_locations_file):
        """Test maze test when still navigating"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {
            "maze_map": "job_hunter",
            "goal": {"x": 100, "y": 100},
            "trap_locations": [{"x": 50, "y": 50}]
        }
        
        character = Mock(spec=CharacterState)
        character.x = 20  # Far from goal
        character.y = 20
        
        game_state = Mock(spec=GameState)
        game_state.character = character
        game_state.navigation_manager = Mock()
        
        result = await system._handle_maze_test(params, game_state)
        
        assert result is False
        game_state.navigation_manager.execute_maze_navigation.assert_called_once()


class TestCompleteJobTest:
    """Test complete_job_test dispatcher"""
    
    @pytest.mark.asyncio
    async def test_complete_job_test_hunting(self, temp_job_paths_file, temp_npc_locations_file):
        """Test job test dispatcher for hunting quest"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {"monster": "Poring", "count": 10, "current_count": 10}
        game_state = Mock(spec=GameState)
        
        result = await system.complete_job_test("hunting_quest", params, game_state)
        
        assert result is True
    
    @pytest.mark.asyncio
    async def test_complete_job_test_unknown_type(self, temp_job_paths_file, temp_npc_locations_file):
        """Test job test dispatcher with unknown test type"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        params = {}
        game_state = Mock(spec=GameState)
        
        result = await system.complete_job_test("unknown_test_type", params, game_state)
        
        assert result is False


class TestHelperMethods:
    """Test helper utility methods"""
    
    def test_get_item_count_in_inventory(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting item count from inventory"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = Mock(spec=CharacterState)
        character.inventory = [
            {"id": 909, "amount": 10},
            {"id": 914, "amount": 5},
            {"id": 909, "amount": 3}  # Duplicate ID
        ]
        
        count = system._get_item_count_in_inventory(character, "909")
        
        assert count == 13  # 10 + 3
    
    def test_get_item_count_no_inventory(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting item count when character has no inventory"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = Mock(spec=CharacterState, spec_set=['name'])
        # Don't set inventory attribute
        
        count = system._get_item_count_in_inventory(character, "909")
        
        assert count == 0
    
    def test_get_quiz_answers_mage(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting mage quiz answers"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        answers = system._get_quiz_answers("mage")
        
        assert "what is magic" in answers
        assert "fire element" in answers
    
    def test_get_quiz_answers_sage(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting sage quiz answers"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        answers = system._get_quiz_answers("sage")
        
        assert "history of magic" in answers
        assert "magic theory" in answers
    
    def test_get_quiz_answers_priest(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting priest quiz answers"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        answers = system._get_quiz_answers("priest")
        
        assert "what is holy" in answers
        assert "healing" in answers
    
    def test_get_quiz_answers_unknown_type(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting answers for unknown quiz type"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        answers = system._get_quiz_answers("unknown_quiz")
        
        assert answers == {}
    
    def test_match_quiz_answer_found(self, temp_job_paths_file, temp_npc_locations_file):
        """Test matching quiz answer with keyword"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        question = "What does INT increase for a mage?"
        answers_db = {"what does int": "Increases magic damage"}
        
        answer = system._match_quiz_answer(question, answers_db)
        
        assert answer == "Increases magic damage"
    
    def test_match_quiz_answer_not_found(self, temp_job_paths_file, temp_npc_locations_file):
        """Test matching with no keyword match"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        question = "Completely unknown question?"
        answers_db = {"known keyword": "Answer"}
        
        answer = system._match_quiz_answer(question, answers_db)
        
        assert answer is None
    
    def test_match_quiz_answer_empty_question(self, temp_job_paths_file, temp_npc_locations_file):
        """Test matching with empty question"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        answer = system._match_quiz_answer("", {"keyword": "answer"})
        
        assert answer is None
    
    def test_calculate_distance(self, temp_job_paths_file, temp_npc_locations_file):
        """Test distance calculation"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        pos1 = {"x": 0, "y": 0}
        pos2 = {"x": 3, "y": 4}
        
        distance = system._calculate_distance(pos1, pos2)
        
        # 3-4-5 triangle
        assert distance == 5.0


class TestJobPathSummary:
    """Test job path summary generation"""
    
    def test_get_job_path_summary(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting job path summary"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        summary = system.get_job_path_summary("Swordman")
        
        assert summary["current_job"] == "Swordman"
        assert summary["job_tier"] == 2
        assert len(summary["next_jobs"]) > 0
        assert "Knight" in [j["job_name"] for j in summary["next_jobs"]]
    
    def test_get_job_path_summary_unknown_job(self, temp_job_paths_file, temp_npc_locations_file):
        """Test getting summary for unknown job"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        summary = system.get_job_path_summary("UnknownJob")
        
        assert summary["current_job"] == "UnknownJob"
        assert summary["job_tier"] is None
        assert summary["next_jobs"] == []


class TestValidateJobPathContinuity:
    """Test job path validation"""
    
    def test_validate_job_path_continuity_valid(self, temp_job_paths_file, temp_npc_locations_file):
        """Test validation detects missing job references in test data"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        errors = system.validate_job_path_continuity()
        
        # Test data intentionally has incomplete references (Mage, Thief, Crusader not defined)
        assert len(errors) > 0
        assert any("Mage" in error or "Thief" in error for error in errors)
    
    def test_validate_job_path_continuity_broken(self, temp_job_paths_file, temp_npc_locations_file):
        """Test validation with broken references"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        # Add invalid reference
        system._job_paths["Swordman"].next_jobs.append("FakeJob")
        
        errors = system.validate_job_path_continuity()
        
        assert len(errors) > 0
        assert any("FakeJob" in error for error in errors)


class TestJobModels:
    """Test job-related models"""
    
    def test_job_npc_location_model(self):
        """Test JobNPCLocation model"""
        location = JobNPCLocation(
            map_name="izlude",
            x=74,
            y=172,
            npc_name="Swordman Guildsman"
        )
        
        assert location.map_name == "izlude"
        assert location.x == 74
        assert location.y == 172
    
    def test_job_requirements_model(self):
        """Test JobRequirements model"""
        reqs = JobRequirements(
            base_level=40,
            job_level=40,
            zeny_cost=0,
            test_required=True,
            test_type="combat_test"
        )
        
        assert reqs.base_level == 40
        assert reqs.test_required is True
    
    def test_job_path_model(self):
        """Test JobPath model"""
        path = JobPath(
            job_id=7,
            job_name="Knight",
            from_job="Swordman",
            job_tier=3,
            requirements=JobRequirements(base_level=40, job_level=40),
            next_jobs=[]
        )
        
        assert path.job_name == "Knight"
        assert path.job_tier == 3


class TestIntegrationScenarios:
    """Test complete job advancement workflows"""
    
    @pytest.mark.asyncio
    async def test_complete_job_change_workflow(self, temp_job_paths_file, temp_npc_locations_file):
        """Test complete job change from Novice to Swordman"""
        system = JobAdvancementSystem(temp_job_paths_file, temp_npc_locations_file)
        
        character = CharacterState(
            name="TestChar",
            base_level=15,
            job_level=15,
            job_class="Novice",
            zeny=1000,
            str=30, agi=10, vit=10, int_stat=10, dex=10, luk=10
        )
        
        # Check advancement
        actions = await system.check_advancement(character, LifecycleState.NOVICE)
        
        assert len(actions) > 0
        action = actions[0]
        assert action.extra["action_subtype"] == "job_advancement"
        assert "npc_map" in action.extra
        assert "npc_name" in action.extra