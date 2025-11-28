"""
Quest data models for AI Sidecar.

Defines Pydantic v2 models for quest tracking, objectives,
rewards, and quest log management.
"""

from datetime import datetime
from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field, ConfigDict


class QuestObjectiveType(str, Enum):
    """Types of quest objectives."""

    KILL_MONSTER = "kill_monster"
    COLLECT_ITEM = "collect_item"
    DELIVER_ITEM = "deliver_item"
    TALK_TO_NPC = "talk_to_npc"
    VISIT_LOCATION = "visit_location"
    USE_SKILL = "use_skill"
    REACH_LEVEL = "reach_level"


class QuestObjective(BaseModel):
    """Individual quest objective with progress tracking."""

    model_config = ConfigDict(frozen=False)

    objective_id: str = Field(description="Unique objective identifier")
    objective_type: QuestObjectiveType = Field(description="Type of objective")
    target_id: int = Field(description="Monster ID, Item ID, NPC ID, etc.")
    target_name: str = Field(description="Human-readable target name")
    required_count: int = Field(ge=1, description="Number required to complete")
    current_count: int = Field(default=0, ge=0, description="Current progress")

    # Location data (for location-based objectives)
    map_name: str | None = Field(default=None, description="Map for objective")
    x: int | None = Field(default=None, ge=0, description="X coordinate if applicable")
    y: int | None = Field(default=None, ge=0, description="Y coordinate if applicable")

    completed: bool = Field(default=False, description="Is objective completed")

    @property
    def progress_percent(self) -> float:
        """Calculate progress percentage."""
        if self.required_count == 0:
            return 100.0
        return (self.current_count / self.required_count) * 100

    def is_complete(self) -> bool:
        """Check if objective is complete."""
        return self.current_count >= self.required_count

    def update_progress(self, count: int) -> bool:
        """
        Update objective progress.

        Args:
            count: Amount to add to current count

        Returns:
            True if objective completed after update
        """
        self.current_count += count
        if self.current_count >= self.required_count:
            self.completed = True
        return self.completed


class QuestReward(BaseModel):
    """Quest completion reward."""

    model_config = ConfigDict(frozen=True)

    reward_type: Literal["item", "zeny", "exp_base", "exp_job", "skill_point"] = Field(
        description="Type of reward"
    )
    item_id: int | None = Field(default=None, description="Item ID for item rewards")
    amount: int = Field(ge=1, description="Amount of reward")

    def __str__(self) -> str:
        """String representation of reward."""
        if self.reward_type == "item":
            return f"{self.amount}x Item[{self.item_id}]"
        elif self.reward_type == "zeny":
            return f"{self.amount} Zeny"
        elif self.reward_type == "exp_base":
            return f"{self.amount} Base EXP"
        elif self.reward_type == "exp_job":
            return f"{self.amount} Job EXP"
        elif self.reward_type == "skill_point":
            return f"{self.amount} Skill Point(s)"
        return f"{self.reward_type}: {self.amount}"


