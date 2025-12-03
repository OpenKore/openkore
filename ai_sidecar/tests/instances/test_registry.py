"""
Comprehensive tests for Instance Registry system.

Tests cover:
- Instance definition models
- Registry initialization and loading
- Instance lookup by various criteria
- Requirement validation
- Recommended instance calculation
- Instance type and difficulty filtering
"""

import pytest
from pathlib import Path
from unittest.mock import Mock, patch, mock_open
import json

from ai_sidecar.instances.registry import (
    InstanceType,
    InstanceDifficulty,
    InstanceRequirement,
    InstanceReward,
    InstanceDefinition,
    InstanceRegistry
)


# Fixtures

@pytest.fixture
def sample_requirement():
    """Create sample instance requirement."""
    return InstanceRequirement(
        min_level=80,
        max_level=120,
        required_quest="Memorial Dungeon Access",
        min_party_size=1,
        max_party_size=12,
        guild_required=False,
        rebirth_required=True
    )


@pytest.fixture
def sample_reward():
    """Create sample instance reward."""
    return InstanceReward(
        guaranteed_items=["Old Purple Box", "Instance Coin"],
        chance_items={"Rare Card": 0.01, "MVP Card": 0.001},
        experience_base=1000000,
        experience_job=500000,
        zeny=50000,
        instance_points=100
    )


@pytest.fixture
def sample_instance():
    """Create sample instance definition."""
    return InstanceDefinition(
        instance_id="endless_tower",
        instance_name="Endless Tower",
        instance_type=InstanceType.ENDLESS_TOWER,
        difficulty=InstanceDifficulty.HARD,
        entry_npc="Tower Keeper",
        entry_map="alberta",
        entry_position=(100, 50),
        time_limit_minutes=240,
        cooldown_hours=168,
        floors=100,
        requirements=InstanceRequirement(min_level=50),
        rewards=InstanceReward(experience_base=5000000),
        boss_names=["Amon Ra", "Dark Lord", "Baphomet"],
        recommended_level=99,
        recommended_party_size=6,
        estimated_clear_time_minutes=180
    )


@pytest.fixture
def registry():
    """Create empty registry."""
    return InstanceRegistry()


@pytest.fixture
def populated_registry():
    """Create registry with sample instances."""
    registry = InstanceRegistry()
    
    # Add various instances
    registry.instances["endless_tower"] = InstanceDefinition(
        instance_id="endless_tower",
        instance_name="Endless Tower",
        instance_type=InstanceType.ENDLESS_TOWER,
        difficulty=InstanceDifficulty.HARD,
        entry_npc="Tower Keeper",
        entry_map="alberta",
        entry_position=(100, 50),
        requirements=InstanceRequirement(min_level=50),
        recommended_level=99
    )
    
    registry.instances["orc_memory"] = InstanceDefinition(
        instance_id="orc_memory",
        instance_name="Orc's Memory",
        instance_type=InstanceType.MEMORIAL_DUNGEON,
        difficulty=InstanceDifficulty.EASY,
        entry_npc="Orc Warrior",
        entry_map="geffen",
        entry_position=(120, 100),
        requirements=InstanceRequirement(min_level=30, max_level=80),
        recommended_level=50
    )
    
    registry.instances["nidhogg"] = InstanceDefinition(
        instance_id="nidhogg",
        instance_name="Nidhogg's Nest",
        instance_type=InstanceType.MEMORIAL_DUNGEON,
        difficulty=InstanceDifficulty.NIGHTMARE,
        entry_npc="Sage",
        entry_map="splendide",
        entry_position=(200, 150),
        requirements=InstanceRequirement(
            min_level=90,
            min_party_size=3,
            required_quest="Nidhogg Quest"
        ),
        recommended_level=120,
        recommended_party_size=6
    )
    
    return registry


# Model Tests

