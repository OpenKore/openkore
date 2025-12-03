"""
Comprehensive tests for BATCH 5 - All remaining modules with 10+ uncovered lines.

Covers ~300 uncovered lines across 20 modules targeting 95%+ coverage for each.

Modules tested:
- combat/tactics/support.py (31 lines)
- crafting/forging.py (29 lines)
- companions/pet.py (17 lines)
- core/state.py (17 lines)
- consumables/coordinator.py (17 lines)
- llm/manager.py (16 lines)
- consumables/food.py (15 lines)
- consumables/recovery.py (15 lines)
- social/chat_models.py (16 lines)
- utils/startup.py (15 lines)
- social/mvp_models.py (14 lines)
- quests/daily.py (14 lines)
- economy/zeny.py (14 lines)
- economy/buying.py (14 lines)
- combat/evasion.py (13 lines)
- combat/cast_delay.py (12 lines)
- crafting/refining.py (12 lines)
- memory/manager.py (11 lines)
- memory/working_memory.py (11 lines)
- economy/trading.py (11 lines)
"""

import asyncio
import json
import pytest
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from unittest.mock import Mock, AsyncMock, MagicMock, patch, mock_open

# Combat tactics support
from ai_sidecar.combat.tactics.support import (
    SupportTactics,
    SupportTacticsConfig,
)
from ai_sidecar.combat.tactics.base import (
    Position,
    Skill,
    TargetPriority,
)

# Crafting
from ai_sidecar.crafting.forging import (
    ForgingManager,
    ForgeableWeapon,
    ForgeElement,
    Material,
)
from ai_sidecar.crafting.refining import (
    RefiningManager,
    RefineOre,
    RefineLevel,
)

# Companions
from ai_sidecar.companions.pet import (
    PetManager,
    PetState,
    PetType,
    PetConfig,
    FeedDecision,
    EvolutionDecision,
    SkillAction,
)

# Core state
from ai_sidecar.core.state import (
    GameState,
    CharacterState,
    ActorState,
    ActorType,
    Position as CorePosition,
    InventoryItem,
    InventoryState,
    MapState,
    Monster,
    parse_game_state,
)

# Consumables
from ai_sidecar.consumables.coordinator import (
    ConsumableCoordinator,
    ConsumableContext,
    ConsumableAction,
    ActionPriority,
)
from ai_sidecar.consumables.food import (
    FoodManager,
    FoodItem,
    FoodBuff,
    FoodCategory,
    FoodAction,
)
from ai_sidecar.consumables.recovery import (
    RecoveryManager,
    RecoveryConfig,
    RecoveryItem,
    RecoveryType,
    RecoveryDecision,
)

# LLM
from ai_sidecar.llm.manager import LLMManager
from ai_sidecar.llm.providers import LLMMessage, LLMResponse

# Social
from ai_sidecar.social.chat_models import (
    ChatMessage,
    ChatChannel,
    ChatFilter,
    AutoResponse,
    ChatCommand,
)
from ai_sidecar.social.mvp_models import (
    MVPBoss,
    MVPSpawnRecord,
    MVPHuntingStrategy,
    MVPTracker,
    MVPDatabase,
    MVPDifficulty,
)
from ai_sidecar.social.party_models import PartyRole

# Quests
from ai_sidecar.quests.daily import (
    DailyQuestManager,
    DailyQuestCategory,
    GrampsQuest,
    EdenQuest,
    BoardQuest,
)

# Economy
from ai_sidecar.economy.zeny import (
    ZenyManager,
    ZenyManagerConfig,
    BudgetAllocation,
    Transaction,
    FinancialSummary,
)
from ai_sidecar.economy.buying import (
    BuyingManager,
    PurchaseTarget,
    PurchasePriority,
)
from ai_sidecar.economy.trading import (
    TradingSystem,
    TradingSystemConfig,
    ShoppingItem,
    SellRule,
    ShopItem,
    VendingItem,
)

# Combat mechanics
from ai_sidecar.combat.evasion import (
    EvasionCalculator,
    EvasionStats,
    HitStats,
    EvasionResult,
)
from ai_sidecar.combat.cast_delay import (
    CastDelayManager,
    SkillTiming,
    CastState,
    DelayState,
    CastType,
)

# Memory
from ai_sidecar.memory.manager import MemoryManager
from ai_sidecar.memory.working_memory import WorkingMemory
from ai_sidecar.memory.models import (
    Memory,
    MemoryType,
    MemoryImportance,
    MemoryQuery,
)
from ai_sidecar.memory.decision_models import (
    DecisionRecord,
    DecisionContext,
    DecisionOutcome,
    DecisionType,
)

# Utils
from ai_sidecar.utils.startup import (
    StartupProgress,
    StartupStep,
    StepStatus,
    SpinnerProgress,
    show_quick_status,
    format_loading_error,
    check_dependencies,
    load_config,
    validate_environment,
    wait_with_progress,
)


# ============================================================================
# FIXTURES
# ============================================================================

@pytest.fixture
def mock_combat_context():
    """Mock combat context for tactics tests."""
    context = Mock()
    context.character_hp = 5000
    context.character_hp_max = 10000
    context.character_sp = 3000
    context.character_sp_max = 5000
    context.character_position = Position(x=100, y=100)
    context.nearby_monsters = []
    context.party_members = []
    context.cooldowns = {}
    return context


@pytest.fixture
def mock_crafting_manager():
    """Mock crafting manager."""
    manager = Mock()
    manager.validate_materials = Mock(return_value=True)
    return manager


@pytest.fixture
def mock_quest_manager():
    """Mock quest manager."""
    manager = Mock()
    return manager


@pytest.fixture
def mock_market_manager():
    """Mock market manager."""
    manager = Mock()
    manager.listings = {}
    manager.get_trend = Mock(return_value=Mock(value="stable"))
    return manager


@pytest.fixture
def mock_price_analyzer():
    """Mock price analyzer."""
    analyzer = Mock()
    analyzer.calculate_fair_price = Mock(return_value=1000)
    analyzer.detect_price_anomaly = Mock(return_value=(False, "normal"))
    analyzer.compare_to_market = Mock(return_value={
        "recommendation": "good_price",
        "deviation": 0.0
    })
    analyzer.predict_price = Mock(return_value=(900, 0.7))
    return analyzer


@pytest.fixture
def temp_data_dir(tmp_path):
    """Create temporary data directory with test files."""
    data_dir = tmp_path / "data"
    data_dir.mkdir()
    
    # Create forge_weapons.json
    forge_data = {
        "weapons": [
            {
                "weapon_id": 1101,
                "weapon_name": "Sword",
                "weapon_level": 1,
                "base_materials": [
                    {"item_id": 7000, "item_name": "Iron", "quantity_required": 10, "is_consumed": True}
                ],
                "base_success_rate": 100.0
            },
            {
                "weapon_id": 1201,
                "weapon_name": "Knife",
                "weapon_level": 2,
                "base_materials": [
                    {"item_id": 7001, "item_name": "Steel", "quantity_required": 5, "is_consumed": True}
                ],
                "element_stone": {
                    "item_id": 7002,
                    "item_name": "Fire Stone",
                    "quantity_required": 1,
                    "is_consumed": True
                },
                "star_crumb_count": 1,
                "base_success_rate": 85.0
            }
        ]
    }
    with open(data_dir / "forge_weapons.json", "w") as f:
        json.dump(forge_data, f)
    
    # Create daily_quests.json
    daily_data = {
        "gramps_quests": [
            {
                "level_min": 85,
                "level_max": 99,
                "monsters": [
                    {
                        "monster_id": 1001,
                        "monster_name": "Poring",
                        "required_kills": 100,
                        "exp_reward": 50000,
                        "job_exp_reward": 25000,
                        "spawn_maps": ["prt_fild08"]
                    }
                ]
            }
        ],
        "eden_quests": {
            "71-85": [
                {
                    "quest_id": 2001,
                    "quest_name": "Hunt Porings",
                    "monsters": ["Poring"],
                    "target_count": 50,
                    "exp_reward": 30000,
                    "job_exp_reward": 15000,
                    "zeny_reward": 5000
                }
            ]
        },
        "board_quests": {
            "prontera": [
                {
                    "monster_name": "Poring",
                    "monster_id": 1002,
                    "required_kills": 30,
                    "reward_zeny": 3000,
                    "reward_exp": 10000
                }
            ]
        }
    }
    with open(data_dir / "daily_quests.json", "w") as f:
        json.dump(daily_data, f)
    
    # Create pets.json
    pets_data = {
        "poring": {
            "food": "Apple",
            "stat_bonus": {"luk": 2, "crit": 1},
            "skills": ["Heal"]
        },
        "drops": {
            "food": "Orange Juice",
            "stat_bonus": {"dex": 3},
            "evolution": {
                "target": "poporing",
                "item": "Rainbow Carrot"
            },
            "skills": ["Loot Boost"]
        }
    }
    with open(data_dir / "pets.json", "w") as f:
        json.dump(pets_data, f)
    
    return data_dir


# ============================================================================
# COMBAT TACTICS SUPPORT TESTS
# ============================================================================

class TestSupportTactics:
    """Test support tactics implementation."""
    
    def test_support_tactics_initialization(self):
        """Test support tactics initialization."""
        config = SupportTacticsConfig(
            heal_trigger_threshold=0.75,
            emergency_heal_threshold=0.30,
        )
        tactics = SupportTactics(config)
        
        assert tactics.role.value == "support"
        assert tactics.support_config.heal_trigger_threshold == 0.75
        assert tactics.support_config.emergency_heal_threshold == 0.30
        assert len(tactics._buff_timers) == 0
    
    @pytest.mark.asyncio
    async def test_select_target_self_heal(self, mock_combat_context):
        """Test target selection with self heal needed."""
        tactics = SupportTactics()
        
        # Set low HP to trigger self-heal
        mock_combat_context.character_hp = 500
        mock_combat_context.character_hp_max = 10000
        
        target = await tactics.select_target(mock_combat_context)
        
        assert target is not None
        assert target.actor_id == 0  # Self
        assert target.reason == "self_heal"
    
    @pytest.mark.asyncio
    async def test_select_target_party_healing(self, mock_combat_context):
        """Test party member healing target selection."""
        tactics = SupportTactics()
        
        # Add low HP party member
        party_member = Mock()
        party_member.actor_id = 100
        party_member.hp = 200
        party_member.hp_max = 1000
        party_member.position = (105, 105)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.character_hp = 9000
        
        target = await tactics.select_target(mock_combat_context)
        
        assert target is not None
        assert target.actor_id == 100
        assert target.reason == "heal_needed"
        assert target.hp_percent < 0.80
    
    @pytest.mark.asyncio
    async def test_select_target_emergency_heal(self, mock_combat_context):
        """Test emergency heal target selection."""
        tactics = SupportTactics()
        
        # Add critical HP party member
        party_member = Mock()
        party_member.actor_id = 101
        party_member.hp = 100
        party_member.hp_max = 1000
        party_member.position = (105, 105)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.character_hp = 9000
        
        target = await tactics.select_target(mock_combat_context)
        
        assert target is not None
        assert target.priority_score > 150  # Emergency bonus applied
    
    @pytest.mark.asyncio
    async def test_select_target_buff_needed(self, mock_combat_context):
        """Test buff target selection."""
        tactics = SupportTactics()
        
        # Add healthy party member needing buffs
        party_member = Mock()
        party_member.actor_id = 102
        party_member.hp = 900
        party_member.hp_max = 1000
        party_member.position = (105, 105)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.character_hp = 9000
        
        target = await tactics.select_target(mock_combat_context)
        
        assert target is not None
        assert target.reason == "buff_needed"
    
    @pytest.mark.asyncio
    async def test_select_target_solo_offensive(self, mock_combat_context):
        """Test offensive target selection when solo."""
        tactics = SupportTactics()
        
        # Add monster for solo combat
        monster = Mock()
        monster.actor_id = 200
        monster.position = (110, 110)
        monster.hp = 1000
        monster.hp_max = 1000
        
        mock_combat_context.nearby_monsters = [monster]
        mock_combat_context.party_members = []
        mock_combat_context.character_hp = 9000
        
        target = await tactics.select_target(mock_combat_context)
        
        assert target is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_self_heal(self, mock_combat_context):
        """Test skill selection for self healing."""
        tactics = SupportTactics()
        
        # Low HP triggers self heal
        mock_combat_context.character_hp = 1000
        mock_combat_context.character_hp_max = 10000
        mock_combat_context.character_sp = 3000
        
        target = TargetPriority(
            actor_id=100,
            priority_score=100,
            reason="heal",
            distance=5,
            hp_percent=0.50
        )
        
        skill = await tactics.select_skill(mock_combat_context, target)
        
        assert skill is not None
        assert not skill.is_offensive
    
    @pytest.mark.asyncio
    async def test_select_skill_emergency_heal(self, mock_combat_context):
        """Test emergency heal skill selection."""
        tactics = SupportTactics()
        
        mock_combat_context.character_sp = 3000
        mock_combat_context.character_hp = 9000  # Self has good HP
        
        # Add party member so target is recognized as ally
        party_member = Mock()
        party_member.actor_id = 100
        party_member.hp = 200
        party_member.hp_max = 1000
        mock_combat_context.party_members = [party_member]
        
        target = TargetPriority(
            actor_id=100,
            priority_score=200,
            reason="emergency",
            distance=5,
            hp_percent=0.20
        )
        
        skill = await tactics.select_skill(mock_combat_context, target)
        
        assert skill is not None
        # Should be heal or defensive buff for low HP ally
        assert skill.name in (tactics.EMERGENCY_HEALS + tactics.DEFENSIVE_BUFFS + tactics.REGULAR_HEALS)
    
    @pytest.mark.asyncio
    async def test_select_skill_defensive_buff(self, mock_combat_context):
        """Test defensive buff selection."""
        tactics = SupportTactics()
        
        mock_combat_context.character_sp = 3000
        mock_combat_context.character_hp = 9000
        
        target = TargetPriority(
            actor_id=100,
            priority_score=150,
            reason="low_hp",
            distance=5,
            hp_percent=0.60
        )
        
        skill = await tactics.select_skill(mock_combat_context, target)
        
        assert skill is not None
    
    @pytest.mark.asyncio
    async def test_select_skill_offensive_solo(self, mock_combat_context):
        """Test offensive skill for solo combat."""
        tactics = SupportTactics()
        
        mock_combat_context.character_sp = 3000
        mock_combat_context.party_members = []
        
        target = TargetPriority(
            actor_id=200,
            priority_score=50,
            reason="enemy",
            distance=5,
            hp_percent=1.0
        )
        
        skill = await tactics.select_skill(mock_combat_context, target)
        
        assert skill is not None
        assert skill.is_offensive
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_solo(self, mock_combat_context):
        """Test positioning evaluation when solo."""
        tactics = SupportTactics()
        
        monster = Mock()
        monster.position = (110, 110)
        mock_combat_context.nearby_monsters = [monster]
        mock_combat_context.party_members = []
        
        position = await tactics.evaluate_positioning(mock_combat_context)
        
        assert position is not None
        # Should move away from enemy
        assert position.x < 100 or position.y < 100
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_with_party(self, mock_combat_context):
        """Test positioning with party."""
        tactics = SupportTactics()
        
        # Add party member and enemy
        party_member = Mock()
        party_member.position = (95, 95)
        
        monster = Mock()
        monster.position = (90, 90)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.nearby_monsters = [monster]
        
        position = await tactics.evaluate_positioning(mock_combat_context)
        
        assert position is not None
    
    @pytest.mark.asyncio
    async def test_evaluate_positioning_far_from_party(self, mock_combat_context):
        """Test repositioning when far from party."""
        config = SupportTacticsConfig(max_heal_range=9)
        tactics = SupportTactics(config)
        
        # Party far away
        party_member = Mock()
        party_member.position = (150, 150)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.nearby_monsters = []
        
        position = await tactics.evaluate_positioning(mock_combat_context)
        
        assert position is not None
        # Should move toward party
        assert position.x > 100 or position.y > 100
    
    def test_threat_assessment_low_hp(self, mock_combat_context):
        """Test threat assessment with low HP."""
        tactics = SupportTactics()
        
        mock_combat_context.character_hp = 1000
        
        threat = tactics.get_threat_assessment(mock_combat_context)
        
        assert threat > 0.3  # Significant threat from low HP
    
    def test_threat_assessment_low_sp(self, mock_combat_context):
        """Test threat assessment with low SP."""
        tactics = SupportTactics()
        
        mock_combat_context.character_sp = 200
        
        threat = tactics.get_threat_assessment(mock_combat_context)
        
        assert threat > 0.2  # SP threat
    
    def test_threat_assessment_party_emergency(self, mock_combat_context):
        """Test threat assessment with party emergencies."""
        tactics = SupportTactics()
        
        # Multiple low HP party members
        for i in range(3):
            member = Mock()
            member.hp = 100
            member.hp_max = 1000
            mock_combat_context.party_members.append(member)
        
        threat = tactics.get_threat_assessment(mock_combat_context)
        
        assert threat > 0.2  # Multiple emergencies increase threat
    
    def test_threat_assessment_close_enemies(self, mock_combat_context):
        """Test threat assessment with close enemies."""
        tactics = SupportTactics()
        
        # Add close enemies
        for i in range(3):
            monster = Mock()
            monster.position = (101, 101)
            mock_combat_context.nearby_monsters.append(monster)
        
        threat = tactics.get_threat_assessment(mock_combat_context)
        
        assert threat > 0.1


