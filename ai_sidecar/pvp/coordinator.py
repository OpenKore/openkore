"""
Main PvP Coordinator - Facade integrating all PvP systems.

This is the primary interface for all PvP functionality, coordinating:
- Core PvP engine (threat, targeting, positioning)
- WoE system (castle sieges)
- Battlegrounds (competitive team modes)
- Tactics engine (combos, burst, kiting)
- Guild coordination (formations, commands)
"""

from datetime import datetime
from pathlib import Path
from typing import Any

import structlog

from ai_sidecar.pvp.battlegrounds import BattlegroundManager, BattlegroundMode, BGTeam
from ai_sidecar.pvp.coordination import GuildCoordinator, GuildCommand, CommandPriority, FormationType
from ai_sidecar.pvp.core import PvPCoreEngine, PvPMode, ThreatLevel
from ai_sidecar.pvp.tactics import PvPTacticsEngine, TacticalAction, CrowdControlType
from ai_sidecar.pvp.woe import WoEManager, WoEEdition, WoERole


class PvPCoordinator:
    """
    Main PvP coordinator facade.

    Provides unified interface to all PvP systems:
    - Threat assessment and targeting
    - WoE castle siege management
    - Battleground matches
    - Advanced tactics and combos
    - Guild coordination
    """

    def __init__(self, data_dir: Path) -> None:
        self.log = structlog.get_logger()
        self.data_dir = data_dir

        # Initialize subsystems
        self.core = PvPCoreEngine(data_dir)
        self.woe = WoEManager(data_dir)
        self.battlegrounds = BattlegroundManager(data_dir)
        self.tactics = PvPTacticsEngine(data_dir)
        self.coordination = GuildCoordinator()

        # State tracking
        self.in_pvp: bool = False
        self.current_mode: PvPMode | None = None
        self.own_player_id: int = 0
        self.own_player_name: str = ""
        self.own_job_class: str = ""
        self.enemy_tracking: dict[int, dict[str, Any]] = {}
        self.last_action_time: datetime | None = None

        self.log.info("PvP Coordinator initialized")

    async def enter_pvp(
        self,
        mode: PvPMode,
        player_id: int,
        player_name: str,
        job_class: str,
        team: str | None = None,
    ) -> None:
        """Enter PvP mode and initialize systems"""
        self.in_pvp = True
        self.current_mode = mode
        self.own_player_id = player_id
        self.own_player_name = player_name
        self.own_job_class = job_class

        await self.core.set_pvp_mode(mode)

        # Mode-specific initialization
        if mode in [PvPMode.WOE_FE, PvPMode.WOE_SE, PvPMode.WOE_TE]:
            edition = {
                PvPMode.WOE_FE: WoEEdition.FIRST_EDITION,
                PvPMode.WOE_SE: WoEEdition.SECOND_EDITION,
                PvPMode.WOE_TE: WoEEdition.TRAINING_EDITION,
            }[mode]
            await self.woe.handle_woe_start(edition)

        elif mode == PvPMode.BATTLEGROUND:
            # Battleground mode will be set via join_battleground
            pass

        self.log.info(
            "Entered PvP mode",
            mode=mode.value,
            player=player_name,
            job=job_class,
        )

    async def exit_pvp(self) -> None:
        """Exit PvP mode and cleanup"""
        if not self.in_pvp:
            return

        # Cleanup mode-specific state
        if self.current_mode in [PvPMode.WOE_FE, PvPMode.WOE_SE, PvPMode.WOE_TE]:
            await self.woe.handle_woe_end()

        # Clear tracking
        self.enemy_tracking.clear()
        self.in_pvp = False
        self.current_mode = None

        self.log.info("Exited PvP mode")

    async def get_next_action(
        self,
        own_state: dict[str, Any],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
        map_layout: dict[str, Any],
    ) -> dict[str, Any]:
        """
        Get next optimal action based on current situation.
        
        This is the main decision-making method that coordinates
        all subsystems to determine the best action.
        """
        if not self.in_pvp:
            return {"action": "none", "reason": "not_in_pvp"}

        # Update enemy tracking
        for enemy in enemies:
            self._track_enemy(enemy)

        # Check for critical situations
        if self.core.threat_assessor.should_flee(own_state):
            return await self._handle_flee(own_state, enemies)

        # Mode-specific logic
        if self.current_mode == PvPMode.BATTLEGROUND:
            return await self._get_battleground_action(own_state, enemies, allies)

        elif self.current_mode in [PvPMode.WOE_FE, PvPMode.WOE_SE, PvPMode.WOE_TE]:
            return await self._get_woe_action(own_state, enemies, allies)

        else:
            return await self._get_general_pvp_action(own_state, enemies, allies, map_layout)

    async def _get_general_pvp_action(
        self,
        own_state: dict[str, Any],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
        map_layout: dict[str, Any],
    ) -> dict[str, Any]:
        """Get action for general PvP"""
        # Get tactical assessment
        if enemies:
            target_data = enemies[0]  # Simplified; could use select_target
            tactical_action = await self.tactics.get_tactical_action(
                own_state, target_data, len(allies), len(enemies)
            )

            # Select target
            target_id = await self.core.select_target(enemies, allies, own_state)

            if tactical_action == TacticalAction.BURST:
                # Execute burst combo
                combo = await self.tactics.get_optimal_combo(
                    self.own_job_class, target_data, own_state
                )
                if combo:
                    return {
                        "action": "execute_combo",
                        "combo": combo.skills,
                        "target_id": target_id,
                        "reason": "burst_window",
                    }

            elif tactical_action == TacticalAction.KITE:
                # Calculate kiting path
                path = await self.tactics.get_kiting_path(
                    own_state.get("position", (0, 0)),
                    target_data.get("position", (0, 0)),
                )
                return {
                    "action": "kite",
                    "path": path,
                    "target_id": target_id,
                    "reason": "tactical_kite",
                }

            elif tactical_action == TacticalAction.DISENGAGE:
                # Get defensive rotation
                defensive_skills = await self.tactics.get_defensive_rotation(
                    self.own_job_class, "high"
                )
                return {
                    "action": "disengage",
                    "skills": defensive_skills,
                    "reason": "tactical_retreat",
                }

            # Default: engage target
            return {
                "action": "engage",
                "target_id": target_id,
                "reason": "general_combat",
            }

        # No enemies - move to strategic position
        optimal_pos = await self.core.get_optimal_position(
            enemies, allies, own_state, map_layout
        )
        return {
            "action": "move_to_position",
            "position": optimal_pos,
            "reason": "positioning",
        }

    async def _get_woe_action(
        self,
        own_state: dict[str, Any],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Get action for WoE mode"""
        if not self.woe.woe_active:
            return {"action": "wait", "reason": "woe_not_active"}

        # Check guild coordination
        called_target = self.coordination.get_called_target()
        if called_target:
            # Focus called target
            return {
                "action": "attack_target",
                "target_id": called_target,
                "reason": "focus_fire",
            }

        # Check formation position
        formation_pos = self.coordination.get_formation_position(self.own_player_id)
        if formation_pos:
            own_pos = own_state.get("position", (0, 0))
            distance = ((own_pos[0] - formation_pos[0]) ** 2 + 
                       (own_pos[1] - formation_pos[1]) ** 2) ** 0.5
            
            if distance > 5:
                return {
                    "action": "move_to_position",
                    "position": formation_pos,
                    "reason": "formation_positioning",
                }

        # Role-specific WoE actions
        if self.woe.current_role == WoERole.EMPERIUM_BREAKER:
            # Attack emperium or move toward it
            if self.woe.target_castle:
                castle = self.woe.castles.get(self.woe.target_castle)
                if castle:
                    strategy = await self.woe.get_emperium_break_strategy(
                        castle, own_state
                    )
                    return {
                        "action": "break_emperium",
                        "strategy": strategy,
                        "reason": "emp_breaker_role",
                    }

        # Default: engage enemies
        target_id = await self.core.select_target(enemies, allies, own_state)
        return {
            "action": "engage",
            "target_id": target_id,
            "reason": "woe_combat",
        }

    async def _get_battleground_action(
        self,
        own_state: dict[str, Any],
        enemies: list[dict[str, Any]],
        allies: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Get action for Battleground mode"""
        if self.battlegrounds.match_state.value != "active":
            return {"action": "wait", "reason": "match_not_active"}

        # Get current BG objective
        objective = await self.battlegrounds.get_current_objective(
            own_state.get("position", (0, 0)), own_state
        )

        # Execute objective-based action
        if objective["action"] == "return_flag":
            return {
                "action": "move_to_position",
                "position": objective["target_position"],
                "priority": objective["priority"],
                "reason": "ctf_return_flag",
            }

        elif objective["action"] == "capture_flag":
            return {
                "action": "capture_objective",
                "position": objective["target_position"],
                "priority": objective["priority"],
                "reason": "ctf_capture_flag",
            }

        elif objective["action"] == "capture_point":
            return {
                "action": "capture_objective",
                "position": objective["target_position"],
                "control_point": objective.get("target_control_point"),
                "priority": objective["priority"],
                "reason": "conquest_capture_point",
            }

        elif objective["action"] == "engage_enemy":
            return {
                "action": "engage",
                "target_id": objective.get("target_player_id"),
                "priority": objective["priority"],
                "reason": "bg_combat",
            }

        # Default objective action
        return {
            "action": objective["action"],
            "priority": objective.get("priority", 5),
            "reason": "bg_objective",
        }

    async def _handle_flee(
        self, own_state: dict[str, Any], enemies: list[dict[str, Any]]
    ) -> dict[str, Any]:
        """Handle flee/escape situation"""
        # Get defensive combo
        escape_combo = await self.tactics.get_combo_for_situation(
            self.own_job_class, "escape", own_state
        )

        if escape_combo:
            return {
                "action": "execute_combo",
                "combo": escape_combo.skills,
                "reason": "emergency_escape",
                "priority": 10,
            }

        # Default flee
        return {
            "action": "flee",
            "reason": "critical_hp",
            "priority": 10,
        }

    async def handle_pvp_event(self, event_type: str, event_data: dict[str, Any]) -> None:
        """Handle PvP-related events"""
        if event_type == "player_killed":
            # Update threat assessment
            killer_id = event_data.get("killer_id")
            victim_id = event_data.get("victim_id")

            if victim_id == self.own_player_id:
                # We were killed
                self.core.threat_assessor.update_threat(
                    killer_id, "killed_us", event_data
                )
            elif killer_id == self.own_player_id:
                # We got a kill
                self.core.threat_assessor.update_threat(
                    victim_id, "killed_by_us", event_data
                )

        elif event_type == "skill_cast":
            # Update casting status
            caster_id = event_data.get("player_id")
            self.core.threat_assessor.update_threat(
                caster_id, "skill_cast", event_data
            )

        elif event_type == "woe_castle_captured":
            # Update castle ownership
            castle_id = event_data.get("castle_id")
            guild_name = event_data.get("guild_name")
            our_guild = event_data.get("our_guild")
            self.woe.update_castle_ownership(castle_id, guild_name, our_guild)

        elif event_type == "bg_score_update":
            # Update battleground score
            team = BGTeam(event_data.get("team", "guillaume"))
            score = event_data.get("score", 0)
            self.battlegrounds.update_score(team, score)

        elif event_type == "guild_command":
            # Process guild command
            command = event_data.get("command")
            await self.coordination.receive_command(command)

        self.log.debug("pvp_event_handled", event_type=event_type)

    def _track_enemy(self, enemy_data: dict[str, Any]) -> None:
        """Track enemy player data"""
        enemy_id = enemy_data.get("player_id", 0)
        
        if enemy_id not in self.enemy_tracking:
            self.enemy_tracking[enemy_id] = {
                "first_seen": datetime.now(),
                "last_seen": datetime.now(),
                "encounter_count": 1,
            }
        else:
            self.enemy_tracking[enemy_id]["last_seen"] = datetime.now()
            self.enemy_tracking[enemy_id]["encounter_count"] += 1

        # Update threat assessment
        self.core.threat_assessor.assess_threat(enemy_data)

    async def update_enemy_tracking(self, enemies: list[dict[str, Any]]) -> None:
        """Update tracking for all visible enemies"""
        for enemy in enemies:
            self._track_enemy(enemy)

        # Clean up old tracking data
        self.core.threat_assessor.clear_old_threats(max_age_seconds=300)

    # Subsystem-specific methods

    async def join_battleground(
        self, mode: BattlegroundMode, team: BGTeam
    ) -> bool:
        """Join a battleground queue"""
        return await self.battlegrounds.join_battleground(mode, team)

    async def set_woe_role(self, role: WoERole) -> None:
        """Set WoE role"""
        self.woe.set_role(role)

    async def set_formation(self, formation: FormationType) -> None:
        """Set guild formation"""
        await self.coordination.execute_formation(formation)

    async def call_target(self, target_id: int, duration: float = 15.0) -> None:
        """Call target for focus fire"""
        await self.coordination.call_target(
            target_id, self.own_player_id, duration
        )

    async def request_support(self, support_type: str, urgency: str = "medium") -> None:
        """Request support from guild"""
        priority_map = {
            "low": CommandPriority.LOW,
            "medium": CommandPriority.MEDIUM,
            "high": CommandPriority.HIGH,
            "critical": CommandPriority.CRITICAL,
        }
        priority = priority_map.get(urgency, CommandPriority.MEDIUM)

        await self.coordination.request_support(
            self.own_player_id, support_type, priority
        )

    def get_status(self) -> dict[str, Any]:
        """Get comprehensive PvP status"""
        return {
            "in_pvp": self.in_pvp,
            "mode": self.current_mode.value if self.current_mode else None,
            "player_id": self.own_player_id,
            "player_name": self.own_player_name,
            "job_class": self.own_job_class,
            "enemies_tracked": len(self.enemy_tracking),
            "woe": self.woe.get_woe_status() if self.woe.woe_active else None,
            "battleground": (
                self.battlegrounds.get_match_status()
                if self.battlegrounds.match_state.value == "active"
                else None
            ),
            "coordination": self.coordination.get_coordination_status(),
            "tactics": self.tactics.get_tactics_status(),
        }