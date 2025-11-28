"""
Unit tests for storage management.

Tests storage prioritization, inventory management,
and cart optimization.
"""

import pytest

from ai_sidecar.core.state import GameState, CharacterState, InventoryItem, InventoryState
from ai_sidecar.economy.storage import (
    StorageManager,
    StorageManagerConfig,
    ItemPriority,
)


class TestStorageManager:
    """Test storage manager functionality."""
    
    @pytest.fixture
    def manager(self):
        """Create storage manager for testing."""
        config = StorageManagerConfig(
            auto_storage=True,
            inventory_full_threshold=0.80,
            always_keep_items=[501, 502],  # Red/Orange potions
        )
        return StorageManager(config=config)
    
    def test_manager_initialization(self, manager):
        """Test manager initializes correctly."""
        assert manager.config.auto_storage
        assert manager.config.inventory_full_threshold == 0.80
    
    def test_inventory_priority_consumables(self, manager):
        """Test consumables get high priority."""
        potion = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=50,
        )
        
        priority = manager.calculate_inventory_priority(potion)
        
        # Consumables should have high priority (>= 50)
        assert priority >= 50.0
    
    def test_inventory_priority_equipped(self, manager):
        """Test equipped items get highest priority."""
        equipped = InventoryItem(
            index=0,
            item_id=1101,
            name="Sword",
            amount=1,
            equipped=True,
        )
        
        priority = manager.calculate_inventory_priority(equipped)
        
        # Equipped items should have maximum priority
        assert priority == 100.0
    
    def test_inventory_priority_etc_items(self, manager):
        """Test etc items get low priority."""
        etc_item = InventoryItem(
            index=0,
            item_id=909,
            name="Jellopy",
            amount=50,
            item_type="etc",
        )
        
        priority = manager.calculate_inventory_priority(etc_item)
        
        # Etc items should have lower priority
        assert priority < 50.0
    
    def test_always_keep_items(self, manager):
        """Test always-keep items get max priority."""
        item = InventoryItem(
            index=0,
            item_id=501,  # In always_keep_items list
            name="Red Potion",
            amount=10,
        )
        
        priority = manager.calculate_inventory_priority(item)
        
        assert priority == 100.0
    
    @pytest.mark.asyncio
    async def test_tick_returns_actions(self, manager):
        """Test that tick method returns action list."""
        # Create game state with inventory
        char_state = CharacterState(
            name="TestChar",
            weight=5000,
            weight_max=10000,
        )
        
        inventory = InventoryState(items=[])
        
        game_state = GameState(
            character=char_state,
            inventory=inventory,
        )
        
        actions = await manager.tick(game_state)
        
        assert isinstance(actions, list)
    
    def test_inventory_full_by_weight(self, manager):
        """Test inventory full detection by weight."""
        char_state = CharacterState(
            weight=8000,  # 80% of max
            weight_max=10000,
        )
        
        game_state = GameState(character=char_state)
        
        assert manager._inventory_full(game_state)
    
    def test_inventory_not_full(self, manager):
        """Test inventory not full detection."""
        char_state = CharacterState(
            weight=5000,  # 50% of max
            weight_max=10000,
        )
        
        inventory = InventoryState(items=[])
        
        game_state = GameState(
            character=char_state,
            inventory=inventory,
        )
        
        assert not manager._inventory_full(game_state)


class TestItemPriority:
    """Test item priority model."""
    
    def test_item_priority_creation(self):
        """Test creating item priority."""
        item = InventoryItem(
            index=0,
            item_id=501,
            name="Red Potion",
            amount=10,
        )
        
        priority = ItemPriority(
            item=item,
            priority_score=75.0,
            reason="Combat consumable",
        )
        
        assert priority.item == item
        assert priority.priority_score == 75.0
        assert priority.reason == "Combat consumable"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])