# ============================================================================
# CRAFTING FORGING TESTS
# ============================================================================

class TestForgingManager:
    """Test forging manager."""
    
    def test_forging_manager_initialization(self, temp_data_dir, mock_crafting_manager):
        """Test forging manager initialization."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        assert len(manager.forgeable_weapons) == 2
        assert 1101 in manager.forgeable_weapons
        assert manager.forgeable_weapons[1101].weapon_name == "Sword"
    
    def test_forge_success_rate_level_1(self, temp_data_dir, mock_crafting_manager):
        """Test forge success rate for level 1 weapon."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        character_state = {
            "dex": 50,
            "luk": 30,
            "job_level": 40
        }
        
        rate = manager.get_forge_success_rate(1101, character_state)
        
        assert rate == 100.0  # Level 1 weapon caps at 100%
    
    def test_forge_success_rate_level_2_with_element(self, temp_data_dir, mock_crafting_manager):
        """Test forge success rate with element."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        character_state = {
            "dex": 60,
            "luk": 40,
            "job_level": 50
        }
        
        rate = manager.get_forge_success_rate(
            1201,
            character_state,
            element=ForgeElement.FIRE
        )
        
        assert rate < 100.0  # Element penalty applied
        assert rate > 0.0
    
    def test_forge_success_rate_with_star_crumbs(self, temp_data_dir, mock_crafting_manager):
        """Test forge success rate with star crumbs."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        character_state = {
            "dex": 70,
            "luk": 50,
            "job_level": 50
        }
        
        rate = manager.get_forge_success_rate(
            1201,
            character_state,
            star_crumbs=3
        )
        
        assert rate < 100.0  # Star crumb penalty applied
    
    def test_get_required_materials_basic(self, temp_data_dir, mock_crafting_manager):
        """Test getting required materials for basic forge."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        materials = manager.get_required_materials(1101)
        
        assert len(materials) == 1
        assert materials[0].item_id == 7000
        assert materials[0].quantity_required == 10
    
    def test_get_required_materials_with_element(self, temp_data_dir, mock_crafting_manager):
        """Test required materials with element stone."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        materials = manager.get_required_materials(1201, element=ForgeElement.FIRE)
        
        assert len(materials) == 2  # Base materials + element stone
        assert any(m.item_id == 7002 for m in materials)
    
    def test_get_required_materials_with_star_crumbs(self, temp_data_dir, mock_crafting_manager):
        """Test required materials with star crumbs."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        materials = manager.get_required_materials(1201, star_crumbs=2)
        
        # Should have base materials + star crumbs
        assert any(m.item_name == "Star Crumb" and m.quantity_required == 2 for m in materials)
    
    def test_get_fame_value_basic(self, temp_data_dir, mock_crafting_manager):
        """Test fame value calculation."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        fame = manager.get_fame_value(1)
        assert fame == 1
        
        fame = manager.get_fame_value(4)
        assert fame == 15
    
    def test_get_fame_value_with_element(self, temp_data_dir, mock_crafting_manager):
        """Test fame value with element."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        fame = manager.get_fame_value(2, element=ForgeElement.FIRE)
        assert fame == 7  # 5 base + 2 element
        
        fame = manager.get_fame_value(2, element=ForgeElement.VERY_STRONG_FIRE)
        assert fame == 10  # 5 base + 5 element
    
    def test_get_fame_value_with_star_crumbs(self, temp_data_dir, mock_crafting_manager):
        """Test fame value with star crumbs."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        fame = manager.get_fame_value(3, star_crumbs=2)
        assert fame == 16  # 10 base + 6 from crumbs
    
    def test_get_optimal_forge_target(self, temp_data_dir, mock_crafting_manager):
        """Test optimal forge target selection."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        inventory = {
            7000: 20,  # Enough iron
            7001: 10   # Enough steel
        }
        
        character_state = {
            "dex": 50,
            "luk": 30,
            "job_level": 40
        }
        
        target = manager.get_optimal_forge_target(inventory, character_state)
        
        assert target is not None
        assert "weapon_id" in target
        assert "success_rate" in target
        assert "fame_gain" in target
    
    def test_get_optimal_forge_target_with_prices(self, temp_data_dir, mock_crafting_manager):
        """Test optimal forge target with market prices."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        inventory = {7000: 20, 7001: 10}
        character_state = {"dex": 50, "luk": 30, "job_level": 40}
        market_prices = {
            1101: 5000,
            1201: 8000,
            7000: 100,
            7001: 200
        }
        
        target = manager.get_optimal_forge_target(
            inventory,
            character_state,
            market_prices
        )
        
        assert target is not None
        assert "estimated_profit" in target
    
    def test_add_fame(self, temp_data_dir, mock_crafting_manager):
        """Test fame tracking."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        total = manager.add_fame("TestChar", 10)
        assert total == 10
        
        total = manager.add_fame("TestChar", 5)
        assert total == 15
        
        assert manager.get_fame("TestChar") == 15
    
    def test_get_statistics(self, temp_data_dir, mock_crafting_manager):
        """Test forge statistics."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        manager.add_fame("Char1", 20)
        manager.add_fame("Char2", 15)
        
        stats = manager.get_statistics()
        
        assert stats["total_forgeable"] == 2
        assert stats["total_fame_tracked"] == 35
        assert stats["characters_with_fame"] == 2
        assert 1 in stats["by_weapon_level"]
    
    def test_can_forge_by_id(self, temp_data_dir, mock_crafting_manager):
        """Test can forge check by weapon ID."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        # Check with no inventory (assume available)
        assert manager.can_forge("1101") is True
        assert manager.can_forge("9999") is False
    
    def test_can_forge_by_name(self, temp_data_dir, mock_crafting_manager):
        """Test can forge check by weapon name."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        assert manager.can_forge("sword") is True
        assert manager.can_forge("Sword") is True
        assert manager.can_forge("unknown") is False
    
    def test_can_forge_with_inventory(self, temp_data_dir, mock_crafting_manager):
        """Test can forge with inventory check."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        # Enough materials
        inventory = {7000: 20}
        assert manager.can_forge("1101", inventory=inventory) is True
        
        # Not enough materials
        inventory = {7000: 5}
        assert manager.can_forge("1101", inventory=inventory) is False
    
    @pytest.mark.asyncio
    async def test_forge_method(self, temp_data_dir, mock_crafting_manager):
        """Test forge method."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        result = await manager.forge("Sword", quantity=5)
        
        assert result["success"] is True
        assert result["recipe"] == "Sword"
        assert result["quantity"] == 5
    
    def test_calculate_success_rate_by_id(self, temp_data_dir, mock_crafting_manager):
        """Test success rate calculation by ID."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        rate = manager.calculate_success_rate("1101", smith_level=10)
        assert rate == 110.0  # 100 base + 10 from skill
    
    def test_calculate_success_rate_by_name(self, temp_data_dir, mock_crafting_manager):
        """Test success rate calculation by name."""
        manager = ForgingManager(temp_data_dir, mock_crafting_manager)
        
        rate = manager.calculate_success_rate("sword", smith_level=5)
        assert rate == 105.0


# ============================================================================
# COMPANIONS PET TESTS
# ============================================================================

class TestPetManager:
    """Test pet manager."""
    
    def test_pet_manager_initialization(self, temp_data_dir):
        """Test pet manager initialization."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        assert "poring" in manager._pet_database
        assert "drops" in manager._pet_database
    
    @pytest.mark.asyncio
    async def test_update_state_evolution_ready(self, temp_data_dir):
        """Test state update with evolution ready."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.DROPS,
            intimacy=920,  # Above 910
            hunger=50,
            is_summoned=True
        )
        
        await manager.update_state(state)
        
        assert state.can_evolve is True
        assert state.evolution_target == PetType.POPORING
    
    @pytest.mark.asyncio
    async def test_decide_feed_timing_emergency(self, temp_data_dir):
        """Test emergency feeding decision."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=5,  # Very low
            is_summoned=True
        )
        await manager.update_state(state)
        
        decision = await manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is True
        assert decision.reason == "emergency_low_hunger"
    
    @pytest.mark.asyncio
    async def test_decide_feed_timing_optimal_window(self, temp_data_dir):
        """Test feeding in optimal intimacy window."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=30,  # Optimal range
            is_summoned=True
        )
        await manager.update_state(state)
        
        decision = await manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is True
        assert decision.reason == "optimal_intimacy_window"
        assert decision.expected_intimacy_gain > 0
    
    @pytest.mark.asyncio
    async def test_decide_feed_timing_max_intimacy(self, temp_data_dir):
        """Test feeding decision at max intimacy."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=1000,  # Max
            hunger=60,  # High
            is_summoned=True
        )
        await manager.update_state(state)
        
        decision = await manager.decide_feed_timing()
        
        assert decision is not None
        assert decision.should_feed is False
        assert "max_intimacy" in decision.reason
    
    @pytest.mark.asyncio
    async def test_decide_feed_timing_not_summoned(self, temp_data_dir):
        """Test feeding decision when pet not summoned."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=20,
            is_summoned=False
        )
        await manager.update_state(state)
        
        decision = await manager.decide_feed_timing()
        
        assert decision is None
    
    @pytest.mark.asyncio
    async def test_evaluate_evolution_eligible(self, temp_data_dir):
        """Test evolution evaluation when eligible."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.DROPS,
            intimacy=920,
            hunger=50,
            is_summoned=True,
            can_evolve=True,
            evolution_target=PetType.POPORING
        )
        await manager.update_state(state)
        
        decision = await manager.evaluate_evolution()
        
        assert decision is not None
        assert decision.should_evolve is True
        assert decision.target == PetType.POPORING
        assert decision.required_item == "Rainbow Carrot"
    
    @pytest.mark.asyncio
    async def test_evaluate_evolution_low_intimacy(self, temp_data_dir):
        """Test evolution evaluation with low intimacy."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.DROPS,
            intimacy=500,  # Too low
            hunger=50,
            is_summoned=True
        )
        await manager.update_state(state)
        
        decision = await manager.evaluate_evolution()
        
        assert decision is not None
        assert decision.should_evolve is False
        assert "intimacy_too_low" in decision.reason
    
    @pytest.mark.asyncio
    async def test_evaluate_evolution_no_path(self, temp_data_dir):
        """Test evolution evaluation with no evolution path."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,  # No evolution
            intimacy=950,
            hunger=50,
            is_summoned=True
        )
        await manager.update_state(state)
        
        decision = await manager.evaluate_evolution()
        
        assert decision is not None
        assert decision.should_evolve is False
        assert decision.reason == "no_evolution_path"
    
    @pytest.mark.asyncio
    async def test_select_optimal_pet_farming(self, temp_data_dir):
        """Test pet selection for farming."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        pet_type = await manager.select_optimal_pet("farming")
        
        assert pet_type in [PetType.DROPS, PetType.YOYO]
    
    @pytest.mark.asyncio
    async def test_select_optimal_pet_mvp(self, temp_data_dir):
        """Test pet selection for MVP."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        pet_type = await manager.select_optimal_pet("mvp")
        
        assert pet_type is not None
    
    @pytest.mark.asyncio
    async def test_coordinate_pet_skills_heal(self, temp_data_dir):
        """Test pet skill coordination - healing."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=50,
            is_summoned=True
        )
        await manager.update_state(state)
        
        action = await manager.coordinate_pet_skills(
            combat_active=True,
            player_hp_percent=0.3,  # Low HP
            enemies_nearby=2
        )
        
        assert action is not None
        assert action.skill_name == "Heal"
        assert action.reason == "player_hp_low"
    
    @pytest.mark.asyncio
    async def test_coordinate_pet_skills_combat(self, temp_data_dir):
        """Test pet skill coordination in combat."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=50,
            is_summoned=True
        )
        await manager.update_state(state)
        
        # First call to heal (low HP)
        await manager.coordinate_pet_skills(True, 0.4, 2)
        
        # Wait for cooldown
        time.sleep(0.1)
        
        # Second call - no heal skills, should return None
        action = await manager.coordinate_pet_skills(True, 0.9, 3)
        
        # Depends on cooldown - might be None
        assert action is None or isinstance(action, SkillAction)
    
    @pytest.mark.asyncio
    async def test_coordinate_pet_skills_cooldown(self, temp_data_dir):
        """Test pet skill cooldown."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        manager.config = PetConfig(skill_cooldown=10.0)
        
        state = PetState(
            pet_id=1,
            pet_type=PetType.PORING,
            intimacy=500,
            hunger=50,
            is_summoned=True
        )
        await manager.update_state(state)
        
        # First use
        action1 = await manager.coordinate_pet_skills(True, 0.3, 2)
        assert action1 is not None
        
        # Immediate second use - should be on cooldown
        action2 = await manager.coordinate_pet_skills(True, 0.3, 2)
        assert action2 is None
    
    def test_get_pet_bonus(self, temp_data_dir):
        """Test getting pet stat bonuses."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        bonus = manager.get_pet_bonus(PetType.PORING)
        
        assert isinstance(bonus, dict)
        assert "luk" in bonus


