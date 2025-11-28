"""
Comprehensive tests for PvP system modules.

Tests cover:
- Battleground system (Tierra, Flavius, KVM, Eye of Storm)
- Tactics engine (combos, burst timing, kiting)
- Guild coordination (formations, commands)
- Main PvP coordinator (integration)
"""

import pytest
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, AsyncMock, patch

from ai_sidecar.pvp.battlegrounds import (
    BattlegroundManager,
    BattlegroundMode,
    BGTeam,
    BGMatchState,
    BGObjective,
)
from ai_sidecar.pvp.tactics import (
    PvPTacticsEngine,
    TacticalAction,
    CrowdControlType,
    ComboChain,
)
from ai_sidecar.pvp.coordination import (
    GuildCoordinator,
    FormationType,
    GuildCommand,
    CommandPriority,
)
from ai_sidecar.pvp.coordinator import PvPCoordinator
from ai_sidecar.pvp.core import PvPMode, ThreatLevel


@pytest.fixture
def data_dir(tmp_path):
    """Create temporary data directory with test configs"""
    data_dir = tmp_path / "data"
    data_dir.mkdir()

    # Create minimal battleground config
    bg_config = data_dir / "battleground_configs.json"
    bg_config.write_text("""{
        "modes": {
            "tierra": {
                "mode_id": "tierra_canyon",
                "full_name": "Tierra Canyon",
                "objective": "capture_flag",
                "team_size": 15,
                "duration_minutes": 20,
                "score_to_win": 3,
                "map": "bat_a01",
                "spawn_positions": {"guillaume": [50, 374], "croix": [342, 16]},
                "flag_positions": {"guillaume": [50, 374], "croix": [342, 16]},
                "base_positions": {"guillaume": [50, 374], "croix": [342, 16]},
                "strategic_points": [],
                "rewards": {"winner_badges": 3}
            }
        }
    }""")

    # Create minimal combo config
    combo_config = data_dir / "pvp_combos.json"
    combo_config.write_text("""{
        "combos": {
            "champion": [{
                "name": "test_combo",
                "skills": ["Skill1", "Skill2"],
                "total_cast_time_ms": 2000,
                "total_damage": 5000,
                "cc_type": "stun",
                "requirements": {},
                "description": "Test combo"
            }]
        },
        "defensive_combos": {},
        "support_combos": {}
    }""")

    # Create minimal job danger ratings
    danger_config = data_dir / "job_danger_ratings.json"
    danger_config.write_text("""{
        "ratings": {"champion": 8.0, "default": 5.0},
        "modifiers": {"is_casting": 1.5}
    }""")

    return data_dir


# Battlegrounds Tests

def test_battleground_manager_init(data_dir):
    """Test BattlegroundManager initialization"""
    manager = BattlegroundManager(data_dir)
    assert BattlegroundMode.TIERRA in manager.configs
    assert manager.match_state == BGMatchState.WAITING


@pytest.mark.asyncio
async def test_join_battleground(data_dir):
    """Test joining battleground queue"""
    manager = BattlegroundManager(data_dir)
    result = await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
    
    assert result is True
    assert manager.current_mode == BattlegroundMode.TIERRA
    assert manager.own_team == BGTeam.GUILLAUME


@pytest.mark.asyncio
async def test_battleground_match_start(data_dir):
    """Test battleground match start"""
    manager = BattlegroundManager(data_dir)
    await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
    
    await manager.start_match(1, "TestPlayer", "Champion")
    
    assert manager.match_state == BGMatchState.ACTIVE
    assert 1 in manager.players
    assert manager.match_start_time is not None


@pytest.mark.asyncio
async def test_ctf_objective(data_dir):
    """Test CTF objective calculation"""
    manager = BattlegroundManager(data_dir)
    await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
    await manager.start_match(1, "TestPlayer", "Champion")
    
    objective = await manager.get_current_objective(
        (100, 100),
        {"player_id": 1, "hp_percent": 80}
    )
    
    assert "action" in objective
    assert "priority" in objective


@pytest.mark.asyncio
async def test_battleground_score_update(data_dir):
    """Test score updating"""
    manager = BattlegroundManager(data_dir)
    manager.update_score(BGTeam.GUILLAUME, 2)
    manager.update_score(BGTeam.CROIX, 1)
    
    assert manager.team_scores[BGTeam.GUILLAUME] == 2
    assert manager.team_scores[BGTeam.CROIX] == 1


@pytest.mark.asyncio
async def test_should_defend_or_attack(data_dir):
    """Test defend/attack decision"""
    manager = BattlegroundManager(data_dir)
    await manager.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
    
    decision = await manager.should_defend_or_attack(
        {"job_class": "archbishop", "hp_percent": 80},
        {"tank": 2, "healer": 1, "dps": 3}
    )
    
    assert decision in ["defend", "attack"]


