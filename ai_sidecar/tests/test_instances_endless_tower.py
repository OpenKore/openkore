"""
Comprehensive tests for instances/endless_tower.py module.

Tests Endless Tower instance handling including:
- Floor strategies
- MVP floor handling
- Checkpoint system
- Party requirements
- Stopping point optimization
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch
import json

from ai_sidecar.instances.endless_tower import (
    ETFloorData,
    EndlessTowerHandler
)
from ai_sidecar.instances.state import InstanceState, InstanceType
from ai_sidecar.instances.strategy import FloorStrategy, InstanceAction


class TestETFloorDataModel:
    """Test ETFloorData model."""
    
    def test_floor_data_creation(self):
        """Test ETFloorData creation."""
        floor = ETFloorData(
            floor_number=25,
            monster_types=["Amon Ra"],
            boss_name="Amon Ra",
            mvp_floor=True,
            recommended_level=85,
            danger_rating=8
        )
        assert floor.floor_number == 25
        assert floor.mvp_floor is True
        assert floor.boss_name == "Amon Ra"
    
    def test_floor_data_regular_floor(self):
        """Test regular floor data."""
        floor = ETFloorData(
            floor_number=10,
            monster_types=["Mixed"],
            monster_count=10,
            recommended_level=60,
            danger_rating=3
        )
        assert floor.mvp_floor is False
        assert floor.boss_name is None


class TestEndlessTowerHandlerInit:
    """Test EndlessTowerHandler initialization."""
    
    def test_init_without_data_dir(self):
        """Test initialization without data directory."""
        handler = EndlessTowerHandler()
        
        assert len(handler.floor_data) == 100  # All floors
        assert handler.floor_data[25].mvp_floor is True
    
    def test_init_with_data_dir(self, tmp_path):
        """Test initialization with data directory."""
        # Create test floor data file
        floors_file = tmp_path / "endless_tower_floors.json"
        test_data = {
            "25": {
                "monster_types": ["Amon Ra"],
                "boss_name": "Amon Ra",
                "mvp_floor": True,
                "recommended_level": 85,
                "danger_rating": 8,
                "monster_count": 0
            }
        }
        floors_file.write_text(json.dumps(test_data))
        
        handler = EndlessTowerHandler(data_dir=tmp_path)
        
        assert 25 in handler.floor_data
        assert handler.floor_data[25].boss_name == "Amon Ra"
    
    def test_init_generates_all_floors(self):
        """Test all 100 floors are generated."""
        handler = EndlessTowerHandler()
        
        assert len(handler.floor_data) == 100
        for floor in range(1, 101):
            assert floor in handler.floor_data
    
    def test_init_mvp_floors_correct(self):
        """Test MVP floors are correctly identified."""
        handler = EndlessTowerHandler()
        
        assert handler.floor_data[25].mvp_floor is True
        assert handler.floor_data[50].mvp_floor is True
        assert handler.floor_data[75].mvp_floor is True
        assert handler.floor_data[100].mvp_floor is True
        
        assert handler.floor_data[24].mvp_floor is False
        assert handler.floor_data[26].mvp_floor is False


class TestGetFloorStrategy:
    """Test floor strategy generation."""
    
    @pytest.mark.asyncio
    async def test_get_strategy_mvp_floor(self):
        """Test strategy for MVP floor."""
        handler = EndlessTowerHandler()
        character_state = {"base_level": 99}
        
        strategy = await handler.get_floor_strategy(
            floor=25,
            character_state=character_state
        )
        
        assert strategy.floor_number == 25
        assert len(strategy.buff_requirements) > 0
        assert "Assumptio" in strategy.buff_requirements
    
    @pytest.mark.asyncio
    async def test_get_strategy_regular_floor(self):
        """Test strategy for regular floor."""
        handler = EndlessTowerHandler()
        character_state = {"base_level": 99}
        
        strategy = await handler.get_floor_strategy(
            floor=10,
            character_state=character_state
        )
        
        assert strategy.floor_number == 10
        assert len(strategy.special_mechanics) > 0
    
    @pytest.mark.asyncio
    async def test_get_strategy_first_floor(self):
        """Test strategy for first floor includes buffs."""
        handler = EndlessTowerHandler()
        character_state = {"base_level": 99}
        
        strategy = await handler.get_floor_strategy(
            floor=1,
            character_state=character_state
        )
        
        assert "Bless" in strategy.buff_requirements


class TestCanHandleFloor:
    """Test floor capability checks."""
    
    @pytest.mark.asyncio
    async def test_can_handle_level_sufficient(self):
        """Test handling floor with sufficient level."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 85,
            "gear_score": 5000,
            "party_size": 1
        }
        
        can_handle, reason = await handler.can_handle_floor(
            floor=25,
            character_state=character_state
        )
        
        # Might fail due to other requirements, but shouldn't fail on level
        if not can_handle:
            assert "Level too low" not in reason
    
    @pytest.mark.asyncio
    async def test_can_handle_level_too_low(self):
        """Test rejection when level too low."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 50,
            "gear_score": 5000,
            "party_size": 1
        }
        
        can_handle, reason = await handler.can_handle_floor(
            floor=25,
            character_state=character_state
        )
        
        assert can_handle is False
        assert "Level too low" in reason
    
    @pytest.mark.asyncio
    async def test_can_handle_mvp_solo_low_gear(self):
        """Test MVP floor solo with low gear."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 3000,
            "party_size": 1,
            "consumables": {"Yggdrasil Leaf": 5}
        }
        
        can_handle, reason = await handler.can_handle_floor(
            floor=25,
            character_state=character_state
        )
        
        assert can_handle is False
        assert "requires better gear" in reason
    
    @pytest.mark.asyncio
    async def test_can_handle_mvp_no_ygg_leaf(self):
        """Test MVP floor without Yggdrasil Leaf."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 6000,
            "party_size": 1,
            "consumables": {}
        }
        
        can_handle, reason = await handler.can_handle_floor(
            floor=50,
            character_state=character_state
        )
        
        assert can_handle is False
        assert "Yggdrasil Leaf" in reason
    
    @pytest.mark.asyncio
    async def test_can_handle_high_danger_solo(self):
        """Test high danger floor solo."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 3000,
            "party_size": 1
        }
        
        can_handle, reason = await handler.can_handle_floor(
            floor=75,
            character_state=character_state
        )
        
        # Floor 75 is MVP with high danger
        assert can_handle is False


