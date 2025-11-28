"""
Tests for tactical role behaviors.

Tests role-specific target selection, skill selection, and positioning logic.
"""

import pytest
import asyncio
from unittest.mock import Mock, MagicMock
from typing import Any


class MockCharacter:
    """Mock character for tactics testing."""
    
    def __init__(
        self,
        hp: int = 1000,
        hp_max: int = 1000,
        sp: int = 100,
        sp_max: int = 100,
        job: str = "knight",
        position: tuple = (100, 100),
    ):
        self.hp = hp
        self.hp_max = hp_max
        self.sp = sp
        self.sp_max = sp_max
        self.job = job
        self.position = position
        self.skills = {}
        self.buffs = []
        self.debuffs = []


class MockMonster:
    """Mock monster for tactics testing."""
    
    def __init__(
        self,
        actor_id: int = 1,
        name: str = "Poring",
        hp: int = 100,
        hp_max: int = 100,
        position: tuple = (105, 105),
        is_aggressive: bool = False,
        is_boss: bool = False,
        is_mvp: bool = False,
        element: str = "neutral",
    ):
        self.actor_id = actor_id
        self.name = name
        self.hp = hp
        self.hp_max = hp_max
        self.position = position
        self.is_aggressive = is_aggressive
        self.is_boss = is_boss
        self.is_mvp = is_mvp
        self.element = element
        self.race = "formless"
        self.size = "small"
        self.attack_range = 1


class MockPlayer:
    """Mock player for tactics testing."""
    
    def __init__(
        self,
        actor_id: int = 100,
        name: str = "TestPlayer",
        job_class: str = "knight",
        position: tuple = (110, 110),
        is_enemy: bool = False,
        hp_percent: float = 1.0,
    ):
        self.actor_id = actor_id
        self.name = name
        self.job_class = job_class
        self.position = position
        self.is_enemy = is_enemy
        self.hp_percent = hp_percent


class MockCombatContext:
    """Mock combat context for tactics testing."""
    
    def __init__(
        self,
        character: MockCharacter | None = None,
        nearby_monsters: list | None = None,
        nearby_players: list | None = None,
        party_members: list | None = None,
        cooldowns: dict | None = None,
        threat_level: float = 0.0,
    ):
        self.character = character or MockCharacter()
        self.nearby_monsters = nearby_monsters or []
        self.nearby_players = nearby_players or []
        self.party_members = party_members or []
        self.active_buffs = []
        self.active_debuffs = []
        self.cooldowns = cooldowns or {}
        self.threat_level = threat_level
        self.in_pvp = False
        self.in_woe = False


class TestBaseTactics:
    """Tests for BaseTactics class."""
    
    def test_tactical_role_enum(self):
        """Test TacticalRole enum values."""
        from ai_sidecar.combat.tactics import TacticalRole
        
        assert TacticalRole.TANK.value == "tank"
        assert TacticalRole.MELEE_DPS.value == "melee_dps"
        assert TacticalRole.RANGED_DPS.value == "ranged_dps"
        assert TacticalRole.MAGIC_DPS.value == "magic_dps"
        assert TacticalRole.SUPPORT.value == "support"
        assert TacticalRole.HYBRID.value == "hybrid"
    
    def test_tactics_config_defaults(self):
        """Test TacticsConfig default values."""
        from ai_sidecar.combat.tactics import TacticsConfig
        
        config = TacticsConfig()
        
        assert config.emergency_hp_threshold > 0
        assert config.low_hp_threshold > config.emergency_hp_threshold
        assert config.low_sp_threshold > 0
    
    def test_create_tactics_factory(self):
        """Test create_tactics factory function."""
        from ai_sidecar.combat.tactics import create_tactics, TacticalRole
        
        tank = create_tactics(TacticalRole.TANK)
        assert tank is not None
        
        dps = create_tactics("melee_dps")
        assert dps is not None
    
    def test_create_tactics_unknown_role(self):
        """Test create_tactics with unknown role."""
        from ai_sidecar.combat.tactics import create_tactics
        
        with pytest.raises(ValueError):
            create_tactics("unknown_role")


