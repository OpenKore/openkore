"""
Item valuation engine for AI Sidecar.

Calculates item worth based on multiple factors including:
- Build-specific stat weights
- Market prices and trends
- Card and enchant values
- Refine levels and risks
"""

import json
import logging
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.equipment.models import (
    Equipment,
    EquipSlot,
    MarketPrice,
    get_refine_success_rate,
    calculate_refine_cost,
)

logger = logging.getLogger(__name__)


class BuildWeights(BaseModel):
    """Stat weights for a specific build type."""
    
    model_config = ConfigDict(frozen=True)
    
    # Base stat weights
    atk: float = Field(default=1.0, ge=0.0)
    matk: float = Field(default=1.0, ge=0.0)
    defense: float = Field(default=1.0, ge=0.0)
    mdef: float = Field(default=1.0, ge=0.0)
    
    # Stat bonus weights
    str_bonus: float = Field(default=1.0, ge=0.0)
    agi_bonus: float = Field(default=1.0, ge=0.0)
    vit_bonus: float = Field(default=1.0, ge=0.0)
    int_bonus: float = Field(default=1.0, ge=0.0)
    dex_bonus: float = Field(default=1.0, ge=0.0)
    luk_bonus: float = Field(default=1.0, ge=0.0)
    
    # Additional bonus weights
    hp_bonus: float = Field(default=1.0, ge=0.0)
    sp_bonus: float = Field(default=1.0, ge=0.0)
    aspd_bonus: float = Field(default=1.0, ge=0.0)
    crit_bonus: float = Field(default=1.0, ge=0.0)
    
    # Refine value multiplier
    refine_weight: float = Field(default=1.0, ge=0.0)


# Default build-specific weights
DEFAULT_BUILD_WEIGHTS = {
    "melee_dps": BuildWeights(
        atk=1.5,
        str_bonus=1.2,
        agi_bonus=1.0,
        dex_bonus=1.1,
        aspd_bonus=1.3,
        crit_bonus=1.3,
        defense=0.5,
        refine_weight=1.4,
    ),
    "tank": BuildWeights(
        defense=1.5,
        vit_bonus=1.3,
        hp_bonus=1.2,
        mdef=1.0,
        str_bonus=0.8,
        agi_bonus=0.6,
        refine_weight=1.2,
    ),
    "magic_dps": BuildWeights(
        matk=1.5,
        int_bonus=1.3,
        dex_bonus=1.2,
        sp_bonus=1.1,
        mdef=0.7,
        defense=0.5,
        refine_weight=1.1,
    ),
    "support": BuildWeights(
        int_bonus=1.2,
        dex_bonus=1.2,
        vit_bonus=1.0,
        sp_bonus=1.3,
        mdef=0.8,
        defense=0.7,
        refine_weight=0.8,
    ),
    "ranged_dps": BuildWeights(
        atk=1.4,
        dex_bonus=1.5,
        agi_bonus=1.2,
        str_bonus=0.9,
        aspd_bonus=1.2,
        crit_bonus=1.1,
        defense=0.6,
        refine_weight=1.3,
    ),
    "hybrid": BuildWeights(
        atk=1.0,
        matk=1.0,
        defense=1.0,
        str_bonus=1.0,
        agi_bonus=1.0,
        vit_bonus=1.0,
        int_bonus=1.0,
        dex_bonus=1.0,
        luk_bonus=1.0,
        refine_weight=1.0,
    ),
}


class RefineAnalysis(BaseModel):
    """Analysis of refining an item."""
    
    model_config = ConfigDict(frozen=False)
    
    current_refine: int = Field(ge=0, le=20)
    target_refine: int = Field(ge=0, le=20)
    success_rate: float = Field(ge=0.0, le=1.0)
    cost_estimate: int = Field(ge=0, description="Estimated zeny cost")
    expected_value_gain: float = Field(description="Expected score improvement")
    risk_score: float = Field(ge=0.0, le=1.0, description="Risk of failure")
    recommended: bool = Field(default=False, description="Is this refine recommended")


