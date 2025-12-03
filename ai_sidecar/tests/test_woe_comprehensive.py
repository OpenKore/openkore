"""
Comprehensive tests for pvp/woe.py to achieve 90%+ coverage.

Tests War of Emperium castle siege management, scheduling, attack/defense
strategies, and all WoE editions (FE, SE, TE).
"""

import pytest
import json
from datetime import datetime, time
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

from ai_sidecar.pvp.woe import (
    WoEManager,
    WoEEdition,
    CastleOwnership,
    WoERole,
    Castle,
    GuardianStone,
    Barricade,
    WoESchedule
)


@pytest.fixture
def data_dir(tmp_path: Path) -> Path:
    """Create temporary data directory with test WoE data."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Castle data
    castles_data = {
        "first_edition": {
            "prontera": {
                "castle1": {
                    "map": "prtg_cas01",
                    "realm": "prontera",
                    "emperium": [100, 100],
                    "spawn": [50, 50],
                    "difficulty": 5
                }
            }
        },
        "second_edition": {
            "schwaltzvald": {
                "castle1": {
                    "map": "schg_cas01",
                    "realm": "schwaltzvald",
                    "spawn": [50, 50],
                    "difficulty": 8,
                    "stones": [
                        {"id": 1, "position": [80, 80], "max_hp": 50000},
                        {"id": 2, "position": [120, 80], "max_hp": 50000}
                    ],
                    "barricades": [
                        {"id": 1, "position": [100, 60], "max_hp": 150000}
                    ]
                }
            }
        },
        "training_edition": {
            "te_castle1": {
                "map": "te_prtcas01",
                "realm": "training",
                "emperium": [100, 100],
                "spawn": [50, 50],
                "difficulty": 5
            }
        }
    }
    
    (data_dir / "castles.json").write_text(json.dumps(castles_data))
    
    # Schedule data
    schedule_data = {
        "schedules": [
            {
                "day_of_week": 2,  # Wednesday
                "start_hour": 20,
                "start_minute": 0,
                "duration_minutes": 120,
                "edition": "fe",
                "castles": ["fe_prontera_castle1"],
                "description": "Wednesday FE WoE"
            },
            {
                "day_of_week": 5,  # Saturday
                "start_hour": 14,
                "start_minute": 0,
                "duration_minutes": 120,
                "edition": "se",
                "castles": ["se_schwaltzvald_castle1"],
                "description": "Saturday SE WoE"
            }
        ]
    }
    
    (data_dir / "woe_schedule.json").write_text(json.dumps(schedule_data))
    
    return data_dir


class TestWoEManagerInit:
    """Test WoEManager initialization."""
    
    def test_init_loads_castle_data(self, data_dir):
        """Test manager loads castle data on init."""
        mgr = WoEManager(data_dir)
        
        assert len(mgr.castles) > 0
        assert mgr.woe_active is False
        assert mgr.current_edition is None
        
    def test_init_loads_schedule(self, data_dir):
        """Test manager loads WoE schedule on init."""
        mgr = WoEManager(data_dir)
        
        assert len(mgr.schedule) == 2
        
    def test_init_sets_default_role(self, data_dir):
        """Test manager sets default role."""
        mgr = WoEManager(data_dir)
        
        assert mgr.current_role == WoERole.DPS


class TestLoadCastleData:
    """Test _load_castle_data method."""
    
    def test_loads_first_edition_castles(self, data_dir):
        """Test loads FE castles correctly."""
        mgr = WoEManager(data_dir)
        
        fe_castles = [c for c in mgr.castles.values() if c.edition == WoEEdition.FIRST_EDITION]
        assert len(fe_castles) > 0
        
        castle = fe_castles[0]
        assert castle.castle_id.startswith("fe_")
        assert castle.emperium_position != (0, 0)
        
    def test_loads_second_edition_castles(self, data_dir):
        """Test loads SE castles with guardian stones."""
        mgr = WoEManager(data_dir)
        
        se_castles = [c for c in mgr.castles.values() if c.edition == WoEEdition.SECOND_EDITION]
        assert len(se_castles) > 0
        
        castle = se_castles[0]
        assert castle.castle_id.startswith("se_")
        assert len(castle.guardian_stones) > 0
        assert len(castle.barricades) > 0
        
    def test_loads_training_edition_castles(self, data_dir):
        """Test loads TE castles correctly."""
        mgr = WoEManager(data_dir)
        
        te_castles = [c for c in mgr.castles.values() if c.edition == WoEEdition.TRAINING_EDITION]
        assert len(te_castles) > 0
        
        castle = te_castles[0]
        assert castle.castle_id.startswith("te_")
        
    def test_handles_missing_castle_file(self, tmp_path):
        """Test handles missing castles.json gracefully."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        
        # Should not crash
        mgr = WoEManager(empty_dir)
        assert len(mgr.castles) == 0
        
    def test_handles_malformed_castle_data(self, tmp_path):
        """Test handles malformed castle data."""
        bad_dir = tmp_path / "bad"
        bad_dir.mkdir()
        
        (bad_dir / "castles.json").write_text("{invalid json")
        (bad_dir / "woe_schedule.json").write_text('{"schedules": []}')
        
        # Should not crash
        mgr = WoEManager(bad_dir)
        assert len(mgr.castles) == 0


