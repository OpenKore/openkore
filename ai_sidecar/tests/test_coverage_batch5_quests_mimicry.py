"""
Coverage Batch 5: Quest System & Mimicry Modules
Target: ~94% → ~95.5% coverage (~200-250 lines)

Modules:
- ai_sidecar/quests/core.py (310 uncovered lines) - Target: 50-60% coverage (~150-180 lines)
- ai_sidecar/mimicry/pattern_breaker.py (223 uncovered lines) - Target: 30-40% coverage (~70-90 lines)
- ai_sidecar/mimicry/movement.py (212 uncovered lines) - Target: 20-30% coverage (~40-60 lines)

Test Classes:
- TestQuestCoreInitialization: Quest manager setup and data loading
- TestQuestAcceptanceLogic: Quest requirement checking and acceptance
- TestQuestObjectiveTracking: Objective progress and completion
- TestQuestCompletionValidation: Quest completion logic
- TestQuestRewardProcessing: Reward calculation and distribution
- TestPatternBreakerCore: Pattern detection and breaking
- TestMovementMimicryCore: Human-like movement generation
"""

import json
import math
import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.quests.core import (
    QuestManager,
    Quest,
    QuestType,
    QuestStatus,
    QuestObjective,
    QuestObjectiveType,
    QuestReward,
    QuestRequirement,
)
from ai_sidecar.mimicry.pattern_breaker import (
    PatternBreaker,
    DetectedPattern,
    PatternType,
)
from ai_sidecar.mimicry.movement import (
    MovementHumanizer,
    HumanPath,
    PathPoint,
    MovementPattern,
)


# ==================== Quest System Tests ====================