class TestGetStoppingPoint:
    """Test optimal stopping point calculation."""
    
    @pytest.mark.asyncio
    async def test_stopping_point_low_level(self):
        """Test stopping point for low-level character."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 60,
            "gear_score": 3000,
            "party_size": 1,
            "time_remaining_minutes": 240,
            "consumables": {"Yggdrasil Leaf": 5}
        }
        
        stop_floor = await handler.get_stopping_point(
            character_state=character_state,
            current_floor=1
        )
        
        # Should stop before hitting level walls
        assert stop_floor < 100
    
    @pytest.mark.asyncio
    async def test_stopping_point_time_limited(self):
        """Test stopping at checkpoint with limited time."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 8000,
            "party_size": 1,
            "time_remaining_minutes": 50,
            "consumables": {"Yggdrasil Leaf": 10}
        }
        
        stop_floor = await handler.get_stopping_point(
            character_state=character_state,
            current_floor=20
        )
        
        # Should stop at checkpoint 26 due to time
        assert stop_floor in handler.CHECKPOINT_FLOORS or stop_floor < 50
    
    @pytest.mark.asyncio
    async def test_stopping_point_before_mvp_underprepared(self):
        """Test stopping before MVP when underprepared."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 4000,  # Low gear
            "party_size": 1,
            "time_remaining_minutes": 240,
            "consumables": {"Yggdrasil Leaf": 5}
        }
        
        stop_floor = await handler.get_stopping_point(
            character_state=character_state,
            current_floor=20
        )
        
        # Should recommend stopping before floor 25 MVP
        assert stop_floor == 24


class TestHandleMVPFloor:
    """Test MVP floor special handling."""
    
    @pytest.mark.asyncio
    async def test_handle_mvp_floor_25(self):
        """Test handling floor 25 MVP."""
        handler = EndlessTowerHandler()
        state = InstanceState(
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=25,
            time_remaining_minutes=180
        )
        
        actions = await handler.handle_mvp_floor(floor=25, state=state)
        
        assert len(actions) > 0
        # Should include buff, safety check, positioning
        action_types = [a.action_type for a in actions]
        assert "buff" in action_types
    
    @pytest.mark.asyncio
    async def test_handle_mvp_floor_non_mvp(self):
        """Test handling non-MVP floor."""
        handler = EndlessTowerHandler()
        state = InstanceState(
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=10,
            time_remaining_minutes=180
        )
        
        actions = await handler.handle_mvp_floor(floor=10, state=state)
        
        assert len(actions) == 0


class TestShouldContinuePastMVP:
    """Test continuation decision after MVP."""
    
    @pytest.mark.asyncio
    async def test_continue_sufficient_resources(self):
        """Test continuing with sufficient resources."""
        from datetime import datetime, timedelta
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 7000,
            "consumables": {"White Potion": 50, "Yggdrasil Leaf": 5}
        }
        # Set time_limit to create high time_remaining_percent
        now = datetime.now()
        state = InstanceState(
            instance_id="et_test_003",
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=25,
            started_at=now,
            time_limit=now + timedelta(minutes=180)
        )
        
        should_continue = await handler.should_continue_past_mvp(
            floor=25,
            character_state=character_state,
            state=state
        )
        
        assert should_continue is True
    
    @pytest.mark.asyncio
    async def test_continue_low_resources(self):
        """Test stopping with low resources."""
        from datetime import datetime, timedelta
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 7000,
            "consumables": {"White Potion": 10}  # Low potions
        }
        now = datetime.now()
        state = InstanceState(
            instance_id="et_test_004",
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=25,
            started_at=now,
            time_limit=now + timedelta(minutes=180)
        )
        
        should_continue = await handler.should_continue_past_mvp(
            floor=25,
            character_state=character_state,
            state=state
        )
        
        assert should_continue is False
    
    @pytest.mark.asyncio
    async def test_continue_low_time(self):
        """Test stopping with low time."""
        from datetime import datetime, timedelta
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 7000,
            "consumables": {"White Potion": 50}
        }
        # Set low time remaining
        now = datetime.now()
        state = InstanceState(
            instance_id="et_test_005",
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=25,
            started_at=now - timedelta(minutes=120),
            time_limit=now + timedelta(minutes=30)
        )
        
        should_continue = await handler.should_continue_past_mvp(
            floor=25,
            character_state=character_state,
            state=state
        )
        
        assert should_continue is False
    
    @pytest.mark.asyncio
    async def test_continue_too_many_deaths(self):
        """Test stopping after multiple deaths."""
        from datetime import datetime, timedelta
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 7000,
            "consumables": {"White Potion": 50}
        }
        now = datetime.now()
        state = InstanceState(
            instance_id="et_test_006",
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=50,
            started_at=now,
            time_limit=now + timedelta(minutes=120),
            deaths=3
        )
        
        should_continue = await handler.should_continue_past_mvp(
            floor=50,
            character_state=character_state,
            state=state
        )
        
        assert should_continue is False
    
    @pytest.mark.asyncio
    async def test_continue_cannot_handle_next_mvp(self):
        """Test stopping when can't handle next MVP."""
        from datetime import datetime, timedelta
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 70,  # Too low for floor 50
            "gear_score": 4000,
            "consumables": {"White Potion": 50}
        }
        now = datetime.now()
        state = InstanceState(
            instance_id="et_test_007",
            instance_name="Endless Tower",
            type=InstanceType.ENDLESS_TOWER,
            current_floor=25,
            started_at=now,
            time_limit=now + timedelta(minutes=180)
        )
        
        should_continue = await handler.should_continue_past_mvp(
            floor=25,
            character_state=character_state,
            state=state
        )
        
        assert should_continue is False


