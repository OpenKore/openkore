"""
Behavior randomization for anti-detection.

Injects random human-like behaviors to break patterns and simulate
natural player behavior including idle actions, social interactions,
and spontaneous activities.
"""

import json
import random
from datetime import datetime, timedelta
from enum import Enum
from pathlib import Path
from typing import Optional

import structlog
from pydantic import BaseModel, Field, ConfigDict

logger = structlog.get_logger(__name__)


class BehaviorCategory(str, Enum):
    """Categories of randomizable behavior."""
    COMBAT = "combat"
    MOVEMENT = "movement"
    CHAT = "chat"
    INVENTORY = "inventory"
    SOCIAL = "social"
    IDLE = "idle"


class RandomBehavior(BaseModel):
    """Random behavior to inject."""
    
    model_config = ConfigDict(frozen=False)
    
    behavior_type: str = Field(description="Type of behavior")
    description: str = Field(description="Human-readable description")
    duration_ms: int = Field(ge=0, description="How long behavior takes")
    can_interrupt: bool = Field(default=True, description="Can be interrupted")
    cooldown_ms: int = Field(default=0, ge=0, description="Cooldown before can trigger again")
    priority: int = Field(default=5, ge=1, le=10, description="Priority (1=highest)")
    
    # Optional parameters
    target_type: Optional[str] = Field(default=None, description="Target type if needed")
    emote: Optional[str] = Field(default=None, description="Emote command if applicable")
    message: Optional[str] = Field(default=None, description="Chat message if applicable")


class RandomBehaviorPool(BaseModel):
    """Pool of random behaviors to inject."""
    
    model_config = ConfigDict(frozen=False)
    
    category: BehaviorCategory = Field(description="Behavior category")
    behaviors: list[RandomBehavior] = Field(default_factory=list, description="Available behaviors")
    total_weight: float = Field(default=1.0, ge=0.0, description="Sum of all weights")
    last_triggered: Optional[datetime] = Field(default=None, description="Last time a behavior triggered")
    
    def select_behavior(self) -> Optional[RandomBehavior]:
        """Randomly select a behavior from pool."""
        return random.choice(self.behaviors) if self.behaviors else None


class ActionRandomizer:
    """
    Inject random action variations.
    
    Alias for BehaviorRandomizer for backward compatibility.
    """
    
    def __init__(self, data_dir: Path | None = None):
        """Initialize action randomizer."""
        self._randomizer = BehaviorRandomizer(data_dir or Path("data"))
    
    def __getattr__(self, name):
        """Delegate to BehaviorRandomizer."""
        return getattr(self._randomizer, name)
    
    def add_jitter(self, base_value: float, jitter_factor: float = 0.1) -> float:
        """
        Add random jitter to a value.
        
        Args:
            base_value: Base value to add jitter to
            jitter_factor: Jitter factor (0.1 = ±10%)
        
        Returns:
            Value with jitter applied
        """
        import random
        jitter_amount = base_value * jitter_factor
        return base_value + random.uniform(-jitter_amount, jitter_amount)


