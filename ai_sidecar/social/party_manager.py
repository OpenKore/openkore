"""
Party coordination manager for social features.

Manages party activities, role assignment, member monitoring,
and tactical coordination in Ragnarok Online.
"""

from typing import Literal

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class PartyManager:
    """Manages party coordination and tactics."""
    
    def __init__(self) -> None:
        self.party: Party | None = None
        self.pending_invites: list[int] = []
        self.coordination_mode: Literal["follow", "spread", "formation", "free"] = "follow"
        self.my_char_id: int | None = None
    
    async def tick(self, game_state: GameState) -> list[Action]:
        """Main party tick - process party coordination."""
        actions: list[Action] = []
        
        if not self.party:
            return actions
        
        # Update member statuses from game state
        self._update_party_state(game_state)
        
        # Priority 1: Emergency responses (heal party members)
        emergency = self._check_party_emergencies(game_state)
        if emergency:
            actions.extend(emergency)
            return actions
        
        # Priority 2: Role-based actions
        role_actions = self._execute_role_duties(game_state)
        actions.extend(role_actions)
        
        # Priority 3: Coordination (follow leader, formation)
        coord_actions = self._maintain_coordination(game_state)
        actions.extend(coord_actions)
        
        return actions
    
    def _update_party_state(self, game_state: GameState) -> None:
        """Update party member states from game state."""
        if not self.party:
            return
        
        # Update members from actors in game state
        for member in self.party.members:
            for actor in game_state.actors:
                if actor.name == member.name:
                    member.hp = actor.hp or member.hp
                    member.hp_max = actor.hp_max or member.hp_max
                    member.x = actor.position.x
                    member.y = actor.position.y
                    member.is_online = True
                    break
    
    def _check_party_emergencies(self, game_state: GameState) -> list[Action]:
        """Check for party members needing help."""
        actions: list[Action] = []
        
        if not self.party:
            return actions
        
        # Check if we can heal
        if not self._can_heal(game_state):
            return actions
        
        # Find members needing healing
        for member in self.party.members:
            if member.needs_healing and member.is_online:
                # Create heal action (placeholder - actual skill ID depends on class)
                actions.append(Action(
                    type=ActionType.SKILL,
                    skill_id=28,  # Heal skill ID (example)
                    target_id=member.char_id,
                    priority=1
                ))
                break  # Heal one at a time
        
        return actions
    
    def _execute_role_duties(self, game_state: GameState) -> list[Action]:
        """Execute duties based on assigned role."""
        my_role = self._get_my_role()
        
        if my_role == PartyRole.HEALER:
            return self._healer_duties(game_state)
        elif my_role == PartyRole.TANK:
            return self._tank_duties(game_state)
        elif my_role == PartyRole.SUPPORT:
            return self._support_duties(game_state)
        else:
            return self._dps_duties(game_state)
    
    def _healer_duties(self, game_state: GameState) -> list[Action]:
        """Healer role: prioritize keeping party alive."""
        actions: list[Action] = []
        
        if not self.party:
            return actions
        
        # Check for lowest HP member
        lowest_hp_member = min(
            self.party.online_members,
            key=lambda m: m.hp_percent,
            default=None
        )
        
        if lowest_hp_member and lowest_hp_member.hp_percent < 80:
            # Heal lowest HP member
            actions.append(Action(
                type=ActionType.SKILL,
                skill_id=28,  # Heal
                target_id=lowest_hp_member.char_id,
                priority=2
            ))
        
        return actions
    
    def _tank_duties(self, game_state: GameState) -> list[Action]:
        """Tank role: aggro management, protect squishies."""
        actions: list[Action] = []
        
        # Get nearest monster
        monsters = game_state.get_monsters()
        if monsters:
            nearest = min(
                monsters,
                key=lambda m: m.position.distance_to(game_state.character.position)
            )
            
            # Attack to maintain aggro
            actions.append(Action.attack(nearest.id, priority=3))
        
        return actions
    
    def _support_duties(self, game_state: GameState) -> list[Action]:
        """Support role: buffs, debuffs, utility."""
        # Placeholder for support logic
        return []
    
    def _dps_duties(self, game_state: GameState) -> list[Action]:
        """DPS role: damage optimization."""
        actions: list[Action] = []
        
        # Attack monsters
        monsters = game_state.get_monsters()
        if monsters:
            # Target lowest HP monster
            target = min(monsters, key=lambda m: m.hp or 999999)
            actions.append(Action.attack(target.id, priority=4))
        
        return actions
    
    def _maintain_coordination(self, game_state: GameState) -> list[Action]:
        """Maintain party coordination (follow leader, formation)."""
        actions: list[Action] = []
        
        if not self.party or self.coordination_mode == "free":
            return actions
        
        if self.coordination_mode == "follow" and self.party.settings.follow_leader:
            leader = self.party.get_leader()
            if leader and not self._am_i_leader():
                # Follow leader if too far
                my_pos = game_state.character.position
                leader_distance = ((my_pos.x - leader.x) ** 2 + (my_pos.y - leader.y) ** 2) ** 0.5
                
                if leader_distance > 5:
                    actions.append(Action.move_to(leader.x, leader.y, priority=6))
        
        return actions
    
    def _can_heal(self, game_state: GameState) -> bool:
        """Check if character can cast heal."""
        # Placeholder - check if we have heal skill and enough SP
        return game_state.character.sp > 10
    
    def _get_my_role(self) -> PartyRole:
        """Get my assigned party role."""
        if not self.party or not self.my_char_id:
            return PartyRole.FLEX
        
        my_member = self.party.get_member_by_id(self.my_char_id)
        return my_member.assigned_role if my_member else PartyRole.FLEX
    
    def _am_i_leader(self) -> bool:
        """Check if I am the party leader."""
        if not self.party or not self.my_char_id:
            return False
        return self.party.leader_id == self.my_char_id
    
    def assign_roles(self, party: Party) -> dict[int, PartyRole]:
        """Auto-assign roles based on job classes."""
        role_assignments: dict[int, PartyRole] = {}
        
        for member in party.members:
            job = member.job_class.lower()
            
            # Simple job-to-role mapping
            if "priest" in job or "acolyte" in job:
                role = PartyRole.HEALER
            elif "knight" in job or "crusader" in job or "swordsman" in job:
                role = PartyRole.TANK
            elif "sage" in job or "wizard" in job or "magician" in job:
                role = PartyRole.DPS_MAGIC
            elif "hunter" in job or "archer" in job or "bard" in job or "dancer" in job:
                role = PartyRole.DPS_RANGED
            elif "assassin" in job or "rogue" in job or "thief" in job:
                role = PartyRole.DPS_MELEE
            else:
                role = PartyRole.FLEX
            
            role_assignments[member.char_id] = role
            member.assigned_role = role
        
        return role_assignments
    
    def handle_party_invite(self, inviter_id: int, inviter_name: str) -> Action | None:
        """Handle incoming party invite."""
        # Auto-accept if setting enabled
        if self.party and self.party.settings.auto_accept_invites:
            logger.info(f"Auto-accepting party invite from {inviter_name}")
            # Return accept action (implementation depends on protocol)
            return None
        
        # Add to pending invites
        self.pending_invites.append(inviter_id)
        return None
    
    def set_party(self, party: Party) -> None:
        """Set the current party."""
        self.party = party
        
        # Auto-assign roles
        self.assign_roles(party)
        
        logger.info(f"Party set: {party.name} with {party.member_count} members")