"""
Card system for OpenKore AI.

Provides card slotting, combo tracking, card removal risk calculation,
and optimal card configuration selection.
"""

import json
from enum import Enum
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from pydantic import BaseModel, ConfigDict, Field

logger = structlog.get_logger(__name__)


class CardSlotType(str, Enum):
    """Types of card slots"""
    WEAPON = "weapon"
    ARMOR = "armor"
    GARMENT = "garment"
    FOOTGEAR = "footgear"
    ACCESSORY = "accessory"
    HEADGEAR = "headgear"
    SHIELD = "shield"


class Card(BaseModel):
    """Card definition"""
    
    model_config = ConfigDict(frozen=True)
    
    card_id: int
    card_name: str
    slot_type: CardSlotType
    effects: Dict[str, Any] = Field(default_factory=dict)  # Effect descriptions
    combo_with: List[int] = Field(default_factory=list)  # Card IDs for combo
    market_value: int = 0
    drop_source: Optional[str] = None
    
    @property
    def has_combos(self) -> bool:
        """Check if card has combo potential"""
        return len(self.combo_with) > 0


class CardCombo(BaseModel):
    """Card combo definition"""
    
    model_config = ConfigDict(frozen=True)
    
    combo_id: int
    combo_name: str
    required_cards: List[int]
    combo_effect: str
    stat_bonus: Dict[str, int] = Field(default_factory=dict)
    is_complete: bool = False
    
    @property
    def card_count(self) -> int:
        """Get number of cards in combo"""
        return len(self.required_cards)