# Tactics Tests

def test_tactics_engine_init(data_dir):
    """Test PvPTacticsEngine initialization"""
    engine = PvPTacticsEngine(data_dir)
    assert "champion" in engine.combos
    assert len(engine.combos["champion"]) > 0


@pytest.mark.asyncio
async def test_get_tactical_action(data_dir):
    """Test tactical action selection"""
    engine = PvPTacticsEngine(data_dir)
    
    action = await engine.get_tactical_action(
        {"hp_percent": 80, "sp_percent": 60, "job_class": "champion"},
        {"hp_percent": 50, "is_stunned": False},
        allies_nearby=2,
        enemies_nearby=1
    )
    
    assert isinstance(action, TacticalAction)


@pytest.mark.asyncio
async def test_get_optimal_combo(data_dir):
    """Test optimal combo selection"""
    engine = PvPTacticsEngine(data_dir)
    
    combo = await engine.get_optimal_combo(
        "champion",
        {"hp_percent": 50, "player_id": 1},
        {"sp_percent": 100, "hp_percent": 80}
    )
    
    assert combo is None or isinstance(combo, ComboChain)


@pytest.mark.asyncio
async def test_calculate_burst_window(data_dir):
    """Test burst window calculation"""
    engine = PvPTacticsEngine(data_dir)
    
    window = await engine.calculate_burst_window(
        {"is_stunned": True, "hp_percent": 40, "player_id": 1},
        {"job_class": "champion", "sp_percent": 80}
    )
    
    assert window is not None
    assert window.target_vulnerable is True


@pytest.mark.asyncio
async def test_kiting_path(data_dir):
    """Test kiting path calculation"""
    engine = PvPTacticsEngine(data_dir)
    
    path = await engine.get_kiting_path(
        (100, 100),
        (110, 110),
        optimal_range=10
    )
    
    assert len(path) >= 2
    assert path[0] == (100, 100)


@pytest.mark.asyncio
async def test_should_use_cc(data_dir):
    """Test CC decision making"""
    engine = PvPTacticsEngine(data_dir)
    
    should_cc, cc_type = await engine.should_use_cc(
        {"is_casting": True, "cc_immune": False, "job_class": "warlock"},
        {"job_class": "champion", "hp_percent": 80}
    )
    
    assert isinstance(should_cc, bool)
    if should_cc:
        assert isinstance(cc_type, CrowdControlType)


@pytest.mark.asyncio
async def test_get_defensive_rotation(data_dir):
    """Test defensive rotation"""
    engine = PvPTacticsEngine(data_dir)
    
    skills = await engine.get_defensive_rotation("champion", "high")
    
    assert isinstance(skills, list)
    assert len(skills) > 0


def test_cooldown_tracking(data_dir):
    """Test skill cooldown tracking"""
    engine = PvPTacticsEngine(data_dir)
    
    engine.mark_skill_used("TestSkill", 5.0)
    assert not engine.is_skill_ready("TestSkill")
    
    # Simulate cooldown expiry
    engine.cooldowns["TestSkill"] = datetime.now() - timedelta(seconds=10)
    assert engine.is_skill_ready("TestSkill")


# Coordination Tests

def test_guild_coordinator_init():
    """Test GuildCoordinator initialization"""
    coordinator = GuildCoordinator()
    assert coordinator.current_formation == FormationType.SCATTER
    assert len(coordinator.members) == 0


def test_add_remove_member():
    """Test member management"""
    coordinator = GuildCoordinator()
    
    coordinator.add_member({
        "player_id": 1,
        "name": "TestPlayer",
        "job_class": "champion",
        "role": "dps"
    })
    
    assert 1 in coordinator.members
    assert coordinator.members[1].player_name == "TestPlayer"
    
    coordinator.remove_member(1)
    assert 1 not in coordinator.members


@pytest.mark.asyncio
async def test_execute_formation():
    """Test formation execution"""
    coordinator = GuildCoordinator()
    
    await coordinator.execute_formation(FormationType.WEDGE)
    
    assert coordinator.current_formation == FormationType.WEDGE


@pytest.mark.asyncio
async def test_call_target():
    """Test target calling"""
    coordinator = GuildCoordinator()
    
    await coordinator.call_target(999, 1, duration_seconds=10.0)
    
    assert coordinator.get_called_target() == 999


