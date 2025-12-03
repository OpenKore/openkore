"""
Guild coordination system - Team-based PvP coordination and communication.

Features:
- Formation management (wedge, line, box, scatter)
- Command system (call target, request support, regroup)
- Target calling and focus fire
- Support request coordination
- Buff synchronization
"""

from datetime import datetime, timedelta
from enum import Enum
from typing import Any

import structlog
from pydantic import BaseModel, Field


class FormationType(str, Enum):
    """Formation types for coordinated movement"""

    WEDGE = "wedge"  # V-formation for aggressive push
    LINE = "line"  # Horizontal line for area control
    BOX = "box"  # Protective formation around VIP
    SCATTER = "scatter"  # Spread out to avoid AoE
    COLUMN = "column"  # Single file for narrow passages
    CIRCLE = "circle"  # Defensive circle formation


class GuildCommand(str, Enum):
    """Guild command types"""

    CALL_TARGET = "call_target"
    REQUEST_HEAL = "request_heal"
    REQUEST_BUFF = "request_buff"
    REQUEST_SUPPORT = "request_support"
    REGROUP = "regroup"
    RETREAT = "retreat"
    PUSH = "push"
    HOLD_POSITION = "hold_position"
    FOCUS_FIRE = "focus_fire"
    SPREAD_OUT = "spread_out"
    PROTECT_VIP = "protect_vip"


class CommandPriority(int, Enum):
    """Command priority levels"""

    CRITICAL = 10
    HIGH = 7
    MEDIUM = 5
    LOW = 3


class GuildMember(BaseModel):
    """Guild member in coordination"""

    player_id: int
    player_name: str
    job_class: str
    role: str = "dps"  # tank, healer, dps, support
    position: tuple[int, int] = (0, 0)
    hp_percent: float = 100.0
    sp_percent: float = 100.0
    is_leader: bool = False
    formation_slot: int = 0
    last_seen: datetime = Field(default_factory=datetime.now)


class CoordinationCommand(BaseModel):
    """Coordination command"""

    command_id: str
    command_type: GuildCommand
    issuer_id: int
    issuer_name: str
    priority: CommandPriority = CommandPriority.MEDIUM
    target_id: int | None = None
    target_position: tuple[int, int] | None = None
    parameters: dict[str, Any] = Field(default_factory=dict)
    issued_at: datetime = Field(default_factory=datetime.now)
    expires_at: datetime | None = None


class FormationPosition(BaseModel):
    """Position in formation"""

    slot_id: int
    role: str
    relative_position: tuple[int, int]  # Relative to formation center
    description: str = ""