class Quest(BaseModel):
    """Quest with objectives, rewards, and state tracking."""

    model_config = ConfigDict(frozen=False)

    # Identity
    quest_id: int = Field(description="Unique quest ID")
    name: str = Field(description="Quest name")
    description: str = Field(description="Quest description/story")

    # Quest giver
    npc_id: int = Field(description="Quest giver NPC ID")
    npc_name: str = Field(description="Quest giver NPC name")

    # Quest chain
    prerequisite_quests: list[int] = Field(
        default_factory=list, description="Quests that must be completed first"
    )
    next_quests: list[int] = Field(
        default_factory=list, description="Quests unlocked by completing this"
    )

    # Requirements
    min_level: int = Field(default=1, ge=1, description="Minimum level required")
    max_level: int = Field(default=999, ge=1, description="Maximum level allowed")
    required_job: str | None = Field(
        default=None, description="Required job class if any"
    )

    # State
    status: Literal[
        "not_started", "in_progress", "ready_to_turn_in", "completed", "failed"
    ] = Field(default="not_started", description="Quest status")

    objectives: list[QuestObjective] = Field(
        default_factory=list, description="Quest objectives"
    )
    rewards: list[QuestReward] = Field(
        default_factory=list, description="Quest rewards"
    )

    # Tracking
    started_at: datetime | None = Field(default=None, description="When quest started")
    completed_at: datetime | None = Field(
        default=None, description="When quest completed"
    )
    turn_in_npc_id: int | None = Field(
        default=None, description="NPC ID for turn-in (if different from giver)"
    )

    # Metadata
    is_repeatable: bool = Field(default=False, description="Can quest be repeated")
    is_daily: bool = Field(default=False, description="Is this a daily quest")
    time_limit_seconds: int | None = Field(
        default=None, description="Time limit in seconds if applicable"
    )

    @property
    def all_objectives_complete(self) -> bool:
        """Check if all objectives are complete."""
        return all(obj.is_complete() for obj in self.objectives)

    @property
    def progress_percent(self) -> float:
        """Calculate overall quest progress percentage."""
        if not self.objectives:
            return 0.0

        total_progress = sum(obj.progress_percent for obj in self.objectives)
        return total_progress / len(self.objectives)

    def start(self) -> None:
        """Start the quest."""
        self.status = "in_progress"
        self.started_at = datetime.now()

    def complete(self) -> None:
        """Mark quest as completed."""
        self.status = "completed"
        self.completed_at = datetime.now()

    def fail(self) -> None:
        """Mark quest as failed."""
        self.status = "failed"

    def is_eligible(self, level: int, job: str) -> bool:
        """
        Check if character is eligible for this quest.

        Args:
            level: Character level
            job: Character job class

        Returns:
            True if eligible
        """
        if level < self.min_level or level > self.max_level:
            return False

        if self.required_job and self.required_job != job:
            return False

        return True

    def get_objective_by_type(
        self, objective_type: QuestObjectiveType
    ) -> list[QuestObjective]:
        """Get objectives of specific type."""
        return [obj for obj in self.objectives if obj.objective_type == objective_type]

    def update_objective(
        self, objective_id: str, count: int = 1
    ) -> QuestObjective | None:
        """
        Update specific objective progress.

        Args:
            objective_id: ID of objective to update
            count: Amount to add

        Returns:
            Updated objective or None if not found
        """
        for obj in self.objectives:
            if obj.objective_id == objective_id:
                obj.update_progress(count)
                # Check if all objectives complete
                if self.all_objectives_complete:
                    self.status = "ready_to_turn_in"
                return obj
        return None


