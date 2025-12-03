"""
Comprehensive tests for quests/core.py to achieve 100% coverage.
Target: Cover remaining 35 uncovered lines (83.10% -> 100%)
"""

import json
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

import pytest

from ai_sidecar.quests.core import (
    Quest,
    QuestManager,
    QuestObjective,
    QuestObjectiveType,
    QuestRequirement,
    QuestReward,
    QuestStatus,
    QuestType,
)
from ai_sidecar.core.state import CharacterState, Position


class TestQuestObjectiveEdgeCases:
    """Test QuestObjective edge cases and uncovered lines."""
    
    def test_progress_percent_with_zero_required(self):
        """Test progress_percent when required_count is 0 (line 86)."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_name="Poring",
            required_count=0,  # Zero required
            current_count=0
        )
        
        # Should return 100% when required is 0
        assert obj.progress_percent == 100.0


class TestQuestProperties:
    """Test Quest model properties and edge cases."""
    
    def test_overall_progress_no_objectives(self):
        """Test overall_progress with empty objectives list (line 178)."""
        quest = Quest(
            quest_id=1,
            quest_name="Empty Quest",
            quest_type=QuestType.MAIN_STORY,
            description="Quest with no objectives",
            objectives=[]  # Empty list
        )
        
        # Should return 0.0 when no objectives
        assert quest.overall_progress == 0.0
    
    def test_can_start_daily_quest_on_cooldown(self):
        """Test can_start for daily quest on cooldown (lines 187-189)."""
        quest = Quest(
            quest_id=2,
            quest_name="Daily Quest",
            quest_type=QuestType.DAILY,
            description="Daily quest",
            is_daily=True,
            cooldown_hours=24,
            last_completed=datetime.now() - timedelta(hours=12)  # Only 12 hours ago
        )
        
        # Should return False - still on cooldown
        assert quest.can_start is False
    
    def test_get_cooldown_remaining_not_daily(self):
        """Test get_cooldown_remaining for non-daily quest (line 197)."""
        quest = Quest(
            quest_id=3,
            quest_name="Regular Quest",
            quest_type=QuestType.MAIN_STORY,
            description="Not a daily quest",
            is_daily=False,
            is_repeatable=False,
            last_completed=datetime.now()
        )
        
        # Should return None for non-daily/non-repeatable quests
        assert quest.get_cooldown_remaining() is None


class TestQuestManagerErrorHandling:
    """Test QuestManager error handling paths."""
    
    def test_load_quest_data_parse_error(self):
        """Test _load_quest_data with parse errors (lines 244-245)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            # Create quest data with invalid quest (missing required field)
            invalid_data = {
                "quests": [
                    {
                        "quest_id": 1,
                        # Missing quest_name - should cause parse error
                        "quest_type": "main_story",
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(invalid_data, f)
            
            # Should handle parse error gracefully
            manager = QuestManager(data_dir)
            assert len(manager.quests) == 0  # Failed quest not added
    
    def test_load_quest_data_file_error(self):
        """Test _load_quest_data with file read error (lines 252-253)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            # Create invalid JSON file
            with open(quest_file, 'w') as f:
                f.write("{ invalid json }")
            
            # Should handle JSON decode error gracefully
            manager = QuestManager(data_dir)
            assert len(manager.quests) == 0


class TestQuestManagerRequirements:
    """Test _check_requirements with CharacterState objects."""
    
    def test_check_requirements_with_character_state(self):
        """Test _check_requirements with CharacterState object (lines 331-337)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Create quest with level requirement
            quest = Quest(
                quest_id=1,
                quest_name="Level Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Requires level 50",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 50",
                        required_value=50
                    )
                ]
            )
            
            # Create CharacterState object (not dict)
            char_state = CharacterState(
                name="TestChar",
                job_id=0,
                base_level=60,  # Meets requirement
                job_level=10,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0)
            )
            
            # Should handle CharacterState object
            assert manager._check_requirements(quest, char_state) is True
    
    def test_check_requirements_job_level_with_state(self):
        """Test job_level requirement with CharacterState (lines 341-342, 345)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=2,
                quest_name="Job Quest",
                quest_type=QuestType.JOB_CHANGE,
                description="Requires job level 40",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 40",
                        required_value=40
                    )
                ]
            )
            
            # CharacterState with insufficient job level
            char_state = CharacterState(
                name="TestChar",
                job_id=0,
                base_level=50,
                job_level=30,  # Below requirement
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0)
            )
            
            # Should return False
            assert manager._check_requirements(quest, char_state) is False
    
    def test_check_requirements_job_with_state(self):
        """Test job requirement with CharacterState (lines 349-351)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=3,
                quest_name="Class Quest",
                quest_type=QuestType.JOB_CHANGE,
                description="Knight only",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Knight",
                        required_value="Knight"
                    )
                ]
            )
            
            # CharacterState with wrong job
            char_state = CharacterState(
                name="TestChar",
                job_id=7,  # Assume this is Knight
                base_level=50,
                job_level=40,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0),
                job_class="Swordsman"  # Wrong job
            )
            
            # Should return False
            assert manager._check_requirements(quest, char_state) is False


class TestUpdateObjectiveEdgeCases:
    """Test update_objective edge cases."""
    
    def test_update_objective_quest_not_found(self):
        """Test update_objective when quest not active (line 377->376)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Try to update non-existent quest
            result = manager.update_objective(999, 1, 10)
            
            assert result is False
    
    def test_update_objective_not_found(self):
        """Test update_objective when objective not found (line 392)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Create and start quest
            quest = Quest(
                quest_id=1,
                quest_name="Test Quest",
                quest_type=QuestType.HUNTING,
                description="Test",
                objectives=[
                    QuestObjective(
                        objective_id=1,
                        objective_type=QuestObjectiveType.KILL_MONSTER,
                        target_name="Poring",
                        required_count=10
                    )
                ]
            )
            manager.quests[1] = quest
            manager.start_quest(1)
            
            # Try to update non-existent objective
            result = manager.update_objective(1, 999, 5)  # Wrong objective_id
            
            assert result is False


