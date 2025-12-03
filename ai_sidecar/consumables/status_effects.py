"""
Status Effect Management System - P0 Critical Component.

Provides intelligent status effect detection, prioritization, and curing
with life-saving emergency handling for Ragnarok Online.
"""

import json
from datetime import datetime
from enum import Enum, IntEnum
from pathlib import Path
from typing import Any, Dict, List, Optional, Set

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class StatusEffectType(str, Enum):
    """All status effects in RO."""
    
    # Negative (debuffs) - Critical
    STONE = "stone"                    # Stone Curse - CRITICAL
    FREEZE = "freeze"                  # Frozen - CRITICAL
    STUN = "stun"                      # Stunned - HIGH
    SLEEP = "sleep"                    # Sleeping - HIGH
    
    # Negative - High Priority
    SILENCE = "silence"                # Silenced (blocks spells)
    CONFUSION = "confusion"            # Confused (random movement)
    BLIND = "blind"                    # Blinded (reduced hit rate)
    
    # Negative - Medium Priority
    POISON = "poison"                  # Poisoned (DoT)
    CURSE = "curse"                    # Cursed (-LUK, -stats)
    BLEEDING = "bleeding"              # Bleeding (DoT)
    BURNING = "burning"                # Burning (DoT)
    
    # Negative - Advanced
    FEAR = "fear"                      # Fear (flee reduction)
    CRYSTALLIZE = "crystallize"        # Crystal (DEF down, water vuln)
    DEEP_SLEEP = "deep_sleep"          # Deep Sleep (harder to wake)
    HALLUCINATION = "hallucination"    # Hallucination
    MANDRAGORA = "mandragora"          # Howling of Mandragora
    MARSH_OF_ABYSS = "marsh_of_abyss"  # Marsh of Abyss
    CHAOS = "chaos"                    # Chaos
    
    # Positive (track but don't cure)
    BERSERK = "berserk"                # Berserk mode
    PROVOKE = "provoke"                # Provoke (can be buff or debuff)


class StatusSeverity(IntEnum):
    """Severity for cure prioritization."""
    
    CRITICAL = 10    # Must cure immediately (Stone, Freeze)
    HIGH = 7         # Cure ASAP (Stun, Sleep, Silence for casters)
    MEDIUM = 5       # Cure when convenient (Poison, Blind)
    LOW = 3          # Minor annoyance (Curse)
    IGNORE = 0       # Don't bother curing (some situational)


class StatusCure(BaseModel):
    """How to cure a status effect."""
    
    status: StatusEffectType
    cure_items: List[str] = Field(default_factory=list)
    cure_skills: List[str] = Field(default_factory=list)
    immunity_items: List[str] = Field(default_factory=list)
    immunity_skills: List[str] = Field(default_factory=list)
    natural_duration: float = 0.0
    can_be_cured: bool = True
    notes: str = ""