class TestMVPFloorChecks:
    """Test MVP floor identification."""
    
    def test_is_mvp_floor_true(self):
        """Test MVP floor identification."""
        handler = EndlessTowerHandler()
        
        assert handler.is_mvp_floor(25) is True
        assert handler.is_mvp_floor(50) is True
        assert handler.is_mvp_floor(75) is True
        assert handler.is_mvp_floor(100) is True
    
    def test_is_mvp_floor_false(self):
        """Test non-MVP floor identification."""
        handler = EndlessTowerHandler()
        
        assert handler.is_mvp_floor(10) is False
        assert handler.is_mvp_floor(24) is False
        assert handler.is_mvp_floor(26) is False


class TestCheckpointSystem:
    """Test checkpoint floor functionality."""
    
    def test_is_checkpoint_floor_true(self):
        """Test checkpoint identification."""
        handler = EndlessTowerHandler()
        
        assert handler.is_checkpoint_floor(26) is True
        assert handler.is_checkpoint_floor(51) is True
        assert handler.is_checkpoint_floor(77) is True
    
    def test_is_checkpoint_floor_false(self):
        """Test non-checkpoint identification."""
        handler = EndlessTowerHandler()
        
        assert handler.is_checkpoint_floor(25) is False
        assert handler.is_checkpoint_floor(50) is False
        assert handler.is_checkpoint_floor(100) is False
    
    def test_get_next_checkpoint_from_start(self):
        """Test getting next checkpoint from start."""
        handler = EndlessTowerHandler()
        
        next_cp = handler.get_next_checkpoint(current_floor=1)
        
        assert next_cp == 26
    
    def test_get_next_checkpoint_mid_tower(self):
        """Test getting next checkpoint from middle."""
        handler = EndlessTowerHandler()
        
        next_cp = handler.get_next_checkpoint(current_floor=30)
        
        assert next_cp == 51
    
    def test_get_next_checkpoint_near_end(self):
        """Test getting next checkpoint near end."""
        handler = EndlessTowerHandler()
        
        next_cp = handler.get_next_checkpoint(current_floor=80)
        
        assert next_cp is None  # No checkpoints after 77


