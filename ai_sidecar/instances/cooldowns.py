"""
Instance Cooldown Management System.

Tracks and manages instance cooldowns per character including daily/weekly
resets and optimal scheduling.
"""

from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple

import structlog
from pydantic import BaseModel, Field, ConfigDict

from ai_sidecar.instances.registry import InstanceRegistry

logger = structlog.get_logger(__name__)


class CooldownEntry(BaseModel):
    """Cooldown entry for an instance."""
    
    model_config = ConfigDict(arbitrary_types_allowed=True)
    
    instance_id: str
    character_name: str
    last_completed: datetime
    cooldown_ends: datetime
    times_completed_today: int = Field(default=0, ge=0)
    times_completed_week: int = Field(default=0, ge=0)
    
    @property
    def is_available(self) -> bool:
        """Check if cooldown has expired."""
        return datetime.now() >= self.cooldown_ends
    
    @property
    def time_until_available(self) -> timedelta:
        """Time until instance is available."""
        if self.is_available:
            return timedelta(0)
        return self.cooldown_ends - datetime.now()
    
    @property
    def hours_until_available(self) -> float:
        """Hours until available (rounded to 1 decimal)."""
        seconds = self.time_until_available.total_seconds()
        return round(seconds / 3600, 1)


class CooldownManager:
    """
    Manages instance cooldowns.
    
    Features:
    - Track cooldowns per character
    - Daily/weekly reset handling
    - Cooldown optimization
    - Schedule planning
    """
    
    # Reset times (in UTC)
    DAILY_RESET_HOUR = 0  # Midnight UTC
    WEEKLY_RESET_DAY = 2  # Tuesday (0=Monday)
    
    def __init__(self):
        """Initialize cooldown manager."""
        self.log = structlog.get_logger(__name__)
        self.cooldowns: Dict[Tuple[str, str], CooldownEntry] = {}  # (char, instance) -> entry
        self.last_daily_reset: Optional[datetime] = None
        self.last_weekly_reset: Optional[datetime] = None
        
        self._check_resets()
    
    def _check_resets(self) -> None:
        """Check and apply daily/weekly resets if needed."""
        now = datetime.now()
        
        # Check daily reset
        if self.last_daily_reset is None:
            self.last_daily_reset = now.replace(
                hour=self.DAILY_RESET_HOUR,
                minute=0,
                second=0,
                microsecond=0
            )
            if self.last_daily_reset > now:
                self.last_daily_reset -= timedelta(days=1)
        
        # Check if daily reset should occur
        next_daily = self.last_daily_reset + timedelta(days=1)
        if now >= next_daily:
            self._apply_daily_reset()
            self.last_daily_reset = next_daily
        
        # Check weekly reset
        if self.last_weekly_reset is None:
            # Find last Tuesday
            days_since_tuesday = (now.weekday() - self.WEEKLY_RESET_DAY) % 7
            self.last_weekly_reset = now - timedelta(days=days_since_tuesday)
            self.last_weekly_reset = self.last_weekly_reset.replace(
                hour=self.DAILY_RESET_HOUR,
                minute=0,
                second=0,
                microsecond=0
            )
        
        # Check if weekly reset should occur
        next_weekly = self.last_weekly_reset + timedelta(days=7)
        if now >= next_weekly:
            self._apply_weekly_reset()
            self.last_weekly_reset = next_weekly
    
    def _apply_daily_reset(self) -> None:
        """Apply daily reset to all cooldowns."""
        for entry in self.cooldowns.values():
            entry.times_completed_today = 0
        
        self.log.info("Daily reset applied")
    
    def _apply_weekly_reset(self) -> None:
        """Apply weekly reset to all cooldowns."""
        for entry in self.cooldowns.values():
            entry.times_completed_week = 0
        
        self.log.info("Weekly reset applied")
    
    async def check_cooldown(
        self,
        instance_id: str,
        character_name: str
    ) -> Tuple[bool, Optional[timedelta]]:
        """
        Check if instance is available.
        
        Args:
            instance_id: Instance identifier
            character_name: Character name
            
        Returns:
            Tuple of (is_available, time_until_available)
        """
        self._check_resets()
        
        key = (character_name, instance_id)
        
        if key not in self.cooldowns:
            return True, None
        
        entry = self.cooldowns[key]
        is_available = entry.is_available
        time_until = None if is_available else entry.time_until_available
        
        return is_available, time_until
    
    async def record_completion(
        self,
        instance_id: str,
        character_name: str,
        cooldown_hours: int
    ) -> None:
        """
        Record instance completion and set cooldown.
        
        Args:
            instance_id: Instance identifier
            character_name: Character name
            cooldown_hours: Cooldown duration in hours
        """
        now = datetime.now()
        cooldown_ends = now + timedelta(hours=cooldown_hours)
        
        key = (character_name, instance_id)
        
        if key in self.cooldowns:
            entry = self.cooldowns[key]
            entry.last_completed = now
            entry.cooldown_ends = cooldown_ends
            entry.times_completed_today += 1
            entry.times_completed_week += 1
        else:
            entry = CooldownEntry(
                instance_id=instance_id,
                character_name=character_name,
                last_completed=now,
                cooldown_ends=cooldown_ends,
                times_completed_today=1,
                times_completed_week=1
            )
            self.cooldowns[key] = entry
        
        self.log.info(
            "Instance cooldown recorded",
            instance=instance_id,
            character=character_name,
            cooldown_hours=cooldown_hours,
            available_at=cooldown_ends.strftime("%Y-%m-%d %H:%M")
        )
    
    async def get_available_instances(
        self,
        character_name: str,
        instance_registry: InstanceRegistry
    ) -> List[str]:
        """
        Get list of instances not on cooldown.
        
        Args:
            character_name: Character name
            instance_registry: Instance registry
            
        Returns:
            List of available instance IDs
        """
        self._check_resets()
        
        available: List[str] = []
        
        for instance_id in instance_registry.instances.keys():
            is_available, _ = await self.check_cooldown(instance_id, character_name)
            if is_available:
                available.append(instance_id)
        
        return available
    
    async def get_optimal_schedule(
        self,
        character_name: str,
        desired_instances: List[str]
    ) -> Dict[str, datetime]:
        """
        Plan optimal instance schedule.
        
        Consider:
        - Cooldown overlaps
        - Daily reset timing
        - Weekly reset timing
        - Instance efficiency
        
        Args:
            character_name: Character name
            desired_instances: List of instance IDs to schedule
            
        Returns:
            Dict mapping instance_id to recommended run time
        """
        schedule: Dict[str, datetime] = {}
        now = datetime.now()
        
        # Get current cooldown status
        cooldown_data: List[Tuple[str, bool, Optional[datetime]]] = []
        
        for instance_id in desired_instances:
            key = (character_name, instance_id)
            if key in self.cooldowns:
                entry = self.cooldowns[key]
                cooldown_data.append((
                    instance_id,
                    entry.is_available,
                    entry.cooldown_ends
                ))
            else:
                cooldown_data.append((instance_id, True, None))
        
        # Sort by availability (available first, then by cooldown end time)
        cooldown_data.sort(
            key=lambda x: (not x[1], x[2] or now)
        )
        
        # Schedule available instances immediately
        current_time = now
        for instance_id, is_available, cooldown_ends in cooldown_data:
            if is_available:
                schedule[instance_id] = current_time
                current_time += timedelta(hours=1)  # Space out by 1 hour
            else:
                # Schedule when available
                schedule[instance_id] = cooldown_ends or now
        
        return schedule
    
    async def handle_reset(self, reset_type: str) -> None:
        """
        Handle daily/weekly reset.
        
        Args:
            reset_type: "daily" or "weekly"
        """
        if reset_type == "daily":
            self._apply_daily_reset()
        elif reset_type == "weekly":
            self._apply_weekly_reset()
        else:
            self.log.warning(f"Unknown reset type: {reset_type}")
    
    def get_cooldown_summary(
        self,
        character_name: str
    ) -> Dict[str, any]:
        """
        Get cooldown summary for a character.
        
        Args:
            character_name: Character name
            
        Returns:
            Summary dict with cooldown info
        """
        self._check_resets()
        
        character_cooldowns = {
            instance_id: entry
            for (char, instance_id), entry in self.cooldowns.items()
            if char == character_name
        }
        
        available_count = sum(
            1 for entry in character_cooldowns.values()
            if entry.is_available
        )
        
        on_cooldown = [
            {
                "instance_id": entry.instance_id,
                "hours_remaining": entry.hours_until_available
            }
            for entry in character_cooldowns.values()
            if not entry.is_available
        ]
        
        return {
            "total_instances": len(character_cooldowns),
            "available": available_count,
            "on_cooldown": len(character_cooldowns) - available_count,
            "cooldown_details": on_cooldown,
            "times_run_today": sum(
                e.times_completed_today for e in character_cooldowns.values()
            ),
            "times_run_week": sum(
                e.times_completed_week for e in character_cooldowns.values()
            )
        }