class TestInstanceTypeEnum:
    """Test InstanceType enum."""
    
    def test_all_types_defined(self):
        """Test all instance types are defined."""
        assert InstanceType.MEMORIAL_DUNGEON
        assert InstanceType.ENDLESS_TOWER
        assert InstanceType.GUILD_DUNGEON
        assert InstanceType.EVENT_INSTANCE
        assert InstanceType.PARTY_INSTANCE
        assert InstanceType.SOLO_INSTANCE
        assert InstanceType.INFINITE_DUNGEON


class TestInstanceDifficultyEnum:
    """Test InstanceDifficulty enum."""
    
    def test_all_difficulties_defined(self):
        """Test all difficulties are defined."""
        assert InstanceDifficulty.EASY
        assert InstanceDifficulty.NORMAL
        assert InstanceDifficulty.HARD
        assert InstanceDifficulty.NIGHTMARE
        assert InstanceDifficulty.HELL


class TestInstanceRequirement:
    """Test InstanceRequirement model."""
    
    def test_create_basic_requirement(self):
        """Test creating basic requirement."""
        req = InstanceRequirement(min_level=50)
        
        assert req.min_level == 50
        assert req.max_level is None
        assert req.min_party_size == 1
        assert req.max_party_size == 12
        assert req.guild_required is False
    
    def test_requirement_with_all_fields(self, sample_requirement):
        """Test requirement with all fields."""
        assert sample_requirement.min_level == 80
        assert sample_requirement.max_level == 120
        assert sample_requirement.required_quest == "Memorial Dungeon Access"
        assert sample_requirement.rebirth_required is True
    
    def test_requirement_immutable(self, sample_requirement):
        """Test requirement is frozen."""
        with pytest.raises(Exception):
            sample_requirement.min_level = 100
    
    def test_level_validation(self):
        """Test level must be in valid range."""
        with pytest.raises(Exception):
            InstanceRequirement(min_level=0)
        
        with pytest.raises(Exception):
            InstanceRequirement(min_level=1000)
    
    def test_party_size_validation(self):
        """Test party size validation."""
        req = InstanceRequirement(min_party_size=5, max_party_size=5)
        assert req.min_party_size == 5
        assert req.max_party_size == 5


class TestInstanceReward:
    """Test InstanceReward model."""
    
    def test_create_basic_reward(self):
        """Test creating basic reward."""
        reward = InstanceReward()
        
        assert reward.guaranteed_items == []
        assert reward.chance_items == {}
        assert reward.experience_base == 0
        assert reward.zeny == 0
    
    def test_reward_with_items(self, sample_reward):
        """Test reward with items."""
        assert len(sample_reward.guaranteed_items) == 2
        assert "Old Purple Box" in sample_reward.guaranteed_items
        assert "Rare Card" in sample_reward.chance_items
        assert sample_reward.chance_items["MVP Card"] == 0.001
    
    def test_reward_with_experience(self, sample_reward):
        """Test reward with experience."""
        assert sample_reward.experience_base == 1000000
        assert sample_reward.experience_job == 500000
    
    def test_reward_immutable(self, sample_reward):
        """Test reward is frozen."""
        with pytest.raises(Exception):
            sample_reward.zeny = 100000


class TestInstanceDefinition:
    """Test InstanceDefinition model."""
    
    def test_create_instance_definition(self, sample_instance):
        """Test creating instance definition."""
        assert sample_instance.instance_id == "endless_tower"
        assert sample_instance.instance_name == "Endless Tower"
        assert sample_instance.instance_type == InstanceType.ENDLESS_TOWER
        assert sample_instance.difficulty == InstanceDifficulty.HARD
    
    def test_instance_entry_info(self, sample_instance):
        """Test instance entry information."""
        assert sample_instance.entry_npc == "Tower Keeper"
        assert sample_instance.entry_map == "alberta"
        assert sample_instance.entry_position == (100, 50)
    
    def test_instance_mechanics(self, sample_instance):
        """Test instance mechanics."""
        assert sample_instance.time_limit_minutes == 240
        assert sample_instance.cooldown_hours == 168
        assert sample_instance.floors == 100
    
    def test_instance_boss_names(self, sample_instance):
        """Test boss names."""
        assert len(sample_instance.boss_names) == 3
        assert "Baphomet" in sample_instance.boss_names
    
    def test_instance_recommended_values(self, sample_instance):
        """Test recommended values."""
        assert sample_instance.recommended_level == 99
        assert sample_instance.recommended_party_size == 6
        assert sample_instance.estimated_clear_time_minutes == 180


