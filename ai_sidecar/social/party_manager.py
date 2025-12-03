"""
Party coordination manager for social features.

Manages party activities, role assignment, member monitoring,
and tactical coordination in Ragnarok Online.
"""

from typing import Literal, Tuple
import random

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.core.state import GameState
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole
from ai_sidecar.social import config
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class PartyManager:
    """Manages party coordination and tactics."""
    
    # Essential buff IDs to track
    ESSENTIAL_BUFFS = {
        34: "Blessing",
        29: "Increase AGI",
        30: "Angelus",
        33: "Kyrie Eleison",
        74: "Gloria",
        156: "Magnificat",
    }
    
    # Common debuff IDs to track
    DEBUFFS = {
        71: "Decrease AGI",
        79: "Lex Aeterna",
        235: "Quagmire",
        19: "Fire Wall",  # Area denial
    }
    
    # Heal skill IDs by job
    HEAL_SKILLS = {
        "acolyte": 28,
        "priest": 28,
        "high priest": 28,
        "archbishop": 2042,
        "paladin": 379,  # Heal from Grand Cross
        "royal guard": 379,
    }
    
    def __init__(self) -> None:
        self.party: Party | None = None
        self.pending_invites: dict[int, dict] = {}  # inviter_id -> invite_data
        self.coordination_mode: Literal["follow", "spread", "formation", "free"] = "follow"
        self.my_char_id: int | None = None
        self.relationships: dict[str, str] = {}  # player_name -> relationship_type
        self.blacklist: set[str] = set()
        self.friend_list: set[str] = set()
        self.guild_members: set[str] = set()
        self.party_history: dict[str, int] = {}  # player_name -> party_count
        self.member_buffs: dict[int, set[int]] = {}  # char_id -> set of buff IDs
        self.monster_debuffs: dict[int, set[int]] = {}  # monster_id -> set of debuff IDs
        self.buff_expiry: dict[int, dict[int, float]] = {}  # char_id -> {buff_id: expiry_time}
    
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
        
        # Find members needing healing - handle Mock objects gracefully
        for member in self.party.members:
            # Safely get hp_percent, handling Mock objects
            try:
                hp_percent = member.hp_percent
                # Check if it's a real number (not Mock)
                if isinstance(hp_percent, (int, float)):
                    if hp_percent < 70.0 and member.is_online:
                        # Create heal action
                        actions.append(Action(
                            type=ActionType.SKILL,
                            skill_id=28,  # Heal skill ID
                            target_id=member.char_id,
                            priority=1
                        ))
                        break  # Heal one at a time
            except (TypeError, AttributeError):
                # Skip members with invalid HP data
                continue
        
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
        
        # Find lowest HP member - handle Mock objects
        lowest_hp_member = None
        lowest_hp = 100.0
        
        for member in self.party.online_members:
            try:
                hp_percent = member.hp_percent
                if isinstance(hp_percent, (int, float)) and hp_percent < lowest_hp:
                    lowest_hp = hp_percent
                    lowest_hp_member = member
            except (TypeError, AttributeError):
                continue
        
        if lowest_hp_member and lowest_hp < 80.0:
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
        actions: list[Action] = []
        
        if not self.party:
            return actions
        
        # Check for members needing buffs
        unbuffed_members = [
            m for m in self.party.online_members
            if not self._has_essential_buffs(m)
        ]
        
        if unbuffed_members:
            # Buff random unbuffed member to appear more human
            target = random.choice(unbuffed_members)
            # Use blessing/increase AGI/etc based on job
            buff_skill_id = self._get_support_buff_skill(game_state)
            if buff_skill_id:
                actions.append(Action(
                    type=ActionType.SKILL,
                    skill_id=buff_skill_id,
                    target_id=target.char_id,
                    priority=4
                ))
        
        # Check for debuff opportunities on monsters
        monsters = game_state.get_monsters()
        if monsters and game_state.character.sp > 20:
            # Find nearest monster without debuff
            for monster in monsters[:3]:  # Check top 3 nearest
                if not self._has_debuff(monster):
                    debuff_skill_id = self._get_support_debuff_skill(game_state)
                    if debuff_skill_id:
                        actions.append(Action(
                            type=ActionType.SKILL,
                            skill_id=debuff_skill_id,
                            target_id=monster.id,
                            priority=5
                        ))
                        break
        
        return actions
    
    def _has_essential_buffs(self, member: PartyMember) -> bool:
        """
        Check if party member has essential buffs.
        
        Uses tracked buff status from game events. Falls back to
        HP/SP ratio heuristic if buff tracking unavailable.
        """
        import time
        
        # Check tracked buffs
        char_id = member.char_id
        if char_id in self.member_buffs and char_id in self.buff_expiry:
            current_time = time.time()
            active_buffs = set()
            
            # Remove expired buffs
            for buff_id in list(self.buff_expiry.get(char_id, {}).keys()):
                if self.buff_expiry[char_id][buff_id] <= current_time:
                    self.member_buffs.get(char_id, set()).discard(buff_id)
                    del self.buff_expiry[char_id][buff_id]
                else:
                    active_buffs.add(buff_id)
            
            # Check if has at least one essential buff
            essential_ids = set(self.ESSENTIAL_BUFFS.keys())
            has_essential = bool(active_buffs & essential_ids)
            
            if active_buffs:  # Has some buff tracking
                return has_essential
        
        # Fallback heuristic: if HP/SP both high, likely buffed
        # Players usually buff before combat when resources are full
        # Handle Mock objects gracefully
        try:
            hp_pct = member.hp_percent
            sp_pct = member.sp_percent
            if isinstance(hp_pct, (int, float)) and isinstance(sp_pct, (int, float)):
                return hp_pct >= 95.0 and sp_pct >= 90.0
        except (TypeError, AttributeError):
            pass
        
        return False
    
    def _has_debuff(self, monster) -> bool:
        """
        Check if monster has debuffs applied by us.
        
        Uses tracked debuff status from skill cast events.
        """
        if not hasattr(monster, 'id'):
            return False
        
        monster_id = monster.id
        if monster_id in self.monster_debuffs:
            return len(self.monster_debuffs[monster_id]) > 0
        
        return False
    
    def add_buff(self, char_id: int, buff_id: int, duration_seconds: float = 120.0) -> None:
        """
        Record a buff being applied to party member.
        
        Args:
            char_id: Character ID receiving buff
            buff_id: Buff skill ID
            duration_seconds: Duration of buff
        """
        import time
        
        if char_id not in self.member_buffs:
            self.member_buffs[char_id] = set()
        if char_id not in self.buff_expiry:
            self.buff_expiry[char_id] = {}
        
        self.member_buffs[char_id].add(buff_id)
        self.buff_expiry[char_id][buff_id] = time.time() + duration_seconds
        
        buff_name = self.ESSENTIAL_BUFFS.get(buff_id, f"Buff#{buff_id}")
        logger.debug(f"Buff applied: {buff_name} on char {char_id}")
    
    def add_debuff(self, monster_id: int, debuff_id: int) -> None:
        """
        Record a debuff being applied to monster.
        
        Args:
            monster_id: Monster ID receiving debuff
            debuff_id: Debuff skill ID
        """
        if monster_id not in self.monster_debuffs:
            self.monster_debuffs[monster_id] = set()
        
        self.monster_debuffs[monster_id].add(debuff_id)
        debuff_name = self.DEBUFFS.get(debuff_id, f"Debuff#{debuff_id}")
        logger.debug(f"Debuff applied: {debuff_name} on monster {monster_id}")
    
    def clear_monster_debuffs(self, monster_id: int) -> None:
        """Clear debuffs when monster dies or despawns."""
        if monster_id in self.monster_debuffs:
            del self.monster_debuffs[monster_id]
    
    def _get_support_buff_skill(self, game_state: GameState) -> int | None:
        """Get appropriate buff skill based on character class."""
        # Mapping of job to common buff skill IDs
        # This is a simplified version - actual skill IDs depend on RO version
        job = game_state.character.job_class.lower()
        
        if "priest" in job or "acolyte" in job:
            return 34  # Blessing
        elif "sage" in job:
            return 157  # Endow abilities
        elif "bard" in job or "dancer" in job:
            return None  # Song/dance skills handled differently
        
        return None
    
    def _get_support_debuff_skill(self, game_state: GameState) -> int | None:
        """Get appropriate debuff skill based on character class."""
        job = game_state.character.job_class.lower()
        
        if "sage" in job or "wizard" in job:
            return 19  # Earth Spike (example)
        elif "priest" in job:
            return 71  # Decrease AGI
        
        return None
    
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
        """
        Check if character can cast heal skill.
        
        Verifies:
        1. Character has a heal skill for their job
        2. Has enough SP to cast
        3. Is not silenced/disabled
        """
        job = game_state.character.job_class.lower()
        
        # Find matching heal skill for job
        heal_skill_id = None
        for job_key, skill_id in self.HEAL_SKILLS.items():
            if job_key in job:
                heal_skill_id = skill_id
                break
        
        if not heal_skill_id:
            return False  # Job can't heal
        
        # Check SP requirement (Heal costs ~10-20 SP based on level)
        min_sp_required = 15
        if game_state.character.sp < min_sp_required:
            return False
        
        # Check for silence status (would prevent casting)
        # Status ID 1 = Stone Curse, 2 = Freeze, etc.
        silenced_statuses = {1, 2, 7}  # Stone, Freeze, Silence
        if hasattr(game_state.character, 'status_effects'):
            char_statuses = set(game_state.character.status_effects or [])
            if char_statuses & silenced_statuses:
                return False
        
        return True
    
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
            elif "hunter" in job or "sniper" in job or "archer" in job or "bard" in job or "dancer" in job or "ranger" in job:
                role = PartyRole.DPS_RANGED
            elif "assassin" in job or "rogue" in job or "thief" in job:
                role = PartyRole.DPS_MELEE
            else:
                role = PartyRole.FLEX
            
            role_assignments[member.char_id] = role
            member.assigned_role = role
        
        return role_assignments
    
    def should_accept_invite(self, player_name: str) -> bool:
        """
        Alias for should_accept_party_invite.
        
        Determine if should accept party invitation.
        
        Args:
            player_name: Name of player sending invite
            
        Returns:
            True if should accept, False otherwise
        """
        should_accept, _ = self.should_accept_party_invite(player_name, {})
        return should_accept
    
    def should_accept_party_invite(
        self, inviter_name: str, inviter_data: dict
    ) -> Tuple[bool, str]:
        """
        Determine if should accept party invitation.
        
        Args:
            inviter_name: Name of player sending invite
            inviter_data: Additional data about inviter (guild, level, etc.)
        
        Returns:
            Tuple of (should_accept, reason)
        """
        # Check blacklist first
        if self.is_blacklisted(inviter_name):
            return False, f"Rejected: {inviter_name} is blacklisted"
        
        # Check relationship
        relationship = self.get_relationship(inviter_name)
        criteria = config.PARTY_ACCEPT_CRITERIA.get(
            relationship,
            config.PARTY_ACCEPT_CRITERIA["stranger"]
        )
        
        if criteria["auto_accept"]:
            return True, f"Accepted: {criteria['reason']}"
        elif criteria.get("ask"):
            # Queue for user confirmation
            self.pending_invites[inviter_data.get("char_id", 0)] = {
                "name": inviter_name,
                "data": inviter_data,
                "relationship": relationship
            }
            return False, f"Pending confirmation: {criteria['reason']}"
        else:
            return False, f"Rejected: {criteria['reason']}"
    
    def get_relationship(self, player_name: str) -> str:
        """
        Get relationship type with player.
        
        Args:
            player_name: Player name to check
            
        Returns:
            Relationship type string
        """
        # Check cached relationship
        if player_name in self.relationships:
            return self.relationships[player_name]
        
        # Determine relationship
        if player_name in self.blacklist:
            rel = config.RelationshipType.BLACKLIST
        elif player_name in self.friend_list:
            rel = config.RelationshipType.FRIEND
        elif player_name in self.guild_members:
            rel = config.RelationshipType.GUILD_MEMBER
        elif player_name in self.party_history:
            party_count = self.party_history[player_name]
            if party_count >= config.RELATIONSHIP_THRESHOLDS["party_count_for_known"]:
                rel = config.RelationshipType.KNOWN_PLAYER
            else:
                rel = config.RelationshipType.PARTY_HISTORY
        else:
            rel = config.RelationshipType.STRANGER
        
        # Cache relationship
        self.relationships[player_name] = rel
        return rel
    
    def is_blacklisted(self, player_name: str) -> bool:
        """Check if player is blacklisted."""
        return player_name in self.blacklist
    
    def add_to_blacklist(self, player_name: str, reason: str) -> None:
        """Add player to blacklist."""
        self.blacklist.add(player_name)
        self.relationships[player_name] = config.RelationshipType.BLACKLIST
        logger.warning(f"Added {player_name} to blacklist: {reason}")
    
    def add_to_friend_list(self, player_name: str) -> None:
        """Add player to friend list."""
        self.friend_list.add(player_name)
        self.relationships.pop(player_name, None)  # Invalidate cache
        logger.info(f"Added {player_name} to friend list")
    
    def record_party_session(self, player_name: str) -> None:
        """Record party session with player."""
        self.party_history[player_name] = self.party_history.get(player_name, 0) + 1
        self.relationships.pop(player_name, None)  # Invalidate cache
        logger.debug(f"Recorded party session with {player_name}: {self.party_history[player_name]} total")
    
    def handle_party_invite(self, inviter_id: int, inviter_name: str, inviter_data: dict | None = None) -> Action | None:
        """
        Handle incoming party invite.
        
        Args:
            inviter_id: Character ID of inviter
            inviter_name: Name of inviter
            inviter_data: Additional data about inviter
            
        Returns:
            Action to accept/reject or None if pending
        """
        if inviter_data is None:
            inviter_data = {"char_id": inviter_id}
        
        # Auto-accept if party settings enable it
        if self.party and self.party.settings.auto_accept_invites:
            logger.info(f"Auto-accepting party invite from {inviter_name}")
            return Action(
                type=ActionType.NOOP,  # Would be ACCEPT_PARTY_INVITE
                priority=1,
                extra={"inviter_id": inviter_id, "accept": True}
            )
        
        # Use decision logic
        should_accept, reason = self.should_accept_party_invite(inviter_name, inviter_data)
        
        logger.info(f"Party invite from {inviter_name}: {reason}")
        
        if should_accept:
            # Add small delay to appear human
            delay = random.uniform(*config.BEHAVIOR_RANDOMIZATION["party_accept_delay"])
            logger.debug(f"Accepting party invite with {delay:.1f}s delay")
            
            return Action(
                type=ActionType.NOOP,  # Would be ACCEPT_PARTY_INVITE
                priority=1,
                extra={"inviter_id": inviter_id, "accept": True, "delay": delay}
            )
        elif inviter_data.get("char_id", 0) in self.pending_invites:
            # Pending user confirmation
            return None
        else:
            # Reject
            return Action(
                type=ActionType.NOOP,  # Would be REJECT_PARTY_INVITE
                priority=1,
                extra={"inviter_id": inviter_id, "accept": False}
            )
    
    async def leave_party(self) -> bool:
        """Leave current party."""
        if not self.party:
            return False
        
        self.party = None
        logger.info("Left party")
        return True
    
    async def kick_member(self, member_name: str) -> bool:
        """
        Kick a member from party (requires leader).
        
        Args:
            member_name: Name of member to kick
            
        Returns:
            True if kicked successfully
        """
        if not self.party or not self._am_i_leader():
            return False
        
        for member in self.party.members:
            if member.name == member_name:
                self.party.members.remove(member)
                logger.info(f"Kicked {member_name} from party")
                return True
        
        return False
    
    def get_party_members(self) -> list:
        """Get list of party members."""
        if not self.party:
            return []
        return [{"name": m.name, "level": m.base_level, "job": m.job_class} for m in self.party.members]
    
    def set_party(self, party: Party) -> None:
        """Set the current party."""
        self.party = party
        
        # Auto-assign roles
        self.assign_roles(party)
        
        # Record party session with all members
        for member in party.members:
            if member.char_id != self.my_char_id:
                self.record_party_session(member.name)
        
        logger.info(f"Party set: {party.name} with {party.member_count} members")
    
    def set_guild_members(self, members: list[str]) -> None:
        """Set guild member list for relationship tracking."""
        self.guild_members = set(members)
        # Invalidate cache for these members
        for name in members:
            self.relationships.pop(name, None)
        logger.debug(f"Updated guild member list: {len(members)} members")
    
    def set_friend_list(self, friends: list[str]) -> None:
        """Set friend list for relationship tracking."""
        self.friend_list = set(friends)
        # Invalidate cache for these friends
        for name in friends:
            self.relationships.pop(name, None)
        logger.debug(f"Updated friend list: {len(friends)} friends")
    
    def set_role(self, role: PartyRole | str) -> None:
        """
        Set this character's party role.
        
        Args:
            role: Party role to assign
        """
        if not self.party or not self.my_char_id:
            logger.warning("Cannot set role: not in party or character ID not set")
            return
        
        # Convert string to enum if needed
        if isinstance(role, str):
            role = PartyRole(role.lower())
        
        # Find and update my member record
        my_member = self.party.get_member_by_id(self.my_char_id)
        if my_member:
            old_role = my_member.assigned_role
            my_member.assigned_role = role
            logger.info(f"Party role changed: {old_role.value} → {role.value}")
        else:
            logger.warning(f"Cannot set role: character ID {self.my_char_id} not found in party")