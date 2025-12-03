"""
Comprehensive tests for mvp_manager.py - covering all uncovered lines.
Target: 100% coverage of MVP tracking, spawn timers, hunting, and coordination.
"""

import pytest
from datetime import datetime, timedelta
from unittest.mock import Mock, patch, AsyncMock

from ai_sidecar.core.decision import Action, ActionType
from ai_sidecar.social.mvp_manager import MVPManager
from ai_sidecar.social.mvp_models import MVPBoss, MVPSpawnRecord, MVPHuntingStrategy
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole


@pytest.fixture
def mvp_manager():
    """Create MVPManager instance."""
    return MVPManager()


@pytest.fixture
def mock_game_state():
    """Create mock game state."""
    state = Mock()
    state.map = Mock()
    state.map.name = "prontera"
    state.character = Mock()
    state.character.position = Mock(x=100, y=100)
    state.actors = []
    return state


@pytest.fixture
def sample_mvp():
    """Create sample MVP."""
    return MVPBoss(
        monster_id=1001,
        name="Baphomet",
        base_level=99,
        hp=668000,
        spawn_maps=["prt_maze03"],
        spawn_time_min=120,
        spawn_time_max=130,
        danger_rating=8,
        card_id=4001,
    )


@pytest.fixture
def sample_party():
    """Create sample party."""
    return Party(
        party_id=1,
        name="Test Party",
        leader_id=1,
        members=[
            PartyMember(
                account_id=1,
                char_id=1,
                name="Tank",
                job_class="Knight",
                base_level=99,
                assigned_role=PartyRole.TANK,
            ),
            PartyMember(
                account_id=2,
                char_id=2,
                name="Healer",
                job_class="Priest",
                base_level=99,
                assigned_role=PartyRole.HEALER,
            ),
            PartyMember(
                account_id=3,
                char_id=3,
                name="DPS",
                job_class="Assassin",
                base_level=99,
                assigned_role=PartyRole.DPS_MELEE,
            ),
        ],
    )


class TestMVPManagerInit:
    """Test MVPManager initialization."""

    def test_init(self, mvp_manager):
        """Test initialization."""
        assert mvp_manager.mvp_db is not None
        assert mvp_manager.tracker is not None
        assert mvp_manager.active_hunt is None
        assert mvp_manager.rotation_index == 0


