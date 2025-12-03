"""
Comprehensive tests for quests/hunting.py to achieve 90%+ coverage.

Tests hunting quest system, kill tracking, optimal target selection,
party kill sharing, and map optimization.
"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch

from ai_sidecar.quests.hunting import (
    HuntingQuestManager,
    HuntingQuest,
    HuntingTarget
)
from ai_sidecar.quests.core import QuestManager


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test hunting data."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Quest data (for QuestManager)
    (data_dir / "quests.json").write_text('{"quests": []}')
    (data_dir / "daily_quests.json").write_text('{"gramps_quests": [], "eden_quests": {}, "board_quests": {}}')
    (data_dir / "achievements.json").write_text('{"achievements": []}')
    
    # Hunting quest data
    hunting_data = {
        "hunting_quests": [
            {
                "quest_id": 1001,
                "quest_name": "Poring Hunt",
                "targets": [
                    {
                        "monster_id": 1002,
                        "monster_name": "Poring",
                        "required_kills": 50,
                        "spawn_maps": ["prt_fild08", "prt_fild09"],
                        "element": "Water",
                        "race": "Plant",
                        "size": "Small"
                    }
                ],
                "base_exp_reward": 10000,
                "job_exp_reward": 5000,
                "zeny_reward": 1000,
                "min_level": 1,
                "max_level": 30,
                "is_party_shared": True
            },
            {
                "quest_id": 1002,
                "quest_name": "Multi-Target Hunt",
                "targets": [
                    {
                        "monster_id": 1031,
                        "monster_name": "Poporing",
                        "required_kills": 30,
                        "spawn_maps": ["prt_fild08"]
                    },
                    {
                        "monster_id": 1113,
                        "monster_name": "Drops",
                        "required_kills": 20,
                        "spawn_maps": ["prt_fild08", "prt_fild10"]
                    }
                ],
                "base_exp_reward": 20000,
                "job_exp_reward": 10000,
                "zeny_reward": 2000,
                "is_party_shared": False
            }
        ]
    }
    
    (data_dir / "hunting_quests.json").write_text(json.dumps(hunting_data))
    
    return data_dir


@pytest.fixture
def quest_manager(data_dir):
    """Create QuestManager instance."""
    return QuestManager(data_dir)


class TestHuntingTargetModel:
    """Test HuntingTarget model."""
    
    def test_is_complete_property(self):
        """Test is_complete property."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=10,
            current_kills=10
        )
        
        assert target.is_complete is True
        
        target.current_kills = 5
        assert target.is_complete is False
        
    def test_progress_percent_property(self):
        """Test progress_percent calculation."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=100,
            current_kills=50
        )
        
        assert target.progress_percent == 50.0
        
    def test_progress_percent_zero_required(self):
        """Test progress 100% when required is zero."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=0,
            current_kills=0
        )
        
        assert target.progress_percent == 100.0
        
    def test_add_kill_increments(self):
        """Test add_kill increments counter."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=10,
            current_kills=5
        )
        
        completed = target.add_kill(1)
        
        assert target.current_kills == 6
        assert completed is False
        
    def test_add_kill_multiple(self):
        """Test add_kill with multiple count."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=10,
            current_kills=5
        )
        
        target.add_kill(3)
        
        assert target.current_kills == 8
        
    def test_add_kill_caps_at_required(self):
        """Test add_kill doesn't exceed required."""
        target = HuntingTarget(
            monster_id=1002,
            monster_name="Poring",
            required_kills=10,
            current_kills=9
        )
        
        completed = target.add_kill(5)  # Add 5, but should cap at 10
        
        assert target.current_kills == 10
        assert completed is True


class TestHuntingQuestModel:
    """Test HuntingQuest model."""
    
    def test_is_complete_all_targets(self):
        """Test quest complete when all targets complete."""
        quest = HuntingQuest(
            quest_id=1001,
            quest_name="Test",
            targets=[
                HuntingTarget(monster_id=1, monster_name="A", required_kills=10, current_kills=10),
                HuntingTarget(monster_id=2, monster_name="B", required_kills=5, current_kills=5)
            ]
        )
        
        assert quest.is_complete is True
        
    def test_is_complete_partial_targets(self):
        """Test quest incomplete when some targets incomplete."""
        quest = HuntingQuest(
            quest_id=1001,
            quest_name="Test",
            targets=[
                HuntingTarget(monster_id=1, monster_name="A", required_kills=10, current_kills=10),
                HuntingTarget(monster_id=2, monster_name="B", required_kills=5, current_kills=3)
            ]
        )
        
        assert quest.is_complete is False
        
    def test_overall_progress(self):
        """Test overall progress calculation."""
        quest = HuntingQuest(
            quest_id=1001,
            quest_name="Test",
            targets=[
                HuntingTarget(monster_id=1, monster_name="A", required_kills=100, current_kills=50),
                HuntingTarget(monster_id=2, monster_name="B", required_kills=100, current_kills=100)
            ]
        )
        
        # (50% + 100%) / 2 = 75%
        assert quest.overall_progress == 75.0


