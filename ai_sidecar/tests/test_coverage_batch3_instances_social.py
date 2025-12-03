"""
Coverage Batch 3: Instances, Social & NPC Systems
Target: ~92% → ~98% coverage
Modules: instances (state, registry), social (party, guild), NPCs (quests)

Focuses on uncovered edge cases, error paths, and boundary conditions.
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from pathlib import Path

from ai_sidecar.instances.state import (
    InstanceState,
    InstanceStateManager,
    FloorState,
    InstancePhase,
    InstanceType,
)
from ai_sidecar.instances.registry import (
    InstanceRegistry,
    InstanceDefinition,
    InstanceRequirement,
    InstanceReward,
    InstanceType as RegInstanceType,
    InstanceDifficulty,
)
from ai_sidecar.social.party_manager import PartyManager
from ai_sidecar.social.guild_manager import GuildManager
from ai_sidecar.npc.quest_manager import QuestManager


# ============================================================================
# INSTANCE STATE TESTS - Targeting uncovered lines
# ============================================================================

class TestInstanceStateEdgeCases:
    """Test edge cases in instance state management."""
    
    @pytest.mark.asyncio
    async def test_update_floor_progress_no_instance(self):
        """Cover line 261-262: Early return when no instance."""
        manager = InstanceStateManager()
        
        # Should return without error
        await manager.update_floor_progress(monsters_killed=5)
        
        assert manager.current_instance is None
    
    @pytest.mark.asyncio
    async def test_update_floor_progress_no_floor_state(self):
        """Cover line 264-266: Early return when no floor state."""
        manager = InstanceStateManager()
        
        # Create instance with empty floors dict
        manager.current_instance = InstanceState(
            instance_id="test",
            current_floor=99,  # Floor doesn't exist
            total_floors=1,
            floors={}
        )
        
        await manager.update_floor_progress(monsters_killed=5)
        
        # Should not crash
        assert manager.current_instance.current_floor == 99
    
    @pytest.mark.asyncio
    async def test_advance_floor_no_current_floor_state(self):
        """Cover line 297-299: Handle missing current floor state."""
        manager = InstanceStateManager()
        
        # Create instance with floor that doesn't exist
        manager.current_instance = InstanceState(
            instance_id="test",
            current_floor=1,
            total_floors=3,
            floors={2: FloorState(floor_number=2)}  # Floor 1 missing
        )
        
        result = await manager.advance_floor()
        
        # Should still advance
        assert result == True
        assert manager.current_instance.current_floor == 2
    
    @pytest.mark.asyncio
    async def test_advance_floor_no_next_floor_state(self):
        """Cover line 308-310: Handle missing next floor state."""
        manager = InstanceStateManager()
        
        # Create instance where next floor doesn't exist
        manager.current_instance = InstanceState(
            instance_id="test",
            current_floor=1,
            total_floors=3,
            floors={1: FloorState(floor_number=1)}  # Floor 2 missing
        )
        
        result = await manager.advance_floor()
        
        # Should still advance
        assert result == True
        assert manager.current_instance.current_floor == 2
    
    @pytest.mark.asyncio
    async def test_record_death_no_instance(self):
        """Cover line 330-331: Early return when no instance."""
        manager = InstanceStateManager()
        
        await manager.record_death(member_name="TestPlayer")
        
        # Should not crash
        assert manager.current_instance is None
    
    @pytest.mark.asyncio
    async def test_record_resurrection_no_instance(self):
        """Cover line 355-356: Early return when no instance."""
        manager = InstanceStateManager()
        
        await manager.record_resurrection(member_name="TestPlayer")
        
        assert manager.current_instance is None
    
    @pytest.mark.asyncio
    async def test_record_resurrection_member_not_in_party(self):
        """Cover line 360: Handle resurrection of non-party member."""
        manager = InstanceStateManager()
        
        # Create instance with party
        manager.current_instance = InstanceState(
            instance_id="test",
            party_members=["Alice", "Bob"],
            party_alive_count=1
        )
        
        # Resurrect someone not in party
        await manager.record_resurrection(member_name="Charlie")
        
        # Party alive count should not change
        assert manager.current_instance.party_alive_count == 1
        assert manager.current_instance.resurrections_used == 1
    
    @pytest.mark.asyncio
    async def test_record_loot_no_instance(self):
        """Cover line 379-380: Early return when no instance."""
        manager = InstanceStateManager()
        
        await manager.record_loot(items=["Item1", "Item2"])
        
        assert manager.current_instance is None
    
    @pytest.mark.asyncio
    async def test_record_loot_no_floor_state(self):
        """Cover line 385-387: Handle missing floor state when recording loot."""
        manager = InstanceStateManager()
        
        # Create instance with missing current floor
        manager.current_instance = InstanceState(
            instance_id="test",
            current_floor=99,
            total_floors=1,
            floors={}
        )
        
        await manager.record_loot(items=["Item1"])
        
        # Loot should still be recorded to total
        assert "Item1" in manager.current_instance.total_loot
    
    @pytest.mark.asyncio
    async def test_record_consumable_no_instance(self):
        """Cover line 403-404: Early return when no instance."""
        manager = InstanceStateManager()
        
        await manager.record_consumable_use("Potion", 5)
        
        assert manager.current_instance is None
    
    @pytest.mark.asyncio
    async def test_check_time_critical_no_instance(self):
        """Cover line 416-417: Return False when no instance."""
        manager = InstanceStateManager()
        
        result = await manager.check_time_critical()
        
        assert result == False
    
    @pytest.mark.asyncio
    async def test_should_abort_no_instance(self):
        """Cover line 428-429: Return False when no instance."""
        manager = InstanceStateManager()
        
        should_abort, reason = await manager.should_abort()
        
        assert should_abort == False
        assert reason == ""
    
    @pytest.mark.asyncio
    async def test_should_abort_party_wiped(self):
        """Cover line 436-438: Detect party wipe condition."""
        manager = InstanceStateManager()
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.PARTY_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            time_limit_minutes=60
        )
        
        state = await manager.start_instance(
            instance_def,
            party_members=["Alice", "Bob", "Charlie"]
        )
        
        # Wipe the party
        state.party_alive_count = 0
        
        should_abort, reason = await manager.should_abort()
        
        assert should_abort == True
        assert "Party wiped" in reason
    
    @pytest.mark.asyncio
    async def test_should_abort_time_critical_low_progress(self):
        """Cover line 441-443: Abort when time critical and low progress."""
        manager = InstanceStateManager()
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            time_limit_minutes=60  # 60 minute time limit
        )
        
        state = await manager.start_instance(instance_def)
        
        # Simulate being near time limit with low progress
        # Set time so that < 20% remains, and we have < 30% progress
        elapsed = timedelta(minutes=50)  # 50/60 = 83.3% elapsed, 16.7% remaining (< 20%)
        state.started_at = datetime.now() - elapsed
        state.time_limit = state.started_at + timedelta(minutes=60)
        
        # Set low progress: only 1 out of 10 floors cleared = 10% < 30%
        state.current_floor = 1
        state.total_floors = 10
        state.floors[1].boss_killed = False  # Floor 1 not cleared
        
        should_abort, reason = await manager.should_abort()
        
        assert should_abort == True
        assert "Time critical" in reason or "low progress" in reason
    
    @pytest.mark.asyncio
    async def test_should_abort_time_exceeded(self):
        """Cover line 446-447: Abort when time limit exceeded."""
        manager = InstanceStateManager()
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            time_limit_minutes=1
        )
        
        state = await manager.start_instance(instance_def)
        
        # Set time limit to past - this should trigger line 446-447
        # Make sure we have good progress so time_critical check passes
        state.started_at = datetime.now() - timedelta(minutes=2)
        state.time_limit = datetime.now() - timedelta(seconds=10)
        state.current_floor = 1
        state.total_floors = 1
        # Mark floor as cleared to get > 30% progress
        state.floors[1].boss_killed = True
        
        should_abort, reason = await manager.should_abort()
        
        assert should_abort == True
        assert "Time limit exceeded" in reason
    
    @pytest.mark.asyncio
    async def test_complete_instance_no_instance_raises(self):
        """Cover line 461-462: Raise error when completing with no instance."""
        manager = InstanceStateManager()
        
        with pytest.raises(ValueError, match="No active instance"):
            await manager.complete_instance()
    
    @pytest.mark.asyncio
    async def test_complete_instance_sets_floor_completion_time(self):
        """Cover line 469-472: Set floor completion time on success."""
        manager = InstanceStateManager()
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL
        )
        
        await manager.start_instance(instance_def)
        floor_state = manager.current_instance.get_current_floor_state()
        
        # Ensure time_completed is None initially
        assert floor_state.time_completed is None
        
        completed = await manager.complete_instance(success=True)
        
        # Floor should have completion time
        assert floor_state.time_completed is not None
    
    @pytest.mark.asyncio
    async def test_complete_instance_trims_history(self):
        """Cover line 488-489: Trim history when > 50 entries."""
        manager = InstanceStateManager()
        instance_def = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL
        )
        
        # Fill history with 51 instances
        for i in range(51):
            state = InstanceState(
                instance_id=f"test_{i}",
                instance_name=f"Test {i}"
            )
            manager.instance_history.append(state)
        
        # Complete one more
        await manager.start_instance(instance_def)
        await manager.complete_instance()
        
        # History should be trimmed to 25 most recent
        assert len(manager.instance_history) == 25


# ============================================================================
# INSTANCE REGISTRY TESTS - Targeting uncovered lines
# ============================================================================

class TestInstanceRegistryEdgeCases:
    """Test edge cases in instance registry."""
    
    @pytest.mark.asyncio
    async def test_check_requirements_unknown_instance(self):
        """Cover line 265-266: Unknown instance returns False."""
        registry = InstanceRegistry()
        
        can_enter, missing = await registry.check_requirements(
            "nonexistent_instance",
            {"base_level": 99}
        )
        
        assert can_enter == False
        assert len(missing) == 1
        assert "Unknown instance" in missing[0]
    
    @pytest.mark.asyncio
    async def test_check_requirements_level_too_high(self):
        """Cover line 278-281: Level exceeds maximum."""
        registry = InstanceRegistry()
        
        # Add instance with max level
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(
                min_level=50,
                max_level=99
            )
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 150}  # Too high
        )
        
        assert can_enter == False
        assert any("too high" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_wrong_job_class(self):
        """Cover line 284-290: Wrong job class requirement."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(
                required_job_classes=["Priest", "Monk"]
            )
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99, "job_class": "Knight"}
        )
        
        assert can_enter == False
        assert any("Wrong job class" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_rebirth_required(self):
        """Cover line 293-296: Rebirth requirement."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(rebirth_required=True)
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99, "is_rebirth": False}
        )
        
        assert can_enter == False
        assert any("Rebirth required" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_quest_not_completed(self):
        """Cover line 299-302: Required quest not completed."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(required_quest="biolabs_access")
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99, "completed_quests": []}
        )
        
        assert can_enter == False
        assert any("Quest required" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_missing_item(self):
        """Cover line 305-312: Required item missing."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(required_item="Ticket")
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99, "inventory": [{"name": "Potion"}]}
        )
        
        assert can_enter == False
        assert any("Item required" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_party_too_large(self):
        """Cover line 321-324: Party exceeds maximum size."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.PARTY_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(
                min_party_size=1,
                max_party_size=4
            )
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99, "party_size": 8}
        )
        
        assert can_enter == False
        assert any("too large" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_check_requirements_guild_required(self):
        """Cover line 327-330: Guild requirement."""
        registry = InstanceRegistry()
        
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=RegInstanceType.GUILD_DUNGEON,
            difficulty=InstanceDifficulty.NORMAL,
            requirements=InstanceRequirement(guild_required=True)
        )
        registry.instances["test"] = instance
        
        can_enter, missing = await registry.check_requirements(
            "test",
            {"base_level": 99}  # No guild_id
        )
        
        assert can_enter == False
        assert any("Must be in a guild" in m for m in missing)
    
    @pytest.mark.asyncio
    async def test_get_recommended_high_level_nidhogg_boost(self):
        """Cover line 379-380: High-level nidhogg boost."""
        registry = InstanceRegistry()
        
        # Add nidhogg instance
        nidhogg = InstanceDefinition(
            instance_id="nidhogg",
            instance_name="Nidhoggur's Nest",
            instance_type=RegInstanceType.MEMORIAL_DUNGEON,
            difficulty=InstanceDifficulty.HARD,
            recommended_level=110
        )
        registry.instances["nidhogg"] = nidhogg
        
        # High-level character should get nidhogg recommended
        recommendations = await registry.get_recommended_instances(
            {"base_level": 115, "party_size": 1, "gear_score": 5000}
        )
        
        # Nidhogg should be in recommendations
        assert any(r.instance_id == "nidhogg" for r in recommendations)