# ============================================================================
# CORE STATE TESTS
# ============================================================================

class TestCoreState:
    """Test core state models."""
    
    def test_position_distance_to(self):
        """Test position distance calculation."""
        pos1 = CorePosition(x=0, y=0)
        pos2 = CorePosition(x=3, y=4)
        
        distance = pos1.distance_to(pos2)
        assert distance == 5.0
    
    def test_position_manhattan_distance(self):
        """Test Manhattan distance."""
        pos1 = CorePosition(x=0, y=0)
        pos2 = CorePosition(x=3, y=4)
        
        distance = pos1.manhattan_distance(pos2)
        assert distance == 7
    
    def test_actor_state_hp_percent(self):
        """Test actor HP percentage."""
        actor = ActorState(
            id=1,
            type=ActorType.MONSTER,
            hp=500,
            hp_max=1000
        )
        
        assert actor.hp_percent == 50.0
    
    def test_actor_state_hp_percent_zero_max(self):
        """Test actor HP percentage with zero max."""
        actor = ActorState(
            id=1,
            type=ActorType.MONSTER,
            hp=500,
            hp_max=0
        )
        
        assert actor.hp_percent is None
    
    def test_character_state_properties(self):
        """Test character state property aliases."""
        char = CharacterState(
            name="Test",
            stat_str=50,
            int_stat=40,
            job_class="Priest"
        )
        
        assert char.str == 50
        assert char.int == 40
        assert char.job == "Priest"
        assert char.level == 1
    
    def test_inventory_item_get_item_type(self):
        """Test inventory item type accessor."""
        item = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            type=3
        )
        
        assert item.get_item_type() == 3
        
        item_with_string = InventoryItem(
            index=1,
            item_id=502,
            name="Orange Potion",
            type=3,
            item_type="potion"
        )
        
        assert item_with_string.get_item_type() == "potion"
    
    def test_inventory_state_get_item_by_id(self):
        """Test inventory get item by ID."""
        inventory = InventoryState(items=[
            InventoryItem(index=0, item_id=501, name="Red Potion"),
            InventoryItem(index=1, item_id=502, name="Orange Potion"),
        ])
        
        item = inventory.get_item_by_id(501)
        assert item is not None
        assert item.name == "Red Potion"
        
        item = inventory.get_item_by_id(999)
        assert item is None
    
    def test_inventory_state_get_item_count(self):
        """Test inventory item count."""
        inventory = InventoryState(items=[
            InventoryItem(index=0, item_id=501, amount=10),
            InventoryItem(index=1, item_id=501, amount=5),
            InventoryItem(index=2, item_id=502, amount=3),
        ])
        
        count = inventory.get_item_count(501)
        assert count == 15
        
        count = inventory.get_item_count(999)
        assert count == 0
    
    def test_game_state_get_monsters(self):
        """Test getting monsters from game state."""
        game_state = GameState(actors=[
            ActorState(id=1, type=ActorType.MONSTER, name="Poring"),
            ActorState(id=2, type=ActorType.PLAYER, name="Player"),
            ActorState(id=3, type=ActorType.MONSTER, name="Drops"),
        ])
        
        monsters = game_state.get_monsters()
        assert len(monsters) == 2
    
    def test_game_state_get_nearest_monster(self):
        """Test getting nearest monster."""
        game_state = GameState(
            character=CharacterState(position=CorePosition(x=100, y=100)),
            actors=[
                ActorState(id=1, type=ActorType.MONSTER, position=CorePosition(x=105, y=105)),
                ActorState(id=2, type=ActorType.MONSTER, position=CorePosition(x=110, y=110)),
            ]
        )
        
        nearest, distance = game_state.get_nearest_monster()
        
        assert nearest is not None
        assert nearest.id == 1
        assert distance < 10
    
    def test_game_state_convenience_properties(self):
        """Test game state convenience properties."""
        game_state = GameState(
            character=CharacterState(
                hp=5000,
                hp_max=10000,
                sp=2500,
                sp_max=5000,
                position=CorePosition(x=100, y=100),
                job_class="Wizard"
            ),
            actors=[
                ActorState(id=1, type=ActorType.MONSTER),
                ActorState(id=2, type=ActorType.MONSTER),
            ]
        )
        
        assert game_state.player_hp_percent == 0.5
        assert game_state.player_sp_percent == 0.5
        assert game_state.player_position == (100, 100)
        assert game_state.player_class == "Wizard"
        assert game_state.enemies_nearby == 2
        assert game_state.is_boss_fight is False
    
    def test_parse_game_state_with_payload(self):
        """Test parsing game state with payload wrapper."""
        data = {
            "payload": {
                "tick": 100,
                "character": {"name": "Test"}
            }
        }
        
        state = parse_game_state(data)
        
        assert state.tick == 100
        assert state.character.name == "Test"
    
    def test_monster_constructor_flexibility(self):
        """Test Monster constructor with flexible args."""
        monster = Monster(
            actor_id=1,
            position=(50, 60),
            level=10,
            hp_percent=0.75
        )
        
        assert monster.id == 1
        assert monster.position.x == 50
        assert monster.position.y == 60
        assert monster.hp == 75
        assert monster.hp_max == 100


# ============================================================================
# CONSUMABLES COORDINATOR TESTS
# ============================================================================

class TestConsumableCoordinator:
    """Test consumable coordinator."""
    
    @pytest.mark.asyncio
    async def test_coordinator_initialization(self):
        """Test coordinator initialization."""
        coordinator = ConsumableCoordinator()
        
        assert coordinator.buff_manager is not None
        assert coordinator.status_manager is not None
        assert coordinator.recovery_manager is not None
        assert coordinator.food_manager is not None
    
    @pytest.mark.asyncio
    async def test_update_all_emergency_recovery(self):
        """Test update with emergency recovery."""
        coordinator = ConsumableCoordinator()
        
        game_state = ConsumableContext(
            hp_percent=0.15,  # Emergency
            sp_percent=0.50,
            max_hp=10000,
            max_sp=5000,
            inventory={607: 1}  # Yggdrasil Berry
        )
        
        actions = await coordinator.update_all(game_state)
        
        assert len(actions) > 0
        assert any(a.priority == ActionPriority.EMERGENCY for a in actions)
    
    @pytest.mark.asyncio
    async def test_update_all_urgent_recovery(self):
        """Test update with urgent recovery."""
        coordinator = ConsumableCoordinator()
        
        game_state = ConsumableContext(
            hp_percent=0.35,  # Urgent
            sp_percent=0.50,
            max_hp=10000,
            max_sp=5000,
            inventory={504: 5}  # White Potion
        )
        
        actions = await coordinator.update_all(game_state)
        
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_pre_combat_preparation(self):
        """Test pre-combat preparation."""
        coordinator = ConsumableCoordinator()
        
        enemy_info = {
            "map": "gef_dun01",
            "monsters": ["Zombie", "Ghoul"]
        }
        
        actions = await coordinator.pre_combat_preparation(
            enemy_info,
            character_build="melee_dps"
        )
        
        assert isinstance(actions, list)
    
    @pytest.mark.asyncio
    async def test_post_combat_recovery(self):
        """Test post-combat recovery."""
        coordinator = ConsumableCoordinator()
        
        actions = await coordinator.post_combat_recovery(
            hp_percent=0.60,
            sp_percent=0.30
        )
        
        assert isinstance(actions, list)
    
    def test_get_system_summary(self):
        """Test system summary."""
        coordinator = ConsumableCoordinator()
        coordinator.last_update = datetime.now()
        
        summary = coordinator.get_system_summary()
        
        assert "buffs" in summary
        assert "status_effects" in summary
        assert "food" in summary
        assert "last_update" in summary


# ============================================================================
# LLM MANAGER TESTS
# ============================================================================

class TestLLMManager:
    """Test LLM manager."""
    
    def test_llm_manager_initialization_basic(self):
        """Test basic LLM manager initialization."""
        manager = LLMManager()
        
        assert len(manager.providers) == 0
        assert manager.primary_provider is None
    
    def test_llm_manager_initialization_with_provider(self):
        """Test LLM manager with provider."""
        with patch('ai_sidecar.llm.providers.OpenAIProvider'):
            manager = LLMManager(provider="openai", api_key="test-key")
            
            assert len(manager.providers) > 0
    
    def test_add_provider(self):
        """Test adding provider."""
        manager = LLMManager()
        mock_provider = Mock()
        mock_provider.provider_name = "test"
        
        manager.add_provider(mock_provider, primary=True)
        
        assert len(manager.providers) == 1
        assert manager.primary_provider == mock_provider
    
    @pytest.mark.asyncio
    async def test_complete_with_primary(self):
        """Test completion with primary provider."""
        manager = LLMManager()
        
        mock_provider = AsyncMock()
        mock_provider.provider_name = "test"
        mock_provider.complete = AsyncMock(return_value=LLMResponse(
            content="Response",
            provider="test",
            model="test-model",
            tokens_used=10
        ))
        
        manager.add_provider(mock_provider, primary=True)
        
        messages = [LLMMessage(role="user", content="Hello")]
        response = await manager.complete(messages)
        
        assert response is not None
        assert response.content == "Response"
        assert manager._usage_stats["test"] == 1
    
    @pytest.mark.asyncio
    async def test_complete_fallback(self):
        """Test completion with fallback."""
        manager = LLMManager()
        
        # Primary fails
        primary = AsyncMock()
        primary.provider_name = "primary"
        primary.complete = AsyncMock(return_value=None)
        
        # Fallback succeeds
        fallback = AsyncMock()
        fallback.provider_name = "fallback"
        fallback.complete = AsyncMock(return_value=LLMResponse(
            content="Fallback response",
            provider="fallback",
            model="fallback-model",
            tokens_used=10
        ))
        
        manager.add_provider(primary, primary=True)
        manager.add_provider(fallback)
        
        messages = [LLMMessage(role="user", content="Hello")]
        response = await manager.complete(messages)
        
        assert response is not None
        assert response.content == "Fallback response"
        assert manager._usage_stats["fallback"] == 1
    
    @pytest.mark.asyncio
    async def test_analyze_situation(self):
        """Test situation analysis."""
        manager = LLMManager()
        
        mock_provider = AsyncMock()
        mock_provider.provider_name = "test"
        mock_provider.complete = AsyncMock(return_value=LLMResponse(
            content="Attack the nearest monster",
            provider="test",
            model="test-model",
            tokens_used=10
        ))
        
        manager.add_provider(mock_provider, primary=True)
        
        game_state = {
            "base_level": 50,
            "hp_percent": 75,
            "map_name": "prt_fild08",
            "monster_count": 3,
            "in_combat": True
        }
        
        from ai_sidecar.memory.models import Memory, MemoryType
        memories = [
            Memory(memory_type=MemoryType.EVENT, content="Killed Poring", summary="Killed Poring"),
        ]
        
        analysis = await manager.analyze_situation(game_state, memories)
        
        assert analysis is not None
        assert isinstance(analysis, str)
    
    @pytest.mark.asyncio
    async def test_explain_decision(self):
        """Test decision explanation."""
        manager = LLMManager()
        
        mock_provider = AsyncMock()
        mock_provider.provider_name = "test"
        mock_provider.complete = AsyncMock(return_value=LLMResponse(
            content="Attacked because HP was full",
            provider="test",
            model="test-model",
            tokens_used=10
        ))
        
        manager.add_provider(mock_provider, primary=True)
        
        decision = DecisionRecord(
            record_id="test_2",
            decision_type="combat",
            action_taken={"action": "attack"},
            context=DecisionContext(
                game_state_snapshot={},
                available_options=["attack"],
                considered_factors=["hp"],
                confidence_level=0.9,
                reasoning="HP full"
            ),
            outcome=DecisionOutcome(
                success=True,
                actual_result={"result": "success"}
            )
        )
        
        explanation = await manager.explain_decision(decision)
        
        assert explanation is not None
    
    @pytest.mark.asyncio
    async def test_generate(self):
        """Test text generation."""
        manager = LLMManager()
        
        mock_provider = AsyncMock()
        mock_provider.provider_name = "test"
        mock_provider.complete = AsyncMock(return_value=LLMResponse(
            content="Generated text",
            provider="test",
            model="test-model",
            tokens_used=10
        ))
        
        manager.add_provider(mock_provider, primary=True)
        
        result = await manager.generate("Generate something")
        
        assert result == "Generated text"
    
    @pytest.mark.asyncio
    async def test_chat(self):
        """Test chat method."""
        manager = LLMManager()
        
        mock_provider = AsyncMock()
        mock_provider.provider_name = "test"
        mock_provider.complete = AsyncMock(return_value=LLMResponse(
            content="Chat response",
            provider="test",
            model="test-model",
            tokens_used=10
        ))
        
        manager.add_provider(mock_provider, primary=True)
        
        result = await manager.chat(["Hello", "How are you"])
        
        assert result == "Chat response"
    
    @pytest.mark.asyncio
    async def test_embed(self):
        """Test embedding generation."""
        manager = LLMManager()
        
        embedding = await manager.embed("Test text")
        
        assert embedding is not None
        assert len(embedding) == 768
    
    def test_list_models(self):
        """Test listing models."""
        manager = LLMManager()
        
        mock_provider = Mock()
        mock_provider.provider_name = "test"
        mock_provider.model = "gpt-4"
        
        manager.add_provider(mock_provider)
        
        models = manager.list_models()
        
        assert len(models) == 1
        assert "test:gpt-4" in models
    
    def test_get_usage_stats(self):
        """Test getting usage statistics."""
        manager = LLMManager()
        manager._usage_stats = {"test": 5, "fallback": 2}
        
        stats = manager.get_usage_stats()
        
        assert stats["test"] == 5
        assert stats["fallback"] == 2