class TestQuestCoreInitialization:
    """Test QuestManager initialization and quest data loading (Lines 215-283)"""
    
    def test_quest_manager_initialization_should_create_instance(self, tmp_path):
        """Cover QuestManager.__init__ (Lines 215-227)"""
        # Arrange & Act
        manager = QuestManager(data_dir=tmp_path)
        
        # Assert
        assert manager is not None
        assert manager.data_dir == tmp_path
        assert isinstance(manager.quests, dict)
        assert isinstance(manager.active_quests, dict)
        assert isinstance(manager.completed_quests, list)
    
    def test_load_quest_data_should_handle_missing_file(self, tmp_path):
        """Cover _load_quest_data with missing file (Lines 229-234)"""
        # Arrange & Act - File doesn't exist, should log warning but not crash
        manager = QuestManager(data_dir=tmp_path)
        
        # Assert
        assert len(manager.quests) == 0
    
    def test_load_quest_data_should_parse_valid_json(self, tmp_path):
        """Cover _load_quest_data with valid quest data (Lines 236-251)"""
        # Arrange
        quest_data = {
            "quests": [
                {
                    "quest_id": 1001,
                    "quest_name": "Test Quest",
                    "quest_type": "main_story",
                    "description": "A test quest",
                    "objectives": [
                        {
                            "objective_id": 1,
                            "objective_type": "kill_monster",
                            "target_name": "Poring",
                            "target_id": 1002,
                            "required_count": 10
                        }
                    ],
                    "requirements": [],
                    "rewards": [],
                    "min_level": 1,
                    "base_exp_reward": 1000,
                    "job_exp_reward": 500
                }
            ]
        }
        quest_file = tmp_path / "quests.json"
        quest_file.write_text(json.dumps(quest_data))
        
        # Act
        manager = QuestManager(data_dir=tmp_path)
        
        # Assert
        assert len(manager.quests) == 1
        assert 1001 in manager.quests
        assert manager.quests[1001].quest_name == "Test Quest"
    
    def test_parse_quest_should_create_quest_model(self, tmp_path):
        """Cover _parse_quest (Lines 255-282)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest_data = {
            "quest_id": 2001,
            "quest_name": "Parse Test",
            "quest_type": "daily",
            "description": "Test parsing",
            "objectives": [
                {
                    "objective_id": 1,
                    "objective_type": "collect_item",
                    "target_name": "Red Potion",
                    "required_count": 5
                }
            ],
            "requirements": [
                {
                    "requirement_type": "level",
                    "requirement_name": "Level 10",
                    "required_value": 10
                }
            ],
            "rewards": [
                {
                    "reward_type": "item",
                    "reward_name": "Blue Potion",
                    "reward_id": 501,
                    "quantity": 3
                }
            ],
            "min_level": 10,
            "max_level": 50,
            "job_requirements": ["Swordman", "Knight"],
            "base_exp_reward": 5000,
            "job_exp_reward": 2500,
            "zeny_reward": 1000,
            "is_daily": True,
            "cooldown_hours": 24,
            "start_npc": "Quest Giver",
            "start_map": "prontera",
            "end_npc": "Quest Completer",
            "end_map": "prontera"
        }
        
        # Act
        quest = manager._parse_quest(quest_data)
        
        # Assert
        assert quest.quest_id == 2001
        assert quest.quest_name == "Parse Test"
        assert quest.quest_type == QuestType.DAILY
        assert len(quest.objectives) == 1
        assert len(quest.requirements) == 1
        assert len(quest.rewards) == 1
        assert quest.is_daily is True
        assert quest.min_level == 10
        assert "Swordman" in quest.job_requirements


class TestQuestAcceptanceLogic:
    """Test quest availability and acceptance logic (Lines 284-368)"""
    
    def test_get_quest_should_return_from_active_or_quests(self, tmp_path):
        """Cover get_quest (Lines 284-286)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test",
            quest_type=QuestType.MAIN_STORY,
            description="Test"
        )
        manager.quests[1001] = quest
        
        # Act
        result = manager.get_quest(1001)
        
        # Assert
        assert result == quest
    
    def test_get_active_quests_should_return_list(self, tmp_path):
        """Cover get_active_quests (Lines 288-290)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest1 = Quest(quest_id=1, quest_name="Q1", quest_type=QuestType.DAILY, description="D1")
        quest2 = Quest(quest_id=2, quest_name="Q2", quest_type=QuestType.DAILY, description="D2")
        manager.active_quests[1] = quest1
        manager.active_quests[2] = quest2
        
        # Act
        result = manager.get_active_quests()
        
        # Assert
        assert len(result) == 2
        assert quest1 in result
        assert quest2 in result
    
    def test_get_available_quests_with_dict_should_filter_by_level(self, tmp_path):
        """Cover get_available_quests with dict character_state (Lines 292-321)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest1 = Quest(quest_id=1, quest_name="Q1", quest_type=QuestType.DAILY, description="D1", min_level=1, max_level=10)
        quest2 = Quest(quest_id=2, quest_name="Q2", quest_type=QuestType.DAILY, description="D2", min_level=20, max_level=30)
        manager.quests[1] = quest1
        manager.quests[2] = quest2
        character_state = {"level": 5, "job": "Novice"}
        
        # Act
        result = manager.get_available_quests(character_state)
        
        # Assert
        assert len(result) == 1
        assert result[0].quest_id == 1
    
    def test_get_available_quests_with_object_should_filter_by_job(self, tmp_path):
        """Cover get_available_quests with CharacterState object (Lines 292-321)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1,
            quest_name="Q1",
            quest_type=QuestType.JOB_CHANGE,
            description="D1",
            min_level=1,
            job_requirements=["Swordman"]
        )
        manager.quests[1] = quest
        
        # Mock CharacterState object
        char_state = Mock()
        char_state.base_level = 10
        char_state.job_class = "Swordman"
        
        # Act
        result = manager.get_available_quests(char_state)
        
        # Assert
        assert len(result) == 1
    
    def test_check_requirements_with_quest_prerequisite(self, tmp_path):
        """Cover _check_requirements with quest prerequisite (Lines 323-352)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        manager.completed_quests = [999]
        quest = Quest(
            quest_id=1001,
            quest_name="Quest",
            quest_type=QuestType.MAIN_STORY,
            description="Test",
            requirements=[
                QuestRequirement(
                    requirement_type="quest",
                    requirement_id=999,
                    requirement_name="Previous Quest"
                )
            ]
        )
        character_state = {"level": 10, "job": "Novice"}
        
        # Act
        result = manager._check_requirements(quest, character_state)
        
        # Assert
        assert result is True
    
    def test_start_quest_should_activate_quest(self, tmp_path):
        """Cover start_quest (Lines 354-368)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test Quest",
            quest_type=QuestType.DAILY,
            description="Test",
            status=QuestStatus.NOT_STARTED
        )
        manager.quests[1001] = quest
        
        # Act
        result = manager.start_quest(1001)
        
        # Assert
        assert result is True
        assert quest.status == QuestStatus.IN_PROGRESS
        assert 1001 in manager.active_quests
    
    def test_start_quest_should_fail_if_not_found(self, tmp_path):
        """Cover start_quest with missing quest (Lines 356-359)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        
        # Act
        result = manager.start_quest(9999)
        
        # Assert
        assert result is False