# InstanceRegistry Tests

class TestRegistryInitialization:
    """Test registry initialization."""
    
    def test_create_empty_registry(self, registry):
        """Test creating empty registry."""
        assert registry.instances == {}
        assert registry.log is not None
    
    def test_registry_with_nonexistent_data_dir(self):
        """Test registry with non-existent data directory."""
        data_dir = Path("/nonexistent/path")
        registry = InstanceRegistry(data_dir=data_dir)
        
        # Should not crash, just log warning
        assert len(registry.instances) == 0


class TestGetInstance:
    """Test getting instance by ID."""
    
    @pytest.mark.asyncio
    async def test_get_existing_instance(self, populated_registry):
        """Test getting existing instance."""
        instance = await populated_registry.get_instance("endless_tower")
        
        assert instance is not None
        assert instance.instance_id == "endless_tower"
        assert instance.instance_name == "Endless Tower"
    
    @pytest.mark.asyncio
    async def test_get_nonexistent_instance(self, populated_registry):
        """Test getting non-existent instance."""
        instance = await populated_registry.get_instance("nonexistent")
        
        assert instance is None
    
    @pytest.mark.asyncio
    async def test_get_from_empty_registry(self, registry):
        """Test getting from empty registry."""
        instance = await registry.get_instance("any_id")
        
        assert instance is None


class TestFindInstancesByLevel:
    """Test finding instances by level."""
    
    @pytest.mark.asyncio
    async def test_find_by_level_basic(self, populated_registry):
        """Test finding instances for level."""
        instances = await populated_registry.find_instances_by_level(50)
        
        assert len(instances) > 0
        # Should find orc_memory (30-80, recommended 50)
        ids = [i.instance_id for i in instances]
        assert "orc_memory" in ids
    
    @pytest.mark.asyncio
    async def test_find_by_level_high_level(self, populated_registry):
        """Test finding instances for high level."""
        instances = await populated_registry.find_instances_by_level(120)
        
        # Should find nidhogg (90+, recommended 120)
        ids = [i.instance_id for i in instances]
        assert "nidhogg" in ids
    
    @pytest.mark.asyncio
    async def test_find_by_level_too_low(self, populated_registry):
        """Test finding with level too low."""
        instances = await populated_registry.find_instances_by_level(20)
        
        # Might find nothing or only very low level instances
        for instance in instances:
            assert instance.requirements.min_level <= 20
    
    @pytest.mark.asyncio
    async def test_find_sorted_by_proximity(self, populated_registry):
        """Test results sorted by level proximity."""
        instances = await populated_registry.find_instances_by_level(50)
        
        if len(instances) > 1:
            # Should be sorted by proximity to level 50
            first_diff = abs(instances[0].recommended_level - 50)
            second_diff = abs(instances[1].recommended_level - 50)
            assert first_diff <= second_diff


class TestFindInstancesByType:
    """Test finding instances by type."""
    
    @pytest.mark.asyncio
    async def test_find_by_memorial_dungeon_type(self, populated_registry):
        """Test finding memorial dungeons."""
        instances = await populated_registry.find_instances_by_type(
            InstanceType.MEMORIAL_DUNGEON
        )
        
        assert len(instances) >= 2
        ids = [i.instance_id for i in instances]
        assert "orc_memory" in ids
        assert "nidhogg" in ids
    
    @pytest.mark.asyncio
    async def test_find_by_endless_tower_type(self, populated_registry):
        """Test finding endless tower."""
        instances = await populated_registry.find_instances_by_type(
            InstanceType.ENDLESS_TOWER
        )
        
        assert len(instances) >= 1
        assert instances[0].instance_id == "endless_tower"
    
    @pytest.mark.asyncio
    async def test_find_by_nonexistent_type(self, populated_registry):
        """Test finding type that doesn't exist."""
        instances = await populated_registry.find_instances_by_type(
            InstanceType.GUILD_DUNGEON
        )
        
        assert len(instances) == 0