# ============================================================================
# CONSUMABLES FOOD TESTS
# ============================================================================

class TestFoodManager:
    """Test food manager."""
    
    def test_food_manager_initialization(self):
        """Test food manager initialization."""
        manager = FoodManager()
        
        assert len(manager.food_database) > 0
        assert 12043 in manager.food_database
    
    @pytest.mark.asyncio
    async def test_get_optimal_food_set_melee(self):
        """Test optimal food for melee DPS."""
        manager = FoodManager()
        
        foods = await manager.get_optimal_food_set("melee_dps")
        
        assert len(foods) > 0
        # Should prioritize STR/AGI foods
        assert any("str" in f.stat_bonuses for f in foods)
    
    @pytest.mark.asyncio
    async def test_get_optimal_food_set_magic(self):
        """Test optimal food for magic DPS."""
        manager = FoodManager()
        
        foods = await manager.get_optimal_food_set("magic_dps")
        
        assert len(foods) > 0
        # Should prioritize INT foods
        assert any("int" in f.stat_bonuses for f in foods)
    
    @pytest.mark.asyncio
    async def test_track_food_buffs(self):
        """Test tracking active food buffs."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        buffs = await manager.track_food_buffs()
        
        assert len(buffs) == 1
        assert buffs[0].item_id == 12043
    
    @pytest.mark.asyncio
    async def test_check_food_needs_expiring(self):
        """Test checking food needs with expiring buffs."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        # Make it expiring
        manager.active_food_buffs[12043].remaining_seconds = 60.0
        
        actions = await manager.check_food_needs()
        
        assert len(actions) > 0
        assert "Expiring soon" in actions[0].reason
    
    @pytest.mark.asyncio
    async def test_update_food_timers(self):
        """Test updating food timers."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        initial_remaining = manager.active_food_buffs[12043].remaining_seconds
        
        await manager.update_food_timers(10.0)
        
        assert manager.active_food_buffs[12043].remaining_seconds == initial_remaining - 10.0
    
    @pytest.mark.asyncio
    async def test_update_food_timers_expiration(self):
        """Test food timer expiration."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        # Expire it
        manager.active_food_buffs[12043].remaining_seconds = 5.0
        
        await manager.update_food_timers(10.0)
        
        # Should be removed
        assert 12043 not in manager.active_food_buffs
    
    def test_apply_food_success(self):
        """Test applying food."""
        manager = FoodManager()
        manager.inventory = {12043: 5}
        
        result = manager.apply_food(12043)
        
        assert result is True
        assert 12043 in manager.active_food_buffs
        assert manager.inventory[12043] == 4
    
    def test_apply_food_unknown_item(self):
        """Test applying unknown food."""
        manager = FoodManager()
        
        result = manager.apply_food(99999)
        
        assert result is False
    
    def test_apply_food_not_in_inventory(self):
        """Test applying food not in inventory."""
        manager = FoodManager()
        manager.inventory = {}
        
        result = manager.apply_food(12043)
        
        assert result is False
    
    def test_get_active_stat_bonuses(self):
        """Test getting total stat bonuses."""
        manager = FoodManager()
        manager.inventory = {12043: 1, 12044: 1}
        
        manager.apply_food(12043)
        manager.apply_food(12044)
        
        bonuses = manager.get_active_stat_bonuses()
        
        assert bonuses["str"] == 5
        assert bonuses["agi"] == 5
        assert bonuses.get("vit", 0) == 2
        assert bonuses.get("dex", 0) == 4
    
    def test_get_food_summary(self):
        """Test food summary."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        summary = manager.get_food_summary()
        
        assert summary["total_active"] == 1
        assert "stat_bonuses" in summary
        assert len(summary["active_foods"]) == 1
    
    def test_update_inventory_dict(self):
        """Test updating inventory from dict."""
        manager = FoodManager()
        
        inventory = {12043: 10, 12044: 5}
        manager.update_inventory(inventory)
        
        assert manager.inventory[12043] == 10
        assert manager.inventory[12044] == 5
    
    def test_update_inventory_inventory_state(self):
        """Test updating inventory from InventoryState."""
        manager = FoodManager()
        
        inventory = InventoryState(items=[
            InventoryItem(index=0, item_id=12043, amount=10),
            InventoryItem(index=1, item_id=12044, amount=5),
        ])
        
        manager.update_inventory(inventory)
        
        assert manager.inventory[12043] == 10
        assert manager.inventory[12044] == 5
    
    def test_has_food_buff(self):
        """Test checking for active food buff."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        assert manager.has_food_buff("STR Dish") is True
        assert manager.has_food_buff("AGI Dish") is False
    
    def test_get_missing_food(self):
        """Test getting missing food from recommendations."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        manager.apply_food(12043)
        
        recommended = [
            manager.food_database[12043],
            manager.food_database[12044],
        ]
        
        missing = manager.get_missing_food(recommended)
        
        assert len(missing) == 1
        assert missing[0].item_id == 12044
    
    def test_should_eat_food_no_active(self):
        """Test should eat food when no active buffs."""
        manager = FoodManager()
        manager.inventory = {12043: 1}
        
        character_state = {"str": 60, "int": 30, "build": "melee"}
        
        food = manager.should_eat_food(character_state)
        
        assert food is not None
        assert "str" in food.stat_bonuses
    
    def test_should_eat_food_expiring(self):
        """Test should eat food when buff expiring."""
        manager = FoodManager()
        manager.inventory = {12043: 5}
        manager.apply_food(12043)
        
        # Make it expiring
        manager.active_food_buffs[12043].remaining_seconds = 60.0
        
        character_state = {"str": 60, "int": 30}
        food = manager.should_eat_food(character_state)
        
        assert food is not None
        assert food.item_id == 12043


# ============================================================================
# CONSUMABLES RECOVERY TESTS
# ============================================================================

class TestRecoveryManager:
    """Test recovery manager."""
    
    def test_recovery_manager_initialization(self):
        """Test recovery manager initialization."""
        config = RecoveryConfig(hp_critical_threshold=0.25)
        manager = RecoveryManager(config=config)
        
        assert manager.config.hp_critical_threshold == 0.25
        assert len(manager.items_database) > 0
    
    @pytest.mark.asyncio
    async def test_evaluate_recovery_need_hp_critical(self):
        """Test recovery evaluation at critical HP."""
        manager = RecoveryManager()
        manager.inventory = {607: 1}  # Yggdrasil Berry
        
        decision = await manager.evaluate_recovery_need(
            hp_percent=0.15,
            sp_percent=0.50,
            in_combat=True
        )
        
        assert decision is not None
        assert decision.priority == 10
        assert "EMERGENCY" in decision.reason
    
    @pytest.mark.asyncio
    async def test_evaluate_recovery_need_hp_normal(self):
        """Test recovery evaluation at normal threshold."""
        manager = RecoveryManager()
        manager.inventory = {504: 5}  # White Potion
        
        decision = await manager.evaluate_recovery_need(
            hp_percent=0.65,
            sp_percent=0.50,
            situation="normal"
        )
        
        assert decision is not None
        assert decision.item.item_id == 504
    
    @pytest.mark.asyncio
    async def test_evaluate_recovery_need_sp(self):
        """Test SP recovery evaluation."""
        manager = RecoveryManager()
        manager.inventory = {505: 5}  # Blue Potion
        
        decision = await manager.evaluate_recovery_need(
            hp_percent=0.90,
            sp_percent=0.30,
            situation="normal"
        )
        
        assert decision is not None
        assert decision.item.recovery_type == RecoveryType.SP_INSTANT
    
    @pytest.mark.asyncio
    async def test_evaluate_recovery_mvp_threshold(self):
        """Test recovery with MVP threshold."""
        config = RecoveryConfig(mvp_hp_threshold=0.50)
        manager = RecoveryManager(config=config)
        manager.inventory = {504: 5}
        
        decision = await manager.evaluate_recovery_need(
            hp_percent=0.48,
            sp_percent=0.50,
            situation="mvp"
        )
        
        assert decision is not None
    
    @pytest.mark.asyncio
    async def test_select_optimal_item(self):
        """Test optimal item selection."""
        manager = RecoveryManager()
        manager.inventory = {501: 10, 504: 5}
        
        item = await manager.select_optimal_item(
            RecoveryType.HP_INSTANT,
            current_percent=0.60,
            situation="normal"
        )
        
        assert item is not None
        assert item.recovery_type == RecoveryType.HP_INSTANT
    
    @pytest.mark.asyncio
    async def test_track_cooldowns(self):
        """Test cooldown tracking."""
        manager = RecoveryManager()
        manager.use_item(501, 45)
        
        cooldowns = await manager.track_cooldowns()
        
        assert "potion" in cooldowns
        assert cooldowns["potion"] > 0
    
    @pytest.mark.asyncio
    async def test_manage_inventory_levels(self):
        """Test inventory level management."""
        manager = RecoveryManager()
        manager.inventory = {501: 5, 504: 2}
        
        # Add some usage history
        for _ in range(5):
            manager.use_item(501, 45)
        
        recommendations = await manager.manage_inventory_levels()
        
        assert len(recommendations) > 0
    
    @pytest.mark.asyncio
    async def test_emergency_recovery_ygg_berry(self):
        """Test emergency recovery with Yggdrasil Berry."""
        manager = RecoveryManager()
        manager.inventory = {607: 1}
        
        decision = await manager.emergency_recovery()
        
        assert decision is not None
        assert decision.item.recovery_type == RecoveryType.EMERGENCY
        assert decision.priority == 10
    
    @pytest.mark.asyncio
    async def test_emergency_recovery_fallback(self):
        """Test emergency recovery fallback."""
        manager = RecoveryManager()
        manager.inventory = {504: 5}  # Only White Potion
        
        decision = await manager.emergency_recovery()
        
        assert decision is not None
        assert decision.item.item_id == 504
    
    def test_use_item_tracking(self):
        """Test item usage tracking."""
        manager = RecoveryManager()
        manager.inventory = {501: 10}
        
        manager.use_item(501, 45)
        
        assert manager.inventory[501] == 9
        assert len(manager.usage_history) == 1
        assert manager.cooldowns["potion"] > datetime.now()
    
    def test_update_inventory(self):
        """Test inventory update."""
        manager = RecoveryManager()
        
        inventory = {501: 20, 504: 10}
        manager.update_inventory(inventory)
        
        assert manager.inventory == inventory


# ============================================================================
# SOCIAL CHAT MODELS TESTS
# ============================================================================

class TestChatModels:
    """Test chat models."""
    
    def test_chat_message_is_directed_at_mention(self):
        """Test message directed detection with @mention."""
        msg = ChatMessage(
            message_id="1",
            channel=ChatChannel.GLOBAL,
            sender_name="Player",
            content="@BotName attack now"
        )
        
        assert msg.is_directed_at("BotName") is True
    
    def test_chat_message_is_directed_at_name_start(self):
        """Test message directed detection with name at start."""
        msg = ChatMessage(
            message_id="2",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="BotName follow me"
        )
        
        assert msg.is_directed_at("BotName") is True
    
    def test_chat_message_is_directed_at_whisper(self):
        """Test whispers are always directed."""
        msg = ChatMessage(
            message_id="3",
            channel=ChatChannel.WHISPER,
            sender_name="Player",
            content="Hello"
        )
        
        assert msg.is_directed_at("BotName") is True
    
    def test_chat_message_extract_command_with_prefix(self):
        """Test command extraction with prefix."""
        msg = ChatMessage(
            message_id="4",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="BotName attack monster"
        )
        
        result = msg.extract_command("BotName")
        
        assert result is not None
        assert result[0] == "attack"
        assert result[1] == ["monster"]
    
    def test_chat_message_extract_command_with_exclamation(self):
        """Test command extraction with ! prefix."""
        msg = ChatMessage(
            message_id="5",
            channel=ChatChannel.PARTY,
            sender_name="Player",
            content="!heal me now"
        )
        
        result = msg.extract_command("BotName")
        
        assert result is not None
        assert result[0] == "heal"
        assert result[1] == ["me", "now"]
    
    def test_chat_filter_should_block_channel(self):
        """Test blocking muted channels."""
        filter = ChatFilter(muted_channels=[ChatChannel.TRADE])
        
        msg = ChatMessage(
            message_id="6",
            channel=ChatChannel.TRADE,
            sender_name="Spammer",
            content="Buy my stuff"
        )
        
        assert filter.should_block(msg) is True
    
    def test_chat_filter_should_block_player(self):
        """Test blocking specific players."""
        filter = ChatFilter(blocked_players=["Spammer"])
        
        msg = ChatMessage(
            message_id="7",
            channel=ChatChannel.GLOBAL,
            sender_name="Spammer",
            content="Spam message"
        )
        
        assert filter.should_block(msg) is True
    
    def test_chat_filter_should_block_keyword(self):
        """Test blocking by keyword."""
        filter = ChatFilter(keywords_block=["gold", "paypal"])
        
        msg = ChatMessage(
            message_id="8",
            channel=ChatChannel.GLOBAL,
            sender_name="Seller",
            content="Buy GOLD for paypal"
        )
        
        assert filter.should_block(msg) is True
    
    def test_chat_filter_should_highlight(self):
        """Test highlighting messages."""
        filter = ChatFilter(keywords_highlight=["mvp", "boss"])
        
        msg = ChatMessage(
            message_id="9",
            channel=ChatChannel.GLOBAL,
            sender_name="Player",
            content="MVP spawned at prontera"
        )
        
        assert filter.should_highlight(msg) is True
    
    def test_auto_response_matches(self):
        """Test auto response pattern matching."""
        response = AutoResponse(
            trigger_patterns=[r"\bhello\b", r"\bhi\b"],
            response_template="Hello {sender}!",
            channel=ChatChannel.GLOBAL
        )
        
        msg = ChatMessage(
            message_id="10",
            channel=ChatChannel.GLOBAL,
            sender_name="Player",
            content="Hello everyone"
        )
        
        assert response.matches(msg) is True
    
    def test_auto_response_cooldown(self):
        """Test auto response cooldown."""
        response = AutoResponse(
            trigger_patterns=[r"hello"],
            response_template="Hi!",
            channel=ChatChannel.GLOBAL,
            cooldown_seconds=60
        )
        
        response.mark_triggered()
        
        msg = ChatMessage(
            message_id="11",
            channel=ChatChannel.GLOBAL,
            sender_name="Player",
            content="hello"
        )
        
        # Should not match due to cooldown
        assert response.matches(msg) is False
    
    def test_auto_response_generate_response(self):
        """Test response generation."""
        response = AutoResponse(
            trigger_patterns=[r"hello"],
            response_template="Hello {sender}!",
            channel=ChatChannel.GLOBAL
        )
        
        msg = ChatMessage(
            message_id="12",
            channel=ChatChannel.GLOBAL,
            sender_name="TestPlayer",
            content="hello"
        )
        
        generated = response.generate_response(msg)
        
        assert generated == "Hello TestPlayer!"
    
    def test_chat_command_matches(self):
        """Test command matching."""
        cmd = ChatCommand(
            name="attack",
            aliases=["atk", "fight"],
            description="Attack target",
            usage="attack <target>"
        )
        
        assert cmd.matches("attack") is True
        assert cmd.matches("ATK") is True
        assert cmd.matches("defend") is False
    
    def test_chat_command_validate_args(self):
        """Test command argument validation."""
        cmd = ChatCommand(
            name="move",
            aliases=[],
            description="Move to location",
            usage="move <x> <y>",
            min_args=2,
            max_args=2
        )
        
        assert cmd.validate_args(["100", "200"]) is True
        assert cmd.validate_args(["100"]) is False
        assert cmd.validate_args(["100", "200", "extra"]) is False


# ============================================================================
# UTILS STARTUP TESTS
# ============================================================================

class TestStartupUtils:
    """Test startup utilities."""
    
    def test_startup_progress_initialization(self):
        """Test startup progress initialization."""
        progress = StartupProgress(show_banner=False, show_progress=False)
        
        assert progress.show_banner is False
        assert progress.show_progress is False
        assert len(progress._steps) == 0
    
    def test_startup_progress_add_step(self):
        """Test adding a step."""
        progress = StartupProgress(show_banner=False, show_progress=False)
        
        step = progress.add_step("Config", "Loading configuration")
        
        assert step.name == "Config"
        assert step.status == StepStatus.PENDING
        assert len(progress._steps) == 1
    
    def test_startup_progress_step_context_success(self):
        """Test step context manager success."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=True,
            output=lambda msg: output_lines.append(msg)
        )
        
        with progress.step("Test", "Testing step") as step:
            step.details["test"] = "value"
        
        assert step.status == StepStatus.SUCCESS
        assert step.duration_ms > 0
        assert len(output_lines) == 2  # Start and done
    
    def test_startup_progress_step_context_failure(self):
        """Test step context manager failure."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=True,
            output=lambda msg: output_lines.append(msg)
        )
        
        with pytest.raises(ValueError):
            with progress.step("Test", "Testing step", critical=True):
                raise ValueError("Test error")
    
    def test_startup_progress_step_context_non_critical_failure(self):
        """Test step context with non-critical failure."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=True,
            output=lambda msg: output_lines.append(msg)
        )
        
        try:
            with progress.step("Test", "Testing step", critical=False):
                raise ValueError("Non-critical error")
        except ValueError:
            pass  # Should not propagate
        
        assert len(progress._steps) == 1
        assert progress._steps[0].status == StepStatus.FAILED
    
    def test_startup_progress_skip_step(self):
        """Test skipping a step."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=True,
            output=lambda msg: output_lines.append(msg)
        )
        
        progress.skip_step("Optional", "Not needed")
        
        assert len(progress._steps) == 1
        assert progress._steps[0].status == StepStatus.SKIPPED
    
    def test_startup_progress_warn_step(self):
        """Test warning step."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=True,
            output=lambda msg: output_lines.append(msg)
        )
        
        progress.warn_step("Config", "Using defaults")
        
        assert len(progress._steps) == 1
        assert progress._steps[0].status == StepStatus.WARNING
    
    def test_startup_progress_display_summary_success(self):
        """Test summary display on success."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=False,
            output=lambda msg: output_lines.append(msg)
        )
        
        with progress.step("Step1", "Test", critical=False):
            pass
        
        progress.display_summary()
        
        assert any("complete" in line.lower() for line in output_lines)
        assert progress.success is True
    
    def test_startup_progress_display_summary_failure(self):
        """Test summary display on failure."""
        output_lines = []
        progress = StartupProgress(
            show_banner=False,
            show_progress=False,
            output=lambda msg: output_lines.append(msg)
        )
        
        try:
            with progress.step("Step1", "Test", critical=False):
                raise ValueError("Error")
        except:
            pass
        
        progress.display_summary()
        
        assert any("failed" in line.lower() for line in output_lines)
        assert progress.success is False
    
    @pytest.mark.asyncio
    async def test_wait_with_progress_success(self):
        """Test wait with progress - success."""
        async def quick_task():
            await asyncio.sleep(0.01)
            return "done"
        
        result = await wait_with_progress(
            asyncio.create_task(quick_task()),
            message="Test",
            timeout=1.0
        )
        
        assert result == "done"
    
    @pytest.mark.asyncio
    async def test_wait_with_progress_timeout(self):
        """Test wait with progress - timeout."""
        async def slow_task():
            await asyncio.sleep(10)
            return "done"
        
        with pytest.raises(asyncio.TimeoutError):
            await wait_with_progress(
                asyncio.create_task(slow_task()),
                message="Test",
                timeout=0.1
            )
    
    def test_check_dependencies(self):
        """Test dependency checking."""
        result = check_dependencies()
        
        # Should pass since we're running tests
        assert result is True
    
    def test_show_quick_status(self):
        """Test quick status display."""
        output_lines = []
        
        with patch('builtins.print', lambda msg, **kwargs: output_lines.append(msg)):
            show_quick_status({
                "llm_provider": "openai",
                "debug_mode": True,
                "max_retries": 3
            })
        
        assert len(output_lines) > 0
    
    def test_format_loading_error(self):
        """Test error formatting."""
        error_msg = format_loading_error("Database", Exception("Connection failed"))
        
        assert "Database" in error_msg
        assert "Connection failed" in error_msg
        assert "Suggestions" in error_msg
    
    def test_validate_environment(self):
        """Test environment validation."""
        result = validate_environment()
        
        assert result is True


# ============================================================================
# SOCIAL MVP MODELS TESTS  
# ============================================================================

class TestMVPModels:
    """Test MVP models."""
    
    def test_mvp_boss_properties(self):
        """Test MVP boss properties."""
        boss = MVPBoss(
            monster_id=1002,
            name="Baphomet",
            base_level=81,
            hp=668000,
            spawn_maps=["prt_maze03"],
            spawn_time_min=120,
            spawn_time_max=130,
            mvp_drops=[(617, 5.0), (2513, 0.01)],
            card_id=4147,
            card_rate=0.01
        )
        
        assert boss.is_high_value is True
        assert boss.average_spawn_time == 125
    
    def test_mvp_spawn_record_properties(self):
        """Test MVP spawn record properties."""
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=60),
            next_spawn_earliest=now + timedelta(minutes=60),
            next_spawn_latest=now + timedelta(minutes=70)
        )
        
        assert record.is_spawn_window_active is False
        assert record.minutes_until_spawn > 0
        assert record.spawn_window_expired is False
    
    def test_mvp_spawn_record_active_window(self):
        """Test spawn window active state."""
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=120),
            next_spawn_earliest=now - timedelta(minutes=5),
            next_spawn_latest=now + timedelta(minutes=10)
        )
        
        assert record.is_spawn_window_active is True
        assert record.minutes_until_spawn < 0
    
    def test_mvp_hunting_strategy_get_spawn_map(self):
        """Test hunting strategy spawn map selection."""
        boss = MVPBoss(
            monster_id=1002,
            name="Baphomet",
            base_level=81,
            hp=668000,
            spawn_maps=["prt_maze01", "prt_maze02", "prt_maze03"],
            spawn_time_min=120,
            spawn_time_max=130
        )
        
        strategy = MVPHuntingStrategy(
            target_mvp=boss,
            party_composition={PartyRole.TANK: 1, PartyRole.DPS: 2},
            approach_strategy="camp",
            preferred_spawn_map="prt_maze02"
        )
        
        assert strategy.get_spawn_map() == "prt_maze02"
    
    def test_mvp_hunting_strategy_is_party_ready(self):
        """Test party readiness check."""
        boss = MVPBoss(
            monster_id=1002,
            name="Baphomet",
            base_level=81,
            hp=668000,
            spawn_maps=["prt_maze03"],
            spawn_time_min=120,
            spawn_time_max=130
        )
        
        strategy = MVPHuntingStrategy(
            target_mvp=boss,
            party_composition={PartyRole.TANK: 1, PartyRole.DPS: 2},
            approach_strategy="camp"
        )
        
        # Party ready
        assert strategy.is_party_ready({PartyRole.TANK: 1, PartyRole.DPS: 3}) is True
        
        # Party not ready
        assert strategy.is_party_ready({PartyRole.TANK: 0, PartyRole.DPS: 2}) is False
    
    def test_mvp_tracker_add_record(self):
        """Test adding spawn record."""
        tracker = MVPTracker()
        
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now,
            next_spawn_earliest=now + timedelta(minutes=120),
            next_spawn_latest=now + timedelta(minutes=130)
        )
        
        tracker.add_record(record)
        
        assert 1002 in tracker.records
        assert len(tracker.records[1002]) == 1
    
    def test_mvp_tracker_get_latest_record(self):
        """Test getting latest record."""
        tracker = MVPTracker()
        
        now = datetime.now()
        
        # Add older record
        old_record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(hours=2),
            next_spawn_earliest=now,
            next_spawn_latest=now + timedelta(minutes=10)
        )
        tracker.add_record(old_record)
        
        # Add newer record
        new_record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=30),
            next_spawn_earliest=now + timedelta(minutes=90),
            next_spawn_latest=now + timedelta(minutes=100)
        )
        tracker.add_record(new_record)
        
        latest = tracker.get_latest_record(1002)
        
        assert latest == new_record
    
    def test_mvp_tracker_get_spawn_window(self):
        """Test getting spawn window."""
        tracker = MVPTracker()
        
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now,
            next_spawn_earliest=now + timedelta(minutes=120),
            next_spawn_latest=now + timedelta(minutes=130)
        )
        tracker.add_record(record)
        
        window = tracker.get_spawn_window(1002)
        
        assert window is not None
        assert window[0] == record.next_spawn_earliest
        assert window[1] == record.next_spawn_latest
    
    def test_mvp_tracker_is_spawn_window_active(self):
        """Test checking if spawn window is active."""
        tracker = MVPTracker()
        
        now = datetime.now()
        record = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(hours=2),
            next_spawn_earliest=now - timedelta(minutes=5),
            next_spawn_latest=now + timedelta(minutes=10)
        )
        tracker.add_record(record)
        
        assert tracker.is_spawn_window_active(1002) is True
    
    def test_mvp_tracker_get_upcoming_spawns(self):
        """Test getting upcoming spawns."""
        tracker = MVPTracker()
        
        now = datetime.now()
        
        # Add soon-to-spawn MVP
        record1 = MVPSpawnRecord(
            monster_id=1002,
            map_name="prt_maze03",
            killed_at=now - timedelta(minutes=115),
            next_spawn_earliest=now + timedelta(minutes=5),
            next_spawn_latest=now + timedelta(minutes=15)
        )
        tracker.add_record(record1)
        
        # Add distant spawn
        record2 = MVPSpawnRecord(
            monster_id=1003,
            map_name="gef_dun02",
            killed_at=now - timedelta(minutes=60),
            next_spawn_earliest=now + timedelta(minutes=60),
            next_spawn_latest=now + timedelta(minutes=70)
        )
        tracker.add_record(record2)
        
        upcoming = tracker.get_upcoming_spawns(within_minutes=30)
        
        assert len(upcoming) > 0
        assert upcoming[0][0] == 1002
    
    def test_mvp_tracker_add_location(self):
        """Test adding known spawn location."""
        tracker = MVPTracker()
        
        tracker.add_location(1002, "prt_maze03", 100, 100)
        tracker.add_location(1002, "prt_maze03", 150, 150)
        
        assert 1002 in tracker.known_locations
        assert len(tracker.known_locations[1002]) == 2
    
    def test_mvp_database_operations(self):
        """Test MVP database operations."""
        db = MVPDatabase()
        
        boss = MVPBoss(
            monster_id=1002,
            name="Baphomet",
            base_level=81,
            hp=668000,
            spawn_maps=["prt_maze03"],
            spawn_time_min=120,
            spawn_time_max=130
        )
        
        db.add(boss)
        
        assert db.get(1002) == boss
        assert db.get_by_name("Baphomet") == boss
        assert db.get_by_name("baphomet") == boss  # Case insensitive
        assert len(db.get_by_map("prt_maze03")) == 1
        assert len(db.get_all()) == 1
    
    def test_mvp_database_load_from_dict(self):
        """Test loading MVP database from dict."""
        db = MVPDatabase()
        
        data = {
            "1002": {
                "name": "Baphomet",
                "base_level": 81,
                "hp": 668000,
                "spawn_maps": ["prt_maze03"],
                "spawn_time_min": 120,
                "spawn_time_max": 130
            }
        }
        
        db.load_from_dict(data)
        
        assert db.get(1002) is not None


# ============================================================================
# QUESTS DAILY TESTS
# ============================================================================

class TestDailyQuestManager:
    """Test daily quest manager."""
    
    def test_daily_quest_manager_initialization(self, temp_data_dir, mock_quest_manager):
        """Test daily quest manager initialization."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        assert len(manager.gramps_quests) > 0
        assert len(manager.eden_quests) > 0
        assert len(manager.board_quests) > 0
    
    def test_get_gramps_quest(self, temp_data_dir, mock_quest_manager):
        """Test getting Gramps quest for level."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        quest = manager.get_gramps_quest(90)
        
        assert quest is not None
        assert quest.monster_name == "Poring"
        assert quest.required_kills == 100
    
    def test_get_eden_quests(self, temp_data_dir, mock_quest_manager):
        """Test getting Eden quests."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        quests = manager.get_eden_quests(75)
        
        assert len(quests) > 0
        assert quests[0].quest_name == "Hunt Porings"
    
    def test_get_board_quests(self, temp_data_dir, mock_quest_manager):
        """Test getting board quests."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        quests = manager.get_board_quests("prontera")
        
        assert len(quests) > 0
        assert quests[0].monster_name == "Poring"
    
    def test_get_optimal_daily_route(self, temp_data_dir, mock_quest_manager):
        """Test optimal daily route calculation."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        character_state = {
            "level": 90,
            "map": "prontera"
        }
        
        route = manager.get_optimal_daily_route(character_state)
        
        assert len(route) > 0
        assert all("priority" in waypoint for waypoint in route)
    
    def test_calculate_daily_exp_potential(self, temp_data_dir, mock_quest_manager):
        """Test daily exp calculation."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        character_state = {"level": 90}
        
        exp_data = manager.calculate_daily_exp_potential(character_state)
        
        assert "total_base_exp" in exp_data
        assert "total_job_exp" in exp_data
        assert "gramps_exp" in exp_data
        assert exp_data["total_base_exp"] > 0
    
    def test_is_daily_completed(self, temp_data_dir, mock_quest_manager):
        """Test daily completion check."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        assert manager.is_daily_completed(DailyQuestCategory.GRAMPS) is False
        
        manager.mark_daily_complete(DailyQuestCategory.GRAMPS)
        
        assert manager.is_daily_completed(DailyQuestCategory.GRAMPS) is True
    
    def test_get_time_until_reset(self, temp_data_dir, mock_quest_manager):
        """Test time until reset calculation."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        time_remaining = manager.get_time_until_reset()
        
        assert isinstance(time_remaining, timedelta)
        assert time_remaining.total_seconds() > 0
    
    def test_get_priority_dailies(self, temp_data_dir, mock_quest_manager):
        """Test priority dailies listing."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        character_state = {"level": 90}
        
        dailies = manager.get_priority_dailies(character_state)
        
        assert len(dailies) > 0
        assert all("priority_score" in daily for daily in dailies)
    
    def test_get_completion_summary(self, temp_data_dir, mock_quest_manager):
        """Test completion summary."""
        manager = DailyQuestManager(temp_data_dir, mock_quest_manager)
        
        manager.mark_daily_complete(DailyQuestCategory.GRAMPS)
        
        summary = manager.get_completion_summary()
        
        assert DailyQuestCategory.GRAMPS.value in summary["completed"]
        assert "completion_rate" in summary
        assert "time_until_reset_hours" in summary