class TestLoadSchedule:
    """Test _load_schedule method."""
    
    def test_loads_schedule_correctly(self, data_dir):
        """Test loads schedule with correct fields."""
        mgr = WoEManager(data_dir)
        
        assert len(mgr.schedule) == 2
        
        schedule = mgr.schedule[0]
        assert schedule.day_of_week == 2
        assert schedule.start_hour == 20
        assert schedule.duration_minutes == 120
        assert schedule.edition == WoEEdition.FIRST_EDITION
        
    def test_handles_missing_schedule_file(self, tmp_path):
        """Test handles missing woe_schedule.json."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        (empty_dir / "castles.json").write_text('{}')
        
        mgr = WoEManager(empty_dir)
        assert len(mgr.schedule) == 0


class TestGetWoESchedule:
    """Test get_woe_schedule method."""
    
    def test_filters_by_day(self, data_dir):
        """Test returns schedules for specific day."""
        mgr = WoEManager(data_dir)
        
        wednesday_schedules = mgr.get_woe_schedule(2)
        assert len(wednesday_schedules) == 1
        assert wednesday_schedules[0].day_of_week == 2
        
    def test_returns_empty_for_no_woe_day(self, data_dir):
        """Test returns empty list for days without WoE."""
        mgr = WoEManager(data_dir)
        
        monday_schedules = mgr.get_woe_schedule(0)
        assert len(monday_schedules) == 0


class TestIsWoEActive:
    """Test is_woe_active method."""
    
    def test_active_during_scheduled_time(self, data_dir):
        """Test returns True during WoE time."""
        mgr = WoEManager(data_dir)
        
        # Mock datetime to be during WoE (Wed 20:30)
        with patch('ai_sidecar.pvp.woe.datetime') as mock_datetime:
            mock_now = Mock()
            mock_now.weekday.return_value = 2  # Wednesday
            mock_now.hour = 20
            mock_now.minute = 30
            mock_datetime.now.return_value = mock_now
            
            active, edition = mgr.is_woe_active()
            
            assert active is True
            assert edition == WoEEdition.FIRST_EDITION
            
    def test_inactive_outside_scheduled_time(self, data_dir):
        """Test returns False outside WoE time."""
        mgr = WoEManager(data_dir)
        
        # Mock datetime to be outside WoE
        with patch('ai_sidecar.pvp.woe.datetime') as mock_datetime:
            mock_now = Mock()
            mock_now.weekday.return_value = 2  # Wednesday
            mock_now.hour = 10  # Morning, no WoE
            mock_now.minute = 0
            mock_datetime.now.return_value = mock_now
            
            active, edition = mgr.is_woe_active()
            
            assert active is False
            assert edition is None


class TestSelectTargetCastle:
    """Test select_target_castle method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        mgr = WoEManager(data_dir)
        mgr.woe_active = True
        mgr.current_edition = WoEEdition.FIRST_EDITION
        return mgr
    
    @pytest.mark.asyncio
    async def test_returns_none_when_inactive(self, data_dir):
        """Test returns None when WoE is not active."""
        mgr = WoEManager(data_dir)
        mgr.woe_active = False
        
        result = await mgr.select_target_castle([], [])
        assert result is None
        
    @pytest.mark.asyncio
    async def test_excludes_owned_castles(self, manager):
        """Test does not target castles we own."""
        for castle in manager.castles.values():
            if castle.edition == WoEEdition.FIRST_EDITION:
                castle.ownership_status = CastleOwnership.OWNED_BY_US
        
        result = await manager.select_target_castle([], [])
        # Should return None or a castle not owned by us
        if result:
            castle = manager.castles[result]
            assert castle.ownership_status != CastleOwnership.OWNED_BY_US
            
    @pytest.mark.asyncio
    async def test_selects_best_scored_castle(self, manager):
        """Test selects highest scored castle."""
        result = await manager.select_target_castle(
            [{"level": 90} for _ in range(15)],  # 15 members
            []
        )
        
        assert result is not None
        assert manager.target_castle == result