class TestCheckQuestRequirementsEdgeCases:
    """Test check_quest_requirements edge cases."""
    
    def test_check_requirements_quest_not_found(self):
        """Test check_quest_requirements for non-existent quest (line 431)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            can_do, missing = manager.check_quest_requirements(
                999,
                {"level": 50, "job": "Knight"}
            )
            
            assert can_do is False
            assert "Quest not found" in missing
    
    def test_check_requirements_level_too_high(self):
        """Test check_quest_requirements when level too high (line 439)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=1,
                quest_name="Novice Quest",
                quest_type=QuestType.TUTORIAL,
                description="For low levels only",
                min_level=1,
                max_level=10  # Max level restriction
            )
            manager.quests[1] = quest
            
            can_do, missing = manager.check_quest_requirements(
                1,
                {"level": 50}  # Too high
            )
            
            assert can_do is False
            assert any("max:" in msg for msg in missing)
    
    def test_check_requirements_job_level(self):
        """Test check_quest_requirements with job_level (lines 447-448, 452-455)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=2,
                quest_name="Advanced Quest",
                quest_type=QuestType.JOB_CHANGE,
                description="High job level needed",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 50",
                        required_value=50
                    )
                ]
            )
            manager.quests[2] = quest
            
            can_do, missing = manager.check_quest_requirements(
                2,
                {"level": 99, "job_level": 30}  # Insufficient job level
            )
            
            assert can_do is False
            assert any("Job level 50" in msg for msg in missing)


class TestTickMethodEdgeCases:
    """Test async tick method edge cases."""
    
    @pytest.mark.asyncio
    async def test_tick_expired_quest(self):
        """Test tick with expired quest (lines 500-503)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Create quest with expiry in the past
            quest = Quest(
                quest_id=1,
                quest_name="Expired Quest",
                quest_type=QuestType.DAILY,
                description="Already expired",
                expires_at=datetime.now() - timedelta(hours=1),  # Expired
                objectives=[
                    QuestObjective(
                        objective_id=1,
                        objective_type=QuestObjectiveType.KILL_MONSTER,
                        target_name="Poring",
                        required_count=10
                    )
                ]
            )
            
            manager.quests[1] = quest
            manager.start_quest(1)
            
            # Tick should detect expired quest
            actions = await manager.tick()
            
            # Quest should be failed and removed
            assert 1 not in manager.active_quests
            assert quest.status == QuestStatus.FAILED
    
    @pytest.mark.asyncio
    async def test_tick_ready_to_complete(self):
        """Test tick with ready-to-complete quest (lines 507-508)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Create quest with completed objectives
            quest = Quest(
                quest_id=2,
                quest_name="Ready Quest",
                quest_type=QuestType.HUNTING,
                description="All objectives complete",
                objectives=[
                    QuestObjective(
                        objective_id=1,
                        objective_type=QuestObjectiveType.KILL_MONSTER,
                        target_name="Poring",
                        required_count=10,
                        current_count=10  # Complete
                    )
                ]
            )
            
            manager.quests[2] = quest
            manager.start_quest(2)
            
            # Tick should log ready-for-completion
            actions = await manager.tick()
            
            # Quest should still be in active_quests but is_complete
            assert 2 in manager.active_quests
            assert quest.is_complete


class TestAcceptQuestEdgeCases:
    """Test accept_quest method edge cases."""
    
    @pytest.mark.asyncio
    async def test_accept_quest_by_numeric_string(self):
        """Test accept_quest with numeric string (lines 518-519)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=123,
                quest_name="Test Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Test",
                objectives=[]
            )
            manager.quests[123] = quest
            
            # Accept by numeric string
            result = await manager.accept_quest("123")
            
            assert result is True
            assert 123 in manager.active_quests
    
    @pytest.mark.asyncio
    async def test_accept_quest_triggers_except_block(self):
        """
        Test accept_quest except block (lines 518-523).
        
        This requires start_quest to raise an exception, which happens
        when quest_id is invalid type that triggers dict access error.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 456,
                        "quest_name": "Named Quest",
                        "quest_type": "main_story",
                        "description": "Test quest",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Modify start_quest to raise TypeError for testing except path
            original_start = manager.start_quest
            def raising_start_quest(qid):
                if isinstance(qid, str):
                    raise TypeError("Invalid quest_id type")
                return original_start(qid)
            
            manager.start_quest = raising_start_quest
            
            # Now accept_quest should hit except block and search by name
            result = await manager.accept_quest("named quest")
            
            assert result is True
            assert 456 in manager.active_quests
    
    @pytest.mark.asyncio
    async def test_accept_quest_invalid_input(self):
        """Test accept_quest with invalid input (line 523)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Try to accept quest that doesn't exist
            result = await manager.accept_quest("NonExistent Quest")
            
            assert result is False