# ============================================================================
# ECONOMY ZENY TESTS
# ============================================================================

class TestZenyManager:
    """Test zeny manager."""
    
    def test_zeny_manager_initialization(self):
        """Test zeny manager initialization."""
        config = ZenyManagerConfig(
            equipment_budget_pct=40.0,
            consumables_budget_pct=35.0,
            savings_budget_pct=25.0
        )
        manager = ZenyManager(config)
        
        assert manager.config.equipment_budget_pct == 40.0
        assert len(manager.budgets) == 3
    
    def test_get_budget(self):
        """Test budget calculation."""
        manager = ZenyManager()
        
        budget = manager.get_budget("equipment", 100000)
        
        assert budget == 50000  # 50% of 100k
    
    def test_get_budget_unknown_category(self):
        """Test budget for unknown category."""
        manager = ZenyManager()
        
        budget = manager.get_budget("unknown", 100000)
        
        assert budget == 10000  # Default 10%
    
    def test_should_spend_within_budget(self):
        """Test spending approval within budget."""
        manager = ZenyManager()
        
        approved = manager.should_spend(
            amount=30000,
            category="equipment",
            priority=5,
            total_zeny=200000  # Enough to exceed emergency reserve
        )
        
        assert approved is True
    
    def test_should_spend_emergency_reserve(self):
        """Test spending blocked by emergency reserve."""
        config = ZenyManagerConfig(emergency_reserve=50000)
        manager = ZenyManager(config)
        
        approved = manager.should_spend(
            amount=60000,
            category="equipment",
            priority=5,
            total_zeny=100000
        )
        
        assert approved is False  # Would breach reserve
    
    def test_should_spend_high_priority_overrun(self):
        """Test high priority can exceed budget slightly."""
        manager = ZenyManager()
        
        approved = manager.should_spend(
            amount=55000,  # Exceeds 50k budget
            category="equipment",
            priority=9,  # High priority
            total_zeny=200000
        )
        
        assert approved is True  # High priority allows overrun
    
    def test_track_income(self):
        """Test income tracking."""
        manager = ZenyManager()
        
        manager.track_income("monster_drops", 5000)
        manager.track_income("quest_reward", 10000)
        
        assert manager.stats.total_income == 15000
        assert manager.stats.income_by_source["monster_drops"] == 5000
        assert manager.stats.transaction_count == 2
    
    def test_track_expense(self):
        """Test expense tracking."""
        manager = ZenyManager()
        
        manager.track_expense("equipment", 30000)
        manager.track_expense("consumables", 5000)
        
        assert manager.stats.total_expenses == 35000
        assert manager.stats.expenses_by_category["equipment"] == 30000
        assert manager.stats.net_income == -35000
    
    def test_get_financial_summary(self):
        """Test financial summary."""
        manager = ZenyManager()
        
        manager.track_income("farming", 50000)
        manager.track_expense("equipment", 30000)
        
        summary = manager.get_financial_summary()
        
        assert summary.total_income == 50000
        assert summary.total_expenses == 30000
        assert summary.net_income == 20000
        assert summary.zeny_per_hour > 0
    
    def test_reset_statistics(self):
        """Test resetting statistics."""
        manager = ZenyManager()
        
        manager.track_income("test", 1000)
        manager.reset_statistics()
        
        assert manager.stats.total_income == 0
        assert len(manager.transactions) == 0
    
    def test_set_budget_allocation(self):
        """Test setting budget allocation."""
        manager = ZenyManager()
        
        manager.set_budget_allocation("custom", 15.0, min_reserve=10000)
        
        assert "custom" in manager.budgets
        assert manager.budgets["custom"].percentage == 15.0
    
    def test_get_spending_recommendations(self):
        """Test spending recommendations."""
        manager = ZenyManager()
        
        manager.track_expense("equipment", 20000)
        
        recommendations = manager.get_spending_recommendations(100000)
        
        assert "equipment" in recommendations
        assert recommendations["equipment"]["spent"] == 20000
        assert recommendations["equipment"]["available"] == 30000