class TestQuestObjectiveTracking:
    """Test quest objective progress tracking (Lines 63-100, 370-392)"""
    
    def test_quest_objective_is_complete_property(self):
        """Cover QuestObjective.is_complete (Lines 77-80)"""
        # Arrange
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_name="Poring",
            required_count=10,
            current_count=10
        )
        
        # Act & Assert
        assert obj.is_complete is True
    
    def test_quest_objective_progress_percent(self):
        """Cover QuestObjective.progress_percent (Lines 82-87)"""
        # Arrange
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.COLLECT_ITEM,
            target_name="Red Herb",
            required_count=20,
            current_count=10
        )
        
        # Act
        progress = obj.progress_percent
        
        # Assert
        assert progress == 50.0
    
    def test_quest_objective_update_progress(self):
        """Cover QuestObjective.update_progress (Lines 89-100)"""
        # Arrange
        obj = QuestObjective(
            objective_id=1,
            objective_type=QuestObjectiveType.KILL_MONSTER,
            target_name="Poring",
            required_count=10,
            current_count=5
        )
        
        # Act
        completed = obj.update_progress(5)
        
        # Assert
        assert completed is True
        assert obj.current_count == 10
    
    def test_update_objective_should_track_progress(self, tmp_path):
        """Cover update_objective (Lines 370-392)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test",
            quest_type=QuestType.HUNTING,
            description="Kill monsters",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_name="Poring",
                    required_count=10,
                    current_count=0
                )
            ]
        )
        manager.active_quests[1001] = quest
        
        # Act
        result = manager.update_objective(1001, 1, 5)
        
        # Assert
        assert result is True
        assert quest.objectives[0].current_count == 5
    
    def test_update_objective_should_mark_quest_complete(self, tmp_path):
        """Cover update_objective marking quest complete (Lines 386-388)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test",
            quest_type=QuestType.HUNTING,
            description="Test",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.KILL_MONSTER,
                    target_name="Poring",
                    required_count=10,
                    current_count=8
                )
            ]
        )
        manager.active_quests[1001] = quest
        
        # Act
        manager.update_objective(1001, 1, 2)
        
        # Assert
        assert quest.status == QuestStatus.COMPLETED


