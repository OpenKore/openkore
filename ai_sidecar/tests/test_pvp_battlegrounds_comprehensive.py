"""
Comprehensive tests for PvP Battlegrounds system - Batch 3.

Tests all BG modes: Tierra CTF, Flavius, KVM, Eye of Storm, Conquest.
"""

import json
from datetime import datetime
from pathlib import Path

import pytest

from ai_sidecar.pvp.battlegrounds import (
    BGFlag,
    BGMatchConfig,
    BGMatchState,
    BGObjective,
    BGPlayer,
    BGTeam,
    BattlegroundManager,
    BattlegroundMode,
    ControlPoint,
)


@pytest.fixture
def temp_bg_data_dir(tmp_path):
    """Create temporary data directory with BG configs."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    config_data = {
        "modes": {
            "tierra": {
                "mode_id": "tierra",
                "full_name": "Tierra Canyon",
                "objective": "capture_flag",
                "team_size": 10,
                "duration_minutes": 20,
                "score_to_win": 3,
                "map": "bat_a01",
                "spawn_positions": {
                    "guillaume": [50, 50],
                    "croix": [150, 150]
                },
                "flag_positions": {
                    "guillaume": [50, 60],
                    "croix": [150, 140]
                },
                "strategic_points": [
                    {"position": [100, 100], "name": "Center"}
                ],
                "rewards": {
                    "winner_badges": 3,
                    "loser_badges": 1
                }
            },
            "kvm": {
                "mode_id": "kvm",
                "full_name": "KVM",
                "objective": "team_deathmatch",
                "team_size": 5,
                "duration_minutes": 10,
                "score_to_win": 50,
                "map": "bat_c01",
                "spawn_positions": {
                    "guillaume": [50, 50],
                    "croix": [150, 150]
                },
                "rewards": {
                    "winner_badges": 2,
                    "loser_badges": 1
                }
            },
            "eos": {
                "mode_id": "eos",
                "full_name": "Eye of Storm",
                "objective": "domination",
                "team_size": 15,
                "duration_minutes": 30,
                "score_to_win": 1000,
                "map": "bat_b02",
                "spawn_positions": {
                    "guillaume": [50, 50],
                    "croix": [200, 200]
                },
                "control_points": [
                    {"position": [100, 100], "name": "Center", "importance": 10},
                    {"position": [75, 75], "name": "West", "importance": 5},
                    {"position": [125, 125], "name": "East", "importance": 5}
                ],
                "rewards": {
                    "winner_badges": 5,
                    "loser_badges": 2
                }
            }
        }
    }
    
    config_file = data_dir / "battleground_configs.json"
    config_file.write_text(json.dumps(config_data))
    
    return data_dir


class TestBGManagerInit:
    """Test BattlegroundManager initialization."""
    
    def test_init_loads_configs(self, temp_bg_data_dir):
        """Test configs are loaded on init."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        assert len(manager.configs) > 0
        assert BattlegroundMode.TIERRA in manager.configs
        assert BattlegroundMode.KVM in manager.configs
    
    def test_init_missing_file(self, tmp_path):
        """Test init with missing config file."""
        manager = BattlegroundManager(tmp_path / "nonexistent")
        
        # Should not crash, just have empty configs
        assert len(manager.configs) == 0


