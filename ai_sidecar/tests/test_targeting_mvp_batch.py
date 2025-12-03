"""
Batch tests for high-impact modules: targeting.py + mvp_manager.py
Target: Push overall coverage from 69.94% to 75%+
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, AsyncMock, patch

# Targeting imports
from ai_sidecar.combat.targeting import (
    TargetingSystem,
    TargetPriorityType,
    TargetScore,
    TARGET_WEIGHTS,
    create_default_targeting_system,
)
from ai_sidecar.combat.models import MonsterActor, Element, MonsterRace
from ai_sidecar.core.state import CharacterState, Position

# MVP Manager imports
from ai_sidecar.social.mvp_manager import MVPManager
from ai_sidecar.social.mvp_models import MVPBoss, MVPSpawnRecord, MVPHuntingStrategy
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole
from ai_sidecar.core.state import GameState, MapState
from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.progression.lifecycle import LifecycleState


# ========== TARGETING SYSTEM TESTS ==========

class TestTargetingSystemInit:
    """Test TargetingSystem initialization"""
    
    def test_init_default(self):
        """Test default initialization"""
        system = TargetingSystem()
        
        assert len(system.quest_targets) == 0
        assert system._last_target_id is None
    
    def test_init_with_quest_targets(self):
        """Test initialization with quest targets"""
        targets = {1001, 1002, 1003}
        system = TargetingSystem(quest_targets=targets)
        
        assert system.quest_targets == targets
    
    def test_create_default_targeting_system(self):
        """Test factory function"""
        system = create_default_targeting_system()
        
        assert isinstance(system, TargetingSystem)


class TestSelectTarget:
    """Test target selection logic"""
    
    def test_select_target_no_monsters(self):
        """Test selection with no monsters"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        
        target = system.select_target(character, [])
        
        assert target is None
    
    def test_select_target_mvp_priority(self):
        """Test MVP gets highest priority"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        # Regular monster
        regular = MonsterActor(
            actor_id=1,
            mob_id=1001,
            name="Poring",
            level=10,
            hp=500,
            hp_max=500,
            position=Position(x=105, y=105),
            is_mvp=False,
            is_boss=False,
            is_aggressive=False,
            is_targeting_player=False,
            element=Element.NEUTRAL,
            race=MonsterRace.PLANT
        )
        
        # MVP monster (farther but MVP)
        mvp = MonsterActor(
            actor_id=2,
            mob_id=1511,
            name="Amon Ra",
            level=88,
            hp=1445000,
            hp_max=1445000,
            position=Position(x=150, y=150),  # Farther away
            is_mvp=True,
            is_boss=False,
            is_aggressive=True,
            is_targeting_player=False,
            element=Element.EARTH,
            race=MonsterRace.DEMI_HUMAN
        )
        
        target = system.select_target(character, [regular, mvp])
        
        # Should select MVP despite distance
        assert target.actor_id == mvp.actor_id
    
    def test_select_target_aggressive_priority(self):
        """Test aggressive monster targeting player gets priority"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        passive = MonsterActor(
            actor_id=1, mob_id=1001, name="Poring",
            level=10, hp=500, hp_max=500,
            position=Position(x=105, y=105),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        aggressive = MonsterActor(
            actor_id=2, mob_id=1002, name="Hunter Fly",
            level=15, hp=800, hp_max=800,
            position=Position(x=110, y=110),
            is_mvp=False, is_boss=False,
            is_aggressive=True, is_targeting_player=True,  # Targeting us!
            element=Element.WIND, race=MonsterRace.INSECT
        )
        
        target = system.select_target(character, [passive, aggressive])
        
        # Should select aggressive monster
        assert target.actor_id == aggressive.actor_id
    
    def test_select_target_quest_priority(self):
        """Test quest targets get priority"""
        system = TargetingSystem(quest_targets={1003})
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        regular = MonsterActor(
            actor_id=1, mob_id=1001, name="Regular",
            level=50, hp=1000, hp_max=1000,
            position=Position(x=105, y=105),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        quest_target = MonsterActor(
            actor_id=2, mob_id=1003, name="Quest Monster",
            level=50, hp=1000, hp_max=1000,
            position=Position(x=115, y=115),  # Farther
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        target = system.select_target(character, [regular, quest_target])
        
        # Should select quest target despite distance
        assert target.mob_id == 1003
    
    def test_select_target_low_hp_preference(self):
        """Test low HP targets preferred when enabled"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        full_hp = MonsterActor(
            actor_id=1, mob_id=1001, name="Full HP",
            level=50, hp=1000, hp_max=1000,  # 100% HP
            position=Position(x=105, y=105),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        low_hp = MonsterActor(
            actor_id=2, mob_id=1002, name="Low HP",
            level=50, hp=200, hp_max=1000,  # 20% HP
            position=Position(x=105, y=105),  # Same distance
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        target = system.select_target(character, [full_hp, low_hp], prefer_finish_low_hp=True)
        
        # Should prefer low HP target
        assert target.actor_id == low_hp.actor_id


class TestQuestTargetManagement:
    """Test quest target add/remove"""
    
    def test_add_quest_target(self):
        """Test adding quest target"""
        system = TargetingSystem()
        
        system.add_quest_target(1001)
        
        assert 1001 in system.quest_targets
    
    def test_remove_quest_target(self):
        """Test removing quest target"""
        system = TargetingSystem(quest_targets={1001, 1002})
        
        system.remove_quest_target(1001)
        
        assert 1001 not in system.quest_targets
        assert 1002 in system.quest_targets
    
    def test_clear_quest_targets(self):
        """Test clearing all quest targets"""
        system = TargetingSystem(quest_targets={1001, 1002, 1003})
        
        system.clear_quest_targets()
        
        assert len(system.quest_targets) == 0


class TestShouldSwitchTarget:
    """Test target switching logic"""
    
    def test_should_switch_target_dead(self):
        """Test switching when current target dead"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        current = MonsterActor(
            actor_id=1, mob_id=1001, name="Dead",
            level=50, hp=0, hp_max=1000,
            position=Position(x=105, y=105),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        # Current not in nearby list (dead/out of range)
        should_switch = system.should_switch_target(current, [], character)
        
        assert should_switch is True
    
    def test_should_switch_for_mvp(self):
        """Test switching when MVP appears"""
        system = TargetingSystem()
        character = Mock(spec=CharacterState)
        character.level = 50
        character.position = Position(x=100, y=100)
        
        current = MonsterActor(
            actor_id=1, mob_id=1001, name="Regular",
            level=50, hp=1000, hp_max=1000,
            position=Position(x=105, y=105),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        mvp = MonsterActor(
            actor_id=2, mob_id=1511, name="MVP",
            level=88, hp=1000000, hp_max=1000000,
            position=Position(x=110, y=110),
            is_mvp=True, is_boss=False,
            is_aggressive=True, is_targeting_player=False,
            element=Element.EARTH, race=MonsterRace.DEMI_HUMAN
        )
        
        should_switch = system.should_switch_target(
            current,
            [current, mvp],
            character
        )
        
        # Should switch to MVP
        assert should_switch is True


class TestGetPrioritySummary:
    """Test priority summary for debugging"""
    
    def test_get_priority_summary(self):
        """Test getting priority summary"""
        system = TargetingSystem(quest_targets={1001, 1002})
        character = Mock(spec=CharacterState)
        
        summary = system.get_priority_summary(character)
        
        assert summary["quest_targets"] == 2
        assert summary["mvp_weight"] == 1000.0
        assert "optimal_level_range" in summary


# ========== MVP MANAGER TESTS ==========

class TestMVPManagerInit:
    """Test MVPManager initialization"""
    
    def test_init_creates_components(self):
        """Test initialization creates all components"""
        manager = MVPManager()
        
        assert manager.mvp_db is not None
        assert manager.tracker is not None
        assert manager.active_hunt is None
        assert manager.current_map == ""


class TestMVPTick:
    """Test MVP manager tick method"""
    
    @pytest.mark.asyncio
    async def test_tick_updates_map(self):
        """Test tick updates current map"""
        manager = MVPManager()
        
        game_state = Mock(spec=GameState)
        game_state.map = Mock(spec=MapState)
        game_state.map.name = "moc_pryd06"
        game_state.actors = []
        
        actions = await manager.tick(game_state)
        
        assert manager.current_map == "moc_pryd06"
    
    @pytest.mark.asyncio
    async def test_tick_no_active_hunt(self):
        """Test tick with no active hunt"""
        manager = MVPManager()
        
        game_state = Mock(spec=GameState)
        game_state.map = Mock(spec=MapState)
        game_state.map.name = "prontera"
        game_state.actors = []
        
        actions = await manager.tick(game_state)
        
        assert len(actions) == 0


class TestRecordMVPDeath:
    """Test MVP death recording"""
    
    def test_record_mvp_death(self):
        """Test recording MVP death creates spawn record"""
        manager = MVPManager()
        
        # Add MVP to database
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"]
        )
        manager.mvp_db.add(mvp)
        
        manager.record_mvp_death(
            monster_id=1511,
            map_name="moc_pryd06",
            killer="TestPlayer"
        )
        
        # Should create spawn record
        assert 1511 in manager.tracker.records
        assert len(manager.tracker.records[1511]) > 0
    
    def test_record_mvp_death_ends_active_hunt(self):
        """Test recording death ends active hunt if hunting that MVP"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"]
        )
        manager.mvp_db.add(mvp)
        
        # Set active hunt
        manager.active_hunt = MVPHuntingStrategy(
            target_mvp=mvp,
            party_composition={},
            approach_strategy="camp"
        )
        
        manager.record_mvp_death(1511, "moc_pryd06")
        
        # Active hunt should be cleared
        assert manager.active_hunt is None


class TestRecordMVPLocation:
    """Test MVP location recording"""
    
    def test_record_mvp_location(self):
        """Test recording MVP spawn location"""
        manager = MVPManager()
        
        manager.record_mvp_location(
            monster_id=1511,
            map_name="moc_pryd06",
            x=102,
            y=90
        )
        
        # Should be added to tracker
        assert 1511 in manager.tracker.known_locations


class TestGetSpawnWindow:
    """Test spawn window retrieval"""
    
    def test_get_spawn_window(self):
        """Test getting spawn window"""
        manager = MVPManager()
        
        # Add MVP and record death
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"]
        )
        manager.mvp_db.add(mvp)
        manager.record_mvp_death(1511, "moc_pryd06")
        
        window = manager.get_spawn_window(1511)
        
        assert window is not None
        earliest, latest = window
        assert earliest < latest


class TestStartHunt:
    """Test starting MVP hunt"""
    
    def test_start_hunt_solo(self):
        """Test starting solo MVP hunt"""
        manager = MVPManager()
        
        # Add MVP
        mvp = MVPBoss(
            monster_id=1002,
            name="Ghostring",
            base_level=86,
            hp=1218000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["gl_cas01"],
            danger_rating=3
        )
        manager.mvp_db.add(mvp)
        
        actions = manager.start_hunt(target_id=1002, party=None)
        
        assert manager.active_hunt is not None
        assert manager.active_hunt.target_mvp.monster_id == 1002
        assert manager.active_hunt.approach_strategy == "check_rotation"
    
    def test_start_hunt_with_party(self):
        """Test starting party MVP hunt"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"],
            danger_rating=8
        )
        manager.mvp_db.add(mvp)
        
        party = Party(
            party_id=1,
            name="Test Party",
            party_name="Test Party",
            leader_name="Leader",
            leader_id=1,
            members=[
                PartyMember(
                    name="Tank",
                    char_id=1,
                    account_id=101,
                    job_class="Lord Knight",
                    assigned_role=PartyRole.TANK,
                    base_level=99,
                    job_level=70
                ),
                PartyMember(
                    name="Healer",
                    char_id=2,
                    account_id=102,
                    job_class="High Priest",
                    assigned_role=PartyRole.HEALER,
                    base_level=99,
                    job_level=70
                ),
                PartyMember(
                    name="DPS",
                    char_id=3,
                    account_id=103,
                    job_class="Assassin Cross",
                    assigned_role=PartyRole.DPS_MELEE,
                    base_level=99,
                    job_level=70
                )
            ]
        )
        
        actions = manager.start_hunt(target_id=1511, party=party)
        
        assert manager.active_hunt is not None
        assert manager.active_hunt.approach_strategy == "camp"
    
    def test_start_hunt_unknown_mvp(self):
        """Test starting hunt for unknown MVP"""
        manager = MVPManager()
        
        actions = manager.start_hunt(target_id=9999, party=None)
        
        assert len(actions) == 0
        assert manager.active_hunt is None