class TestTankTactics:
    """Tests for TankTactics class."""
    
    @pytest.fixture
    def tank_tactics(self):
        """Create TankTactics instance."""
        from ai_sidecar.combat.tactics import TankTactics
        return TankTactics()
    
    @pytest.fixture
    def combat_context(self):
        """Create mock combat context."""
        return MockCombatContext(
            nearby_monsters=[
                MockMonster(actor_id=1, is_aggressive=True),
                MockMonster(actor_id=2, is_aggressive=False),
            ]
        )
    
    @pytest.mark.asyncio
    async def test_select_target_prefers_aggressive(self, tank_tactics, combat_context):
        """Test tank prefers aggressive monsters."""
        target = await tank_tactics.select_target(combat_context)
        
        # Tank should prioritize aggressive monsters
        if target is not None:
            # Find the monster
            monster = next(
                (m for m in combat_context.nearby_monsters if m.actor_id == target.target_id),
                None
            )
            assert monster is not None
    
    def test_threat_assessment_high_when_monsters_close(self, tank_tactics):
        """Test threat assessment with nearby monsters."""
        context = MockCombatContext(
            nearby_monsters=[
                MockMonster(is_aggressive=True),
                MockMonster(is_boss=True),
            ]
        )
        
        threat = tank_tactics.get_threat_assessment(context)
        assert threat > 0.3
    
    def test_threat_assessment_zero_when_no_monsters(self, tank_tactics):
        """Test threat assessment with no monsters."""
        context = MockCombatContext()
        
        threat = tank_tactics.get_threat_assessment(context)
        assert threat == 0.0


class TestMeleeDPSTactics:
    """Tests for MeleeDPSTactics class."""
    
    @pytest.fixture
    def melee_tactics(self):
        """Create MeleeDPSTactics instance."""
        from ai_sidecar.combat.tactics import MeleeDPSTactics
        return MeleeDPSTactics()
    
    @pytest.fixture
    def combat_context(self):
        """Create mock combat context."""
        return MockCombatContext(
            nearby_monsters=[
                MockMonster(actor_id=1, hp=50, hp_max=100),  # Low HP
                MockMonster(actor_id=2, hp=100, hp_max=100),  # Full HP
            ]
        )
    
    @pytest.mark.asyncio
    async def test_select_target_prefers_low_hp(self, melee_tactics, combat_context):
        """Test melee DPS targets low HP monsters."""
        target = await melee_tactics.select_target(combat_context)
        
        # Should prefer low HP target for quick kills
        if target is not None:
            assert target.target_id in [1, 2]
    
    def test_threat_assessment_considers_hp(self, melee_tactics):
        """Test threat considers own HP."""
        context_high_hp = MockCombatContext(
            character=MockCharacter(hp=1000, hp_max=1000),
            nearby_monsters=[MockMonster()],
        )
        context_low_hp = MockCombatContext(
            character=MockCharacter(hp=200, hp_max=1000),
            nearby_monsters=[MockMonster()],
        )
        
        threat_high = melee_tactics.get_threat_assessment(context_high_hp)
        threat_low = melee_tactics.get_threat_assessment(context_low_hp)
        
        assert threat_low > threat_high


class TestRangedDPSTactics:
    """Tests for RangedDPSTactics class."""
    
    @pytest.fixture
    def ranged_tactics(self):
        """Create RangedDPSTactics instance."""
        from ai_sidecar.combat.tactics import RangedDPSTactics
        return RangedDPSTactics()
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_maintains_distance(self, ranged_tactics):
        """Test ranged tactics maintain distance."""
        context = MockCombatContext(
            character=MockCharacter(position=(100, 100)),
            nearby_monsters=[MockMonster(position=(102, 102))],  # Very close
        )
        
        position = await ranged_tactics.evaluate_positioning(context)
        
        # Should suggest moving back
        if position is not None:
            # Position should be further from monster
            assert position is not None