class TestGetAvailableQuestsWithState:
    """Test get_available_quests with CharacterState objects."""
    
    def test_get_available_quests_with_character_state(self):
        """Test get_available_quests with CharacterState object."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=1,
                quest_name="State Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Test with state",
                min_level=10,
                max_level=50,
                objectives=[]
            )
            manager.quests[1] = quest
            
            # Use CharacterState object
            char_state = CharacterState(
                name="TestChar",
                job_id=0,
                base_level=25,
                job_level=10,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0)
            )
            
            available = manager.get_available_quests(char_state)
            
            assert len(available) == 1
            assert available[0].quest_id == 1


class TestQuestManagerComprehensive:
    """Comprehensive integration tests."""
    
    def test_full_quest_lifecycle_with_cooldown(self):
        """Test complete quest lifecycle including cooldown checks."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            # Create quest data
            quest_data = {
                "quests": [
                    {
                        "quest_id": 1,
                        "quest_name": "Daily Hunt",
                        "quest_type": "daily",
                        "description": "Hunt daily",
                        "is_daily": True,
                        "cooldown_hours": 24,
                        "min_level": 1,
                        "max_level": 999,
                        "objectives": [
                            {
                                "objective_id": 1,
                                "objective_type": "kill_monster",
                                "target_name": "Poring",
                                "required_count": 10
                            }
                        ],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Start quest
            assert manager.start_quest(1) is True
            
            # Complete objectives
            for i in range(10):
                manager.update_objective(1, 1, 1)
            
            # Complete quest
            rewards = manager.complete_quest(1)
            assert len(rewards) == 0  # No rewards defined
            
            # Check cooldown
            quest = manager.quests[1]
            assert quest.last_completed is not None
            remaining = quest.get_cooldown_remaining()
            assert remaining is not None
            assert remaining.total_seconds() > 0
    
    def test_quest_with_multiple_requirement_types(self):
        """Test quest with complex requirements."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Add prerequisite quest
            prereq_quest = Quest(
                quest_id=1,
                quest_name="Prerequisite",
                quest_type=QuestType.MAIN_STORY,
                description="Complete first",
                objectives=[]
            )
            manager.quests[1] = prereq_quest
            manager.completed_quests.append(1)
            
            # Main quest with multiple requirements
            main_quest = Quest(
                quest_id=2,
                quest_name="Main Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Complex requirements",
                min_level=50,
                max_level=99,
                job_requirements=["Knight", "Lord Knight"],
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=1,
                        requirement_name="Prerequisite"
                    ),
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 50",
                        required_value=50
                    ),
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 40",
                        required_value=40
                    )
                ],
                objectives=[]
            )
            manager.quests[2] = main_quest
            
            # Check with insufficient stats
            can_do, missing = manager.check_quest_requirements(
                2,
                {"level": 45, "job_level": 30, "job": "Swordsman"}
            )
            
            assert can_do is False
            assert len(missing) > 0


class TestAdditionalEdgeCases:
    """Additional edge cases to reach 100% coverage."""
    
    def test_get_available_quests_cooldown_check(self):
        """Test get_available_quests with cooldown filtering."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Quest on cooldown
            quest = Quest(
                quest_id=1,
                quest_name="Cooldown Quest",
                quest_type=QuestType.DAILY,
                description="On cooldown",
                is_daily=True,
                is_repeatable=True,
                cooldown_hours=24,
                last_completed=datetime.now() - timedelta(hours=1),  # Recent
                min_level=1,
                max_level=999
            )
            manager.quests[1] = quest
            manager.completed_quests.append(1)
            
            # Should filter out quest on cooldown
            available = manager.get_available_quests({"level": 50, "job": "Knight"})
            
            assert len(available) == 0  # Quest filtered due to cooldown
    
    def test_get_available_quests_level_bounds(self):
        """Test get_available_quests with level filtering."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=2,
                quest_name="Level Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Level restricted",
                min_level=30,
                max_level=50
            )
            manager.quests[2] = quest
            
            # Too low level
            available = manager.get_available_quests({"level": 20, "job": "Knight"})
            assert len(available) == 0
            
            # Too high level
            available = manager.get_available_quests({"level": 60, "job": "Knight"})
            assert len(available) == 0
    
    def test_get_available_quests_job_requirements(self):
        """Test get_available_quests with job filtering."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=3,
                quest_name="Job Quest",
                quest_type=QuestType.JOB_CHANGE,
                description="Knight only",
                min_level=1,
                max_level=999,
                job_requirements=["Knight", "Lord Knight"]
            )
            manager.quests[3] = quest
            
            # Wrong job
            available = manager.get_available_quests({"level": 50, "job": "Wizard"})
            assert len(available) == 0
            
            # Correct job
            available = manager.get_available_quests({"level": 50, "job": "Knight"})
            assert len(available) == 1
    
    def test_get_available_quests_with_requirements(self):
        """Test get_available_quests with quest requirements."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=4,
                quest_name="Advanced Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Requires prerequisite",
                min_level=1,
                max_level=999,
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=999,  # Prerequisite not completed
                        requirement_name="Prerequisite"
                    )
                ]
            )
            manager.quests[4] = quest
            
            # Missing prerequisite
            available = manager.get_available_quests({"level": 50, "job": "Knight"})
            assert len(available) == 0
    
    def test_get_available_quests_already_active(self):
        """Test get_available_quests filters active quests."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=5,
                quest_name="Active Quest",
                quest_type=QuestType.HUNTING,
                description="Already active",
                min_level=1,
                max_level=999,
                objectives=[]
            )
            manager.quests[5] = quest
            manager.start_quest(5)
            
            # Should not appear in available (already active)
            available = manager.get_available_quests({"level": 50, "job": "Knight"})
            assert len(available) == 0
    
    def test_get_available_quests_completed_non_repeatable(self):
        """Test get_available_quests filters completed non-repeatable quests."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=6,
                quest_name="Completed Quest",
                quest_type=QuestType.MAIN_STORY,
                description="Already done",
                min_level=1,
                max_level=999,
                is_repeatable=False,
                objectives=[]
            )
            manager.quests[6] = quest
            manager.completed_quests.append(6)
            
            # Should not appear (already completed and not repeatable)
            available = manager.get_available_quests({"level": 50, "job": "Knight"})
            assert len(available) == 0
    
    def test_get_recommended_quests_empty(self):
        """Test get_recommended_quests with no available quests."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # No quests at all
            recommended = manager.get_recommended_quests({"level": 50, "job": "Knight"})
            
            assert len(recommended) == 0
    
    def test_get_recommended_quests_sorting(self):
        """Test get_recommended_quests priority sorting."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Low priority quest
            quest1 = Quest(
                quest_id=1,
                quest_name="Low Priority",
                quest_type=QuestType.HUNTING,
                description="Low rewards",
                min_level=1,
                max_level=999,
                base_exp_reward=100,
                zeny_reward=50,
                is_daily=False
            )
            manager.quests[1] = quest1
            
            # High priority daily quest
            quest2 = Quest(
                quest_id=2,
                quest_name="High Priority",
                quest_type=QuestType.DAILY,
                description="Daily with good rewards",
                min_level=1,
                max_level=999,
                base_exp_reward=10000,
                job_exp_reward=5000,
                zeny_reward=1000,
                is_daily=True
            )
            manager.quests[2] = quest2
            
            recommended = manager.get_recommended_quests(
                {"level": 50, "job": "Knight"},
                limit=2
            )
            
            # Daily quest should be first due to priority
            assert len(recommended) == 2
            assert recommended[0].quest_id == 2
    
    def test_complete_quest_not_ready(self):
        """Test complete_quest when objectives not complete."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=1,
                quest_name="Incomplete Quest",
                quest_type=QuestType.HUNTING,
                description="Not done yet",
                objectives=[
                    QuestObjective(
                        objective_id=1,
                        objective_type=QuestObjectiveType.KILL_MONSTER,
                        target_name="Poring",
                        required_count=10,
                        current_count=5  # Only half done
                    )
                ],
                rewards=[
                    QuestReward(
                        reward_type="exp",
                        reward_name="Experience",
                        quantity=1000
                    )
                ]
            )
            manager.quests[1] = quest
            manager.start_quest(1)
            
            # Try to complete incomplete quest
            rewards = manager.complete_quest(1)
            
            # Should return empty rewards
            assert len(rewards) == 0
            # Quest should still be active
            assert 1 in manager.active_quests
    
    def test_complete_quest_not_active(self):
        """Test complete_quest for non-active quest."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Try to complete non-existent quest
            rewards = manager.complete_quest(999)
            
            assert len(rewards) == 0
    
    def test_abandon_quest_not_active(self):
        """Test abandon_quest for non-active quest."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Try to abandon non-existent quest
            result = manager.abandon_quest(999)
            
            assert result is False
    
    @pytest.mark.asyncio
    async def test_accept_quest_non_numeric_string(self):
        """Test accept_quest with non-numeric string."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=100,
                quest_name="Test Quest",
                quest_type=QuestType.HUNTING,
                description="Test",
                status=QuestStatus.NOT_STARTED
            )
            manager.quests[100] = quest
            
            # Try with string that's not all digits and doesn't match name
            result = await manager.accept_quest("abc123")
            
            assert result is False


class TestAbandonQuestPaths:
    """Test abandon_quest functionality."""
    
    def test_abandon_active_quest(self):
        """Test abandoning an active quest (lines 418-421)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 100,
                        "quest_name": "Abandonable Quest",
                        "quest_type": "hunting",
                        "description": "Can be abandoned",
                        "objectives": [
                            {
                                "objective_id": 1,
                                "objective_type": "kill_monster",
                                "target_name": "Poring",
                                "required_count": 10
                            }
                        ],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            manager.start_quest(100)
            
            # Abandon the quest
            result = manager.abandon_quest(100)
            
            assert result is True
            assert 100 not in manager.active_quests
            assert manager.quests[100].status == QuestStatus.FAILED