@pytest.mark.asyncio
async def test_request_support():
    """Test support requests"""
    coordinator = GuildCoordinator()
    coordinator.add_member({
        "player_id": 1,
        "name": "TestPlayer",
        "job_class": "champion",
        "role": "dps",
        "position": [100, 100]
    })
    
    await coordinator.request_support(1, "heal", CommandPriority.HIGH)
    
    commands = coordinator.get_active_commands(CommandPriority.HIGH)
    assert len(commands) > 0


def test_get_formation_position():
    """Test formation position calculation"""
    coordinator = GuildCoordinator()
    coordinator.formation_center = (200, 200)
    
    coordinator.add_member({
        "player_id": 1,
        "name": "TestPlayer",
        "job_class": "champion",
        "role": "dps"
    })
    
    position = coordinator.get_formation_position(1)
    assert position is not None


@pytest.mark.asyncio
async def test_should_regroup():
    """Test regroup decision"""
    coordinator = GuildCoordinator()
    
    # Add spread out members
    coordinator.add_member({
        "player_id": 1,
        "name": "Player1",
        "job_class": "champion",
        "role": "dps",
        "position": [0, 0]
    })
    coordinator.add_member({
        "player_id": 2,
        "name": "Player2",
        "job_class": "wizard",
        "role": "dps",
        "position": [100, 100]
    })
    
    should_regroup = await coordinator.should_regroup()
    assert isinstance(should_regroup, bool)


# Main Coordinator Tests

@pytest.mark.asyncio
async def test_pvp_coordinator_init(data_dir):
    """Test PvPCoordinator initialization"""
    coordinator = PvPCoordinator(data_dir)
    
    assert coordinator.core is not None
    assert coordinator.woe is not None
    assert coordinator.battlegrounds is not None
    assert coordinator.tactics is not None
    assert coordinator.coordination is not None


@pytest.mark.asyncio
async def test_enter_exit_pvp(data_dir):
    """Test entering and exiting PvP"""
    coordinator = PvPCoordinator(data_dir)
    
    await coordinator.enter_pvp(
        PvPMode.OPEN_WORLD,
        1,
        "TestPlayer",
        "Champion"
    )
    
    assert coordinator.in_pvp is True
    assert coordinator.current_mode == PvPMode.OPEN_WORLD
    
    await coordinator.exit_pvp()
    
    assert coordinator.in_pvp is False


@pytest.mark.asyncio
async def test_get_next_action(data_dir):
    """Test action decision making"""
    coordinator = PvPCoordinator(data_dir)
    
    await coordinator.enter_pvp(
        PvPMode.OPEN_WORLD,
        1,
        "TestPlayer",
        "Champion"
    )
    
    action = await coordinator.get_next_action(
        {"position": (100, 100), "hp_percent": 80, "sp_percent": 60},
        [{"player_id": 2, "position": (110, 110), "hp_percent": 50}],
        [{"player_id": 3, "position": (95, 95)}],
        {}
    )
    
    assert "action" in action
    assert "reason" in action


@pytest.mark.asyncio
async def test_handle_pvp_event(data_dir):
    """Test event handling"""
    coordinator = PvPCoordinator(data_dir)
    
    await coordinator.enter_pvp(
        PvPMode.OPEN_WORLD,
        1,
        "TestPlayer",
        "Champion"
    )
    
    await coordinator.handle_pvp_event(
        "player_killed",
        {"killer_id": 2, "victim_id": 1}
    )
    
    # Should update threat tracking
    assert 2 in coordinator.core.threat_assessor.threats


def test_get_status(data_dir):
    """Test status retrieval"""
    coordinator = PvPCoordinator(data_dir)
    
    status = coordinator.get_status()
    
    assert "in_pvp" in status
    assert "mode" in status
    assert "coordination" in status


@pytest.mark.asyncio
async def test_integration_battleground_flow(data_dir):
    """Integration test: Complete battleground flow"""
    coordinator = PvPCoordinator(data_dir)
    
    # Enter PvP
    await coordinator.enter_pvp(
        PvPMode.BATTLEGROUND,
        1,
        "TestPlayer",
        "Champion"
    )
    
    # Join battleground
    await coordinator.join_battleground(BattlegroundMode.TIERRA, BGTeam.GUILLAUME)
    
    # Start match
    await coordinator.battlegrounds.start_match(1, "TestPlayer", "Champion")
    
    # Get action
    action = await coordinator.get_next_action(
        {"position": (100, 100), "hp_percent": 80, "sp_percent": 60, "player_id": 1},
        [{"player_id": 2, "position": (200, 200), "hp_percent": 70}],
        [],
        {}
    )
    
    assert action["action"] is not None
    
    # Exit
    await coordinator.exit_pvp()
    assert not coordinator.in_pvp


if __name__ == "__main__":
    pytest.main([__file__, "-v"])