class CardManager:
    """
    Card slotting and combo system.
    
    Features:
    - Card slot management
    - Combo tracking
    - Card removal
    - Optimal card selection
    """
    
    def __init__(self, data_dir: Path):
        """
        Initialize card manager.
        
        Args:
            data_dir: Directory containing card data files
        """
        self.log = logger.bind(component="card_manager")
        self.data_dir = Path(data_dir)
        self.cards: Dict[int, Card] = {}
        self.combos: Dict[int, CardCombo] = {}
        self._load_card_data()
    
    def _load_card_data(self) -> None:
        """Load card definitions from data files"""
        card_file = self.data_dir / "cards.json"
        if not card_file.exists():
            self.log.warning("card_data_missing", file=str(card_file))
            return
        
        try:
            with open(card_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Load cards
            for card_data in data.get("cards", []):
                try:
                    card = Card(**card_data)
                    self.cards[card.card_id] = card
                except Exception as e:
                    self.log.error(
                        "card_parse_error",
                        card_id=card_data.get("card_id"),
                        error=str(e)
                    )
            
            # Load combos
            for combo_data in data.get("combos", []):
                try:
                    combo = CardCombo(**combo_data)
                    self.combos[combo.combo_id] = combo
                except Exception as e:
                    self.log.error(
                        "combo_parse_error",
                        combo_id=combo_data.get("combo_id"),
                        error=str(e)
                    )
            
            self.log.info(
                "card_data_loaded",
                cards=len(self.cards),
                combos=len(self.combos)
            )
        except Exception as e:
            self.log.error("card_data_load_error", error=str(e))
    
    def get_card(self, card_id: int) -> Optional[Card]:
        """Get card by ID"""
        return self.cards.get(card_id)
    
    def get_valid_cards(self, slot_type: CardSlotType) -> List[Card]:
        """
        Get cards valid for slot type.
        
        Args:
            slot_type: Type of equipment slot
            
        Returns:
            List of valid cards
        """
        return [
            card for card in self.cards.values()
            if card.slot_type == slot_type
        ]
    
    def check_combo(self, equipped_cards: List[int]) -> List[CardCombo]:
        """
        Check for active card combos.
        
        Args:
            equipped_cards: List of equipped card IDs
            
        Returns:
            List of active combos
        """
        active_combos = []
        equipped_set = set(equipped_cards)
        
        for combo in self.combos.values():
            required_set = set(combo.required_cards)
            if required_set.issubset(equipped_set):
                # All required cards are equipped
                active_combo = CardCombo(
                    combo_id=combo.combo_id,
                    combo_name=combo.combo_name,
                    required_cards=combo.required_cards,
                    combo_effect=combo.combo_effect,
                    stat_bonus=combo.stat_bonus,
                    is_complete=True
                )
                active_combos.append(active_combo)
        
        return active_combos
    
    def get_missing_combo_cards(
        self,
        combo_id: int,
        equipped_cards: List[int]
    ) -> List[int]:
        """
        Get cards needed to complete combo.
        
        Args:
            combo_id: Combo identifier
            equipped_cards: Currently equipped card IDs
            
        Returns:
            List of missing card IDs
        """
        combo = self.combos.get(combo_id)
        if not combo:
            return []
        
        equipped_set = set(equipped_cards)
        required_set = set(combo.required_cards)
        missing = required_set - equipped_set
        
        return list(missing)
    
    def calculate_card_removal_risk(
        self,
        item_id: int,
        card_count: int
    ) -> dict:
        """
        Calculate risks of card removal.
        
        Args:
            item_id: Item with cards
            card_count: Number of cards in item
            
        Returns:
            Risk analysis dict
        """
        # RO card removal mechanics
        # - Each card has a chance to be destroyed
        # - Risk increases with more cards
        
        base_success_rate = 100.0
        card_destruction_rate = 0.0
        
        if card_count == 1:
            base_success_rate = 90.0
            card_destruction_rate = 10.0
        elif card_count == 2:
            base_success_rate = 80.0
            card_destruction_rate = 20.0
        elif card_count == 3:
            base_success_rate = 70.0
            card_destruction_rate = 30.0
        elif card_count >= 4:
            base_success_rate = 60.0
            card_destruction_rate = 40.0
        
        return {
            "card_count": card_count,
            "success_rate": base_success_rate,
            "card_destruction_rate": card_destruction_rate,
            "item_destruction_rate": 0.0,  # Items don't break in RO
            "recommendation": (
                "Low risk" if base_success_rate >= 80
                else "Medium risk" if base_success_rate >= 70
                else "High risk"
            ),
        }
    
    def get_optimal_card_setup(
        self,
        character_state: dict,
        available_cards: List[int],
        equipment: dict
    ) -> dict:
        """
        Get optimal card configuration.
        
        Args:
            character_state: Character stats and build
            available_cards: Available card IDs
            equipment: Current equipment setup
            
        Returns:
            Optimal card configuration
        """
        # Analyze character build
        primary_stat = self._get_primary_stat(character_state)
        job = character_state.get("job", "Novice")
        
        recommendations = {}
        
        # For each equipment slot, recommend best cards
        for slot_name, item_info in equipment.items():
            if not item_info or not item_info.get("has_slots"):
                continue
            
            slot_type = self._map_equipment_to_card_slot(slot_name)
            if not slot_type:
                continue
            
            # Get valid cards for this slot
            valid_cards = self.get_valid_cards(slot_type)
            
            # Filter to available cards
            available_valid = [
                card for card in valid_cards
                if card.card_id in available_cards
            ]
            
            if not available_valid:
                continue
            
            # Score cards based on character build
            scored_cards = [
                (card, self._score_card_for_build(card, character_state))
                for card in available_valid
            ]
            
            # Sort by score
            scored_cards.sort(key=lambda x: x[1], reverse=True)
            
            # Recommend top cards
            slot_count = item_info.get("slot_count", 1)
            recommendations[slot_name] = [
                {
                    "card_id": card.card_id,
                    "card_name": card.card_name,
                    "score": score,
                    "effects": card.effects,
                }
                for card, score in scored_cards[:slot_count]
            ]
        
        # Check for possible combos with recommended setup
        recommended_card_ids = []
        for slot_recs in recommendations.values():
            recommended_card_ids.extend(rec["card_id"] for rec in slot_recs)
        
        possible_combos = self.check_combo(recommended_card_ids)
        
        return {
            "recommendations": recommendations,
            "active_combos": [
                {
                    "combo_id": combo.combo_id,
                    "combo_name": combo.combo_name,
                    "combo_effect": combo.combo_effect,
                    "stat_bonus": combo.stat_bonus,
                }
                for combo in possible_combos
            ],
            "total_cards_needed": len(recommended_card_ids),
        }
    
    def _get_primary_stat(self, character_state: dict) -> str:
        """Determine primary stat from character state"""
        stats = {
            "str": character_state.get("str", 0),
            "agi": character_state.get("agi", 0),
            "vit": character_state.get("vit", 0),
            "int": character_state.get("int", 0),
            "dex": character_state.get("dex", 0),
            "luk": character_state.get("luk", 0),
        }
        return max(stats, key=stats.get)
    
    def _map_equipment_to_card_slot(self, equipment_slot: str) -> Optional[CardSlotType]:
        """Map equipment slot to card slot type"""
        mapping = {
            "weapon": CardSlotType.WEAPON,
            "armor": CardSlotType.ARMOR,
            "garment": CardSlotType.GARMENT,
            "shoes": CardSlotType.FOOTGEAR,
            "accessory1": CardSlotType.ACCESSORY,
            "accessory2": CardSlotType.ACCESSORY,
            "headgear": CardSlotType.HEADGEAR,
            "shield": CardSlotType.SHIELD,
        }
        return mapping.get(equipment_slot.lower())
    
    def _score_card_for_build(self, card: Card, character_state: dict) -> float:
        """Score card based on character build"""
        score = 0.0
        
        # Base score from market value (rarity indicator)
        score += card.market_value * 0.001
        
        # Bonus for combo potential
        if card.has_combos:
            score += 50.0
        
        # Score based on effects matching build
        # This is simplified - real implementation would analyze effects deeply
        primary_stat = self._get_primary_stat(character_state)
        effects_str = str(card.effects).lower()
        
        if primary_stat in effects_str:
            score += 100.0
        
        # Job-specific bonuses
        job = character_state.get("job", "").lower()
        if job in effects_str:
            score += 75.0
        
        return score
    
    def get_statistics(self) -> dict:
        """
        Get card statistics.
        
        Returns:
            Statistics dictionary
        """
        slot_counts = {}
        combo_cards = set()
        
        for card in self.cards.values():
            slot_counts[card.slot_type] = slot_counts.get(
                card.slot_type, 0
            ) + 1
            if card.has_combos:
                combo_cards.add(card.card_id)
        
        return {
            "total_cards": len(self.cards),
            "by_slot_type": slot_counts,
            "total_combos": len(self.combos),
            "cards_with_combos": len(combo_cards),
        }