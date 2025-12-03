"""
Comprehensive tests for pvp/coordinator.py - Batch 7.

Target: Push coverage from 47.68% to 75%+
Focus on uncovered lines: 78-83, 99, 103, 126, 134, 141, 166-170, 179-183,
192-195, 209-212, 225-269, 283, 292, 307-325, 336-349, 367-396, 411-412,
419-423, 435, 439, 443, 449-457
"""

from datetime import datetime
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import tempfile
import pytest

from ai_sidecar.pvp.coordinator import PvPCoordinator
from ai_sidecar.pvp.core import PvPMode, ThreatLevel
from ai_sidecar.pvp.battlegrounds import BattlegroundMode, BGTeam, BGMatchState
from ai_sidecar.pvp.woe import WoEEdition, WoERole
from ai_sidecar.pvp.tactics import TacticalAction
from ai_sidecar.pvp.coordination import FormationType, CommandPriority


@pytest.fixture
def temp_data_dir():
    """Create temporary data directory."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def coordinator(temp_data_dir):
    """Create PvP coordinator."""
    return PvPCoordinator(temp_data_dir)


@pytest.fixture
def own_state():
    """Create player's own state."""
    return {
        "player_id": 1,
        "name": "TestPlayer",
        "job": "Lord Knight",
        "hp": 8000,
        "max_hp": 10000,
        "sp": 500,
        "max_sp": 1000,
        "position": (100, 100)
    }


@pytest.fixture
def enemies():
    """Create enemy list."""
    return [
        {
            "player_id": 2,
            "name": "Enemy1",
            "job": "High Priest",
            "hp": 5000,
            "max_hp": 8000,
            "position": (110, 110)
        },
        {
            "player_id": 3,
            "name": "Enemy2",
            "job": "Assassin Cross",
            "hp": 7000,
            "max_hp": 9000,
            "position": (105, 105)
        }
    ]


@pytest.fixture
def allies():
    """Create ally list."""
    return [
        {
            "player_id": 4,
            "name": "Ally1",
            "job": "High Wizard",
            "hp": 4000,
            "max_hp": 6000,
            "position": (95, 95)
        }
    ]


class TestEnterPvP:
    """Test enter_pvp method - lines 59-94."""

    @pytest.mark.asyncio
    async def test_enter_pvp_standard(self, coordinator):
        """Test entering standard PvP mode."""
        coordinator.core.set_pvp_mode = AsyncMock()
        
        await coordinator.enter_pvp(
            mode=PvPMode.OPEN_WORLD,
            player_id=1,
            player_name="TestPlayer",
            job_class="Lord Knight"
        )
        
        assert coordinator.in_pvp is True
        assert coordinator.current_mode == PvPMode.OPEN_WORLD
        assert coordinator.own_player_id == 1

    @pytest.mark.asyncio
    async def test_enter_pvp_woe_fe(self, coordinator):
        """Test entering WoE First Edition."""
        coordinator.core.set_pvp_mode = AsyncMock()
        coordinator.woe.handle_woe_start = AsyncMock()
        
        await coordinator.enter_pvp(
            mode=PvPMode.WOE_FE,
            player_id=1,
            player_name="TestPlayer",
            job_class="Lord Knight"
        )
        
        coordinator.woe.handle_woe_start.assert_called_once_with(WoEEdition.FIRST_EDITION)

    @pytest.mark.asyncio
    async def test_enter_pvp_woe_se(self, coordinator):
        """Test entering WoE Second Edition."""
        coordinator.core.set_pvp_mode = AsyncMock()
        coordinator.woe.handle_woe_start = AsyncMock()
        
        await coordinator.enter_pvp(
            mode=PvPMode.WOE_SE,
            player_id=1,
            player_name="TestPlayer",
            job_class="Lord Knight"
        )
        
        coordinator.woe.handle_woe_start.assert_called_once_with(WoEEdition.SECOND_EDITION)

    @pytest.mark.asyncio
    async def test_enter_pvp_woe_te(self, coordinator):
        """Test entering WoE Training Edition."""
        coordinator.core.set_pvp_mode = AsyncMock()
        coordinator.woe.handle_woe_start = AsyncMock()
        
        await coordinator.enter_pvp(
            mode=PvPMode.WOE_TE,
            player_id=1,
            player_name="TestPlayer",
            job_class="Lord Knight"
        )
        
        coordinator.woe.handle_woe_start.assert_called_once_with(WoEEdition.TRAINING_EDITION)

    @pytest.mark.asyncio
    async def test_enter_pvp_battleground(self, coordinator):
        """Test entering Battleground mode."""
        coordinator.core.set_pvp_mode = AsyncMock()
        
        await coordinator.enter_pvp(
            mode=PvPMode.BATTLEGROUND,
            player_id=1,
            player_name="TestPlayer",
            job_class="Lord Knight",
            team="guillaume"
        )
        
        assert coordinator.current_mode == PvPMode.BATTLEGROUND


