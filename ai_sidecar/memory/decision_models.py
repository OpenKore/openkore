"""
Decision record models for learning and experience replay.

Tracks decisions, their context, outcomes, and lessons learned.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class DecisionContext(BaseModel):
    """Context at the time of a decision."""
    
    game_state_snapshot: Dict[str, Any]
    available_options: List[str]
    considered_factors: List[str]
    confidence_level: float  # 0-1
    reasoning: str


class DecisionOutcome(BaseModel):
    """Outcome of a decision after execution."""
    
    success: bool
    actual_result: Dict[str, Any]
    expected_result: Optional[Dict[str, Any]] = None
    deviation_score: float = 0.0  # How much it differed from expectation
    reward_signal: float = 0.0    # -1 to +1


class DecisionRecord(BaseModel):
    """
    Complete record of a decision for learning.
    
    Tracks what was decided, why, and what happened as a result.
    """
    
    record_id: str
    timestamp: datetime = Field(default_factory=datetime.now)
    
    # What was decided
    decision_type: str  # combat, movement, skill_use, npc_interact, etc.
    action_taken: Dict[str, Any]
    
    # Context
    context: DecisionContext
    
    # Outcome (filled in later)
    outcome: Optional[DecisionOutcome] = None
    outcome_recorded_at: Optional[datetime] = None
    
    # Learning
    lesson_learned: Optional[str] = None
    strategy_update: Optional[Dict[str, Any]] = None


class ExperienceReplay(BaseModel):
    """Batch of decisions for experience replay learning."""
    
    batch_id: str
    records: List[DecisionRecord]
    replay_at: datetime = Field(default_factory=datetime.now)
    learning_rate: float = 0.01