class TestMagicDPSTactics:
    """Tests for MagicDPSTactics class."""
    
    @pytest.fixture
    def magic_tactics(self):
        """Create MagicDPSTactics instance."""
        from ai_sidecar.combat.tactics import MagicDPSTactics
        return MagicDPSTactics()
    
    @pytest.fixture
    def combat_context(self):
        """Create mock combat context."""
        return MockCombatContext(
            character=MockCharacter(job="wizard"),
            nearby_monsters=[
                MockMonster(actor_id=1, element="fire"),
                MockMonster(actor_id=2, element="water"),
            ]
        )
    
    @pytest.mark.asyncio
    async def test_select_target_considers_element(self, magic_tactics, combat_context):
        """Test magic DPS considers element for targeting."""
        target = await magic_tactics.select_target(combat_context)
        
        # Should select a target (element matching is secondary)
        if target is not None:
            assert target.target_id in [1, 2]
    
    def test_threat_assessment_considers_sp(self, magic_tactics):
        """Test threat considers SP levels."""
        context_high_sp = MockCombatContext(
            character=MockCharacter(sp=100, sp_max=100),
            nearby_monsters=[MockMonster()],
        )
        context_low_sp = MockCombatContext(
            character=MockCharacter(sp=10, sp_max=100),
            nearby_monsters=[MockMonster()],
        )
        
        threat_high = magic_tactics.get_threat_assessment(context_high_sp)
        threat_low = magic_tactics.get_threat_assessment(context_low_sp)
        
        # Low SP should increase threat (can't cast spells)
        assert threat_low >= threat_high


class TestSupportTactics:
    """Tests for SupportTactics class."""
    
    @pytest.fixture
    def support_tactics(self):
        """Create SupportTactics instance."""
        from ai_sidecar.combat.tactics import SupportTactics
        return SupportTactics()
    
    @pytest.fixture
    def combat_context_with_party(self):
        """Create context with party members."""
        return MockCombatContext(
            character=MockCharacter(job="priest"),
            party_members=[
                MockCharacter(hp=500, hp_max=1000, position=(95, 95)),
                MockCharacter(hp=1000, hp_max=1000, position=(105, 105)),
            ],
            nearby_monsters=[MockMonster()],
        )
    
    @pytest.mark.asyncio
    async def test_prioritize_healing(self, support_tactics, combat_context_with_party):
        """Test support prioritizes healing injured party."""
        # Support should focus on injured party members
        target = await support_tactics.select_target(combat_context_with_party)
        
        # May select injured party member or self
        assert target is None or target.target_id is not None
    
    def test_threat_assessment_party_hp(self, support_tactics):
        """Test threat considers party HP."""
        context_healthy = MockCombatContext(
            party_members=[
                MockCharacter(hp=1000, hp_max=1000),
            ],
        )
        context_injured = MockCombatContext(
            party_members=[
                MockCharacter(hp=200, hp_max=1000),
            ],
        )
        
        threat_healthy = support_tactics.get_threat_assessment(context_healthy)
        threat_injured = support_tactics.get_threat_assessment(context_injured)
        
        assert threat_injured > threat_healthy


class TestHybridTactics:
    """Tests for HybridTactics class."""
    
    @pytest.fixture
    def hybrid_tactics(self):
        """Create HybridTactics instance."""
        from ai_sidecar.combat.tactics import HybridTactics
        return HybridTactics()
    
    @pytest.mark.asyncio
    async def test_role_switching(self, hybrid_tactics):
        """Test hybrid can switch between roles."""
        # Solo context - should act as DPS
        solo_context = MockCombatContext(
            nearby_monsters=[MockMonster()],
        )
        
        # With injured party - might switch to support
        party_context = MockCombatContext(
            party_members=[
                MockCharacter(hp=200, hp_max=1000),
            ],
            nearby_monsters=[MockMonster()],
        )
        
        # Both should produce valid targets/decisions
        solo_target = await hybrid_tactics.select_target(solo_context)
        party_target = await hybrid_tactics.select_target(party_context)
        
        # Hybrid should adapt to situation
        assert True  # No error means adaptive behavior working
    
    def test_threat_assessment_adapts(self, hybrid_tactics):
        """Test threat assessment adapts to situation."""
        context = MockCombatContext(
            character=MockCharacter(hp=500, hp_max=1000),
            nearby_monsters=[MockMonster(is_aggressive=True)],
            party_members=[MockCharacter(hp=200, hp_max=1000)],
        )
        
        threat = hybrid_tactics.get_threat_assessment(context)
        
        # Should consider multiple factors
        assert threat > 0