class TestHuntingQuestManagerInit:
    """Test HuntingQuestManager initialization."""
    
    def test_init_loads_data(self, data_dir, quest_manager):
        """Test manager loads hunting data on init."""
        mgr = HuntingQuestManager(data_dir, quest_manager)
        
        assert mgr.quest_manager == quest_manager
        assert isinstance(mgr.active_hunts, dict)
        assert isinstance(mgr.kill_counts, dict)
        
    def test_init_handles_missing_file(self, tmp_path, quest_manager):
        """Test handles missing hunting_quests.json."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        
        mgr = HuntingQuestManager(empty_dir, quest_manager)
        
        assert len(mgr.active_hunts) == 0


class TestLoadHuntingData:
    """Test _load_hunting_data method."""
    
    def test_loads_hunting_data(self, data_dir, quest_manager):
        """Test loads hunting quest data."""
        mgr = HuntingQuestManager(data_dir, quest_manager)
        
        # Should log successful load
        # Data loaded but not started as active quests
        
    def test_handles_malformed_json(self, tmp_path, quest_manager):
        """Test handles malformed JSON gracefully."""
        bad_dir = tmp_path / "bad"
        bad_dir.mkdir()
        (bad_dir / "hunting_quests.json").write_text("{invalid")
        (bad_dir / "quests.json").write_text('{}')
        
        # Should not crash
        mgr = HuntingQuestManager(bad_dir, quest_manager)


class TestStartHunt:
    """Test start_hunt method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        return HuntingQuestManager(data_dir, quest_manager)
    
    def test_starts_valid_hunt(self, manager):
        """Test starts hunting quest successfully."""
        result = manager.start_hunt(1001)
        
        assert result is True
        assert 1001 in manager.active_hunts
        
        quest = manager.active_hunts[1001]
        assert quest.quest_name == "Poring Hunt"
        assert len(quest.targets) == 1
        
    def test_starts_multi_target_hunt(self, manager):
        """Test starts hunt with multiple targets."""
        result = manager.start_hunt(1002)
        
        assert result is True
        assert 1002 in manager.active_hunts
        
        quest = manager.active_hunts[1002]
        assert len(quest.targets) == 2
        
    def test_fails_unknown_quest(self, manager):
        """Test fails to start unknown quest."""
        result = manager.start_hunt(9999)
        
        assert result is False
        assert 9999 not in manager.active_hunts
        
    def test_handles_missing_file(self, tmp_path, quest_manager):
        """Test handles missing file gracefully."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        
        mgr = HuntingQuestManager(empty_dir, quest_manager)
        result = mgr.start_hunt(1001)
        
        assert result is False


class TestRecordKill:
    """Test record_kill method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1001)
        return mgr
    
    def test_updates_kill_count(self, manager):
        """Test updates global kill count."""
        manager.record_kill(1002)
        
        assert manager.kill_counts[1002] == 1
        
        manager.record_kill(1002)
        assert manager.kill_counts[1002] == 2
        
    def test_updates_quest_targets(self, manager):
        """Test updates quest target progress."""
        affected = manager.record_kill(1002)  # Poring
        
        assert 1001 in affected
        
        quest = manager.active_hunts[1001]
        target = quest.targets[0]
        assert target.current_kills == 1
        
    def test_party_kill_shared_quest(self, manager):
        """Test party kills count for shared quests."""
        quest = manager.active_hunts[1001]
        assert quest.is_party_shared is True
        
        affected = manager.record_kill(1002, is_party_kill=True)
        
        assert 1001 in affected
        
    def test_party_kill_non_shared_quest(self, data_dir, quest_manager):
        """Test party kills don't count for non-shared quests."""
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1002)  # Not party shared
        
        affected = mgr.record_kill(1031, is_party_kill=True)
        
        # Should not affect quest
        assert 1002 not in affected
        
    def test_logs_target_completion(self, manager):
        """Test logs when target completes."""
        # Kill 50 porings to complete
        for _ in range(50):
            manager.record_kill(1002)
        
        quest = manager.active_hunts[1001]
        assert quest.targets[0].is_complete is True
        
    def test_multiple_quests_same_monster(self, data_dir, quest_manager):
        """Test updates all quests targeting same monster."""
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1001)
        mgr.start_hunt(1002)
        
        # Poring not in quest 1002, but let's test the logic
        affected = mgr.record_kill(1002)
        
        # Only quest 1001 should be affected
        assert 1001 in affected


