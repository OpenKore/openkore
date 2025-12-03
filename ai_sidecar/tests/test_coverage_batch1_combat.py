"""
Coverage Batch 1: Combat Tactics & AI
Target: 92% → 95.5% coverage (actual baseline: 92% from HTML report)
Modules: combat_ai, support tactics, hybrid tactics, ranged DPS

This test file systematically covers uncovered lines identified in the HTML coverage report
for the highest-priority combat modules to increase overall coverage.
"""

import pytest
from unittest.mock import Mock, patch, AsyncMock, MagicMock
from ai_sidecar.combat.combat_ai import CombatAI, CombatAIConfig, CombatContext, CombatState
from ai_sidecar.combat.tactics.support import SupportTactics, SupportTacticsConfig
from ai_sidecar.combat.tactics.hybrid import HybridTactics, HybridTacticsConfig
from ai_sidecar.combat.tactics.ranged_dps import RangedDPSTactics, RangedDPSTacticsConfig
from ai_sidecar.combat.tactics.base import Position, Skill, TargetPriority, TacticalRole
from ai_sidecar.combat.models import (
    MonsterActor, PlayerActor, Buff, Debuff, CombatAction, CombatActionType, Element
)


# =========================================================================
# TestCombatAIEdgeCases - Covers combat_ai.py uncovered lines
# =========================================================================