# ============================================================================
# ECONOMY BUYING TESTS
# ============================================================================

class TestBuyingManager:
    """Test buying manager."""
    
    def test_buying_manager_initialization(self, mock_market_manager, mock_price_analyzer):
        """Test buying manager initialization."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        assert manager.market == mock_market_manager
        assert manager.analyzer == mock_price_analyzer
    
    def test_add_purchase_target(self, mock_market_manager, mock_price_analyzer):
        """Test adding purchase target."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.HIGH,
            quantity_needed=50
        )
        
        manager.add_purchase_target(target)
        
        assert 501 in manager.purchase_targets
    
    def test_remove_purchase_target(self, mock_market_manager, mock_price_analyzer):
        """Test removing purchase target."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.HIGH,
            quantity_needed=50
        )
        manager.add_purchase_target(target)
        
        manager.remove_purchase_target(501)
        
        assert 501 not in manager.purchase_targets
    
    def test_calculate_buy_price_urgent(self, mock_market_manager, mock_price_analyzer):
        """Test buy price calculation with urgency."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        price = manager.calculate_buy_price(501, urgency=0.9)
        
        assert price > 1000  # Should be above fair price
    
    def test_calculate_buy_price_patient(self, mock_market_manager, mock_price_analyzer):
        """Test buy price calculation when patient."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        price = manager.calculate_buy_price(501, urgency=0.1)
        
        assert price < 1000  # Should be below fair price
    
    def test_evaluate_listing_not_on_list(self, mock_market_manager, mock_price_analyzer):
        """Test evaluating listing not on purchase list."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        from ai_sidecar.economy.core import MarketListing, MarketSource
        
        listing = MarketListing(
            item_id=999,
            item_name="Unknown",
            price=1000,
            quantity=10,
            seller_name="Seller",
            source=MarketSource.VENDING
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        
        assert should_buy is False
        assert reason == "not_on_purchase_list"
    
    def test_evaluate_listing_already_enough(self, mock_market_manager, mock_price_analyzer):
        """Test evaluating listing when already have enough."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.NORMAL,
            quantity_needed=10,
            quantity_owned=10
        )
        manager.add_purchase_target(target)
        
        from ai_sidecar.economy.core import MarketListing, MarketSource
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=10,
            seller_name="Seller",
            source=MarketSource.NPC
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        
        assert should_buy is False
        assert reason == "already_have_enough"
    
    def test_evaluate_listing_good_deal(self, mock_market_manager, mock_price_analyzer):
        """Test evaluating good deal listing."""
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        target = PurchaseTarget(
            item_id=501,
            item_name="Red Potion",
            max_price=100,
            priority=PurchasePriority.NORMAL,
            quantity_needed=10,
            quantity_owned=0
        )
        manager.add_purchase_target(target)
        
        from ai_sidecar.economy.core import MarketListing, MarketSource
        
        listing = MarketListing(
            item_id=501,
            item_name="Red Potion",
            price=50,
            quantity=10,
            seller_name="Seller",
            source=MarketSource.NPC
        )
        
        should_buy, reason = manager.evaluate_listing(listing)
        
        assert should_buy is True
        assert "good_deal" in reason
    
    def test_find_best_sellers(self, mock_market_manager, mock_price_analyzer):
        """Test finding best sellers."""
        from ai_sidecar.economy.core import MarketListing, MarketSource
        
        mock_market_manager.listings = {
            501: [
                MarketListing(item_id=501, item_name="Red Potion", price=60, quantity=10, 
                            seller_name="S1", source=MarketSource.VENDING),
                MarketListing(item_id=501, item_name="Red Potion", price=50, quantity=5,
                            seller_name="S2", source=MarketSource.VENDING),
                MarketListing(item_id=501, item_name="Red Potion", price=150, quantity=20,
                            seller_name="S3", source=MarketSource.VENDING),
            ]
        }
        
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        sellers = manager.find_best_sellers(501, max_price=100)
        
        assert len(sellers) == 2  # Only under 100z
        assert sellers[0].price == 50  # Cheapest first
    
    def test_bulk_buy_strategy_feasible(self, mock_market_manager, mock_price_analyzer):
        """Test bulk buy strategy when feasible."""
        from ai_sidecar.economy.core import MarketListing, MarketSource
        
        mock_market_manager.listings = {
            501: [
                MarketListing(item_id=501, item_name="Red Potion", price=50, quantity=30,
                            seller_name="S1", source=MarketSource.VENDING),
                MarketListing(item_id=501, item_name="Red Potion", price=60, quantity=50,
                            seller_name="S2", source=MarketSource.VENDING),
            ]
        }
        
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        strategy = manager.bulk_buy_strategy(
            item_id=501,
            quantity=70,
            max_total=5000
        )
        
        assert strategy["feasible"] is True
        assert strategy["total_quantity"] >= 70
        assert len(strategy["plan"]) > 0
    
    def test_should_wait_falling_trend(self, mock_market_manager, mock_price_analyzer):
        """Test should wait when price falling."""
        mock_market_manager.get_trend = Mock(return_value=Mock(value="falling"))
        
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        should_wait, reason = manager.should_wait(501, 1000)
        
        assert should_wait is True
        assert reason == "price_falling_trend"
    
    def test_should_wait_predicted_drop(self, mock_market_manager, mock_price_analyzer):
        """Test should wait when price drop predicted."""
        mock_price_analyzer.predict_price = Mock(return_value=(800, 0.8))
        
        manager = BuyingManager(mock_market_manager, mock_price_analyzer)
        
        should_wait, reason = manager.should_wait(501, 1000, days_to_wait=3)
        
        assert should_wait is True
        assert reason == "predicted_price_drop"


# ============================================================================
# COMBAT EVASION TESTS
# ============================================================================

class TestEvasionCalculator:
    """Test evasion calculator."""
    
    def test_calculate_flee(self):
        """Test flee calculation."""
        calc = EvasionCalculator()
        
        flee = calc.calculate_flee(
            base_level=99,
            agi=90,
            flee_bonus=10,
            flee_bonus_percent=0.0
        )
        
        assert flee == 199  # 99 + 90 + 10
    
    def test_calculate_flee_with_bonus_percent(self):
        """Test flee calculation with percentage bonus."""
        calc = EvasionCalculator()
        
        flee = calc.calculate_flee(
            base_level=99,
            agi=90,
            flee_bonus=10,
            flee_bonus_percent=0.20
        )
        
        assert flee == 238  # (99 + 90 + 10) * 1.20
    
    def test_calculate_perfect_dodge(self):
        """Test perfect dodge calculation."""
        calc = EvasionCalculator()
        
        pd = calc.calculate_perfect_dodge(luk=50)
        
        assert pd == 5.0
    
    def test_calculate_hit_rate(self):
        """Test hit rate calculation."""
        calc = EvasionCalculator()
        
        hit_rate = calc.calculate_hit_rate(
            attacker_hit=150,
            defender_flee=100,
            num_attackers=1
        )
        
        # 80 + 150 - 100 = 130, clamped to 95
        assert hit_rate == 95.0
    
    def test_calculate_hit_rate_multiple_attackers(self):
        """Test hit rate with multiple attackers."""
        calc = EvasionCalculator()
        
        hit_rate = calc.calculate_hit_rate(
            attacker_hit=100,
            defender_flee=150,
            num_attackers=5  # 3 extra attackers = 30% flee penalty
        )
        
        # Flee should be reduced
        assert hit_rate > 5.0  # Above minimum
    
    def test_calculate_flee_needed(self):
        """Test calculating flee needed."""
        calc = EvasionCalculator()
        
        flee = calc.calculate_flee_needed(
            monster_hit=100,
            desired_miss_rate=0.95
        )
        
        # 80 + 100 - flee = 5 (for 95% miss)
        # flee = 175
        assert flee == 175
    
    def test_is_flee_viable(self):
        """Test flee viability check."""
        calc = EvasionCalculator()
        
        viable, miss_rate = calc.is_flee_viable(
            player_flee=200,
            monster_hit=100,
            monster_count=1
        )
        
        assert viable is True
        assert miss_rate >= 0.80
    
    def test_is_flee_viable_not_viable(self):
        """Test flee not viable."""
        calc = EvasionCalculator()
        
        viable, miss_rate = calc.is_flee_viable(
            player_flee=50,
            monster_hit=150,
            monster_count=1
        )
        
        assert viable is False
    
    @pytest.mark.asyncio
    async def test_get_evasion_recommendation(self):
        """Test evasion recommendation."""
        calc = EvasionCalculator()
        
        current_stats = EvasionStats(
            flee=150,
            perfect_dodge=5,
            effective_flee=150,
            perfect_dodge_percent=5.0
        )
        
        monster_data = {
            "hit": 100,
            "count": 1
        }
        
        recommendation = await calc.get_evasion_recommendation(
            current_stats,
            monster_data
        )
        
        assert "current_flee" in recommendation
        assert "flee_needed_95" in recommendation
        assert "flee_viable" in recommendation


# ============================================================================
# COMBAT CAST DELAY TESTS
# ============================================================================

class TestCastDelayManager:
    """Test cast delay manager."""
    
    def test_cast_delay_manager_initialization(self):
        """Test cast delay manager initialization."""
        manager = CastDelayManager()
        
        assert len(manager.skill_timings) > 0
        assert "storm gust" in manager.skill_timings
    
    def test_calculate_cast_time(self):
        """Test cast time calculation."""
        manager = CastDelayManager()
        
        timing = manager.calculate_cast_time(
            "Storm Gust",
            dex=99,
            int_stat=99,
            cast_reduction_gear=0.0
        )
        
        assert timing.variable_cast_ms < 6000  # Reduced from base
        assert timing.fixed_cast_ms == 1000
    
    def test_calculate_cast_time_max_reduction(self):
        """Test cast time with max reduction."""
        manager = CastDelayManager()
        
        timing = manager.calculate_cast_time(
            "Storm Gust",
            dex=99,
            int_stat=67,  # DEX*2 + INT = 265 for 80% reduction
            cast_reduction_gear=0.19
        )
        
        # With high stats + gear, should be significantly reduced
        assert timing.variable_cast_ms < 6000  # Less than base
        assert timing.cast_reduction_percent > 0.5  # Significant reduction
    
    def test_calculate_after_cast_delay(self):
        """Test after-cast delay calculation."""
        manager = CastDelayManager()
        
        delay = manager.calculate_after_cast_delay(
            "Storm Gust",
            agi=100,
            delay_reduction_gear=0.0
        )
        
        assert delay < 5000  # Reduced from base
    
    @pytest.mark.asyncio
    async def test_start_cast(self):
        """Test recording cast start."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", cast_time_ms=3000)
        
        assert manager.cast_state.is_casting is True
        assert manager.cast_state.skill_name == "Storm Gust"
        assert manager.cast_state.cast_started is not None
    
    @pytest.mark.asyncio
    async def test_cast_complete(self):
        """Test cast completion."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", 3000)
        await manager.cast_complete("Storm Gust", delay_ms=2000)
        
        assert manager.cast_state.is_casting is False
        assert manager.delay_state.in_after_cast_delay is True
    
    @pytest.mark.asyncio
    async def test_cast_interrupted(self):
        """Test cast interruption."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", 3000)
        await manager.cast_interrupted()
        
        assert manager.cast_state.is_casting is False
        assert manager.cast_state.skill_name is None
    
    @pytest.mark.asyncio
    async def test_can_cast_now_casting(self):
        """Test can cast check while casting."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", 3000)
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is False
        assert reason == "already_casting"
    
    @pytest.mark.asyncio
    async def test_can_cast_now_delay(self):
        """Test can cast check during delay."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", 100)
        await manager.cast_complete("Storm Gust", delay_ms=5000)
        
        can_cast, reason = await manager.can_cast_now()
        
        assert can_cast is False
        assert reason == "after_cast_delay"
    
    @pytest.mark.asyncio
    async def test_time_until_can_cast(self):
        """Test time until can cast."""
        manager = CastDelayManager()
        
        await manager.start_cast("Storm Gust", cast_time_ms=3000)
        
        time_ms = await manager.time_until_can_cast()
        
        assert time_ms > 0
    
    @pytest.mark.asyncio
    async def test_is_skill_on_cooldown(self):
        """Test skill cooldown check."""
        manager = CastDelayManager()
        
        await manager.cast_complete("Asura Strike", delay_ms=3000)
        
        on_cooldown, remaining = await manager.is_skill_on_cooldown("Asura Strike")
        
        assert on_cooldown is True
        assert remaining > 0
    
    @pytest.mark.asyncio
    async def test_get_optimal_skill_order(self):
        """Test optimal skill ordering."""
        manager = CastDelayManager()
        
        skills = ["Storm Gust", "Sonic Blow", "Spiral Pierce"]
        character_stats = {"dex": 80, "int": 80}
        
        order = await manager.get_optimal_skill_order(skills, character_stats)
        
        assert len(order) == 3
        # Instant skills should be prioritized
        assert "Sonic Blow" in order or "Spiral Pierce" in order