class TestJoinBattleground:
    """Test joining battleground queues."""
    
    @pytest.mark.asyncio
    async def test_join_tierra_guillaume(self, temp_bg_data_dir):
        """Test joining Tierra as Guillaume."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        result = await manager.join_battleground(
            BattlegroundMode.TIERRA,
            BGTeam.GUILLAUME
        )
        
        assert result is True
        assert manager.current_mode == BattlegroundMode.TIERRA
        assert manager.own_team == BGTeam.GUILLAUME
        assert manager.match_state == BGMatchState.WAITING
    
    @pytest.mark.asyncio
    async def test_join_kvm_croix(self, temp_bg_data_dir):
        """Test joining KVM as Croix."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        result = await manager.join_battleground(
            BattlegroundMode.KVM,
            BGTeam.CROIX
        )
        
        assert result is True
        assert manager.own_team == BGTeam.CROIX
    
    @pytest.mark.asyncio
    async def test_join_unknown_mode(self, temp_bg_data_dir):
        """Test joining unknown mode fails."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        # Try conquest mode which exists in enum but not loaded in config
        fake_mode = BattlegroundMode.CONQUEST
        result = await manager.join_battleground(fake_mode, BGTeam.GUILLAUME)
        
        assert result is False


class TestMatchStart:
    """Test match starting."""
    
    @pytest.mark.asyncio
    async def test_start_ctf_match(self, temp_bg_data_dir):
        """Test starting CTF match."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        
        await manager.start_match(
            player_id=1,
            player_name="TestPlayer",
            job_class="Champion"
        )
        
        assert manager.match_state == BGMatchState.ACTIVE
        assert manager.match_start_time is not None
        assert 1 in manager.players
        assert len(manager.flags) == 2  # Both team flags
    
    @pytest.mark.asyncio
    async def test_start_conquest_match(self, temp_bg_data_dir):
        """Test starting conquest match."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode("eos"), BGTeam.GUILLAUME)
        
        await manager.start_match(
            player_id=1,
            player_name="TestPlayer",
            job_class="Warlock"
        )
        
        assert len(manager.control_points) == 3  # 3 control points
    
    @pytest.mark.asyncio
    async def test_start_match_initializes_scores(self, temp_bg_data_dir):
        """Test match start initializes scores."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        
        await manager.start_match(1, "Player", "Champion")
        
        assert manager.team_scores[BGTeam.GUILLAUME] == 0
        assert manager.team_scores[BGTeam.CROIX] == 0


class TestCTFObjectives:
    """Test Capture the Flag objectives."""
    
    @pytest.mark.asyncio
    async def test_get_ctf_objective_no_flag(self, temp_bg_data_dir):
        """Test CTF objective when we don't have flag."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        own_state = {"player_id": 1, "position": (100, 100)}
        objective = await manager.get_current_objective((100, 100), own_state)
        
        assert objective["action"] in ["capture_flag", "defend_flag", "pickup_flag", "chase_carrier"]
    
    @pytest.mark.asyncio
    async def test_get_ctf_objective_has_flag(self, temp_bg_data_dir):
        """Test CTF objective when we have flag."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Give player the flag
        manager.players[1].has_flag = True
        
        own_state = {"player_id": 1, "position": (100, 100)}
        objective = await manager.get_current_objective((100, 100), own_state)
        
        assert objective["action"] == "return_flag"
        assert objective["priority"] == 10
    
    @pytest.mark.asyncio
    async def test_get_ctf_objective_chase_carrier(self, temp_bg_data_dir):
        """Test chasing flag carrier."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Add enemy player
        manager.add_player({
            "player_id": 2,
            "name": "Enemy",
            "team": "croix",
            "job_class": "Assassin Cross",
            "position": [120, 120]
        })
        
        # Update enemy team's flag (Croix flag) - we want to capture it
        # Set it as carried by enemy player 2
        flag_id = "flag_croix"
        if flag_id in manager.flags:
            manager.update_flag_status(flag_id, (120, 120), carrier_id=2, is_at_base=False)
        
        own_state = {"player_id": 1, "position": (100, 100)}
        objective = await manager.get_current_objective((100, 100), own_state)
        
        # Should want to chase the carrier or capture flag
        assert objective["action"] in ["chase_carrier", "capture_flag"]


class TestTDMObjectives:
    """Test Team Deathmatch objectives."""
    
    @pytest.mark.asyncio
    async def test_get_tdm_objective_with_enemies(self, temp_bg_data_dir):
        """Test TDM objective with enemies nearby."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.KVM, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Add enemy
        manager.add_player({
            "player_id": 2,
            "name": "Enemy",
            "team": "croix",
            "job_class": "Warlock",
            "position": [110, 110]
        })
        
        objective = await manager.get_current_objective((100, 100), {})
        
        assert objective["action"] == "engage_enemy"
        assert objective["target_player_id"] == 2
    
    @pytest.mark.asyncio
    async def test_get_tdm_objective_no_enemies(self, temp_bg_data_dir):
        """Test TDM objective with no enemies."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.KVM, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        objective = await manager.get_current_objective((100, 100), {})
        
        # Should move to strategic position or patrol
        assert objective["action"] in ["move_to_strategic", "patrol"]


class TestConquestObjectives:
    """Test Conquest/Domination objectives."""
    
    @pytest.mark.asyncio
    async def test_get_conquest_objective(self, temp_bg_data_dir):
        """Test conquest objective selection."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode("eos"), BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        objective = await manager.get_current_objective((100, 100), {})
        
        assert objective["action"] in ["capture_point", "defend_points"]
    
    @pytest.mark.asyncio
    async def test_calculate_objective_priority_neutral(self, temp_bg_data_dir):
        """Test prioritizing neutral control points."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode("eos"), BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Make one point neutral
        for cp in manager.control_points.values():
            cp.controlled_by = BGTeam.NEUTRAL
            break
        
        priority_cp = await manager.calculate_objective_priority((100, 100))
        
        assert priority_cp is not None
    
    @pytest.mark.asyncio
    async def test_calculate_objective_priority_enemy(self, temp_bg_data_dir):
        """Test prioritizing enemy control points."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode("eos"), BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Give all points to enemy
        for cp in manager.control_points.values():
            cp.controlled_by = BGTeam.CROIX
        
        priority_cp = await manager.calculate_objective_priority((100, 100))
        
        assert priority_cp is not None