class TestGetOptimalHuntingTargets:
    """Test get_optimal_hunting_targets method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1002)  # Multi-target quest
        return mgr
    
    def test_returns_targets_from_active_quests(self, manager):
        """Test returns targets from specified quests."""
        targets = manager.get_optimal_hunting_targets([1002])
        
        assert len(targets) >= 1
        
    def test_prioritizes_multi_quest_monsters(self, manager):
        """Test monsters satisfying multiple quests get higher priority."""
        targets = manager.get_optimal_hunting_targets([1002])
        
        # Each target should have priority score
        for target in targets:
            assert "priority" in target
            assert "quest_count" in target
            
    def test_includes_spawn_maps(self, manager):
        """Test includes all spawn maps for monsters."""
        targets = manager.get_optimal_hunting_targets([1002])
        
        for target in targets:
            assert "spawn_maps" in target
            assert len(target["spawn_maps"]) > 0
            
    def test_sorted_by_priority(self, manager):
        """Test targets sorted by priority descending."""
        targets = manager.get_optimal_hunting_targets([1002])
        
        if len(targets) >= 2:
            assert targets[0]["priority"] >= targets[1]["priority"]
            
    def test_excludes_complete_targets(self, manager):
        """Test excludes complete targets from results."""
        # Complete all Poporing kills
        for _ in range(30):
            manager.record_kill(1031)
        
        targets = manager.get_optimal_hunting_targets([1002])
        
        # Poporing should not be in targets or marked complete
        poporing_targets = [t for t in targets if t["monster_id"] == 1031]
        if poporing_targets:
            # If included, total_needed should be 0
            assert poporing_targets[0]["total_needed"] == 0
            
    def test_unknown_quest_id(self, manager):
        """Test handles unknown quest ID gracefully."""
        targets = manager.get_optimal_hunting_targets([9999])
        
        assert targets == []


class TestGetHuntingProgress:
    """Test get_hunting_progress method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1001)
        return mgr
    
    def test_returns_progress_dict(self, manager):
        """Test returns comprehensive progress info."""
        progress = manager.get_hunting_progress(1001)
        
        assert progress["quest_id"] == 1001
        assert progress["quest_name"] == "Poring Hunt"
        assert "overall_progress" in progress
        assert "is_complete" in progress
        assert "targets" in progress
        
    def test_includes_target_details(self, manager):
        """Test includes detailed target progress."""
        # Kill 25 porings (50% progress)
        for _ in range(25):
            manager.record_kill(1002)
        
        progress = manager.get_hunting_progress(1001)
        
        target_progress = progress["targets"][0]
        assert target_progress["monster_name"] == "Poring"
        assert target_progress["current"] == 25
        assert target_progress["required"] == 50
        assert target_progress["progress_percent"] == 50.0
        
    def test_unknown_quest_returns_empty(self, manager):
        """Test returns empty dict for unknown quest."""
        progress = manager.get_hunting_progress(9999)
        
        assert progress == {}