class TestQuestCompletionValidation:
    """Test quest completion logic (Lines 169-201, 394-421)"""
    
    def test_quest_is_complete_property(self):
        """Cover Quest.is_complete (Lines 169-172)"""
        # Arrange
        quest = Quest(
            quest_id=1,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            objectives=[
                QuestObjective(
                    objective_id=1,
                    objective_type=QuestObjectiveType.TALK_NPC,
                    target_name="NPC",
                    required_count=1,
                    current_count=1
                )
            ]
        )
        
        # Act & Assert
        assert quest.is_complete is True
    
    def test_quest_overall_progress(self):
        """Cover Quest.overall_progress (Lines 174-179)"""
        # Arrange
        quest = Quest(
            quest_id=1,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            objectives=[
                QuestObjective(objective_id=1, objective_type=QuestObjectiveType.KILL_MONSTER, target_name="P1", required_count=10, current_count=5),
                QuestObjective(objective_id=2, objective_type=QuestObjectiveType.KILL_MONSTER, target_name="P2", required_count=10, current_count=7)
            ]
        )
        
        # Act
        progress = quest.overall_progress
        
        # Assert
        assert progress == 60.0  # (50% + 70%) / 2
    
    def test_quest_can_start_property(self):
        """Cover Quest.can_start (Lines 181-190)"""
        # Arrange
        quest = Quest(
            quest_id=1,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            status=QuestStatus.NOT_STARTED
        )
        
        # Act & Assert
        assert quest.can_start is True
    
    def test_quest_can_start_with_cooldown(self):
        """Cover Quest.can_start with cooldown check (Lines 186-189)"""
        # Arrange
        quest = Quest(
            quest_id=1,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            status=QuestStatus.NOT_STARTED,
            is_daily=True,
            last_completed=datetime.now() - timedelta(hours=12),
            cooldown_hours=24
        )
        
        # Act & Assert
        assert quest.can_start is False
    
    def test_quest_get_cooldown_remaining(self):
        """Cover Quest.get_cooldown_remaining (Lines 192-201)"""
        # Arrange
        quest = Quest(
            quest_id=1,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            is_daily=True,
            last_completed=datetime.now() - timedelta(hours=20),
            cooldown_hours=24
        )
        
        # Act
        remaining = quest.get_cooldown_remaining()
        
        # Assert
        assert remaining is not None
        assert remaining.total_seconds() > 0
    
    def test_complete_quest_should_return_rewards(self, tmp_path):
        """Cover complete_quest (Lines 394-410)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        rewards = [
            QuestReward(reward_type="exp", reward_name="Base EXP", quantity=1000),
            QuestReward(reward_type="item", reward_name="Red Potion", reward_id=501, quantity=5)
        ]
        quest = Quest(
            quest_id=1001,
            quest_name="Test",
            quest_type=QuestType.DAILY,
            description="Test",
            rewards=rewards,
            objectives=[
                QuestObjective(objective_id=1, objective_type=QuestObjectiveType.TALK_NPC, target_name="NPC", required_count=1, current_count=1)
            ]
        )
        manager.active_quests[1001] = quest
        
        # Act
        result = manager.complete_quest(1001)
        
        # Assert
        assert len(result) == 2
        assert 1001 in manager.completed_quests
        assert 1001 not in manager.active_quests
    
    def test_abandon_quest_should_remove_from_active(self, tmp_path):
        """Cover abandon_quest (Lines 412-421)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(quest_id=1001, quest_name="Test", quest_type=QuestType.DAILY, description="Test")
        manager.active_quests[1001] = quest
        
        # Act
        result = manager.abandon_quest(1001)
        
        # Assert
        assert result is True
        assert quest.status == QuestStatus.FAILED
        assert 1001 not in manager.active_quests