class TestScoreCastleTarget:
    """Test _score_castle_target method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_prefers_unowned_castles(self, manager):
        """Test unowned castles get bonus points."""
        castle = list(manager.castles.values())[0]
        castle.ownership_status = CastleOwnership.UNOWNED
        
        score_unowned = manager._score_castle_target(castle, [], [])
        
        castle.ownership_status = CastleOwnership.OWNED_BY_ENEMY
        score_enemy = manager._score_castle_target(castle, [], [])
        
        assert score_unowned > score_enemy
        
    def test_penalizes_hard_castles_small_guild(self, manager):
        """Test hard castles penalized for small guilds."""
        castle = list(manager.castles.values())[0]
        castle.difficulty = 9
        
        # Small guild (5 members)
        small_score = manager._score_castle_target(
            castle,
            [{"level": 90} for _ in range(5)],
            []
        )
        
        castle.difficulty = 3
        easy_score = manager._score_castle_target(
            castle,
            [{"level": 90} for _ in range(5)],
            []
        )
        
        assert easy_score > small_score


class TestCalculateAttackRoute:
    """Test calculate_attack_route method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_fe_direct_to_emperium(self, manager):
        """Test FE castles route directly to emperium."""
        fe_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.FIRST_EDITION][0]
        
        route = await manager.calculate_attack_route(fe_castle, (0, 0))
        
        assert len(route) >= 1
        assert route[-1] == fe_castle.emperium_position
        
    @pytest.mark.asyncio
    async def test_se_routes_through_stones(self, manager):
        """Test SE castles route through guardian stones."""
        se_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.SECOND_EDITION][0]
        
        route = await manager.calculate_attack_route(se_castle, (0, 0))
        
        # Should include stone positions
        assert len(route) > 1


class TestGetDefensePositions:
    """Test get_defense_positions method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_se_defender_around_stones(self, manager):
        """Test SE defenders positioned around stones."""
        se_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.SECOND_EDITION][0]
        
        positions = await manager.get_defense_positions(se_castle, WoERole.DEFENDER)
        
        assert len(positions) > 0
        
    @pytest.mark.asyncio
    async def test_fe_defender_around_emperium(self, manager):
        """Test FE defenders positioned around emperium."""
        fe_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.FIRST_EDITION][0]
        
        positions = await manager.get_defense_positions(fe_castle, WoERole.DEFENDER)
        
        assert len(positions) > 0
        
    @pytest.mark.asyncio
    async def test_healer_backline_position(self, manager):
        """Test healers get backline positions."""
        fe_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.FIRST_EDITION][0]
        
        positions = await manager.get_defense_positions(fe_castle, WoERole.HEALER)
        
        assert len(positions) > 0


class TestShouldAttackGuardianStone:
    """Test should_attack_guardian_stone method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_skip_destroyed_stone(self, manager):
        """Test does not attack destroyed stones."""
        stone = GuardianStone(stone_id=1, position=(80, 80), is_destroyed=True)
        
        result = await manager.should_attack_guardian_stone(stone, 0)
        assert result is False
        
    @pytest.mark.asyncio
    async def test_skip_heavily_defended_stone(self, manager):
        """Test avoids attacking heavily defended stones."""
        stone = GuardianStone(stone_id=1, position=(80, 80), is_destroyed=False)
        
        result = await manager.should_attack_guardian_stone(stone, 10)
        assert result is False
        
    @pytest.mark.asyncio
    async def test_attack_accessible_stone(self, manager):
        """Test attacks accessible stones."""
        stone = GuardianStone(stone_id=1, position=(80, 80), is_destroyed=False)
        
        result = await manager.should_attack_guardian_stone(stone, 2)
        assert result is True


