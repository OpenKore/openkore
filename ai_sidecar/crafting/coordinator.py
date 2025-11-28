"""
Main crafting coordinator integrating all crafting systems.

Provides unified interface for crafting opportunities, profit calculation,
material management, and crafting action recommendations.
"""

from pathlib import Path
from typing import Dict, List, Optional

import structlog

from ai_sidecar.crafting.brewing import BrewingManager
from ai_sidecar.crafting.cards import CardManager
from ai_sidecar.crafting.core import CraftingManager, CraftingType
from ai_sidecar.crafting.enchanting import EnchantingManager
from ai_sidecar.crafting.forging import ForgingManager
from ai_sidecar.crafting.refining import RefiningManager

logger = structlog.get_logger(__name__)


class CraftingCoordinator:
    """
    Main crafting coordinator integrating all systems.
    
    Acts as facade for:
    - Crafting Manager
    - Forging Manager
    - Brewing Manager
    - Refining Manager
    - Enchanting Manager
    - Card Manager
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize crafting coordinator.
        
        Args:
            data_dir: Directory containing all crafting data files
        """
        self.log = logger.bind(component="crafting_coordinator")
        self.data_dir = Path(data_dir)
        
        # Initialize core systems
        self.log.info("initializing_crafting_systems")
        self.crafting = CraftingManager(data_dir)
        self.forging = ForgingManager(data_dir, self.crafting)
        self.brewing = BrewingManager(data_dir, self.crafting)
        self.refining = RefiningManager(data_dir, self.crafting)
        self.enchanting = EnchantingManager(data_dir, self.crafting)
        self.cards = CardManager(data_dir)
        
        self.log.info("crafting_systems_initialized")
    
    async def get_crafting_opportunities(
        self,
        character_state: dict,
        inventory: dict,
        market_prices: Optional[dict] = None
    ) -> List[dict]:
        """
        Get all available crafting opportunities.
        
        Args:
            character_state: Character stats, job, skills
            inventory: Current inventory
            market_prices: Market prices for items
            
        Returns:
            List of crafting opportunities
        """
        opportunities = []
        
        # Get craftable recipes
        craftable = self.crafting.get_craftable_recipes(
            inventory, character_state
        )
        
        for recipe in craftable:
            success_rate = self.crafting.calculate_success_rate(
                recipe.recipe_id, character_state
            )
            
            opportunity = {
                "type": "recipe",
                "crafting_type": recipe.crafting_type.value,
                "recipe_id": recipe.recipe_id,
                "recipe_name": recipe.recipe_name,
                "result_item": recipe.result_item_name,
                "success_rate": success_rate,
                "materials": [
                    {
                        "item_id": m.item_id,
                        "item_name": m.item_name,
                        "quantity": m.quantity_required,
                    }
                    for m in recipe.materials
                ],
            }
            
            # Add profit if market prices available
            if market_prices:
                material_cost = sum(
                    market_prices.get(m.item_id, 0) * m.quantity_required
                    for m in recipe.materials
                )
                result_value = market_prices.get(recipe.result_item_id, 0)
                opportunity["profit"] = result_value - material_cost
                opportunity["material_cost"] = material_cost
            
            opportunities.append(opportunity)
        
        # Get forging opportunities
        forge_target = self.forging.get_optimal_forge_target(
            inventory, character_state, market_prices
        )
        if forge_target:
            opportunities.append({
                "type": "forge",
                "crafting_type": "forge",
                **forge_target
            })
        
        # Get brewing opportunities
        brew_target = self.brewing.get_most_profitable_brew(
            inventory, character_state, market_prices or {}
        )
        if brew_target:
            opportunities.append({
                "type": "brew",
                "crafting_type": "brew",
                **brew_target
            })
        
        # Sort by profit if available
        if market_prices:
            opportunities.sort(
                key=lambda x: x.get("profit", 0),
                reverse=True
            )
        
        return opportunities
    
    def get_profit_potential(
        self,
        crafting_type: CraftingType,
        character_state: dict,
        inventory: dict,
        market_prices: dict
    ) -> List[dict]:
        """
        Calculate profit potential for crafting type.
        
        Args:
            crafting_type: Type of crafting
            character_state: Character stats
            inventory: Current inventory
            market_prices: Market prices
            
        Returns:
            List of profitable crafts
        """
        profitable = []
        
        if crafting_type == CraftingType.FORGE:
            target = self.forging.get_optimal_forge_target(
                inventory, character_state, market_prices
            )
            if target:
                profitable.append(target)
        
        elif crafting_type == CraftingType.BREW:
            target = self.brewing.get_most_profitable_brew(
                inventory, character_state, market_prices
            )
            if target:
                profitable.append(target)
        
        else:
            # Get recipes of this type
            recipes = self.crafting.get_recipes_by_type(crafting_type)
            
            for recipe in recipes:
                # Check if we have materials
                has_materials, _ = self.crafting.check_materials(
                    recipe.recipe_id, inventory
                )
                if not has_materials:
                    continue
                
                # Calculate profit
                material_cost = sum(
                    market_prices.get(m.item_id, 0) * m.quantity_required
                    for m in recipe.materials
                )
                result_value = market_prices.get(recipe.result_item_id, 0)
                profit = result_value - material_cost
                
                if profit > 0:
                    profitable.append({
                        "recipe_id": recipe.recipe_id,
                        "recipe_name": recipe.recipe_name,
                        "profit": profit,
                        "material_cost": material_cost,
                        "result_value": result_value,
                    })
        
        # Sort by profit
        profitable.sort(key=lambda x: x.get("profit", 0), reverse=True)
        return profitable
    
    def get_material_shopping_list(
        self,
        target_crafts: List[int],
        inventory: dict
    ) -> List[dict]:
        """
        Get shopping list for target crafts.
        
        Args:
            target_crafts: List of recipe IDs to craft
            inventory: Current inventory
            
        Returns:
            Shopping list with aggregated materials
        """
        shopping_list = {}
        
        for recipe_id in target_crafts:
            missing = self.crafting.get_missing_materials(recipe_id, inventory)
            
            for material in missing:
                if material.item_id in shopping_list:
                    shopping_list[material.item_id]["quantity"] += material.quantity_required
                else:
                    shopping_list[material.item_id] = {
                        "item_id": material.item_id,
                        "item_name": material.item_name,
                        "quantity": material.quantity_required,
                    }
        
        return list(shopping_list.values())
    
    async def get_next_crafting_action(
        self,
        character_state: dict,
        inventory: dict,
        current_map: str
    ) -> dict:
        """
        Get next recommended crafting action.
        
        Args:
            character_state: Character state
            inventory: Current inventory
            current_map: Current map location
            
        Returns:
            Recommended action dict
        """
        # Get all opportunities
        opportunities = await self.get_crafting_opportunities(
            character_state, inventory
        )
        
        if not opportunities:
            return {
                "action": "none",
                "reason": "No crafting opportunities available"
            }
        
        # Pick best opportunity
        best = opportunities[0]
        
        # Check if we're at the right location
        recipe = self.crafting.get_recipe(best.get("recipe_id", 0))
        if recipe and recipe.npc_map:
            if current_map != recipe.npc_map:
                return {
                    "action": "move",
                    "target_map": recipe.npc_map,
                    "target_npc": recipe.npc_name,
                    "reason": f"Need to go to {recipe.npc_name} for crafting"
                }
        
        return {
            "action": "craft",
            "crafting_type": best.get("crafting_type"),
            "target": best,
            "reason": "Best available crafting opportunity"
        }
    
    def calculate_total_crafting_value(self, character_state: dict) -> dict:
        """
        Calculate total value from crafting activities.
        
        Args:
            character_state: Character state
            
        Returns:
            Value breakdown
        """
        total_value = 0
        breakdown = {}
        
        # Forging fame value (estimate based on level)
        character_name = character_state.get("name", "Unknown")
        fame = self.forging.get_fame(character_name)
        fame_value = fame * 1000  # Rough zeny equivalent
        breakdown["forging_fame"] = fame_value
        total_value += fame_value
        
        # Add other value sources...
        # (simplified for now)
        
        return {
            "total_value": total_value,
            "breakdown": breakdown,
        }
    
    def get_statistics(self) -> dict:
        """
        Get crafting statistics.
        
        Returns:
            Aggregate statistics from all systems
        """
        return {
            "crafting": self.crafting.get_statistics(),
            "forging": self.forging.get_statistics(),
            "brewing": self.brewing.get_statistics(),
            "refining": self.refining.get_statistics(),
            "enchanting": self.enchanting.get_statistics(),
            "cards": self.cards.get_statistics(),
        }