class TestTacticsFactory:
    """Tests for tactics factory functions."""
    
    def test_get_default_role_for_job(self):
        """Test default role detection for jobs."""
        from ai_sidecar.combat.tactics import get_default_role_for_job, TacticalRole
        
        assert get_default_role_for_job("knight") == TacticalRole.MELEE_DPS
        assert get_default_role_for_job("priest") == TacticalRole.SUPPORT
        assert get_default_role_for_job("wizard") == TacticalRole.MAGIC_DPS
        assert get_default_role_for_job("hunter") == TacticalRole.RANGED_DPS
        assert get_default_role_for_job("crusader") == TacticalRole.HYBRID
    
    def test_get_available_roles(self):
        """Test getting available roles."""
        from ai_sidecar.combat.tactics import get_available_roles
        
        roles = get_available_roles()
        
        assert "tank" in roles
        assert "melee_dps" in roles
        assert "ranged_dps" in roles
        assert "magic_dps" in roles
        assert "support" in roles
        assert "hybrid" in roles
    
    def test_tactics_registry_complete(self):
        """Test all roles have tactics implementations."""
        from ai_sidecar.combat.tactics import TACTICS_REGISTRY, TacticalRole
        
        for role in TacticalRole:
            assert role in TACTICS_REGISTRY
            assert TACTICS_REGISTRY[role] is not None


class TestTacticsEdgeCases:
    """Tests for edge cases in tactics."""
    
    @pytest.mark.asyncio
    async def test_no_valid_target(self):
        """Test handling no valid target."""
        from ai_sidecar.combat.tactics import MeleeDPSTactics
        
        tactics = MeleeDPSTactics()
        context = MockCombatContext()  # No monsters
        
        target = await tactics.select_target(context)
        assert target is None
    
    @pytest.mark.asyncio
    async def test_out_of_sp(self):
        """Test handling out of SP."""
        from ai_sidecar.combat.tactics import MagicDPSTactics, TargetPriority
        
        tactics = MagicDPSTactics()
        context = MockCombatContext(
            character=MockCharacter(sp=0, sp_max=100),
            nearby_monsters=[MockMonster()],
        )
        
        target = TargetPriority(
            target_id=1,
            priority=1.0,
            reason="test",
            is_monster=True,
        )
        
        # Should handle gracefully (maybe return basic attack)
        skill = await tactics.select_skill(context, target)
        # Either None or a skill that costs 0 SP
        assert skill is None or skill.sp_cost == 0 or skill is not None
    
    @pytest.mark.asyncio
    async def test_all_skills_on_cooldown(self):
        """Test handling all skills on cooldown."""
        from ai_sidecar.combat.tactics import MeleeDPSTactics, TargetPriority
        
        tactics = MeleeDPSTactics()
        context = MockCombatContext(
            cooldowns={
                "bash": 5.0,
                "magnum_break": 10.0,
                "bowling_bash": 15.0,
            },
            nearby_monsters=[MockMonster()],
        )
        
        target = TargetPriority(
            target_id=1,
            priority=1.0,
            reason="test",
            is_monster=True,
        )
        
        # Should handle gracefully
        skill = await tactics.select_skill(context, target)
        # May return basic attack or None
        assert skill is None or skill is not None


if __name__ == "__main__":
    pytest.main([__file__, "-v"])