class TestGetEmperiumBreakStrategy:
    """Test get_emperium_break_strategy method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_champion_strategy(self, manager):
        """Test champion class gets Asura Strike strategy."""
        castle = list(manager.castles.values())[0]
        state = {"job_class": "Champion"}
        
        strategy = await manager.get_emperium_break_strategy(castle, state)
        
        assert "Asura Strike" in strategy["skills"]
        
    @pytest.mark.asyncio
    async def test_assassin_strategy(self, manager):
        """Test assassin class gets appropriate skills."""
        castle = list(manager.castles.values())[0]
        state = {"job_class": "Guillotine Cross"}
        
        strategy = await manager.get_emperium_break_strategy(castle, state)
        
        assert len(strategy["skills"]) > 0
        
    @pytest.mark.asyncio
    async def test_includes_consumables(self, manager):
        """Test strategy includes consumable items."""
        castle = list(manager.castles.values())[0]
        state = {"job_class": "Knight"}
        
        strategy = await manager.get_emperium_break_strategy(castle, state)
        
        assert len(strategy["items"]) > 0


class TestCoordinateWithGuild:
    """Test coordinate_with_guild method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_logs_coordination(self, manager):
        """Test coordination action is logged."""
        # Should not raise
        await manager.coordinate_with_guild("attack", {"target": "castle1"})


class TestGetCastleStatus:
    """Test get_castle_status method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_returns_castle_by_name(self, manager):
        """Test returns castle by name."""
        castle_id = list(manager.castles.keys())[0]
        
        result = manager.get_castle_status(castle_id)
        
        assert result is not None
        assert result.castle_id == castle_id
        
    def test_returns_none_for_unknown(self, manager):
        """Test returns None for unknown castle."""
        result = manager.get_castle_status("unknown_castle")
        assert result is None


class TestHandleWoEStart:
    """Test handle_woe_start method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    @pytest.mark.asyncio
    async def test_sets_active_flag(self, manager):
        """Test sets WoE active flag."""
        await manager.handle_woe_start(WoEEdition.FIRST_EDITION)
        
        assert manager.woe_active is True
        assert manager.current_edition == WoEEdition.FIRST_EDITION
        
    @pytest.mark.asyncio
    async def test_resets_castle_defenses(self, manager):
        """Test resets guardian stones and barricades."""
        # Damage a stone
        se_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.SECOND_EDITION][0]
        if se_castle.guardian_stones:
            se_castle.guardian_stones[0].is_destroyed = True
        
        await manager.handle_woe_start(WoEEdition.SECOND_EDITION)
        
        # Should be reset
        if se_castle.guardian_stones:
            assert se_castle.guardian_stones[0].is_destroyed is False
            assert se_castle.guardian_stones[0].current_hp == se_castle.guardian_stones[0].max_hp