class TestMVPTick:
    """Test MVP tick functionality."""

    @pytest.mark.asyncio
    async def test_tick_basic(self, mvp_manager, mock_game_state):
        """Test basic tick."""
        actions = await mvp_manager.tick(mock_game_state)
        assert isinstance(actions, list)
        assert mvp_manager.current_map == "prontera"

    @pytest.mark.asyncio
    async def test_tick_with_upcoming_spawns(self, mvp_manager, mock_game_state, sample_mvp):
        """Test tick with upcoming spawns."""
        # Add spawn record
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=sample_mvp.monster_id,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=110),
            next_spawn_earliest=now + timedelta(minutes=5),
            next_spawn_latest=now + timedelta(minutes=15),
            confirmed=True,
        )
        mvp_manager.tracker.add_record(record)
        
        actions = await mvp_manager.tick(mock_game_state)
        assert isinstance(actions, list)

    @pytest.mark.asyncio
    async def test_tick_with_active_hunt(self, mvp_manager, mock_game_state, sample_mvp):
        """Test tick with active hunt."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        
        actions = await mvp_manager.tick(mock_game_state)
        assert isinstance(actions, list)


class TestSpawnTimerManagement:
    """Test spawn timer updates."""

    def test_update_spawn_timers(self, mvp_manager):
        """Test updating spawn timers."""
        # Add expired record
        old_record = MVPSpawnRecord(
            monster_id=1001,
            map_name="test_map",
            killed_at=datetime.now() - timedelta(days=1),
            next_spawn_earliest=datetime.now() - timedelta(hours=12),
            next_spawn_latest=datetime.now() - timedelta(hours=11),
        )
        mvp_manager.tracker.records[1001] = [old_record]
        
        mvp_manager._update_spawn_timers()
        
        # Expired records should be removed
        assert 1001 not in mvp_manager.tracker.records

    def test_update_spawn_timers_valid_records(self, mvp_manager):
        """Test updating with valid records."""
        now = datetime.now()
        valid_record = MVPSpawnRecord(
            monster_id=1001,
            map_name="test_map",
            killed_at=now - timedelta(minutes=30),
            next_spawn_earliest=now + timedelta(minutes=90),
            next_spawn_latest=now + timedelta(minutes=100),
        )
        mvp_manager.tracker.records[1001] = [valid_record]
        
        mvp_manager._update_spawn_timers()
        
        # Valid records should remain
        assert 1001 in mvp_manager.tracker.records

    def test_get_upcoming_spawns(self, mvp_manager, sample_mvp):
        """Test getting upcoming spawns."""
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=sample_mvp.monster_id,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=110),
            next_spawn_earliest=now + timedelta(minutes=5),
            next_spawn_latest=now + timedelta(minutes=15),
        )
        mvp_manager.tracker.add_record(record)
        
        upcoming = mvp_manager._get_upcoming_spawns(minutes=30)
        assert len(upcoming) > 0


class TestHuntExecution:
    """Test hunt strategy execution."""

    def test_execute_hunt_strategy_no_hunt(self, mvp_manager, mock_game_state):
        """Test execute with no active hunt."""
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        assert len(actions) == 0

    def test_execute_hunt_strategy_wrong_map(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt on wrong map."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prontera"  # Wrong map
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        assert len(actions) == 0

    def test_execute_hunt_strategy_too_early(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt before spawn window."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        
        # Add spawn record with future window
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=sample_mvp.monster_id,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=30),
            next_spawn_earliest=now + timedelta(minutes=30),
            next_spawn_latest=now + timedelta(minutes=40),
        )
        mvp_manager.tracker.add_record(record)
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        assert len(actions) == 0

    def test_execute_hunt_strategy_expired_window(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt after spawn window expired."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        
        # Add expired spawn record
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=sample_mvp.monster_id,
            map_name="prt_maze03",
            killed_at=now - timedelta(hours=5),
            next_spawn_earliest=now - timedelta(minutes=30),
            next_spawn_latest=now - timedelta(minutes=20),
        )
        mvp_manager.tracker.add_record(record)
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        assert mvp_manager.active_hunt is None

    def test_execute_hunt_strategy_camp_mode(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt with camp strategy."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        mvp_manager.tracker.known_locations[sample_mvp.monster_id] = [
            ("prt_maze03", 150, 150)
        ]
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        # Should try to move to spawn point
        assert len(actions) > 0

    def test_execute_hunt_strategy_rotation_mode(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt with rotation strategy."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="check_rotation",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        assert isinstance(actions, list)

    def test_execute_hunt_strategy_mvp_found(self, mvp_manager, mock_game_state, sample_mvp):
        """Test hunt when MVP is visible."""
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        mvp_manager.current_map = "prt_maze03"
        
        # Add MVP to actors
        mvp_actor = Mock()
        mvp_actor.mob_id = sample_mvp.monster_id
        mvp_actor.id = 2000
        mock_game_state.actors = [mvp_actor]
        
        actions = mvp_manager._execute_hunt_strategy(mock_game_state)
        # Should attack MVP
        assert any(action.type == ActionType.ATTACK for action in actions)


class TestMVPRecording:
    """Test MVP death and location recording."""

    def test_record_mvp_death(self, mvp_manager, sample_mvp):
        """Test recording MVP death."""
        mvp_manager.mvp_db.add(sample_mvp)
        
        mvp_manager.record_mvp_death(sample_mvp.monster_id, "prt_maze03", "Player")
        
        assert sample_mvp.monster_id in mvp_manager.tracker.records

    def test_record_mvp_death_unknown(self, mvp_manager):
        """Test recording unknown MVP death."""
        mvp_manager.record_mvp_death(9999, "test_map")
        # Should handle gracefully

    def test_record_mvp_death_clears_active_hunt(self, mvp_manager, sample_mvp):
        """Test death recording clears active hunt."""
        mvp_manager.mvp_db.add(sample_mvp)
        strategy = MVPHuntingStrategy(
            target_mvp=sample_mvp,
            party_composition={},
            approach_strategy="camp",
        )
        mvp_manager.active_hunt = strategy
        
        mvp_manager.record_mvp_death(sample_mvp.monster_id, "prt_maze03")
        
        assert mvp_manager.active_hunt is None

    def test_record_mvp_location(self, mvp_manager):
        """Test recording MVP location."""
        mvp_manager.record_mvp_location(1001, "test_map", 100, 100)
        assert 1001 in mvp_manager.tracker.known_locations

    def test_get_spawn_window(self, mvp_manager, sample_mvp):
        """Test getting spawn window."""
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=sample_mvp.monster_id,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=100),
            next_spawn_earliest=now + timedelta(minutes=20),
            next_spawn_latest=now + timedelta(minutes=30),
        )
        mvp_manager.tracker.add_record(record)
        
        window = mvp_manager.get_spawn_window(sample_mvp.monster_id)
        assert window is not None


class TestHuntManagement:
    """Test hunt start/stop."""

    def test_start_hunt(self, mvp_manager, sample_mvp):
        """Test starting MVP hunt."""
        mvp_manager.mvp_db.add(sample_mvp)
        
        actions = mvp_manager.start_hunt(sample_mvp.monster_id)
        assert mvp_manager.active_hunt is not None
        assert isinstance(actions, list)

    def test_start_hunt_with_party(self, mvp_manager, sample_mvp, sample_party):
        """Test starting hunt with party."""
        mvp_manager.mvp_db.add(sample_mvp)
        
        actions = mvp_manager.start_hunt(sample_mvp.monster_id, party=sample_party)
        assert mvp_manager.active_hunt is not None

    def test_start_hunt_unknown_mvp(self, mvp_manager):
        """Test starting hunt for unknown MVP."""
        actions = mvp_manager.start_hunt(9999)
        assert len(actions) == 0
        assert mvp_manager.active_hunt is None

    def test_stop_hunt(self, mvp_manager, sample_mvp):
        """Test stopping hunt."""
        mvp_manager.mvp_db.add(sample_mvp)
        mvp_manager.start_hunt(sample_mvp.monster_id)
        
        mvp_manager.stop_hunt()
        assert mvp_manager.active_hunt is None

    def test_stop_hunt_no_active(self, mvp_manager):
        """Test stopping when no active hunt."""
        mvp_manager.stop_hunt()
        # Should not raise error


class TestPartyComposition:
    """Test party composition calculations."""

    def test_calculate_party_needs_high_danger(self, mvp_manager):
        """Test party needs for high danger MVP."""
        mvp = MVPBoss(
            monster_id=1001,
            base_level=99,
            hp=500000,
            name="Dangerous MVP",
            spawn_maps=["map"],
            spawn_time_min=120,
            spawn_time_max=130,
            danger_rating=8,
        )
        
        composition = mvp_manager._calculate_party_needs(mvp)
        assert PartyRole.TANK in composition
        assert PartyRole.HEALER in composition
        assert PartyRole.DPS_MELEE in composition

    def test_calculate_party_needs_medium_danger(self, mvp_manager):
        """Test party needs for medium danger MVP."""
        mvp = MVPBoss(
            monster_id=1002,
            name="Medium MVP",
            base_level=85,
            hp=300000,
            spawn_maps=["map"],
            spawn_time_min=60,
            spawn_time_max=70,
            danger_rating=5,
        )
        
        composition = mvp_manager._calculate_party_needs(mvp)
        assert PartyRole.HEALER in composition
        assert PartyRole.DPS_MELEE in composition

    def test_calculate_party_needs_low_danger(self, mvp_manager):
        """Test party needs for low danger MVP."""
        mvp = MVPBoss(
            monster_id=1003,
            name="Easy MVP",
            base_level=50,
            hp=100000,
            spawn_maps=["map"],
            spawn_time_min=30,
            spawn_time_max=40,
            danger_rating=2,
        )
        
        composition = mvp_manager._calculate_party_needs(mvp)
        assert PartyRole.DPS_MELEE in composition

    def test_count_party_roles(self, mvp_manager, sample_party):
        """Test counting party roles."""
        role_counts = mvp_manager._count_party_roles(sample_party)
        assert role_counts[PartyRole.TANK] == 1
        assert role_counts[PartyRole.HEALER] == 1
        assert role_counts[PartyRole.DPS_MELEE] == 1


class TestLocationRotation:
    """Test location rotation logic."""

    def test_execute_location_rotation_no_locations(self, mvp_manager, mock_game_state):
        """Test rotation with no known locations."""
        actions = mvp_manager._execute_location_rotation(9999, mock_game_state)
        assert isinstance(actions, list)

    def test_execute_location_rotation_from_database(self, mvp_manager, mock_game_state, sample_mvp):
        """Test rotation using database spawn maps."""
        mvp_manager.mvp_db.add(sample_mvp)
        
        actions = mvp_manager._execute_location_rotation(sample_mvp.monster_id, mock_game_state)
        assert isinstance(actions, list)

    def test_execute_location_rotation_known_locations(self, mvp_manager, mock_game_state):
        """Test rotation with known locations."""
        mvp_manager.tracker.known_locations[1001] = [
            ("prontera", 150, 150),
            ("prontera", 200, 200),
        ]
        mvp_manager.current_map = "prontera"
        
        actions = mvp_manager._execute_location_rotation(1001, mock_game_state)
        assert isinstance(actions, list)

    def test_execute_location_rotation_wrong_map(self, mvp_manager, mock_game_state):
        """Test rotation on wrong map."""
        mvp_manager.tracker.known_locations[1001] = [
            ("different_map", 150, 150),
        ]
        mvp_manager.current_map = "prontera"
        
        actions = mvp_manager._execute_location_rotation(1001, mock_game_state)
        # Should create warp action
        assert len(actions) > 0

    def test_execute_location_rotation_far_from_point(self, mvp_manager, mock_game_state):
        """Test rotation when far from target."""
        mvp_manager.tracker.known_locations[1001] = [
            ("prontera", 200, 200),
        ]
        mvp_manager.current_map = "prontera"
        mock_game_state.character.position = Mock(x=100, y=100)
        
        actions = mvp_manager._execute_location_rotation(1001, mock_game_state)
        # Should move to location
        assert any(action.type == ActionType.MOVE for action in actions)

    def test_execute_location_rotation_cycles(self, mvp_manager, mock_game_state):
        """Test rotation cycles through locations."""
        mvp_manager.tracker.known_locations[1001] = [
            ("prontera", 100, 100),
            ("prontera", 200, 200),
            ("prontera", 300, 300),
        ]
        mvp_manager.current_map = "prontera"
        mvp_manager.rotation_index = 0
        mvp_manager.last_rotation_time = datetime.now() - timedelta(seconds=60)
        
        # Execute rotation
        actions = mvp_manager._execute_location_rotation(1001, mock_game_state)
        
        # Index should advance
        assert mvp_manager.rotation_index > 0


class TestRotationControl:
    """Test rotation control methods."""

    def test_set_rotation_interval(self, mvp_manager):
        """Test setting rotation interval."""
        mvp_manager.set_rotation_interval(60)
        assert mvp_manager.rotation_interval_seconds == 60

    def test_set_rotation_interval_minimum(self, mvp_manager):
        """Test minimum rotation interval."""
        mvp_manager.set_rotation_interval(5)
        assert mvp_manager.rotation_interval_seconds == 10  # Minimum

    def test_reset_rotation(self, mvp_manager):
        """Test resetting rotation."""
        mvp_manager.rotation_index = 5
        mvp_manager.last_rotation_time = datetime.now()
        
        mvp_manager.reset_rotation()
        
        assert mvp_manager.rotation_index == 0
        assert mvp_manager.last_rotation_time is None


class TestHuntInitiation:
    """Test hunt initiation."""

    def test_initiate_hunt(self, mvp_manager, sample_mvp):
        """Test initiating hunt."""
        mvp_manager.current_map = "prontera"
        actions = mvp_manager._initiate_hunt(sample_mvp)
        
        # Should queue warp action
        assert len(actions) > 0

    def test_initiate_hunt_already_on_map(self, mvp_manager, sample_mvp):
        """Test initiating hunt when already on map."""
        mvp_manager.current_map = "prt_maze03"
        actions = mvp_manager._initiate_hunt(sample_mvp)
        
        # May have fewer actions
        assert isinstance(actions, list)

    def test_initiate_hunt_resets_rotation(self, mvp_manager, sample_mvp):
        """Test hunt initiation resets rotation."""
        mvp_manager.rotation_index = 5
        mvp_manager._initiate_hunt(sample_mvp)
        
        assert mvp_manager.rotation_index == 0


class TestDatabaseLoading:
    """Test MVP database loading."""

    def test_load_mvp_database(self, mvp_manager):
        """Test loading MVP database."""
        mvp_data = {
            "1001": {
                "name": "Test MVP",
                "base_level": 99,
                "hp": 500000,
                "spawn_maps": ["test_map"],
                "spawn_time_min": 120,
                "spawn_time_max": 130,
                "danger_rating": 5,
            }
        }
        
        mvp_manager.load_mvp_database(mvp_data)
        # Database should be loaded
        assert len(mvp_manager.mvp_db.get_all()) > 0