class TestCheckRequirements:
    """Test requirement checking."""
    
    @pytest.mark.asyncio
    async def test_check_requirements_pass(self, populated_registry):
        """Test checking requirements that pass."""
        character_state = {
            "base_level": 50,
            "party_size": 1
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "orc_memory",
            character_state
        )
        
        assert can_enter is True
        assert len(missing) == 0
    
    @pytest.mark.asyncio
    async def test_check_level_too_low(self, populated_registry):
        """Test checking with level too low."""
        character_state = {
            "base_level": 20,
            "party_size": 1
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "orc_memory",
            character_state
        )
        
        assert can_enter is False
        assert len(missing) > 0
        assert any("Level too low" in msg for msg in missing)
    
    @pytest.mark.asyncio
    async def test_check_level_too_high(self, populated_registry):
        """Test checking with level too high."""
        character_state = {
            "base_level": 100,
            "party_size": 1
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "orc_memory",
            character_state
        )
        
        assert can_enter is False
        assert any("Level too high" in msg for msg in missing)
    
    @pytest.mark.asyncio
    async def test_check_party_too_small(self, populated_registry):
        """Test checking with party too small."""
        character_state = {
            "base_level": 100,
            "party_size": 1
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "nidhogg",
            character_state
        )
        
        assert can_enter is False
        assert any("Party too small" in msg for msg in missing)
    
    @pytest.mark.asyncio
    async def test_check_missing_quest(self, populated_registry):
        """Test checking with missing quest."""
        character_state = {
            "base_level": 100,
            "party_size": 5,
            "completed_quests": []
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "nidhogg",
            character_state
        )
        
        assert can_enter is False
        assert any("Quest required" in msg for msg in missing)
    
    @pytest.mark.asyncio
    async def test_check_with_quest_completed(self, populated_registry):
        """Test checking with quest completed."""
        character_state = {
            "base_level": 100,
            "party_size": 5,
            "completed_quests": ["Nidhogg Quest"]
        }
        
        can_enter, missing = await populated_registry.check_requirements(
            "nidhogg",
            character_state
        )
        
        assert can_enter is True
        assert len(missing) == 0
    
    @pytest.mark.asyncio
    async def test_check_nonexistent_instance(self, populated_registry):
        """Test checking requirements for non-existent instance."""
        character_state = {"base_level": 50}
        
        can_enter, missing = await populated_registry.check_requirements(
            "nonexistent",
            character_state
        )
        
        assert can_enter is False
        assert len(missing) == 1
        assert "Unknown instance" in missing[0]


