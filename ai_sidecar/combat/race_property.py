"""
Race and Size Property System for Advanced Combat Mechanics.

Implements race damage bonuses, weapon size penalties, and optimal
weapon/card selection for different monster types.

Reference: https://irowiki.org/wiki/Race
Reference: https://irowiki.org/wiki/Weapon_Size_Penalty
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.combat.models import MonsterRace, MonsterSize


class RaceDamageModifier(BaseModel):
    """Damage modifier for race and size."""
    
    model_config = ConfigDict(frozen=True)
    
    race: MonsterRace = Field(description="Monster race")
    size: MonsterSize = Field(description="Monster size")
    race_modifier: float = Field(default=1.0, description="Race bonus from cards/skills")
    size_modifier: float = Field(default=1.0, description="Size penalty from weapon")
    total_modifier: float = Field(default=1.0, description="Combined modifier")
    
    @property
    def damage_percent(self) -> int:
        """Total damage as percentage."""
        return int(self.total_modifier * 100)


class CardInfo(BaseModel):
    """Information about a race/size damage card."""
    
    model_config = ConfigDict(frozen=False)
    
    card_name: str = Field(description="Card name")
    card_id: int = Field(default=0, description="Card ID")
    bonus_percent: float = Field(description="Damage bonus (0.20 = 20%)")
    race: Optional[MonsterRace] = Field(default=None, description="Race target")
    size: Optional[MonsterSize] = Field(default=None, description="Size target")
    slot_type: str = Field(default="weapon", description="Card slot type")


# Weapon size penalty table
# Reference: https://irowiki.org/wiki/Weapon_Size_Penalty
WEAPON_SIZE_PENALTY: Dict[str, Dict[MonsterSize, float]] = {
    "dagger": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 0.5,
    },
    "sword": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.75,
    },
    "two_hand_sword": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 1.0,
    },
    "spear": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 1.0,
    },
    "two_hand_spear": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 1.0,
    },
    "axe": {
        MonsterSize.SMALL: 0.5,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 1.0,
    },
    "two_hand_axe": {
        MonsterSize.SMALL: 0.5,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 1.0,
    },
    "mace": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "two_hand_mace": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "rod": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "staff": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "bow": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.75,
    },
    "katar": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.75,
    },
    "book": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.5,
    },
    "knuckle": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 0.5,
    },
    "instrument": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.75,
    },
    "whip": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.5,
    },
    "gun": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "rifle": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "gatling": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "shotgun": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "grenade": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 1.0,
    },
    "shuriken": {
        MonsterSize.SMALL: 1.0,
        MonsterSize.MEDIUM: 0.75,
        MonsterSize.LARGE: 0.5,
    },
    "huuma": {
        MonsterSize.SMALL: 0.75,
        MonsterSize.MEDIUM: 1.0,
        MonsterSize.LARGE: 0.75,
    },
}


class RacePropertyCalculator:
    """
    Calculate race and size damage modifiers.
    
    Features:
    - Race damage bonuses (from cards)
    - Size penalty calculation
    - Optimal weapon selection
    - Card recommendations
    """
    
    def __init__(self, data_dir: Optional[Path] = None) -> None:
        """
        Initialize race property calculator.
        
        Args:
            data_dir: Directory containing card data files
        """
        self.log = structlog.get_logger(__name__)
        
        # Card database
        self.race_cards: Dict[MonsterRace, List[CardInfo]] = {
            race: [] for race in MonsterRace
        }
        self.size_cards: Dict[MonsterSize, List[CardInfo]] = {
            size: [] for size in MonsterSize
        }
        
        # Load card data if available
        if data_dir:
            self._load_card_data(data_dir)
        else:
            self._initialize_default_cards()
            
    def _initialize_default_cards(self) -> None:
        """Initialize with common race/size cards."""
        # Race cards (common ones)
        default_race_cards = [
            CardInfo(
                card_name="Hydra Card",
                card_id=4001,
                bonus_percent=0.20,
                race=MonsterRace.DEMI_HUMAN,
            ),
            CardInfo(
                card_name="Skeleton Worker Card",
                card_id=4092,
                bonus_percent=0.15,
                race=MonsterRace.FORMLESS,
            ),
            CardInfo(
                card_name="Minorous Card",
                card_id=4126,
                bonus_percent=0.15,
                race=MonsterRace.BRUTE,
            ),
            CardInfo(
                card_name="Strouf Card",
                card_id=4111,
                bonus_percent=0.20,
                race=MonsterRace.UNDEAD,
            ),
            CardInfo(
                card_name="Flora Card",
                card_id=4080,
                bonus_percent=0.10,
                race=MonsterRace.FISH,
            ),
            CardInfo(
                card_name="Goblin Card",
                card_id=4060,
                bonus_percent=0.20,
                race=MonsterRace.BRUTE,
            ),
        ]
        
        for card in default_race_cards:
            if card.race:
                self.race_cards[card.race].append(card)
                
        # Size cards
        default_size_cards = [
            CardInfo(
                card_name="Desert Wolf Card",
                card_id=4082,
                bonus_percent=0.15,
                size=MonsterSize.SMALL,
            ),
            CardInfo(
                card_name="Skeleton Worker Card",
                card_id=4092,
                bonus_percent=0.15,
                size=MonsterSize.MEDIUM,
            ),
            CardInfo(
                card_name="Minorous Card",
                card_id=4126,
                bonus_percent=0.15,
                size=MonsterSize.LARGE,
            ),
        ]
        
        for card in default_size_cards:
            if card.size:
                self.size_cards[card.size].append(card)
                
        self.log.info("initialized_default_cards", race_count=len(default_race_cards), size_count=len(default_size_cards))
        
    def _load_card_data(self, data_dir: Path) -> None:
        """Load card data from JSON file."""
        card_file = data_dir / "race_cards.json"
        
        if not card_file.exists():
            self.log.warning("card_data_not_found", path=str(card_file))
            self._initialize_default_cards()
            return
            
        try:
            with open(card_file, "r", encoding="utf-8") as f:
                data = json.load(f)
                
            # Load race cards
            for race_str, cards in data.get("race_cards", {}).items():
                race = MonsterRace(race_str)
                for card_data in cards:
                    card = CardInfo(
                        card_name=card_data["card"],
                        bonus_percent=card_data["bonus"],
                        race=race,
                    )
                    self.race_cards[race].append(card)
                    
            # Load size cards
            for size_str, cards in data.get("size_cards", {}).items():
                size = MonsterSize(size_str)
                for card_data in cards:
                    card = CardInfo(
                        card_name=card_data["card"],
                        bonus_percent=card_data["bonus"],
                        size=size,
                    )
                    self.size_cards[size].append(card)
                    
            self.log.info("loaded_card_data", path=str(card_file))
            
        except Exception as e:
            self.log.error("failed_to_load_card_data", path=str(card_file), error=str(e))
            self._initialize_default_cards()
            
    def get_size_penalty(self, weapon_type: str, target_size: MonsterSize) -> float:
        """
        Get weapon size penalty for target.
        
        Args:
            weapon_type: Type of weapon
            target_size: Target monster size
            
        Returns:
            Size modifier (1.0 = no penalty, <1.0 = penalty)
        """
        weapon_lower = weapon_type.lower().replace(" ", "_")
        penalties = WEAPON_SIZE_PENALTY.get(weapon_lower, {})
        
        if not penalties:
            self.log.debug("unknown_weapon_type", weapon=weapon_type)
            return 1.0
            
        penalty = penalties.get(target_size, 1.0)
        
        self.log.debug(
            "size_penalty_calculated",
            weapon=weapon_type,
            size=target_size.value,
            penalty=penalty,
        )
        
        return penalty
        
    def get_race_bonus(
        self,
        equipped_cards: List[str],
        target_race: MonsterRace,
    ) -> float:
        """
        Calculate total race bonus from equipped cards.
        
        Args:
            equipped_cards: List of equipped card names
            target_race: Target monster race
            
        Returns:
            Total race bonus multiplier (1.0 = no bonus, >1.0 = bonus)
        """
        total_bonus = 0.0
        
        # Get race cards for this race
        race_card_list = self.race_cards.get(target_race, [])
        
        for card_name in equipped_cards:
            for card in race_card_list:
                if card.card_name.lower() == card_name.lower():
                    total_bonus += card.bonus_percent
                    
        modifier = 1.0 + total_bonus
        
        self.log.debug(
            "race_bonus_calculated",
            cards=equipped_cards,
            race=target_race.value,
            bonus=total_bonus,
            modifier=modifier,
        )
        
        return modifier
        
    def calculate_total_modifier(
        self,
        weapon_type: str,
        equipped_cards: List[str],
        target_race: MonsterRace,
        target_size: MonsterSize,
    ) -> RaceDamageModifier:
        """
        Calculate combined race and size modifier.
        
        Args:
            weapon_type: Weapon type
            equipped_cards: Equipped card names
            target_race: Target race
            target_size: Target size
            
        Returns:
            Combined damage modifier
        """
        size_mod = self.get_size_penalty(weapon_type, target_size)
        race_mod = self.get_race_bonus(equipped_cards, target_race)
        total_mod = size_mod * race_mod
        
        return RaceDamageModifier(
            race=target_race,
            size=target_size,
            race_modifier=race_mod,
            size_modifier=size_mod,
            total_modifier=total_mod,
        )
        
    def get_optimal_weapon_type(
        self,
        target_size: MonsterSize,
        available_weapons: List[dict],
    ) -> Optional[str]:
        """
        Find weapon type with best size modifier.
        
        Args:
            target_size: Target monster size
            available_weapons: List of available weapon dicts
            
        Returns:
            Best weapon type or None
        """
        best_weapon = None
        best_penalty = 0.0
        
        for weapon in available_weapons:
            weapon_type = weapon.get("type", "")
            penalty = self.get_size_penalty(weapon_type, target_size)
            
            if penalty > best_penalty:
                best_penalty = penalty
                best_weapon = weapon_type
                
        if best_weapon:
            self.log.info(
                "optimal_weapon_found",
                size=target_size.value,
                weapon=best_weapon,
                penalty=best_penalty,
            )
            
        return best_weapon
        
    def suggest_cards_for_target(
        self,
        target_race: MonsterRace,
        target_size: MonsterSize,
        max_suggestions: int = 5,
    ) -> List[CardInfo]:
        """
        Suggest best cards for farming specific target.
        
        Args:
            target_race: Target race
            target_size: Target size
            max_suggestions: Maximum cards to suggest
            
        Returns:
            List of suggested cards
        """
        suggestions: List[CardInfo] = []
        
        # Add race cards
        race_cards = self.race_cards.get(target_race, [])
        suggestions.extend(race_cards[:max_suggestions])
        
        # Add size cards if space available
        if len(suggestions) < max_suggestions:
            size_cards = self.size_cards.get(target_size, [])
            remaining = max_suggestions - len(suggestions)
            suggestions.extend(size_cards[:remaining])
            
        self.log.info(
            "cards_suggested",
            race=target_race.value,
            size=target_size.value,
            count=len(suggestions),
        )
        
        return suggestions
        
    def analyze_equipment_for_target(
        self,
        weapon_type: str,
        equipped_cards: List[str],
        target_race: MonsterRace,
        target_size: MonsterSize,
    ) -> dict:
        """
        Comprehensive equipment analysis for target.
        
        Args:
            weapon_type: Current weapon type
            equipped_cards: Currently equipped cards
            target_race: Target race
            target_size: Target size
            
        Returns:
            Analysis dict with recommendations
        """
        modifier = self.calculate_total_modifier(
            weapon_type, equipped_cards, target_race, target_size
        )
        
        # Get suggested cards
        suggested_cards = self.suggest_cards_for_target(target_race, target_size)
        
        # Calculate potential improvement
        potential_bonus = sum(c.bonus_percent for c in suggested_cards[:4])
        potential_modifier = modifier.size_modifier * (1.0 + potential_bonus)
        improvement = potential_modifier / modifier.total_modifier if modifier.total_modifier > 0 else 1.0
        
        analysis = {
            "current_weapon": weapon_type,
            "target_race": target_race.value,
            "target_size": target_size.value,
            "current_modifier": modifier.total_modifier,
            "size_penalty": modifier.size_modifier,
            "race_bonus": modifier.race_modifier,
            "damage_percent": modifier.damage_percent,
            "equipped_cards": equipped_cards,
            "suggested_cards": [c.card_name for c in suggested_cards],
            "potential_improvement": improvement,
            "needs_optimization": improvement > 1.5,  # 50% improvement possible
        }
        
        return analysis