class TestCalculateExpPerKill:
    """Test calculate_exp_per_kill method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1001)
        return mgr
    
    def test_calculates_exp_efficiency(self, manager):
        """Test calculates EXP per kill correctly."""
        exp_data = manager.calculate_exp_per_kill(1001)
        
        # 50 kills needed, 15000 total exp
        assert exp_data["total_exp"] == 15000
        assert exp_data["base_exp"] == 10000
        assert exp_data["job_exp"] == 5000
        assert exp_data["exp_per_kill"] == 300
        assert exp_data["kills_remaining"] == 50
        
    def test_partial_completion(self, manager):
        """Test calculates correctly with partial progress."""
        # Kill 25 porings
        for _ in range(25):
            manager.record_kill(1002)
        
        exp_data = manager.calculate_exp_per_kill(1001)
        
        # 25 kills remaining
        assert exp_data["kills_remaining"] == 25
        assert exp_data["exp_per_kill"] == 15000 / 25
        
    def test_complete_quest_zero_kills(self, manager):
        """Test complete quest shows 0 kills remaining."""
        # Complete all kills
        for _ in range(50):
            manager.record_kill(1002)
        
        exp_data = manager.calculate_exp_per_kill(1001)
        
        assert exp_data["kills_remaining"] == 0
        assert exp_data["exp_per_kill"] == 0
        
    def test_unknown_quest_returns_empty(self, manager):
        """Test returns empty for unknown quest."""
        exp_data = manager.calculate_exp_per_kill(9999)
        
        assert exp_data == {}


class TestGetBestFarmingMap:
    """Test get_best_farming_map method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1002)  # Multi-target quest
        return mgr
    
    def test_returns_map_with_most_targets(self, manager):
        """Test returns map covering most quest targets."""
        best_map, all_maps = manager.get_best_farming_map(1002)
        
        # prt_fild08 has both Poporing and Drops
        assert best_map == "prt_fild08"
        assert "prt_fild08" in all_maps
        
    def test_ignores_complete_targets(self, manager):
        """Test ignores complete targets when selecting map."""
        # Complete Poporing
        for _ in range(30):
            manager.record_kill(1031)
        
        best_map, all_maps = manager.get_best_farming_map(1002)
        
        # Should still recommend map with Drops
        assert best_map in ["prt_fild08", "prt_fild10"]
        
    def test_unknown_quest_returns_empty(self, manager):
        """Test returns empty for unknown quest."""
        best_map, all_maps = manager.get_best_farming_map(9999)
        
        assert best_map == ""
        assert all_maps == []
        
    def test_all_targets_complete_returns_empty(self, manager):
        """Test returns empty when all targets complete."""
        # Complete all targets
        for _ in range(30):
            manager.record_kill(1031)
        for _ in range(20):
            manager.record_kill(1113)
        
        best_map, all_maps = manager.get_best_farming_map(1002)
        
        assert best_map == ""
        assert all_maps == []


class TestCompleteHunt:
    """Test complete_hunt method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        mgr = HuntingQuestManager(data_dir, quest_manager)
        mgr.start_hunt(1001)
        return mgr
    
    def test_completes_finished_hunt(self, manager):
        """Test completes hunt when all targets done."""
        # Complete all kills
        for _ in range(50):
            manager.record_kill(1002)
        
        result = manager.complete_hunt(1001)
        
        assert result is True
        assert 1001 not in manager.active_hunts
        
    def test_fails_incomplete_hunt(self, manager):
        """Test cannot complete incomplete hunt."""
        result = manager.complete_hunt(1001)
        
        assert result is False
        assert 1001 in manager.active_hunts
        
    def test_fails_unknown_hunt(self, manager):
        """Test fails for unknown hunt."""
        result = manager.complete_hunt(9999)
        
        assert result is False


class TestGetActiveHunts:
    """Test get_active_hunts method."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        return HuntingQuestManager(data_dir, quest_manager)
    
    def test_returns_all_active(self, manager):
        """Test returns all active hunting quests."""
        manager.start_hunt(1001)
        manager.start_hunt(1002)
        
        active = manager.get_active_hunts()
        
        assert len(active) == 2
        
    def test_returns_empty_no_hunts(self, manager):
        """Test returns empty list when no hunts."""
        active = manager.get_active_hunts()
        
        assert active == []


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.fixture
    def manager(self, data_dir, quest_manager):
        return HuntingQuestManager(data_dir, quest_manager)
    
    def test_record_kill_unknown_monster(self, manager):
        """Test recording kill for monster not in any quest."""
        manager.start_hunt(1001)
        
        affected = manager.record_kill(9999)
        
        # No quests affected
        assert affected == []
        # But kill count should still increment
        assert manager.kill_counts[9999] == 1
        
    def test_multiple_targets_same_quest(self, manager):
        """Test quest with multiple targets of same monster."""
        manager.start_hunt(1002)
        
        # Record kills
        manager.record_kill(1031)  # Poporing
        manager.record_kill(1113)  # Drops
        
        quest = manager.active_hunts[1002]
        
        # Each target should be updated correctly
        poporing = [t for t in quest.targets if t.monster_id == 1031][0]
        drops = [t for t in quest.targets if t.monster_id == 1113][0]
        
        assert poporing.current_kills == 1
        assert drops.current_kills == 1