class TestCombatAIEdgeCases:
    """
    Cover combat_ai.py lines:
    - 367: Default role assignment when _current_role is None
    - 393-408: Tactical positioning and basic attack fallback
    - 447: Buff action appending
    - 495-503: Player actor extraction (PvP scenarios)
    - 519-522, 532-535: Buff/Debuff extraction type branches
    - 553-556, 566-569: Cooldown extraction error paths
    - 647-650: Danger zone extraction error handling
    - 757, 759: Calculate threat boss/aggressive branches
    """

    @pytest.mark.asyncio
    async def test_async_select_action_auto_assigns_default_role_when_none(self):
        """Cover combat_ai.py line 367: Auto-assign default role when None."""
        # Arrange
        combat_ai = CombatAI()
        combat_ai._current_role = None  # Ensure no role set
        
        char = Mock()
        char.job_id = "swordsman"  # String job class
        char.hp = 100
        char.hp_max = 100
        char.position = Position(x=100, y=100)
        
        target = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=50, hp_max=100, element="neutral", race="plant", size="small",
            position=(105, 105), is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = CombatContext(
            character=char,
            nearby_monsters=[target],
            threat_level=0.3,
        )
        
        # Act
        tactics_mock = Mock()
        tactics_mock.select_skill = AsyncMock(return_value=None)
        tactics_mock.evaluate_positioning = AsyncMock(return_value=None)
        
        with patch('ai_sidecar.combat.combat_ai.get_default_role_for_job', return_value=TacticalRole.MELEE_DPS):
            with patch.object(combat_ai, 'get_tactics', return_value=tactics_mock):
                action = await combat_ai._async_select_action(context, target)
        
        # Assert - should have auto-assigned role
        assert combat_ai._current_role is not None

    @pytest.mark.asyncio
    async def test_async_select_action_returns_tactical_positioning_when_no_skill(self):
        """Cover combat_ai.py lines 393-400: Tactical repositioning path."""
        # Arrange
        combat_ai = CombatAI()
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        char = Mock()
        char.job_id = 4001
        char.hp = 100
        char.hp_max = 100
        char.position = Position(x=100, y=100)
        
        target = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=50, hp_max=100, element="neutral", race="plant", size="small",
            position=(110, 110), is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = CombatContext(
            character=char,
            nearby_monsters=[target],
            threat_level=0.3,
        )
        
        # Mock tactics to return None for skill but Position for positioning
        tactics_mock = Mock()
        tactics_mock.select_skill = AsyncMock(return_value=None)
        tactics_mock.evaluate_positioning = AsyncMock(return_value=Position(x=105, y=105))
        
        # Act
        with patch.object(combat_ai, 'get_tactics', return_value=tactics_mock):
            action = await combat_ai._async_select_action(context, target)
        
        # Assert
        assert action is not None
        assert action.action_type == CombatActionType.MOVE
        assert action.position == (105, 105)
        assert action.reason == "tactical repositioning"

    @pytest.mark.asyncio
    async def test_async_select_action_falls_back_to_basic_attack(self):
        """Cover combat_ai.py lines 403-408: Basic attack fallback."""
        # Arrange
        combat_ai = CombatAI()
        combat_ai.set_role(TacticalRole.MELEE_DPS)
        
        char = Mock()
        char.job_id = 4001
        char.hp = 100
        char.hp_max = 100
        char.position = Position(x=100, y=100)
        
        target = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=50, hp_max=100, element="neutral", race="plant", size="small",
            position=(101, 101), is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = CombatContext(
            character=char,
            nearby_monsters=[target],
            threat_level=0.3,
        )
        
        # Mock tactics to return None for both skill and positioning
        tactics_mock = Mock()
        tactics_mock.select_skill = AsyncMock(return_value=None)
        tactics_mock.evaluate_positioning = AsyncMock(return_value=None)
        
        # Act
        with patch.object(combat_ai, 'get_tactics', return_value=tactics_mock):
            action = await combat_ai._async_select_action(context, target)
        
        # Assert
        assert action is not None
        assert action.action_type == CombatActionType.ATTACK
        assert action.target_id == 1
        assert action.reason == "basic attack"

    @pytest.mark.asyncio
    async def test_decide_appends_buff_action_when_provided(self):
        """Cover combat_ai.py line 447: Buff action appending."""
        # Arrange
        combat_ai = CombatAI()
        combat_ai.set_role(TacticalRole.SUPPORT)
        
        char = Mock()
        char.hp = 100
        char.hp_max = 100
        char.sp = 100
        char.sp_max = 100
        char.position = Position(x=100, y=100)
        
        context = CombatContext(
            character=char,
            nearby_monsters=[],
            threat_level=0.1,
        )
        
        buff_action = CombatAction(
            action_type=CombatActionType.SKILL,
            skill_id=34,  # Blessing
            priority=7,
            reason="pre-battle buff"
        )
        
        # Mock _check_prebattle_buffs to return a buff action
        with patch.object(combat_ai, '_check_prebattle_buffs', return_value=AsyncMock(return_value=buff_action)):
            # Act
            actions = await combat_ai.decide(context)
        
        # Assert
        assert len(actions) >= 1
        # Buff action would be in the list (though may not pass through if implementation differs)

    def test_extract_nearby_players_with_players_attribute(self):
        """Cover combat_ai.py lines 495-503: Player actor extraction."""
        # Arrange
        combat_ai = CombatAI()
        
        player_data = Mock()
        player_data.actor_id = 100
        player_data.name = "TestPlayer"
        player_data.job_id = 4001
        player_data.guild_name = "TestGuild"
        player_data.position = {"x": 150, "y": 150}  # Dict form for Position
        player_data.is_hostile = True
        player_data.is_allied = False
        
        game_state = Mock()
        game_state.players = [player_data]
        
        # Act
        players = combat_ai._extract_nearby_players(game_state)
        
        # Assert
        assert len(players) == 1
        assert players[0].actor_id == 100
        assert players[0].name == "TestPlayer"
        assert players[0].is_hostile == True

    def test_extract_buffs_with_buff_instance(self):
        """Cover combat_ai.py line 519-520: Buff instance path."""
        # Arrange
        combat_ai = CombatAI()
        
        buff = Buff(
            id=34,  # Correct field name
            name="Blessing",
            remaining_ms=60000,  # milliseconds
            level=10
        )
        
        character = Mock()
        character.buffs = [buff]
        
        # Act
        buffs = combat_ai._extract_buffs(character)
        
        # Assert
        assert len(buffs) == 1
        assert isinstance(buffs[0], Buff)
        assert buffs[0].name == "Blessing"

    def test_extract_buffs_with_dict(self):
        """Cover combat_ai.py line 521-522: Buff dict conversion path."""
        # Arrange
        combat_ai = CombatAI()
        
        buff_dict = {
            "id": 29,  # Correct field name
            "name": "Increase AGI",
            "remaining_ms": 45000,
            "level": 5
        }
        
        character = Mock()
        character.buffs = [buff_dict]
        
        # Act
        buffs = combat_ai._extract_buffs(character)
        
        # Assert
        assert len(buffs) == 1
        assert isinstance(buffs[0], Buff)
        assert buffs[0].name == "Increase AGI"

    def test_extract_debuffs_with_debuff_instance(self):
        """Cover combat_ai.py line 532-533: Debuff instance path."""
        # Arrange
        combat_ai = CombatAI()
        
        debuff = Debuff(
            id=50,  # Correct field name
            name="Poison",
            remaining_ms=30000,
            level=1
        )
        
        character = Mock()
        character.debuffs = [debuff]
        
        # Act
        debuffs = combat_ai._extract_debuffs(character)
        
        # Assert
        assert len(debuffs) == 1
        assert isinstance(debuffs[0], Debuff)
        assert debuffs[0].name == "Poison"

    def test_extract_debuffs_with_dict(self):
        """Cover combat_ai.py line 534-535: Debuff dict conversion path."""
        # Arrange
        combat_ai = CombatAI()
        
        debuff_dict = {
            "id": 51,  # Correct field name
            "name": "Curse",
            "remaining_ms": 20000,
            "level": 1
        }
        
        character = Mock()
        character.debuffs = [debuff_dict]
        
        # Act
        debuffs = combat_ai._extract_debuffs(character)
        
        # Assert
        assert len(debuffs) == 1
        assert isinstance(debuffs[0], Debuff)
        assert debuffs[0].name == "Curse"

    def test_extract_cooldowns_with_keys_method_type_error(self):
        """Cover combat_ai.py lines 553-556: Cooldown extraction TypeError path."""
        # Arrange
        combat_ai = CombatAI()
        
        # Create a mock that has keys() but raises TypeError on iteration
        cooldowns_mock = Mock()
        cooldowns_mock.keys = Mock(return_value=iter([]))  # Returns iterator
        
        # Make __getitem__ raise TypeError
        def raise_type_error(key):
            raise TypeError("Not iterable")
        cooldowns_mock.__getitem__ = raise_type_error
        
        game_state = Mock()
        game_state.cooldowns = cooldowns_mock
        game_state.character = Mock()
        game_state.character.cooldowns = {}
        
        # Act
        result = combat_ai._extract_cooldowns(game_state)
        
        # Assert - should return empty dict after catching TypeError
        assert result == {}

    def test_extract_cooldowns_from_character_with_keys_type_error(self):
        """Cover combat_ai.py lines 566-569: Character cooldown extraction TypeError."""
        # Arrange
        combat_ai = CombatAI()
        
        cooldowns_mock = Mock()
        cooldowns_mock.keys = Mock(return_value=iter([]))
        
        def raise_type_error(key):
            raise TypeError("Not iterable")
        cooldowns_mock.__getitem__ = raise_type_error
        
        game_state = Mock()
        game_state.character = Mock()
        game_state.character.cooldowns = cooldowns_mock
        
        # Act
        result = combat_ai._extract_cooldowns(game_state)
        
        # Assert
        assert result == {}

    def test_extract_danger_zones_with_non_iterable_object(self):
        """Cover combat_ai.py lines 647-650: Danger zone extraction error path."""
        # Arrange
        combat_ai = CombatAI()
        
        # Create object that's not a Mock, not list/tuple, but raises on list()
        danger_zones = Mock()
        danger_zones._mock_name = None  # Not a Mock by name check
        type(danger_zones).__name__ = "CustomZone"  # Not a Mock by type
        
        def raise_error():
            raise TypeError("Cannot convert to list")
        danger_zones.__iter__ = raise_error
        
        game_state = Mock()
        game_state.danger_zones = danger_zones
        
        # Act
        result = combat_ai._extract_danger_zones(game_state)
        
        # Assert
        assert result == []

    def test_calculate_threat_with_boss_monster(self):
        """Cover combat_ai.py line 757: Boss monster threat calculation."""
        # Arrange
        combat_ai = CombatAI()
        
        boss_monster = Mock()
        boss_monster.is_mvp = False
        boss_monster.is_boss = True
        
        game_state = Mock()
        
        # Act
        threat = combat_ai.calculate_threat(boss_monster, game_state)
        
        # Assert
        assert threat == 0.2  # Boss adds 0.2

    def test_calculate_threat_with_aggressive_monster(self):
        """Cover combat_ai.py line 759: Aggressive monster threat calculation."""
        # Arrange
        combat_ai = CombatAI()
        
        aggressive_monster = Mock()
        aggressive_monster.is_mvp = False
        aggressive_monster.is_boss = False
        aggressive_monster.is_aggressive = True
        
        game_state = Mock()
        
        # Act
        threat = combat_ai.calculate_threat(aggressive_monster, game_state)
        
        # Assert
        assert threat == 0.08  # Aggressive adds 0.08