class TestGetQuestMethod:
    """Test get_quest method."""
    
    def test_get_quest_from_active(self):
        """Test get_quest retrieves from active quests (line 286)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 50,
                        "quest_name": "Active Quest",
                        "quest_type": "main_story",
                        "description": "In progress",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            manager.start_quest(50)
            
            # Should retrieve from active_quests
            quest = manager.get_quest(50)
            
            assert quest is not None
            assert quest.quest_id == 50
            assert quest.status == QuestStatus.IN_PROGRESS
    
    def test_get_active_quests(self):
        """Test get_active_quests method (line 290)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 1,
                        "quest_name": "Quest 1",
                        "quest_type": "hunting",
                        "description": "First",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    },
                    {
                        "quest_id": 2,
                        "quest_name": "Quest 2",
                        "quest_type": "hunting",
                        "description": "Second",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            manager.start_quest(1)
            manager.start_quest(2)
            
            active = manager.get_active_quests()
            
            assert len(active) == 2
            assert all(q.status == QuestStatus.IN_PROGRESS for q in active)


class TestStartQuestEdgeCases:
    """Test start_quest edge cases."""
    
    def test_start_quest_already_in_progress(self):
        """Test starting quest that's already in progress (lines 362-363)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 75,
                        "quest_name": "In Progress Quest",
                        "quest_type": "main_story",
                        "description": "Already started",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Start quest first time
            assert manager.start_quest(75) is True
            
            # Try to start again - should fail
            result = manager.start_quest(75)
            
            assert result is False  # Already in progress


class TestAcceptQuestWorkaround:
    """Test accept_quest with comprehensive scenarios."""
    
    @pytest.mark.asyncio
    async def test_accept_quest_by_integer(self):
        """Test accept_quest with direct integer."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 200,
                        "quest_name": "Integer Quest",
                        "quest_type": "hunting",
                        "description": "Accept by int",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Accept by integer (not string)
            result = await manager.accept_quest(200)
            
            assert result is True
            assert 200 in manager.active_quests


class TestQuestExceptBlockCoverage:
    """
    Try to cover the except block in accept_quest (lines 518-523).
    
    Note: These lines are difficult to reach with current implementation
    because start_quest returns False instead of raising exceptions.
    """
    
    @pytest.mark.asyncio  
    async def test_accept_quest_with_type_error_scenario(self):
        """
        Attempt to trigger except block by modifying quests dict.
        
        This is a workaround to test the error handling path.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Create a quest object
            quest = Quest(
                quest_id=300,
                quest_name="Error Quest",
                quest_type=QuestType.HUNTING,
                description="Will cause error",
                objectives=[]
            )
            
            # Manually add to quests dict
            manager.quests[300] = quest
            
            # Mock start_quest to raise TypeError
            original_start = manager.start_quest
            
            def mock_start_quest(qid):
                if isinstance(qid, str):
                    raise TypeError("Cannot start quest with string ID")
                return original_start(qid)
            
            manager.start_quest = mock_start_quest
            
            # Now accept_quest should catch the TypeError and try name matching
            result = await manager.accept_quest("error quest")
            
            # Should find by name and call start_quest with int
            assert result is True
            assert 300 in manager.active_quests


class TestQuestWithCharacterStateAlternatives:
    """Test various character state scenarios."""
    
    def test_get_available_quests_dict_vs_state(self):
        """Compare dict and CharacterState behavior."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 400,
                        "quest_name": "State Test",
                        "quest_type": "main_story",
                        "description": "Test both formats",
                        "min_level": 20,
                        "max_level": 60,
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Test with dict
            dict_state = {"level": 40, "job": "Knight"}
            available_dict = manager.get_available_quests(dict_state)
            
            # Test with CharacterState
            char_state = CharacterState(
                name="TestChar",
                job_id=7,
                base_level=40,
                job_level=30,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0),
                job_class="Knight"
            )
            available_state = manager.get_available_quests(char_state)
            
            # Both should return the same quest
            assert len(available_dict) == 1
            assert len(available_state) == 1
            assert available_dict[0].quest_id == available_state[0].quest_id


