"""
Supply/Demand Helper Functions - Private calculation utilities.

This module contains helper functions for calculating supply/demand metrics:
- Supply score calculation
- Demand score calculation
- Market liquidity calculation
- Sale time estimation
- Drop rate loading
"""

import json
from datetime import timedelta
from pathlib import Path
from typing import Any, Dict, List

import structlog

logger = structlog.get_logger(__name__)


def calculate_supply_score(
    item_id: int,
    listings: List[Any],
    drop_rates: Dict[int, float]
) -> float:
    """
    Calculate supply score for an item.
    
    Args:
        item_id: Item ID
        listings: Current market listings
        drop_rates: Item drop rate dictionary
        
    Returns:
        Supply score (0-100)
    """
    # Base score on number of listings
    listing_count = len(listings)
    
    # More listings = higher supply
    if listing_count == 0:
        base_score = 0.0
    elif listing_count < 5:
        base_score = 20.0
    elif listing_count < 20:
        base_score = 40.0
    elif listing_count < 50:
        base_score = 60.0
    elif listing_count < 100:
        base_score = 80.0
    else:
        base_score = 100.0
    
    # Factor in drop rate
    drop_rate = drop_rates.get(item_id, 0.0)
    
    if drop_rate > 0:
        # Higher drop rate = more supply
        drop_multiplier = min(1.5, 1.0 + drop_rate)
        base_score *= drop_multiplier
    
    return min(100.0, base_score)


def calculate_demand_score(
    daily_volume: int,
    history: Any
) -> float:
    """
    Calculate demand score for an item.
    
    Args:
        daily_volume: Estimated daily transaction volume
        history: Price history object
        
    Returns:
        Demand score (0-100)
    """
    if not history or not history.price_points:
        return 50.0  # Default medium demand
    
    # Base score on transaction volume
    if daily_volume == 0:
        base_score = 20.0
    elif daily_volume < 10:
        base_score = 40.0
    elif daily_volume < 50:
        base_score = 60.0
    elif daily_volume < 200:
        base_score = 80.0
    else:
        base_score = 100.0
    
    # Factor in price trend
    if history.trend.value in ["rising", "rising_fast"]:
        base_score *= 1.2  # Rising prices indicate demand
    elif history.trend.value in ["falling", "falling_fast"]:
        base_score *= 0.8  # Falling prices indicate low demand
    
    return min(100.0, base_score)


def calculate_liquidity(
    daily_volume: int,
    history: Any
) -> float:
    """
    Calculate market liquidity.
    
    Args:
        daily_volume: Estimated daily transaction volume
        history: Price history object
        
    Returns:
        Liquidity score (0-1)
    """
    if not history or not history.price_points:
        return 0.0
    
    # High liquidity = many transactions, stable prices
    
    # Factor 1: Transaction volume
    volume_score = min(1.0, daily_volume / 100.0)
    
    # Factor 2: Price stability (inverse of volatility)
    stability_score = max(0.0, 1.0 - history.volatility)
    
    # Combined liquidity
    liquidity = (volume_score * 0.6) + (stability_score * 0.4)
    
    return liquidity


def estimate_sale_time(
    supply_score: float,
    demand_score: float
) -> timedelta:
    """
    Estimate average time to sell item.
    
    Args:
        supply_score: Supply score (0-100)
        demand_score: Demand score (0-100)
        
    Returns:
        Estimated time to sell
    """
    # High demand + low supply = fast sale
    # Low demand + high supply = slow sale
    
    if demand_score == 0:
        # No demand, assume long sale time
        return timedelta(days=30)
    
    ratio = supply_score / demand_score
    
    if ratio < 0.5:
        # High demand, low supply
        hours = 2
    elif ratio < 1.0:
        # Good demand
        hours = 12
    elif ratio < 2.0:
        # Moderate
        hours = 48
    elif ratio < 5.0:
        # Slow
        hours = 168  # 7 days
    else:
        # Very slow
        hours = 720  # 30 days
    
    return timedelta(hours=hours)


def load_drop_rates(data_dir: Path, log: Any) -> Dict[int, float]:
    """
    Load drop rate data from file.
    
    Args:
        data_dir: Directory containing drop_rates.json
        log: Logger instance
        
    Returns:
        Dictionary mapping item_id to drop rate
    """
    drop_rates: Dict[int, float] = {}
    drop_file = data_dir / "drop_rates.json"
    
    if not drop_file.exists():
        log.warning("no_drop_rates_file", path=str(drop_file))
        return drop_rates
    
    try:
        with open(drop_file, 'r') as f:
            data = json.load(f)
        
        # Load normal drop rates
        for item_id_str, drop_info in data.get("drop_rates", {}).items():
            drop_rates[int(item_id_str)] = drop_info.get("rate", 0.0)
        
        # Load MVP drop rates
        for item_id_str, drop_info in data.get("mvp_drops", {}).items():
            drop_rates[int(item_id_str)] = drop_info.get("rate", 0.0)
        
        log.info("drop_rates_loaded", count=len(drop_rates))
    
    except Exception as e:
        log.error("drop_rates_load_failed", error=str(e))
    
    return drop_rates