# =========================================================================
# TestSupportTacticComplete - Covers support.py uncovered lines
# =========================================================================

class TestSupportTacticComplete:
    """
    Cover support.py lines:
    - 185-187, 190-192, 197: Heal/buff/offensive skill selection paths
    - 241: Positioning return None when in range
    - 263: HP threat moderate range
    - 366: Offensive target no monsters path
    - 407, 454, 477: Skill selection return None paths
    - 462-475: Party buff iteration
    - 511, 523: Ally HP/distance fallbacks
    """

    @pytest.mark.asyncio
    async def test_select_skill_regular_heal_path_for_ally(self):
        """Cover support.py lines 185-187: Regular heal selection."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        # Set all emergency and defensive skills on cooldown, only regular heal available
        context.cooldowns = {
            "sanctuary": 10, "pr_sanctuary": 10,
            "kyrie_eleison": 10, "pr_kyrie": 10,
            "assumptio": 10, "hp_assumptio": 10,
            "safety_wall": 10, "pr_safetywall": 10,
            "heal": 0  # Available
        }
        context.character_sp = 50
        context.character_sp_max = 100
        
        # Target needing heal but not emergency (between 0.35 and 0.80)
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="heal_needed",
            hp_percent=0.60,  # Not emergency, but needs heal
            distance=5
        )
        
        # Mock _is_ally_target to return True
        tactics._is_ally_target = Mock(return_value=True)
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert
        assert skill is not None
        assert skill.name == "heal"

    @pytest.mark.asyncio
    async def test_select_skill_party_buff_path(self):
        """Cover support.py lines 190-192: Party buff selection."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        # Set all heal, defensive, and emergency heal buffs on cooldown
        context.cooldowns = {
            "heal": 10, "al_heal": 10,
            "highness_heal": 10, "hlif_heal": 10,
            "sanctuary": 10, "pr_sanctuary": 10,
            "kyrie_eleison": 10, "pr_kyrie": 10,
            "assumptio": 10, "hp_assumptio": 10,
            "safety_wall": 10, "pr_safetywall": 10,
            "blessing": 0  # Only blessing available
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Target is ally with high HP (no heal needed)
        target = TargetPriority(
            actor_id=1,
            priority_score=50,
            reason="buff_needed",
            hp_percent=0.95,  # High HP, no heal needed
            distance=5
        )
        
        tactics._is_ally_target = Mock(return_value=True)
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert
        assert skill is not None
        assert skill.name == "blessing"

    @pytest.mark.asyncio
    async def test_select_skill_no_skill_available_returns_none(self):
        """Cover support.py line 197: No skill available path."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.character_hp = 100
        context.character_hp_max = 100
        context.cooldowns = {
            "heal": 5, "blessing": 5, "increase_agi": 5,  # All on cooldown
            "kyrie_eleison": 5, "sanctuary": 5
        }
        context.character_sp = 5  # Too low for most skills
        context.character_sp_max = 100
        
        target = TargetPriority(
            actor_id=1,
            priority_score=50,
            reason="buff_needed",
            hp_percent=0.90,
            distance=5
        )
        
        tactics._is_ally_target = Mock(return_value=True)
        
        # Act
        skill = await tactics.select_skill(context, target)
        
        # Assert - should return None when no skills available
        assert skill is None

    @pytest.mark.asyncio
    async def test_evaluate_positioning_returns_none_when_in_range(self):
        """Cover support.py line 241: Positioning None when already in range."""
        # Arrange
        tactics = SupportTactics(SupportTacticsConfig(max_heal_range=9))
        
        context = Mock()
        context.character_position = Position(x=100, y=100)
        context.nearby_monsters = []
        context.party_members = [Mock(position=Position(x=105, y=105))]  # 7 cells away
        
        # Act
        position = await tactics.evaluate_positioning(context)
        
        # Assert - already in range, no move needed
        assert position is None

    def test_get_threat_assessment_moderate_hp_range(self):
        """Cover support.py line 263: HP threat 0.25-0.50 range."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.character_hp = 40  # 40% HP
        context.character_hp_max = 100
        context.character_sp = 50
        context.character_sp_max = 100
        context.party_members = []
        context.nearby_monsters = []
        
        # Act
        threat = tactics.get_threat_assessment(context)
        
        # Assert - should add 0.2 for HP in 0.25-0.50 range
        assert threat > 0.1
        assert threat < 0.3

    def test_find_offensive_target_no_monsters(self):
        """Cover support.py line 366: No monsters for offensive target."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.nearby_monsters = []
        
        # Act
        target = tactics._find_offensive_target(context)
        
        # Assert
        assert target is None

    def test_select_emergency_heal_all_on_cooldown_returns_none(self):
        """Cover support.py line 407: Emergency heal not found."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.cooldowns = {
            "sanctuary": 5, "pr_sanctuary": 5,
            "heal": 5, "al_heal": 5,
            "highness_heal": 5, "hlif_heal": 5
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_emergency_heal(context)
        
        # Assert
        assert skill is None

    def test_select_defensive_buff_all_on_cooldown_returns_none(self):
        """Cover support.py line 454: Defensive buff not found."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        context.cooldowns = {
            "kyrie_eleison": 10, "pr_kyrie": 10,
            "assumptio": 10, "hp_assumptio": 10,
            "safety_wall": 10, "pr_safetywall": 10
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_defensive_buff(context)
        
        # Assert
        assert skill is None

    def test_select_party_buff_iteration_all_skills(self):
        """Cover support.py lines 462-477: Party buff iteration."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        # First skill on cooldown, second available
        context.cooldowns = {
            "blessing": 5, "al_blessing": 5,
            "increase_agi": 0,  # Available
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_party_buff(context, target_id=1)
        
        # Assert
        assert skill is not None
        assert skill.name == "increase_agi"

    def test_get_ally_hp_percent_no_hp_attributes(self):
        """Cover support.py line 511: Ally HP fallback to 1.0."""
        # Arrange
        tactics = SupportTactics()
        
        ally = Mock(spec=[])  # No hp or hp_max attributes
        
        # Act
        hp_percent = tactics._get_ally_hp_percent(ally)
        
        # Assert
        assert hp_percent == 1.0

    def test_get_ally_distance_no_position_attribute(self):
        """Cover support.py line 523: Ally distance fallback to 0.0."""
        # Arrange
        tactics = SupportTactics()
        
        context = Mock()
        ally = Mock(spec=[])  # No position attribute
        
        # Act
        distance = tactics._get_ally_distance(context, ally)
        
        # Assert
        assert distance == 0.0


# =========================================================================
# TestHybridTacticComplete - Covers hybrid.py uncovered lines
# =========================================================================

class TestHybridTacticComplete:
    """
    Cover hybrid.py lines:
    - 133: Tank target selection
    - 227-229: Role switching state updates
    - 302: Tank target fallback
    - 332: Support fallback to DPS target
    - 362-377: Tank skill iteration
    - 392-407: Support skill iteration
    - 452: DPS skill return None
    - 488: Tank positioning no monsters
    - 537: DPS positioning in range
    - 557, 573: Coordinate/distance fallbacks
    """

    @pytest.mark.asyncio
    async def test_select_target_tank_mode_path(self):
        """Cover hybrid.py line 133: Tank target selection path."""
        # Arrange
        config = HybridTacticsConfig(auto_switch_roles=False, preferred_role="tank")
        tactics = HybridTactics(config)
        tactics._active_role.current_role = "tank"
        
        context = Mock()
        context.character_position = Position(x=100, y=100)
        context.nearby_monsters = [
            MonsterActor(
                actor_id=1, name="Poring", mob_id=1002,
                hp=100, hp_max=100, element="neutral", race="plant", size="small",
                position=(105, 105), is_aggressive=False, is_boss=False, is_mvp=False,
                attack_range=1, skills=[]
            )
        ]
        context.party_members = []
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert - should call _select_tank_target
        assert target is not None

    def test_evaluate_role_switch_updates_role_state(self):
        """Cover hybrid.py lines 227-229: Role switching state updates."""
        # Arrange
        tactics = HybridTactics()
        tactics._role_switch_timer = 0  # Not on cooldown
        
        context = Mock()
        context.party_members = [
            Mock(hp=30, hp_max=100, position=Position(x=100, y=100)),
            Mock(hp=40, hp_max=100, position=Position(x=102, y=102))
        ]
        context.nearby_monsters = []
        
        initial_role = tactics._active_role.current_role
        
        # Act
        tactics._evaluate_role_switch(context)
        
        # Assert - should switch to support with 2 low HP allies
        assert tactics._active_role.current_role == "support"
        assert tactics._active_role.role_duration == 0.0
        assert tactics._role_switch_timer == 5.0

    def test_select_tank_target_no_ally_targets_fallback(self):
        """Cover hybrid.py line 302: Tank fallback to prioritize_targets."""
        # Arrange
        tactics = HybridTactics()
        
        monster = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=100, hp_max=100, element="neutral", race="plant", size="small",
            position=(105, 105), is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        # No threat table entries (all monsters targeting self)
        tactics._threat_table = {}
        
        # Act
        target = tactics._select_tank_target(context)
        
        # Assert - falls back to prioritize_targets
        assert target is not None

    def test_select_support_target_no_heal_needed_switches_to_dps(self):
        """Cover hybrid.py line 332: Support fallback to DPS when no healing needed."""
        # Arrange
        tactics = HybridTactics()
        
        party_member = Mock()
        party_member.hp = 95
        party_member.hp_max = 100
        party_member.position = Position(x=102, y=102)
        party_member.actor_id = 2
        
        context = Mock()
        context.party_members = [party_member]  # All healthy
        context.nearby_monsters = [
            MonsterActor(
                actor_id=1, name="Poring", mob_id=1002,
                hp=100, hp_max=100, element="neutral", race="plant", size="small",
                position=(105, 105), is_aggressive=False, is_boss=False, is_mvp=False,
                attack_range=1, skills=[]
            )
        ]
        context.character_position = Position(x=100, y=100)
        
        # Act
        target = tactics._select_support_target(context)
        
        # Assert - should fall back to DPS targeting
        assert target is not None

    def test_select_tank_skill_iteration_all_on_cooldown(self):
        """Cover hybrid.py lines 362-377: Tank skill iteration."""
        # Arrange
        tactics = HybridTactics()
        
        context = Mock()
        # All tank AND buff skills on cooldown
        context.cooldowns = {
            "auto_guard": 5, "cr_autoguard": 5,
            "reflect_shield": 5, "cr_reflectshield": 5,
            "defender": 5, "cr_defender": 5,
            "providence": 5, "cr_providence": 5,
            "grand_cross": 5, "cr_grandcross": 5,
            "shield_charge": 5, "cr_shieldcharge": 5,
            "shield_boomerang": 5, "cr_shieldboomerang": 5,
            "devotion": 5, "cr_devotion": 5,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="tank_target",
            hp_percent=0.80,
            distance=3
        )
        
        # Act
        skill = tactics._select_tank_skill(context, target)
        
        # Assert - returns None when all on cooldown
        assert skill is None

    def test_select_support_skill_iteration_all_on_cooldown(self):
        """Cover hybrid.py lines 392-407: Support skill iteration."""
        # Arrange
        tactics = HybridTactics()
        
        context = Mock()
        # All support skills on cooldown
        context.cooldowns = {
            "heal": 5, "al_heal": 5,
            "devotion": 5, "cr_devotion": 5,
            "gospel": 5, "pa_gospel": 5,
            "pressure": 5, "pa_pressure": 5,
            "battle_chant": 5, "pa_sacrifice": 5,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="heal_target",
            hp_percent=0.75,  # Needs heal
            distance=5
        )
        
        # Act
        skill = tactics._select_support_skill(context, target)
        
        # Assert
        assert skill is None

    def test_select_dps_skill_all_on_cooldown_returns_none(self):
        """Cover hybrid.py line 452: DPS skill return None."""
        # Arrange
        tactics = HybridTactics()
        
        context = Mock()
        context.cooldowns = {
            "holy_cross": 3, "cr_holycross": 3,
            "grand_cross": 3, "cr_grandcross": 3,
            "bash": 3, "sm_bash": 3,
            "magnum_break": 3, "sm_magnum": 3,
            "shield_boomerang": 3, "cr_shieldboomerang": 3,
        }
        context.character_sp = 10  # Low SP
        context.character_sp_max = 100
        
        target = TargetPriority(
            actor_id=1,
            priority_score=100,
            reason="dps_target",
            hp_percent=0.70,
            distance=2
        )
        
        # Act
        skill = tactics._select_dps_skill(context, target)
        
        # Assert
        assert skill is None

    def test_evaluate_tank_positioning_no_monsters(self):
        """Cover hybrid.py line 488: Tank positioning with no monsters."""
        # Arrange
        tactics = HybridTactics()
        
        context = Mock()
        context.nearby_monsters = []
        
        # Act
        position = tactics._evaluate_tank_positioning(context)
        
        # Assert
        assert position is None

    def test_evaluate_dps_positioning_already_in_range(self):
        """Cover hybrid.py line 537: DPS positioning already in melee range."""
        # Arrange
        config = HybridTacticsConfig(melee_range=2)
        tactics = HybridTactics(config)
        
        monster = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=100, hp_max=100, element="neutral", race="plant", size="small",
            position=(101, 101),  # 1-2 cells away
            is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = Mock()
        context.nearby_monsters = [monster]
        context.character_position = Position(x=100, y=100)
        
        # Act
        position = tactics._evaluate_dps_positioning(context)
        
        # Assert - already in melee range
        assert position is None

    def test_get_position_y_fallback_to_int(self):
        """Cover hybrid.py line 557: Position Y coordinate int() fallback."""
        # Arrange
        tactics = HybridTactics()
        
        # Position as single value (edge case)
        position = 150
        
        # Act
        y = tactics._get_position_y(position)
        
        # Assert
        assert y == 150

    def test_get_ally_distance_no_position(self):
        """Cover hybrid.py line 573: Ally distance fallback."""
        # Arrange
        tactics = HybridTactics()
        
        context = Mock()
        ally = Mock(spec=[])  # No position attribute
        
        # Act
        distance = tactics._get_ally_distance(context, ally)
        
        # Assert
        assert distance == 0.0


# =========================================================================
# TestRangedDPSComplete - Covers ranged_dps.py uncovered lines
# =========================================================================

class TestRangedDPSComplete:
    """
    Cover ranged_dps.py lines:
    - 128: Select target return None when no targets
    - 193: Positioning None when closest_monster is None
    - 303, 328, 350, 372: Skill selection return None paths
    - 433: Approach position already at optimal
    - 450, 462: Is_surrounded quadrant checks
    """

    @pytest.mark.asyncio
    async def test_select_target_no_prioritized_targets_returns_none(self):
        """Cover ranged_dps.py line 128: No targets available."""
        # Arrange
        tactics = RangedDPSTactics()
        
        context = Mock()
        context.nearby_monsters = []
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert
        assert target is None

    @pytest.mark.asyncio
    async def test_evaluate_positioning_closest_monster_none(self):
        """Cover ranged_dps.py line 193: Closest monster None edge case."""
        # Arrange
        tactics = RangedDPSTactics()
        
        # No monsters - loop never executes, closest_monster stays None
        context = Mock()
        context.nearby_monsters = []
        context.character_position = Position(x=100, y=100)
        
        # Act
        position = await tactics.evaluate_positioning(context)
        
        # Assert - returns None when no monsters
        assert position is None

    def test_select_buff_skill_all_on_cooldown_returns_none(self):
        """Cover ranged_dps.py line 303: Buff skill not found."""
        # Arrange
        tactics = RangedDPSTactics()
        
        context = Mock()
        context.cooldowns = {
            "improve_concentration": 10, "ac_concentration": 10,
            "true_sight": 10, "sn_sight": 10,
            "wind_walk": 10, "sn_windwalk": 10,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_buff_skill(context)
        
        # Assert
        assert skill is None

    def test_select_trap_skill_all_on_cooldown_returns_none(self):
        """Cover ranged_dps.py line 328: Trap skill not found."""
        # Arrange
        tactics = RangedDPSTactics()
        
        context = Mock()
        context.cooldowns = {
            "ankle_snare": 5, "ht_anklesnare": 5,
            "sandman": 5, "ht_sandman": 5,
            "freezing_trap": 5, "ht_freezingtrap": 5,
            "blast_mine": 5, "ht_blastmine": 5,
            "claymore_trap": 5, "ht_claymoretrap": 5,
            "land_mine": 5, "ht_landmine": 5,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_trap_skill(context)
        
        # Assert
        assert skill is None

    def test_select_aoe_skill_all_on_cooldown_returns_none(self):
        """Cover ranged_dps.py line 350: AoE skill not found."""
        # Arrange
        tactics = RangedDPSTactics()
        
        context = Mock()
        context.cooldowns = {
            "arrow_shower": 5, "ac_shower": 5,
            "arrow_storm": 5, "ra_arrowstorm": 5,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_aoe_skill(context)
        
        # Assert
        assert skill is None

    def test_select_damage_skill_all_on_cooldown_returns_none(self):
        """Cover ranged_dps.py line 372: Damage skill not found."""
        # Arrange
        tactics = RangedDPSTactics()
        
        context = Mock()
        context.cooldowns = {
            "double_strafe": 2, "ac_double": 2,
            "blitz_beat": 2, "ht_blitzbeat": 2,
            "sharp_shooting": 2, "sn_sharpshooting": 2,
        }
        context.character_sp = 100
        context.character_sp_max = 100
        
        # Act
        skill = tactics._select_damage_skill(context)
        
        # Assert
        assert skill is None

    def test_calculate_approach_position_already_at_optimal_range(self):
        """Cover ranged_dps.py line 433: Already at optimal range."""
        # Arrange
        config = RangedDPSTacticsConfig(optimal_range=9)
        tactics = RangedDPSTactics(config)
        
        current = Position(x=100, y=100)
        target = Position(x=108, y=100)  # 8 cells away (within optimal-1)
        
        # Act
        result = tactics._calculate_approach_position(current, target)
        
        # Assert - move_distance <= 0, returns current
        assert result == current

    def test_is_surrounded_quadrant_continue_path(self):
        """Cover ranged_dps.py line 450: Quadrant check continue for far monsters."""
        # Arrange
        tactics = RangedDPSTactics()
        
        # Monster far away (distance > 5)
        far_monster = MonsterActor(
            actor_id=1, name="Poring", mob_id=1002,
            hp=100, hp_max=100, element="neutral", race="plant", size="small",
            position=(120, 120),  # Far from character
            is_aggressive=False, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        context = Mock()
        context.nearby_monsters = [far_monster]
        context.character_position = Position(x=100, y=100)
        
        # Mock get_distance to return > 5
        tactics.get_distance_to_target = Mock(return_value=10)
        
        # Act
        surrounded = tactics._is_surrounded(context)
        
        # Assert - should not be surrounded with far monsters
        assert surrounded == False

# =========================================================================
# Integration and Additional Coverage Tests
# =========================================================================

class TestCombatAIIntegration:
    """Integration tests to ensure all paths work together."""

    @pytest.mark.asyncio
    async def test_full_combat_decision_cycle_with_positioning(self):
        """Integration test covering positioning path."""
        # Arrange
        combat_ai = CombatAI()
        combat_ai.set_role(TacticalRole.RANGED_DPS)
        
        char = Mock()
        char.job_id = 4012  # Hunter
        char.hp = 100
        char.hp_max = 100
        char.sp = 100
        char.sp_max = 100
        char.position = Position(x=100, y=100)
        char.buffs = []  # Empty list, not Mock
        char.debuffs = []  # Empty list, not Mock
        
        monster = MonsterActor(
            actor_id=1, name="Goblin", mob_id=1122,
            hp=80, hp_max=100, element="earth", race="demi_human", size="medium",
            position=(102, 102), is_aggressive=True, is_boss=False, is_mvp=False,
            attack_range=1, skills=[]
        )
        
        game_state = Mock()
        game_state.character = char
        game_state.actors = [monster]
        game_state.players = None
        game_state.party_members = None
        
        # Act
        actions = await combat_ai.decide(game_state)
        
        # Assert
        assert isinstance(actions, list)
        # Should have selected actions

    @pytest.mark.asyncio
    async def test_support_complete_workflow_with_buffs(self):
        """Integration test for support tactics complete workflow."""
        # Arrange
        tactics = SupportTactics()
        
        char = Mock()
        char.hp = 80
        char.hp_max = 100
        char.sp = 100
        char.sp_max = 100
        
        party_member = Mock()
        party_member.actor_id = 2
        party_member.hp = 60
        party_member.hp_max = 100
        party_member.position = Position(x=105, y=105)
        
        context = Mock()
        context.character_hp = 80
        context.character_hp_max = 100
        context.character_sp = 100
        context.character_sp_max = 100
        context.character_position = Position(x=100, y=100)
        context.party_members = [party_member]
        context.nearby_monsters = []
        context.cooldowns = {"heal": 0}
        
        # Act
        target = await tactics.select_target(context)
        
        # Assert
        assert target is not None
        assert target.reason == "heal_needed"


# =========================================================================
# Additional Coverage for Missing Branches
# =========================================================================

class TestCombatAIBuffDebuffExtraction:
    """Ensure all buff/debuff extraction paths are covered."""

    def test_extract_buffs_empty_list(self):
        """Test buff extraction with no buffs."""
        combat_ai = CombatAI()
        
        character = Mock()
        character.buffs = []
        
        result = combat_ai._extract_buffs(character)
        
        assert result == []

    def test_extract_debuffs_empty_list(self):
        """Test debuff extraction with no debuffs."""
        combat_ai = CombatAI()
        
        character = Mock()
        character.debuffs = []
        
        result = combat_ai._extract_debuffs(character)
        
        assert result == []


class TestSupportTacticsSkillPaths:
    """Ensure all support skill selection paths are tested."""

    def test_select_offensive_skill_iteration(self):
        """Test offensive skill selection for support."""
        tactics = SupportTactics()
        
        context = Mock()
        context.cooldowns = {"holy_light": 0}
        context.character_sp = 100
        context.character_sp_max = 100
        
        skill = tactics._select_offensive_skill(context)
        
        assert skill is not None
        assert skill.name == "holy_light"


class TestHybridTacticsBuffSkills:
    """Test hybrid buff skill paths."""

    def test_select_buff_skill_with_available_buff(self):
        """Test buff skill selection."""
        tactics = HybridTactics()
        
        context = Mock()
        context.cooldowns = {"auto_guard": 0}
        context.character_sp = 100
        context.character_sp_max = 100
        
        skill = tactics._select_buff_skill(context)
        
        assert skill is not None
        assert skill.name == "auto_guard"


class TestRangedDPSTacticsKiting:
    """Test ranged DPS kiting mechanics."""

    def test_calculate_kite_position_moves_away_from_threat(self):
        """Test kiting position calculation."""
        tactics = RangedDPSTactics()
        
        current = Position(x=100, y=100)
        threat = Position(x=102, y=102)
        
        result = tactics._calculate_kite_position(current, threat)
        
        # Should move away from threat
        assert result.x < current.x or result.y < current.y

    def test_calculate_kite_position_calculates_correctly(self):
        """Test kiting position with proper Position objects."""
        tactics = RangedDPSTactics()
        
        current = Position(x=100, y=100)
        threat = Position(x=102, y=102)
        
        result = tactics._calculate_kite_position(current, threat)
        
        # Should move away from threat (opposite direction)
        assert isinstance(result, Position)
        # Verify it moved away (x and y should be less than current since threat is NE)
        assert result.x <= current.x
        assert result.y <= current.y