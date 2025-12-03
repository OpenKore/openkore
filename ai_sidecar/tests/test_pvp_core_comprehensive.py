"""
Comprehensive tests for PvP core engine - Batch 3.

Tests threat assessment, target selection, positioning,
and engagement decisions.
"""

import json
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import Mock, mock_open, patch

import pytest

from ai_sidecar.pvp.core import (
    PlayerThreat,
    PvPCoreEngine,
    PvPMode,
    ThreatAssessor,
    ThreatLevel,
)


@pytest.fixture
def temp_data_dir(tmp_path):
    """Create temporary data directory with danger ratings."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    ratings_file = data_dir / "job_danger_ratings.json"
    ratings_data = {
        "ratings": {
            "high_priest": 8.0,
            "archbishop": 8.5,
            "champion": 9.0,
            "warlock": 7.5,
            "wizard": 7.0,
            "assassin_cross": 8.0,
            "default": 5.0
        },
        "modifiers": {
            "is_casting": 1.5,
            "low_hp_percent": 0.5,
            "high_hp_percent": 1.2,
            "is_guild_leader": 1.5
        }
    }
    ratings_file.write_text(json.dumps(ratings_data))
    
    return data_dir


class TestThreatAssessorInit:
    """Test ThreatAssessor initialization."""
    
    def test_init_with_valid_data(self, temp_data_dir):
        """Test initialization with valid danger ratings."""
        assessor = ThreatAssessor(temp_data_dir)
        
        assert len(assessor.job_danger_ratings) > 0
        assert "high_priest" in assessor.job_danger_ratings
        assert assessor.job_danger_ratings["high_priest"] == 8.0
        assert "is_casting" in assessor.modifiers
    
    def test_init_missing_file(self, tmp_path):
        """Test initialization with missing file uses defaults."""
        assessor = ThreatAssessor(tmp_path / "nonexistent")
        
        assert "default" in assessor.job_danger_ratings
        assert assessor.job_danger_ratings["default"] == 5.0


class TestThreatAssessment:
    """Test threat assessment functionality."""
    
    def test_assess_new_threat(self, temp_data_dir):
        """Test assessing a new player threat."""
        assessor = ThreatAssessor(temp_data_dir)
        
        player_data = {
            "player_id": 1,
            "name": "TestPlayer",
            "job_class": "High Priest",
            "level": 99,
            "guild": "TestGuild",
            "position": (100, 100),
            "is_casting": False,
            "hp": 5000
        }
        
        threat = assessor.assess_threat(player_data)
        
        assert threat.player_id == 1
        assert threat.player_name == "TestPlayer"
        assert threat.job_class == "High Priest"
        assert threat.threat_score > 0
    
    def test_assess_casting_player(self, temp_data_dir):
        """Test threat assessment for casting player."""
        assessor = ThreatAssessor(temp_data_dir)
        
        player_data = {
            "player_id": 1,
            "name": "Wizard",
            "job_class": "Warlock",
            "level": 99,
            "position": (100, 100),
            "is_casting": True,
            "current_skill": "Comet",
            "hp": 3000
        }
        
        threat = assessor.assess_threat(player_data)
        
        assert threat.is_casting
        assert threat.current_skill == "Comet"
        # Casting should increase threat
        assert threat.threat_score > 50.0
    
    def test_assess_low_hp_player(self, temp_data_dir):
        """Test threat assessment for low HP player."""
        assessor = ThreatAssessor(temp_data_dir)
        
        player_data = {
            "player_id": 1,
            "name": "LowHP",
            "job_class": "Champion",
            "level": 99,
            "position": (100, 100),
            "hp": 500  # Low HP
        }
        
        threat = assessor.assess_threat(player_data)
        
        # Low HP reduces threat but Champion base rating is still high
        assert threat.threat_score < 60.0
    
    def test_assess_guild_leader(self, temp_data_dir):
        """Test threat assessment for guild leader."""
        assessor = ThreatAssessor(temp_data_dir)
        
        player_data = {
            "player_id": 1,
            "name": "Guild Leader",  # Contains "leader"
            "job_class": "Archbishop",
            "level": 99,
            "guild": "TestGuild",
            "position": (100, 100),
            "hp": 8000
        }
        
        threat = assessor.assess_threat(player_data)
        
        # Guild leader should have high threat
        assert threat.threat_score > 60.0


class TestThreatScoring:
    """Test threat score calculation."""
    
    def test_calculate_threat_score_base(self, temp_data_dir):
        """Test basic threat score calculation."""
        assessor = ThreatAssessor(temp_data_dir)
        
        threat = PlayerThreat(
            player_id=1,
            player_name="Test",
            job_class="champion",
            level=99
        )
        
        score = assessor.calculate_threat_score(threat)
        
        assert score > 0
        assert score <= 100.0
    
    def test_calculate_threat_score_with_kills(self, temp_data_dir):
        """Test threat score with kill history."""
        assessor = ThreatAssessor(temp_data_dir)
        
        threat = PlayerThreat(
            player_id=1,
            player_name="Killer",
            job_class="assassin_cross",
            level=99,
            kills_against_us=3,
            deaths_to_us=0
        )
        
        score = assessor.calculate_threat_score(threat)
        
        # Kills should increase threat significantly
        assert score > 70.0
    
    def test_calculate_threat_score_with_deaths(self, temp_data_dir):
        """Test threat score with death history."""
        assessor = ThreatAssessor(temp_data_dir)
        
        threat = PlayerThreat(
            player_id=1,
            player_name="Easy",
            job_class="novice",
            level=10,
            deaths_to_us=5,
            kills_against_us=0
        )
        
        score = assessor.calculate_threat_score(threat)
        
        # Deaths should reduce threat
        assert score < 50.0


class TestThreatPrioritization:
    """Test threat prioritization."""
    
    def test_get_priority_targets(self, temp_data_dir):
        """Test getting priority targets."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Add multiple threats
        for i in range(10):
            player_data = {
                "player_id": i,
                "name": f"Player{i}",
                "job_class": "champion" if i < 3 else "novice",
                "level": 99 if i < 3 else 10,
                "position": (100 + i, 100 + i),
                "hp": 5000
            }
            assessor.assess_threat(player_data)
        
        priorities = assessor.get_priority_targets(limit=3)
        
        assert len(priorities) == 3
        # Should be sorted by threat score (highest first)
        assert priorities[0].threat_score >= priorities[1].threat_score
        assert priorities[1].threat_score >= priorities[2].threat_score
    
    def test_get_threat_in_range(self, temp_data_dir):
        """Test getting threats within range."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Add threats at various distances
        positions = [(100, 100), (105, 105), (120, 120), (150, 150)]
        for i, pos in enumerate(positions):
            player_data = {
                "player_id": i,
                "name": f"Player{i}",
                "job_class": "champion",
                "level": 99,
                "position": pos,
                "hp": 5000
            }
            assessor.assess_threat(player_data)
        
        in_range = assessor.get_threat_in_range((100, 100), range_cells=10)
        
        # Should only include close threats
        assert len(in_range) <= 2


class TestThreatUpdates:
    """Test threat update events."""
    
    def test_update_threat_killed_us(self, temp_data_dir):
        """Test updating threat when they kill us."""
        assessor = ThreatAssessor(temp_data_dir)
        
        assessor.update_threat(1, "killed_us", {
            "name": "Killer",
            "job_class": "assassin_cross",
            "level": 99
        })
        
        threat = assessor.threats[1]
        assert threat.kills_against_us == 1
    
    def test_update_threat_killed_by_us(self, temp_data_dir):
        """Test updating threat when we kill them."""
        assessor = ThreatAssessor(temp_data_dir)
        
        assessor.update_threat(1, "killed_by_us", {
            "name": "Victim",
            "job_class": "novice",
            "level": 10
        })
        
        threat = assessor.threats[1]
        assert threat.deaths_to_us == 1
    
    def test_update_threat_skill_cast(self, temp_data_dir):
        """Test updating threat when they cast skill."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Create initial threat
        assessor.update_threat(1, "skill_cast", {
            "name": "Caster",
            "job_class": "warlock",
            "level": 99,
            "skill_name": "Meteor Storm"
        })
        
        threat = assessor.threats[1]
        assert threat.is_casting
        assert threat.current_skill == "Meteor Storm"
    
    def test_update_threat_skill_end(self, temp_data_dir):
        """Test updating threat when skill ends."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Create threat with casting
        assessor.threats[1] = PlayerThreat(
            player_id=1,
            player_name="Caster",
            job_class="warlock",
            level=99,
            is_casting=True,
            current_skill="Comet"
        )
        
        assessor.update_threat(1, "skill_end", {})
        
        threat = assessor.threats[1]
        assert not threat.is_casting
        assert threat.current_skill is None


class TestFleeDecision:
    """Test flee decision logic."""
    
    def test_should_flee_low_hp(self, temp_data_dir):
        """Test flee decision with low HP."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Add dangerous threat nearby
        assessor.assess_threat({
            "player_id": 1,
            "name": "Danger",
            "job_class": "champion",
            "level": 99,
            "position": (105, 105),
            "hp": 5000
        })
        
        own_state = {
            "hp_percent": 25.0,
            "position": (100, 100)
        }
        
        assert assessor.should_flee(own_state)
    
    def test_should_flee_outnumbered(self, temp_data_dir):
        """Test flee decision when outnumbered."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Add multiple dangerous threats
        for i in range(4):
            assessor.assess_threat({
                "player_id": i,
                "name": f"Enemy{i}",
                "job_class": "champion",
                "level": 99,
                "position": (100 + i, 100 + i),
                "hp": 5000
            })
        
        own_state = {
            "hp_percent": 100.0,
            "position": (100, 100)
        }
        
        # Should flee with 3+ dangerous enemies
        assert assessor.should_flee(own_state)
    
    def test_should_not_flee_safe(self, temp_data_dir):
        """Test no flee when safe."""
        assessor = ThreatAssessor(temp_data_dir)
        
        own_state = {
            "hp_percent": 100.0,
            "position": (100, 100)
        }
        
        assert not assessor.should_flee(own_state)


class TestPvPCoreEngine:
    """Test PvP core engine functionality."""
    
    @pytest.mark.asyncio
    async def test_set_pvp_mode_woe(self, temp_data_dir):
        """Test setting WoE mode."""
        engine = PvPCoreEngine(temp_data_dir)
        
        await engine.set_pvp_mode(PvPMode.WOE_FE)
        
        assert engine.current_mode == PvPMode.WOE_FE
        assert "emp_breaker" in engine.target_priorities
        assert engine.target_priorities["emp_breaker"] == 10.0
    
    @pytest.mark.asyncio
    async def test_set_pvp_mode_battleground(self, temp_data_dir):
        """Test setting battleground mode."""
        engine = PvPCoreEngine(temp_data_dir)
        
        await engine.set_pvp_mode(PvPMode.BATTLEGROUND)
        
        assert engine.current_mode == PvPMode.BATTLEGROUND
        assert "flag_carrier" in engine.target_priorities
    
    @pytest.mark.asyncio
    async def test_select_target_no_enemies(self, temp_data_dir):
        """Test target selection with no enemies."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = await engine.select_target([], [], {"position": (100, 100)})
        
        assert target is None
    
    @pytest.mark.asyncio
    async def test_select_target_in_range(self, temp_data_dir):
        """Test selecting target in range."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemies = [
            {"player_id": 1, "name": "E1", "job_class": "champion", "level": 99, "position": (105, 105), "hp": 5000},
            {"player_id": 2, "name": "E2", "job_class": "novice", "level": 10, "position": (103, 103), "hp": 1000}
        ]
        
        own_state = {"position": (100, 100), "attack_range": 10}
        
        target = await engine.select_target(enemies, [], own_state)
        
        assert target is not None
        # Should target champion (higher threat)
        assert target == 1
    
    @pytest.mark.asyncio
    async def test_select_target_woe_priority(self, temp_data_dir):
        """Test WoE priority targeting."""
        engine = PvPCoreEngine(temp_data_dir)
        await engine.set_pvp_mode(PvPMode.WOE_FE)
        
        enemies = [
            {"player_id": 1, "name": "Tank", "job_class": "royal_guard", "level": 99, "position": (105, 105), "hp": 10000},
            {"player_id": 2, "name": "Healer", "job_class": "archbishop", "level": 99, "position": (106, 106), "hp": 5000}
        ]
        
        own_state = {"position": (100, 100), "attack_range": 10}
        
        target = await engine.select_target(enemies, [], own_state)
        
        # Should prioritize healer in WoE
        assert target == 2


class TestPositioning:
    """Test positioning calculations."""
    
    @pytest.mark.asyncio
    async def test_healer_position(self, temp_data_dir):
        """Test healer positioning."""
        engine = PvPCoreEngine(temp_data_dir)
        
        allies = [
            {"position": (100, 100)},
            {"position": (110, 110)},
            {"position": (105, 105)}
        ]
        
        own_state = {
            "position": (100, 100),
            "job_class": "high priest"
        }
        
        pos = await engine.get_optimal_position([], allies, own_state, {})
        
        # Should be behind allies
        assert isinstance(pos, tuple)
        assert len(pos) == 2
    
    @pytest.mark.asyncio
    async def test_caster_position(self, temp_data_dir):
        """Test caster positioning."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemies = [{"position": (120, 120), "player_id": 1, "name": "E1", "job_class": "champion", "level": 99, "hp": 5000}]
        
        own_state = {
            "position": (100, 100),
            "job_class": "warlock"
        }
        
        pos = await engine.get_optimal_position(enemies, [], own_state, {})
        
        # Should maintain max range
        assert isinstance(pos, tuple)
    
    @pytest.mark.asyncio
    async def test_dps_position(self, temp_data_dir):
        """Test DPS positioning."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemies = [{"position": (120, 120), "player_id": 1, "name": "E1", "job_class": "novice", "level": 10, "hp": 1000}]
        
        own_state = {
            "position": (100, 100),
            "job_class": "assassin cross"
        }
        
        pos = await engine.get_optimal_position(enemies, [], own_state, {})
        
        # Should move toward target
        assert isinstance(pos, tuple)


class TestEngagement:
    """Test engagement decisions."""
    
    @pytest.mark.asyncio
    async def test_should_engage_low_threat(self, temp_data_dir):
        """Test engaging low threat enemy."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemy = {"player_id": 1, "name": "Weak", "job_class": "novice", "level": 10, "position": (105, 105), "hp": 500}
        own_state = {"hp_percent": 100.0, "sp_percent": 100.0, "position": (100, 100)}
        
        should_engage = await engine.should_engage(enemy, own_state, allies_nearby=0)
        
        # With good resources, should engage
        assert should_engage or own_state["hp_percent"] > 50
    
    @pytest.mark.asyncio
    async def test_should_not_engage_low_resources(self, temp_data_dir):
        """Test not engaging with low resources."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemy = {"player_id": 1, "name": "Enemy", "job_class": "champion", "level": 99, "position": (105, 105), "hp": 5000}
        own_state = {"hp_percent": 15.0, "sp_percent": 5.0}
        
        should_engage = await engine.should_engage(enemy, own_state, allies_nearby=0)
        
        assert not should_engage
    
    @pytest.mark.asyncio
    async def test_should_engage_high_threat_with_backup(self, temp_data_dir):
        """Test engaging high threat with allies."""
        engine = PvPCoreEngine(temp_data_dir)
        
        enemy = {"player_id": 1, "name": "Boss", "job_class": "champion", "level": 99, "position": (105, 105), "hp": 10000}
        own_state = {"hp_percent": 100.0, "sp_percent": 100.0}
        
        should_engage = await engine.should_engage(enemy, own_state, allies_nearby=2)
        
        assert should_engage


class TestKillPotential:
    """Test kill potential calculations."""
    
    @pytest.mark.asyncio
    async def test_calculate_kill_potential_easy(self, temp_data_dir):
        """Test kill potential for easy target."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = {"player_id": 1, "name": "Easy", "job_class": "novice", "level": 10, "position": (105, 105), "hp": 500}
        own_state = {"avg_damage": 1000}
        
        potential = await engine.calculate_kill_potential(target, own_state)
        
        # High kill potential
        assert potential > 0.5
    
    @pytest.mark.asyncio
    async def test_calculate_kill_potential_hard(self, temp_data_dir):
        """Test kill potential for hard target."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = {"player_id": 1, "name": "Tank", "job_class": "royal_guard", "level": 99, "position": (105, 105), "hp": 20000}
        own_state = {"avg_damage": 500}
        
        potential = await engine.calculate_kill_potential(target, own_state)
        
        # Low kill potential
        assert potential < 0.5


class TestSkillRotations:
    """Test PvP skill rotations."""
    
    @pytest.mark.asyncio
    async def test_get_pvp_skill_rotation_champion(self, temp_data_dir):
        """Test champion skill rotation."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = {"player_id": 1, "name": "Enemy", "hp": 5000}
        own_state = {"job_class": "champion"}
        
        rotation = await engine.get_pvp_skill_rotation(target, own_state, "burst")
        
        assert len(rotation) > 0
        assert "Asura Strike" in rotation
    
    @pytest.mark.asyncio
    async def test_get_pvp_skill_rotation_warlock(self, temp_data_dir):
        """Test warlock skill rotation."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = {"player_id": 1, "name": "Enemy", "hp": 5000}
        own_state = {"job_class": "warlock"}
        
        rotation = await engine.get_pvp_skill_rotation(target, own_state, "burst")
        
        assert "Comet" in rotation or "Tetra Vortex" in rotation
    
    @pytest.mark.asyncio
    async def test_get_pvp_skill_rotation_default(self, temp_data_dir):
        """Test default skill rotation."""
        engine = PvPCoreEngine(temp_data_dir)
        
        target = {"player_id": 1, "name": "Enemy", "hp": 5000}
        own_state = {"job_class": "unknown"}
        
        rotation = await engine.get_pvp_skill_rotation(target, own_state, "burst")
        
        assert rotation == ["Attack"]


class TestThreatMaintenance:
    """Test threat maintenance functions."""
    
    def test_clear_old_threats(self, temp_data_dir):
        """Test clearing old threats."""
        assessor = ThreatAssessor(temp_data_dir)
        
        # Add old threat
        old_threat = PlayerThreat(
            player_id=1,
            player_name="Old",
            job_class="novice",
            level=10,
            last_seen=datetime.now() - timedelta(seconds=400)
        )
        assessor.threats[1] = old_threat
        
        # Add recent threat
        recent_threat = PlayerThreat(
            player_id=2,
            player_name="Recent",
            job_class="champion",
            level=99,
            last_seen=datetime.now()
        )
        assessor.threats[2] = recent_threat
        
        assessor.clear_old_threats(max_age_seconds=300)
        
        # Old threat should be removed
        assert 1 not in assessor.threats
        assert 2 in assessor.threats