class TestGetRecommendedInstances:
    """Test getting recommended instances."""
    
    @pytest.mark.asyncio
    async def test_recommend_basic(self, populated_registry):
        """Test basic recommendation."""
        character_state = {
            "base_level": 50,
            "party_size": 1,
            "gear_score": 3000
        }
        
        recommendations = await populated_registry.get_recommended_instances(
            character_state
        )
        
        assert len(recommendations) > 0
        # Orc's Memory should be highly recommended at level 50
        ids = [i.instance_id for i in recommendations]
        assert "orc_memory" in ids
    
    @pytest.mark.asyncio
    async def test_recommend_excludes_on_cooldown(self, populated_registry):
        """Test recommendation excludes cooldowns."""
        character_state = {
            "base_level": 50,
            "party_size": 1,
            "gear_score": 3000
        }
        cooldowns = {
            "orc_memory": True  # On cooldown
        }
        
        recommendations = await populated_registry.get_recommended_instances(
            character_state,
            cooldowns
        )
        
        # Should not recommend orc_memory
        ids = [i.instance_id for i in recommendations]
        assert "orc_memory" not in ids
    
    @pytest.mark.asyncio
    async def test_recommend_respects_requirements(self, populated_registry):
        """Test recommendations respect requirements."""
        character_state = {
            "base_level": 20,  # Too low for most
            "party_size": 1,
            "gear_score": 1000
        }
        
        recommendations = await populated_registry.get_recommended_instances(
            character_state
        )
        
        # Should only recommend instances with min_level <= 20
        for instance in recommendations:
            assert instance.requirements.min_level <= 20
    
    @pytest.mark.asyncio
    async def test_recommend_high_level_character(self, populated_registry):
        """Test recommendations for high level character."""
        character_state = {
            "base_level": 120,
            "party_size": 6,
            "gear_score": 8000,
            "completed_quests": ["Nidhogg Quest"]  # Include required quest
        }
        
        recommendations = await populated_registry.get_recommended_instances(
            character_state
        )
        
        # Should recommend high level instances
        ids = [i.instance_id for i in recommendations]
        assert "nidhogg" in ids
    
    @pytest.mark.asyncio
    async def test_recommend_sorted_by_score(self, populated_registry):
        """Test recommendations are sorted by score."""
        character_state = {
            "base_level": 50,
            "party_size": 1,
            "gear_score": 3000
        }
        
        recommendations = await populated_registry.get_recommended_instances(
            character_state
        )
        
        # First recommendation should be best match
        if len(recommendations) > 0:
            best = recommendations[0]
            # Should be close to character level
            assert abs(best.recommended_level - 50) <= 20


class TestGetAllInstances:
    """Test getting all instances."""
    
    def test_get_all_instances(self, populated_registry):
        """Test getting all instances."""
        all_instances = populated_registry.get_all_instances()
        
        assert len(all_instances) == 3
        ids = [i.instance_id for i in all_instances]
        assert "endless_tower" in ids
        assert "orc_memory" in ids
        assert "nidhogg" in ids
    
    def test_get_all_from_empty(self, registry):
        """Test getting all from empty registry."""
        all_instances = registry.get_all_instances()
        
        assert len(all_instances) == 0


class TestGetInstanceCount:
    """Test instance count."""
    
    def test_count_populated(self, populated_registry):
        """Test count with populated registry."""
        count = populated_registry.get_instance_count()
        
        assert count == 3
    
    def test_count_empty(self, registry):
        """Test count with empty registry."""
        count = registry.get_instance_count()
        
        assert count == 0


# Edge Cases

class TestEdgeCases:
    """Test edge cases and error handling."""
    
    @pytest.mark.asyncio
    async def test_check_requirements_empty_state(self, populated_registry):
        """Test checking with empty character state."""
        character_state = {}
        
        can_enter, missing = await populated_registry.check_requirements(
            "orc_memory",
            character_state
        )
        
        # Should use defaults and likely fail level check
        assert can_enter is False
    
    @pytest.mark.asyncio
    async def test_recommend_empty_registry(self, registry):
        """Test recommendations from empty registry."""
        character_state = {"base_level": 50, "party_size": 1, "gear_score": 3000}
        
        recommendations = await registry.get_recommended_instances(character_state)
        
        assert len(recommendations) == 0
    
    def test_instance_with_minimal_fields(self):
        """Test instance with only required fields."""
        instance = InstanceDefinition(
            instance_id="test",
            instance_name="Test",
            instance_type=InstanceType.SOLO_INSTANCE,
            difficulty=InstanceDifficulty.EASY,
            entry_npc="NPC",
            entry_map="map",
            entry_position=(0, 0)
        )
        
        assert instance.time_limit_minutes == 60  # Default
        assert instance.cooldown_hours == 24  # Default
        assert instance.floors == 1  # Default
    
    @pytest.mark.asyncio
    async def test_find_level_boundary(self, populated_registry):
        """Test finding at exact level boundaries."""
        # Test at exact min level
        instances = await populated_registry.find_instances_by_level(30)
        
        # Should include orc_memory (min 30)
        ids = [i.instance_id for i in instances]
        assert "orc_memory" in ids