class TestExitPvP:
    """Test exit_pvp method - lines 96-110."""

    @pytest.mark.asyncio
    async def test_exit_pvp_not_in_pvp(self, coordinator):
        """Test exiting when not in PvP."""
        coordinator.in_pvp = False
        
        await coordinator.exit_pvp()
        
        # Should return without error
        assert coordinator.in_pvp is False

    @pytest.mark.asyncio
    async def test_exit_pvp_from_woe(self, coordinator):
        """Test exiting from WoE."""
        coordinator.in_pvp = True
        coordinator.current_mode = PvPMode.WOE_FE
        coordinator.woe.handle_woe_end = AsyncMock()
        
        await coordinator.exit_pvp()
        
        coordinator.woe.handle_woe_end.assert_called_once()
        assert coordinator.in_pvp is False


class TestGetNextAction:
    """Test get_next_action method - lines 112-144."""

    @pytest.mark.asyncio
    async def test_get_next_action_not_in_pvp(self, coordinator, own_state, enemies, allies):
        """Test action when not in PvP."""
        coordinator.in_pvp = False
        
        result = await coordinator.get_next_action(own_state, enemies, allies, {})
        
        assert result["action"] == "none"

    @pytest.mark.asyncio
    async def test_get_next_action_should_flee(self, coordinator, own_state, enemies, allies):
        """Test flee action."""
        coordinator.in_pvp = True
        coordinator.current_mode = PvPMode.OPEN_WORLD
        coordinator.own_job_class = "Lord Knight"
        
        coordinator.core.threat_assessor.should_flee = MagicMock(return_value=True)
        coordinator.tactics.get_combo_for_situation = AsyncMock(
            return_value=MagicMock(skills=["Emergency Escape"])
        )
        
        result = await coordinator.get_next_action(own_state, enemies, allies, {})
        
        assert result["action"] == "execute_combo"
        assert result["priority"] == 10

    @pytest.mark.asyncio
    async def test_get_next_action_battleground(self, coordinator, own_state, enemies, allies):
        """Test Battleground action."""
        coordinator.in_pvp = True
        coordinator.current_mode = PvPMode.BATTLEGROUND
        coordinator.own_player_id = 1
        coordinator.own_job_class = "Lord Knight"
        
        coordinator.core.threat_assessor.should_flee = MagicMock(return_value=False)
        coordinator.battlegrounds.match_state = BGMatchState.ACTIVE
        coordinator.battlegrounds.get_current_objective = AsyncMock(
            return_value={
                "action": "capture_flag",
                "target_position": (200, 200),
                "priority": 8
            }
        )
        
        result = await coordinator.get_next_action(own_state, enemies, allies, {})
        
        assert result["action"] == "capture_objective"

    @pytest.mark.asyncio
    async def test_get_next_action_woe(self, coordinator, own_state, enemies, allies):
        """Test WoE action."""
        coordinator.in_pvp = True
        coordinator.current_mode = PvPMode.WOE_FE
        coordinator.own_player_id = 1
        coordinator.own_job_class = "Lord Knight"
        
        coordinator.core.threat_assessor.should_flee = MagicMock(return_value=False)
        coordinator.woe.woe_active = True
        coordinator.coordination.get_called_target = MagicMock(return_value=None)
        coordinator.coordination.get_formation_position = MagicMock(return_value=None)
        coordinator.woe.current_role = WoERole.DPS
        coordinator.core.select_target = AsyncMock(return_value=2)
        
        result = await coordinator.get_next_action(own_state, enemies, allies, {})
        
        assert result["action"] == "engage"