class TestFinalCoveragePush:
    """Final tests to reach 100% coverage."""
    
    def test_progress_percent_edge_case(self):
        """Test progress_percent normal calculation (line 87)."""
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_name="Jellopy",
            required_count=20,
            current_count=10
        )
        
        # Should return 50%
        assert obj.progress_percent == 50.0
    
    def test_overall_progress_normal_case(self):
        """Test overall_progress with objectives (line 179)."""
        quest = Quest(
            quest_id=1,
            quest_name="Progress Quest",
            quest_type=QuestType.HUNTING,
            description="Test progress",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_name="Poring",
                    required_count=10,
                    current_count=5  # 50%
                ),
                QuestObjective(
                    objective_id=2,
                    objective_type=QuestObjectiveType.COLLECT_ITEM,
                    target_name="Jellopy",
                    required_count=20,
                    current_count=10  # 50%
                )
            ]
        )
        
        # Average should be 50%
        assert quest.overall_progress == 50.0
    
    def test_can_start_daily_off_cooldown(self):
        """Test can_start for daily quest that's off cooldown (line 188->190)."""
        quest = Quest(
            quest_id=1,
            quest_name="Daily Off Cooldown",
            quest_type=QuestType.DAILY,
            description="Ready to start",
            is_daily=True,
            cooldown_hours=24,
            last_completed=datetime.now() - timedelta(hours=25),  # More than 24h
            status=QuestStatus.NOT_STARTED
        )
        
        # Should return True - cooldown passed
        assert quest.can_start is True
    
    def test_check_requirements_dict_path(self):
        """Test _check_requirements dict get path (line 328)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=1,
                quest_name="Dict Test",
                quest_type=QuestType.MAIN_STORY,
                description="Test dict path",
                requirements=[]  # No requirements, just test get_value function
            )
            
            # Pass dict with level
            char_dict = {"level": 50, "job": "Knight", "job_level": 40}
            result = manager._check_requirements(quest, char_dict)
            
            assert result is True
    
    def test_check_requirements_quest_prerequisite_met(self):
        """Test quest prerequisite that is met (lines 341->339)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Complete prerequisite quest
            manager.completed_quests.append(100)
            
            quest = Quest(
                quest_id=2,
                quest_name="Has Prerequisite",
                quest_type=QuestType.MAIN_STORY,
                description="Needs quest 100",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=100,  # Completed
                        requirement_name="Prerequisite"
                    )
                ]
            )
            
            # Should pass - prerequisite met
            result = manager._check_requirements(quest, {"level": 50})
            
            assert result is True
    
    def test_check_requirements_level_requirement_met(self):
        """Test level requirement that is met (lines 345, 347->339)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=3,
                quest_name="Level Requirement Met",
                quest_type=QuestType.MAIN_STORY,
                description="Needs level 40",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 40",
                        required_value=40
                    )
                ]
            )
            
            # Pass with exact level
            result = manager._check_requirements(quest, {"level": 40})
            assert result is True
            
            # Pass with higher level
            result = manager._check_requirements(quest, {"level": 50})
            assert result is True
    
    def test_check_requirements_job_level_met(self):
        """Test job_level requirement that is met (lines 347->339, 349->339)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=4,
                quest_name="Job Level Met",
                quest_type=QuestType.JOB_CHANGE,
                description="Needs job level 40",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 40",
                        required_value=40
                    )
                ]
            )
            
            # Pass with exact job level
            result = manager._check_requirements(quest, {"job_level": 40})
            assert result is True
    
    def test_check_requirements_job_met(self):
        """Test job requirement that is met (lines 350->339)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=5,
                quest_name="Job Requirement Met",
                quest_type=QuestType.JOB_CHANGE,
                description="Needs Knight",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Knight",
                        required_value="Knight"
                    )
                ]
            )
            
            # Pass with matching job
            result = manager._check_requirements(quest, {"job": "Knight"})
            assert result is True
    
    def test_check_quest_requirements_quest_prereq_met(self):
        """Test check_quest_requirements with quest prerequisite met (line 448)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Complete prerequisite
            manager.completed_quests.append(50)
            
            quest = Quest(
                quest_id=6,
                quest_name="Has Met Prerequisite",
                quest_type=QuestType.MAIN_STORY,
                description="Prerequisite met",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=50,  # Already completed
                        requirement_name="Prerequisite Quest"
                    )
                ]
            )
            manager.quests[6] = quest
            
            can_do, missing = manager.check_quest_requirements(
                6,
                {"level": 50, "job": "Knight"}
            )
            
            # Should pass - prerequisite met
            assert can_do is True
            assert len(missing) == 0
    
    def test_check_quest_requirements_level_met(self):
        """Test check_quest_requirements with level met (lines 450->445)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=7,
                quest_name="Level Met",
                quest_type=QuestType.MAIN_STORY,
                description="Level requirement met",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 30",
                        required_value=30
                    )
                ]
            )
            manager.quests[7] = quest
            
            can_do, missing = manager.check_quest_requirements(
                7,
                {"level": 35}  # Meets requirement
            )
            
            assert can_do is True
            assert len(missing) == 0
    
    def test_check_quest_requirements_job_level_met(self):
        """Test check_quest_requirements with job_level met (lines 452->445, 454->445)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=8,
                quest_name="Job Level Met",
                quest_type=QuestType.JOB_CHANGE,
                description="Job level met",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 35",
                        required_value=35
                    )
                ]
            )
            manager.quests[8] = quest
            
            can_do, missing = manager.check_quest_requirements(
                8,
                {"level": 50, "job_level": 40}  # Meets requirement
            )
            
            assert can_do is True
            assert len(missing) == 0
    
    @pytest.mark.asyncio
    async def test_tick_no_ready_quests(self):
        """Test tick when no quests are ready (line 507->506)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Add active quest that's NOT complete
            quest = Quest(
                quest_id=1,
                quest_name="Not Ready",
                quest_type=QuestType.HUNTING,
                description="Still in progress",
                objectives=[
                    QuestObjective(
                        objective_id=1,
                        objective_type=QuestObjectiveType.KILL_MONSTER,
                        target_name="Poring",
                        required_count=10,
                        current_count=5  # Not complete
                    )
                ]
            )
            manager.quests[1] = quest
            manager.active_quests[1] = quest
            quest.status = QuestStatus.IN_PROGRESS
            
            actions = await manager.tick()
            
            # Should return empty actions (no quests ready)
            assert len(actions) == 0
    
    @pytest.mark.asyncio
    async def test_accept_quest_name_search_success(self):
        """Test accept_quest name search path with mocking (lines 521->520)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 999,
                        "quest_name": "Exact Name Quest",
                        "quest_type": "hunting",
                        "description": "Find by exact name",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Mock start_quest to raise exception on non-int, forcing name search
            original_start = manager.start_quest
            def mock_start(qid):
                if not isinstance(qid, int):
                    raise TypeError("Must be int")
                return original_start(qid)
            
            manager.start_quest = mock_start
            
            # Pass a non-digit string - should hit except block and search by name
            result = await manager.accept_quest("Exact Name Quest")
            
            # Should find and start the quest via name matching
            assert result is True
            assert 999 in manager.active_quests
    
    @pytest.mark.asyncio
    async def test_accept_quest_no_match_returns_false(self):
        """Test accept_quest returns False when no match (line 523)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # No quests loaded
            result = await manager.accept_quest("Nonexistent")
            
            assert result is False


class TestRemainingBranchCoverage:
    """Target the final remaining 6 branch lines."""
    
    def test_check_requirements_level_exactly_met(self):
        """Test level requirement exactly met to cover line 345 branch."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=1,
                quest_name="Exact Level",
                quest_type=QuestType.MAIN_STORY,
                description="Test exact level match",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 50",
                        required_value=50
                    )
                ]
            )
            
            # Exactly meets level requirement - should NOT take the < branch
            result = manager._check_requirements(quest, {"level": 50})
            assert result is True
            
            # Above level requirement
            result = manager._check_requirements(quest, {"level": 60})
            assert result is True
    
    def test_check_requirements_job_exactly_matched(self):
        """Test job requirement exactly matched to cover line 349 branch."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=2,
                quest_name="Job Match",
                quest_type=QuestType.JOB_CHANGE,
                description="Exact job match",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Swordsman",
                        required_value="Swordsman"
                    )
                ]
            )
            
            # Job matches exactly - should NOT take the != branch (line 350)
            result = manager._check_requirements(quest, {"job": "Swordsman"})
            assert result is True
    
    def test_check_quest_requirements_prereq_append_not_triggered(self):
        """Test that line 448 append is NOT triggered when prereq met."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Add completed prerequisite
            manager.completed_quests.append(123)
            
            quest = Quest(
                quest_id=10,
                quest_name="Has Completed Prereq",
                quest_type=QuestType.MAIN_STORY,
                description="Prereq already done",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=123,  # Already in completed_quests
                        requirement_name="Prerequisite Quest"
                    )
                ]
            )
            manager.quests[10] = quest
            
            can_do, missing = manager.check_quest_requirements(10, {"level": 50})
            
            # Should pass, line 448 should NOT execute
            assert can_do is True
            assert len(missing) == 0
    
    def test_check_quest_requirements_job_level_exactly_met(self):
        """Test job_level exactly met to avoid line 454-455 branch."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=11,
                quest_name="Job Level Exact",
                quest_type=QuestType.JOB_CHANGE,
                description="Exact job level",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 45",
                        required_value=45
                    )
                ]
            )
            manager.quests[11] = quest
            
            # Exactly meets job_level - line 454 condition is False
            can_do, missing = manager.check_quest_requirements(
                11,
                {"level": 50, "job_level": 45}
            )
            
            assert can_do is True
            assert len(missing) == 0
            
            # Above job_level
            can_do, missing = manager.check_quest_requirements(
                11,
                {"level": 50, "job_level": 50}
            )
            
            assert can_do is True
            assert len(missing) == 0


class TestExactLineCoverage:
    """Ultra-specific tests to cover exact remaining lines."""
    
    def test_check_quest_requirements_unmet_quest_prereq(self):
        """
        Directly test check_quest_requirements with unmet quest prerequisite.
        This should hit line 448 exactly.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Do NOT complete prerequisite
            quest = Quest(
                quest_id=1000,
                quest_name="Needs Prereq",
                quest_type=QuestType.MAIN_STORY,
                description="Missing prerequisite",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=500,  # NOT in completed_quests
                        requirement_name="Missing Quest"
                    )
                ]
            )
            manager.quests[1000] = quest
            
            can_do, missing = manager.check_quest_requirements(
                1000,
                {"level": 50, "job": "Knight"}
            )
            
            # Should fail and line 448 should execute
            assert can_do is False
            assert any("Complete quest: Missing Quest" in msg for msg in missing)
    
    def test_check_requirements_with_only_job_match(self):
        """
        Test _check_requirements with ONLY job requirement that matches.
        This should take the branch at line 349 directly to line 339 (return True).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Quest with ONLY job requirement
            quest = Quest(
                quest_id=2000,
                quest_name="Job Only",
                quest_type=QuestType.JOB_CHANGE,
                description="Only job requirement",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Assassin",
                        required_value="Assassin"
                    )
                ]
            )
            
            # Character state with matching job
            char_state = CharacterState(
                name="TestAssassin",
                job_id=12,
                base_level=50,
                job_level=40,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0),
                job_class="Assassin"  # Matches
            )
            
            # Should pass and hit line 349->339 branch
            result = manager._check_requirements(quest, char_state)
            assert result is True


class TestFinalBranchPaths:
    """Pinpoint tests for the last 5 branch paths."""
    
    def test_check_requirements_level_gte_path(self):
        """
        Test _check_requirements with level >= required (line 345 FALSE branch).
        When level >= required_value, line 345 condition is False, execution continues.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=9000,
                quest_name="Level GTE Test",
                quest_type=QuestType.MAIN_STORY,
                description="Level must be >= 40",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 40",
                        required_value=40
                    )
                ]
            )
            
            # level = required_value exactly
            char_state_exact = CharacterState(
                name="ExactLevel",
                job_id=0,
                base_level=40,  # Exactly 40
                job_level=1,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0)
            )
            
            # Should pass - line 345 is False, continues to line 339
            result = manager._check_requirements(quest, char_state_exact)
            assert result is True
            
            # level > required_value
            char_state_higher = CharacterState(
                name="HighLevel",
                job_id=0,
                base_level=60,  # Above 40
                job_level=1,
                hp=100,
                hp_max=100,
                sp=50,
                sp_max=50,
                position=Position(x=0, y=0)
            )
            
            result = manager._check_requirements(quest, char_state_higher)
            assert result is True
    
    def test_check_quest_requirements_job_level_gte(self):
        """
        Test check_quest_requirements with job_level >= required (line 452->445 FALSE, line 454 FALSE).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=9001,
                quest_name="Job Level GTE",
                quest_type=QuestType.JOB_CHANGE,
                description="Job level >= 35",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 35",
                        required_value=35
                    )
                ]
            )
            manager.quests[9001] = quest
            
            # Exactly meets job_level - line 454 is False
            can_do, missing = manager.check_quest_requirements(
                9001,
                {"level": 50, "job_level": 35}
            )
            assert can_do is True
            assert len(missing) == 0
            
            # Exceeds job_level
            can_do, missing = manager.check_quest_requirements(
                9001,
                {"level": 50, "job_level": 50}
            )
            assert can_do is True
            assert len(missing) == 0
    
    @pytest.mark.asyncio
    async def test_accept_quest_successful_name_search(self):
        """
        Test accept_quest with successful name match after except (lines 521->520).
        Need to trigger ValueError/TypeError, then find by name.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 8888,
                        "quest_name": "Searchable Quest",
                        "quest_type": "hunting",
                        "description": "Find by name",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Inject a start_quest that raises ValueError for string inputs
            original_start_quest = manager.start_quest
            
            def failing_start_quest(quest_id):
                # Raise ValueError if called with wrong type
                if isinstance(quest_id, str):
                    raise ValueError(f"Invalid quest_id type: {type(quest_id)}")
                return original_start_quest(quest_id)
            
            manager.start_quest = failing_start_quest
            
            # This should:
            # 1. Try start_quest with string "Searchable Quest" -> ValueError
            # 2. Enter except block at line 518
            # 3. Search by name at line 520
            # 4. Find match and call start_quest with int 8888
            result = await manager.accept_quest("Searchable Quest")
            
            assert result is True
            assert 8888 in manager.active_quests
    
    @pytest.mark.asyncio
    async def test_accept_quest_no_match_after_except(self):
        """
        Test accept_quest with no name match after except (line 523).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            data_dir = Path(tmpdir)
            quest_file = data_dir / "quests.json"
            
            quest_data = {
                "quests": [
                    {
                        "quest_id": 7777,
                        "quest_name": "Different Name",
                        "quest_type": "hunting",
                        "description": "Won't match",
                        "objectives": [],
                        "requirements": [],
                        "rewards": []
                    }
                ]
            }
            
            with open(quest_file, 'w') as f:
                json.dump(quest_data, f)
            
            manager = QuestManager(data_dir)
            
            # Inject start_quest that raises ValueError
            def failing_start_quest(quest_id):
                if isinstance(quest_id, str):
                    raise ValueError("Bad type")
                return manager.quests.get(quest_id) is not None
            
            manager.start_quest = failing_start_quest
            
            # This should:
            # 1. Try start_quest -> ValueError
            # 2. Enter except block
            # 3. Search by name "NoMatch" - no quest with this name
            # 4. Hit line 523 and return False
            result = await manager.accept_quest("NoMatch")
            
            assert result is False


class TestFinal100PercentCoverage:
    """Ultra-targeted tests for the final 3 branch paths."""
    
    def test_check_requirements_level_fails_dict(self):
        """Test _check_requirements level < required with dict (line 345 directly)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=10000,
                quest_name="Level Fail Dict",
                quest_type=QuestType.MAIN_STORY,
                description="Level too low",
                requirements=[
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 60",
                        required_value=60
                    )
                ]
            )
            
            # Use dict with level below requirement
            result = manager._check_requirements(quest, {"level": 40})
            
            # Line 345 should execute (return False)
            assert result is False
    
    def test_check_requirements_job_ne_with_state(self):
        """
        Test _check_requirements job != required with CharacterState.
        This should make line 350 True, hitting line 351 and NOT going to 339 directly.
        But we want the branch 349->339 which is when job DOES match.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=10001,
                quest_name="Job Match State",
                quest_type=QuestType.JOB_CHANGE,
                description="Job must match",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Wizard",
                        required_value="Wizard"
                    )
                ]
            )
            
            # CharacterState with matching job
            char_state = CharacterState(
                name="TestWizard",
                job_id=9,
                base_level=50,
                job_level=40,
                hp=100,
                hp_max=100,
                sp=100,
                sp_max=100,
                position=Position(x=0, y=0),
                job_class="Wizard"  # MATCHES
            )
            
            # Line 350 condition is False (job matches), so continues to 339
            # This should cover the 349->339 branch
            result = manager._check_requirements(quest, char_state)
            assert result is True
    
    def test_check_quest_requirements_job_level_succeeds(self):
        """
        Test check_quest_requirements where job_level >= required.
        Line 454 condition is False, so continues past line 455 to line 445.
        This should cover 452->445 branch.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=10002,
                quest_name="Job Level Success",
                quest_type=QuestType.JOB_CHANGE,
                description="Job level passes",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 30",
                        required_value=30
                    )
                ]
            )
            manager.quests[10002] = quest
            
            # Job level exactly meets requirement
            can_do, missing = manager.check_quest_requirements(
                10002,
                {"level": 50, "job_level": 30}
            )
            
            # Line 454 is False, doesn't execute 455, continues
            # This hits 452->445 branch
            assert can_do is True
            assert len(missing) == 0