class TestStopHunt:
    """Test stopping MVP hunt"""
    
    def test_stop_hunt(self):
        """Test stopping active hunt"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1002,
            name="Ghostring",
            base_level=86,
            hp=1218000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["gl_cas01"],
            danger_rating=3
        )
        manager.mvp_db.add(mvp)
        manager.start_hunt(target_id=1002)
        
        manager.stop_hunt()
        
        assert manager.active_hunt is None


class TestCalculatePartyNeeds:
    """Test party composition calculation"""
    
    def test_party_needs_high_danger(self):
        """Test party composition for high danger MVP"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"],
            danger_rating=9  # High danger
        )
        
        composition = manager._calculate_party_needs(mvp)
        
        # High danger needs full party
        assert PartyRole.TANK in composition
        assert PartyRole.HEALER in composition
        assert PartyRole.DPS_MELEE in composition
        assert PartyRole.DPS_RANGED in composition
    
    def test_party_needs_medium_danger(self):
        """Test party composition for medium danger MVP"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1312,
            name="Turtle General",
            base_level=97,
            hp=1442000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["tur_dun04"],
            danger_rating=5  # Medium danger
        )
        
        composition = manager._calculate_party_needs(mvp)
        
        # Medium danger needs healer + DPS
        assert PartyRole.HEALER in composition
        assert PartyRole.DPS_MELEE in composition
    
    def test_party_needs_low_danger(self):
        """Test party composition for low danger MVP"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1002,
            name="Ghostring",
            base_level=86,
            hp=1218000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["gl_cas01"],
            danger_rating=2  # Low danger
        )
        
        composition = manager._calculate_party_needs(mvp)
        
        # Low danger can solo
        assert PartyRole.DPS_MELEE in composition
        assert PartyRole.TANK not in composition