class TestGetGeneralPvPAction:
    """Test _get_general_pvp_action method - lines 146-216."""

    @pytest.mark.asyncio
    async def test_general_pvp_burst_action(self, coordinator, own_state, enemies, allies):
        """Test burst action in general PvP."""
        coordinator.own_job_class = "Lord Knight"
        coordinator.tactics.get_tactical_action = AsyncMock(
            return_value=TacticalAction.BURST
        )
        coordinator.core.select_target = AsyncMock(return_value=2)
        coordinator.tactics.get_optimal_combo = AsyncMock(
            return_value=MagicMock(skills=["Bowling Bash", "Berserk"])
        )
        
        result = await coordinator._get_general_pvp_action(
            own_state, enemies, allies, {}
        )
        
        assert result["action"] == "execute_combo"

    @pytest.mark.asyncio
    async def test_general_pvp_kite_action(self, coordinator, own_state, enemies, allies):
        """Test kite action in general PvP."""
        coordinator.own_job_class = "Lord Knight"
        coordinator.tactics.get_tactical_action = AsyncMock(
            return_value=TacticalAction.KITE
        )
        coordinator.core.select_target = AsyncMock(return_value=2)
        coordinator.tactics.get_kiting_path = AsyncMock(
            return_value=[(90, 90), (80, 80)]
        )
        
        result = await coordinator._get_general_pvp_action(
            own_state, enemies, allies, {}
        )
        
        assert result["action"] == "kite"

    @pytest.mark.asyncio
    async def test_general_pvp_disengage_action(self, coordinator, own_state, enemies, allies):
        """Test disengage action in general PvP."""
        coordinator.own_job_class = "Lord Knight"
        coordinator.tactics.get_tactical_action = AsyncMock(
            return_value=TacticalAction.DISENGAGE
        )
        coordinator.core.select_target = AsyncMock(return_value=2)
        coordinator.tactics.get_defensive_rotation = AsyncMock(
            return_value=["Parry", "Auto Guard"]
        )
        
        result = await coordinator._get_general_pvp_action(
            own_state, enemies, allies, {}
        )
        
        assert result["action"] == "disengage"

    @pytest.mark.asyncio
    async def test_general_pvp_no_enemies(self, coordinator, own_state, allies):
        """Test action when no enemies."""
        coordinator.core.get_optimal_position = AsyncMock(
            return_value=(150, 150)
        )
        
        result = await coordinator._get_general_pvp_action(
            own_state, [], allies, {}
        )
        
        assert result["action"] == "move_to_position"


class TestGetWoEAction:
    """Test _get_woe_action method - lines 218-273."""

    @pytest.mark.asyncio
    async def test_woe_not_active(self, coordinator, own_state, enemies, allies):
        """Test WoE action when WoE not active."""
        coordinator.woe.woe_active = False
        
        result = await coordinator._get_woe_action(own_state, enemies, allies)
        
        assert result["action"] == "wait"

    @pytest.mark.asyncio
    async def test_woe_with_called_target(self, coordinator, own_state, enemies, allies):
        """Test WoE focus fire on called target."""
        coordinator.woe.woe_active = True
        coordinator.coordination.get_called_target = MagicMock(return_value=2)
        
        result = await coordinator._get_woe_action(own_state, enemies, allies)
        
        assert result["action"] == "attack_target"
        assert result["target_id"] == 2

    @pytest.mark.asyncio
    async def test_woe_formation_positioning(self, coordinator, own_state, enemies, allies):
        """Test WoE formation positioning."""
        coordinator.own_player_id = 1
        coordinator.woe.woe_active = True
        coordinator.coordination.get_called_target = MagicMock(return_value=None)
        coordinator.coordination.get_formation_position = MagicMock(
            return_value=(150, 150)  # Far from current position
        )
        
        result = await coordinator._get_woe_action(own_state, enemies, allies)
        
        assert result["action"] == "move_to_position"

    @pytest.mark.asyncio
    async def test_woe_emperium_breaker_role(self, coordinator, own_state, enemies, allies):
        """Test WoE emperium breaker role."""
        coordinator.own_player_id = 1
        coordinator.woe.woe_active = True
        coordinator.woe.current_role = WoERole.EMPERIUM_BREAKER
        coordinator.woe.target_castle = "castle1"
        coordinator.coordination.get_called_target = MagicMock(return_value=None)
        coordinator.coordination.get_formation_position = MagicMock(return_value=None)
        
        mock_castle = MagicMock()
        coordinator.woe.castles = {"castle1": mock_castle}
        coordinator.woe.get_emperium_break_strategy = AsyncMock(
            return_value={"approach": "direct"}
        )
        
        result = await coordinator._get_woe_action(own_state, enemies, allies)
        
        assert result["action"] == "break_emperium"