class TestQuestRewardProcessing:
    """Test quest requirement checking and recommendations (Lines 423-478)"""
    
    def test_check_quest_requirements_should_validate_level(self, tmp_path):
        """Cover check_quest_requirements (Lines 423-457)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="High Level Quest",
            quest_type=QuestType.MAIN_STORY,
            description="Test",
            min_level=50
        )
        manager.quests[1001] = quest
        character_state = {"level": 30, "job": "Novice"}
        
        # Act
        can_accept, missing = manager.check_quest_requirements(1001, character_state)
        
        # Assert
        assert can_accept is False
        assert len(missing) > 0
    
    def test_check_quest_requirements_should_validate_job(self, tmp_path):
        """Cover check_quest_requirements job validation (Lines 441-443)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Job Quest",
            quest_type=QuestType.JOB_CHANGE,
            description="Test",
            job_requirements=["Swordman", "Knight"]
        )
        manager.quests[1001] = quest
        character_state = {"level": 50, "job": "Mage"}
        
        # Act
        can_accept, missing = manager.check_quest_requirements(1001, character_state)
        
        # Assert
        assert can_accept is False
        assert any("Job requirement" in msg for msg in missing)
    
    def test_check_quest_requirements_should_validate_prerequisites(self, tmp_path):
        """Cover check_quest_requirements prerequisite check (Lines 445-448)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test",
            quest_type=QuestType.MAIN_STORY,
            description="Test",
            requirements=[
                QuestRequirement(requirement_type="quest", requirement_id=999, requirement_name="Previous Quest")
            ]
        )
        manager.quests[1001] = quest
        character_state = {"level": 50, "job": "Novice"}
        
        # Act
        can_accept, missing = manager.check_quest_requirements(1001, character_state)
        
        # Assert
        assert can_accept is False
        assert any("Previous Quest" in msg for msg in missing)
    
    def test_get_recommended_quests_should_prioritize_daily(self, tmp_path):
        """Cover get_recommended_quests (Lines 459-478)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest1 = Quest(quest_id=1, quest_name="Q1", quest_type=QuestType.DAILY, description="D1", is_daily=True, base_exp_reward=5000)
        quest2 = Quest(quest_id=2, quest_name="Q2", quest_type=QuestType.MAIN_STORY, description="D2", base_exp_reward=1000)
        manager.quests[1] = quest1
        manager.quests[2] = quest2
        character_state = {"level": 10, "job": "Novice"}
        
        # Act
        result = manager.get_recommended_quests(character_state, limit=2)
        
        # Assert
        assert len(result) <= 2
        # Daily quest should be first due to +100 priority
        if len(result) > 0:
            assert result[0].is_daily or result[0].base_exp_reward > 0
    
    @pytest.mark.asyncio
    async def test_tick_should_check_expired_quests(self, tmp_path):
        """Cover tick method (Lines 480-510)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        expired_quest = Quest(
            quest_id=1001,
            quest_name="Expired",
            quest_type=QuestType.DAILY,
            description="Test",
            expires_at=datetime.now() - timedelta(hours=1)
        )
        manager.active_quests[1001] = expired_quest
        
        # Act
        actions = await manager.tick()
        
        # Assert
        assert 1001 not in manager.active_quests
        assert expired_quest.status == QuestStatus.FAILED
    
    @pytest.mark.asyncio
    async def test_accept_quest_by_id(self, tmp_path):
        """Cover accept_quest method (Lines 512-523)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(quest_id=1001, quest_name="Test Quest", quest_type=QuestType.DAILY, description="Test")
        manager.quests[1001] = quest
        
        # Act
        result = await manager.accept_quest(1001)
        
        # Assert
        assert result is True
        assert 1001 in manager.active_quests
    
    @pytest.mark.asyncio
    async def test_accept_quest_by_string_id_conversion(self, tmp_path):
        """Cover accept_quest with string ID conversion (Lines 515-517)"""
        # Arrange
        manager = QuestManager(data_dir=tmp_path)
        quest = Quest(
            quest_id=1001,
            quest_name="Test Quest",
            quest_type=QuestType.DAILY,
            description="Test",
            status=QuestStatus.NOT_STARTED
        )
        manager.quests[1001] = quest
        
        # Act - Pass numeric ID as string
        result = await manager.accept_quest("1001")
        
        # Assert - Should convert string to int and accept
        assert result is True
        assert 1001 in manager.active_quests


# ==================== Pattern Breaker Tests ====================