# ============================================================================
# PARTY MANAGER TESTS - Targeting uncovered lines
# ============================================================================

class TestPartyManagerEdgeCases:
    """Test edge cases in party management."""
    
    def test_check_party_emergencies_no_party(self):
        """Cover line 111-112: Early return when no party."""
        manager = PartyManager()
        manager.party = None
        
        # Create mock game state
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.job_class = "Priest"
        game_state.character.sp = 100
        
        actions = manager._check_party_emergencies(game_state)
        
        assert actions == []
    
    def test_healer_duties_no_party(self):
        """Cover line 157-158: Early return when no party."""
        manager = PartyManager()
        manager.party = None
        
        game_state = Mock()
        actions = manager._healer_duties(game_state)
        
        assert actions == []
    
    def test_healer_duties_no_low_hp_members(self):
        """Cover line 164-181: No actions when all members healthy."""
        from ai_sidecar.social.party_models import Party, PartyMember, PartySettings
        
        manager = PartyManager()
        
        # Create party with healthy members
        members = [
            PartyMember(
                char_id=1,
                name="Alice",
                base_level=99,
                job_class="Priest",
                hp=1000,
                hp_max=1000,  # 100% HP
                sp=500,
                sp_max=500
            )
        ]
        
        party = Party(
            party_id=1,
            name="Test Party",
            leader_id=1,
            members=members,
            settings=PartySettings()
        )
        manager.party = party
        
        game_state = Mock()
        actions = manager._healer_duties(game_state)
        
        # No heal needed
        assert len(actions) == 0
    
    def test_support_duties_no_party(self):
        """Cover line 205-206: Early return when no party."""
        manager = PartyManager()
        manager.party = None
        
        game_state = Mock()
        actions = manager._support_duties(game_state)
        
        assert actions == []
    
    def test_support_duties_low_sp_no_debuff(self):
        """Cover line 229: Skip debuff when low SP."""
        from ai_sidecar.social.party_models import Party, PartyMember, PartySettings
        
        manager = PartyManager()
        members = [PartyMember(
            char_id=1,
            name="Sage",
            base_level=99,
            job_class="Sage"
        )]
        party = Party(
            party_id=1,
            name="Test",
            leader_id=1,
            members=members,
            settings=PartySettings()
        )
        manager.party = party
        
        # Mock game state with low SP
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.sp = 15  # Low SP
        game_state.character.job_class = "Sage"
        game_state.get_monsters = Mock(return_value=[Mock(id=1)])
        
        actions = manager._support_duties(game_state)
        
        # Should not debuff due to low SP
        assert not any(a.priority == 5 for a in actions)
    
    def test_dps_duties_no_monsters(self):
        """Cover line 376-380: No actions when no monsters."""
        manager = PartyManager()
        
        game_state = Mock()
        game_state.get_monsters = Mock(return_value=[])
        
        actions = manager._dps_duties(game_state)
        
        assert len(actions) == 0
    
    def test_maintain_coordination_no_party(self):
        """Cover line 388-389: Early return when no party."""
        manager = PartyManager()
        manager.party = None
        
        game_state = Mock()
        actions = manager._maintain_coordination(game_state)
        
        assert actions == []
    
    def test_maintain_coordination_free_mode(self):
        """Cover line 388-389: No coordination in free mode."""
        from ai_sidecar.social.party_models import Party, PartySettings
        
        manager = PartyManager()
        manager.coordination_mode = "free"
        manager.party = Party(
            party_id=1,
            name="Test",
            leader_id=1,
            members=[],
            settings=PartySettings()
        )
        
        game_state = Mock()
        actions = manager._maintain_coordination(game_state)
        
        assert actions == []
    
    def test_maintain_coordination_no_leader(self):
        """Cover line 392-399: No follow when no leader."""
        from ai_sidecar.social.party_models import Party, PartySettings
        
        manager = PartyManager()
        manager.coordination_mode = "follow"
        manager.party = Party(
            party_id=1,
            name="Test",
            leader_id=1,
            members=[],
            settings=PartySettings(follow_leader=True)
        )
        manager.my_char_id = 1  # We are the leader
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.position = Mock(x=100, y=100)
        
        actions = manager._maintain_coordination(game_state)
        
        # Leader doesn't follow self
        assert len(actions) == 0
    
    def test_set_role_no_char_id(self):
        """Cover line 710-712: Warning when no character ID set."""
        from ai_sidecar.social.party_models import Party, PartyMember, PartySettings, PartyRole
        
        manager = PartyManager()
        manager.party = Party(
            party_id=1,
            name="Test",
            leader_id=1,
            members=[PartyMember(char_id=1, name="Test", base_level=99, job_class="Knight")],
            settings=PartySettings()
        )
        manager.my_char_id = None  # No char ID set
        
        # Should log warning and return early
        manager.set_role(PartyRole.TANK)
        
        # No assertion needed - just verifying no crash
    
    @pytest.mark.asyncio
    async def test_set_role_member_not_found(self):
        """Cover line 724-725: Warning when member not found."""
        from ai_sidecar.social.party_models import Party, PartyMember, PartySettings, PartyRole
        
        manager = PartyManager()
        manager.party = Party(
            party_id=1,
            name="Test",
            leader_id=1,
            members=[PartyMember(char_id=1, name="Test", base_level=99, job_class="Knight")],
            settings=PartySettings()
        )
        manager.my_char_id = 999  # Not in party
        
        # Should log warning
        manager.set_role(PartyRole.TANK)
        
        # No assertion needed - just verifying no crash