class TestGetBattlegroundAction:
    """Test _get_battleground_action method - lines 275-329."""

    @pytest.mark.asyncio
    async def test_bg_match_not_active(self, coordinator, own_state, enemies, allies):
        """Test BG action when match not active."""
        coordinator.battlegrounds.match_state = BGMatchState.WAITING
        
        result = await coordinator._get_battleground_action(own_state, enemies, allies)
        
        assert result["action"] == "wait"

    @pytest.mark.asyncio
    async def test_bg_return_flag(self, coordinator, own_state, enemies, allies):
        """Test BG return flag objective."""
        coordinator.battlegrounds.match_state = BGMatchState.ACTIVE
        coordinator.battlegrounds.get_current_objective = AsyncMock(
            return_value={
                "action": "return_flag",
                "target_position": (200, 200),
                "priority": 9
            }
        )
        
        result = await coordinator._get_battleground_action(own_state, enemies, allies)
        
        assert result["action"] == "move_to_position"
        assert result["priority"] == 9

    @pytest.mark.asyncio
    async def test_bg_capture_point(self, coordinator, own_state, enemies, allies):
        """Test BG capture control point."""
        coordinator.battlegrounds.match_state = BGMatchState.ACTIVE
        coordinator.battlegrounds.get_current_objective = AsyncMock(
            return_value={
                "action": "capture_point",
                "target_position": (180, 180),
                "target_control_point": "CP_A",
                "priority": 7
            }
        )
        
        result = await coordinator._get_battleground_action(own_state, enemies, allies)
        
        assert result["action"] == "capture_objective"
        assert result["control_point"] == "CP_A"


class TestHandleFlee:
    """Test _handle_flee method - lines 331-353."""

    @pytest.mark.asyncio
    async def test_handle_flee_with_combo(self, coordinator, own_state, enemies):
        """Test flee with escape combo."""
        coordinator.own_job_class = "Lord Knight"
        coordinator.tactics.get_combo_for_situation = AsyncMock(
            return_value=MagicMock(skills=["Teleport", "Endure"])
        )
        
        result = await coordinator._handle_flee(own_state, enemies)
        
        assert result["action"] == "execute_combo"
        assert result["priority"] == 10

    @pytest.mark.asyncio
    async def test_handle_flee_default(self, coordinator, own_state, enemies):
        """Test default flee action."""
        coordinator.own_job_class = "Lord Knight"
        coordinator.tactics.get_combo_for_situation = AsyncMock(return_value=None)
        
        result = await coordinator._handle_flee(own_state, enemies)
        
        assert result["action"] == "flee"
        assert result["priority"] == 10


