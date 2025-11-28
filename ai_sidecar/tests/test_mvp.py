"""
Tests for MVP models and MVP manager.

Tests MVP tracking, spawn timers, hunting strategies,
and database management.
"""

import pytest
from datetime import datetime, timedelta

from ai_sidecar.social.mvp_models import (
    MVPBoss,
    MVPSpawnRecord,
    MVPTracker,
    MVPHuntingStrategy,
    MVPDatabase
)
from ai_sidecar.social.mvp_manager import MVPManager
from ai_sidecar.social.party_models import Party, PartyMember, PartyRole
from ai_sidecar.core.state import GameState


class TestMVPModels:
    """Test MVP data models."""
    
    def test_mvp_boss_creation(self):
        """Test creating an MVP boss."""
        mvp = MVPBoss(
            monster_id=1038,
            name="Osiris",
            base_level=78,
            hp=415600,
            spawn_maps=["moc_pryd04"],
            spawn_time_min=60,
            spawn_time_max=70,
            element="undead",
            recommended_level=85
        )
        
        assert mvp.name == "Osiris"
        assert mvp.average_spawn_time == 65
        assert "moc_pryd04" in mvp.spawn_maps
    
    def test_mvp_spawn_record(self):
        """Test MVP spawn record."""
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1038,
            map_name="moc_pryd04",
            killed_at=now,
            killed_by="TestPlayer",
            next_spawn_earliest=now + timedelta(minutes=60),
            next_spawn_latest=now + timedelta(minutes=70),
            confirmed=True
        )
        
        assert record.minutes_until_spawn >= 59
        assert not record.is_spawn_window_active
        assert not record.spawn_window_expired
    
    def test_mvp_tracker(self):
        """Test MVP tracker functionality."""
        tracker = MVPTracker()
        now = datetime.now()
        
        record = MVPSpawnRecord(
            monster_id=1038,
            map_name="moc_pryd04",
            killed_at=now,
            next_spawn_earliest=now + timedelta(minutes=60),
            next_spawn_latest=now + timedelta(minutes=70)
        )
        
        tracker.add_record(record)
        assert 1038 in tracker.records
        
        latest = tracker.get_latest_record(1038)
        assert latest is not None
        assert latest.monster_id == 1038
    
    def test_mvp_database(self):
        """Test MVP database operations."""
        db = MVPDatabase()
        
        mvp = MVPBoss(
            monster_id=1038,
            name="Osiris",
            base_level=78,
            hp=415600,
            spawn_maps=["moc_pryd04"],
            spawn_time_min=60,
            spawn_time_max=70
        )
        
        db.add(mvp)
        
        retrieved = db.get(1038)
        assert retrieved is not None
        assert retrieved.name == "Osiris"
        
        by_name = db.get_by_name("Osiris")
        assert by_name is not None
        assert by_name.monster_id == 1038


class TestMVPManager:
    """Test MVP manager logic."""
    
    @pytest.fixture
    def manager(self):
        """Create MVP manager instance."""
        mgr = MVPManager()
        
        # Load test MVP
        mvp = MVPBoss(
            monster_id=1038,
            name="Osiris",
            base_level=78,
            hp=415600,
            spawn_maps=["moc_pryd04"],
            spawn_time_min=60,
            spawn_time_max=70,
            recommended_party_size=3,
            danger_rating=6
        )
        mgr.mvp_db.add(mvp)
        
        return mgr
    
    def test_record_mvp_death(self, manager):
        """Test recording MVP death."""
        manager.record_mvp_death(1038, "moc_pryd04", "TestPlayer")
        
        assert 1038 in manager.tracker.records
        records = manager.tracker.records[1038]
        assert len(records) == 1
        assert records[0].killed_by == "TestPlayer"
    
    def test_get_spawn_window(self, manager):
        """Test getting spawn window."""
        manager.record_mvp_death(1038, "moc_pryd04")
        
        window = manager.get_spawn_window(1038)
        assert window is not None
        
        earliest, latest = window
        assert earliest > datetime.now()
        assert latest > earliest
    
    @pytest.mark.asyncio
    async def test_start_hunt(self, manager):
        """Test starting an MVP hunt."""
        party = Party(
            party_id=100,
            name="Test Party",
            leader_id=2001,
            members=[
                PartyMember(
                    account_id=1001,
                    char_id=2001,
                    name="Tank",
                    job_class="Knight",
                    base_level=90,
                    assigned_role=PartyRole.TANK
                ),
                PartyMember(
                    account_id=1002,
                    char_id=2002,
                    name="Healer",
                    job_class="Priest",
                    base_level=85,
                    assigned_role=PartyRole.HEALER
                ),
            ]
        )
        
        actions = manager.start_hunt(1038, party)
        
        assert manager.active_hunt is not None
        assert manager.active_hunt.target_mvp.monster_id == 1038
    
    @pytest.mark.asyncio
    async def test_mvp_tick(self, manager):
        """Test MVP manager tick."""
        game_state = GameState()
        actions = await manager.tick(game_state)
        
        # With no active hunt, should return empty
        assert len(actions) == 0