class BehaviorRandomizer:
    """
    Inject random human-like behaviors.
    
    Features:
    - Random idle animations
    - Spontaneous emotes
    - Inventory checking
    - Looking at other players
    - Reading chat
    - AFK behaviors
    """
    
    def __init__(self, data_dir: Path):
        self.log = structlog.get_logger()
        self.data_dir = data_dir
        self.behavior_pools: dict[BehaviorCategory, RandomBehaviorPool] = {}
        self.behavior_history: list[tuple[datetime, str]] = []
        self.last_injection_time = datetime.now()
        self._load_behavior_pools()
        self.log.info("behavior_randomizer_initialized", pools=len(self.behavior_pools))
        
    def _load_behavior_pools(self) -> None:
        """Load behavior pools from configuration."""
        behaviors_file = self.data_dir / "human_behaviors.json"
        
        if not behaviors_file.exists():
            self.log.warning("human_behaviors.json not found, using defaults")
            self._create_default_pools()
            return
        
        try:
            with open(behaviors_file, "r") as f:
                data = json.load(f)
            
            # Load idle behaviors
            idle_behaviors = [
                RandomBehavior(
                    behavior_type=b["type"],
                    description=f"Idle: {b['type']}",
                    duration_ms=b["duration_ms"],
                    cooldown_ms=b.get("cooldown_ms", 10000),
                    emote=b.get("emote")
                )
                for b in data.get("idle_behaviors", [])
            ]
            
            self.behavior_pools[BehaviorCategory.IDLE] = RandomBehaviorPool(
                category=BehaviorCategory.IDLE,
                behaviors=idle_behaviors
            )
            
            # Load social behaviors
            social_behaviors = [
                RandomBehavior(
                    behavior_type=b["type"],
                    description=f"Social: {b['type']}",
                    duration_ms=b.get("duration_ms", 2000),
                    target_type=b.get("target"),
                    emote=b.get("emote"),
                    message=b.get("message")
                )
                for b in data.get("social_behaviors", [])
            ]
            
            self.behavior_pools[BehaviorCategory.SOCIAL] = RandomBehaviorPool(
                category=BehaviorCategory.SOCIAL,
                behaviors=social_behaviors
            )
            
            self.log.info("behavior_pools_loaded", file=str(behaviors_file))
            
        except Exception as e:
            self.log.error("failed_to_load_behaviors", error=str(e))
            self._create_default_pools()
    
    def _create_default_pools(self) -> None:
        """Create default behavior pools."""
        idle_behaviors = [
            RandomBehavior(behavior_type="sit", description="Sit down", duration_ms=5000, cooldown_ms=30000),
            RandomBehavior(behavior_type="jump", description="Jump", duration_ms=500, cooldown_ms=10000),
            RandomBehavior(behavior_type="open_inventory", description="Check inventory", duration_ms=3000, cooldown_ms=20000),
            RandomBehavior(behavior_type="open_map", description="Check map", duration_ms=2000, cooldown_ms=15000),
        ]
        
        social_behaviors = [
            RandomBehavior(behavior_type="wave", description="Wave at player", duration_ms=1000, target_type="nearby_player"),
            RandomBehavior(behavior_type="emote", description="Show emote", duration_ms=1000, emote="/heh"),
        ]
        
        self.behavior_pools[BehaviorCategory.IDLE] = RandomBehaviorPool(
            category=BehaviorCategory.IDLE, behaviors=idle_behaviors
        )
        self.behavior_pools[BehaviorCategory.SOCIAL] = RandomBehaviorPool(
            category=BehaviorCategory.SOCIAL, behaviors=social_behaviors
        )
    
    def should_inject_random_behavior(
        self,
        current_activity: str,
        time_in_activity_ms: int
    ) -> tuple[bool, Optional[RandomBehavior]]:
        """
        Determine if we should inject random behavior.
        More likely after long periods of same activity.
        """
        critical_activities = ["combat", "trading", "dialogue", "boss_fight"]
        if current_activity in critical_activities:
            return False, None
        
        # Calculate injection probability
        time_minutes = time_in_activity_ms / 60000.0
        base_chance = 0.15 if time_minutes > 10 else (0.10 if time_minutes > 5 else 0.05)
        
        time_since_last = (datetime.now() - self.last_injection_time).total_seconds()
        if time_since_last < 30:
            return False, None
        
        if random.random() < base_chance:
            category = BehaviorCategory.IDLE if current_activity == "idle" else random.choice([BehaviorCategory.IDLE, BehaviorCategory.SOCIAL])
            pool = self.behavior_pools.get(category)
            
            if pool and (behavior := pool.select_behavior()):
                self.last_injection_time = datetime.now()
                self.behavior_history.append((datetime.now(), behavior.behavior_type))
                self.log.info("injecting_random_behavior", behavior=behavior.behavior_type, category=category.value)
                return True, behavior
        
        return False, None
    
    def get_random_idle_behavior(self) -> Optional[RandomBehavior]:
        """Get random idle behavior to execute."""
        pool = self.behavior_pools.get(BehaviorCategory.IDLE)
        return pool.select_behavior() if pool else None
    
    def get_random_social_behavior(self, nearby_players: list[str]) -> Optional[RandomBehavior]:
        """Get random social interaction with nearby players."""
        if not nearby_players:
            return None
        
        pool = self.behavior_pools.get(BehaviorCategory.SOCIAL)
        if pool and random.random() < 0.1:
            if behavior := pool.select_behavior():
                behavior.target_type = random.choice(nearby_players)
                self.log.debug("social_behavior_selected", behavior=behavior.behavior_type, target=behavior.target_type)
                return behavior
        
        return None
    
    def inject_inventory_check(self) -> RandomBehavior:
        """Random inventory checking behavior."""
        return RandomBehavior(
            behavior_type="open_inventory",
            description="Check inventory",
            duration_ms=random.randint(2000, 5000),
            cooldown_ms=30000,
            priority=6
        )
    
    def inject_map_check(self) -> RandomBehavior:
        """Random map checking behavior."""
        return RandomBehavior(
            behavior_type="open_map",
            description="Check map",
            duration_ms=random.randint(1500, 3000),
            cooldown_ms=20000,
            priority=6
        )
    
    def inject_status_check(self) -> RandomBehavior:
        """Random status/skill window checking."""
        check_type = random.choice(["status", "skills", "equipment", "quest"])
        return RandomBehavior(
            behavior_type=f"open_{check_type}",
            description=f"Check {check_type}",
            duration_ms=random.randint(2000, 4000),
            cooldown_ms=25000,
            priority=7
        )
    
    def get_spontaneous_emote(self) -> Optional[str]:
        """Get random spontaneous emote (2% chance)."""
        emotes = ["/lv", "/heh", "/hmm", "/gg", "/ok", "/no", "/swt", "/kis", "/dum", "/sry"]
        return random.choice(emotes) if random.random() < 0.02 else None
    
    def vary_target_selection(self, targets: list[dict], optimal_target: dict) -> dict:
        """
        Sometimes don't pick the optimal target (15% chance).
        Humans make suboptimal choices.
        """
        if not targets or random.random() < 0.85:
            return optimal_target
        
        other_targets = [t for t in targets if t != optimal_target]
        if other_targets:
            suboptimal = random.choice(other_targets)
            self.log.debug("suboptimal_target_selected", optimal_id=optimal_target.get("actor_id"), selected_id=suboptimal.get("actor_id"))
            return suboptimal
        
        return optimal_target
    
    def should_check_surroundings(self) -> bool:
        """Random chance to look around (5% per check)."""
        return random.random() < 0.05
    
    def get_random_camera_movement(self) -> tuple[float, float]:
        """Generate random camera movement (angle, duration)."""
        return random.uniform(-45, 45), random.uniform(500, 2000)
    
    def should_sit_and_rest(self, hp_percent: float, sp_percent: float) -> bool:
        """Determine if player should sit and rest."""
        if hp_percent < 30 or sp_percent < 20:
            return True
        if hp_percent < 60 or sp_percent < 40:
            return random.random() < 0.3
        return random.random() < 0.01
    
    def get_afk_behavior(self, duration_seconds: int) -> list[RandomBehavior]:
        """Generate realistic AFK behavior sequence."""
        behaviors = [
            RandomBehavior(
                behavior_type="sit",
                description="Sit down for AFK",
                duration_ms=duration_seconds * 1000,
                can_interrupt=False,
                priority=1
            )
        ]
        
        if duration_seconds > 60 and random.random() < 0.5:
            behaviors.append(RandomBehavior(
                behavior_type="micro_movement",
                description="Small position adjustment",
                duration_ms=500,
                priority=8
            ))
        
        return behaviors
    
    def should_make_typo_in_combat(self) -> bool:
        """Combat typo chance (3% - higher under pressure)."""
        return random.random() < 0.03
    
    def get_panic_behavior(self, threat_level: float) -> Optional[RandomBehavior]:
        """Get panic-induced behavior based on threat level."""
        if threat_level < 0.7:
            return None
        
        panic_behaviors = ["spam_heal_key", "spam_teleport", "erratic_movement", "panic_item_use"]
        panic_chance = (threat_level - 0.7) / 0.3 * 0.2
        
        if random.random() < panic_chance:
            return RandomBehavior(
                behavior_type=random.choice(panic_behaviors),
                description=f"Panic behavior",
                duration_ms=random.randint(500, 2000),
                can_interrupt=True,
                priority=2
            )
        
        return None
    
    def get_celebration_emote(self) -> Optional[str]:
        """Get celebration emote after achievement (30% chance)."""
        celebration_emotes = ["/gg", "/heh", "/lv", "/kis", "/ok"]
        return random.choice(celebration_emotes) if random.random() < 0.3 else None
    
    def clear_old_history(self, hours: int = 1) -> None:
        """Clear behavior history older than specified hours."""
        cutoff = datetime.now() - timedelta(hours=hours)
        self.behavior_history = [(t, b) for t, b in self.behavior_history if t > cutoff]
    
    def get_behavior_stats(self) -> dict:
        """Get behavior injection statistics."""
        if not self.behavior_history:
            return {"total_injections": 0, "recent_count": 0}
        
        recent_cutoff = datetime.now() - timedelta(hours=1)
        recent = [b for t, b in self.behavior_history if t > recent_cutoff]
        
        behavior_counts = {}
        for _, behavior in self.behavior_history:
            behavior_counts[behavior] = behavior_counts.get(behavior, 0) + 1
        
        return {
            "total_injections": len(self.behavior_history),
            "recent_count": len(recent),
            "behavior_distribution": behavior_counts,
            "time_since_last_injection": (datetime.now() - self.last_injection_time).total_seconds()
        }