class TestGetFloorInfo:
    """Test floor info retrieval."""
    
    def test_get_floor_info_exists(self):
        """Test getting existing floor info."""
        handler = EndlessTowerHandler()
        
        info = handler.get_floor_info(floor=25)
        
        assert info is not None
        assert info.floor_number == 25
        assert info.mvp_floor is True
    
    def test_get_floor_info_not_exists(self):
        """Test getting non-existent floor info."""
        handler = EndlessTowerHandler()
        
        info = handler.get_floor_info(floor=999)
        
        assert info is None


class TestFloorDataGeneration:
    """Test floor data generation."""
    
    def test_generated_regular_floors_increase_difficulty(self):
        """Test difficulty progression in regular floors."""
        handler = EndlessTowerHandler()
        
        floor_10 = handler.floor_data[10]
        floor_50_minus = handler.floor_data[49]
        floor_90 = handler.floor_data[90]
        
        # Difficulty should generally increase
        assert floor_10.danger_rating <= floor_50_minus.danger_rating
        assert floor_50_minus.danger_rating <= floor_90.danger_rating
    
    def test_generated_mvp_bosses_assigned(self):
        """Test MVP bosses are assigned."""
        handler = EndlessTowerHandler()
        
        assert handler.floor_data[25].boss_name == "Amon Ra"
        assert handler.floor_data[50].boss_name == "Drake"
        assert handler.floor_data[75].boss_name == "Osiris"
        assert handler.floor_data[100].boss_name == "Naght Sieger"


class TestLoadFloorDataEdgeCases:
    """Test floor data loading edge cases."""
    
    def test_load_with_missing_file(self, tmp_path):
        """Test loading when file doesn't exist."""
        handler = EndlessTowerHandler(data_dir=tmp_path)
        
        # Should fall back to defaults
        assert len(handler.floor_data) == 100
    
    def test_load_with_invalid_json(self, tmp_path):
        """Test loading with corrupted file."""
        floors_file = tmp_path / "endless_tower_floors.json"
        floors_file.write_text("{ invalid json")
        
        handler = EndlessTowerHandler(data_dir=tmp_path)
        
        # Should fall back to defaults
        assert len(handler.floor_data) == 100


class TestMVPFloorConstants:
    """Test MVP floor constants."""
    
    def test_mvp_floors_dict(self):
        """Test MVP_FLOORS dictionary."""
        assert EndlessTowerHandler.MVP_FLOORS[25] == "Amon Ra"
        assert EndlessTowerHandler.MVP_FLOORS[50] == "Drake"
        assert EndlessTowerHandler.MVP_FLOORS[75] == "Osiris"
        assert EndlessTowerHandler.MVP_FLOORS[100] == "Naght Sieger"
    
    def test_checkpoint_floors_set(self):
        """Test CHECKPOINT_FLOORS set."""
        assert 26 in EndlessTowerHandler.CHECKPOINT_FLOORS
        assert 51 in EndlessTowerHandler.CHECKPOINT_FLOORS
        assert 77 in EndlessTowerHandler.CHECKPOINT_FLOORS
        assert len(EndlessTowerHandler.CHECKPOINT_FLOORS) == 3


class TestIntegrationScenarios:
    """Test full workflow scenarios."""
    
    @pytest.mark.asyncio
    async def test_full_tower_progression_simulation(self):
        """Test simulating full tower progression."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 99,
            "gear_score": 8000,
            "party_size": 2,
            "time_remaining_minutes": 240,
            "consumables": {"Yggdrasil Leaf": 10, "White Potion": 100}
        }
        
        # Should be able to reach high floors
        stop_floor = await handler.get_stopping_point(
            character_state=character_state,
            current_floor=1
        )
        
        assert stop_floor >= 50  # Should reach at least floor 50
    
    @pytest.mark.asyncio
    async def test_solo_low_gear_progression(self):
        """Test solo progression with low gear."""
        handler = EndlessTowerHandler()
        character_state = {
            "base_level": 85,
            "gear_score": 3000,
            "party_size": 1,
            "time_remaining_minutes": 240,
            "consumables": {"Yggdrasil Leaf": 5}
        }
        
        stop_floor = await handler.get_stopping_point(
            character_state=character_state,
            current_floor=1
        )
        
        # Should stop before first MVP
        assert stop_floor <= 24