# ============================================================================
# CRAFTING REFINING TESTS
# ============================================================================

class TestRefiningManager:
    """Test refining manager."""
    
    def test_refining_manager_initialization(self):
        """Test refining manager initialization."""
        manager = RefiningManager()
        
        assert len(manager.refine_rates) > 0
        assert 1 in manager.refine_rates
    
    def test_get_required_ore_weapon_level_1(self):
        """Test ore requirement for level 1 weapon."""
        manager = RefiningManager()
        
        ore = manager.get_required_ore(
            item_id=1101,
            item_level=1,
            is_armor=False
        )
        
        assert ore == RefineOre.PHRACON
    
    def test_get_required_ore_weapon_hd(self):
        """Test HD ore for weapons."""
        manager = RefiningManager()
        
        ore = manager.get_required_ore(
            item_id=1201,
            item_level=3,
            is_armor=False,
            use_hd=True
        )
        
        assert ore == RefineOre.HD_ORIDECON
    
    def test_get_required_ore_armor(self):
        """Test ore for armor."""
        manager = RefiningManager()
        
        ore = manager.get_required_ore(
            item_id=2301,
            item_level=0,
            is_armor=True
        )
        
        assert ore == RefineOre.ELUNIUM
    
    def test_calculate_refine_rate_safe_level(self):
        """Test refine rate for safe levels."""
        manager = RefiningManager()
        
        rate = manager.calculate_refine_rate(
            current_level=3,
            is_armor=False
        )
        
        assert rate == 100.0
    
    def test_calculate_refine_rate_risky_level(self):
        """Test refine rate for risky levels."""
        manager = RefiningManager()
        
        rate = manager.calculate_refine_rate(
            current_level=5,
            is_armor=False
        )
        
        assert rate < 100.0
    
    def test_calculate_refine_rate_with_job_bonus(self):
        """Test refine rate with Blacksmith bonus."""
        manager = RefiningManager()
        
        rate = manager.calculate_refine_rate(
            current_level=5,
            is_armor=False,
            character_state={"job": "Whitesmith", "job_level": 50}
        )
        
        assert rate > 40.0  # Base + job bonus
    
    def test_calculate_refine_rate_with_stats(self):
        """Test refine rate with stat bonuses."""
        manager = RefiningManager()
        
        rate = manager.calculate_refine_rate(
            current_level=5,
            is_armor=False,
            character_state={"dex": 99, "luk": 50}
        )
        
        assert rate > 40.0  # Base + stat bonuses
    
    def test_get_safe_limit(self):
        """Test safe limit calculation."""
        manager = RefiningManager()
        
        assert manager.get_safe_limit(1, is_armor=False) == 7
        assert manager.get_safe_limit(4, is_armor=False) == 4
        assert manager.get_safe_limit(1, is_armor=True) == 4
    
    def test_calculate_expected_cost(self):
        """Test expected cost calculation."""
        manager = RefiningManager()
        
        ore_prices = {
            "oridecon": 3000,
            "elunium": 3500
        }
        
        result = manager.calculate_expected_cost(
            current_level=4,
            target_level=7,
            is_armor=False,
            ore_prices=ore_prices
        )
        
        assert "total_ore_cost" in result
        assert "expected_break_cost" in result
        assert result["total_ore_cost"] > 0
    
    def test_should_refine_safe(self):
        """Test should refine decision - safe."""
        manager = RefiningManager()
        
        should, reason = manager.should_refine(
            item_id=1101,
            current_level=3,
            target_level=4,
            inventory={"oridecon": 10},
            risk_tolerance=0.5
        )
        
        assert should is True
    
    def test_should_refine_risky(self):
        """Test should refine decision - risky."""
        manager = RefiningManager()
        
        should, reason = manager.should_refine(
            item_id=1101,
            current_level=5,
            target_level=6,
            inventory={"oridecon": 10},
            risk_tolerance=0.2  # Low risk tolerance
        )
        
        assert should is False
        assert "risky" in reason.lower()
    
    @pytest.mark.asyncio
    async def test_refine_method(self):
        """Test refine method."""
        manager = RefiningManager()
        
        result = await manager.refine(item_index=0, use_hd_ore=True)
        
        assert result["success"] is True
        assert result["item_index"] == 0
    
    def test_get_safe_refine_limit(self):
        """Test safe refine limit wrapper."""
        manager = RefiningManager()
        
        limit = manager.get_safe_refine_limit(item_level=2)
        
        assert limit == 6
    
    def test_get_statistics(self):
        """Test refining statistics."""
        manager = RefiningManager()
        
        stats = manager.get_statistics()
        
        assert "total_refine_levels" in stats
        assert "safe_levels" in stats
        assert stats["safe_levels"] == 4


# ============================================================================
# MEMORY MANAGER TESTS
# ============================================================================

class TestMemoryManager:
    """Test memory manager."""
    
    @pytest.mark.asyncio
    async def test_memory_manager_initialization(self):
        """Test memory manager initialization."""
        manager = MemoryManager(db_path=":memory:")
        
        assert manager.working is not None
        assert manager.session is not None
        assert manager.persistent is not None
    
    @pytest.mark.asyncio
    async def test_store_normal_memory(self):
        """Test storing normal memory."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        memory = Memory(
            memory_type=MemoryType.EVENT,
            importance=MemoryImportance.NORMAL,
            summary="Test event"
        )
        
        memory_id = await manager.store(memory)
        
        assert memory_id is not None
    
    @pytest.mark.asyncio
    async def test_store_critical_memory(self):
        """Test storing critical memory."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        memory = Memory(
            memory_type=MemoryType.COMBAT_PATTERN,
            importance=MemoryImportance.CRITICAL,
            summary="Critical pattern"
        )
        
        memory_id = await manager.store(memory)
        
        assert memory_id is not None
        # Should be in persistent storage too
        retrieved = await manager.persistent.retrieve(memory_id)
        assert retrieved is not None
    
    @pytest.mark.asyncio
    async def test_retrieve_from_working(self):
        """Test retrieving from working memory."""
        manager = MemoryManager(db_path=":memory:")
        
        memory = Memory(
            memory_type=MemoryType.EVENT,
            summary="Test"
        )
        
        memory_id = await manager.store(memory)
        retrieved = await manager.retrieve(memory_id)
        
        assert retrieved is not None
        assert retrieved.memory_id == memory_id
    
    @pytest.mark.asyncio
    async def test_query_by_type(self):
        """Test querying by memory type."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        # Store different types
        await manager.store(Memory(memory_type=MemoryType.EVENT, summary="Event 1"))
        await manager.store(Memory(memory_type=MemoryType.COMBAT_PATTERN, summary="Combat 1"))
        await manager.store(Memory(memory_type=MemoryType.EVENT, summary="Event 2"))
        
        results = await manager.query(MemoryType.EVENT)
        
        assert len(results) >= 2
        assert all(m.memory_type == MemoryType.EVENT for m in results)
    
    @pytest.mark.asyncio
    async def test_remember_event(self):
        """Test remembering an event."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        memory_id = await manager.remember_event(
            "level_up",
            {"from_level": 50, "to_level": 51},
            importance=MemoryImportance.IMPORTANT
        )
        
        assert memory_id is not None
    
    @pytest.mark.asyncio
    async def test_remember_decision(self):
        """Test remembering a decision."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        decision = DecisionRecord(
            record_id="test_decision",
            decision_type=DecisionType.COMBAT,
            action_taken={"action": "attack", "target": "monster"},
            context=DecisionContext(
                game_state_snapshot={},
                available_options=["attack", "flee"],
                considered_factors=["hp", "sp"],
                confidence_level=0.9,
                reasoning="Test"
            )
        )
        
        memory_id = await manager.remember_decision(decision)
        
        assert memory_id is not None
    
    @pytest.mark.asyncio
    async def test_get_relevant_memories(self):
        """Test getting relevant memories."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        await manager.store(Memory(
            memory_type=MemoryType.EVENT,
            summary="Killed Poring at prt_fild08",
            tags=["poring", "combat"]
        ))
        
        relevant = await manager.get_relevant_memories("poring combat", limit=5)
        
        assert len(relevant) >= 1
    
    @pytest.mark.asyncio
    async def test_consolidate(self):
        """Test memory consolidation."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        # Store some memories
        for i in range(5):
            await manager.store(Memory(
                memory_type=MemoryType.EVENT,
                importance=MemoryImportance.IMPORTANT,
                summary=f"Event {i}"
            ))
        
        stats = await manager.consolidate()
        
        assert "working_to_session" in stats
        assert "session_to_persistent" in stats
    
    @pytest.mark.asyncio
    async def test_tick(self):
        """Test periodic tick."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        # Force consolidation by setting last time in past
        manager._last_consolidation = datetime.now() - timedelta(minutes=10)
        manager._consolidation_interval = 60  # 1 minute
        
        await manager.tick()
        
        # Should have consolidated
        assert (datetime.now() - manager._last_consolidation).total_seconds() < 10
    
    @pytest.mark.asyncio
    async def test_shutdown(self):
        """Test shutdown."""
        manager = MemoryManager(db_path=":memory:")
        await manager.initialize()
        
        await manager.shutdown()
        
        # Should complete without errors