class TestHandleWoEEnd:
    """Test handle_woe_end method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        mgr = WoEManager(data_dir)
        mgr.woe_active = True
        mgr.current_edition = WoEEdition.FIRST_EDITION
        mgr.target_castle = "some_castle"
        return mgr
    
    @pytest.mark.asyncio
    async def test_clears_woe_state(self, manager):
        """Test clears WoE state."""
        await manager.handle_woe_end()
        
        assert manager.woe_active is False
        assert manager.current_edition is None
        assert manager.target_castle is None


class TestUpdateCastleOwnership:
    """Test update_castle_ownership method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_sets_unowned_status(self, manager):
        """Test sets unowned status correctly."""
        castle_id = list(manager.castles.keys())[0]
        
        manager.update_castle_ownership(castle_id, None, "MyGuild")
        
        castle = manager.castles[castle_id]
        assert castle.ownership_status == CastleOwnership.UNOWNED
        
    def test_sets_owned_by_us(self, manager):
        """Test sets owned by us status."""
        castle_id = list(manager.castles.keys())[0]
        
        manager.update_castle_ownership(castle_id, "MyGuild", "MyGuild")
        
        castle = manager.castles[castle_id]
        assert castle.ownership_status == CastleOwnership.OWNED_BY_US
        
    def test_sets_owned_by_enemy(self, manager):
        """Test sets enemy ownership."""
        castle_id = list(manager.castles.keys())[0]
        
        manager.update_castle_ownership(castle_id, "EnemyGuild", "MyGuild")
        
        castle = manager.castles[castle_id]
        assert castle.ownership_status == CastleOwnership.OWNED_BY_ENEMY
        
    def test_ignores_unknown_castle(self, manager):
        """Test handles unknown castle gracefully."""
        # Should not crash
        manager.update_castle_ownership("unknown", "Guild", "MyGuild")


class TestUpdateGuardianStone:
    """Test update_guardian_stone method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_updates_stone_status(self, manager):
        """Test updates stone destroyed status."""
        se_castle = [c for c in manager.castles.values() if c.edition == WoEEdition.SECOND_EDITION][0]
        
        if se_castle.guardian_stones:
            stone_id = se_castle.guardian_stones[0].stone_id
            
            manager.update_guardian_stone(se_castle.castle_id, stone_id, True)
            
            assert se_castle.guardian_stones[0].is_destroyed is True
            assert se_castle.guardian_stones[0].current_hp == 0
            
    def test_ignores_unknown_castle(self, manager):
        """Test handles unknown castle gracefully."""
        # Should not crash
        manager.update_guardian_stone("unknown", 1, True)


class TestSetRole:
    """Test set_role method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_sets_role(self, manager):
        """Test sets current WoE role."""
        manager.set_role(WoERole.EMPERIUM_BREAKER)
        
        assert manager.current_role == WoERole.EMPERIUM_BREAKER


class TestGetWoEStatus:
    """Test get_woe_status method."""
    
    @pytest.fixture
    def manager(self, data_dir):
        mgr = WoEManager(data_dir)
        mgr.woe_active = True
        mgr.current_edition = WoEEdition.FIRST_EDITION
        mgr.current_role = WoERole.TANK
        mgr.target_castle = "castle1"
        return mgr
    
    def test_returns_comprehensive_status(self, manager):
        """Test returns all WoE status information."""
        # Set a castle as owned
        castle = list(manager.castles.values())[0]
        castle.ownership_status = CastleOwnership.OWNED_BY_US
        
        status = manager.get_woe_status()
        
        assert status["active"] is True
        assert status["edition"] == "fe"
        assert status["role"] == "tank"
        assert status["target_castle"] == "castle1"
        assert len(status["owned_castles"]) > 0


class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.fixture
    def manager(self, data_dir):
        return WoEManager(data_dir)
    
    def test_empty_castle_list(self, tmp_path):
        """Test handles empty castle list."""
        empty_dir = tmp_path / "empty"
        empty_dir.mkdir()
        (empty_dir / "castles.json").write_text('{}')
        (empty_dir / "woe_schedule.json").write_text('{"schedules": []}')
        
        mgr = WoEManager(empty_dir)
        assert len(mgr.castles) == 0
        
    @pytest.mark.asyncio
    async def test_select_target_no_available_castles(self, manager):
        """Test select target with no available castles."""
        # Mark all castles as owned
        for castle in manager.castles.values():
            castle.ownership_status = CastleOwnership.OWNED_BY_US
        
        manager.woe_active = True
        manager.current_edition = WoEEdition.FIRST_EDITION
        
        result = await manager.select_target_castle([], [])
        assert result is None