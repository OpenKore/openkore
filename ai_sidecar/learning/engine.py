"""
Self-Learning Engine using experience replay and strategy adaptation.

Learns from decisions, outcomes, and patterns to improve over time.
"""

from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

from ai_sidecar.memory.decision_models import DecisionContext, DecisionOutcome, DecisionRecord
from ai_sidecar.memory.manager import MemoryManager
from ai_sidecar.memory.models import Memory, MemoryImportance, MemoryQuery, MemoryType
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class LearningEngine:
    """
    Self-learning engine using experience replay.
    
    Features:
    - Decision outcome tracking
    - Experience replay learning
    - Strategy performance monitoring
    - Pattern discovery
    """
    
    def __init__(self, memory_manager: MemoryManager | None = None):
        """
        Initialize learning engine.
        
        Args:
            memory_manager: Memory manager instance. If None, creates a default one.
        """
        if memory_manager is None:
            memory_manager = MemoryManager()
        self.memory = memory_manager
        self.learning_rate = 0.1
        
        # Strategy performance tracking
        self.strategy_scores: Dict[str, Dict[str, float]] = {}
        
        # Decision outcome tracking
        self.pending_outcomes: Dict[str, DecisionRecord] = {}
        self._outcome_timeout = timedelta(minutes=5)
    
    async def record_decision(
        self, decision_type: str, action: Dict, context: DecisionContext
    ) -> str:
        """
        Record a decision for later outcome evaluation.
        
        Args:
            decision_type: Type of decision
            action: Action taken
            context: Decision context
        
        Returns:
            Decision record ID
        """
        record = DecisionRecord(
            record_id=f"{decision_type}_{datetime.now().timestamp()}",
            decision_type=decision_type,
            action_taken=action,
            context=context,
        )
        
        self.pending_outcomes[record.record_id] = record
        await self.memory.remember_decision(record)
        
        return record.record_id
    
    async def record_outcome(
        self,
        record_id: str,
        success: bool,
        actual_result: Dict,
        reward_signal: float = 0.0,
    ) -> None:
        """
        Record the outcome of a decision.
        
        Args:
            record_id: Decision record ID
            success: Whether decision was successful
            actual_result: Actual outcome
            reward_signal: Reward signal (-1 to +1)
        """
        if record_id not in self.pending_outcomes:
            return
        
        record = self.pending_outcomes[record_id]
        record.outcome = DecisionOutcome(
            success=success, actual_result=actual_result, reward_signal=reward_signal
        )
        record.outcome_recorded_at = datetime.now()
        
        # Learn from outcome
        await self._learn_from_decision(record)
        
        # Clean up
        del self.pending_outcomes[record_id]
    
    async def _learn_from_decision(self, record: DecisionRecord) -> None:
        """
        Update strategies based on decision outcome.
        
        Args:
            record: Decision record with outcome
        """
        if not record.outcome:
            return
        
        strategy_key = f"{record.decision_type}:{record.action_taken.get('strategy', 'default')}"
        
        # Initialize if needed
        if strategy_key not in self.strategy_scores:
            self.strategy_scores[strategy_key] = {
                "success_count": 0,
                "total_count": 0,
                "average_reward": 0.0,
            }
        
        scores = self.strategy_scores[strategy_key]
        scores["total_count"] += 1
        
        if record.outcome.success:
            scores["success_count"] += 1
        
        # Update average reward with exponential moving average
        scores["average_reward"] = (
            (1 - self.learning_rate) * scores["average_reward"]
            + self.learning_rate * record.outcome.reward_signal
        )
        
        # Generate lesson learned
        success_rate = scores["success_count"] / scores["total_count"]
        if success_rate < 0.3 and scores["total_count"] >= 5:
            record.lesson_learned = f"Strategy '{strategy_key}' has low success rate ({success_rate:.2%}), consider alternatives"
        elif success_rate > 0.8 and scores["total_count"] >= 5:
            record.lesson_learned = f"Strategy '{strategy_key}' is highly effective ({success_rate:.2%})"
        
        # Store updated record
        await self.memory.remember_decision(record)
        
        # Update persistent strategy
        await self.memory.persistent.store_strategy(
            strategy_key, record.decision_type, record.action_taken, success_rate
        )
        
        logger.info(
            "learned_from_decision",
            strategy=strategy_key,
            success=record.outcome.success,
            success_rate=success_rate,
        )
    
    async def experience_replay(self, batch_size: int = 20) -> Dict[str, Any]:
        """
        Perform experience replay learning.
        
        Args:
            batch_size: Number of decisions to analyze
        
        Returns:
            Statistics about replay session
        """
        # Get recent decisions
        query = MemoryQuery(
            memory_types=[MemoryType.DECISION],
            min_strength=0.3,
            time_range_hours=24,
            limit=batch_size,
        )
        
        memories = await self.memory.query(query)
        
        updates = {"strategies_updated": 0, "patterns_found": 0}
        
        # Group by decision type
        by_type: Dict[str, List[Memory]] = {}
        for m in memories:
            dtype = m.content.get("decision_type", "unknown")
            if dtype not in by_type:
                by_type[dtype] = []
            by_type[dtype].append(m)
        
        # Analyze each type
        for dtype, type_memories in by_type.items():
            successful = []
            for m in type_memories:
                if not m.content:
                    continue
                outcome = m.content.get("outcome")
                if outcome and outcome.get("success", False):
                    successful.append(m)
            
            if len(type_memories) >= 5:
                success_rate = len(successful) / len(type_memories)
                
                # Find common patterns in successful decisions
                if successful:
                    pattern = await self._find_success_pattern(successful)
                    if pattern:
                        await self._store_pattern(dtype, pattern)
                        updates["patterns_found"] += 1
                
                updates["strategies_updated"] += 1
        
        logger.info("experience_replay_complete", **updates)
        return updates
    
    async def _find_success_pattern(self, memories: List[Memory]) -> Optional[Dict]:
        """
        Find common patterns in successful decisions.
        
        Args:
            memories: List of successful decision memories
        
        Returns:
            Pattern data if found
        """
        if len(memories) < 3:
            return None
        
        # Simple pattern: common context factors
        context_factors = {}
        for m in memories:
            context = m.content.get("context", {})
            factors = context.get("considered_factors", [])
            for f in factors:
                context_factors[f] = context_factors.get(f, 0) + 1
        
        # Factors present in >50% of successes
        threshold = len(memories) * 0.5
        common_factors = [
            f for f, count in context_factors.items() if count >= threshold
        ]
        
        if common_factors:
            return {"common_factors": common_factors, "sample_size": len(memories)}
        return None
    
    async def _store_pattern(self, decision_type: str, pattern: Dict) -> None:
        """
        Store a discovered pattern.
        
        Args:
            decision_type: Type of decision
            pattern: Pattern data
        """
        memory = Memory(
            memory_type=MemoryType.PATTERN,
            importance=MemoryImportance.IMPORTANT,
            content={"decision_type": decision_type, "pattern": pattern},
            summary=f"Pattern for {decision_type}: {pattern.get('common_factors', [])}",
            tags=[decision_type, "pattern"],
        )
        await self.memory.store(memory, immediate_persist=True)
    
    async def get_best_action(
        self, decision_type: str, options: List[Dict]
    ) -> Tuple[Dict, float]:
        """
        Get the best action based on learned strategies.
        
        Args:
            decision_type: Type of decision
            options: Available action options
        
        Returns:
            Tuple of (best option, confidence score)
        """
        best_option = options[0] if options else {}
        best_score = 0.0
        
        # Check each option against known strategies
        for option in options:
            strategy_key = f"{decision_type}:{option.get('strategy', 'default')}"
            
            if strategy_key in self.strategy_scores:
                scores = self.strategy_scores[strategy_key]
                if scores["total_count"] > 0:
                    score = scores["success_count"] / scores["total_count"]
                    if score > best_score:
                        best_score = score
                        best_option = option
        
        # Also check persistent strategies
        persistent = await self.memory.persistent.get_best_strategy(decision_type)
        if persistent and persistent["success_rate"] > best_score:
            best_score = persistent["success_rate"]
            best_option = persistent["parameters"]
        
        return best_option, best_score
    
    async def train(self, data: List[Any], model_name: str) -> Dict[str, Any]:
        """
        Train a model with provided data.
        
        Args:
            data: Training data
            model_name: Name of model to train
            
        Returns:
            Training results
        """
        logger.info("train_called", model=model_name, data_size=len(data))
        # Placeholder for actual training logic
        return {"model": model_name, "samples": len(data), "status": "trained"}
    
    async def predict(self, input_data: Dict[str, Any]) -> Any:
        """
        Make a prediction using trained model.
        
        Args:
            input_data: Input data for prediction
            
        Returns:
            Prediction result
        """
        logger.info("predict_called", input_keys=list(input_data.keys()))
        # Placeholder for actual prediction logic
        return None
    
    async def cleanup_pending(self) -> int:
        """
        Clean up timed-out pending outcomes.
        
        Returns:
            Number of timed-out decisions
        """
        now = datetime.now()
        timed_out = []
        
        for record_id, record in self.pending_outcomes.items():
            if now - record.timestamp > self._outcome_timeout:
                timed_out.append(record_id)
        
        for record_id in timed_out:
            # Assume failure if no outcome recorded
            await self.record_outcome(
                record_id,
                success=False,
                actual_result={"reason": "timeout"},
                reward_signal=-0.1,
            )
        
        return len(timed_out)