class TestCountPartyRoles:
    """Test party role counting"""
    
    def test_count_party_roles(self):
        """Test counting roles in party"""
        manager = MVPManager()
        
        party = Party(
            party_id=1,
            name="Test",
            party_name="Test",
            leader_name="Leader",
            leader_id=1,
            members=[
                PartyMember(
                    name="Tank1", char_id=1,
                    account_id=201,
                    job_class="Paladin",
                    assigned_role=PartyRole.TANK,
                    base_level=99, job_level=70
                ),
                PartyMember(
                    name="Tank2", char_id=2,
                    account_id=202,
                    job_class="Lord Knight",
                    assigned_role=PartyRole.TANK,
                    base_level=99, job_level=70
                ),
                PartyMember(
                    name="Healer", char_id=3,
                    account_id=203,
                    job_class="High Priest",
                    assigned_role=PartyRole.HEALER,
                    base_level=99, job_level=70
                )
            ]
        )
        
        counts = manager._count_party_roles(party)
        
        assert counts[PartyRole.TANK] == 2
        assert counts[PartyRole.HEALER] == 1


class TestUpdateSpawnTimers:
    """Test spawn timer updates"""
    
    def test_update_spawn_timers_removes_expired(self):
        """Test that expired spawn records are removed"""
        manager = MVPManager()
        
        # Add expired record
        expired_record = MVPSpawnRecord(
            monster_id=1511,
            map_name="moc_pryd06",
            killed_at=datetime.now() - timedelta(hours=3),
            next_spawn_earliest=datetime.now() - timedelta(hours=2),
            next_spawn_latest=datetime.now() - timedelta(hours=1),  # Expired
            confirmed=True
        )
        
        manager.tracker.records[1511] = [expired_record]
        
        manager._update_spawn_timers()
        
        # Expired records should be removed
        assert 1511 not in manager.tracker.records