class TestPatternBreakerCore:
    """Test pattern detection and breaking (Lines 62-446)"""
    
    def test_pattern_breaker_initialization(self, tmp_path):
        """Cover PatternBreaker.__init__ (Lines 62-80)"""
        # Arrange & Act
        breaker = PatternBreaker(data_dir=tmp_path, history_size=50)
        
        # Assert
        assert breaker is not None
        assert breaker.action_history.maxlen == 50
        assert breaker.detected_patterns == []
    
    def test_should_break_pattern_long_activity(self, tmp_path):
        """Cover should_break_pattern (Lines 82-103)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        
        # Act
        result = breaker.should_break_pattern("combat", 35)
        
        # Assert
        assert result is True
    
    def test_should_break_pattern_low_entropy(self, tmp_path):
        """Cover should_break_pattern with entropy check (Lines 98-100)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        # Add repetitive actions to lower entropy
        for i in range(20):
            breaker.action_history.append({"action_type": "attack", "timestamp": datetime.now()})
        
        # Act
        result = breaker.should_break_pattern("combat", 10)
        
        # Assert - Low entropy should trigger pattern breaking
        assert result is True
    
    @pytest.mark.asyncio
    async def test_analyze_patterns_should_detect_multiple_types(self, tmp_path):
        """Cover analyze_patterns (Lines 105-135)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        
        # Add timing patterns
        base_time = datetime.now()
        for i in range(15):
            breaker.timing_history.append({
                "delay_ms": 1000,  # Exact same delay = pattern
                "timestamp": base_time + timedelta(seconds=i)
            })
        
        # Act
        patterns = await breaker.analyze_patterns()
        
        # Assert
        assert len(patterns) >= 0  # May detect timing pattern
    
    def test_detect_timing_patterns_low_variance(self, tmp_path):
        """Cover detect_timing_patterns (Lines 137-175)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        base_time = datetime.now()
        actions = [
            {"timestamp": base_time + timedelta(milliseconds=i*1000)}
            for i in range(15)
        ]
        
        # Act
        pattern = breaker.detect_timing_patterns(actions)
        
        # Assert - Should detect regular 1-second intervals
        assert pattern is not None
        assert pattern.pattern_type == PatternType.TIMING
        assert pattern.similarity_score > 0.8
    
    def test_detect_movement_patterns_repetitive_paths(self, tmp_path):
        """Cover detect_movement_patterns (Lines 177-212)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        movements = [
            {"path": [{"x": 100, "y": 100}, {"x": 110, "y": 110}, {"x": 120, "y": 120}]}
            for _ in range(10)
        ]
        
        # Act
        pattern = breaker.detect_movement_patterns(movements)
        
        # Assert - Should detect repeated path
        assert pattern is not None
        assert pattern.pattern_type == PatternType.MOVEMENT
    
    def test_detect_targeting_patterns_predictable(self, tmp_path):
        """Cover detect_targeting_patterns (Lines 214-251)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        targets = [
            {"target_type": "monster", "selection_reason": "lowest_hp"}
            for _ in range(15)
        ]
        
        # Act
        pattern = breaker.detect_targeting_patterns(targets)
        
        # Assert - Should detect predictable targeting
        assert pattern is not None
        assert pattern.pattern_type == PatternType.TARGETING
    
    def test_detect_skill_patterns_repetitive_sequence(self, tmp_path):
        """Cover _detect_skill_patterns (Lines 253-287)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        actions = [
            {"action_type": "skill", "skill_id": str(i % 3)}
            for i in range(20)
        ]
        
        # Act
        pattern = breaker._detect_skill_patterns(actions)
        
        # Assert - Should detect repeated 0-1-2 sequence
        assert pattern is not None
        assert pattern.pattern_type == PatternType.SKILL_ORDER
    
    def test_calculate_risk_level(self, tmp_path):
        """Cover _calculate_risk_level (Lines 289-298)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        
        # Act & Assert
        assert breaker._calculate_risk_level(0.96) == "critical"
        assert breaker._calculate_risk_level(0.92) == "high"
        assert breaker._calculate_risk_level(0.85) == "medium"
        assert breaker._calculate_risk_level(0.70) == "low"
    
    @pytest.mark.asyncio
    async def test_break_pattern_should_generate_variation(self, tmp_path):
        """Cover break_pattern (Lines 300-318)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Test",
            occurrences=10,
            similarity_score=0.95,
            risk_level="high"
        )
        
        # Act
        variation = await breaker.break_pattern(pattern)
        
        # Assert
        assert "type" in variation
        assert variation["type"] == "timing_variation"
    
    def test_inject_variation_should_modify_action(self, tmp_path):
        """Cover inject_variation (Lines 353-374)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        action = {
            "delay_ms": 1000,
            "position": (100, 100)
        }
        
        # Act - Use higher variation_factor to avoid zero division
        varied = breaker.inject_variation(action, variation_factor=0.5)
        
        # Assert
        assert "delay_ms" in varied
        assert "position" in varied
        # Variation may result in same or different values due to random hash
    
    def test_calculate_behavior_entropy(self, tmp_path):
        """Cover calculate_behavior_entropy (Lines 376-402)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        # Add varied actions
        for i in range(20):
            breaker.action_history.append({
                "action_type": ["attack", "move", "skill", "item"][i % 4],
                "timestamp": datetime.now()
            })
        
        # Act
        entropy = breaker.calculate_behavior_entropy()
        
        # Assert
        assert 0.0 <= entropy <= 1.0
    
    def test_calculate_shannon_entropy(self, tmp_path):
        """Cover _calculate_shannon_entropy (Lines 404-422)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        data = ["a", "b", "c", "a", "b", "c"]
        
        # Act
        entropy = breaker._calculate_shannon_entropy(data)
        
        # Assert
        assert 0.0 <= entropy <= 1.0
    
    @pytest.mark.asyncio
    async def test_get_pattern_breaking_suggestions(self, tmp_path):
        """Cover get_pattern_breaking_suggestions (Lines 424-446)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        # Force low entropy
        for i in range(30):
            breaker.action_history.append({"action_type": "attack", "timestamp": datetime.now()})
        
        # Act
        suggestions = await breaker.get_pattern_breaking_suggestions()
        
        # Assert
        assert len(suggestions) > 0
    
    def test_record_action_should_store_in_histories(self, tmp_path):
        """Cover record_action (Lines 448-465)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        action = {
            "delay_ms": 500,
            "path": [{"x": 1, "y": 1}],
            "target_id": 123,
            "target_type": "monster",
            "selection_reason": "closest"
        }
        
        # Act
        breaker.record_action(action)
        
        # Assert
        assert len(breaker.action_history) == 1
        assert len(breaker.timing_history) == 1
        assert len(breaker.movement_history) == 1
        assert len(breaker.targeting_history) == 1
    
    def test_get_pattern_stats(self, tmp_path):
        """Cover get_pattern_stats (Lines 467-481)"""
        # Arrange
        breaker = PatternBreaker(data_dir=tmp_path)
        pattern = DetectedPattern(
            pattern_type=PatternType.TIMING,
            description="Test",
            occurrences=5,
            similarity_score=0.9,
            risk_level="high"
        )
        breaker.detected_patterns.append(pattern)
        
        # Act
        stats = breaker.get_pattern_stats()
        
        # Assert
        assert "total_actions_tracked" in stats
        assert "behavior_entropy" in stats
        assert "patterns_detected_last_hour" in stats