class TestFlagRoutes:
    """Test flag carry route calculation."""
    
    @pytest.mark.asyncio
    async def test_get_flag_route_direct(self, temp_bg_data_dir):
        """Test direct flag route."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        route = await manager.get_flag_route((100, 100), (50, 50))
        
        assert len(route) >= 2
        assert route[0] == (100, 100)
        assert route[-1] == (50, 50)
    
    @pytest.mark.asyncio
    async def test_get_flag_route_with_waypoints(self, temp_bg_data_dir):
        """Test flag route with strategic waypoints."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Route through center
        route = await manager.get_flag_route((150, 150), (50, 50))
        
        assert len(route) >= 2
        # May include center waypoint if on path


class TestAttackDefendDecision:
    """Test attack/defend decision making."""
    
    @pytest.mark.asyncio
    async def test_should_defend_when_winning(self, temp_bg_data_dir):
        """Test defending when ahead."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Archbishop")
        
        # Set winning score
        manager.team_scores[BGTeam.GUILLAUME] = 50
        manager.team_scores[BGTeam.CROIX] = 30
        
        own_state = {"job_class": "archbishop"}
        decision = await manager.should_defend_or_attack(own_state, {})
        
        assert decision == "defend"
    
    @pytest.mark.asyncio
    async def test_should_attack_when_losing(self, temp_bg_data_dir):
        """Test attacking when behind."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Set losing score
        manager.team_scores[BGTeam.GUILLAUME] = 10
        manager.team_scores[BGTeam.CROIX] = 35
        
        own_state = {"job_class": "champion"}
        decision = await manager.should_defend_or_attack(own_state, {})
        
        assert decision == "attack"
    
    @pytest.mark.asyncio
    async def test_should_defend_flag_stolen(self, temp_bg_data_dir):
        """Test defending when flag is stolen."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Royal Guard")
        
        # Mark flag as not at base
        own_flag = manager.flags.get("flag_guillaume")
        if own_flag:
            own_flag.is_at_base = False
        
        own_state = {"job_class": "royal_guard"}
        decision = await manager.should_defend_or_attack(own_state, {})
        
        assert decision == "defend"


class TestPlayerManagement:
    """Test player add/remove/update."""
    
    def test_add_player(self, temp_bg_data_dir):
        """Test adding player."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        manager.add_player({
            "player_id": 5,
            "name": "NewPlayer",
            "team": "guillaume",
            "job_class": "Ranger",
            "position": [80, 80]
        })
        
        assert 5 in manager.players
        assert manager.players[5].player_name == "NewPlayer"
    
    def test_remove_player(self, temp_bg_data_dir):
        """Test removing player."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        manager.add_player({
            "player_id": 5,
            "name": "Player",
            "team": "guillaume",
            "job_class": "Champion",
            "position": [100, 100]
        })
        
        manager.remove_player(5)
        
        assert 5 not in manager.players
    
    def test_update_player_position(self, temp_bg_data_dir):
        """Test updating player position."""
        manager = BattlegroundManager(temp_bg_data_dir)
        
        manager.add_player({
            "player_id": 5,
            "name": "Player",
            "team": "guillaume",
            "job_class": "Champion",
            "position": [100, 100]
        })
        
        manager.update_player_position(5, (120, 120))
        
        assert manager.players[5].position == (120, 120)


class TestFlagManagement:
    """Test flag status updates."""
    
    @pytest.mark.asyncio
    async def test_update_flag_status_carried(self, temp_bg_data_dir):
        """Test updating flag when carried."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        manager.add_player({
            "player_id": 2,
            "name": "Carrier",
            "team": "guillaume",
            "job_class": "Assassin Cross",
            "position": [110, 110]
        })
        
        flag_id = "flag_croix"
        manager.update_flag_status(flag_id, (110, 110), carrier_id=2, is_at_base=False)
        
        flag = manager.flags[flag_id]
        assert flag.carrier_id == 2
        assert not flag.is_at_base
        assert manager.players[2].has_flag
    
    @pytest.mark.asyncio
    async def test_update_flag_status_dropped(self, temp_bg_data_dir):
        """Test updating flag when dropped."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        flag_id = "flag_croix"
        manager.update_flag_status(flag_id, (115, 115), carrier_id=None, is_at_base=False)
        
        flag = manager.flags[flag_id]
        assert flag.carrier_id is None
        assert not flag.is_at_base
        assert flag.current_position == (115, 115)


class TestControlPointManagement:
    """Test control point updates."""
    
    @pytest.mark.asyncio
    async def test_update_control_point(self, temp_bg_data_dir):
        """Test updating control point ownership."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode("eos"), BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        # Get first control point
        cp_id = list(manager.control_points.keys())[0]
        
        manager.update_control_point(cp_id, BGTeam.GUILLAUME, defenders=3)
        
        cp = manager.control_points[cp_id]
        assert cp.controlled_by == BGTeam.GUILLAUME
        assert cp.defenders == 3