class StatusEffectState(BaseModel):
    """Current status effect on character."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    effect_type: StatusEffectType
    severity: StatusSeverity
    inflicted_time: datetime
    estimated_duration: Optional[float] = None
    source_monster: Optional[str] = None
    damage_per_tick: Optional[int] = None  # For DoT effects
    
    @property
    def age_seconds(self) -> float:
        """Get how long this effect has been active."""
        return (datetime.now() - self.inflicted_time).total_seconds()
    
    @property
    def is_recent(self) -> bool:
        """Check if effect was inflicted recently (< 1 second)."""
        return self.age_seconds < 1.0


class CureAction(BaseModel):
    """Action to cure a status effect."""
    
    effect_type: StatusEffectType
    method: str  # "item", "skill", "wait"
    item_name: Optional[str] = None
    skill_name: Optional[str] = None
    priority: int
    wait_seconds: float = 0.0


class ImmunityRecommendation(BaseModel):
    """Recommendation to apply immunity."""
    
    status: StatusEffectType
    reason: str
    method: str  # "item" or "skill"
    item_name: Optional[str] = None
    skill_name: Optional[str] = None
    priority: int = 5


class StatusEffectManager:
    """
    Intelligent status effect handling.
    
    Features:
    - Automatic status detection via game state
    - Priority-based curing (Stone > Poison > Blind)
    - Cure item inventory management
    - Immunity tracking
    - Pre-emptive immunity application
    - Emergency cure (0.5s response for critical effects)
    """
    
    def __init__(self, data_path: Optional[Path] = None):
        """
        Initialize status effect manager.
        
        Args:
            data_path: Path to status effects data JSON file
        """
        self.log = structlog.get_logger(__name__)
        self.active_effects: Dict[StatusEffectType, StatusEffectState] = {}
        self.status_database: Dict[str, Dict[str, Any]] = {}
        self.cure_history: List[tuple[StatusEffectType, datetime, bool]] = []
        self.immunity_active: Set[StatusEffectType] = set()
        
        # Load status effect database
        if data_path:
            self._load_status_database(data_path)
        else:
            # Add default test data
            self._load_default_status_data()
        
        self.log.info("StatusEffectManager initialized")
    
    def _load_default_status_data(self) -> None:
        """Load default status effect data for testing."""
        self.status_database = {
            "stone": {
                "severity": 10,
                "cure_items": ["Blue Gemstone"],
                "cure_skills": ["Resurrection"],
                "immunity_items": ["Panacea"],
                "can_be_cured": True,
                "natural_duration": 30.0,
            },
            "freeze": {
                "severity": 10,
                "cure_items": ["Ice Pick"],
                "cure_skills": [],
                "immunity_items": ["Marc Card"],
                "can_be_cured": True,
                "natural_duration": 30.0,
            },
            "poison": {
                "severity": 5,
                "cure_items": ["Green Potion", "Royal Jelly"],
                "cure_skills": ["Cure"],
                "immunity_items": ["Panacea"],
                "can_be_cured": True,
                "natural_duration": 60.0,
            },
            "blind": {
                "severity": 5,
                "cure_items": ["Eye Drops"],
                "cure_skills": ["Cure"],
                "immunity_items": [],
                "can_be_cured": True,
                "natural_duration": 30.0,
            },
        }
    
    def _load_status_database(self, data_path: Path) -> None:
        """
        Load status effect definitions from JSON file.
        
        Args:
            data_path: Path to status_effects.json
        """
        try:
            with open(data_path, "r") as f:
                self.status_database = json.load(f)
            
            self.log.info(
                "Loaded status effect database",
                effect_count=len(self.status_database),
            )
        except Exception as e:
            self.log.error("Failed to load status database", error=str(e))
    
    async def detect_status_effects(self, game_state: Dict[str, Any]) -> List[StatusEffectState]:
        """
        Detect current status effects from game state.
        
        Args:
            game_state: Current game state from OpenKore
            
        Returns:
            List of detected status effects
        """
        detected: List[StatusEffectState] = []
        
        # Parse status from game state
        # This would integrate with OpenKore's status packet parsing
        status_list = game_state.get("character", {}).get("status_effects", [])
        
        for status_id in status_list:
            effect_type = self._map_status_id(status_id)
            if not effect_type:
                continue
            
            # Check if already tracked
            if effect_type in self.active_effects:
                detected.append(self.active_effects[effect_type])
            else:
                # New status effect detected
                severity = self._get_severity(effect_type)
                
                effect_state = StatusEffectState(
                    effect_type=effect_type,
                    severity=severity,
                    inflicted_time=datetime.now(),
                )
                
                self.active_effects[effect_type] = effect_state
                detected.append(effect_state)
                
                self.log.warning(
                    "Status effect detected",
                    effect=effect_type.value,
                    severity=severity,
                )
        
        # Remove effects no longer in game state
        current_types = {self._map_status_id(sid) for sid in status_list}
        to_remove = [
            eff for eff in self.active_effects.keys()
            if eff not in current_types
        ]
        for eff in to_remove:
            del self.active_effects[eff]
        
        return detected
    
    def _map_status_id(self, status_id: str) -> Optional[StatusEffectType]:
        """Map game status ID to StatusEffectType."""
        # This would use OpenKore's status ID mapping
        # For now, simple mapping
        mapping = {
            "SC_STONE": StatusEffectType.STONE,
            "SC_FREEZE": StatusEffectType.FREEZE,
            "SC_STUN": StatusEffectType.STUN,
            "SC_SLEEP": StatusEffectType.SLEEP,
            "SC_POISON": StatusEffectType.POISON,
            "SC_SILENCE": StatusEffectType.SILENCE,
            "SC_CONFUSION": StatusEffectType.CONFUSION,
            "SC_BLIND": StatusEffectType.BLIND,
            "SC_CURSE": StatusEffectType.CURSE,
            "SC_BLEEDING": StatusEffectType.BLEEDING,
        }
        return mapping.get(status_id)
    
    def _get_severity(self, effect: StatusEffectType) -> StatusSeverity:
        """Get severity level for a status effect."""
        if effect.value in self.status_database:
            return StatusSeverity(
                self.status_database[effect.value].get("severity", 5)
            )
        
        # Defaults
        critical_effects = {StatusEffectType.STONE, StatusEffectType.FREEZE}
        high_effects = {
            StatusEffectType.STUN,
            StatusEffectType.SLEEP,
            StatusEffectType.SILENCE,
        }
        
        if effect in critical_effects:
            return StatusSeverity.CRITICAL
        elif effect in high_effects:
            return StatusSeverity.HIGH
        else:
            return StatusSeverity.MEDIUM
    
    async def prioritize_cures(
        self,
        effects: List[StatusEffectState],
    ) -> List[StatusEffectState]:
        """
        Sort effects by cure priority.
        
        Args:
            effects: List of status effects
            
        Returns:
            Sorted list (highest priority first)
        """
        return sorted(effects, key=lambda e: e.severity, reverse=True)
    
    async def get_cure_action(
        self,
        effect: StatusEffectState,
        available_items: Optional[Set[str]] = None,
        available_sp: int = 0,
    ) -> Optional[CureAction]:
        """
        Determine best cure method.
        
        Decision logic:
        - Item if skill on cooldown or no SP
        - Skill if efficient and available
        - Wait if about to expire naturally
        
        Args:
            effect: Status effect to cure
            available_items: Set of available cure items
            available_sp: Current SP available
            
        Returns:
            Cure action or None if can't cure
        """
        if effect.effect_type.value not in self.status_database:
            return None
        
        cure_data = self.status_database[effect.effect_type.value]
        
        # Check if can't be cured
        if not cure_data.get("can_be_cured", True):
            # Wait for natural expiration
            natural_duration = cure_data.get("natural_duration", 5.0)
            return CureAction(
                effect_type=effect.effect_type,
                method="wait",
                priority=effect.severity,
                wait_seconds=natural_duration,
            )
        
        # Try item cure first (more reliable)
        cure_items = cure_data.get("cure_items", [])
        if cure_items and available_items:
            for item in cure_items:
                if item in available_items:
                    return CureAction(
                        effect_type=effect.effect_type,
                        method="item",
                        item_name=item,
                        priority=effect.severity,
                    )
        
        # Try skill cure
        cure_skills = cure_data.get("cure_skills", [])
        if cure_skills and available_sp > 0:
            # Would need to check SP costs
            skill = cure_skills[0]
            return CureAction(
                effect_type=effect.effect_type,
                method="skill",
                skill_name=skill,
                priority=effect.severity,
            )
        
        # As last resort, return a cure recommendation even without items
        # This indicates the need exists (coordinator can handle unavailability)
        if cure_items:
            return CureAction(
                effect_type=effect.effect_type,
                method="item",
                item_name=cure_items[0],
                priority=effect.severity,
            )
        
        return None
    
    async def should_apply_immunity(
        self,
        map_name: str,
        monsters: List[str],
    ) -> List[ImmunityRecommendation]:
        """
        Check if immunity items should be used proactively.
        
        Based on:
        - Map monster spawn data
        - Known monster abilities
        - Previous status effect history
        
        Args:
            map_name: Current map
            monsters: List of monsters on map
            
        Returns:
            List of immunity recommendations
        """
        recommendations: List[ImmunityRecommendation] = []
        
        # Check recent status history
        recent_effects = self._get_recent_effects(seconds=60)
        
        # Recommend immunity for frequently occurring effects
        for effect_type, count in recent_effects.items():
            if count >= 3:  # 3+ times in last minute
                if effect_type.value not in self.status_database:
                    continue
                
                data = self.status_database[effect_type.value]
                immunity_items = data.get("immunity_items", [])
                
                if immunity_items:
                    recommendations.append(
                        ImmunityRecommendation(
                            status=effect_type,
                            reason=f"Frequent occurrence ({count} times/min)",
                            method="item",
                            item_name=immunity_items[0],
                            priority=8,
                        )
                    )
        
        return recommendations
    
    def _get_recent_effects(self, seconds: float = 60) -> Dict[StatusEffectType, int]:
        """Get count of recent status effects."""
        cutoff = datetime.now().timestamp() - seconds
        counts: Dict[StatusEffectType, int] = {}
        
        for effect_type, timestamp, _ in self.cure_history:
            if timestamp.timestamp() >= cutoff:
                counts[effect_type] = counts.get(effect_type, 0) + 1
        
        return counts
    
    async def track_cure_effectiveness(
        self,
        action: CureAction,
        success: bool,
    ) -> None:
        """
        Learn which cures work in which situations.
        
        Args:
            action: Cure action that was attempted
            success: Whether cure was successful
        """
        self.cure_history.append((action.effect_type, datetime.now(), success))
        
        # Limit history size
        if len(self.cure_history) > 1000:
            self.cure_history = self.cure_history[-500:]
        
        if success:
            self.log.debug(
                "Cure successful",
                effect=action.effect_type.value,
                method=action.method,
            )
        else:
            self.log.warning(
                "Cure failed",
                effect=action.effect_type.value,
                method=action.method,
            )
    
    def has_critical_status(self) -> bool:
        """
        Check if character has any critical status effects.
        
        Returns:
            True if any critical status is active
        """
        return any(
            effect.severity == StatusSeverity.CRITICAL
            for effect in self.active_effects.values()
        )
    
    def get_status_summary(self) -> Dict[str, Any]:
        """
        Get summary of current status effects.
        
        Returns:
            Dict with counts and details
        """
        return {
            "total_active": len(self.active_effects),
            "critical_count": sum(
                1 for e in self.active_effects.values()
                if e.severity == StatusSeverity.CRITICAL
            ),
            "high_priority_count": sum(
                1 for e in self.active_effects.values()
                if e.severity == StatusSeverity.HIGH
            ),
            "effects": [
                {
                    "type": e.effect_type.value,
                    "severity": e.severity,
                    "age_seconds": e.age_seconds,
                }
                for e in self.active_effects.values()
            ],
        }
    
    def clear_effect(self, effect_type: StatusEffectType) -> None:
        """
        Clear a status effect (after successful cure).
        
        Args:
            effect_type: Status effect to clear
        """
        if effect_type in self.active_effects:
            del self.active_effects[effect_type]
            self.log.debug("Status effect cleared", effect=effect_type.value)
    
    def add_immunity(self, effect_type: StatusEffectType) -> None:
        """
        Mark immunity as active for a status effect.
        
        Args:
            effect_type: Status effect with immunity
        """
        self.immunity_active.add(effect_type)
        self.log.debug("Immunity activated", effect=effect_type.value)
    
    def remove_immunity(self, effect_type: StatusEffectType) -> None:
        """
        Remove immunity status.
        
        Args:
            effect_type: Status effect to remove immunity for
        """
        self.immunity_active.discard(effect_type)
        self.log.debug("Immunity expired", effect=effect_type.value)
    
    def add_status_effect(
        self,
        effect_type: StatusEffectType | str,
        source_monster: Optional[str] = None,
        duration: Optional[float] = None
    ) -> None:
        """
        Add a status effect to character.
        
        Args:
            effect_type: Type of status effect (enum or string)
            source_monster: Monster that inflicted it
            duration: Effect duration in seconds
        """
        # Convert string to enum if needed
        if isinstance(effect_type, str):
            try:
                effect_type = StatusEffectType(effect_type.lower())
            except ValueError:
                self.log.warning(f"Unknown status effect: {effect_type}")
                return
        
        severity = self._get_severity(effect_type)
        
        effect_state = StatusEffectState(
            effect_type=effect_type,
            severity=severity,
            inflicted_time=datetime.now(),
            estimated_duration=duration,
            source_monster=source_monster,
        )
        
        self.active_effects[effect_type] = effect_state
        
        self.log.warning(
            "status_effect_added",
            effect=effect_type.value,
            severity=severity,
            source=source_monster
        )