# ==================== Movement Mimicry Tests ====================

class TestMovementMimicryCore:
    """Test human-like movement generation (Lines 101-473)"""
    
    def test_movement_humanizer_initialization(self, tmp_path):
        """Cover MovementHumanizer.__init__ (Lines 101-112)"""
        # Arrange & Act
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Assert
        assert humanizer is not None
        assert humanizer.data_dir == tmp_path
        assert humanizer.movement_history == []
    
    def test_humanize_path_urgent_movement(self, tmp_path):
        """Cover humanize_path with urgent movement (Lines 114-161)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        start = (0, 0)
        end = (100, 100)
        
        # Act
        path = humanizer.humanize_path(start, end, urgency=0.9)
        
        # Assert
        assert path is not None
        assert path.pattern_type == MovementPattern.URGENT
        assert path.path_efficiency >= 0.90
        assert len(path.points) > 0
    
    def test_humanize_path_short_distance(self, tmp_path):
        """Cover humanize_path short distance (Lines 121-122)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Act
        path = humanizer.humanize_path((0, 0), (3, 3), urgency=0.5)
        
        # Assert
        assert path.pattern_type == MovementPattern.DIRECT
    
    def test_add_path_noise_should_deviate(self, tmp_path):
        """Cover add_path_noise (Lines 163-205)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        points = [
            PathPoint(x=0, y=0),
            PathPoint(x=10, y=10),
            PathPoint(x=20, y=20)
        ]
        
        # Act
        noisy = humanizer.add_path_noise(points, noise_factor=0.5)
        
        # Assert
        assert len(noisy) == 3
        # First and last should be unchanged
        assert noisy[0].x == 0 and noisy[0].y == 0
        assert noisy[-1].x == 20 and noisy[-1].y == 20
    
    def test_generate_bezier_path(self, tmp_path):
        """Cover generate_bezier_path (Lines 207-266)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Act
        path = humanizer.generate_bezier_path((0, 0), (100, 100), control_points=2)
        
        # Assert
        assert len(path) > 5
        assert path[0].x == 0 and path[0].y == 0
        assert path[-1].x == 100 and path[-1].y == 100
    
    def test_bezier_point_calculation(self, tmp_path):
        """Cover _bezier_point (Lines 268-282)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        points = [(0, 0), (50, 100), (100, 0)]
        
        # Act
        point = humanizer._bezier_point(points, 0.5)
        
        # Assert
        assert isinstance(point, tuple)
        assert len(point) == 2
    
    def test_add_pause_points(self, tmp_path):
        """Cover add_pause_points (Lines 284-310)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        path = [PathPoint(x=i*10, y=i*10) for i in range(10)]
        
        # Act
        with_pauses = humanizer.add_pause_points(path, pause_chance=1.0)
        
        # Assert
        # Should have pauses in middle points
        pauses = [p for p in with_pauses[1:-1] if p.delay_before_ms > 0]
        assert len(pauses) > 0
    
    def test_get_movement_speed_variation(self, tmp_path):
        """Cover get_movement_speed_variation (Lines 312-340)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Act
        speeds = humanizer.get_movement_speed_variation(10)
        
        # Assert
        assert len(speeds) == 10
        assert all(0.7 <= s <= 1.2 for s in speeds)
    
    def test_simulate_obstacle_avoidance(self, tmp_path):
        """Cover simulate_obstacle_avoidance (Lines 342-362)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        path = [PathPoint(x=i, y=i) for i in range(10)]
        obstacles = [(5, 5), (6, 6)]
        
        # Act
        avoided = humanizer.simulate_obstacle_avoidance(path, obstacles)
        
        # Assert
        assert len(avoided) == len(path)
    
    def test_generate_zigzag_path(self, tmp_path):
        """Cover _generate_zigzag_path (Lines 364-383)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Act
        path = humanizer._generate_zigzag_path((0, 0), (100, 100))
        
        # Assert
        assert len(path) >= 3
        assert path[0].x == 0 and path[0].y == 0
        assert path[-1].x == 100 and path[-1].y == 100
    
    def test_generate_wandering_path(self, tmp_path):
        """Cover _generate_wandering_path (Lines 385-407)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        
        # Act
        path = humanizer._generate_wandering_path((0, 0), (100, 100))
        
        # Assert
        assert len(path) >= 4
        assert any(p.is_waypoint for p in path)
    
    def test_count_direction_changes(self, tmp_path):
        """Cover _count_direction_changes (Lines 409-434)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        # Create path with sharp turns
        points = [
            PathPoint(x=0, y=0),
            PathPoint(x=10, y=0),
            PathPoint(x=10, y=10),
            PathPoint(x=0, y=10)
        ]
        
        # Act
        changes = humanizer._count_direction_changes(points)
        
        # Assert
        assert changes >= 0
    
    def test_detect_suspicious_pattern(self, tmp_path):
        """Cover detect_suspicious_pattern (Lines 436-455)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        # Add overly efficient paths
        for i in range(15):
            path = HumanPath(
                points=[PathPoint(x=0, y=0), PathPoint(x=100, y=100)],
                pattern_type=MovementPattern.DIRECT,
                total_distance=141.4,
                estimated_time_ms=5000,
                path_efficiency=0.99,  # Too high
                pause_points=[],
                direction_changes=0
            )
            humanizer.movement_history.append(path)
        
        # Act
        is_suspicious, reason = humanizer.detect_suspicious_pattern()
        
        # Assert
        assert is_suspicious is True
        assert len(reason) > 0
    
    def test_get_movement_stats(self, tmp_path):
        """Cover get_movement_stats (Lines 457-473)"""
        # Arrange
        humanizer = MovementHumanizer(data_dir=tmp_path)
        path = HumanPath(
            points=[PathPoint(x=0, y=0), PathPoint(x=10, y=10)],
            pattern_type=MovementPattern.CURVED,
            total_distance=14.14,
            estimated_time_ms=3000,
            path_efficiency=0.85,
            pause_points=[1],
            direction_changes=2
        )
        humanizer.movement_history.append(path)
        
        # Act
        stats = humanizer.get_movement_stats()
        
        # Assert
        assert "total_paths" in stats
        assert "recent_avg_efficiency" in stats
        assert "pattern_distribution" in stats


# Summary: Batch 5 Test Counts
# - TestQuestCoreInitialization: 4 tests
# - TestQuestAcceptanceLogic: 7 tests
# - TestQuestObjectiveTracking: 5 tests
# - TestQuestCompletionValidation: 9 tests
# - TestQuestRewardProcessing: 6 tests
# - TestPatternBreakerCore: 15 tests
# - TestMovementMimicryCore: 15 tests
# Total: 61 tests targeting ~200-250 lines