class TestRotationManagement:
    """Test location rotation logic"""
    
    def test_set_rotation_interval(self):
        """Test setting rotation interval"""
        manager = MVPManager()
        
        manager.set_rotation_interval(60)
        
        assert manager.rotation_interval_seconds == 60
    
    def test_set_rotation_interval_min_limit(self):
        """Test rotation interval has minimum"""
        manager = MVPManager()
        
        manager.set_rotation_interval(5)  # Try to set too low
        
        assert manager.rotation_interval_seconds >= 10  # Minimum 10s
    
    def test_reset_rotation(self):
        """Test resetting rotation"""
        manager = MVPManager()
        
        manager.rotation_index = 5
        manager.last_rotation_time = datetime.now()
        
        manager.reset_rotation()
        
        assert manager.rotation_index == 0
        assert manager.last_rotation_time is None


class TestLoadMVPDatabase:
    """Test MVP database loading"""
    
    def test_load_mvp_database(self):
        """Test loading MVP data"""
        manager = MVPManager()
        
        data = {
            "1511": {
                "monster_id": 1511,
                "name": "Amon Ra",
                "base_level": 88,
                "hp": 1445000,
                "spawn_time_min": 60,
                "spawn_time_max": 120,
                "spawn_maps": ["moc_pryd06"],
                "danger_rating": 8,
                "card_id": 4236
            }
        }
        
        manager.load_mvp_database(data)
        
        mvp = manager.mvp_db.get(1511)
        assert mvp is not None
        assert mvp.name == "Amon Ra"


