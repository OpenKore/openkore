"""
Unit tests for equipment models and management.

Tests equipment comparison, slot management, refine calculations,
and equipment manager functionality.
"""

import pytest

from ai_sidecar.equipment.models import (
    CardSlot,
    Equipment,
    EquipmentLoadout,
    EquipSlot,
    WeaponType,
    get_refine_success_rate,
    calculate_refine_cost,
)
from ai_sidecar.equipment.manager import EquipmentManager, EquipmentManagerConfig


class TestEquipmentModels:
    """Test equipment data models."""
    
    def test_equipment_creation(self):
        """Test creating an equipment item."""
        equip = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            weapon_type=WeaponType.ONE_HAND_SWORD,
            atk=25,
            slots=3,
        )
        
        assert equip.item_id == 1101
        assert equip.name == "Sword"
        assert equip.slot == EquipSlot.WEAPON
        assert equip.atk == 25
        assert equip.refine == 0
    
    def test_equipment_refine_bonus(self):
        """Test refine bonus calculations."""
        weapon = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            atk=25,
            refine=7,
        )
        
        # Weapon refine adds to ATK
        assert weapon.total_atk == 32  # 25 + 7
        
        armor = Equipment(
            item_id=2315,
            name="Full Plate",
            slot=EquipSlot.ARMOR,
            defense=70,
            refine=7,
        )
        
        # Armor refine adds to DEF
        assert armor.total_defense == 77  # 70 + 7
    
    def test_card_slots(self):
        """Test card slot management."""
        equip = Equipment(
            item_id=1101,
            name="Sword",
            slot=EquipSlot.WEAPON,
            slots=3,
            cards=[
                CardSlot(slot_index=0, card_id=4054, card_name="Hydra Card"),
                CardSlot(slot_index=1),
                CardSlot(slot_index=2),
            ],
        )
        
        assert equip.slots == 3
        assert equip.card_count == 1
        assert equip.has_empty_slots
        assert not equip.is_fully_carded
    
    def test_equipment_loadout(self):
        """Test equipment loadout creation and management."""
        loadout = EquipmentLoadout(
            name="DPS Build",
            optimized_for="damage",
        )
        
        weapon = Equipment(
            item_id=1116,
            name="Katana",
            slot=EquipSlot.WEAPON,
            atk=60,
        )
        
        loadout.set_equipment(EquipSlot.WEAPON, weapon)
        
        retrieved = loadout.get_equipment_by_slot(EquipSlot.WEAPON)
        assert retrieved == weapon
        assert loadout.total_atk == 60


class TestRefineCalculations:
    """Test refine-related calculations."""
    
    def test_refine_success_rates_weapons(self):
        """Test weapon refine success rates."""
        # Safe refines (1-4)
        assert get_refine_success_rate(EquipSlot.WEAPON, 0, 4) == 1.0
        
        # Mid refines (5-7)
        assert get_refine_success_rate(EquipSlot.WEAPON, 6, 7) == 0.75
        
        # High refines (8-10)
        assert get_refine_success_rate(EquipSlot.WEAPON, 7, 8) == 0.50
        assert get_refine_success_rate(EquipSlot.WEAPON, 8, 9) == 0.30
        assert get_refine_success_rate(EquipSlot.WEAPON, 9, 10) == 0.20
    
    def test_refine_success_rates_armor(self):
        """Test armor refine success rates."""
        # Safe refines (1-7)
        assert get_refine_success_rate(EquipSlot.ARMOR, 0, 7) == 1.0
        
        # Mid refines (8-10)
        assert get_refine_success_rate(EquipSlot.ARMOR, 7, 8) == 0.75
        assert get_refine_success_rate(EquipSlot.ARMOR, 8, 9) == 0.50
        assert get_refine_success_rate(EquipSlot.ARMOR, 9, 10) == 0.30
    
    def test_multi_level_refine_probability(self):
        """Test cumulative probability for multi-level refining."""
        # Refining from +7 to +10 on weapon
        # Success = 0.50 * 0.30 * 0.20 = 0.03 (3%)
        prob = get_refine_success_rate(EquipSlot.WEAPON, 7, 10)
        assert pytest.approx(prob, 0.01) == 0.03
    
    def test_refine_cost_calculation(self):
        """Test zeny cost estimation for refining."""
        # Single level refine
        cost = calculate_refine_cost(0, 1, base_cost=2000)
        assert cost == 2000
        
        # Multi-level refine
        cost = calculate_refine_cost(0, 5, base_cost=2000)
        assert cost > 0


class TestEquipmentManager:
    """Test equipment manager functionality."""
    
    @pytest.fixture
    def manager(self):
        """Create equipment manager for testing."""
        config = EquipmentManagerConfig(
            auto_equip_better_gear=True,
            min_score_improvement=5.0,
        )
        return EquipmentManager(config=config)
    
    def test_manager_initialization(self, manager):
        """Test manager initializes correctly."""
        assert manager.config.auto_equip_better_gear
        assert manager.config.min_score_improvement == 5.0
    
    def test_set_build_type(self, manager):
        """Test setting build type."""
        manager.set_build_type("melee_dps")
        assert manager.build_type == "melee_dps"
    
    @pytest.mark.asyncio
    async def test_tick_returns_actions(self, manager):
        """Test that tick method returns action list."""
        from ai_sidecar.core.state import GameState
        
        game_state = GameState()
        actions = await manager.tick(game_state)
        
        assert isinstance(actions, list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])