# ============================================================================
# GUILD MANAGER TESTS - Targeting uncovered lines  
# ============================================================================

class TestGuildManagerEdgeCases:
    """Test edge cases in guild management."""
    
    @pytest.mark.asyncio
    async def test_tick_no_guild(self):
        """Cover line 38-39: Early return when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        game_state = Mock()
        actions = await manager.tick(game_state)
        
        assert actions == []
    
    def test_is_woe_time_no_guild(self):
        """Cover line 55-56: Return False when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        assert manager._is_woe_time() == False
    
    def test_is_woe_time_no_schedule(self):
        """Cover line 55-56: Return False when no WoE schedule."""
        from ai_sidecar.social.guild_models import Guild
        
        manager = GuildManager()
        manager.guild = Guild(
            guild_id=1,
            name="Test Guild",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[],
            woe_schedule=[],  # Empty schedule
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        assert manager._is_woe_time() == False
    
    def test_woe_strategy_no_guild(self):
        """Cover line 75-76: Early return when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        game_state = Mock()
        actions = manager._woe_strategy(game_state)
        
        assert actions == []
    
    def test_woe_attack_strategy_no_target_castle(self):
        """Cover line 115-122: Skip castle movement when no target."""
        manager = GuildManager()
        manager.woe_target_castle = None
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.position = Mock(x=100, y=100)
        
        actions = manager._woe_attack_strategy(game_state)
        
        # No movement action
        assert not any(a.type.value == "move_to" for a in actions if hasattr(a, 'type'))
    
    def test_woe_defense_strategy_no_rally_point(self):
        """Cover line 141-150: Skip positioning when no rally point."""
        manager = GuildManager()
        manager.rally_point = None
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.position = Mock(x=100, y=100)
        
        actions = manager._woe_defense_strategy(game_state)
        
        # Should not have movement action
        assert not any(a.type.value == "move_to" for a in actions if hasattr(a, 'type'))
    
    def test_woe_support_strategy_no_guild_members(self):
        """Cover line 170-193: Handle when no guild members nearby."""
        manager = GuildManager()
        manager.guild = Mock()
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.position = Mock(x=100, y=100)
        
        # Mock _get_guild_players to return empty
        with patch.object(manager, '_get_guild_players', return_value=[]):
            actions = manager._woe_support_strategy(game_state)
        
        # No follow action when no guild members
        assert not any(a.priority == 4 for a in actions)
    
    def test_get_enemy_players_no_guild(self):
        """Cover line 198-199: Return empty when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        game_state = Mock()
        game_state.actors = []
        
        result = manager._get_enemy_players(game_state)
        
        assert result == []
    
    def test_get_guild_players_no_guild(self):
        """Cover line 215-216: Return empty when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        game_state = Mock()
        game_state.actors = []
        
        result = manager._get_guild_players(game_state)
        
        assert result == []
    
    def test_request_guild_buff_no_skill(self):
        """Cover line 229-236: Return None when no guild skill."""
        manager = GuildManager()
        manager.guild = Mock()
        manager.guild.get_skill_level = Mock(return_value=0)
        
        game_state = Mock()
        result = manager._request_guild_buff(game_state)
        
        assert result is None
    
    def test_process_storage_requests_no_char_id(self):
        """Cover line 259-260: Early return when no char ID."""
        manager = GuildManager()
        manager.my_char_id = None
        manager.guild = Mock()
        manager.storage_requests = [{"item_id": 501, "amount": 10, "type": "deposit"}]
        
        game_state = Mock()
        actions = manager._process_storage_requests(game_state)
        
        assert actions == []
    
    def test_process_storage_requests_no_permission(self):
        """Cover line 262-265: Clear requests when no permission."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member without storage permission
        position = GuildPosition(
            position_id=0,
            name="Member",
            can_storage=False  # No storage permission
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="TestMember",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage_requests = [{"test": "data"}]
        
        game_state = Mock()
        actions = manager._process_storage_requests(game_state)
        
        # Requests should be cleared
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_requests_not_near_npc(self):
        """Cover line 268-277: Move to storage NPC when not near."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests = [{"item_id": 501, "amount": 10, "type": "deposit"}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=False):
            game_state = Mock()
            game_state.map = Mock()
            game_state.map.name = "prontera"
            
            actions = manager._process_storage_requests(game_state)
        
        # Should have movement action
        assert len(actions) > 0
    
    def test_process_storage_requests_wrong_map(self):
        """Cover line 272-276: Handle wrong map for storage."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage_npc_location = ("prontera", 150, 150)
        manager.storage_requests = [{"item_id": 501, "amount": 10, "type": "deposit"}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=False):
            game_state = Mock()
            game_state.map = Mock()
            game_state.map.name = "geffen"  # Wrong map
            
            actions = manager._process_storage_requests(game_state)
        
        # Should return empty (logged message about needing to travel)
        assert actions == []
    
    def test_process_storage_deposit_insufficient_items(self):
        """Cover line 291-306: Handle insufficient items for deposit."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage_requests = [{"item_id": 501, "amount": 100, "type": "deposit"}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=True):
            with patch.object(manager, '_get_inventory_item_count', return_value=5):
                game_state = Mock()
                
                actions = manager._process_storage_requests(game_state)
        
        # Request should be popped, but no deposit action
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_withdraw_no_storage(self):
        """Cover line 310-330: Handle withdraw when storage not loaded."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage = None  # No storage loaded
        manager.storage_requests = [{"item_id": 501, "amount": 10, "type": "withdraw"}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=True):
            game_state = Mock()
            
            actions = manager._process_storage_requests(game_state)
        
        # Request popped but no action
        assert len(manager.storage_requests) == 0
    
    def test_process_storage_withdraw_insufficient_storage(self):
        """Cover line 312-327: Handle insufficient items in storage."""
        from ai_sidecar.social.guild_models import Guild, GuildStorage, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        # Create storage with only 2 of the item
        manager.storage = GuildStorage(
            max_capacity=100,
            items=[{"item_id": 501, "amount": 2}]
        )
        manager.storage_requests = [{"item_id": 501, "amount": 10, "type": "withdraw"}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=True):
            game_state = Mock()
            
            actions = manager._process_storage_requests(game_state)
        
        # Request popped but no action
        assert len(manager.storage_requests) == 0
    
    def test_is_near_storage_npc_no_location(self):
        """Cover line 336-337: Return False when no location set."""
        manager = GuildManager()
        manager.storage_npc_location = None
        
        game_state = Mock()
        
        assert manager._is_near_storage_npc(game_state) == False
    
    def test_is_near_storage_npc_wrong_map(self):
        """Cover line 340-341: Return False on wrong map."""
        manager = GuildManager()
        manager.storage_npc_location = ("prontera", 150, 150)
        
        game_state = Mock()
        game_state.map = Mock()
        game_state.map.name = "geffen"
        
        assert manager._is_near_storage_npc(game_state) == False
    
    def test_is_near_storage_npc_nearby(self):
        """Cover line 343-345: Return True when near NPC."""
        manager = GuildManager()
        manager.storage_npc_location = ("prontera", 150, 150)
        
        game_state = Mock()
        game_state.map = Mock()
        game_state.map.name = "prontera"
        game_state.character = Mock()
        game_state.character.position = Mock(x=152, y=152)  # 2 cells away
        
        assert manager._is_near_storage_npc(game_state) == True
    
    def test_is_near_storage_npc_far(self):
        """Cover line 343-345: Return False when far from NPC."""
        manager = GuildManager()
        manager.storage_npc_location = ("prontera", 150, 150)
        
        game_state = Mock()
        game_state.map = Mock()
        game_state.map.name = "prontera"
        game_state.character = Mock()
        game_state.character.position = Mock(x=160, y=160)  # 10+ cells away
        
        assert manager._is_near_storage_npc(game_state) == False
    
    def test_donate_exp_invalid_amount(self):
        """Cover line 365-367: Reject invalid donation amounts."""
        from ai_sidecar.social.guild_models import Guild
        
        manager = GuildManager()
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        result = manager.donate_exp(-10)
        
        assert result is None
    
    def test_donate_exp_below_minimum(self):
        """Cover line 370-372: Enforce minimum donation."""
        from ai_sidecar.social.guild_models import Guild
        from ai_sidecar.social import config
        
        manager = GuildManager()
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        # Mock config to have min donation
        with patch.dict(config.WOE_SETTINGS, {"min_exp_donation": 5}):
            action = manager.donate_exp(2)  # Below minimum
        
        # Should adjust to minimum
        assert action.extra["amount"] >= 5
    
    def test_use_guild_storage_no_guild(self):
        """Cover line 400-402: Return empty when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        actions = manager.use_guild_storage([(501, 10)])
        
        assert actions == []
    
    def test_use_guild_storage_no_permission(self):
        """Cover line 404-406: Return empty when no permission."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member without storage permission
        position = GuildPosition(
            position_id=0,
            name="Member",
            can_storage=False  # No storage permission
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="TestMember",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        actions = manager.use_guild_storage([(501, 10)])
        
        assert actions == []
    
    def test_use_guild_storage_zero_amount(self):
        """Cover line 410-411: Skip zero-amount operations."""
        from ai_sidecar.social.guild_models import Guild, GuildMember, GuildPosition
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create member with storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test",
            master_id=1,
            master_name="Guild Master",
            level=1,
            max_members=50,
            member_count=1,
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        
        manager.use_guild_storage([(501, 0)])  # Zero amount
        
        # No requests should be queued
        assert len(manager.storage_requests) == 0
    
    def test_check_guild_skill_no_guild(self):
        """Cover line 426-428: Return 0 when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        level = manager.check_guild_skill("Emergency Call")
        
        assert level == 0
    
    def test_is_ally_no_guild(self):
        """Cover line 433-434: Return False when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        assert manager.is_ally(123) == False
    
    def test_is_enemy_no_guild(self):
        """Cover line 439-440: Return False when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        assert manager.is_enemy(123) == False
    
    def test_get_online_members_count_no_guild(self):
        """Cover line 445-446: Return 0 when no guild."""
        manager = GuildManager()
        manager.guild = None
        
        count = manager.get_online_members_count()
        
        assert count == 0


# ============================================================================
# QUEST MANAGER TESTS - Targeting uncovered lines
# ============================================================================

class TestQuestManagerEdgeCases:
    """Test edge cases in quest management."""
    
    @pytest.mark.asyncio
    async def test_update_quest_progress_empty_inventory(self):
        """Cover edge case with empty inventory attribute."""
        manager = QuestManager()
        
        # Mock game state with empty inventory
        game_state = Mock()
        game_state.inventory = []  # Empty list
        
        # Should not crash
        manager._update_quest_progress(game_state)
    
    @pytest.mark.asyncio
    async def test_update_quest_progress_no_active_quests(self):
        """Cover line 87-88: Early return when no active quests."""
        manager = QuestManager()
        
        game_state = Mock()
        game_state.inventory = []
        
        # Should return without error
        manager._update_quest_progress(game_state)
        
        assert len(manager.quest_log.active_quests) == 0
    
    def test_determine_quest_type_daily(self):
        """Cover line 351-352: Identify daily quest type."""
        from ai_sidecar.npc.quest_models import Quest
        
        manager = QuestManager()
        
        quest = Quest(
            quest_id=1,
            name="Daily Hunt",
            description="Hunt monsters daily",
            npc_id=1,
            npc_name="Quest Giver",
            is_daily=True
        )
        
        quest_type = manager._determine_quest_type(quest)
        
        assert quest_type == "daily"
    
    def test_determine_quest_type_repeatable(self):
        """Cover line 354-355: Identify repeatable quest type."""
        from ai_sidecar.npc.quest_models import Quest
        
        manager = QuestManager()
        
        quest = Quest(
            quest_id=1,
            name="Repeatable Quest",
            description="Do this repeatedly",
            npc_id=1,
            npc_name="Quest Giver",
            is_repeatable=True
        )
        
        quest_type = manager._determine_quest_type(quest)
        
        assert quest_type == "repeatable"
    
    def test_determine_quest_type_main_story(self):
        """Cover line 358-362: Identify main story quest."""
        from ai_sidecar.npc.quest_models import Quest
        
        manager = QuestManager()
        
        quest = Quest(
            quest_id=1,
            name="Main Story Chapter 1",
            description="The story begins",
            npc_id=1,
            npc_name="Story NPC"
        )
        
        quest_type = manager._determine_quest_type(quest)
        
        assert quest_type == "main_story"
    
    def test_determine_quest_type_collection(self):
        """Cover line 367-368: Identify collection quest."""
        from ai_sidecar.npc.quest_models import Quest
        
        manager = QuestManager()
        
        quest = Quest(
            quest_id=1,
            name="Gather Herbs",
            description="Collect 10 healing herbs",
            npc_id=1,
            npc_name="Herbalist"
        )
        
        quest_type = manager._determine_quest_type(quest)
        
        assert quest_type == "collection"
    
    def test_determine_quest_type_default_side_quest(self):
        """Cover line 371: Default to side quest."""
        from ai_sidecar.npc.quest_models import Quest
        
        manager = QuestManager()
        
        quest = Quest(
            quest_id=1,
            name="Random Task",
            description="Do something",
            npc_id=1,
            npc_name="Random NPC"
        )
        
        quest_type = manager._determine_quest_type(quest)
        
        assert quest_type == "side_quest"


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class TestBatch3Integration:
    """Integration tests for Batch 3 modules."""
    
    @pytest.mark.asyncio
    async def test_instance_full_lifecycle_with_party_wipe(self):
        """Test complete instance run ending in party wipe."""
        manager = InstanceStateManager()
        
        instance_def = InstanceDefinition(
            instance_id="test_dungeon",
            instance_name="Test Dungeon",
            instance_type=RegInstanceType.PARTY_INSTANCE,
            difficulty=InstanceDifficulty.NORMAL,
            time_limit_minutes=30,
            floors=5
        )
        
        # Start instance with party
        state = await manager.start_instance(
            instance_def,
            party_members=["Tank", "Healer", "DPS1", "DPS2"]
        )
        
        assert state.party_alive_count == 4
        
        # Simulate deaths
        await manager.record_death("Tank")
        await manager.record_death("Healer")
        await manager.record_death("DPS1")
        await manager.record_death("DPS2")
        
        # Check party wipe
        should_abort, reason = await manager.should_abort()
        
        assert should_abort == True
        assert "Party wiped" in reason
    
    @pytest.mark.asyncio
    async def test_guild_storage_complete_workflow(self):
        """Test complete guild storage workflow."""
        from ai_sidecar.social.guild_models import Guild, GuildStorage, GuildMember, GuildPosition
        from ai_sidecar.core.state import Position, InventoryItem
        
        manager = GuildManager()
        manager.my_char_id = 1
        
        # Create guild with member that has storage permission
        position = GuildPosition(
            position_id=0,
            name="Master",
            can_storage=True
        )
        member = GuildMember(
            account_id=1,
            char_id=1,
            name="GuildMaster",
            position=position
        )
        
        manager.guild = Guild(
            guild_id=1,
            name="Test Guild",
            level=5,
            max_members=50,
            member_count=10,
            master_id=1,
            master_name="GuildMaster",
            members=[member],
            woe_schedule=[],
            allied_guilds=[],
            enemy_guilds=[],
            guild_skills={}
        )
        manager.storage = GuildStorage(max_capacity=100)
        manager.storage_npc_location = ("prontera", 150, 150)
        
        # Queue storage operations (can_use_storage will check member permission)
        manager.use_guild_storage([(501, 10), (502, -5)])  # Deposit and withdraw
        
        assert len(manager.storage_requests) == 2
        
        # Process first request (near NPC)
        # Add items to storage for withdrawal
        manager.storage.items = [{"item_id": 502, "amount": 50}]
        
        with patch.object(manager, '_is_near_storage_npc', return_value=True):
            with patch.object(manager, '_get_inventory_item_count', return_value=15):
                game_state = Mock()
                game_state.map = Mock()
                game_state.map.name = "prontera"
                game_state.inventory = Mock()
                game_state.inventory.items = [
                    InventoryItem(index=0, item_id=501, amount=15)
                ]
                
                actions = await manager.tick(game_state)
        
        # Should have processed deposit
        assert len(manager.storage_requests) == 1  # One request consumed


# ============================================================================
# RUN SUMMARY
# ============================================================================

def test_batch3_summary():
    """
    Summary test to verify all Batch 3 imports work.
    
    This test ensures all modules in Batch 3 can be imported
    and basic instantiation works without errors.
    """
    # Instance modules
    assert InstanceStateManager is not None
    assert InstanceRegistry is not None
    
    # Social modules  
    assert PartyManager is not None
    assert GuildManager is not None
    
    # NPC modules
    assert QuestManager is not None
    
    # Verify instantiation
    state_mgr = InstanceStateManager()
    assert state_mgr.current_instance is None
    
    registry = InstanceRegistry()
    assert registry.get_instance_count() == 0
    
    party_mgr = PartyManager()
    assert party_mgr.party is None
    
    guild_mgr = GuildManager()
    assert guild_mgr.guild is None
    
    quest_mgr = QuestManager()
    assert quest_mgr.quest_db is not None