class ItemValuationEngine:
    """
    Calculates item worth based on multiple factors.
    
    Features:
    - Build-specific equipment scoring
    - Market value estimation
    - Equipment comparison
    - Refine risk/reward analysis
    """
    
    def __init__(
        self,
        market_prices: dict[int, MarketPrice] | None = None,
        build_weights: dict[str, BuildWeights] | None = None,
    ):
        """
        Initialize valuation engine.
        
        Args:
            market_prices: Market price database
            build_weights: Custom build weights (uses defaults if not provided)
        """
        self.market_prices = market_prices or {}
        self.build_weights = build_weights or DEFAULT_BUILD_WEIGHTS
    
    def load_market_prices(self, prices_file: str | Path) -> None:
        """
        Load market prices from JSON file.
        
        Args:
            prices_file: Path to market_prices.json
        """
        try:
            with open(prices_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            
            self.market_prices = {
                int(item_id): MarketPrice.model_validate(price_data)
                for item_id, price_data in data.items()
            }
            logger.info(f"Loaded {len(self.market_prices)} market prices")
        except FileNotFoundError:
            logger.warning(f"Market prices file not found: {prices_file}")
        except Exception as e:
            logger.error(f"Failed to load market prices: {e}")
    
    def calculate_equipment_score(
        self,
        item: Equipment,
        build: str = "hybrid",
    ) -> float:
        """
        Calculate equipment effectiveness score for a specific build.
        
        Uses weighted sum of stats based on build priorities.
        
        Args:
            item: Equipment to evaluate
            build: Build type (melee_dps, tank, magic_dps, etc.)
            
        Returns:
            Equipment score (higher is better)
        """
        weights = self.build_weights.get(build, self.build_weights["hybrid"])
        
        score = 0.0
        
        # Base stats
        score += item.atk * weights.atk
        score += item.matk * weights.matk
        score += item.defense * weights.defense
        score += item.mdef * weights.mdef
        
        # Stat bonuses
        score += item.str_bonus * weights.str_bonus
        score += item.agi_bonus * weights.agi_bonus
        score += item.vit_bonus * weights.vit_bonus
        score += item.int_bonus * weights.int_bonus
        score += item.dex_bonus * weights.dex_bonus
        score += item.luk_bonus * weights.luk_bonus
        
        # Additional bonuses
        score += item.hp_bonus * weights.hp_bonus * 0.01  # Scale down HP
        score += item.sp_bonus * weights.sp_bonus * 0.01  # Scale down SP
        score += item.aspd_bonus * weights.aspd_bonus
        score += item.crit_bonus * weights.crit_bonus
        
        # Refine bonus (higher refines are exponentially more valuable)
        if item.refine > 0:
            refine_value = item.refine * (1 + item.refine * 0.1)
            score += refine_value * weights.refine_weight
        
        # Card slot value (empty slots have potential value)
        if item.has_empty_slots:
            score += (item.slots - item.card_count) * 5.0
        
        # Special effects (simple scoring)
        score += len(item.effects) * 10.0
        
        return max(score, 0.0)
    
    def estimate_market_value(
        self,
        item: Equipment,
    ) -> tuple[int, int, int]:
        """
        Estimate min, avg, max zeny value for an item.
        
        Considers base item price, refine level, cards, and market trends.
        
        Args:
            item: Equipment to evaluate
            
        Returns:
            Tuple of (min_price, avg_price, max_price) in zeny
        """
        # Get base market price
        market_info = self.market_prices.get(item.item_id)
        
        if market_info:
            base_min = market_info.min_price
            base_avg = market_info.avg_price
            base_max = market_info.max_price
        else:
            # Fallback to NPC price if market data unavailable
            base_avg = item.item_id * 100  # Simple fallback
            base_min = int(base_avg * 0.7)
            base_max = int(base_avg * 1.5)
        
        # Refine multiplier (exponential)
        refine_multiplier = 1.0 + (item.refine * 0.2) + (item.refine ** 2 * 0.05)
        
        # Card value (rough estimate)
        card_value = 0
        for card in item.cards:
            if card.card_id:
                # Card prices vary widely; this is a placeholder
                card_market = self.market_prices.get(card.card_id)
                if card_market:
                    card_value += card_market.avg_price
                else:
                    card_value += 50000  # Default card value
        
        # Enchant value (rough estimate)
        enchant_value = len(item.enchants) * 100000
        
        # Calculate final prices
        min_price = int((base_min * refine_multiplier) + card_value + enchant_value)
        avg_price = int((base_avg * refine_multiplier) + card_value + enchant_value)
        max_price = int((base_max * refine_multiplier) + card_value + enchant_value)
        
        return (min_price, avg_price, max_price)
    
    def compare_equipment(
        self,
        current: Equipment | None,
        candidate: Equipment,
        build: str = "hybrid",
    ) -> float:
        """
        Compare two equipment pieces.
        
        Args:
            current: Currently equipped item (None if slot is empty)
            candidate: Candidate replacement item
            build: Build type for scoring
            
        Returns:
            Score difference (positive if candidate is better, negative if worse)
        """
        candidate_score = self.calculate_equipment_score(candidate, build)
        
        if current is None:
            # Empty slot - any equipment is better
            return candidate_score
        
        current_score = self.calculate_equipment_score(current, build)
        
        return candidate_score - current_score
    
    def calculate_refine_value(
        self,
        item: Equipment,
        target_refine: int,
        build: str = "hybrid",
    ) -> RefineAnalysis:
        """
        Calculate expected value gain and risk from refining.
        
        Analyzes whether refining is worth the cost and risk.
        
        Args:
            item: Equipment to potentially refine
            target_refine: Target refine level
            build: Build type for value calculation
            
        Returns:
            RefineAnalysis with recommendation
        """
        if target_refine <= item.refine:
            return RefineAnalysis(
                current_refine=item.refine,
                target_refine=target_refine,
                success_rate=1.0,
                cost_estimate=0,
                expected_value_gain=0.0,
                risk_score=0.0,
                recommended=False,
            )
        
        # Calculate success rate
        success_rate = get_refine_success_rate(
            item.slot,
            item.refine,
            target_refine,
        )
        
        # Calculate cost
        cost = calculate_refine_cost(item.refine, target_refine)
        
        # Calculate value gain if successful
        current_score = self.calculate_equipment_score(item, build)
        
        # Simulate refined item
        refined_item = item.model_copy()
        refined_item.refine = target_refine
        refined_score = self.calculate_equipment_score(refined_item, build)
        
        value_gain = refined_score - current_score
        
        # Expected value = (success_rate * value_gain) - (failure_rate * item_loss)
        item_value = self.estimate_market_value(item)[1]  # Use avg price
        failure_risk = (1.0 - success_rate) * item_value
        expected_value = (success_rate * value_gain) - (failure_risk * 0.5)
        
        # Risk score (higher = riskier)
        risk_score = 1.0 - success_rate
        
        # Recommendation logic
        # Only recommend if expected value is positive and risk is acceptable
        recommended = (
            expected_value > 0
            and success_rate > 0.5
            and cost < item_value * 0.3  # Cost < 30% of item value
        )
        
        return RefineAnalysis(
            current_refine=item.refine,
            target_refine=target_refine,
            success_rate=success_rate,
            cost_estimate=cost,
            expected_value_gain=expected_value,
            risk_score=risk_score,
            recommended=recommended,
        )
    
    def evaluate_card_insertion(
        self,
        item: Equipment,
        card_id: int,
        build: str = "hybrid",
    ) -> dict[str, Any]:
        """
        Evaluate inserting a card into equipment.
        
        Args:
            item: Equipment to insert card into
            card_id: Card to insert
            build: Build type
            
        Returns:
            Dict with score_improvement, recommended, etc.
        """
        if not item.has_empty_slots:
            return {
                "score_improvement": 0.0,
                "recommended": False,
                "reason": "No empty card slots",
            }
        
        # Current score
        current_score = self.calculate_equipment_score(item, build)
        
        # Simulate with card inserted
        carded_item = item.model_copy()
        
        # Find first empty slot
        for slot in carded_item.cards:
            if slot.card_id is None:
                slot.card_id = card_id
                break
        else:
            # No existing slots, add one
            from ai_sidecar.equipment.models import CardSlot
            carded_item.cards.append(
                CardSlot(slot_index=len(carded_item.cards), card_id=card_id)
            )
        
        # Calculate new score
        # Note: This is simplified; real implementation would need card database
        # to get actual card effects
        carded_score = self.calculate_equipment_score(carded_item, build)
        
        improvement = carded_score - current_score
        
        # Get card market value
        card_price = self.market_prices.get(card_id)
        card_cost = card_price.avg_price if card_price else 50000
        
        return {
            "score_improvement": improvement,
            "card_cost": card_cost,
            "recommended": improvement > 10.0,  # Threshold for recommendation
            "reason": f"Score improvement: {improvement:.1f}",
        }
    
    def prioritize_equipment_upgrades(
        self,
        current_equipment: dict[EquipSlot, Equipment | None],
        available_items: list[Equipment],
        build: str = "hybrid",
        max_recommendations: int = 5,
    ) -> list[dict[str, Any]]:
        """
        Prioritize equipment upgrades from available items.
        
        Args:
            current_equipment: Currently equipped items by slot
            available_items: Items available in inventory/storage
            build: Build type for scoring
            max_recommendations: Maximum number of recommendations
            
        Returns:
            List of upgrade recommendations sorted by impact
        """
        recommendations = []
        
        for candidate in available_items:
            # Get current item in this slot
            current = current_equipment.get(candidate.slot)
            
            # Calculate improvement
            improvement = self.compare_equipment(current, candidate, build)
            
            if improvement > 0:
                # This is an upgrade
                min_val, avg_val, max_val = self.estimate_market_value(candidate)
                
                recommendations.append({
                    "slot": candidate.slot,
                    "item": candidate,
                    "current_item": current,
                    "score_improvement": improvement,
                    "market_value": avg_val,
                    "reason": self._generate_upgrade_reason(current, candidate),
                })
        
        # Sort by score improvement (descending)
        recommendations.sort(key=lambda x: x["score_improvement"], reverse=True)
        
        return recommendations[:max_recommendations]
    
    def _generate_upgrade_reason(
        self,
        current: Equipment | None,
        candidate: Equipment,
    ) -> str:
        """Generate human-readable reason for equipment upgrade."""
        if current is None:
            return f"Equip {candidate.name} (empty slot)"
        
        reasons = []
        
        # Check significant improvements
        if candidate.total_atk > current.total_atk:
            diff = candidate.total_atk - current.total_atk
            reasons.append(f"+{diff} ATK")
        
        if candidate.total_defense > current.total_defense:
            diff = candidate.total_defense - current.total_defense
            reasons.append(f"+{diff} DEF")
        
        if candidate.refine > current.refine:
            reasons.append(f"Higher refine (+{candidate.refine} vs +{current.refine})")
        
        if candidate.slots > current.slots:
            reasons.append(f"More slots ({candidate.slots} vs {current.slots})")
        
        # Stat bonuses
        for stat in ["str", "agi", "vit", "int", "dex", "luk"]:
            cand_bonus = getattr(candidate, f"{stat}_bonus", 0)
            curr_bonus = getattr(current, f"{stat}_bonus", 0)
            if cand_bonus > curr_bonus:
                diff = cand_bonus - curr_bonus
                reasons.append(f"+{diff} {stat.upper()}")
        
        if not reasons:
            reasons.append("Overall better stats")
        
        return ", ".join(reasons[:3])  # Limit to top 3 reasons
    
    def calculate_slot_priority(
        self,
        slot: EquipSlot,
        build: str = "hybrid",
    ) -> float:
        """
        Calculate upgrade priority for an equipment slot.
        
        Some slots are more important than others depending on build.
        
        Args:
            slot: Equipment slot
            build: Build type
            
        Returns:
            Priority score (0.0-1.0)
        """
        # Base priorities
        base_priority = {
            EquipSlot.WEAPON: 1.0,      # Highest priority
            EquipSlot.ARMOR: 0.9,
            EquipSlot.SHIELD: 0.7,
            EquipSlot.GARMENT: 0.6,
            EquipSlot.FOOTGEAR: 0.6,
            EquipSlot.HEAD_TOP: 0.5,
            EquipSlot.ACCESSORY1: 0.7,
            EquipSlot.ACCESSORY2: 0.7,
            EquipSlot.HEAD_MID: 0.3,
            EquipSlot.HEAD_LOW: 0.3,
            EquipSlot.AMMO: 0.4,
        }
        
        priority = base_priority.get(slot, 0.5)
        
        # Build-specific adjustments
        if build == "tank":
            if slot in [EquipSlot.ARMOR, EquipSlot.SHIELD]:
                priority *= 1.3
            elif slot == EquipSlot.WEAPON:
                priority *= 0.8
        elif build in ["magic_dps", "support"]:
            if slot == EquipSlot.WEAPON:
                priority *= 1.2  # Staff/rod important for MATK
            elif slot == EquipSlot.SHIELD:
                priority *= 0.5  # Less important for casters
        elif build in ["melee_dps", "ranged_dps"]:
            if slot == EquipSlot.WEAPON:
                priority *= 1.3
            elif slot in [EquipSlot.ACCESSORY1, EquipSlot.ACCESSORY2]:
                priority *= 1.2  # Accessories for damage
        
        return min(priority, 1.0)
    
    def calculate_total_equipment_value(
        self,
        equipment_set: dict[EquipSlot, Equipment | None],
    ) -> int:
        """
        Calculate total zeny value of an equipment set.
        
        Args:
            equipment_set: Dict of equipped items by slot
            
        Returns:
            Total estimated zeny value
        """
        total = 0
        
        for slot, item in equipment_set.items():
            if item:
                _, avg_price, _ = self.estimate_market_value(item)
                total += avg_price
        
        return total