class TestExecuteHuntStrategy:
    """Test hunt strategy execution"""
    
    @pytest.mark.asyncio
    async def test_execute_hunt_wrong_map(self):
        """Test hunt execution when on wrong map"""
        manager = MVPManager()
        
        mvp = MVPBoss(
            monster_id=1511,
            name="Amon Ra",
            base_level=88,
            hp=1445000,
            spawn_time_min=60,
            spawn_time_max=120,
            spawn_maps=["moc_pryd06"],
            danger_rating=8
        )
        manager.mvp_db.add(mvp)
        
        manager.active_hunt = MVPHuntingStrategy(
            target_mvp=mvp,
            party_composition={},
            approach_strategy="camp"
        )
        manager.current_map = "prontera"  # Wrong map
        
        game_state = Mock(spec=GameState)
        game_state.map = Mock(spec=MapState)
        game_state.map.name = "prontera"
        game_state.actors = []
        
        actions = manager._execute_hunt_strategy(game_state)
        
        # Should return empty (need to warp)
        assert len(actions) == 0


class TestTargetScoreModel:
    """Test TargetScore dataclass"""
    
    def test_target_score_creation(self):
        """Test creating TargetScore"""
        monster = MonsterActor(
            actor_id=1, mob_id=1001, name="Poring",
            level=10, hp=500, hp_max=500,
            position=Position(x=100, y=100),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        score = TargetScore(
            monster=monster,
            total_score=150.5,
            priority_reasons=[(TargetPriorityType.NEARBY, 50.0)],
            distance=5.0
        )
        
        assert score.total_score == 150.5
        assert score.distance == 5.0
    
    def test_get_reason_summary(self):
        """Test getting reason summary"""
        monster = MonsterActor(
            actor_id=1, mob_id=1001, name="Poring",
            level=10, hp=500, hp_max=500,
            position=Position(x=100, y=100),
            is_mvp=False, is_boss=False,
            is_aggressive=False, is_targeting_player=False,
            element=Element.NEUTRAL, race=MonsterRace.PLANT
        )
        
        score = TargetScore(
            monster=monster,
            total_score=250.0,
            priority_reasons=[
                (TargetPriorityType.QUEST_TARGET, 150.0),
                (TargetPriorityType.NEARBY, 50.0),
            ],
            distance=5.0
        )
        
        summary = score.get_reason_summary()
        
        assert "quest_target" in summary
        assert "150" in summary