class QuestLog(BaseModel):
    """Player's quest log with active and completed quests."""

    model_config = ConfigDict(frozen=False)

    active_quests: list[Quest] = Field(
        default_factory=list, description="Currently active quests"
    )
    completed_quests: list[int] = Field(
        default_factory=list, description="Completed quest IDs"
    )
    daily_quests_completed: dict[int, datetime] = Field(
        default_factory=dict, description="Daily quest completion timestamps"
    )
    failed_quests: list[int] = Field(
        default_factory=list, description="Failed quest IDs"
    )

    def add_quest(self, quest: Quest) -> bool:
        """
        Add quest to active quests.

        Args:
            quest: Quest to add

        Returns:
            True if added successfully
        """
        # Check if already active
        if any(q.quest_id == quest.quest_id for q in self.active_quests):
            return False

        # Check if already completed (unless repeatable)
        if not quest.is_repeatable and quest.quest_id in self.completed_quests:
            return False

        quest.start()
        self.active_quests.append(quest)
        return True

    def get_quest(self, quest_id: int) -> Quest | None:
        """Get active quest by ID."""
        for quest in self.active_quests:
            if quest.quest_id == quest_id:
                return quest
        return None

    def complete_quest(self, quest_id: int) -> bool:
        """
        Mark quest as completed and move to completed list.

        Args:
            quest_id: ID of quest to complete

        Returns:
            True if quest was found and completed
        """
        quest = self.get_quest(quest_id)
        if not quest:
            return False

        quest.complete()

        # Add to completed
        if quest_id not in self.completed_quests:
            self.completed_quests.append(quest_id)

        # Track daily quest completion
        if quest.is_daily:
            self.daily_quests_completed[quest_id] = datetime.now()

        # Remove from active
        self.active_quests = [q for q in self.active_quests if q.quest_id != quest_id]

        return True

    def fail_quest(self, quest_id: int) -> bool:
        """
        Mark quest as failed.

        Args:
            quest_id: ID of quest to fail

        Returns:
            True if quest was found and failed
        """
        quest = self.get_quest(quest_id)
        if not quest:
            return False

        quest.fail()
        self.failed_quests.append(quest_id)
        self.active_quests = [q for q in self.active_quests if q.quest_id != quest_id]

        return True

    def get_completable_quests(self) -> list[Quest]:
        """Get quests that are ready to turn in."""
        return [q for q in self.active_quests if q.status == "ready_to_turn_in"]

    def get_quests_by_npc(self, npc_id: int) -> list[Quest]:
        """Get active quests associated with an NPC."""
        return [
            q
            for q in self.active_quests
            if q.npc_id == npc_id or q.turn_in_npc_id == npc_id
        ]

    def is_quest_completed(self, quest_id: int) -> bool:
        """Check if a quest has been completed."""
        return quest_id in self.completed_quests

    def can_accept_daily_quest(self, quest_id: int) -> bool:
        """Check if a daily quest can be accepted today."""
        if quest_id not in self.daily_quests_completed:
            return True

        # Check if last completion was today
        last_completed = self.daily_quests_completed[quest_id]
        now = datetime.now()

        # If last completed date is different from today, can accept again
        return last_completed.date() != now.date()


class QuestDatabase:
    """
    In-memory quest database for caching and lookup.

    Provides fast access to quest definitions without file I/O.
    """

    def __init__(self) -> None:
        """Initialize empty quest database."""
        self._quests: dict[int, Quest] = {}
        self._by_npc: dict[int, list[Quest]] = {}
        self._by_level: dict[int, list[Quest]] = {}

    def add_quest(self, quest: Quest) -> None:
        """Add quest to database."""
        self._quests[quest.quest_id] = quest

        # Index by NPC
        if quest.npc_id not in self._by_npc:
            self._by_npc[quest.npc_id] = []
        self._by_npc[quest.npc_id].append(quest)

        # Index by level range (use min_level as key)
        if quest.min_level not in self._by_level:
            self._by_level[quest.min_level] = []
        self._by_level[quest.min_level].append(quest)

    def get_quest(self, quest_id: int) -> Quest | None:
        """Get quest by ID."""
        quest = self._quests.get(quest_id)
        # Return a copy to prevent modifications to database
        return quest.model_copy() if quest else None

    def get_quests_by_npc(self, npc_id: int) -> list[Quest]:
        """Get all quests from a specific NPC."""
        quests = self._by_npc.get(npc_id, [])
        return [q.model_copy() for q in quests]

    def get_quests_for_level(self, level: int) -> list[Quest]:
        """Get quests available for a specific level."""
        available = []
        for quest in self._quests.values():
            if quest.min_level <= level <= quest.max_level:
                available.append(quest.model_copy())
        return available

    def get_quest_chain(self, quest_id: int) -> list[Quest]:
        """Get entire quest chain starting from given quest."""
        chain = []
        quest = self.get_quest(quest_id)

        if not quest:
            return chain

        chain.append(quest)

        # Get all next quests recursively
        for next_id in quest.next_quests:
            chain.extend(self.get_quest_chain(next_id))

        return chain

    def count(self) -> int:
        """Get total number of quests in database."""
        return len(self._quests)