class TestHandlePvPEvent:
    """Test handle_pvp_event method - lines 355-398."""

    @pytest.mark.asyncio
    async def test_handle_player_killed_us(self, coordinator):
        """Test handling when we are killed."""
        coordinator.own_player_id = 1
        coordinator.core.threat_assessor.update_threat = MagicMock()
        
        await coordinator.handle_pvp_event(
            "player_killed",
            {"killer_id": 2, "victim_id": 1}
        )
        
        coordinator.core.threat_assessor.update_threat.assert_called()

    @pytest.mark.asyncio
    async def test_handle_player_killed_by_us(self, coordinator):
        """Test handling when we get a kill."""
        coordinator.own_player_id = 1
        coordinator.core.threat_assessor.update_threat = MagicMock()
        
        await coordinator.handle_pvp_event(
            "player_killed",
            {"killer_id": 1, "victim_id": 2}
        )
        
        coordinator.core.threat_assessor.update_threat.assert_called()

    @pytest.mark.asyncio
    async def test_handle_skill_cast(self, coordinator):
        """Test handling skill cast event."""
        coordinator.core.threat_assessor.update_threat = MagicMock()
        
        await coordinator.handle_pvp_event(
            "skill_cast",
            {"player_id": 2, "skill": "Storm Gust"}
        )
        
        coordinator.core.threat_assessor.update_threat.assert_called()

    @pytest.mark.asyncio
    async def test_handle_woe_castle_captured(self, coordinator):
        """Test handling castle capture."""
        coordinator.woe.update_castle_ownership = MagicMock()
        
        await coordinator.handle_pvp_event(
            "woe_castle_captured",
            {
                "castle_id": "castle1",
                "guild_name": "TestGuild",
                "our_guild": True
            }
        )
        
        coordinator.woe.update_castle_ownership.assert_called()

    @pytest.mark.asyncio
    async def test_handle_bg_score_update(self, coordinator):
        """Test handling BG score update."""
        coordinator.battlegrounds.update_score = MagicMock()
        
        await coordinator.handle_pvp_event(
            "bg_score_update",
            {"team": "guillaume", "score": 100}
        )
        
        coordinator.battlegrounds.update_score.assert_called()

    @pytest.mark.asyncio
    async def test_handle_guild_command(self, coordinator):
        """Test handling guild command."""
        coordinator.coordination.receive_command = AsyncMock()
        
        await coordinator.handle_pvp_event(
            "guild_command",
            {"command": "focus_fire"}
        )
        
        coordinator.coordination.receive_command.assert_called()


class TestSubsystemMethods:
    """Test subsystem-specific methods - lines 426-478."""

    @pytest.mark.asyncio
    async def test_join_battleground(self, coordinator):
        """Test joining battleground."""
        coordinator.battlegrounds.join_battleground = AsyncMock(return_value=True)
        
        result = await coordinator.join_battleground(
            BattlegroundMode.TIERRA,
            BGTeam.GUILLAUME
        )
        
        assert result is True

    @pytest.mark.asyncio
    async def test_set_woe_role(self, coordinator):
        """Test setting WoE role."""
        coordinator.woe.set_role = MagicMock()
        
        await coordinator.set_woe_role(WoERole.DEFENDER)
        
        coordinator.woe.set_role.assert_called_once()

    @pytest.mark.asyncio
    async def test_set_formation(self, coordinator):
        """Test setting formation."""
        coordinator.coordination.execute_formation = AsyncMock()
        
        await coordinator.set_formation(FormationType.WEDGE)
        
        coordinator.coordination.execute_formation.assert_called_once()

    @pytest.mark.asyncio
    async def test_call_target(self, coordinator):
        """Test calling target."""
        coordinator.own_player_id = 1
        coordinator.coordination.call_target = AsyncMock()
        
        await coordinator.call_target(target_id=2, duration=15.0)
        
        coordinator.coordination.call_target.assert_called_once()

    @pytest.mark.asyncio
    async def test_request_support(self, coordinator):
        """Test requesting support."""
        coordinator.own_player_id = 1
        coordinator.coordination.request_support = AsyncMock()
        
        await coordinator.request_support("heal", urgency="high")
        
        coordinator.coordination.request_support.assert_called()

    def test_get_status(self, coordinator):
        """Test getting PvP status."""
        coordinator.in_pvp = True
        coordinator.current_mode = PvPMode.OPEN_WORLD
        coordinator.own_player_id = 1
        coordinator.own_player_name = "TestPlayer"
        coordinator.own_job_class = "Lord Knight"
        coordinator.woe.woe_active = False
        coordinator.battlegrounds.match_state = BGMatchState.WAITING
        coordinator.coordination.get_coordination_status = MagicMock(return_value={})
        coordinator.tactics.get_tactics_status = MagicMock(return_value={})
        
        status = coordinator.get_status()
        
        assert status["in_pvp"] is True
        assert status["mode"] == "open_world"