class TestAbsoluteFinalBranches:
    """Cover the absolute final 2 partial branches."""
    
    def test_check_requirements_job_false_branch_with_dict(self):
        """
        Cover 349->339 branch with dict (job matches, continues to return True).
        Use dict instead of CharacterState to ensure both code paths tested.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=20000,
                quest_name="Job Dict Match",
                quest_type=QuestType.JOB_CHANGE,
                description="Job matches via dict",
                requirements=[
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Priest",
                        required_value="Priest"
                    )
                ]
            )
            
            # Use DICT with matching job (not CharacterState)
            char_dict = {"level": 50, "job": "Priest"}  # Job matches
            
            # Line 350 condition is False, doesn't execute 351
            # Falls through to line 339 (return True)
            result = manager._check_requirements(quest, char_dict)
            assert result is True
    
    def test_check_quest_requirements_job_level_false_branch(self):
        """
        Cover 452->445 branch (job_level >= requirement, continues without appending).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=20001,
                quest_name="Job Level Pass",
                quest_type=QuestType.JOB_CHANGE,
                description="Job level passes",
                requirements=[
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 25",
                        required_value=25
                    )
                ]
            )
            manager.quests[20001] = quest
            
            # Job level exceeds requirement
            can_do, missing = manager.check_quest_requirements(
                20001,
                {"level": 50, "job_level": 40}  # 40 >= 25
            )
            
            # Line 454 condition is False, doesn't execute 455
            # Continues to line 445 (next iteration)
            assert can_do is True
            assert len(missing) == 0
    
    def test_combined_requirements_all_pass(self):
        """
        Test quest with multiple requirements that all pass.
        This should exercise multiple success branches in one test.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            # Complete prerequisite
            manager.completed_quests.append(555)
            
            quest = Quest(
                quest_id=20002,
                quest_name="All Pass",
                quest_type=QuestType.MAIN_STORY,
                description="All requirements pass",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=555,
                        requirement_name="Prereq"
                    ),
                    QuestRequirement(
                        requirement_type="level",
                        requirement_name="Level 45",
                        required_value=45
                    ),
                    QuestRequirement(
                        requirement_type="job_level",
                        requirement_name="Job Level 35",
                        required_value=35
                    ),
                    QuestRequirement(
                        requirement_type="job",
                        requirement_name="Hunter",
                        required_value="Hunter"
                    )
                ]
            )
            manager.quests[20002] = quest
            
            # All requirements met
            can_do, missing = manager.check_quest_requirements(
                20002,
                {"level": 60, "job_level": 45, "job": "Hunter"}
            )
            
            assert can_do is True
            assert len(missing) == 0


class TestAbsolute100PercentCoverage:
    """The final test to achieve perfect 100% coverage."""
    
    def test_check_requirements_unknown_requirement_type(self):
        """
        Test _check_requirements with unknown requirement type.
        
        This covers the 349->339 branch where line 349 elif is False
        (requirement is not "job" type), so it skips to line 339 (return True).
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=99999,
                quest_name="Unknown Requirement Type",
                quest_type=QuestType.MAIN_STORY,
                description="Has unknown requirement type",
                requirements=[
                    QuestRequirement(
                        requirement_type="unknown_type",  # Not quest, level, job_level, or job
                        requirement_name="Unknown",
                        required_value="something"
                    )
                ]
            )
            
            # When requirement_type is not recognized, all elif conditions are False
            # So line 349 elif is False, execution continues past line 351 to line 352 (return True)
            # This covers the 349->339 branch
            result = manager._check_requirements(quest, {"level": 50, "job": "Knight"})
            
            # Should return True (unknown requirements are ignored)
            assert result is True
    
    def test_check_requirements_empty_requirements_list(self):
        """Test _check_requirements with no requirements (for loop never executes)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            quest = Quest(
                quest_id=99998,
                quest_name="No Requirements",
                quest_type=QuestType.HUNTING,
                description="No requirements at all",
                requirements=[]  # Empty list - for loop doesn't execute
            )
            
            # With empty requirements list, immediately returns True
            result = manager._check_requirements(quest, {"level": 1})
            
            assert result is True
    
    def test_check_requirements_multiple_unknown_types(self):
        """Test with multiple requirement types including unknown ones."""
        with tempfile.TemporaryDirectory() as tmpdir:
            manager = QuestManager(Path(tmpdir))
            
            manager.completed_quests.append(111)
            
            quest = Quest(
                quest_id=99997,
                quest_name="Mixed Requirements",
                quest_type=QuestType.MAIN_STORY,
                description="Mix of known and unknown",
                requirements=[
                    QuestRequirement(
                        requirement_type="quest",
                        requirement_id=111,
                        requirement_name="Prereq"
                    ),
                    QuestRequirement(
                        requirement_type="item",  # Unknown type
                        requirement_name="Some Item",
                        required_value=5
                    ),
                    QuestRequirement(
                        requirement_type="custom",  # Unknown type
                        requirement_name="Custom Req",
                        required_value="value"
                    )
                ]
            )
            
            # Quest prereq passes, unknown types are ignored
            result = manager._check_requirements(quest, {"level": 50})
            
            assert result is True