class TestScoreManagement:
    """Test score tracking."""
    
    @pytest.mark.asyncio
    async def test_update_score(self, temp_bg_data_dir):
        """Test updating team score."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.KVM, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        manager.update_score(BGTeam.GUILLAUME, 25)
        
        assert manager.team_scores[BGTeam.GUILLAUME] == 25


class TestMatchEnd:
    """Test match ending."""
    
    @pytest.mark.asyncio
    async def test_end_match_victory(self, temp_bg_data_dir):
        """Test ending match with victory."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        rewards = await manager.end_match(BGTeam.GUILLAUME)
        
        assert rewards["result"] == "victory"
        assert rewards["badges"] == 3
        assert manager.match_state == BGMatchState.FINISHED
        assert len(manager.players) == 0
    
    @pytest.mark.asyncio
    async def test_end_match_defeat(self, temp_bg_data_dir):
        """Test ending match with defeat."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        rewards = await manager.end_match(BGTeam.CROIX)
        
        assert rewards["result"] == "defeat"
        assert rewards["badges"] == 1


class TestMatchStatus:
    """Test match status reporting."""
    
    @pytest.mark.asyncio
    async def test_get_match_status(self, temp_bg_data_dir):
        """Test getting match status."""
        manager = BattlegroundManager(temp_bg_data_dir)
        await manager.join_battleground(BattlegroundMode.KVM, BGTeam.GUILLAUME)
        await manager.start_match(1, "Player", "Champion")
        
        manager.add_player({
            "player_id": 2,
            "name": "Player2",
            "team": "croix",
            "job_class": "Warlock",
            "position": [150, 150]
        })
        
        status = manager.get_match_status()
        
        assert status["mode"] == "kvm"
        assert status["state"] == "active"
        assert status["team"] == "guillaume"
        assert status["players"] == 2
        assert "time_elapsed" in status