"""
Crafting Analysis Module - Analyzes crafting profitability and material demand.

This module provides comprehensive crafting analysis including:
- Material cost calculations
- Profitability analysis
- Material demand impact
- Profitable crafting opportunity discovery
"""

from typing import Any, Dict, List, Optional, TYPE_CHECKING

import structlog

from ai_sidecar.economy.crafting_recipes import (
    CraftingRecipeDatabase,
    CraftingType,
)

if TYPE_CHECKING:
    from ai_sidecar.economy.core import MarketManager
    from ai_sidecar.economy.item_categories import ItemCategoryDatabase

logger = structlog.get_logger(__name__)


class CraftingAnalyzer:
    """
    Crafting profitability and demand analyzer.
    
    Provides methods for:
    - Analyzing crafting profitability
    - Calculating material costs
    - Tracking material demand impact
    - Finding profitable crafting opportunities
    """
    
    def __init__(
        self,
        recipe_db: CraftingRecipeDatabase,
        category_db: "ItemCategoryDatabase",
        market: "MarketManager",
        supply_demand_calculator: Any = None
    ):
        """
        Initialize crafting analyzer.
        
        Args:
            recipe_db: Crafting recipe database
            category_db: Item category database
            market: Market data manager
            supply_demand_calculator: Optional callback for supply/demand metrics
        """
        self.log = logger.bind(system="crafting_analyzer")
        self.recipe_db = recipe_db
        self.category_db = category_db
        self.market = market
        self._supply_demand_calculator = supply_demand_calculator
        
        self.log.info(
            "crafting_analyzer_initialized",
            recipes=len(recipe_db.recipes)
        )
    
    def set_supply_demand_calculator(self, calculator: Any) -> None:
        """Set the supply/demand calculator callback."""
        self._supply_demand_calculator = calculator
    
    def analyze_crafting_demand(self, product_id: int) -> Dict[str, Any]:
        """
        Analyze material demand for crafted items.
        
        Provides comprehensive crafting profitability analysis:
        - Material costs from market data
        - Success rate considerations
        - Expected profit margins
        - Material availability
        - Crafting requirements
        
        Args:
            product_id: Crafted product ID
            
        Returns:
            Dict with material demand analysis
        """
        self.log.debug(
            "analyzing_crafting_demand",
            product_id=product_id
        )
        
        recipes = self.recipe_db.get_recipes_for_product(product_id)
        
        if not recipes:
            self.log.debug(
                "item_not_craftable",
                product_id=product_id
            )
            return {
                "product_id": product_id,
                "is_craftable": False,
                "materials": [],
                "total_material_cost": 0.0,
                "product_price": 0.0,
                "expected_value": 0.0,
                "success_rate": 0.0,
                "profitability": 0.0,
                "profit_margin": 0.0,
                "material_availability": {},
                "requirements": {}
            }
        
        # Use first recipe (primary/most common)
        recipe = recipes[0]
        
        # Calculate material costs
        material_data: List[Dict[str, Any]] = []
        total_material_cost = 0.0
        material_availability: Dict[int, float] = {}
        
        for mat in recipe.materials:
            # Get market price for material
            mat_history = self.market.get_price_history(mat.item_id, days=7)
            avg_price = mat_history.avg_price if mat_history else 0.0
            mat_cost = avg_price * mat.quantity
            total_material_cost += mat_cost
            
            # Check supply score for this material
            supply_score = self._get_supply_score(mat.item_id)
            
            material_data.append({
                "item_id": mat.item_id,
                "item_name": mat.item_name,
                "quantity": mat.quantity,
                "unit_price": avg_price,
                "total_cost": mat_cost,
                "availability": supply_score,
                "consumed": mat.consumed
            })
            
            material_availability[mat.item_id] = supply_score
            
            self.log.debug(
                "material_analyzed",
                item_id=mat.item_id,
                item_name=mat.item_name,
                quantity=mat.quantity,
                unit_price=avg_price,
                total_cost=mat_cost,
                availability=supply_score
            )
        
        # Get product price
        product_history = self.market.get_price_history(product_id, days=7)
        product_price = product_history.avg_price if product_history else 0.0
        
        # Calculate profitability (adjusted for success rate and product count)
        expected_products = recipe.product_count * recipe.base_success_rate
        expected_value = product_price * expected_products
        profitability = expected_value - total_material_cost
        
        # Profit margin as percentage
        profit_margin = (
            (profitability / total_material_cost * 100)
            if total_material_cost > 0
            else 0.0
        )
        
        # Calculate average material availability
        avg_availability = (
            sum(material_availability.values()) / len(material_availability)
            if material_availability
            else 0.0
        )
        
        result = {
            "product_id": product_id,
            "is_craftable": True,
            "recipe_id": recipe.recipe_id,
            "recipe_name": recipe.name,
            "crafting_type": recipe.crafting_type.value,
            "materials": material_data,
            "total_material_cost": total_material_cost,
            "product_price": product_price,
            "product_count": recipe.product_count,
            "expected_value": expected_value,
            "success_rate": recipe.base_success_rate,
            "profitability": profitability,
            "profit_margin": profit_margin,
            "material_availability": material_availability,
            "avg_material_availability": avg_availability,
            "requirements": {
                "job": recipe.required_job.value,
                "level": recipe.required_level,
                "skills": recipe.required_skills,
                "npc_required": recipe.npc_required,
                "npc_name": recipe.npc_name
            },
            "alternative_recipes": len(recipes) - 1,
            "notes": recipe.notes
        }
        
        self.log.info(
            "crafting_demand_analyzed",
            product_id=product_id,
            recipe=recipe.recipe_id,
            material_cost=total_material_cost,
            product_price=product_price,
            profitability=profitability,
            profit_margin=profit_margin
        )
        
        return result
    
    def is_craftable(self, item_id: int) -> bool:
        """
        Check if an item can be crafted.
        
        Args:
            item_id: Item ID to check
            
        Returns:
            True if item has crafting recipes
        """
        return self.recipe_db.is_craftable(item_id)
    
    def get_crafting_requirements(self, item_id: int) -> Optional[Dict[str, Any]]:
        """
        Get crafting requirements for an item.
        
        Args:
            item_id: Item ID to check
            
        Returns:
            Dict with requirements or None if not craftable
        """
        recipes = self.recipe_db.get_recipes_for_product(item_id)
        
        if not recipes:
            return None
        
        recipe = recipes[0]
        
        return {
            "recipe_id": recipe.recipe_id,
            "recipe_name": recipe.name,
            "crafting_type": recipe.crafting_type.value,
            "materials": [
                {
                    "item_id": m.item_id,
                    "item_name": m.item_name,
                    "quantity": m.quantity
                }
                for m in recipe.materials
            ],
            "job_required": recipe.required_job.value,
            "level_required": recipe.required_level,
            "skills_required": recipe.required_skills,
            "npc_required": recipe.npc_required,
            "npc_name": recipe.npc_name,
            "success_rate": recipe.base_success_rate,
            "product_count": recipe.product_count
        }
    
    def estimate_crafting_value(self, item_id: int) -> Dict[str, float]:
        """
        Estimate the crafting value and potential profit for an item.
        
        Args:
            item_id: Item ID to analyze
            
        Returns:
            Dict with value estimates
        """
        analysis = self.analyze_crafting_demand(item_id)
        
        if not analysis.get("is_craftable"):
            return {
                "material_cost": 0.0,
                "market_value": 0.0,
                "expected_profit": 0.0,
                "profit_margin_pct": 0.0,
                "risk_adjusted_profit": 0.0,
                "is_profitable": False
            }
        
        material_cost = analysis["total_material_cost"]
        market_value = analysis["product_price"]
        expected_profit = analysis["profitability"]
        profit_margin = analysis["profit_margin"]
        success_rate = analysis["success_rate"]
        
        # Risk-adjusted profit (accounts for failure chance)
        # On failure, materials are lost
        risk_adjusted = (expected_profit * success_rate) - (
            material_cost * (1 - success_rate)
        )
        
        return {
            "material_cost": material_cost,
            "market_value": market_value,
            "expected_profit": expected_profit,
            "profit_margin_pct": profit_margin,
            "risk_adjusted_profit": risk_adjusted,
            "is_profitable": risk_adjusted > 0,
            "success_rate": success_rate
        }
    
    def get_material_demand_impact(self, material_id: int) -> Dict[str, Any]:
        """
        Analyze how demand for products affects demand for this material.
        
        Args:
            material_id: Material item ID
            
        Returns:
            Dict with demand impact analysis
        """
        self.log.debug(
            "analyzing_material_demand_impact",
            material_id=material_id
        )
        
        if not self.recipe_db.is_crafting_material(material_id):
            return {
                "material_id": material_id,
                "is_crafting_material": False,
                "used_in_recipes": 0,
                "products": [],
                "total_demand_score": 0.0,
                "demand_drivers": []
            }
        
        recipes = self.recipe_db.get_recipes_using_material(material_id)
        products_data: List[Dict[str, Any]] = []
        demand_drivers: List[Dict[str, Any]] = []
        total_weighted_demand = 0.0
        
        for recipe in recipes:
            # Get demand for the product
            product_demand = self._get_demand_score(recipe.product_id)
            
            # Find how much material is needed per product
            mat_qty = 0
            for mat in recipe.materials:
                if mat.item_id == material_id:
                    mat_qty = mat.quantity
                    break
            
            # Weight demand by material quantity needed
            weighted_demand = product_demand * mat_qty
            total_weighted_demand += weighted_demand
            
            products_data.append({
                "product_id": recipe.product_id,
                "product_name": recipe.product_name,
                "recipe_id": recipe.recipe_id,
                "material_quantity": mat_qty,
                "product_demand": product_demand,
                "weighted_contribution": weighted_demand
            })
            
            # Track high-demand products as drivers
            if product_demand > 60:
                demand_drivers.append({
                    "product_id": recipe.product_id,
                    "product_name": recipe.product_name,
                    "demand_score": product_demand
                })
        
        # Normalize total demand to 0-100 scale
        normalized_demand = min(100.0, total_weighted_demand / max(1, len(recipes)))
        
        result = {
            "material_id": material_id,
            "is_crafting_material": True,
            "used_in_recipes": len(recipes),
            "products": products_data,
            "total_demand_score": normalized_demand,
            "demand_drivers": demand_drivers,
            "crafting_types": list(set(r.crafting_type.value for r in recipes))
        }
        
        self.log.info(
            "material_demand_impact_analyzed",
            material_id=material_id,
            recipe_count=len(recipes),
            demand_score=normalized_demand
        )
        
        return result
    
    def find_profitable_crafting(
        self,
        min_profit_margin: float = 10.0,
        crafting_type: Optional[CraftingType] = None
    ) -> List[Dict[str, Any]]:
        """
        Find items that are profitable to craft.
        
        Args:
            min_profit_margin: Minimum profit margin percentage
            crafting_type: Optional filter by crafting type
            
        Returns:
            List of profitable crafting opportunities sorted by profit
        """
        self.log.info(
            "searching_profitable_crafting",
            min_margin=min_profit_margin,
            crafting_type=crafting_type.value if crafting_type else "all"
        )
        
        profitable: List[Dict[str, Any]] = []
        
        # Get recipes to analyze
        if crafting_type:
            recipes = self.recipe_db.get_recipes_by_type(crafting_type)
        else:
            recipes = list(self.recipe_db.recipes.values())
        
        for recipe in recipes:
            # Skip refining recipes (product_id = 0)
            if recipe.product_id == 0:
                continue
            
            try:
                value_estimate = self.estimate_crafting_value(recipe.product_id)
                
                if (
                    value_estimate["is_profitable"]
                    and value_estimate["profit_margin_pct"] >= min_profit_margin
                ):
                    profitable.append({
                        "recipe_id": recipe.recipe_id,
                        "recipe_name": recipe.name,
                        "product_id": recipe.product_id,
                        "product_name": recipe.product_name,
                        "crafting_type": recipe.crafting_type.value,
                        "material_cost": value_estimate["material_cost"],
                        "market_value": value_estimate["market_value"],
                        "profit": value_estimate["expected_profit"],
                        "profit_margin": value_estimate["profit_margin_pct"],
                        "risk_adjusted_profit": value_estimate["risk_adjusted_profit"],
                        "success_rate": value_estimate["success_rate"]
                    })
            except Exception as e:
                self.log.warning(
                    "profit_calculation_failed",
                    recipe_id=recipe.recipe_id,
                    error=str(e)
                )
        
        # Sort by risk-adjusted profit descending
        profitable.sort(key=lambda x: x["risk_adjusted_profit"], reverse=True)
        
        self.log.info(
            "profitable_crafting_found",
            count=len(profitable),
            min_margin=min_profit_margin
        )
        
        return profitable
    
    def _get_supply_score(self, item_id: int) -> float:
        """Get supply score for an item, using callback if available."""
        if self._supply_demand_calculator:
            try:
                metrics = self._supply_demand_calculator(item_id)
                return metrics.supply_score
            except Exception:
                pass
        return 50.0  # Default medium availability
    
    def _get_demand_score(self, item_id: int) -> float:
        """Get demand score for an item, using callback if available."""
        if self._supply_demand_calculator:
            try:
                metrics = self._supply_demand_calculator(item_id)
                return metrics.demand_score
            except Exception:
                pass
        return 50.0  # Default medium demand