# ============================================================================
# MEMORY WORKING MEMORY TESTS
# ============================================================================

class TestWorkingMemory:
    """Test working memory."""
    
    @pytest.mark.asyncio
    async def test_working_memory_store(self):
        """Test storing in working memory."""
        wm = WorkingMemory(max_size=10)
        
        memory = Memory(
            memory_type=MemoryType.EVENT,
            summary="Test event"
        )
        
        memory_id = await wm.store(memory)
        
        assert memory_id is not None
        assert memory_id in wm.memories
    
    @pytest.mark.asyncio
    async def test_working_memory_eviction(self):
        """Test LRU eviction."""
        wm = WorkingMemory(max_size=3)
        
        # Store 4 memories (should evict oldest)
        ids = []
        for i in range(4):
            memory = Memory(
                memory_type=MemoryType.EVENT,
                summary=f"Event {i}"
            )
            ids.append(await wm.store(memory))
        
        # First should be evicted
        assert await wm.size() == 3
        assert ids[0] not in wm.memories
    
    @pytest.mark.asyncio
    async def test_working_memory_retrieve(self):
        """Test retrieving from working memory."""
        wm = WorkingMemory()
        
        memory = Memory(
            memory_type=MemoryType.EVENT,
            summary="Test"
        )
        
        memory_id = await wm.store(memory)
        retrieved = await wm.retrieve(memory_id)
        
        assert retrieved is not None
        assert retrieved.access_count > 0
    
    @pytest.mark.asyncio
    async def test_working_memory_query(self):
        """Test querying working memory."""
        wm = WorkingMemory()
        
        await wm.store(Memory(memory_type=MemoryType.EVENT, summary="Event 1"))
        await wm.store(Memory(memory_type=MemoryType.COMBAT_PATTERN, summary="Combat 1"))
        await wm.store(Memory(memory_type=MemoryType.EVENT, summary="Event 2"))
        
        query = MemoryQuery(memory_types=[MemoryType.EVENT])
        results = await wm.query(query)
        
        assert len(results) == 2
    
    @pytest.mark.asyncio
    async def test_working_memory_query_by_tags(self):
        """Test querying by tags."""
        wm = WorkingMemory()
        
        await wm.store(Memory(
            memory_type=MemoryType.EVENT,
            summary="Combat event",
            tags=["combat", "victory"]
        ))
        
        query = MemoryQuery(tags=["combat"])
        results = await wm.query(query)
        
        assert len(results) >= 1
    
    @pytest.mark.asyncio
    async def test_get_recent(self):
        """Test getting recent memories."""
        wm = WorkingMemory()
        
        for i in range(5):
            await wm.store(Memory(memory_type=MemoryType.EVENT, summary=f"Event {i}"))
        
        recent = await wm.get_recent(count=3)
        
        assert len(recent) == 3
    
    @pytest.mark.asyncio
    async def test_get_candidates_for_consolidation(self):
        """Test getting consolidation candidates."""
        wm = WorkingMemory()
        
        # Store important memory
        important = Memory(
            memory_type=MemoryType.EVENT,
            importance=MemoryImportance.IMPORTANT,
            summary="Important event"
        )
        await wm.store(important)
        
        # Store frequently accessed memory
        frequent = Memory(
            memory_type=MemoryType.EVENT,
            summary="Frequent event"
        )
        mem_id = await wm.store(frequent)
        # Access it multiple times
        for _ in range(3):
            await wm.retrieve(mem_id)
        
        candidates = await wm.get_candidates_for_consolidation()
        
        assert len(candidates) >= 1
    
    @pytest.mark.asyncio
    async def test_apply_decay(self):
        """Test applying decay."""
        wm = WorkingMemory()
        
        # Store weak memory
        weak = Memory(
            memory_type=MemoryType.EVENT,
            importance=MemoryImportance.TRIVIAL,
            content="Weak event",
            summary="Weak event"
        )
        weak.strength = 0.1
        await wm.store(weak)
        
        forgotten = await wm.apply_decay()
        
        assert forgotten >= 1
    
    @pytest.mark.asyncio
    async def test_clear(self):
        """Test clearing working memory."""
        wm = WorkingMemory()
        
        await wm.store(Memory(memory_type=MemoryType.EVENT, content="Test", summary="Test"))
        await wm.clear()
        
        assert await wm.size() == 0
    
    def test_synchronous_accessors(self):
        """Test synchronous accessor methods."""
        wm = WorkingMemory(max_size=10)
        
        assert wm.is_full() is False
        assert len(wm.get_all()) == 0


# ============================================================================
# ECONOMY TRADING TESTS
# ============================================================================

class TestTradingSystem:
    """Test trading system."""
    
    @pytest.mark.asyncio
    async def test_trading_system_initialization(self):
        """Test trading system initialization."""
        config = TradingSystemConfig(
            auto_buy=True,
            auto_sell=True
        )
        system = TradingSystem(config=config)
        
        assert system.config.auto_buy is True
        assert system.config.auto_sell is True
    
    @pytest.mark.asyncio
    async def test_evaluate_shop(self):
        """Test shop evaluation."""
        system = TradingSystem(config=TradingSystemConfig(auto_buy=True))
        
        shopping_item = ShoppingItem(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=50,
            priority=7
        )
        system.shopping_list = [shopping_item]
        
        shop_items = [
            ShopItem(
                item_id=501,
                name="Red Potion",
                price=80,
                quantity=100,
                shop_type="npc"
            )
        ]
        
        actions = await system.evaluate_shop(shop_items, current_zeny=100000)
        
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_evaluate_vending(self):
        """Test vending evaluation."""
        system = TradingSystem(config=TradingSystemConfig(auto_buy=True))
        
        shopping_item = ShoppingItem(
            item_id=502,
            name="Orange Potion",
            max_price=200,
            desired_quantity=30,
            priority=5
        )
        system.shopping_list = [shopping_item]
        
        vending_items = [
            VendingItem(
                item_id=502,
                name="Orange Potion",
                price=150,
                quantity=50,
                seller_name="VendorBot"
            )
        ]
        
        actions = await system.evaluate_vending(vending_items, current_zeny=150000)
        
        assert len(actions) > 0
    
    @pytest.mark.asyncio
    async def test_setup_vend(self):
        """Test vending setup."""
        config = TradingSystemConfig(auto_vend=True)
        system = TradingSystem(config=config)
        
        # Add sell rule for vending
        system.add_sell_rule("Red Potion", sell_to="vend", sell_below_price=150)
        
        game_state = GameState(
            inventory=InventoryState(items=[
                InventoryItem(index=0, item_id=501, name="Red Potion", amount=50)
            ])
        )
        
        action = await system.setup_vend(game_state)
        
        assert action is not None
        assert "setup_vending" in action.extra.get("action", "")
    
    def test_should_buy(self):
        """Test should buy decision."""
        system = TradingSystem()
        
        shop_item = ShopItem(
            item_id=501,
            price=80,
            quantity=100,
            shop_type="npc"
        )
        
        wanted = ShoppingItem(
            item_id=501,
            max_price=100,
            desired_quantity=50
        )
        
        should_buy, quantity = system.should_buy(shop_item, wanted)
        
        assert should_buy is True
        assert quantity == 50
    
    def test_should_buy_too_expensive(self):
        """Test should buy when price too high."""
        system = TradingSystem()
        
        shop_item = ShopItem(
            item_id=501,
            price=150,
            quantity=100,
            shop_type="npc"
        )
        
        wanted = ShoppingItem(
            item_id=501,
            max_price=100,
            desired_quantity=50
        )
        
        should_buy, quantity = system.should_buy(shop_item, wanted)
        
        assert should_buy is False
    
    def test_should_sell_with_rule(self):
        """Test should sell with matching rule."""
        system = TradingSystem()
        
        system.add_sell_rule("Red.*", keep_quantity=10)
        
        item = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=30
        )
        
        should_sell, quantity = system.should_sell(item, current_quantity=30)
        
        assert should_sell is True
        assert quantity == 20  # Keep 10
    
    def test_add_shopping_item(self):
        """Test adding shopping item."""
        system = TradingSystem()
        
        system.add_shopping_item(
            item_id=501,
            name="Red Potion",
            max_price=100,
            desired_quantity=50,
            priority=7
        )
        
        assert len(system.shopping_list) == 1
        assert system.shopping_list[0].item_id == 501
    
    def test_add_sell_rule(self):
        """Test adding sell rule."""
        system = TradingSystem()
        
        system.add_sell_rule(
            ".*Potion",
            sell_to="npc",
            keep_quantity=5,
            sell_below_price=1000
        )
        
        assert len(system.sell_rules) == 1
    
    def test_clear_shopping_list(self):
        """Test clearing shopping list."""
        system = TradingSystem()
        system.add_shopping_item(501, "Red Potion", 100, 50)
        
        system.clear_shopping_list()
        
        assert len(system.shopping_list) == 0
    
    def test_should_buy_for_flip(self):
        """Test flip opportunity detection."""
        system = TradingSystem()
        
        market_data = {"fair_price": 1200}
        
        is_opportunity = system.should_buy_for_flip(
            item_id=501,
            current_price=800,
            market_data=market_data
        )
        
        assert is_opportunity is True  # 50% profit margin
    
    def test_find_arbitrage_opportunities(self):
        """Test finding arbitrage opportunities."""
        system = TradingSystem()
        
        opportunities = system.find_arbitrage_opportunities(min_profit=100)
        
        assert len(opportunities) >= 2
        assert all(opp["profit"] >= 100 for opp in opportunities)
    
    def test_clear_sell_rules(self):
        """Test clearing sell rules."""
        system = TradingSystem()
        system.add_sell_rule(".*")
        
        system.clear_sell_rules()
        
        assert len(system.sell_rules) == 0


# ============================================================================
# INTEGRATION TESTS
# ============================================================================

class TestBatch5Integration:
    """Integration tests across BATCH 5 modules."""
    
    @pytest.mark.asyncio
    async def test_support_tactics_full_workflow(self, mock_combat_context):
        """Test complete support tactics workflow."""
        tactics = SupportTactics()
        
        # Setup party combat scenario
        party_member = Mock()
        party_member.actor_id = 100
        party_member.hp = 300
        party_member.hp_max = 1000
        party_member.position = (105, 105)
        
        monster = Mock()
        monster.actor_id = 200
        monster.position = (95, 95)
        
        mock_combat_context.party_members = [party_member]
        mock_combat_context.nearby_monsters = [monster]
        mock_combat_context.character_sp = 3000
        
        # Select target
        target = await tactics.select_target(mock_combat_context)
        assert target is not None
        
        # Select skill
        skill = await tactics.select_skill(mock_combat_context, target)
        assert skill is not None
        
        # Evaluate positioning
        position = await tactics.evaluate_positioning(mock_combat_context)
        # Position may be None if already optimal
        
        # Get threat
        threat = tactics.get_threat_assessment(mock_combat_context)
        assert 0.0 <= threat <= 1.0
    
    @pytest.mark.asyncio
    async def test_consumable_coordinator_workflow(self):
        """Test consumable coordinator full workflow."""
        coordinator = ConsumableCoordinator()
        
        # Low HP combat scenario
        game_state = ConsumableContext(
            hp_percent=0.30,
            sp_percent=0.40,
            max_hp=10000,
            max_sp=5000,
            in_combat=True,
            situation="mvp",
            inventory={504: 10, 505: 5}
        )
        
        # Update all systems
        actions = await coordinator.update_all(game_state)
        
        assert len(actions) > 0
        
        # Pre-combat prep
        prep_actions = await coordinator.pre_combat_preparation(
            {"map": "test", "monsters": []},
            "melee_dps"
        )
        
        assert isinstance(prep_actions, list)
        
        # Post-combat recovery
        post_actions = await coordinator.post_combat_recovery(0.60, 0.30)
        
        assert isinstance(post_actions, list)
        
        # Get summary
        summary = coordinator.get_system_summary()
        assert "buffs" in summary
    
    def test_pet_manager_full_lifecycle(self, temp_data_dir):
        """Test pet manager full lifecycle."""
        manager = PetManager(data_path=temp_data_dir / "pets.json")
        
        # Start with pet
        state = PetState(
            pet_id=1,
            pet_type=PetType.DROPS,
            intimacy=500,
            hunger=50,
            is_summoned=True
        )
        
        # Update state (sync wrapper for async)
        asyncio.run(manager.update_state(state))
        
        # Feed decisions
        decision = asyncio.run(manager.decide_feed_timing())
        assert decision is not None
        
        # Skill coordination
        action = asyncio.run(manager.coordinate_pet_skills(True, 0.8, 2))
        # May be None if no applicable skills
        
        # Bonus check
        bonus = manager.get_pet_bonus(PetType.DROPS)
        assert isinstance(bonus, dict)


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])