class GuildCoordinator:
    """
    Coordinate guild activities in PvP.

    Features:
    - Formation management
    - Command issuing and receiving
    - Target calling
    - Support coordination
    - Buff synchronization
    """

    def __init__(self) -> None:
        self.log = structlog.get_logger()
        self.members: dict[int, GuildMember] = {}
        self.active_commands: list[CoordinationCommand] = []
        self.current_formation: FormationType = FormationType.SCATTER
        self.formation_center: tuple[int, int] = (0, 0)
        self.formation_leader_id: int | None = None
        self.called_target_id: int | None = None
        self.called_target_expires: datetime | None = None
        self.formation_positions: dict[FormationType, list[FormationPosition]] = {}

        self._initialize_formations()

    def _initialize_formations(self) -> None:
        """Initialize formation templates"""
        # Wedge formation - aggressive push
        self.formation_positions[FormationType.WEDGE] = [
            FormationPosition(slot_id=0, role="leader", relative_position=(0, 0), description="Point"),
            FormationPosition(slot_id=1, role="tank", relative_position=(-2, 2), description="Left flank"),
            FormationPosition(slot_id=2, role="tank", relative_position=(2, 2), description="Right flank"),
            FormationPosition(slot_id=3, role="dps", relative_position=(-3, 4), description="Left wing"),
            FormationPosition(slot_id=4, role="dps", relative_position=(3, 4), description="Right wing"),
            FormationPosition(slot_id=5, role="healer", relative_position=(0, 6), description="Rear support"),
        ]

        # Line formation - area control
        self.formation_positions[FormationType.LINE] = [
            FormationPosition(slot_id=0, role="tank", relative_position=(-6, 0), description="Left end"),
            FormationPosition(slot_id=1, role="dps", relative_position=(-3, 0), description="Left center"),
            FormationPosition(slot_id=2, role="leader", relative_position=(0, 0), description="Center"),
            FormationPosition(slot_id=3, role="dps", relative_position=(3, 0), description="Right center"),
            FormationPosition(slot_id=4, role="tank", relative_position=(6, 0), description="Right end"),
            FormationPosition(slot_id=5, role="healer", relative_position=(0, 4), description="Back line"),
        ]

        # Box formation - protect VIP
        self.formation_positions[FormationType.BOX] = [
            FormationPosition(slot_id=0, role="vip", relative_position=(0, 0), description="Protected"),
            FormationPosition(slot_id=1, role="tank", relative_position=(0, -3), description="Front guard"),
            FormationPosition(slot_id=2, role="tank", relative_position=(0, 3), description="Rear guard"),
            FormationPosition(slot_id=3, role="dps", relative_position=(-3, 0), description="Left guard"),
            FormationPosition(slot_id=4, role="dps", relative_position=(3, 0), description="Right guard"),
            FormationPosition(slot_id=5, role="healer", relative_position=(2, 2), description="Support"),
        ]

        # Scatter formation - anti-AoE
        self.formation_positions[FormationType.SCATTER] = [
            FormationPosition(slot_id=0, role="any", relative_position=(0, 0), description="Center"),
            FormationPosition(slot_id=1, role="any", relative_position=(-8, -8), description="NW"),
            FormationPosition(slot_id=2, role="any", relative_position=(8, -8), description="NE"),
            FormationPosition(slot_id=3, role="any", relative_position=(-8, 8), description="SW"),
            FormationPosition(slot_id=4, role="any", relative_position=(8, 8), description="SE"),
            FormationPosition(slot_id=5, role="any", relative_position=(0, 10), description="South"),
        ]

    async def receive_command(self, command: CoordinationCommand) -> None:
        """Receive and process a coordination command"""
        # Add to active commands
        self.active_commands.append(command)

        self.log.info(
            "Command received",
            command=command.command_type.value,
            issuer=command.issuer_name,
            priority=command.priority,
        )

        # Process command immediately if critical
        if command.priority == CommandPriority.CRITICAL:
            await self._execute_command_immediately(command)

    async def _execute_command_immediately(self, command: CoordinationCommand) -> None:
        """Execute critical command immediately"""
        if command.command_type == GuildCommand.RETREAT:
            self.log.warning("CRITICAL: Retreat command received!")
            # Switch to scatter formation for escape
            await self.execute_formation(FormationType.SCATTER)

        elif command.command_type == GuildCommand.REGROUP:
            self.log.info("CRITICAL: Regroup command received!")
            if command.target_position:
                self.formation_center = command.target_position

        elif command.command_type == GuildCommand.CALL_TARGET:
            await self.call_target(
                command.target_id or 0,
                command.issuer_id,
                duration_seconds=command.parameters.get("duration", 15.0)
            )

    async def execute_formation(self, formation: FormationType) -> None:
        """Execute formation change"""
        self.current_formation = formation
        self.log.info("Formation changed", formation=formation.value)

        # Assign members to formation slots
        await self._assign_formation_slots()

    async def _assign_formation_slots(self) -> None:
        """Assign guild members to formation slots"""
        if self.current_formation not in self.formation_positions:
            return

        positions = self.formation_positions[self.current_formation]
        members_list = list(self.members.values())

        # Sort members by role priority
        role_priority = {"tank": 0, "healer": 1, "dps": 2, "support": 3}
        members_list.sort(key=lambda m: role_priority.get(m.role, 99))

        # Assign slots
        for i, member in enumerate(members_list):
            if i < len(positions):
                member.formation_slot = positions[i].slot_id

        self.log.debug("Formation slots assigned", member_count=len(members_list))

    async def call_target(
        self, target_id: int, caller_id: int, duration_seconds: float = 15.0
    ) -> None:
        """Call focus fire on target"""
        self.called_target_id = target_id
        self.called_target_expires = datetime.now() + timedelta(seconds=duration_seconds)

        caller_name = "Unknown"
        if caller_id in self.members:
            caller_name = self.members[caller_id].player_name

        self.log.info(
            "Target called",
            target_id=target_id,
            caller=caller_name,
            duration=duration_seconds,
        )

    async def request_support(
        self, requester_id: int, support_type: str, urgency: CommandPriority
    ) -> None:
        """Request support from guild"""
        if requester_id not in self.members:
            return

        requester = self.members[requester_id]

        command = CoordinationCommand(
            command_id=f"support_{requester_id}_{datetime.now().timestamp()}",
            command_type=(
                GuildCommand.REQUEST_HEAL
                if support_type == "heal"
                else GuildCommand.REQUEST_SUPPORT
            ),
            issuer_id=requester_id,
            issuer_name=requester.player_name,
            priority=urgency,
            target_position=requester.position,
            parameters={"support_type": support_type},
        )

        await self.receive_command(command)

    async def sync_buffs(self, buff_list: list[str]) -> dict[str, list[int]]:
        """Synchronize buff application across guild"""
        # Determine who needs which buffs
        buff_targets: dict[str, list[int]] = {buff: [] for buff in buff_list}

        for member in self.members.values():
            # Simple logic: all members need all buffs
            # More complex logic would check actual buff status
            for buff in buff_list:
                buff_targets[buff].append(member.player_id)

        self.log.debug("Buff sync calculated", buff_count=len(buff_list))
        return buff_targets

    def add_member(self, member_data: dict[str, Any]) -> None:
        """Add guild member to coordination"""
        player_id = member_data.get("player_id", 0)

        member = GuildMember(
            player_id=player_id,
            player_name=member_data.get("name", "Unknown"),
            job_class=member_data.get("job_class", "unknown"),
            role=member_data.get("role", "dps"),
            position=tuple(member_data.get("position", [0, 0])),
            hp_percent=member_data.get("hp_percent", 100.0),
            sp_percent=member_data.get("sp_percent", 100.0),
            is_leader=member_data.get("is_leader", False),
        )

        self.members[player_id] = member

        # If this is the leader, set as formation leader
        if member.is_leader:
            self.formation_leader_id = player_id
            self.formation_center = member.position

    def update_member_position(
        self, player_id: int, position: tuple[int, int]
    ) -> None:
        """Update member position"""
        if player_id in self.members:
            self.members[player_id].position = position
            self.members[player_id].last_seen = datetime.now()

            # Update formation center if this is the leader
            if player_id == self.formation_leader_id:
                self.formation_center = position

    def update_member_status(
        self, player_id: int, hp_percent: float, sp_percent: float
    ) -> None:
        """Update member HP/SP status"""
        if player_id in self.members:
            self.members[player_id].hp_percent = hp_percent
            self.members[player_id].sp_percent = sp_percent

    def remove_member(self, player_id: int) -> None:
        """Remove guild member"""
        if player_id in self.members:
            del self.members[player_id]

            # Reassign formation slots
            if self.members:
                self._assign_formation_slots()

    def get_formation_position(
        self, player_id: int
    ) -> tuple[int, int] | None:
        """Get assigned formation position for player"""
        if player_id not in self.members:
            return None

        member = self.members[player_id]
        positions = self.formation_positions.get(self.current_formation, [])

        # Find position for member's slot
        for pos in positions:
            if pos.slot_id == member.formation_slot:
                # Calculate absolute position
                abs_x = self.formation_center[0] + pos.relative_position[0]
                abs_y = self.formation_center[1] + pos.relative_position[1]
                return (abs_x, abs_y)

        # Default to formation center
        return self.formation_center

    def get_called_target(self) -> int | None:
        """Get currently called target if still valid"""
        if self.called_target_id is None:
            return None

        # Check if call has expired
        if self.called_target_expires and datetime.now() > self.called_target_expires:
            self.called_target_id = None
            self.called_target_expires = None
            return None

        return self.called_target_id

    def get_members_needing_support(
        self, support_type: str, hp_threshold: float = 50.0
    ) -> list[GuildMember]:
        """Get members needing support"""
        if support_type == "heal":
            return [
                m for m in self.members.values()
                if m.hp_percent < hp_threshold
            ]
        elif support_type == "sp":
            return [
                m for m in self.members.values()
                if m.sp_percent < 30.0
            ]
        else:
            return []

    def get_nearest_ally(
        self, position: tuple[int, int], role: str | None = None
    ) -> GuildMember | None:
        """Get nearest guild member, optionally filtered by role"""
        candidates = self.members.values()

        if role:
            candidates = [m for m in candidates if m.role == role]

        if not candidates:
            return None

        # Calculate distances
        def distance(m: GuildMember) -> float:
            dx = m.position[0] - position[0]
            dy = m.position[1] - position[1]
            return (dx * dx + dy * dy) ** 0.5

        return min(candidates, key=distance)

    def get_active_commands(
        self, priority: CommandPriority | None = None
    ) -> list[CoordinationCommand]:
        """Get active commands, optionally filtered by priority"""
        # Clean up expired commands
        now = datetime.now()
        self.active_commands = [
            cmd for cmd in self.active_commands
            if cmd.expires_at is None or cmd.expires_at > now
        ]

        if priority:
            return [cmd for cmd in self.active_commands if cmd.priority == priority]

        return self.active_commands

    def issue_command(
        self,
        command_type: GuildCommand,
        issuer_id: int,
        priority: CommandPriority = CommandPriority.MEDIUM,
        target_id: int | None = None,
        target_position: tuple[int, int] | None = None,
        parameters: dict[str, Any] | None = None,
        duration_seconds: float = 30.0,
    ) -> CoordinationCommand:
        """Issue a new coordination command"""
        issuer_name = "System"
        if issuer_id in self.members:
            issuer_name = self.members[issuer_id].player_name

        command = CoordinationCommand(
            command_id=f"{command_type.value}_{issuer_id}_{datetime.now().timestamp()}",
            command_type=command_type,
            issuer_id=issuer_id,
            issuer_name=issuer_name,
            priority=priority,
            target_id=target_id,
            target_position=target_position,
            parameters=parameters or {},
            expires_at=datetime.now() + timedelta(seconds=duration_seconds),
        )

        self.active_commands.append(command)

        self.log.info(
            "Command issued",
            command=command_type.value,
            issuer=issuer_name,
            priority=priority,
        )

        return command

    def get_coordination_status(self) -> dict[str, Any]:
        """Get current coordination status"""
        return {
            "formation": self.current_formation.value,
            "formation_center": self.formation_center,
            "member_count": len(self.members),
            "active_commands": len(self.active_commands),
            "called_target": self.called_target_id,
            "formation_leader": self.formation_leader_id,
            "members_low_hp": len([
                m for m in self.members.values() if m.hp_percent < 30.0
            ]),
        }

    async def should_regroup(self) -> bool:
        """Determine if guild should regroup"""
        if len(self.members) < 2:
            return False

        # Check member spread
        positions = [m.position for m in self.members.values()]
        center_x = sum(p[0] for p in positions) / len(positions)
        center_y = sum(p[1] for p in positions) / len(positions)

        # Calculate max distance from center
        max_distance = 0.0
        for pos in positions:
            dist = ((pos[0] - center_x) ** 2 + (pos[1] - center_y) ** 2) ** 0.5
            max_distance = max(max_distance, dist)

        # Regroup if members are too spread out (>30 cells)
        return max_distance > 30.0

    def clear_expired_commands(self) -> None:
        """Remove expired commands"""
        now = datetime.now()
        self.active_commands = [
            cmd for cmd in self.active_commands
            if cmd.expires_at is None or cmd.expires_at > now
        ]

    async def coordinate_team_attack(
        self, team: list[dict[str, Any]], enemies: list[Any]
    ) -> dict[str, Any]:
        """
        Coordinate team attack on enemies.
        
        Args:
            team: List of team member data
            enemies: List of enemy targets
            
        Returns:
            Coordination result with target assignments
        """
        if not team or not enemies:
            self.log.debug("Empty team or enemies in coordinate_team_attack")
            return {"assignments": [], "strategy": "none"}
        
        # Simple focus fire strategy - all attack highest priority target
        result = {
            "assignments": [],
            "strategy": "focus_fire",
            "called_target": None
        }
        
        if enemies:
            # Call target on first enemy
            primary_target = enemies[0]
            if hasattr(primary_target, 'id'):
                target_id = primary_target.id
            else:
                target_id = 0
                
            result["called_target"] = target_id
            
            # Assign all team members to attack primary target
            for member in team:
                result["assignments"].append({
                    "player_id": member.get("player_id", 0),
                    "target_id": target_id,
                    "action": "attack"
                })
        
        self.log.info(
            "Team attack coordinated",
            team_size=len(team),
            enemy_count=len(enemies),
            strategy=result["strategy"]
        )
        
        return result

    async def assign_roles(self, team: list[dict[str, Any]]) -> dict[str, list[int]]:
        """
        Assign roles to team members.
        
        Args:
            team: List of team member data
            
        Returns:
            Role assignments mapping role names to player IDs
        """
        assignments: dict[str, list[int]] = {
            "tank": [],
            "healer": [],
            "dps": [],
            "support": []
        }
        
        if not team:
            self.log.debug("Empty team in assign_roles")
            return assignments
        
        # Simple role assignment based on class or provided role
        for member in team:
            player_id = member.get("player_id", 0)
            job_class = member.get("class", "").lower()
            provided_role = member.get("role", "").lower()
            
            # Determine role
            if provided_role in assignments:
                role = provided_role
            elif any(tank_class in job_class for tank_class in ["knight", "crusader", "royal"]):
                role = "tank"
            elif any(heal_class in job_class for heal_class in ["priest", "acolyte", "arch"]):
                role = "healer"
            elif any(support_class in job_class for support_class in ["bard", "dancer", "professor"]):
                role = "support"
            else:
                role = "dps"
            
            assignments[role].append(player_id)
            
            # Update member in coordination if they exist
            if player_id in self.members:
                self.members[player_id].role = role
        
        self.log.info(
            "Roles assigned",
            team_size=len(team),
            tanks=len(assignments["tank"]),
            healers=len(assignments["healer"]),
            dps=len(assignments["dps"]),
            support=len(assignments["support"])
        )
        
        return assignments


# Alias for backward compatibility
TeamCoordinator = GuildCoordinator